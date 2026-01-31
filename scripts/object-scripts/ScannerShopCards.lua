-- =========================
-- WLB - SHOP DECK TOOLS v1.0.1 (CLEAN REWRITE)
-- Scan: names + tags (for loose cards)
-- Retag: loose cards + decks (by deck contents nicknames)
-- Export: copy/paste friendly
-- =========================

local CFG = {
  C_PREFIX = "^CSHOP_%d%d_",
  H_PREFIX = "^HSHOP_%d%d_",
  I_PREFIX = "^ISHOP_%d%d_",

  EXPECT_C = 28,
  EXPECT_H = 14,
  EXPECT_I = 14,

  TAG_CARD_ALL = "WLB_SHOP_CARD",
  TAG_CARD_C   = "WLB_SHOP_CARD_C",
  TAG_CARD_H   = "WLB_SHOP_CARD_H",
  TAG_CARD_I   = "WLB_SHOP_CARD_I",

  TAG_DECK_ALL = "WLB_SHOP_DECK",
  TAG_DECK_C   = "WLB_SHOP_DECK_C",
  TAG_DECK_H   = "WLB_SHOP_DECK_H",
  TAG_DECK_I   = "WLB_SHOP_DECK_I",

  BROADCAST_COLOR = {1,1,1},
}

local cache = {}

local function resetCache()
  cache = {
    loose = { C={}, H={}, I={} },        -- [guid]={name=, tags=}
    decks = { C={}, H={}, I={} },        -- [deckGuid]={deck=, names={...}}
    names = { C={}, H={}, I={} },        -- unique names
  }
end

-- ---------- UI ----------
local function addBtn(index, label, fn, x, z)
  self.createButton({
    index = index,
    label = label,
    click_function = fn,
    function_owner = self,
    position = {x, 0.2, z},
    rotation = {0, 180, 0},
    width = 2000,
    height = 320,
    font_size = 170,
    color = {0.15,0.15,0.15},
    font_color = {1,1,1},
  })
end

local function buildUI()
  self.clearButtons()
  local x = -0.9
  local z = 0.78
  addBtn(0, "SCAN SHOP",      "uiScanShop",      x, z); z = z - 0.40
  addBtn(1, "RETAG SHOP",     "uiRetagShop",     x, z); z = z - 0.40
  addBtn(2, "EXPORT (PASTE)", "uiExportPaste",   x, z); z = z - 0.40
  addBtn(3, "CHECK SEQ",      "uiCheckSeq",      x, z)
end

function onLoad()
  resetCache()
  buildUI()
end

-- ---------- Helpers ----------
local function broadcast(playerColor, msg)
  if playerColor and Player[playerColor] then
    Player[playerColor].broadcast(msg, CFG.BROADCAST_COLOR)
  else
    printToAll(msg, CFG.BROADCAST_COLOR)
  end
end

local function isCName(n) return (n and string.match(n, CFG.C_PREFIX) ~= nil) end
local function isHName(n) return (n and string.match(n, CFG.H_PREFIX) ~= nil) end
local function isIName(n) return (n and string.match(n, CFG.I_PREFIX) ~= nil) end

local function classifyByName(n)
  if isCName(n) then return "C" end
  if isHName(n) then return "H" end
  if isIName(n) then return "I" end
  return nil
end

local function uniqAppend(arr, val)
  if not val or val == "" then return end
  for _,v in ipairs(arr) do
    if v == val then return end
  end
  table.insert(arr, val)
end

local function getTagsSafe(obj)
  local tags = {}
  if not obj or not obj.getTags then return tags end
  local ok, t = pcall(function() return obj.getTags() end)
  if ok and type(t) == "table" then
    for _,tag in ipairs(t) do
      table.insert(tags, tostring(tag))
    end
  end
  return tags
end

local function tagsToStr(tags)
  if not tags or #tags == 0 then return "" end
  table.sort(tags)
  return table.concat(tags, ",")
end

local function ensureTag(obj, tag)
  if not obj or not obj.addTag or not obj.hasTag then return end
  if not obj.hasTag(tag) then
    pcall(function() obj.addTag(tag) end)
  end
end

