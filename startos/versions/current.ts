import { VersionInfo } from '@start9labs/start-sdk'

export const current = VersionInfo.of({
  version: '3.2.1:4',
  releaseNotes: {
    en_US:
      'Prepared for mandatory signaling and activation. Block colours and wording now depend on the block height and on whether your node enforces BIP-110: blocks that are invalid now show red, distinct from amber for violations that are only hypothetical or historical. Detects node enforcement via getdeploymentinfo, reports whether the chain your node follows obeys BIP-110 (naming the first diverging block), and implements the spec exemption for inputs spending pre-activation UTXOs. Adds gold milestone markers for mandatory signaling, lock-in, activation and expiry, and a per-phase deployment card. Fixes violation counts surviving a reorg, unknown counts reading as "no violations", and the newest blocks going unscanned. Based on Mempool v3.2.1.',
  },
  // No data migration: 3.2.1:3 -> 3.2.1:4 changes only application logic and UI.
  // The 0.3.x -> 0.4.0 config migration stays on 3.2.1:3, which remains in the
  // version graph so that path is still reachable.
  migrations: {},
})
