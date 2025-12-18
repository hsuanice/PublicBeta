--[[
@description AudioSweet ReaImGui - ImGui Interface for AudioSweet
@author hsuanice
@version 0.1.2
@provides
  [main] .
@about

Key Features:
  - Focused/Chain modes with real-time FX display
  - Preset library with custom naming and rename sync
  - Auto-tracked history (up to 50 operations)
  - Keyboard shortcuts (Space=Play/Stop, S=Solo)
  - Comprehensive file naming settings with FX Alias
  - Debug mode with detailed console logging

Reference:
  Inspired by AudioSuite-like Script by Tim Chimes
  'AudioSweet' is a name originally given by Tim Chimes.  
  This project continues to use the name in reference to his original work.

  Original: Renders selected plugin to selected media item
  Written for REAPER 5.1 with Lua
  v1.1 12/22/2015 - Added PreventUIRefresh
  http://timchimes.com/scripting-with-reaper-audiosuite/

Development:
  This script was developed with the assistance of AI tools
  including ChatGPT and Claude AI.

@changelog
  0.1.2 [Internal Build 251218.2240] - Disabled collapse arrow
    - Added: Main GUI window now has collapse controls disabled (WindowFlags_NoCollapse) to prevent accidental collapse errors reported by users

  0.1.1 [Internal Build 251218.2150] - BWF MetaEdit reminder + install guide
    - Added: CLI detection at startup with warning banner so users know TC embedding requires bwfmetaedit
    - Added: Settings > Timecode Embed modal showing status, custom path input, and re-check/install buttons
    - Added: Homebrew install guide popup with copy-friendly commands for quick setup
]]--

------------------------------------------------------------
-- Dependencies
------------------------------------------------------------
local r = reaper
local OS_NAME = r.GetOS()
local IS_WINDOWS = OS_NAME:match("Win") ~= nil
local PATH_SEPARATOR = IS_WINDOWS and ';' or ':'
local DIR_SEPARATOR = package.config:sub(1,1) or '/'
package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local RES_PATH = r.GetResourcePath()
local CORE_PATH = RES_PATH .. '/Scripts/hsuanice Scripts/Library/hsuanice_AudioSweet Core.lua'
local PREVIEW_CORE_PATH = RES_PATH .. '/Scripts/hsuanice Scripts/Library/hsuanice_AS Preview Core.lua'

------------------------------------------------------------
-- ImGui Context
------------------------------------------------------------
local ctx = ImGui.CreateContext('AudioSweet GUI')

------------------------------------------------------------
-- GUI State
------------------------------------------------------------
local gui = {
  open = true,
  mode = 0,              -- 0=focused, 1=chain
  action = 0,            -- 0=apply, 1=copy
  copy_scope = 0,
  copy_pos = 0,
  channel_mode = 0,      -- 0=auto, 1=mono, 2=multi
  handle_seconds = 5.0,
  debug = false,
  max_history = 10,      -- Maximum number of history items to keep
  show_fx_on_recall = true,    -- Show FX window when executing SAVED CHAIN/HISTORY
  fxname_show_type = true,     -- Show FX type prefix (CLAP:, VST3:, etc.)
  fxname_show_vendor = true,  -- Show vendor name in parentheses
  fxname_strip_symbol = true,  -- Strip spaces and symbols
  use_alias = false,           -- Use FX Alias for file naming
  -- Chain mode naming
  chain_token_source = 0,      -- 0=track, 1=aliases, 2=fxchain
  chain_alias_joiner = "",     -- Joiner for aliases mode
  max_fx_tokens = 3,           -- FIFO limit for FX tokens
  trackname_strip_symbols = true,  -- Strip symbols from track names
  sanitize_token = false,      -- Sanitize tokens for safe filenames
  is_running = false,
  last_result = "",
  focused_fx_name = "",
  focused_fx_index = nil,  -- Store FX index for focused mode
  focused_track = nil,
  focused_track_name = "",
  focused_track_fx_list = {},
  saved_chains = {},
  history = {},
  new_chain_name = "",
  new_chain_name_default = "",  -- Store initial default value to detect if user modified
  new_fx_preset_name = "",
  show_save_popup = false,
  show_save_fx_popup = false,
  show_rename_popup = false,
  rename_chain_idx = nil,
  rename_chain_name = "",
  show_settings_popup = false,
  show_fxname_popup = false,
  show_preview_settings = false,
  show_naming_popup = false,
  show_target_track_popup = false,
  show_tc_embed_popup = false,
  -- Preview settings
  preview_target_track = "AudioSweet",
  preview_target_track_guid = "",  -- Track GUID for unique identification
  preview_solo_scope = 0,     -- 0=track, 1=item
  preview_restore_mode = 0,   -- 0=timesel, 1=guid
  is_previewing = false,      -- Track if preview is currently playing
  -- Feature flags
  enable_saved_chains = true,   -- Now working with OVERRIDE ExtState mechanism
  enable_history = true,        -- Now working with OVERRIDE ExtState mechanism
  -- UI settings
  enable_docking = false,       -- Allow window docking
  bwfmetaedit_custom_path = "",
  open_bwf_install_popup = false,
}

------------------------------------------------------------
-- GUI Settings Persistence
------------------------------------------------------------
local SETTINGS_NAMESPACE = "hsuanice_AS_GUI"

local function save_gui_settings()
  r.SetExtState(SETTINGS_NAMESPACE, "mode", tostring(gui.mode), true)
  r.SetExtState(SETTINGS_NAMESPACE, "action", tostring(gui.action), true)
  r.SetExtState(SETTINGS_NAMESPACE, "copy_scope", tostring(gui.copy_scope), true)
  r.SetExtState(SETTINGS_NAMESPACE, "copy_pos", tostring(gui.copy_pos), true)
  r.SetExtState(SETTINGS_NAMESPACE, "channel_mode", tostring(gui.channel_mode), true)
  r.SetExtState(SETTINGS_NAMESPACE, "handle_seconds", tostring(gui.handle_seconds), true)
  r.SetExtState(SETTINGS_NAMESPACE, "debug", gui.debug and "1" or "0", true)
  r.SetExtState(SETTINGS_NAMESPACE, "max_history", tostring(gui.max_history), true)
  r.SetExtState(SETTINGS_NAMESPACE, "show_fx_on_recall", gui.show_fx_on_recall and "1" or "0", true)
  r.SetExtState(SETTINGS_NAMESPACE, "fxname_show_type", gui.fxname_show_type and "1" or "0", true)
  r.SetExtState(SETTINGS_NAMESPACE, "fxname_show_vendor", gui.fxname_show_vendor and "1" or "0", true)
  r.SetExtState(SETTINGS_NAMESPACE, "fxname_strip_symbol", gui.fxname_strip_symbol and "1" or "0", true)
  r.SetExtState(SETTINGS_NAMESPACE, "use_alias", gui.use_alias and "1" or "0", true)
  r.SetExtState(SETTINGS_NAMESPACE, "chain_token_source", tostring(gui.chain_token_source), true)
  r.SetExtState(SETTINGS_NAMESPACE, "chain_alias_joiner", gui.chain_alias_joiner, true)
  r.SetExtState(SETTINGS_NAMESPACE, "max_fx_tokens", tostring(gui.max_fx_tokens), true)
  r.SetExtState(SETTINGS_NAMESPACE, "trackname_strip_symbols", gui.trackname_strip_symbols and "1" or "0", true)
  r.SetExtState(SETTINGS_NAMESPACE, "sanitize_token", gui.sanitize_token and "1" or "0", true)
  -- Preview settings
  r.SetExtState(SETTINGS_NAMESPACE, "preview_target_track", gui.preview_target_track, true)
  r.SetExtState(SETTINGS_NAMESPACE, "preview_target_track_guid", gui.preview_target_track_guid, true)
  r.SetExtState(SETTINGS_NAMESPACE, "preview_solo_scope", tostring(gui.preview_solo_scope), true)
  r.SetExtState(SETTINGS_NAMESPACE, "preview_restore_mode", tostring(gui.preview_restore_mode), true)
  -- UI settings
  r.SetExtState(SETTINGS_NAMESPACE, "enable_docking", gui.enable_docking and "1" or "0", true)
  r.SetExtState(SETTINGS_NAMESPACE, "bwfmetaedit_custom_path", gui.bwfmetaedit_custom_path or "", true)
end

local function load_gui_settings()
  local function get_int(key, default)
    local val = r.GetExtState(SETTINGS_NAMESPACE, key)
    return (val ~= "") and tonumber(val) or default
  end

  local function get_bool(key, default)
    local val = r.GetExtState(SETTINGS_NAMESPACE, key)
    if val == "" then return default end
    return val == "1"
  end

  local function get_float(key, default)
    local val = r.GetExtState(SETTINGS_NAMESPACE, key)
    return (val ~= "") and tonumber(val) or default
  end

  gui.mode = get_int("mode", 0)
  gui.action = get_int("action", 0)
  gui.copy_scope = get_int("copy_scope", 0)
  gui.copy_pos = get_int("copy_pos", 0)
  gui.channel_mode = get_int("channel_mode", 0)
  gui.handle_seconds = get_float("handle_seconds", 5.0)
  gui.debug = get_bool("debug", false)
  gui.max_history = get_int("max_history", 10)
  gui.show_fx_on_recall = get_bool("show_fx_on_recall", true)
  gui.fxname_show_type = get_bool("fxname_show_type", true)
  gui.fxname_show_vendor = get_bool("fxname_show_vendor", false)
  gui.fxname_strip_symbol = get_bool("fxname_strip_symbol", true)
  gui.use_alias = get_bool("use_alias", false)
  gui.chain_token_source = get_int("chain_token_source", 0)
  gui.max_fx_tokens = get_int("max_fx_tokens", 3)
  gui.trackname_strip_symbols = get_bool("trackname_strip_symbols", true)
  gui.sanitize_token = get_bool("sanitize_token", false)
  -- Preview settings
  local function get_string(key, default)
    local val = r.GetExtState(SETTINGS_NAMESPACE, key)
    return (val ~= "") and val or default
  end
  gui.chain_alias_joiner = get_string("chain_alias_joiner", "")
  gui.preview_target_track = get_string("preview_target_track", "AudioSweet")
  gui.preview_target_track_guid = get_string("preview_target_track_guid", "")
  gui.preview_solo_scope = get_int("preview_solo_scope", 0)
  gui.preview_restore_mode = get_int("preview_restore_mode", 0)
  gui.bwfmetaedit_custom_path = get_string("bwfmetaedit_custom_path", "")
  -- UI settings
  gui.enable_docking = get_bool("enable_docking", false)

  -- Debug output on startup
  if gui.debug then
    r.ShowConsoleMsg("========================================\n")
    r.ShowConsoleMsg("[AS GUI] Script startup - Current settings:\n")
    r.ShowConsoleMsg("========================================\n")
    r.ShowConsoleMsg(string.format("  Mode: %s\n", gui.mode == 0 and "Focused" or "Chain"))
    r.ShowConsoleMsg(string.format("  Action: %s\n", gui.action == 0 and "Apply" or "Copy"))
    r.ShowConsoleMsg(string.format("  Copy Scope: %s\n", gui.copy_scope == 0 and "Active" or "All"))
    r.ShowConsoleMsg(string.format("  Copy Position: %s\n", gui.copy_pos == 0 and "Last" or "Replace"))
    local channel_mode_names = {"Auto", "Mono", "Multi"}
    r.ShowConsoleMsg(string.format("  Channel Mode: %s\n", channel_mode_names[gui.channel_mode + 1]))
    r.ShowConsoleMsg(string.format("  Handle Seconds: %.2f\n", gui.handle_seconds))
    r.ShowConsoleMsg(string.format("  Debug Mode: %s\n", gui.debug and "ON" or "OFF"))
    r.ShowConsoleMsg(string.format("  Max History: %d\n", gui.max_history))
    r.ShowConsoleMsg(string.format("  FX Name - Show Type: %s\n", gui.fxname_show_type and "ON" or "OFF"))
    r.ShowConsoleMsg(string.format("  FX Name - Show Vendor: %s\n", gui.fxname_show_vendor and "ON" or "OFF"))
    r.ShowConsoleMsg(string.format("  FX Name - Strip Symbol: %s\n", gui.fxname_strip_symbol and "ON" or "OFF"))
    r.ShowConsoleMsg(string.format("  FX Name - Use Alias: %s\n", gui.use_alias and "ON" or "OFF"))
    r.ShowConsoleMsg(string.format("  Max FX Tokens: %d\n", gui.max_fx_tokens))
    local chain_token_source_names = {"Track Name", "FX Aliases", "FXChain"}
    r.ShowConsoleMsg(string.format("  Chain Token Source: %s\n", chain_token_source_names[gui.chain_token_source + 1]))
    if gui.chain_token_source == 1 then
      r.ShowConsoleMsg(string.format("  Chain Alias Joiner: '%s'\n", gui.chain_alias_joiner))
    end
    r.ShowConsoleMsg(string.format("  Track Name Strip Symbols: %s\n", gui.trackname_strip_symbols and "ON" or "OFF"))
    r.ShowConsoleMsg(string.format("  Preview Target Track: %s\n", gui.preview_target_track))
    local solo_scope_names = {"Track Solo", "Item Solo"}
    r.ShowConsoleMsg(string.format("  Preview Solo Scope: %s\n", solo_scope_names[gui.preview_solo_scope + 1]))
    local restore_mode_names = {"Keep", "Restore"}
    r.ShowConsoleMsg(string.format("  Preview Restore Mode: %s\n", restore_mode_names[gui.preview_restore_mode + 1]))
    r.ShowConsoleMsg("========================================\n")
  end
end

------------------------------------------------------------
-- BWF MetaEdit CLI Detection
------------------------------------------------------------
local bwf_cli = {
  checked = false,
  available = false,
  resolved_path = "",
  message = "",
  last_source = "",
  attempts = {},
  warning_dismissed = false,
}

local function trim(s)
  if not s then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end

local function sanitize_bwf_custom_path(path)
  local v = trim(path or "")
  v = v:gsub('^"(.*)"$', '%1')
  v = v:gsub("^'(.*)'$", "%1")
  return v
end

local function file_exists(path)
  if not path or path == "" then return false end
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

local function join_path(base, fragment)
  if base == "" then return fragment end
  local last = base:sub(-1)
  if last == '/' or last == '\\' then
    return base .. fragment
  end
  local sep = DIR_SEPARATOR == "\\" and "\\" or "/"
  return base .. sep .. fragment
end

