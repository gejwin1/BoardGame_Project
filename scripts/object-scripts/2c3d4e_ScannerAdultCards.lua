-- =========================
-- WLB - DECK TOOLS (Adult)
-- Purpose:
-- 1) Scan all AD_ cards (including inside decks) + loose cards
-- 2) Retag them deterministically
-- 3) Export names (no manual copying)
-- 4) Validate sequential numbering (AD_01 .. AD_81)
-- =========================

local CFG = {
    AD_PREFIX = "^AD_%d%d_",
    AD_TAG_CARD = "WLB_EVT_ADULT_CARD",
    AD_TAG_DECK = "WLB_DECK_ADULT",

    -- OPTIONAL: if you want strict expected count
    EXPECTED_AD_COUNT = 81,

    -- output settings
    BROADCAST_COLOR = {1, 1, 1},
}

-- internal cache
local cache = {
    cards = {},      -- [guid] = { name=..., src=..., idx=... }
    decks = {},      -- [guid] = deckObject
    names = {},      -- array of names
}

-- ---------- UI ----------
function onLoad()
    buildUI()
end

function buildUI()
    self.clearButtons()

    local x = -0.9
    local y = 0.55
    local w = 1800
    local h = 340
    local font = 180

    addBtn(0, x, y, w, h, "SCAN ADULT", "uiScanAdult", font); y = y - 0.45
    addBtn(1, x, y, w, h, "RETAG ADULT", "uiRetagAdult", font); y = y - 0.45
    addBtn(2, x, y, w, h, "EXPORT NAMES", "uiExportNames", font); y = y - 0.45
    addBtn(3, x, y, w, h, "CHECK SEQ", "uiCheckSeq", font)
end

function addBtn(i, x, y, w, h, label, fn, font)
    self.createButton({
        index = i,
        label = label,
        click_function = fn,
        function_owner = self,
        position = {x, 0.2, y},
        rotation = {0, 180, 0},
        width = w,
        height = h,
        font_size = font,
        color = {0.15, 0.15, 0.15},
        font_color = {1, 1, 1},
    })
end

-- ---------- Scanning ----------
local function resetCache()
    cache.cards = {}
    cache.decks = {}
    cache.names = {}
end

local function isAdultName(n)
    if not n then return false end
    return string.match(n, CFG.AD_PREFIX) ~= nil
end

local function addCardEntry(guid, name, src)
    if not guid or guid == "" then return end
    if not name then name = "" end
    if not cache.cards[guid] then
        cache.cards[guid] = { name = name, src = src or "unknown" }
        table.insert(cache.names, name)
    end
end

local function scanLooseObjects()
    local all = getAllObjects()
    for _, obj in ipairs(all) do
        local t = obj.tag
        if t == "Card" then
            local n = obj.getName()
            if isAdultName(n) then
                addCardEntry(obj.getGUID(), n, "loose")
            end
        elseif t == "Deck" then
            -- we don't know if deck is Adult until we inspect its contained objects
            local deckObjs = obj.getObjects()
            local adultCount = 0
            for _, entry in ipairs(deckObjs) do
                local n = entry.nickname or ""
                if isAdultName(n) then
                    adultCount = adultCount + 1
                end
            end

            if adultCount > 0 then
                cache.decks[obj.getGUID()] = obj
                -- also add all adult cards inside (by nickname)
                for _, entry in ipairs(deckObjs) do
                    local n = entry.nickname or ""
                    if isAdultName(n) then
                        -- NOTE: entries in deck don't have GUIDs until taken out
                        -- For export/check we use names anyway.
                        table.insert(cache.names, n)
                    end
                end
            end
        end
    end
end

local function scanAdult()
    resetCache()
    scanLooseObjects()

    -- de-duplicate names list while preserving order
    local seen = {}
    local uniq = {}
    for _, n in ipairs(cache.names) do
        if n and n ~= "" and not seen[n] then
            seen[n] = true
            table.insert(uniq, n)
        end
    end
    cache.names = uniq
end

-- ---------- Actions ----------
function uiScanAdult(_, playerColor)
    scanAdult()
    local c = countAdultCardsByNames(cache.names)

    broadcast(playerColor, "SCAN ADULT: found "..tostring(c).." unique AD_ card names (decks + loose).")
    if CFG.EXPECTED_AD_COUNT and c ~= CFG.EXPECTED_AD_COUNT then
        broadcast(playerColor, "WARNING: expected "..tostring(CFG.EXPECTED_AD_COUNT).." but found "..tostring(c)..".")
    end
