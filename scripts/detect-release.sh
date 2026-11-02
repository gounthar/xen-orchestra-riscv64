#!/usr/bin/env bash
# Print "<version> <sha> <subject-version>" for an upstream XO release.
#
# Usage: detect-release.sh [X.Y[.Z]]
#   no argument: the newest release
#   a version:   the newest release commit whose CHANGELOG.md says that version
#
# Upstream has no tags for XO releases; each one is a "feat: release X.Y[.Z]" commit on
# vatesfr/xen-orchestra master. The commit subject finds the commit, but the version comes
# from the first "## **X.Y.Z**" heading of CHANGELOG.md at that commit: the subject is typed
# by hand and has been wrong ("feat: release 9.10.0" for 6.10.0, #10689). The third field is
# the version the subject claims, so the caller can warn when the two differ.
set -euo pipefail

for cmd in git sed grep; do
  command -v "$cmd" >/dev/null || {
    echo "Error: $cmd is required. Install with: sudo apt-get install $cmd" >&2
    exit 1
  }
done

want=${1:-}
repo=${UPSTREAM_REPO:-https://github.com/vatesfr/xen-orchestra.git}
# How many release commits a version search looks through, newest first
depth=${SEARCH_DEPTH:-60}

ver_re='[0-9]+\.[0-9]+(\.[0-9]+)?'
[[ -z $want || $want =~ ^$ver_re$ ]] || {
  echo "not a version: $want" >&2
  exit 1
}

# X.Y and X.Y.0 are the same release ("feat: release 6.8" shipped 6.8.0)
norm() { [[ $1 =~ ^[0-9]+\.[0-9]+$ ]] && echo "$1.0" || echo "$1"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone -q --filter=blob:none --no-checkout --single-branch -b master "$repo" "$tmp"

# Version from CHANGELOG.md at a commit; empty when the heading is not a version
# (a premature release commit had "## **next**"). Tolerates "**6.2.2 **".
# Read the whole file before parsing: `git show | grep -m1` dies of SIGPIPE under pipefail.
changelog_version() {
  local log heading
  # A failed read (network, missing file) stops the script: skipping to an older commit
  # would turn a fetch error into "no such release", or pick an older match.
  log=$(git -C "$tmp" show "$1:CHANGELOG.md" 2>&1 </dev/null) || {
    echo "cannot read CHANGELOG.md at $1: $log" >&2
    return 1
  }
  heading=$(grep -m1 -E '^## ' <<<"$log") || return 0
  sed -nE "s/^## \*\*[[:space:]]*($ver_re)[[:space:]]*\*\*.*/\1/p" <<<"$heading"
}

# List first, then loop: breaking out of `while read < <(git log)` leaves git log writing
# into a closed pipe, and a lazy blob fetch inside the loop could read the loop's stdin.
mapfile -t releases < <(git -C "$tmp" log -"$depth" -E --grep="^feat: release $ver_re( |\$)" --format='%H %s')
[[ ${#releases[@]} -gt 0 ]] || { echo "no release commits found" >&2; exit 1; }

found=false
for line in "${releases[@]}"; do
  sha=${line%% *}
  subject=${line#* }
  subject_version=$(sed -nE "s/^feat: release ($ver_re)( .*)?$/\1/p" <<<"$subject")
  # --grep also matches body lines; only a release subject marks a release commit
  [[ -n $subject_version ]] || continue
  version=$(changelog_version "$sha")
  if [[ -z $want ]]; then
    # The newest release commit decides; never fall back to an older one silently
    [[ -n $version ]] || {
      echo "cannot read a version from CHANGELOG.md at $sha" >&2
      exit 1
    }
    found=true
    break
  fi
  if [[ -n $version && $(norm "$version") == "$(norm "$want")" ]]; then
    found=true
    break
  fi
done

$found || {
  echo "no release commit with CHANGELOG.md version ${want:-<any>}" >&2
  exit 1
}
echo "$(norm "$version") $sha $(norm "$subject_version")"
