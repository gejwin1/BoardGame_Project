-- =========================================================
-- WLB VOCATIONS CONTROLLER v1.0.0
-- GOAL: Track player vocations, levels, and promotion progress
-- Manages vocation selection, tile placement, work income, and promotions
-- =========================================================

local DEBUG = true
local VERSION = "1.0.0"

-- =========================================================
-- TAGS
-- =========================================================
local TAG_SELF = "WLB_VOCATIONS_CTRL"
local TAG_BOARD = "WLB_BOARD"
local TAG_VOCATION_TILE = "WLB_VOCATION_TILE"
local COLOR_TAG_PREFIX = "WLB_COLOR_"
local TAG_TURN_CTRL = "WLB_TURN_CTRL"
local TAG_STATS_CTRL = "WLB_STATS_CTRL"
local TAG_AP_CTRL = "WLB_AP_CTRL"
local TAG_MONEY = "WLB_MONEY"

local COLORS = {"Yellow", "Blue", "Red", "Green"}

-- =========================================================
-- VOCATION CONSTANTS
-- =========================================================
local VOC_PUBLIC_SERVANT = "PUBLIC_SERVANT"
local VOC_CELEBRITY = "CELEBRITY"
local VOC_SOCIAL_WORKER = "SOCIAL_WORKER"
local VOC_GANGSTER = "GANGSTER"
local VOC_ENTREPRENEUR = "ENTREPRENEUR"
local VOC_NGO_WORKER = "NGO_WORKER"

local ALL_VOCATIONS = {
  VOC_PUBLIC_SERVANT,    -- "PUBLIC_SERVANT"
  VOC_CELEBRITY,         -- "CELEBRITY"
  VOC_SOCIAL_WORKER,     -- "SOCIAL_WORKER"
  VOC_GANGSTER,          -- "GANGSTER"
  VOC_ENTREPRENEUR,      -- "ENTREPRENEUR"
  VOC_NGO_WORKER,        -- "NGO_WORKER"
}

-- Vocation card image URLs (from selection panel buttons)
local VOCATION_IMAGES = {
  [VOC_PUBLIC_SERVANT] = "https://steamusercontent-a.akamaihd.net/ugc/10392559236544991035/C6BAE73B4680AEA8725F7535B8B22722049C9F2C/",
  [VOC_CELEBRITY] = "https://steamusercontent-a.akamaihd.net/ugc/9313197015274600451/3A5C87686AFB80F5066B04C0E49FD921678122AD/",
  [VOC_SOCIAL_WORKER] = "https://steamusercontent-a.akamaihd.net/ugc/14603143457404129563/3BD34A2BFB5BBE8439CD618BC71B897622B06723/",
  [VOC_GANGSTER] = "https://steamusercontent-a.akamaihd.net/ugc/11270667329628070372/E9ABCD6EF148388B0550D54DB5C9C87639660566/",
  [VOC_ENTREPRENEUR] = "https://steamusercontent-a.akamaihd.net/ugc/15721746676026378582/E9AE12F01BF052F5C565A331E6164B1E5F81AF57/",
  [VOC_NGO_WORKER] = "https://steamusercontent-a.akamaihd.net/ugc/15161606966614937150/C0417B3848A1F1D06E92207213881A63EEC04352/",
}

-- Level 1 vocation card GUIDs (physical cards player picks from)
local VOC_LEVEL1_CARD_GUID = {
  [VOC_PUBLIC_SERVANT] = "1d3306",
  [VOC_SOCIAL_WORKER] = "24b50d",
  [VOC_GANGSTER] = "197dbb",
  [VOC_ENTREPRENEUR] = "650a1c",
  [VOC_NGO_WORKER] = "5ca95c",
  [VOC_CELEBRITY] = "3d7a01",
}

-- Full explanation card GUIDs (reference cards with full vocation details)
local VOC_EXPLANATION_CARD_GUID = {
  [VOC_GANGSTER] = "de1ca1",
  [VOC_PUBLIC_SERVANT] = "e9f577",
  [VOC_CELEBRITY] = "bf63ee",
  [VOC_SOCIAL_WORKER] = "36a382",
  [VOC_ENTREPRENEUR] = "d2b30f",
  [VOC_NGO_WORKER] = "595084",
}

-- Explanation picture URLs for the Global UI summary (after picking a vocation).
-- Add your image links here; leave empty to fall back to VOCATION_IMAGES (card art).
local VOCATION_EXPLANATION_IMAGE = {
  [VOC_PUBLIC_SERVANT] = "https://steamusercontent-a.akamaihd.net/ugc/11440077369821407359/F91EFBFA3906EC48F9739225207B04249E217B45/",
  [VOC_CELEBRITY] = "https://steamusercontent-a.akamaihd.net/ugc/15842791840777541847/D6AD9C9870CDC60BC172874ECAA11F5C8E124F28/",
  [VOC_SOCIAL_WORKER] = "https://steamusercontent-a.akamaihd.net/ugc/10641833055364341103/00D6E1B6734EBC22EECB4360289CD22F1B603FC3/",
  [VOC_GANGSTER] = "https://steamusercontent-a.akamaihd.net/ugc/13152719458524444078/B04656463B4181081841A5670597EFF2F41C187E/",
  [VOC_ENTREPRENEUR] = "https://steamusercontent-a.akamaihd.net/ugc/16795266523463767199/C1FAABC9AA762914819125E4C59865F6F23676E8/",
  [VOC_NGO_WORKER] = "https://steamusercontent-a.akamaihd.net/ugc/15161606966614937150/C0417B3848A1F1D06E92207213881A63EEC04352/",
}

-- Selection card image URLs (shown when player has chosen a vocation on the summary screen).
local VOCATION_SELECTION_CARD_IMAGE = {
  [VOC_GANGSTER] = "https://steamusercontent-a.akamaihd.net/ugc/9894880456177855273/3D5A59699938A36C09124FD69811AF79732DDE9D/",
  [VOC_NGO_WORKER] = "https://steamusercontent-a.akamaihd.net/ugc/16912365033054427398/B55921DBD756A2AF4A3FE4B89F2C7D580DDDEC0B/",
  [VOC_PUBLIC_SERVANT] = "https://steamusercontent-a.akamaihd.net/ugc/17637544505239532230/4B793D58020C59CDD36E08FEB4D3B47ABDD0C121/",
  [VOC_CELEBRITY] = "https://steamusercontent-a.akamaihd.net/ugc/13680959911826208089/A48AE5817D00BC09F2A76823E43C0C5290D19CB8/",
  [VOC_SOCIAL_WORKER] = "https://steamusercontent-a.akamaihd.net/ugc/17468286109764365863/1135E73AB4BEAC2CE40B14CE29302DCC2DCEF068/",
  [VOC_ENTREPRENEUR] = "https://steamusercontent-a.akamaihd.net/ugc/11454490895890466202/C2C67D02CA477C809D7E74D98D36721560B5697D/",
}

-- =========================================================
-- CHARACTER SLOT POSITION (from scanner)
-- =========================================================
-- Measured by `VOC_SCANNER` (local position on the player board object).
-- Screenshot: Yellow measured {5.717, 0.592, -0.442} (error: 0.000)
-- Assumption (per your note): same local position for every player board.
local CHARACTER_SLOT_LOCAL = {
  Yellow = {x=5.717, y=0.592, z=-0.442},
  Blue   = {x=5.717, y=0.592, z=-0.442},
  Red    = {x=5.717, y=0.592, z=-0.442},
  Green  = {x=5.717, y=0.592, z=-0.442},
}

-- Storage position for tiles (when not on board)
-- Storage position for tiles (when not on board)
-- You requested to avoid the middle of the table. We store relative to the TABLE object:
-- Update: better solution — store vocation tiles ON the VocationsController object itself.
-- This makes the storage deterministic and always visible.
-- Store as ONE tidy stack (tower) on top of this controller.
local STORAGE_LOCAL_ORIGIN = {x=0.0, y=0.55, z=0.0}   -- center of controller, slightly above
local STORAGE_STACK_LIFT   = 0.12                     -- extra Y per tile (keeps stack stable)
local STORAGE_STACK_DELAY  = 0.08                     -- delay between placements (reduces physics jitter)

local function getVocationStorageWorldPosForIndex(i)
  i = tonumber(i) or 1
  if i < 1 then i = 1 end

  local localPos = {
    x = STORAGE_LOCAL_ORIGIN.x,
    y = STORAGE_LOCAL_ORIGIN.y + ((i - 1) * STORAGE_STACK_LIFT),
    z = STORAGE_LOCAL_ORIGIN.z,
  }

  if self and self.positionToWorld then
    local ok, wp = pcall(function()
      return self.positionToWorld(localPos)
    end)
    if ok and wp then
      -- Ensure tiles are clearly above the controller
      wp.y = math.max(wp.y, (self.getPosition and self.getPosition().y or wp.y) + STORAGE_LOCAL_ORIGIN.y + ((i - 1) * STORAGE_STACK_LIFT))
      return wp
    end
  end

  -- Fallback: somewhere above table origin
  return {0, 5, 0}
end

local function parkTileOnController(obj, idx)
  if not obj then return end
  local wp = getVocationStorageWorldPosForIndex(idx)

  -- Place deterministically and prevent physics from piling them up.
  pcall(function() if obj.setLock then obj.setLock(false) end end)
  pcall(function() if obj.setVelocity then obj.setVelocity({0,0,0}) end end)
  pcall(function() if obj.setAngularVelocity then obj.setAngularVelocity({0,0,0}) end end)

  -- Prefer instant position for stability.
  pcall(function()
    if obj.setPosition then
      obj.setPosition(wp)
    else
      obj.setPositionSmooth(wp, false, true)
    end
  end)

  -- Align rotation to controller (optional; helps with neat look)
  pcall(function()
    if self and self.getRotation and obj.setRotation then
      local r = self.getRotation()
      obj.setRotation({0, r.y or 0, 0})
    end
  end)

  -- Lock after a short delay so it settles first
  if Wait and Wait.time and obj.setLock then
    Wait.time(function()
      pcall(function() obj.setLock(true) end)
    end, 0.15)
  else
    pcall(function() if obj.setLock then obj.setLock(true) end end)
  end
end

local function countTilesNearStorage()
  -- Best-effort: count vocation tiles already near the stack origin (so single returns stack on top)
  local origin = getVocationStorageWorldPosForIndex(1)
  local count = 0
  for _, obj in ipairs(getAllObjects()) do
    -- Guard: some TTS objects (e.g. bags, dice) may not have callable hasTag
    if obj and type(obj.hasTag) == "function" and obj.getPosition and (obj.hasTag(TAG_VOCATION_TILE) or obj.hasTag("WLB_VOCATION_TILE")) then
      -- Ignore currently assigned-to-player tiles
      local hasColor = false
      for _, c in ipairs(COLORS) do
        local ok, has = pcall(function() return obj.hasTag(colorTag(c)) end)
        if ok and has then hasColor = true break end
      end
      if not hasColor then
        local ok, p = pcall(function() return obj.getPosition() end)
        if ok and p then
          local dx = (p.x or 0) - (origin.x or 0)
          local dz = (p.z or 0) - (origin.z or 0)
          if (dx*dx + dz*dz) < 0.9 then
            count = count + 1
          end
        end
      end
    end
  end
  return count
end

-- Selection UI positions (WORLD coordinates - center of table)
local SELECTION_AREA_CENTER = {x=0, y=2.0, z=0}  -- Center of table, elevated high for visibility
local SELECTION_TILE_SPACING = 3.0  -- Space between selection tiles (increased for better visibility)
local SUMMARY_DISPLAY_POS = {x=0, y=2.5, z=0}  -- Summary tile display position (elevated)
local STORAGE_SELECTION = {x=0, y=5, z=5}  -- Storage for selection tiles
local STORAGE_SUMMARY = {x=0, y=5, z=6}  -- Storage for summary tiles
local STORAGE_EXPLANATION = {x=0, y=5, z=7}  -- Storage for explanation cards when not displayed

-- Offsets from Vocations Controller (local space) for placing Level 1 cards and explanation card
local LEVEL1_CARDS_OFFSET_X = 3.0   -- Distance to the side of controller
local LEVEL1_CARDS_Z_SPACING = 1.4  -- Spacing between cards in row
local EXPLANATION_CARD_OFFSET_X = 4.5  -- Explanation card further out from controller

-- Selection state
local selectionState = {
  activeColor = nil,  -- Which player is currently selecting
  shownSummary = nil,  -- Which summary tile is currently shown
  shownVocation = nil,  -- Which vocation summary is shown
  shownExplanationCard = nil,  -- Reference card with full vocation explanation (by GUID)
  selectionTiles = {},  -- Level 1 tiles shown for selection
  level1Cards = {},  -- Level 1 card objects placed for selection (for cleanup)
  level1OriginalPositions = {},  -- Original positions to return cards to
}

-- Selection UI positions
local SELECTION_AREA = {
  center = {x=0, y=1.0, z=0},  -- Center of table, elevated
  spacing = 2.5,  -- Space between tiles (X axis)
  rowY = 1.0,  -- Y position for selection row
}

local SUMMARY_POSITION = {
  center = {x=0, y=1.5, z=0},  -- Center, elevated for visibility
}


-- =========================================================
-- VOCATION DATA STRUCTURE
-- =========================================================
local VOCATION_DATA = {
  [VOC_PUBLIC_SERVANT] = {
    name = "Public Servant",
    levels = {
      [1] = {
        jobTitle = "Junior Clerk",
        salary = 100,  -- VIN per AP
        promotion = {
          type = "standard",  -- standard, work_based, award
          knowledge = 8,
          skills = 4,
          experience = 2,  -- years
        },
      },
      [2] = {
        jobTitle = "Administrative Officer",
        salary = 200,
        promotion = {
          type = "standard",
          knowledge = 12,
          skills = 6,
          experience = 3,
        },
      },
      [3] = {
        jobTitle = "Office Director",
        salary = 300,
        promotion = {
          type = "award",
          knowledge = 15,
          skills = 7,
          awardCondition = "Successfully collect taxes TWO times at any level",
        },
      },
    },
  },
  
  [VOC_NGO_WORKER] = {
    name = "NGO Worker",
    levels = {
      [1] = {
        jobTitle = "NGO Volunteer",
        salary = 80,
        promotion = {
          type = "standard",
          knowledge = 7,
          skills = 5,
          experience = 3,
        },
      },
      [2] = {
        jobTitle = "Project Coordinator",
        salary = 240,
        promotion = {
          type = "standard",
          knowledge = 11,
          skills = 9,
          experience = 2,
        },
      },
      [3] = {
        jobTitle = "NGO Owner",
        salary = 450,
        promotion = {
          type = "award",
          knowledge = 12,
          skills = 10,
          awardCondition = "Complete 2 social campaigns OR 1 social campaign + 10 AP volunteering work",
        },
      },
    },
  },
  
  [VOC_ENTREPRENEUR] = {
    name = "Entrepreneur",
    levels = {
      [1] = {
        jobTitle = "Shop Assistant",
        salary = 150,
        promotion = {
          type = "standard",
          knowledge = 7,
          skills = 8,
          experience = 2,
        },
      },
      [2] = {
        jobTitle = "Manager",
        salary = 300,
        promotion = {
          type = "standard",
          knowledge = 7,
          skills = 11,
          experience = 3,
        },
      },
      [3] = {
        jobTitle = "Hi-Tech Company Owner",
        salary = 500,
        promotion = {
          type = "award",
          knowledge = 9,
          skills = 13,
          awardCondition = "Buy a level 3 or level 4 house + 2 High-Tech items",
        },
      },
    },
  },
  
  [VOC_GANGSTER] = {
    name = "Gangster",
    levels = {
      [1] = {
        jobTitle = "Thug",
        salary = 80,
        promotion = {
          type = "standard",
          knowledge = 3,
          skills = 10,
          experience = 3,
        },
      },
      [2] = {
        jobTitle = "Gangster",
        salary = 200,
        promotion = {
          type = "standard",
          knowledge = 8,
          skills = 11,
          experience = 2,
        },
      },
      [3] = {
        jobTitle = "Head of the Gang",
        salary = 450,
        promotion = {
          type = "award",
          knowledge = 9,
          skills = 13,
          awardCondition = "Commit 2 crimes without getting caught (or complete 3 including getting caught once)",
        },
      },
    },
  },
  
  [VOC_CELEBRITY] = {
    name = "Celebrity",
    levels = {
      [1] = {
        jobTitle = "Aspiring Streamer",
        salary = 30,
        promotion = {
          type = "work_based",
          knowledge = 3,
          skills = 8,
          workAP = 10,  -- Must work 10 AP on this level
        },
      },
      [2] = {
        jobTitle = "Rising Influencer",
        salary = 150,
        promotion = {
          type = "work_based",
          knowledge = 5,
          skills = 12,
          workAP = 10,
        },
      },
      [3] = {
        jobTitle = "Superstar Icon",
        salary = 800,
        promotion = {
          type = "work_based",
          knowledge = 7,
          skills = 15,
          workAP = 10,
          additionalCost = 4000,  -- Must pay 4000 VIN
        },
      },
    },
  },
  
  [VOC_SOCIAL_WORKER] = {
    name = "Social Worker",
    levels = {
      [1] = {
        jobTitle = "Community Assistant",
        salary = 70,
        promotion = {
          type = "standard",
          knowledge = 6,
          skills = 6,
          experience = 2,
        },
      },
      [2] = {
        jobTitle = "Family Care Specialist",
        salary = 150,
        promotion = {
          type = "standard",
          knowledge = 9,
          skills = 9,
          experience = 2,
        },
      },
      [3] = {
        jobTitle = "Senior Social Protector",
        salary = 250,
        promotion = {
          type = "award",
          knowledge = 10,  -- Note: Analysis doc says "10" but Level 3 doesn't have promotion, it's award-based
          skills = 10,
          awardCondition = "Successfully conduct TWO community events with at least ONE participant each",
        },
      },
    },
  },
}

-- =========================================================
-- STATE
-- =========================================================
local state = {
  vocations = { Yellow=nil, Blue=nil, Red=nil, Green=nil },
  currentPickerColor = nil, -- which player is currently in vocation picker UI
  levels = { Yellow=1, Blue=1, Red=1, Green=1 },
  workAP = { Yellow=0, Blue=0, Red=0, Green=0 },  -- Cumulative AP spent on work
  workAPThisLevel = { Yellow=0, Blue=0, Red=0, Green=0 },  -- AP spent on work at current level (for Celebrity)
  levelUpRound = { Yellow=nil, Blue=nil, Red=nil, Green=nil },  -- Round when player reached current vocation level (for Time/Experience)
}

-- =========================================================
-- UTILS
-- =========================================================
local function log(msg)
  if DEBUG then print("[VOC_CTRL] " .. tostring(msg)) end
end

local function warn(msg)
  print("[VOC_CTRL][WARN] " .. tostring(msg))
end

local function safeBroadcastAll(msg, rgb)
  pcall(function() broadcastToAll(tostring(msg), rgb or {1,1,1}) end)