local function check_bwfmetaedit(force)
  if bwf_cli.checked and not force then return end
  bwf_cli.checked = true
  if force then bwf_cli.warning_dismissed = false end

  local custom = sanitize_bwf_custom_path(gui.bwfmetaedit_custom_path or "")
  gui.bwfmetaedit_custom_path = custom

  local attempted = {}
  local found_path, source_label
  local binary_names = IS_WINDOWS and { "bwfmetaedit.exe", "bwfmetaedit" } or { "bwfmetaedit" }

  local function register_attempt(path)
    if path and path ~= "" then
      attempted[#attempted+1] = path
    end
  end

  local function try_candidate(path, label)
    if found_path or not path or path == "" then return false end
    register_attempt(path)
    if file_exists(path) then
      found_path = path
      source_label = label or path
      return true
    end
    return false
  end

  if custom ~= "" then
    try_candidate(custom, "custom path")
    if IS_WINDOWS and not found_path and not custom:lower():match("%.exe$") then
      try_candidate(custom .. ".exe", "custom path (.exe)")
    end
  end

  local path_env = os.getenv(IS_WINDOWS and "Path" or "PATH") or ""
  if not found_path and path_env ~= "" then
    local pattern = string.format("([^%s]+)", PATH_SEPARATOR)
    for dir in path_env:gmatch(pattern) do
      dir = trim(dir:gsub('"', ''))
      if dir ~= "" then
        for _, name in ipairs(binary_names) do
          try_candidate(join_path(dir, name), "PATH: " .. dir)
          if found_path then break end
        end
      end
      if found_path then break end
    end
  end

  local fallback_dirs = {}
  if IS_WINDOWS then
    local pf = os.getenv("ProgramFiles")
    local pf86 = os.getenv("ProgramFiles(x86)")
    if pf then fallback_dirs[#fallback_dirs+1] = join_path(pf, "BWF MetaEdit") end
    if pf86 then fallback_dirs[#fallback_dirs+1] = join_path(pf86, "BWF MetaEdit") end
  else
    fallback_dirs = { "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/opt/local/bin" }
  end
  if not found_path then
    for _, dir in ipairs(fallback_dirs) do
      for _, name in ipairs(binary_names) do
        try_candidate(join_path(dir, name), dir)
        if found_path then break end
      end
      if found_path then break end
    end
  end

  bwf_cli.attempts = attempted
  if found_path then
    bwf_cli.available = true
    bwf_cli.resolved_path = found_path
    bwf_cli.last_source = source_label or ""
    bwf_cli.message = string.format("BWF MetaEdit CLI ready (%s)", source_label or found_path)
  else
    bwf_cli.available = false
    bwf_cli.resolved_path = ""
    if custom ~= "" then
      bwf_cli.message = "Custom BWF MetaEdit CLI path not found. Please verify the file exists."
    else
      bwf_cli.message = "No 'bwfmetaedit' binary detected. Timecode embedding is currently disabled."
    end
  end
end

local BWF_INSTALL_POPUP_ID = 'BWF MetaEdit CLI Install Guide'
local BREW_INSTALL_CMD = '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
local BREW_BWF_CMD = 'brew install bwfmetaedit'
local BWF_VERIFY_CMD = 'bwfmetaedit --version'

local function draw_bwfmetaedit_warning_banner()
  if bwf_cli.available or bwf_cli.warning_dismissed then return end

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6666FF)
  ImGui.Text(ctx, "BWF MetaEdit CLI missing – Timecode embedding is disabled.")
  ImGui.PopStyleColor(ctx)

  ImGui.TextWrapped(ctx,
    "AudioSweet relies on the bwfmetaedit CLI to embed BWF TimeReference (timecode).\n" ..
    "You can continue using other features, but TC embedding stays off until the CLI is installed.")
  if bwf_cli.message ~= "" then
    ImGui.TextDisabled(ctx, bwf_cli.message)
  end

  if ImGui.Button(ctx, "Install Guide##as_warn") then
    gui.open_bwf_install_popup = true
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Re-check##as_warn") then
    check_bwfmetaedit(true)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Remind Me Later##as_warn") then
    bwf_cli.warning_dismissed = true
  end
  ImGui.Spacing(ctx)
end

local function draw_bwfmetaedit_install_modal()
  if gui.open_bwf_install_popup then
    ImGui.SetNextWindowSize(ctx, 520, 0, ImGui.Cond_Appearing)
    ImGui.OpenPopup(ctx, BWF_INSTALL_POPUP_ID)
    gui.open_bwf_install_popup = false
  end

  if ImGui.BeginPopupModal(ctx, BWF_INSTALL_POPUP_ID, true, ImGui.WindowFlags_AlwaysAutoResize) then
    if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.TextColored(ctx, 0x00AAFFFF, "Why is this required?")
    ImGui.TextWrapped(ctx,
      "AudioSweet calls the BWF MetaEdit CLI to write BWF TimeReference (timecode) back into rendered files.\n" ..
      "Without the CLI, the embed step is skipped. The steps below describe a Homebrew-based install on macOS:")
    ImGui.Spacing(ctx)

    ImGui.TextColored(ctx, 0xFFFFAAFF, "Step 1: Install Homebrew (if missing)")
    ImGui.TextWrapped(ctx, "Open Terminal, run the following command, and follow the prompts to install Homebrew:")
    ImGui.SetNextItemWidth(ctx, 460)
    ImGui.InputText(ctx, "##as_brew_install_cmd", BREW_INSTALL_CMD, ImGui.InputTextFlags_ReadOnly)
    if ImGui.Button(ctx, "Copy Command##as_copy_brew_install") then
      r.ImGui_SetClipboardText(ctx, BREW_INSTALL_CMD)
    end
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "Reference: https://brew.sh")
    ImGui.Separator(ctx)

    ImGui.TextColored(ctx, 0xFFFFAAFF, "Step 2: Install BWF MetaEdit CLI")
    ImGui.TextWrapped(ctx, "Once Homebrew is installed, run this command to install bwfmetaedit:")
    ImGui.SetNextItemWidth(ctx, 460)
    ImGui.InputText(ctx, "##as_brew_bwf_cmd", BREW_BWF_CMD, ImGui.InputTextFlags_ReadOnly)
    if ImGui.Button(ctx, "Copy Command##as_copy_bwf") then
      r.ImGui_SetClipboardText(ctx, BREW_BWF_CMD)
    end
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "Binary is typically placed in /opt/homebrew/bin")
    ImGui.Separator(ctx)

    ImGui.TextColored(ctx, 0xFFFFAAFF, "Step 3: Verify the CLI")
    ImGui.TextWrapped(ctx, "Confirm the binary responds by running:")
    ImGui.SetNextItemWidth(ctx, 460)
    ImGui.InputText(ctx, "##as_brew_verify_cmd", BWF_VERIFY_CMD, ImGui.InputTextFlags_ReadOnly)
    if ImGui.Button(ctx, "Copy Command##as_copy_verify") then
      r.ImGui_SetClipboardText(ctx, BWF_VERIFY_CMD)
    end
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "Version output = install success")
    ImGui.Spacing(ctx)

    ImGui.TextWrapped(ctx,
      "After installing, reopen AudioSweet (or press \"Re-check CLI\") to enable embedding again.\n" ..
      "Windows users (or anyone skipping Homebrew) can download installers from MediaArea: https://mediaarea.net/BWFMetaEdit")

    ImGui.Separator(ctx)
    if ImGui.Button(ctx, "Close", 120, 0) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end
end

local function draw_tc_embed_settings_popup()
  if gui.show_tc_embed_popup then
    local mouse_x, mouse_y = r.GetMousePosition()
    ImGui.SetNextWindowPos(ctx, mouse_x, mouse_y, ImGui.Cond_Appearing)
    ImGui.OpenPopup(ctx, 'Timecode Embed Settings')
    gui.show_tc_embed_popup = false
  end

  if ImGui.BeginPopupModal(ctx, 'Timecode Embed Settings', true, ImGui.WindowFlags_AlwaysAutoResize) then
    if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
      ImGui.CloseCurrentPopup(ctx)
    end

    if bwf_cli.available then
      ImGui.TextColored(ctx, 0x55FF55FF, ("CLI detected: %s"):format(bwf_cli.resolved_path))
      if bwf_cli.last_source ~= "" then
        ImGui.TextDisabled(ctx, ("Source: %s"):format(bwf_cli.last_source))
      end
    else
      ImGui.TextColored(ctx, 0xFF6666FF, "bwfmetaedit CLI not detected – Timecode embedding stays disabled.")
      if bwf_cli.message ~= "" then
        ImGui.TextWrapped(ctx, bwf_cli.message)
      end
    end

    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Custom CLI Path (optional):")
    ImGui.SetNextItemWidth(ctx, 360)
    local rv_path, new_path = ImGui.InputText(ctx, "##as_bwf_path", gui.bwfmetaedit_custom_path or "")
    if rv_path then
      gui.bwfmetaedit_custom_path = new_path
      save_gui_settings()
    end
    ImGui.TextDisabled(ctx, "Leave blank to search PATH. Provide full path incl. .exe on Windows.")

    ImGui.Separator(ctx)
    if ImGui.Button(ctx, "Re-check CLI##as_settings") then
      check_bwfmetaedit(true)
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Install Guide##as_settings") then
      gui.open_bwf_install_popup = true
    end

    ImGui.Spacing(ctx)
    ImGui.TextWrapped(ctx,
      "AudioSweet uses bwfmetaedit after renders to embed BWF TimeReference so downstream apps read the correct TC.\n" ..
      "If you skip installation, rendering still works but the embed step is skipped.")

    ImGui.Separator(ctx)
    if ImGui.Button(ctx, "Close##as_tc_settings", 120, 0) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end
end

------------------------------------------------------------
-- Track FX Chain Helpers
------------------------------------------------------------
local function get_track_guid(tr)
  if not tr then return nil end
  return r.GetTrackGUID(tr)
end

local function get_track_name_and_number(tr)
  if not tr then return "", 0 end
  local track_num = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER") or 0
  local _, track_name = r.GetTrackName(tr, "")
  return track_name or "", track_num
end

local function get_track_fx_chain(tr)
  local fx_list = {}
  if not tr then return fx_list end
  local fx_count = r.TrackFX_GetCount(tr)
  for i = 0, fx_count - 1 do
    local _, fx_name = r.TrackFX_GetFXName(tr, i, "")
    fx_list[#fx_list + 1] = {
      index = i,
      name = fx_name or "(unknown)",
      enabled = r.TrackFX_GetEnabled(tr, i),
      offline = r.TrackFX_GetOffline(tr, i),
    }
  end
  return fx_list
end

------------------------------------------------------------
-- Saved Chain Management
------------------------------------------------------------
local CHAIN_NAMESPACE = "hsuanice_AS_SavedChains"
local HISTORY_NAMESPACE = "hsuanice_AS_History"

local function load_saved_chains()
  gui.saved_chains = {}
  local idx = 0
  while true do
    local ok, data = r.GetProjExtState(0, CHAIN_NAMESPACE, "chain_" .. idx)
    if ok == 0 or data == "" then break end
    -- Format: name|guid|track_name|custom_name|mode|fx_index
    -- For backward compatibility: if no custom_name, mode, or fx_index, they will be nil/"chain"/nil
    local parts = {}
    for part in (data .. "|"):gmatch("([^|]*)|") do
      table.insert(parts, part)
    end
    local name, guid, track_name, custom_name, mode, fx_index_str = parts[1], parts[2], parts[3], parts[4], parts[5], parts[6]
    if name and guid then
      local fx_index = nil
      if fx_index_str and fx_index_str ~= "" then
        fx_index = tonumber(fx_index_str)
      end
      gui.saved_chains[#gui.saved_chains + 1] = {
        name = name,
        track_guid = guid,
        track_name = track_name or "",
        custom_name = (custom_name and custom_name ~= "") and custom_name or nil,
        mode = (mode and mode ~= "") and mode or "chain",  -- Default to "chain" for backward compatibility
        fx_index = fx_index,  -- Load fx_index
      }
    end
    idx = idx + 1
  end
end

local function save_chains_to_extstate()
  local idx = 0
  while true do
    local ok = r.GetProjExtState(0, CHAIN_NAMESPACE, "chain_" .. idx)
    if ok == 0 then break end
    r.SetProjExtState(0, CHAIN_NAMESPACE, "chain_" .. idx, "")
    idx = idx + 1
  end
  for i, chain in ipairs(gui.saved_chains) do
    local data = string.format("%s|%s|%s|%s|%s|%s",
      chain.name,
      chain.track_guid,
      chain.track_name,
      chain.custom_name or "",
      chain.mode or "chain",
      tostring(chain.fx_index or ""))  -- Add fx_index field
    r.SetProjExtState(0, CHAIN_NAMESPACE, "chain_" .. (i - 1), data)
  end
end

local function add_saved_chain(name, track_guid, track_name, custom_name, mode, fx_index)
  gui.saved_chains[#gui.saved_chains + 1] = {
    name = name,
    track_guid = track_guid,
    track_name = track_name,
    custom_name = custom_name,
    mode = mode or "chain",
    fx_index = fx_index,  -- Store FX index for focused mode
  }
  if gui.debug then
    r.ShowConsoleMsg(string.format("[AudioSweet] Save preset: name='%s', mode='%s', fx_index=%s\n",
      name or "nil", mode or "chain", tostring(fx_index or "nil")))
  end
  save_chains_to_extstate()
end

local function delete_saved_chain(idx)
  table.remove(gui.saved_chains, idx)
  save_chains_to_extstate()
end

local function rename_saved_chain(idx, new_custom_name)
  if gui.saved_chains[idx] then
    local chain = gui.saved_chains[idx]
    chain.custom_name = (new_custom_name and new_custom_name ~= "") and new_custom_name or nil
    if gui.debug then
      r.ShowConsoleMsg(string.format("[AudioSweet] Rename preset #%d: custom_name='%s', mode='%s'\n",
        idx, tostring(chain.custom_name or "nil"), chain.mode or "chain"))
    end
    save_chains_to_extstate()

    -- Sync rename to history items that match this preset
    -- Match by: track_guid + mode + (fx_index for focused, name for chain)
    for _, hist_item in ipairs(gui.history) do
      if hist_item.track_guid == chain.track_guid and hist_item.mode == chain.mode then
        if chain.mode == "focused" then
          -- For focused mode: match by fx_index
          if hist_item.fx_index == chain.fx_index then
            hist_item.custom_name = chain.custom_name
          end
        else
          -- For chain mode: match by name (original internal name)
          if hist_item.name == chain.name then
            hist_item.custom_name = chain.custom_name
          end
        end
      end
    end

    -- Save updated history to ExtState
    for i = 0, gui.max_history - 1 do
      r.SetProjExtState(0, HISTORY_NAMESPACE, "hist_" .. i, "")
    end
    for i, item in ipairs(gui.history) do
      local data = string.format("%s|%s|%s|%s|%d|%s", item.name, item.track_guid, item.track_name, item.mode, item.fx_index, item.custom_name or "")
      r.SetProjExtState(0, HISTORY_NAMESPACE, "hist_" .. (i - 1), data)
    end
  end