local function scanAll()
  resetCache()

  for _,obj in ipairs(getAllObjects()) do
    if obj.tag == "Card" then
      local name = obj.getName() or ""
      local row = classifyByName(name)
      if row then
        local guid = obj.getGUID()
        cache.loose[row][guid] = { name=name, tags=getTagsSafe(obj) }
        uniqAppend(cache.names[row], name)
      end

    elseif obj.tag == "Deck" then
      local deckList = obj.getObjects() or {}
      local hits = { C={}, H={}, I={} }

      for _,entry in ipairs(deckList) do
        local n = entry.nickname or ""
        local row = classifyByName(n)
        if row then
          table.insert(hits[row], n)
          uniqAppend(cache.names[row], n)
        end
      end

      for _,row in ipairs({"C","H","I"}) do
        if #hits[row] > 0 then
          local dg = obj.getGUID()
          if not cache.decks[row][dg] then
            cache.decks[row][dg] = { deck=obj, names={} }
          end
          for _,n in ipairs(hits[row]) do
            uniqAppend(cache.decks[row][dg].names, n)
          end
        end
      end
    end
  end

  table.sort(cache.names.C)
  table.sort(cache.names.H)
  table.sort(cache.names.I)
end

local function countLoose(row)
  local c = 0
  for _,_ in pairs(cache.loose[row]) do c = c + 1 end
  return c
end

