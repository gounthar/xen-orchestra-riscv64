#!/usr/bin/env bash
# Start the packaged tree the way a user would and check it serves both UIs after login.
# Needs redis-server installed. Usage: smoke-test.sh <tarball>
set -euo pipefail
tarball=$(realpath "$1"); work=$(mktemp -d); cd "$work"
zstd -dc "$tarball" | tar -xf -
root=$(realpath -- */)
bad=$(find "$root" -xtype l | wc -l); echo "broken symlinks: $bad"; [ "$bad" = 0 ]
redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes --port 6379
mkdir -p "$work/home/.config/xo-server" "$work/data" "$work/mounts"
printf 'datadir = "%s/data"\n\n[[http.listen]]\nport = 8088\n\n[remoteOptions]\nmountsDir = "%s/mounts"\n' \
  "$work" "$work" > "$work/home/.config/xo-server/config.toml"
( cd "$root/packages/xo-server" && HOME=$work/home nohup node dist/cli.mjs > "$work/xo-server.log" 2>&1 & echo $! > "$work/pid" )
up=
for _ in $(seq 1 120); do
  sleep 5
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/signin || true)" = 200 ] && { up=1; break; }
done
stop() { kill "$(cat "$work/pid")" 2>/dev/null || true; }
[ -n "$up" ] || { echo "xo-server did not come up"; tail -40 "$work/xo-server.log"; stop; exit 1; }
jar=$work/cookies
curl -s -c "$jar" -b "$jar" -o /dev/null -d 'username=admin%40admin.net&password=admin' http://127.0.0.1:8088/signin/local
check() { # check <path> <min-bytes>
  local out; out=$(curl -s -b "$jar" -o "$work/body" -w '%{http_code} %{size_download}' "http://127.0.0.1:8088$1")
  echo "$1 -> $out"
  if [ "${out% *}" = 200 ] && [ "${out#* }" -ge "$2" ]; then return 0; fi
  echo "--- body:"; head -c 400 "$work/body"; echo; return 1; }
ok=0
check /v5/ 500 && check /v5/index.js 1000000 && check /v6/ 500 && ok=1
grep -c 'failed register' "$work/xo-server.log" | sed 's/^/plugins failing to register: /' || true
stop
cp "$work/xo-server.log" "${SMOKE_LOG:-/dev/null}" 2>/dev/null || true
if [ "$ok" != 1 ]; then
  echo "--- mounts and errors from the xo-server log:"
  grep -a -E 'Setting up|listening|signin|error' "$work/xo-server.log" | grep -v '^\s*at ' | head -40
  exit 1
fi
