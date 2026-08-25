#!/usr/bin/env bash
# Symlink every skill in this repo into a Claude Code skills directory.
#
#   bin/install-skills.sh                  # -> ~/.claude/skills (all sources)
#   bin/install-skills.sh --only mine      # just my own skills
#   bin/install-skills.sh --target ./.claude/skills   # install into a project
#   bin/install-skills.sh --copy           # copy instead of symlink
#   bin/install-skills.sh --dry-run
#
# Skills are discovered as any directory containing a SKILL.md, under:
#   mine/<skill>/SKILL.md
#   vendor/<upstream>/skills/<skill>/SKILL.md
# They install FLAT (~/.claude/skills/<skill>) because that is the only layout
# Claude Code discovers.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$HOME/.claude/skills"
ONLY=""
MODE="link"
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --only)   ONLY="$2"; shift 2 ;;
    --copy)   MODE="copy"; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

roots=()
if [ -z "$ONLY" ] || [ "$ONLY" = "mine" ]; then roots+=("$REPO/mine"); fi
if [ -z "$ONLY" ] || [ "$ONLY" = "vendor" ]; then
  for v in "$REPO"/vendor/*/skills; do [ -d "$v" ] && roots+=("$v"); done
fi

installed=0
skipped=0
for root in "${roots[@]}"; do
  [ -d "$root" ] || continue
  for dir in "$root"/*/; do
    [ -f "${dir}SKILL.md" ] || continue
    name="$(basename "$dir")"
    dest="$TARGET/$name"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
      # Ours already? replace. Someone else's? leave it alone and warn.
      if [ -L "$dest" ] && [[ "$(readlink "$dest")" == "$REPO"/* ]]; then
        [ "$DRY" = 1 ] || rm -f "$dest"
      else
        echo "skip  $name (already exists at $dest and is not from this repo)"
        skipped=$((skipped + 1))
        continue
      fi
    fi

    if [ "$DRY" = 1 ]; then
      echo "would install $name  <- ${dir%/}"
    elif [ "$MODE" = "copy" ]; then
      rm -rf "$dest"; cp -R "${dir%/}" "$dest"
    else
      ln -s "${dir%/}" "$dest"
    fi
    installed=$((installed + 1))
  done
done

echo "$installed skill(s) installed into $TARGET ($MODE), $skipped skipped"