end

function uiRetagAdult(_, playerColor)
    scanAdult()

    -- Retag loose cards only (decks contained cards cannot be tagged until they are objects)
    local retagged = 0
    for guid, entry in pairs(cache.cards) do
        local obj = getObjectFromGUID(guid)
        if obj and obj.tag == "Card" then
            obj.addTag(CFG.AD_TAG_CARD)
            retagged = retagged + 1
        end
    end

    -- Tag adult decks
    local deckTagged = 0
    for guid, deck in pairs(cache.decks) do
        if deck and deck.tag == "Deck" then
            deck.addTag(CFG.AD_TAG_DECK)
            deckTagged = deckTagged + 1
        end
    end

    broadcast(playerColor, "RETAG ADULT: tagged "..tostring(retagged).." loose cards with "..CFG.AD_TAG_CARD.." and "..tostring(deckTagged).." decks with "..CFG.AD_TAG_DECK..".")
    broadcast(playerColor, "NOTE: cards inside a deck don't exist as separate objects, so tagging them directly isn't possible until they are taken out.")
end

function uiExportNames(_, playerColor)
    scanAdult()
    table.sort(cache.names)

    local lines = {}
    table.insert(lines, "=== ADULT CARD NAMES (sorted) ===")
    for i, n in ipairs(cache.names) do
        table.insert(lines, string.format("%03d) %s", i, n))
    end
    table.insert(lines, "TOTAL: "..tostring(#cache.names))

    local msg = table.concat(lines, "\n")
    print(msg)
    broadcast(playerColor, "EXPORT NAMES: printed "..tostring(#cache.names).." names to console log (and as multi-line print).")
end

function uiCheckSeq(_, playerColor)
    scanAdult()

    -- Build map number -> occurrences
    local numMap = {}
    local bad = {}

    for _, n in ipairs(cache.names) do
        local numStr = string.match(n, "^AD_(%d%d)_")
        if not numStr then
            table.insert(bad, n)
        else
            local num = tonumber(numStr)
            if num then
                numMap[num] = (numMap[num] or 0) + 1
            else
                table.insert(bad, n)
            end
        end
    end

    local missing = {}
    local dupes = {}
    local maxN = CFG.EXPECTED_AD_COUNT or 81

    for i = 1, maxN do
        local c = numMap[i] or 0
        if c == 0 then table.insert(missing, i) end
        if c > 1 then table.insert(dupes, {i=i, c=c}) end
    end

    broadcast(playerColor, "CHECK SEQ: expected AD_01..AD_"..string.format("%02d", maxN)..".")
    if #bad > 0 then
        print("BAD NAMES (not matching AD_XX_):")
        for _, n in ipairs(bad) do print(" - "..n) end
        broadcast(playerColor, "WARNING: "..tostring(#bad).." names do not match AD_XX_ pattern (see console).")
    end

    if #missing > 0 then
        print("MISSING NUMBERS:")
        for _, i in ipairs(missing) do print(string.format(" - %02d", i)) end
        broadcast(playerColor, "MISSING: "..tostring(#missing).." numbers (see console).")
    else
        broadcast(playerColor, "MISSING: none ✅")
    end

    if #dupes > 0 then
        print("DUPLICATE NUMBERS:")
        for _, d in ipairs(dupes) do print(string.format(" - %02d occurs %d times", d.i, d.c)) end
        broadcast(playerColor, "DUPLICATES: "..tostring(#dupes).." numbers duplicated (see console).")
    else
        broadcast(playerColor, "DUPLICATES: none ✅")
    end

    broadcast(playerColor, "TOTAL UNIQUE NAMES: "..tostring(#cache.names))
end

-- ---------- Helpers ----------
function broadcast(playerColor, msg)
    if playerColor and Player[playerColor] then
        Player[playerColor].broadcast(msg, CFG.BROADCAST_COLOR)
    else
        print(msg)
        printToAll(msg, CFG.BROADCAST_COLOR)
    end
end

function countAdultCardsByNames(names)
    local c = 0
    for _, n in ipairs(names) do
        if isAdultName(n) then c = c + 1 end
    end
    return c
end
