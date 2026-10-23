# Changelog

## 0.2.0

- Added workspace review: every measured function sorted by CCN, with file/line
  navigation and a warning summary for functions over CCN 10.
- Added changed review against `HEAD~1` using `ccn --report-json`, including
  added/worsened kind and the CCN delta.
- Added `CCN: Preview agent brief` in the drawer.
- Added `CCN: Copy agent brief`: top functions, metrics, baseline reasons and
  capped source snippets as Markdown on the clipboard.
- Added `Alt+R`/`Alt+C`, `fs.read` (workspace) and `git` execution permissions.
- `CCN: Refresh` now refreshes whichever view is active.
- Added `demo/complex.c` (CCN 21) for review-mode testing.

## 0.1.0

- Initial TTT integration spike.
- Right-side CCN drawer for the active file.
- Function list sorted by CCN with click-to-line navigation.
- Auto-open on the first supported file; refresh on open/save.
- `CCN: Open inspector`, `CCN: Refresh`, `CCN: Close inspector`.
- `Ctrl+K C` keybinding and status item.
- Missing `ccn` and `untitled` errors are reported in the drawer.

