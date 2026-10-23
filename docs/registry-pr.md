# TTT community registry PR

The TTT plugin browser reads entries from `community-plugins.json` in
[eugenioenko/ttt](https://github.com/eugenioenko/ttt). To list this plugin:

1. Fork `eugenioenko/ttt`.
2. Add the entry from `contrib/community-plugins-entry.json` to
   `community-plugins.json` (keep the array sorted by name if the file already
   is).
3. Open a pull request.

## Entry diff

```diff
+  {
+    "name": "ttt-ccn",
+    "displayName": "CCN Complexity",
+    "author": "Shinick-Han",
+    "description": "Workspace complexity review, changed-function review, and agent briefs backed by the ccn binary",
+    "repo": "https://github.com/Shinick-Han/ttt-ccn",
+    "version": "0.2.0",
+    "tags": ["complexity", "ccn", "mccabe", "c", "cpp", "rust", "code-review", "eda"]
+  }
+```

`featured` is maintainer-curated. The PR may ask for consideration, but the
entry should remain `featured: false` unless the maintainer adds it.

## Suggested PR title

```text
Add CCN Complexity plugin (workspace review + agent brief)
```

## Suggested PR body

```markdown
## Plugin

- Repo: https://github.com/Shinick-Han/ttt-ccn
- Version: 0.2.0
- TTT requirement: v1.9.0+
- External requirement: ccn v0.27.0+ on PATH; Git for changed review

## What it does

Adds three complexity-review surfaces inside TTT:

- file inspector for the active source file
- workspace review: every measured function sorted by CCN, click to jump
- changed review: functions added or worsened since `HEAD~1`
- agent brief: top functions, metrics, baseline reasons and capped source
  snippets copied as Markdown

The plugin requests drawer/commands/keybindings/editor read/file events,
workspace file reads for snippets, and allow-listed execution of `ccn` and
`git`. It does not write files or use the network.

## Verification

- Tested against TTT v1.9.0 on Windows.
- `demo/complex.c` contains a CCN 21 function; file mode reports
  `max CCN 21 · 2 functions · 1 over 10`.
- Workspace review lists `complex.c:classify L3 21` first.
- Changed review against a committed simple version reports `+19`.
- `CCN: Preview agent brief` renders the snippet without leaving TTT.
- Missing `ccn`, non-Git workspaces and unsaved buffers fail with a message
  rather than crashing.
```

## After merge

The plugin should appear in the **Plugins → Search** list and can be installed
without a URL. Bump `version` in `plugin.ttt.json` and the registry entry
together for later releases.