end

local function find_track_by_guid(guid)
  if not guid or guid == "" then return nil end
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    if get_track_guid(tr) == guid then
      return tr
    end
  end
  return nil
end

-- Get display name and current info for a saved chain
-- Returns: display_name, track_info_line, fx_info, saved_fx_index
local function get_chain_display_info(chain)
  local display_name = chain.name  -- fallback
  local current_track_name = nil
  local fx_info = ""
  local track_number = nil
  local track_info_line = ""  -- First line for tooltip: #track_number: track_name
  local saved_fx_index = nil  -- For focused mode: which FX is the saved one
  local found_fx_name = nil  -- For focused mode: current FX name from track

  -- Try to find the track by GUID
  local tr = find_track_by_guid(chain.track_guid)
  if tr and r.ValidatePtr2(0, tr, "MediaTrack*") then
    -- Get current track name and number
    local _, track_name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    current_track_name = track_name
    track_number = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")  -- 1-based

    -- Build track info line for tooltip (always show #number: name)
    track_info_line = string.format("#%d: %s", track_number, track_name)

    -- Build FX info based on mode
    if chain.mode == "focused" then
      -- For focused FX: show entire FX chain, mark the saved FX
      local found_fx_idx = nil

      -- Method 1: Try to use saved fx_index if available
      if chain.fx_index then
        local fx_count = r.TrackFX_GetCount(tr)
        if chain.fx_index < fx_count then
          local _, fx_name = r.TrackFX_GetFXName(tr, chain.fx_index, "")
          -- Verify this is still the same FX (name should match or contain saved name)
          if fx_name and (fx_name == chain.name or fx_name:find(chain.name, 1, true)) then
            found_fx_name = fx_name
            found_fx_idx = chain.fx_index
          end
        end
      end

      -- Method 2: If index didn't work, search by exact name match
      if not found_fx_name then
        local fx_count = r.TrackFX_GetCount(tr)
        for i = 0, fx_count - 1 do
          local _, fx_name = r.TrackFX_GetFXName(tr, i, "")
          -- Only exact match to avoid matching wrong FX
          if fx_name == chain.name then
            found_fx_name = fx_name
            found_fx_idx = i
            break
          end
        end
      end

      -- Build full FX chain list, same as chain mode
      saved_fx_index = found_fx_idx  -- Store for tooltip coloring
      local fx_count = r.TrackFX_GetCount(tr)
      if fx_count > 0 then
        local fx_lines = {}
        for i = 0, fx_count - 1 do
          local _, fx_name = r.TrackFX_GetFXName(tr, i, "")
          table.insert(fx_lines, string.format("%d. %s", i + 1, fx_name))
        end
        fx_info = table.concat(fx_lines, "\n")
      else
        fx_info = "No FX"
      end
    else
      -- For chain mode: show entire FX chain list
      local fx_count = r.TrackFX_GetCount(tr)
      if fx_count > 0 then
        local fx_lines = {}
        for i = 0, fx_count - 1 do
          local _, fx_name = r.TrackFX_GetFXName(tr, i, "")
          -- fx_name format: "VST3: Pro-Q 4 (FabFilter)" or "JS: ReaEQ"
          -- Keep the full name including plugin type
          -- Format: "1. [Plugin Type]: FX Name"
          table.insert(fx_lines, string.format("%d. %s", i + 1, fx_name))
        end
        fx_info = table.concat(fx_lines, "\n")
      else
        fx_info = "No FX"
      end
    end
  else
    track_info_line = "Track not found"
    fx_info = ""
  end

  -- Determine display name based on mode
  if chain.mode == "focused" then
    -- Focused FX mode: use custom name OR current FX name from track (real-time)
    if chain.custom_name and chain.custom_name ~= "" then
      display_name = chain.custom_name
    else
      -- Use current FX name from track, fallback to saved name
      display_name = found_fx_name or chain.name
    end
  else
    -- Chain mode: use custom name OR current track name OR saved track name
    if chain.custom_name and chain.custom_name ~= "" then
      display_name = chain.custom_name
      -- Add track# prefix for custom names
      if track_number then
        display_name = string.format("#%d %s", track_number, display_name)
      end
    elseif current_track_name then
      -- Add track# prefix for dynamic track names
      if track_number then
        display_name = string.format("#%d %s", track_number, current_track_name)
      else
        display_name = current_track_name
      end
    else
      display_name = chain.track_name  -- fallback to saved name
    end
  end

  return display_name, track_info_line, fx_info, saved_fx_index
end

-- Get display name for a history item with current track info
local function get_history_display_name(hist_item)
  local display_name = hist_item.name  -- fallback

  -- Try to find the track by GUID to get current track number
  local tr = find_track_by_guid(hist_item.track_guid)
  if tr and r.ValidatePtr2(0, tr, "MediaTrack*") then
    local track_number = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")  -- 1-based
    local _, track_name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)

    if hist_item.mode == "focused" then
      -- Focused mode: use custom name OR FX name (no track# prefix)
      if hist_item.custom_name and hist_item.custom_name ~= "" then
        display_name = hist_item.custom_name
      else
        -- Use the saved FX name (hist_item.name already contains full FX name)
        display_name = hist_item.name
      end
    else
      -- Chain mode: use custom name OR current track name
      if hist_item.custom_name and hist_item.custom_name ~= "" then
        display_name = hist_item.custom_name
        -- Add track# prefix for custom names
        if track_number then
          display_name = string.format("#%d %s", track_number, display_name)
        end
      elseif track_number then
        -- Use current track name with track# prefix
        display_name = string.format("#%d %s", track_number, track_name)
      else
        display_name = track_name
      end
    end
  end

  return display_name
end

-- Show hover tooltip for preset/history item (shared function)
-- item: saved chain or history item
local function show_preset_tooltip(item)
  local tr = find_track_by_guid(item.track_guid)
  if not tr or not r.ValidatePtr2(0, tr, "MediaTrack*") then
    ImGui.SetTooltip(ctx, "Track not found")
    return
  end

  local track_number = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
  local _, track_name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  local track_info_line = string.format("#%d: %s", track_number, track_name)

  local fx_count = r.TrackFX_GetCount(tr)
  if fx_count == 0 then
    ImGui.SetTooltip(ctx, track_info_line .. "\nNo FX")
    return
  end

  if item.mode == "focused" then
    -- For focused mode: show entire FX chain, mark the saved FX in GREEN
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, track_info_line)
    for fx_idx = 0, fx_count - 1 do
      local _, fx_name = r.TrackFX_GetFXName(tr, fx_idx, "")
      if fx_idx == (item.fx_index or 0) then
        -- This is the saved FX - color it green
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00FF00FF)
        ImGui.Text(ctx, string.format("%d. %s", fx_idx + 1, fx_name))
        ImGui.PopStyleColor(ctx)
      else
        ImGui.Text(ctx, string.format("%d. %s", fx_idx + 1, fx_name))
      end
    end
    ImGui.EndTooltip(ctx)
  else
    -- For chain mode: show entire FX chain
    local fx_lines = {}
    for fx_idx = 0, fx_count - 1 do
      local _, fx_name = r.TrackFX_GetFXName(tr, fx_idx, "")
      table.insert(fx_lines, string.format("%d. %s", fx_idx + 1, fx_name))
    end
    local fx_info = table.concat(fx_lines, "\n")
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, track_info_line)
    ImGui.Text(ctx, fx_info)
    ImGui.EndTooltip(ctx)
  end
end

------------------------------------------------------------
-- History Management
------------------------------------------------------------
local function load_history()
  gui.history = {}
  local idx = 0
  while idx < gui.max_history do
    local ok, data = r.GetProjExtState(0, HISTORY_NAMESPACE, "hist_" .. idx)
    if ok == 0 or data == "" then break end
    -- Format: name|guid|track_name|mode|fx_index|custom_name
    local parts = {}
    for part in (data .. "|"):gmatch("([^|]*)|") do
      table.insert(parts, part)
    end
    local name, guid, track_name, mode, fx_idx_str, custom_name = parts[1], parts[2], parts[3], parts[4], parts[5], parts[6]
    if name and guid then
      gui.history[#gui.history + 1] = {
        name = name,
        track_guid = guid,
        track_name = track_name or "",
        mode = mode or "chain",
        fx_index = tonumber(fx_idx_str) or 0,
        custom_name = (custom_name and custom_name ~= "") and custom_name or nil,
      }
    end
    idx = idx + 1
  end
end

local function add_to_history(name, track_guid, track_name, mode, fx_index, custom_name)
  fx_index = fx_index or 0

  -- Remove if already exists
  for i = #gui.history, 1, -1 do
    if gui.history[i].name == name and gui.history[i].track_guid == track_guid then
      table.remove(gui.history, i)
    end
  end

  -- Add to front
  table.insert(gui.history, 1, {
    name = name,
    track_guid = track_guid,
    track_name = track_name,
    mode = mode,
    fx_index = fx_index,
    custom_name = custom_name,
  })

  -- Trim to max_history
  while #gui.history > gui.max_history do
    table.remove(gui.history)
  end

  -- Save to ExtState
  for i = 0, gui.max_history - 1 do
    r.SetProjExtState(0, HISTORY_NAMESPACE, "hist_" .. i, "")
  end
  for i, item in ipairs(gui.history) do
    local data = string.format("%s|%s|%s|%s|%d|%s", item.name, item.track_guid, item.track_name, item.mode, item.fx_index, item.custom_name or "")
    r.SetProjExtState(0, HISTORY_NAMESPACE, "hist_" .. (i - 1), data)
  end
end

------------------------------------------------------------
-- Focused FX Detection
------------------------------------------------------------
local function normalize_focused_fx_index(idx)
  if idx >= 0x2000000 then idx = idx - 0x2000000 end
  if idx >= 0x1000000 then idx = idx - 0x1000000 end
  return idx
end

local function get_focused_fx_info()
  local retval, trackOut, itemOut, fxOut = r.GetFocusedFX()
  if retval == 1 then
    local tr = r.GetTrack(0, math.max(0, (trackOut or 1) - 1))
    if tr then
      local fx_index = normalize_focused_fx_index(fxOut or 0)
      local _, name = r.TrackFX_GetFXName(tr, fx_index, "")
      return true, "Track FX", name or "(unknown)", tr, fx_index
    end
  elseif retval == 2 then
    return true, "Take FX", "(Take FX not supported)", nil, nil
  end
  return false, "None", "No focused FX", nil, nil
end

local function update_focused_fx_display()
  local found, fx_type, fx_name, tr, fx_index = get_focused_fx_info()

  -- In Chain mode: if no focused FX, try to use first selected track with FX
  if gui.mode == 1 and not found then
    local sel_track = r.GetSelectedTrack(0, 0)  -- Get first selected track
    if sel_track and r.TrackFX_GetCount(sel_track) > 0 then
      tr = sel_track
      local track_name, track_num = get_track_name_and_number(tr)
      gui.focused_track = tr
      gui.focused_track_name = string.format("#%d - %s", track_num, track_name)
      gui.focused_track_fx_list = get_track_fx_chain(tr)
      gui.focused_fx_name = "Track: " .. track_name
      return false  -- Not a "valid focused FX" but we have a track with FX chain
    end
  end

  gui.focused_track = tr
  if found then
    if fx_type == "Track FX" then
      gui.focused_fx_name = fx_name
      gui.focused_fx_index = fx_index  -- Store FX index
      if tr then
        local track_name, track_num = get_track_name_and_number(tr)
        gui.focused_track_name = string.format("#%d - %s", track_num, track_name)
        gui.focused_track_fx_list = get_track_fx_chain(tr)
      end
      return true
    else
      gui.focused_fx_name = fx_name .. " (WARNING)"
      gui.focused_fx_index = nil
      gui.focused_track_name = ""
      gui.focused_track_fx_list = {}
      return false
    end
  else
    gui.focused_fx_name = "No focused FX"
    gui.focused_fx_index = nil
    gui.focused_track_name = ""
    gui.focused_track_fx_list = {}
    return false
  end
end

------------------------------------------------------------
-- AudioSweet Execution
------------------------------------------------------------
local function set_extstate_from_gui()
  local mode_names = { "focused", "chain" }
  local action_names = { "apply", "copy" }
  local scope_names = { "active", "all_takes" }
  local pos_names = { "tail", "head" }
  local channel_names = { "auto", "mono", "multi" }

  r.SetExtState("hsuanice_AS", "AS_MODE", mode_names[gui.mode + 1], false)
  r.SetExtState("hsuanice_AS", "AS_ACTION", action_names[gui.action + 1], false)
  r.SetExtState("hsuanice_AS", "AS_COPY_SCOPE", scope_names[gui.copy_scope + 1], false)
  r.SetExtState("hsuanice_AS", "AS_COPY_POS", pos_names[gui.copy_pos + 1], false)
  r.SetExtState("hsuanice_AS", "AS_APPLY_FX_MODE", channel_names[gui.channel_mode + 1], false)
  r.SetExtState("hsuanice_AS", "DEBUG", gui.debug and "1" or "0", false)

  -- File Naming ExtStates
  r.SetExtState("hsuanice_AS", "USE_ALIAS", gui.use_alias and "1" or "0", false)
  r.SetExtState("hsuanice_AS", "FXNAME_SHOW_TYPE", gui.fxname_show_type and "1" or "0", false)
  r.SetExtState("hsuanice_AS", "FXNAME_SHOW_VENDOR", gui.fxname_show_vendor and "1" or "0", false)
  r.SetExtState("hsuanice_AS", "FXNAME_STRIP_SYMBOL", gui.fxname_strip_symbol and "1" or "0", false)
  local chain_token_names = {"track", "aliases", "fxchain"}
  r.SetExtState("hsuanice_AS", "AS_CHAIN_TOKEN_SOURCE", chain_token_names[gui.chain_token_source + 1], false)
  r.SetExtState("hsuanice_AS", "AS_CHAIN_ALIAS_JOINER", gui.chain_alias_joiner, false)
  r.SetExtState("hsuanice_AS", "AS_MAX_FX_TOKENS", tostring(gui.max_fx_tokens), false)
  r.SetExtState("hsuanice_AS", "TRACKNAME_STRIP_SYMBOLS", gui.trackname_strip_symbols and "1" or "0", false)
  r.SetExtState("hsuanice_AS", "SANITIZE_TOKEN_FOR_FILENAME", gui.sanitize_token and "1" or "0", false)

  -- Debug output
  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] ExtState: channel_mode=%s (gui.channel_mode=%d)\n",
      channel_names[gui.channel_mode + 1], gui.channel_mode))
  end
  r.SetExtState("hsuanice_AS", "AS_SHOW_SUMMARY", "0", false)  -- Always disable summary dialog
  r.SetProjExtState(0, "RGWH", "HANDLE_SECONDS", tostring(gui.handle_seconds))

  -- Set RGWH Core debug level (0 = silent, no console output)
  r.SetProjExtState(0, "RGWH", "DEBUG_LEVEL", gui.debug and "2" or "0")

  -- Set FX name formatting options
  r.SetExtState("hsuanice_AS", "FXNAME_SHOW_TYPE", gui.fxname_show_type and "1" or "0", false)
  r.SetExtState("hsuanice_AS", "FXNAME_SHOW_VENDOR", gui.fxname_show_vendor and "1" or "0", false)
  r.SetExtState("hsuanice_AS", "FXNAME_STRIP_SYMBOL", gui.fxname_strip_symbol and "1" or "0", false)
