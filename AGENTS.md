# Working on this repo

Instructions for AI coding agents. Humans are welcome to read it too — it's just
the project's operating manual.

Claude Code users: [`CLAUDE.md`](CLAUDE.md) adds a few Claude-specific notes on
top of this file.

---

## What this is

The Shopify theme for **unicoemultiplo.com** (store `a1cd90-81.myshopify.com`), a
fork of [Dawn](https://github.com/Shopify/dawn) 15.5.0. Italian storefront,
~2 600 products.

Plain Liquid + CSS + JS. **No build step, no bundler, no preprocessor** — files
upload to Shopify as-is. All tooling is local to this repo; run `npm install`
once after cloning.

Three docs, in the order you'll want them:

| | |
| --- | --- |
| **[`docs/PREVIEW.md`](docs/PREVIEW.md)** | How to run and *see* the theme. Start here for any visual work. |
| **[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)** | Why the theme is built this way. Read before structural changes. |
| **[`README.md`](README.md)** | Upstream Dawn's readme, kept unmodified on purpose. Not about this store. |

---

## Rules

**PRs go to `unicomultiplo/dawn`, never to `Shopify/dawn`.** This repo is a fork;
`upstream` is fetch-only. Always pass `--repo` explicitly — with two remotes,
`gh` can resolve an omitted default to the public upstream, and once did:

```sh
gh pr create --repo unicomultiplo/dawn --base main --head <branch> ...
```

A committed `PreToolUse` hook blocks the unsafe forms, and `npm install` pins
`gh`'s default repo and disables pushing to `upstream`. Fetching and diffing
upstream stays allowed — Dawn syncs need it. See
[ARCHITECTURE.md D14](docs/ARCHITECTURE.md#d14--upstream-is-fetch-only-prs-go-to-unicomultiplodawn).

**Never publish to live.** No npm script does, deliberately. Publishing happens in
the Shopify admin, or via an explicit
`npm run shopify -- theme push -e production --theme <id>` — and only after
confirming with the user. `npm run dev` and `npm run push` are safe; they use a
hidden development theme and an unpublished theme respectively.

**`npm run pull` overwrites local files** with whatever is on the live theme.
Confirm before running it, especially on a dirty tree.

**Don't edit auto-generated app files.** `snippets/shogun-*.liquid` are owned by
Shogun and will be overwritten. Same for anything else marked auto-generated.

**Don't reformat Dawn files you aren't otherwise changing.** 34 files already
differ from upstream by whitespace alone, and each one is a permanent merge
conflict for zero gain. Turn off format-on-save for vendored files. See
[ARCHITECTURE.md D11](docs/ARCHITECTURE.md#d11-dont-reformat-vendored-dawn-files).

**Add new UI copy to both `locales/en.default.json` and `locales/it.json`**, or
the Italian storefront falls back to English and `npm run check` flags it.

**Run `npm run check` before you finish.** It's Theme Check, and it's what CI
runs on every push.

**Chrome UI uses `<span>`, not `<h2>`/`<h3>`.** Deliberate SEO convention — see
[ARCHITECTURE.md D3](docs/ARCHITECTURE.md#d3--seo-heading-hierarchy-chrome-uses-span-not-h2h3).

**Theme-editor files change under you.** `config/`, `templates/*.json` and
`sections/*-group.json` are written by merchants in the Shopify admin and land
here as commits titled `Update from Shopify for theme Main`. Treat them as
merchandising data, not code.

---

## Doing visual work

The short version — full detail in [`docs/PREVIEW.md`](docs/PREVIEW.md):

```sh
npm run dev                                   # background it; wait for the 127.0.0.1:9292 line
npm run shot -- /products/doiy-sweetie-mug    # writes a PNG, prints the path
```

Then **look at the PNG**, edit, and re-run `npm run shot`. Liquid/CSS/JS hot-reload;
no restart needed. Add `--mobile`, `--full`, or `--dark` as needed.

Don't claim a design change works because the code looks right. Screenshot it.

**On auth:** just run `npm run dev` — the CLI session is usually already cached
and it starts without a prompt. Only if it tries to open a browser for OAuth do
you need the user to add a Theme Access token to `.env`
([details](docs/PREVIEW.md#auth)). Meanwhile `npm run shot -- <path> --live`
inspects the published site.

---

## Keeping the docs alive

**These docs are meant to be edited by you, without being asked.**

The point of writing them down was so that nobody has to re-derive the same thing
twice. That only holds if you fold what you learn back in.

**When any of these happen, update the docs in the same change:**

| You discovered… | Update |
| --- | --- |
| a faster/more reliable way to preview, screenshot, or debug something | `docs/PREVIEW.md` — **replace** the old instruction, don't append an alternative |
| a documented command that no longer works, or a wrong URL / handle / file path | wherever it appears — fix it, don't work around it |
| a design decision, convention, or constraint that isn't written down | `docs/ARCHITECTURE.md` §2 as a new `D<n>` entry |
| a decision was reversed or superseded | edit that `D<n>` in place; say what changed and why |
| new dead code, drift, or a latent bug you're not fixing now | `docs/ARCHITECTURE.md` §3 |
| you fixed something listed in §3 | delete the entry |
| a rule an agent should always follow | the [Rules](#rules) section above |
| a gotcha that cost you more than a few minutes | the closest relevant section |

**How to do it well:**

- Write the *conclusion*, not the investigation. "Use X because Y fails on Z" —
  not a narrative of how you found out.
- Prefer replacing over accumulating. A doc with two competing methods is worse
  than one with a single method that works.
- Verify before you write. These files are load-bearing for future agents; a
  confidently wrong line costs more than a missing one. Run the command.
- Don't log routine work here. This is for durable facts, not a changelog.
- Mention doc updates in your summary so the user can see what you changed.

If you're unsure whether something belongs: would the next agent waste time
without it? Then write it down.
