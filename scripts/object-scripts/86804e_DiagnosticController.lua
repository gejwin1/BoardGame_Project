-- =========================================================
-- WLB_DIAGNOSTIC_CTRL v0.6.1
--  - Keeps v0.5.0 DIAG snapshot to Notes (as you use)
--  - Keeps Player Registry snapshot (moved from PlayerStatusCtrl)
--  - Keeps AP sanity, Deck sanity, Status sanity, Near-board scan
--  - ADDS:
--      [FULL TAG INVENTORY] (all tags across all objects)
--      [SCRIPT INVENTORY] (scripted vs non-scripted, optional list)
--      Chunked console printing to avoid truncation
--
-- IMPORTANT FIX:
--  Some userdata objects (e.g., Custom Tile) throw on obj.getLuaScriptState field access.
--  We use safeCallMethod() to call methods without crashing.
-- =========================================================

local VERSION = "0.6.1"

local COLORS = {"Yellow","Blue","Red","Green"}
local function TAG_COLOR(c) return "WLB_COLOR_"..c end

-- Core tags
local TAG_BOARD        = "WLB_BOARD"
local TAG_PLAYER_TOKEN = "WLB_PLAYER_TOKEN"
local TAG_DIAG         = "WLB_DIAGNOSTIC_CTRL"

-- Tokens near boards
local TAG_SAT_TOKEN      = "SAT_TOKEN"
local TAG_HEALTH_TOKEN   = "WLB_HEALTH_TOKEN"
local TAG_KNOW_TOKEN     = "WLB_KNOWLEDGE_TOKEN"
local TAG_SKILLS_TOKEN   = "WLB_SKILLS_TOKEN"

-- AP
local TAG_AP_CTRL        = "WLB_AP_CTRL"
local TAG_AP_TOKEN       = "WLB_AP_TOKEN"
local TAG_AP_PROBE       = "WLB_AP_PROBE"
local EXPECTED_AP_TOKENS = 12
local EXPECTED_AP_PROBES = 1

-- Decks
local TAG_DECK_YOUTH     = "WLB_DECK_YOUTH"
local TAG_DECK_ADULT     = "WLB_DECK_ADULT"
local EXPECTED_YOUTH_CNT = 39
local EXPECTED_ADULT_CNT = 81

-- Controllers expected
local TAG_TURN_CTRL      = "WLB_TURN_CTRL"
local TAG_YEAR_TOKEN     = "WLB_YEAR"

local CONTROLLERS_EXPECTED = {
  { label="Token System",          tag="WLB_TOKEN_SYSTEM" },
  { label="Market Controller",     tag="WLB_MARKET_CTRL" },
  { label="Event Engine",          tag="WLB_EVENT_ENGINE" },
  { label="Events Controller",     tag="WLB_EVT_CONTROLLER" },
  { label="Shop Engine",           tag="WLB_SHOP_ENGINE" },
  { label="Costs Calculator",      tag="WLB_COSTS_CALC" },
  { label="Turn Controller",       tag=TAG_TURN_CTRL },
  { label="Diagnostic Controller", tag=TAG_DIAG },
}

-- Status sanity
local DEPRECATED_STATUS_TAG = "WLB_STATUS_SEEK"
local REQUIRED_STATUS_TAG   = "WLB_STATUS_SICK"

-- Near-board scan config
local NEAR_SCAN_RADIUS = 6.0
local NEAR_SCAN_LIMIT  = 10

-- =========================================================
-- NEW: INVENTORY CONFIG
-- =========================================================
local TAG_SAMPLE_PER_TAG      = 5       -- how many sample objects per tag
local TAG_LINES_PER_CHUNK     = 50      -- console chunk printing
local OBJ_LINES_PER_CHUNK     = 50
local MAX_TAGS_PER_OBJECT     = 25      -- cap tag list per object line

local INCLUDE_OBJECT_CATALOG_TO_CONSOLE = true -- prints all objects to console
local INCLUDE_SCRIPTED_LIST_TO_CONSOLE  = true -- prints scripted objects to console

-- Notes length protection (Notes can get huge; we keep summary in Notes)
local NOTES_MAX_TAG_LINES     = 120     -- only first N tag lines into Notes
local NOTES_MAX_SCRIPTED_LINES= 80      -- only first N scripted lines into Notes

-- ---------------------------------------------------------
-- INTERNAL STATE (cached registry)
-- ---------------------------------------------------------
local LAST_REGISTRY = nil

-- =========================================================
-- SAFE METHOD CALLS (CRITICAL FIX)
-- =========================================================
local function safeCallMethod(obj, methodName, ...)
  if not obj or not methodName then return false, nil end

  -- Capture varargs before using in nested function
  local args = {...}
  
  local okGet, fn = pcall(function()
    return obj[methodName]
  end)
  if not okGet or type(fn) ~= "function" then
    return false, nil
  end

  local okCall, ret = pcall(function()
    return fn(obj, unpack(args))
  end)
  if not okCall then
    return false, nil
  end
  return true, ret
end