end

------------------------------------------------------------
-- Preview & Solo Functions
------------------------------------------------------------
local function toggle_preview()
  -- Check if transport is playing (includes previews started by Tools scripts)
  local play_state = r.GetPlayState()
  local is_playing = (play_state & 1 ~= 0)

  -- If transport is playing (GUI preview or Tools script preview), stop it
  if gui.is_previewing or is_playing then
    r.Main_OnCommand(40044, 0)  -- Transport: Stop
    gui.is_previewing = false
    gui.last_result = "Preview stopped"
    return
  end

  -- Otherwise, start preview
  if gui.is_running then return end

  -- Load AS Preview Core
  local ok, ASP = pcall(dofile, PREVIEW_CORE_PATH)
  if not ok or type(ASP) ~= "table" or type(ASP.preview) ~= "function" then
    gui.last_result = "Error: Preview Core not found"
    return
  end

  gui.is_running = true
  gui.last_result = "Running Preview..."

  -- Prepare arguments
  local solo_scope_names = { "track", "item" }
  local restore_mode_names = { "timesel", "guid" }

  -- Determine target track for chain mode
  local target_track_name = gui.preview_target_track  -- Default to settings
  local target_track_obj = nil  -- Store the actual track object to pass directly

  if gui.debug then
    r.ShowConsoleMsg(string.format("\n[AudioSweet] === PREVIEW TARGET SELECTION DEBUG ===\n"))
    r.ShowConsoleMsg(string.format("  Mode: %s\n", gui.mode == 1 and "Chain" or "Focused"))
    r.ShowConsoleMsg(string.format("  Settings preview_target_track: %s\n", gui.preview_target_track))
    r.ShowConsoleMsg(string.format("  Settings preview_target_track_guid: %s\n", gui.preview_target_track_guid or "(empty)"))
    r.ShowConsoleMsg(string.format("  Has focused_track: %s\n", gui.focused_track and "YES" or "NO"))
  end

  if gui.mode == 1 then
    -- Chain mode: prioritize focused FX chain track if available
    if gui.focused_track and r.ValidatePtr2(0, gui.focused_track, "MediaTrack*") then
      -- Get pure track name from track object (P_NAME doesn't include track number)
      local _, pure_name = r.GetSetMediaTrackInfo_String(gui.focused_track, "P_NAME", "", false)
      local focused_guid = get_track_guid(gui.focused_track)
      target_track_name = pure_name
      target_track_obj = gui.focused_track
      if gui.debug then
        r.ShowConsoleMsg(string.format("  DECISION: Using focused FX chain track\n"))
        r.ShowConsoleMsg(string.format("  → Track: %s (GUID: %s)\n", pure_name, focused_guid))
      end
    else
      -- No focused FX: use settings target track
      if gui.debug then
        r.ShowConsoleMsg(string.format("  DECISION: No focused FX, using settings\n"))
      end
      -- Try to find track by GUID first (more reliable for duplicate names)
      if gui.preview_target_track_guid and gui.preview_target_track_guid ~= "" then
        local target_track = find_track_by_guid(gui.preview_target_track_guid)
        if target_track and r.ValidatePtr2(0, target_track, "MediaTrack*") then
          -- Found by GUID: get current track name and store track object
          local _, current_name = r.GetSetMediaTrackInfo_String(target_track, "P_NAME", "", false)
          target_track_name = current_name
          target_track_obj = target_track  -- IMPORTANT: Pass track object directly to avoid duplicate name issues
          if gui.debug then
            r.ShowConsoleMsg(string.format("  → Found by GUID: %s\n", gui.preview_target_track_guid))
            r.ShowConsoleMsg(string.format("  → Track name: %s\n", current_name))
            r.ShowConsoleMsg(string.format("  → Will pass MediaTrack* directly to Preview Core\n"))
          end
        else
          -- GUID not found: fallback to name
          if gui.debug then
            r.ShowConsoleMsg(string.format("  → GUID not found: %s\n", gui.preview_target_track_guid))
            r.ShowConsoleMsg(string.format("  → Fallback to track name search: %s\n", target_track_name))
          end
        end
      else
        -- No GUID: use track name directly
        if gui.debug then
          r.ShowConsoleMsg(string.format("  → No GUID stored, using track name: %s\n", target_track_name))
        end
      end
    end
  end

  if gui.debug then
    r.ShowConsoleMsg(string.format("  FINAL target_track_name: %s\n", target_track_name))
    r.ShowConsoleMsg(string.format("  FINAL target_track_obj: %s\n", target_track_obj and "MediaTrack*" or "nil (will use name search)"))
    r.ShowConsoleMsg("[AudioSweet] =====================================\n\n")
  end

  local args = {
    debug = gui.debug,
    chain_mode = (gui.mode == 1),  -- 0=focused, 1=chain
    mode = "solo",
    -- Pass track object directly if available (avoids duplicate name issues)
    -- Otherwise fall back to track name search
    target = target_track_obj or nil,
    target_track_name = target_track_obj and nil or target_track_name,
    solo_scope = solo_scope_names[gui.preview_solo_scope + 1],
    restore_mode = restore_mode_names[gui.preview_restore_mode + 1],
  }

  -- Run preview
  local preview_ok, preview_err = pcall(ASP.preview, args)

  if preview_ok then
    gui.last_result = "Preview: Success"
    gui.is_previewing = true
  else
    gui.last_result = "Preview Error: " .. tostring(preview_err)
    gui.is_previewing = false
  end

  gui.is_running = false
end

local function toggle_solo()
  -- Debug logging
  if gui.debug then
    local scope_name = (gui.preview_solo_scope == 0) and "Track Solo" or "Item Solo"
    r.ShowConsoleMsg(string.format("[AS GUI] SOLO button clicked (scope=%s, mode=%s)\n",
      scope_name, gui.mode == 0 and "Focused" or "Chain"))
  end

  -- Toggle solo based on solo_scope setting
  if gui.preview_solo_scope == 0 then
    -- Track solo: determine target track based on mode
    local target_track = nil
    local track_name = ""

    if gui.mode == 0 then
      -- Focused mode: use focused track
      target_track = gui.focused_track
      track_name = gui.focused_track_name
    else
      -- Chain mode: use preview target track or focused track
      if gui.focused_track then
        -- If there's a focused FX chain, use that track
        target_track = gui.focused_track
        track_name = gui.focused_track_name
      else
        -- No focused FX: find track by GUID first, then by name
        if gui.preview_target_track_guid and gui.preview_target_track_guid ~= "" then
          target_track = find_track_by_guid(gui.preview_target_track_guid)
          if target_track and r.ValidatePtr2(0, target_track, "MediaTrack*") then
            local _, tn = r.GetSetMediaTrackInfo_String(target_track, "P_NAME", "", false)
            track_name = tn
          end
        end
        -- Fallback to name search if GUID not found
        if not target_track then
          local tc = r.CountTracks(0)
          for i = 0, tc - 1 do
            local tr = r.GetTrack(0, i)
            local _, tn = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            if tn == gui.preview_target_track then
              target_track = tr
              track_name = gui.preview_target_track
              break
            end
          end
        end
      end
    end

    if target_track then
      local current_solo = r.GetMediaTrackInfo_Value(target_track, "I_SOLO")
      -- Toggle: 0=unsolo, 1=solo, 2=solo in place
      -- Simple toggle: if any solo state, set to 0; if 0, set to 1
      local new_solo = (current_solo == 0) and 1 or 0
      r.SetMediaTrackInfo_Value(target_track, "I_SOLO", new_solo)

      if gui.debug then
        r.ShowConsoleMsg(string.format("[AS GUI] Toggled track solo: %s -> %s (Track: %s)\n",
          current_solo, new_solo, track_name))
      end
    else
      if gui.debug then
        r.ShowConsoleMsg("[AS GUI] No target track found for solo\n")
      end
    end
  else
    -- Item solo (41561): operate on selected items
    r.Main_OnCommand(41561, 0)
  end
end

------------------------------------------------------------
-- AudioSweet Run Function
------------------------------------------------------------
local function run_audiosweet(override_track)
  if gui.is_running then return end

  local item_count = r.CountSelectedMediaItems(0)
  if item_count == 0 then
    gui.last_result = "Error: No items selected"
    return
  end

  local target_track = override_track or gui.focused_track

  if not override_track then
    local has_valid_fx = update_focused_fx_display()
    if not has_valid_fx then
      gui.last_result = "Error: No valid Track FX focused"
      return
    end
  end

  if not target_track then
    gui.last_result = "Error: Target track not found"
    return
  end

  gui.is_running = true
  gui.last_result = "Running..."

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  -- Only use Core for focused FX mode
  -- (Core needs GetFocusedFX to work properly)
  if gui.mode == 0 and not override_track then
    set_extstate_from_gui()

    local ok, err = pcall(dofile, CORE_PATH)
    r.UpdateArrange()

    if ok then
      gui.last_result = string.format("Success! (%d items)", item_count)

      -- Add to history
      if gui.focused_track then
        local track_guid = get_track_guid(gui.focused_track)
        local name = gui.focused_fx_name
        -- Get FX index from GetFocusedFX
        local retval, trackidx, itemidx, fxidx = r.GetFocusedFX()
        local fx_index = (retval == 1) and normalize_focused_fx_index(fxidx or 0) or 0
        add_to_history(name, track_guid, gui.focused_track_name, "focused", fx_index, nil)  -- No custom name from direct execution
      end
    else
      gui.last_result = "Error: " .. tostring(err)
    end
  else
    -- For chain mode, focus first FX and use AudioSweet Core
    local fx_count = r.TrackFX_GetCount(target_track)
    if fx_count == 0 then
      gui.last_result = "Error: No FX on target track"
      r.PreventUIRefresh(-1)
      r.Undo_EndBlock("AudioSweet GUI (error)", -1)
      gui.is_running = false
      return
    end

    -- Set track as last touched (without changing selection)
    -- Note: OVERRIDE ExtState tells Core which track to use
    -- We don't call SetOnlyTrackSelected() to preserve item selection
    r.SetMixerScroll(target_track)

    -- Set ExtState for AudioSweet (chain mode)
    set_extstate_from_gui()
    r.SetExtState("hsuanice_AS", "AS_MODE", "chain", false)

    -- Set OVERRIDE ExtState to specify track and FX for Core
    -- (bypasses GetFocusedFX check which fails for CLAP plugins)
    local track_idx = r.CSurf_TrackToID(target_track, false) - 1  -- Convert to 0-based index
    r.SetExtState("hsuanice_AS", "OVERRIDE_TRACK_IDX", tostring(track_idx), false)
    r.SetExtState("hsuanice_AS", "OVERRIDE_FX_IDX", "0", false)  -- Chain mode uses first FX

    -- Run AudioSweet Core
    local ok, err = pcall(dofile, CORE_PATH)
    r.UpdateArrange()

    if ok then
      gui.last_result = string.format("Success! (%d items)", item_count)

      -- Add to history
      if target_track then
        local track_guid = get_track_guid(target_track)
        local track_name, track_num = get_track_name_and_number(target_track)
        local name = string.format("#%d - %s", track_num, track_name)
        add_to_history(name, track_guid, name, "chain", 0, nil)  -- chain mode uses index 0, no custom name from direct execution
      end
    else
      gui.last_result = "Error: " .. tostring(err)
    end
  end

  r.PreventUIRefresh(-1)
  local mode_name = (gui.mode == 0) and "Focused" or "Chain"
  local action_name = (gui.action == 0) and "Apply" or "Copy"
  r.Undo_EndBlock(string.format("AudioSweet GUI: %s %s", mode_name, action_name), -1)

  gui.is_running = false
end

local function run_focused_fx_copy_mode(tr, fx_name, fx_idx, item_count)
  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Focused FX copy: '%s' (fx_idx=%d, items=%d)\n", fx_name, fx_idx, item_count))
  end

  local fx_count = r.TrackFX_GetCount(tr)
  if fx_idx >= fx_count then
    gui.last_result = string.format("Error: FX #%d not found", fx_idx + 1)
    gui.is_running = false
    return
  end

  local scope_names = { "active", "all_takes" }
  local pos_names = { "tail", "head" }
  local scope = scope_names[gui.copy_scope + 1]
  local pos = pos_names[gui.copy_pos + 1]

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Copy settings: scope=%s, position=%s\n", scope, pos))
  end

  local ops = 0
  for i = 0, item_count - 1 do
    local it = r.GetSelectedMediaItem(0, i)
    if it then
      if scope == "all_takes" then
        local take_count = r.CountTakes(it)
        for t = 0, take_count - 1 do
          local tk = r.GetTake(it, t)
          if tk then
            local dest_idx = (pos == "head") and 0 or r.TakeFX_GetCount(tk)
            r.TrackFX_CopyToTake(tr, fx_idx, tk, dest_idx, false)
            ops = ops + 1
          end
        end
      else
        local tk = r.GetActiveTake(it)
        if tk then
          local dest_idx = (pos == "head") and 0 or r.TakeFX_GetCount(tk)
          r.TrackFX_CopyToTake(tr, fx_idx, tk, dest_idx, false)
          ops = ops + 1
        end
      end
    end
  end

  r.UpdateArrange()

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Focused FX copy completed: %d operations\n", ops))
  end

  gui.last_result = string.format("Success! [%s] Copy (%d ops)", fx_name, ops)
  gui.is_running = false
end

local function run_saved_chain_copy_mode(tr, chain_name, item_count)
  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Chain copy: '%s' (items=%d)\n", chain_name, item_count))
  end

  local fx_count = r.TrackFX_GetCount(tr)
  if fx_count == 0 then
    gui.last_result = "Error: No FX on track"
    gui.is_running = false
    return
  end

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Track has %d FX to copy\n", fx_count))
  end

  local scope_names = { "active", "all_takes" }
  local pos_names = { "tail", "head" }
  local scope = scope_names[gui.copy_scope + 1]
  local pos = pos_names[gui.copy_pos + 1]

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Copy settings: scope=%s, position=%s\n", scope, pos))
  end

  local ops = 0
  for i = 0, item_count - 1 do
    local it = r.GetSelectedMediaItem(0, i)
    if it then
      if scope == "all_takes" then
        local take_count = r.CountTakes(it)
        for t = 0, take_count - 1 do
          local tk = r.GetTake(it, t)
          if tk then
            for fx = 0, fx_count - 1 do
              local dest_idx = (pos == "head") and 0 or r.TakeFX_GetCount(tk)
              r.TrackFX_CopyToTake(tr, fx, tk, dest_idx, false)
              ops = ops + 1
            end
          end
        end
      else
        local tk = r.GetActiveTake(it)
        if tk then
          if pos == "head" then
            for fx = fx_count - 1, 0, -1 do
              r.TrackFX_CopyToTake(tr, fx, tk, 0, false)
              ops = ops + 1
            end
          else
            for fx = 0, fx_count - 1 do
              local dest_idx = r.TakeFX_GetCount(tk)
              r.TrackFX_CopyToTake(tr, fx, tk, dest_idx, false)
              ops = ops + 1
            end
          end
        end
      end
    end
  end

  r.UpdateArrange()

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Chain copy completed: %d operations\n", ops))
  end

  gui.last_result = string.format("Success! [%s] Copy (%d ops)", chain_name, ops)
  gui.is_running = false
end

local function run_saved_chain_apply_mode(tr, chain_name, item_count)
  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Saved chain apply: '%s' (items=%d)\n", chain_name, item_count))
  end

  -- Check if track has FX
  local fx_count = r.TrackFX_GetCount(tr)
  if fx_count == 0 then
    gui.last_result = "Error: No FX on track"
    gui.is_running = false
    return
  end

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Track has %d FX\n", fx_count))
  end

  -- Set track as last touched (without changing selection)
  -- Note: We don't call SetOnlyTrackSelected() to preserve item selection
  -- Core will snapshot the current selection and restore it at the end
  r.SetMixerScroll(tr)

  -- Open FX chain window if setting enabled
  if gui.show_fx_on_recall then
    if gui.debug then
      r.ShowConsoleMsg("[AS GUI] Opening FX chain window for target track\n")
    end
    -- Use TrackFX_Show to open the specific track's FX chain
    -- Flag 1 = show FX chain window
    r.TrackFX_Show(tr, 0, 1)
  else
    if gui.debug then
      r.ShowConsoleMsg("[AS GUI] Skipping FX chain window (show_fx_on_recall = false)\n")
    end
  end

  if gui.debug then
    r.ShowConsoleMsg("[AS GUI] Track set as last touched\n")
  end

  -- Set ExtState for AudioSweet (chain mode)
  local action_names = { "apply", "copy" }

  r.SetExtState("hsuanice_AS", "AS_MODE", "chain", false)
  r.SetExtState("hsuanice_AS", "AS_ACTION", action_names[gui.action + 1], false)
  r.SetExtState("hsuanice_AS", "DEBUG", gui.debug and "1" or "0", false)

  -- Set OVERRIDE ExtState to specify track and FX for Core
  -- (bypasses GetFocusedFX check which fails for CLAP plugins)
  local track_idx = r.CSurf_TrackToID(tr, false) - 1  -- Convert to 0-based index
  r.SetExtState("hsuanice_AS", "OVERRIDE_TRACK_IDX", tostring(track_idx), false)
  r.SetExtState("hsuanice_AS", "OVERRIDE_FX_IDX", "0", false)  -- Chain mode uses first FX

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] OVERRIDE set: track_idx=%d fx_idx=0\n", track_idx))
  end
  r.SetExtState("hsuanice_AS", "AS_SHOW_SUMMARY", "0", false)
  r.SetProjExtState(0, "RGWH", "HANDLE_SECONDS", tostring(gui.handle_seconds))
  r.SetProjExtState(0, "RGWH", "DEBUG_LEVEL", gui.debug and "2" or "0")

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Executing AudioSweet Core (mode=chain, action=%s, handle=%.1fs)\n",
      gui.action == 0 and "apply" or "copy", gui.handle_seconds))
  end

  -- Run AudioSweet Core (it will use the focused track's FX chain)
  -- Note: Core handles selection save/restore internally
  local ok, err = pcall(dofile, CORE_PATH)
  r.UpdateArrange()

  if ok then
    if gui.debug then
      r.ShowConsoleMsg(string.format("[AS GUI] Execution completed successfully\n"))
    end
    gui.last_result = string.format("Success! [%s] Apply (%d items)", chain_name, item_count)
  else
    if gui.debug then
      r.ShowConsoleMsg(string.format("[AS GUI] ERROR: %s\n", tostring(err)))
    end
    gui.last_result = "Error: " .. tostring(err)
  end

  gui.is_running = false
end

local function open_saved_chain_fx(chain_idx)
  local chain = gui.saved_chains[chain_idx]
  if not chain then return end

  local tr = find_track_by_guid(chain.track_guid)
  if not tr then
    gui.last_result = string.format("Error: Track '%s' not found", chain.track_name)
    return
  end

  -- Select track and set as last touched
  r.SetOnlyTrackSelected(tr)
  r.SetMixerScroll(tr)

  local fx_count = r.TrackFX_GetCount(tr)
  if fx_count == 0 then
    gui.last_result = string.format("Error: No FX on track '%s'", chain.track_name)
    return
  end

  -- Determine window type based on how it was saved
  if chain.mode == "focused" then
    -- Focused FX preset: toggle floating window for the specific FX
    local fx_idx = nil
    local found_fx_name = nil

    -- Method 1: Try saved fx_index first
    if chain.fx_index and chain.fx_index < fx_count then
      local _, fx_name = r.TrackFX_GetFXName(tr, chain.fx_index, "")
      -- Verify this is still the same FX
      if fx_name == chain.name then
        fx_idx = chain.fx_index
        found_fx_name = fx_name
      end
    end

    -- Method 2: If index didn't match, search by name
    if not fx_idx then
      for i = 0, fx_count - 1 do
        local _, fx_name = r.TrackFX_GetFXName(tr, i, "")
        if fx_name == chain.name then
          fx_idx = i
          found_fx_name = fx_name
          break
        end
      end
    end

    -- Check if FX was found
    if not fx_idx then
      gui.last_result = string.format("Error: FX '%s' not found on track", chain.name)
      return
    end

    if gui.debug then
      r.ShowConsoleMsg(string.format("[AudioSweet] Open preset: saved_name='%s', saved_index=%s, actual_index=%d, actual_name='%s'\n",
        chain.name, tostring(chain.fx_index or "nil"), fx_idx, found_fx_name))
    end

    local is_open = r.TrackFX_GetOpen(tr, fx_idx)
    if is_open then
      r.TrackFX_Show(tr, fx_idx, 2)  -- Hide floating window
    else
      r.TrackFX_Show(tr, fx_idx, 3)  -- Show floating window
    end
    gui.last_result = string.format("Toggled FX #%d: %s", fx_idx + 1, found_fx_name)
  else
    -- Chain preset: toggle FX chain window
    local chain_visible = r.TrackFX_GetChainVisible(tr)

    if gui.debug then
      r.ShowConsoleMsg(string.format("[AudioSweet] Open chain: name='%s', mode='%s', chain_visible=%d\n",
        chain.name or "nil", chain.mode or "chain", chain_visible))
    end

    if chain_visible == -1 then
      -- Chain window is closed, open it
      r.TrackFX_Show(tr, 0, 1)  -- Show chain window
    else
      -- Chain window is open, close it
      r.TrackFX_Show(tr, 0, 0)  -- Hide chain window
    end
    gui.last_result = string.format("Toggled FX chain: %s", chain.name)
  end
end

local function open_history_fx(hist_idx)
  local hist_item = gui.history[hist_idx]
  if not hist_item then return end

  local tr = find_track_by_guid(hist_item.track_guid)
  if not tr then
    gui.last_result = string.format("Error: Track '%s' not found", hist_item.track_name)
    return
  end

  -- Select track and set as last touched
  r.SetOnlyTrackSelected(tr)
  r.SetMixerScroll(tr)

  -- Toggle FX window based on history mode
  if hist_item.mode == "focused" then
    -- For focused mode, toggle the specific FX floating window
    local fx_idx = hist_item.fx_index or 0
    local fx_count = r.TrackFX_GetCount(tr)

    if fx_idx >= fx_count then
      gui.last_result = string.format("Error: FX #%d not found (track has %d FX)", fx_idx + 1, fx_count)
      return
    end

    -- Toggle specific FX floating window
    -- Check if FX is open using TrackFX_GetOpen
    local is_open = r.TrackFX_GetOpen(tr, fx_idx)
    if is_open then
      r.TrackFX_Show(tr, fx_idx, 2)  -- Hide floating window
    else
      r.TrackFX_Show(tr, fx_idx, 3)  -- Show floating window
    end
    gui.last_result = string.format("Toggled FX: %s (FX #%d)", hist_item.name, fx_idx + 1)
  else
    -- For chain mode, toggle FX chain window (chain mode uses entire FX chain)
    local chain_visible = r.TrackFX_GetChainVisible(tr)

    if gui.debug then
      r.ShowConsoleMsg(string.format("[AudioSweet] Open history chain: name='%s', mode='%s', chain_visible=%d\n",
        hist_item.name or "nil", hist_item.mode or "chain", chain_visible))
    end

    if chain_visible == -1 then
      -- Chain window is closed, open it
      r.TrackFX_Show(tr, 0, 1)  -- Show chain window
    else
      -- Chain window is open, close it
      r.TrackFX_Show(tr, 0, 0)  -- Hide chain window
    end
    gui.last_result = string.format("Toggled FX chain: %s", hist_item.name)
  end
end

local function run_history_focused_apply(tr, fx_name, fx_idx, item_count)
  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] History focused apply: '%s' (fx_idx=%d, items=%d)\n", fx_name, fx_idx, item_count))
  end

  -- Validate FX still exists at this index
  local fx_count = r.TrackFX_GetCount(tr)
  if fx_idx >= fx_count then
    gui.last_result = string.format("Error: FX #%d not found (track only has %d FX)", fx_idx + 1, fx_count)
    gui.is_running = false
    return
  end

  -- Set track as last touched (without changing selection)
  -- Note: We don't call SetOnlyTrackSelected() to preserve item selection
  -- Core will snapshot the current selection and restore it at the end
  r.SetMixerScroll(tr)

  -- Open specific FX as floating window if setting enabled
  -- Note: Focus detection is not required - Core will work regardless
  if gui.show_fx_on_recall then
    if gui.debug then
      r.ShowConsoleMsg(string.format("[AS GUI] Opening FX #%d floating window\n", fx_idx + 1))
    end
    r.TrackFX_Show(tr, fx_idx, 3)  -- Show floating window (flag 3)

    -- Small delay to ensure FX window is fully opened before Core checks it
    -- This prevents "Please focus a Track FX" warning
    r.defer(function() end)  -- Process one defer cycle
  else
    if gui.debug then
      r.ShowConsoleMsg("[AS GUI] Skipping FX window (show_fx_on_recall = false)\n")
    end
  end

  -- Set ExtState for AudioSweet (focused mode)
  set_extstate_from_gui()
  r.SetExtState("hsuanice_AS", "AS_MODE", "focused", false)

  -- Set OVERRIDE ExtState to specify exact FX (bypasses GetFocusedFX check)
  -- This ensures Core processes the correct FX even if focus detection fails
  local track_idx = r.CSurf_TrackToID(tr, false) - 1  -- Convert to 0-based index
  r.SetExtState("hsuanice_AS", "OVERRIDE_TRACK_IDX", tostring(track_idx), false)
  r.SetExtState("hsuanice_AS", "OVERRIDE_FX_IDX", tostring(fx_idx), false)

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AS GUI] Executing AudioSweet Core (mode=focused, action=%s, handle=%.1fs)\n",
      gui.action == 0 and "apply" or "copy", gui.handle_seconds))
  end

  -- Run AudioSweet Core
  -- Note: Core handles selection save/restore internally
  local ok, err = pcall(dofile, CORE_PATH)
  r.UpdateArrange()

  if ok then
    if gui.debug then
      r.ShowConsoleMsg("[AS GUI] Execution completed successfully\n")
    end
    gui.last_result = string.format("Success! [%s] Apply (%d items)", fx_name, item_count)
  else
    if gui.debug then
      r.ShowConsoleMsg(string.format("[AS GUI] ERROR: %s\n", tostring(err)))
    end
    gui.last_result = "Error: " .. tostring(err)
  end

  gui.is_running = false
