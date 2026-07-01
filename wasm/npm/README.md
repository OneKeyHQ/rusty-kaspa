# @onekeyfe/kaspa-wasm

OneKey's repackaging of the **official Kaspa WASM32 SDK (web target)**, adapted so
it loads across all OneKey platforms — including React Native, where the stock
package cannot load.

## Where the binary comes from (NOT built from this repo)

The wasm binary and JS glue are **not** compiled from this repository's Rust
source. They are taken from the **official `kaspanet/rusty-kaspa` GitHub Release**:

- Releases: https://github.com/kaspanet/rusty-kaspa/releases
- Asset: `kaspa-wasm32-sdk-v<tag>.zip` → use the optimized `web/kaspa/` folder

Current binary: **kaspa v2.0.1** (post-Crescendo — binds the transaction `payload`
into the signing hash and ships the wRPC `RpcClient`). The embedded build path is
`/home/runner/...`, i.e. kaspanet's own CI build.

> ⚠️ Do NOT take this from npm. The upstream npm package `kaspa-wasm32-sdk` is
> stale (stuck at `0.15.2`) — that is why older `@onekeyfe/kaspa-wasm` builds were
> a pre-payload `0.15.2` binary. Always take the prebuilt from the GitHub
> **Release** assets.

## What OneKey changes, and why

The stock package loads the wasm via `fetch(new URL('kaspa_bg.wasm', import.meta.url))`,
which fails in React Native (no `import.meta.url` asset resolution, can't fetch a
local `.wasm`) and in some bundlers. OneKey rewrites the loader so the wasm is
**embedded and `require()`d, never fetched**:

1. rename `kaspa_bg.wasm` → `kaspa_bg.wasm.bin` (so bundlers don't emit it as an asset)
2. add `kaspa_bg.wasm.js` — the wasm inlined as base64, exported via `require()`
3. patch `kaspa.js` `__wbg_load` to instantiate from that inline base64 (the
   `fetch` / `instantiateStreaming` path is disabled)

## Updating to a newer kaspa release

1. Download `kaspa-wasm32-sdk-v<tag>.zip` from the kaspanet release.
2. From the zip's `web/kaspa/`, repackage into this folder:
   - copy `kaspa.js`, `kaspa.d.ts`, `kaspa_bg.wasm.d.ts`, `LICENSE`
   - `cp kaspa_bg.wasm kaspa_bg.wasm.bin`
   - regenerate `kaspa_bg.wasm.js` = `module.exports = () => Buffer.from("<base64 of .bin>", "base64")`
   - re-apply the three `kaspa.js` patches above
3. Bump `version` in `package.json`.
4. Do the same for `../npm-node` from the zip's `nodejs/kaspa/` (node loads the raw
   `.wasm` via `fs`, so it needs no inline patch — just copy the files).
5. Commit, then trigger the `publish-npm-package` GitHub Action (workflow_dispatch).
