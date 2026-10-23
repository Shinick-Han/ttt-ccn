-- CCN inspector for TTT.
--
-- TTT owns the editor, LSP, Git, terminal and layout; ccn owns the analysis.
-- The plugin has two surfaces:
--   * file inspector: functions in the active file
--   * review: workspace hotspots, or functions newly worsened since a baseline
-- The review drawer can also copy a compact Markdown brief for an agent.

local ttt = require("ttt")
local sys = require("ttt.system")
local events = require("ttt.events")
local editor = require("ttt.editor")
local json = require("ttt.json")
local fs = require("ttt.fs")

local THRESHOLD = 10
local MAX_ROWS = 60
local MAX_BRIEF_FUNCTIONS = 8
local MAX_BRIEF_LINES = 100

local function supported(path)
  return path:match("%.([%w]+)$") ~= nil and ({
    c = true, h = true, cc = true, cpp = true, cxx = true, hpp = true,
    cs = true, go = true, java = true, js = true, jsx = true, mjs = true,
    py = true, rs = true, ts = true, tsx = true,
  })[(path:match("%.([%w]+)$") or ""):lower()] == true
end

local auto_opened = false

local function is_untitled(path)
  return path == nil or path == "" or path == "untitled"
end

local function trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function basename(path)
  return path:match("([^/\\]+)$") or path
end

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]+$") or "."
end

local function compact_dir(path)
  local parent = dirname(path)
  if parent == "." then return basename(path) end
  return basename(parent) .. "/" .. basename(path)
end

local function path_join(root, rel)
  if rel == nil or rel == "" then return root end
  if rel:match("^%a:[/\\]") or rel:sub(1, 1) == "/" or rel:sub(1, 1) == "\\" then
    return rel
  end
  return (root:gsub("[/\\]+$", "")) .. "/" .. (rel:gsub("^[/\\]+", ""))
end

