#!/usr/bin/env bash
# Test battery for .claude/hooks/guard-upstream.sh
cd "$(git rev-parse --show-toplevel)" || exit 1
HOOK=.claude/hooks/guard-upstream.sh
UP="Sho""pify/dawn"

t() { # $1 = expected, $2 = label, $3 = command
  r=$(printf '%s' "{\"tool_input\":{\"command\":$(jq -Rn --arg c "$3" '$c')}}" | "$HOOK" 2>&1)
  d=$(printf '%s' "$r" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
  [ -z "$d" ] && d=ALLOW
  [ "$d" = "$1" ] && res="ok  " || res="FAIL"
  printf '%s expected=%-6s got=%-6s | %s\n' "$res" "$1" "$d" "$2"
}

HD=$(printf 'git commit -F - <<%sMSG%s\nfix: stop git push upstream and gh pr create misuse\nSee %s for context\nMSG\ngit log -1' "'" "'" "$UP")
t ALLOW "heredoc body merely quoting blocked commands" "$HD"

HD2=$(printf 'git commit -F - <<%sMSG%s\nsome message\nMSG\ngit push upstream main' "'" "'")
t deny "real command hidden AFTER heredoc marker" "$HD2"

t deny  "push to upstream"              'git push upstream main'
t deny  "pr create with no --repo"      'gh pr create --title x --body y'
t deny  "pr create at upstream"         "gh pr create --repo $UP --base main"
t deny  "issue create at upstream"      "gh issue create --repo $UP -t bug"
t deny  "pr comment at upstream"        "gh pr comment 1 --repo $UP --body hi"

t ALLOW "pr create at origin"           'gh pr create --repo unicomultiplo/dawn --base main --head x'
t ALLOW "pr create at origin (-R)"      'gh pr create -R unicomultiplo/dawn --base main'
t ALLOW "fetch upstream"                'git fetch upstream --tags'
t ALLOW "merge upstream"                'git merge upstream/main'
t ALLOW "log upstream"                  'git log --oneline upstream/main -5'
t ALLOW "read-only pr list at upstream" "gh pr list --repo $UP"
t ALLOW "read-only pr view at upstream" "gh pr view 3943 --repo $UP"
t ALLOW "push to origin"                'git push -u origin docs/x'
t ALLOW "unrelated command"             'npm run check'