end

local function run_saved_chain(chain_idx)
  local chain = gui.saved_chains[chain_idx]
  if not chain then return end

  if gui.debug then
    r.ShowConsoleMsg(string.format("[AudioSweet] Run preset #%d: name='%s', mode='%s', fx_index=%s\n",
      chain_idx, chain.name, chain.mode or "chain", tostring(chain.fx_index or "nil")))
  end

  local tr = find_track_by_guid(chain.track_guid)
  if not tr then
    gui.last_result = string.format("Error: Track '%s' not found", chain.track_name)
    return
  end

  local item_count = r.CountSelectedMediaItems(0)
  if item_count == 0 then
    gui.last_result = "Error: No items selected"
    return
  end

  if gui.is_running then return end

  gui.is_running = true
  gui.last_result = "Running..."

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  -- Execute based on saved mode (chain or focused)
  if chain.mode == "focused" then
    -- For focused mode, use stored FX index
    if gui.action == 1 then
      run_focused_fx_copy_mode(tr, chain.name, chain.fx_index or 0, item_count)
    else
      run_history_focused_apply(tr, chain.name, chain.fx_index or 0, item_count)
    end
  else
    -- Chain mode - use chain execution
    if gui.action == 1 then
      run_saved_chain_copy_mode(tr, chain.name, item_count)
    else
      run_saved_chain_apply_mode(tr, chain.name, item_count)
    end
  end

  -- Add to history with correct mode, fx_index, and custom_name
  add_to_history(chain.name, chain.track_guid, chain.track_name, chain.mode or "chain", chain.fx_index or 0, chain.custom_name)

  r.PreventUIRefresh(-1)
  r.Undo_EndBlock(string.format("AudioSweet GUI: %s [%s]", gui.action == 1 and "Copy" or "Apply", chain.name), -1)
