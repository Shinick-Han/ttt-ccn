# ttt-ccn

**McCabe complexity and function inspection inside [TTT](https://github.com/eugenioenko/ttt).**

TTT already provides the terminal IDE: editor, LSP, Git, terminal, file tree and
a right-side drawer. This plugin adds a CCN inspector for the active file by
running the [`ccn`](https://github.com/Shinick-Han/ccn) binary.

```text
CCN · main.c
max CCN 4 · 3 functions · 0 over 10
┌─────────────────────────────────────┐
│ process  L3   4                     │
│ simple   L12  1                     │
│ main     L14  1                     │
└─────────────────────────────────────┘
```

Click a function to jump to its line. The drawer refreshes after opening or
saving a file and adds a compact `CCN <max> · <n> hot` status item.

## Requirements

- TTT **v1.9.0+**
- ccn **v0.27.0+** on `PATH`:
  - `npm install -g @shinick/ccn`
  - or download a release from <https://github.com/Shinick-Han/ccn/releases>
- A supported source file: C, C++, C#, Go, Java, JavaScript/JSX, Python, Rust,
  TypeScript/TSX.

Verify ccn first:

```console
$ ccn --version
$ ccn doctor
```

## Install

### TTT Plugins panel

Once the plugin is included in TTT's community registry, open the **Plugins**
sidebar tab, search for `CCN`, and install. The first load asks for approval of
the permissions listed below.

### Install from URL

In TTT: `Ctrl+P` → **Plugins: Install from URL**

```text
https://github.com/Shinick-Han/ttt-ccn
```

### Manual

User-wide:

```powershell
# Windows (run inside the cloned ttt-ccn directory)
$dest = "$HOME\.config\ttt\plugins\ttt-ccn"
New-Item -ItemType Directory $dest -Force | Out-Null
Copy-Item .\* $dest -Recurse -Force
```

```sh
# Linux / macOS
mkdir -p ~/.config/ttt/plugins
cp -R . ~/.config/ttt/plugins/ttt-ccn
```

Workspace-local:

```powershell
New-Item -ItemType Directory .\plugins -Force
Copy-Item -Recurse C:\path\to\ttt-ccn .\plugins\ttt-ccn
```

Then start TTT from the workspace:

```console
$ ttt . src/main.c
```

The inspector opens automatically for the first supported source file. Use
`Esc` to close the drawer.

## Commands and keys

| Input | Action |
|---|---|
| `Ctrl+K C` | Open the CCN inspector |
| `Ctrl+P` → `CCN: Open inspector` | Open/reopen the drawer |
| `Ctrl+P` → `CCN: Refresh` | Re-run ccn for the active file |
| `Ctrl+P` → `CCN: Close inspector` | Close the drawer |
| `Esc` | Close the drawer |
| Click a function row | Jump to that function's line |
| `Ctrl+Q` | Quit TTT |

## How it works

1. TTT reports the active file path.
2. The plugin runs `ccn <absolute-path> --json` asynchronously.
3. It reads the file-level `ccn.max`, `ccn.over_10` and `ccn.detail` fields.
4. The function list is sorted by CCN and rendered in a right drawer.

It does not write files, access the network, or change the editor buffer. The
manifest requests only:

- `panel.drawer`
- `commands`
- `keybindings`
- `editor.read`
- `events.file`
- `system.exec` for `ccn` / `ccn.exe`

## Demo

A 15-second recording outline lives in [`docs/demo.md`](docs/demo.md). It shows:

```text
open a C file → right CCN drawer → click the hottest function → save → refresh
```

`demo/demo.c` is the small fixture used by the recording; `demo/ttt-ccn.tape`
can regenerate the GIF with [VHS](https://github.com/charmbracelet/vhs).

## Limitations

This is an inspector, not a full CCN review product yet.

- File-level detail only; no repository-wide review queue in the drawer.
- No baseline, Perforce changelist, or review comments yet.
- ccn's grammar support and heuristic limits apply unchanged.
- An unsaved `untitled` buffer is reported as an error rather than analyzed.

The next planned steps are a changed-file review drawer, baseline/P4 support,
and opening the diff for a hot function from the inspector.

## Development

```console
$ ttt . src/main.c
```

Use **Plugins: Reload** after editing `init.lua`. A workspace-local copy is the
fastest development loop; do not edit the installed user copy.

## License

MIT. See [LICENSE](LICENSE).
