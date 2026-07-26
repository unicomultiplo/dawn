#!/usr/bin/env bash
# Stop hook: nudge the agent to fold what it learned back into the docs.
#
# Fires at most ONCE per session, and only when theme files changed while
# AGENTS.md / CLAUDE.md / docs/ did not. Staying quiet is the common case.
#
# See AGENTS.md § "Keeping the docs alive".

set -uo pipefail

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)

sentinel="${TMPDIR:-/tmp}/claude-uem-docs-reminder-${session_id}"
[ -e "$sentinel" ] && exit 0

repo=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo" || exit 0

changed=$(git status --porcelain 2>/dev/null) || exit 0
[ -z "$changed" ] && exit 0

paths=$(printf '%s\n' "$changed" | awk '{ $1=""; sub(/^ +/,""); print }')

theme_changed=$(printf '%s\n' "$paths" \
  | grep -Eq '^(assets|sections|snippets|layout|blocks|templates|config|locales|scripts)/|^(package\.json|shopify\.theme\.toml|\.theme-check\.yml)$' \
  && echo yes || echo no)

docs_changed=$(printf '%s\n' "$paths" \
  | grep -Eq '^(docs/|AGENTS\.md|CLAUDE\.md)' \
  && echo yes || echo no)

[ "$theme_changed" = "yes" ] && [ "$docs_changed" = "no" ] || exit 0

: > "$sentinel"

cat <<'JSON'
{
  "decision": "block",
  "reason": "Docs check (fires once per session; theme files changed, docs did not).\n\nDid this session turn up anything durable — a better way to preview or debug something, a documented command or path that was wrong, an undocumented convention or constraint, a new piece of drift?\n\nIf yes: update docs/PREVIEW.md, docs/ARCHITECTURE.md, or AGENTS.md per the protocol in AGENTS.md, then finish.\n\nIf no — which is the common case for routine edits — say so in one line and stop. Do not invent a doc change to satisfy this check."
}
JSON