end

local function run_history_item(hist_idx)
  local hist_item = gui.history[hist_idx]
  if not hist_item then return end

  local tr = find_track_by_guid(hist_item.track_guid)
  if not tr then
    gui.last_result = string.format("Error: Track '%s' not found", hist_item.track_name)
    return
  end

  local item_count = r.CountSelectedMediaItems(0)
  if item_count == 0 then
    gui.last_result = "Error: No items selected"
    return
  end

  if gui.is_running then return end

  gui.is_running = true
  gui.last_result = "Running..."

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  -- Check if this was originally a focused FX or chain
  if hist_item.mode == "focused" then
    -- For focused mode, use stored FX index
    if gui.action == 1 then
      run_focused_fx_copy_mode(tr, hist_item.name, hist_item.fx_index or 0, item_count)
    else
      run_history_focused_apply(tr, hist_item.name, hist_item.fx_index or 0, item_count)
    end
  else
    -- Chain mode - use saved chain execution
    if gui.action == 1 then
      run_saved_chain_copy_mode(tr, hist_item.name, item_count)
    else
      run_saved_chain_apply_mode(tr, hist_item.name, item_count)
    end
  end

  -- Note: History doesn't re-add to history to avoid duplication

  r.PreventUIRefresh(-1)
  r.Undo_EndBlock(string.format("AudioSweet GUI: %s [%s]", gui.action == 1 and "Copy" or "Apply", hist_item.name), -1)
end

------------------------------------------------------------
-- GUI Rendering
------------------------------------------------------------
local function draw_gui()
  -- Auto-reset is_previewing when transport stops
  if gui.is_previewing then
    local play_state = r.GetPlayState()
    if play_state == 0 then  -- 0 = stopped
      gui.is_previewing = false
      if gui.last_result == "Preview: Success" or gui.last_result == "Preview stopped" then
        gui.last_result = "Preview stopped (auto-detected)"
      end
    end
  end

  -- Keyboard shortcuts (only work when NOT typing in text inputs)
  local is_typing = ImGui.IsAnyItemActive(ctx)

  if not is_typing then
    -- Space = Stop transport (simple, no modifiers needed)
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Space, false) then
      if gui.debug then
        r.ShowConsoleMsg("[AS GUI] Keyboard shortcut: Space (Stop transport, command=40044)\n")
      end
      r.Main_OnCommand(40044, 0)  -- Transport: Stop
    end

    -- S = Solo toggle (depends on solo_scope setting)
    if ImGui.IsKeyPressed(ctx, ImGui.Key_S, false) then
      if gui.debug then
        local scope_name = (gui.preview_solo_scope == 0) and "Track Solo" or "Item Solo"
        r.ShowConsoleMsg(string.format("[AS GUI] Keyboard shortcut: S pressed (scope=%s)\n", scope_name))
      end
      toggle_solo()
    end
  end

  -- Note: Preview shortcuts with modifiers (Ctrl+Space, etc.) should use Tools scripts
  -- Users should bind keyboard shortcuts to:
  --   - "hsuanice_AudioSweet Chain Preview Solo Exclusive" (for Chain mode)
  --   - "hsuanice_AudioSweet Preview Solo Exclusive" (for Focused mode)
  -- These scripts read settings from GUI ExtState automatically

  local window_flags = ImGui.WindowFlags_MenuBar |
                       ImGui.WindowFlags_AlwaysAutoResize |
                       ImGui.WindowFlags_NoResize |
                       ImGui.WindowFlags_NoCollapse

  -- Add NoDocking flag if docking is disabled
  if not gui.enable_docking then
    window_flags = window_flags | ImGui.WindowFlags_NoDocking
  end

  -- Set minimum window size to make buttons more readable (min width: 700px)
  ImGui.SetNextWindowSizeConstraints(ctx, 450, 0, 99999, 99999)

  local visible, open = ImGui.Begin(ctx, 'AudioSweet Control Panel', true, window_flags)
  if not visible then
    ImGui.End(ctx)
    return open
  end

  -- Close the window when ESC is pressed and the window is focused
  if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    open = false
    if gui.debug then
      r.ShowConsoleMsg("[AS GUI] Keyboard shortcut: ESC pressed (Close window)\n")
    end
  end

  -- Menu Bar
  if ImGui.BeginMenuBar(ctx) then
    if ImGui.BeginMenu(ctx, 'Presets') then
      if ImGui.MenuItem(ctx, 'Focused Apply', nil, false, true) then
        gui.mode = 0; gui.action = 0
        save_gui_settings()
      end
      if ImGui.MenuItem(ctx, 'Focused Copy', nil, false, true) then
        gui.mode = 0; gui.action = 1; gui.copy_scope = 0; gui.copy_pos = 0
        save_gui_settings()
      end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, 'Chain Apply', nil, false, true) then
        gui.mode = 1; gui.action = 0
        save_gui_settings()
      end
      if ImGui.MenuItem(ctx, 'Chain Copy', nil, false, true) then
        gui.mode = 1; gui.action = 1; gui.copy_scope = 0; gui.copy_pos = 0
        save_gui_settings()
      end
      ImGui.EndMenu(ctx)
    end

    if ImGui.BeginMenu(ctx, 'Debug') then
      local rv, new_val = ImGui.MenuItem(ctx, 'Enable Debug Mode', nil, gui.debug, true)
      if rv then
        gui.debug = new_val
        save_gui_settings()
      end
      ImGui.EndMenu(ctx)
    end

    if ImGui.BeginMenu(ctx, 'Settings') then
      -- UI Settings
      local rv_dock, new_dock = ImGui.MenuItem(ctx, 'Enable Window Docking', nil, gui.enable_docking, true)
      if rv_dock then
        gui.enable_docking = new_dock
        save_gui_settings()
      end
      ImGui.Separator(ctx)

      if ImGui.MenuItem(ctx, 'Preview Settings...', nil, false, true) then
        gui.show_preview_settings = true
      end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, 'History Settings...', nil, false, gui.enable_history) then
        gui.show_settings_popup = true
      end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, 'File Naming Settings...', nil, false, true) then
        gui.show_naming_popup = true
      end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, 'Timecode Embed Settings...', nil, false, true) then
        gui.show_tc_embed_popup = true
      end
      ImGui.Separator(ctx)
      if ImGui.BeginMenu(ctx, 'FX Alias Tools') then
        if ImGui.MenuItem(ctx, 'Build FX Alias Database', nil, false, true) then
          local script_path = r.GetResourcePath() .. "/Scripts/hsuanice Scripts/Tools/hsuanice_FX Alias Build.lua"
          local success, err = pcall(dofile, script_path)
          if success then
            r.ShowConsoleMsg("[AS GUI] FX Alias Build completed\n")
          else
            r.ShowConsoleMsg("[AS GUI] Error running FX Alias Build: " .. tostring(err) .. "\n")
          end
        end
        if ImGui.MenuItem(ctx, 'Export JSON to TSV', nil, false, true) then
          local script_path = r.GetResourcePath() .. "/Scripts/hsuanice Scripts/Tools/hsuanice_FX Alias Export JSON to TSV.lua"
          local success, err = pcall(dofile, script_path)
          if success then
            r.ShowConsoleMsg("[AS GUI] FX Alias Export completed\n")
          else
            r.ShowConsoleMsg("[AS GUI] Error running FX Alias Export: " .. tostring(err) .. "\n")
          end
        end
        if ImGui.MenuItem(ctx, 'Update TSV to JSON', nil, false, true) then
          local script_path = r.GetResourcePath() .. "/Scripts/hsuanice Scripts/Tools/hsuanice_FX Alias Update TSV to JSON.lua"
          local success, err = pcall(dofile, script_path)
          if success then
            r.ShowConsoleMsg("[AS GUI] FX Alias Update completed\n")
          else
            r.ShowConsoleMsg("[AS GUI] Error running FX Alias Update: " .. tostring(err) .. "\n")
          end
        end
        ImGui.EndMenu(ctx)
      end
      ImGui.EndMenu(ctx)
    end

    if ImGui.BeginMenu(ctx, 'Help') then
      if ImGui.MenuItem(ctx, 'About', nil, false, true) then
        r.ShowConsoleMsg(
          "=================================================\n" ..
          "AudioSweet ReaImGui - ImGui Interface for AudioSweet\n" ..
          "=================================================\n" ..
          "Version: 0.1.1 (251218)\n" ..
          "Author: hsuanice\n\n" ..

          "Quick Start:\n" ..
          "  1. Select a track with FX or focus an FX window\n" ..
          "  2. Choose mode: Focused (single FX) or Chain (full track)\n" ..
          "  3. Click Apply to audition or Copy to prepare\n" ..
          "  4. Click Save to store presets for later use\n\n" ..

          "Key Features:\n" ..
          "  - Focused/Chain modes with real-time FX display\n" ..
          "  - Preset library with custom naming and rename sync\n" ..
          "  - Auto-tracked history (up to 50 operations)\n" ..
          "  - Keyboard shortcuts (Space=Play/Stop, S=Solo)\n" ..
          "  - Comprehensive file naming settings with FX Alias\n" ..
          "  - Debug mode with detailed console logging\n\n" ..


          "Reference:\n" ..
          "  Inspired by AudioSuite-like Script by Tim Chimes\n" ..
          "  'AudioSweet' is a name originally given by Tim Chimes.  \n" ..
          "  This project continues to use the name in reference to his original work.\n\n" ..
          "  Original: Renders selected plugin to selected media item\n" ..
          "  Written for REAPER 5.1 with Lua\n" ..
          "  v1.1 12/22/2015 - Added PreventUIRefresh\n" ..
          "  http://timchimes.com/scripting-with-reaper-audiosuite/\n\n" ..

          "Development:\n" ..
          "  This script was developed with the assistance of AI tools\n" ..
          "  including ChatGPT and Claude AI.\n" ..
          "=================================================\n"
        )
      end
    ImGui.EndMenu(ctx)
  end

  ImGui.EndMenuBar(ctx)
