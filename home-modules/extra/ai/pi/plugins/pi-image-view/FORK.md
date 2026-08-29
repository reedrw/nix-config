# Vendored fork of pi-image-view

Vendored copy of [pi-image-view](https://github.com/alchemistklk/pi-image-view)
(upstream 0.3.1, MIT) so UX tweaks can be made without relying on the
npm-published package. Loaded as a local pi package from
`~/.pi/agent/pi-image-view` (a home-manager symlink to this directory) via the
`packages` entry in `~/.pi/agent/settings.json`.

## Deviations from upstream

- `src/extension-runtime.ts`: pressing `ctrl+q` while images are attached to
  the editor toggles the next submission between the default 480p preview and
  1280px detail mode (same as `/pi-image-view detail`, without the command).
  The gallery header shows the armed state.
- `src/image-gallery.ts`: header shows the resolution the next submission will
  use plus the ctrl+q hint.

## Updating

To pull in a newer upstream release, replace this directory with the new
package contents (`index.ts`, `src/`, `package.json`, `README.md`,
`CHANGELOG.md`, `LICENSE`) and re-apply the deviations above.
