# Demo scenario (15 seconds)

Use this to record the README GIF with VHS. It should show the problem and the
result without narration.

## Setup

1. Install `ttt` and `ccn`.
2. Copy this repository to `<demo-workspace>/plugins/ttt-ccn`.
3. Put `demo/demo.c` at `<demo-workspace>/demo/demo.c`.
4. From the demo workspace, run `vhs demo/ttt-ccn.tape` (from this repo) or
   reproduce the keystrokes manually.

The checked-in `docs/images/ttt-ccn-demo.gif` was captured from actual TTT
windows using `TTT_CONFIG_DIR` isolation, then rendered from the terminal
buffer. It shows TTT alone, the auto-opened CCN drawer, closing with `Esc`,
`Ctrl+P` → `CCN: Open inspector`, and the reopened drawer.

## Shot list

| Time | Screen | Action |
|---|---|---|
| 0-2s | TTT with `demo.c` open, CCN drawer on the right | Start on the finished view; no setup |
| 2-4s | Drawer shows `max CCN 4 · 3 functions · 0 over 10` | Hold so it is readable |
| 4-7s | Function list | Move selection to `process L3 4` |
| 7-9s | Editor jumps to line 3 | Click/Enter the `process` row |
| 9-12s | Save (`Ctrl+S`) | Drawer status briefly shows `CCN ...`, then settles |
| 12-15s | Finished state | Hold on the drawer + function list |

## README copy

The static screenshot in the README is intentionally text-first:

```text
CCN · main.c
max CCN 4 · 3 functions · 0 over 10

process  L3  4
simple   L12 1
main     L14 1
```

Keep the GIF under ~5 MB. A silent, short loop works better than a narrated
screen recording for a plugin listing.