end

-- Safe broadcast function: checks if player exists before broadcasting
local function safeBroadcastToColor(msg, color, rgb)
  if not color or color == "" then
    broadcastToAll("[VOC] " .. tostring(msg), rgb or {1, 1, 1})
    return
  end
  
  -- Check if player exists
  local ok, player = pcall(function()
    return Player[color]
  end)
  
  if ok and player and player.seated then
    -- Player exists and is seated, use broadcastToColor
    pcall(function()
      broadcastToColor(tostring(msg), color, rgb or {1, 1, 1})
    end)
  else
    -- Player doesn't exist or isn't seated, use broadcastToAll with prefix
    broadcastToAll("[" .. tostring(color) .. "] " .. tostring(msg), rgb or {1, 1, 1})
  end
end

local function normalizeColor(color)
  if not color then return nil end
  color = tostring(color)

  -- Remove "Player " prefix if present
  if string.sub(color, 1, 7) == "Player " then
    color = string.sub(color, 8)
  end

  -- ✅ Allow White (host/spectator clicks in Global UI)
  if color == "White" then return "White" end

  -- Check if valid player color
  for _, c in ipairs(COLORS) do
    if c == color then return c end
  end
  return nil
end

local function colorTag(color)
  return COLOR_TAG_PREFIX .. tostring(color)
end

-- Generic helper: find first object with all given tags
local function findByTags(tags)
  local all = getAllObjects()
  for _, o in ipairs(all) do
    local ok = true
    for _, t in ipairs(tags) do
      if not (o and o.hasTag and o.hasTag(t)) then
        ok = false
        break
      end
    end
    if ok then return o end
  end
  return nil
end

-- AP helpers (EVENT/Events area = "E")
local function findApCtrlForColor(color)
  color = normalizeColor(color)
  if not color then return nil end
  return findByTags({ TAG_AP_CTRL, colorTag(color) })
end

local function getApUnspentCount(color)
  local ap = findApCtrlForColor(color)
  if not ap or not ap.call then return 0 end

  local candidates = {
    function() return ap.call("getUnspentCount") end,
    function() return ap.call("getUnspentAP") end,
    function() return ap.call("countUnspent") end,
  }

  for _, fn in ipairs(candidates) do
    local ok, res = pcall(fn)
    if ok and type(res) == "number" then
      return math.max(0, math.floor(res))
    end
  end

  warn("AP_CTRL for "..tostring(color).." has no unspent getter.")
  return 0
end

local function canSpendAP(color, amount)
  local ap = findApCtrlForColor(color)
  if not ap or not ap.call then
    warn("AP controller not found for "..tostring(color))
    return false
  end
  local ok, can = pcall(function()
    return ap.call("canSpendAP", { to = "E", amount = amount })
  end)
  return ok and (can == true or can == "true")
end

local function spendAP(color, amount, reason)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end
  local ap = findApCtrlForColor(color)
  if not ap or not ap.call then
    warn("AP controller not found for "..tostring(color))
    safeBroadcastToColor("⚠️ No AP controller — cannot deduct "..tostring(amount).." AP ("..tostring(reason)..").", color, {1,0.7,0.2})
    return false
  end
  local ok, paid = pcall(function()
    return ap.call("spendAP", { to = "E", amount = amount })
  end)
  return ok and (paid == true or paid == "true")
end

-- Satisfaction helpers (copied from ShopEngine)
local SAT_TOKEN_GUIDS = {
  Yellow = "d33a15",
  Red    = "6fe69b",
  Blue   = "b2b5e3",
  Green  = "e8834c",
}

local function getSatToken(color)
  local guid = SAT_TOKEN_GUIDS[tostring(color or "")]
  if not guid then
    warn("SAT GUID missing for color="..tostring(color))
    return nil
  end
  local obj = getObjectFromGUID(guid)
  if not obj then
    warn("SAT token GUID not found: "..tostring(color).." guid="..tostring(guid))
    return nil
  end
  return obj
end

local function satAdd(color, amount)
  amount = tonumber(amount) or 0
  if amount == 0 then return true end

  local satObj = getSatToken(color)
  if not satObj then
    safeBroadcastAll("⚠️ SAT +"..tostring(amount).." for "..tostring(color).." (SAT token not found)", {1,0.7,0.2})
    return false
  end

  pcall(function()
    if satObj.setLock then satObj.setLock(false) end
  end)

  local ok = false
  if satObj.call then
    ok = pcall(function() satObj.call("addSat", { delta = amount }) end)
  end

  if not ok and satObj.call then
    local stepFn = (amount >= 0) and "p1" or "m1"
    local n = math.abs(amount)
    for _=1,n do
      local ok2 = pcall(function() satObj.call(stepFn) end)
      if not ok2 then
        warn("SAT CALL FAILED: "..tostring(stepFn))
        safeBroadcastAll("⚠️ SAT +"..tostring(amount).." for "..tostring(color).." (SAT API call failed)", {1,0.7,0.2})
        return false
      end
    end
    ok = true
  end

  if not ok then
    safeBroadcastAll("⚠️ SAT +"..tostring(amount).." for "..tostring(color).." (SAT API not working)", {1,0.7,0.2})
  end

  return ok
end

-- Turn helpers (active player)
local function getActiveTurnColor()
  if not (Turns and Turns.turn_color and Turns.turn_color ~= "") then
    return nil
  end
  return normalizeColor(Turns.turn_color)
end

local function getActorColor()
  local c = getActiveTurnColor()
  if not c then
    warn("No active player from Turns.turn_color. Action blocked.")
    broadcastToAll("[VOC] ⛔ No active player with Turns.turn_color. Enable Turns and set turn.", {1,0.6,0.2})
    return nil
  end
  return c
end

local function findPlayerBoard(color)
  color = normalizeColor(color)
  if not color then return nil end
  
  local list = getObjectsWithTag(colorTag(color)) or {}
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag(TAG_BOARD) then
      return o
    end
  end
  return nil
end

local function findStatsController(color)
  color = normalizeColor(color)
  if not color then return nil end
  
  local list = getObjectsWithTag(colorTag(color)) or {}
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag("WLB_STATS_CTRL") then
      return o
    end
  end
  return nil
end

-- Year/Round token: used for Time (experience in rounds) for promotion
local YEAR_TOKEN_TAG = "WLB_YEAR"
local function findYearToken()
  local list = getAllObjects()
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag(YEAR_TOKEN_TAG) then return o end
  end
  return nil
end
local function getCurrentRound()
  local yt = findYearToken()
  if not yt or not yt.call then return 1 end
  local ok, r = pcall(function() return yt.call("getRound") end)
  if ok and type(r) == "number" and r >= 1 then return r end
  return 1
end

-- Helper to find Turn Controller
local function getTurnCtrl()
  -- First try by tag
  local allObjects = getAllObjects()
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and obj.hasTag(TAG_TURN_CTRL) then
      return obj
    end
  end
  
  -- Fallback: try to find by function name (API_GetSciencePoints)
  for _, obj in ipairs(allObjects) do
    if obj and obj.call then
      local ok, result = pcall(function()
        return obj.call("API_GetSciencePoints", {color = "Yellow"})
      end)
      if ok and type(result) == "number" then
        log("getTurnCtrl: Found TurnController by function name (fallback)")
        return obj
      end
    end
  end
  
  return nil
end

-- Get science points for a color by querying Turn Controller
local function getSciencePointsForColor(color)
  color = normalizeColor(color)
  if not color then return 0 end
  
  local turnCtrl = getTurnCtrl()
  if not turnCtrl or not turnCtrl.call then
    log("getSciencePointsForColor: Turn Controller not found")
    return 0
  end
  
  local ok, points = pcall(function()
    return turnCtrl.call("API_GetSciencePoints", {color = color})
  end)
  
  if ok and type(points) == "number" then
    return points
  end
  
  log("getSciencePointsForColor: Failed to get science points for " .. color)
  return 0
end

-- =========================================================
-- INTERACTION STATE (multi-player vocation events)
-- =========================================================
local interaction = {
  active = false,
  id = nil,
  initiator = nil,
  responses = {},  -- [color] = "JOIN"/"IGNORE"/...
  targets = {},    -- [color] = true if should respond
  joinCostAP = 0,
  timer = 0,
}

local function updateInteractionTimerText()
  if not UI then return end
  if not interaction.active or (interaction.timer or 0) <= 0 then
    UI.setAttribute("interactionTimer", "text", "")
  else
    UI.setAttribute("interactionTimer", "text", "Time left: "..tostring(interaction.timer).."s")
  end
end

local function clearInteraction()
  interaction.active = false
  interaction.id = nil
  interaction.initiator = nil
  interaction.responses = {}
  interaction.targets = {}
  interaction.joinCostAP = 0
  interaction.timer = 0
  if UI then
    UI.setAttribute("interactionOverlay", "active", "false")
  end
  updateInteractionTimerText()
end

local function updateInteractionStatusText()
  if not UI then return end
  if not interaction.active then
    UI.setAttribute("interactionStatus", "text", "")
    return
  end
  local waiting = {}
  for _, c in ipairs(COLORS) do
    if interaction.targets[c] and not interaction.responses[c] then
      table.insert(waiting, c)
    end
  end
  local text
  if #waiting == 0 then
    text = "Waiting for: [none]"
  else
    text = "Waiting for: ["..table.concat(waiting, ", ").."]"
  end
  UI.setAttribute("interactionStatus", "text", text)
end

local function isPlayableColor(c)
  c = normalizeColor(c)
  if not c then return false end

  -- Primary source: TurnController's configured player colors (W.colors)
  local turnCtrl = findTurnController()
  if turnCtrl and turnCtrl.call then
    local ok, data = pcall(function() return turnCtrl.call("API_GetPlayerColors", {}) end)
    if ok and type(data) == "table" then
      for _, col in ipairs(data) do
        if normalizeColor(col) == c then
          return true
        end
      end
      -- If TurnController responded but this color is not listed, treat as non-playable.
      return false
    end
  end

  -- Fallback: no TurnController info – be conservative and only allow standard seated players.
  local ok, p = pcall(function() return Player[c] end)
  if ok and p and p.seated then
    return true
  end

  return false
end

local function resetInteractionButtonsForColor(color, active)
  if not UI then return end
  local idPrefix = "interaction"..color
  local joinId = idPrefix.."Join"
  local ignoreId = idPrefix.."Ignore"
  local val = active and "true" or "false"
  UI.setAttribute(joinId, "active", val)
  UI.setAttribute(ignoreId, "active", val)
  UI.setAttribute(joinId, "interactable", val)
  UI.setAttribute(ignoreId, "interactable", val)
end

local function setInteractionPanelVisibility()
  if not UI then return end

  local function activeFor(c)
    return interaction.targets[c] and "true" or "false"
  end

  UI.setAttribute("interactionYellowPanel", "active", activeFor("Yellow"))
  UI.setAttribute("interactionBluePanel",   "active", activeFor("Blue"))
  UI.setAttribute("interactionRedPanel",    "active", activeFor("Red"))
  UI.setAttribute("interactionGreenPanel",  "active", activeFor("Green"))

  resetInteractionButtonsForColor("Yellow", interaction.targets["Yellow"] == true)
  resetInteractionButtonsForColor("Blue",   interaction.targets["Blue"]   == true)
  resetInteractionButtonsForColor("Red",    interaction.targets["Red"]    == true)
  resetInteractionButtonsForColor("Green",  interaction.targets["Green"]  == true)
end

local function disableInteractionButtonsForColor(color)
  if not UI then return end
  local idPrefix = "interaction"..color
  local joinId = idPrefix.."Join"
  local ignoreId = idPrefix.."Ignore"
  -- Hide buttons completely after the player has made a choice
  UI.setAttribute(joinId, "active", "false")
  UI.setAttribute(ignoreId, "active", "false")
end

-- Forward declaration: implementation is assigned later
local resolveInteractionEffects_impl

local function tickInteractionTimer(expectedId)
  if not interaction.active then return end
  if interaction.id ~= expectedId then return end

  interaction.timer = (interaction.timer or 0) - 1
  if interaction.timer <= 0 then
    -- Auto-ignore for all players who did not respond
    for c, needed in pairs(interaction.targets) do
      if needed and not interaction.responses[c] then
        interaction.responses[c] = "IGNORE"
        disableInteractionButtonsForColor(c)
      end
    end
    updateInteractionStatusText()
    if resolveInteractionEffects_impl then
      resolveInteractionEffects_impl()
    end
  else
    updateInteractionTimerText()
    if Wait and Wait.time then
      local id = interaction.id
      Wait.time(function() tickInteractionTimer(id) end, 1)
    end
  end
end

local function startInteraction(params)
  -- params: id, initiator, title, subtitle, joinCostText, effectText, joinCostAP, duration
  if not UI then
    log("startInteraction: UI is nil")
    return
  end

  local initiator = normalizeColor(params.initiator)
  if not initiator then return end

  clearInteraction()
  interaction.active = true
  interaction.id = params.id
  interaction.initiator = initiator
  interaction.joinCostAP = tonumber(params.joinCostAP or 0) or 0
  interaction.responses = {}
  interaction.targets = {}
  interaction.timer = tonumber(params.duration or 30) or 30

  for _, c in ipairs(COLORS) do
    if c ~= initiator and isPlayableColor(c) then
      interaction.targets[c] = true
    end
  end

  UI.setAttribute("interactionTitle", "text", params.title or "[EVENT]")
  UI.setAttribute("interactionSubtitle", "text", params.subtitle or "")
  UI.setAttribute("interactionCost", "text", params.joinCostText or "")
  UI.setAttribute("interactionEffect", "text", params.effectText or "")
  setInteractionPanelVisibility()
  updateInteractionStatusText()
  updateInteractionTimerText()
  UI.setAttribute("interactionOverlay", "active", "true")

  if Wait and Wait.time then
    local id = interaction.id
    Wait.time(function() tickInteractionTimer(id) end, 1)
  end
end

local function allInteractionResponsesCollected()
  for c, needed in pairs(interaction.targets) do
    if needed and not interaction.responses[c] then
      return false
    end
  end
  return true
end

resolveInteractionEffects_impl = function()
  if not interaction.active then return end

  local id = interaction.id
  local initiator = interaction.initiator

  -- Social Worker Level 2 – Community wellbeing session
  if id == "SW_L2_COMMUNITY_WELLBEING" then
    local participants = {}
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        table.insert(participants, c)
      end
    end

    if #participants == 0 then
      safeBroadcastToColor("Community wellbeing session: no one joined → no effect.", initiator, {0.9,0.9,0.9})
    else
      -- Each participant gains +2 Satisfaction
      for _, c in ipairs(participants) do
        satAdd(c, 2)
      end
      -- Initiator: +1 SAT per participant +2 additional SAT (if anyone joined)
      local totalSatForInitiator = #participants + 2
      satAdd(initiator, totalSatForInitiator)

      local msg = "Community wellbeing session: "..initiator.." ran the event. Participants: "..table.concat(participants, ", ")
      safeBroadcastAll(msg, {0.7,1,0.7})
    end
  end

  clearInteraction()
end

local function handleInteractionResponse(color, choice, actorColor)
  if not interaction.active then return end
  color = normalizeColor(color)
  if not color or not interaction.targets[color] then return end
  actorColor = normalizeColor(actorColor)

  -- Only the matching player (or White spectator) can click their own color's buttons
  if actorColor and actorColor ~= "White" and actorColor ~= color then
    safeBroadcastToColor("⛔ You can only choose for your own color ("..tostring(actorColor)..").", actorColor, {1,0.6,0.2})
    return
  end

  if interaction.responses[color] then return end

  if choice == "JOIN" and interaction.joinCostAP > 0 then
    -- Optional JOIN: must have enough free AP, and the cost carries into next turn.
    local free = getApUnspentCount(color)
    if free < interaction.joinCostAP then
      safeBroadcastToColor("⛔ You don't have enough free AP to join this event (need "..tostring(interaction.joinCostAP)..", have "..tostring(free)..").", color, {1,0.6,0.2})
      return
    end

    local ap = findApCtrlForColor(color)
    if not ap or not ap.call then
      safeBroadcastToColor("⚠️ AP controller not found – cannot join this event.", color, {1,0.7,0.2})
      return
    end

    -- Move AP to INACTIVE with duration=1 so it is blocked for the next turn (same pattern as Birthday/Marriage events).
    local okMove = pcall(function()
      return ap.call("moveAP", { to = "INACTIVE", amount = interaction.joinCostAP, duration = 1 })
    end)
    if not okMove then
      safeBroadcastToColor("⚠️ Failed to deduct AP to join this event.", color, {1,0.7,0.2})
      return
    end
  end

  interaction.responses[color] = choice
  disableInteractionButtonsForColor(color)
  updateInteractionStatusText()

  if allInteractionResponsesCollected() then
    if resolveInteractionEffects_impl then
      resolveInteractionEffects_impl()
    end
  end
end

-- =========================================================
-- STATE PERSISTENCE
-- =========================================================
local function loadState()
  if self.script_state and self.script_state ~= "" then
    local ok, data = pcall(function() return JSON.decode(self.script_state) end)
    if ok and data and data.vocations then
      state.vocations = data.vocations or state.vocations
      state.levels = data.levels or state.levels
      state.workAP = data.workAP or state.workAP
      state.workAPThisLevel = data.workAPThisLevel or state.workAPThisLevel
      state.levelUpRound = data.levelUpRound or state.levelUpRound
      -- Backfill: if a player has a vocation but no levelUpRound (old save), treat as round 1
      for _, c in ipairs(COLORS) do
        if state.vocations[c] and (state.levelUpRound[c] == nil or state.levelUpRound[c] == 0) then
          state.levelUpRound[c] = 1
        end
      end
      log("State loaded")
    end
  end
end

local function saveState()
  local data = {
    vocations = state.vocations,
    levels = state.levels,
    workAP = state.workAP,
    workAPThisLevel = state.workAPThisLevel,
    levelUpRound = state.levelUpRound,
  }
  self.script_state = JSON.encode(data)
end

-- =========================================================
-- TILE MANAGEMENT
-- =========================================================
local function findTileForVocationAndLevel(vocation, level)
  local vocationTag = "WLB_VOC_" .. vocation
  local levelTag = "WLB_VOC_LEVEL_" .. level
  
  local allObjects = getAllObjects()
  for _, obj in ipairs(allObjects) do
    if obj and type(obj.hasTag) == "function" and
       obj.hasTag(TAG_VOCATION_TILE) and
       obj.hasTag(vocationTag) and
       obj.hasTag(levelTag) then
      -- Check if it's not on any board (no color tag)
      local hasColorTag = false
      for _, c in ipairs(COLORS) do
        local ok, has = pcall(function() return obj.hasTag(colorTag(c)) end)
        if ok and has then hasColorTag = true break end
      end
      
      if not hasColorTag then
        return obj
      end
    end
  end
  return nil
end

