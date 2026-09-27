#!/usr/bin/env bash
# Print the names of the xo-server-* plugin workspaces (upstream's `yarn build` builds them
# with turbo --filter xo-server-'*'; without them xo-server logs "Cannot find module" per plugin).
# Usage (from the XO checkout): plugins.sh
set -euo pipefail
yarn --silent workspaces info --json | node -e '
  let s = ""; process.stdin.on("data", d => (s += d)).on("end", () => {
    const info = JSON.parse(s.slice(s.indexOf("{")))
    console.log(Object.keys(info).filter(n => n.startsWith("xo-server-")).sort().join(" "))
  })'