end

  draw_bwfmetaedit_warning_banner()

  -- Settings Popup
  if gui.show_settings_popup then
    -- Position popup near mouse cursor
    local mouse_x, mouse_y = r.GetMousePosition()
    ImGui.SetNextWindowPos(ctx, mouse_x, mouse_y, ImGui.Cond_Appearing)
    ImGui.OpenPopup(ctx, 'History Settings')
    gui.show_settings_popup = false
  end

  if ImGui.BeginPopupModal(ctx, 'History Settings', true, ImGui.WindowFlags_AlwaysAutoResize) then
    -- ESC key handling for popup (only when popup is focused)
    if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.Text(ctx, "Maximum History Items:")
    ImGui.SetNextItemWidth(ctx, 120)
    local rv, new_val = ImGui.InputInt(ctx, "##max_history", gui.max_history)
    if rv then
      gui.max_history = math.max(1, math.min(50, new_val))  -- Limit 1-50
      save_gui_settings()
      -- Trim history if needed
      while #gui.history > gui.max_history do
        table.remove(gui.history)
      end
    end

    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Range: 1-50 items")

    ImGui.Separator(ctx)
    if ImGui.Button(ctx, 'Close', 120, 0) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

  -- FX Name Formatting Popup
  -- File Naming Settings Popup
  if gui.show_naming_popup then
    -- Position popup near mouse cursor
    local mouse_x, mouse_y = r.GetMousePosition()
    ImGui.SetNextWindowPos(ctx, mouse_x, mouse_y, ImGui.Cond_Appearing)
    ImGui.OpenPopup(ctx, 'File Naming Settings')
    gui.show_naming_popup = false
  end

  if ImGui.BeginPopupModal(ctx, 'File Naming Settings', true, ImGui.WindowFlags_AlwaysAutoResize) then
    -- ESC key handling for popup (only when popup is focused)
    if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
      ImGui.CloseCurrentPopup(ctx)
    end

    local changed = false
    local rv

    -- === Global FX Name Settings (applies to Focused & Chain modes) ===
    ImGui.Text(ctx, "Global FX Name Settings:")
    ImGui.TextDisabled(ctx, "(applies to both Focused and Chain modes)")
    ImGui.Separator(ctx)

    rv, gui.fxname_show_type = ImGui.Checkbox(ctx, "Show Plugin Type (CLAP:, VST3:, AU:, VST:)", gui.fxname_show_type)
    if rv then changed = true end

    rv, gui.fxname_show_vendor = ImGui.Checkbox(ctx, "Show Vendor Name (FabFilter)", gui.fxname_show_vendor)
    if rv then changed = true end

    rv, gui.fxname_strip_symbol = ImGui.Checkbox(ctx, "Strip Spaces & Symbols (ProQ4 vs Pro-Q 4)", gui.fxname_strip_symbol)
    if rv then changed = true end

    rv, gui.use_alias = ImGui.Checkbox(ctx, "Use FX Alias for file naming", gui.use_alias)
    if rv then changed = true end

    ImGui.Text(ctx, "Max FX Tokens:")
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 80)
    rv, gui.max_fx_tokens = ImGui.InputInt(ctx, "##max_tokens", gui.max_fx_tokens)
    if rv then
      gui.max_fx_tokens = math.max(1, math.min(10, gui.max_fx_tokens))
      changed = true
    end
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "(FIFO limit, 1-10)")

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- === Chain Mode Specific Settings ===
    ImGui.Text(ctx, "Chain Mode Specific Settings:")
    ImGui.Separator(ctx)

    ImGui.Text(ctx, "Chain Token Source:")
    if ImGui.RadioButton(ctx, "Track Name", gui.chain_token_source == 0) then
      gui.chain_token_source = 0
      changed = true
    end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "FX Aliases", gui.chain_token_source == 1) then
      gui.chain_token_source = 1
      changed = true
    end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "FXChain", gui.chain_token_source == 2) then
      gui.chain_token_source = 2
      changed = true
    end

    -- Chain Alias Joiner (only when using aliases)
    if gui.chain_token_source == 1 then
      ImGui.Text(ctx, "Alias Joiner:")
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 100)
      rv, gui.chain_alias_joiner = ImGui.InputText(ctx, "##chain_joiner", gui.chain_alias_joiner)
      if rv then changed = true end
      ImGui.SameLine(ctx)
      ImGui.TextDisabled(ctx, "(separator between aliases)")
    end

    rv, gui.trackname_strip_symbols = ImGui.Checkbox(ctx, "Strip Symbols from Track Names", gui.trackname_strip_symbols)
    if rv then changed = true end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- === File Safety Section ===
    ImGui.Text(ctx, "File Name Safety:")
    ImGui.Separator(ctx)

    rv, gui.sanitize_token = ImGui.Checkbox(ctx, "Sanitize tokens for safe filenames", gui.sanitize_token)
    if rv then changed = true end
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "(?)")
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Replace unsafe characters with underscores")
    end

    if changed then
      save_gui_settings()
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    if ImGui.Button(ctx, 'Close', 120, 0) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

  -- Target Track Name Popup (simple input)
  if gui.show_target_track_popup then
    ImGui.OpenPopup(ctx, 'Edit Preview Target Track')
    gui.show_target_track_popup = false
  end

  if ImGui.BeginPopupModal(ctx, 'Edit Preview Target Track', true, ImGui.WindowFlags_AlwaysAutoResize) then
    ImGui.Text(ctx, "Enter target track name for preview:")
    ImGui.SetNextItemWidth(ctx, 250)
    local rv, new_target = ImGui.InputText(ctx, "##target_track_input", gui.preview_target_track)
    if rv then
      gui.preview_target_track = new_target
      save_gui_settings()
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- "Set First Selected Track" button
    if ImGui.Button(ctx, 'Set First Selected Track', 250, 0) then
      local first_track = r.GetSelectedTrack(0, 0)  -- Get first selected track (index 0)
      if first_track then
        local _, track_name = r.GetSetMediaTrackInfo_String(first_track, "P_NAME", "", false)
        local track_guid = get_track_guid(first_track)
        gui.preview_target_track = track_name
        gui.preview_target_track_guid = track_guid
        save_gui_settings()
        if gui.debug then
          r.ShowConsoleMsg(string.format("[AudioSweet] Preview target set to first selected track: %s (GUID: %s)\n",
            track_name, track_guid))
        end
      else
        if gui.debug then
          r.ShowConsoleMsg("[AudioSweet] No track selected\n")
        end
      end
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    if ImGui.Button(ctx, 'OK', 100, 0) then
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Cancel', 100, 0) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

  -- Preview Settings Popup
  if gui.show_preview_settings then
    -- Position popup near mouse cursor
    local mouse_x, mouse_y = r.GetMousePosition()
    ImGui.SetNextWindowPos(ctx, mouse_x, mouse_y, ImGui.Cond_Appearing)
    ImGui.OpenPopup(ctx, 'Preview Settings')
    gui.show_preview_settings = false
  end

  if ImGui.BeginPopupModal(ctx, 'Preview Settings', true, ImGui.WindowFlags_AlwaysAutoResize) then
    -- ESC key handling for popup (only when popup is focused)
    if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.Text(ctx, "Target Track Name:")
    ImGui.SetNextItemWidth(ctx, 200)
    local rv, new_name = ImGui.InputText(ctx, "##preview_target", gui.preview_target_track)
    if rv then
      gui.preview_target_track = new_name
      save_gui_settings()
    end
    ImGui.TextWrapped(ctx, "The track where preview will be applied")

    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Solo Scope:")
    local changed_scope = false
    if ImGui.RadioButton(ctx, "Track Solo (40281)", gui.preview_solo_scope == 0) then
      gui.preview_solo_scope = 0
      changed_scope = true
    end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Item Solo (41561)", gui.preview_solo_scope == 1) then
      gui.preview_solo_scope = 1
      changed_scope = true
    end
    if changed_scope then
      save_gui_settings()
    end

    -- Warning for Item Solo lag
    if gui.preview_solo_scope == 1 then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAA00FF)  -- Orange color
      ImGui.TextWrapped(ctx, "Note: Item Solo may have a slight lag when toggling, not as responsive as Track Solo.")
      ImGui.PopStyleColor(ctx)
    end

    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Restore Mode:")
    local changed_restore = false
    if ImGui.RadioButton(ctx, "Time Selection", gui.preview_restore_mode == 0) then
      gui.preview_restore_mode = 0
      changed_restore = true
    end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "GUID", gui.preview_restore_mode == 1) then
      gui.preview_restore_mode = 1
      changed_restore = true
    end
    if changed_restore then
      save_gui_settings()
    end

    ImGui.Separator(ctx)
    if ImGui.Button(ctx, 'Close', 120, 0) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end
  
  draw_tc_embed_settings_popup()
  draw_bwfmetaedit_install_modal()

  -- Main content with compact layout
  local has_valid_fx = update_focused_fx_display()
  local item_count = r.CountSelectedMediaItems(0)

  -- === MODE & ACTION (Radio buttons, horizontal) ===
  ImGui.Text(ctx, "Mode:")
  ImGui.SameLine(ctx)
  if ImGui.RadioButton(ctx, "Focused", gui.mode == 0) then
    gui.mode = 0
    save_gui_settings()
  end
  ImGui.SameLine(ctx)
  if ImGui.RadioButton(ctx, "Chain", gui.mode == 1) then
    gui.mode = 1
    save_gui_settings()
  end

  ImGui.SameLine(ctx, 0, 30)
  ImGui.Text(ctx, "Action:")
  ImGui.SameLine(ctx)
  if ImGui.RadioButton(ctx, "Apply", gui.action == 0) then
    gui.action = 0
    save_gui_settings()
  end
  ImGui.SameLine(ctx)
  if ImGui.RadioButton(ctx, "Copy", gui.action == 1) then
    gui.action = 1
    save_gui_settings()
  end

  -- === TARGET TRACK NAME (Chain mode only) ===
  if gui.mode == 1 then
    ImGui.Text(ctx, "Preview Target:")
    ImGui.SameLine(ctx)
    -- Display current target track name as a button
    -- Use ## ID to handle empty string case
    local display_name = (gui.preview_target_track ~= "") and gui.preview_target_track or "(not set)"
    if ImGui.Button(ctx, display_name .. "##target_track_btn", 150, 0) then
      gui.show_target_track_popup = true
    end
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "(click to edit)")
  end

  -- === COPY/APPLY SETTINGS (Compact horizontal) ===
  if gui.action == 1 then
    ImGui.Text(ctx, "Copy to:")
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Active##scope", gui.copy_scope == 0) then
      gui.copy_scope = 0
      save_gui_settings()
    end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "All Takes##scope", gui.copy_scope == 1) then
      gui.copy_scope = 1
      save_gui_settings()
    end
    ImGui.SameLine(ctx, 0, 20)
    if ImGui.RadioButton(ctx, "Tail##pos", gui.copy_pos == 0) then
      gui.copy_pos = 0
      save_gui_settings()
    end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Head##pos", gui.copy_pos == 1) then
      gui.copy_pos = 1
      save_gui_settings()
    end
  else
    -- Handle seconds
    ImGui.Text(ctx, "Handle:")
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 80)
    local rv, new_val = ImGui.InputDouble(ctx, "##handle_seconds", gui.handle_seconds, 0, 0, "%.1f")
    if rv then
      gui.handle_seconds = math.max(0, new_val)
      save_gui_settings()
    end
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "seconds")

    -- Channel Mode
    ImGui.Text(ctx, "Channel:")
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Auto##channel", gui.channel_mode == 0) then
      gui.channel_mode = 0
      save_gui_settings()
    end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Mono##channel", gui.channel_mode == 1) then
      gui.channel_mode = 1
      save_gui_settings()
    end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Multi##channel", gui.channel_mode == 2) then
      gui.channel_mode = 2
      save_gui_settings()
    end
  end

  ImGui.Separator(ctx)

  -- === RUN BUTTONS: PREVIEW / SOLO / AUDIOSWEET ===
  local can_run = has_valid_fx and item_count > 0 and not gui.is_running

  -- Calculate button widths (3 buttons with spacing)
  local avail_width = ImGui.GetContentRegionAvail(ctx)
  local spacing = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
  local button_width = (avail_width - spacing * 2) / 3

  -- PREVIEW button (toggle: preview/stop)
  -- Check if transport is playing (includes previews started by Tools scripts)
  local play_state = r.GetPlayState()
  local is_playing = (play_state & 1 ~= 0)  -- bit 1 = playing
  local is_previewing_now = gui.is_previewing or is_playing

  -- Preview can run if:
  -- - Focused mode: has valid focused FX + has items + not running
  -- - Chain mode: has items + not running (no focused FX required, uses target track)
  -- - Already previewing/playing: always enabled to allow stopping
  local preview_can_run
  if is_previewing_now then
    preview_can_run = true  -- Always allow stopping
  elseif gui.mode == 0 then
    -- Focused mode: requires valid FX
    preview_can_run = has_valid_fx and item_count > 0 and not gui.is_running
  else
    -- Chain mode: only requires items (uses target track)
    preview_can_run = item_count > 0 and not gui.is_running
  end

  if not preview_can_run then ImGui.BeginDisabled(ctx) end

  -- Change button color if previewing
  if is_previewing_now then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFF6600FF)  -- Orange when previewing
  end

  local button_label = is_previewing_now and "STOP" or "PREVIEW"
  if ImGui.Button(ctx, button_label, button_width, 35) then
    toggle_preview()
  end

  if is_previewing_now then
    ImGui.PopStyleColor(ctx)
  end
  if not preview_can_run then ImGui.EndDisabled(ctx) end

  ImGui.SameLine(ctx)

  -- SOLO button (always enabled)
  if ImGui.Button(ctx, "SOLO", button_width, 35) then
    toggle_solo()
  end

  ImGui.SameLine(ctx)

  -- AUDIOSWEET button
  if not can_run then ImGui.BeginDisabled(ctx) end
  if ImGui.Button(ctx, "AUDIOSWEET", button_width, 35) then
    run_audiosweet(nil)
  end
  if not can_run then ImGui.EndDisabled(ctx) end

  -- === KEYBOARD SHORTCUTS INFO ===
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x808080FF)  -- Gray color
  ImGui.Text(ctx, "Shortcuts: ESC = Close, Space = Stop, S = Solo")
  if gui.mode == 1 then
    -- Chain mode
    ImGui.Text(ctx, "Tip: Set shortcut 'Script: hsuanice_AudioSweet Chain Preview...' (Ctrl+Space)")
  else
    -- Focused mode
    ImGui.Text(ctx, "Tip: Set shortcut 'Script: hsuanice_AudioSweet Preview...' (Ctrl+Shift+Space)")
  end
  ImGui.PopStyleColor(ctx)

  ImGui.Separator(ctx)

  -- === SAVE BUTTON (above Saved/History) ===
  if gui.enable_saved_chains then
    -- Unified Save button that changes text based on mode
    local save_button_label = (gui.mode == 1) and "Save This Chain" or "Save This FX"
    local save_button_enabled = (gui.mode == 1 and #gui.focused_track_fx_list > 0) or (gui.mode == 0 and has_valid_fx)

    if not save_button_enabled then ImGui.BeginDisabled(ctx) end
    if ImGui.Button(ctx, save_button_label, -1, 0) then
      -- Unified save popup - we'll use one popup for both
      gui.show_save_popup = true
      if gui.mode == 1 then
        -- Extract only track name without "#N - " prefix
        local track_name, _ = get_track_name_and_number(gui.focused_track)
        gui.new_chain_name = track_name
        gui.new_chain_name_default = track_name  -- Store default
      else
        gui.new_chain_name = gui.focused_fx_name
        gui.new_chain_name_default = gui.focused_fx_name  -- Store default
      end
    end
    if not save_button_enabled then ImGui.EndDisabled(ctx) end
  end

  -- === QUICK PROCESS (Saved + History, side by side) ===
  if gui.enable_saved_chains or gui.enable_history then
    -- Show FX on recall checkbox
    local changed
    changed, gui.show_fx_on_recall = ImGui.Checkbox(ctx, "Show FX window on recall", gui.show_fx_on_recall)
    if changed then save_gui_settings() end

    -- Only show if at least one feature is enabled and has content
    if (gui.enable_saved_chains and #gui.saved_chains > 0) or (gui.enable_history and #gui.history > 0) then
      local avail_w = ImGui.GetContentRegionAvail(ctx)
      local col1_w = avail_w * 0.5 - 5

      -- Left: Saved FX Preset
      if gui.enable_saved_chains and #gui.saved_chains > 0 then
        if ImGui.BeginChild(ctx, "SavedCol", col1_w, 200) then
          ImGui.Text(ctx, "SAVED FX PRESET")
          ImGui.Separator(ctx)
          local to_delete = nil
          for i, chain in ipairs(gui.saved_chains) do
            ImGui.PushID(ctx, i)

            -- Get display info
            local display_name, track_info_line, fx_info, saved_fx_index = get_chain_display_info(chain)

            -- "Open" button (small, on the left)
            if ImGui.SmallButton(ctx, "Open") then
              open_saved_chain_fx(i)
            end
            ImGui.SameLine(ctx)

            -- Chain name button (executes AudioSweet) - use available width minus Delete button
            local avail_width = ImGui.GetContentRegionAvail(ctx) - 25  -- Space for "X" button
            if ImGui.Button(ctx, display_name, avail_width, 0) then
              run_saved_chain(i)
            end

            -- Hover tooltip showing track and FX info
            if ImGui.IsItemHovered(ctx) then
              show_preset_tooltip(chain)
            end

            -- Right-click context menu for renaming
            if ImGui.BeginPopupContextItem(ctx, "chain_context_" .. i) then
              if ImGui.MenuItem(ctx, "Rename") then
                gui.show_rename_popup = true
                gui.rename_chain_idx = i
                -- Pre-fill with current custom name, or use display name (without track# prefix for chains)
                if chain.custom_name and chain.custom_name ~= "" then
                  gui.rename_chain_name = chain.custom_name
                else
                  -- Use the base name without track# prefix
                  if chain.mode == "focused" then
                    gui.rename_chain_name = chain.name  -- FX name for focused mode
                  else
                    -- For chain mode, extract track name from track_info_line (#N: name)
                    local extracted_name = track_info_line:match("^#%d+: (.+)$")
                    gui.rename_chain_name = extracted_name or chain.track_name or ""
                  end
                end
              end
              ImGui.EndPopup(ctx)
            end

            ImGui.SameLine(ctx)
            -- Delete button
            if ImGui.Button(ctx, "X", 20, 0) then
              to_delete = i
            end
            ImGui.PopID(ctx)
          end
          if to_delete then delete_saved_chain(to_delete) end
          ImGui.EndChild(ctx)
        end

        ImGui.SameLine(ctx)
      end

      -- Right: History (auto-resizes based on content)
      if gui.enable_history and #gui.history > 0 then
        -- Calculate height based on number of history items (each item ~25px, header ~40px)
        local history_height = math.min(#gui.history * 25 + 40, 200)  -- Max 200px
        if ImGui.BeginChild(ctx, "HistoryCol", 0, history_height) then
          ImGui.Text(ctx, "HISTORY")
          ImGui.SameLine(ctx)
          ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + ImGui.GetContentRegionAvail(ctx) - 45)
          if ImGui.SmallButton(ctx, "Clear") then
            gui.history = {}
            -- Clear from ProjExtState
            for i = 0, gui.max_history - 1 do
              r.SetProjExtState(0, HISTORY_NAMESPACE, "hist_" .. i, "")
            end
          end
          ImGui.Separator(ctx)
          for i, item in ipairs(gui.history) do
            ImGui.PushID(ctx, 1000 + i)
            -- "Open" button (small, on the left)
            if ImGui.SmallButton(ctx, "Open") then
              open_history_fx(i)
            end
            ImGui.SameLine(ctx)
            -- History item name button (executes AudioSweet) - use available width minus Save button
            local avail_width = ImGui.GetContentRegionAvail(ctx) - 45  -- Space for "Save" button
            local display_name = get_history_display_name(item)
            if ImGui.Button(ctx, display_name, avail_width, 0) then
              run_history_item(i)
            end

            -- Hover tooltip showing track and FX info
            if ImGui.IsItemHovered(ctx) then
              show_preset_tooltip(item)
            end

            ImGui.SameLine(ctx)
            -- "Save" button to save this history item as a saved preset
            if ImGui.Button(ctx, "Save", 40, 0) then
              -- Check if this exact preset already exists in saved_chains
              local already_saved = false
              for _, chain in ipairs(gui.saved_chains) do
                if chain.track_guid == item.track_guid and chain.mode == item.mode then
                  if item.mode == "focused" then
                    -- For focused mode: check fx_index
                    if chain.fx_index == item.fx_index then
                      already_saved = true
                      break
                    end
                  else
                    -- For chain mode: check if same chain (by name)
                    if chain.name == item.name then
                      already_saved = true
                      break
                    end
                  end
                end
              end

              if already_saved then
                gui.last_result = "Info: This preset is already saved"
              else
                -- Add to saved_chains
                add_saved_chain(item.name, item.track_guid, item.track_name, nil, item.mode, item.fx_index)
                gui.last_result = "Success: History item saved to presets"
              end
            end

            ImGui.PopID(ctx)
          end
          ImGui.EndChild(ctx)
        end
      end
    end
  else
    -- Show "Developing" message when both features are disabled
    ImGui.TextWrapped(ctx, "SAVED FX PRESET and HISTORY features are currently under development.")
    ImGui.TextWrapped(ctx, "These features are not functioning properly and will be available in a future update.")
  end

  -- === FX INFO (at bottom, auto-resizes) ===
  ImGui.Separator(ctx)

  -- === STATUS (above FX info) ===
  if gui.last_result ~= "" then
    if gui.last_result:match("^Success") then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00FF00FF)
    elseif gui.last_result:match("^Error") then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF0000FF)
    else
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFFF00FF)
    end
    ImGui.Text(ctx, gui.last_result)
    ImGui.PopStyleColor(ctx)
  end

  -- STATUS BAR
  if has_valid_fx then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00FF00FF)
  else
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF0000FF)
  end

  if gui.mode == 0 then
    ImGui.Text(ctx, gui.focused_fx_name)
  else
    ImGui.Text(ctx, gui.focused_track_name ~= "" and ("Track: " .. gui.focused_track_name) or "No Track FX")
  end
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx)
  ImGui.Text(ctx, string.format(" | Items: %d", item_count))

  -- Show FX chain in Chain mode (dynamic height, auto-resizes based on content)
  if gui.mode == 1 and #gui.focused_track_fx_list > 0 then
    -- Dynamic height based on FX count (each FX line ~20px), max 150px
    local line_height = 20
    local max_height = 150
    local fx_count = #gui.focused_track_fx_list
    local calculated_height = math.min(fx_count * line_height, max_height)

    if ImGui.BeginChild(ctx, "FXChainList", 0, calculated_height) then
      for _, fx in ipairs(gui.focused_track_fx_list) do
        local status = fx.offline and "[offline]" or (fx.enabled and "[on]" or "[byp]")
        ImGui.Text(ctx, string.format("%02d) %s %s", fx.index + 1, fx.name, status))
      end
      ImGui.EndChild(ctx)
    end
  end

  ImGui.End(ctx)

  -- === SAVE PRESET POPUP (Unified for both Chain and Focused modes) ===
  if gui.show_save_popup then
    -- Position popup near main window
    local main_x, main_y = ImGui.GetWindowPos(ctx)
    local main_w, main_h = ImGui.GetWindowSize(ctx)
    ImGui.SetNextWindowPos(ctx, main_x + main_w / 2, main_y + 50, ImGui.Cond_Appearing, 0.5, 0)
    ImGui.OpenPopup(ctx, "Save FX Preset")
    gui.show_save_popup = false
  end

  if ImGui.BeginPopupModal(ctx, "Save FX Preset", true, ImGui.WindowFlags_AlwaysAutoResize) then
    -- Show track# prefix for chain mode (outside input field)
    if gui.mode == 1 and gui.focused_track then
      local track_number = r.GetMediaTrackInfo_Value(gui.focused_track, "IP_TRACKNUMBER")
      ImGui.Text(ctx, string.format("Track #%d - Preset Name:", track_number))
    else
      ImGui.Text(ctx, "Preset Name:")
    end
    ImGui.TextDisabled(ctx, "(leave empty to use default)")
    ImGui.Spacing(ctx)

    local rv, new_name = ImGui.InputText(ctx, "##presetname", gui.new_chain_name, 256)
    if rv then gui.new_chain_name = new_name end

    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "Save", 100, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
      if gui.focused_track then
        local user_input = gui.new_chain_name
        local default_value = gui.new_chain_name_default

        -- Determine final_name and custom_name
        local final_name
        local custom_name = nil

        if user_input == "" then
          -- User cleared the field → use default name, no custom name
          final_name = default_value
          custom_name = nil
        elseif user_input == default_value then
          -- User kept default value → use default name, no custom name
          final_name = default_value
          custom_name = nil
        else
          -- User modified the name → use user's input as both final_name and custom_name
          final_name = user_input
          custom_name = user_input
        end

        -- Check for duplicates
        local duplicate_found = false
        local track_guid = get_track_guid(gui.focused_track)
        local mode = (gui.mode == 1) and "chain" or "focused"
        local fx_index = (mode == "focused") and gui.focused_fx_index or nil

        -- For focused mode: get the ORIGINAL FX name from track (not processed by FX name settings)
        local original_fx_name = nil
        if mode == "focused" and fx_index ~= nil then
          local _, raw_fx_name = r.TrackFX_GetFXName(gui.focused_track, fx_index, "")
          original_fx_name = raw_fx_name
        end

        -- For chain mode: get current FX chain content for comparison
        local current_fx_list = nil
        if mode == "chain" then
          current_fx_list = get_track_fx_chain(gui.focused_track)
        end

        for _, chain in ipairs(gui.saved_chains) do
          -- For focused mode: check by track_guid + fx_index (same FX)
          -- For chain mode: check by track_guid + FX chain content (same chain regardless of name)
          if mode == "focused" and chain.mode == "focused" then
            if chain.track_guid == track_guid and chain.fx_index == fx_index then
              duplicate_found = true
              break
            end
          elseif mode == "chain" and chain.mode == "chain" then
            -- Compare FX chain content instead of name
            if chain.track_guid == track_guid then
              local saved_track = find_track_by_guid(chain.track_guid)
              if saved_track then
                local saved_fx_list = get_track_fx_chain(saved_track)
                -- Compare FX counts first
                if #saved_fx_list == #current_fx_list then
                  local chains_match = true
                  for i = 1, #saved_fx_list do
                    if saved_fx_list[i].name ~= current_fx_list[i].name then
                      chains_match = false
                      break
                    end
                  end
                  if chains_match then
                    duplicate_found = true
                    break
                  end
                end
              end
            end
          end
        end

        if duplicate_found then
          gui.last_result = "Error: This FX preset already exists"
        else
          -- For focused mode: use original FX name (with VST3:/CLAP: prefix) for internal storage
          -- For chain mode: use final_name (track name)
          local storage_name = (mode == "focused" and original_fx_name) or final_name
          add_saved_chain(storage_name, track_guid, gui.focused_track_name, custom_name, mode, fx_index)
          gui.last_result = "Success: Preset saved"
          gui.new_chain_name = ""
          gui.new_chain_name_default = ""
          ImGui.CloseCurrentPopup(ctx)
        end
      end
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 100, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      gui.new_chain_name = ""
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.EndPopup(ctx)
  end

  -- === RENAME CHAIN POPUP ===
  if gui.show_rename_popup then
    -- Position popup near main window
    local main_x, main_y = ImGui.GetWindowPos(ctx)
    local main_w, main_h = ImGui.GetWindowSize(ctx)
    ImGui.SetNextWindowPos(ctx, main_x + main_w / 2, main_y + 50, ImGui.Cond_Appearing, 0.5, 0)
    ImGui.OpenPopup(ctx, "Rename Preset")
    gui.show_rename_popup = false
  end

  if ImGui.BeginPopupModal(ctx, "Rename Preset", true, ImGui.WindowFlags_AlwaysAutoResize) then
    -- Show track# prefix for chain mode (outside input field)
    local hint_text = "(leave empty to use default)"
    if gui.rename_chain_idx and gui.saved_chains[gui.rename_chain_idx] then
      local chain = gui.saved_chains[gui.rename_chain_idx]
      if chain.mode == "chain" then
        local tr = find_track_by_guid(chain.track_guid)
        if tr then
          local track_number = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
          ImGui.Text(ctx, string.format("Track #%d - Preset Name:", track_number))
          -- Show current track name in hint
          local current_track_name, _ = get_track_name_and_number(tr)
          hint_text = string.format("(default: #%.0f - %s)", track_number, current_track_name)
        else
          ImGui.Text(ctx, "Preset Name:")
        end
      else
        -- Focused mode: show FX name in hint
        ImGui.Text(ctx, "Preset Name:")
        if chain.name then
          hint_text = string.format("(default: %s)", chain.name)
        end
      end
    else
      ImGui.Text(ctx, "Preset Name:")
    end
    ImGui.TextDisabled(ctx, hint_text)
    ImGui.Spacing(ctx)

    local rv, new_name = ImGui.InputText(ctx, "##renamefield", gui.rename_chain_name, 256)
    if rv then gui.rename_chain_name = new_name end

    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "OK", 100, 0) then
      if gui.rename_chain_idx then
        rename_saved_chain(gui.rename_chain_idx, gui.rename_chain_name)
        gui.rename_chain_idx = nil
        gui.rename_chain_name = ""
        ImGui.CloseCurrentPopup(ctx)
      end
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 100, 0) then
      gui.rename_chain_idx = nil
      gui.rename_chain_name = ""
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.EndPopup(ctx)
  end

  return open