local function findTileOnPlayerBoard(color)
  color = normalizeColor(color)
  if not color then return nil end
  
  local ctag = colorTag(color)
  local allObjects = getAllObjects()
  
  for _, obj in ipairs(allObjects) do
    if obj and type(obj.hasTag) == "function" and
       obj.hasTag(TAG_VOCATION_TILE) and
       obj.hasTag(ctag) then
      return obj
    end
  end
  
  return nil
end

-- Get vocation id from a tile's tags (e.g. WLB_VOC_GANGSTER)
local function getVocationFromTile(tile)
  if not tile or not tile.hasTag then return nil end
  for _, voc in ipairs(ALL_VOCATIONS) do
    if tile.hasTag("WLB_VOC_" .. voc) then return voc end
  end
  return nil
end

-- Invisible LMB button on vocation tile so left-click shows explanation even when tile is locked on board (board no longer steals the click)
local function addClickToShowExplanationButton(tile)
  if not tile or not tile.createButton then return end
  pcall(function()
    tile.clearButtons()
    tile.createButton({
      click_function = "VOC_VocationTileClicked",
      function_owner = self,
      label          = "",
      position       = {0, 0.5, 0},
      width          = 800,
      height         = 800,
      font_size      = 1,
      color          = {0, 0, 0, 0},
      font_color     = {0, 0, 0, 0},
      tooltip        = "Click to view vocation details",
    })
  end)
end

local function placeTileOnBoard(tile, color)
  color = normalizeColor(color)
  if not color or not tile then return false end
  
  local board = findPlayerBoard(color)
  if not board then
    log("Board not found for " .. color)
    return false
  end
  
  local localPos = CHARACTER_SLOT_LOCAL[color]
  if not localPos then
    log("Character slot position not set for " .. color)
    return false
  end
  
  local worldPos = board.positionToWorld(localPos)
  tile.setPositionSmooth(worldPos, false, true)
  tile.addTag(colorTag(color))
  pcall(function() if tile.clearContextMenu then tile.clearContextMenu() end end)
  addClickToShowExplanationButton(tile)
  pcall(function() if tile.setLock then tile.setLock(false) end end)

  log("Placed tile on " .. color .. " board")
  return true
end

local function removeTileFromBoard(color)
  color = normalizeColor(color)
  if not color then return nil end
  
  local tile = findTileOnPlayerBoard(color)
  if not tile then return nil end

  pcall(function() if tile.clearButtons then tile.clearButtons() end end)
  tile.removeTag(colorTag(color))
  local idx = 1
  local ok, count = pcall(countTilesNearStorage)
  if ok and type(count) == "number" then idx = count + 1 end
  local wp = getVocationStorageWorldPosForIndex(idx)
  pcall(function() if tile.setPositionSmooth then tile.setPositionSmooth(wp, false, true) end end)
  
  log("Removed tile from " .. color .. " board")
  return tile
end

local function swapTileOnPromotion(color, vocation, oldLevel, newLevel)
  color = normalizeColor(color)
  if not color or not vocation then return false end
  
  -- Remove old tile
  local oldTile = removeTileFromBoard(color)
  
  -- Find and place new tile
  local newTile = findTileForVocationAndLevel(vocation, newLevel)
  if not newTile then
    log("New tile not found: " .. vocation .. " Level " .. newLevel)
    return false
  end
  
  local success = placeTileOnBoard(newTile, color)
  if success then
    log("Swapped tile: " .. color .. " " .. vocation .. " Level " .. oldLevel .. " → " .. newLevel)
  end
  
  return success
end

-- =========================================================
-- DEBUG STATE FUNCTION
-- =========================================================
function VOC_DebugState()
  local s = {}
  s.self_guid = self.getGUID()
  s.self_name = self.getName()

  -- dopasuj nazwy do tego co macie w skrypcie:
  s.selection_activeColor = selectionState and selectionState.activeColor or "nil"
  s.ui_activeColor        = uiState and uiState.activeColor or "nil"
  s.ui_screen             = uiState and uiState.currentScreen or "nil"
  s.science_points        = uiState and uiState.sciencePoints or (selectionState and selectionState.sciencePoints) or "nil"
  s.selected_vocation     = uiState and uiState.selectedVocationId or (selectionState and selectionState.selectedVocationId) or "nil"
  s.last_reject           = uiState and uiState.lastRejectReason or "nil"

  return s
end

-- =========================================================
-- PUBLIC API
-- =========================================================

-- Call when starting a new game so vocations from the previous game are cleared
function VOC_ResetForNewGame(params)
  -- 1) Force-remove vocation tiles from ALL boards (even unused colors)
  -- This prevents situations like: in a 2-player game, a tile stays tagged on Red board
  -- and becomes "unavailable" for Yellow/Blue selection.
  local function looksLikeVocationTile(obj)
    if not obj or not obj.hasTag then return false end
    if obj.hasTag(TAG_VOCATION_TILE) or obj.hasTag("WLB_VOCATION_TILE") then return true end
    -- Fallback heuristic: has both vocation id tag and level tag
    if obj.getTags then
      local tags = obj.getTags() or {}
      local hasVoc = false
      local hasLvl = false
      for _,t in ipairs(tags) do
        if type(t) == "string" then
          if string.sub(t, 1, 8) == "WLB_VOC_" then hasVoc = true end
          if string.sub(t, 1, 14) == "WLB_VOC_LEVEL_" then hasLvl = true end
        end
        if hasVoc and hasLvl then return true end
      end
    end
    return false
  end

  local function stripAllColorTags(obj)
    if not obj or not obj.removeTag then return end
    for _, c in ipairs(COLORS) do
      pcall(function() obj.removeTag(colorTag(c)) end)
    end
  end

  -- First, try the fast per-color removal (if tiles are correctly tagged)
  for _, c in ipairs(COLORS) do
    pcall(function() removeTileFromBoard(c) end)
  end

  -- Then, do a full scan and reclaim any vocation tiles still tagged with a player color
  -- and place them neatly on top of THIS controller.
  local tiles = {}
  for _, obj in ipairs(getAllObjects()) do
    if looksLikeVocationTile(obj) then
      table.insert(tiles, obj)
    end
  end

  -- Sort for stable, pretty layout (by name, fallback GUID)
  table.sort(tiles, function(a,b)
    local an, bn = nil, nil
    pcall(function() an = a.getName and a.getName() or "" end)
    pcall(function() bn = b.getName and b.getName() or "" end)
    an = tostring(an or "")
    bn = tostring(bn or "")
    if an ~= bn then return an < bn end
    local ag = tostring(a.getGUID and a.getGUID() or "")
    local bg = tostring(b.getGUID and b.getGUID() or "")
    return ag < bg
  end)

  -- Place sequentially with small delays to avoid physics jitter
  for i, obj in ipairs(tiles) do
    stripAllColorTags(obj)
    if Wait and Wait.time then
      Wait.time(function()
        parkTileOnController(obj, i)
      end, STORAGE_STACK_DELAY * i)
    else
      parkTileOnController(obj, i)
    end
  end

  -- Clear any selection artifacts (level-1 cards / explanation card / summary)
  pcall(function() VOC_CleanupSelection({color="Yellow"}) end)
  pcall(function() VOC_CleanupSelection({color="Blue"}) end)
  pcall(function() VOC_CleanupSelection({color="Red"}) end)
  pcall(function() VOC_CleanupSelection({color="Green"}) end)

  -- 2) Reset saved state
  state.vocations = { Yellow = nil, Blue = nil, Red = nil, Green = nil }
  state.levels = { Yellow = 1, Blue = 1, Red = 1, Green = 1 }
  state.workAP = { Yellow = 0, Blue = 0, Red = 0, Green = 0 }
  state.workAPThisLevel = { Yellow = 0, Blue = 0, Red = 0, Green = 0 }
  state.levelUpRound = { Yellow = nil, Blue = nil, Red = nil, Green = nil }
  state.currentPickerColor = nil
  selectionState.activeColor = nil
  selectionState.shownSummary = nil
  selectionState.shownVocation = nil
  selectionState.shownExplanationCard = nil
  saveState()
  log("Vocation state reset for new game")
end

function VOC_GetVocation(params)
  local color = normalizeColor(params.color)
  if not color then return nil end
  
  return state.vocations[color]
end

function VOC_SetVocation(params)
  local color = normalizeColor(params.color)
  local vocation = params.vocation
  
  if not color then
    log("Invalid color")
    return false, "Invalid color"
  end
  
  if not vocation then
    log("Vocation not specified")
    return false, "Vocation not specified"
  end
  
  -- Check if vocation is valid
  local valid = false
  for _, v in ipairs(ALL_VOCATIONS) do
    if v == vocation then
      valid = true
      break
    end
  end
  
  if not valid then
    log("Invalid vocation: " .. tostring(vocation))
    return false, "Invalid vocation"
  end
  
  -- One player, one vocation: cannot change during the game
  if state.vocations[color] and state.vocations[color] ~= vocation then
    log("Player " .. color .. " already has vocation " .. tostring(state.vocations[color]) .. "; cannot change to " .. tostring(vocation))
    return false, "Already has a different vocation"
  end
  
  -- Check exclusivity (can't choose if already taken)
  for _, c in ipairs(COLORS) do
    if c ~= color and state.vocations[c] == vocation then
      log("Vocation " .. vocation .. " already taken by " .. c)
      return false, "Vocation already taken"
    end
  end
  
  -- Set vocation
  state.vocations[color] = vocation
  state.levels[color] = 1  -- Start at Level 1
  state.workAP[color] = 0
  state.workAPThisLevel[color] = 0
  state.levelUpRound[color] = getCurrentRound()  -- Time/Experience: rounds at this level
  
  saveState()
  
  -- Place Level 1 tile on board
  local tile = findTileForVocationAndLevel(vocation, 1)
  if tile then
    placeTileOnBoard(tile, color)
  else
    log("Warning: Level 1 tile not found for " .. vocation)
  end
  
  log("Vocation set: " .. color .. " → " .. vocation)
  broadcastToAll(color .. " chose " .. VOCATION_DATA[vocation].name, {0.3, 1, 0.3})
  
  return true
end

function VOC_GetLevel(params)
  local color = normalizeColor(params.color)
  if not color then return nil end
  
  return state.levels[color] or 1
end

function VOC_GetSalary(params)
  local color = normalizeColor(params.color)
  if not color then return 0 end
  
  local vocation = state.vocations[color]
  if not vocation then return 0 end
  
  local level = state.levels[color] or 1
  local vocationData = VOCATION_DATA[vocation]
  if not vocationData or not vocationData.levels[level] then
    return 0
  end
  
  return vocationData.levels[level].salary or 0
end

function VOC_AddWorkAP(params)
  local color = normalizeColor(params.color)
  local amount = tonumber(params.amount) or 0
  
  if not color then return false end
  
  state.workAP[color] = (state.workAP[color] or 0) + amount
  state.workAPThisLevel[color] = (state.workAPThisLevel[color] or 0) + amount
  
  saveState()
  
  log("Work AP added: " .. color .. " +" .. amount .. " (total: " .. state.workAP[color] .. ", this level: " .. state.workAPThisLevel[color] .. ")")
  
  return true
end

function VOC_GetTotalWorkAP(params)
  local color = normalizeColor(params.color)
  if not color then return 0 end
  
  return state.workAP[color] or 0
end

function VOC_GetWorkAPThisLevel(params)
  local color = normalizeColor(params.color)
  if not color then return 0 end
  
  return state.workAPThisLevel[color] or 0
end

function VOC_GetVocationData(params)
  local vocation = params.vocation
  if not vocation then return nil end
  
  return VOCATION_DATA[vocation]
end

-- Start Social Worker Level 2 community event: "Community wellbeing session"
-- Flow:
--  - Active Social Worker (level 2+) spends 2 AP
--  - Other players may JOIN by spending 1 AP
--  - If no one joins → no effect
--  - Each participant gains +2 SAT
--  - Initiator gains +1 SAT per participant, plus +2 SAT if anyone joined
function VOC_StartSocialWorkerCommunitySession(params)
  params = params or {}
  local color = normalizeColor(params.color)
  if not color then
    color = getActorColor()
  end
  if not color then
    return false, "Invalid color"
  end

  local vocation = state.vocations[color]
  if vocation ~= VOC_SOCIAL_WORKER then
    safeBroadcastToColor("Only Social Worker can use this community event.", color, {1,0.7,0.2})
    return false, "Wrong vocation"
  end

  local level = state.levels[color] or 1
  if level < 2 then
    safeBroadcastToColor("Community wellbeing session requires Social Worker Level 2.", color, {1,0.7,0.2})
    return false, "Wrong level"
  end

  -- Spend 2 AP from initiator
  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Community wellbeing session.", color, {1,0.6,0.2})
    return false, "Not enough AP"
  end
  local ok = spendAP(color, 2, "SW_L2_COMMUNITY_WELLBEING")
  if not ok then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP for Community wellbeing session.", color, {1,0.6,0.2})
    return false, "AP deduction failed"
  end

  startInteraction({
    id = "SW_L2_COMMUNITY_WELLBEING",
    initiator = color,
    title = "COMMUNITY EVENT – Community wellbeing session",
    subtitle = "Social Worker – Cost for you: Spend 2 AP",
    joinCostText = "Others may join by spending 1 AP.",
    effectText = "Each participant gains +2 Satisfaction. You gain +1 Satisfaction per participant, plus +2 extra Satisfaction if anyone joins.",
    joinCostAP = 1,
  })

  return true
end

function VOC_CanPromote(params)
  local color = normalizeColor(params.color)
  if not color then return false, "Invalid color" end
  
  local vocation = state.vocations[color]
  if not vocation then return false, "No vocation selected" end
  
  local level = state.levels[color] or 1
  if level >= 3 then
    return false, "Already at maximum level"
  end
  
  local vocationData = VOCATION_DATA[vocation]
  if not vocationData then return false, "Invalid vocation data" end
  
  -- Requirements to level up FROM current level are in current level's promotion (not next level's)
  local currentLevelData = vocationData.levels[level]
  if not currentLevelData then return false, "Level data not found" end
  
  local promotion = currentLevelData.promotion
  if not promotion then return false, "No promotion data" end
  
  -- Get Stats Controller
  local statsCtrl = findStatsController(color)
  if not statsCtrl then return false, "Stats Controller not found" end
  
  -- Get Knowledge and Skills (try getKnowledge/getSkills first, then getState as fallback)
  local knowledge, skills = 0, 0
  local ok1, k1 = pcall(function() return statsCtrl.call("getKnowledge") end)
  local ok2, s1 = pcall(function() return statsCtrl.call("getSkills") end)
  if ok1 and (tonumber(k1) or k1) ~= nil then
    knowledge = tonumber(k1) or 0
  end
  if ok2 and (tonumber(s1) or s1) ~= nil then
    skills = tonumber(s1) or 0
  end
  if (not ok1 or not ok2) or (knowledge == 0 and skills == 0) then
    local ok3, st = pcall(function() return statsCtrl.call("getState") end)
    if ok3 and type(st) == "table" then
      knowledge = tonumber(st.k) or knowledge
      skills = tonumber(st.s) or skills
    end
  end
  
  -- Build full requirement message and check all conditions (so player sees K, S, and Time/Work)
  local function failMsg(parts)
    return table.concat(parts, ". ")
  end
  
  -- Check requirements based on promotion type
  if promotion.type == "standard" then
    local parts = {}
    if knowledge < (promotion.knowledge or 0) then
      table.insert(parts, "Need " .. tostring(promotion.knowledge) .. " Knowledge (have " .. tostring(knowledge) .. ")")
    end
    if skills < (promotion.skills or 0) then
      table.insert(parts, "Need " .. tostring(promotion.skills) .. " Skills (have " .. tostring(skills) .. ")")
    end
    local currentRound = getCurrentRound()
    local roundAtLevel = state.levelUpRound[color] or 1
    local roundsAtLevel = math.max(0, currentRound - roundAtLevel)
    local needYears = promotion.experience or 0
    if roundsAtLevel < needYears then
      table.insert(parts, "Need " .. needYears .. " years at this level (have " .. roundsAtLevel .. " rounds)")
    end
    if #parts > 0 then return false, failMsg(parts) end
    return true, "All requirements met"
    
  elseif promotion.type == "work_based" then
    local parts = {}
    if knowledge < (promotion.knowledge or 0) then
      table.insert(parts, "Need " .. tostring(promotion.knowledge) .. " Knowledge (have " .. tostring(knowledge) .. ")")
    end
    if skills < (promotion.skills or 0) then
      table.insert(parts, "Need " .. tostring(promotion.skills) .. " Skills (have " .. tostring(skills) .. ")")
    end
    local workAP = state.workAPThisLevel[color] or 0
    if workAP < (promotion.workAP or 0) then
      table.insert(parts, "Need " .. tostring(promotion.workAP) .. " AP work on this level (have " .. tostring(workAP) .. ")")
    end
    if #parts > 0 then return false, failMsg(parts) end
    -- Check additional cost (e.g., Celebrity Level 3 needs 4000 VIN)
    if promotion.additionalCost then
      -- TODO: Check if player has enough money
      -- For now, just note it
      log("Additional cost required: " .. promotion.additionalCost .. " VIN")
    end
    return true, "All requirements met"
    
  elseif promotion.type == "award" then
    -- Need Knowledge, Skills, and Award condition
    if knowledge < promotion.knowledge then
      return false, "Need " .. promotion.knowledge .. " Knowledge (have " .. knowledge .. ")"
    end
    if skills < promotion.skills then
      return false, "Need " .. promotion.skills .. " Skills (have " .. skills .. ")"
    end
    -- Award condition check would need to track specific achievements
    -- TODO: Implement award tracking
    return false, "Award condition check not yet implemented: " .. (promotion.awardCondition or "Unknown")
  end
  
  return false, "Unknown promotion type"
end

function VOC_Promote(params)
  local color = normalizeColor(params.color)
  if not color then return false, "Invalid color" end
  
  -- Only the owner of the vocation card can level it up
  local tileGuid = params.tileGuid
  if tileGuid and tileGuid ~= "" then
    local tile = getObjectFromGUID(tileGuid)
    if tile and tile.hasTag then
      local ownerColor = nil
      for _, c in ipairs(COLORS) do
        if tile.hasTag(colorTag(c)) then ownerColor = c; break end
      end
      if ownerColor and ownerColor ~= color then
        return false, "Only the owner of this vocation can level up"
      end
    end
  end
  
  local canPromote, reason = VOC_CanPromote({color=color})
  if not canPromote then
    log("Cannot promote " .. color .. ": " .. tostring(reason))
    return false, reason
  end
  
  local vocation = state.vocations[color]
  local oldLevel = state.levels[color] or 1
  local newLevel = oldLevel + 1
  
  -- Replace vocation card with higher-level card first; only then update state
  local swapOk = swapTileOnPromotion(color, vocation, oldLevel, newLevel)
  if not swapOk then
    log("Promotion aborted: could not replace vocation card for " .. color .. " (Level " .. newLevel .. " tile not found or place failed)")
    return false, "Could not replace vocation card – ensure Level " .. newLevel .. " vocation tiles exist with correct tags"
  end
  
  -- Update level and round after successful card swap
  state.levels[color] = newLevel
  state.levelUpRound[color] = getCurrentRound()
  state.workAPThisLevel[color] = 0
  saveState()
  
  local vocationData = VOCATION_DATA[vocation]
  local newLevelData = vocationData.levels[newLevel]
  
  log("Promoted: " .. color .. " " .. vocation .. " Level " .. oldLevel .. " → " .. newLevel)
  broadcastToAll(color .. " promoted to " .. vocationData.name .. " - " .. newLevelData.jobTitle, {0.3, 1, 0.3})
  
  return true