-- ---------------------------------------------------------
-- UTILS
-- ---------------------------------------------------------
local function hasTag(obj, tag)
  local ok, ret = pcall(function()
    return obj and obj.hasTag and obj.hasTag(tag)
  end)
  return ok and ret == true
end

local function safeName(o)
  local ok, n = safeCallMethod(o, "getName")
  if ok and n and n ~= "" then return n end
  return ""
end

local function safeGuid(o)
  local ok, g = safeCallMethod(o, "getGUID")
  if ok and g and g ~= "" then return g end
  return "??????"
end

local function safeGetTags(o, max)
  max = max or 9999
  local ok, tags = safeCallMethod(o, "getTags")
  if not ok or type(tags) ~= "table" then return {} end
  local out = {}
  for i=1, math.min(#tags, max) do
    out[#out+1] = tags[i]
  end
  return out
end

local function now()
  return os.date("%Y-%m-%d %H:%M:%S")
end

local function ensureSelfTag()
  if self and self.addTag then
    local okHas = pcall(function() return self.hasTag and self.hasTag(TAG_DIAG) end)
    if not okHas or (self.hasTag and (not self.hasTag(TAG_DIAG))) then
      pcall(function() self.addTag(TAG_DIAG) end)
    end
  end
end

local function findObjectsWithTag(tag)
  local out = {}
  for _,o in ipairs(getAllObjects()) do
    if hasTag(o, tag) then out[#out+1] = o end
  end
  return out
end

local function findOneWithTag(tag)
  local all = findObjectsWithTag(tag)
  if #all == 0 then return nil, 0 end
  return all[1], #all
end

local function findOneWithTagAndColor(tag, color)
  local found, count = nil, 0
  for _,o in ipairs(getAllObjects()) do
    if hasTag(o, tag) and hasTag(o, TAG_COLOR(color)) then
      count = count + 1
      if not found then found = o end
    end
  end
  return found, count
end

local function countPerColor(tag)
  local counts = {}
  for _,c in ipairs(COLORS) do counts[c] = 0 end
  local objs = findObjectsWithTag(tag)
  for _,o in ipairs(objs) do
    for _,c in ipairs(COLORS) do
      if hasTag(o, TAG_COLOR(c)) then counts[c] = counts[c] + 1 end
    end
  end
  return counts
end

local function cardCount(obj)
  if not obj then return 0 end
  if obj.type == "Deck" then
    local ok, q = safeCallMethod(obj, "getQuantity")
    if ok and type(q) == "number" then return q end
    return 0
  elseif obj.type == "Card" then
    return 1
  end
  return 0
end

local function computeTaggedSet(tag)
  local decks, cards, total = 0, 0, 0
  local objs = findObjectsWithTag(tag)
  for _,o in ipairs(objs) do
    if o.type == "Deck" then decks = decks + 1 end
    if o.type == "Card" then cards = cards + 1 end
    total = total + cardCount(o)
  end
  return { decks=decks, cards=cards, total=total, objs=#objs }
end

local function vecDist(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  local dz = a.z - b.z
  return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function isScripted(o)
  -- SAFE: do not touch o.getLuaScriptState field directly
  local ok1, script = safeCallMethod(o, "getLuaScript")
  if ok1 and type(script)=="string" and script ~= "" then return true end

  local ok2, state = safeCallMethod(o, "getLuaScriptState")
  if ok2 and type(state)=="string" and state ~= "" then return true end

  return false
end

local function isInterestingCandidate(o)
  if not o or o == self then return false end
  if o.type == "Card" or o.type == "Deck" then return false end

  if isScripted(o) then return true end

  local okB, btns = safeCallMethod(o, "getButtons")
  if okB and type(btns)=="table" and #btns > 0 then return true end

  local tags = safeGetTags(o, 40)
  for _,t in ipairs(tags) do
    if string.sub(t,1,4) == "WLB_" or t == "SAT_TOKEN" then return true end
  end
  return false
end

local function notesSet(lines)
  Notes.setNotes(table.concat(lines, "\n"))
end

local function joinTags(tags, limit)
  if type(tags)~="table" or #tags==0 then return "{}" end
  limit = limit or #tags
  local out = {}
  for i=1, math.min(#tags, limit) do out[#out+1] = tostring(tags[i]) end
  if #tags > limit then out[#out+1] = "...(+"..tostring(#tags-limit)..")" end
  return "{"..table.concat(out, ", ").."}"
end

local function sortKeys(t)
  local keys = {}
  for k,_ in pairs(t) do keys[#keys+1]=k end
  table.sort(keys, function(a,b) return tostring(a)<tostring(b) end)
  return keys
end

local function printChunked(lines, header, perChunk)
  perChunk = perChunk or 50
  local total = #lines
  if total == 0 then
    print("[WLB_DIAG] "..header.." (0)")
    return
  end

  local idx = 1
  local chunkId = 0

  local function step()
    chunkId = chunkId + 1
    print(string.format("[WLB_DIAG] %s (chunk %d) %d/%d", header, chunkId, idx, total))
    for i=1,perChunk do
      if idx > total then break end
      print(lines[idx])
      idx = idx + 1
    end
    if idx <= total then
      Wait.time(step, 0.2)
    end
  end

  step()
end

-- =========================================================
-- NEW: FULL TAG + SCRIPT INVENTORY
-- =========================================================
local function buildInventory()
  local inv = {
    tagCounts = {},         -- tag -> count
    tagSamples = {},        -- tag -> { "Name [GUID]", ... }
    scripted = {},          -- { line, ... }
    scriptedCount = 0,
    nonScriptedCount = 0,
    totalObjects = 0,
  }

  for _,o in ipairs(getAllObjects()) do
    if o then
      inv.totalObjects = inv.totalObjects + 1

      local scripted = isScripted(o)
      if scripted then 
        inv.scriptedCount = inv.scriptedCount + 1
      else 
        inv.nonScriptedCount = inv.nonScriptedCount + 1 
      end

      if scripted and INCLUDE_SCRIPTED_LIST_TO_CONSOLE then
        inv.scripted[#inv.scripted+1] =
          string.format("• %s [%s] type=%s tags=%s",
            safeName(o), safeGuid(o), tostring(o.type or o.tag or "?"), joinTags(safeGetTags(o, MAX_TAGS_PER_OBJECT), MAX_TAGS_PER_OBJECT))
      end

      local tags = safeGetTags(o, 9999)
      for _,t in ipairs(tags) do
        local tagName = tostring(t)
        if tagName ~= "" then
          inv.tagCounts[tagName] = (inv.tagCounts[tagName] or 0) + 1
          if not inv.tagSamples[tagName] then inv.tagSamples[tagName] = {} end
          local samples = inv.tagSamples[tagName]
          if #samples < TAG_SAMPLE_PER_TAG then
            samples[#samples+1] = string.format("%s [%s]", safeName(o), safeGuid(o))
          end
        end
      end
    end
  end

  return inv
end

-- =========================================================
-- PUBLIC API (for other controllers)
-- =========================================================
function D_FindOneByTag(tag)
  local objs = findObjectsWithTag(tag)
  if #objs == 0 then return nil, 0 end
  return objs[1], #objs
end

function D_FindBoards()
  local map = {}
  local boards = findObjectsWithTag(TAG_BOARD)
  for _,b in ipairs(boards) do
    for _,c in ipairs(COLORS) do
      if hasTag(b, TAG_COLOR(c)) then map[c] = b end
    end
  end
  return map
end

function D_ScanNearBoard(color, radius, limit)
  radius = radius or NEAR_SCAN_RADIUS
  limit  = limit  or NEAR_SCAN_LIMIT

  local boards = D_FindBoards()
  local board = boards[color]
  if not board then return {} end

  local bp = board.getPosition()
  local candidates = {}

  for _,o in ipairs(getAllObjects()) do
    if isInterestingCandidate(o) then
      local op = o.getPosition()
      local d = vecDist(
        {x=bp[1],y=bp[2],z=bp[3]},
        {x=op[1],y=op[2],z=op[3]}
      )
      if d <= radius then
        candidates[#candidates+1] = {obj=o, dist=d}
      end
    end
  end

  table.sort(candidates, function(a,b) return a.dist < b.dist end)

  local out = {}
  for i=1, math.min(#candidates, limit) do
    local o = candidates[i].obj
    out[#out+1] = {
      name = safeName(o),
      guid = safeGuid(o),
      dist = math.floor(candidates[i].dist*100)/100,
      tags = safeGetTags(o, 20),
      scripted = isScripted(o),
    }
  end
  return out
end

-- =========================================================
-- PLAYER REGISTRY (as in v0.5.0)
-- =========================================================
function D_BuildRegistry()
  local reg = { systems = {}, players = {} }

  reg.systems.diag_ctrl, reg.systems.diag_count         = findOneWithTag(TAG_DIAG)
  reg.systems.token_system, reg.systems.token_sys_count = findOneWithTag("WLB_TOKEN_SYSTEM")

  reg.systems.market_ctrl, reg.systems.market_count     = findOneWithTag("WLB_MARKET_CTRL")
  reg.systems.event_engine, reg.systems.eventeng_count  = findOneWithTag("WLB_EVENT_ENGINE")
  reg.systems.evt_ctrl, reg.systems.evtctrl_count       = findOneWithTag("WLB_EVT_CONTROLLER")
  reg.systems.shop_engine, reg.systems.shop_count       = findOneWithTag("WLB_SHOP_ENGINE")
  reg.systems.costs_calc, reg.systems.costs_count       = findOneWithTag("WLB_COSTS_CALC")
  reg.systems.turn_ctrl, reg.systems.turn_count         = findOneWithTag(TAG_TURN_CTRL)
  reg.systems.year_token, reg.systems.year_count        = findOneWithTag(TAG_YEAR_TOKEN)

  local ALL = getAllObjects()

  for _,c in ipairs(COLORS) do
    local p = {}

    p.board, p.board_count         = findOneWithTagAndColor(TAG_BOARD, c)
    p.player_token, p.pt_count     = findOneWithTagAndColor(TAG_PLAYER_TOKEN, c)

    p.sat_token, p.sat_count       = findOneWithTagAndColor(TAG_SAT_TOKEN, c)
    p.health_token, p.health_count = findOneWithTagAndColor(TAG_HEALTH_TOKEN, c)
    p.know_token, p.know_count     = findOneWithTagAndColor(TAG_KNOW_TOKEN, c)
    p.skills_token, p.skills_count = findOneWithTagAndColor(TAG_SKILLS_TOKEN, c)

    p.ap_ctrl, p.apctrl_count      = findOneWithTagAndColor(TAG_AP_CTRL, c)

    p.ap_token_count = 0
    p.ap_probe_count = 0
    p.ap_token_guids = {}
    p.ap_probe_guids = {}

    for _,o in ipairs(ALL) do
      if hasTag(o, TAG_COLOR(c)) then
        if hasTag(o, TAG_AP_PROBE) then
          p.ap_probe_count = p.ap_probe_count + 1
          p.ap_probe_guids[#p.ap_probe_guids+1] = safeGuid(o)
        end
        if hasTag(o, TAG_AP_TOKEN) and (not hasTag(o, TAG_AP_PROBE)) then
          p.ap_token_count = p.ap_token_count + 1
          p.ap_token_guids[#p.ap_token_guids+1] = safeGuid(o)
        end
      end
    end

    reg.players[c] = p
  end

  LAST_REGISTRY = reg
  return reg
end

function D_GetRegistry()
  if not LAST_REGISTRY then
    return D_BuildRegistry()
  end
  return LAST_REGISTRY
end

function D_DumpPlayerRegistryToNotes()
  local reg = D_BuildRegistry()

  local L = {}
  table.insert(L, "WLB PLAYER REGISTRY SNAPSHOT v"..VERSION)
  table.insert(L, "Timestamp: "..now())
  table.insert(L, "")

  table.insert(L, "[SYSTEMS]")
  local s = reg.systems or {}

  local function sysLine(label, obj, cnt)
    cnt = cnt or 0
    if not obj then
      table.insert(L, "✖ "..label.." missing (count="..tostring(cnt)..")")
    else
      local extra = (cnt > 1) and (" ⚠ duplicated x"..tostring(cnt)) or ""
      table.insert(L, "✔ "..label.." ["..safeGuid(obj).."] "..safeName(obj)..extra)
    end
  end

  sysLine("Diagnostic Ctrl (WLB_DIAGNOSTIC_CTRL)", s.diag_ctrl, s.diag_count or 0)
  sysLine("Token System (WLB_TOKEN_SYSTEM)", s.token_system, s.token_sys_count or 0)
  sysLine("Turn Ctrl (WLB_TURN_CTRL)", s.turn_ctrl, s.turn_count or 0)
  sysLine("Event Engine (WLB_EVENT_ENGINE)", s.event_engine, s.eventeng_count or 0)
  sysLine("Events Ctrl (WLB_EVT_CONTROLLER)", s.evt_ctrl, s.evtctrl_count or 0)
  sysLine("Market Ctrl (WLB_MARKET_CTRL)", s.market_ctrl, s.market_count or 0)
  sysLine("Shop Engine (WLB_SHOP_ENGINE)", s.shop_engine, s.shop_count or 0)
  sysLine("Costs Calc (WLB_COSTS_CALC)", s.costs_calc, s.costs_count or 0)
  sysLine("Year Token (WLB_YEAR)", s.year_token, s.year_count or 0)

  table.insert(L, "")
  table.insert(L, "[PLAYERS]")

  for _,c in ipairs(COLORS) do
    local p = reg.players[c] or {}
    table.insert(L, "• "..c..":")

    local function line(role, obj, cnt)
      cnt = cnt or 0
      if not obj then
        table.insert(L, "  ✖ "..role.." missing (count="..tostring(cnt)..")")
      else
        local extra = (cnt > 1) and (" ⚠ x"..tostring(cnt)) or ""
        table.insert(L, "  ✔ "..role.." ["..safeGuid(obj).."] "..safeName(obj)..extra)
      end
    end

    line("Board (WLB_BOARD)", p.board, p.board_count)
    line("PlayerToken (WLB_PLAYER_TOKEN)", p.player_token, p.pt_count)
    line("AP Ctrl (WLB_AP_CTRL)", p.ap_ctrl, p.apctrl_count)

    line("SAT token (SAT_TOKEN)", p.sat_token, p.sat_count)
    line("HEALTH token (WLB_HEALTH_TOKEN)", p.health_token, p.health_count)
    line("KNOW token (WLB_KNOWLEDGE_TOKEN)", p.know_token, p.know_count)
    line("SKILLS token (WLB_SKILLS_TOKEN)", p.skills_token, p.skills_count)

    local apOk = (p.ap_token_count == EXPECTED_AP_TOKENS)
    local prOk = (p.ap_probe_count == EXPECTED_AP_PROBES)

    local apMark = apOk and "✔" or "⚠"
    local prMark = prOk and "✔" or "⚠"

    table.insert(L, "  "..apMark.." AP tokens (WLB_AP_TOKEN, probe excluded): "..tostring(p.ap_token_count or 0).." (expected "..EXPECTED_AP_TOKENS..")")
    table.insert(L, "  "..prMark.." AP probes (WLB_AP_PROBE): "..tostring(p.ap_probe_count or 0).." (expected "..EXPECTED_AP_PROBES..")")

    if not apOk then
      table.insert(L, "    i AP token guids: {"..table.concat(p.ap_token_guids or {}, ",").."}")
    end
    if not prOk then
      table.insert(L, "    i AP probe guids: {"..table.concat(p.ap_probe_guids or {}, ",").."}")
    end
  end

  notesSet(L)
  return true
end

-- =========================================================
-- MAIN DIAGNOSTIC SNAPSHOT (Notes) + NEW inventories
-- =========================================================
function runDiagnostic(_, pc)
  ensureSelfTag()

  local lines = {}
  local status = "PASS"
  local problems = 0

  local function warnN(msg)
    if status ~= "FAIL" then status = "WARN" end
    problems = problems + 1
    table.insert(lines, "⚠ "..msg)
  end

  local function failN(msg)
    status = "FAIL"
    problems = problems + 1
    table.insert(lines, "✖ "..msg)
  end

  local function okN(msg)
    table.insert(lines, "✔ "..msg)
  end

  table.insert(lines, "WLB DIAGNOSTIC SNAPSHOT v"..VERSION)
  table.insert(lines, "Timestamp: "..now())
  table.insert(lines, "")
  table.insert(lines, "[SUMMARY]")
  table.insert(lines, "STATUS: PENDING")
  table.insert(lines, "Objects on table: "..#getAllObjects())
  table.insert(lines, "")

  -- PLAYER BOARDS
  table.insert(lines, "[PLAYER BOARDS]")
  local boards = findObjectsWithTag(TAG_BOARD)
  local foundColors = {}
  for _,b in ipairs(boards) do
    for _,c in ipairs(COLORS) do
      if hasTag(b, TAG_COLOR(c)) then
        foundColors[c] = (foundColors[c] or 0) + 1
      end
    end
  end
  for _,c in ipairs(COLORS) do
    if not foundColors[c] then
      failN("PlayerBoard "..c.." missing")
    elseif foundColors[c] > 1 then
      failN("PlayerBoard "..c.." duplicated x"..foundColors[c])
    else
      okN(c)
    end
  end
  table.insert(lines, "")

  -- PLAYER TOKENS
  table.insert(lines, "[PLAYER TOKENS]")
  local tokens = findObjectsWithTag(TAG_PLAYER_TOKEN)
  local tokenColors = {}
  for _,c in ipairs(COLORS) do tokenColors[c] = 0 end
  for _,t in ipairs(tokens) do
    for _,c in ipairs(COLORS) do
      if hasTag(t, TAG_COLOR(c)) then tokenColors[c] = tokenColors[c] + 1 end
    end
  end
  for _,c in ipairs(COLORS) do
    if tokenColors[c] == 1 then
      okN(c)
    else
      failN("PlayerToken "..c.." count="..tostring(tokenColors[c] or 0))
    end
  end
  table.insert(lines, "")

  -- CONTROLLERS
  table.insert(lines, "[CONTROLLERS]")
  for _,spec in ipairs(CONTROLLERS_EXPECTED) do
    local objs = findObjectsWithTag(spec.tag)
    local label = spec.label.." (tag="..spec.tag..")"
    if #objs == 0 then
      failN(label.." missing")
    elseif #objs > 1 then
      warnN(label.." duplicated x"..#objs)
    else
      okN(label)
    end
  end
  table.insert(lines, "")

  -- CORE TOKENS
  table.insert(lines, "[CORE TOKENS]")
  local sat = countPerColor(TAG_SAT_TOKEN)
  for _,c in ipairs(COLORS) do
    if sat[c] == 1 then okN("SAT "..c) else failN("SAT "..c.." count="..tostring(sat[c])) end
  end

  local health = countPerColor(TAG_HEALTH_TOKEN)
  local know   = countPerColor(TAG_KNOW_TOKEN)
  local skills = countPerColor(TAG_SKILLS_TOKEN)

  for _,c in ipairs(COLORS) do
    if health[c] == 1 then okN("HEALTH "..c) else failN("HEALTH "..c.." count="..tostring(health[c])) end
  end
  for _,c in ipairs(COLORS) do
    if know[c] == 1 then okN("KNOWLEDGE "..c) else failN("KNOWLEDGE "..c.." count="..tostring(know[c])) end
  end
  for _,c in ipairs(COLORS) do
    if skills[c] == 1 then okN("SKILLS "..c) else failN("SKILLS "..c.." count="..tostring(skills[c])) end
  end

  local yearObjs = findObjectsWithTag(TAG_YEAR_TOKEN)
  if #yearObjs == 1 then
    okN("YEAR token (tag="..TAG_YEAR_TOKEN..")")
  elseif #yearObjs == 0 then
    failN("YEAR token missing (tag="..TAG_YEAR_TOKEN..")")
  else
    warnN("YEAR token duplicated x"..#yearObjs.." (tag="..TAG_YEAR_TOKEN..")")
  end

  table.insert(lines, "")

  -- DECK SANITY
  table.insert(lines, "[DECK SANITY]")
  local youth = computeTaggedSet(TAG_DECK_YOUTH)
  local adult = computeTaggedSet(TAG_DECK_ADULT)

  local function reportSet(label, tag, s, expected)
    if s.total == 0 then
      failN(label.." missing/empty (tag="..tag..")")
      return
    end
    if s.total == expected then
      okN(label..": total="..s.total.." (decks="..s.decks..", cards="..s.cards..")")
    else
      warnN(label..": total="..s.total.." expected="..expected.." (decks="..s.decks..", cards="..s.cards..")")
    end
  end

  reportSet("Youth Deck", TAG_DECK_YOUTH, youth, EXPECTED_YOUTH_CNT)
  reportSet("Adult Deck", TAG_DECK_ADULT, adult, EXPECTED_ADULT_CNT)

  table.insert(lines, "")

  -- STATUS TAG SANITY
  table.insert(lines, "[STATUS TOKENS SANITY]")
  local hasDeprecated, hasRequired = false, false
  for _,o in ipairs(getAllObjects()) do
    if hasTag(o, DEPRECATED_STATUS_TAG) then hasDeprecated = true end
    if hasTag(o, REQUIRED_STATUS_TAG) then hasRequired = true end
  end
  if hasDeprecated then warnN("Found deprecated tag: "..DEPRECATED_STATUS_TAG) else okN("No deprecated tags") end
  if not hasRequired then failN("Missing required tag: "..REQUIRED_STATUS_TAG) else okN("Required tag present: "..REQUIRED_STATUS_TAG) end

  table.insert(lines, "")

  -- NEAR BOARD SCAN
  table.insert(lines, "[NEAR BOARD SCAN] (scripted/tagged objects near each PlayerBoard)")
  table.insert(lines, "radius="..tostring(NEAR_SCAN_RADIUS)..", limit="..tostring(NEAR_SCAN_LIMIT))

  local boardsMap = D_FindBoards()
  for _,c in ipairs(COLORS) do
    if not boardsMap[c] then
      table.insert(lines, "✖ "..c..": board missing -> scan skipped")
    else
      table.insert(lines, "• "..c..":")
      local list = D_ScanNearBoard(c, NEAR_SCAN_RADIUS, NEAR_SCAN_LIMIT)
      if #list == 0 then
        table.insert(lines, "  (no candidates)")
      else
        for _,it in ipairs(list) do
          local tagStr = table.concat(it.tags or {}, ", ")
          if tagStr == "" then tagStr = "(no tags)" end
          table.insert(lines, string.format("  - %s [%s] dist=%.2f scripted=%s tags={%s}",
            it.name or "", it.guid or "", it.dist or 0,
            it.scripted and "YES" or "NO",
            tagStr
          ))
        end
      end
    end
  end

  -- NEW: FULL INVENTORY (SUMMARY IN NOTES, FULL TO CONSOLE)
  local inv = buildInventory()

  table.insert(lines, "")
  table.insert(lines, "[SCRIPT INVENTORY]")
  table.insert(lines, "Scripted objects: "..tostring(inv.scriptedCount))
  table.insert(lines, "Non-scripted objects: "..tostring(inv.nonScriptedCount))

  local tagKeys = sortKeys(inv.tagCounts)
  table.insert(lines, "")
  table.insert(lines, "[FULL TAG INVENTORY] (summary; full list printed to console)")
  table.insert(lines, "Unique tags: "..tostring(#tagKeys))

  for i=1, math.min(#tagKeys, NOTES_MAX_TAG_LINES) do
    local k = tagKeys[i]
    local cnt = inv.tagCounts[k] or 0
    local samples = inv.tagSamples[k] or {}
    local sampleStr = (#samples>0) and (" | samples: "..table.concat(samples, " ; ")) or ""
    table.insert(lines, "• "..k.." = "..tostring(cnt)..sampleStr)
  end
  if #tagKeys > NOTES_MAX_TAG_LINES then
    table.insert(lines, "… (+ "..tostring(#tagKeys - NOTES_MAX_TAG_LINES).." tags) see console output")
  end

  if INCLUDE_SCRIPTED_LIST_TO_CONSOLE then
    table.insert(lines, "")
    table.insert(lines, "[SCRIPTED OBJECTS] (summary; full list printed to console)")
    for i=1, math.min(#inv.scripted, NOTES_MAX_SCRIPTED_LINES) do
      table.insert(lines, inv.scripted[i])
    end
    if #inv.scripted > NOTES_MAX_SCRIPTED_LINES then
      table.insert(lines, "… (+ "..tostring(#inv.scripted - NOTES_MAX_SCRIPTED_LINES).." scripted objects) see console output")
    end
  end

  -- FINALIZE
  lines[5] = "STATUS: "..status
  notesSet(lines)

  broadcastToAll(
    "DIAGNOSTIC: "..status.." ("..problems.." issue(s))",
    status=="PASS" and {0.6,1,0.6} or status=="WARN" and {1,0.9,0.5} or {1,0.5,0.5}
  )

  -- PRINT FULL LISTS TO CONSOLE (chunked)
  local tagLines = {}
  tagLines[#tagLines+1] = "=== [WLB_DIAG] FULL TAG INVENTORY v"..VERSION.." ("..now()..") ==="
  for _,k in ipairs(tagKeys) do
    local cnt = inv.tagCounts[k] or 0
    local samples = inv.tagSamples[k] or {}
    local sampleStr = (#samples>0) and (" | samples: "..table.concat(samples, " ; ")) or ""
    tagLines[#tagLines+1] = "• "..k.." = "..tostring(cnt)..sampleStr
  end
  printChunked(tagLines, "FULL TAG INVENTORY", TAG_LINES_PER_CHUNK)

  if INCLUDE_SCRIPTED_LIST_TO_CONSOLE then
    local scr = {}
    scr[#scr+1] = "=== [WLB_DIAG] SCRIPTED OBJECTS v"..VERSION.." ("..now()..") ==="
    for _,l in ipairs(inv.scripted) do scr[#scr+1] = l end
    printChunked(scr, "SCRIPTED OBJECTS", OBJ_LINES_PER_CHUNK)
  end

  if INCLUDE_OBJECT_CATALOG_TO_CONSOLE then
    local allLines = {}
    allLines[#allLines+1] = "=== [WLB_DIAG] OBJECT CATALOG v"..VERSION.." ("..now()..") ==="
    for _,o in ipairs(getAllObjects()) do
      local tags = safeGetTags(o, MAX_TAGS_PER_OBJECT)
      allLines[#allLines+1] = string.format("• %s [%s] type=%s scripted=%s tags=%s",
        safeName(o), safeGuid(o), tostring(o.type or o.tag or "?"),
        isScripted(o) and "YES" or "NO",
        joinTags(tags, MAX_TAGS_PER_OBJECT)
      )
    end
    printChunked(allLines, "OBJECT CATALOG", OBJ_LINES_PER_CHUNK)
  end

  return status, problems
end

-- Convenience
function D_RunAllToNotes()
  return runDiagnostic(nil, nil)
end

-- =========================================================
-- COMPREHENSIVE OBJECT INVENTORY (ALL OBJECTS)
-- =========================================================
function D_GenerateFullInventory()
  ensureSelfTag()
  
  local allObjects = getAllObjects()
  local totalCount = #allObjects
  local scriptedCount = 0
  local nonScriptedCount = 0
  
  -- Build comprehensive list
  local inventory = {}
  local notesLines = {}
  
  table.insert(notesLines, "=== FULL OBJECT INVENTORY ===")
  table.insert(notesLines, "Generated: "..now())
  table.insert(notesLines, "Total objects: "..tostring(totalCount))
  table.insert(notesLines, "")
  table.insert(notesLines, "Format: [GUID] Name | Type | Scripted: YES/NO | Tags: {...}")
  table.insert(notesLines, "")
  table.insert(notesLines, "Full detailed list printed to Console (chunked)")
  table.insert(notesLines, "")
  
  -- Process all objects
  for _,o in ipairs(allObjects) do
    if o then
      local guid = safeGuid(o)
      local name = safeName(o)
      local objType = tostring(o.type or o.tag or "Unknown")
      local scripted = isScripted(o)
      local tags = safeGetTags(o, 9999) -- Get ALL tags, no limit
      
      if scripted then
        scriptedCount = scriptedCount + 1
      else
        nonScriptedCount = nonScriptedCount + 1
      end
      
      -- Format tags
      local tagStr = ""
      if #tags > 0 then
        tagStr = table.concat(tags, ", ")
      else
        tagStr = "(no tags)"
      end
      
      -- Create detailed line
      local line = string.format("[%s] %s | Type: %s | Scripted: %s | Tags: {%s}",
        guid,
        name ~= "" and name or "(unnamed)",
        objType,
        scripted and "YES" or "NO",
        tagStr
      )
      
      table.insert(inventory, line)
      
      -- Add first 50 to Notes as sample
      if #inventory <= 50 then
        table.insert(notesLines, line)
      end
    end
  end
  
  -- Add summary to Notes
  table.insert(notesLines, "")
  table.insert(notesLines, "=== SUMMARY ===")
  table.insert(notesLines, "Total objects: "..tostring(totalCount))
  table.insert(notesLines, "Scripted: "..tostring(scriptedCount))
  table.insert(notesLines, "Non-scripted: "..tostring(nonScriptedCount))
  if totalCount > 50 then
    table.insert(notesLines, "")
    table.insert(notesLines, "... (showing first 50 objects above)")
    table.insert(notesLines, "See Console for complete list of all "..tostring(totalCount).." objects")
  end
  
  -- Save to Notes
  notesSet(notesLines)
  
  -- Print everything at once to Console (easier to copy from console)
  -- Note: If you have many objects (>200), console might truncate
  print("")
  print("========================================")
  print("=== FULL OBJECT INVENTORY (COPY FROM HERE) ===")
  print("========================================")
  print("Generated: "..now())
  print("Total objects: "..tostring(totalCount))
  print("Scripted: "..tostring(scriptedCount).." | Non-scripted: "..tostring(nonScriptedCount))
  print("Format: [GUID] Name | Type | Scripted: YES/NO | Tags: {...}")
  print("")
  print("--- START COPYING BELOW ---")
  print("")
  
  -- Print all objects in one continuous block
  for _,line in ipairs(inventory) do
    print(line)
  end
  
  print("")
  print("--- END COPYING ABOVE ---")
  print("")
  print("=== END OF INVENTORY ===")
  print("========================================")
  
  broadcastToAll(
    "INVENTORY: "..tostring(totalCount).." objects ("..tostring(scriptedCount).." scripted)",
    {0.6,0.8,1}
  )
  
  return totalCount, scriptedCount, nonScriptedCount
end

function btnFullInventory(_, pc)
  D_GenerateFullInventory()
end

-- =========================================================
-- SCRIPTED OBJECTS ONLY (for documentation)
-- =========================================================
function D_GenerateScriptedObjectsList()
  ensureSelfTag()
  
  local allObjects = getAllObjects()
  local scriptedList = {}
  
  -- Build list of only scripted objects
  for _,o in ipairs(allObjects) do
    if o and isScripted(o) then
      local guid = safeGuid(o)
      local name = safeName(o)
      local objType = tostring(o.type or o.tag or "Unknown")
      local tags = safeGetTags(o, 9999)
      
      local tagStr = ""
      if #tags > 0 then
        tagStr = table.concat(tags, ", ")
      else
        tagStr = "(no tags)"
      end
      
      table.insert(scriptedList, {
        guid = guid,
        name = name ~= "" and name or "(unnamed)",
        type = objType,
        tags = tagStr
      })
    end
  end
  
  -- Sort by name for easier review
  table.sort(scriptedList, function(a, b)
    return a.name < b.name
  end)
  
  -- Print to console in documentation format
  print("")
  print("========================================")
  print("=== SCRIPTED OBJECTS LIST (FOR DOCUMENTATION) ===")
  print("========================================")
  print("Total scripted objects: "..tostring(#scriptedList))
  print("Generated: "..now())
  print("")
  print("Format for each object:")
  print("  [#] Name | GUID: [guid] | Type: [type] | Tags: {tags}")
  print("")
  print("--- START COPYING BELOW ---")
  print("")
  
  for i, obj in ipairs(scriptedList) do
    print(string.format("%d. %s | GUID: %s | Type: %s | Tags: {%s}",
      i,
      obj.name,
      obj.guid,
      obj.type,
      obj.tags
    ))
  end
  
  print("")
  print("--- END COPYING ABOVE ---")
  print("")
  print("=== END OF SCRIPTED OBJECTS LIST ===")
  print("========================================")
  
  broadcastToAll(
    "Scripted objects list: "..tostring(#scriptedList).." found (check Console)",
    {0.6,0.8,1}
  )
  
  return scriptedList
end

function btnScriptedOnly(_, pc)
  D_GenerateScriptedObjectsList()
end

-- =========================================================
-- UI
-- =========================================================
local function makeBtn(label, fn, x, z, w, h, fs, bg)
  self.createButton({
    label = label,
    click_function = fn,
    function_owner = self,
    position = {x,0.2,z},
    width = w, height = h,
    font_size = fs,
    color = bg or {0.2,0.2,0.2},
    font_color = {1,1,1}
  })
end

function btnRunDiag(_, pc) 
  runDiagnostic(nil, pc) 
end

function btnRunRegistry(_, pc)
  D_DumpPlayerRegistryToNotes()
  broadcastToAll("DIAG: Player Registry dumped to Notes", {0.8,0.9,0.8})
end

function onLoad()
  ensureSelfTag()
  
  -- Button 1: RUN CHECK - Runs full diagnostic check (boards, tokens, controllers, etc.)
  makeBtn("RUN CHECK", "btnRunDiag", 0.0, -2.25, 1200, 400, 240, {0.2,0.2,0.2})
  
  -- Button 2: PLAYER REG - Dumps player registry (boards, tokens, AP tokens per player) to Notes
  makeBtn("PLAYER REG", "btnRunRegistry", 0.0, -0.75, 1200, 400, 210, {0.15,0.35,0.25})
  
  -- Button 3: FULL INVENTORY - Lists ALL objects with GUID, tags, and script status
  makeBtn("FULL INVENTORY", "btnFullInventory", 0.0, 0.75, 1200, 400, 200, {0.2,0.4,0.6})
  
  -- Button 4: SCRIPTED ONLY - Lists ONLY scripted objects (for documentation)
  makeBtn("SCRIPTED ONLY", "btnScriptedOnly", 0.0, 2.25, 1200, 400, 200, {0.6,0.3,0.6})
  
  print("[WLB_DIAGNOSTIC_CTRL] Loaded v"..VERSION.." | tag enforced: "..TAG_DIAG)
end
