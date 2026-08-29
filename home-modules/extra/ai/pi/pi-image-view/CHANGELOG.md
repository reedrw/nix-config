# Changelog

All notable changes to `pi-image-view` are documented here. This project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.3.1 — 2026-08-27

Package discovery artwork and an evidence-backed 480px quality baseline. No runtime behavior changes.

### Added

- A privacy-safe Before/After Gallery image and stable `pi.image` metadata for pi.dev package cards and details.
- A deterministic OCR benchmark harness plus a clean 48-trial source/480px/1280px baseline across Luna and Sol. The result keeps 480px as the ordinary default, retains explicit `/pi-image-view detail` for dense diagrams, and does not enable automatic escalation.

### Changed

- The README now opens with the new Gallery artwork using an absolute GitHub URL that renders correctly on npm.
- The Gallery image was rebuilt from a reproducible HTML card and reduced to a 1600×900 privacy-safe asset.

## 0.3.0 — 2026-08-27

Native Linux clipboard support and load-order-independent Zentui composition.

### Added

- Native Linux direct clipboard support: Wayland `wl-paste`, X11 `xclip`, and text-only X11 `xsel`. Detection is asynchronous, commands use bounded `execFile` calls, and unavailable commands, MIME targets, or reads fall back to Pi's built-in paste path. `xsel` is text-only because its `-t` flag is a retrieval timeout, not a MIME-target selector, so [Issue #7](https://github.com/alchemistklk/pi-image-view/issues/7) stays open pending an acceptance-criteria update and a real Wayland/X11 probe.

### Fixed

- `pi-zentui` 0.21.0 editor composition is **provisionally** load-order independent: image-view enhances an existing editor instance in place, preserves Zentui ownership metadata, and removes nested editor factories safely during forward-ordered shutdown. A forwarding wrapper that does not own its editing state is declined rather than decorated, so the host's submit and paste callbacks keep reaching the real editor. Verified by fixtures only; [Issue #1](https://github.com/alchemistklk/pi-image-view/issues/1) stays open until a real pi-zentui install is attested in both orders.

## 0.2.2 — 2026-08-27

Session-global image IDs and Pi package peer alignment.

### Added

- `[Image #N]` numbering now increases across turns and resumes from the active session branch after reload, resume, or fork.
- Marker allocation skips IDs already present in the current draft and ignores marker-like assistant text when restoring the counter.

### Changed

- Pi core packages are declared as wildcard peers, matching Pi package guidance. Pi's installer provides these from the host and does not install a duplicate runtime.
- Pi 0.84.3 remains the tested host; private atomic-editor seams are feature-checked at runtime instead of using peer semver as an ineffective compatibility gate.

## 0.2.1 — 2026-08-26

Documentation and package metadata only. No runtime code changes.

### Changed

- The README opens with the before/after the extension exists for, states when to
  use it, front-loads command/key/limit reference tables, and phrases
  troubleshooting entries as the symptom rather than the mechanism.
- The npm `description` states the job and carries the terms people search with
  (screenshot, clipboard, paste) instead of describing the mechanism.
- `keywords` expanded from 8 to 23. `pi-package` is retained — the pi.dev gallery
  indexes on it.
- `CHANGELOG.md` ships in the npm tarball.

`0.2.0` was published with the previous description and keywords, and npm does not
allow republishing a version, so this patch release exists to correct the listing.

## 0.2.0 — 2026-08-26

Direct clipboard paste, atomic `[Image #N]` markers, and a one-shot detail mode.

### Added

- **Direct clipboard paste** on macOS, Windows, and WSL. The extension reads image
  clipboard data itself, so Pi never renders a temporary path — `[Image #N]` appears
  immediately. Reads run as bounded asynchronous `execFile` calls and no longer block
  the TUI. Native Linux keeps Pi's default editor and paste-triggered burst scans.
- **Atomic markers.** `←`/`→` jump across a whole `[Image #N]` marker and
  `Backspace`/`Delete` remove it in one undoable action, instead of editing it one
  character at a time.
- **`/pi-image-view detail`** arms the next image batch at 1280px for small text and
  dense diagrams, then reverts to the 480px default automatically.
- **Windows path support.** Drive paths (`C:\...`) and UNC paths (`\\host\share\...`)
  are detected, and drive paths are translated to `/mnt/<drive>/...` under WSL.
- **`~/`, `./`, and `../` paths** are expanded, with `./` and `../` resolved against
  the active Pi session cwd.
- Punctuation directly after an unquoted path no longer swallows the path.
- A [comparison of the Pi image extensions](docs/research/pi-image-plugin-comparison.md)
  covering `pi-image-preview`, `pi-paster`, and `pi-screenshots-picker`.

### Fixed

- Clipboard paste no longer attaches an image to the wrong turn. A read that resolves
  after the draft was submitted is dropped, overlapping pastes are serialized, and a
  failed read is logged instead of raising an unhandled rejection that would end the
  session.
- Shell escapes are resolved before the `~` and `./` prefixes are interpreted, so a
  path dragged in from a file manager (`~/My\ Photo.png`) reads correctly.
- Non-PNG images are no longer sent through Kitty's `f=100` transmission, which
  accepts PNG only and rendered them as a blank block. The gallery falls back to text.
- Whole-marker deletion now requires a verified undo snapshot seam, so an atomic
  delete is always undoable.
- On shutdown the extension restores the editor factory it displaced, and only when it
  still owns the active one — it no longer clears an editor installed by another
  extension.
- The clear boundary is rebased across compacted context prefixes, so
  `/pi-image-view clear` stays anchored after compaction.
- Word and grapheme segmentation is preserved outside atomic image markers.

### Changed

- Atomic-editor compatibility is tested against Pi 0.84.3. Private undo support is feature-checked at runtime and falls back to normal deletion when unavailable.

### Known limitations

- **`pi-zentui` load order.** Load `pi-image-view` before `pi-zentui` so Zentui wraps
  the image-view editor; the reverse order can destabilize editor/status
  reconciliation. Tracked in [#1](https://github.com/alchemistklk/pi-image-view/issues/1),
  not yet fully resolved.
- **Kitty fallback is all-or-nothing.** A single non-PNG image downgrades the whole
  gallery to text. This only happens when PNG conversion fails.
- **Clipboard read timeouts** (1500 ms macOS, 2500 ms Windows) have not been measured
  against a cold PowerShell start, where `-STA` plus `Add-Type` can approach 2 s. A
  timeout degrades silently to the text clipboard.
- **Automatic blob deletion stays disabled.** See
  [Blob lifecycle](README.md#blob-lifecycle).

### Validation

- 59 automated tests across 12 files
- 0 production dependency vulnerabilities (`npm audit --omit=dev`)
- `npm pack --dry-run` and `npm publish --dry-run --access public` pass
- Isolated Pi load probe passes
- Direct marker paste and atomic deletion confirmed by a real user on macOS

## 0.1.0 — 2026-08-26

First release, forked from
[RielJ/pi-image-preview](https://github.com/RielJ/pi-image-preview).

### Added

- Replaces temporary clipboard paths with `[Image #N]`
- Keeps clickable image references in restored conversation history
- Submits best-effort 480px PNG thumbnails to reduce model payload size
- Stores submitted thumbnails as SHA-256 content-addressed local blobs
- Strips local `file://` targets from model-facing context
- Deduplicates Pi-preprocessed and path-discovered attachments
- Kitty and tmux inline draft previews
- Non-destructive `/pi-image-view clear` for long sessions
