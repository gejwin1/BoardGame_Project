-- =========================================================
-- WLB GLOBAL v1.1.0 (FULL REPLACE)
-- GOALS:
--  - Tags only (no GUIDs)
--  - NEW GAME: resetNewGame() on all AP controllers
--  - END TURN: apply AP reset+inactive for the player who ended turn
--  - Blocked inactive memory per color (set/get)
--  - Diagnostics: dump AP controller states
--  - Global UI callbacks for Vocation Selection system
-- =========================================================

local DEBUG = true

-- =========================
-- [SECTION 1] TAGS / CONFIG
-- =========================
-- === CONFIG ===
-- IMPORTANT: Set VOC_CTRL_GUID to the actual GUID of your VocationsController object
-- To find it: In TTS, right-click VocationsController → Scripting → copy the GUID
VOC_CTRL_GUID = "37f7a7"   -- VocationsController GUID
EVENTS_CTRL_GUID = "1339d3" -- EventsController GUID (auction backend)
HEAT_POLICE_GUID = "ffe844" -- Police Car pawn (Crime / Heat track)
UI_DIAG_ENABLED = true      -- Set to false to disable UI diagnostics logging

local TAG_COLOR_PREFIX = "WLB_COLOR_"   -- e.g. WLB_COLOR_Red
local TAG_AP_CTRL      = "WLB_AP_CTRL"  -- add this tag to all 4 AP controllers
local TAG_VOCATIONS_CTRL = "WLB_VOCATIONS_CTRL"  -- VocationsController tag
local TAG_VOCATION_TILE = "WLB_VOCATION_TILE"    -- vocation tile on player board

-- Vocation IDs (must match VocationsController ALL_VOCATIONS for tile click → explanation)
local VOCATION_IDS = { "PUBLIC_SERVANT", "NGO_WORKER", "ENTREPRENEUR", "GANGSTER", "CELEBRITY", "SOCIAL_WORKER" }

local COLORS = { "Red", "Blue", "Yellow", "Green" }

-- persisted memory
local G = {
  blocked = { Red=0, Blue=0, Yellow=0, Green=0 }
}

-- =========================
-- [SECTION 2] HELPERS
-- =========================
local function log(s)  if DEBUG then print("[WLB] " .. tostring(s)) end end
local function warn(s) print("[WLB][WARN] " .. tostring(s)) end

local function hasTag(o, t) return o and o.hasTag and o.hasTag(t) end
local function colorTag(colorName) return TAG_COLOR_PREFIX .. tostring(colorName) end

local function findOneWithTags(tagA, tagB)
  for _, o in ipairs(getAllObjects()) do
    if hasTag(o, tagA) and (not tagB or hasTag(o, tagB)) then
      return o
    end
  end
  return nil
end

local function getAPController(colorName)
  local ctag = colorTag(colorName)
  local ctrl = findOneWithTags(TAG_AP_CTRL, ctag)
  if ctrl then return ctrl end

  -- fallback heuristic (defensive)
  for _, o in ipairs(getAllObjects()) do
    if hasTag(o, ctag) then
      local lua = o.getLuaScript and o.getLuaScript() or ""
      if type(lua) == "string" and string.find(lua, "function%s+getState%s*%(") then
        return o
      end
    end
  end
  return nil
end

local function clampInt(x)
  x = tonumber(x) or 0
  x = math.floor(x + 0.00001)
  if x < 0 then x = 0 end
  return x
end

local function normColor(c)
  c = tostring(c or "")
  if c == "" then return "" end
  -- normalize first letter upper
  c = c:gsub("^%l", string.upper)
  return c
end

local function save()
  script_state = JSON.encode(G)
end

local function load()
  if script_state and script_state ~= "" then
    local ok, t = pcall(JSON.decode, script_state)
    if ok and type(t) == "table" then
      G = t
    end
  end
  G.blocked = G.blocked or { Red=0, Blue=0, Yellow=0, Green=0 }
  for _,c in ipairs(COLORS) do
    G.blocked[c] = clampInt(G.blocked[c] or 0)
  end
end

