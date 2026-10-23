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
+    "description": "McCabe complexity and function inspector for the active source file, backed by the ccn binary",
+    "repo": "https://github.com/Shinick-Han/ttt-ccn",
+    "version": "0.1.0",
+    "tags": ["complexity", "ccn", "mccabe", "c", "cpp", "rust", "code-review", "eda"]
+  }
```

`featured` is maintainer-curated. The PR may ask for consideration, but the
entry should remain `featured: false` unless the maintainer adds it.

## Suggested PR title

```text
Add CCN Complexity plugin (McCabe inspector for active file)
```

## Suggested PR body

```markdown
## Plugin

- Repo: https://github.com/Shinick-Han/ttt-ccn
- Version: 0.1.0
- TTT requirement: v1.9.0+
- External requirement: ccn v0.27.0+ on PATH

## What it does

Adds a right-side "CCN" drawer for the active source file. It runs
`ccn <file> --json` asynchronously and shows the file's max CCN, function
count, `>10` count, and a clickable function list. A status item shows
`CCN <max> · <n> hot`.

The plugin requests only drawer/commands/keybindings/editor read/file events
and allow-listed execution of `ccn`; it does not write files or use the
network.

## Verification

- Tested against TTT v1.9.0 on Windows.
- Tested with a small C fixture: drawer shows `max CCN 4 · 3 functions`,
  function rows `process L3 4`, `simple L12 1`, `main L14 1`.
- Missing `ccn` and unsaved `untitled` buffers fail with a message rather than
  crashing.
```

## After merge

The plugin should appear in the **Plugins → Search** list and can be installed
without a URL. Bump `version` in `plugin.ttt.json` and the registry entry
together for later releases.
