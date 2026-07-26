#!/usr/bin/env node
// Configure this clone so PRs and pushes can only reach unicomultiplo/dawn.
//
// `upstream` (Shopify/dawn) must stay fetch-only — it exists to diff and replay
// Dawn releases, nothing more. Git and gh config live in .git/config, which is
// NOT committed, so every clone has to run this once. Runs from `npm install`
// via the prepare script.
//
// The committed PreToolUse hook in .claude/settings.json enforces the same rule
// for Claude Code sessions. This covers humans and other tools.

import { spawnSync } from 'node:child_process';

const run = (cmd, args) => spawnSync(cmd, args, { encoding: 'utf8' });
const ok = (r) => r.status === 0;

if (!ok(run('git', ['rev-parse', '--git-dir']))) process.exit(0); // not a clone (e.g. tarball)

const steps = [];

// 1. gh: pin the default repo so `gh pr create` can never resolve to upstream.
if (ok(run('sh', ['-c', 'command -v gh']))) {
  if (ok(run('gh', ['repo', 'set-default', 'unicomultiplo/dawn']))) {
    steps.push('gh default repo → unicomultiplo/dawn');
  }
} else {
  steps.push('gh not installed — skipped default-repo pin');
}

// 2. git: make the upstream remote fetch-only.
const remotes = run('git', ['remote']).stdout || '';
if (remotes.split('\n').includes('upstream')) {
  const DISABLED = 'DISABLED-upstream-is-fetch-only';
  const current = (run('git', ['remote', 'get-url', '--push', 'upstream']).stdout || '').trim();
  if (current !== DISABLED) {
    run('git', ['remote', 'set-url', '--push', 'upstream', DISABLED]);
    steps.push('upstream remote → fetch-only (push disabled)');
  }
}

if (steps.length) {
  console.log('Remote guards configured:');
  for (const s of steps) console.log(`  • ${s}`);
}
