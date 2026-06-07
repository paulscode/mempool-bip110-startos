import { setupManifest } from '@start9labs/start-sdk'
import {
  alertInstall,
  alertUpdate,
  bitcoindDescription,
  clnDescription,
  electrsDescription,
  fulcrumDescription,
  lndDescription,
  long,
  short,
} from './i18n'

export const manifest = setupManifest({
  id: 'mempool-rdts',
  title: 'Mempool BIP-110',
  license: 'AGPL',
  packageRepo: 'https://github.com/paulscode/mempool-bip110-startos',
  upstreamRepo: 'https://github.com/paulscode/mempool-bip110',
  marketingUrl: 'https://github.com/paulscode/mempool-bip110',
  donationUrl: 'https://mempool.space/sponsor',
  description: { short, long },
  volumes: ['main', 'cache', 'db', 'config'],
  images: {
    // Single monolithic image (frontend + backend + MariaDB + nginx), built
    // from ./Dockerfile against the BIP-110 fork submodule. Mirrors the 0.3.x
    // package layout. TARGETARCH is provided automatically by buildx per arch.
    main: {
      source: {
        dockerBuild: {
          dockerfile: 'Dockerfile',
          workdir: '.',
        },
      },
      arch: ['x86_64', 'aarch64'],
    },
  },
  alerts: {
    install: alertInstall,
    update: alertUpdate,
  },
  dependencies: {
    bitcoind: {
      description: bitcoindDescription,
      optional: false,
      metadata: {
        title: 'Bitcoin',
        icon: 'https://raw.githubusercontent.com/Start9Labs/bitcoin-core-startos/refs/heads/30.x/dep-icon.svg',
      },
    },
    electrs: {
      description: electrsDescription,
      optional: true,
      metadata: {
        title: 'Electrs',
        icon: 'https://raw.githubusercontent.com/Start9Labs/electrs-startos/refs/heads/master/icon.svg',
      },
    },
    fulcrum: {
      description: fulcrumDescription,
      optional: true,
      metadata: {
        title: 'Fulcrum',
        icon: 'https://raw.githubusercontent.com/Start9Labs/fulcrum-startos/master/icon.png',
      },
    },
    'c-lightning': {
      description: clnDescription,
      optional: true,
      metadata: {
        title: 'Core Lightning',
        icon: 'https://raw.githubusercontent.com/Start9Labs/cln-startos/refs/heads/master/icon.svg',
      },
    },
    lnd: {
      description: lndDescription,
      optional: true,
      metadata: {
        title: 'LND',
        icon: 'https://raw.githubusercontent.com/Start9Labs/lnd-startos/refs/heads/master/icon.svg',
      },
    },
  },
})
