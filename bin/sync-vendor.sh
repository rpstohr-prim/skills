#!/usr/bin/env bash
# Re-pull a vendored upstream skill collection at its current HEAD.
#
#   bin/sync-vendor.sh                            # sync every vendor/*
#   bin/sync-vendor.sh coreyhaines-marketingskills
#
# Each vendor/<name>/UPSTREAM.txt records repo=, commit=, date=, license=.
# This script replaces vendor/<name>/skills wholesale, so never hand-edit files
# in there — put your changes in mine/ instead (see README).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  for d in "$REPO"/vendor/*/; do targets+=("$(basename "$d")"); done
fi

for name in "${targets[@]}"; do
  vdir="$REPO/vendor/$name"
  [ -f "$vdir/UPSTREAM.txt" ] || { echo "no vendor/$name/UPSTREAM.txt" >&2; exit 1; }
  url="$(grep '^repo=' "$vdir/UPSTREAM.txt" | cut -d= -f2-)"
  old="$(grep '^commit=' "$vdir/UPSTREAM.txt" | cut -d= -f2-)"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  git clone --depth 1 -q "$url" "$tmp/src"
  new="$(git -C "$tmp/src" rev-parse HEAD)"

  if [ "$new" = "$old" ]; then echo "$name: already at $new"; continue; fi

  rm -rf "$vdir/skills"
  cp -R "$tmp/src/skills" "$vdir/skills"
  [ -f "$tmp/src/LICENSE" ] && cp "$tmp/src/LICENSE" "$vdir/LICENSE"
  [ -f "$tmp/src/README.md" ] && cp "$tmp/src/README.md" "$vdir/UPSTREAM-README.md"
  find "$vdir" -name '.DS_Store' -delete
  printf 'repo=%s\ncommit=%s\ndate=%s\nlicense=%s\n' \
    "$url" "$new" "$(git -C "$tmp/src" log -1 --format=%cs)" \
    "$(grep '^license=' "$vdir/UPSTREAM.txt" | cut -d= -f2-)" > "$vdir/UPSTREAM.txt"
  echo "$name: $old -> $new"
  rm -rf "$tmp"; trap - EXIT
done