end

-- Called before a player's turn (by TurnController at turn start): if they meet promotion requirements, promote automatically
-- and swap the next-level vocation tile (Level 2 or Level 3) with their current tile (no tile context menu needed).
function VOC_CheckAndAutoPromote(params)
  local color = normalizeColor(params and params.color)
  if not color then return false end
  local canPromote = VOC_CanPromote({ color = color })
  if not canPromote then return false end
  local ok = VOC_Promote({ color = color })
  return ok
end

-- =========================================================
-- UI XML HANDLERS (Screen-based HUD interface)
-- Must be defined BEFORE VOC_StartSelection which calls them
-- =========================================================

-- UI State tracking
local uiState = {
  activeColor = nil,
  currentScreen = nil,  -- "selection", "summary", or nil
  previewedVocation = nil,
}

-- Safe UI setters: missing element IDs should NOT break the whole flow
local function uiSet(id, attr, value)
  if not UI then return false end
  local ok = pcall(function()
    UI.setAttribute(id, attr, tostring(value))
  end)
  return ok
end

local function uiGet(id, attr)
  if not UI then return nil end
  local ok, val = pcall(function()
    return UI.getAttribute(id, attr)
  end)
  if ok then return val end
  return nil
end


-- Hide the Vocation Summary UI panel (must be defined before showSelectionUI)
local function hideSummaryUI()
  if not UI then 
    log("hideSummaryUI: UI is nil")
    return 
  end
  pcall(function()
    log("hideSummaryUI: Setting vocationSummaryPanel active=false")
    UI.setAttribute("vocationSummaryPanel", "active", "false")
    UI.setAttribute("selectionCardPanel", "active", "false")
  end)
  uiState.currentScreen = "selection"
  uiState.previewedVocation = nil
end

-- Hide the Vocation Selection UI panel
local function hideSelectionUI()
  if not UI then 
    log("hideSelectionUI: UI is nil")
    return 
  end
  pcall(function()
    log("hideSelectionUI: Setting vocationSelectionPanel active=false")
    UI.setAttribute("vocationSelectionPanel", "active", "false")
    -- Also hide overlay to completely close UI
    UI.setAttribute("vocationOverlay", "active", "false")
    local verify = UI.getAttribute("vocationSelectionPanel", "active")
    log("hideSelectionUI: Verified active=" .. tostring(verify))
  end)
  uiState.currentScreen = nil
end

-- Refresh selection card allocation numbers and Apply button state (pool=0 => enabled)
-- Defined early so it is available when called from UI_ConfirmVocation/UI_AllocScience (TTS may chunk scripts)
function refreshSelectionCardAllocUI(turnCtrl, color)
  if not turnCtrl or not turnCtrl.call or not color then return end
  local ok, st = pcall(function() return turnCtrl.call("API_GetAllocState", { color = color }) end)
  if ok and st and type(st) == "table" then
    UI.setAttribute("selectionCardSciencePoints", "text", tostring(st.pool or 0))
    UI.setAttribute("selectionCardKnowledgeValue", "text", tostring(st.k or 0))
    UI.setAttribute("selectionCardSkillsValue", "text", tostring(st.s or 0))
    local pool = tonumber(st.pool) or 0
    UI.setAttribute("selectionCardApply", "interactable", pool == 0 and "true" or "false")
    -- Keep apply button invisible even when enabled
    UI.setAttribute("selectionCardApply", "color", "#00000000")
    UI.setAttribute("selectionCardApply", "fontColor", "#00000000")
  end
end

-- Show the Vocation Selection UI panel
local function showSelectionUI(color, points, showSciencePointsLabelParam)
  if not UI then
    log("ERROR: UI system not available - UI is nil. Check that VocationsUI_Global.xml is in Global → UI tab.")
    broadcastToAll("⚠️ UI system not available. Check that VocationsUI_Global.xml is in Global → UI tab.", {1, 0.5, 0.2})
    return false
  end
  
  color = normalizeColor(color)
  if not color then return false end
  
  -- Hide summary if shown
  if uiState.currentScreen == "summary" then
    hideSummaryUI()
  end
  
  -- Show selection panel
  local ok, err = pcall(function()
    -- First, verify UI element exists by trying to get ANY attribute
    local testAttr = nil
    local testOk, testErr = pcall(function()
      testAttr = UI.getAttribute("vocationSelectionPanel", "active")
    end)
    
    if not testOk or testAttr == nil then
      -- Panel doesn't exist - UI XML not loaded!
      log("ERROR: Panel 'vocationSelectionPanel' not found! UI XML may not be loaded in Global → UI tab.")
      log("ERROR: testOk=" .. tostring(testOk) .. ", testAttr=" .. tostring(testAttr) .. ", testErr=" .. tostring(testErr))
      error("UI panel 'vocationSelectionPanel' not found. Please check that VocationsUI_Global.xml is pasted into Global → UI tab.")
    end
    
    log("DEBUG: Panel exists! Current active state: " .. tostring(testAttr))
    
    -- CRITICAL: Verify overlay exists before activating
    local overlayTest = nil
    local overlayTestOk, overlayTestErr = pcall(function()
      overlayTest = UI.getAttribute("vocationOverlay", "active")
    end)
    
    if not overlayTestOk or overlayTest == nil then
      log("ERROR: Overlay 'vocationOverlay' not found! UI XML structure may be incorrect.")
      error("Overlay 'vocationOverlay' not found. Please check VocationsUI_Global.xml structure.")
    end
    
    log("DEBUG: Overlay found! Current active state: " .. tostring(overlayTest))
    
    -- Show overlay first (contains Cancel button and all panels)
    UI.setAttribute("vocationOverlay", "active", "true")
    log("DEBUG: Overlay activated")
    
    -- Set panel to active
    UI.setAttribute("vocationSelectionPanel", "active", "true")
    log("DEBUG: Selection panel activated")
    
    -- Hide other panels
    UI.setAttribute("vocationSummaryPanel", "active", "false")
    UI.setAttribute("sciencePointsPanel", "active", "false")
    
    -- Verify it was set
    local verifyOverlay = UI.getAttribute("vocationOverlay", "active")
    local verifyAttr = UI.getAttribute("vocationSelectionPanel", "active")
    log("DEBUG: Overlay active=" .. tostring(verifyOverlay) .. ", Panel active=" .. tostring(verifyAttr))
    
    -- Update subtitle: Adult start = "Science Points: x"; Youth (round 1 or round 6) = Knowledge and Skill
    -- Use param from TurnController when starting selection (reliable); fallback to API if not provided
    uiSet("selectionSubtitle", "text", "Player: " .. color)
    local turnCtrl = findTurnController()
    local showSciencePointsLabel = (showSciencePointsLabelParam == true)
    if showSciencePointsLabelParam == nil then
      if turnCtrl and turnCtrl.call then
        local ok, v = pcall(function() return turnCtrl.call("API_ShouldShowSciencePointsOnSelectionScreen", {}) end)
        if ok and v then showSciencePointsLabel = true end
      end
    end
    if showSciencePointsLabel then
      -- Adult start only: show "Science Points: x"
      local sciencePoints = points
      if not sciencePoints or sciencePoints == 0 then
        sciencePoints = getSciencePointsForColor(color)
      end
      UI.setAttribute("selectionSciencePoints", "text", "Science Points: " .. tostring(sciencePoints))
      UI.setAttribute("selectionSciencePoints", "active", "true")
      UI.setAttribute("selectionKnowledgeSkillLine", "active", "false")
      log("DEBUG: Set subtitle to: Player: " .. color .. " | Science Points=" .. tostring(sciencePoints))
    else
      -- Youth (round 1 or round 6): show Knowledge • Skill on one line
      UI.setAttribute("selectionSciencePoints", "active", "false")
      UI.setAttribute("selectionSciencePoints", "text", "")
      local k, s = 0, 0
      if turnCtrl and turnCtrl.call then
        local ok, ks = pcall(function() return turnCtrl.call("API_GetKnowledgeAndSkills", { color = color }) end)
        if ok and ks and type(ks) == "table" then
          k = ks.k or 0
          s = ks.s or 0
        end
      end
      UI.setAttribute("selectionKnowledgeSkillLine", "text", "Knowledge: " .. tostring(k) .. "  •  Skill: " .. tostring(s))
      UI.setAttribute("selectionKnowledgeSkillLine", "active", "true")
      log("DEBUG: Set subtitle to: Player: " .. color .. " | Knowledge=" .. tostring(k) .. " Skill=" .. tostring(s))
    end

    -- Update button states (disable taken vocations)
    for _, voc in ipairs(ALL_VOCATIONS) do
      local isTaken = false
      for _, c in ipairs(COLORS) do
        if state.vocations[c] == voc then
          isTaken = true
          break
        end
      end
      
      local btnId = "btn" .. voc:gsub("_", "")
      if isTaken then
        -- For buttons with images, don't set color (it tints the image)
        -- Instead, use opacity or overlay
        uiSet(btnId, "interactable", "false")
        -- Set a semi-transparent overlay effect instead of color
        UI.setAttribute(btnId, "opacity", "0.5")
        log("DEBUG: Disabled button: " .. btnId)
      else
        -- For buttons with images, don't set color (it tints the image)
        -- Keep images natural by not setting color attribute
        uiSet(btnId, "interactable", "true")
        UI.setAttribute(btnId, "opacity", "1.0")
        log("DEBUG: Enabled button: " .. btnId)
      end
    end
  end)
  
  if not ok then
    log("ERROR: Failed to show selection UI: " .. tostring(err))
    
    -- Check if error is about missing panel
    if tostring(err):find("not found") or tostring(err):find("nil") then
      broadcastToAll("❌ CRITICAL: UI XML not loaded!", {1, 0.2, 0.2})
      broadcastToAll("📋 Steps to fix:", {1, 0.7, 0.2})
      broadcastToAll("1) Go to Global → UI tab", {1, 0.8, 0.3})
      broadcastToAll("2) Clear all (CTRL+A, Delete)", {1, 0.8, 0.3})
      broadcastToAll("3) Paste VocationsUI_Global.xml content", {1, 0.8, 0.3})
      broadcastToAll("4) Click 'Save & Apply'", {1, 0.8, 0.3})
    else
      broadcastToAll("⚠️ Failed to show vocation selection UI: " .. tostring(err), {1, 0.5, 0.2})
    end
    return false
  end
  
  -- Additional verification
  Wait.time(function()
    if UI then
      local finalCheck = UI.getAttribute("vocationSelectionPanel", "active")
      log("DEBUG: Final panel active check (after 0.1s): " .. tostring(finalCheck))
      if finalCheck ~= "true" then
        log("WARNING: Panel active state is not 'true'! It is: " .. tostring(finalCheck))
        broadcastToAll("⚠️ UI panel may not be visible. Check UI XML is loaded in Global → UI tab.", {1, 0.5, 0.2})
      end
    end
  end, 0.1)
  
  uiState.activeColor = color
  selectionState.activeColor = color  -- Also set selectionState for consistency
  uiState.currentScreen = "selection"
  log("Selection UI shown for " .. color .. " (both uiState and selectionState set)")
  return true
end

-- Show the Vocation Summary UI panel
local function showSummaryUI(color, vocation, previewOnly)
  log("=== showSummaryUI CALLED ===")
  log("color: " .. tostring(color) .. ", vocation: " .. tostring(vocation) .. ", previewOnly: " .. tostring(previewOnly))
  
  if not UI then
    log("ERROR: UI system not available - UI is nil")
    broadcastToAll("⚠️ UI system not available. Check Global UI XML.", {1, 0.3, 0.3})
    return false
  end
  
  color = normalizeColor(color)
  if not color or not vocation then 
    log("ERROR: Invalid color or vocation. color=" .. tostring(color) .. ", vocation=" .. tostring(vocation))
    return false 
  end
  
  local vocData = VOCATION_DATA[vocation]
  if not vocData then
    log("ERROR: No data for vocation: " .. tostring(vocation))
    return false
  end
  
  local level1 = vocData.levels[1]
  local level2 = vocData.levels[2]
  
  if not level1 then
    log("ERROR: No Level 1 data for vocation: " .. tostring(vocation))
    return false
  end
  
  -- Check if vocation is already taken
  local isTaken = false
  local takenBy = nil
  for _, c in ipairs(COLORS) do
    if state.vocations[c] == vocation and c ~= color then
      isTaken = true
      takenBy = c
      break
    end
  end
  
  local ok, err = pcall(function()
    log("showSummaryUI: Setting UI attributes...")
    
    -- First, verify panels exist
    local testOk, testAttr = pcall(function()
      return UI.getAttribute("vocationSummaryPanel", "active")
    end)
    if not testOk or testAttr == nil then
      log("ERROR: Panel 'vocationSummaryPanel' not found! Check UI XML.")
      broadcastToAll("⚠️ UI panel not found. Check Global → UI tab.", {1, 0.3, 0.3})
      error("Panel 'vocationSummaryPanel' not found")
    end
    log("showSummaryUI: Panel exists, current active state: " .. tostring(testAttr))
    
    -- Show overlay if not already shown
    UI.setAttribute("vocationOverlay", "active", "true")
    log("showSummaryUI: Overlay set to active")
    
    -- Hide selection panel
    UI.setAttribute("vocationSelectionPanel", "active", "false")
    log("showSummaryUI: Selection panel set to inactive")
    
    -- Show summary panel
    UI.setAttribute("vocationSummaryPanel", "active", "true")
    log("showSummaryUI: Summary panel set to active")
    
    -- Hide vocation title text so only the explanation image and buttons show (no "Public Servant" below)
    UI.setAttribute("summaryTitle", "text", vocData.name)
    UI.setAttribute("summaryTitle", "active", "false")
    
    -- Show explanation picture: prefer VOCATION_EXPLANATION_IMAGE (add your links in VocationsController),
    -- else fall back to vocation card image (VOCATION_IMAGES)
    local imageUrl = (VOCATION_EXPLANATION_IMAGE[vocation] and VOCATION_EXPLANATION_IMAGE[vocation] ~= "")
        and VOCATION_EXPLANATION_IMAGE[vocation] or VOCATION_IMAGES[vocation]
    if imageUrl and imageUrl ~= "" then
      UI.setAttribute("summaryVocationImage", "image", imageUrl)
      UI.setAttribute("summaryVocationImage", "active", "true")
      log("showSummaryUI: Set explanation image for " .. vocation)
    else
      log("WARNING: No image URL for vocation: " .. tostring(vocation))
      UI.setAttribute("summaryVocationImage", "active", "false")
    end

    -- Selection card is shown only after Confirm (see UI_ConfirmVocation)
    UI.setAttribute("selectionCardPanel", "active", "false")

    -- Hide the summary content panel (dark grey box) so the explanation image is visible
    UI.setAttribute("summaryContent", "active", "false")
    
    -- Hide text description fields (user wants graphics, not text)
    UI.setAttribute("level1Title", "active", "false")
    UI.setAttribute("level1Salary", "active", "false")
    UI.setAttribute("promoTitle", "active", "false")
    UI.setAttribute("promoReqs", "active", "false")
    UI.setAttribute("level2Title", "active", "false")
    UI.setAttribute("level2Salary", "active", "false")
    
    -- Show/hide taken warning (only relevant when selecting; hide in "Show explanation" read-only)
    if previewOnly then
      UI.setAttribute("takenWarning", "active", "false")
    elseif isTaken then
      UI.setAttribute("takenWarning", "active", "true")
      UI.setAttribute("btnConfirm", "interactable", "false")
      UI.setAttribute("btnConfirm", "color", "#333333")
    else
      UI.setAttribute("takenWarning", "active", "false")
      UI.setAttribute("btnConfirm", "interactable", "true")
      UI.setAttribute("btnConfirm", "color", "#4a90e2")
    end
    
    -- "Show explanation" (read-only): hide Back/Confirm, show Exit. Selection flow: show Back/Confirm, hide Exit.
    if previewOnly then
      UI.setAttribute("actionButtons", "active", "false")
      UI.setAttribute("btnExit", "active", "true")
    else
      UI.setAttribute("actionButtons", "active", "true")
      UI.setAttribute("btnExit", "active", "false")
    end
    
    -- Verify the panel is actually active (with delay to allow UI to update)
    Wait.time(function()
      local verify = UI.getAttribute("vocationSummaryPanel", "active")
      log("showSummaryUI: Verified summary panel active=" .. tostring(verify) .. " (after 0.1s)")
      if verify ~= "true" then
        log("WARNING: Summary panel active state is not 'true'! It is: " .. tostring(verify))
        broadcastToAll("⚠️ Summary panel may not be visible. Check UI XML.", {1, 0.7, 0.2})
      else
        log("✅ Summary panel is ACTIVE - should be visible now!")
      end
    end, 0.1)
  end)
  
  if not ok then
    log("ERROR: showSummaryUI pcall failed: " .. tostring(err))
    broadcastToAll("❌ showSummaryUI error: " .. tostring(err), {1, 0.3, 0.3})
    return false
  end
  
  uiState.currentScreen = "summary"
  uiState.previewedVocation = vocation
  log("Summary UI shown for " .. color .. " -> " .. vocation)
  return true
end

-- Hide the Vocation Summary UI panel (duplicate removed - already defined earlier)

-- =========================================================
-- SELECTION UI FUNCTIONS (Legacy - physical tiles)
-- =========================================================

function findSummaryTileForVocation(vocation)
  local summaryTag = "WLB_VOC_SUMMARY_" .. vocation
  local allObjects = getAllObjects()
  
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and
       obj.hasTag("WLB_VOCATION_SUMMARY") and
       obj.hasTag(summaryTag) then
      return obj
    end
  end
  return nil
end

