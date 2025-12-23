--[[
@description AudioSweet Core - Focused Track FX render via RGWH Core
@version 0.2.0.0.1
@author hsuanice
@provides
  [main] .
@notes

Tim Chimes (original), adapted by hsuanice for AudioSweet Core integration.
  Reference:
  Inspired and named by Tim Chimes
  Original: Renders selected plugin to selected media item
  http://timchimes.com/scripting-with-reaper-audiosuite/

@changelog
  v0.2.0 (2025-12-23) [internal: v251223.2256]
    - CHANGED: Version bump to 0.2.0 (public beta)

  0v.1.9 (2025-12-23) [internal: v251223.2236]
    - CHANGED: Copy+Apply now reuses Apply flow, then copies target FX to non-active takes
      • Single/multi items share the same glue/apply path for stability
      • Copy+Apply no longer uses a separate glue→copy→render path
    - CHANGED: Copy+Apply FX copy targets the processed take channel count (min 2)
    - FIXED: TC embed offset by handle length in Apply flow
      • Use item-start-based TC (matches RGWH current mode)
    - DEBUG: Added TC embed logging for current/previous sources
    - NOTE: Do not override RGWH TC embed mode in Core/GLUE path

  v0.1.8 (2025-12-23) [internal: v251223.1924]
    - ADDED: Copy+Apply flow (copy FX then render) with multi-item glue support
      • Copy step now enforces identity pin mappings for stable multichannel IO
      • Render uses track FX to match Apply results, then clears take FX on output
    - FIXED: Multi-Channel Policy handling for Copy+Apply (source/target policies)
    - CHANGED: RGWH TimeReference embed forced to "current" during runs
    - DEBUG: Added take FX IO tracing and safe handling for invalid item pointers

  v0.1.7 (2025-12-22) [internal: v251222.1706]
    - ADDED: External undo control support for single undo operation
      • External callers (GUI/standalone scripts) can set EXTERNAL_UNDO_CONTROL="1" ExtState
      • When enabled, Core skips its internal Undo_BeginBlock/EndBlock
      • Allows GUI and standalone scripts to manage undo as single operation
      • Default: false (Core manages undo internally for backward compatibility)
      • Integration: AudioSweet GUI v0.1.24 and Run v0.1.1 both enable external undo control
    - CHANGED: Unified all processing to use Core/GLUE path (eliminates RGWH Render path)
      • Single-item units now use Core/GLUE instead of RGWH Render
      • GLUE mode produces single take (no old take preserved)
      • Fixes position issues that occurred with RGWH Render path
      • Multi-Channel Policy already implemented in Core/GLUE path (works immediately)
      • Consistent behavior across all unit sizes (single/multi-item)
      • RGWH Core's GLUE_SINGLE_ITEMS flag handles single-item glue correctly

  v0.1.5 (2025-12-22) [internal: v251222.1622]
    - ADDED: Multi-Channel Policy support for Core/GLUE path (multi-item units)
      • Core/GLUE path now implements all three Multi-Channel Policy options
      • SOURCE-PLAYBACK: Match unit's max playback channels
      • SOURCE-TRACK: Match source track channel count (uses pre-move snapshot)
      • TARGET-TRACK: Respect FX track's current channel count
      • Policy applied before calling RGWH Core, via ExtState RGWH_PRESERVE_TRACK_CH
    - ADDED: RGWH Core integration via ExtState control
      • Sets RGWH_PRESERVE_TRACK_CH="0" to disable FX track restoration (Multi/Auto mode)
      • Sets RGWH_PRESERVE_TRACK_CH="1" to enable FX track restoration (Mono mode)
      • ExtState cleared after RGWH Core execution
      • Works with RGWH Core v0.1.1+ preserve_track_ch parameter
    - IMPROVED: RGWH Render path now correctly applies Multi-Channel Policy
      • Previously: RGWH Core restored FX track channel count, overriding policy
      • Now: Uses ExtState to tell RGWH Core not to restore when policy is active
      • Fixes single-item units producing incorrect channel counts

  v0.1.4 (2025-12-22) [internal: v251222.1122]
    - FIXED: Core/GLUE path (multi-item units) source track protection
      • Added source track channel count snapshot BEFORE move to FX track
      • Added source track restore AFTER move back from FX track
      • Prevents REAPER auto-adjust from changing source track channel count
      • Affects per-unit path when unit has ≥2 items (uses Core/GLUE)
      • Debug log: "snapshot SOURCE track #N I_NCHAN=X (pre-move)"
      • Debug log: "restored SOURCE track #N I_NCHAN=X (post-move)"
      • Completes source track protection coverage for all execution paths

  v0.1.3 (2025-12-22) [internal: v251222.1103]
    - FIXED: Multi-unit processing across tracks - SOURCE-TRACK policy now works correctly
      • TS-WINDOW[GLOBAL] path now snapshots ALL source track channel counts BEFORE glue operation
      • Previously: second unit read post-glue channel count (incorrect)
      • Now: all units use pre-glue snapshot (correct)
      • apply_focused_fx_to_item() accepts optional source_track_nchan_snapshot parameter
      • When snapshot provided, uses pre-glue value for SOURCE-TRACK policy calculation
      • Individual track restore skipped when using snapshot (batch restore at end instead)
      • Renamed variable to avoid confusion with FX track snapshot (main function line 1967)
      • Added detailed debug logging: "snapshot SOURCE track" vs "SNAPSHOT track" (FX track)
      • Debug logs now clearly distinguish SOURCE track operations from FX track operations

  v0.1.2 (2025-12-22) [internal: v251222.1035]
    - ADDED: Multi-Channel Policy system with 3 options (Settings → Channel Mode)
      • SOURCE-PLAYBACK: Match item's actual playback channels (default, current behavior)
      • SOURCE-TRACK: Match source track channel count (RGWH/Pro Tools style)
      • TARGET-TRACK: Respect FX track's current channel count (passive mode)
      • Policy only applies when Channel Mode is explicitly set to "Multi"
      • Auto/Mono modes use SOURCE-PLAYBACK logic (default behavior)
      • Implemented in both TS-Window and RGWH Render paths
      • Reads policy from ExtState: AS_MULTI_CHANNEL_POLICY
      • Debug logging shows policy selection and resulting channel count
    - ADDED: Source track channel count protection
      • Snapshots source track I_NCHAN before moving items to FX track
      • Restores source track channel count after processing complete
      • Prevents REAPER auto-adjust from changing source track channel count
      • Essential for post-production workflows and project interchange (Pro Tools/Nuendo)
      • Implemented in both TS-Window and RGWH Render paths
    - ADDED: Debug file logging
      • All debug output now writes to ~/Desktop/AudioSweet_Core_Debug.log
      • Prevents console messages from being washed away by RGWH Core output
      • Helps troubleshooting when multiple cores are running

  v0.1.1 (2025-12-21) [internal: v251221.2141]
    - ADDED: Track channel count restoration after execution
      • Snapshots track I_NCHAN at execution start (after FXmediaTrack is known)
      • Restores original channel count at all exit points (copy/apply/TS-window paths)
      • Prevents REAPER auto-expansion from persisting after processing
      • Works in both focused and chain modes
      • Helper function restore_track_nchan() for consistent restoration
]]--

