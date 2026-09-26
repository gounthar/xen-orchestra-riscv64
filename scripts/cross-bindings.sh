#!/usr/bin/env bash
# Cross-compile the riscv64 napi bindings XO needs but npm does not ship, at the exact
# versions an XO lockfile resolves. Runs on an x86 ubuntu-24.04 runner (or in ubuntu:24.04).
# Usage: cross-bindings.sh <yarn.lock> <outdir>
set -euo pipefail
lock=$1; out=$(realpath -m "$2"); mkdir -p "$out"
here=$(dirname "$(realpath "$0")")
export CARGO_TARGET_RISCV64GC_UNKNOWN_LINUX_GNU_LINKER=riscv64-linux-gnu-gcc
export CC_riscv64gc_unknown_linux_gnu=riscv64-linux-gnu-gcc CXX_riscv64gc_unknown_linux_gnu=riscv64-linux-gnu-g++
work=${WORK:-$(mktemp -d)}
build() { # build <name> <version> <git-url> <tag> <crate> <lib> <out-file>
  local dest="$out/$7"
  if [ -s "$dest" ]; then echo "cached $7"; return; fi
  rm -rf "$work/$1-$2"; git clone -q --depth 1 -b "$4" "$3" "$work/$1-$2"
  ( cd "$work/$1-$2"
    rustup target add riscv64gc-unknown-linux-gnu >/dev/null
    time cargo build --release -p "$5" --target riscv64gc-unknown-linux-gnu )
  cp "$work/$1-$2/target/riscv64gc-unknown-linux-gnu/release/$6" "$dest"
  file "$dest"
}
for v in $("$here/lockfile-versions.sh" "$lock" rolldown); do
  build rolldown "$v" https://github.com/rolldown/rolldown.git "v$v" rolldown_binding \
    librolldown_binding.so "rolldown-binding.linux-riscv64-gnu-$v.node"
done
for v in $("$here/lockfile-versions.sh" "$lock" lightningcss); do
  build lightningcss "$v" https://github.com/parcel-bundler/lightningcss.git "v$v" lightningcss_node \
    liblightningcss_node.so "lightningcss.linux-riscv64-gnu-$v.node"
done
ls -l "$out"
