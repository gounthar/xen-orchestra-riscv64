#!/usr/bin/env bash
# The only source change made to upstream XO for riscv64. Fails if upstream moved on, so a
# stale patch is noticed rather than silently skipped.
#
# fuse-native 2.2.6 (last published 2022) links a prebuilt x86-64 libfuse.so from
# fuse-shared-library-linux, so it cannot build on riscv64 (nor arm64). @cocalc/fuse-native
# 2.4.3 is a maintained fork that builds against the system libfuse through pkg-config; it
# is aliased under the same name, so code requiring 'fuse-native' is unchanged.
# Usage (from the XO checkout): patch-source.sh
set -euo pipefail
f=@vates/fuse-vhd/package.json
grep -q '"fuse-native": "\^2\.2\.6"' "$f" || { echo "patch-source: fuse-native line changed in $f" >&2; exit 1; }
sed -i 's#"fuse-native": "\^2\.2\.6"#"fuse-native": "npm:@cocalc/fuse-native@^2.4.3"#' "$f"
grep -n fuse-native "$f"
