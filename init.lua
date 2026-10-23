-- CCN inspector for TTT.
--
-- This is a deliberately thin integration spike: TTT owns the editor, LSP,
-- Git, terminal and layout; ccn owns the complexity analysis. The plugin runs
-- `ccn <file> --json` on the active file and renders the function list in a
-- right-side drawer.
--
-- Install: copy this directory to <workspace>/plugins/ccn (or
-- ~/.config/ttt/plugins/ccn on Unix) and run "CCN: Open inspector" from the
-- command palette. The plugin asks for the permissions declared in
-- plugin.ttt.json.

local ttt = require("ttt")
local sys = require("ttt.system")
local events = require("ttt.events")
local editor = require("ttt.editor")
local json = require("ttt.json")

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


local state = {
  path = "",
  file = "",
  error = nil,
  loading = false,
  ccn_max = nil,
  over_10 = nil,
  functions = {},
}

local drawer_panel = nil

local function basename(path)
  return path:match("([^/\\]+)$") or path
end

local function set_status(text)
  pcall(ttt.set_status_item, "right", "ccn", text, {
    priority = 120,
    on_click = function()
      ttt.exec_command("ccn.inspector")
    end,
  })
end

local function refresh()
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

local function render(panel)
  drawer_panel = panel
  panel:title({ text = "CCN", badge = state.file })

  if state.loading then
    panel:label({ text = "Analyzing " .. state.file .. " ...", style = "muted" })
    return
  end
  if state.error then
    panel:label({ text = state.error, style = "danger" })
    panel:label({ text = "Run `ccn doctor` or check PATH.", style = "muted" })
    panel:button({ label = "Retry", on_click = refresh })
    return
  end
  if state.path == "" then
    panel:label({ text = "Open a supported source file.", style = "muted" })
    return
  end

  panel:label({
    text = string.format("max CCN %s · %d functions · %d over 10", tostring(state.ccn_max), #state.functions, state.over_10 or 0),
    style = "muted",
  })
  panel:button({ label = "Refresh", on_click = refresh })
  panel:divider()

  if #state.functions == 0 then
    panel:label({ text = "No function-level CCN in this file.", style = "muted" })
    return
  end

  local items = {}
  for _, fn in ipairs(state.functions) do
    local name = fn.name
    if name == nil or name == "" then name = fn.identity or "(anonymous)" end
    table.insert(items, {
      id = tostring(fn.line or 0),
      label = string.format("%s  L%s", name, tostring(fn.line or 0)),
      badge = tostring(fn.ccn),
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

local function open_inspector()
  ttt.open_drawer({
    width = 48,
    min_width = 30,
    side = "right",
    render = render,
  })
  refresh()
end

ttt.register({
  commands = {
    {
      id = "ccn.inspector",
      title = "CCN: Open inspector",
      handler = open_inspector,
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
    { key = "ctrl+k c", command = "ccn.inspector" },
  },
})

events.on("file.open", function(path)
  if not auto_opened and not is_untitled(path) and supported(path) then
    auto_opened = true
    open_inspector()
  else
    refresh()
  end
end)
events.on("file.save", function()
  refresh()
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
