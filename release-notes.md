Adds support for standard storefront events and a new section and block to display product disclosures.

### Added

- [Storefront Events & Actions] Added support for app, agent, and AI cart interactions without page reloads.
- [Product disclosures] New section and block to display product disclosures on product pages.

### Fixes and improvements

- [Accessibility] Fixed aria labels and focus management on search and filtering components
- [Performance] Changed body layout styles for improved cumulative layout shift (CLS)
- Fixed missing theme setting translation strings in "Icons with Text" section
Dawn 15.1.0 changes the way SVGs are rendered
### Fixes and improvements
- Moves SVGs from Liquid snippets to `.svg` files in the `/assets` folder
- Uses new `inline_asset_content` Liquid filter to render SVGs
Dawn 15.0.1 introduces a few bug fixes.

### Fixes and improvements

- Fix issues where when the header section is hidden, some functionalities were broken.
- Update cart errors to be output as a string rather than a HTML element.
- Escape variant option names so that when an option includes quotation marks it doesn’t cause undesired effects.
- Fix placeholder product cards that were not showing a default price and make the check more robust.
