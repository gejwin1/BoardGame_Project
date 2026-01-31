-- =========================
-- WLB CONTROL PANEL v1.3.2 (WLB_LAYOUT) - BIG UI
-- + YOUTH: reset YDECK (712b7d) via Event Track Controller.resetYouthDeck()
-- =========================

local TOKENYEAR_GUID = "465776"

local menuOpen = false
local SAT_NAME_PATTERN = "^SAT%s*[%-%–]"

-- tags for resettable controllers
local TAG_STATS = "WLB_STATS_CTRL"
local TAG_AP    = "WLB_AP_CTRL"
local TAG_MONEY = "WLB_MONEY"

-- SAT tag
local SAT_TAG = "SAT_TOKEN"

-- LAYOUT tag (standard)
local LAYOUT_TAG = "WLB_LAYOUT"

-- optional Adult Start manager tag
local ADULT_START_MANAGER_TAG = "WLB_ADULT_START"

-- NEW: Event Track Controller tag (add this tag to the Event Controller tile)
local TAG_EVT_CONTROLLER = "WLB_EVT_CONTROLLER"

-- persisted
local layoutData = {}

-- ===== utils =====
local function hasLayoutTag(o)
  return (o.hasTag and o.hasTag(LAYOUT_TAG))
end

local function v3pack(v) return {x=v.x, y=v.y, z=v.z} end

local function loadState()
  layoutData = {}
  if self.script_state and self.script_state ~= "" then
    local ok, data = pcall(function() return JSON.decode(self.script_state) end)
    if ok and data and data.layoutData then
      layoutData = data.layoutData
    end
  end
end

local function saveState()
  self.script_state = JSON.encode({ layoutData = layoutData })
end

local function sortByName(list)
  table.sort(list, function(a,b)
    return (a.getName() or "") < (b.getName() or "")
  end)
end

