# @onekeyfe/kaspa-wasm-node

OneKey's repackaging of the **official Kaspa WASM32 SDK (nodejs target)**.

## Where the binary comes from (NOT built from this repo)

Not compiled from this repository's Rust source. Taken from the official
`kaspanet/rusty-kaspa` GitHub Release asset `kaspa-wasm32-sdk-v<tag>.zip`, folder
`nodejs/kaspa/`.

Current binary: **kaspa v2.0.1** (post-Crescendo — payload-in-sighash + wRPC
`RpcClient`). Build path `/home/runner/...` (kaspanet CI build).

> ⚠️ Do NOT take this from npm — upstream `kaspa-wasm32-sdk` on npm is stale at
> `0.15.2`. Use the GitHub **Release** assets.

## Processing

Unlike the web package (`@onekeyfe/kaspa-wasm`), the node target loads its `.wasm`
from disk via `fs`, so it needs **no inline-base64 / loader patch**. The files are
copied straight from the release's `nodejs/kaspa/`; only `package.json` (name +
version) is OneKey's.

## Updating

See `../npm/README.md`. For this package just copy `nodejs/kaspa/`'s `kaspa.js`,
`kaspa.d.ts`, `kaspa_bg.wasm`, `kaspa_bg.wasm.d.ts`, `LICENSE`, then bump the
`version` in `package.json`.
