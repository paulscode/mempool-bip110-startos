import { sdk } from './sdk'

/**
 * Single-image package: MariaDB runs inside the `main` container rather than as
 * a separate `mariadb` image, so we back up the volumes directly (matching the
 * 0.3.x package's behavior). `config` holds the generated mempool-config.json
 * including the DB password, so it must be included for a restore to authenticate.
 */
export const { createBackup, restoreInit } = sdk.setupBackups(async () =>
  sdk.Backups.ofVolumes('main', 'cache', 'db', 'config'),
)
