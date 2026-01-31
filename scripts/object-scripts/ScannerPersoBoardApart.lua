-- =========================================================
-- WLB FAMILY SLOT LOCATOR v1.1.0 (BOARD + ESTATE CARDS)
--  - MODE: BOARD  -> measures local positions relative to PlayerBoard (WLB_BOARD)
--  - MODE: CARD   -> measures local positions relative to Estate Card (Card or WLB_ESTATE_CARD)
--
-- Use case:
--  - L0 (grandma room printed on playerboard): MODE=BOARD, LEVEL=L0
--  - L1-L4 (estate cards): MODE=CARD, LEVEL=L1..L4
-- =========================================================

local DEBUG = true

local TAG_PROBE      = "WLB_PROBE"
local TAG_BOARD      = "WLB_BOARD"
local TAG_ESTATECARD = "WLB_ESTATE_CARD"

local COLORS = {"Yellow","Red","Blue","Green"}
local function colorTag(c) return "WLB_COLOR_"..c end

-- MODE: "BOARD" or "CARD"
local MODE = "BOARD"

-- Data stores:
-- For BOARD mode we store per COLOR (because boards could be rotated/placed differently).
local boardSlots = {
  Yellow = { L0 = {} },
  Red    = { L0 = {} },
  Blue   = { L0 = {} },
  Green  = { L0 = {} },
}

-- For CARD mode we store per LEVEL (local to the card itself).
local cardSlots = { L1={}, L2={}, L3={}, L4={} }

-- UI state
local curLevel = "L0"   -- for BOARD we use L0, for CARD we use L1..L4
local curIndex = 1

local function dprint(...)
  if DEBUG then print("[WLB_SLOT_LOC]", ...) end
end

local function clamp(n,a,b)
  if n < a then return a end
  if n > b then return b end
  return n
end

local function findProbe()
  for _, o in ipairs(getAllObjects()) do
    if o.hasTag and o.hasTag(TAG_PROBE) then return o end
  end
  return nil
end

local function raycastDown(pos)
  local origin = {pos[1], pos[2] + 2.0, pos[3]}
  return Physics.cast({
    origin       = origin,
    direction    = {0,-1,0},
    type         = 3,
    max_distance = 6,
    debug        = false,
  })
end

local function getBoardUnder(pos)
  local hits = raycastDown(pos)
  for _, h in ipairs(hits) do
    local obj = h.hit_object
    if obj and obj ~= self and obj.hasTag and obj.hasTag(TAG_BOARD) then
      return obj
    end
  end
  return nil
end

local function getBoardColor(board)
  if not board or not board.hasTag then return nil end
  for _, c in ipairs(COLORS) do
    if board.hasTag(colorTag(c)) then return c end
  end
  return nil
end

local function getEstateCardUnder(pos)
  local hits = raycastDown(pos)

  -- Prefer tagged estate cards
  for _, h in ipairs(hits) do
    local obj = h.hit_object
    if obj and obj ~= self and obj.hasTag and obj.hasTag(TAG_ESTATECARD) then
      return obj
    end
  end

  -- Fallback: any Card
  for _, h in ipairs(hits) do
    local obj = h.hit_object
    if obj and obj ~= self and obj.tag == "Card" then
      return obj
    end
  end

  return nil
end

local function updateButtons()
  self.editButton({index=0, label="MODE: "..MODE})
  self.editButton({index=1, label="LEVEL: "..curLevel})
  self.editButton({index=2, label="SLOT: "..tostring(curIndex)})
end

function onLoad()
  -- MODE
  self.createButton({
    index=0, label="MODE: "..MODE, click_function="btnMode", function_owner=self,
    position={0,0.2,-1.10}, width=1700, height=280, font_size=170,
    color={0.2,0.2,0.2}, font_color={1,1,1},
  })

  -- LEVEL
  self.createButton({
    index=1, label="LEVEL: "..curLevel, click_function="btnLevel", function_owner=self,
    position={0,0.2,-0.70}, width=1700, height=280, font_size=170,
    color={0.2,0.2,0.2}, font_color={1,1,1},
  })

  -- SLOT +/- (alt click = -)
  self.createButton({
    index=2, label="SLOT: "..tostring(curIndex), click_function="btnSlot", function_owner=self,
    position={0,0.2,-0.30}, width=1700, height=280, font_size=170,
    color={0.2,0.2,0.2}, font_color={1,1,1},
  })

  -- CAPTURE
  self.createButton({
    index=3, label="CAPTURE", click_function="btnCapture", function_owner=self,
    position={0,0.2,0.20}, width=1700, height=360, font_size=220,
    color={0.1,0.35,0.1}, font_color={1,1,1},
  })

  -- EXPORT
  self.createButton({
    index=4, label="EXPORT", click_function="btnExport", function_owner=self,
    position={0,0.2,0.75}, width=1700, height=300, font_size=200,
    color={0.1,0.2,0.4}, font_color={1,1,1},
  })

  -- CLEAR (current context)
  self.createButton({
    index=5, label="CLEAR", click_function="btnClear", function_owner=self,
    position={0,0.2,1.15}, width=1700, height=260, font_size=160,
    color={0.45,0.1,0.1}, font_color={1,1,1},
  })
end

function btnMode()
  MODE = (MODE == "BOARD") and "CARD" or "BOARD"
  -- auto-suggest sensible level
  if MODE == "BOARD" then curLevel = "L0" else curLevel = "L1" end
  updateButtons()
