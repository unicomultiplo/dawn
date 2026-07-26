# Unico e Multiplo — Shopify theme

Dawn-based theme for the live store `a1cd90-81.myshopify.com` (public domain:
unicoemultiplo.com). Commits titled "Update from Shopify for theme Main" come
from Shopify's GitHub integration, i.e. edits made in the online theme editor.

All tooling is local to this repo — nothing is installed globally. Run
`npm install` once after cloning.

## Previewing changes locally

```sh
npm run dev
```

Serves the working tree at **http://127.0.0.1:9292** with hot reload, rendered
against the real store's products, collections, metafields and settings.

Under the hood this uploads to a **development theme**: hidden from the theme
list in the Shopify admin, not counted against the 20-theme limit, and deleted
automatically after ~7 days of inactivity. **It never touches the live theme**,
so it is safe to run against production.

For agents:

- Start it with the harness's background-run option, then wait for
  `Preview your theme (t)` / the `127.0.0.1:9292` line in the output before
  browsing. First start takes ~10-30s while the theme is uploaded.
- The port is fixed at 9292 (`--port` to change it), so the preview URL is
  predictable. Deep-link straight to the page under test, e.g.
  `http://127.0.0.1:9292/products/<handle>`.
- Liquid, CSS and JS edits are picked up automatically — do not restart the
  server between edits.
- Section/block rendering can occasionally get out of sync after schema changes;
  restart the server rather than debugging a stale render.

## Other scripts

| Script | What it does | Touches the store? |
| --- | --- | --- |
| `npm run dev` | Local hot-reloading preview (development theme) | hidden dev theme only |
| `npm run dev:sync` | Same, plus pulls theme-editor changes back into local files | hidden dev theme only |
| `npm run dev:open` | Same as `dev`, opens a browser | hidden dev theme only |
| `npm run preview` | Creates a shareable preview link for someone else | adds an **unpublished** theme |
| `npm run push` | Uploads to a new unpublished theme | adds an **unpublished** theme |
| `npm run pull` | Downloads the live theme's files over the working tree | read-only |
| `npm run pull:settings` | Downloads only `config/` and `templates/` (settings + JSON templates) | read-only |
| `npm run check` | Theme Check lint (same as CI) | no |
| `npm run check:fix` | Theme Check with `--auto-correct` | no |
| `npm run themes` | Lists the store's themes with IDs | read-only |
| `npm run shopify -- <args>` | Escape hatch to the local CLI, e.g. `npm run shopify -- theme info -e production` | depends |

No script publishes a theme. Publishing to live is deliberately not wired up —
do it from the Shopify admin, or with an explicit
`npm run shopify -- theme push -e production --theme <id>` after confirming with
the user.

`npm run pull` overwrites local files with whatever is on the live theme —
confirm with the user before running it on a dirty working tree.

## Store / auth

The store is set once in `shopify.theme.toml` under `[environments.production]`;
every script passes `-e production`.

The first command run on a machine opens a browser for Shopify OAuth. After
that the session is cached in `~/.config/shopify` and all commands are
non-interactive. If a command needs to run with no cached session (CI, headless
agent), put a Theme Access token in `.env` as `SHOPIFY_CLI_THEME_TOKEN` — see
`.env.example`. The `.env not found. Continuing without it.` notice on every
script is expected when no `.env` exists.

## Caveats when previewing

- Checkout runs on Shopify's real checkout, outside the local proxy.
- Some third-party app scripts and analytics misbehave through the proxy. This
  store injects the Shogun page builder via
  `snippets/shogun-content-handler.liquid`, which wraps `content_for_header` —
  Shogun-built pages may render differently locally than on the storefront.

## Upstream

`upstream` points at `Shopify/dawn`. Keep root files added for local tooling
(`package.json`, `shopify.theme.toml`, `.shopifyignore`, this file) out of
upstream merges' way; the Dawn `README.md` is intentionally left unmodified to
avoid merge conflicts.
