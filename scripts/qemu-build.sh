#!/usr/bin/env bash
# Inside a linux/riscv64 container under QEMU user-mode, from the XO checkout (mounted at the
# same absolute path as on the native runner, so outputs that embed paths still compare):
# full build of xo-server, xo-web (XO 5) and XO 6, then the manifest the native build must match.
# Needs /ci (this repo), /bindings (cross-built .node files), /logs.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends ca-certificates curl xz-utils git \
  python3 make g++ pkg-config libfuse-dev time >/dev/null
bash /ci/scripts/node-riscv64.sh
export PATH=/opt/node/bin:$PATH
corepack enable && corepack prepare yarn@1.22.22 --activate
git config --global --add safe.directory '*'
node -p "[process.arch, process.version, process.versions.v8].join(' ')"
export BUILT_LIST=/logs/built-workspaces
CXXFLAGS=-DLEVELDB_ATOMIC_PRESENT /usr/bin/time -v yarn 2>&1 | tee /logs/install.log | tail -3
/ci/scripts/install-bindings.sh . /bindings | tee /logs/bindings.log
b() { /usr/bin/time -v node /ci/scripts/build-deps.mjs "$@" 2>&1 | tee -a /logs/build.log | grep '^BUILD\|Elapsed'; }
b xo-server @vates/fuse-vhd $(/ci/scripts/plugins.sh)
b xo-web
b @xen-orchestra/web
test -s packages/xo-web/dist/index.js
/ci/scripts/manifest.sh > /logs/qemu.sha256
wc -l /logs/qemu.sha256
