#!/usr/bin/env bash
# Print "<version> <sha>" of the newest upstream XO release. Upstream has no tags for XO
# releases; each one is a "feat: release X.Y[.Z]" commit on vatesfr/xen-orchestra master.
set -euo pipefail
repo=${UPSTREAM_REPO:-https://github.com/vatesfr/xen-orchestra.git}
tmp=$(mktemp -d)
git clone -q --filter=blob:none --no-checkout --single-branch -b master "$repo" "$tmp"
line=$(git -C "$tmp" log -1 -E --grep='^feat: release [0-9]+\.[0-9]+(\.[0-9]+)?( |$)' --format='%H %s')
sha=${line%% *}
version=$(sed -E 's/^[0-9a-f]+ feat: release ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/' <<<"$line")
[[ $version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { echo "cannot parse: $line" >&2; exit 1; }
echo "$version $sha"
