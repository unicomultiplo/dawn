#!/usr/bin/env bash
# PreToolUse(Bash) guard: never open a PR or push against Shopify/dawn.
#
# This repo is a fork. `upstream` points at Shopify/dawn and must stay
# fetch-only — it exists so we can diff and replay Dawn releases, nothing more.
# On 2026-07-26 a PR was opened against Shopify/dawn by accident because `gh`
# had no default repo and resolved to upstream. This makes that impossible.
#
# Denies:  gh pr/issue create (and other writes) aimed at Shopify/dawn
#          gh pr create without an explicit --repo unicomultiplo/dawn
#          git push to upstream / any Shopify remote
# Allows:  git fetch upstream, git merge upstream/*, git log upstream/*,
#          gh pr view|list|checks --repo Shopify/dawn  (read-only)
#
# Regression tests:  bash .claude/hooks/guard-upstream.test.sh
# Run them after ANY change here — the allow cases matter as much as the denies.

set -uo pipefail

cmd=$(cat | jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# Strip heredoc BODIES before matching. Otherwise a commit message that merely
# quotes a blocked command (`git push upstream`) is read as the command itself —
# which blocked a real commit on 2026-07-26.
stripped=$(printf '%s\n' "$cmd" | awk '
  skip { if ($0 == mark) skip = 0; next }
  {
    print
    if (match($0, /<<-?[[:space:]]*['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?/)) {
      m = substr($0, RSTART, RLENGTH)
      sub(/^<<-?[[:space:]]*/, "", m)
      gsub(/['"'"'"]/, "", m)
      mark = m; skip = 1
    }
  }
')

# Normalise whitespace for matching.
c=$(printf '%s' "$stripped" | tr '\n' ' ' | tr -s ' ')

upstream_slug='[Ss]hopify/dawn'

# 1. Any gh write verb aimed at Shopify/dawn.
if printf '%s' "$c" | grep -Eq "gh (pr|issue|release|api)\b" \
   && printf '%s' "$c" | grep -Eq "$upstream_slug" \
   && printf '%s' "$c" | grep -Eqv "gh (pr|issue) (view|list|checks|diff|status)\b"; then
  deny "Blocked: this command targets Shopify/dawn, the public upstream Dawn repo.

This repo is a FORK. PRs and issues belong on unicomultiplo/dawn only.
\`upstream\` exists solely to fetch and diff Dawn releases.

Use: gh pr create --repo unicomultiplo/dawn --base main ...
Read-only queries against upstream (gh pr view/list/checks) are allowed."
fi

# 2. gh pr create without an explicit correct --repo. `gh` resolves an ambiguous
#    default to whichever remote it likes; being explicit is the whole fix.
if printf '%s' "$c" | grep -Eq 'gh pr create\b' \
   && ! printf '%s' "$c" | grep -Eq '(--repo[= ]+|-R )unicomultiplo/dawn\b'; then
  deny "Blocked: \`gh pr create\` without an explicit --repo.

This repo has two remotes (origin=unicomultiplo/dawn, upstream=Shopify/dawn).
Without --repo, gh can resolve to the public upstream — which has happened.

Re-run with: gh pr create --repo unicomultiplo/dawn --base main --head <branch> ..."
fi

# 3. git push anywhere near upstream / Shopify.
if printf '%s' "$c" | grep -Eq 'git +push\b' \
   && printf '%s' "$c" | grep -Eq "(\bupstream\b|$upstream_slug)"; then
  deny "Blocked: never push to \`upstream\` (Shopify/dawn).

Push to origin instead:  git push -u origin <branch>"
fi

exit 0