local function short_path(path, max)
  if #path <= max then return path end
  return "..." .. path:sub(#path - max + 4)
end

local function language(path)
  local ext = (path:match("%.([%w]+)$") or ""):lower()
  return ({
    c = "c", h = "c", cc = "cpp", cpp = "cpp", cxx = "cpp", hpp = "cpp",
    cs = "csharp", go = "go", java = "java", js = "javascript",
    jsx = "javascript", mjs = "javascript", py = "python", rs = "rust",
    ts = "typescript", tsx = "tsx",
  })[ext] or ""
end

local function split_lines(text)
  local out = {}
  text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(out, line)
  end
  return out
end

local state = {
  mode = "file",
  path = "",
  file = "",
  error = nil,
  loading = false,
  ccn_max = nil,
  over_10 = nil,
  functions = {},
  review = {
    root = "",
    rev = "",
    functions = {},
    total = 0,
    files = 0,
    over_10 = 0,
    changed = false,
    complete = true,
  },
}

local drawer_panel = nil

local function set_status(text)
  pcall(ttt.set_status_item, "right", "ccn", text, {
    priority = 120,
    on_click = function()
      if state.mode == "file" then
        ttt.exec_command("ccn.inspector")
      else
        ttt.exec_command("ccn.review")
      end
    end,
  })
end

local function workspace_root()
  local ok, result = pcall(sys.exec, "git", { "rev-parse", "--show-toplevel" })
  if ok and result and result.exit_code == 0 then
    local root = trim(result.stdout)
    if root ~= "" then return root end
  end
  local path = editor.file_path()
  if not is_untitled(path) then return dirname(path) end
  return nil
end

-- ---------------------------------------------------------------- file view

local function refresh_file()
  local path = editor.file_path()
  if path == nil or path == "" then
    state.path = ""
    state.file = ""
    state.error = "No active file"
    state.functions = {}
    if drawer_panel ~= nil then drawer_panel:redraw() end
    set_status("CCN --")
    return
  end

  state.path = path
  state.file = basename(path)
  state.error = nil
  state.loading = true
  set_status("CCN ...")
  if drawer_panel ~= nil then drawer_panel:redraw() end

  sys.exec_async("ccn", { path, "--json" }, function(result)
    state.loading = false
    if result.exit_code ~= 0 then
      local detail = result.stderr ~= "" and result.stderr or result.stdout
      if detail and detail:lower():match("not found") then
        state.error = "ccn not found. Install @shinick/ccn and put ccn on PATH."
      else
        state.error = "ccn failed: " .. (detail or "unknown error")
      end
      state.functions = {}
      state.ccn_max = nil
      set_status("CCN !")
    else
      local scan, decode_error = json.decode(result.stdout)
      if not scan then
        state.error = "ccn JSON: " .. tostring(decode_error)
        state.functions = {}
        state.ccn_max = nil
        set_status("CCN !")
      else
        local file = nil
        for _, candidate in ipairs(scan.files or {}) do
          if candidate.path == state.file or candidate.path == path
              or basename(candidate.path) == state.file then
            file = candidate
            break
          end
        end
        if file == nil and scan.files and scan.files[1] then
          file = scan.files[1]
        end

        state.functions = {}
        state.ccn_max = file and file.ccn and file.ccn.max or nil
        state.over_10 = file and file.ccn and file.ccn.over_10 or nil
        if file and file.ccn and file.ccn.detail then
          for _, fn in ipairs(file.ccn.detail) do
            table.insert(state.functions, fn)
          end
          table.sort(state.functions, function(a, b)
            if a.ccn == b.ccn then return (a.line or 0) < (b.line or 0) end
            return a.ccn > b.ccn
          end)
        end
        if state.ccn_max ~= nil then
          set_status(string.format("CCN %s · %d hot", tostring(state.ccn_max), state.over_10 or 0))
        else
          set_status("CCN --")
        end
      end
    end
    if drawer_panel ~= nil then drawer_panel:redraw() end
  end)
end

-- -------------------------------------------------------------- review view

local function sort_functions(functions)
  table.sort(functions, function(a, b)
    if a.ccn == b.ccn then
      if a.path == b.path then return (a.line or 0) < (b.line or 0) end
      return a.path < b.path
    end
    return (a.ccn or 0) > (b.ccn or 0)
  end)
end

local function function_name(fn)
  if fn.name ~= nil and fn.name ~= "" then return fn.name end
  if fn.identity ~= nil and fn.identity ~= "" then return fn.identity end
  return "(anonymous)"
end

local function reset_review(mode, rev)
  state.mode = mode
  state.error = nil
  state.loading = true
  state.review.root = workspace_root() or ""
  state.review.rev = rev or ""
  state.review.functions = {}
  state.review.total = 0
  state.review.files = 0
  state.review.over_10 = 0
  state.review.changed = mode == "changed"
  state.review.complete = true
  if state.review.root == "" then
    state.loading = false
    state.error = "Open a file in a workspace, or run TTT from a Git repository."
  end
  if drawer_panel ~= nil then drawer_panel:redraw() end
end

local function apply_workspace(scan, root)
  local functions = {}
  for _, file in ipairs(scan.files or {}) do
    if file.ccn and file.ccn.detail then
      for _, fn in ipairs(file.ccn.detail) do
        table.insert(functions, {
          path = file.path,
          abs = path_join(root, file.path),
          name = fn.name,
          identity = fn.identity,
          line = fn.line,
          end_line = fn.end_line,
          ccn = fn.ccn,
          nloc = fn.nloc,
          params = fn.params,
          max_nesting = fn.max_nesting,
        })
      end
    end
  end
  sort_functions(functions)
  state.review.functions = functions
  state.review.total = scan.functions_total or #functions
  state.review.files = scan.files_analyzed or #(scan.files or {})
  state.review.over_10 = (scan.ccn and scan.ccn.over_10) or 0
  state.review.changed = false
  state.review.complete = true
end

local function apply_changed(report)
  local baseline = report.baseline
  if baseline == nil then
    state.error = "ccn returned no baseline. Run this inside a Git repository."
    state.review.functions = {}
    return
  end

  local functions = {}
  for _, change in ipairs(baseline.changes or {}) do
    table.insert(functions, {
      path = change.path,
      abs = path_join(state.review.root, change.path),
      name = change.name,
      identity = change.identity,
      line = change.line,
      end_line = (change.line or 1) + (change.nloc or 0),
      ccn = change.ccn,
      base_ccn = change.base_ccn,
      kind = change.kind,
      reasons = change.reasons or {},
      nloc = change.nloc,
      max_nesting = change.max_nesting,
    })
  end
  sort_functions(functions)
  state.review.functions = functions
  state.review.total = #functions
  state.review.files = baseline.files_compared or 0
  state.review.over_10 = #functions
  state.review.complete = baseline.complete ~= false
  state.review.rev = baseline.rev or state.review.rev
  state.review.changed = true
end

local function review_scan(mode, rev)
  reset_review(mode, rev or "HEAD~1")
  if state.error ~= nil then
    set_status("CCN !")
    return
  end

  local root = state.review.root
  local args
  if mode == "changed" then
    args = { root, "--report-json", "--baseline", state.review.rev }
    set_status("CCN changed ...")
  else
    args = { root, "--json" }
    set_status("CCN review ...")
  end

  sys.exec_async("ccn", args, function(result)
    state.loading = false
    if result.exit_code ~= 0 then
      local detail = result.stderr ~= "" and result.stderr or result.stdout
      state.error = "ccn failed: " .. (detail or "unknown error")
      state.review.functions = {}
      set_status("CCN !")
    else
      local data, decode_error = json.decode(result.stdout)
      if not data then
        state.error = "ccn JSON: " .. tostring(decode_error)
        state.review.functions = {}
        set_status("CCN !")
      else
        if mode == "changed" then
          apply_changed(data)
        else
          apply_workspace(data, root)
        end
        if state.error == nil then
          set_status(string.format("CCN review · %d hot", state.review.over_10 or 0))
        end
      end
    end
    if drawer_panel ~= nil then drawer_panel:redraw() end
  end)
end

local function build_brief()
  local review = state.review
  local out = {
    "# CCN review brief",
    "",
    "Root: `" .. review.root .. "`",
    "Mode: " .. (review.changed and ("changed since `" .. review.rev .. "`") or "workspace hotspots"),
    "",
    string.format("Functions: %d · over %d: %d", review.total, THRESHOLD, review.over_10),
    "",
    "Use the snippets as pre-processed context. Verify before editing.",
    "",
  }

  if #review.functions == 0 then
    table.insert(out, "No functions matched this review.")
    return table.concat(out, "\n")
  end

  local shown = math.min(#review.functions, MAX_BRIEF_FUNCTIONS)
  for i = 1, shown do
    local fn = review.functions[i]
    table.insert(out, string.format("## %d. `%s:%s` — CCN %d", i, fn.path, function_name(fn), fn.ccn or 0))
    local metric = string.format(
      "- line %s, %s nloc, nesting %s",
      tostring(fn.line or 0), tostring(fn.nloc or 0),
      tostring(fn.max_nesting or 0)
    )
    if fn.params ~= nil then
      metric = metric .. string.format(", %s params", tostring(fn.params))
    end
    table.insert(out, metric)
    if fn.kind ~= nil then
      table.insert(out, string.format("- %s (base CCN %s)", tostring(fn.kind), tostring(fn.base_ccn or 0)))
    end
    if #(fn.reasons or {}) > 0 then
      table.insert(out, "- reasons: " .. table.concat(fn.reasons, ", "))
    end

    local ok, source = pcall(fs.read, fn.abs)
    if ok and type(source) == "string" then
      local lines = split_lines(source)
      local start_line = math.max(1, (fn.line or 1) - 1)
      local end_line = math.min(#lines, (fn.end_line or fn.line or 1) + 1)
      local truncated = false
      if end_line - start_line + 1 > MAX_BRIEF_LINES then
        end_line = start_line + MAX_BRIEF_LINES - 1
        truncated = true
      end
      table.insert(out, "```" .. language(fn.path))
      for line = start_line, end_line do
        table.insert(out, lines[line])
      end
      table.insert(out, "```")
      if truncated then
        table.insert(out, string.format("_(truncated at %d lines)_", MAX_BRIEF_LINES))
      end
    else
      table.insert(out, "_(source unavailable: " .. tostring(source) .. ")_")
    end
    table.insert(out, "")
  end

  if #review.functions > shown then
    table.insert(out, string.format("(%d more functions omitted)", #review.functions - shown))
  end
  return table.concat(out, "\n")
end

local function copy_brief()
  if state.review.root == "" then
    pcall(ttt.notify, "Run CCN review first")
    return
  end
  local brief = build_brief()
  local ok, err = pcall(ttt.clipboard_write, brief)
  if ok then
    pcall(ttt.notify, "CCN agent brief copied")
    pcall(ttt.log, "CCN agent brief copied (" .. tostring(#brief) .. " bytes)")
  else
    pcall(ttt.notify, "CCN brief failed: " .. tostring(err))
    pcall(ttt.log, "CCN brief failed: " .. tostring(err))
  end
end

-- --------------------------------------------------------------- rendering

local function render_file(panel)
  panel:title({ text = "CCN", badge = state.file })

  if state.loading then
    panel:label({ text = "Analyzing " .. state.file .. " ...", style = "muted" })
    return
  end
  if state.error then
    panel:label({ text = state.error, style = "danger" })
    panel:label({ text = "Run `ccn doctor` or check PATH.", style = "muted" })
    panel:button({ label = "Retry", on_click = refresh_file })
    return
  end
  if state.path == "" then
    panel:label({ text = "Open a supported source file.", style = "muted" })
    return
  end

  panel:label({
    text = string.format("max CCN %s · %d functions · %d over %d", tostring(state.ccn_max), #state.functions, state.over_10 or 0, THRESHOLD),
    style = "muted",
  })
  panel:button({ label = "Refresh", on_click = refresh_file })
  panel:button({ label = "Review workspace", on_click = function()
    ttt.exec_command("ccn.review")
  end })
  panel:divider()

  if #state.functions == 0 then
    panel:label({ text = "No function-level CCN in this file.", style = "muted" })
    return
  end

  local items = {}
  for _, fn in ipairs(state.functions) do
    table.insert(items, {
      id = tostring(fn.line or 0),
      label = string.format("%s  L%s", function_name(fn), tostring(fn.line or 0)),
      badge = tostring(fn.ccn),
      icon = (fn.ccn or 0) > THRESHOLD and "!" or " ",
      muted = (fn.ccn or 0) <= THRESHOLD,
    })
  end
  panel:list({
    items = items,
    on_select = function(node)
      if state.path ~= "" then
        ttt.open_file(state.path, tonumber(node.id) or 1)
      end
    end,
  })
end

local open_review

local function render_brief(panel)
  panel:title({
    text = "CCN agent brief",
    badge = state.review.root ~= "" and basename(state.review.root) or "",
  })
  panel:markdown(build_brief())
  panel:button({ label = "Copy brief", on_click = copy_brief })
  panel:button({ label = "Back to review", on_click = function()
    open_review(state.review.changed and "changed" or "workspace", state.review.rev)
  end })
end

local function render_review(panel)
  local review = state.review
  panel:title({
    text = review.changed and "CCN changed" or "CCN review",
    badge = review.root ~= "" and basename(review.root) or "",
  })

  if state.loading then
    panel:label({ text = review.changed and ("Comparing against " .. review.rev .. " ...") or ("Scanning " .. short_path(review.root, 48) .. " ..."), style = "muted" })
    return
  end
  if state.error then
    panel:label({ text = state.error, style = "danger" })
    panel:label({ text = "Check `ccn doctor`, Git, and the baseline revision.", style = "muted" })
    panel:button({ label = "Retry", on_click = function() review_scan(state.mode, state.review.rev) end })
    return
  end

  panel:label({ text = compact_dir(review.root), style = "muted" })
  if review.changed then
    panel:label({
      text = string.format("%d new/worsened · baseline %s", review.total, review.rev),
      style = (review.total > 0) and "warning" or "muted",
    })
  else
    panel:label({
      text = string.format("%d files · %d functions · %d over %d", review.files, review.total, review.over_10 or 0, THRESHOLD),
      style = (review.over_10 or 0) > 0 and "warning" or "muted",
    })
  end
  if not review.complete then
    panel:label({ text = "Baseline incomplete: some files could not be compared.", style = "warning" })
  end

  panel:button({ label = "Refresh", on_click = function() review_scan(state.mode, state.review.rev) end })
  panel:button({ label = "Review changed (HEAD~1)", on_click = function() review_scan("changed", "HEAD~1") end })
  panel:button({ label = "Preview agent brief", on_click = function()
    ttt.exec_command("ccn.preview")
  end })
  panel:button({ label = "Copy agent brief", on_click = copy_brief })
  panel:divider()

  if #review.functions == 0 then
    panel:label({
      text = review.changed and "No new or worsened functions since the baseline." or "No function-level CCN found.",
      style = "muted",
    })
    return
  end

  local items = {}
  local shown = math.min(#review.functions, MAX_ROWS)
  for i = 1, shown do
    local fn = review.functions[i]
    local suffix = ""
    if fn.kind ~= nil then
      if fn.base_ccn == nil then
        suffix = "  new"
      else
        suffix = string.format("  +%d", math.max(0, (fn.ccn or 0) - (fn.base_ccn or 0)))
      end
    end
    table.insert(items, {
      id = tostring(i),
      label = string.format("%s:%s  L%s%s", fn.path, function_name(fn), tostring(fn.line or 0), suffix),
      badge = tostring(fn.ccn or 0),
      icon = (fn.ccn or 0) > THRESHOLD and "!" or " ",
      muted = (fn.ccn or 0) <= THRESHOLD,
    })
  end
  panel:list({
    items = items,
    on_select = function(node)
      local fn = review.functions[tonumber(node.id) or 0]
      if fn ~= nil then
        ttt.open_file(fn.abs, fn.line or 1)
      end
    end,
  })
  if #review.functions > shown then
    panel:label({ text = string.format("+%d more", #review.functions - shown), style = "muted" })
  end
  panel:label({ text = "! = over " .. tostring(THRESHOLD) .. " · click to jump", style = "muted" })
end

local function render(panel)
  drawer_panel = panel
  if state.mode == "file" then
    render_file(panel)
  elseif state.mode == "brief" then
    render_brief(panel)
  else
    render_review(panel)
  end
end

-- ----------------------------------------------------------------- commands

local function open_inspector()
  state.mode = "file"
  ttt.open_drawer({
    width = 48,
    min_width = 30,
    side = "right",
    render = render,
  })
  refresh_file()
end

open_review = function(mode, rev)
  state.mode = mode
  ttt.open_drawer({
    width = 56,
    min_width = 30,
    side = "right",
    render = render,
  })
  review_scan(mode, rev)
end

local function open_brief()
  if state.review.root == "" or #state.review.functions == 0 then
    pcall(ttt.notify, "Run CCN: Review workspace first")
    return
  end
  state.mode = "brief"
  ttt.open_drawer({
    width = 64,
    min_width = 40,
    side = "right",
    render = render,
  })
end

local function refresh()
  if state.mode == "file" then
    refresh_file()
  elseif state.mode == "brief" then
    if drawer_panel ~= nil then drawer_panel:redraw() end
  else
    review_scan(state.mode, state.review.rev)
  end
end

ttt.register({
  commands = {
    {
      id = "ccn.inspector",
      title = "CCN: Open inspector",
      handler = open_inspector,
    },
    {
      id = "ccn.review",
      title = "CCN: Review workspace",
      handler = function() open_review("workspace") end,
    },
    {
      id = "ccn.changed",
      title = "CCN: Review changed (HEAD~1)",
      handler = function() open_review("changed", "HEAD~1") end,
    },
    {
      id = "ccn.preview",
      title = "CCN: Preview agent brief",
      handler = open_brief,
    },
    {
      id = "ccn.brief",
      title = "CCN: Copy agent brief",
      handler = copy_brief,
    },
    {
      id = "ccn.refresh",
      title = "CCN: Refresh",
      handler = refresh,
    },
    {
      id = "ccn.close",
      title = "CCN: Close inspector",
      handler = function() ttt.close_drawer() end,
    },
  },
  keybindings = {
    { key = "alt+c", command = "ccn.inspector" },
    { key = "alt+r", command = "ccn.review" },
  },
})

events.on("file.open", function(path)
  if not auto_opened and not is_untitled(path) and supported(path) then
    auto_opened = true
    open_inspector()
  elseif state.mode == "file" then
    refresh_file()
  end
end)
events.on("file.save", function()
  if state.mode == "file" then
    refresh_file()
  end
end)

local function maybe_auto_open()
  local path = editor.file_path()
  if not auto_opened and not is_untitled(path) and supported(path) then
    auto_opened = true
    open_inspector()
  end
end

set_status("CCN ready")
if ttt.set_timeout ~= nil then
  ttt.set_timeout(250, maybe_auto_open)
else
  maybe_auto_open()
end


