#!/usr/bin/env bash
set -euo pipefail

# Usage: sync-docs.sh [-c cache_dir] [--force]
# Downloads the Claude Code docs bundle (llms-full.txt) once and splits it into
# one Markdown file per page under the cache dir, plus an index.txt listing
# "<slug><TAB><title>" for every page. Re-running is a no-op unless --force.
#

# Cache dir precedence: -c/--cache, then $CLAUDE_DOCS_DIR, then the XDG cache.
# Plugin runs pass -c ${CLAUDE_PLUGIN_DATA}/docs, because Claude Code does not export
# CLAUDE_PLUGIN_DATA to the Bash tool; it only substitutes it into skill and command text.
CACHE="${CLAUDE_DOCS_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-code-docs}"
BASE="https://code.claude.com/docs/en/"
BUNDLE_URL="https://code.claude.com/docs/llms-full.txt"

force=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) force=1 ;;
        -c|--cache) CACHE="${2:?--cache needs a directory}"; shift ;;
        *) echo "usage: sync-docs.sh [-c cache_dir] [--force]" >&2; exit 2 ;;
    esac
    shift
done

if [[ $force -eq 0 && -f "$CACHE/index.txt" ]]; then
    echo "docs already cached at $CACHE (use --force to refresh)"
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "fetching $BUNDLE_URL"
curl -sfL "$BUNDLE_URL" -o "$tmp/llms-full.txt"

mkdir -p "$tmp/pages"
# Pages can sit in subdirectories (plugins/...), so create those first.
sed -n 's#^Source: https://code\.claude\.com/docs/en/##p' "$tmp/llms-full.txt" \
    | while IFS= read -r slug; do mkdir -p "$(dirname "$tmp/pages/$slug.md")"; done

awk -v dir="$tmp/pages" -v base="$BASE" -v indexfile="$tmp/index.txt" '
    # Each page is "# Title" immediately followed by "Source: <url>". The title
    # line is held back one line so it can be written to the new page file.
    BEGIN { havepending = 0; out = "" }
    index($0, "Source: " base) == 1 {
        if (out != "") close(out)
        slug = substr($0, length("Source: " base) + 1)
        out = dir "/" slug ".md"
        title = havepending ? pending : slug
        sub(/^# /, "", title)
        print slug "\t" title >> indexfile
        if (havepending) print pending > out
        print $0 > out
        havepending = 0
        next
    }
    {
        if (out != "" && havepending) print pending > out
        pending = $0
        havepending = 1
    }
    END {
        if (out != "" && havepending) print pending > out
        if (out != "") close(out)
    }
' "$tmp/llms-full.txt"

pages=$(find "$tmp/pages" -name '*.md' | wc -l)
if [[ "$pages" -eq 0 ]]; then
    echo "error: no pages found in bundle" >&2
    exit 1
fi

# Swap in the new copy in one step so a failed run never leaves a half cache.
mkdir -p "$(dirname "$CACHE")"
rm -rf "$CACHE"
mkdir -p "$CACHE"
cp -r "$tmp/pages/." "$CACHE/"
mv "$tmp/index.txt" "$CACHE/index.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$CACHE/synced-at.txt"

echo "synced $pages pages to $CACHE"