-- =========================
-- [SECTION 3] PUBLIC API: BLOCKED MEMORY
-- =========================
function WLB_SET_BLOCKED_INACTIVE(params)
  params = params or {}
  local c = normColor(params.color or params.playerColor or params.c)
  if c == "" then
    warn("WLB_SET_BLOCKED_INACTIVE: missing color")
    return { ok=false, reason="no_color" }
  end
  local v = clampInt(params.count or params.blocked or params.inactive or 0)
  G.blocked[c] = v
  save()
  log("Blocked inactive set: "..c.."="..tostring(v))
  return { ok=true, color=c, count=v }
end

function WLB_GET_BLOCKED_INACTIVE(params)
  params = params or {}
  local c = normColor(params.color or params.playerColor or params.c)
  if c == "" then return 0 end
  return clampInt(G.blocked[c] or 0)
end

-- =========================
-- [SECTION 4] CORE: NEW GAME / END TURN
-- =========================
local TAG_PLAYER_STATUS_CTRL = "WLB_PLAYER_STATUS_CTRL"

local TAG_HEAT_POLICE = "WLB_POLICE"  -- Police Car pawn (Crime / Heat track)

function WLB_NEW_GAME()
  log("NEW GAME: resetting AP controllers + clearing blocked memory...")

  -- reset blocked memory
  for _,c in ipairs(COLORS) do G.blocked[c] = 0 end
  save()

  -- reset Heat (Crime & Investigation) so police pawn returns to 0
  -- Use GUID so we always target the scripted Police Car; delay so onLoad has run
  local heatPawn = getObjectFromGUID(HEAT_POLICE_GUID)
  if not heatPawn then heatPawn = findOneWithTags(TAG_HEAT_POLICE, nil) end
  if heatPawn and heatPawn.call then
    Wait.time(function()
      local ok, err = pcall(function() heatPawn.call("SetHeat", 0) end)
      if ok then
        log(" - Heat reset to 0 (Police Car)")
      else
        warn("Heat reset failed: " .. tostring(err))
      end
    end, 0.5)
  end

  -- reset child-blocked AP (so no leftover kids from previous game block AP at start)
  local psc = findOneWithTags(TAG_PLAYER_STATUS_CTRL, nil)
  if psc and psc.call then
    pcall(function() psc.call("resetNewGame") end)
    log(" - PlayerStatusController resetNewGame() called (child-blocked AP cleared)")
  end

  local okAny = false
  for _, c in ipairs(COLORS) do
    local ctrl = getAPController(c)
    if ctrl then
      okAny = true
      pcall(function() ctrl.call("resetNewGame") end)
      log(" - AP resetNewGame() called for " .. c)
    else
      warn("No AP controller found for color " .. tostring(c) .. " (missing tags?)")
    end
  end

  if not okAny then
    warn("No AP controllers resolved at all. Add tags: WLB_AP_CTRL + WLB_COLOR_* on controller objects.")
  end

  return { ok = okAny }
end

-- END TURN: apply reset+inactive for the player who JUST ENDED turn
-- expects blocked already computed and stored via WLB_SET_BLOCKED_INACTIVE
function WLB_END_TURN(params)
  params = params or {}
  local c = normColor(params.color or params.playerColor or params.c)
  if c == "" then
    warn("WLB_END_TURN called without color")
    return { ok=false, reason="no_color" }
  end

  local ctrl = getAPController(c)
  if not ctrl then
    warn("No AP controller found for " .. c .. " (check tags)")
    return { ok=false, reason="no_ap_controller" }
  end

  local blocked = clampInt(G.blocked[c] or 0)
  -- allow explicit override (admin)
  if params.blocked ~= nil or params.inactive ~= nil then
    blocked = clampInt(params.blocked or params.inactive)
  end

  log("END TURN: color="..c.." blocked="..tostring(blocked))

  local r = nil
  pcall(function()
    r = ctrl.call("WLB_AP_START_TURN", { blocked = blocked })
  end)

  return { ok=true, color=c, blocked=blocked, apResult=r }
end

-- Optional legacy: START TURN (kept for admin; NOT used by new Turn Controller)
function WLB_START_TURN(params)
  return WLB_END_TURN(params)
end

