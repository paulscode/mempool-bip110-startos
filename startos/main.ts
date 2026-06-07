import { totalmem } from 'os'
import { manifest as bitcoinManifest } from 'bitcoin-core-startos/startos/manifest'
import { manifest as clnManifest } from 'cln-startos/startos/manifest'
import { manifest as lndManifest } from 'lnd-startos/startos/manifest'
import { configJson } from './file-models/mempool-config.json'
import { i18n } from './i18n'
import { sdk } from './sdk'
import { btcMountpoint, clnMountpoint, lndMountpoint, uiPort } from './utils'

export const main = sdk.setupMain(async ({ effects }) => {
  /**
   * ======================== Setup ========================
   *
   * Single-image deployment: one `main` image (built from ./Dockerfile) that
   * runs MariaDB + the mempool backend + the nginx frontend together, driven by
   * docker_entrypoint_040.sh. All connection details (Bitcoin cookie auth,
   * indexer, lightning, database) live in the generated mempool-config.json,
   * which is mounted read-only into the container; the entrypoint reads what it
   * needs (DB password, lightning toggle) from it via jq.
   */
  console.info(i18n('Starting Mempool'))

  const config = await configJson.read().const(effects)
  if (!config) throw new Error('Config file not found')

  // V8 old-space heap for the mempool backend, scaled to host RAM. Reserve
  // headroom for the co-resident stack (Bitcoin Core, indexer, LND/CLN, StartOS)
  // before computing our share. Indexing is memory-hungry, so raise the floor
  // when any indexing toggle is on.
  const RESERVED_MB = 6 * 1024
  const totalMB = Math.floor(totalmem() / (1024 * 1024))
  const effectiveMB = Math.max(0, totalMB - RESERVED_MB)
  const anyIndexing =
    config.MEMPOOL.BLOCKS_SUMMARIES_INDEXING ||
    config.MEMPOOL.GOGGLES_INDEXING ||
    config.MEMPOOL.AUDIT ||
    config.MEMPOOL.CPFP_INDEXING
  const backendMaxOldSpaceMB = anyIndexing
    ? Math.max(4096, Math.min(8192, Math.floor(effectiveMB / 4)))
    : Math.max(2048, Math.min(8192, Math.floor(effectiveMB / 8)))

  let mounts = sdk.Mounts.of()
    .mountVolume({
      volumeId: 'main',
      subpath: null,
      mountpoint: '/root',
      readonly: false,
    })
    .mountVolume({
      volumeId: 'cache',
      subpath: null,
      mountpoint: '/backend/cache',
      readonly: false,
    })
    .mountVolume({
      volumeId: 'db',
      subpath: null,
      mountpoint: '/var/lib/mysql',
      readonly: false,
    })
    .mountVolume({
      volumeId: 'config',
      subpath: 'mempool-config.json',
      mountpoint: '/backend/mempool-config.json',
      readonly: true,
      type: 'file',
    })
    .mountDependency<typeof bitcoinManifest>({
      dependencyId: 'bitcoind',
      volumeId: 'main',
      subpath: null,
      mountpoint: btcMountpoint,
      readonly: true,
    })

  if (config.LIGHTNING.ENABLED) {
    switch (config.LIGHTNING.BACKEND) {
      case 'lnd':
        mounts = mounts.mountDependency<typeof lndManifest>({
          dependencyId: 'lnd',
          volumeId: 'main',
          subpath: null,
          mountpoint: lndMountpoint,
          readonly: true,
          type: 'directory',
        })
        break
      case 'cln':
        mounts = mounts.mountDependency<typeof clnManifest>({
          dependencyId: 'c-lightning',
          volumeId: 'main',
          subpath: 'bitcoin',
          mountpoint: clnMountpoint,
          readonly: true,
          type: 'directory',
        })
        break
      default:
        break
    }
  }

  const mainSub = await sdk.SubContainer.of(
    effects,
    { imageId: 'main' },
    mounts,
    'mempool-bip110',
  )

  /**
   *  ======================== Daemon ========================
   */
  return sdk.Daemons.of(effects).addDaemon('mempool', {
    subcontainer: mainSub,
    exec: {
      command: ['docker_entrypoint_040.sh'],
      user: 'root',
      env: {
        NODE_OPTIONS: `--max-old-space-size=${backendMaxOldSpaceMB}`,
      },
    },
    ready: {
      // MariaDB init + indexing warm-up can be slow on first boot.
      gracePeriod: 120_000,
      display: i18n('Web Interface'),
      fn: () =>
        sdk.healthCheck.checkPortListening(effects, uiPort, {
          successMessage: i18n('The web interface is ready'),
          errorMessage: i18n('The web interface is not ready'),
        }),
    },
    requires: [],
  })
})
