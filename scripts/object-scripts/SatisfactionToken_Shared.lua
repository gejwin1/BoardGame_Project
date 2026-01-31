-- =========================
-- SATISFACTION TOKEN v2.4 (staggered move + anti-collision)
-- Buttons: -5, -1, +1, +5
-- Persistent value
-- External API:
--   addSat({delta=+/-N})
--   getSatValue()
--   setSatValue({value=N})
--   resetToStart({slot=0..3})
-- =========================

local BOARD_GUID = "c2d811"
local MIN_VAL = 0
local MAX_VAL = 100
local START_VAL = 10
local Y_OFFSET = 0.25

local DEBUG = false

-- Opóźnienie pomiędzy tokenami (żeby nie leciały w to samo miejsce jednocześnie)
local MOVE_GAP = 0.35
-- Jak długo trzymamy lock podczas ruchu
local LOCK_TIME = 0.70

local value = START_VAL

-- Anchory (local positions on board)
local p0, p9, p10, p11, p100 = nil, nil, nil, nil, nil

-- kolejka ruchu
local moveScheduled = false
local pendingValue = nil

-- ===== HELPERS =====
local function log(msg)
    if DEBUG then print("[SAT TOKEN]["..(self.getName() or self.getGUID() or "?").."] "..tostring(msg)) end
end

local function warn(msg)
    print("[SAT TOKEN][WARN]["..(self.getName() or self.getGUID() or "?").."] "..tostring(msg))
end

local function getBoard()
    local obj = getObjectFromGUID(BOARD_GUID)
    if not obj then
        warn("Brak SatisfactionBoard – sprawdź BOARD_GUID="..tostring(BOARD_GUID))
        return nil
    end
    return obj
end

local function clamp(v)
    v = tonumber(v)
    if not v then return START_VAL end
    if v < MIN_VAL then return MIN_VAL end
    if v > MAX_VAL then return MAX_VAL end
    return v
end

local function anchorsOk()
    return (p0 and p9 and p10 and p11 and p100)
end

local function tryFetchAnchorsFromBoard()
    local board = getBoard()
    if not board or not board.call then return false end

    local ok, a = pcall(function() return board.call("getSatAnchors") end)
    if ok and type(a) == "table" then
        if a.p0 and a.p9 and a.p10 and a.p11 and a.p100 then
            p0 = a.p0; p9 = a.p9; p10 = a.p10; p11 = a.p11; p100 = a.p100
            log("Fetched anchors from board.getSatAnchors() OK")
            return true
        end
    end

    local ok2, a2 = pcall(function() return board.getVar("SAT_ANCHORS") end)
    if ok2 and type(a2) == "table" then
        if a2.p0 and a2.p9 and a2.p10 and a2.p11 and a2.p100 then
            p0 = a2.p0; p9 = a2.p9; p10 = a2.p10; p11 = a2.p11; p100 = a2.p100
            log("Fetched anchors from board SAT_ANCHORS var OK")
            return true
        end
    end

    return false
end

-- Ustalenie slotu na podstawie tagów koloru
local function getSlotFromColorTag()
    -- Ustalona kolejność: Yellow, Red, Blue, Green
    if self.hasTag and self.hasTag("WLB_COLOR_Yellow") then return 0 end
    if self.hasTag and self.hasTag("WLB_COLOR_Red")    then return 1 end
    if self.hasTag and self.hasTag("WLB_COLOR_Blue")   then return 2 end
    if self.hasTag and self.hasTag("WLB_COLOR_Green")  then return 3 end
    return 0
end

-- ===== SAVE / LOAD =====
function onSave()
    return JSON.encode({
        value = value,
        p0 = p0, p9 = p9, p10 = p10, p11 = p11, p100 = p100
    })
end

function onLoad(saved)
    self.addTag("SAT_TOKEN")

    if saved and saved ~= "" then
        local ok, data = pcall(function() return JSON.decode(saved) end)
        if ok and type(data) == "table" then
            value = data.value
            p0 = data.p0; p9 = data.p9; p10 = data.p10; p11 = data.p11; p100 = data.p100
        end
    end

    value = clamp(value or START_VAL)

    if not anchorsOk() then
        local got = tryFetchAnchorsFromBoard()
        if not got then
            warn("Brak anchorów p0/p9/p10/p11/p100. Token będzie zmieniał VALUE, ale nie ruszy się po planszy.")
        end
    end

    self.clearButtons()
    createCompactButtons()

    -- Na load ustawiamy pozycję instant (bez fizyki i bez kolejki)
    moveToValueNow(value, true)
