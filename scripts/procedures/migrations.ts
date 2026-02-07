import { types as T, compat } from "../deps.ts";

// Initial release — no legacy migrations needed.
// Future versions should add migration entries here.
const current = "3.2.1";

export const migration: T.ExpectedExports.migration = (
  effects: T.Effects,
  version: string,
  ...args: unknown[]
) => {
  return compat.migrations.fromMapping(
    {
      // No migrations yet — 3.2.1 is the first release of mempool-rdts.
    },
    current
  )(effects, version, ...args);
};
