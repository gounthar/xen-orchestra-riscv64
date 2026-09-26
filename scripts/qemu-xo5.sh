#!/usr/bin/env bash
# Inside a linux/riscv64 container under QEMU user-mode: install XO and build xo-web (XO 5).
# Native riscv64 hardware (BPI-F3, RISE EM-RV1) crashes V8 in gulp buildScripts; QEMU does not.
# Usage (from the XO checkout): bash /ci/scripts/qemu-xo5.sh
set -euo pipefail
NODE_VERSION=${NODE_VERSION:-v22.23.2}
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends ca-certificates curl xz-utils git \
  python3 make g++ pkg-config libfuse-dev time >/dev/null
base=https://unofficial-builds.nodejs.org/download/release/$NODE_VERSION
tarball=node-$NODE_VERSION-linux-riscv64.tar.xz
curl -fsSLO "$base/$tarball"
curl -fsSL "$base/SHASUMS256.txt" | grep " $tarball\$" | sha256sum -c -
mkdir -p /opt/node && tar -xJf "$tarball" -C /opt/node --strip-components=1 && rm "$tarball"
export PATH=/opt/node/bin:$PATH
corepack enable && corepack prepare yarn@1.22.22 --activate
git config --global --add safe.directory '*'
node -p "[process.arch, process.version, process.versions.v8].join(' ')"
CXXFLAGS=-DLEVELDB_ATOMIC_PRESENT /usr/bin/time -v yarn 2>&1 | tee /ci/logs/xo5-install.log | tail -5
/usr/bin/time -v node /ci/scripts/build-deps.mjs xo-web 2>&1 | tee /ci/logs/xo5-build.log | grep '^BUILD\|Elapsed'
test -s packages/xo-web/dist/index.js
