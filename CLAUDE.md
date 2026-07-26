# Unico e Multiplo — Shopify theme

**Read [`AGENTS.md`](AGENTS.md) first.** It is the operating manual for this repo:
what the theme is, the rules, how to preview your work, and how to keep the docs
current. Everything there applies to you.

Then, as needed:

- [`docs/PREVIEW.md`](docs/PREVIEW.md) — running the theme and seeing your changes
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — why the theme is built this way

This file only covers things specific to Claude Code.

---

## Working visually

`npm run shot` writes a PNG and prints its path. **Use the Read tool on that
path** — you can see images directly, so a screenshot is a real check, not a
formality. Do this before reporting that a design change works.

```sh
npm run dev                                   # run_in_background: true
npm run shot -- /products/doiy-sweetie-mug    # then Read the PNG it prints
```

Start `npm run dev` with `run_in_background: true` and wait for the
`127.0.0.1:9292` line before browsing. Don't foreground it — it never exits.

For an iterative design task, make several edits, then take one screenshot, rather
than screenshotting after every line. Hot reload means the server keeps up.

## Parallelism

`sections/`, `snippets/` and `assets/` are largely independent — separate files,
no shared build. Fanning subagents out across unrelated sections works well.
`assets/base.css`, `layout/theme.liquid` and `templates/*.json` are the shared
files; serialize edits to those.

## Doc upkeep

[`AGENTS.md`](AGENTS.md#keeping-the-docs-alive) asks you to fold what you learn
back into these files without being prompted. A `Stop` hook in
`.claude/settings.json` reminds you at the end of each turn — treat it as a
prompt to check, not an instruction to always write something. Most turns need no
doc change; the ones that discover a better method, a stale command, or an
undocumented constraint do.

## Permissions

`npm run dev`, `npm run shot`, `npm run browser` and `npm run check` are all safe
and reversible — they never touch the live theme. `npm run pull`,
`npm run push`, `npm run preview` and anything with `theme push` reach the store;
confirm those with the user first.
