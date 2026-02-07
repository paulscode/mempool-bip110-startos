# Mempool BIP-110

Mempool BIP-110 is a specialized fork of the open-source Mempool explorer, enhanced with visualizations for BIP-110 (Reduced Data Temporary Softfork) information.

## 🎯 BIP-110 Features

### Signaling Blocks (Green/Gold Celebration Style)
Blocks mined by pools signaling support for BIP-110 are highlighted with celebratory green and gold styling. Look for the **"BIP-110 ✓"** badge next to the block version in block details.

### Invalid Transactions (Orange Warning Style)
Transactions that would violate BIP-110 consensus rules (if activated) are highlighted with glowing orange warning indicators. These transactions show a **"⚠️ BIP-110"** badge in the transaction features.

### What Makes a Transaction Invalid Under BIP-110?

1. **Large scriptPubKey** - Output scripts larger than 34 bytes (except OP_RETURN up to 83 bytes)
2. **Large data pushes** - OP_PUSHDATA or witness elements larger than 256 bytes
3. **Undefined witness versions** - Spending from witness versions other than v0 (SegWit), v1 (Taproot), or P2A
4. **Taproot annex** - Transactions with Taproot annex data
5. **Large control blocks** - Taproot control blocks larger than 257 bytes
6. **OP_SUCCESS opcodes** - Tapscripts containing OP_SUCCESS* opcodes
7. **OP_IF/OP_NOTIF** - Tapscripts using conditional flow opcodes

## Configuration

Mempool BIP-110 on the Start9 Server requires a fully synced archival Bitcoin Core node to function.

This implementation enables you to connect to your own Bitcoin Core node.

As of Mempool v2.5.0, you can optionally enable the Lightning Tab. This requires you to have either LND or Core Lightning running on your Start9 Server.

## Lightning

Once the Lightning tab is enabled, you are able to see information across the entire Lightning network, including statistics about your own lightning node. Choosing LND or Core Lightning provide similar network data, but may have different quantities of historical data depending on the age of your lightning node.

## Mining

The Mining tab provides network information about bitcoin mining statistics and 3rd party information about known mining pools connected to each confirmed block.

## Address Lookups

To enable address lookups, select Electrs or Fulcrum as the Indexer in the configuration menu.

You will need Electrs or Fulcrum to be installed and synced before this feature will work. Lookups may be slow or time out altogether while the service is still warming up, or if there are too many other things running on your system.

## Support

For general Mempool questions, visit the [mempool.space matrix support room](https://matrix.to/#/%23mempool:bitcoin.kyoto).

For BIP110-specific questions, see the [BIP110 discussion](https://groups.google.com/g/bitcoindev/c/nOZim6FbuF8) or the [project repository](https://github.com/paulscode/mempool-bip110).