end

-- ===== UI =====
function createCompactButtons()
    btn("-5", "m5", {-0.30, 0.60, -0.24})
    btn("-1", "m1", { 0.30, 0.60, -0.24})
    btn("+1", "p1", {-0.30, 0.60,  0.24})
    btn("+5", "p5", { 0.30, 0.60,  0.24})
end

function btn(label, fn, pos)
    self.createButton({
        label = label,
        click_function = fn,
        function_owner = self,
        position = pos,
        rotation = {0,0,0},
        width = 540,
        height = 390,
        font_size = 210
    })
end

-- ===== Movement core =====

local function computeWorldPos(v)
    if not anchorsOk() then return nil end
    local board = getBoard(); if not board then return nil end

    local lp
    if v == 10 then
        lp = p10
    elseif v <= 9 then
        local dx = (p9.x - p0.x) / 9
        lp = {x = p0.x + dx * v, y = p0.y, z = p0.z}
    else
        local idx = v - 11
        local col = idx % 10
        local row = math.floor(idx / 10)
        local dx = (p9.x - p0.x) / 9
        local dz = (p100.z - p11.z) / 8
        lp = { x = p11.x + dx * col, y = p11.y, z = p11.z + dz * row }
    end

    return board.positionToWorld(Vector(lp.x, lp.y + Y_OFFSET, lp.z))
end

function moveToValueNow(v, instant)
    local wp = computeWorldPos(v)
    if not wp then return end

    -- anti-collision: lock token for the move
    self.setLock(true)

    if instant then
        self.setPosition(wp)
    else
        -- collide=false, fast=true (jak było), ale z lockiem i z rozjechaniem w czasie
        self.setPositionSmooth(wp, false, true)
    end

    Wait.time(function()
        if self and self.setLock then self.setLock(false) end
    end, LOCK_TIME)
end

local function scheduleMove()
    if moveScheduled then return end
    moveScheduled = true

    local slot = getSlotFromColorTag()
    local delay = (tonumber(slot) or 0) * MOVE_GAP

    Wait.time(function()
        moveScheduled = false
        if pendingValue ~= nil then
            local v = pendingValue
            pendingValue = nil
            moveToValueNow(v, false)
        end
    end, delay)
end

local function setValueInternal(v, instant)
    value = clamp(v)

    if instant then
        pendingValue = nil
        moveScheduled = false
        moveToValueNow(value, true)
        return
    end

    -- kolejkujemy: jeśli wpadnie kilka zmian, wykonamy tylko ostatnią
    pendingValue = value
    scheduleMove()
end

-- klikane
function m1() setValueInternal(value - 1, false) end
function p1() setValueInternal(value + 1, false) end
function m5() setValueInternal(value - 5, false) end
function p5() setValueInternal(value + 5, false) end

-- ===== External API =====
function addSat(params)
    local delta = 0
    if type(params) == "table" then delta = tonumber(params.delta) or tonumber(params.amount) or 0 end
    if type(params) == "number" then delta = params end

    setValueInternal(value + delta, false)
    log("addSat delta="..tostring(delta).." -> value="..tostring(value))
    return true
end

function getSatValue()
    return value
end

function setSatValue(params)
    local v = nil
    if type(params) == "table" then v = params.value end
    if type(params) == "number" then v = params end
    setValueInternal(v, false)
    return true
end

-- ===== RESET API =====
function resetToStart(params)
    local slot = 0
    if type(params) == "table" then
        slot = params.slot or params.i or 0
    end

    value = START_VAL

    if not anchorsOk() then
        tryFetchAnchorsFromBoard()
        if not anchorsOk() then return end
    end

    local board = getBoard(); if not board then return end

    local SPREAD = 1.60
    local BASE_Y = Y_OFFSET + 0.02

    local ox = (slot - 1.5) * SPREAD
    local oz = 0

    local base = p10
    local wp = board.positionToWorld(Vector(
        base.x + ox,
        base.y + BASE_Y,
        base.z + oz
    ))

    self.setLock(true)
    self.setPosition(wp)
    self.setRotation({0, 180, 0})

    Wait.time(function()
        if self and self.setLock then self.setLock(false) end
    end, 0.5)

    -- po reset niech też "wewnętrznie" zna wartość
    pendingValue = nil
    moveScheduled = false
end
