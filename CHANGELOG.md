# Changelog

## 1.2.1

Listing and documentation only; the plugin's behavior is unchanged.

- **A short description.** The manifest description, shown on the marketplace card, is one sentence: "A themed app store for Omarchy: browse, search and install with one key."
- **A new preview image.** `preview.png` is now a 1920x1080 poster with three real views: Featured, an AUR search with trust warnings, and the Bundles tab.
- **README first screen.** A one-line pitch, the new image and a short "Why you will want it" list before the screenshot gallery.

## 1.2.0

### Added
- **Bundles tab.** Six starter packs: Dev setup, Creative, Media center, Office,
  Privacy and Gaming. `Insert` or a click queues every missing app in a pack,
  `Enter` or **Install all** installs them. Packages that your repositories do not
  have are left out. Pack contents live in `Catalog.js`.
- **Real icons.** Installed apps show the icon from their `.desktop` file. Icons the
  theme cannot find fall back to the letter tile instead of a placeholder.
- **Launch.** Installed apps with a desktop entry get a **Launch** button and
  `Ctrl+L` (also in the detail view). Terminal apps are not launchable.
- `test/model.test.js` covers the desktop-entry parser and the bundle logic.

### Changed
- Cards for launchable apps show a shorter meta line to make room for the button.

## 1.1.0

### Added
- **Updates tab.** Lists pending repository updates (`checkupdates`) and AUR updates
  (`yay -Qua`), with a count on the chip. `Enter` or the "Update all" button runs
  `omarchy-update`. Arch does not support partial upgrades, so there is deliberately
  no per-package update. `Ctrl+R` rechecks. Results are cached for five minutes.
- **Detail view.** `Ctrl+I` or right-click on a card shows the full description,
  source, version, license, download and installed size, dependencies, optional
  dependencies and homepage. `Ctrl+O` opens the homepage. For AUR packages it also
  shows maintainer, votes, popularity and first/last update dates.
- **AUR trust signals.** AUR cards and the detail view flag packages that are
  out of date, orphaned (no maintainer) or stale (not updated for two years), with a
  warning badge on the icon and a plain-language explanation in the detail view.
- **Sorting.** `Ctrl+S` cycles Default, Name, Size and Votes. The current mode is
  shown next to the AUR badge.

### Changed
- Card meta line now has the full card width, so versions and warnings are no longer
  cut off.

## 1.0.0

Initial release: curated catalog, repository and AUR search, install queue, installed
state, removal, theme following.
