#!/usr/bin/env bash
# Install cross-built riscv64 bindings next to every rolldown / lightningcss copy in an
# installed XO tree, as the optional packages their loaders ask for.
# Usage: install-bindings.sh <xo-tree> <bindings-dir>
set -euo pipefail
cd "$1"; b=$(realpath "$2")
mk() { # mk <pkgdir> <name> <version> <file-in-b> <file-name>
  mkdir -p "$1"; cp "$b/$4" "$1/$5"
  printf '{"name":"%s","version":"%s","main":"%s","os":["linux"],"cpu":["riscv64"],"libc":["glibc"]}\n' \
    "$2" "$3" "$5" > "$1/package.json"; echo "installed $2@$3 in $1"; }
while read -r d; do
  v=$(node -p "require('./$d/package.json').version"); base=$(dirname "$d")
  mk "$base/@rolldown/binding-linux-riscv64-gnu" @rolldown/binding-linux-riscv64-gnu "$v" \
    "rolldown-binding.linux-riscv64-gnu-$v.node" rolldown-binding.linux-riscv64-gnu.node
done < <(find node_modules -path '*/rolldown/package.json' -not -path '*/@rolldown/*' -printf '%h\n')
while read -r d; do
  v=$(node -p "require('./$d/package.json').version"); base=$(dirname "$d")
  mk "$base/lightningcss-linux-riscv64-gnu" lightningcss-linux-riscv64-gnu "$v" \
    "lightningcss.linux-riscv64-gnu-$v.node" lightningcss.linux-riscv64-gnu.node
done < <(find node_modules -path '*/lightningcss/package.json' -printf '%h\n')
node -e "require('rolldown'); require('lightningcss'); console.log('bindings load')"