-- =========================
-- [SECTION 5] DIAGNOSTICS
-- =========================
function UI_DumpToNotes()
  local voc = GetVocCtrl()
  local state = nil
  if voc then
    local ok, result = pcall(function()
      return voc.call("VOC_DebugState")
    end)
    if ok then
      state = result
    else
      UILog("ERR VOC_DebugState call failed: "..tostring(result))
    end
  end

  local L = {}
  table.insert(L, "=== UI/VOC DIAG DUMP ===")
  table.insert(L, "Time: "..os.date("%Y-%m-%d %H:%M:%S"))
  table.insert(L, "VOC_CTRL_GUID (configured): "..tostring(VOC_CTRL_GUID))
  table.insert(L, "")

  table.insert(L, "[VOC STATE]")
  if not state then
    table.insert(L, "✖ VOC_DebugState returned nil")
  else
    for k,v in pairs(state) do
      table.insert(L, tostring(k)..": "..tostring(v))
    end
  end
  table.insert(L, "")

  table.insert(L, "[LAST UI EVENTS]")
  for i=1, math.min(#UI_DIAG.events, 25) do
    table.insert(L, UI_DIAG.events[i])
  end
  table.insert(L, "")

  table.insert(L, "[LAST UI OPS]")
  for i=1, math.min(#UI_DIAG.uiops, 25) do
    table.insert(L, UI_DIAG.uiops[i])
  end

  Notes.setNotes(table.concat(L, "\n"))
  print("[UI_DIAG] Dumped to Notes")
  UILog("UI_DumpToNotes executed")
end

function WLB_AP_DUMP(params)
  params = params or {}
  local c = params.color or params.playerColor
  if c then
    c = normColor(c)
    local ctrl = getAPController(c)
    if not ctrl then
      warn("DUMP: no controller for " .. tostring(c))
      return { ok=false, reason="no_ctrl" }
    end
    local st = ctrl.call("getState")
    print("[WLB][AP_STATE]["..tostring(c).."] " .. JSON.encode(st))
    return st
  end

  local out = {}
  for _, col in ipairs(COLORS) do
    local ctrl = getAPController(col)
    if ctrl then
      local st = ctrl.call("getState")
      out[col] = st
      print("[WLB][AP_STATE]["..tostring(col).."] " .. JSON.encode(st))
    else
      warn("DUMP: no controller for " .. tostring(col))
    end
  end
  return out
end

-- =========================
-- [SECTION 5B] UI DIAGNOSTICS: RING BUFFER LOGGING
-- =========================
-- === UI DIAG RING BUFFER ===
local UI_DIAG = {
  max = 80,
  events = {},
  uiops = {},
  maxOps = 80,
}

local function _ts() return os.date("%H:%M:%S") end

local function _push(buf, max, line)
  table.insert(buf, 1, line)
  while #buf > max do table.remove(buf) end
end

local function UILog(line)
  if not UI_DIAG_ENABLED then return end
  _push(UI_DIAG.events, UI_DIAG.max, "[".._ts().."] "..line)
  if DEBUG then print("[UI_DIAG] "..line) end
end

local function UIOp(line)
  if not UI_DIAG_ENABLED then return end
  _push(UI_DIAG.uiops, UI_DIAG.maxOps, "[".._ts().."] "..line)
end

local function UISetAttr(id, attr, val)
  UIOp("UI.setAttribute id="..tostring(id).." "..tostring(attr).."="..tostring(val))
  UI.setAttribute(id, attr, tostring(val))
end

local function UISetActive(id, active)
  UIOp("UI.setAttribute id="..tostring(id).." active="..tostring(active))
  UI.setAttribute(id, "active", active and "true" or "false")
end

-- =========================
-- [SECTION 6] GLOBAL UI CALLBACKS FOR VOCATION SELECTION
-- =========================
-- These functions route Global UI callbacks to VocationsController
-- Global UI callbacks (from VocationsUI_Global.xml) are handled here
-- and forwarded to the VocationsController object

-- Helper function to find VocationsController (by GUID - preferred)
local function GetVocCtrl()
  if not VOC_CTRL_GUID or VOC_CTRL_GUID == "" then
    warn("[VOC][ERR] VOC_CTRL_GUID is not set!")
    -- Fallback to tag-based lookup
    local allObjects = getAllObjects()
    for _, obj in ipairs(allObjects) do
      if obj and obj.hasTag and obj.hasTag(TAG_VOCATIONS_CTRL) then
        if obj and obj.call then
          warn("[VOC][FALLBACK] Found VocationsController by tag. Set VOC_CTRL_GUID!")
          return obj
        end
      end
    end
    return nil
  end
  
  local o = getObjectFromGUID(VOC_CTRL_GUID)
  if not o then
    print("[VOC][ERR] VocationsController not found by GUID="..tostring(VOC_CTRL_GUID))
    -- Fallback to tag-based lookup
    local allObjects = getAllObjects()
    for _, obj in ipairs(allObjects) do
      if obj and obj.hasTag and obj.hasTag(TAG_VOCATIONS_CTRL) then
        warn("[VOC][FALLBACK] Found VocationsController by tag, but GUID lookup failed. Update VOC_CTRL_GUID!")
        if obj and obj.call then
          return obj
        end
      end
    end
    return nil
  end
  -- Verify the object has a call method before returning
  if o and o.call then
    return o
  else
    warn("[VOC][ERR] VocationsController found but missing call method! Object type: "..type(o))
    return nil
  end
end

-- Legacy function name (for backward compatibility)
local function findVocationsController()
  return GetVocCtrl()
end

-- EventsController (auction backend)
local function GetEvtCtrl()
  if not EVENTS_CTRL_GUID or EVENTS_CTRL_GUID == "" then return nil end
  local o = getObjectFromGUID(EVENTS_CTRL_GUID)
  return (o and o.call) and o or nil
end

-- =========================
-- [SECTION 6b] AUCTION UI (board panel – Bid/Pass visible to all)
-- =========================
local AUCTION_OVERLAY_ID = "auctionOverlay"

function UI_AuctionShow(snapshot)
  if not snapshot or snapshot.state ~= "BIDDING" then return end
  UI.setAttribute(AUCTION_OVERLAY_ID, "active", "true")
  UI_AuctionUpdate(snapshot)
end

function UI_AuctionUpdate(snapshot)
  if not snapshot then return end
  UI.setAttribute("auctionPrice", "text", "Current price: " .. tostring(snapshot.currentPrice or 1500) .. " WIN")
  UI.setAttribute("auctionBidder", "text", "Current bidder: " .. tostring(snapshot.currentBidderColor or "—"))
  UI.setAttribute("auctionLeader", "text", "Leader: " .. tostring(snapshot.leaderColor or "—"))
  local sec = snapshot.timerSeconds
  if type(sec) == "number" and sec >= 0 then
    UI.setAttribute("auctionTimer", "text", "Time left: " .. tostring(sec) .. " s")
  else
    UI.setAttribute("auctionTimer", "text", "Time limit: " .. tostring(snapshot.timerMaxSeconds or 20) .. " seconds")
  end
  if snapshot.state == "BIDDING" then
    UI.setAttribute(AUCTION_OVERLAY_ID, "active", "true")
  end
end

function UI_AuctionHide()
  UI.setAttribute(AUCTION_OVERLAY_ID, "active", "false")
end

function UI_AuctionBid(player, value, id)
  local pc = player and player.color or "White"
  if pc == "White" then return end
  local evt = GetEvtCtrl()
  if not evt then log("UI_AuctionBid: EventsController not found") return end
  pcall(function() evt.call("Auction_OnBid", { color = pc }) end)
end

function UI_AuctionPass(player, value, id)
  local pc = player and player.color or "White"
  if pc == "White" then return end
  local evt = GetEvtCtrl()
  if not evt then log("UI_AuctionPass: EventsController not found") return end
  pcall(function() evt.call("Auction_OnPass", { color = pc }) end)
end

-- UI Callback: Vocation button clicked (from selection screen)
-- This is called by Global UI when a vocation button is clicked
function UI_SelectVocation(player, value, id)
  local pc = player and player.color or "White"
  UILog("CLICK UI_SelectVocation pc="..tostring(pc).." id="..tostring(id).." value="..tostring(value))
  
  local voc = GetVocCtrl()
  if not voc then
    UILog("ERR no VocCtrl by GUID="..tostring(VOC_CTRL_GUID))
    warn("UI_SelectVocation: VocationsController not found! (GUID: " .. tostring(VOC_CTRL_GUID) .. ")")
    return
  end
  
  UILog("ROUTE -> VocCtrl GUID="..voc.getGUID())
  
  local ok, reason = pcall(function()
    return voc.call("VOC_UI_SelectVocation", {playerColor=pc, buttonId=id, value=value})
  end)
  
  if not ok then
    UILog("RESULT ok=false reason="..tostring(reason))
    warn("UI_SelectVocation: Error calling VocationsController: " .. tostring(reason))
  else
    UILog("RESULT ok="..tostring(ok).." reason="..tostring(reason))
    log("UI_SelectVocation: Successfully routed to VocationsController")
  end
end

-- UI Callback: Confirm vocation selection
function UI_ConfirmVocation(player, value, id)
  local pc = player and player.color or "White"
  UILog("CLICK UI_ConfirmVocation pc="..tostring(pc).." id="..tostring(id))
  
  local voc = GetVocCtrl()
  if not voc then
    UILog("ERR no VocCtrl by GUID="..tostring(VOC_CTRL_GUID))
    warn("UI_ConfirmVocation: VocationsController not found!")
    return
  end
  
  UILog("ROUTE -> VocCtrl GUID="..voc.getGUID())
  
  local ok, reason = pcall(function()
    return voc.call("VOC_UI_ConfirmVocation", {playerColor=pc, value=value, id=id})
  end)
  
  UILog("RESULT ok="..tostring(ok).." reason="..tostring(reason))
end

-- UI Callback: Back to selection screen
function UI_BackToSelection(player, value, id)
  local pc = player and player.color or "White"
  UILog("CLICK UI_BackToSelection pc="..tostring(pc))
  
  local voc = GetVocCtrl()
  if not voc then
    UILog("ERR no VocCtrl by GUID="..tostring(VOC_CTRL_GUID))
    warn("UI_BackToSelection: VocationsController not found!")
    return
  end
  
  UILog("ROUTE -> VocCtrl GUID="..voc.getGUID())
  
  local ok, reason = pcall(function()
    return voc.call("VOC_UI_BackToSelection", {playerColor=pc, value=value, id=id})
  end)
  
  UILog("RESULT ok="..tostring(ok).." reason="..tostring(reason))
end

-- UI Callback: Close vocation explanation (Exit in "Show explanation" – hide UI, back to playing)
function UI_CloseVocationExplanation(player, value, id)
  local voc = GetVocCtrl()
  if not voc then return end
  pcall(function()
    return voc.call("VOC_UI_CloseVocationExplanation", {playerColor=(player and player.color or "White"), value=value, id=id})
  end)
end

-- UI Callback: Science Points allocation (+K/-K/+S/-S on selection card or science panel)
function UI_AllocScience(player, value, id)
  local vocCtrl = findVocationsController()
  if vocCtrl and vocCtrl.call then
    pcall(function()
      vocCtrl.call("UI_AllocScience", {color=(player and player.color or "White"), value=value, id=id})
    end)
  else
    warn("UI_AllocScience: VocationsController not found!")
  end
end

-- UI Callback: Apply allocated K/S to player board (selection card Apply button)
function UI_ApplyAllocScience(player, value, id)
  local vocCtrl = findVocationsController()
  if vocCtrl and vocCtrl.call then
    pcall(function()
      vocCtrl.call("UI_ApplyAllocScience", {color=(player and player.color or "White"), value=value, id=id})
    end)
  else
    warn("UI_ApplyAllocScience: VocationsController not found!")
  end
end

-- UI Callback: Continue to vocation selection (for future use)
function UI_ContinueToVocation(player, value, id)
  local vocCtrl = findVocationsController()
  if vocCtrl and vocCtrl.call then
    pcall(function()
      vocCtrl.call("UI_ContinueToVocation", {color=(player and player.color or "White"), value=value, id=id})
    end)
  else
    warn("UI_ContinueToVocation: VocationsController not found!")
  end
end

-- =========================
-- [SECTION 6C] INTERACTION UI CALLBACKS (JOIN / IGNORE)
-- =========================

local function routeInteractionCallback(fnName, player)
  local pc = player and player.color or "White"
  UILog("CLICK "..tostring(fnName).." pc="..tostring(pc))
  local voc = GetVocCtrl()
  if not voc then
    UILog("ERR "..tostring(fnName).." no VocCtrl by GUID="..tostring(VOC_CTRL_GUID))
    warn(tostring(fnName)..": VocationsController not found!")
    return
  end
  UILog("ROUTE -> VocCtrl GUID="..voc.getGUID())
  local ok, err = pcall(function()
    return voc.call(fnName, { playerColor = pc })
  end)
  if not ok then
    UILog("ERR "..tostring(fnName).." "..tostring(err))
    warn(tostring(fnName)..": Error calling VocationsController: "..tostring(err))
  end
end

function UI_Interaction_YellowJoin(player, value, id)
  routeInteractionCallback("UI_Interaction_YellowJoin", player)
end

function UI_Interaction_YellowIgnore(player, value, id)
  routeInteractionCallback("UI_Interaction_YellowIgnore", player)
end

function UI_Interaction_BlueJoin(player, value, id)
  routeInteractionCallback("UI_Interaction_BlueJoin", player)
end

function UI_Interaction_BlueIgnore(player, value, id)
  routeInteractionCallback("UI_Interaction_BlueIgnore", player)
end

function UI_Interaction_RedJoin(player, value, id)
  routeInteractionCallback("UI_Interaction_RedJoin", player)
end

function UI_Interaction_RedIgnore(player, value, id)
  routeInteractionCallback("UI_Interaction_RedIgnore", player)
end

function UI_Interaction_GreenJoin(player, value, id)
  routeInteractionCallback("UI_Interaction_GreenJoin", player)
end

function UI_Interaction_GreenIgnore(player, value, id)
  routeInteractionCallback("UI_Interaction_GreenIgnore", player)
end

-- =========================
-- [SECTION 6E] TARGET SELECTION CALLBACKS
-- =========================

function UI_SelectTarget_Yellow(player, value, id)
  local voc = GetVocCtrl()
  if not voc or not voc.call then return end
  local ok, err = pcall(function() voc.call("handleTargetSelection", "Yellow") end)
  if not ok then warn("Error calling handleTargetSelection for Yellow: "..tostring(err)) end
end

function UI_SelectTarget_Blue(player, value, id)
  local voc = GetVocCtrl()
  if not voc or not voc.call then return end
  local ok, err = pcall(function() voc.call("handleTargetSelection", "Blue") end)
  if not ok then warn("Error calling handleTargetSelection for Blue: "..tostring(err)) end
end

function UI_SelectTarget_Red(player, value, id)
  local voc = GetVocCtrl()
  if not voc or not voc.call then return end
  local ok, err = pcall(function() voc.call("handleTargetSelection", "Red") end)
  if not ok then warn("Error calling handleTargetSelection for Red: "..tostring(err)) end
end

function UI_SelectTarget_Green(player, value, id)
  local voc = GetVocCtrl()
  if not voc or not voc.call then return end
  local ok, err = pcall(function() voc.call("handleTargetSelection", "Green") end)
  if not ok then warn("Error calling handleTargetSelection for Green: "..tostring(err)) end
end

function UI_CancelTargetSelection(player, value, id)
  local voc = GetVocCtrl()
  if not voc or not voc.call then return end
  -- Pass true to indicate this IS a cancel - should refund AP
  local ok, err = pcall(function() voc.call("hideTargetSelection", true) end)
  if not ok then warn("Error calling hideTargetSelection: "..tostring(err)) end
end

-- =========================
-- [SECTION 6D] VOCATION ACTION BUTTONS (5 buttons for vocation actions)
-- =========================

function UI_VocationAction1(player, value, id)
  UILog("CLICK UI_VocationAction1 - START")
  
  -- Defensive: check player
  local pc = "White"
  if player and type(player) == "table" and player.color then
    pc = player.color
  end
  UILog("CLICK UI_VocationAction1 pc="..tostring(pc))
  
  local voc = GetVocCtrl()
  if not voc then
    warn("UI_VocationAction1: VocationsController not found!")
    broadcastToAll("⚠️ VocationsController not found!", {1,0.6,0.2})
    return
  end
  if not voc.call then
    warn("UI_VocationAction1: VocationsController missing call method!")
    broadcastToAll("⚠️ VocationsController missing call method!", {1,0.6,0.2})
    return
  end
  
  -- Capture voc explicitly in closure to avoid scoping issues
  local vocObj = voc
  local ok, err = pcall(function()
    if not vocObj then
      warn("UI_VocationAction1: VocationsController became nil during call!")
      return
    end
    if not vocObj.call then
      warn("UI_VocationAction1: VocationsController lost call method during call!")
      return
    end
    UILog("UI_VocationAction1: About to call UI_VocationAction with pc="..tostring(pc))
    local result = vocObj.call("UI_VocationAction", {playerColor=pc, buttonIndex=1})
    UILog("UI_VocationAction1: Call completed, result="..tostring(result))
  end)
  if not ok then
    warn("UI_VocationAction1 error: "..tostring(err))
    broadcastToAll("⚠️ Action button error: "..tostring(err), {1,0.6,0.2})
  else
    UILog("UI_VocationAction1: Success")
  end
end

function UI_VocationAction2(player, value, id)
  local pc = player and player.color or "White"
  UILog("CLICK UI_VocationAction2 pc="..tostring(pc))
  local voc = GetVocCtrl()
  if not voc then
    warn("UI_VocationAction2: VocationsController not found!")
    return
  end
  if not voc.call then
    warn("UI_VocationAction2: VocationsController missing call method!")
    return
  end
  local vocObj = voc
  local ok, err = pcall(function()
    if not vocObj then
      warn("UI_VocationAction2: VocationsController became nil during call!")
      return
    end
    if not vocObj.call then
      warn("UI_VocationAction2: VocationsController lost call method during call!")
      return
    end
    vocObj.call("UI_VocationAction", {playerColor=pc, buttonIndex=2})
  end)
  if not ok then
    warn("UI_VocationAction2 error: "..tostring(err))
  end
end

function UI_VocationAction3(player, value, id)
  local pc = player and player.color or "White"
  UILog("CLICK UI_VocationAction3 pc="..tostring(pc))
  local voc = GetVocCtrl()
  if not voc then
    warn("UI_VocationAction3: VocationsController not found!")
    return
  end
  if not voc.call then
    warn("UI_VocationAction3: VocationsController missing call method!")
    return
  end
  local vocObj = voc
  local ok, err = pcall(function()
    if not vocObj then
      warn("UI_VocationAction3: VocationsController became nil during call!")
      return
    end
    if not vocObj.call then
      warn("UI_VocationAction3: VocationsController lost call method during call!")
      return
    end
    vocObj.call("UI_VocationAction", {playerColor=pc, buttonIndex=3})
  end)
  if not ok then
    warn("UI_VocationAction3 error: "..tostring(err))
  end
end

function UI_VocationAction4(player, value, id)
  local pc = player and player.color or "White"
  UILog("CLICK UI_VocationAction4 pc="..tostring(pc))
  local voc = GetVocCtrl()
  if not voc then
    warn("UI_VocationAction4: VocationsController not found!")
    return
  end
  if not voc.call then
    warn("UI_VocationAction4: VocationsController missing call method!")
    return
  end
  local vocObj = voc
  local ok, err = pcall(function()
    if not vocObj then
      warn("UI_VocationAction4: VocationsController became nil during call!")
      return
    end
    if not vocObj.call then
      warn("UI_VocationAction4: VocationsController lost call method during call!")
      return
    end
    vocObj.call("UI_VocationAction", {playerColor=pc, buttonIndex=4})
  end)
  if not ok then
    warn("UI_VocationAction4 error: "..tostring(err))
  end
end

function UI_VocationAction5(player, value, id)
  local pc = player and player.color or "White"
  UILog("CLICK UI_VocationAction5 pc="..tostring(pc))
  local voc = GetVocCtrl()
  if not voc then
    warn("UI_VocationAction5: VocationsController not found!")
    return
  end
  if not voc.call then
    warn("UI_VocationAction5: VocationsController missing call method!")
    return
  end
  local vocObj = voc
  local ok, err = pcall(function()
    if not vocObj then
      warn("UI_VocationAction5: VocationsController became nil during call!")
      return
    end
    if not vocObj.call then
      warn("UI_VocationAction5: VocationsController lost call method during call!")
      return
    end
    vocObj.call("UI_VocationAction", {playerColor=pc, buttonIndex=5})
  end)
  if not ok then
    warn("UI_VocationAction5 error: "..tostring(err))
  end
end

-- UI Callback: Cancel selection (close UI) - KILL SWITCH
-- This is a direct kill switch that closes all UI panels immediately
-- Works even if VocationsController is not found (emergency fallback)
function UI_CancelSelection(player, value, id)
  local pc = player and player.color or "White"
  UILog("CLICK UI_CancelSelection pc="..tostring(pc))
  
  -- Direct kill switch - close all vocation UI panels immediately
  if UI then
    pcall(function()
      UISetActive("vocationSelectionPanel", false)
      UISetActive("vocationSummaryPanel", false)
      UISetActive("sciencePointsPanel", false)
      UISetActive("vocationOverlay", false)
      UILog("KILL SWITCH: All panels closed directly")
    end)
  end
  
  -- Also route to VocationsController for proper state cleanup
  local voc = GetVocCtrl()
  if voc then
    UILog("ROUTE -> VocCtrl GUID="..voc.getGUID())
    local ok, reason = pcall(function()
      return voc.call("VOC_UI_CancelSelection", {playerColor=pc, value=value, id=id})
    end)
    UILog("RESULT ok="..tostring(ok).." reason="..tostring(reason))
  else
    UILog("ERR no VocCtrl by GUID="..tostring(VOC_CTRL_GUID))
    warn("UI_CancelSelection: VocationsController not found, but UI closed via kill switch")
  end
end

-- =========================
-- [SECTION 6B] VOCATION TILE – EXPLANATION VIA LMB BUTTON ONLY
-- =========================
-- Explanation is shown only by the LMB button on the vocation tile (VocationsController). No RMB/Select handling here.
function onPlayerAction(player, action, targets)
  return true
end

-- =========================
-- [SECTION 7] CHAT COMMANDS
-- =========================
function onChat(message, player)
  local msg = tostring(message or "")
  msg = string.gsub(msg, "^%s+", "")
  msg = string.gsub(msg, "%s+$", "")

  if msg == "/wlbn" then
    WLB_NEW_GAME()
    return false
  end

  if msg == "/wlbd" then
    WLB_AP_DUMP()
    return false
  end

  if msg == "/uidump" or msg == "/uivocdump" then
    UI_DumpToNotes()
    return false
  end

  -- /wlbe <color> [blocked]  (end turn apply)
  if string.sub(msg, 1, 5) == "/wlbe" then
    local parts = {}
    for w in string.gmatch(msg, "%S+") do table.insert(parts, w) end
    local c = normColor(parts[2])
    local b = tonumber(parts[3])

    if c == "" then
      warn("Usage: /wlbe Red 2")
      return false
    end

    if b ~= nil then
      WLB_END_TURN({ color = c, blocked = b })
    else
      WLB_END_TURN({ color = c })
    end
    return false
  end

  return true
end

-- =========================
-- [SECTION 8] LIFECYCLE
-- =========================
function onSave()
  save()
  return script_state
end

function onLoad()
  load()
  log("Global loaded. Resolving AP controllers...")
  for _, c in ipairs(COLORS) do
    local ctrl = getAPController(c)
    log(" - "..c.." AP ctrl = "..tostring(ctrl and ctrl.getGUID() or "nil").." | blocked="..tostring(G.blocked[c] or 0))
  end
  
  -- Check for VocationsController
  local vocCtrl = findVocationsController()
  if vocCtrl then
    log(" - VocationsController found: " .. tostring(vocCtrl.getGUID() or "nil"))
  else
    warn("VocationsController not found (missing WLB_VOCATIONS_CTRL tag?)")
  end

  -- Register this object with EventsController so auction UI (Bid/Pass panel) is found automatically
  local evtCtrl = GetEvtCtrl()
  if evtCtrl and self and self.getGUID then
    pcall(function() evtCtrl.call("Auction_RegisterGlobal", { guid = self.getGUID() }) end)
    log(" - EventsController: registered Global for auction UI")
  end
  
  log("Commands: /wlbn (new game), /wlbe Red 2 (end turn apply), /wlbd (dump)")
end