-- ===== Layout: CAPTURE / RESTORE =====
function captureLayout()
  local list = {}
  for _, o in ipairs(getAllObjects()) do
    if hasLayoutTag(o) then table.insert(list, o) end
  end

  sortByName(list)

  layoutData = {}
  for _, o in ipairs(list) do
    local guid = o.getGUID()
    layoutData[guid] = {
      pos   = v3pack(o.getPosition()),
      rot   = v3pack(o.getRotation()),
      scale = v3pack(o.getScale()),
      name  = o.getName()
    }
  end

  saveState()
  broadcastToAll("✅ [WLB] CAPTURE LAYOUT: zapisano "..tostring(#list).." obiektów (WLB_LAYOUT). TERAZ ZRÓB SAVE.", {0.8,1,0.8})
  print("[WLB] CAPTURE LAYOUT saved objects: "..tostring(#list))
end

function restoreLayout()
  if not layoutData or next(layoutData) == nil then
    broadcastToAll("❌ [WLB] RESTORE LAYOUT: no saved layout. Click CAPTURE LAYOUT (and do SAVE).", {1,0.4,0.4})
    return
  end

  local moved, missing = 0, 0
  for guid, t in pairs(layoutData) do
    local o = getObjectFromGUID(guid)
    if o then
      o.setPositionSmooth({t.pos.x, t.pos.y, t.pos.z}, false, true)
      o.setRotationSmooth({t.rot.x, t.rot.y, t.rot.z}, false, true)
      if t.scale then o.setScale({t.scale.x, t.scale.y, t.scale.z}) end
      moved = moved + 1
    else
      missing = missing + 1
      print("[WLB][LAYOUT] Missing GUID="..tostring(guid).." name="..tostring(t.name))
    end
  end

  broadcastToAll("🔁 [WLB] RESTORE LAYOUT: restored "..tostring(moved).." objects, missing "..tostring(missing)..".", {0.8,0.9,1})
end

-- ===== SAT: collect =====
function sat_collect()
  local sats = getObjectsWithTag(SAT_TAG)
  local base = self.getPosition()
  local i = 0

  print("[SAT] Found (by tag): "..tostring(#sats))
  for _, o in ipairs(sats) do
    i = i + 1
    print(string.format("[SAT] %d) GUID=%s | name=%s", i, o.getGUID(), o.getName()))
    o.setPositionSmooth({base.x + (i * 1.7), base.y + 1.2, base.z}, false, true)
    o.setRotationSmooth({0, 180, 0}, false, true)
  end

  broadcastToAll("[WLB] SAT: zebrano tokeny SAT_TOKEN obok Control Panelu ("..tostring(#sats)..")", {0.8,1,0.8})
end

-- ===== reset SAT =====
function resetSatisfactionTo10()
  local sats = {}

  for _, obj in ipairs(getAllObjects()) do
    if obj.hasTag and obj.hasTag(SAT_TAG) then
      table.insert(sats, obj)
    end
  end

  local usedFallback = false
  if #sats == 0 then
    usedFallback = true
    for _, obj in ipairs(getAllObjects()) do
      local name = obj.getName and (obj.getName() or "") or ""
      if string.match(name, SAT_NAME_PATTERN) then
        table.insert(sats, obj)
      end
    end
  end

  sortByName(sats)
  print("CP: SAT found="..tostring(#sats).." via "..(usedFallback and "NAME" or "TAG"))

  for i, obj in ipairs(sats) do
    local ok, err = pcall(function()
      obj.call("resetToStart", {slot = (i-1)})
    end)
    if not ok then
      print("CP: SAT resetToStart error on "..tostring(obj.getName())..": "..tostring(err))
    end
  end

  return #sats
end

-- ===== generic reset by tag =====
function resetByTag(tag, label)
  local out = { ok = "?", count = 0 }

  local list = {}
  for _, obj in ipairs(getAllObjects()) do
    if obj.hasTag and obj.hasTag(tag) then
      table.insert(list, obj)
    end
  end

  if #list == 0 then
    out.ok = "NONE"
    out.count = 0
    print("CP: nie znaleziono obiektów dla tagu: "..tag.." ("..label..")")
    return out
  end

  sortByName(list)

  local okAll = true
  for _, o in ipairs(list) do
    local ok, err = pcall(function()
      o.call("resetNewGame")
    end)
    if not ok then
      okAll = false
      print("CP: reset error ["..label.."] on "..tostring(o.getName())..": "..tostring(err))
    end
  end

  out.ok = okAll and "OK" or "ERR"
  out.count = #list
  return out
end

-- ===== AdultStart mode (optional) =====
function setAdultStartMode(isAdult)
  local found = false
  for _, obj in ipairs(getAllObjects()) do
    if obj.hasTag and obj.hasTag(ADULT_START_MANAGER_TAG) then
      found = true
      local ok, err = pcall(function()
        obj.call("setMode", { adult = (isAdult == true) })
      end)
      if not ok then
        print("CP: AdultStart setMode error: "..tostring(err))
      end
    end
  end
  if not found then
    print("CP: brak ADULT START MANAGER (tag "..ADULT_START_MANAGER_TAG..")")
  end
end

-- ===== TokenYear =====
function setTokenYearRound(r)
  local ty = getObjectFromGUID(TOKENYEAR_GUID)
  if not ty then
    broadcastToAll("❌ Control: nie znaleziono TokenYear (GUID "..TOKENYEAR_GUID..")", {1,0.3,0.3})
    return
  end
  local ok, err = pcall(function()
    ty.call("setRound", {round = r})
  end)
  if not ok then
    broadcastToAll("❌ Control: błąd setRound(): "..tostring(err), {1,0.3,0.3})
  end
end

-- ===== NEW: reset YOUTH Event Deck (YDECK 712b7d) =====
local function resetYouthEventDeck()
  -- 1) preferred: by tag
  local list = getObjectsWithTag(TAG_EVT_CONTROLLER)
  if list and #list > 0 then
    local ctrl = list[1]
    local ok, err = pcall(function()
      ctrl.call("resetYouthDeck")
    end)
    if ok then
      print("CP: YOUTH event deck reset via tag "..TAG_EVT_CONTROLLER.." on "..tostring(ctrl.getGUID()))
      return { ok=true, mode="TAG", guid=ctrl.getGUID() }
    else
      print("CP: YOUTH event deck reset error (TAG): "..tostring(err))
      return { ok=false, mode="TAG", err=tostring(err) }
    end
  end

  -- 2) fallback: try by name hints (safe: only one attempt succeeds, otherwise we warn)
  local candidates = {}
  for _, o in ipairs(getAllObjects()) do
    if o and o.getName and o.call then
      local n = (o.getName() or ""):lower()
      if n:find("event") or n:find("evt") then
        table.insert(candidates, o)
      end
    end
  end

  for _, o in ipairs(candidates) do
    local ok, err = pcall(function()
      o.call("resetYouthDeck")
    end)
    if ok then
      print("CP: YOUTH event deck reset via NAME fallback on "..tostring(o.getGUID()).." name="..tostring(o.getName()))
      return { ok=true, mode="NAME", guid=o.getGUID() }
    end
  end

  -- 3) not found
  warn("CP: Nie znaleziono kontrolera toru eventów do resetu YDECK. Dodaj tag '"..TAG_EVT_CONTROLLER.."' do tile'a kontrolera eventów.")
  return { ok=false, mode="NONE" }
end

-- ===== NEW GAME =====
function newGameYouth()
  restoreLayout()

  local satCount = resetSatisfactionTo10()
  setTokenYearRound(1)

  local stats = resetByTag(TAG_STATS, "STATS")
  local ap    = resetByTag(TAG_AP, "AP")
  local money = resetByTag(TAG_MONEY, "MONEY")

  -- YOUTH ONLY: reset YDECK and refill youth track
  local evt = resetYouthEventDeck()

  setAdultStartMode(false)
  finish("YOUTH (runda 1)", satCount, stats, ap, money, evt)
end

function newGameAdult()
  restoreLayout()

  local satCount = resetSatisfactionTo10()
  setTokenYearRound(6)

  local stats = resetByTag(TAG_AP, "STATS")
  local ap    = resetByTag(TAG_AP, "AP")
  local money = resetByTag(TAG_MONEY, "MONEY")

  -- Adult: for now do nothing with YDECK
  setAdultStartMode(true)
  finish("ADULT (runda 6)", satCount, stats, ap, money, nil)
end

function finish(label, satCount, stats, ap, money, evt)
  local msg =
    "✅ NEW GAME: " .. label ..
    " | SAT: " .. tostring(satCount) ..
    " | STATS=" .. tostring(stats.ok) .. ":" .. tostring(stats.count) ..
    " | AP=" .. tostring(ap.ok) .. ":" .. tostring(ap.count) ..
    " | MONEY=" .. tostring(money.ok) .. ":" .. tostring(money.count)

  if evt ~= nil then
    if evt.ok then
      msg = msg .. " | EVT=OK:"..tostring(evt.mode)
    else
      msg = msg .. " | EVT=NOCTRL"
    end
  end

  broadcastToAll(msg, {0.7,1,0.7})
  menuOpen = false
  drawMenu()
end

-- ===== UI =====
function onLoad()
  loadState()
  drawMenu()
end

function drawMenu()
  self.clearButtons()

  -- BIG UI settings
  local Y = 0.25

  -- Row 1 (two big buttons)
  self.createButton({
    label="CAPTURE\nLAYOUT",
    click_function="captureLayout",
    function_owner=self,
    position={-0.62, Y, -0.75},
    rotation={0,0,0},
    width=1200, height=520, font_size=160,
    tooltip="Saves positions of all objects with tag WLB_LAYOUT. After clicking: SAVE!"
  })

  self.createButton({
    label="RESTORE\nLAYOUT",
    click_function="restoreLayout",
    function_owner=self,
    position={0.62, Y, -0.75},
    rotation={0,0,0},
    width=1200, height=520, font_size=160,
    tooltip="Restores saved layout."
  })

  -- Row 2 (one long button)
  self.createButton({
    label="SAT: COLLECT",
    click_function="sat_collect",
    function_owner=self,
    position={0, Y, -1.35},
    rotation={0,0,0},
    width=2600, height=420, font_size=170,
    tooltip="Collects SAT_TOKEN tokens near Control Panel"
  })

  -- Main menu
  if not menuOpen then
    self.createButton({
      label="NEW GAME",
      click_function="toggleMenu",
      function_owner=self,
      position={0, Y, 0.05},
      rotation={0,0,0},
      width=2600, height=700, font_size=240,
      tooltip="Choose start: Youth or Adult"
    })
    return
  end

  -- Youth/Adult very big
  self.createButton({
    label="YOUTH",
    click_function="newGameYouth",
    function_owner=self,
    position={-0.62, Y, 0.05},
    rotation={0,0,0},
    width=1200, height=700, font_size=220,
      tooltip="Start from round 1 (Youth) + SAT=10"
  })

  self.createButton({
    label="ADULT",
    click_function="newGameAdult",
    function_owner=self,
    position={0.62, Y, 0.05},
    rotation={0,0,0},
    width=1200, height=700, font_size=220,
      tooltip="Start from round 6 (Adult) + SAT=10 + Adult start mechanics"
  })

  self.createButton({
    label="BACK",
    click_function="toggleMenu",
    function_owner=self,
    position={0, Y, 0.85},
    rotation={0,0,0},
    width=1100, height=420, font_size=200,
      tooltip="BACK"
  })
end

function toggleMenu()
  menuOpen = not menuOpen
  drawMenu()
end
