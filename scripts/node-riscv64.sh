#!/usr/bin/env bash
# Install riscv64 Node from unofficial-builds (sha256-checked) into /opt/node. For the QEMU container.
set -euo pipefail
v=${NODE_VERSION:-v22.23.2}; base=https://unofficial-builds.nodejs.org/download/release/$v
t=node-$v-linux-riscv64.tar.xz
curl -fsSLO "$base/$t"; curl -fsSL "$base/SHASUMS256.txt" | grep " $t\$" | sha256sum -c -
mkdir -p /opt/node && tar -xJf "$t" -C /opt/node --strip-components=1 && rm "$t"
