#!/usr/bin/env bash
set -euo pipefail

# Usage: claude-code-documentation.sh [savePath]
# Fetches the Claude Code docs llms-full.txt, derives the page list from its
# `Source: <url>` lines, downloads each page's .md, and builds an OVERVIEW.md
# index (h1 + h2 headings + first code-block line per page).

DIR="${1:-/tmp/claude-code-docs/}"
mkdir -p "$DIR"

LLMS_FULL_URL="https://code.claude.com/docs/llms-full.txt"
LLMS_FULL_FILE="$DIR/llms-full.txt"
OVERVIEW_FILE="$DIR/OVERVIEW.md"

echo "fetching $LLMS_FULL_URL"
curl -sL "$LLMS_FULL_URL" -o "$LLMS_FULL_FILE"

# Extract page slugs from "Source: https://code.claude.com/docs/en/<slug>" lines.
mapfile -t pages < <(
    sed -n 's#^Source: https://code\.claude\.com/docs/en/\(.*\)$#\1#p' "$LLMS_FULL_FILE" \
        | sort -u
)

echo "found ${#pages[@]} pages"

extract_overview() {
    local slug="$1" file="$2" h1 h2 first_code

    # grep exits 1 on no match; with pipefail that would kill the script, so
    # guard each pipeline explicitly (headings are optional per page).
    h1=$(grep -m1 '^# ' "$file" | sed 's/^# //') || true
    h2=$(grep '^## ' "$file" | sed 's/^## //') || true
    first_code=$(awk '
        /^```/ {
            depth++
            if (depth == 1) { infence = 1; first = 1; next }
            if (depth == 2) { exit }
        }
        infence && first { print; first = 0 }
    ' "$file") || true

    {
        echo "## ${h1:-$slug}"
        echo "_source: https://code.claude.com/docs/en/${slug}_"
        echo
        if [[ -n "$h2" ]]; then
            while IFS= read -r line; do
                echo "- $line"
            done <<<"$h2"
            echo
        fi
        if [[ -n "$first_code" ]]; then
            echo '```'
            echo "$first_code"
            echo '```'
            echo
        fi
    } >>"$OVERVIEW_FILE"
}

: >"$OVERVIEW_FILE"
echo "# Claude Code Documentation Overview" >>"$OVERVIEW_FILE"
echo >>"$OVERVIEW_FILE"

for page in "${pages[@]}"; do
    echo "$page"
    dest="$DIR/$page.md"
    mkdir -p "$(dirname "$dest")"
    if curl -sL --fail "https://code.claude.com/docs/en/${page}.md" -o "$dest"; then
        extract_overview "$page" "$dest"
    else
        echo "  failed: $page" >&2
        rm -f "$dest"
    fi
done

echo "docs saved to $DIR"
echo "overview written to $OVERVIEW_FILE"
