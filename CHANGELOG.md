# Changelog

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