end

------------------------------------------------------------
-- Main Loop
------------------------------------------------------------
local function loop()
  gui.open = draw_gui()
  if gui.open then
    r.defer(loop)
  else
    -- Script is closing - output final settings if debug mode is on
    if gui.debug then
      r.ShowConsoleMsg("========================================\n")
      r.ShowConsoleMsg("[AS GUI] Script closing - Final settings:\n")
      r.ShowConsoleMsg("========================================\n")
      r.ShowConsoleMsg(string.format("  Mode: %s\n", gui.mode == 0 and "Focused" or "Chain"))
      r.ShowConsoleMsg(string.format("  Action: %s\n", gui.action == 0 and "Apply" or "Copy"))
      r.ShowConsoleMsg(string.format("  Copy Scope: %s\n", gui.copy_scope == 0 and "Active" or "All"))
      r.ShowConsoleMsg(string.format("  Copy Position: %s\n", gui.copy_pos == 0 and "Last" or "Replace"))
      local channel_mode_names = {"Auto", "Mono", "Multi"}
      r.ShowConsoleMsg(string.format("  Channel Mode: %s\n", channel_mode_names[gui.channel_mode + 1]))
      r.ShowConsoleMsg(string.format("  Handle Seconds: %.2f\n", gui.handle_seconds))
      r.ShowConsoleMsg(string.format("  Debug Mode: %s\n", gui.debug and "ON" or "OFF"))
      r.ShowConsoleMsg(string.format("  Max History: %d\n", gui.max_history))
      r.ShowConsoleMsg(string.format("  FX Name - Show Type: %s\n", gui.fxname_show_type and "ON" or "OFF"))
      r.ShowConsoleMsg(string.format("  FX Name - Show Vendor: %s\n", gui.fxname_show_vendor and "ON" or "OFF"))
      r.ShowConsoleMsg(string.format("  FX Name - Strip Symbol: %s\n", gui.fxname_strip_symbol and "ON" or "OFF"))
      r.ShowConsoleMsg(string.format("  FX Name - Use Alias: %s\n", gui.use_alias and "ON" or "OFF"))
      r.ShowConsoleMsg(string.format("  Max FX Tokens: %d\n", gui.max_fx_tokens))
      local chain_token_source_names = {"Track Name", "FX Aliases", "FXChain"}
      r.ShowConsoleMsg(string.format("  Chain Token Source: %s\n", chain_token_source_names[gui.chain_token_source + 1]))
      if gui.chain_token_source == 1 then
        r.ShowConsoleMsg(string.format("  Chain Alias Joiner: '%s'\n", gui.chain_alias_joiner))
      end
      r.ShowConsoleMsg(string.format("  Track Name Strip Symbols: %s\n", gui.trackname_strip_symbols and "ON" or "OFF"))
      r.ShowConsoleMsg(string.format("  Preview Target Track: %s\n", gui.preview_target_track))
      local solo_scope_names = {"Track Solo", "Item Solo"}
      r.ShowConsoleMsg(string.format("  Preview Solo Scope: %s\n", solo_scope_names[gui.preview_solo_scope + 1]))
      local restore_mode_names = {"Keep", "Restore"}
      r.ShowConsoleMsg(string.format("  Preview Restore Mode: %s\n", restore_mode_names[gui.preview_restore_mode + 1]))
      r.ShowConsoleMsg("========================================\n")
    end
  end
end

------------------------------------------------------------
-- Entry Point
------------------------------------------------------------
load_gui_settings()  -- Load saved GUI settings first
check_bwfmetaedit(true)
load_saved_chains()
load_history()
r.defer(loop)
