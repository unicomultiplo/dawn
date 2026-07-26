# Previewing & visually checking the theme

How to see a change with your own eyes, without a human in the loop.

**Keep this file current.** If you find a faster or more reliable way to do
anything here, replace the instruction — see
[`AGENTS.md`](../AGENTS.md#keeping-the-docs-alive).

---

## The loop

```sh
npm run dev                      # 1. start the preview (background it) — ~10-30s
npm run shot -- /products/doiy-sweetie-mug   # 2. screenshot a page
# 3. read the PNG it prints, edit liquid/css, re-run step 2 (no restart needed)
```

That's it. Steps 1 and 2 are explained below; everything else on this page is
for when the simple loop isn't enough.

---

## 1. Start the preview server

```sh
npm run dev
```

Serves the working tree at **http://127.0.0.1:9292** with hot reload, rendered
against the real store's products, collections, metafields and settings.

Under the hood it uploads to a **development theme**: hidden from the admin theme
list, not counted against the 20-theme limit, deleted automatically after ~7 days
idle. **It never touches the live theme** — safe to run against production.

**Running it as an agent:**

- Start it with your harness's background-run option. Wait for the
  `127.0.0.1:9292` line in the output before browsing. First start takes ~10–30 s.
- The port is fixed, so URLs are predictable. Deep-link straight to the page under
  test — don't navigate from the homepage.
- Liquid, CSS and JS edits are picked up automatically. **Do not restart between
  edits.**
- Restart after `{% schema %}` changes — section rendering can get out of sync,
  and a stale render is not worth debugging.

### Auth

**Just run it first.** The CLI caches its session in
`~/.config/shopify-cli-kit-nodejs/` (not `~/.config/shopify/` — don't use that
path's absence as evidence you're logged out). On a machine that has been used
before, `npm run dev` starts with no prompt.

Only if it tries to open a browser for OAuth do you need a human, one time:

> Shopify admin → Apps → Theme Access → Add user → copy the emailed `shptka_…`
> token → put it in `.env` as `SHOPIFY_CLI_THEME_TOKEN=shptka_…`

`.env` is gitignored and loaded automatically by the npm scripts
(`--env-file-if-exists`). See `.env.example`. That token also covers CI and any
truly headless run.

While you're blocked on that, `npm run shot -- <path> --live` inspects the
published storefront — useful for "what does it look like today?", useless for
checking your own edit.

---

## 2. Screenshot a page

```sh
npm run shot -- <path> [flags]
```

`scripts/shot.mjs` wraps [`agent-browser`](https://github.com/vercel-labs/agent-browser)
with the settings this store needs every time. It opens the page, dismisses the
cookie banner, waits for the page to settle, writes a PNG to `.screenshots/`, and
prints the path plus any console errors. **Read the PNG** — that's the point.

| Flag | Effect |
| --- | --- |
| *(none)* | desktop, 1440×900 |
| `--mobile` | 390×844 |
| `--tablet` | 820×1180 |
| `--full` | full page, not just the viewport |
| `--dark` | emulate `prefers-color-scheme: dark` |
| `--live` | hit `https://unicoemultiplo.com` instead of localhost |
| `--out path.png` | explicit output path |

```sh
npm run shot -- /                                  # homepage
npm run shot -- /collections/seletti --mobile      # mobile PLP
npm run shot -- /products/<handle> --full          # whole PDP
npm run shot -- /cart --live                       # live cart, no dev server
```

Output filenames derive from the path, so desktop and mobile shots of the same
page don't overwrite each other. `.screenshots/` is gitignored.

If it reports `Nothing listening on 127.0.0.1:9292`, start the dev server.
If Chrome fails to launch: `npm run browser:setup` (downloads Chrome for Testing
to `~/.agent-browser/`, ~184 MB, once per machine). Diagnose with
`npm run browser:doctor`.

---

## 3. Driving the browser directly

`npm run shot` covers most needs. For anything interactive, use the CLI:

```sh
npm run browser -- <command>
```

This is `agent-browser` pinned to the session name `uem`, so cookies and the
accepted cookie consent persist across calls — and across separate shell
invocations. The browser stays alive between commands via a daemon.

```sh
npm run browser -- open http://127.0.0.1:9292/products/<handle>
npm run browser -- snapshot -i          # accessibility tree, interactive only, gives @e1 refs
npm run browser -- click @e4            # click by ref from the snapshot
npm run browser -- find role button click --name "Aggiungi al carrello"
npm run browser -- get text .price
npm run browser -- errors               # JS errors
npm run browser -- console              # console output
npm run browser -- set viewport 390 844
npm run browser -- eval "document.querySelectorAll('.card').length"
npm run browser -- close
```

`snapshot` before `click` — refs (`@e1`, `@e2`) come from the most recent
snapshot. `--annotate` on a screenshot overlays those same numbers on the image,
which is the fastest way to connect what you see to what you can click.

Full command list: `npx agent-browser --help`, or
`npx agent-browser skills get core --full` for the authors' own agent guide.

### Things worth knowing for this store

**The cookie banner covers everything.** First run in a fresh session, dismiss it:

```sh
npm run browser -- find role button click --name "Accetta"
```

The `uem` session persists that consent, so it only happens once per machine.
`npm run shot` does it automatically.

**A WhatsApp widget sits bottom-right** on every page and will appear in
full-page screenshots. It's an app embed, not theme code.

**Shogun pages may not reflect your edits.** If a page renders empty, doubled, or
ignores your change, check for `<template id="shogun-variant-body">`:

```sh
npm run browser -- eval "!!document.getElementById('shogun-variant-body')"
```

`true` means Shogun replaced the theme's markup and your `sections/*.liquid` edit
cannot show up. Test on a resource without `shogun.*` metafields.
See [ARCHITECTURE.md D2](ARCHITECTURE.md#d2--shogun-is-the-page-builder-of-record).

**Some third-party app scripts and analytics misbehave through the local proxy.**
Console noise from them is expected and not your bug.

**Checkout runs on Shopify's real checkout**, outside the proxy. You cannot
preview checkout changes locally, and you should not place test orders.

---

## 4. Visual regression

Prove a change did what you intended and nothing else:

```sh
npm run shot -- /collections/seletti --out /tmp/before.png     # before editing
# ... make the edit ...
npm run shot -- /collections/seletti --out /tmp/after.png
npm run browser -- diff screenshot --baseline /tmp/before.png
```

`diff snapshot` does the same for the accessibility tree — better than pixels for
catching structural changes (an element that vanished, a heading that changed
level) without false positives from image lazy-loading.

Other checks worth running on a design change:

```sh
npm run browser -- vitals                # LCP / CLS / TTFB / FCP / INP
npm run browser -- errors                # JS errors
npm run check                            # Theme Check lint — same as CI
```

Run `npm run check` before handing work back. CI runs it on every push.

---

## 5. Page ↔ file map

Which URL to open, and which file to edit.

| To check… | Open | Edit |
| --- | --- | --- |
| Homepage | `/` | `templates/index.json`, `sections/slideshow.liquid`, `sections/multicolumn.liquid` |
| Product page | `/products/doiy-sweetie-mug` | `sections/main-product.liquid`, `assets/section-main-product.css` |
| Product cards / grid tiles | any collection URL | `snippets/card-product.liquid`, `assets/component-card.css` |
| Collection / PLP | `/collections/cucina-e-tavola-piatti` | `sections/main-collection-product-grid.liquid`, `sections/main-collection-banner.liquid`, `assets/template-collection.css` |
| Filters / facets | `/collections/seletti` | `snippets/facets.liquid`, `assets/component-facets.css`, `assets/facets.js` |
| Cart page | `/cart` | `sections/main-cart-items.liquid`, `assets/component-cart-items.css` |
| Cart drawer | any page, then add to cart | `snippets/cart-drawer.liquid`, `assets/component-cart-drawer.css` |
| Header / nav / mega menu | any page | `sections/header.liquid`, `snippets/header-mega-menu.liquid`, `sections/header-group.json` |
| Footer | any page | `sections/footer.liquid`, `assets/section-footer.css`, `sections/footer-group.json` |
| Search | `/search?q=piatti` | `sections/main-search.liquid`; predictive: `sections/predictive-search.liquid` |
| Blog index | `/blogs/apparecchiare-con-stile` | `sections/main-blog.liquid` |
| Article | `/blogs/regalare-per-stupire/cosa-regalare-ai-genitori-per-natale` | `sections/main-article.liquid` |
| Generic page | `/pages/i-nostri-brand` | `sections/main-page.liquid` |
| Contact form | `/pages/i-nostri-brand?view=contact` | `sections/contact-form.liquid` |
| 404 | `/this-does-not-exist` | `templates/404.json` (the `main-404` section is **disabled**; a rich-text block replaces it) |
| Login / account | `/account/login` | `sections/main-login.liquid`, `assets/customer.css` |
| Disclosures feature | product & cart pages | `snippets/product-disclosures.liquid`, `snippets/cart-disclosure-indicator.liquid`, `assets/component-disclosures.css` |

### The `?view=` trick

Suffixed templates render on **any** resource of that type via `?view=`:

```
/collections/<any-collection>?view=brandani-brand   → templates/collection.brandani-brand.json
/products/<any-product>?view=bone-china             → templates/product.bone-china.json
/pages/<any-page>?view=contact                      → templates/page.contact.json
```

This works through the dev proxy, so you can check any of the 41 collection
templates, 15 page templates and 8 article templates **without knowing which
resource it's assigned to in the admin.** This is the fastest way to review
merchandised layouts.

### Real handles to deep-link to

Products: `doiy-sweetie-mug`, `bitossi-home-guest-piatto-pizza-mamma-mia`,
`brandani-calipso-mug-set-2-pz-stoneware`, `1518-seletti-hybrid-vaso-melania`,
`5074-seletti-my-moon-lamp-lampada-seduta-indoor-outdoor`,
`joseph-joseph-ceppo-coltelli-con-forbici`, `brabantia-appendiabiti-linn`

Collections: `cucina-e-tavola-piatti`, `cucina-e-tavola-bicchieri-e-calici`,
`cucina-e-tavola-posate`, `seletti`, `brandani`, `knindustrie`, `bitossi-home`,
`offerte-e-promo`, `idee-regalo-natale`, `vetro-borosilicato`

Pages: `i-nostri-brand`, `iscrizione`, `pagamenti`, `natale`,
`la-tavola-di-natale`, `bomboniere-brandani`

Blogs: `apparecchiare-con-stile`, `regalare-per-stupire`, `blog`

Navigation menus live in the Shopify admin, not this repo — but the dev server
renders the real ones, so nav looks correct locally.

---

## 6. Other scripts

| Script | What it does | Touches the store? |
| --- | --- | --- |
| `npm run dev` | local hot-reloading preview | hidden dev theme only |
| `npm run dev:sync` | same, plus pulls theme-editor changes into local files | hidden dev theme only |
| `npm run dev:open` | same as `dev`, opens a browser | hidden dev theme only |
| `npm run shot` | screenshot a page for review | no |
| `npm run browser` | drive the browser directly | no |
| `npm run browser:setup` | download Chrome for Testing (once per machine) | no |
| `npm run check` | Theme Check lint (same as CI) | no |
| `npm run check:fix` | Theme Check with `--auto-correct` | no |
| `npm run preview` | shareable preview link for a human | adds an **unpublished** theme |
| `npm run push` | upload to a new unpublished theme | adds an **unpublished** theme |
| `npm run pull` | **overwrites local files** with the live theme | read-only on the store |
| `npm run pull:settings` | pull only `config/` and `templates/` | read-only on the store |
| `npm run themes` | list the store's themes with IDs | read-only |
| `npm run shopify -- <args>` | escape hatch to the local CLI | depends |

`npm run pull` overwrites the working tree — **confirm with the user before
running it**, especially if the tree is dirty.

No script publishes to live. That is deliberate — see
[ARCHITECTURE.md D12](ARCHITECTURE.md#d12--local-tooling-can-never-publish-to-live).

The `.env not found. Continuing without it.` notice on every script is expected
when no `.env` exists.
