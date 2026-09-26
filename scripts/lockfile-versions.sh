#!/usr/bin/env bash
# Print the resolved versions of a package in a yarn v1 lockfile, one per line.
# Usage: lockfile-versions.sh <yarn.lock> <package-name>
set -euo pipefail
awk -v pkg="$2" '
  /^[^ ]/ { inpkg = 0; n = split($0, keys, ", ")
            for (i = 1; i <= n; i++) { k = keys[i]; gsub(/^"|"?:?$/, "", k); sub(/@[^@]*$/, "", k)
                                       if (k == pkg) inpkg = 1 } }
  inpkg && /^  version / { gsub(/"/, "", $2); print $2; inpkg = 0 }
' "$1" | sort -uV
