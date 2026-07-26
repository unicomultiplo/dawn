# Architecture & design decisions

Why this theme is built the way it is. Read this before changing anything
structural — most of what looks odd here is deliberate, and the parts that
aren't are listed in [Known drift](#known-drift--cleanup-backlog).

**Keep this file current.** See the maintenance protocol in
[`AGENTS.md`](../AGENTS.md#keeping-the-docs-alive).

---

## 1. What this is

A fork of [Shopify Dawn](https://github.com/Shopify/dawn) **15.5.0**
(`config/settings_schema.json` → `theme_version`) powering
[unicoemultiplo.com](https://unicoemultiplo.com) (store `a1cd90-81.myshopify.com`)
— an Italian design / homeware retailer, ~2 600 products.

Three parties write to this repo:

| Author | How it arrives | Touches |
| --- | --- | --- |
| Developers / agents | PRs on `main` | everything |
| Shopify theme editor | commits titled `Update from Shopify for theme Main`, via the Shopify GitHub integration | `config/`, `templates/`, `sections/*-group.json` |
| Storefront apps (Shogun, GemPages, PageFly, Rewind) | written into the theme by the app, then synced down | `snippets/`, `layout/`, some `templates/` |

That third row is the single most important thing to internalise: **files can
appear in this repo that no one on the team wrote**, and some are marked
"auto-generated, may be rewritten at any time". Editing those is pointless.

### Divergence from upstream, in numbers

`git diff v15.5.0 HEAD --stat` → 226 files, +53 426 / −999. Broken down:

- **~150 `templates/*.json`** (~48 000 lines) — theme-editor merchandising output, not code.
- **46 genuinely modified** code files in `assets/ sections/ snippets/ layout/ blocks/`.
- **34 code files that differ from upstream by formatting alone** — see [D11](#d11-dont-reformat-vendored-dawn-files).

---

## 2. Decision log

### D1 — Track Dawn as a remote; sync by squash at release boundaries

`upstream` = `https://github.com/Shopify/dawn.git`. Syncs land as a single
squashed commit (`ec8b4825` for 15.5.0).

**Consequence:** upstream tags are *not* ancestors of `HEAD`
(`git merge-base --is-ancestor v15.5.0 HEAD` is false), so `git merge upstream/main`
will not work cleanly. Every future sync is a manual re-application: diff the new
Dawn release against the old one, then replay onto this tree, resolving against
the 46 modified files.

Dawn's `README.md` is deliberately left unmodified to avoid a guaranteed conflict
on every sync. Repo-local tooling (`package.json`, `shopify.theme.toml`,
`.shopifyignore`, `AGENTS.md`, `CLAUDE.md`, `docs/`, `scripts/`) lives at paths
Dawn does not use, for the same reason.

### D2 — Shogun is the page builder of record

`snippets/shogun-content-handler.liquid` is `{% include %}`d as **line 1** of
`layout/theme.liquid` and `layout/password.liquid`, before `<!doctype html>`.

It resolves the current `article | page | product | collection` into a `content`
variable and then re-`{% capture %}`s Shopify's reserved output variables:

1. appends `{% render 'shogun-products', content: content %}` to `content_for_header` — on **every page**;
2. appends per-`template.suffix` head HTML from `content.metafields.shogun.json_template_snippets`;
3. if `content.metafields.shogun.json_template_html_wrapper` exists, **replaces `content_for_layout` entirely**;
4. if `content.metafields.shogun.json_template_optimizer` exists, wraps head and body in `<template id="shogun-variant-head|body">` so Shogun's JS decides what renders.

**Accepted costs**, in exchange for merchant-editable landing pages:

- Rewriting `content_for_header` is unsupported by Shopify. `.theme-check.yml`
  suppresses `ContentForHeaderModification` for this one file, with a comment.
- The file is auto-generated. **Do not edit it** — Shogun will overwrite it.
- Which pages are Shogun-driven is **metafield-driven per resource** and therefore
  not knowable from this repo.
- `snippets/shogun-products.liquid` inlines up to 20 full `product | json` objects
  plus a paginated dump of every product in listed collections into `<head>`. On
  collection-heavy pages this is a real LCP/TTFB cost.

**Debugging rule:** if a page renders empty, doubled, or ignores your
`sections/*.liquid` edit, look for `<template id="shogun-variant-body">` in the
DOM. Step 4 fired and the theme's own markup is inert. Test design changes on a
resource without `shogun.*` metafields.

### D3 — SEO heading hierarchy: chrome uses `<span>`, not `<h2>`/`<h3>`

Across 12 files — `announcement-bar`, `header`, `header-drawer`, `footer`,
`cart-drawer`, `main-cart-footer`, `facets`, `main-collection-product-grid`,
`main-search`, `predictive-search`, `card-collection` — every non-content heading
("Country", "Language", "Sort by", "Filter by", "Your cart", "Estimated total",
collection card titles) was demoted to `<span>` **keeping the original class
names**, so styling is untouched.

Companion changes with the same motive: the duplicate `<h2 class="h1">` product
title link removed from `sections/main-product.liquid`; `snippets/pagination.liquid`
strips `?page=1` from the page-1 link; `templates/robots.txt.liquid` blocks facet
params.

**Accepted trade-off:** several of these were the accessible name for a landmark
or form. `<span id=…>` still satisfies `aria-labelledby`, but the facets drawer
and cart drawer lose heading semantics for screen-reader heading navigation.
This was chosen knowingly — SEO over that specific a11y affordance.

**If you add chrome UI, follow this convention** — use `<span>` with the heading
class, not a real heading tag.

### D4 — Percentage discount badges instead of the word "Sale"

`snippets/price.liquid` and `snippets/card-product.liquid` compute
`-{{ discount_percentage }}%` from `compare_at_price` rather than rendering
Dawn's `products.product.on_sale` string.

Incomplete: `card-product.liquid` still has other branches emitting the plain
`on_sale` label, so badges are inconsistent by card style. See [drift](#known-drift--cleanup-backlog).

### D5 — Product content comes from metafields, surfaced via `type: "liquid"` settings

Rather than adding a block type per field, two schemas gained a
`type: "liquid"` setting so merchants can write Liquid from the theme editor:

- `sections/main-product.liquid` → `custom-liquid` on `collapsible_tab` blocks
- `sections/collapsible-content.liquid` → `liquid_content` on `collapsible_row` blocks

This is load-bearing: the product page's entire "Caratteristiche" spec table is a
`liquid_content` block reading `product.metafields.shopify.material`,
`custom.lunghezza`, `custom.altezza_2`, `custom.profondita`, `custom.diametro_2`,
`custom.designer`, `custom.capacit_`. There are 6 `custom_liquid` blocks in the
main product section and 46 `custom-liquid` sections across templates.

**Upside:** merchants change product presentation without a deploy.
**Downside:** a lot of the storefront's logic lives in `templates/*.json` strings
that no linter, formatter, or grep-for-Liquid will ever check.

Two custom product blocks back this up:

- **`variant_sku`** — `<p id="product-sku">` inside `<div id="sku-{{ section.id }}">`
- **`qty_disclaimer`** — when the variant is out of stock and
  `product.metafields.custom.banner-spedizione-in-gg` is set, prints
  `Spedito dopo il DD/MM/YYYY`

Dawn only re-renders a fixed set of section IDs on variant change, so
`assets/product-info.js` was extended with `updateDynamic(id, html)`, called for
`sku-${section}` and `qty-disclaimer-${section}`. **A third dynamic block needs
another explicit call here** — this is not generic.

### D6 — Merchandising is one template per collection

41 hand-built `templates/collection.<suffix>.json` files rather than a generic PLP
driven by metafields. Three families:

- **Brand PLPs** — `SELETTI`, `seletti-brand`, `brandani`, `brandani-brand`, `knindustrie`, `knindustrie-brand`, `bitossi-home-sc`, `plp-brand-bitossi`, `brabantia`
- **Category PLPs** — `bicchieri-calici`, `piatti-da-tavola`, `piatti-frutta`, `piatti-brandani`, `posate`, `tumbler`, `tovaglie-tovagliette`, `turbo-moka`, `toilet-seletti`
- **Seasonal / gifting** — `black-friday`, `san-valentino`, `regali-pasqua`, `idee-regalo-*`, `natale-*`, `regali-{50,100,150}`, `regali-per-{lei,lui,gli-sposi}`, `regalo-{compleanno,genitori}`, `offerte-e-promo`, …

Plus 15 `page.*`, 8 `article.*`, 5 `blog.*`, 3 `product.*` suffixed templates.
Stock Dawn ships 20 templates; this theme has 85 + 7 customer templates.

**Why it matters to you:** editing `sections/main-collection-product-grid.liquid`
changes all 41. Editing one merchandised page means editing its JSON template.

### D7 — Flat visual language

From `config/settings_data.json`:

| Token | Value |
| --- | --- |
| Page width | **1400 px** (Dawn default 1200) |
| Section spacing | 16 |
| Grid gaps | 20 / 20 |
| Corner radius | 6 px — buttons, variant pills, inputs |
| Borders | 1 px, full opacity, on buttons / pills / inputs |
| **Shadows** | **all opacities 0 — the theme is entirely flat** |
| Cards | `card` style, 0 border, 2 px radius (product/collection), no padding, left-aligned |
| Badges | top-right, `badge_corner_radius: 40` (pill) |
| Media | 1 px border @ 5 % opacity, 0 radius |
| Animations | reveal-on-scroll on, hover effect `default` |

**Typography:** `type_header_font` and `type_body_font` are **both `roboto_n4`**,
both at scale 100. Headings and body are the same font at the same weight, and
there are **no webfont files in `assets/`**. Any display typography you see on the
site comes from Shogun pages or per-section `custom_css`. Introducing real type
hierarchy is a settings change, not a code change.

**Colour:** 19 schemes (Dawn ships 5). The brand palette:

| Role | Colour |
| --- | --- |
| Primary accent / buttons | `#598db2` muted blue |
| Promotional emphasis | `#f4cf5f` brand yellow |
| Seasonal | `#cc0033` christmas red |
| Text | `#121212` |
| Product background | `#f5f5f5` |

Mirrored as custom properties at the top of `assets/base.css`
(`--highlight-color`, `--highlight-color-2`, `--highlight-christmas`,
`--product-background-color`, `--highlight-color-rgb`). These are consumed from
theme-editor `custom_css` arrays in `sections/header-group.json` and
`templates/index.json` — **not** from Liquid. The design system is therefore half
in CSS and half in JSON, with no single source of truth. Changing a brand colour
means changing both.

Two schemes contain the unresolved literal
`{{ shop.brand.colors.secondary[0].foreground }}` as their value — resolved at
render, so `scheme-1`'s background is not knowable from the file alone.

### D8 — Italian-first, selectors off

Storefront copy is Italian and lives in `templates/*.json`, not in translation
keys. `enable_country_selector` / `enable_language_selector` are `false` in
`sections/header-group.json` and in `sections/header.liquid`'s schema defaults
(only the footer group enables them).

`locales/en.default.json` is still nominally the default file. `locales/it.json`
is the only locale with real store overrides, and two of them are load-bearing:

- `shopify.links.powered_by_shopify` → **`"P.IVA IT00454960436"`** — the
  "Powered by Shopify" footer slot is repurposed to display the Italian VAT
  number. Invisible from the theme editor. **Do not "fix" this.**
- `shopify.checkout.payment_gateway.cash_on_delivery_label` →
  `"Contrassegno contanti (+ €8,00)"` — a **price hard-coded into a translation
  string**. It will silently go stale if the COD fee changes.
- Billing-address labels rewritten to instruct customers to email invoicing details.
- `customer_accounts.B2B.locations.tax_id` → `"Codice fiscale / Partita IVA"`.

**When adding UI copy**, add the key to **both** `locales/en.default.json` and
`locales/it.json`, or Italian falls back to English and `npm run check` flags it.

### D9 — Four custom sections, one custom block

| File | Purpose | Uses |
| --- | --- | --- |
| `sections/separator.liquid` | horizontal rule, configurable thickness + responsive padding | 21 |
| `sections/dual-images.liquid` | 1 large left image + 2 stacked right, each linkable | 8 |
| `blocks/ai_gen_block_f52c25c.liquid` | "Icone prodotti cliccabili" (AI-generated; Italian `@prompt` docstring) | 3 collection templates |
| `sections/payment-methods.liquid` | payment-icon strip | **0 — dead** |
| `sections/disclosures.liquid` | product/cart disclosure feature | see below |

These three deviate from Dawn's convention by using an inline `<style>` block
instead of an `assets/section-*.css` file: `dual-images`, `separator`,
`payment-methods`.

The **disclosures** feature is a bespoke addition spanning
`snippets/product-disclosures.liquid`, `snippets/cart-disclosure-indicator.liquid`,
`assets/component-disclosures.css`, `assets/cart-disclosure-modal.js`,
`assets/cart-disclosure-tooltip.js`, `assets/disclosures.js`.

### D10 — Whole multicolumn card is clickable

`sections/multicolumn.liquid` changed `.multicolumn-card` from `<div>` to `<a>`.
Three coupled edits make it work:

1. `role="none"` on the non-linked variant;
2. `assets/base.css` → `a:not([href]):not([role="none"]) { cursor: not-allowed }`;
3. `assets/section-multicolumn.css` → `.multicolumn-card { display: block }`.

Multicolumn is the most-used section on the site (**368 instances**), so this is
load-bearing — but the inner content still contains an `<a>` for `link_label`,
producing **nested anchors**, which is invalid HTML that browsers silently unnest.

### D11 — Don't reformat vendored Dawn files

**34 code files differ from upstream Dawn 15.5.0 by formatting alone** —
Prettier 3 style: multiline `box-shadow`/`transition`, trailing commas,
`.5rem` → `0.5rem`, `99.630%` → `99.63%`. Zero functional change, permanent merge
conflict on every upstream sync.

Cause: `.vscode/settings.json` enables `formatOnSave` for JS and CSS with a newer
Prettier than Shopify used to author Dawn.

**Rule going forward: never save-format a Dawn file you are not otherwise
changing.** Verify before committing:

```sh
# Files whose diff vs upstream is whitespace/comma-only
for f in $(git diff v15.5.0 HEAD --name-only -- assets sections snippets layout blocks); do
  [ -f "$f" ] || continue
  [ "$(git show v15.5.0:"$f" | tr -d '[:space:],')" = "$(tr -d '[:space:],' < "$f")" ] && echo "format-only: $f"
done
```

### D12 — Local tooling can never publish to live

Encoded in `package.json` (commit `70703b36`):

- `npm run push` is always `--unpublished`.
- `npm run dev` uploads to a **hidden development theme** — invisible in the admin
  theme list, not counted against the 20-theme limit, auto-deleted after ~7 days
  idle. Safe against production.
- **No script publishes.** Publishing is the admin UI, or an explicit
  `npm run shopify -- theme push -e production --theme <id>` after confirming with
  the store owner.
- `.shopifyignore` keeps every tooling file off the store.
- CI is a single `theme-check` job on every push (`.github/workflows/ci.yml`).

### D13 — Three documented theme-check suppressions

`.theme-check.yml`, each with a comment explaining why:

| Rule | Scope | Reason |
| --- | --- | --- |
| `LiquidHTMLSyntaxError` | `sections/header.liquid` | dynamic tag names (`<sticky-header>` vs `<div>`) via Liquid inside the opening tag — valid Shopify Liquid the parser can't handle |
| `ContentForHeaderModification` | `snippets/shogun-content-handler.liquid` | see [D2](#d2--shogun-is-the-page-builder-of-record) |
| `ValidSchema` | `sections/email-signup-banner.liquid` | `templates` is a valid schema key that theme-check flags as unknown |
| `MatchingTranslations`, `TemplateLength` | global | disabled |

**Add a suppression only with a comment saying why.** That precedent is the point.

---

## 3. Known drift & cleanup backlog

Not decisions — accumulated debt. Verified present as of 2026-07-26.

**Dead code**

1. **GemPages is entirely dead but still ships**: `layout/theme.gempages.{blank,header,footer}.liquid`, `layout/theme.gem-layout-none.liquid`, `snippets/gp-head.liquid` (**no caller**, verified), `assets/gp-global.css` (minified Tailwind 3.3.2 reset, loaded only by the orphaned snippet), and 3 homepage backups `templates/index.gem-*.json` / `index.gp-template-bk-default.json` (~780 lines each).
2. **PageFly is dead**: `snippets/pagefly-main-js.liquid` (**no caller**, verified) — but its `pagefly.*` translation block was appended to **all 30 locale files**.
3. **Rewind leftovers**: `snippets/rewind_menu_backup_do_not_delete.liquid` + `templates/page.rewind_menu_backup_do_not_delete.liquid`.
4. `sections/payment-methods.liquid` — **0 uses**.
5. `{% capture content_for_body %}` in `shogun-content-handler.liquid` is never output — dead code from an older Shogun version.

**Correctness**

6. **Trailing commas in two `{% schema %}` blocks** — `sections/collapsible-content.liquid` and `sections/dual-images.liquid` both fail `JSON.parse`. Shopify tolerates it today; it is invalid JSON.
7. **Hyphenated Liquid identifiers** — `block.settings.custom-liquid`, `product.metafields.custom.banner-spedizione-in-gg`. Resolves today, one strict-mode change from being parsed as subtraction.
8. **Nested `<a>`** in `multicolumn.liquid` (see [D10](#d10--whole-multicolumn-card-is-clickable)).
9. **`-N%` badge covers only some sale-badge render paths** (see [D4](#d4--percentage-discount-badges-instead-of-the-word-sale)).

**Design system**

10. **`scheme-white-text` is white-on-white** and unreadable. The dated hotfix at the bottom of `assets/base.css` (`/* # Fix for the 2026-02-05 issue */`, `!important` on `.cart-remove-button` and hover states) patches the symptom, not the scheme.
11. **`.page-width--narrow` neutered globally** in `base.css` — `max-width: 72.6rem; padding: 0` → `max-width: var(--page-width); padding: 0 5rem`. Dawn's narrow-content variant (article/page templates) is effectively gone, site-wide, rather than per-template.
12. **All article/blog cards forced brand yellow** — `.article-card-wrapper .card, .contains-card--article { background-color: var(--highlight-color) !important }` overrides the `blog_card_color_scheme` setting.

**Drifted layouts**

13. The five alternate layouts (`theme.shogun.landing`, four `theme.gem*`) were cloned from an older `theme.liquid` and never re-synced. All are missing: the GTM container + noscript iframe, Dawn 15.5.0's `standard-events.js` + `PageViewEvent`, `cart-disclosure-modal.js` / `cart-disclosure-tooltip.js` / `standard-actions-override.js`, `data-template` on `<main>`, and the 15.5.0 CLS body-layout fix. **Practical impact: Shogun landing pages have no analytics.** The gap widens with every Dawn upgrade.

**Untranslated / hard-coded**

14. Italian strings outside the locale system: `"Leggi di più..."` (`main-collection-banner.liquid`), `"Spedito dopo il"` (`main-product.liquid`).
15. `€8,00` COD fee inside a translation string ([D8](#d8--italian-first-selectors-off)).
16. `main-collection-banner.liquid`'s expandable description hard-codes a `#ffffff` gradient (ignores the section colour scheme), measures height at parse time rather than `DOMContentLoaded` (so it can run before webfonts settle), and leaves an empty `.collection-hero__description__expand button {}` rule plus a `display: flex` immediately overridden by `display: none`.

**Merge friction**

17. 34 format-only divergences ([D11](#d11-dont-reformat-vendored-dawn-files)).
18. All 30 Dawn buyer locales + 21 schema locales retained for a single-language store.

**Historical curiosity:** `templates/robots.txt.liquid` blocks `/catalogsearch/` — a **Magento** URL pattern, left over from a pre-Shopify migration.

---

## 4. Where things live

```
layout/      theme.liquid ← GTM, Shogun include (line 1), global JS/CSS
             + 5 drifted alternate layouts (see drift #13)
sections/    58 files. main-*.liquid = a page's real content.
             Custom: separator, dual-images, payment-methods, disclosures
             *-group.json = header/footer, theme-editor owned
snippets/    44 files. card-product.liquid is the product card design (~929 lines changed)
             shogun-*.liquid = auto-generated, do not edit
blocks/      ai_gen_block_f52c25c.liquid
assets/      flat, no build step. base.css (global + brand tokens),
             component-*.css, section-*.css, template-*.css, ~90 icon-*.svg
             global.js + per-feature JS loaded by the section that needs it
templates/   85 + 7 customer. JSON = merchandising, theme-editor owned
config/      settings_data.json (all design settings), settings_schema.json
locales/     30 buyer + 21 schema. en.default.json is default; it.json has the overrides
```

**Adding CSS:** sections load their own with
`{{ 'section-foo.css' | asset_url | stylesheet_tag }}` at the top of the liquid
file (see `sections/main-product.liquid`, `sections/main-collection-product-grid.liquid`).
Global-only rules go in `base.css`. No preprocessor, no bundler — files upload as-is.

**Heavily modified Dawn files — expect conflicts on upstream sync:**
`sections/main-product.liquid` (effectively rewritten), `snippets/card-product.liquid`
(~929 lines), `sections/main-collection-product-grid.liquid`, `assets/component-cart-items.css`
(+257, rewritten), `assets/global.js` (+158), `assets/cart.js` (+144), `assets/facets.js` (+121),
`assets/base.css` (+117), `sections/header.liquid`, `snippets/facets.liquid`.

For the page-by-page "what URL, what file" map, see
[`PREVIEW.md`](PREVIEW.md#page--file-map).
