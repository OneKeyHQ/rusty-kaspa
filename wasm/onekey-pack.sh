#!/bin/bash
#
# OneKey wasm packaging.
#
# Builds the kaspa wasm (web + nodejs, wasm32-sdk feature) from the CURRENTLY
# CHECKED-OUT kaspa release source and repackages the output into:
#
#   wasm/npm       -> @onekeyfe/kaspa-wasm       (web target; wasm inlined as base64)
#   wasm/npm-node  -> @onekeyfe/kaspa-wasm-node  (nodejs target; raw .wasm)
#
# MAINTENANCE: to move to a newer kaspa release, check out that release TAG
# (NOT master - master carries unreleased drift) and re-run this script with a
# bumped npm version. The committed wasm/npm* artifacts then stay reproducible
# from the checked-out source.
#
#   git checkout -b chore/wasm-<tag>-onekey <tag>
#   ./wasm/onekey-pack.sh <npm-version>
#
set -euo pipefail

VERSION="${1:?usage: onekey-pack.sh <npm-version>   e.g. 1.0.3-alpha.1}"
WASM_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$WASM_DIR"

# secp256k1-sys compiles C down to wasm32. Apple's clang has no wasm backend, so
# on macOS point the C toolchain at Homebrew llvm. On Linux/CI the system clang
# (e.g. clang-15) already targets wasm32, so leave CC/AR unset there.
LLVM_MAC="/opt/homebrew/opt/llvm@21/bin"
if [ -x "$LLVM_MAC/clang" ]; then
  export CC_wasm32_unknown_unknown="$LLVM_MAC/clang"
  export AR_wasm32_unknown_unknown="$LLVM_MAC/llvm-ar"
fi

echo ">>> building wasm (web, sdk) ..."
./build-web --sdk      # -> wasm/web/kaspa
echo ">>> building wasm (nodejs, sdk) ..."
./build-node           # -> wasm/nodejs/kaspa  (reuses web's compiled deps)

# ---------------------------------------------------------------------------
# web -> wasm/npm  (@onekeyfe/kaspa-wasm)
# ---------------------------------------------------------------------------
echo ">>> packaging wasm/npm (@onekeyfe/kaspa-wasm) ..."
NPM="$WASM_DIR/npm"
rm -rf "$NPM"; mkdir -p "$NPM"
cp web/kaspa/kaspa.js web/kaspa/kaspa.d.ts web/kaspa/kaspa_bg.wasm.d.ts "$NPM/"
[ -f web/kaspa/README.md ] && cp web/kaspa/README.md "$NPM/" || true
[ -f web/kaspa/LICENSE ]   && cp web/kaspa/LICENSE   "$NPM/" || true

# rename the wasm so bundlers don't auto-resolve/emit it as an asset
cp web/kaspa/kaspa_bg.wasm "$NPM/kaspa_bg.wasm.bin"

# inline the wasm as base64 (require split keeps bundlers from static-analysing it)
{
  printf 'module.exports = function loadWebAssembly() {\n  return require("buf" + "fer").Buffer.from("'
  base64 < "$NPM/kaspa_bg.wasm.bin" | tr -d '\n'
  printf '", "base64");\n};\n'
} > "$NPM/kaspa_bg.wasm.js"

# patch kaspa.js: instantiate from the inline base64 buffer, never fetch a URL
perl -0pi -e 's/async function __wbg_load\(module, imports\) \{/async function __wbg_load(module, imports) {\n    return await WebAssembly.instantiate(require(".\/kaspa_bg.wasm.js")(), imports);/' "$NPM/kaspa.js"
perl -pi -e "s/new URL\('kaspa_bg\.wasm', import\.meta\.url\)/new URL('kaspa_bg.wasm.bin', import.meta.url)/" "$NPM/kaspa.js"
perl -pi -e 's/^(\s*)module_or_path = fetch\(module_or_path\);/$1\/\/ module_or_path = fetch(module_or_path);/' "$NPM/kaspa.js"

# verify each patch landed exactly once
grep -q 'require("./kaspa_bg.wasm.js")()' "$NPM/kaspa.js" || { echo "ERR: __wbg_load patch failed"; exit 1; }
grep -q "new URL('kaspa_bg.wasm.bin'" "$NPM/kaspa.js"     || { echo "ERR: wasm.bin URL patch failed"; exit 1; }
grep -q '// module_or_path = fetch' "$NPM/kaspa.js"       || { echo "ERR: fetch comment patch failed"; exit 1; }

cat > "$NPM/package.json" <<JSON
{
  "name": "@onekeyfe/kaspa-wasm",
  "collaborators": [
    "Kaspa developers"
  ],
  "description": "KASPA WASM bindings",
  "version": "$VERSION",
  "license": "ISC",
  "repository": {
    "type": "git",
    "url": "https://github.com/OneKeyHQ/rusty-kaspa"
  },
  "files": [
    "kaspa_bg.wasm.d.ts",
    "kaspa_bg.wasm.bin",
    "kaspa.js",
    "kaspa.d.ts",
    "kaspa_bg.wasm.js"
  ],
  "module": "kaspa.js",
  "types": "kaspa.d.ts",
  "sideEffects": [
    "./snippets/*"
  ]
}
JSON

# ---------------------------------------------------------------------------
# nodejs -> wasm/npm-node  (@onekeyfe/kaspa-wasm-node)
# ---------------------------------------------------------------------------
echo ">>> packaging wasm/npm-node (@onekeyfe/kaspa-wasm-node) ..."
NODE="$WASM_DIR/npm-node"
rm -rf "$NODE"; mkdir -p "$NODE"
cp nodejs/kaspa/kaspa.js nodejs/kaspa/kaspa.d.ts nodejs/kaspa/kaspa_bg.wasm.d.ts nodejs/kaspa/kaspa_bg.wasm "$NODE/"
[ -f nodejs/kaspa/README.md ] && cp nodejs/kaspa/README.md "$NODE/" || true
[ -f nodejs/kaspa/LICENSE ]   && cp nodejs/kaspa/LICENSE   "$NODE/" || true

cat > "$NODE/package.json" <<JSON
{
  "name": "@onekeyfe/kaspa-wasm-node",
  "collaborators": [
    "Kaspa developers"
  ],
  "description": "KASPA WASM bindings",
  "version": "$VERSION",
  "license": "ISC",
  "repository": {
    "type": "git",
    "url": "https://github.com/OneKeyHQ/rusty-kaspa"
  },
  "files": [
    "kaspa_bg.wasm.d.ts",
    "kaspa_bg.wasm",
    "kaspa.js",
    "kaspa.d.ts"
  ],
  "module": "kaspa.js",
  "types": "kaspa.d.ts",
  "sideEffects": [
    "./snippets/*"
  ]
}
JSON

echo ">>> done. version=$VERSION"
echo "    wasm/npm       -> @onekeyfe/kaspa-wasm@$VERSION"
echo "    wasm/npm-node  -> @onekeyfe/kaspa-wasm-node@$VERSION"