end

function btnLevel()
  if MODE == "BOARD" then
    -- only L0 on board (for now)
    curLevel = "L0"
  else
    local order = {"L1","L2","L3","L4"}
    local idx = 1
    for i,v in ipairs(order) do if v == curLevel then idx = i break end end
    idx = idx + 1; if idx > #order then idx = 1 end
    curLevel = order[idx]
  end
  updateButtons()
end

function btnSlot(_, _, alt_click)
  if alt_click then curIndex = curIndex - 1 else curIndex = curIndex + 1 end
  curIndex = clamp(curIndex, 1, 30)
  updateButtons()
end

function btnCapture(_, playerColor)
  local probe = findProbe()
  if not probe then
    broadcastToColor("No PROBE (tag: "..TAG_PROBE..")", playerColor, {1,0.4,0.4})
    return
  end

  local ppos = probe.getPosition()

  if MODE == "BOARD" then
    local board = getBoardUnder(ppos)
    if not board then
      broadcastToColor("Nie widzę PlayerBoard pod PROBE (wymagany tag: "..TAG_BOARD..")", playerColor, {1,0.4,0.4})
      return
    end
    local bColor = getBoardColor(board) or "Unknown"
    if bColor == "Unknown" then
      broadcastToColor("Board nie ma tagu koloru (WLB_COLOR_*) – zapiszemy jako Unknown, ale lepiej dodać tag.", playerColor, {1,0.7,0.2})
    end

    local localPos = board.positionToLocal(ppos)
    if not boardSlots[bColor] then boardSlots[bColor] = {L0={}} end
    boardSlots[bColor].L0[curIndex] = {x=localPos[1], y=localPos[2], z=localPos[3]}

    local msg = string.format("CAPTURED BOARD %s L0 slot %d on board [%s] => {x=%.3f,y=%.3f,z=%.3f}",
      bColor, curIndex, board.getName(), localPos[1], localPos[2], localPos[3])
    broadcastToColor(msg, playerColor, {0.6,1,0.6}); dprint(msg)
    return
  end

  -- MODE == CARD
  local card = getEstateCardUnder(ppos)
  if not card then
    broadcastToColor("Nie widzę karty Estates pod PROBE (MODE=CARD).", playerColor, {1,0.4,0.4})
    return
  end

  local localPos = card.positionToLocal(ppos)
  cardSlots[curLevel][curIndex] = {x=localPos[1], y=localPos[2], z=localPos[3]}

  local msg = string.format("CAPTURED CARD %s slot %d on card [%s] => {x=%.3f,y=%.3f,z=%.3f}",
    curLevel, curIndex, card.getName(), localPos[1], localPos[2], localPos[3])
  broadcastToColor(msg, playerColor, {0.6,1,0.6}); dprint(msg)
end

local function exportAll()
  local lines = {}
  table.insert(lines, "-- === WLB FAMILY SLOTS EXPORT ===")

  -- BOARD
  table.insert(lines, "local FAMILY_SLOTS_BOARD = {")
  for _, c in ipairs(COLORS) do
    table.insert(lines, "  "..c.." = { L0 = {")
    local lvl = boardSlots[c] and boardSlots[c].L0 or {}
    local maxI = 0
    for i,_ in pairs(lvl) do if i > maxI then maxI = i end end
    for i=1,maxI do
      local v = lvl[i]
      if v then
        table.insert(lines, string.format("    [%d] = {x=%.3f, y=%.3f, z=%.3f},", i, v.x, v.y, v.z))
      end
    end
    table.insert(lines, "  } },")
  end
  table.insert(lines, "}")
  table.insert(lines, "")

  -- CARD
  table.insert(lines, "local FAMILY_SLOTS_CARD = {")
  for _, lvlName in ipairs({"L1","L2","L3","L4"}) do
    table.insert(lines, "  "..lvlName.." = {")
    local lvl = cardSlots[lvlName]
    local maxI = 0
    for i,_ in pairs(lvl) do if i > maxI then maxI = i end end
    for i=1,maxI do
      local v = lvl[i]
      if v then
        table.insert(lines, string.format("    [%d] = {x=%.3f, y=%.3f, z=%.3f},", i, v.x, v.y, v.z))
      end
    end
    table.insert(lines, "  },")
  end
  table.insert(lines, "}")
  return table.concat(lines, "\n")
end

function btnExport(_, playerColor)
  local out = exportAll()
  print(out)
  broadcastToColor("EXPORT gotowy — zobacz konsolę (Print).", playerColor, {0.7,0.9,1})
end

function btnClear(_, playerColor)
  if MODE == "BOARD" then
    -- clear only current player's board color if we can infer from board under probe, else clear Yellow
    local probe = findProbe()
    if probe then
      local board = getBoardUnder(probe.getPosition())
      local bc = getBoardColor(board) or "Yellow"
      if boardSlots[bc] then boardSlots[bc].L0 = {} end
      broadcastToColor("Wyczyszczono BOARD L0 dla "..bc, playerColor, {1,0.7,0.2})
      return
    end
    boardSlots.Yellow.L0 = {}
    broadcastToColor("Wyczyszczono BOARD L0 dla Yellow (fallback)", playerColor, {1,0.7,0.2})
    return
  end

  cardSlots[curLevel] = {}
  broadcastToColor("Wyczyszczono CARD "..curLevel, playerColor, {1,0.7,0.2})
end