-- Debug toggle: set ExtState "hsuanice_AS"/"DEBUG" to "1" to enable, "0" (or empty) to disable
-- reaper.SetExtState("hsuanice_AS","DEBUG","1", false)  -- (disabled: don't force-on DEBUG by default)

-- === User options ===
-- How many FX names to keep in the "-ASn-..." suffix.
-- 0 or nil = unlimited; N>0 = keep last N tokens (FIFO).
-- Now reads from ExtState: hsuanice_AS/AS_MAX_FX_TOKENS
local function get_max_fx_tokens()
  local val = reaper.GetExtState("hsuanice_AS", "AS_MAX_FX_TOKENS")
  local n = tonumber(val)
  return (n and n > 0) and n or 3  -- default: 3
end

-- Chain token source (for chain mode):
--   "aliases" -> use enabled Track FX aliases in order (joined by AS_CHAIN_ALIAS_JOINER)
--   "fxchain" -> literal token "FXChain"
--   "track"   -> use the FX track's name (sanitized)
-- Now reads from ExtState: hsuanice_AS/AS_CHAIN_TOKEN_SOURCE
local function get_chain_token_source()
  local val = reaper.GetExtState("hsuanice_AS", "AS_CHAIN_TOKEN_SOURCE")
  return (val ~= "") and val or "track"  -- default: "track"
end

-- When AS_CHAIN_TOKEN_SOURCE="aliases", use this joiner to connect alias tokens
-- Now reads from ExtState: hsuanice_AS/AS_CHAIN_ALIAS_JOINER
local function get_chain_alias_joiner()
  return reaper.GetExtState("hsuanice_AS", "AS_CHAIN_ALIAS_JOINER")  -- default: "" (empty)
end

-- If true, strip unsafe filename characters from chain tokens (for "track" mode & others)
-- Now reads from ExtState: hsuanice_AS/SANITIZE_TOKEN_FOR_FILENAME
local function get_sanitize_token_for_filename()
  return reaper.GetExtState("hsuanice_AS", "SANITIZE_TOKEN_FOR_FILENAME") == "1"  -- default: false
end

-- Track name token style: when true, strip ALL non-alphanumeric (FX-like short name).
-- When false, fall back to sanitize_token (underscores etc.).
-- Now reads from ExtState: hsuanice_AS/TRACKNAME_STRIP_SYMBOLS
local function get_trackname_strip_symbols()
  local val = reaper.GetExtState("hsuanice_AS", "TRACKNAME_STRIP_SYMBOLS")
  return (val == "") and true or (val == "1")  -- default: true
end

-- Naming-only debug (console print before/after renaming).
-- Now controlled by ExtState: hsuanice_AS/DEBUG
local function debug_naming_enabled()
  return reaper.GetExtState("hsuanice_AS", "DEBUG") == "1"
end

local function debug_enabled()
  return reaper.GetExtState("hsuanice_AS", "DEBUG") == "1"
end

function debug(message)
  if not debug_enabled() then return end
  if message == nil then return end
  reaper.ShowConsoleMsg(tostring(message) .. "\n")
end

-- Step logger: always prints when DEBUG=1; use for deterministic tracing
local DEBUG_FILE_PATH = (os.getenv("HOME") or "") .. "/Desktop/AudioSweet_Core_Debug.log"
local function log_step(tag, fmt, ...)
  if not debug_enabled() then return end
  local msg = fmt and string.format(fmt, ...) or ""
  local output = string.format("[AS][STEP] %s %s\n", tostring(tag or ""), msg)
  reaper.ShowConsoleMsg(output)

  -- Also write to file
  local f = io.open(DEBUG_FILE_PATH, "a")
  if f then
    f:write(output)
    f:close()
  end
end



-- ==== debug helpers ====
local function dbg_item_brief(it, tag)
  if not debug_enabled() or not it then return end
  local p   = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
  local tr  = reaper.GetMediaItem_Track(it)
  local _, g = reaper.GetSetMediaItemInfo_String(it, "GUID", "", false)
  local trname = ""
  if tr then
    local _, tn = reaper.GetTrackName(tr)
    trname = tn or ""
  end
  reaper.ShowConsoleMsg(string.format("[AS][STEP] %s item pos=%.3f len=%.3f track='%s' guid=%s\n",
    tag or "ITEM", p or -1, len or -1, trname, g))
end

local function dbg_dump_selection(tag)
  if not debug_enabled() then return end
  local n = reaper.CountSelectedMediaItems(0)
  reaper.ShowConsoleMsg(string.format("[AS][STEP] %s selected_items=%d\n", tag or "SEL", n))
  for i=0,n-1 do
    dbg_item_brief(reaper.GetSelectedMediaItem(0, i), "  •")
  end
end

local function dbg_dump_unit(u, idx)
  if not debug_enabled() or not u then return end
  reaper.ShowConsoleMsg(string.format("[AS][STEP] UNIT#%d UL=%.3f UR=%.3f members=%d\n",
    idx or -1, u.UL, u.UR, #u.items))
  for _,it in ipairs(u.items) do dbg_item_brief(it, "    -") end
end

local function dbg_track_items_in_range(tr, L, R)
  if not debug_enabled() then return end
  reaper.ShowConsoleMsg(string.format("[AS][STEP] TRACK SCAN in [%.3f..%.3f]\n", L, R))
  if not tr then
    reaper.ShowConsoleMsg("[AS][STEP]   (no track)\n")
    return
  end
  local n = reaper.CountTrackMediaItems(tr)
  for i=0,n-1 do
    local it = reaper.GetTrackMediaItem(tr, i)
    if it then
      local p   = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
      local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
      local q   = (p or 0) + (len or 0)
      if p and len and not (q < L or p > R) then
        dbg_item_brief(it, "  tr-hit")
      end
    end
  end
end

-- === COPY HELPERS (non-destructive, no rename) ===
local function AS_merge_args_with_extstate(args)
  args = args or {}
  local function get_ns(ns, key, def)
    local v = reaper.GetExtState(ns, key)
    if v == "" then return def else return v end
  end
  args.mode       = args.mode       or get_ns("hsuanice_AS","AS_MODE","focused")     -- focused | chain
  args.action     = args.action     or get_ns("hsuanice_AS","AS_ACTION","apply")      -- apply | copy | apply_after_copy
  args.scope      = args.scope      or get_ns("hsuanice_AS","AS_COPY_SCOPE","active") -- active  | all_takes
  args.append_pos = args.append_pos or get_ns("hsuanice_AS","AS_COPY_POS","tail")     -- tail    | head
  args.warn_takefx = (args.warn_takefx ~= false)
  return args
end

local function AS_copy_focused_fx_to_items(src_track, fx_index, args)
  local selN = reaper.CountSelectedMediaItems(0)
  local copied = 0
  for i = 0, selN - 1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    if it then
      local take_count = reaper.CountTakes(it) or 0
      local function each_take(fn)
        if args.scope == "all_takes" then
          for t = 0, take_count - 1 do
            local tk = reaper.GetMediaItemTake(it, t)
            if tk then fn(tk) end
          end
        else
          local tk = reaper.GetActiveTake(it)
          if tk then fn(tk) end
        end
      end
      each_take(function(tk)
        local dest = (args.append_pos == "head") and 0 or (reaper.TakeFX_GetCount(tk) or 0)
        reaper.TrackFX_CopyToTake(src_track, fx_index, tk, dest, false)
        do
          local in_ch, out_ch = reaper.TrackFX_GetIOSize(src_track, fx_index)
          if in_ch and out_ch then
            for pin = 0, in_ch - 1 do
              local lo, hi = reaper.TrackFX_GetPinMappings(src_track, fx_index, 0, pin)
              if lo then reaper.TakeFX_SetPinMappings(tk, dest, 0, pin, lo, hi) end
            end
            for pin = 0, out_ch - 1 do
              local lo, hi = reaper.TrackFX_GetPinMappings(src_track, fx_index, 1, pin)
              if lo then reaper.TakeFX_SetPinMappings(tk, dest, 1, pin, lo, hi) end
            end
          end
        end
        copied = copied + 1
      end)
    end
  end
  return copied
end

local function AS_copy_chain_to_items(src_track, args)
  local chainN = reaper.TrackFX_GetCount(src_track) or 0
  local selN   = reaper.CountSelectedMediaItems(0)
  local total  = 0
  for i = 0, selN - 1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    if it then
      local take_count = reaper.CountTakes(it) or 0
      local function each_take(fn)
        if args.scope == "all_takes" then
          for t = 0, take_count - 1 do
            local tk = reaper.GetMediaItemTake(it, t)
            if tk then fn(tk) end
          end
        else
          local tk = reaper.GetActiveTake(it)
          if tk then fn(tk) end
        end
      end
      each_take(function(tk)
        if args.append_pos == "head" then
          for fx = chainN - 1, 0, -1 do
            reaper.TrackFX_CopyToTake(src_track, fx, tk, 0, false)
            do
              local in_ch, out_ch = reaper.TrackFX_GetIOSize(src_track, fx)
              if in_ch and out_ch then
                for pin = 0, in_ch - 1 do
                  local lo, hi = reaper.TrackFX_GetPinMappings(src_track, fx, 0, pin)
                  if lo then reaper.TakeFX_SetPinMappings(tk, 0, 0, pin, lo, hi) end
                end
                for pin = 0, out_ch - 1 do
                  local lo, hi = reaper.TrackFX_GetPinMappings(src_track, fx, 1, pin)
                  if lo then reaper.TakeFX_SetPinMappings(tk, 0, 1, pin, lo, hi) end
                end
              end
            end
            total = total + 1
          end
        else
          for fx = 0, chainN - 1 do
            local dest = reaper.TakeFX_GetCount(tk) or 0
            reaper.TrackFX_CopyToTake(src_track, fx, tk, dest, false)
            do
              local in_ch, out_ch = reaper.TrackFX_GetIOSize(src_track, fx)
              if in_ch and out_ch then
                for pin = 0, in_ch - 1 do
                  local lo, hi = reaper.TrackFX_GetPinMappings(src_track, fx, 0, pin)
                  if lo then reaper.TakeFX_SetPinMappings(tk, dest, 0, pin, lo, hi) end
                end
                for pin = 0, out_ch - 1 do
                  local lo, hi = reaper.TrackFX_GetPinMappings(src_track, fx, 1, pin)
                  if lo then reaper.TakeFX_SetPinMappings(tk, dest, 1, pin, lo, hi) end
                end
              end
            end
            total = total + 1
          end
        end
      end)
    end
  end
  return total
end

local function AS_copy_to_selected_items(src_track, fx_index, args)
  if args.mode == "focused" then
    return AS_copy_focused_fx_to_items(src_track, fx_index, args)
  end
  return AS_copy_chain_to_items(src_track, args)
end

local function copy_trackfx_to_take(src_track, fx_index, tk, dest)
  reaper.TrackFX_CopyToTake(src_track, fx_index, tk, dest, false)
  local in_ch, out_ch = reaper.TrackFX_GetIOSize(src_track, fx_index)
  if in_ch and out_ch then
    for pin = 0, in_ch - 1 do
      local lo, hi = reaper.TrackFX_GetPinMappings(src_track, fx_index, 0, pin)
      if lo then reaper.TakeFX_SetPinMappings(tk, dest, 0, pin, lo, hi) end
    end
    for pin = 0, out_ch - 1 do
      local lo, hi = reaper.TrackFX_GetPinMappings(src_track, fx_index, 1, pin)
      if lo then reaper.TakeFX_SetPinMappings(tk, dest, 1, pin, lo, hi) end
    end
  end
end

local function copy_focused_fx_to_take(src_track, fx_index, tk, append_pos)
  local dest = (append_pos == "head") and 0 or (reaper.TakeFX_GetCount(tk) or 0)
  copy_trackfx_to_take(src_track, fx_index, tk, dest)
  return 1
end

local function copy_chain_fx_to_take(src_track, tk, append_pos)
  local chainN = reaper.TrackFX_GetCount(src_track) or 0
  local total = 0
  if append_pos == "head" then
    for fx = chainN - 1, 0, -1 do
      copy_trackfx_to_take(src_track, fx, tk, 0)
      total = total + 1
    end
  else
    for fx = 0, chainN - 1 do
      local dest = reaper.TakeFX_GetCount(tk) or 0
      copy_trackfx_to_take(src_track, fx, tk, dest)
      total = total + 1
    end
  end
  return total
end

local get_item_channels
local clear_take_fx
local snapshot_trackfx_pins
local restore_trackfx_pins
local set_trackfx_identity_pins

local function resolve_apply_fx_mode_for_item(item)
  local mode = reaper.GetExtState("hsuanice_AS", "AS_APPLY_FX_MODE")
  if mode == "" or mode == "auto" then
    return (get_item_channels(item) <= 1) and "mono" or "multi"
  end
  return mode
end

local function compute_desired_nchan_for_copy(item, FXmediaTrack, apply_fx_mode, source_track_nchan)
  if apply_fx_mode ~= "multi" then return nil end
  local multi_policy = reaper.GetExtState("hsuanice_AS", "AS_MULTI_CHANNEL_POLICY")
  if multi_policy == "" then multi_policy = "source_playback" end

  if multi_policy == "source_playback" then
    local ch = get_item_channels(item)
    if ch <= 1 then return nil end
    return (ch % 2 == 0) and ch or (ch + 1)
  elseif multi_policy == "source_track" then
    local tr_ch = source_track_nchan or 2
    return (tr_ch % 2 == 0) and tr_ch or (tr_ch + 1)
  elseif multi_policy == "target_track" then
    return tonumber(reaper.GetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN")) or 2
  end
  return nil
end

local function copy_fx_to_non_active_takes(item, FXmediaTrack, fxIndex, source_track_nchan)
  if not item then return 0 end
  local take_count = reaper.CountTakes(item) or 0
  if take_count <= 1 then return 0 end
  local active = reaper.GetActiveTake(item)

  local apply_fx_mode = resolve_apply_fx_mode_for_item(item)
  local desired_nchan = nil
  if apply_fx_mode == "multi" then
    local ch = get_item_channels(item)
    if ch and ch > 0 then
      desired_nchan = (ch < 2) and 2 or ch
    end
  end
  local prev_nchan = tonumber(reaper.GetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN")) or 2
  local did_set = false
  if apply_fx_mode == "multi" and desired_nchan then
    reaper.SetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN", desired_nchan)
    did_set = true
  end

  local total = 0
  local copy_mode = (AS and AS.mode) or AS_merge_args_with_extstate({}).mode
  for t = 0, take_count - 1 do
    local tk = reaper.GetMediaItemTake(item, t)
    if tk and tk ~= active then
      clear_take_fx(tk)
      if copy_mode == "focused" then
        total = total + copy_focused_fx_to_take(FXmediaTrack, fxIndex, tk, "tail")
      else
        total = total + copy_chain_fx_to_take(FXmediaTrack, tk, "tail")
      end
    end
  end

  if did_set then
    reaper.SetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN", prev_nchan)
  end

  return total
end

local function is_valid_item(it)
  if not it then return false end
  if reaper.ValidatePtr2 then
    return reaper.ValidatePtr2(0, it, "MediaItem*")
  end
  if reaper.ValidatePtr then
    return reaper.ValidatePtr(it, "MediaItem*")
  end
  return true
end

local function dbg_take_fx_io(label, items)
  if not debug_enabled() then return end
  local list = items or {}
  for _, it in ipairs(list) do
    if is_valid_item(it) then
      local ok, tk = pcall(reaper.GetActiveTake, it)
      if not ok then tk = nil end
      if tk then
        local chanmode = reaper.GetMediaItemTakeInfo_Value(tk, "I_CHANMODE") or 0
        local fxn = reaper.TakeFX_GetCount(tk) or 0
        log_step("IO", "%s item=%s take_fx=%d chanmode=%d", tostring(label), tostring(it), fxn, chanmode)
        for fx = 0, fxn - 1 do
          local in_ch, out_ch = reaper.TakeFX_GetIOSize(tk, fx)
          if in_ch and out_ch then
            log_step("IO", "  takefx#%d in=%d out=%d", fx, in_ch, out_ch)
            for pin = 0, in_ch - 1 do
              local lo, hi = reaper.TakeFX_GetPinMappings(tk, fx, 0, pin)
              log_step("IO", "    in#%d map lo=%s hi=%s", pin, tostring(lo), tostring(hi))
            end
            for pin = 0, out_ch - 1 do
              local lo, hi = reaper.TakeFX_GetPinMappings(tk, fx, 1, pin)
              log_step("IO", "    out#%d map lo=%s hi=%s", pin, tostring(lo), tostring(hi))
            end
          end
        end
      end
    else
      log_step("IO", "%s skip invalid item=%s", tostring(label), tostring(it))
    end
  end
end

clear_take_fx = function(tk)
  if not tk then return end
  local n = reaper.TakeFX_GetCount(tk) or 0
  for i = n - 1, 0, -1 do
    reaper.TakeFX_Delete(tk, i)
  end
end

local function snapshot_takefx_enabled(tk)
  if not tk then return nil end
  local n = reaper.TakeFX_GetCount(tk) or 0
  local snap = {}
  for i = 0, n - 1 do
    snap[i] = reaper.TakeFX_GetEnabled(tk, i)
  end
  return snap
end

local function set_takefx_enabled(tk, enabled)
  if not tk then return end
  local n = reaper.TakeFX_GetCount(tk) or 0
  for i = 0, n - 1 do
    reaper.TakeFX_SetEnabled(tk, i, enabled)
  end
end

local function restore_takefx_enabled(tk, snap)
  if not tk or not snap then return end
  local n = reaper.TakeFX_GetCount(tk) or 0
  for i = 0, n - 1 do
    local state = snap[i]
    if state ~= nil then
      reaper.TakeFX_SetEnabled(tk, i, state)
    end
  end
end
-- ================================================
-- ==== Chain token helpers (for chain mode naming) ====
local function sanitize_token(s)
  s = tostring(s or "")
  if get_sanitize_token_for_filename() then
    s = s:gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  end
  return s
end

local function track_name_token(FXtrack)
  if not FXtrack then return "" end
  local _, tn = reaper.GetTrackName(FXtrack)
  tn = tn or ""
  if get_trackname_strip_symbols() then
    tn = tn:gsub("%b()", "")
           :gsub("[^%w]+","")
  else
    tn = sanitize_token(tn)
  end
  return tn
end

-- build_chain_token moved after format_fx_label and fx_alias_for_raw_label definitions (see line ~900)
-- =======================
-- ==== FX enable snapshot/restore (preserve original bypass states) ====
local function snapshot_fx_enables(tr)
  if not tr then return nil end
  local snap = {}
  local cnt = reaper.TrackFX_GetCount(tr) or 0
  for i = 0, cnt-1 do
    snap[i] = reaper.TrackFX_GetEnabled(tr, i) and true or false
  end
  return snap
end

local function restore_fx_enables(tr, snap)
  if not tr or not snap then return end
  local cnt = reaper.TrackFX_GetCount(tr) or 0
  for i = 0, cnt-1 do
    local en = snap[i]
    if en ~= nil then reaper.TrackFX_SetEnabled(tr, i, en) end
  end
end

local function pin_mask_for_channel(ch)
  if ch < 32 then
    return 2 ^ ch, 0
  end
  return 0, 2 ^ (ch - 32)
end

snapshot_trackfx_pins = function(tr, fx)
  if not tr then return nil end
  local in_ch, out_ch = reaper.TrackFX_GetIOSize(tr, fx)
  if not in_ch or not out_ch then return nil end
  local snap = { in_ch = in_ch, out_ch = out_ch, in_map = {}, out_map = {} }
  for pin = 0, in_ch - 1 do
    local lo, hi = reaper.TrackFX_GetPinMappings(tr, fx, 0, pin)
    snap.in_map[pin] = { lo, hi }
  end
  for pin = 0, out_ch - 1 do
    local lo, hi = reaper.TrackFX_GetPinMappings(tr, fx, 1, pin)
    snap.out_map[pin] = { lo, hi }
  end
  return snap
end

restore_trackfx_pins = function(tr, fx, snap)
  if not tr or not snap then return end
  for pin = 0, (snap.in_ch or 0) - 1 do
    local m = snap.in_map[pin]
    if m then reaper.TrackFX_SetPinMappings(tr, fx, 0, pin, m[1] or 0, m[2] or 0) end
  end
  for pin = 0, (snap.out_ch or 0) - 1 do
    local m = snap.out_map[pin]
    if m then reaper.TrackFX_SetPinMappings(tr, fx, 1, pin, m[1] or 0, m[2] or 0) end
  end
end

set_trackfx_identity_pins = function(tr, fx, nch)
  if not tr or not nch then return end
  local in_ch, out_ch = reaper.TrackFX_GetIOSize(tr, fx)
  if not in_ch or not out_ch then return end
  for pin = 0, in_ch - 1 do
    local lo, hi = 0, 0
    if pin < nch then lo, hi = pin_mask_for_channel(pin) end
    reaper.TrackFX_SetPinMappings(tr, fx, 0, pin, lo, hi)
  end
  for pin = 0, out_ch - 1 do
    local lo, hi = 0, 0
    if pin < nch then lo, hi = pin_mask_for_channel(pin) end
    reaper.TrackFX_SetPinMappings(tr, fx, 1, pin, lo, hi)
  end
end
-- =====================================================================
-- ==== FX name formatting options & helper ====
-- ExtState flags (if not set, reads defaults)
local FXNAME_DEFAULT_SHOW_TYPE    = false  -- include type prefix (e.g., "VST3:" / "CLAP:")
local FXNAME_DEFAULT_SHOW_VENDOR  = false  -- include vendor name (in parentheses)
local FXNAME_DEFAULT_STRIP_SYMBOL = true  -- strip spaces and symbols (keep alphanumeric only)

local function fxname_opts()
  local function flag(key, default)
    local v = reaper.GetExtState("hsuanice_AS", key)
    if v == "1" then return true end
    if v == "0" then return false end
    return default
  end
  return {
    show_type    = flag("FXNAME_SHOW_TYPE",   FXNAME_DEFAULT_SHOW_TYPE),
    show_vendor  = flag("FXNAME_SHOW_VENDOR", FXNAME_DEFAULT_SHOW_VENDOR),
    strip_symbol = flag("FXNAME_STRIP_SYMBOL",FXNAME_DEFAULT_STRIP_SYMBOL),
  }
end

local function trim(s) return (s and s:gsub("^%s+",""):gsub("%s+$","")) or "" end

-- Parse REAPER FX display name:
--  Example: "CLAP: Pro-Q 4 (FabFilter)" → type="CLAP", core="Pro-Q 4", vendor="FabFilter"
local function parse_fx_label(raw)
  raw = tostring(raw or "")
  local typ, rest = raw:match("^([%w%+%._-]+):%s*(.+)$")
  rest = rest or raw
  local core, vendor = rest, nil
  local core_only, v = rest:match("^(.-)%s*%(([^%(%)]+)%)%s*$")
  if core_only then
    core, vendor = core_only, v
  end
  return trim(typ), trim(core), trim(vendor)
end

-- forward declare for alias lookup used by format_fx_label
local fx_alias_for_raw_label

local function format_fx_label(raw)
  -- Get formatting options from ExtState
  local opt = fxname_opts()

  -- Check if alias exists
  local alias = fx_alias_for_raw_label(raw)
  local use_alias = (type(alias) == "string" and alias ~= "")

  -- Parse the raw FX label to get type and vendor
  local typ, core, vendor = parse_fx_label(raw)

  -- If alias exists, use it as the core name; otherwise use parsed core
  local base_name = use_alias and alias or core

  -- Apply formatting options (even if using alias)
  local base
  if opt.show_type and typ ~= "" then
    base = typ .. ": " .. base_name
  else
    base = base_name
  end
  if opt.show_vendor and vendor ~= "" then
    base = base .. " (" .. vendor .. ")"
  end

  if opt.strip_symbol then
    base = base:gsub("[^%w]+","")
  end
  return base
end

-- ==== FX alias lookup (from Settings/fx_alias.json / .tsv) ====
-- User options
local AS_ALIAS_JSON_PATH = reaper.GetResourcePath() ..
  "/Scripts/hsuanice Scripts/Settings/fx_alias.json"
local AS_ALIAS_TSV_PATH = reaper.GetResourcePath() ..
  "/Scripts/hsuanice Scripts/Settings/fx_alias.tsv"
local AS_USE_ALIAS   = (reaper.GetExtState("hsuanice_AS","USE_ALIAS") == "1")
local AS_DEBUG_ALIAS = (reaper.GetExtState("hsuanice_AS","AS_DEBUG_ALIAS") == "1")

-- Simple normalization: lowercase, remove non-alphanumeric
local function _norm(s) return (tostring(s or ""):lower():gsub("[^%w]+","")) end

-- Lazy-load JSON (requires dkjson or equivalent json.decode in system)
-- Forward declare TSV helper so _alias_map() can call it before definition.
local _alias_map_from_tsv

local _FX_ALIAS_CACHE = nil
local function _alias_map()
  if _FX_ALIAS_CACHE ~= nil then return _FX_ALIAS_CACHE end
  _FX_ALIAS_CACHE = {}
  if not AS_USE_ALIAS then return _FX_ALIAS_CACHE end

  local f = io.open(AS_ALIAS_JSON_PATH, "rb")
  if not f then
    if AS_DEBUG_ALIAS then
      reaper.ShowConsoleMsg(("[ALIAS][LOAD] JSON not found: %s\n"):format(AS_ALIAS_JSON_PATH))
    end
    -- JSON file not found → try TSV fallback
    _FX_ALIAS_CACHE = _alias_map_from_tsv(AS_ALIAS_TSV_PATH)
    return _FX_ALIAS_CACHE
  end
  local blob = f:read("*a"); f:close()

  -- Detect/load JSON decoder
  local JSON = _G.json or _G.dkjson
  if not JSON or not (JSON.decode or JSON.Decode or JSON.parse) then
    pcall(function()
      local lib = reaper.GetResourcePath() .. "/Scripts/hsuanice Scripts/Library/dkjson.lua"
      local ok, mod = pcall(dofile, lib)
      if ok and mod then JSON = mod end
    end)
  end
  local decode = (JSON and (JSON.decode or JSON.Decode or JSON.parse)) or nil
  if not decode then
    if AS_DEBUG_ALIAS then
      reaper.ShowConsoleMsg("[ALIAS][LOAD] No JSON decoder found\n")
    end
    -- No decoder → try TSV fallback
    _FX_ALIAS_CACHE = _alias_map_from_tsv(AS_ALIAS_TSV_PATH)
    return _FX_ALIAS_CACHE
  end

  local ok, data = pcall(decode, blob)
  if not ok or type(data) ~= "table" then
    if AS_DEBUG_ALIAS then
      reaper.ShowConsoleMsg("[ALIAS][LOAD] JSON decode failed or not a table\n")
    end
    -- JSON parse failed → try TSV fallback
    _FX_ALIAS_CACHE = _alias_map_from_tsv(AS_ALIAS_TSV_PATH)
    return _FX_ALIAS_CACHE
  end

  -- Support two formats:
  -- (A) object: { ["vst3|core|vendor"] = { alias="FOO", ... }, ... }
  -- (B) array:  [ { fingerprint="vst3|core|vendor", alias="FOO", ... }, ... ]
  local count = 0

  local is_array = (data[1] ~= nil) and true or false
  if is_array then
    for i = 1, #data do
      local rec = data[i]
      if type(rec) == "table" then
        local fp = rec.fingerprint
        local al = rec.alias
        if type(fp) == "string" and fp ~= "" and type(al) == "string" and al ~= "" then
          _FX_ALIAS_CACHE[fp] = al
          count = count + 1
        end
      end
    end
  else
    for k, v in pairs(data) do
      if type(k) == "string" and k ~= "" then
        if type(v) == "table" then
          local al = v.alias
          if type(al) == "string" and al ~= "" then
            _FX_ALIAS_CACHE[k] = al
            count = count + 1
          end
        elseif type(v) == "string" then
          _FX_ALIAS_CACHE[k] = v
          count = count + 1
        end
      end
    end
  end

  if AS_DEBUG_ALIAS then
    reaper.ShowConsoleMsg(("[ALIAS][LOAD] entries=%d  from=%s\n")
      :format(count, AS_ALIAS_JSON_PATH))
  end

  return _FX_ALIAS_CACHE
end
-- TSV small helper: build alias map from a TSV with headers:
--   fingerprint <TAB> alias  (other columns optional)
function _alias_map_from_tsv(tsv_path)
  local map = {}
  local f = io.open(tsv_path, "rb")
  if not f then
    if AS_DEBUG_ALIAS then
      reaper.ShowConsoleMsg(("[ALIAS][LOAD] TSV not found: %s\n"):format(tsv_path))
    end
    return map
  end

  local header = f:read("*l")
  if not header then
    f:close()
    if AS_DEBUG_ALIAS then
      reaper.ShowConsoleMsg("[ALIAS][LOAD] TSV empty header\n")
    end
    return map
  end

  -- Find column indices
  local cols = {}
  local idx = 1
  for h in tostring(header):gmatch("([^\t]+)") do
    cols[h] = idx
    idx = idx + 1
  end
  local fp_i  = cols["fingerprint"]
  local al_i  = cols["alias"]

  if not fp_i or not al_i then
    f:close()
    if AS_DEBUG_ALIAS then
      reaper.ShowConsoleMsg("[ALIAS][LOAD] TSV missing 'fingerprint' or 'alias' header\n")
    end
    return map
  end

  local added = 0
  while true do
    local line = f:read("*l")
    if not line then break end
    if line ~= "" then
      local fields = {}
      local i = 1
      for seg in line:gmatch("([^\t]*)\t?") do
        fields[i] = seg
        i = i + 1
        if (#fields >= idx-1) then break end
      end
      local fp = fields[fp_i]
      local al = fields[al_i]
      if type(fp) == "string" and fp ~= "" and type(al) == "string" and al ~= "" then
        map[fp] = al
        added = added + 1
      end
    end
  end
  f:close()

  if AS_DEBUG_ALIAS then
    reaper.ShowConsoleMsg(("[ALIAS][LOAD] TSV entries=%d  from=%s\n"):format(added, tsv_path))
  end
  return map
end
-- Stronger raw parsing: extract host/type, core without parens, outermost paren as vendor
-- Example: "VST3: UADx Manley VOXBOX Channel Strip (Universal Audio (UADx))"
--  => host="vst3", core="uadxmanleyvoxboxchannelstrip", vendor="universalaudiouadx"
local function _parse_raw_label_host_core_vendor(raw)
  raw = tostring(raw or "")

  -- host/type
  local host = raw:match("^%s*([%w_]+)%s*:") or ""
  host = host:lower()

  -- core: take everything after colon, remove all parens and non-alphanumeric
  local core = raw:match(":%s*(.+)$") or ""
  core = core:gsub("%b()", "")            -- remove all paren segments
               :gsub("%s+%-[%s%-].*$", "")-- remove " - Something" tail (just in case)
               :gsub("%W", "")            -- remove non-alphanumeric
               :lower()

  -- vendor: extract each balanced paren segment, take the last one
  local last = nil
  for seg in raw:gmatch("%b()") do
    last = seg
  end
  local vendor = ""
  if last and #last >= 2 then
    vendor = last:sub(2, -2)              -- remove leading/trailing parens
    vendor = vendor:gsub("%W", ""):lower()
  end

  return host, core, vendor
end
-- Return alias or nil (enhanced: support vendor+core keys, scan fallback, debug output)
function fx_alias_for_raw_label(raw_label)
  if not AS_USE_ALIAS then return nil end
  local m = _alias_map()
  if not m then return nil end

  -- Main parsing
  local host, core, vendor = _parse_raw_label_host_core_vendor(raw_label)

  -- Legacy parsing once (compatible with old keys)
  local typ2, core2, vendor2 = parse_fx_label(raw_label)
  local t2 = _norm(typ2)
  local c2 = _norm(core2)
  local v2 = _norm(vendor2)

  local t = host
  local c = core
  local v = vendor

  -- Build various candidate keys
  local key1  = string.format("%s|%s|%s", t,  c,  v)
  local key2  = string.format("%s|%s|",    t,  c)
  local key2b = (v ~= "" and string.format("%s|%s%s|", t, c, v)) or nil
  local key3  = string.format("|%s|",      c)

  local key1b = string.format("%s|%s|%s", t2, c2, v2)
  local key2c = string.format("%s|%s|",    t2, c2)
  local key2d = (v2 ~= "" and string.format("%s|%s%s|", t2, c2, v2)) or nil
  local key3b = string.format("|%s|",      c2)

  local hit, from

  -- Direct match
  if type(m[key1]) == "string" and m[key1] ~= "" then hit, from = m[key1], "exact" end
  if not hit and type(m[key2]) == "string" and m[key2] ~= "" then hit, from = m[key2], "empty-vendor" end
  if not hit and key2b and type(m[key2b]) == "string" and m[key2b] ~= "" then hit, from = m[key2b], "core+vendor-as-core" end
  if not hit and type(m[key3]) == "string" and m[key3] ~= "" then hit, from = m[key3], "cross-type" end

  -- Legacy key compatibility
  if not hit and type(m[key1b]) == "string" and m[key1b] ~= "" then hit, from = m[key1b], "exact(legacy)" end
  if not hit and type(m[key2c]) == "string" and m[key2c] ~= "" then hit, from = m[key2c], "empty-vendor(legacy)" end
  if not hit and key2d and type(m[key2d]) == "string" and m[key2d] ~= "" then hit, from = m[key2d], "core+vendor-as-core(legacy)" end
  if not hit and type(m[key3b]) == "string" and m[key3b] ~= "" then hit, from = m[key3b], "cross-type(legacy)" end

  -- Fallback scan
  if not hit then
    local core_pat1 = "|" .. c  .. "|"
    local core_pat2 = (v ~= "" and ("|" .. c .. v .. "|")) or nil
    for k, rec in pairs(m) do
      if type(rec) == "string" and rec ~= "" then
        if k:find(core_pat1, 1, true) or (core_pat2 and k:find(core_pat2, 1, true)) then
          hit, from = rec, "scan"
          break
        end
      end
    end
  end

  if AS_DEBUG_ALIAS then
    local size = 0
    for _ in pairs(m) do size = size + 1 end
    reaper.ShowConsoleMsg(("[ALIAS][LOOKUP]\n  raw   = %s\n  host  = %s\n  core  = %s\n  vendor= %s\n  try   = %s | %s | %s | %s\n  legacy= %s | %s | %s | %s\n  alias = %s (from=%s)\n  map   = %d entries\n\n")
      :format(
        tostring(raw_label or ""),
        t, c, v,
        key1, key2, tostring(key2b or "(nil)"), key3,
        key1b, key2c, tostring(key2d or "(nil)"), key3b,
        tostring(hit or ""), tostring(from or "miss"),
        size
      ))
  end

  return hit
end

-- =============================================
-- ==== Chain token builder (moved here after format_fx_label is defined) ====
local function build_chain_token(FXtrack)
  local source = get_chain_token_source()
  if source == "fxchain" then
    return "FXChain"
  elseif source == "track" then
    return track_name_token(FXtrack)
  end

  -- default: "aliases"
  local list = {}
  if not FXtrack then return "" end
  local cnt = reaper.TrackFX_GetCount(FXtrack) or 0
  for i = 0, cnt-1 do
    local enabled = reaper.TrackFX_GetEnabled(FXtrack, i)
    if enabled then
      local _, raw = reaper.TrackFX_GetFXName(FXtrack, i, "")
      local name  = format_fx_label(raw)
      if name and name ~= "" then list[#list+1] = name end
    end
  end
  return table.concat(list, get_chain_alias_joiner())
end

-- =============================================
-- ==== selection snapshot helpers ====
local function snapshot_selection()
  local list = {}
  local n = reaper.CountSelectedMediaItems(0)
  for i = 0, n - 1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    if it then
      local tr = reaper.GetMediaItem_Track(it)
      local p  = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
      local l  = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
      table.insert(list, { tr = tr, L = p, R = p + l })
    end
  end
  return list
end

local function restore_selection(snap)
  if not snap then return end
  reaper.Main_OnCommand(40289, 0) -- clear selection
  local eps = project_epsilon()
  for _, rec in ipairs(snap) do
    local tr = rec.tr
    if tr then
      local n = reaper.CountTrackMediaItems(tr)
      for j = 0, n - 1 do
        local it = reaper.GetTrackMediaItem(tr, j)
        if it then
          local p  = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
          local l  = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
          local q  = p + l
          -- If this item covers the original selection range, consider it a match (TS-Window generates aligned glued clips)
          if p <= rec.L + eps and q >= rec.R - eps then
            reaper.SetMediaItemSelected(it, true)
            break
          end
        end
      end
    end
  end
end
-- ==== channel helpers ====
-- Get source channel count (ignores item channel mode)
local function get_source_channels(it)
  if not it then return 2 end
  local tk = reaper.GetActiveTake(it)
  if not tk then return 2 end
  local src = reaper.GetMediaItemTake_Source(tk)
  if not src then return 2 end
  local ch = reaper.GetMediaSourceNumChannels(src) or 2
  return ch
end

-- Get item's actual playback channel count (respects take channel mode setting)
-- This considers whether the take is set to mono, stereo, or multichannel
get_item_channels = function(it)
  if not it then return 2 end

  local tk = reaper.GetActiveTake(it)
  if not tk then return 2 end

  -- Get take's channel mode setting (IMPORTANT: use GetMediaItemTakeInfo_Value, not GetMediaItemInfo_Value!)
  -- I_CHANMODE: 0=normal, 1=reverse stereo, 2=downmix to mono, 3=left only, 4=right only, 5+=multichannel
  local chanmode = reaper.GetMediaItemTakeInfo_Value(tk, "I_CHANMODE")

  -- If set to mono (modes 2, 3, or 4), return 1
  if chanmode == 2 or chanmode == 3 or chanmode == 4 then
    return 1
  end

  -- Otherwise, use source channels
  return get_source_channels(it)
end

local function unit_max_channels(u)
  if not u or not u.items or #u.items == 0 then return 2 end
  local maxch = 1
  for _,it in ipairs(u.items) do
    local ch = get_item_channels(it)
    if ch > maxch then maxch = ch end
  end
  return maxch
end
-- =========================
function getSelectedMedia() --Get value of Media Item that is selected
  local selitem = 0
  local mediaItem = reaper.GetSelectedMediaItem(0, selitem)
  debug(mediaItem)
  return mediaItem
end

local function countSelected() --Makes sure there is only 1 MediaItem selected
  if reaper.CountSelectedMediaItems(0) == 1 then
    debug("Media Item is Selected! \n")
    return true
    else 
      debug("Must Have only ONE Media Item Selected")
      return false
  end
end

function checkSelectedFX() --Determines if a TrackFX is selected, and which FX is selected
  local retval = 0
  local tracknumberOut = 0
  local itemnumberOut = 0
  local fxnumberOut = 0
  local window = false

  -- Check for OVERRIDE ExtState first (set by GUI for SAVED CHAIN/HISTORY execution)
  local override_track_idx = reaper.GetExtState("hsuanice_AS", "OVERRIDE_TRACK_IDX")
  local override_fx_idx = reaper.GetExtState("hsuanice_AS", "OVERRIDE_FX_IDX")

  if override_track_idx ~= "" and override_fx_idx ~= "" then
    -- Use override values from GUI
    tracknumberOut = tonumber(override_track_idx) + 1  -- Convert 0-based to 1-based
    fxnumberOut = tonumber(override_fx_idx)
    retval = 1  -- Success

    debug(string.format("\n[OVERRIDE] Using track=%d, fx=%d", tracknumberOut, fxnumberOut))

    -- Clear override for next run
    reaper.SetExtState("hsuanice_AS", "OVERRIDE_TRACK_IDX", "", false)
    reaper.SetExtState("hsuanice_AS", "OVERRIDE_FX_IDX", "", false)
  else
    -- Fall back to GetFocusedFX
    retval, tracknumberOut, itemnumberOut, fxnumberOut = reaper.GetFocusedFX()
    debug ("\n"..retval..tracknumberOut..itemnumberOut..fxnumberOut)
  end

  -- Normalize FX index: strip container (0x2000000) and input/floating (0x1000000) flags
  local raw_fx = fxnumberOut or 0
  if raw_fx >= 0x2000000 then raw_fx = raw_fx - 0x2000000 end
  if raw_fx >= 0x1000000 then raw_fx = raw_fx - 0x1000000 end
  fxnumberOut = raw_fx

  local track = tracknumberOut - 1
  
  if track == -1 then
    track = 0
  else
  end
  
  local mtrack = reaper.GetTrack(0, track)
  
  window = reaper.TrackFX_GetOpen(mtrack, fxnumberOut)
  
  return retval, tracknumberOut, itemnumberOut, fxnumberOut, window
end

function getFXname(trackNumber, fxNumber) --Get FX name
  local track = trackNumber - 1
  local FX = fxNumber
  local FXname = ""

  local mTrack = reaper.GetTrack (0, track)
    
  local retvalfx, FXname = reaper.TrackFX_GetFXName(mTrack, FX, FXname)
    
  return FXname, mTrack
end

function bypassUnfocusedFX(FXmediaTrack, fxnumber_Out, render)--bypass and unbypass FX on FXtrack
  FXtrack = FXmediaTrack
  FXnumber = fxnumber_Out

  FXtotal = reaper.TrackFX_GetCount(FXtrack)
  FXtotal = FXtotal - 1
  
  if render == false then
    for i = 0, FXtotal do
      if i == FXnumber then
        reaper.TrackFX_SetEnabled(FXtrack, i, true)
      else
        reaper.TrackFX_SetEnabled(FXtrack, i, false)
      end
    end
  else
    for i = 0, FXtotal do
      reaper.TrackFX_SetEnabled(FXtrack, i, true)
      i = i + 1
    
    end
  end
  
  return
end

function getLoopSelection()--Checks to see if there is a loop selection
  local startOut, endOut = 0, 0
  local isSet, isLoop, allowautoseek = false, false, false

  startOut, endOut = reaper.GetSet_LoopTimeRange(isSet, isLoop, startOut, endOut, allowautoseek)
  local hasLoop = not (startOut == 0 and endOut == 0)
  return hasLoop, startOut, endOut
end

-- Build processing units from current selection:
-- same track, position-sorted, merge items that touch/overlap into one unit.
-- ===== epsilon helpers (early shim for forward calls) =====
if not project_epsilon then
  function project_epsilon()
    local sr = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
    return (sr and sr > 0) and (1.0 / sr) or 1e-6
  end
end

if not approx_eq then
  function approx_eq(a, b, eps)
    eps = eps or project_epsilon()
    return math.abs(a - b) <= eps
  end
end

if not ranges_touch_or_overlap then
  function ranges_touch_or_overlap(a0, a1, b0, b1, eps)
    eps = eps or project_epsilon()
    return not (a1 < b0 - eps or b1 < a0 - eps)
  end
end
-- ==========================================================
local function build_units_from_selection()
  local n = reaper.CountSelectedMediaItems(0)
  local by_track = {}
  for i = 0, n-1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    if it then
      local tr  = reaper.GetMediaItem_Track(it)
      local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
      local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
      local fin = pos + len
      by_track[tr] = by_track[tr] or {}
      table.insert(by_track[tr], { item=it, pos=pos, fin=fin })
    end
  end

  local units = {}
  local eps = project_epsilon()
  for tr, arr in pairs(by_track) do
    table.sort(arr, function(a,b) return a.pos < b.pos end)
    local cur = nil
    for _, e in ipairs(arr) do
      if not cur then
        cur = { track=tr, items={ e.item }, UL=e.pos, UR=e.fin }
      else
        if ranges_touch_or_overlap(cur.UL, cur.UR, e.pos, e.fin, eps) then
          table.insert(cur.items, e.item)
          if e.pos < cur.UL then cur.UL = e.pos end
          if e.fin > cur.UR then cur.UR = e.fin end
        else
          table.insert(units, cur)
          cur = { track=tr, items={ e.item }, UL=e.pos, UR=e.fin }
        end
      end
    end
    if cur then table.insert(units, cur) end
  end

  -- debug dump
  log_step("UNITS", "count=%d", #units)
  if debug_enabled() then
    for i,u in ipairs(units) do
      reaper.ShowConsoleMsg(string.format("  unit#%d  track=%s  members=%d  span=%.3f..%.3f\n",
        i, tostring(u.track), #u.items, u.UL, u.UR))
    end
  end
  return units
end

-- Collect units intersecting a time selection
local function collect_units_intersecting_ts(units, tsL, tsR)
  local out = {}
  -- Guard: only process one item via Core when not in TS-Window mode
  local processed_core_once = false
  for _,u in ipairs(units) do
    if ranges_touch_or_overlap(u.UL, u.UR, tsL, tsR, project_epsilon()) then
      table.insert(out, u)
    end
  end
  log_step("TS-INTERSECT", "TS=[%.3f..%.3f]  hit_units=%d", tsL, tsR, #out)
  return out
end

-- Strict: TS equals unit when both edges match within epsilon
local function ts_equals_unit(u, tsL, tsR)
  local eps = project_epsilon()
  return approx_eq(u.UL, tsL, eps) and approx_eq(u.UR, tsR, eps)
end

local function select_only_items(items)
  reaper.Main_OnCommand(40289, 0) -- Unselect all
  for _,it in ipairs(items) do reaper.SetMediaItemSelected(it, true) end
end

local function move_items_to_track(items, destTrack)
  for _, it in ipairs(items) do
    -- Enhanced safety check: only move MediaItem*
    if is_valid_item(it) then
      reaper.MoveMediaItemToTrack(it, destTrack)
    else
      log_step("WARN", "move_items_to_track: skipped non-item entry=%s", tostring(it))
    end
  end
end

-- Are all items on a certain track?
local function items_all_on_track(items, tr)
  for _,it in ipairs(items) do
    if not it then return false end
    local cur = reaper.GetMediaItem_Track(it)
    if cur ~= tr then return false end
  end
  return true
end

-- Select only specified items (ensure selection matches unit)
local function select_only_items_checked(items)
  reaper.Main_OnCommand(40289, 0)
  for _,it in ipairs(items) do
    if is_valid_item(it) then
      reaper.SetMediaItemSelected(it, true)
    end
  end
end

local function isolate_focused_fx(FXtrack, focusedIndex)
  -- enable only focusedIndex; others bypass
  local cnt = reaper.TrackFX_GetCount(FXtrack)
  for i = 0, cnt-1 do
    reaper.TrackFX_SetEnabled(FXtrack, i, i == focusedIndex)
  end
end

local function disable_all_fx(FXtrack)
  local cnt = reaper.TrackFX_GetCount(FXtrack)
  for i = 0, cnt-1 do
    reaper.TrackFX_SetEnabled(FXtrack, i, false)
  end
end

-- Forward declare helpers used below
local append_fx_to_take_name

-- Max FX tokens cap (via user option AS_MAX_FX_TOKENS)
local function max_fx_tokens()
  local n = get_max_fx_tokens()
  if not n or n < 1 then
    return math.huge -- unlimited
  end
  return math.floor(n)
end

-- === Take name normalization helpers (for AS naming) ===
local function strip_extension(name)
  return (name or ""):gsub("%.[A-Za-z0-9]+$", "")
end

-- remove "glued-XX", "render XXX/edX" and any trailing " - Something"
local function strip_glue_render_and_trailing_label(name)
  local s = name or ""
  s = s:gsub("[_%-%s]*glue[dD]?[%s_%-%d]*", "")
  s = s:gsub("[_%-%s]*render[eE]?[dD]?[%s_%-%d]*", "")
  s = s:gsub("%s+%-[%s%-].*$", "") -- remove trailing " - Something"
  s = s:gsub("%s+$","")
  s = s:gsub("[_%-%s]+$","")
  return s
end

-- tokens like "glued", "render", or "ed123"/"dup3" should be ignored
-- NOTE: do NOT drop pure-numeric tokens (e.g., "1073", "1176"), since some FX aliases are numeric.
local function is_noise_token(tok)
  local t = tostring(tok or ""):lower()
  if t == "" then return true end
  if t == "glue" or t == "glued" or t == "render" or t == "rendered" then return true end
  if t:match("^ed%d*$")  then return true end  -- e.g. "ed1", "ed23"
  if t:match("^dup%d*$") then return true end  -- e.g. "dup1"
  return false
end
-- Try parse "Base-AS{n}-FX1_FX2" and tolerate extra tails like "-ASx-YYY"
-- Return: base (string), n (number), fx_tokens (table)
local function parse_as_tag(full)
  local s = tostring(full or "")
  local base, n, tail = s:match("^(.-)[-_]AS(%d+)[-_](.+)$")
  if not base or not n then
    return nil, nil, nil
  end
  base = base:gsub("%s+$", "")

  -- If tail contains another "-ASx-" (e.g., "Saturn2-AS1-ProQ4"), only keep the part **before** the next AS tag.
  local first_tail = tail:match("^(.-)[-_]AS%d+[-_].*$") or tail

  -- PRE-CLEAN: strip legacy artifacts BEFORE tokenizing
  -- Remove whole "glued-XX", "render 001"/"rendered-03", and "ed###"/"dup###" sequences.
  local cleaned = first_tail
  cleaned = cleaned
              :gsub("[_%-%s]*glue[dD]?[%s_%-%d]*", "")     -- remove "glued" plus any digits/underscores/hyphens/spaces after it
              :gsub("[_%-%s]*render[eE]?[dD]?[%s_%-%d]*", "") -- remove "render"/"rendered" plus trailing digits etc.
              :gsub("ed%d+", "")                            -- remove "ed###"
              :gsub("dup%d+", "")                           -- remove "dup###"
              :gsub("%s+%-[%s%-].*$", "")                   -- trailing " - Something"
              :gsub("^[_%-%s]+", "")                        -- leading separators
              :gsub("[_%-%s]+$", "")                        -- trailing separators

  -- Tokenize FX names (alnum only), keep order.
  -- NOTE: pure numeric tokens are allowed (e.g., "1073"), since some aliases are numeric by design.
  local fx_tokens = {}
  for tok in cleaned:gmatch("([%w]+)") do
    if tok ~= "" and not tok:match("^AS%d+$") and not is_noise_token(tok) then
      fx_tokens[#fx_tokens+1] = tok
    end
  end

  return base, tonumber(n), fx_tokens
end
local function embed_previous_tc_for_item(item)
  if not item then return end
  local tk = reaper.GetActiveTake(item)
  if not tk then return end
  local prev_tk = nil
  local tc = reaper.CountTakes(item) or 0
  local active_idx = -1
  for i = 0, tc - 1 do
    local t = reaper.GetMediaItemTake(item, i)
    if t and t ~= tk then
      prev_tk = t
      if active_idx < 0 then active_idx = i end
      break
    elseif t == tk then
      active_idx = i
    end
  end
  if not prev_tk then return end
  local meta_path = reaper.GetResourcePath() .. "/Scripts/hsuanice Scripts/Library/hsuanice_Metadata Embed.lua"
  local ok_mod, E = pcall(dofile, meta_path)
  if not ok_mod or type(E) ~= "table" then return end
  if debug_enabled() then
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") or 0
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") or 0
    local offs_active = reaper.GetMediaItemTakeInfo_Value(tk, "D_STARTOFFS") or 0
    local offs_prev = reaper.GetMediaItemTakeInfo_Value(prev_tk, "D_STARTOFFS") or 0
    log_step("TC", "embed prev→active item=%s pos=%.6f len=%.6f takes=%d active_idx=%d offs_active=%.6f offs_prev=%.6f",
      tostring(item), pos, len, tc, active_idx, offs_active, offs_prev)
  end
  local smp = E.TR_PrevToActive(prev_tk, tk)
  local src = reaper.GetMediaItemTake_Source(tk)
  local path = src and reaper.GetMediaSourceFileName(src, "") or ""
  if path ~= "" and path:lower():sub(-4) == ".wav" then
    local cli = E.CLI_Resolve()
    if debug_enabled() and E.TR_Read then
      local ok_read, smp_prev = pcall(E.TR_Read, cli, path)
      log_step("TC", "embed tc: prev_read_ok=%s prev_smp=%s next_smp=%s path='%s'",
        tostring(ok_read), tostring(smp_prev), tostring(smp), path)
    end
    local ok = (select(1, E.TR_Write(cli, path, smp)) == true)
    if ok then
      E.Refresh_Items({ tk })
      if debug_enabled() then
        log_step("TC", "embed tc: write ok path='%s' smp=%s", path, tostring(smp))
      end
    elseif debug_enabled() then
      log_step("TC", "embed tc: write failed path='%s' smp=%s", path, tostring(smp))
    end
  elseif debug_enabled() then
    log_step("TC", "embed tc: skip non-wav path='%s'", path)
  end
end
local function embed_current_tc_from_item_start(item)
  if not item then return end
  local tk = reaper.GetActiveTake(item)
  if not tk then return end
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") or 0
  local offs = reaper.GetMediaItemTakeInfo_Value(tk, "D_STARTOFFS") or 0
  local meta_path = reaper.GetResourcePath() .. "/Scripts/hsuanice Scripts/Library/hsuanice_Metadata Embed.lua"
  local ok_mod, E = pcall(dofile, meta_path)
  if not ok_mod or type(E) ~= "table" then return end
  -- TR_FromItemStart already subtracts D_STARTOFFS internally
  local smp = E.TR_FromItemStart(tk, pos)
  local src = reaper.GetMediaItemTake_Source(tk)
  local path = src and reaper.GetMediaSourceFileName(src, "") or ""
  if debug_enabled() then
    log_step("TC", "embed current(from item) pos=%.6f offs=%.6f smp=%s path='%s'",
      pos, offs, tostring(smp), path)
  end
  if path ~= "" and path:lower():sub(-4) == ".wav" then
    local cli = E.CLI_Resolve()
    local ok = (select(1, E.TR_Write(cli, path, smp)) == true)
    if ok then
      E.Refresh_Items({ tk })
    end
    if debug_enabled() then
      log_step("TC", "embed current(from item) write=%s path='%s'", tostring(ok), path)
    end
  end
end
-- Shared: move single item to FX track and apply "focused FX only"
-- source_track_nchan_snapshot: optional table[source_track] = nchan for TS-WINDOW[GLOBAL] path (pre-glue snapshot of SOURCE tracks)
local function apply_focused_fx_to_item(item, FXmediaTrack, fxIndex, FXName, source_track_nchan_snapshot)
  if not item then return false, -1 end
  local origTR = reaper.GetMediaItem_Track(item)

  -- Ensure TC embed uses current timecode during Apply flow
  local _, tc_embed_snap = reaper.GetProjExtState(0, "RGWH", "RENDER_TC_EMBED")
  reaper.SetProjExtState(0, "RGWH", "RENDER_TC_EMBED", "current")

  -- ★ Snapshot take's channel info BEFORE moving (MoveMediaItemToTrack might affect it!)
  local tk = reaper.GetActiveTake(item)
  local orig_chanmode = tk and reaper.GetMediaItemTakeInfo_Value(tk, "I_CHANMODE") or 0
  local orig_src_ch = get_source_channels(item)

  -- ★ Snapshot source track channel count (protect from REAPER auto-adjust on move back)
  -- If called from TS-WINDOW[GLOBAL] with pre-glue snapshot, use that; otherwise snapshot now
  local orig_track_nchan
  if source_track_nchan_snapshot and source_track_nchan_snapshot[origTR] then
    orig_track_nchan = source_track_nchan_snapshot[origTR]
    if debug_enabled() then
      log_step("TS-APPLY", "Using pre-glue SOURCE snapshot: orig_track_nchan=%d", orig_track_nchan)
    end
  else
    orig_track_nchan = tonumber(reaper.GetMediaTrackInfo_Value(origTR, "I_NCHAN")) or 2
    if debug_enabled() then
      log_step("TS-APPLY", "Snapshot SOURCE now: orig_track_nchan=%d", orig_track_nchan)
    end
  end

  -- ★ NEW: snapshot FX enable state (preserve original bypass/enable)
  local fx_enable_snap = snapshot_fx_enables(FXmediaTrack)

  -- Move to FX track and isolate
  reaper.MoveMediaItemToTrack(item, FXmediaTrack)
  dbg_item_brief(item, "TS-APPLY moved→FX")
  local __AS = AS_merge_args_with_extstate({})
  if __AS.mode == "focused" then
    isolate_focused_fx(FXmediaTrack, fxIndex)
  else
    -- chain mode: do NOT isolate; apply entire track FX chain
  end

  -- Choose 40361/41993 based on ExtState channel mode (or auto-detect from item channels)
  local apply_fx_mode = reaper.GetExtState("hsuanice_AS","AS_APPLY_FX_MODE")
  -- Calculate item_ch from ORIGINAL chanmode (current chanmode was reset to 0 by move)
  local ch
  if orig_chanmode == 2 or orig_chanmode == 3 or orig_chanmode == 4 then
    ch = 1  -- mono modes
  else
    ch = orig_src_ch  -- use source channels
  end
  local prev_nchan = tonumber(reaper.GetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN")) or 2
  local cmd_apply  = 41993
  local did_set    = false

  -- Resolve channel mode: explicit setting from GUI or auto-detect
  local use_mono = false
  if apply_fx_mode == "mono" then
    use_mono = true
    if debug_enabled() then
      log_step("TS-APPLY", "AS_APPLY_FX_MODE='mono' (explicit) → use 40361")
    end
  elseif apply_fx_mode == "multi" then
    use_mono = false
    if debug_enabled() then
      log_step("TS-APPLY", "AS_APPLY_FX_MODE='multi' (explicit) → use 41993")
    end
  else
    -- auto or empty: detect from item playback channels (respects item channel mode)
    use_mono = (ch <= 1)
    if debug_enabled() then
      log_step("TS-APPLY", "AS_APPLY_FX_MODE='%s' → auto: source_ch=%d, item_ch=%d (orig_chanmode=%d) → use %d",
        apply_fx_mode, orig_src_ch, ch, orig_chanmode, use_mono and 40361 or 41993)
    end
  end

  local multi_policy = reaper.GetExtState("hsuanice_AS", "AS_MULTI_CHANNEL_POLICY")
  if multi_policy == "" then multi_policy = "source_playback" end  -- default

  -- In Multi+Source-Playback, keep mono items mono (use 40361).
  if apply_fx_mode == "multi" and multi_policy == "source_playback" and ch <= 1 then
    use_mono = true
  end

  if use_mono then
    cmd_apply = 40361
  else
    -- Multi-channel mode: apply policy (only when explicitly set to "multi")
    local desired = nil

    if apply_fx_mode == "multi" then
      -- Explicit Multi mode: apply policy
      if multi_policy == "source_playback" then
        -- Option 1: Match source item playback channels
        desired = (ch % 2 == 0) and ch or (ch + 1)
        if debug_enabled() then
          log_step("TS-APPLY", "Multi policy: SOURCE-PLAYBACK (item_ch=%d → desired=%d)", ch, desired)
        end
      elseif multi_policy == "source_track" then
        -- Option 2: Match source track channel count (use snapshotted value)
        desired = (orig_track_nchan % 2 == 0) and orig_track_nchan or (orig_track_nchan + 1)
        if debug_enabled() then
          log_step("TS-APPLY", "Multi policy: SOURCE-TRACK (track_ch=%d → desired=%d)", orig_track_nchan, desired)
        end
      elseif multi_policy == "target_track" then
        -- Option 3: Respect FX track's current channel count (no change)
        desired = nil  -- Do not modify I_NCHAN
        if debug_enabled() then
          log_step("TS-APPLY", "Multi policy: TARGET-TRACK (keep I_NCHAN=%d)", prev_nchan)
        end
      end
    else
      -- Auto mode: use SOURCE-PLAYBACK logic (default behavior)
      desired = (ch % 2 == 0) and ch or (ch + 1)
    end

    if desired and prev_nchan ~= desired then
      log_step("TS-APPLY", "I_NCHAN %d → %d (pre-apply)", prev_nchan, desired)
      reaper.SetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN", desired)
      did_set = true
    end
  end

  -- Select only that item then execute apply
  reaper.Main_OnCommand(40289, 0)
  reaper.SetMediaItemSelected(item, true)
  reaper.Main_OnCommand(cmd_apply, 0)
  log_step("TS-APPLY", "applied %d", cmd_apply)
  dbg_dump_selection("TS-APPLY post-apply")

  -- Restore I_NCHAN (if changed)
  if did_set then
    log_step("TS-APPLY", "I_NCHAN restore %d → %d", reaper.GetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN"), prev_nchan)
    reaper.SetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN", prev_nchan)
  end

  -- Retrieve the applied item (still the single selected item), rename, move back
  local out = reaper.GetSelectedMediaItem(0, 0) or item
  append_fx_to_take_name(out, FXName)
  reaper.MoveMediaItemToTrack(out, origTR)
  if debug_enabled() then
    log_step("TC", "embed tc on output item=%s", tostring(out))
  end
  embed_previous_tc_for_item(out)

  -- ★ Restore source track channel count (protect from REAPER auto-adjust)
  -- Skip individual restore if called from TS-WINDOW[GLOBAL] (will be restored in batch at end)
  if not source_track_nchan_snapshot then
    reaper.SetMediaTrackInfo_Value(origTR, "I_NCHAN", orig_track_nchan)
    if debug_enabled() then
      log_step("TS-APPLY", "Restored SOURCE track I_NCHAN to %d", orig_track_nchan)
    end
  else
    if debug_enabled() then
      log_step("TS-APPLY", "Skipping individual SOURCE restore (will restore in batch at TS-WINDOW[GLOBAL] end)")
    end
  end

  -- ★ NEW: restore FX enable state (back to original bypass/enable)
  restore_fx_enables(FXmediaTrack, fx_enable_snap)

  -- Restore TC embed setting
  if tc_embed_snap ~= "" then
    reaper.SetProjExtState(0, "RGWH", "RENDER_TC_EMBED", tc_embed_snap)
  else
    reaper.SetProjExtState(0, "RGWH", "RENDER_TC_EMBED", "")
  end

  return true, cmd_apply
end

-- Single item: use RGWH Core Render (new take; keep old take; render both Take FX and Track FX)
local function apply_focused_via_rgwh_render_new_take(item, FXmediaTrack, fxIndex, FXName)
  if not item then return false end
  local origTR = reaper.GetMediaItem_Track(item)

  -- ★ Snapshot take's channel mode BEFORE moving (MoveMediaItemToTrack might affect it!)
  local tk = reaper.GetActiveTake(item)
  local orig_chanmode = tk and reaper.GetMediaItemTakeInfo_Value(tk, "I_CHANMODE") or 0
  local orig_src_ch = get_source_channels(item)

  -- ★ Snapshot source track channel count (protect from REAPER auto-adjust on move back)
  local orig_track_nchan = tonumber(reaper.GetMediaTrackInfo_Value(origTR, "I_NCHAN")) or 2

  -- ★ NEW: snapshot FX enable state (preserve original bypass/enable)
  local fx_enable_snap = snapshot_fx_enables(FXmediaTrack)

  -- Move to FX track + isolate focused FX only (Track FX original enable/bypass state preserved; here just bypass non-focused)
  reaper.MoveMediaItemToTrack(item, FXmediaTrack)
  dbg_item_brief(item, "RGWH-RENDER moved→FX")
  local __AS = AS_merge_args_with_extstate({})
  if __AS.mode == "focused" then
    isolate_focused_fx(FXmediaTrack, fxIndex)
  else
    -- chain mode: do NOT isolate; render full chain
  end

  -- Select only this item as the render selection
  reaper.Main_OnCommand(40289, 0)
  reaper.SetMediaItemSelected(item, true)

  -- Load RGWH Core
  local CORE_PATH = reaper.GetResourcePath() .. "/Scripts/hsuanice Scripts/Library/hsuanice_RGWH Core.lua"
  local ok_mod, M = pcall(dofile, CORE_PATH)
  if not ok_mod or not M or type(M.render_selection) ~= "function" then
    -- ★ Restore FX enable state before returning
    restore_fx_enables(FXmediaTrack, fx_enable_snap)
    log_step("ERROR", "render_selection not available in RGWH Core")
    return false
  end

  -- ★ Important fix: use RGWH Core's "positional parameter" call version, ensure TAKE/TRACK flags = true
  --   M.render_selection(take_fx, track_fx, apply_mode, tc_embed)
  --   Read apply_mode from ExtState (set by GUI), fallback to "auto"
  local apply_fx_mode = reaper.GetExtState("hsuanice_AS","AS_APPLY_FX_MODE")
  if apply_fx_mode == "" then apply_fx_mode = "auto" end

  -- Resolve "auto" mode to "mono" or "multi" based on item's ORIGINAL playback channels
  -- (use orig_chanmode because MoveMediaItemToTrack resets chanmode to 0!)
  if apply_fx_mode == "auto" then
    -- Calculate item_ch from original chanmode
    local item_ch
    if orig_chanmode == 2 or orig_chanmode == 3 or orig_chanmode == 4 then
      item_ch = 1  -- mono modes
    else
      item_ch = orig_src_ch  -- use source channels
    end
    apply_fx_mode = (item_ch >= 2) and "multi" or "mono"

    if debug_enabled() then
      log_step("RGWH-RENDER", "auto mode: source_ch=%d, item_ch=%d (orig_chanmode=%d) → resolved to '%s'",
        orig_src_ch, item_ch, orig_chanmode, apply_fx_mode)
    end
  else
    if debug_enabled() then
      log_step("RGWH-RENDER", "AS_APPLY_FX_MODE from ExtState: '%s' (explicit)", apply_fx_mode)
    end
  end

  -- Apply Multi-Channel Policy if in explicit "multi" mode
  if debug_enabled() then
    log_step("RGWH-RENDER", "apply_fx_mode='%s' (checking if == 'multi')", apply_fx_mode)
  end

  if apply_fx_mode == "multi" then
    local multi_policy = reaper.GetExtState("hsuanice_AS", "AS_MULTI_CHANNEL_POLICY")
    if multi_policy == "" then multi_policy = "source_playback" end
    if debug_enabled() then
      log_step("RGWH-RENDER", "Entering Multi-Channel Policy logic; policy='%s'", multi_policy)
    end

    local desired = nil

    if multi_policy == "source_playback" then
      -- Option 1: Match source item playback channels
      local item_ch
      if orig_chanmode == 2 or orig_chanmode == 3 or orig_chanmode == 4 then
        item_ch = 1  -- mono modes
      else
        item_ch = orig_src_ch  -- use source channels
      end
      if item_ch <= 1 then
        -- Keep mono items mono in source_playback policy
        apply_fx_mode = "mono"
      else
        desired = (item_ch % 2 == 0) and item_ch or (item_ch + 1)
      end
      if debug_enabled() then
        log_step("RGWH-RENDER", "Multi policy: SOURCE-PLAYBACK (item_ch=%d → desired=%d)", item_ch, desired or item_ch)
      end
    elseif multi_policy == "source_track" then
      -- Option 2: Match source track channel count
      local src_track_ch = tonumber(reaper.GetMediaTrackInfo_Value(origTR, "I_NCHAN")) or 2
      desired = (src_track_ch % 2 == 0) and src_track_ch or (src_track_ch + 1)
      if debug_enabled() then
        log_step("RGWH-RENDER", "Multi policy: SOURCE-TRACK (track_ch=%d → desired=%d)", src_track_ch, desired)
      end
    elseif multi_policy == "target_track" then
      -- Option 3: Respect FX track's current channel count (no change)
      desired = nil  -- Do not modify I_NCHAN
      if debug_enabled() then
        local fx_track_ch = tonumber(reaper.GetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN")) or 2
        log_step("RGWH-RENDER", "Multi policy: TARGET-TRACK (keep I_NCHAN=%d)", fx_track_ch)
      end
    end

    if apply_fx_mode == "mono" then
      -- Force mono render when source_playback is mono
      local ok_call, ret_or_err = pcall(M.render_selection, 1, 1, "mono", "current")
      reaper.SetExtState("hsuanice_AS", "RGWH_PRESERVE_TRACK_CH", "", false)
      if not ok_call then
        log_step("ERROR", "render_selection() runtime error: %s", tostring(ret_or_err))
      end
      local out = reaper.GetSelectedMediaItem(0, 0) or item
      append_fx_to_take_name(out, FXName)
      reaper.MoveMediaItemToTrack(out, origTR)
      reaper.SetMediaTrackInfo_Value(origTR, "I_NCHAN", orig_track_nchan)
      restore_fx_enables(FXmediaTrack, fx_enable_snap)
      return true
    end

    -- Set FX track channel count before calling RGWH Core
    if desired then
      reaper.SetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN", desired)
      if debug_enabled() then
        log_step("RGWH-RENDER", "Set FX track I_NCHAN to %d before render", desired)
      end
    end

    -- Tell RGWH Core to NOT restore FX track channel count (allows Multi-Channel Policy to work)
    reaper.SetExtState("hsuanice_AS", "RGWH_PRESERVE_TRACK_CH", "0", false)
  else
    -- When not in Multi mode, allow RGWH Core to restore (for TARGET-TRACK policy compatibility)
    reaper.SetExtState("hsuanice_AS", "RGWH_PRESERVE_TRACK_CH", "1", false)
  end

  local ok_call, ret_or_err = pcall(M.render_selection, 1, 1, apply_fx_mode, "current")

  -- Clear ExtState after RGWH Core execution
  reaper.SetExtState("hsuanice_AS", "RGWH_PRESERVE_TRACK_CH", "", false)

  if not ok_call then
    log_step("ERROR", "render_selection() runtime error: %s", tostring(ret_or_err))
    -- Still attempt to retrieve new output below, in case Core errored but actually produced a new take
  end

  -- Retrieve item with new take (still selected), rename and move back to original track
  local out = reaper.GetSelectedMediaItem(0, 0) or item
  append_fx_to_take_name(out, FXName)
  reaper.MoveMediaItemToTrack(out, origTR)

  -- ★ Restore source track channel count (protect from REAPER auto-adjust)
  reaper.SetMediaTrackInfo_Value(origTR, "I_NCHAN", orig_track_nchan)
  if debug_enabled() then
    log_step("RGWH-RENDER", "Restored source track I_NCHAN to %d", orig_track_nchan)
  end

  -- ★ NEW: restore FX enable state (back to original bypass/enable)
  restore_fx_enables(FXmediaTrack, fx_enable_snap)

  return true
end

function append_fx_to_take_name(item, fxName)
  if not item or not fxName or fxName == "" then return end
  local takeIndex = reaper.GetMediaItemInfo_Value(item, "I_CURTAKE")
  local take      = reaper.GetMediaItemTake(item, takeIndex)
  if not take then return end

  local _, tn0 = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  local tn_noext = strip_extension(tn0 or "")

  -- naming debug: before
  if debug_naming_enabled() then
    reaper.ShowConsoleMsg(("[AS][NAME] before='%s'\n"):format(tn0 or ""))
  end

  local baseAS, nAS, fx_tokens = parse_as_tag(tn_noext)

  local base, n, tokens
  if baseAS and nAS then
    base   = strip_glue_render_and_trailing_label(baseAS)
    n      = nAS + 1
    tokens = fx_tokens or {}
  else
    base   = strip_glue_render_and_trailing_label(tn_noext)
    n      = 1
    tokens = {}
  end

  -- always append new FX (allow duplicates; preserve chronological order)
  table.insert(tokens, fxName)

  -- Apply user cap (FIFO): keep only the last N tokens
  do
    local cap = max_fx_tokens()
    if cap ~= math.huge and #tokens > cap then
      local start = #tokens - cap + 1
      local trimmed = {}
      for i = start, #tokens do
        trimmed[#trimmed+1] = tokens[i]
      end
      tokens = trimmed
    end
  end

  local fx_concat = table.concat(tokens, "_")
  local new_name = string.format("%s-AS%d-%s", base, n, fx_concat)

  -- naming debug: after
  if debug_naming_enabled() then
    reaper.ShowConsoleMsg(("[AS][NAME] after ='%s'\n"):format(new_name))
  end

  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
end

function mediaItemInLoop(mediaItem, startLoop, endLoop)
  local mpos = reaper.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
  local mlen = reaper.GetMediaItemInfo_Value(mediaItem, "D_LENGTH")
  local mend = mpos + mlen
  -- use 1 sample as epsilon
  local sr = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  local eps = (sr and sr > 0) and (1.0 / sr) or 1e-6

  local function approx_eq(a, b) return math.abs(a - b) <= eps end

  -- TS equals unit ONLY when both edges match (within epsilon)
  return approx_eq(mpos, startLoop) and approx_eq(mend, endLoop)
end


function cropNewTake(mediaItem, tracknumber_Out, FXname)--Crop to new take and change name to add FXname

  track = tracknumber_Out - 1
  
  fxName = FXname
    
  --reaper.Main_OnCommand(40131, 0) --This is what crops to the Rendered take. With this removed, you will have a take for each FX you apply
  
  currentTake = reaper.GetMediaItemInfo_Value(mediaItem, "I_CURTAKE")
  
  take = reaper.GetMediaItemTake(mediaItem, currentTake)
  
  local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  local newName = takeName
  if fxName ~= "" then
    newName = takeName .. " - " .. fxName
  end
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", newName, true)
  return true
end

function setNudge()
  reaper.ApplyNudge(0, 0, 0, 0, 1, false, 0)
  reaper.ApplyNudge(0, 0, 0, 0, -1, false, 0)
end

function main() -- main part of the script
  -- Check if external caller wants to manage undo (for single undo in GUI/standalone scripts)
  -- Set ExtState "hsuanice_AS/EXTERNAL_UNDO_CONTROL" = "1" to disable Core's internal undo block
  local external_undo = (reaper.GetExtState("hsuanice_AS", "EXTERNAL_UNDO_CONTROL") == "1")

  if not external_undo then
    reaper.Undo_BeginBlock()
  end
  reaper.PreventUIRefresh(1)
  if debug_enabled() then
    reaper.ShowConsoleMsg("\n=== AudioSweet (hsuanice) run ===\n")
  end
  log_step("BEGIN", "selected_items=%d (external_undo=%s)", reaper.CountSelectedMediaItems(0), tostring(external_undo))
  -- snapshot original selection so we can restore it at the very end
  local sel_snapshot = snapshot_selection()

  -- Snapshot track channel count (will be set after we know FXmediaTrack)
  local track_nchan_snapshot = nil

  -- Focused FX check
  local AS_args = AS_merge_args_with_extstate({})
  local ret_val, tracknumber_Out, itemnumber_Out, fxnumber_Out, window = checkSelectedFX()

  -- In chain mode, if no focused FX, use first selected track as fallback
  if ret_val ~= 1 and AS_args.mode == "chain" then
    local first_track = reaper.GetSelectedTrack(0, 0)
    if first_track then
      tracknumber_Out = reaper.CSurf_TrackToID(first_track, false)
      fxnumber_Out = 0
      ret_val = 1  -- Pretend focus check passed
      log_step("CHAIN-FALLBACK", "No focused FX, using first selected track (tr#=%d)", tracknumber_Out)
    end
  end

  if ret_val ~= 1 then
    reaper.MB("Please focus a Track FX (not a Take FX).", "AudioSweet", 0)
    reaper.PreventUIRefresh(-1)
    if not external_undo then
      reaper.Undo_EndBlock("AudioSweet (no focused Track FX)", -1)
    end
    return
  end
  log_step("FOCUSED-FX", "trackOut=%d  itemOut=%d  fxOut=%d  window=%s", tracknumber_Out, itemnumber_Out, fxnumber_Out, tostring(window))

  -- Normalize focused FX index & resolve name/track
  local fxIndex = fxnumber_Out
  if fxIndex >= 0x1000000 then fxIndex = fxIndex - 0x1000000 end
  local FXNameRaw, FXmediaTrack = getFXname(tracknumber_Out, fxIndex)
  local FXName = format_fx_label(FXNameRaw)
  log_step("FOCUSED-FX", "index(norm)=%d  name='%s' (raw='%s')  FXtrack=%s",
           fxIndex, tostring(FXName or ""), tostring(FXNameRaw or ""), tostring(FXmediaTrack))

  -- Snapshot track channel count now that we have FXmediaTrack
  if FXmediaTrack then
    track_nchan_snapshot = reaper.GetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN")
    log_step("SNAPSHOT", "track channel count = %d", track_nchan_snapshot or -1)
  end

  -- Helper function to restore track channel count
  local function restore_track_nchan()
    if FXmediaTrack and track_nchan_snapshot then
      reaper.SetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN", track_nchan_snapshot)
      log_step("RESTORE", "track channel count = %d", track_nchan_snapshot)
    end
  end

  -- Determine naming token based on mode (focused vs chain)
  local naming_token = FXName
  if AS_args.mode == "chain" then
    naming_token = build_chain_token(FXmediaTrack)
    if naming_token == "" then naming_token = FXName end
    log_step("CHAIN-TOKEN", "mode=chain  token='%s' (source=%s)",
             tostring(naming_token), tostring(get_chain_token_source()))
  end

  local AS = AS_merge_args_with_extstate({})
  local is_apply_after_copy = (AS.action == "apply_after_copy")

  -- === Early branch: COPY mode (non-destructive; no rename) ===
  if AS.action == "copy" then
    local ops = 0
    if AS.mode == "focused" then
      ops = AS_copy_focused_fx_to_items(FXmediaTrack, fxIndex, AS)
      log_step("COPY", "focused FX → items  scope=%s pos=%s  ops=%d", tostring(AS.scope), tostring(AS.append_pos), ops)
      if not external_undo then
        reaper.Undo_EndBlock(string.format("AudioSweet: Copy focused FX to items (%d op)", ops), 0)
      end
    else
      ops = AS_copy_chain_to_items(FXmediaTrack, AS)
      log_step("COPY", "FX CHAIN → items  scope=%s pos=%s  ops=%d", tostring(AS.scope), tostring(AS.append_pos), ops)
      if not external_undo then
        reaper.Undo_EndBlock(string.format("AudioSweet: Copy FX chain to items (%d op)", ops), 0)
      end
    end
    reaper.UpdateArrange()
    restore_selection(sel_snapshot)
    restore_track_nchan()
    reaper.PreventUIRefresh(-1)
    return
  end
  -- === End COPY branch; continue into APPLY flow ===


  -- Build units from current selection
  local units = build_units_from_selection()
  if #units == 0 then
    reaper.MB("No media items selected.", "AudioSweet", 0)
    reaper.PreventUIRefresh(-1)
    if not external_undo then
      reaper.Undo_EndBlock("AudioSweet (no items)", -1)
    end
    return
  end

  if debug_enabled() then
    for i,u in ipairs(units) do dbg_dump_unit(u, i) end
  end  

  -- Time selection state
  local hasTS, tsL, tsR = getLoopSelection()
  if debug_enabled() then
    log_step("PATH", "hasTS=%s TS=[%.3f..%.3f]", tostring(hasTS), tsL or -1, tsR or -1)
  end

  -- Helper: Core flags setup/restore
  local function proj_get(ns, key, def)
    local _, val = reaper.GetProjExtState(0, ns, key)
    if val == "" then return def else return val end
  end
  local function proj_set(ns, key, val)
    reaper.SetProjExtState(0, ns, key, tostring(val or ""))
  end

  -- Process (two paths)
  local outputs = {}

  if hasTS then
    -- Figure out how many units intersect the TS
    local hit = collect_units_intersecting_ts(units, tsL, tsR)
    if debug_enabled() then
      log_step("PATH", "TS hit_units=%d → %s", #hit, (#hit>=2 and "TS-WINDOW[GLOBAL]" or "per-unit"))
    end    
    if #hit >= 2 then
      ------------------------------------------------------------------
      -- TS-Window (GLOBAL): Pro Tools behavior (no handles)
      ------------------------------------------------------------------
      log_step("TS-WINDOW[GLOBAL]", "begin TS=[%.3f..%.3f] units_hit=%d", tsL, tsR, #hit)
      log_step("PATH", "ENTER TS-WINDOW[GLOBAL]")

      -- ★ NEW: Snapshot all source track channel counts BEFORE glue operation
      -- (Glue command 42432 may modify track channel counts, so we must snapshot first)
      local source_track_nchan_snapshot = {}
      for _,u in ipairs(hit) do
        for _,it in ipairs(u.items) do
          local tr = reaper.GetMediaItem_Track(it)
          if tr and not source_track_nchan_snapshot[tr] then
            local nchan = tonumber(reaper.GetMediaTrackInfo_Value(tr, "I_NCHAN")) or 2
            source_track_nchan_snapshot[tr] = nchan
            if debug_enabled() then
              local tr_num = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
              log_step("TS-WINDOW[GLOBAL]", "snapshot SOURCE track #%d I_NCHAN=%d (pre-glue)", tr_num, nchan)
            end
          end
        end
      end

      -- Select all items in intersecting units (on their original tracks)
      reaper.Main_OnCommand(40289, 0)
      for _,u in ipairs(hit) do
        for _,it in ipairs(u.items) do reaper.SetMediaItemSelected(it, true) end
      end
      log_step("TS-WINDOW[GLOBAL]", "pre-42432 selected_items=%d", reaper.CountSelectedMediaItems(0))
      dbg_dump_selection("TSW[GLOBAL] pre-42432")      -- ★ NEW
      reaper.Main_OnCommand(42432, 0) -- Glue items within time selection (no handles)
      log_step("TS-WINDOW[GLOBAL]", "post-42432 selected_items=%d", reaper.CountSelectedMediaItems(0))
      dbg_dump_selection("TSW[GLOBAL] post-42432")     -- ★ NEW

      -- Each glued result: first copy current selection to stable list, then apply one by one
      local glued_items = {}
      do
        local n = reaper.CountSelectedMediaItems(0)
        for i = 0, n - 1 do
          local it = reaper.GetSelectedMediaItem(0, i)
          if it then glued_items[#glued_items + 1] = it end
        end
      end

      for idx, it in ipairs(glued_items) do
        local ok, used_cmd = apply_focused_fx_to_item(it, FXmediaTrack, fxIndex, naming_token, source_track_nchan_snapshot)
        if ok then
          log_step("TS-WINDOW[GLOBAL]", "applied %d to glued #%d", used_cmd or -1, idx)
          -- Get the actually applied item (function sets selection to this item)
          local out_item = reaper.GetSelectedMediaItem(0, 0)
          if out_item then
            if is_apply_after_copy then
              local tr = reaper.GetMediaItem_Track(out_item)
              local src_nchan = source_track_nchan_snapshot[tr]
              local copied = copy_fx_to_non_active_takes(out_item, FXmediaTrack, fxIndex, src_nchan)
              log_step("COPY", "apply_after_copy: copied FX to %d take(s)", copied)
            end
            table.insert(outputs, out_item)
          end
        else
          log_step("TS-WINDOW[GLOBAL]", "apply failed on glued #%d", idx)
        end
      end

      log_step("TS-WINDOW[GLOBAL]", "done, outputs=%d", #outputs)

      -- ★ NEW: Restore all source track channel counts (protect from REAPER auto-adjust during glue)
      for tr, nchan in pairs(source_track_nchan_snapshot) do
        reaper.SetMediaTrackInfo_Value(tr, "I_NCHAN", nchan)
        if debug_enabled() then
          local tr_num = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
          log_step("TS-WINDOW[GLOBAL]", "restored SOURCE track #%d I_NCHAN=%d (post-all)", tr_num, nchan)
        end
      end

      -- Restore pre-execution selection (picks new glued/printed clips on same track and range)
      restore_selection(sel_snapshot)
      if debug_enabled() then dbg_dump_selection("RESTORE selection") end
      restore_track_nchan()

      reaper.PreventUIRefresh(-1)
      if not external_undo then
        reaper.Undo_EndBlock("AudioSweet TS-Window (global) glue+print", 0)
      end
      return
    end
    -- else: TS hits 0 or 1 unit → fall through to per-unit branch below
  end

  ----------------------------------------------------------------------
  -- Per-unit path:
  --   - No TS: Core/GLUE (with handles)
  --   - Has TS and TS==unit: Core/GLUE (with handles)
  --   - Has TS and TS≠unit: TS-Window (UNIT; no handles) → 42432 → 40361
  ----------------------------------------------------------------------
  for _,u in ipairs(units) do
    log_step("UNIT", "enter UL=%.3f UR=%.3f members=%d", u.UL, u.UR, #u.items)
    dbg_dump_unit(u, -1) -- dump the current unit (−1 = “in-process” marker)
    if hasTS and not ts_equals_unit(u, tsL, tsR) then
      log_step("PATH", "TS-WINDOW[UNIT] UL=%.3f UR=%.3f", u.UL, u.UR)
      --------------------------------------------------------------
      -- TS-Window (UNIT) no handles: 42432 → 40361
      --------------------------------------------------------------
      -- select only this unit's items and glue within TS
      reaper.Main_OnCommand(40289, 0)
      for _,it in ipairs(u.items) do reaper.SetMediaItemSelected(it, true) end
      log_step("TS-WINDOW[UNIT]", "pre-42432 selected_items=%d", reaper.CountSelectedMediaItems(0))
      dbg_dump_selection("TSW[UNIT] pre-42432")        -- ★ NEW
      reaper.Main_OnCommand(42432, 0)
      log_step("TS-WINDOW[UNIT]", "post-42432 selected_items=%d", reaper.CountSelectedMediaItems(0))
      dbg_dump_selection("TSW[UNIT] post-42432")       -- ★ NEW

      local glued = reaper.GetSelectedMediaItem(0, 0)
      if not glued then
        reaper.MB("TS-Window glue failed: no item after 42432 (unit).", "AudioSweet", 0)
        goto continue_unit
      end

      local ok, used_cmd = apply_focused_fx_to_item(glued, FXmediaTrack, fxIndex, naming_token)
      if ok then
        log_step("TS-WINDOW[UNIT]", "applied %d", used_cmd or -1)
        if is_apply_after_copy then
          local src_nchan = tonumber(reaper.GetMediaTrackInfo_Value(u.track, "I_NCHAN")) or 2
          local copied = copy_fx_to_non_active_takes(glued, FXmediaTrack, fxIndex, src_nchan)
          log_step("COPY", "apply_after_copy: copied FX to %d take(s)", copied)
        end
        table.insert(outputs, glued)  -- out item already moved back to original track
      else
        log_step("TS-WINDOW[UNIT]", "apply failed")
      end
    else
      --------------------------------------------------------------
      -- Core/GLUE path (unified for both single and multi-item units):
      --   No TS or TS==unit:
      --     • All units (single or multi-item) → use Core/GLUE (with handles)
      --     • GLUE mode produces single take (no old take preserved)
      --------------------------------------------------------------
      -- === Use Core/GLUE for all units (single or multi-item) ===

        -- ★ NEW: Snapshot source track channel count BEFORE moving items (protect from REAPER auto-adjust)
        local orig_track_nchan_core = tonumber(reaper.GetMediaTrackInfo_Value(u.track, "I_NCHAN")) or 2
        if debug_enabled() then
          local tr_num = reaper.GetMediaTrackInfo_Value(u.track, "IP_TRACKNUMBER")
          log_step("CORE", "snapshot SOURCE track #%d I_NCHAN=%d (pre-move)", tr_num, orig_track_nchan_core)
        end

        -- Move all unit items to FX track (keep as-is), but select only the anchor for Core.
        move_items_to_track(u.items, FXmediaTrack)

        -- ★ NEW: snapshot FX enable state (preserve original bypass/enable)
        local fx_enable_snap_core = snapshot_fx_enables(FXmediaTrack)

        -- Enable only focused FX, temporarily bypass others
        local __AS = AS_merge_args_with_extstate({})
        if __AS.mode == "focused" then
          isolate_focused_fx(FXmediaTrack, fxIndex)
        else
          -- chain mode: leave all FX enabled as-is (full chain)
        end

        -- Select the entire unit (non-TS path should preserve full unit selection)
        local anchor = u.items[1]  -- still used for channel auto and safety
        select_only_items_checked(u.items)

        -- [DBG] after move
        do
          local moved = 0
          for _,it in ipairs(u.items) do
            if it and reaper.GetMediaItem_Track(it) == FXmediaTrack then
              moved = moved + 1
            end
          end
          log_step("CORE", "post-move: on-FX=%d / unit=%d", moved, #u.items)

          if debug_enabled() then
            local L = u.UL - project_epsilon()
            local R = u.UR + project_epsilon()
            dbg_track_items_in_range(FXmediaTrack, L, R)
          end
        end

        -- [DBG] selection should equal the full unit at this point
        do
          local selN = reaper.CountSelectedMediaItems(0)
          log_step("CORE", "pre-apply selection count=%d (expect=%d)", selN, #u.items)
          dbg_dump_selection("CORE pre-apply selection")
        end

        -- Load Core
        local failed = false
        local CORE_PATH = reaper.GetResourcePath() .. "/Scripts/hsuanice Scripts/Library/hsuanice_RGWH Core.lua"
        local ok_mod, mod = pcall(dofile, CORE_PATH)
        if not ok_mod or not mod then
          log_step("ERROR", "Core load failed: %s", CORE_PATH)
          reaper.MB("RGWH Core not found or failed to load:\n" .. CORE_PATH, "AudioSweet — Core load failed", 0)
          failed = true
        end

        local core_api = nil
        if not failed then
          core_api = (type(mod)=="table" and type(mod.core)=="function") and mod.core
                     or (type(mod)=="table" and type(mod.glue_selection)=="function") and mod.glue_selection
          if not core_api then
            log_step("ERROR", "RGWH.core or RGWH.glue_selection not found in module")
            reaper.MB("RGWH Core loaded, but M.core() or M.glue_selection() not found.", "AudioSweet — Core API missing", 0)
            failed = true
          end
        end

        -- Resolve auto apply_fx_mode by MAX channels across the entire unit
        -- Use item's actual playback channels (respects item channel mode), not source channels
        local apply_fx_mode = nil
        if not failed then
          apply_fx_mode = reaper.GetExtState("hsuanice_AS","AS_APPLY_FX_MODE")
          if apply_fx_mode == "" or apply_fx_mode == "auto" then
            local ch = unit_max_channels(u)
            apply_fx_mode = (ch <= 1) and "mono" or "multi"
            if debug_enabled() then
              log_step("CORE", "AS_APPLY_FX_MODE='%s' → auto-detect: unit_max_ch=%d → resolved to '%s'",
                (apply_fx_mode == "" and "empty" or "auto"), ch, apply_fx_mode)
            end
          else
            if debug_enabled() then
              log_step("CORE", "AS_APPLY_FX_MODE from ExtState: '%s' (explicit)", apply_fx_mode)
            end
          end
        end

        if debug_enabled() then
          local c = reaper.CountSelectedMediaItems(0)
          log_step("CORE", "pre-apply selected_items=%d (expect = unit members=%d)", c, #u.items)
        end

        -- Snapshot & set project flags
        local snap = {}
        local function proj_get(ns, key, def)
          local _, val = reaper.GetProjExtState(0, ns, key); return (val == "" and def) or val
        end
        local function proj_set(ns, key, val)
          reaper.SetProjExtState(0, ns, key, tostring(val or ""))
        end

        -- Check: are all unit items already on FX track
        if not items_all_on_track(u.items, FXmediaTrack) then
          log_step("ERROR", "unit members not on FX track; fixing...")
          move_items_to_track(u.items, FXmediaTrack)
        end
        -- Check: does selection equal the entire unit
        select_only_items_checked(u.items)
        if debug_enabled() then
          log_step("CORE", "pre-apply selected_items=%d (expect=%d)", reaper.CountSelectedMediaItems(0), #u.items)
        end

        -- Snapshot
        snap.GLUE_TAKE_FX      = proj_get("RGWH","GLUE_TAKE_FX","")
        snap.GLUE_TRACK_FX     = proj_get("RGWH","GLUE_TRACK_FX","")
        snap.GLUE_APPLY_MODE   = proj_get("RGWH","GLUE_APPLY_MODE","")
        snap.GLUE_SINGLE_ITEMS = proj_get("RGWH","GLUE_SINGLE_ITEMS","")
        snap.RENDER_TC_EMBED   = proj_get("RGWH","RENDER_TC_EMBED","")

        -- Set desired flags
        proj_set("RGWH","GLUE_TAKE_FX","1")
        proj_set("RGWH","GLUE_TRACK_FX","1")
        proj_set("RGWH","GLUE_APPLY_MODE",apply_fx_mode)
        proj_set("RGWH","GLUE_SINGLE_ITEMS","1")
        -- Do not override RGWH TC embed mode; preserve its own setting

        if debug_enabled() then
          local _, gsi = reaper.GetProjExtState(0, "RGWH", "GLUE_SINGLE_ITEMS")
          log_step("CORE", "flag GLUE_SINGLE_ITEMS=%s (expected=1 for unit-glue)", (gsi == "" and "(empty)") or gsi)
        end

        -- ★ NEW: Apply Multi-Channel Policy (only when explicitly set to "multi")
        local desired_nchan_for_copy = nil
        if apply_fx_mode == "multi" then
          local multi_policy = reaper.GetExtState("hsuanice_AS", "AS_MULTI_CHANNEL_POLICY")
          if multi_policy == "" then multi_policy = "source_playback" end
          if debug_enabled() then
            log_step("CORE", "Entering Multi-Channel Policy logic; policy='%s'", multi_policy)
          end

          local desired = nil

          if multi_policy == "source_playback" then
            -- Option 1: Match unit's max playback channels
            local unit_ch = unit_max_channels(u)
            if unit_ch <= 1 then
              -- Keep mono items mono in source_playback policy
              apply_fx_mode = "mono"
            else
              desired = (unit_ch % 2 == 0) and unit_ch or (unit_ch + 1)
              desired_nchan_for_copy = desired
            end
            if debug_enabled() then
              log_step("CORE", "Multi policy: SOURCE-PLAYBACK (unit_max_ch=%d → desired=%d)", unit_ch, desired or unit_ch)
            end
          elseif multi_policy == "source_track" then
            -- Option 2: Match source track channel count
            local src_track_ch = orig_track_nchan_core  -- Use the snapshotted value
            desired = (src_track_ch % 2 == 0) and src_track_ch or (src_track_ch + 1)
            desired_nchan_for_copy = desired
            if debug_enabled() then
              log_step("CORE", "Multi policy: SOURCE-TRACK (track_ch=%d → desired=%d)", src_track_ch, desired)
            end
          elseif multi_policy == "target_track" then
            -- Option 3: Respect FX track's current channel count (no change)
            desired = nil  -- Do not modify I_NCHAN
            local fx_track_ch = tonumber(reaper.GetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN")) or 2
            desired_nchan_for_copy = fx_track_ch
            if debug_enabled() then
              log_step("CORE", "Multi policy: TARGET-TRACK (keep I_NCHAN=%d)", fx_track_ch)
            end
          end

          -- Set FX track channel count before calling RGWH Core
          if desired then
            reaper.SetMediaTrackInfo_Value(FXmediaTrack, "I_NCHAN", desired)
            if debug_enabled() then
              log_step("CORE", "Set FX track I_NCHAN to %d before glue", desired)
            end
          end

          -- Tell RGWH Core to NOT restore FX track channel count (allows Multi-Channel Policy to work)
          reaper.SetExtState("hsuanice_AS", "RGWH_PRESERVE_TRACK_CH", "0", false)
        else
          -- When not in Multi mode, allow RGWH Core to restore (default behavior)
          reaper.SetExtState("hsuanice_AS", "RGWH_PRESERVE_TRACK_CH", "1", false)
        end

        -- Prepare arguments and call Core
        if not is_valid_item(anchor) then
          log_step("ERROR", "anchor item invalid (u.items[1]=%s)", tostring(anchor))
          reaper.MB("Internal error: unit anchor item is invalid.", "AudioSweet", 0)
          failed = true
        else
          -- Use new M.core() API
          local is_chain_mode = (AS_merge_args_with_extstate({}).mode == "chain")
          local args = {
            op = "glue",
            channel_mode = apply_fx_mode,
            take_fx = true,
            track_fx = true,
          }
          if debug_enabled() then
            local c = reaper.CountSelectedMediaItems(0)
            log_step("CORE", "call M.core: op=%s channel_mode=%s take_fx=true track_fx=true unit_members=%d",
              tostring(args.op), tostring(args.channel_mode), #u.items)
            log_step("CORE", "pre-apply FINAL selected_items=%d", c)
            dbg_dump_selection("CORE pre-apply FINAL")
          end

          local ok_call, ok_apply, err = pcall(core_api, args)

          -- Clear ExtState after RGWH Core execution
          reaper.SetExtState("hsuanice_AS", "RGWH_PRESERVE_TRACK_CH", "", false)

          if not ok_call then
            log_step("ERROR", "M.core() runtime error: %s", tostring(ok_apply))
            reaper.MB("RGWH Core M.core() runtime error:\n" .. tostring(ok_apply), "AudioSweet — Core error", 0)
            failed = true
          else
            if not ok_apply then
              if debug_enabled() then
                log_step("ERROR", "M.core() returned false; err=%s", tostring(err))
              end
              reaper.MB("RGWH Core M.core() error:\n" .. tostring(err or "(nil)"), "AudioSweet — Core error", 0)
              failed = true
            end
          end
        end

        -- Restore flags
        proj_set("RGWH","GLUE_TAKE_FX",      snap.GLUE_TAKE_FX)
        proj_set("RGWH","GLUE_TRACK_FX",     snap.GLUE_TRACK_FX)
        proj_set("RGWH","GLUE_APPLY_MODE",   snap.GLUE_APPLY_MODE)
        proj_set("RGWH","GLUE_SINGLE_ITEMS", snap.GLUE_SINGLE_ITEMS)
        proj_set("RGWH","RENDER_TC_EMBED",   snap.RENDER_TC_EMBED)

        -- Pick output, rename, move back
        if not failed then
          local postItem = reaper.GetSelectedMediaItem(0, 0)
          if not postItem then
            reaper.MB("Core finished, but no item is selected.", "AudioSweet", 0)
            failed = true
          else
            append_fx_to_take_name(postItem, naming_token)
            local origTR = u.track
            reaper.MoveMediaItemToTrack(postItem, origTR)
            -- Fix TC after RGWH glue/apply; use item start minus handle (D_STARTOFFS)
            embed_current_tc_from_item_start(postItem)
            if is_apply_after_copy then
              local copied = copy_fx_to_non_active_takes(postItem, FXmediaTrack, fxIndex, orig_track_nchan_core)
              log_step("COPY", "apply_after_copy: copied FX to %d take(s)", copied)
            end
            table.insert(outputs, postItem)
          end

          if debug_enabled() then
            dbg_dump_selection("CORE post-apply selection")
            if postItem then
              dbg_item_brief(postItem, "CORE picked postItem")
            end
          end
        end

        -- Move remaining items (if any) in unit back to original track; restore FX enable state
        move_items_to_track(u.items, u.track)

        -- ★ NEW: restore FX enable state (back to original bypass/enable)
        restore_fx_enables(FXmediaTrack, fx_enable_snap_core)

        -- ★ NEW: Restore source track channel count (protect from REAPER auto-adjust during move back)
        reaper.SetMediaTrackInfo_Value(u.track, "I_NCHAN", orig_track_nchan_core)
        if debug_enabled() then
          local tr_num = reaper.GetMediaTrackInfo_Value(u.track, "IP_TRACKNUMBER")
          log_step("CORE", "restored SOURCE track #%d I_NCHAN=%d (post-move)", tr_num, orig_track_nchan_core)
        end
    end
    ::continue_unit::
  end

  log_step("END", "outputs=%d", #outputs)

  -- Restore pre-execution selection
  restore_selection(sel_snapshot)
  if debug_enabled() then dbg_dump_selection("RESTORE selection") end
  restore_track_nchan()

  reaper.PreventUIRefresh(-1)
  if not external_undo then
    reaper.Undo_EndBlock("AudioSweet multi-item glue", 0)
  end
end

reaper.PreventUIRefresh(1)
local function as_err_handler(err)
  return tostring(err)
end
local ok, err = xpcall(main, as_err_handler)
if not ok then
  local msg = "[AS][ERROR] " .. tostring(err)
  reaper.ShowConsoleMsg(msg .. "\n")
  reaper.MB("AudioSweet Core error:\n" .. tostring(err), "AudioSweet — Core error", 0)
end
reaper.PreventUIRefresh(-1)

