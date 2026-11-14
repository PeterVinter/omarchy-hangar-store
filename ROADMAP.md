# Roadmap

Ideas for Hangar Store, roughly in the order I would build them. Nothing here is
promised; open an issue if one of these matters to you.

Shipped items are listed in [CHANGELOG.md](CHANGELOG.md).

## Next

- **Custom catalog without editing code.** Read an optional
  `~/.config/omarchy/hangar-catalog.json` and merge it over `Catalog.js`, so your own
  picks survive plugin updates. The same hook could let people share "app packs".
- **Bundles / starter packs.** One-key install sets such as "Creative workstation",
  "Dev setup" or "Gaming". A bundle simply fills the install queue.
- **Export and import.** Save the explicitly installed packages (`pacman -Qqe`) to a
  file and restore them on a new machine.

## Later

- **Dependency and orphan cleanup.** A "Clean up" action that lists orphans
  (`pacman -Qdtq`) and the package cache size, with a one-key remove.
- **Flatpak support.** Many apps (Spotify, some proprietary tools) are not in the
  repositories. It adds a second backend and a new trust surface, so it would be off
  by default, like the AUR.
- **Real icons.** Resolve the icon from the package's `.desktop` file
  (`pacman -Ql pkg`, then `Icon=`) and fall back to the letter tile.
- **Recently installed and favorites.** A small persisted list in the plugin's state
  directory. This would change the "keeps no files" promise in the README, so it needs
  an explicit opt-in.
- **Richer catalog entries.** Optional `url` and `screenshot` fields in `Catalog.js`.
- **Post-install actions.** Offer "Launch" once an install finishes, using
  `gtk-launch` or `uwsm app`.

## Publishing checklist

- Bump `version` in `manifest.json` for every release and tag it (`v1.1.0`).
- Add an entry to `CHANGELOG.md`.
- Refresh the screenshots in `docs/screenshots/`.
