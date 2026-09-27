#!/usr/bin/env bash
# Start the packaged tree the way a user would and check it serves both UIs after login.
# Up to 3 attempts, each with a fresh data dir: Node on riscv64 hardware also corrupts its heap
# at runtime now and then (run 36305144430: node-openssl-cert crashed during startup with
# "Received type number (63)" and the UIs were never mounted). One clean start is enough to
# prove the package itself is sound, which is what this test is for.
# Needs redis-server installed. Usage: smoke-test.sh <tarball>
set -euo pipefail
tarball=$(realpath "$1"); work=$(mktemp -d); cd "$work"
zstd -dc "$tarball" | tar -xf -
root=$(realpath -- */)
bad=$(find "$root" -xtype l | wc -l); echo "broken symlinks: $bad"; [ "$bad" = 0 ]
redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes --port 6379

attempt() { # attempt <n>; returns 0 if both UIs are served after login
  local n=$1 d=$work/run$1 pid up= jar
  mkdir -p "$d/home/.config/xo-server" "$d/data" "$d/mounts"
  redis-cli flushall >/dev/null
  printf 'datadir = "%s/data"\n\n[[http.listen]]\nport = 8088\n\n[remoteOptions]\nmountsDir = "%s/mounts"\n' \
    "$d" "$d" > "$d/home/.config/xo-server/config.toml"
  ( cd "$root/packages/xo-server" && HOME=$d/home exec node dist/cli.mjs ) > "$d/xo-server.log" 2>&1 &
  pid=$!
  # /signin answers early; the UI mounts come only after every plugin has registered.
  for _ in $(seq 1 120); do
    grep -q 'Setting up /v6' "$d/xo-server.log" && { up=1; break; }
    kill -0 "$pid" 2>/dev/null || break
    sleep 5
  done
  ok=0
  if [ -n "$up" ]; then
    jar=$d/cookies
    curl -s -c "$jar" -b "$jar" -o /dev/null -d 'username=admin%40admin.net&password=admin' \
      http://127.0.0.1:8088/signin/local
    check() { local out
      out=$(curl -s -b "$jar" -o "$d/body" -w '%{http_code} %{size_download}' "http://127.0.0.1:8088$1")
      echo "attempt $n: $1 -> $out"; [ "${out% *}" = 200 ] && [ "${out#* }" -ge "$2" ]; }
    check /v5/ 500 && check /v5/index.js 1000000 && check /v6/ 500 && ok=1
  else
    echo "attempt $n: UI mounts never set up"
  fi
  echo "attempt $n: plugins failing to register: $(grep -c 'failed register' "$d/xo-server.log" || true)"
  grep -a -E 'uncaught exception|unhandled rejection' -A2 "$d/xo-server.log" | grep -a -E 'Error|exception|rejection' \
    | cut -c1-200 | head -6 | sed "s/^/attempt $n: /" || true
  kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
  [ -n "${SMOKE_LOG:-}" ] && cat "$d/xo-server.log" >> "$SMOKE_LOG" || true
  [ "$ok" = 1 ]
}
for n in 1 2 3; do
  if attempt "$n"; then echo "smoke test passed on attempt $n"; exit 0; fi
  sleep 5
done
echo "smoke test failed 3 times"; exit 1
