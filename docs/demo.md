# Demo scenario

Use this to record the README GIF with VHS, or reproduce the keystrokes in a
real TTT window.

## Setup

1. Install `ttt`, `ccn` (v0.27.0+) and Git.
2. Copy this repository to `<demo-workspace>/plugins/ttt-ccn`.
3. Put `demo/complex.c` and `demo/demo.c` in the workspace.
4. From the demo workspace, run `ttt . demo/complex.c`.

The checked-in review captures use TTT's `TTT_CONFIG_DIR` isolation so the
before/after sessions do not share plugin configuration.

## Review shot list

| Step | Screen | Action |
|---|---|---|
| 1 | File inspector | Open `complex.c`; drawer shows `max CCN 21 · 2 functions · 1 over 10` |
| 2 | Workspace review | `Alt+R` or `CCN: Review workspace`; `complex.c:classify L3` is first |
| 3 | Changed review | `CCN: Review changed (HEAD~1)`; row shows `+19` and the baseline revision |
| 4 | Agent brief | `CCN: Preview agent brief`; shows the metrics and source snippet |
| 5 | Copy | `CCN: Copy agent brief`; status says `CCN agent brief copied` |

The `demo/ttt-ccn.tape` file records the original file-inspector flow. Review
mode is captured in `docs/images/` from actual TTT sessions rendered from the
terminal buffer.

## Fixtures

- `demo/demo.c` — three low-complexity functions for the file list.
- `demo/complex.c` — `classify` at CCN 21, nesting 6; good for review mode.
- For changed review, commit a simple version of `complex.c`, then edit it into
  the CCN 21 version without committing.

Keep the GIF under ~5 MB. A silent, short loop works better than a narrated
screen recording for a plugin listing.