local function findAllLevel1Tiles()
  local tiles = {}
  local allObjects = getAllObjects()
  local totalChecked = 0
  local foundWithBaseTag = 0
  local foundWithLevelTag = 0
  local excludedWithColorTag = 0
  
  log("Searching for Level 1 vocation tiles...")
  
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag then
      totalChecked = totalChecked + 1
      
      if obj.hasTag(TAG_VOCATION_TILE) or obj.hasTag("WLB_VOCATION_TILE") then
        foundWithBaseTag = foundWithBaseTag + 1
        
        if obj.hasTag("WLB_VOC_LEVEL_1") then
          foundWithLevelTag = foundWithLevelTag + 1
          
          -- Check if it's not on any board (no color tag)
          local hasColorTag = false
          for _, c in ipairs(COLORS) do
            if obj.hasTag(colorTag(c)) then
              hasColorTag = true
              excludedWithColorTag = excludedWithColorTag + 1
              break
            end
          end
          
          if not hasColorTag then
            table.insert(tiles, obj)
            local name = obj.getName and obj.getName() or "Unknown"
            log("Found available Level 1 tile: " .. name)
          end
        end
      end
    end
  end
  
  log("Tile search results:")
  log("  Total objects checked: " .. totalChecked)
  log("  Objects with WLB_VOCATION_TILE tag: " .. foundWithBaseTag)
  log("  Objects with WLB_VOC_LEVEL_1 tag: " .. foundWithLevelTag)
  log("  Excluded (have color tag): " .. excludedWithColorTag)
  log("  Available tiles found: " .. #tiles)
  
  return tiles
end

local function removeAllButtons(tile)
  if not tile or not tile.clearButtons then return end
  pcall(function() tile.clearButtons() end)
end

local function positionSelectionTiles(tiles)
  if #tiles == 0 then 
    log("No tiles to position")
    return 
  end
  
  log("Positioning " .. #tiles .. " selection tiles in center")
  
  -- Calculate starting X position to center the tiles
  local totalWidth = SELECTION_TILE_SPACING * (#tiles - 1)
  local startX = SELECTION_AREA_CENTER.x - (totalWidth / 2)
  
  -- Position each tile in a horizontal row, elevated above the table
  for i, tile in ipairs(tiles) do
    if tile and tile.setPositionSmooth then
      local x = startX + (i - 1) * SELECTION_TILE_SPACING
      local pos = {
        x = x,
        y = SELECTION_AREA_CENTER.y,  -- Elevated high for visibility
        z = SELECTION_AREA_CENTER.z
      }
      
      log("Positioning tile " .. i .. " at " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
      
      -- Use setPositionSmooth for animated movement
      tile.setPositionSmooth(pos, false, true)
      
      -- Ensure tile is unlocked and face up
      if tile.setLock then
        pcall(function() tile.setLock(false) end)
      end
      
      if tile.flip then
        pcall(function()
          if tile.is_face_down then 
            tile.flip() 
            log("Flipped tile " .. i .. " face up")
          end
        end)
      end
      
      -- Small delay between positioning for smoother animation
      Wait.time(function() end, i * 0.1)
    else
      log("Warning: Tile " .. i .. " is invalid or missing setPositionSmooth")
    end
  end
  
  log("Finished positioning " .. #tiles .. " tiles")
end

-- =========================================================
-- LEVEL 1 CARDS: place next to controller, return on cleanup
-- =========================================================
function VOC_ReturnLevel1Cards()
  for _, card in ipairs(selectionState.level1Cards or {}) do
    if card and not card.isDestroyed and card.clearContextMenu then
      pcall(function() card.clearContextMenu() end)
    end
  end
  for guid, pos in pairs(selectionState.level1OriginalPositions or {}) do
    local card = getObjectFromGUID(guid)
    if card and card.setPositionSmooth and pos then
      pcall(function() card.setPositionSmooth(pos, false, true) end)
    end
  end
  selectionState.level1Cards = {}
  selectionState.level1OriginalPositions = {}
  log("Level 1 cards returned")
end

-- =========================================================
-- SELECTION UI: Button menu with VOCATION_IMAGES + explanation card
-- No physical card movement; click a vocation → see explanation card → Confirm or Go Back
-- =========================================================
-- Button layout: 2 rows × 3 columns; spaced so buttons do not overlap (readable and clickable)
local VOC_SELECTION_BUTTONS = {
  { id = VOC_PUBLIC_SERVANT,  name = "Public Servant",  func = "VOC_SelectPublicServant",  pos = {-1.8, 0.3, 0.55} },
  { id = VOC_CELEBRITY,       name = "Celebrity",       func = "VOC_SelectCelebrity",       pos = {0, 0.3, 0.55} },
  { id = VOC_SOCIAL_WORKER,   name = "Social Worker",   func = "VOC_SelectSocialWorker",   pos = {1.8, 0.3, 0.55} },
  { id = VOC_GANGSTER,        name = "Gangster",        func = "VOC_SelectGangster",        pos = {-1.8, 0.3, -0.45} },
  { id = VOC_ENTREPRENEUR,    name = "Entrepreneur",    func = "VOC_SelectEntrepreneur",    pos = {0, 0.3, -0.45} },
  { id = VOC_NGO_WORKER,      name = "NGO Worker",      func = "VOC_SelectNGOWorker",       pos = {1.8, 0.3, -0.45} },
}

function VOC_ShowSelectionUI(color)
  if not self then return false end

  color = normalizeColor(color)
  if not color then
    log("Invalid color")
    return false
  end

  -- Return any Level 1 cards from a previous selection (cleanup)
  VOC_ReturnLevel1Cards()

  selectionState.activeColor = color
  selectionState.shownVocation = nil
  selectionState.shownSummary = nil
  selectionState.shownExplanationCard = nil

  log("Showing vocation selection menu (VOCATION_IMAGES + buttons) for " .. color)

  -- Title: who is choosing (high contrast, above vocation buttons)
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label = color .. " – Choose Your Vocation",
    position = {0, 0.3, 1.35},
    width = 2200,
    height = 420,
    font_size = 200,
    color = {0.08, 0.08, 0.18, 1},
    font_color = {1, 1, 1, 1},
    tooltip = "Click a vocation below to see its explanation card, then Confirm or Go Back"
  })

  -- Vocation buttons: only show those not yet taken; use VOCATION_IMAGES if supported
  local buttonCount = 0
  for _, btn in ipairs(VOC_SELECTION_BUTTONS) do
    local isTaken = false
    for _, c in ipairs(COLORS) do
      if state.vocations[c] == btn.id then isTaken = true; break end
    end
    if not isTaken then
      local imageUrl = VOCATION_IMAGES[btn.id]
      -- Dark background + white text for readability; smaller size so buttons don't overlap
      local params = {
        click_function = btn.func,
        function_owner = self,
        label = btn.name,
        position = btn.pos,
        width = 800,
        height = 420,
        font_size = 160,
        color = {0.1, 0.15, 0.35, 1},
        font_color = {1, 1, 1, 1},
        tooltip = "View " .. btn.name .. " → then Confirm or Go Back"
      }
      if imageUrl and imageUrl ~= "" then
        params.image = imageUrl
      end
      self.createButton(params)
      buttonCount = buttonCount + 1
    end
  end

  log("Vocation selection menu: " .. buttonCount .. " vocation buttons")
  return true
end

-- Called when player picks a vocation from a Level 1 card (context menu)
function VOC_ChoseFromCard(params)
  local vocation = params.vocation
  local color = normalizeColor(params.color)
  local activeColor = selectionState.activeColor

  if not activeColor or color ~= activeColor then
    broadcastToAll("Only " .. tostring(activeColor) .. " can choose a vocation right now.", {1, 0.5, 0.2})
    return
  end
  if not vocation then return end

  log("VOC_ChoseFromCard: " .. tostring(color) .. " chose " .. tostring(vocation))

  -- Show explanation card next to controller (no description text)
  if VOC_EXPLANATION_CARD_GUID[vocation] and VOC_EXPLANATION_CARD_GUID[vocation] ~= "" then
    VOC_ShowExplanationCard(vocation)
  else
    -- No explanation card GUID: still show Confirm/Go Back on controller (no text panel)
    selectionState.shownVocation = vocation
    selectionState.shownSummary = nil
    selectionState.shownExplanationCard = nil
    if self and self.clearButtons then self.clearButtons() end
    local vocationName = (VOCATION_DATA[vocation] and VOCATION_DATA[vocation].name) or vocation
    self.createButton({
      click_function = "VOC_ConfirmSelection",
      function_owner = self,
      label = "Confirm " .. vocationName,
      position = {-1.0, 0.3, -1.2},
      width = 1000, height = 380, font_size = 140,
      color = {0.2, 0.85, 0.25, 1}, font_color = {0, 0, 0, 1}
    })
    self.createButton({
      click_function = "VOC_BackToSelection",
      function_owner = self,
      label = "Go Back",
      position = {1.0, 0.3, -1.2},
      width = 900, height = 380, font_size = 160,
      color = {0.5, 0.5, 0.55, 1}, font_color = {1, 1, 1, 1}
    })
  end
end

-- =========================================================
-- EXPLANATION CARD (full vocation reference card by GUID)
-- =========================================================
function VOC_ShowExplanationCard(vocation)
  local guid = VOC_EXPLANATION_CARD_GUID[vocation]
  if not guid or guid == "" then return false end

  local card = getObjectFromGUID(guid)
  if not card or not card.setPositionSmooth then
    log("Explanation card not found for " .. vocation .. " (GUID: " .. tostring(guid) .. ")")
    return false
  end

  local color = selectionState.activeColor
  if not color then return false end

  -- Hide any previous summary/explanation
  if selectionState.shownSummary then
    VOC_HideSummary({color = color})
  end
  if selectionState.shownExplanationCard then
    VOC_HideExplanationCard()
  end

  selectionState.shownVocation = vocation
  selectionState.shownSummary = nil
  selectionState.shownExplanationCard = card

  -- Move explanation card next to Vocations Controller (same side as Level 1 cards, further out)
  card.setLock(false)
  local worldPos = self.positionToWorld({ x = EXPLANATION_CARD_OFFSET_X, y = 0, z = 0 })
  card.setPositionSmooth(worldPos, false, true)
  if card.flip and card.is_face_down then
    pcall(function() card.flip() end)
  end

  -- Controller: only Confirm and Go Back (no text panel)
  local vocationName = VOCATION_DATA[vocation] and VOCATION_DATA[vocation].name or vocation

  self.createButton({
    click_function = "VOC_ConfirmSelection",
    function_owner = self,
    label = "Confirm",
    position = {-1.0, 0.3, -1.2},
    width = 900,
    height = 380,
    font_size = 160,
    color = {0.2, 0.85, 0.25, 1},
    font_color = {0, 0, 0, 1},
    tooltip = "Choose " .. vocationName
  })
  self.createButton({
    click_function = "VOC_BackToSelection",
    function_owner = self,
    label = "Go Back",
    position = {1.0, 0.3, -1.2},
    width = 900,
    height = 380,
    font_size = 160,
    color = {0.5, 0.5, 0.55, 1},
    font_color = {1, 1, 1, 1},
    tooltip = "Return to vocation list"
  })

  log("Showing explanation card for " .. vocation .. " (GUID: " .. guid .. ")")
  return true
end

function VOC_HideExplanationCard()
  if not selectionState.shownExplanationCard then return end
  local card = selectionState.shownExplanationCard
  card.setPositionSmooth(STORAGE_EXPLANATION, false, true)
  selectionState.shownExplanationCard = nil
  selectionState.shownVocation = nil
  log("Explanation card returned to storage")
end

-- Show vocation explanation in a different way than summoning the physical card:
-- uses Global UI summary panel (image + details) or broadcasts perks text to the player.
function VOC_ShowExplanationForPlayer(params)
  local vocation = params and params.vocation
  local color = normalizeColor(params and params.color)
  if not vocation or not color then
    log("VOC_ShowExplanationForPlayer: missing vocation or color")
    return false
  end
  if not VOCATION_DATA[vocation] then
    log("VOC_ShowExplanationForPlayer: unknown vocation " .. tostring(vocation))
    return false
  end
  -- Prefer Global UI summary panel (on-screen, no physical card). When from "Show explanation" use previewOnly so only Exit is shown.
  if showSummaryUI and UI then
    local previewOnly = not not (params and params.previewOnly)
    local ok = showSummaryUI(color, vocation, previewOnly)
    if ok then
      log("VOC_ShowExplanationForPlayer: showed summary UI for " .. vocation .. " to " .. color)
      return true
    end
  end
  -- Fallback: broadcast perks text to that player (when Global UI not available)
  local vocationName = VOCATION_DATA[vocation].name or vocation
  local perksText = getPerksText(vocation)
  safeBroadcastToColor(vocationName, color, {0.4, 0.6, 1})
  safeBroadcastToColor(perksText or "No data", color, {0.9, 0.9, 0.95})
  log("VOC_ShowExplanationForPlayer: broadcast perks text to " .. color)
  return true
end

-- Global: called when the "Info" button on a vocation card is clicked (card script uses this).
-- When the button is on the card, self = card, so we find the controller by tag.
function VOC_CardButtonShowExplanation(obj, color, alt_click)
  if not obj or not obj.hasTag then return end
  local vocation = nil
  for _, voc in ipairs(ALL_VOCATIONS) do
    if obj.hasTag("WLB_VOC_" .. voc) then vocation = voc; break end
  end
  if not vocation then return end
  color = normalizeColor(color)
  if not color then return end
  local ctrl = nil
  local list = getAllObjects()
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag("WLB_VOCATIONS_CTRL") then ctrl = o; break end
  end
  if ctrl and ctrl.call then
    ctrl.call("VOC_ShowExplanationForPlayer", { vocation = vocation, color = color })
  end
end

-- Global: called when the invisible LMB button on a vocation tile (on player board) is left-clicked.
-- Shows the same explanation UI as "Show explanation" (read-only). Works even when the tile is locked.
function VOC_VocationTileClicked(obj, player_color, alt_click)
  if not obj or not obj.hasTag or type(obj.hasTag) ~= "function" then return end
  local vocation = nil
  for _, voc in ipairs(ALL_VOCATIONS) do
    if obj.hasTag("WLB_VOC_" .. voc) then vocation = voc; break end
  end
  if not vocation then return end
  player_color = normalizeColor(player_color)
  if not player_color then return end
  VOC_ShowExplanationForPlayer({ vocation = vocation, color = player_color, previewOnly = true })
end

-- =========================================================
-- PERKS TEXT (from VOCATION_DATA)
-- =========================================================
local function getPerksText(vocation)
  local data = VOCATION_DATA[vocation]
  if not data or not data.levels then return "No data" end
  local lines = {}
  for level = 1, 3 do
    local lvl = data.levels[level]
    if lvl then
      table.insert(lines, "Level " .. level .. ": " .. (lvl.jobTitle or ""))
      table.insert(lines, "  Salary: " .. tostring(lvl.salary or 0) .. " VIN/AP")
      if lvl.promotion then
        local p = lvl.promotion
        if p.knowledge then table.insert(lines, "  Promotion: K" .. p.knowledge .. " S" .. (p.skills or 0)) end
        if p.experience then table.insert(lines, "  Experience: " .. p.experience .. " years") end
        if p.workAP then table.insert(lines, "  Work AP: " .. p.workAP) end
        if p.awardCondition then table.insert(lines, "  " .. p.awardCondition) end
      end
      table.insert(lines, "")
    end
  end
  return table.concat(lines, "\n")
end

-- =========================================================
-- PERKS VIEW ON CONTROLLER (show details, then Confirm / Go Back)
-- =========================================================
function VOC_ShowPerksOnController(vocation)
  if not self then return false end
  local color = selectionState.activeColor
  if not color then return false end

  local data = VOCATION_DATA[vocation]
  local vocationName = data and data.name or vocation
  selectionState.shownVocation = vocation
  selectionState.shownSummary = nil  -- No physical tile

  -- Title
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label = vocationName,
    position = {0, 0.3, 1.3},
    width = 2200,
    height = 380,
    font_size = 220,
    color = {0.15, 0.15, 0.35, 1},
    font_color = {1, 1, 1, 1}
  })

  -- Perks text (multi-line; font smaller to fit)
  local perksText = getPerksText(vocation)
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label = perksText,
    position = {0, 0.3, 0.1},
    width = 2400,
    height = 1200,
    font_size = 90,
    color = {0.2, 0.22, 0.28, 1},
    font_color = {0.9, 0.9, 0.95, 1}
  })

  -- Confirm
  self.createButton({
    click_function = "VOC_ConfirmSelection",
    function_owner = self,
    label = "Confirm",
    position = {-1.0, 0.3, -1.2},
    width = 900,
    height = 380,
    font_size = 160,
    color = {0.2, 0.85, 0.25, 1},
    font_color = {0, 0, 0, 1},
    tooltip = "Choose " .. vocationName
  })

  -- Go Back
  self.createButton({
    click_function = "VOC_BackToSelection",
    function_owner = self,
    label = "Go Back",
    position = {1.0, 0.3, -1.2},
    width = 900,
    height = 380,
    font_size = 160,
    color = {0.5, 0.5, 0.55, 1},
    font_color = {1, 1, 1, 1},
    tooltip = "Return to vocation list"
  })

  log("Showing perks for " .. vocation)
  return true
end

-- Called from "Go Back" button: return to vocation grid
function VOC_BackToSelection(obj, color, alt_click)
  if selectionState.shownExplanationCard then
    VOC_HideExplanationCard()
  end
  selectionState.shownVocation = nil
  selectionState.shownSummary = nil
  local activeColor = selectionState.activeColor
  if not activeColor then return end
  VOC_ShowSelectionUI(activeColor)
  log("Back to selection grid for " .. activeColor)
end

-- =========================================================
-- BUTTON-BASED SELECTION UI (No physical tile movement)
-- =========================================================
local function showSelectionButtons(color)
  if not self or not self.clearButtons then
    log("Error: Cannot show buttons - self is invalid")
    return
  end
  
  -- NOTE: Don't clear buttons here - it removes debug buttons!
  -- Only clear if we're using physical buttons (legacy mode)
  -- For UI mode, we don't need to clear controller buttons
  -- self.clearButtons()  -- DISABLED: This was removing debug buttons
  
  log("Showing selection buttons for " .. color)
  
  -- Title button
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label = color .. " - Choose Your Vocation",
    position = {0, 0.3, 1.3},
    rotation = {0, 180, 0},
    width = 2400,
    height = 500,
    font_size = 220,
    color = {0.1, 0.1, 0.1, 1},
    font_color = {1, 1, 1, 1},
    tooltip = "Select a vocation from the buttons below"
  })
  
  -- Vocation button layout (2 rows × 3 columns)
  -- Each vocation gets its own click function
  local vocationButtons = {
    {name="Public Servant", id=VOC_PUBLIC_SERVANT, pos={-1.2, 0.3, 0.4}, func="VOC_SelectPublicServant"},
    {name="Celebrity", id=VOC_CELEBRITY, pos={0, 0.3, 0.4}, func="VOC_SelectCelebrity"},
    {name="Social Worker", id=VOC_SOCIAL_WORKER, pos={1.2, 0.3, 0.4}, func="VOC_SelectSocialWorker"},
    {name="Gangster", id=VOC_GANGSTER, pos={-1.2, 0.3, -0.4}, func="VOC_SelectGangster"},
    {name="Entrepreneur", id=VOC_ENTREPRENEUR, pos={0, 0.3, -0.4}, func="VOC_SelectEntrepreneur"},
    {name="NGO Worker", id=VOC_NGO_WORKER, pos={1.2, 0.3, -0.4}, func="VOC_SelectNGOWorker"},
  }
  
  local buttonCount = 0
  
  for _, vocBtn in ipairs(vocationButtons) do
    -- Check if vocation is already taken
    local isTaken = false
    for _, c in ipairs(COLORS) do
      if state.vocations[c] == vocBtn.id then
        isTaken = true
        break
      end
    end
    
    if not isTaken then
      -- Create button for this vocation with specific click function
      self.createButton({
        click_function = vocBtn.func,
        function_owner = self,
        label = vocBtn.name,
        position = vocBtn.pos,
        rotation = {0, 180, 0},
        width = 1100,
        height = 450,
        font_size = 160,
        color = {0.2, 0.5, 1.0, 1},
        font_color = {1, 1, 1, 1},
        tooltip = "Click to view " .. vocBtn.name .. " details and choose"
      })
      
      log("Created button for: " .. vocBtn.name .. " (" .. vocBtn.id .. ")")
      buttonCount = buttonCount + 1
    else
      log("Skipping " .. vocBtn.name .. " - already taken")
    end
  end
  
  log("Finished creating " .. buttonCount .. " vocation buttons")
