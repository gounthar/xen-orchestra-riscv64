#!/usr/bin/env bash
# On a native riscv64 runner (RISE ubuntu-24.04-riscv): install XO, build xo-server and
# XO 6 with the cross-built bindings. Failed builds are retried once under --predictable.
# Usage (from the XO checkout): native-build.sh <bindings-dir> <logs-dir>
set -euo pipefail
bindings=$(realpath "$1"); logs=$(realpath -m "$2"); mkdir -p "$logs"
ci=$(dirname "$(realpath "$0")")
# --predictable wrapper as a copy of the Node directory: yarn 1 prepends dirname(execPath)
# to PATH, so a lone `node` shim elsewhere on PATH is bypassed; here execPath's own dir holds it.
real=$(dirname "$(dirname "$(command -v node)")")
pred=$RUNNER_TEMP/node-predictable
cp -a "$real" "$pred"; mv "$pred/bin/node" "$pred/bin/node-real"
printf '#!/bin/sh\nexec "$(dirname "$0")/node-real" --predictable "$@"\n' > "$pred/bin/node"
chmod +x "$pred/bin/node"
export PREDICTABLE_SHIM=$pred/bin BUILT_LIST=$logs/built-workspaces
CXXFLAGS=-DLEVELDB_ATOMIC_PRESENT /usr/bin/time -v yarn 2>&1 | tee "$logs/install.log" | tail -5
"$ci/install-bindings.sh" . "$bindings" | tee "$logs/bindings.log"
/usr/bin/time -v node "$ci/build-deps.mjs" xo-server @vates/fuse-vhd 2>&1 | tee "$logs/server.log" | grep '^BUILD\|Elapsed'
/usr/bin/time -v node "$ci/build-deps.mjs" @xen-orchestra/web 2>&1 | tee "$logs/xo6.log" | grep '^BUILD\|Elapsed'
