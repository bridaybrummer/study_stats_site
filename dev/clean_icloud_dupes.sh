#!/bin/bash
# clean_icloud_dupes.sh
# Remove iCloud / Finder sync-conflict duplicates: files and folders whose
# basename ends with " 2", " 3", ... (e.g. "index 2.qmd", "site_libs 2/").
#
# Usage:
#   ./dev/clean_icloud_dupes.sh             # dry run (default)
#   ./dev/clean_icloud_dupes.sh --apply     # actually delete
#   ./dev/clean_icloud_dupes.sh --apply --include-site   # also clean _site/
#
# Excludes by default: .git, .venv, node_modules, .quarto, _site, _freeze.

set -e

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'; NC=$'\033[0m'

APPLY=0
INCLUDE_SITE=0
for arg in "$@"; do
  case "$arg" in
    --apply)        APPLY=1 ;;
    --include-site) INCLUDE_SITE=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $arg"; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Build prune list. .git and the source-tree caches always.
PRUNE=( -path './.git' -o -path './.venv' -o -path './node_modules' \
        -o -path './.quarto' -o -path './_freeze' )
if [ "$INCLUDE_SITE" -eq 0 ]; then
  PRUNE+=( -o -path './_site' )
fi

# Match: basename = "<anything> <digit(s)>" optionally followed by ".ext".
# Examples matched: "index 2.qmd", "styles 3.css", "site_libs 2", "image 10.png"
# NOT matched:      "Section 2 Notes.md" (digit not at end of basename)
# Using -E (extended regex): parens group, no backslashes needed.
FIND_EXPR=( \( "${PRUNE[@]}" \) -prune -false -o \
            \( -regex '.*/[^/]+ [0-9]+(\.[^/]+)?' \) -print )

# macOS find is BSD; -regex is POSIX basic. Use -E for extended.
# bash 3.2 (macOS default) has no mapfile; read into an array manually.
HITS=()
while IFS= read -r line; do
  HITS+=("$line")
done < <(find -E . "${FIND_EXPR[@]}" 2>/dev/null | sort)

if [ "${#HITS[@]}" -eq 0 ]; then
  echo "${GREEN}No iCloud / Finder duplicate files found.${NC}"
  exit 0
fi

echo "${BLUE}Found ${#HITS[@]} duplicate path(s):${NC}"
printf '  %s\n' "${HITS[@]}"

if [ "$APPLY" -eq 0 ]; then
  echo
  echo "${YELLOW}Dry run.${NC} Re-run with ${GREEN}--apply${NC} to delete."
  echo "Add ${GREEN}--include-site${NC} to also clean _site/."
  exit 0
fi

echo
echo "${RED}Deleting...${NC}"
for p in "${HITS[@]}"; do
  rm -rf -- "$p"
  echo "  removed $p"
done
echo "${GREEN}Done. ${#HITS[@]} path(s) removed.${NC}"
