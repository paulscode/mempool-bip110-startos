# Mempool BIP-110 — Start9 Wrapper

A [StartOS](https://start9.com/) wrapper for [Mempool BIP-110](https://github.com/paulscode/mempool-bip110), a fork of the [Mempool](https://mempool.space/) block explorer (v3.2.1) that adds real-time visualization of **BIP-110 miner signaling** and **transaction rule violations**.

> **This is not a wrapper for upstream Mempool.** It packages the BIP-110 fork, which contains custom frontend and backend changes that are not present in the original Mempool project. It can be installed alongside the standard Mempool package on the same StartOS server.

> **Supports both StartOS 0.3.5.1 and 0.4.0.** Both packages are built from this one repo and the same `Dockerfile`/submodule — see [Building](#building).

## 🎯 Why does this exist?

[BIP-110](https://github.com/dathonohm/bips/blob/reduced-data/bip-0110.mediawiki) (Reduced Data Temporary Softfork) is a proposed temporary soft fork that would limit methods of embedding arbitrary data into Bitcoin transactions — targeting inscriptions and other data-heavy payloads that burden node operators, while preserving all known monetary use cases. It uses BIP9-style miner signaling (version bit 4, 55% activation threshold) for a one-year deployment.

This explorer fork lets you **see BIP-110 in action before it activates**: which miners are signaling, which transactions would become invalid, and how much block weight the violations consume.

## ✨ What the fork adds

### 🟢 Miner Signaling (Green)
Blocks from miners signaling BIP-110 support (version bit 4) are highlighted with a **green glow** on all cube faces in the blockchain view, a **"BIP-110 ✓"** badge on the block detail page, and a pulsing **"None ✓"** badge when the block contains zero violations.

### 🟠 Rule Violations (Orange)
Transactions that would be **invalid under BIP-110** are highlighted with **pulsing neon orange** in the block overview graph, **warning badges** in the transaction list, and a **radioactive icon** on the blockchain cube view. Hovering over badges shows which specific rules are violated.

### Combined view
When a signaling block also contains violations, both effects combine: green border with orange interior.

### BIP-110 rules detected

| # | Rule | Threshold |
|---|------|-----------|
| 1 | **Large scriptPubKey** — Output scripts exceeding 34 bytes (unless OP_RETURN ≤ 83 bytes) | 34 / 83 bytes |
| 2 | **Large PUSHDATA / witness** — Data pushes or witness elements exceeding 256 bytes | 256 bytes |
| 3 | **Undefined witness version** — Spending undefined witness or Tapleaf versions (not v0, v1, or P2A) | — |
| 4 | **Taproot annex** — Witness stacks containing a Taproot annex | — |
| 5 | **Large control block** — Taproot control blocks exceeding 257 bytes | 257 bytes |
| 6 | **OP_SUCCESS\*** — Tapscripts including OP_SUCCESS\* opcodes | — |
| 7 | **OP_IF / OP_NOTIF** — Tapscripts executing conditional flow opcodes | — |

All standard Mempool explorer functionality (mempool visualization, fee estimation, address/transaction lookup, Lightning tab, etc.) is fully preserved.

## 📦 Build dependencies

- [Docker](https://docs.docker.com/get-docker) with [buildx](https://docs.docker.com/buildx/working-with-buildx/)
- [yq](https://mikefarah.gitbook.io/yq) (Go version by mikefarah)
- [toml](https://crates.io/crates/toml-cli)
- [make](https://www.gnu.org/software/make)
- [Start9 SDK](https://docs.start9.com/) — `start-sdk` (0.3.5.1 build) and `start-cli` (0.4.0 build)
- [Node.js + npm](https://nodejs.org/) — for the StartOS 0.4.0 build (`startos/`)

## Cloning

```
git clone https://github.com/paulscode/mempool-bip110-startos.git
cd mempool-bip110-startos
git submodule update --init --recursive
```

The `mempool/` submodule tracks the `master` branch of the [Mempool BIP-110 fork](https://github.com/paulscode/mempool-bip110) and is pinned to a specific commit for reproducible builds.

For cross-architecture builds (ARM64), also run:

```
docker run --privileged --rm tonistiigi/binfmt --install arm64,riscv64,arm
```

## Building

This repo builds **two** packages from one source tree, both from the same
`Dockerfile`/submodule:

- **StartOS 0.3.5.1** (Embassy SDK) — `manifest.yaml` + `scripts/embassy.js`, packed with `start-sdk`.
- **StartOS 0.4.0** (start-sdk TS) — `startos/`, packed with `start-cli`.

Each produces a single universal `.s9pk` containing **x86_64 + aarch64**.

```
# StartOS 0.3.5.1
make                  # universal -> mempool-rdts.s9pk
make x86 | make arm   # single arch (faster)

# StartOS 0.4.0  (every output is named with "040")
make 040              # universal  -> mempool-rdts_040.s9pk
make pack-040-x86     # single arch -> mempool-rdts_040_x86_64.s9pk
make install-040-x86  # build x86_64 + install to your 0.4.0 server

# Both, for an official release
make release          # -> builds/<version>/{mempool-rdts-0351.s9pk, mempool-rdts-040.s9pk} + SHA256SUMS
```

The 0.4.0 build requires Node.js/npm (to compile `startos/` via `npm run build`)
and `start-cli`; the first build runs `npm ci` automatically.

## Installing (on StartOS)

`scp` the `.s9pk` to your Start9 server:

```
scp mempool-rdts.s9pk root@<LAN ID>:/tmp
```

Then install:

```
start-cli auth login
start-cli package install /tmp/mempool-bip110.s9pk
```

### Requirements

- A fully synced, **unpruned** Bitcoin Core (or Bitcoin Knots) node with `txindex=1`
- Optional: LND or Core Lightning for the Lightning tab

## 🔗 Related Links

- [BIP-110 Specification](https://github.com/dathonohm/bips/blob/reduced-data/bip-0110.mediawiki)
- [BIP-110 Discussion (bitcoindev)](https://groups.google.com/g/bitcoindev/c/nOZim6FbuF8)
- [Mempool BIP-110 Fork](https://github.com/paulscode/mempool-bip110)
- [Original Mempool Project](https://mempool.space/)
- [StartOS Documentation](https://docs.start9.com/)

## 📄 License

AGPL-3.0 — See [LICENSE](LICENSE) for details.

## 🙏 Credits

- [The Mempool Open Source Project](https://mempool.space/) — Original explorer
- [Start9 Labs](https://start9.com/) — StartOS and wrapper framework
- BIP-110 Authors — Consensus rule specification
