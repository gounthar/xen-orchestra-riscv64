#!/usr/bin/env bash
# sha256 of every build output we cross-check between the native and the QEMU build:
# each workspace dist/ (xo-server and its dependencies) and the XO 6 UI. xo-web (XO 5) is
# left out: it only builds under QEMU. Paths are relative; output is sorted.
# Usage (from the XO checkout): manifest.sh > file
set -euo pipefail
find . -path ./node_modules -prune -o -path '*/node_modules' -prune -o -type d -name dist -print |
  grep -v '^\./packages/xo-web/dist$' | sort |
  while read -r d; do find "$d" -type f -print0 | sort -z | xargs -0 -r sha256sum; done
