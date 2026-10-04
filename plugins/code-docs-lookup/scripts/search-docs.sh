#!/usr/bin/env bash
set -euo pipefail

# Usage: search-docs.sh [-c cache_dir] [-n max_pages] [-r] <term> [more terms...]
# Lists cached Claude Code doc pages containing every term (case-insensitive),
# with the title and the first matching lines. Terms are fixed strings unless
# -r is given, in which case each term is an extended regex.
# Read a match in full with show-doc.sh <slug>.
# Run sync-docs.sh first (done automatically when the cache is empty).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Cache dir precedence: -c/--cache, then $CLAUDE_DOCS_DIR, then the XDG cache.
# Plugin runs pass -c ${CLAUDE_PLUGIN_DATA}/docs, because Claude Code does not export
# CLAUDE_PLUGIN_DATA to the Bash tool; it only substitutes it into skill and command text.
CACHE="${CLAUDE_DOCS_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-code-docs}"

max_pages=8
mode=F
while getopts ":c:n:r" opt; do
    case $opt in
        c) CACHE="$OPTARG" ;;
        n) max_pages="$OPTARG" ;;
        r) mode=E ;;
        *) echo "usage: search-docs.sh [-c cache_dir] [-n max_pages] [-r] <term> [more terms...]" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -eq 0 ]]; then
    echo "usage: search-docs.sh [-n max_pages] [-r] <term> [more terms...]" >&2
    exit 2
fi

if [[ ! -f "$CACHE/index.txt" ]]; then
    "$SCRIPT_DIR/sync-docs.sh" -c "$CACHE"
fi

# Keep only pages that match every term.
files=$(grep -rl --include='*.md' -i -$mode -- "$1" "$CACHE" || true)
shift_terms=("${@:2}")
for term in "${shift_terms[@]}"; do
    files=$(printf '%s\n' "$files" | xargs -r grep -li -$mode -- "$term" || true)
done

if [[ -z "$files" ]]; then
    echo "no matches in Claude Code docs for: $*"
    exit 0
fi

count=$(printf '%s\n' "$files" | wc -l)
echo "$count page(s) matched (showing up to $max_pages)"
echo

printf '%s\n' "$files" | sort | head -n "$max_pages" | while read -r file; do
    slug="${file#"$CACHE"/}"
    slug="${slug%.md}"
    title=$(awk -F'\t' -v s="$slug" '$1 == s { print $2; exit }' "$CACHE/index.txt")
    echo "== ${title:-$slug}"
    echo "   slug:   $slug"
    echo "   source: https://code.claude.com/docs/en/$slug"
    grep -in -m 3 -$mode -- "$1" "$file" | sed 's/^/   /' || true
    echo
done