local function countDeckNames(row)
  local c = 0
  for _,info in pairs(cache.decks[row]) do
    c = c + ((info.names and #info.names) or 0)
  end
  return c
end

local function totalUnique(row)
  return #(cache.names[row] or {})
end

-- ---------- UI Actions ----------
function uiScanShop(_, playerColor)
  scanAll()

  local cN = totalUnique("C")
  local hN = totalUnique("H")
  local iN = totalUnique("I")

  broadcast(playerColor, "SCAN SHOP: unique names -> C="..cN.." H="..hN.." I="..iN)
  broadcast(playerColor, "Loose cards -> C="..countLoose("C").." H="..countLoose("H").." I="..countLoose("I"))
  broadcast(playerColor, "Deck-contained names -> C="..countDeckNames("C").." H="..countDeckNames("H").." I="..countDeckNames("I"))

  if CFG.EXPECT_C and cN ~= CFG.EXPECT_C then
    broadcast(playerColor, "WARNING: C expected "..CFG.EXPECT_C.." but found "..cN)
  end
  if CFG.EXPECT_H and hN ~= CFG.EXPECT_H then
    broadcast(playerColor, "WARNING: H expected "..CFG.EXPECT_H.." but found "..hN)
  end
  if CFG.EXPECT_I and iN ~= CFG.EXPECT_I then
    broadcast(playerColor, "WARNING: I expected "..CFG.EXPECT_I.." but found "..iN)
  end
end

function uiRetagShop(_, playerColor)
  scanAll()

  local tagged = {C=0,H=0,I=0}
  for _,row in ipairs({"C","H","I"}) do
    for guid,_ in pairs(cache.loose[row]) do
      local obj = getObjectFromGUID(guid)
      if obj and obj.tag == "Card" then
        ensureTag(obj, CFG.TAG_CARD_ALL)
        if row=="C" then ensureTag(obj, CFG.TAG_CARD_C) end
        if row=="H" then ensureTag(obj, CFG.TAG_CARD_H) end
        if row=="I" then ensureTag(obj, CFG.TAG_CARD_I) end
        tagged[row] = tagged[row] + 1
      end
    end
  end

  local deckTagged = {C=0,H=0,I=0}
  for _,row in ipairs({"C","H","I"}) do
    for _,info in pairs(cache.decks[row]) do
      local deck = info.deck
      if deck and deck.tag == "Deck" then
        ensureTag(deck, CFG.TAG_DECK_ALL)
        if row=="C" then ensureTag(deck, CFG.TAG_DECK_C) end
        if row=="H" then ensureTag(deck, CFG.TAG_DECK_H) end
        if row=="I" then ensureTag(deck, CFG.TAG_DECK_I) end
        deckTagged[row] = deckTagged[row] + 1
      end
    end
  end

  broadcast(playerColor, "RETAG loose cards: C="..tagged.C.." H="..tagged.H.." I="..tagged.I)
  broadcast(playerColor, "RETAG decks: C="..deckTagged.C.." H="..deckTagged.H.." I="..deckTagged.I)
  broadcast(playerColor, "NOTE: cards inside decks cannot be tagged until taken out (TTS limitation).")
end

function uiExportPaste(_, playerColor)
  scanAll()

  local lines = {}
  table.insert(lines, "=== WLB SHOP SCAN EXPORT (PASTE TO CHAT) ===")
  table.insert(lines, "UNIQUE NAMES: C="..totalUnique("C").." H="..totalUnique("H").." I="..totalUnique("I"))
  table.insert(lines, "")

  local function dumpRow(row, title)
    table.insert(lines, "## "..title.." ("..row..")")
    table.insert(lines, "-- LOOSE: GUID | NAME | TAGS")

    local tmp = {}
    for guid,entry in pairs(cache.loose[row]) do
      table.insert(tmp, {guid=guid, name=entry.name, tags=tagsToStr(entry.tags)})
    end
    table.sort(tmp, function(a,b) return tostring(a.name) < tostring(b.name) end)

    if #tmp == 0 then
      table.insert(lines, "NONE")
    else
      for _,e in ipairs(tmp) do
        table.insert(lines, e.guid.." | "..e.name.." | "..e.tags)
      end
    end

    table.insert(lines, "")
    table.insert(lines, "-- DECKS: DECK_GUID | DECK_NAME | COUNT | SAMPLE_NAMES")

    local dtmp = {}
    for dg,info in pairs(cache.decks[row]) do
      local dn = (info.deck and info.deck.getName and info.deck.getName()) or ""
      local c = (info.names and #info.names) or 0
      table.insert(dtmp, {dg=dg, dn=dn, c=c, names=info.names or {}})
    end
    table.sort(dtmp, function(a,b) return a.c > b.c end)

    if #dtmp == 0 then
      table.insert(lines, "NONE")
    else
      for _,d in ipairs(dtmp) do
        table.sort(d.names)
        local sample = {}
        for i=1, math.min(8, #d.names) do sample[#sample+1] = d.names[i] end
        table.insert(lines, d.dg.." | "..tostring(d.dn).." | "..tostring(d.c).." | "..table.concat(sample, " ; "))
      end
    end

    table.insert(lines, "")
    table.insert(lines, "-- UNIQUE NAMES (sorted)")
    for i,n in ipairs(cache.names[row]) do
      table.insert(lines, string.format("%03d) %s", i, n))
    end
    table.insert(lines, "")
  end

  dumpRow("C", "CONSUMABLES")
  dumpRow("H", "HI-TECH")
  dumpRow("I", "INVESTMENTS")

  local msg = table.concat(lines, "\n")
  print(msg)
  broadcast(playerColor, "EXPORT: printed SHOP scan to console. Skopiuj i wklej tutaj.")
end

function uiCheckSeq(_, playerColor)
  scanAll()

  local function checkRow(row, expected, prefixLetter)
    local numMap = {}
    local bad = {}

    for _,name in ipairs(cache.names[row]) do
      local pat = "^"..prefixLetter.."SHOP_(%d%d)_"
      local numStr = string.match(name, pat)
      if not numStr then
        table.insert(bad, name)
      else
        local n = tonumber(numStr)
        if n then
          numMap[n] = (numMap[n] or 0) + 1
        else
          table.insert(bad, name)
        end
      end
    end

    local missing = {}
    local dupes = {}

    for i=1, expected do
      local c = numMap[i] or 0
      if c == 0 then missing[#missing+1] = i end
      if c > 1 then dupes[#dupes+1] = {i=i,c=c} end
    end

    broadcast(playerColor, "CHECK "..row..": expected "..prefixLetter.."SHOP_01.._"..string.format("%02d", expected))

    if #bad > 0 then
      print("BAD NAMES "..row..":")
      for _,n in ipairs(bad) do print(" - "..n) end
      broadcast(playerColor, "WARNING "..row..": "..#bad.." bad names (see console)")
    end

    if #missing > 0 then
      print("MISSING "..row..":")
      for _,i in ipairs(missing) do print(string.format(" - %02d", i)) end
      broadcast(playerColor, "MISSING "..row..": "..#missing.." numbers (see console)")
    else
      broadcast(playerColor, "MISSING "..row..": none OK")
    end

    if #dupes > 0 then
      print("DUPES "..row..":")
      for _,d in ipairs(dupes) do print(string.format(" - %02d occurs %d times", d.i, d.c)) end
      broadcast(playerColor, "DUPES "..row..": "..#dupes.." duplicates (see console)")
    else
      broadcast(playerColor, "DUPES "..row..": none OK")
    end

    broadcast(playerColor, "TOTAL UNIQUE "..row..": "..tostring(#cache.names[row]))
  end

  checkRow("C", CFG.EXPECT_C, "C")
  checkRow("H", CFG.EXPECT_H, "H")
  checkRow("I", CFG.EXPECT_I, "I")
end