end

function VOC_StartSelection(params)
  local color = normalizeColor(params.color)
  if not color then return false, "Invalid color" end
  
  local points = params and params.points or 0
  
  print("[VOC] StartSelection on GUID="..self.getGUID().." color="..tostring(color).." points="..tostring(points))
  
  -- Check if already has vocation
  if state.vocations[color] then
    log("Player " .. color .. " already has a vocation")
    return false, "Already has vocation"
  end
  
  -- Clean up any previous selection
  VOC_CleanupSelection({color=color})
  
  -- Set state explicitly
  selectionState = selectionState or {}
  selectionState.activeColor = color
  uiState = uiState or {}
  uiState.activeColor = color
  uiState.sciencePoints = points
  uiState.lastRejectReason = nil
  
  -- Primary: Global UI menu (6 vocation cards) when UI is available
  if UI then
    local showSciencePointsLabel = (params and params.showSciencePointsLabel == true)
    local ok = showSelectionUI(color, points, showSciencePointsLabel)
    if ok then
      state.currentPickerColor = color
      saveState()
      local broadcastColor = normalizeColor(color)
      if broadcastColor then
        pcall(function()
          safeBroadcastToColor("Choose your vocation from the on-screen menu!", broadcastColor, {0.3, 1, 0.3})
        end)
      end
      log("Global UI selection started for " .. color)
      return true
    end
  end

  -- Fallback: controller buttons when Global UI not available
  VOC_ShowSelectionUI(color)
  state.currentPickerColor = color
  saveState()
  local broadcastColor = normalizeColor(color)
  if broadcastColor then
    pcall(function()
      safeBroadcastToColor("Choose your vocation! Click a button on the Vocations Controller.", broadcastColor, {0.3, 1, 0.3})
    end)
  else
    broadcastToAll(color .. ": Choose your vocation! Click a button on the Vocations Controller.", {0.3, 1, 0.3})
  end
  log("Button Selection started for " .. color)
  return true
end

function noop() end  -- No-op function for title button

-- Individual button handlers for each vocation
function VOC_SelectPublicServant(obj, color, alt_click)
  handleVocationButtonClick(VOC_PUBLIC_SERVANT, color)
end

function VOC_SelectCelebrity(obj, color, alt_click)
  handleVocationButtonClick(VOC_CELEBRITY, color)
end

function VOC_SelectSocialWorker(obj, color, alt_click)
  handleVocationButtonClick(VOC_SOCIAL_WORKER, color)
end

function VOC_SelectGangster(obj, color, alt_click)
  handleVocationButtonClick(VOC_GANGSTER, color)
end

function VOC_SelectEntrepreneur(obj, color, alt_click)
  handleVocationButtonClick(VOC_ENTREPRENEUR, color)
end

function VOC_SelectNGOWorker(obj, color, alt_click)
  handleVocationButtonClick(VOC_NGO_WORKER, color)
end

function handleVocationButtonClick(vocation, clickerColor)
  local selectingColor = selectionState.activeColor
  if not selectingColor then
    log("No active selection - button clicked out of turn")
    return
  end
  
  -- Verify it's the correct player clicking
  clickerColor = normalizeColor(clickerColor)
  if clickerColor ~= selectingColor then
    log("Wrong player clicked. Active: " .. tostring(selectingColor) .. ", Clicked: " .. tostring(clickerColor))
    broadcastToAll("Only " .. selectingColor .. " can choose a vocation right now.", {1, 0.5, 0.2})
    return
  end
  
  log("Vocation button clicked: " .. vocation .. " by " .. tostring(clickerColor))
  
  -- 1) Prefer full explanation card by GUID (e.g. de1ca1 for Gangster)
  if VOC_EXPLANATION_CARD_GUID[vocation] and VOC_EXPLANATION_CARD_GUID[vocation] ~= "" then
    if VOC_ShowExplanationCard(vocation) then
      return
    end
  end
  -- 2) Else summary tile if available
  local summaryTile = findSummaryTileForVocation(vocation)
  if summaryTile then
    VOC_ShowSummary({vocation = vocation, color = selectingColor})
    return
  end
  -- 3) Fallback: text perks on controller
  VOC_ShowPerksOnController(vocation)
end

function VOC_SelectionTileClicked(obj, color, alt_click)
  color = normalizeColor(color)
  if not color then return end
  
  -- Find which vocation this tile represents
  local vocation = nil
  for _, voc in ipairs(ALL_VOCATIONS) do
    local vocTag = "WLB_VOC_" .. voc
    if obj.hasTag and obj.hasTag(vocTag) then
      vocation = voc
      break
    end
  end
  
  if not vocation then
    log("Could not determine vocation from tile")
    return
  end
  
  -- Show summary for this vocation
  VOC_ShowSummary({vocation=vocation, color=color})
end

function VOC_ShowSummary(params)
  local vocation = params.vocation
  local color = normalizeColor(params.color)
  
  if not vocation or not color then
    log("Invalid parameters for ShowSummary")
    return false
  end
  
  -- Hide any previously shown summary
  if selectionState.shownSummary then
    VOC_HideSummary({color=color})
  end
  
  -- Find summary tile
  local summaryTile = findSummaryTileForVocation(vocation)
  if not summaryTile then
    log("Summary tile not found for " .. vocation)
    local broadcastColor = normalizeColor(color)
    if broadcastColor then
      pcall(function()
        safeBroadcastToColor("Summary tile not found. Please check reference area.", broadcastColor, {1, 0.5, 0.2})
      end)
    else
      broadcastToAll(color .. ": Summary tile not found. Please check reference area.", {1, 0.5, 0.2})
    end
    return false
  end
  
  -- Position summary tile in front of player (or center)
  summaryTile.setPositionSmooth(SUMMARY_DISPLAY_POS, false, true)
  
  -- Ensure face up
  if summaryTile.flip then
    pcall(function()
      if summaryTile.is_face_down then summaryTile.flip() end
    end)
  end
  
  -- Remove any existing buttons
  removeAllButtons(summaryTile)
  
  -- Add buttons
  local vocationName = VOCATION_DATA[vocation] and VOCATION_DATA[vocation].name or vocation
  
  -- Button: "I Choose It"
  summaryTile.createButton({
    click_function = "VOC_ConfirmSelection",
    function_owner = self,
    label = "I Choose It",
    position = {-1.2, 0.3, -1.5},  -- Bottom-left
    rotation = {0, 180, 0},
    width = 1000,
    height = 400,
    font_size = 180,
    color = {0.2, 0.85, 0.25, 1.0},  -- Green
    font_color = {0, 0, 0, 1},
    tooltip = "Select " .. vocationName .. " as your vocation"
  })
  
  -- Button: "Go Back"
  summaryTile.createButton({
    click_function = "VOC_HideSummary",
    function_owner = self,
    label = "Go Back",
    position = {1.2, 0.3, -1.5},  -- Bottom-right
    rotation = {0, 180, 0},
    width = 1000,
    height = 400,
    font_size = 180,
    color = {0.6, 0.6, 0.6, 1.0},  -- Gray
    font_color = {1, 1, 1, 1},
    tooltip = "Return to selection"
  })
  
  -- Store state
  selectionState.shownSummary = summaryTile
  selectionState.shownVocation = vocation
  
  log("Summary shown for " .. vocation .. " to " .. color)
  
  return true
end

function VOC_ConfirmSelection(obj, color, alt_click)
  -- Get vocation and color from selection state
  local vocation = selectionState.shownVocation
  local selectingColor = selectionState.activeColor
  
  if not vocation or not selectingColor then
    log("Warning: Could not get vocation from selection state")
    broadcastToAll("Error: Could not confirm selection. Please try again.", {1, 0.2, 0.2})
    return
  end
  
  selectingColor = normalizeColor(selectingColor)
  
  -- Set vocation
  local success, err = VOC_SetVocation({color=selectingColor, vocation=vocation})
  
  if success then
    -- Clean up selection UI
    VOC_CleanupSelection({color=selectingColor})
    broadcastToAll(selectingColor .. " chose " .. (VOCATION_DATA[vocation] and VOCATION_DATA[vocation].name or vocation), {0.3, 1, 0.3})
    
    -- Notify TurnController that vocation was selected
    local turnCtrl = findTurnController()
    if turnCtrl and turnCtrl.call then
      pcall(function()
        turnCtrl.call("VOC_OnVocationSelected", {color=selectingColor, vocation=vocation})
      end)
    end
  else
    local broadcastColor = normalizeColor(selectingColor)
    if broadcastColor then
      pcall(function()
        safeBroadcastToColor("Selection failed: " .. tostring(err), broadcastColor, {1, 0.5, 0.2})
      end)
    else
      broadcastToAll(selectingColor .. ": Selection failed: " .. tostring(err), {1, 0.5, 0.2})
    end
  end
end

function findTurnController()
  local allObjects = getAllObjects()
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and (obj.hasTag("WLB_TURN_CTRL") or obj.hasTag("WLB_TURN_CONTROLLER")) then
      return obj
    end
  end
  return nil
end

function VOC_HideSummary(obj, color, alt_click)
  -- Handle both function call and button click
  local actualColor = nil
  if type(color) == "table" and color.color then
    -- Called as function
    actualColor = normalizeColor(color.color)
  else
    -- Called as button click
    actualColor = normalizeColor(selectionState.activeColor)
  end
  
  if not actualColor then return false end
  
  if not selectionState.shownSummary then
    return false
  end
  
  -- Remove buttons
  removeAllButtons(selectionState.shownSummary)
  
  -- Return summary tile to storage/reference area
  selectionState.shownSummary.setPositionSmooth(STORAGE_SUMMARY, false, true)
  
  selectionState.shownSummary = nil
  selectionState.shownVocation = nil
  
  log("Summary hidden for " .. actualColor)
  
  return true
end

function VOC_CleanupSelection(params)
  local color = normalizeColor(params.color)
  if not color then return false end
  
  -- Return Level 1 cards to their original positions and clear context menus
  VOC_ReturnLevel1Cards()
  -- Hide explanation card if shown
  if selectionState.shownExplanationCard then
    VOC_HideExplanationCard()
  end
  -- Hide summary tile if shown
  if selectionState.shownSummary then
    VOC_HideSummary({color=color})
  end
  
  -- Remove buttons from selection tiles (if any were used)
  if selectionState.selectionTiles then
    for _, tile in ipairs(selectionState.selectionTiles) do
      if tile and tile.clearButtons then
        removeAllButtons(tile)
      end
    end
  end
  
  -- Clear state
  if selectionState.activeColor == color then
    selectionState.activeColor = nil
  end
  if state.currentPickerColor == color then
    state.currentPickerColor = nil
    saveState()
  end
  selectionState.selectionTiles = {}
  selectionState.shownVocation = nil
  
  log("Selection cleaned up for " .. color)

  -- Restore debug buttons so players can test again after selection or restart
  pcall(function()
    if createDebugButtons then
      createDebugButtons()
      log("Debug buttons restored after cleanup")
    end
  end)
  
  return true
end

-- =========================================================
-- INITIALIZATION
-- =========================================================
local function ensureSelfTag()
  if self and self.addTag and self.hasTag then
    if not self.hasTag(TAG_SELF) then
      self.addTag(TAG_SELF)
    end
  end
end

