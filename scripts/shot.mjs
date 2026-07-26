#!/usr/bin/env node
// Screenshot a storefront page for visual review.
//
//   npm run shot -- /products/doiy-sweetie-mug
//   npm run shot -- / --mobile --full
//   npm run shot -- /collections/seletti --live
//
// Wraps agent-browser with the settings this store needs every time: a named
// session (so the cookie banner stays dismissed), a fixed viewport, and a wait
// for the page to settle. Prints the PNG path and any console errors.
//
// See docs/PREVIEW.md.

import { spawnSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const BIN = resolve(ROOT, 'node_modules/.bin/agent-browser');
const SESSION = 'uem';

const LOCAL_BASE = 'http://127.0.0.1:9292';
const LIVE_BASE = 'https://unicoemultiplo.com';

const VIEWPORTS = {
  desktop: [1440, 900],
  tablet: [820, 1180],
  mobile: [390, 844],
};

const argv = process.argv.slice(2);
const flags = new Set(argv.filter((a) => a.startsWith('--')));
const positional = argv.filter((a) => !a.startsWith('--'));

const outFlagIndex = argv.indexOf('--out');
const explicitOut = outFlagIndex !== -1 ? argv[outFlagIndex + 1] : null;

if (positional.length === 0) {
  console.error('usage: npm run shot -- <path-or-url> [--mobile|--tablet] [--full] [--dark] [--live] [--out file.png]');
  process.exit(1);
}

const target = positional[0];
const base = flags.has('--live') ? LIVE_BASE : LOCAL_BASE;
const url = /^https?:\/\//.test(target) ? target : base + (target.startsWith('/') ? target : `/${target}`);

const size = flags.has('--mobile')
  ? VIEWPORTS.mobile
  : flags.has('--tablet')
    ? VIEWPORTS.tablet
    : VIEWPORTS.desktop;

const slug =
  (target.replace(/^https?:\/\/[^/]+/, '').replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '') || 'home') +
  (flags.has('--mobile') ? '-mobile' : flags.has('--tablet') ? '-tablet' : '') +
  (flags.has('--dark') ? '-dark' : '');

const out = explicitOut ? resolve(explicitOut) : resolve(ROOT, '.screenshots', `${slug}.png`);
mkdirSync(dirname(out), { recursive: true });

/** Run agent-browser; returns {status, stdout, stderr}. Never throws. */
function ab(args, { quiet = true } = {}) {
  const res = spawnSync(BIN, ['--session-name', SESSION, ...args], {
    encoding: 'utf8',
    stdio: quiet ? 'pipe' : 'inherit',
  });
  return { status: res.status ?? 1, stdout: res.stdout ?? '', stderr: res.stderr ?? '' };
}

// Fail early and usefully when the dev server is not up.
if (!flags.has('--live')) {
  const reachable = await fetch(LOCAL_BASE, { method: 'HEAD' }).then(
    () => true,
    () => false,
  );
  if (!reachable) {
    console.error(`✗ Nothing listening on ${LOCAL_BASE}`);
    console.error('  Start the preview first:  npm run dev   (background it; wait for the 127.0.0.1:9292 line)');
    process.exit(1);
  }
}

const open = ab(['open', url, '--viewport', `${size[0]}x${size[1]}`]);
if (open.status !== 0) {
  console.error(open.stderr || open.stdout);
  console.error('\nIf Chrome failed to launch, run:  npm run browser:setup');
  process.exit(1);
}

// `open --viewport` only applies when it launches the browser; a reused session
// keeps the previous size. Set it explicitly, then reload so responsive images
// and section JS re-evaluate at the new width.
ab(['set', 'viewport', String(size[0]), String(size[1])]);
ab(['set', 'media', flags.has('--dark') ? 'dark' : 'light']);
ab(['reload']);

// Cookie consent covers the page. Harmless no-op once the session has accepted.
ab(['find', 'role', 'button', 'click', '--name', 'Accetta']);

// Let lazy images and section JS settle before capturing.
ab(['wait', '1200']);

const shot = ab(['screenshot', ...(flags.has('--full') ? ['--full'] : []), out]);
if (shot.status !== 0) {
  console.error(shot.stderr || shot.stdout);
  process.exit(1);
}

const errors = ab(['errors']).stdout.trim();

console.log(`✓ ${url}`);
console.log(`  ${size[0]}x${size[1]}${flags.has('--full') ? ' full-page' : ''}${flags.has('--dark') ? ' dark' : ''}`);
console.log(`  ${out}`);
if (errors && !/no (page )?errors/i.test(errors)) {
  console.log(`\n⚠ page errors:\n${errors}`);
}
