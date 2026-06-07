import { IMPOSSIBLE, VersionInfo, YAML } from '@start9labs/start-sdk'
import { readFile, rm } from 'fs/promises'
import { configJson } from '../file-models/mempool-config.json'

export const current = VersionInfo.of({
  version: '3.2.1:3',
  releaseNotes: {
    en_US:
      'First StartOS 0.4.0 release of Mempool BIP-110. BIP-110 detection reconciled with the updated spec (Rule 2 script-argument exemptions, Rule 3 Tapleaf versions, Rule 6 OP_SUCCESS), false-positive fixes, an EXPIRED deployment phase, a header-based live signaling count with a recent-signaling-blocks modal, and the full mining-pool logo set. Based on Mempool v3.2.1.',
  },
  migrations: {
    // Best-effort migration from the 0.3.x package (mempool-rdts 3.2.1.x).
    // The 0.3.x wrapper stored its settings in the `main` volume at
    // start9/config.yaml; translate the indexer/lightning choices into the
    // 0.4.0 mempool-config.json and keep the existing DB password ('mempool').
    up: async ({ effects }) => {
      const configYaml:
        | {
            'bitcoin-user'?: string
            'bitcoin-password'?: string
            indexer?: { type?: 'electrs' | 'fulcrum' | 'none' }
            lightning?: { type?: 'lnd' | 'cln' | 'none' }
          }
        | undefined = await readFile(
        '/media/startos/volumes/main/start9/config.yaml',
        'utf-8',
      ).then(YAML.parse, () => undefined)

      if (!configYaml) {
        return
      }

      const { lightning, indexer } = configYaml

      const custom: {
        DATABASE?: { PASSWORD: string }
        LIGHTNING?: { ENABLED: boolean; BACKEND?: 'lnd' | 'cln' }
        ELECTRUM?: {
          HOST: 'electrs.startos' | 'fulcrum.startos'
          PORT: number
          TLS_ENABLED: boolean
        }
      } = { DATABASE: { PASSWORD: 'mempool' } } // 0.3.x used mempool/mempool

      if (lightning && lightning.type && lightning.type !== 'none') {
        custom.LIGHTNING = { ENABLED: true, BACKEND: lightning.type }
      } else {
        custom.LIGHTNING = { ENABLED: false }
      }

      if (
        indexer &&
        (indexer.type === 'electrs' || indexer.type === 'fulcrum')
      ) {
        custom.ELECTRUM = {
          HOST:
            indexer.type === 'fulcrum' ? 'fulcrum.startos' : 'electrs.startos',
          PORT: 50001,
          TLS_ENABLED: false,
        }
      }

      await configJson.merge(effects, custom)

      // Remove the old 0.3.x config dir.
      await rm('/media/startos/volumes/main/start9', {
        recursive: true,
      }).catch(console.error)
    },
    down: IMPOSSIBLE,
  },
})
