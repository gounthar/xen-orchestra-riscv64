#!/usr/bin/env bash
# On a native riscv64 runner (RISE ubuntu-24.04-riscv), from the XO checkout: install, build
# xo-server, xo-lib (the one workspace dependency of xo-web, which only builds under QEMU) and
# XO 6 (vite only: its vue-tsc type-check runs in the QEMU build and emits no
# files), then require the outputs to match the QEMU build byte for byte. Node on riscv64 has
# a heap-corruption bug on real hardware, so a native build that finishes is not trusted on
# its own. Failed workspace builds are retried once under --predictable.
# Usage: native-build.sh <bindings-dir> <logs-dir> <qemu-manifest>
set -euo pipefail
bindings=$(realpath "$1"); logs=$(realpath -m "$2"); ref=$(realpath "$3"); mkdir -p "$logs"
ci=$(dirname "$(realpath "$0")")
# --predictable wrapper as a copy of the Node directory: yarn 1 prepends dirname(execPath)
# to PATH, so a lone `node` shim elsewhere on PATH is bypassed; here execPath's own dir holds it.
real=$(dirname "$(dirname "$(command -v node)")")
pred=$RUNNER_TEMP/node-predictable
cp -a "$real" "$pred"; mv "$pred/bin/node" "$pred/bin/node-real"
printf '#!/bin/sh\nexec "$(dirname "$0")/node-real" --predictable "$@"\n' > "$pred/bin/node"
chmod +x "$pred/bin/node"
export PREDICTABLE_SHIM=$pred/bin BUILT_LIST=$logs/built-workspaces
install() { CXXFLAGS=-DLEVELDB_ATOMIC_PRESENT /usr/bin/time -v yarn 2>&1 | tee -a "$logs/install.log" | tail -3; }
# yarn itself has hit the heap corruption (run 36277817399: "Cannot create property 'onDone'
# on number '48'"), so a failed install is retried once under --predictable.
install || { echo "install failed, retrying under --predictable"; PATH="$pred/bin:$PATH" install; }
"$ci/install-bindings.sh" . "$bindings" | tee "$logs/bindings.log"
"$ci/patch-node-modules.sh" | tee -a "$logs/bindings.log"
/usr/bin/time -v node "$ci/build-deps.mjs" xo-server @vates/fuse-vhd xo-lib $("$ci/plugins.sh") 2>&1 | tee "$logs/server.log" | grep '^BUILD\|Elapsed'
( cd @xen-orchestra/web && /usr/bin/time -v yarn run build-only ) 2>&1 | tee "$logs/xo6.log" | tail -3
"$ci/manifest.sh" > "$logs/native.sha256"
if cmp -s "$ref" "$logs/native.sha256"; then
  echo "native build matches the QEMU build: $(wc -l < "$ref") files"
else
  diff "$ref" "$logs/native.sha256" > "$logs/manifest.diff" || true
  echo "native build DIFFERS from the QEMU build ($(grep -c '^<' "$logs/manifest.diff") lines):"
  head -20 "$logs/manifest.diff"; exit 1
fi