-- =========================================================
-- RECOVERY FUNCTION (For lost tiles)
-- =========================================================
function VOC_RecoverTiles()
  log("Recovering vocation tiles...")
  
  -- Find all Level 1 tiles (including those with color tags)
  local allObjects = getAllObjects()
  local tiles = {}
  
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and
       (obj.hasTag(TAG_VOCATION_TILE) or obj.hasTag("WLB_VOCATION_TILE")) and
       obj.hasTag("WLB_VOC_LEVEL_1") then
      table.insert(tiles, obj)
      local name = obj.getName and obj.getName() or "Unknown"
      log("Found tile: " .. name)
    end
  end
  
  if #tiles == 0 then
    broadcastToAll("No Level 1 vocation tiles found", {1, 0.5, 0.2})
    return false
  end
  
  -- Move them to visible center position
  local center = {x=0, y=2.0, z=0}
  local spacing = 3.0
  local startX = center.x - (spacing * (math.min(#tiles, 6) - 1) / 2)
  
  for i, tile in ipairs(tiles) do
    if tile and tile.setPositionSmooth then
      pcall(function() tile.setLock(false) end)
      
      local pos = {
        x = startX + ((i - 1) % 6) * spacing,
        y = center.y + math.floor((i - 1) / 6) * 0.5,  -- Stack in rows if more than 6
        z = center.z
      }
      
      tile.setPositionSmooth(pos, false, true)
      
      if tile.flip then
        pcall(function()
          if tile.is_face_down then tile.flip() end
        end)
      end
      
      local name = tile.getName and tile.getName() or "Tile " .. i
      log("Recovered: " .. name .. " to " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
    end
  end
  
  broadcastToAll("✅ Recovered " .. #tiles .. " vocation tiles to center (Y=2.0)", {0.7, 1, 0.7})
  return true
end

-- =========================================================
-- UI XML HANDLERS (Screen-based HUD interface) - DUPLICATE REMOVED
-- Functions are defined earlier in the file (before VOC_StartSelection)
-- =========================================================

-- Helper function to unpack UI callback arguments
-- Handles both direct UI callbacks (player, value, id) and object.call() via Global (params table)
-- NOTE: TTS object.call() doesn't preserve Player objects, so we pass color as string instead
local function unpackUIArgs(player, value, id)
  -- Called via object.call from Global: first arg is a params table
  if type(player) == "table" and (player.id or player.value or player.player or player.color) then
    local p = player

    -- New routing format (preferred): {color="Red", id="btnCelebrity", ...}
    if p.color and not p.player then
      return { color = p.color }, p.value, p.id
    end

    -- Legacy routing format: {player=<Player>, id=..., value=...}
    if p.player then
      return p.player, p.value, p.id
    end
  end

  -- Normal UI callback signature (direct Global UI call)
  return player, value, id
end

-- UI Callback wrapper: Vocation button clicked (from Global router)
-- This is called by Global via object.call() with new routing format
function VOC_UI_SelectVocation(payload)
  local pc = payload and payload.playerColor or "Unknown"
  local id = payload and payload.buttonId or ""
  local value = payload and payload.value or -1
  
  print("[VOC] SelectVocation on GUID="..self.getGUID().." vocationId="..tostring(id).." player="..tostring(pc))
  
  -- Call the actual handler
  return UI_SelectVocation(pc, value, id)
end

-- UI Callback: Vocation button clicked (from selection screen)
function UI_SelectVocation(player, value, id)
  -- Unpack arguments (handles both direct call and object.call() from Global)
  -- NOTE: player may be a color string (new) or Player object (old/direct)
  player, value, id = unpackUIArgs(player, value, id)
  
  log("=== UI_SelectVocation CALLED IN VOCATIONSCONTROLLER ===")
  log("player/color: " .. tostring(player))
  log("player type: " .. type(player))
  log("value: " .. tostring(value))
  log("id: " .. tostring(id))
  log("uiState.activeColor: " .. tostring(uiState.activeColor))
  log("selectionState.activeColor: " .. tostring(selectionState.activeColor))
  
  -- Extract color - handle both string (new) and Player object (old/direct)
  local color = nil
  if type(player) == "string" then
    -- New approach: color passed as string
    color = normalizeColor(player)
  else
    -- Old approach: Player object
    color = normalizeColor(player and player.color or nil)
  end
  
  if not color or not id then
    log("ERROR: Missing color or id. color=" .. tostring(color) .. ", id=" .. tostring(id))
    return
  end
  
  log("Normalized color: " .. color)
  
  -- Special handling for "White" (spectator) - try to use active color instead
  if color == "White" then
    log("WARNING: Click detected from White (spectator). Attempting to use active color instead.")
    color = selectionState.activeColor or uiState.activeColor
    if not color then
      log("ERROR: No active selection and clicked as White spectator!")
      broadcastToAll("⚠ Please sit at a player color seat to select a vocation.", {1, 0.5, 0.2})
      return
    end
    log("Using active color instead: " .. color)
  end
  
  -- Check if selection is active
  local activeColor = selectionState.activeColor or uiState.activeColor
  if not activeColor then
    local reason = "selection not active (activeColor=nil)"
    uiState = uiState or {}
    uiState.lastRejectReason = reason
    print("[VOC][REJECT] "..reason)
    log("ERROR: No active selection! selectionState.activeColor=" .. tostring(selectionState.activeColor) .. ", uiState.activeColor=" .. tostring(uiState.activeColor))
    broadcastToAll("⚠ Vocation selection is not active. Please start selection first.", {1, 0.5, 0.2})
    return false, reason
  end
  
  -- Verify it's the active player
  if color ~= activeColor then
    log("UI_SelectVocation: Wrong player clicked. Active: " .. tostring(activeColor) .. ", Clicked: " .. color)
    safeBroadcastToColor("⚠ It's not your turn to select a vocation! Active player: " .. tostring(activeColor), color, {1, 0.5, 0.2})
    return
  end
  
  -- Map button ID to vocation constant
  -- Note: Button IDs in XML are like "btnPublicServant", "btnCelebrity", etc.
  local vocation = nil
  local idLower = string.lower(id or "")
  log("Button ID (lowercase): " .. idLower)
  
  if idLower == "btnpublicservant" then 
    vocation = VOC_PUBLIC_SERVANT
  elseif idLower == "btncelebrity" then 
    vocation = VOC_CELEBRITY
  elseif idLower == "btnsocialworker" then 
    vocation = VOC_SOCIAL_WORKER
  elseif idLower == "btngangster" then 
    vocation = VOC_GANGSTER
  elseif idLower == "btnentrepreneur" then 
    vocation = VOC_ENTREPRENEUR
  elseif idLower == "btnngoworker" then 
    vocation = VOC_NGO_WORKER
  end
  if not vocation then
    log("ERROR: Unknown button ID: " .. tostring(id) .. " (lowercase: " .. idLower .. ")")
    safeBroadcastToColor("⚠ Unknown vocation button clicked. ID: " .. tostring(id), color, {1, 0.3, 0.3})
    return
  end
  
  log("Mapped to vocation: " .. tostring(vocation))
  
  -- Check if already taken
  for _, c in ipairs(COLORS) do
    if state.vocations[c] == vocation and c ~= color then
      log("Vocation already taken by: " .. c)
      safeBroadcastToColor("⚠ This vocation is already taken by " .. c .. "!", color, {1, 0.5, 0.2})
      return
    end
  end
  
  -- Show summary
  log("Calling showSummaryUI for " .. color .. " -> " .. vocation)
  local ok = showSummaryUI(color, vocation)
  if ok then
    log("showSummaryUI returned true - summary should be visible")
    safeBroadcastToColor("✅ Showing vocation summary...", color, {0.3, 1, 0.3})
  else
    log("ERROR: showSummaryUI returned false")
    safeBroadcastToColor("❌ Failed to show vocation summary. Check logs.", color, {1, 0.3, 0.3})
  end
end

-- UI Callback wrapper: Confirm vocation selection (from Global router)
function VOC_UI_ConfirmVocation(payload)
  local pc = payload and payload.playerColor or "Unknown"
  local value = payload and payload.value or -1
  local id = payload and payload.id or ""
  
  print("[VOC] ConfirmVocation on GUID="..self.getGUID().." player="..tostring(pc))
  
  -- Call the actual handler
  return UI_ConfirmVocation(pc, value, id)
end

-- UI Callback: Confirm vocation selection
function UI_ConfirmVocation(player, value, id)
  -- Unpack arguments (handles both direct call and object.call() from Global)
  player, value, id = unpackUIArgs(player, value, id)
  
  -- Extract color - handle both string (new) and Player object (old/direct)
  local color = nil
  if type(player) == "string" then
    color = normalizeColor(player)
  else
    color = normalizeColor(player and player.color or nil)
  end
  
  -- Combined "who is selecting" from all state sources (in case UI click hits different object than VOC_StartSelection)
  local activeColor = uiState.activeColor or selectionState.activeColor or state.currentPickerColor

  -- Special handling for "White" (spectator/host clicks via Global UI):
  -- treat it as the active selecting player so Confirm works in solo testing / hotseat.
  if color == "White" then
    log("WARNING: Confirm click detected from White (spectator). Attempting to use active color instead.")
    color = activeColor
    if not color then
      log("ERROR: Confirm clicked as White but no active color is set")
      broadcastToAll("⚠ Please sit at a player color seat (Yellow/Blue/Red/Green) to confirm.", {1, 0.5, 0.2})
      return
    end
    log("Using active color instead for confirm: " .. tostring(color))
  end
  
  if not color then return end
  
  -- Verify it's the active player (use combined active so 2nd player works when uiState was cleared on another object)
  if not activeColor then
    log("UI_ConfirmVocation: No active selection (activeColor=nil). selectionState.activeColor=" .. tostring(selectionState.activeColor) .. " uiState.activeColor=" .. tostring(uiState.activeColor) .. " currentPickerColor=" .. tostring(state.currentPickerColor))
    broadcastToAll("⚠ Vocation selection is not active. Please start selection first.", {1, 0.5, 0.2})
    return
  end
  if color ~= activeColor then
    log("UI_ConfirmVocation: Wrong player. Active: " .. tostring(activeColor) .. ", Clicked: " .. tostring(color))
    return
  end
  
  local vocation = uiState.previewedVocation
  if not vocation then
    log("ERROR: No vocation previewed for confirmation")
    return
  end
  
  -- Double-check it's not taken (race condition protection)
  for _, c in ipairs(COLORS) do
    if state.vocations[c] == vocation and c ~= color then
      safeBroadcastToColor("❌ " .. vocation .. " was just taken by " .. c .. "! Please choose another.", color, {1, 0.3, 0.3})
      hideSummaryUI()
      return
    end
  end

  -- When Youth (no science-point pool): skip allocation screen and advance to next player or end
  local turnCtrl = findTurnController()
  local showAllocation = false
  if turnCtrl and turnCtrl.call then
    local ok, v = pcall(function() return turnCtrl.call("API_ShouldShowAllocationAfterVocation", {}) end)
    if ok and v then showAllocation = v end
  end
  if not showAllocation then
    -- Set vocation, place tile, notify TurnController, then close UI and advance
    local ok, err = VOC_SetVocation({color = color, vocation = vocation, level = 1})
    if not ok then
      safeBroadcastToColor("❌ Failed to set vocation: " .. tostring(err), color, {1, 0.3, 0.3})
      return
    end
    local tile = findTileForVocationAndLevel(vocation, 1)
    if tile then placeTileOnBoard(tile, color) end
    if turnCtrl and turnCtrl.call then
      pcall(function() turnCtrl.call("VOC_OnVocationSelected", {color = color, vocation = vocation}) end)
      hideSummaryUI()
      hideSelectionUI()
      uiState.selectionCardColor = nil
      pcall(function() turnCtrl.call("API_AllocationConfirmed", {}) end)
    end
    safeBroadcastToColor("✅ You chose: " .. (VOCATION_DATA[vocation] and VOCATION_DATA[vocation].name or vocation), color, {0.3, 1, 0.3})
    uiState.activeColor = nil
    uiState.currentScreen = nil
    uiState.previewedVocation = nil
    return
  end

  -- Show selection card after Confirm (hide explanation and buttons so only the card is visible)
  local selectionCardUrl = VOCATION_SELECTION_CARD_IMAGE[vocation]
  if selectionCardUrl and selectionCardUrl ~= "" then
    UI.setAttribute("selectionCardImage", "image", selectionCardUrl)
    UI.setAttribute("selectionCardPanel", "active", "true")
    UI.setAttribute("summaryVocationImage", "active", "false")
    UI.setAttribute("actionButtons", "active", "false")
    uiState.selectionCardColor = color
    local turnCtrl = findTurnController()
    local pool, k, s = getSciencePointsForColor(color), 0, 0
    if turnCtrl and turnCtrl.call then
      local ok, st = pcall(function() return turnCtrl.call("API_GetAllocState", {color = color}) end)
      if ok and st and type(st) == "table" then
        pool = st.pool or pool
        k = st.k or 0
        s = st.s or 0
      end
    end
    UI.setAttribute("selectionCardSciencePoints", "text", tostring(pool))
    UI.setAttribute("selectionCardKnowledgeValue", "text", tostring(k))
    UI.setAttribute("selectionCardSkillsValue", "text", tostring(s))
    if turnCtrl then
      refreshSelectionCardAllocUI(turnCtrl, color)
    else
      UI.setAttribute("selectionCardApply", "interactable", (tonumber(pool) or 0) == 0 and "true" or "false")
      -- Keep apply button invisible even when enabled
      UI.setAttribute("selectionCardApply", "color", "#00000000")
      UI.setAttribute("selectionCardApply", "fontColor", "#00000000")
    end
    log("UI_ConfirmVocation: Showing selection card for " .. vocation .. ", pool=" .. tostring(pool) .. " K=" .. k .. " S=" .. s)
  end
  
  -- Set the vocation
  local ok, err = VOC_SetVocation({color = color, vocation = vocation, level = 1})
  if not ok then
    safeBroadcastToColor("❌ Failed to set vocation: " .. tostring(err), color, {1, 0.3, 0.3})
    return
  end
  
  -- Place Level 1 tile on player board
  local tile = findTileForVocationAndLevel(vocation, 1)
  if tile then
    placeTileOnBoard(tile, color)
  end
  
  -- Notify TurnController
  local turnCtrl = findTurnController()
  if turnCtrl and turnCtrl.call then
    pcall(function()
      turnCtrl.call("VOC_OnVocationSelected", {color = color, vocation = vocation})
    end)
  end
  
  safeBroadcastToColor("✅ You chose: " .. (VOCATION_DATA[vocation] and VOCATION_DATA[vocation].name or vocation), color, {0.3, 1, 0.3})
  log("Vocation confirmed: " .. color .. " -> " .. vocation)
  
  -- Keep selection UI visible (selection card stays on screen); do not hide overlay/panels
  uiState.activeColor = nil
  uiState.currentScreen = nil
  uiState.previewedVocation = nil
end

-- UI Callback: Science points allocation (+K, -K, +S, -S) from selection card or science panel
-- Payload: { color, value, id } from Global (id = selectionCardKPlus, selectionCardKMinus, selectionCardSPlus, selectionCardSMinus, or btnKPlus, btnKMinus, btnSPlus, btnSMinus)
function UI_AllocScience(payload)
  local color, id
  if type(payload) == "table" and (payload.color or payload.id) then
    color = normalizeColor(payload.color or payload.playerColor or "White")
    id = payload.id or ""
  else
    color = normalizeColor("White")
    id = ""
  end
  if color == "White" and uiState.selectionCardColor then
    color = uiState.selectionCardColor
  end
  if not color or not id or id == "" then return end

  local which, delta
  local idLower = string.lower(id)
  if idLower == "selectioncardkplus" or idLower == "btnkplus" then which, delta = "K", 1
  elseif idLower == "selectioncardkminus" or idLower == "btnkminus" then which, delta = "K", -1
  elseif idLower == "selectioncardsplus" or idLower == "btnsplus" then which, delta = "S", 1
  elseif idLower == "selectioncardsminus" or idLower == "btnsminus" then which, delta = "S", -1
  else return
  end

  local turnCtrl = findTurnController()
  if not turnCtrl or not turnCtrl.call then
    log("UI_AllocScience: TurnController not found")
    return
  end

  local ok = pcall(function()
    return turnCtrl.call("API_AllocScience", { color = color, which = which, delta = delta })
  end)
  if not ok then
    log("UI_AllocScience: API_AllocScience failed for " .. color .. " " .. which .. " " .. tostring(delta))
    return
  end

  -- Refresh selection card display if this player is on the selection card
  if uiState.selectionCardColor == color then
    refreshSelectionCardAllocUI(turnCtrl, color)
  end
end

-- UI Callback: Apply allocated K/S to player board (selection card Apply button)
function UI_ApplyAllocScience(payload)
  local color
  if type(payload) == "table" and (payload.color or payload.playerColor) then
    color = normalizeColor(payload.color or payload.playerColor or "White")
  else
    color = "White"
  end
  if color == "White" and uiState.selectionCardColor then
    color = uiState.selectionCardColor
  end
  if not color then return end

  local turnCtrl = findTurnController()
  if not turnCtrl or not turnCtrl.call then
    log("UI_ApplyAllocScience: TurnController not found")
    return
  end

  pcall(function()
    turnCtrl.call("API_ApplyAlloc", { color = color })
  end)
  refreshSelectionCardAllocUI(turnCtrl, color)

  -- Close vocation selection UI and advance: next player gets vocation selection, or game continues if last
  hideSummaryUI()
  hideSelectionUI()
  uiState.selectionCardColor = nil
  -- Short delay so UI fully closes before we show the next player's selection (avoids UI not appearing for 2nd player)
  if Wait and Wait.time then
    Wait.time(function()
      pcall(function()
        turnCtrl.call("API_AllocationConfirmed", {})
      end)
    end, 0.5)
  else
    pcall(function()
      turnCtrl.call("API_AllocationConfirmed", {})
    end)
  end
end

-- UI Callback wrapper: Back to selection screen (from Global router)
function VOC_UI_BackToSelection(payload)
  local pc = payload and payload.playerColor or "Unknown"
  local value = payload and payload.value or -1
  local id = payload and payload.id or ""
  
  print("[VOC] BackToSelection on GUID="..self.getGUID().." player="..tostring(pc))
  
  -- Call the actual handler
  return UI_BackToSelection(pc, value, id)
end

-- UI Callback: Back to selection screen
function UI_BackToSelection(player, value, id)
  -- Unpack arguments (handles both direct call and object.call() from Global)
  player, value, id = unpackUIArgs(player, value, id)
  
  -- Extract color - handle both string (new) and Player object (old/direct)
  local color = nil
  if type(player) == "string" then
    color = normalizeColor(player)
  else
    color = normalizeColor(player and player.color or nil)
  end
  
  -- Special handling for "White" (spectator/host clicks via Global UI): use active color.
  if color == "White" then
    log("WARNING: Back click detected from White (spectator). Attempting to use active color instead.")
    color = uiState.activeColor or selectionState.activeColor or state.currentPickerColor
    if not color then
      log("UI_BackToSelection: No active color available (clicked as White)")
      broadcastToAll("⚠ Please sit at a player color seat (Yellow/Blue/Red/Green) to go back.", {1, 0.5, 0.2})
      return
    end
    log("Using active color instead for back: " .. tostring(color))
  end
  
  if not color then 
    -- Try to get active color from state
    color = selectionState.activeColor or uiState.activeColor or state.currentPickerColor
    if not color then
      log("UI_BackToSelection: No color available")
      return
    end
  end
  
  -- Verify it's the active player (or allow if no active player set)
  if uiState.activeColor and color ~= uiState.activeColor then
    log("UI_BackToSelection: Wrong player. Active: " .. tostring(uiState.activeColor) .. ", Clicked: " .. tostring(color))
    return
  end
  
  -- Get science points for this color
  local sciencePoints = getSciencePointsForColor(color)
  
  -- Hide summary, show selection again with science points
  hideSummaryUI()
  showSelectionUI(color, sciencePoints)
end

-- UI Callback wrapper: Close vocation explanation (Exit in "Show explanation" – hide UI, back to playing)
function VOC_UI_CloseVocationExplanation(payload)
  local pc = payload and payload.playerColor or "Unknown"
  print("[VOC] CloseVocationExplanation on GUID=" .. tostring(self.getGUID()) .. " player=" .. tostring(pc))
  if not UI then return end
  pcall(function()
    UI.setAttribute("vocationSummaryPanel", "active", "false")
    UI.setAttribute("vocationOverlay", "active", "false")
  end)
  uiState.currentScreen = nil
  uiState.previewedVocation = nil
  log("Vocation explanation closed – UI hidden, back to playing")
end

-- UI Callback wrapper: Cancel selection (from Global router)
function VOC_UI_CancelSelection(payload)
  local pc = payload and payload.playerColor or "Unknown"
  local value = payload and payload.value or -1
  local id = payload and payload.id or ""
  
  print("[VOC] CancelSelection on GUID="..self.getGUID().." player="..tostring(pc))
  
  -- Call the actual handler
  return UI_CancelSelection(pc, value, id)
end

-- UI Callback: Cancel selection (close UI)
function UI_CancelSelection(player, value, id)
  -- Unpack arguments (handles both direct call and object.call() from Global)
  player, value, id = unpackUIArgs(player, value, id)
  
  log("=== UI_CancelSelection CALLED ===")
  log("player/color: " .. tostring(player))
  log("value: " .. tostring(value))
  log("id: " .. tostring(id))
  
  -- Extract color - handle both string (new) and Player object (old/direct)
  local color = nil
  if type(player) == "string" then
    color = normalizeColor(player)
  else
    color = normalizeColor(player and player.color or nil)
  end
  
  if not color then 
    log("WARNING: No color parameter, but continuing with cancel anyway")
  end
  log("Normalized color: " .. tostring(color))
  log("Current activeColor: " .. tostring(uiState.activeColor))
  
  -- Allow any player to cancel (remove restriction for now)
  -- if color ~= uiState.activeColor and uiState.activeColor ~= nil then
  --   log("UI_CancelSelection: Wrong player. Active: " .. tostring(uiState.activeColor) .. ", Clicked: " .. color)
  --   return
  -- end
  
  log("Hiding UI panels...")
  
  -- Hide all UI - direct kill switch approach
  if UI then
    pcall(function()
      log("Setting vocationSelectionPanel active=false")
      UI.setAttribute("vocationSelectionPanel", "active", "false")
      log("Setting vocationSummaryPanel active=false")
      UI.setAttribute("vocationSummaryPanel", "active", "false")
      log("Setting sciencePointsPanel active=false")
      UI.setAttribute("sciencePointsPanel", "active", "false")
      log("Setting vocationOverlay active=false")
      UI.setAttribute("vocationOverlay", "active", "false")
    end)
  else
    log("ERROR: UI is nil!")
  end
  
  hideSummaryUI()
  hideSelectionUI()
  
  -- Reset UI state
  uiState.activeColor = nil
  uiState.currentScreen = nil
  uiState.previewedVocation = nil
  
  log("Vocation selection cancelled by " .. tostring(color))
  broadcastToAll("Vocation selection cancelled", {0.7, 0.7, 0.7})
  
  log("=== UI_CancelSelection COMPLETE ===")
end

-- Updated VOC_StartSelection to use UI instead of buttons
function VOC_StartSelection_UI(params)
  local color = normalizeColor(params.color)
  if not color then return false, "Invalid color" end
  
  -- Check if already has vocation
  if state.vocations[color] then
    log("Player " .. color .. " already has a vocation")
    return false, "Already has vocation"
  end
  
  -- Show UI selection screen
  local ok = showSelectionUI(color)
  if not ok then
    return false, "Failed to show UI"
  end
  
  selectionState.activeColor = color
  
  -- Broadcast to player
  local broadcastColor = normalizeColor(color)
  if broadcastColor then
    pcall(function()
      safeBroadcastToColor("Choose your vocation from the on-screen UI!", broadcastColor, {0.3, 1, 0.3})
    end)
  end
  
  log("UI Selection started for " .. color)
  return true
end

-- =========================================================
-- INTERACTION UI CALLBACKS (JOIN / IGNORE)
-- =========================================================

function UI_Interaction_YellowJoin(params)
  local actor = params and params.playerColor
  handleInteractionResponse("Yellow", "JOIN", actor)
end

function UI_Interaction_YellowIgnore(params)
  local actor = params and params.playerColor
  handleInteractionResponse("Yellow", "IGNORE", actor)
end

function UI_Interaction_BlueJoin(params)
  local actor = params and params.playerColor
  handleInteractionResponse("Blue", "JOIN", actor)
end

function UI_Interaction_BlueIgnore(params)
  local actor = params and params.playerColor
  handleInteractionResponse("Blue", "IGNORE", actor)
end

function UI_Interaction_RedJoin(params)
  local actor = params and params.playerColor
  handleInteractionResponse("Red", "JOIN", actor)
end

function UI_Interaction_RedIgnore(params)
  local actor = params and params.playerColor
  handleInteractionResponse("Red", "IGNORE", actor)
end

function UI_Interaction_GreenJoin(params)
  local actor = params and params.playerColor
  handleInteractionResponse("Green", "JOIN", actor)
end

function UI_Interaction_GreenIgnore(params)
  local actor = params and params.playerColor
  handleInteractionResponse("Green", "IGNORE", actor)
end

-- =========================================================
-- TEST BUTTON (for UI debugging) - Must be defined before onLoad
-- =========================================================
local function createTestButton()
  if not self or not self.createButton then
    log("WARNING: Cannot create test button - self.createButton not available")
    return
  end
  
  -- Create test button
  pcall(function()
    self.createButton({
      label = "TEST UI",
      click_function = "btnTestUI",
      function_owner = self,
      position = {0, 0.3, 0},
      rotation = {0, 180, 0},
      width = 800,
      height = 300,
      font_size = 150,
      color = {0.2, 0.6, 1.0},
      font_color = {1, 1, 1},
      tooltip = "Click to test if UI XML is loaded correctly"
    })
    log("✅ Test button created on VocationsController")
  end)
end

-- Button click handler for UI test (must be global function)
function btnTestUI(obj, player)
  log("=== UI TEST BUTTON CLICKED ===")
  
  if not UI then
    broadcastToAll("❌ UI system not available (Global UI is nil)", {1, 0.3, 0.3})
    log("ERROR: UI is nil - UI XML must be in Global → UI tab")
    return
  end
  
  broadcastToAll("🔍 Testing UI system (Global UI)...", {0.5, 0.5, 1})
  log("UI system is available (Global UI), testing panels...")
  
  -- Test Panel 1: vocationSelectionPanel
  local panel1Ok = false
  local panel1Attr = nil
  local panel1Err = nil
  
  local test1Ok, test1Result = pcall(function()
    panel1Attr = UI.getAttribute("vocationSelectionPanel", "active")
    panel1Ok = (panel1Attr ~= nil)
    return panel1Attr
  end)
  
  if not test1Ok then
    panel1Err = tostring(test1Result)
  end
  
  -- Test Panel 2: vocationSummaryPanel
  local panel2Ok = false
  local panel2Attr = nil
  local panel2Err = nil
  
  local test2Ok, test2Result = pcall(function()
    panel2Attr = UI.getAttribute("vocationSummaryPanel", "active")
    panel2Ok = (panel2Attr ~= nil)
    return panel2Attr
  end)
  
  if not test2Ok then
    panel2Err = tostring(test2Result)
  end
  
  -- Test Overlay: vocationOverlay (CRITICAL - panels are inside this)
  local overlayOk = false
  local overlayAttr = nil
  local overlayErr = nil
  
  local testOverlayOk, testOverlayResult = pcall(function()
    overlayAttr = UI.getAttribute("vocationOverlay", "active")
    overlayOk = (overlayAttr ~= nil)
    return overlayAttr
  end)
  
  if not testOverlayOk then
    overlayErr = tostring(testOverlayResult)
  end
  
  -- Report results
  log("=== TEST RESULTS ===")
  log("Overlay (vocationOverlay):")
  log("  - testOverlayOk: " .. tostring(testOverlayOk))
  log("  - overlayAttr: " .. tostring(overlayAttr))
  log("  - overlayOk: " .. tostring(overlayOk))
  if overlayErr then log("  - ERROR: " .. overlayErr) end
  
  log("Panel 1 (vocationSelectionPanel):")
  log("  - test1Ok: " .. tostring(test1Ok))
  log("  - panel1Attr: " .. tostring(panel1Attr))
  log("  - panel1Ok: " .. tostring(panel1Ok))
  if panel1Err then log("  - ERROR: " .. panel1Err) end
  
  log("Panel 2 (vocationSummaryPanel):")
  log("  - test2Ok: " .. tostring(test2Ok))
  log("  - panel2Attr: " .. tostring(panel2Attr))
  log("  - panel2Ok: " .. tostring(panel2Ok))
  if panel2Err then log("  - ERROR: " .. panel2Err) end
  
  -- Broadcast results
  if overlayOk and panel1Ok and panel2Ok then
    broadcastToAll("✅ SUCCESS: Overlay and UI panels found!", {0.3, 1, 0.3})
    broadcastToAll("Overlay active=" .. tostring(overlayAttr) .. ", Panel 1 active=" .. tostring(panel1Attr) .. ", Panel 2 active=" .. tostring(panel2Attr), {0.7, 1, 0.7})
    
    -- Try to show panel 1 as a test
    Wait.time(function()
      pcall(function()
        -- CRITICAL: Overlay must be active first, then the panel inside it
        UI.setAttribute("vocationOverlay", "active", "true")
        UI.setAttribute("vocationSelectionPanel", "active", "true")
        UI.setAttribute("vocationSummaryPanel", "active", "false")
        UI.setAttribute("sciencePointsPanel", "active", "false")
        UI.setAttribute("selectionSubtitle", "text", "TEST MODE - UI Working!")
        broadcastToAll("✅ UI Panel should be visible now! (Overlay + Selection Panel activated)", {0.3, 1, 0.3})
        log("TEST: Overlay and Selection Panel activated")
      end)
    end, 0.2)
  else
    broadcastToAll("❌ FAILED: UI elements NOT found!", {1, 0.3, 0.3})
    if not overlayOk then
      broadcastToAll("❌ Overlay (vocationOverlay) missing - CRITICAL!", {1, 0.2, 0.2})
    end
    if not panel1Ok then
      broadcastToAll("❌ Panel 1 (vocationSelectionPanel) missing", {1, 0.3, 0.3})
    end
    if not panel2Ok then
      broadcastToAll("❌ Panel 2 (vocationSummaryPanel) missing", {1, 0.3, 0.3})
    end
      broadcastToAll("📋 SOLUTION:", {1, 0.7, 0.2})
      broadcastToAll("1) Go to Global → UI tab", {1, 0.8, 0.3})
      broadcastToAll("2) Clear all (CTRL+A, Delete)", {1, 0.8, 0.3})
      broadcastToAll("3) Paste VocationsUI_Global.xml content", {1, 0.8, 0.3})
      broadcastToAll("4) Click 'Save & Apply'", {1, 0.8, 0.3})
  end
end

-- =========================================================
-- DEBUG BUTTONS AND TESTING FUNCTIONS (must be before onLoad)
-- =========================================================

-- Create debug buttons on the VocationsController object
local function createDebugButtons()
  if not self or not self.createButton then
    log("WARNING: Cannot create debug buttons - self.createButton not available")
    return
  end
  
  -- Don't clear buttons - we want to keep debug buttons visible
  -- Only clear if explicitly requested (for testing)
  -- if self.clearButtons then
  --   pcall(function() self.clearButtons() end)
  -- end
  
  -- Create debug buttons: 2 above, 3 below (to avoid covering test button and overlapping)
  local buttons = {
    -- Top row (above)
    { label = "TEST\nSELECTION", fn = "btnDebugStartSelection", pos = {-0.75, 0.6, 0}, color = {0.2, 0.6, 1.0} },
    { label = "TEST\nSUMMARY", fn = "btnDebugShowSummary", pos = {0.75, 0.6, 0}, color = {0.2, 1.0, 0.6} },
    -- Bottom row (below)
    { label = "TEST\nCALLBACK", fn = "btnDebugTestCallback", pos = {-0.75, 0.0, 0}, color = {1.0, 0.6, 0.2} },
    { label = "FULL\nTEST", fn = "btnDebugFullTest", pos = {0.0, 0.0, 0}, color = {0.8, 0.2, 0.8} },
    { label = "TEST\nSW L2 EVT", fn = "btnDebug_TestSWEvent", pos = {0.75, 0.0, 0}, color = {0.9, 0.3, 0.3} },
  }
  
  for _, btn in ipairs(buttons) do
    pcall(function()
      self.createButton({
        label = btn.label,
        click_function = btn.fn,
        function_owner = self,
        position = btn.pos,
        rotation = {0, 180, 0},
        width = 600,
        height = 250,
        font_size = 100,
        color = btn.color,
        font_color = {1, 1, 1},
        tooltip = "Debug: " .. btn.label
      })
    end)
  end
  
  log("✅ Debug buttons created on VocationsController")
end

function onLoad()
  ensureSelfTag()
  loadState()
  log("VocationsController v" .. VERSION .. " loaded")

  -- Create debug buttons immediately and again after a short delay so they appear after restart.
  -- (TTS may not have the object fully ready on first frame; delayed creation ensures visibility.)
  createDebugButtons()
  if Wait and Wait.time then
    Wait.time(function()
      if self and self.createButton and createDebugButtons then
        createDebugButtons()
        log("VocationsController: debug buttons created (delayed)")
      end
      -- Ensure vocation tiles on player boards have LMB button and lock (e.g. from saved game)
      if self and self.getGUID then
        local list = getAllObjects()
        for _, obj in ipairs(list) do
          if obj and type(obj.hasTag) == "function" and obj.hasTag(TAG_VOCATION_TILE) then
            local hasColor = false
            for _, c in ipairs(COLORS) do
              if obj.hasTag(colorTag(c)) then hasColor = true; break end
            end
            if hasColor then
              pcall(function() if obj.clearContextMenu then obj.clearContextMenu() end end)
              addClickToShowExplanationButton(obj)
              pcall(function() if obj.setLock then obj.setLock(false) end end)
            end
          end
        end
      end
    end, 1.0)
  end

  -- Verify critical functions exist
  if not VOC_StartSelection then
    log("ERROR: VOC_StartSelection function not defined!")
  else
    log("VOC_StartSelection function verified")
  end
  
  -- Verify UI XML is loaded (using Global UI)
  if UI then
    log("UI system is available (Global UI)")
    
    -- Test if panels exist
    local panel1Ok, panel1Attr = pcall(function()
      return UI.getAttribute("vocationSelectionPanel", "active")
    end)
    
    local panel2Ok, panel2Attr = pcall(function()
      return UI.getAttribute("vocationSummaryPanel", "active")
    end)
    
    if panel1Ok and panel1Attr ~= nil then
      log("✅ UI Panel 'vocationSelectionPanel' found and accessible (active=" .. tostring(panel1Attr) .. ")")
      pcall(function()
        UI.setAttribute("vocationSelectionPanel", "active", "false")
      end)
    else
      log("❌ ERROR: UI Panel 'vocationSelectionPanel' NOT FOUND!")
      log("❌ This means VocationsUI_Global.xml is NOT loaded in Global → UI tab!")
      log("❌ OR the XML has parsing errors (check for typos, wrong tags, etc.)")
      log("❌ Please: 1) Go to Global → UI tab")
      log("❌ 2) Clear all (CTRL+A, Delete), 3) Paste FULL VocationsUI_Global.xml content")
      log("❌ 4) Click 'Save & Apply'")
      broadcastToAll("⚠️ VocationsController: UI XML not loaded! Check Global → UI tab.", {1, 0.5, 0.2})
    end
    
    if panel2Ok and panel2Attr ~= nil then
      log("✅ UI Panel 'vocationSummaryPanel' found and accessible (active=" .. tostring(panel2Attr) .. ")")
      pcall(function()
        UI.setAttribute("vocationSummaryPanel", "active", "false")
      end)
    else
      log("❌ ERROR: UI Panel 'vocationSummaryPanel' NOT FOUND!")
    end
  else
    log("⚠️ WARNING: UI system not available (Global UI is nil)")
    broadcastToAll("⚠️ VocationsController: UI system not available (Global UI is nil)", {1, 0.5, 0.2})
  end
  
  -- Debug buttons are created above in createDebugButtons()
end

-- Test function to verify controller is accessible
function VOC_Test()
  return "VocationsController is working! Version " .. VERSION
end

-- Test function to verify UI is loaded and manually show it
function VOC_TestUI()
  if not UI then
    broadcastToAll("❌ UI system not available - UI is nil. XML must be in Global → UI tab", {1, 0.3, 0.3})
    return "❌ UI system not available - UI is nil"
  end
  
  broadcastToAll("🔍 Testing UI system (Global UI)...", {0.5, 0.5, 1})
  
  -- Test 1: Check if panel exists
  local ok1, attr1 = pcall(function()
    return UI.getAttribute("vocationSelectionPanel", "active")
  end)
  
  if not ok1 or attr1 == nil then
    broadcastToAll("❌ Panel 'vocationSelectionPanel' not found in UI XML!", {1, 0.3, 0.3})
    return "❌ Panel not found: " .. tostring(attr1)
  end
  
  log("DEBUG TEST: Panel exists, current active: " .. tostring(attr1))
  
  -- Test 2: Try to show the panel
  local ok2, err2 = pcall(function()
    UI.setAttribute("vocationSelectionPanel", "active", "true")
    UI.setAttribute("vocationSelectionPanel", "position", "0,-300")
    UI.setAttribute("selectionSubtitle", "text", "TEST MODE - UI Check")
  end)
  
  if not ok2 then
    broadcastToAll("❌ Failed to activate panel: " .. tostring(err2), {1, 0.3, 0.3})
    return "❌ Failed to activate: " .. tostring(err2)
  end
  
  -- Test 3: Verify it was set
  Wait.time(function()
    if UI then
      local verify = UI.getAttribute("vocationSelectionPanel", "active")
      log("DEBUG TEST: Panel active after set: " .. tostring(verify))
      if verify == "true" then
        broadcastToAll("✅ UI Test: Panel is ACTIVE. You should see the selection UI now!", {0.3, 1, 0.3})
      else
        broadcastToAll("⚠️ UI Test: Panel active=" .. tostring(verify) .. " (expected 'true')", {1, 0.7, 0.2})
      end
    end
  end, 0.2)
  
  return "✅ UI Test completed. Check if panel is visible."
end

-- Manual function to show UI for testing
function VOC_ShowUITest()
  if not UI then
    broadcastToAll("❌ UI not available (Global UI is nil)", {1, 0.3, 0.3})
    return
  end
  
  pcall(function()
    UI.setAttribute("vocationSelectionPanel", "active", "true")
    UI.setAttribute("vocationSelectionPanel", "position", "0,-300")
    UI.setAttribute("selectionSubtitle", "text", "MANUAL TEST")
    broadcastToAll("✅ Manually activated UI panel", {0.3, 1, 0.3})
  end)
end

-- Debug button: Test starting selection
function btnDebugStartSelection(obj, player)
  log("=== DEBUG: Testing VOC_StartSelection ===")
  local color = "Green"  -- Default test color
  if player and player.color then
    color = normalizeColor(player.color) or "Green"
  end
  
  log("Starting selection for: " .. color)
  local ok, err = VOC_StartSelection({color = color})
  if ok then
    broadcastToAll("✅ Selection started for " .. color, {0.3, 1, 0.3})
    log("✅ Selection started successfully")
  else
    broadcastToAll("❌ Failed to start selection: " .. tostring(err), {1, 0.3, 0.3})
    log("❌ Failed: " .. tostring(err))
  end
end

-- Debug button: Test showing summary panel directly
function btnDebugShowSummary(obj, player)
  log("=== DEBUG: Testing showSummaryUI directly ===")
  
  if not UI then
    broadcastToAll("❌ UI not available", {1, 0.3, 0.3})
    return
  end
  
  local color = "Green"
  if player and player.color then
    color = normalizeColor(player.color) or "Green"
  end
  
  -- Test with GANGSTER vocation
  local ok = showSummaryUI(color, VOC_GANGSTER)
  if ok then
    broadcastToAll("✅ Summary panel shown for " .. color .. " -> GANGSTER", {0.3, 1, 0.3})
    log("✅ Summary panel shown successfully")
  else
    broadcastToAll("❌ Failed to show summary panel", {1, 0.3, 0.3})
    log("❌ Failed to show summary panel")
  end
end

-- Debug button: Test callback routing
function btnDebugTestCallback(obj, player)
  log("=== DEBUG: Testing callback routing ===")
  
  local color = "Green"
  if player and player.color then
    color = normalizeColor(player.color) or "Green"
  end
  
  -- Simulate what Global does
  log("Simulating Global callback with color: " .. color .. ", id: btnGangster")
  
  -- Set active color first
  selectionState.activeColor = color
  uiState.activeColor = color
  
  -- Call UI_SelectVocation directly with color string (simulating Global → Object call)
  UI_SelectVocation(color, -1, "btnGangster")
  
  broadcastToAll("✅ Callback test executed. Check logs.", {0.5, 0.5, 1})
end

-- Function to restore debug buttons if they disappear
function VOC_RestoreDebugButtons()
  log("Restoring debug buttons...")
  createDebugButtons()
  broadcastToAll("✅ Debug buttons restored", {0.3, 1, 0.3})
end

-- Debug button: Full test flow
function btnDebugFullTest(obj, player)
  log("=== DEBUG: Full test flow ===")
  
  local color = "Green"
  if player and player.color then
    color = normalizeColor(player.color) or "Green"
  end
  
  broadcastToAll("🔍 Starting full test flow for " .. color, {0.5, 0.5, 1})
  
  -- Step 1: Start selection
  log("Step 1: Starting selection...")
  local ok1, err1 = VOC_StartSelection({color = color})
  if not ok1 then
    broadcastToAll("❌ Step 1 failed: " .. tostring(err1), {1, 0.3, 0.3})
    return
  end
  
  Wait.time(function()
    -- Step 2: Simulate clicking a vocation
    log("Step 2: Simulating vocation click...")
    selectionState.activeColor = color
    uiState.activeColor = color
    UI_SelectVocation(color, -1, "btnGangster")
    
    Wait.time(function()
      -- Step 3: Verify summary panel is active
      log("Step 3: Verifying summary panel...")
      if UI then
        local ok, active = pcall(function()
          return UI.getAttribute("vocationSummaryPanel", "active")
        end)
        if ok and active == "true" then
          broadcastToAll("✅ Full test PASSED! Summary panel is active.", {0.3, 1, 0.3})
          log("✅ Full test PASSED")
        else
          broadcastToAll("❌ Full test FAILED: Summary panel not active (active=" .. tostring(active) .. ")", {1, 0.3, 0.3})
          log("❌ Full test FAILED: active=" .. tostring(active))
        end
      end
    end, 0.5)
  end, 0.5)
end

-- Debug button: Test Social Worker L2 community wellbeing session interaction
function btnDebug_TestSWEvent(obj, player)
  log("=== DEBUG: Testing Social Worker L2 community wellbeing session ===")
  
  -- Prefer the clicking player's color if seated; otherwise pick the first seated color as initiator.
  local color = nil
  if player and player.color and player.color ~= "" and player.color ~= "White" then
    local pc = normalizeColor(player.color)
    if pc and isPlayableColor(pc) then
      color = pc
    end
  end

  if not color then
    for _, c in ipairs(COLORS) do
      if isPlayableColor(c) then
        color = c
        break
      end
    end
  end

  if not color then
    color = "Green" -- fallback for edge cases
  end

  -- Force vocation and level for test
  state.vocations[color] = VOC_SOCIAL_WORKER
  state.levels[color] = 2
  saveState()

  local ok, reason = VOC_StartSocialWorkerCommunitySession({ color = color })
  if ok == false then
    broadcastToAll("❌ SW L2 event test failed: " .. tostring(reason), {1, 0.3, 0.3})
  else
    broadcastToAll("✅ SW L2 event started for " .. tostring(color) .. ". Other players can now JOIN / IGNORE on the interaction UI.", {0.3, 1, 0.3})
  end
end
