# Roadmap

Ideas for Hangar Store, roughly in the order I would build them. Nothing here is
promised; open an issue if one of these matters to you.

Shipped items are listed in [CHANGELOG.md](CHANGELOG.md).

## Next

- **Custom catalog without editing code.** Read an optional
  `~/.config/omarchy/hangar-catalog.json` and merge it over `Catalog.js`, so your own
  picks survive plugin updates. The same hook could let people share "app packs".
- **Export and import.** Save the explicitly installed packages (`pacman -Qqe`) to a
  file and restore them on a new machine.

## Later

- **Dependency and orphan cleanup.** A "Clean up" action that lists orphans
  (`pacman -Qdtq`) and the package cache size, with a one-key remove.
- **Flatpak support.** Many apps (Spotify, some proprietary tools) are not in the
  repositories. It adds a second backend and a new trust surface, so it would be off
  by default, like the AUR.
- **Recently installed and favorites.** A small persisted list in the plugin's state
  directory. This would change the "keeps no files" promise in the README, so it needs
  an explicit opt-in.
- **Richer catalog entries.** Optional `url` and `screenshot` fields in `Catalog.js`.
## Publishing checklist

- Bump `version` in `manifest.json` for every release and tag it (`v1.2.0`).
- Add an entry to `CHANGELOG.md`.
- Refresh the screenshots in `docs/screenshots/` and `preview.png`. Restart the shell
  (`omarchy-restart-shell`) before capturing, because the shell caches plugin QML.
