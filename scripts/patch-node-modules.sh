#!/usr/bin/env bash
# Run after install, in both builds. Makes index-modules 0.4.3 deterministic, so the native
# and QEMU builds can be compared byte for byte.
#
# xo-server's build generates src/api/index.mjs, src/xapi/mixins/index.mjs and
# src/xo-mixins/index.mjs with index-modules, which lists modules in fs.readdir order (it
# depends on the filesystem: ext4 switches to hash order in larger directories) and adds each
# one only after an async stat() resolves (so it also depends on I/O timing). Run 36287100095:
# api/index.mjs and xo-mixins/index.mjs differed between the RISE runner and QEMU while every
# other file matched. Here readdir is sorted and that stat made synchronous, so modules are
# added in name order. Only the import order in those generated files changes.
# Fails if the upstream code changed, so the patch cannot go stale silently.
# Usage (from the XO checkout, after install): patch-node-modules.sh
set -euo pipefail
f=node_modules/index-modules/index.js
grep -q '"version": "0.4.3"' node_modules/index-modules/package.json || { echo "index-modules is not 0.4.3" >&2; exit 1; }
[ "$(grep -c 'const entries = yield readdir(dir);' "$f")" = 2 ] || { echo "patch-node-modules: readdir lines changed" >&2; exit 1; }
[ "$(grep -c 'const stats = yield stat(join(dir, entry));' "$f")" = 1 ] || { echo "patch-node-modules: stat line changed" >&2; exit 1; }
sed -i 's/const entries = yield readdir(dir);/const entries = (yield readdir(dir)).sort();/' "$f"
sed -i 's/const stats = yield stat(join(dir, entry));/const stats = require("fs").statSync(join(dir, entry));/' "$f"
grep -n 'readdir(dir)).sort()\|statSync' "$f"
