-- =========================================================
-- WLB VOCATIONS CONTROLLER v1.0.0 (REFACTORED - _G.WLB.VOC)
-- GOAL: Track player vocations, levels, and promotion progress
-- Manages vocation selection, tile placement, work income, and promotions
-- REFACTOR: All cross-chunk helpers in _G.WLB.VOC to avoid TTS chunk nil errors
-- =========================================================

-- =========================================================
-- BOOTSTRAP: _G.WLB.VOC namespace (chunk-safe - _G is shared)
-- =========================================================
_G.WLB = _G.WLB or {}
_G.WLB.VOC = _G.WLB.VOC or {}
VOC = _G.WLB.VOC  -- Global (no local): any TTS chunk can access via _G.VOC
-- Ensure VOC is globally reachable from any TTS chunk (chunks may have separate scope)
_G.VOC = _G.WLB.VOC

-- KONSULTANT: accessor - w TTS "goły" VOC może być nil w innym chunku; _G jest wspólne
local function VOC_NS()
  return (_G and (_G.VOC or (_G.WLB and _G.WLB.VOC))) or nil
end
_G.VOC_NS = VOC_NS  -- chunk-safe: dostępny z każdego chunku

VOC.DEBUG = true
VOC.VERSION = "1.0.0"
VOC.TAGS = {
  SELF = "WLB_VOCATIONS_CTRL",
  BOARD = "WLB_BOARD",
  TURN_CTRL = "WLB_TURN_CTRL",
  TURN_CTRL_ALT = "WLB_TURN_CONTROLLER",
  TOKEN_ENGINE = "WLB_TOKEN_ENGINE",
  STATS_CTRL = "WLB_STATS_CTRL",
  AP_CTRL = "WLB_AP_CTRL",
  MONEY = "WLB_MONEY",
  PLAYER_STATUS_CTRL = "WLB_PLAYER_STATUS_CTRL",
  HEAT_POLICE = "WLB_POLICE",
  VOCATION_TILE = "WLB_VOCATION_TILE",
  COLOR_PREFIX = "WLB_COLOR_",
  STATUS_EXPERIENCE = "WLB_STATUS_EXPERIENCE",
}
VOC.COLORS = {"Yellow", "Blue", "Red", "Green"}

-- Safe TTS API (guard - TTS globals may be nil in some chunks)
VOC.getAllObjectsSafe = function()
  return (type(getAllObjects) == "function" and getAllObjects()) or {}
end
VOC.getObjectsWithTagSafe = function(tag)
  if type(getObjectsWithTag) ~= "function" then return {} end
  return getObjectsWithTag(tag) or {}
end
VOC.safeCall = function(obj, fn, params)
  if not obj or type(obj.call) ~= "function" then return false, "no obj/call" end
  local ok, res = pcall(function() return obj.call(fn, params or {}) end)
  return ok, res
end
VOC.getObjectFromGUID = function(guid)
  if type(getObjectFromGUID) ~= "function" then return nil end
  return getObjectFromGUID(guid)
end
VOC.log = function(msg)
  if VOC.DEBUG then print("[VOC_CTRL] " .. tostring(msg)) end
end
VOC.warn = function(msg)
  print("[VOC_CTRL][WARN] " .. tostring(msg))
end
VOC.normalizeColor = function(color)
  if not color then return nil end
  local c = tostring(color or "")
  if string.sub(c, 1, 7) == "Player " then c = string.sub(c, 8) end
  c = c:lower()
  if c == "white" then return "White" end
  local map = { yellow = "Yellow", blue = "Blue", red = "Red", green = "Green" }
  return map[c]
end
VOC.findTurnCtrl = function()
  local all = VOC.getAllObjectsSafe()
  for _, obj in ipairs(all) do
    if obj and obj.hasTag and (obj.hasTag(VOC.TAGS.TURN_CTRL) or obj.hasTag(VOC.TAGS.TURN_CTRL_ALT)) then
      return obj
    end
  end
  for _, obj in ipairs(all) do
    if obj and obj.call then
      local ok, r = pcall(function() return obj.call("API_GetSciencePoints", {color = "Yellow"}) end)
      if ok and type(r) == "number" then return obj end
    end
  end
  return nil
end
VOC.findTokenEngine = function()
  local list = VOC.getObjectsWithTagSafe(VOC.TAGS.TOKEN_ENGINE)
  for _, o in ipairs(list) do
    if o and o.call then return o end
  end
  local all = VOC.getAllObjectsSafe()
  for _, o in ipairs(all) do
    if o and o.hasTag and o.hasTag(VOC.TAGS.TOKEN_ENGINE) and o.call then return o end
  end
  return nil
end
VOC.findStatsCtrl = function(color)
  local tag = VOC.TAGS.COLOR_PREFIX .. tostring(color or "")
  local list = VOC.getObjectsWithTagSafe(tag)
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag(VOC.TAGS.STATS_CTRL) and o.call then return o end
  end
  for _, o in ipairs(VOC.getAllObjectsSafe()) do
    if o and o.hasTag and o.hasTag(VOC.TAGS.STATS_CTRL) and o.hasTag(tag) and o.call then return o end
  end
  return nil
end
VOC.findPlayerStatusCtrl = function()
  local all = VOC.getAllObjectsSafe()
  for _, o in ipairs(all) do
    if o and o.hasTag and o.hasTag(VOC.TAGS.PLAYER_STATUS_CTRL) and o.call then return o end
  end
  return nil
end
VOC.findEventEngine = function()
  return VOC.getObjectFromGUID("7b92b3")
end
VOC.findByTags = function(tags)
  local all = VOC.getAllObjectsSafe()
  for _, o in ipairs(all) do
    local ok = true
    for _, t in ipairs(tags) do
      if not (o and o.hasTag and o.hasTag(t)) then ok = false break end
    end
    if ok then return o end
  end
  return nil
end
VOC.findHeatPawn = function()
  for _, o in ipairs(VOC.getAllObjectsSafe()) do
    if o and o.hasTag and o.hasTag(VOC.TAGS.HEAT_POLICE) then return o end
  end
  return nil
end
VOC.YEAR_TOKEN_TAG = "WLB_YEAR"
VOC.findYearToken = function()
  for _, o in ipairs(VOC.getAllObjectsSafe()) do
    if o and o.hasTag and o.hasTag(VOC.YEAR_TOKEN_TAG) then return o end
  end
  return nil
end
VOC.findPlayerBoard = function(color)
  local c = VOC.normalizeColor and VOC.normalizeColor(color) or nil
  if not c then return nil end
  local tag = (VOC.TAGS.COLOR_PREFIX or "WLB_COLOR_") .. tostring(c)
  local list = VOC.getObjectsWithTagSafe(tag) or {}
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag(VOC.TAGS.BOARD) then return o end
  end
  return nil
end

-- Legacy aliases (for gradual migration; code can use VOC.* or these)
local DEBUG = VOC.DEBUG
local VERSION = VOC.VERSION

-- =========================================================
-- TAGS
-- =========================================================
local TAG_SELF = "WLB_VOCATIONS_CTRL"
local TAG_BOARD = "WLB_BOARD"
local TAG_VOCATION_TILE = "WLB_VOCATION_TILE"
local COLOR_TAG_PREFIX = "WLB_COLOR_"
-- TAG_TURN_CTRL moved to global above (after TAG_HEAT_POLICE)
local TAG_TOKEN_ENGINE = "WLB_TOKEN_ENGINE"
local TAG_STATUS_EXPERIENCE = "WLB_STATUS_EXPERIENCE"
local TAG_STATS_CTRL = "WLB_STATS_CTRL"
local TAG_AP_CTRL = "WLB_AP_CTRL"
local TAG_MONEY = "WLB_MONEY"
local TAG_PLAYER_STATUS_CTRL = "WLB_PLAYER_STATUS_CTRL"
local TAG_HEAT_POLICE = "WLB_POLICE"  -- Police car pawn on shop board (Heat 0-6)

-- GLOBAL so chunk_4 can reach (consultant fix: local in other chunk = nil)
TAG_TURN_CTRL = "WLB_TURN_CTRL"
COLORS = {"Yellow", "Blue", "Red", "Green"}

-- =========================
-- CHUNK-SAFE HELPERS (use _G - TTS chunks may have separate globals, _G is shared)
-- =========================
_G.VOC_DEBUG = (_G.VOC_DEBUG ~= false)

_G.VOC_log = _G.VOC_log or function(msg)
  if _G.VOC_DEBUG then
    print("[VOC_CTRL] " .. tostring(msg))
  end
end

_G.VOC_normalizeColor = _G.VOC_normalizeColor or function(color)
  if not color then return nil end
  local c = tostring(color or "")
  if string.sub(c, 1, 7) == "Player " then c = string.sub(c, 8) end
  c = c:lower()
  if c == "white" then return "White" end
  local map = { yellow = "Yellow", blue = "Blue", red = "Red", green = "Green" }
  return map[c]
end

-- CHUNK-SAFE: delegate to VOC.findTurnCtrl (single source of truth)
_G.getTurnCtrl = _G.getTurnCtrl or function() return _G.WLB and _G.WLB.VOC and _G.WLB.VOC.findTurnCtrl and _G.WLB.VOC.findTurnCtrl() or nil end
getTurnCtrl = _G.getTurnCtrl

-- Die GUID (same as TurnController)
local DIE_GUID = "14d4a4"

-- Entrepreneur die halt: after an Entrepreneur die roll, game stops and shows Reroll (1 AP, once) / Go on. Stored in _G for cross-chunk access.
-- COLORS moved to global above (chunk-safe)

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
  for _, obj in ipairs(VOC.getAllObjectsSafe()) do
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
  workAPThisRound = { Yellow=0, Blue=0, Red=0, Green=0 },  -- Work AP this round (for Public Servant obligation 2–4 AP/year)
  experienceYearsEarned = { Yellow=0, Blue=0, Red=0, Green=0 },  -- For Public Servant: years at level where obligation was met (counts for promotion)
  noSpecialAwardThisYear = { Yellow=false, Blue=false, Red=false, Green=false },  -- PS L3: set if failed obligation
  levelUpRound = { Yellow=nil, Blue=nil, Red=nil, Green=nil },  -- Round when player reached current vocation level (for Time/Experience)
  -- Public Servant: Mastery of Administrative Law – one tax waiver per vocation level (level at which waiver was used, or nil)
  taxWaiverUsedAtLevel = { Yellow=nil, Blue=nil, Red=nil, Green=nil },
  voluntaryWorkAP = { Yellow=0, Blue=0, Red=0, Green=0 },  -- NGO Worker: AP spent on voluntary work (for award path B)
  celebrityAwardReceived = { Yellow=false, Blue=false, Red=false, Green=false },  -- Celebrity L3: claimed "Get an award"
  -- Celebrity hi-tech cashback: { color = { {amount, roundDue, levelAtPurchase, cardName}, ... } }
  celebrityCashbackRefunds = {},
  -- Celebrity event card obligation: count of "events" played this turn (level action = 1, event cards = 1 each)
  celebrityEventsThisTurn = { Yellow=0, Blue=0, Red=0, Green=0 },
}

-- =========================================================
-- UTILS
-- =========================================================
-- CHUNK-SAFE: alias to VOC (globals may be nil in other chunks, VOC is in _G.WLB.VOC)
log = function(msg) if VOC and VOC.log then VOC.log(msg) end end
warn = function(msg) if VOC and VOC.warn then VOC.warn(msg) else print("[VOC_CTRL][WARN] " .. tostring(msg)) end end

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

-- CHUNK-SAFE: use ONLY _G (bare VOC may be nil in another chunk)
normalizeColor = function(color) return (_G.VOC_normalizeColor and _G.VOC_normalizeColor(color)) or nil end

local function colorTag(color)
  return COLOR_TAG_PREFIX .. tostring(color)
end

-- Generic helper: find first object with all given tags
local function findByTags(tags)
  return VOC.findByTags(tags)
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

  VOC.warn("AP_CTRL for "..tostring(color).." has no unspent getter.")
  return 0
end

local function canSpendAP(color, amount)
  -- Bypass only for White (no AP track). When White triggers for effectsTarget, we resolve to real player and check their AP.
  if color == "White" then return true end
  
  local ap = findApCtrlForColor(color)
  if not ap or not ap.call then
    VOC.warn("AP controller not found for "..tostring(color))
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
  
  -- Bypass only when spending from White (no AP track). When White triggers for effectsTarget (e.g. Red), we resolve to Red and actually spend from Red.
  if color == "White" then 
    VOC.log("spendAP: Bypassing AP spend for White (no AP track)")
    return true 
  end
  
  local ap = findApCtrlForColor(color)
  if not ap or not ap.call then
    VOC.warn("AP controller not found for "..tostring(color))
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
    VOC.warn("SAT GUID missing for color="..tostring(color))
    return nil
  end
  local obj = VOC.getObjectFromGUID(guid)
  if not obj then
    VOC.warn("SAT token GUID not found: "..tostring(color).." guid="..tostring(guid))
    return nil
  end
  return obj
end

local function satAdd(color, amount)
  amount = tonumber(amount) or 0
  if amount == 0 then return true end
  
  -- White doesn't have SAT token - skip
  if color == "White" then
    VOC.log("satAdd: Skipping White (testing mode, no SAT token)")
    return true
  end

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
        VOC.warn("SAT CALL FAILED: "..tostring(stepFn))
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
    VOC.warn("No active player from Turns.turn_color. Action blocked.")
    broadcastToAll("[VOC] ⛔ No active player with Turns.turn_color. Enable Turns and set turn.", {1,0.6,0.2})
    return nil
  end
  return c
end

local function findPlayerBoard(color)
  return VOC.findPlayerBoard(color)
end
local function findStatsController(color)
  return VOC.findStatsCtrl(color)
end
local function findPlayerStatusController()
  return VOC.findPlayerStatusCtrl()
end

-- Check if player has at least one child
local function hasChildren(color)
  color = normalizeColor(color)
  if not color then return false end
  
  local psc = findPlayerStatusController()
  if not psc or not psc.call then return false end
  
  local ok, childAP = pcall(function()
    return psc.call("PS_GetChildBlockedAP", {color=color})
  end)
  
  if ok and type(childAP) == "number" then
    -- Each child blocks 2 AP, so if childAP >= 2, player has at least 1 child
    return childAP >= 2
  end
  
  return false
end

-- Add WOUNDED status to a player
local function addWoundedStatus(color)
  color = normalizeColor(color)
  if not color then return false end
  
  -- White doesn't get status tokens
  if color == "White" then
    return true
  end
  
  local psc = findPlayerStatusController()
  if not psc or not psc.call then
    return false
  end
  
  local ok = pcall(function()
    return psc.call("PS_Event", {op="ADD_STATUS", color=color, statusKey="WOUNDED"})
  end)
  
  if not ok then
    return false
  end
  
  -- Gangster crime: Victim loses 3 Health when WOUNDED
  -- Inline health reduction to avoid chunking issues (addHealth might be nil in this chunk)
  -- Use VOC.findStatsCtrl directly (chunk-safe via _G.WLB.VOC)
  if color ~= "White" then
    local stats = (VOC and VOC.findStatsCtrl) and VOC.findStatsCtrl(color) or nil
    if stats and stats.call then
      local healthOk = pcall(function()
        return stats.call("applyDelta", { h = -3 })
      end)
      if healthOk then
        safeBroadcastAll("💔 " .. color .. " is WOUNDED and loses 3 Health.", {1,0.5,0.5})
      end
    end
  end
  
  return ok
end

-- Social Worker L1: Use Good Karma — grant one Good Karma token to the player, once per game.
local function VOC_StartSocialWorkerUseGoodKarma(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = params.color
  local actorColor = (VOC.normalizeColor and VOC.normalizeColor(params.effectsTarget or color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.effectsTarget or color)) or nil
  if not actorColor or actorColor == "White" then
    safeBroadcastToColor("Invalid player for Use Good Karma.", color or "White", {1,0.6,0.2})
    return false
  end
  if state.vocations[actorColor] ~= VOC_SOCIAL_WORKER or (state.levels[actorColor] or 1) < 1 then
    safeBroadcastToColor("Social Worker level 1 required for Use Good Karma.", color or "White", {1,0.6,0.2})
    return false
  end
  state.swGoodKarmaUsed = state.swGoodKarmaUsed or {}
  if state.swGoodKarmaUsed[actorColor] then
    safeBroadcastToColor("Use Good Karma can only be used once per game. Already used.", actorColor, {1,0.6,0.2})
    return false
  end
  local psc = findPlayerStatusController()
  if not psc or not psc.call then
    safeBroadcastToColor("Player Status Controller not found. Cannot add Good Karma.", actorColor, {1,0.6,0.2})
    return false
  end
  local ok = pcall(function()
    return psc.call("PS_Event", { op = "ADD_STATUS", color = actorColor, statusTag = "WLB_STATUS_GOOD_KARMA" })
  end)
  if not ok then
    safeBroadcastToColor("Failed to add Good Karma token.", actorColor, {1,0.6,0.2})
    return false
  end
  state.swGoodKarmaUsed[actorColor] = true
  -- Do not call saveState here: UI/callbacks may run in a chunk where self/saveState is nil. UI_VocationAction will call VOC_SaveState after return.
  broadcastToAll("✨ " .. actorColor .. " used Social Worker Good Karma — gained one Good Karma token. (Once per game.)", {1,0.84,0.0})
  return true
end

local TAG_VOUCH_C = "WLB_STATUS_VOUCH_C"
local TAG_VOUCH_H = "WLB_STATUS_VOUCH_H"

-- Social Worker L2: Once per game, grant 4 consumable voucher tokens (100% = one free consumable).
function VOC_StartSocialWorkerConsumableFree(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  local actorColor = params.effectsTarget or color
  if actorColor == "White" then
    safeBroadcastToColor("Invalid player for free consumable perk.", color or "White", {1,0.6,0.2})
    return false
  end
  if state.vocations[actorColor] ~= VOC_SOCIAL_WORKER or (state.levels[actorColor] or 1) < 2 then
    safeBroadcastToColor("Social Worker Level 2 required for free consumable perk.", actorColor, {1,0.6,0.2})
    return false
  end
  state.swConsumablePerkUsed = state.swConsumablePerkUsed or {}
  if state.swConsumablePerkUsed[actorColor] then
    safeBroadcastToColor("Free consumable perk can only be used once per game. Already used.", actorColor, {1,0.6,0.2})
    return false
  end
  local psc = findPlayerStatusController()
  if not psc or not psc.call then
    safeBroadcastToColor("Player Status Controller not found. Cannot grant vouchers.", actorColor, {1,0.6,0.2})
    return false
  end
  for _ = 1, 4 do
    local ok = pcall(function() return psc.call("PS_Event", { op = "ADD_STATUS", color = actorColor, statusTag = TAG_VOUCH_C }) end)
    if not ok then
      safeBroadcastToColor("Failed to add consumable voucher token.", actorColor, {1,0.6,0.2})
      return false
    end
  end
  state.swConsumablePerkUsed[actorColor] = true
  pcall(function() self.call("VOC_SaveState", {}) end)
  broadcastToAll("✨ " .. actorColor .. " used Social Worker free consumable perk — gained 4 consumable vouchers (one free consumable). (Once per game.)", {1,0.84,0.0})
  return true
end

-- Social Worker L3: Once per game, grant 4 hi-tech voucher tokens (100% = one free hi-tech).
function VOC_StartSocialWorkerHitechFree(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  local actorColor = params.effectsTarget or color
  if actorColor == "White" then
    safeBroadcastToColor("Invalid player for free hi-tech perk.", color or "White", {1,0.6,0.2})
    return false
  end
  if state.vocations[actorColor] ~= VOC_SOCIAL_WORKER or (state.levels[actorColor] or 1) < 3 then
    safeBroadcastToColor("Social Worker Level 3 required for free hi-tech perk.", actorColor, {1,0.6,0.2})
    return false
  end
  state.swHitechPerkUsed = state.swHitechPerkUsed or {}
  if state.swHitechPerkUsed[actorColor] then
    safeBroadcastToColor("Free hi-tech perk can only be used once per game. Already used.", actorColor, {1,0.6,0.2})
    return false
  end
  local psc = findPlayerStatusController()
  if not psc or not psc.call then
    safeBroadcastToColor("Player Status Controller not found. Cannot grant vouchers.", actorColor, {1,0.6,0.2})
    return false
  end
  for _ = 1, 4 do
    local ok = pcall(function() return psc.call("PS_Event", { op = "ADD_STATUS", color = actorColor, statusTag = TAG_VOUCH_H }) end)
    if not ok then
      safeBroadcastToColor("Failed to add hi-tech voucher token.", actorColor, {1,0.6,0.2})
      return false
    end
  end
  state.swHitechPerkUsed[actorColor] = true
  pcall(function() self.call("VOC_SaveState", {}) end)
  broadcastToAll("✨ " .. actorColor .. " used Social Worker free hi-tech perk — gained 4 hi-tech vouchers (one free hi-tech). (Once per game.)", {1,0.84,0.0})
  return true
end

-- Steal money from target player
-- Chunk-safe: die callback may run in another TTS chunk where getMoney/moneySpend/moneyAdd are nil; use _G.VOC_CTRL fallback.
local function stealMoney(fromColor, toColor, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end
  
  fromColor = normalizeColor(fromColor)
  toColor = normalizeColor(toColor)
  if not fromColor or not toColor then return false end
  
  local gm = (type(getMoney) == "function" and getMoney) or (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.getMoney) == "function" and _G.VOC_CTRL.getMoney)
  if not gm then
    VOC.warn("stealMoney: getMoney not available (chunk)")
    return false, 0
  end
  local targetMoney = gm(fromColor)
  local amountToSteal = math.min(amount, targetMoney)
  
  if amountToSteal > 0 then
    local spendFn = (type(moneySpend) == "function" and moneySpend) or (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.moneySpend) == "function" and _G.VOC_CTRL.moneySpend)
    local addFn = (type(moneyAdd) == "function" and moneyAdd) or (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.moneyAdd) == "function" and _G.VOC_CTRL.moneyAdd)
    if not spendFn or not addFn then
      VOC.warn("stealMoney: moneySpend/moneyAdd not available (chunk)")
      return false, 0
    end
    if spendFn(fromColor, amountToSteal) then
      addFn(toColor, amountToSteal)
      VOC.log("stealMoney: "..tostring(toColor).." stole "..amountToSteal.." VIN from "..tostring(fromColor))
      return true, amountToSteal
    end
  end
  
  return false, 0
end

-- Stats helpers (mirror YouthBoard: applyDelta on Stats controller)
local function addKnowledge(color, n)
  n = tonumber(n) or 0
  if n == 0 then return true end
  
  -- White doesn't have Stats controller - skip
  if color == "White" then
    VOC.log("addKnowledge: Skipping White (testing mode, no Stats controller)")
    return true
  end
  
  local stats = findStatsController(color)
  if not stats or not stats.call then
    VOC.warn("Stats controller not found for "..tostring(color).." when adding Knowledge")
    return false
  end
  local ok, err = pcall(function()
    return stats.call("applyDelta", { k = n })
  end)
  if not ok then
    VOC.warn("Stats applyDelta(k="..tostring(n)..") failed for "..tostring(color)..": "..tostring(err))
  end
  return ok
end

local function addSkills(color, n)
  n = tonumber(n) or 0
  if n == 0 then return true end
  
  -- White doesn't have Stats controller - skip
  if color == "White" then
    VOC.log("addSkills: Skipping White (testing mode, no Stats controller)")
    return true
  end
  
  local stats = findStatsController(color)
  if not stats or not stats.call then
    VOC.warn("Stats controller not found for "..tostring(color).." when adding Skills")
    return false
  end
  local ok, err = pcall(function()
    return stats.call("applyDelta", { s = n })
  end)
  if not ok then
    VOC.warn("Stats applyDelta(s="..tostring(n)..") failed for "..tostring(color)..": "..tostring(err))
  end
  return ok
end

local function addHealth(color, n)
  n = tonumber(n) or 0
  if n == 0 then return true end
  
  -- White doesn't have Stats controller - skip
  if color == "White" then
    VOC.log("addHealth: Skipping White (testing mode, no Stats controller)")
    return true
  end
  
  local stats = findStatsController(color)
  if not stats or not stats.call then
    VOC.warn("Stats controller not found for "..tostring(color).." when adding Health")
    return false
  end
  local ok, err = pcall(function()
    return stats.call("applyDelta", { h = n })
  end)
  if not ok then
    VOC.warn("Stats applyDelta(h="..tostring(n)..") failed for "..tostring(color)..": "..tostring(err))
  end
  return ok
end

-- Money helpers (mirror EventEngine/ShopEngine: resolveMoney + moneyAdd/moneySpend)
local function resolveMoney(color)
  color = normalizeColor(color)
  if not color then return nil end
  
  -- Prefer player board with embedded money API (PlayerBoardController_Shared)
  local board = findPlayerBoard(color)
  if board and board.call then
    local ok = pcall(function() return board.call("getMoney") end)
    if ok then return board end
  end
  
  -- Fallback: legacy money tile
  local list = VOC.getObjectsWithTagSafe(colorTag(color)) or {}
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag(TAG_MONEY) then
      return o
    end
  end
  
  return nil
end

-- Forward declaration for getMoney (defined later, but used by moneySpend)
local getMoney

local function moneyAdd(color, amount)
  amount = tonumber(amount) or 0
  if amount == 0 then return true end
  
  -- White doesn't have money controller - skip
  if color == "White" then
    VOC.log("moneyAdd: Skipping White (testing mode, no money controller)")
    return true
  end
  
  local m = resolveMoney(color)
  if not m or not m.call then
    VOC.warn("Money controller not found for "..tostring(color))
    safeBroadcastToColor("⚠️ No MoneyCtrl — cannot adjust "..amount.." VIN.", color, {1,0.7,0.2})
    return false
  end
  
  local ok = pcall(function() m.call("addMoney", { amount = amount }) end)
  if ok then return true end
  
  ok = pcall(function() m.call("addMoney", { delta = amount }) end)
  if not ok then
    VOC.warn("Money addMoney failed for "..tostring(color).." amount="..tostring(amount))
  end
  return ok
end

local function moneySpend(color, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end
  
  -- White bypasses money checks for testing
  if color == "White" then return true end
  
  local m = resolveMoney(color)
  if not m or not m.call then
    VOC.warn("Money controller not found for "..tostring(color))
    safeBroadcastToColor("⚠️ No MoneyCtrl — cannot spend "..amount.." VIN.", color, {1,0.7,0.2})
    return false
  end
  
  -- Get current money first
  local currentMoney = getMoney(color)
  
  -- Determine how much to actually spend (can't spend more than they have)
  local amountToSpend = math.min(amount, currentMoney)
  
  -- If they don't have enough, we'll spend what they have (down to 0)
  if currentMoney < amount and currentMoney > 0 then
    -- Try API_spend first for the amount they have
    local ok, ret = pcall(function() return m.call("API_spend", { amount = amountToSpend }) end)
    if ok and type(ret) == "table" and type(ret.ok) == "boolean" and ret.ok then
      safeBroadcastToColor("⛔ Not enough money (need "..amount.." VIN, had "..currentMoney.." VIN). Paid "..amountToSpend.." VIN (now 0).", color, {1,0.6,0.2})
      return true
    end
    
    -- Fallback: try direct addMoney with negative
    ok = pcall(function() m.call("addMoney", { amount = -amountToSpend }) end)
    if ok then
      safeBroadcastToColor("⛔ Not enough money (need "..amount.." VIN, had "..currentMoney.." VIN). Paid "..amountToSpend.." VIN (now 0).", color, {1,0.6,0.2})
      return true
    end
    ok = pcall(function() m.call("addMoney", { delta = -amountToSpend }) end)
    if ok then
      safeBroadcastToColor("⛔ Not enough money (need "..amount.." VIN, had "..currentMoney.." VIN). Paid "..amountToSpend.." VIN (now 0).", color, {1,0.6,0.2})
      return true
    end
    return false
  end
  
  -- They have enough money - try API_spend first (safe spending with fund check)
  local ok, ret = pcall(function() return m.call("API_spend", { amount = amount }) end)
  if ok and type(ret) == "table" and type(ret.ok) == "boolean" then
    if ret.ok then return true end
    -- API_spend failed but they should have enough - try spending what they have
    local actualMoney = ret.money or getMoney(color)
    if actualMoney > 0 then
      local spendOk, spendRet = pcall(function() return m.call("API_spend", { amount = actualMoney }) end)
      if spendOk and type(spendRet) == "table" and spendRet.ok then
        safeBroadcastToColor("⛔ Not enough money (need "..amount.." VIN, had "..actualMoney.." VIN). Paid "..actualMoney.." VIN (now 0).", color, {1,0.6,0.2})
        return true
      end
      -- Fallback: direct addMoney
      spendOk = pcall(function() m.call("addMoney", { amount = -actualMoney }) end)
      if spendOk then
        safeBroadcastToColor("⛔ Not enough money (need "..amount.." VIN, had "..actualMoney.." VIN). Paid "..actualMoney.." VIN (now 0).", color, {1,0.6,0.2})
        return true
      end
      spendOk = pcall(function() m.call("addMoney", { delta = -actualMoney }) end)
      if spendOk then
        safeBroadcastToColor("⛔ Not enough money (need "..amount.." VIN, had "..actualMoney.." VIN). Paid "..actualMoney.." VIN (now 0).", color, {1,0.6,0.2})
        return true
      end
    end
    safeBroadcastToColor("⛔ Not enough money (need "..amount.." VIN, have "..(actualMoney or 0)..").", color, {1,0.6,0.2})
    return false
  end
  
  -- Fallback: direct addMoney with negative
  ok = pcall(function() m.call("addMoney", { amount = -amount }) end)
  if ok then return true end
  
  ok = pcall(function() m.call("addMoney", { delta = -amount }) end)
  if not ok then
    VOC.warn("Money spend failed for "..tostring(color).." amount="..tostring(amount))
  end
  return ok
end

-- Definition for getMoney (forward declared earlier)
getMoney = function(color)
  local m = resolveMoney(color)
  if not m or not m.call then return 0 end
  
  local ok, v = pcall(function() return m.call("getMoney") end)
  if ok and type(v) == "number" then return v end
  
  ok, v = pcall(function() return m.call("getValue") end)
  if ok and type(v) == "number" then return v end
  
  ok, v = pcall(function() return m.call("getAmount") end)
  if ok and type(v) == "number" then return v end
  
  ok, v = pcall(function() return m.call("getState") end)
  if ok and type(v) == "table" and type(v.money) == "number" then return v.money end
  
  return 0
end

-- Publish money/status helpers to _G so async callbacks (e.g. crime die roll) can use them from any TTS chunk
if not _G.VOC_CTRL then _G.VOC_CTRL = {} end
_G.VOC_CTRL.getMoney = getMoney
_G.VOC_CTRL.moneySpend = moneySpend
_G.VOC_CTRL.moneyAdd = moneyAdd
_G.VOC_CTRL.stealMoney = stealMoney
_G.VOC_CTRL.addWoundedStatus = addWoundedStatus
_G.VOC_CTRL.getActiveTurnColor = getActiveTurnColor

-- Heat / Police pawn (Crime & Investigation system) - delegate to VOC
local function findHeatPawn()
  return VOC.findHeatPawn()
end
local YEAR_TOKEN_TAG = VOC.YEAR_TOKEN_TAG or "WLB_YEAR"
local function findYearToken()
  return VOC.findYearToken()
end
local function getCurrentRound()
  local yt = findYearToken()
  if not yt or not yt.call then return 1 end
  local ok, r = pcall(function() return yt.call("getRound") end)
  if ok and type(r) == "number" and r >= 1 then return r end
  return 1
end

-- Helper to find Token Engine (for experience token)
-- CHUNK-SAFE: use VOC.* (getAllObjects/getObjectsWithTag may be nil in some TTS chunks)
local function findTokenEngine()
  return VOC.findTokenEngine()
end

-- getTurnCtrl defined at top of file in _G

-- Get science points for a color by querying Turn Controller
-- CHUNK-SAFE: uses ONLY VOC.* (_G.WLB.VOC is shared across TTS chunks)
function getSciencePointsForColor(color)
  local ok, res = pcall(function()
    local norm = (VOC.normalizeColor and VOC.normalizeColor(color)) or nil
    if not norm then return 0 end

    local turnCtrl = (VOC.findTurnCtrl and VOC.findTurnCtrl()) or nil
    if not turnCtrl or type(turnCtrl.call) ~= "function" then return 0 end

    local pts = turnCtrl.call("API_GetSciencePoints", { color = norm })
    return (type(pts) == "number") and pts or 0
  end)

  if not ok then
    if VOC.log then VOC.log("getSciencePointsForColor error: " .. tostring(res)) end
    return 0
  end

  return (type(res) == "number") and res or 0
end
if not _G.VOC_CTRL then _G.VOC_CTRL = {} end
_G.VOC_CTRL.getSciencePointsForColor = getSciencePointsForColor
_G.getSciencePointsForColor = getSciencePointsForColor  -- Explicit _G for chunk-safe lookup

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
  customData = nil, -- Custom data for multi-stage interactions
}

VOC.updateInteractionTimerText = function()
  if not UI then return end
  if not interaction.active or (interaction.timer or 0) <= 0 then
    UI.setAttribute("interactionTimer", "text", "")
  else
    UI.setAttribute("interactionTimer", "text", "Time left: "..tostring(interaction.timer).."s")
  end
end

VOC.clearInteraction = function()
  interaction.active = false
  interaction.id = nil
  interaction.initiator = nil
  interaction.responses = {}
  interaction.targets = {}
  interaction.joinCostAP = 0
  interaction.timer = 0
  interaction.customData = nil  -- Clear custom data
  if UI then
    UI.setAttribute("interactionOverlay", "active", "false")
  end
  if VOC.updateInteractionTimerText then VOC.updateInteractionTimerText() end
end

-- =========================================================
-- TARGET PLAYER SELECTION SYSTEM
-- =========================================================

local targetSelection = {
  active = false,
  initiator = nil,  -- Who is selecting the target
  actionId = nil,  -- Which action requires a target
  callback = nil,  -- Function to call with selected target (can be function or string function name)
  callbackParams = nil,  -- Additional params to pass to callback
  requireChildren = false,  -- If true, only show players with children
}

VOC.clearTargetSelection = function()
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  targetSelection.active = false
  targetSelection.initiator = nil
  targetSelection.actionId = nil
  targetSelection.callback = nil
  targetSelection.callbackParams = nil
  targetSelection.requireChildren = false
end

-- Forward declarations (defined later, but needed here)
local isPlayableColor
local handleInteractionResponse

VOC.startTargetSelection = function(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing in this chunk") return false end
  if not UI then return false end

  local initiator = (VOC.normalizeColor and VOC.normalizeColor(params.initiator))
    or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.initiator))
  if not initiator then return false end
  
  if VOC.clearTargetSelection then VOC.clearTargetSelection() end
  targetSelection.active = true
  targetSelection.initiator = initiator
  targetSelection.actionId = params.actionId
  targetSelection.callback = params.callback
  targetSelection.callbackParams = params.callbackParams
  targetSelection.requireChildren = params.requireChildren or false
  
  VOC.log("startTargetSelection: callback="..tostring(targetSelection.callback).." callbackParams="..tostring(targetSelection.callbackParams and targetSelection.callbackParams.cardGuid or "nil"))
  
  -- Set title and subtitle
  UI.setAttribute("targetSelectionTitle", "text", params.title or "SELECT TARGET PLAYER")
  UI.setAttribute("targetSelectionSubtitle", "text", params.subtitle or "Choose which player to target:")
  
  -- Show/hide buttons based on valid targets
  local colors = (VOC and VOC.COLORS) or COLORS or {"Yellow", "Blue", "Red", "Green"}
  for _, c in ipairs(colors) do
    local btnId = "btnTarget"..c
    local isValid = true
    local reason = ""
    
    -- Can't target self
    if c == initiator then
      isValid = false
      reason = "self"
    end
    
    -- Check if target is a playable color
    if isValid and not isPlayableColor(c) then
      isValid = false
      reason = "not playable"
    end
    
    -- Check if children are required
    if isValid and targetSelection.requireChildren and not hasChildren(c) then
      isValid = false
      reason = "no children"
    end
    
    if isValid then
      UI.setAttribute(btnId, "active", "true")
      UI.setAttribute(btnId, "interactable", "true")
      VOC.log("startTargetSelection: showing button for "..c.." (initiator="..tostring(initiator)..")")
    else
      UI.setAttribute(btnId, "active", "false")
      VOC.log("startTargetSelection: hiding button for "..c.." - reason: "..reason)
    end
  end
  
  UI.setAttribute("targetSelectionOverlay", "active", "true")
  return true
end

-- Wrapper: VOC_Start* and other entry points may call startTargetSelection(...) directly
function startTargetSelection(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC or not VOC.startTargetSelection then
    print("[VOC_CTRL][FATAL] startTargetSelection wrapper: missing VOC or handler")
    return false
  end
  return VOC.startTargetSelection(params)
end

-- VOC.hideTargetSelection: chunk-safe (called via VOC.*)
VOC.hideTargetSelection = function(isCancel)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing in this chunk") return end
  -- Check if this is a VE crime cancellation (actionId is "VE_CRIME")
  -- Only refund if isCancel is true AND there's no callback (meaning it was actually canceled, not a target selection)
  local wasVECrime = (targetSelection.actionId == "VE_CRIME")
  local cardGuid = nil
  if wasVECrime and targetSelection.callbackParams then
    cardGuid = targetSelection.callbackParams.cardGuid
  end
  
  if UI then
    UI.setAttribute("targetSelectionOverlay", "active", "false")
    -- Reset all target buttons to inactive state
    local colors = (VOC and VOC.COLORS) or COLORS or {"Yellow", "Blue", "Red", "Green"}
    for _, c in ipairs(colors) do
      local btnId = "btnTarget"..c
      UI.setAttribute(btnId, "active", "false")
      UI.setAttribute(btnId, "interactable", "false")
    end
  end
  
  -- Only refund if this is actually a cancellation (isCancel is true) and it's VE crime
  -- If a target was selected, handleTargetSelection will call hideTargetSelection with isCancel=false/nil
  -- and then execute the callback, so we should NOT refund
  if wasVECrime and cardGuid and isCancel == true then
    local engine = (VOC.getObjectFromGUID and VOC.getObjectFromGUID("7b92b3")) or (type(getObjectFromGUID)=="function" and getObjectFromGUID("7b92b3")) or nil
    if engine and engine.call then
      VOC.log("hideTargetSelection: VE crime cancelled, notifying Event Engine to refund AP for cardGuid="..tostring(cardGuid))
      pcall(function()
        engine.call("CancelVECrimeTargetSelection", { card_guid = cardGuid })
      end)
    end
  end
  
  if VOC.clearTargetSelection then VOC.clearTargetSelection() end
end

-- Wrapper: Global_Script_Complete.lua and button callbacks call this
function hideTargetSelection(isCancel)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC or not VOC.hideTargetSelection then
    print("[VOC_CTRL][FATAL] hideTargetSelection wrapper: missing VOC or handler")
    return
  end
  return VOC.hideTargetSelection(isCancel)
end

-- VOC.handleTargetSelection: chunk-safe (called via VOC.*)
VOC.handleTargetSelection = function(targetColor)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing in this chunk") return end
  if not targetSelection.active then return end
  if not targetSelection.callback then return end

  targetColor = (VOC.normalizeColor and VOC.normalizeColor(targetColor))
    or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(targetColor))
  if not targetColor then return end
  
  -- Validate target
  if targetColor == targetSelection.initiator then
    safeBroadcastToColor("You cannot target yourself.", targetSelection.initiator, {1,0.6,0.2})
    return
  end
  
  if targetSelection.requireChildren and not hasChildren(targetColor) then
    safeBroadcastToColor(targetColor.." does not have any children.", targetSelection.initiator, {1,0.6,0.2})
    return
  end
  
  -- Store callback info BEFORE hiding UI (hideTargetSelection clears targetSelection)
  local callback = targetSelection.callback
  local callbackParams = targetSelection.callbackParams
  
  -- Hide UI (this clears targetSelection, so we must save callback first)
  -- Pass false to indicate this is NOT a cancel - a target was selected
  if VOC.hideTargetSelection then VOC.hideTargetSelection(false) end
  
  -- Execute callback with selected target
  if callback then
    if type(callback) == "function" then
      callback(targetColor)
    elseif type(callback) == "string" then
      -- Callback is a function name. For VE_CRIME, forward DIRECTLY to Event Engine.
      -- Do NOT call VECrimeTargetSelected here: TTS chunks scripts, and that function may be in a
      -- different chunk, causing "attempt to call a nil value" when handleTargetSelection runs.
      local params = callbackParams or {}
      params.targetColor = targetColor
      if callback == "VECrimeTargetSelected" then
        VOC.log("handleTargetSelection: forwarding to Event Engine VECrimeTargetSelected cardGuid="..tostring(params.cardGuid).." targetColor="..tostring(targetColor))
        local engine = (VOC.getObjectFromGUID and VOC.getObjectFromGUID("7b92b3")) or (type(getObjectFromGUID)=="function" and getObjectFromGUID("7b92b3")) or nil
        if engine and engine.call then
          pcall(function() engine.call("VECrimeTargetSelected", params or {}) end)
        else
          VOC.log("handleTargetSelection: Event Engine not found, cannot forward VE crime target")
        end
      else
        local engine = (VOC.getObjectFromGUID and VOC.getObjectFromGUID("7b92b3")) or (type(getObjectFromGUID)=="function" and getObjectFromGUID("7b92b3")) or nil
        if engine and engine.call then
          VOC.log("handleTargetSelection: calling Event Engine function '"..callback.."' with params")
          local ok, result = pcall(function() return engine.call(callback, params) end)
          if not ok then
            VOC.log("handleTargetSelection: ERROR calling Event Engine - "..tostring(result))
          else
            VOC.log("handleTargetSelection: Event Engine call successful")
          end
        else
          VOC.log("handleTargetSelection: Event Engine not found or no call method")
        end
      end
    end
  else
    VOC.log("handleTargetSelection: no callback set (callback was nil)")
  end
end

-- Wrapper: Global_Script_Complete.lua and VECrimeTargetSelected call this
function handleTargetSelection(targetColor)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC or not VOC.handleTargetSelection then
    print("[VOC_CTRL][FATAL] handleTargetSelection wrapper: missing VOC or handler")
    return
  end
  return VOC.handleTargetSelection(targetColor)
end

-- Pass-through: VECrimeTargetSelected lives on Event Engine.
-- Hybrid: supports BOTH script call (params table) AND UI call (player, value, id).
-- QA: xpcall gives full traceback on crash (nil call, etc.)
function VECrimeTargetSelected(a, b, c)
  local ok, err = xpcall(function()
    local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    print("[VOC_CTRL][DBG] VECrimeTargetSelected ENTER ok, VOC=", tostring(VOC ~= nil), "types:", type(a), type(b), type(c))
    if not VOC then error("VOC namespace missing") end

    -- Case 1: called from code with params table
    if type(a) == "table" then
      local params = a
      local engine = (VOC.getObjectFromGUID and VOC.getObjectFromGUID("7b92b3")) or (type(getObjectFromGUID)=="function" and getObjectFromGUID("7b92b3")) or nil
      if engine and engine.call then
        pcall(function() engine.call("VECrimeTargetSelected", params or {}) end)
      else
        VOC.log("VECrimeTargetSelected: Event Engine not found, cannot forward")
      end
      return
    end

    -- Case 2: called from UI (player, value, id) – resolve targetColor and delegate to handleTargetSelection
    local playerColor = a
    local value = b
    local id = c
    local targetColor = (VOC.normalizeColor and VOC.normalizeColor(value))
      or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(value))

    if not targetColor and type(id) == "string" then
      local colors = (VOC and VOC.COLORS) or COLORS or {"Yellow", "Blue", "Red", "Green"}
      for _, col in ipairs(colors) do
        if string.find(id or "", col) then
          targetColor = col
          break
        end
      end
    end

    if not targetColor then
      VOC.log("VECrimeTargetSelected(UI): cannot resolve targetColor. player="..tostring(playerColor).." value="..tostring(value).." id="..tostring(id))
      return
    end

    if type(VOC.handleTargetSelection) ~= "function" then
      error("VOC.handleTargetSelection is not a function: "..tostring(type(VOC.handleTargetSelection)))
    end
    VOC.handleTargetSelection(targetColor)
  end, function(e)
    return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "no traceback")
  end)

  if not ok then
    print("[VOC_CTRL][FATAL] VECrimeTargetSelected crashed:\n" .. tostring(err))
  end
end

-- Called by Event Engine to start VE crime target selection
function StartVECrimeTargetSelection(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing in this chunk") return false end
  if not params or not params.initiator or not params.cardGuid then 
    VOC.log("StartVECrimeTargetSelection: missing params - initiator="..tostring(params and params.initiator).." cardGuid="..tostring(params and params.cardGuid))
    return false 
  end
  local engine = (VOC.getObjectFromGUID and VOC.getObjectFromGUID("7b92b3")) or (type(getObjectFromGUID)=="function" and getObjectFromGUID("7b92b3")) or nil
  if not engine then 
    VOC.log("StartVECrimeTargetSelection: Event Engine not found")
    return false 
  end
  
  print("[VOC_CTRL] calling selector via VOC.startTargetSelection =", tostring(type(VOC.startTargetSelection)))
  VOC.log("StartVECrimeTargetSelection: calling startTargetSelection with callback='VECrimeTargetSelected' cardGuid="..tostring(params.cardGuid))
  local result = VOC.startTargetSelection and VOC.startTargetSelection({
    initiator = params.initiator,
    actionId = "VE_CRIME",
    title = "SELECT TARGET FOR CRIME",
    subtitle = "Choose a player to commit crime against:",
    requireChildren = false,
    callback = "VECrimeTargetSelected",
    callbackParams = { cardGuid = params.cardGuid }
  }) or false
  VOC.log("StartVECrimeTargetSelection: startTargetSelection returned "..tostring(result))
  return result
end

VOC.updateInteractionStatusText = function()
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

-- Define isPlayableColor (forward-declared earlier for use in startTargetSelection)
-- CHUNK-SAFE: use _G.VOC inline resolve (no function call - avoids nil() crash)
isPlayableColor = function(c)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  c = (VOC and VOC.normalizeColor and VOC.normalizeColor(c)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(c))
  if not c then return false end

  -- Primary source: TurnController's configured player colors (W.colors)
  local turnCtrl = (VOC and VOC.findTurnCtrl and VOC.findTurnCtrl()) or (findTurnController and findTurnController())
  if turnCtrl and turnCtrl.call then
    local ok, data = pcall(function() return turnCtrl.call("API_GetPlayerColors", {}) end)
    if ok and type(data) == "table" then
      for _, col in ipairs(data) do
        local nc = (VOC and VOC.normalizeColor and VOC.normalizeColor(col)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(col))
        if nc == c then
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

VOC.resetInteractionButtonsForColor = function(color, active)
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

VOC.setInteractionPanelVisibility = function()
  if not UI then return end

  local function activeFor(c)
    return interaction.targets[c] and "true" or "false"
  end

  UI.setAttribute("interactionYellowPanel", "active", activeFor("Yellow"))
  UI.setAttribute("interactionBluePanel",   "active", activeFor("Blue"))
  UI.setAttribute("interactionRedPanel",    "active", activeFor("Red"))
  UI.setAttribute("interactionGreenPanel",  "active", activeFor("Green"))

  if VOC.resetInteractionButtonsForColor then
    VOC.resetInteractionButtonsForColor("Yellow", interaction.targets["Yellow"] == true)
    VOC.resetInteractionButtonsForColor("Blue",   interaction.targets["Blue"]   == true)
    VOC.resetInteractionButtonsForColor("Red",    interaction.targets["Red"]    == true)
    VOC.resetInteractionButtonsForColor("Green",  interaction.targets["Green"]  == true)
  end
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
    if VOC and VOC.updateInteractionStatusText then VOC.updateInteractionStatusText() end
    if resolveInteractionEffects_impl then
      resolveInteractionEffects_impl()
    end
  else
    if VOC and VOC.updateInteractionTimerText then VOC.updateInteractionTimerText() end
    if Wait and Wait.time then
      local id = interaction.id
      Wait.time(function() tickInteractionTimer(id) end, 1)
    end
  end
end

local function startInteraction(params)
  -- params: id, initiator, title, subtitle, joinCostText, effectText, joinCostAP, duration, onlyTargets, customData
  if not UI then
    VOC.log("startInteraction: UI is nil")
    return
  end

  local initiator = normalizeColor(params.initiator)
  if not initiator then 
    VOC.warn("startInteraction: Invalid initiator="..tostring(params.initiator))
    return 
  end
  
  VOC.log("startInteraction: initiator="..tostring(initiator)..", id="..tostring(params.id))

  if VOC and VOC.clearInteraction then VOC.clearInteraction() end
  interaction.active = true
  interaction.id = params.id
  interaction.initiator = initiator
  interaction.joinCostAP = tonumber(params.joinCostAP or 0) or 0
  interaction.responses = {}
  interaction.targets = {}
  interaction.timer = tonumber(params.duration or 30) or 30
  interaction.customData = params.customData  -- Store custom data for later use

  -- If onlyTargets is provided, use only those players
  if params.onlyTargets and type(params.onlyTargets) == "table" then
    for _, c in ipairs(params.onlyTargets) do
      local nc = normalizeColor(c)
      if nc and nc ~= "White" and isPlayableColor(nc) then
        interaction.targets[nc] = true
      end
    end
  else
    -- Default: all players except initiator and White
    for _, c in ipairs(COLORS) do
      -- Skip White (testing/spectator) and the initiator
      if c ~= initiator and c ~= "White" and isPlayableColor(c) then
        interaction.targets[c] = true
      end
    end
  end

  UI.setAttribute("interactionTitle", "text", params.title or "[EVENT]")
  UI.setAttribute("interactionSubtitle", "text", params.subtitle or "")
  UI.setAttribute("interactionCost", "text", params.joinCostText or "")
  UI.setAttribute("interactionEffect", "text", params.effectText or "")
  
  -- Change button labels for choice interactions
  if params.id == "SW_L1_PRACTICAL_WORKSHOP_CHOICE" then
    -- Update button labels for all colors
    for _, color in ipairs(COLORS) do
      UI.setAttribute("interaction"..color.."Join", "text", "Knowledge")
      UI.setAttribute("interaction"..color.."Ignore", "text", "Skills")
    end
  else
    -- Default labels
    for _, color in ipairs(COLORS) do
      UI.setAttribute("interaction"..color.."Join", "text", "Join")
      UI.setAttribute("interaction"..color.."Ignore", "text", "Ignore")
    end
  end
  
  if VOC and VOC.setInteractionPanelVisibility then VOC.setInteractionPanelVisibility() end
  if VOC and VOC.updateInteractionStatusText then VOC.updateInteractionStatusText() end
  if VOC and VOC.updateInteractionTimerText then VOC.updateInteractionTimerText() end
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

-- Forward declare resolveInteractionEffectsWithDie so it can be called from resolveInteractionEffects_impl
local resolveInteractionEffectsWithDie

-- Safe addAwardToken: avoids "attempt to call nil" when resolveInteractionEffects runs in a different chunk (TTS chunking)
local function safeAddAwardToken(color)
  if not color or color == "White" then return end
  if type(addAwardToken) == "function" then
    addAwardToken(color)
  elseif self and self.call then
    pcall(function() self.call("API_AddAwardToken", {color=color}) end)
  end
end

resolveInteractionEffects_impl = function()
  if not interaction.active then return end

  local id = interaction.id
  local initiator = interaction.initiator

  -- Check if this interaction needs a die roll
  local needsDieRoll = false
  -- Robin Hood (GANG_SPECIAL_ROBIN) is NOT in this list: it uses VOC_StartGangsterRobinHood which does target selection first, then die. Never resolve it here (no target).
  -- NGO_L3_ADVOCACY has no die roll: other players choose YES/NO, then effects apply immediately
  local dieRollActions = {
    "CELEB_L1_STREET_PERF", "CELEB_L2_MEET_GREET", "CELEB_L3_CHARITY_STREAM",
    "PS_L1_INCOME_TAX", "PS_L2_HITECH_TAX", "PS_L3_PROPERTY_TAX",
    "NGO_L1_CHARITY", "NGO_L2_CROWDFUND",
    "ENT_L2_TRAINING", "ENT_SPECIAL_EXPANSION",
    "GANG_L1_CRIME", "GANG_L2_CRIME", "GANG_L3_CRIME"
  }
  for _, actionId in ipairs(dieRollActions) do
    if id == actionId then
      needsDieRoll = true
      break
    end
  end

  if needsDieRoll then
    -- Roll die via .call() so RollDieAndResolveInteraction runs in a chunk that has rollPhysicalDieAndRead in scope
    safeBroadcastAll("🎲 Rolling die for "..id.."...", {1,1,0.6})
    if self and self.call then
      pcall(function() self.call("RollDieAndResolveInteraction", { id = id, initiator = initiator }) end)
    else
      VOC.warn("RollDieAndResolveInteraction: no self.call (chunking)")
    end
    return
  end

  -- No die roll needed, resolve immediately
  resolveInteractionEffectsWithDie(id, initiator, nil)
end

-- Define resolveInteractionEffectsWithDie (forward declared above)
resolveInteractionEffectsWithDie = function(id, initiator, die)
  if not interaction.active then return end
  -- When initiator is White (Spectator), use current turn player for effects
  if not initiator or initiator == "White" then
    initiator = getActiveTurnColor() or initiator
  end
  if not initiator or not isPlayableColor(initiator) then
    VOC.warn("ResolveInteractionEffectsWithDie: invalid initiator "..tostring(initiator))
    if VOC and VOC.clearInteraction then VOC.clearInteraction() end
    return
  end

  -- Social Worker Level 1 – Practical workshop (Stage 1: who joined)
  if id == "SW_L1_PRACTICAL_WORKSHOP" then
    local participants = {}
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        table.insert(participants, c)
      end
    end

    if #participants == 0 then
      safeBroadcastAll("Practical workshop: no one joined → no effect.", {0.9,0.9,0.9})
      if VOC and VOC.clearInteraction then VOC.clearInteraction() end
      return
    else
      -- Check if all other players joined (for bonus)
      local allJoined = true
      for _, c in ipairs(COLORS) do
        if c ~= initiator and isPlayableColor(c) and interaction.responses[c] ~= "JOIN" then
          allJoined = false
          break
        end
      end
      
      -- Store data for stage 2
      local stage2Data = {
        participants = participants,
        initiator = initiator,
        allJoined = allJoined
      }
      
      safeBroadcastAll("Practical workshop: "..#participants.." player(s) joined! Now choosing rewards...", {0.7,1,0.7})
      
      -- Wait a moment, then start stage 2 (startInteraction will clear the first UI automatically)
      Wait.time(function()
        startInteraction({
          id = "SW_L1_PRACTICAL_WORKSHOP_CHOICE",
          initiator = initiator,
          title = "PRACTICAL WORKSHOP - CHOOSE REWARD",
          subtitle = "Each participant: choose +1 Knowledge OR +1 Skill",
          joinCostText = "",  -- No cost for this choice
          effectText = "Click your choice below:",
          joinCostAP = 0,
          duration = 30,
          customData = stage2Data,
          -- Override targets to only include participants
          onlyTargets = participants
        })
      end, 1)
      return
    end
  
  -- Social Worker Level 1 – Practical workshop (Stage 2: reward choice)
  elseif id == "SW_L1_PRACTICAL_WORKSHOP_CHOICE" then
    local stage2Data = interaction.customData
    if not stage2Data then
      VOC.warn("SW_L1_PRACTICAL_WORKSHOP_CHOICE: No customData found!")
      if VOC and VOC.clearInteraction then VOC.clearInteraction() end
      return
    end
    
    local participants = stage2Data.participants or {}
    local initiator = stage2Data.initiator
    local allJoined = stage2Data.allJoined or false
    
    -- Apply rewards based on each player's choice
    for _, c in ipairs(participants) do
      local choice = interaction.responses[c]
      if choice == "JOIN" then
        -- "JOIN" button = Knowledge
        addKnowledge(c, 1)
        safeBroadcastToColor("You gained +1 Knowledge from Practical Workshop!", c, {0.3,1,0.3})
      elseif choice == "IGNORE" then
        -- "IGNORE" button = Skill
        addSkills(c, 1)
        safeBroadcastToColor("You gained +1 Skill from Practical Workshop!", c, {0.3,1,0.3})
      else
        -- No response, default to Knowledge
        addKnowledge(c, 1)
        safeBroadcastToColor("You gained +1 Knowledge from Practical Workshop! (default)", c, {0.9,0.9,0.6})
      end
    end
    
    -- Initiator gains +1 SAT per participant
    satAdd(initiator, #participants)
    safeBroadcastAll("Practical workshop: "..initiator.." gains +"..#participants.." Satisfaction!", {1,1,0.6})
    if #participants > 0 then safeAddAwardToken(initiator) end
    -- If all other players joined: +1 additional SAT & +1 Skill
    if allJoined and #participants > 0 then
      satAdd(initiator, 1)
      addSkills(initiator, 1)
      safeBroadcastAll("All players joined! "..initiator.." gains +1 Satisfaction & +1 Skill bonus!", {1,1,0.6})
    end

    safeBroadcastAll("Practical workshop complete!", {0.3,1,0.3})
    if VOC and VOC.clearInteraction then VOC.clearInteraction() end

  -- Social Worker Level 2 – Community wellbeing session
  elseif id == "SW_L2_COMMUNITY_WELLBEING" then
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
      safeAddAwardToken(initiator)
    end

  -- Social Worker Level 3 – Expose social case
  elseif id == "SW_L3_EXPOSE_CASE" then
    local joinCount = 0
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        joinCount = joinCount + 1
        -- ENGAGE DEEPLY: +1 Knowledge, -2 Satisfaction
        addKnowledge(c, 1)
        satAdd(c, -2)
      else
        -- STAY IGNORANT: +1 Satisfaction
        satAdd(c, 1)
      end
    end
    -- Initiator: +3 Satisfaction
    satAdd(initiator, 3)
    if joinCount > 0 then safeAddAwardToken(initiator) end
    safeBroadcastAll("Social case exposed: "..initiator.." gains +3 Satisfaction.", {0.7,1,0.7})

  -- Celebrity Level 1 – Live Street Performance
  -- Participants (others who joined): each pays 1 AP (via joinCostAP) and gains +2 SAT. Celebrity is not a participant.
  -- If anyone joined: Celebrity gains +1 Skill, +150 VIN, and die 1–3 → +2 SAT, 4–6 → +4 SAT.
  elseif id == "CELEB_L1_STREET_PERF" then
    local participants = {}
    for c, choice in pairs(interaction.responses) do
      if c ~= initiator and choice == "JOIN" then
        table.insert(participants, c)
      end
    end

    if #participants == 0 then
      safeBroadcastToColor("Live Street Performance: no one joined → no effect.", initiator, {0.9,0.9,0.9})
    else
      -- Participants: fixed +2 SAT each (they already paid 1 AP when joining)
      for _, c in ipairs(participants) do
        satAdd(c, 2)
      end

      -- Die roll for celebrity rewards only
      if not die or die < 1 or die > 6 then
        die = math.random(1, 6)
        VOC.warn("Invalid die value, using fallback: "..tostring(die))
      end
      local celebSat = (die <= 3) and 2 or 4

      -- Celebrity: +1 Skill, +150 VIN, and SAT from die (1–3 → +2, 4–6 → +4)
      pcall(function() addSkills(initiator, 1) end)
      pcall(function() moneyAdd(initiator, 150) end)
      satAdd(initiator, celebSat)

      safeBroadcastAll("Live Street Performance: "..initiator.." performed. Participants gained +2 Satisfaction. Celebrity gained +1 Skill, +150 VIN, +"..celebSat.." Satisfaction (die "..die..").", {0.7,1,0.7})
    end
    -- Record Celebrity level action as 1 event (counts toward event obligation)
    state.celebrityEventsThisTurn = state.celebrityEventsThisTurn or { Yellow=0, Blue=0, Red=0, Green=0 }
    local oldCount = tonumber(state.celebrityEventsThisTurn[initiator]) or 0
    state.celebrityEventsThisTurn[initiator] = oldCount + 1
    local newCount = state.celebrityEventsThisTurn[initiator]
    if VOC.log then
      VOC.log("Celebrity level action: " .. initiator .. " used Live Street Performance, event count: " .. oldCount .. " → " .. newCount)
    end

  -- Celebrity Level 2 – Meet & Greet
  elseif id == "CELEB_L2_MEET_GREET" then
    local participants = {}
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        table.insert(participants, c)
      end
    end

    if #participants == 0 then
      -- Celebrity loses satisfaction
      if not die or die < 1 or die > 6 then
        die = math.random(1, 6)
        VOC.warn("Invalid die value, using fallback: "..tostring(die))
      end
      local satLoss = (die <= 3) and -2 or -4
      satAdd(initiator, satLoss)
      safeBroadcastToColor("Meet & Greet: no one joined → you lose "..math.abs(satLoss).." Satisfaction.", initiator, {1,0.7,0.2})
    else
      -- Each participant gains +1 Knowledge & +1 Satisfaction
      for _, c in ipairs(participants) do
        addKnowledge(c, 1)
        satAdd(c, 1)
      end
      
      -- Celebrity gains satisfaction based on D6
      if not die or die < 1 or die > 6 then
        die = math.random(1, 6)
        VOC.warn("Invalid die value, using fallback: "..tostring(die))
      end
      local celebSat = (die <= 3) and 3 or 5
      satAdd(initiator, celebSat)
      
      safeBroadcastAll("Meet & Greet: "..initiator.." met fans. Participants gained +1 Knowledge & +1 Satisfaction.", {0.7,1,0.7})
    end
    -- Record Celebrity level action as 1 event (counts toward event obligation)
    state.celebrityEventsThisTurn = state.celebrityEventsThisTurn or { Yellow=0, Blue=0, Red=0, Green=0 }
    local oldCount = tonumber(state.celebrityEventsThisTurn[initiator]) or 0
    state.celebrityEventsThisTurn[initiator] = oldCount + 1
    local newCount = state.celebrityEventsThisTurn[initiator]
    if VOC.log then
      VOC.log("Celebrity level action: " .. initiator .. " used Meet & Greet, event count: " .. oldCount .. " → " .. newCount)
    end

  -- Celebrity Special – Fan Talent Collaboration
  elseif id == "CELEB_SPECIAL_COLLAB" then
    local supporters = {}
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        table.insert(supporters, c)
        -- Each supporter: gain +1 Knowledge & +2 Satisfaction
        addKnowledge(c, 1)
        satAdd(c, 2)
      end
    end
    
    if #supporters > 0 then
      -- Initiator gains +2 additional Satisfaction (once)
      satAdd(initiator, 2)
      safeBroadcastAll("Fan Collaboration: "..initiator.." collaborated with "..#supporters.." supporter(s).", {0.7,1,0.7})
    end

  -- Celebrity Level 3 – Extended Charity Stream
  elseif id == "CELEB_L3_CHARITY_STREAM" then
    -- This is a multi-donation event (players can join multiple times)
    -- For now, treat each JOIN as one donation
    local donations = 0
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        donations = donations + 1
        -- Each donation: donor gains +2 Satisfaction
        satAdd(c, 2)
        -- Deduct 500 VIN per donation
        if not moneySpend(c, 500) then
          -- If they can't afford it, remove them from donations
          donations = donations - 1
        end
      end
    end
    
    if donations > 0 then
      -- Celebrity gains +2 SAT per donation & +1 AP obligation per donation
      satAdd(initiator, donations * 2)
      -- TODO: Track AP obligations
      safeBroadcastToColor("+1 AP obligation per donation (manual tracking needed)", initiator, {0.7,0.7,1})
      safeBroadcastAll("Charity Stream: "..initiator.." raised "..donations.." donation(s).", {0.7,1,0.7})
    end
    -- Record Celebrity level action as 1 event (counts toward event obligation)
    state.celebrityEventsThisTurn = state.celebrityEventsThisTurn or { Yellow=0, Blue=0, Red=0, Green=0 }
    local oldCount = tonumber(state.celebrityEventsThisTurn[initiator]) or 0
    state.celebrityEventsThisTurn[initiator] = oldCount + 1
    local newCount = state.celebrityEventsThisTurn[initiator]
    if VOC.log then
      VOC.log("Celebrity level action: " .. initiator .. " used Charity Stream, event count: " .. oldCount .. " → " .. newCount)
    end

  -- Public Servant Level 1 – Income Tax Campaign
  elseif id == "PS_L1_INCOME_TAX" then
    -- When initiator is White (Spectator), satisfaction goes to current turn player
    local beneficiary = (initiator == "White" and getActiveTurnColor()) or initiator
    if not beneficiary or not isPlayableColor(beneficiary) then
      beneficiary = initiator
    end
    if not die or die < 1 or die > 6 then
      die = math.random(1, 6)
      VOC.warn("Invalid die value, using fallback: "..tostring(die))
    end
    if die <= 2 then
      safeBroadcastAll("Income Tax Campaign: Some documents were missing → no taxes collected.", {0.9,0.9,0.9})
    elseif die <= 4 then
      -- Each player pays 15% of cash (Public Servant may waive own obligation once per level); beneficiary gains +1 Satisfaction
      local totalCollected = 0
      for _, c in ipairs(COLORS) do
        if isPlayableColor(c) then
          local currentMoney = getMoney(c)
          local tax = math.floor(currentMoney * 0.15)
          totalCollected = totalCollected + collectTaxWithWaiver(c, tax, beneficiary)
        end
      end
      if totalCollected > 0 then safeAddAwardToken(beneficiary) end
      safeBroadcastAll("Income Tax Campaign: Each player pays 15% of cash. "..beneficiary.." gains +1 Satisfaction.", {0.7,1,0.7})
      satAdd(beneficiary, 1)
    else
      -- Each player pays 30% of cash (Public Servant may waive own obligation once per level); beneficiary gains +3 Satisfaction
      local totalCollected = 0
      for _, c in ipairs(COLORS) do
        if isPlayableColor(c) then
          local currentMoney = getMoney(c)
          local tax = math.floor(currentMoney * 0.30)
          totalCollected = totalCollected + collectTaxWithWaiver(c, tax, beneficiary)
        end
      end
      if totalCollected > 0 then safeAddAwardToken(beneficiary) end
      safeBroadcastAll("Income Tax Campaign: Each player pays 30% of cash. "..beneficiary.." gains +3 Satisfaction.", {0.7,1,0.7})
      satAdd(beneficiary, 3)
    end

  -- Public Servant Level 2 – Hi-Tech Tax Campaign
  elseif id == "PS_L2_HITECH_TAX" then
    if not die or die < 1 or die > 6 then
      die = math.random(1, 6)
      VOC.warn("Invalid die value, using fallback: "..tostring(die))
    end
    if die <= 2 then
      safeBroadcastAll("Hi-Tech Tax Campaign: Some documents were missing → no taxes collected.", {0.9,0.9,0.9})
    elseif die <= 4 then
      local totalCollected = 0
      for _, c in ipairs(COLORS) do
        if isPlayableColor(c) then
          totalCollected = totalCollected + collectTaxWithWaiver(c, 200, initiator)
        end
      end
      if totalCollected > 0 then safeAddAwardToken(initiator) end
      safeBroadcastAll("Hi-Tech Tax Campaign: Each player pays 200 VIN per High-Tech item. "..initiator.." gains +2 Satisfaction.", {0.7,1,0.7})
      satAdd(initiator, 2)
    else
      local totalCollected = 0
      for _, c in ipairs(COLORS) do
        if isPlayableColor(c) then
          totalCollected = totalCollected + collectTaxWithWaiver(c, 400, initiator)
        end
      end
      if totalCollected > 0 then safeAddAwardToken(initiator) end
      safeBroadcastAll("Hi-Tech Tax Campaign: Each player pays 400 VIN per High-Tech item. "..initiator.." gains +4 Satisfaction.", {0.7,1,0.7})
      satAdd(initiator, 4)
    end

  -- Public Servant Level 3 – Property Tax Campaign
  elseif id == "PS_L3_PROPERTY_TAX" then
    if not die or die < 1 or die > 6 then
      die = math.random(1, 6)
      VOC.warn("Invalid die value, using fallback: "..tostring(die))
    end
    if die <= 2 then
      safeBroadcastAll("Property Tax Campaign: Some documents were missing → no taxes collected.", {0.9,0.9,0.9})
    elseif die <= 4 then
      local totalCollected = 0
      for _, c in ipairs(COLORS) do
        if isPlayableColor(c) then
          totalCollected = totalCollected + collectTaxWithWaiver(c, 200, initiator)
        end
      end
      if totalCollected > 0 then safeAddAwardToken(initiator) end
      safeBroadcastAll("Property Tax Campaign: Each player pays 200 VIN per property level. "..initiator.." gains +3 Satisfaction.", {0.7,1,0.7})
      satAdd(initiator, 3)
    else
      local totalCollected = 0
      for _, c in ipairs(COLORS) do
        if isPlayableColor(c) then
          totalCollected = totalCollected + collectTaxWithWaiver(c, 400, initiator)
        end
      end
      if totalCollected > 0 then safeAddAwardToken(initiator) end
      safeBroadcastAll("Property Tax Campaign: Each player pays 400 VIN per property level. "..initiator.." gains +6 Satisfaction.", {0.7,1,0.7})
      satAdd(initiator, 6)
    end

  -- NGO Worker Level 1 – Start Charity
  elseif id == "NGO_L1_CHARITY" then
    if not die or die < 1 or die > 6 then
      die = math.random(1, 6)
      VOC.warn("Invalid die value, using fallback: "..tostring(die))
    end
    if die <= 2 then
      safeBroadcastAll("Start Charity: Nothing happens.", {0.9,0.9,0.9})
    else
      safeAddAwardToken(initiator)
      if die <= 4 then
        for _, c in ipairs(COLORS) do
          if c ~= initiator and isPlayableColor(c) then moneySpend(c, 200) end
        end
        safeBroadcastAll("Start Charity: Each player pays 200 VIN.", {0.7,1,0.7})
      else
        for _, c in ipairs(COLORS) do
          if c ~= initiator and isPlayableColor(c) then moneySpend(c, 400) end
        end
        moneyAdd(initiator, 400)
        safeBroadcastAll("Start Charity: Each player pays 400 VIN. "..initiator.." gains 400 VIN reward.", {0.7,1,0.7})
      end
    end

  -- NGO Worker Level 2 – Crowdfunding Campaign
  elseif id == "NGO_L2_CROWDFUND" then
    if not die or die < 1 or die > 6 then
      die = math.random(1, 6)
      VOC.warn("Invalid die value, using fallback: "..tostring(die))
    end
    if die <= 2 then
      safeBroadcastAll("Crowdfunding Campaign: Nothing happens.", {0.9,0.9,0.9})
    else
      safeAddAwardToken(initiator)
      if die <= 4 then
        for _, c in ipairs(COLORS) do
          if c ~= initiator and isPlayableColor(c) then moneySpend(c, 250) end
        end
        safeBroadcastAll("Crowdfunding Campaign: Each player pays 250 VIN.", {0.7,1,0.7})
      else
        for _, c in ipairs(COLORS) do
          if c ~= initiator and isPlayableColor(c) then moneySpend(c, 400) end
        end
        moneyAdd(initiator, 400)
        safeBroadcastAll("Crowdfunding Campaign: Each player pays 400 VIN. "..initiator.." must spend this on High-Tech item.", {0.7,1,0.7})
      end
    end

  -- NGO Worker Level 3 – Advocacy Pressure Campaign
  elseif id == "NGO_L3_ADVOCACY" then
    local participants = {}
    local ignoreCount = 0
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        table.insert(participants, c)
      elseif choice == "IGNORE" then
        ignoreCount = ignoreCount + 1
      end
    end

    -- YES (Support): Pay 300 VIN, gain +2 Satisfaction
    for _, c in ipairs(participants) do
      if moneySpend(c, 300) then
        satAdd(c, 2)
      end
    end

    -- NO (Ignore): Lose -1 Satisfaction
    for c, choice in pairs(interaction.responses) do
      if choice == "IGNORE" then
        satAdd(c, -1)
      end
    end

    -- Initiator: +1 SAT per participant; +1 Skill only when everybody said No (if at least one said Yes, no skill)
    satAdd(initiator, #participants)
    -- Award token only when campaign was successful: at least one other player said Yes (supported)
    if #participants > 0 then safeAddAwardToken(initiator) end
    if #participants == 0 and ignoreCount > 0 then
      addSkills(initiator, 1)
      safeBroadcastAll("Advocacy Campaign: "..initiator.." ran the event. Everyone said No → +1 Skill.", {0.7,1,0.7})
    elseif #participants > 0 then
      safeBroadcastAll("Advocacy Campaign: "..initiator.." ran the event. "..#participants.." supported, "..ignoreCount.." said No.", {0.7,1,0.7})
    else
      safeBroadcastAll("Advocacy Campaign: "..initiator.." ran the event. No responses.", {0.7,1,0.7})
    end

  -- NGO Worker Special – International Crisis Appeal
  elseif id == "NGO_SPECIAL_CRISIS" then
    local participants = {}
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        table.insert(participants, c)
        -- Each joiner: donate 200 VIN, gain +2 Satisfaction
        if moneySpend(c, 200) then
          satAdd(c, 2)
        end
      end
    end
    
    -- Initiator: +2 SAT per joiner, +1 SAT per refuser
    local joiners = #participants
    local refusers = 0
    for c, choice in pairs(interaction.responses) do
      if choice == "IGNORE" then
        refusers = refusers + 1
      end
    end
    satAdd(initiator, joiners * 2 + refusers)
    
    safeBroadcastAll("Crisis Appeal: "..initiator.." raised "..joiners.." donation(s).", {0.7,1,0.7})

  -- NGO Worker Special – Misused Donation Scandal
  elseif id == "NGO_SPECIAL_SCANDAL" then
    if not die or die < 1 or die > 6 then
      die = math.random(1, 6)
      VOC.warn("Invalid die value, using fallback: "..tostring(die))
    end
    if die <= 2 then
      satAdd(initiator, -3)
      safeBroadcastAll("Donation Scandal: Donor accuses you publicly → "..initiator.." loses -3 Satisfaction.", {1,0.7,0.2})
    elseif die <= 4 then
      satAdd(initiator, 4)
      safeBroadcastAll("Donation Scandal: Issue resolved quietly → "..initiator.." gains +4 Satisfaction.", {0.7,1,0.7})
    else
      satAdd(initiator, 6)
      addKnowledge(initiator, 1)
      safeBroadcastAll("Donation Scandal: Donor apologizes publicly → "..initiator.." gains +6 Satisfaction & +1 Knowledge.", {0.7,1,0.7})
    end

  -- Entrepreneur Level 1 – Flash Sale Promotion
  elseif id == "ENT_L1_FLASH_SALE" then
    -- All players may immediately buy one Consumable with 30% discount
    -- Initiator gains +1 Satisfaction per other player who buys
    -- TODO: Implement shop interaction
    safeBroadcastAll("Flash Sale: All players may buy one Consumable with 30% discount. "..initiator.." gains +1 Satisfaction per buyer.", {0.7,1,0.7})

  -- Entrepreneur Level 2 – Commercial Training Course
  elseif id == "ENT_L2_TRAINING" then
    local participants = {}
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        table.insert(participants, c)
        -- Each participant pays 200 VIN
        moneySpend(c, 200)
      end
    end
    
    -- Initiator gains +1 Satisfaction per participant
    satAdd(initiator, #participants)
    
    -- Exam time! Roll D6 for each participant
    -- Note: This needs individual die rolls per participant, but we only have one die roll
    -- For now, use the single die roll for the first participant, then roll for others
    for i, c in ipairs(participants) do
      local examDie = die
      if i == 1 then
        -- Use the main die roll for first participant
        if not examDie or examDie < 1 or examDie > 6 then
          examDie = math.random(1, 6)
          VOC.warn("Invalid die value for exam, using fallback: "..tostring(examDie))
        end
      else
        -- For subsequent participants, roll again (would need async handling)
        examDie = math.random(1, 6)
        VOC.warn("Multiple exam participants - using fallback die for participant "..i)
      end
      if die == 1 then
        safeBroadcastToColor("Training Exam: Failed → no learning", c, {1,0.7,0.2})
      elseif die <= 5 then
        -- TODO: Add +1 Knowledge OR +1 Skill (player choice)
        safeBroadcastToColor("Training Exam: Passed → +1 Knowledge OR +1 Skill (manual adjustment needed)", c, {0.7,0.7,1})
      else
        -- TODO: Add +2 Knowledge OR +2 Skills (player choice)
        safeBroadcastToColor("Training Exam: Genius → +2 Knowledge OR +2 Skills (manual adjustment needed)", c, {0.7,0.7,1})
      end
    end
    
    safeBroadcastAll("Training Course: "..initiator.." ran the course. "..#participants.." participant(s).", {0.7,1,0.7})

  -- Entrepreneur Special – Aggressive Expansion
  elseif id == "ENT_SPECIAL_EXPANSION" then
    if not die or die < 1 or die > 6 then
      die = math.random(1, 6)
      VOC.warn("Invalid die value, using fallback: "..tostring(die))
    end
  if die <= 2 then
    satAdd(initiator, -2)
    moneySpend(initiator, 200)
    safeBroadcastAll("Aggressive Expansion: Collapse → "..initiator.." loses -2 Satisfaction & -200 VIN.", {1,0.7,0.2})
  elseif die <= 4 then
    satAdd(initiator, 3)
    safeBroadcastAll("Aggressive Expansion: Moderate growth → "..initiator.." gains +3 Satisfaction.", {0.7,1,0.7})
  else
    satAdd(initiator, 6)
    moneyAdd(initiator, 800)
    safeBroadcastAll("Aggressive Expansion: Massive success → "..initiator.." gains +6 Satisfaction & +800 VIN.", {0.7,1,0.7})
    end

  -- Entrepreneur Special – Employee Training Boost
  elseif id == "ENT_SPECIAL_TRAINING" then
  if not moneySpend(initiator, 500) then
    safeBroadcastToColor("⛔ Not enough money (need 500 VIN) for Employee Training.", initiator, {1,0.6,0.2})
    return false
  end
  satAdd(initiator, 2)
  addSkills(initiator, 2)
  safeBroadcastAll("Employee Training: "..initiator.." gains +2 Satisfaction & +2 Skills.", {0.7,1,0.7})

  -- Gangster Special – Robin Hood Job must NEVER be resolved here (no target). It is only run via VOC_StartGangsterRobinHood (event card / vocation action) which does: choose target → roll die → steal from target, donate to orphanage, +SAT to initiator.
  elseif id == "GANG_SPECIAL_ROBIN" then
    safeBroadcastAll("Robin Hood Job: Use the vocation event card and choose a target first. This path has no target – no effect applied.", {1,0.85,0.3})
    if VOC and VOC.clearInteraction then VOC.clearInteraction() end
    return

  -- Gangster Special – Protection Racket
  elseif id == "GANG_SPECIAL_PROTECTION" then
    local participants = {}
    local totalCollected = 0
    for c, choice in pairs(interaction.responses) do
      if choice == "JOIN" then
        -- Pay: spend 200 VIN per vocation level
        local targetLevel = state.levels[c] or 1
        local cost = 200 * targetLevel
        if moneySpend(c, cost) then
          table.insert(participants, c)
          totalCollected = totalCollected + cost
        else
          -- If they can't afford it, treat as refuse
          satAdd(c, -2)
          addHealth(c, -2)
        end
      else
        -- Refuse: lose -2 Health & -2 Satisfaction
        addHealth(c, -2)
        satAdd(c, -2)
      end
    end
    
    -- Initiator: +1 SAT per payer, receive the money collected
    satAdd(initiator, #participants)
    if totalCollected > 0 then
      moneyAdd(initiator, totalCollected)
    end
    
    -- Heat +1 (no investigation – protection racket raises heat but does not trigger investigation)
    local pawn = findHeatPawn()
    if pawn and pawn.call then
      pcall(function() pawn.call("AddHeat", 1) end)
      safeBroadcastAll("Heat +1 (police more cautious).", {0.7, 0.8, 1})
    end
    
    safeBroadcastAll("Protection Racket: "..initiator.." collected "..tostring(totalCollected).." VIN from "..#participants.." payer(s). Heat level +1.", {0.7,1,0.7})
  end

  if VOC and VOC.clearInteraction then VOC.clearInteraction() end
end

-- Definition of handleInteractionResponse (forward-declared earlier)
handleInteractionResponse = function(color, choice, actorColor)
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
  if VOC and VOC.updateInteractionStatusText then VOC.updateInteractionStatusText() end

  if allInteractionResponsesCollected() then
    if resolveInteractionEffects_impl then
      resolveInteractionEffects_impl()
    end
  end
end

-- Callable entry point for Join/Ignore so UI callbacks (invoked via .call from Global) can reach handleInteractionResponse
-- without chunking issues (handleInteractionResponse can be nil in the chunk where UI_Interaction_* live).
function HandleInteractionResponse(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  if not params or not params.buttonColor then return end
  local fn = handleInteractionResponse
  if type(fn) == "function" then
    fn(params.buttonColor, params.choice or "JOIN", params.actorColor)
  else
    if VOC.warn then VOC.warn("HandleInteractionResponse: handleInteractionResponse not available (chunking)") end
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
      state.workAPThisRound = data.workAPThisRound or state.workAPThisRound
      state.experienceYearsEarned = data.experienceYearsEarned or state.experienceYearsEarned
      state.noSpecialAwardThisYear = data.noSpecialAwardThisYear or state.noSpecialAwardThisYear
      state.levelUpRound = data.levelUpRound or state.levelUpRound
      state.taxWaiverUsedAtLevel = data.taxWaiverUsedAtLevel or state.taxWaiverUsedAtLevel
      state.swGoodKarmaUsed = data.swGoodKarmaUsed or state.swGoodKarmaUsed or {}
      state.ngoGoodKarmaUsedPerLevel = data.ngoGoodKarmaUsedPerLevel or state.ngoGoodKarmaUsedPerLevel or {}
      state.ngoTakeTripUsedPerLevel = data.ngoTakeTripUsedPerLevel or state.ngoTakeTripUsedPerLevel or {}
      state.ngoUseInvestmentUsedPerLevel = data.ngoUseInvestmentUsedPerLevel or state.ngoUseInvestmentUsedPerLevel or {}
      state.ngoInvestmentSubsidyActive = data.ngoInvestmentSubsidyActive or state.ngoInvestmentSubsidyActive or {}
      state.swConsumablePerkUsed = data.swConsumablePerkUsed or state.swConsumablePerkUsed or {}
      state.swHitechPerkUsed = data.swHitechPerkUsed or state.swHitechPerkUsed or {}
      state.lockdownPending = data.lockdownPending or {}
      state.voluntaryWorkAP = data.voluntaryWorkAP or state.voluntaryWorkAP or { Yellow=0, Blue=0, Red=0, Green=0 }
      state.celebrityAwardReceived = data.celebrityAwardReceived or state.celebrityAwardReceived or { Yellow=false, Blue=false, Red=false, Green=false }
      -- Backfill: if a player has a vocation but no levelUpRound (old save), treat as round 1
      for _, c in ipairs(COLORS) do
        if state.vocations[c] and (state.levelUpRound[c] == nil or state.levelUpRound[c] == 0) then
          state.levelUpRound[c] = 1
        end
      end
      VOC.log("State loaded")
    end
  end
end

local function saveState()
  local data = {
    vocations = state.vocations,
    levels = state.levels,
    workAP = state.workAP,
    workAPThisLevel = state.workAPThisLevel,
    workAPThisRound = state.workAPThisRound,
    experienceYearsEarned = state.experienceYearsEarned,
    noSpecialAwardThisYear = state.noSpecialAwardThisYear,
    levelUpRound = state.levelUpRound,
    taxWaiverUsedAtLevel = state.taxWaiverUsedAtLevel,
    swGoodKarmaUsed = state.swGoodKarmaUsed or {},
    ngoGoodKarmaUsedPerLevel = state.ngoGoodKarmaUsedPerLevel or {},
    ngoTakeTripUsedPerLevel = state.ngoTakeTripUsedPerLevel or {},
    ngoUseInvestmentUsedPerLevel = state.ngoUseInvestmentUsedPerLevel or {},
    ngoInvestmentSubsidyActive = state.ngoInvestmentSubsidyActive or {},
    swConsumablePerkUsed = state.swConsumablePerkUsed or {},
    swHitechPerkUsed = state.swHitechPerkUsed or {},
    lockdownPending = state.lockdownPending or {},
    voluntaryWorkAP = state.voluntaryWorkAP or { Yellow=0, Blue=0, Red=0, Green=0 },
    celebrityAwardReceived = state.celebrityAwardReceived or { Yellow=false, Blue=false, Red=false, Green=false },
    celebrityCashbackRefunds = state.celebrityCashbackRefunds or {},
  celebrityEventsThisTurn = state.celebrityEventsThisTurn or { Yellow=0, Blue=0, Red=0, Green=0 },
  }
  self.script_state = JSON.encode(data)
end

-- Callable so UI/callbacks in other chunks can persist state (saveState is local and may be nil there).
function VOC_SaveState()
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  saveState()
end

-- =========================================================
-- TILE MANAGEMENT
-- =========================================================
local function findTileForVocationAndLevel(vocation, level)
  local vocationTag = "WLB_VOC_" .. vocation
  local levelTag = "WLB_VOC_LEVEL_" .. level
  
  local allObjects = VOC.getAllObjectsSafe()
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
  local allObjects = VOC.getAllObjectsSafe()
  
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
    VOC.log("Board not found for " .. color)
    return false
  end
  
  local localPos = CHARACTER_SLOT_LOCAL[color]
  if not localPos then
    VOC.log("Character slot position not set for " .. color)
    return false
  end
  
  local worldPos = board.positionToWorld(localPos)
  tile.setPositionSmooth(worldPos, false, true)
  tile.addTag(colorTag(color))
  pcall(function() if tile.clearContextMenu then tile.clearContextMenu() end end)
  addClickToShowExplanationButton(tile)
  pcall(function() if tile.setLock then tile.setLock(false) end end)

  VOC.log("Placed tile on " .. color .. " board")
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
  
  VOC.log("Removed tile from " .. color .. " board")
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
    VOC.log("New tile not found: " .. vocation .. " Level " .. newLevel)
    return false
  end
  
  local success = placeTileOnBoard(newTile, color)
  if success then
    VOC.log("Swapped tile: " .. color .. " " .. vocation .. " Level " .. oldLevel .. " → " .. newLevel)
  end
  
  return success
end

-- =========================================================
-- DEBUG STATE FUNCTION
-- =========================================================
function VOC_DebugState()
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return {} end
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
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
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
  for _, obj in ipairs(VOC.getAllObjectsSafe()) do
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
  state.workAPThisRound = { Yellow = 0, Blue = 0, Red = 0, Green = 0 }
  state.experienceYearsEarned = { Yellow = 0, Blue = 0, Red = 0, Green = 0 }
  state.noSpecialAwardThisYear = { Yellow = false, Blue = false, Red = false, Green = false }
  state.levelUpRound = { Yellow = nil, Blue = nil, Red = nil, Green = nil }
  state.taxWaiverUsedAtLevel = { Yellow = nil, Blue = nil, Red = nil, Green = nil }
  state.swGoodKarmaUsed = {}
  state.ngoGoodKarmaUsedPerLevel = {}
  state.ngoTakeTripUsedPerLevel = {}
  state.ngoUseInvestmentUsedPerLevel = {}
  state.ngoInvestmentSubsidyActive = {}
  state.swConsumablePerkUsed = {}
  state.swHitechPerkUsed = {}
  state.crowdfundPool = {}
  state.crowdfundPoolTurnColor = {}
  state.voluntaryWorkAP = { Yellow=0, Blue=0, Red=0, Green=0 }
  state.celebrityAwardReceived = { Yellow=false, Blue=false, Red=false, Green=false }
  state.celebrityEventsThisTurn = { Yellow=0, Blue=0, Red=0, Green=0 }
  state.currentPickerColor = nil
  selectionState.activeColor = nil
  selectionState.shownSummary = nil
  selectionState.shownVocation = nil
  selectionState.shownExplanationCard = nil
  saveState()
  VOC.log("Vocation state reset for new game")
end

function VOC_GetVocation(params)
  if not params then return nil end
  -- Use _G.VOC_normalizeColor directly (chunk-safe, no VOC_NS dependency)
  local color = (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then return nil end
  return state.vocations[color]
end

function VOC_SetVocation(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return false, "VOC missing" end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  local vocation = params.vocation
  
  if not color then
    if VOC.log then VOC.log("Invalid color") end
    return false, "Invalid color"
  end
  
  if not vocation then
    if VOC.log then VOC.log("Vocation not specified") end
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
    if VOC.log then VOC.log("Invalid vocation: " .. tostring(vocation)) end
    return false, "Invalid vocation"
  end
  
  -- One player, one vocation: cannot change during the game
  if state.vocations[color] and state.vocations[color] ~= vocation then
    if VOC.log then VOC.log("Player " .. color .. " already has vocation " .. tostring(state.vocations[color]) .. "; cannot change to " .. tostring(vocation)) end
    return false, "Already has a different vocation"
  end
  
  -- Check exclusivity (can't choose if already taken)
  for _, c in ipairs(COLORS) do
    if c ~= color and state.vocations[c] == vocation then
      if VOC.log then VOC.log("Vocation " .. vocation .. " already taken by " .. c) end
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
    if VOC.log then VOC.log("Warning: Level 1 tile not found for " .. vocation) end
  end
  
  if VOC.log then VOC.log("Vocation set: " .. color .. " → " .. vocation) end
  broadcastToAll(color .. " chose " .. VOCATION_DATA[vocation].name, {0.3, 1, 0.3})
  
  -- Update rental costs immediately if player is Social Worker (50% rent discount)
  -- This ensures the discount applies from the round they get the vocation, not just next turn
  if vocation == VOC_SOCIAL_WORKER then
    Wait.time(function()
      -- Estate/Market controller object uses tag WLB_MARKET_CTRL (EstateEngine script); try both for compatibility
      local estateList = VOC.getObjectsWithTagSafe("WLB_ESTATE_ENGINE") or {}
      if #estateList == 0 then
        estateList = VOC.getObjectsWithTagSafe("WLB_MARKET_CTRL") or {}
      end
      local estate = estateList[1]
      if estate and estate.call then
        local ok = pcall(function()
          estate.call("API_UpdateRentalCostsForVocationChange", { color = color })
        end)
        if not ok and VOC.warn then VOC.warn("API_UpdateRentalCostsForVocationChange failed for "..tostring(color)) end
      else
        if VOC.warn then VOC.warn("Estate/Market controller not found (WLB_ESTATE_ENGINE / WLB_MARKET_CTRL); Social Worker rent not updated") end
      end
    end, 0.5)  -- Small delay to ensure state is saved
  end
  
  return true
end

function VOC_GetLevel(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return nil end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  if not color then return nil end
  return state.levels[color] or 1
end

-- Public Servant: Mastery of Administrative Law – one tax waiver per vocation level.
-- Returns true if this player is Public Servant and has not used their waiver for the current level.
function API_CanPublicServantWaiveTax(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  if not color then return false end
  if state.vocations[color] ~= VOC_PUBLIC_SERVANT then return false end
  local level = state.levels[color] or 1
  local usedAt = state.taxWaiverUsedAtLevel[color]
  return (usedAt == nil or usedAt ~= level)
end

-- Mark that the Public Servant used their tax waiver for the current level (once per level).
function API_UsePublicServantTaxWaiver(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  if not color then return false end
  if state.vocations[color] ~= VOC_PUBLIC_SERVANT then return false end
  local level = state.levels[color] or 1
  state.taxWaiverUsedAtLevel[color] = level
  return true
end

-- Returns "Tax can be waived" or "Tax obligation" for the summary UI (Public Servant only). Others return "".
function API_GetPublicServantTaxWaiverStatus(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return "" end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  if not color then return "" end
  if state.vocations[color] ~= VOC_PUBLIC_SERVANT then return "" end
  local level = state.levels[color] or 1
  local usedAt = state.taxWaiverUsedAtLevel[color]
  if usedAt == nil or usedAt ~= level then
    return "Tax can be waived"
  end
  return "Tax obligation"
end

-- Apply tax for one player: if they are the beneficiary (Public Servant) and can use waiver, waive and don't deduct; else deduct. Returns amount actually collected (0 if waived).
local function collectTaxWithWaiver(color, taxAmount, beneficiary)
  if not isPlayableColor(color) or taxAmount <= 0 then return 0 end
  if color == beneficiary and state.vocations[color] == VOC_PUBLIC_SERVANT then
    local canWaive = API_CanPublicServantWaiveTax({ color = color })
    if canWaive then
      API_UsePublicServantTaxWaiver({ color = color })
      safeBroadcastAll("📜 " .. color .. " waived their tax obligation (Mastery of Administrative Law – once per level).", {0.5, 0.9, 0.6})
      return 0
    end
  end
  if moneySpend(color, taxAmount) then return taxAmount end
  return 0
end

-- Overworking satisfaction loss (general rule). NGO Worker is exempt.
-- workAPThisTurn: 0-2 → 0 sat loss, 3-4 → 1, 5-6 → 2, 7-8 → 3, 9+ → 4.
-- Returns the number of satisfaction points to deduct (0 if NGO Worker or no loss).
function API_GetOverworkSatLoss(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return 0 end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then return 0 end
  if state.vocations[color] == VOC_NGO_WORKER then return 0 end
  local work = math.max(0, math.floor(tonumber(params.workAPThisTurn) or 0))
  if work <= 2 then return 0 end
  if work <= 4 then return 1 end
  if work <= 6 then return 2 end
  if work <= 8 then return 3 end
  return 4
end

-- Returns current experience token count for a player (for UI and promotion). Used by standard vocations (not Celebrity).
function API_GetExperienceTokenCount(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return 0 end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color or params.player_color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color or params.player_color)) or nil
  if not color then return 0 end
  return getExperienceTokenCount(color)
end

function VOC_GetSalary(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return 0 end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color))
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
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  local amount = tonumber(params and params.amount) or 0
  if not color then return false end
  state.workAP[color] = (state.workAP[color] or 0) + amount
  state.workAPThisLevel[color] = (state.workAPThisLevel[color] or 0) + amount
  state.workAPThisRound[color] = (state.workAPThisRound[color] or 0) + amount
  
  saveState()
  if VOC.log then VOC.log("Work AP added: " .. color .. " +" .. amount .. " (total: " .. state.workAP[color] .. ", this level: " .. state.workAPThisLevel[color] .. ", this round: " .. (state.workAPThisRound[color] or 0) .. ")") end
  
  return true
end

function VOC_GetTotalWorkAP(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return 0 end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  if not color then return 0 end
  return state.workAP[color] or 0
end

function VOC_GetWorkAPThisLevel(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return 0 end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  if not color then return 0 end
  return state.workAPThisLevel[color] or 0
end

-- Experience token tag (must match TokenEngine WLB_STATUS_EXPERIENCE)
local TAG_STATUS_EXPERIENCE = "WLB_STATUS_EXPERIENCE"
local TAG_STATUS_AWARD = "WLB_STATUS_AWARD"

-- Add one award token for a player (Public Servant, Social Worker, NGO, Gangster award progress)
local function addAwardToken(color)
  if not color or color == "White" then return false end
  local psc = findPlayerStatusController()
  if not psc or not psc.call then return false end
  local ok = pcall(function()
    return psc.call("PS_Event", { op = "ADD_STATUS", color = color, statusTag = TAG_STATUS_AWARD })
  end)
  if ok then safeBroadcastAll("🏆 Award token received: " .. color, {0.9,0.9,0.5}) end
  return ok
end

-- Callable: add award token (avoids "attempt to call nil" when resolveInteractionEffects runs in a different chunk)
function API_AddAwardToken(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  local color = params and (params.color or params.actorColor)
  color = (color and ((VOC.normalizeColor and VOC.normalizeColor(color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(color)))) or nil
  if not color or color == "White" then return false end
  return addAwardToken(color)
end

-- Get award token count for a player (for promotion/award check)
local function getAwardTokenCount(color)
  if not color or color == "White" then return 0 end
  local psc = findPlayerStatusController()
  if not psc or not psc.call then return 0 end
  local ok, count = pcall(function()
    return psc.call("PS_Event", { op = "GET_STATUS_COUNT", color = color, statusTag = TAG_STATUS_AWARD })
  end)
  if ok and type(count) == "number" and count >= 0 then return count end
  return 0
end

function VOC_GetVocationData(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return nil end
  local vocation = params and params.vocation
  if not vocation then return nil end
  return VOCATION_DATA[vocation]
end

-- Find Token Engine (for giving experience tokens) - use VOC.findTokenEngine (chunk-safe)

-- Get current experience token count for a player (for promotion and display). Returns 0 if TokenEngine missing.
local function getExperienceTokenCount(color)
  if not color or color == "White" then return 0 end
  local tokenEngine = findTokenEngine()
  if not tokenEngine or not tokenEngine.call then return 0 end
  local ok, count = pcall(function()
    return tokenEngine.call("TE_GetStatusCount_ARGS", { color = color, statusTag = TAG_STATUS_EXPERIENCE })
  end)
  if ok and type(count) == "number" and count >= 0 then return count end
  return 0
end

-- Called by TurnController at end of each round (when turn wraps to next round). Work obligation + experience tokens.
function VOC_OnRoundEnd(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  params = params or {}
  local roundJustFinished = tonumber(params.round) or getCurrentRound()
  local tokenEngine = findTokenEngine()

  -- Reset L3 "no special award" so this round we only set it for those who failed
  for _, c in ipairs(COLORS) do
    state.noSpecialAwardThisYear[c] = false
  end

  for _, color in ipairs(COLORS) do
    local vocation = state.vocations[color]
    if vocation and color ~= "White" then
    local level = state.levels[color] or 1
    local workThisRound = state.workAPThisRound[color] or 0
    local inRange = (workThisRound >= 2 and workThisRound <= 4)
    local giveExperience = false

    if vocation == VOC_PUBLIC_SERVANT then
      -- Work obligation: must work 2–4 AP per year
      if level == 1 then
        if not inRange then
          safeBroadcastToColor("📋 Public Servant (L1): You worked " .. tostring(workThisRound) .. " AP this year (need 2–4). No experience token; this year does not count for promotion.", color, {1, 0.85, 0.4})
        else
          giveExperience = true
          state.experienceYearsEarned[color] = (state.experienceYearsEarned[color] or 0) + 1
        end
      elseif level == 2 then
        if not inRange then
          local off = (workThisRound < 2) and (2 - workThisRound) or (workThisRound > 4) and (workThisRound - 4) or 0
          local satLoss = math.max(0, off)
          if satLoss > 0 then
            satAdd(color, -satLoss)
            safeBroadcastToColor("📋 Public Servant (L2): You worked " .. tostring(workThisRound) .. " AP (need 2–4). -" .. tostring(satLoss) .. " Satisfaction; no experience token this year.", color, {1, 0.6, 0.2})
          else
            safeBroadcastToColor("📋 Public Servant (L2): You worked " .. tostring(workThisRound) .. " AP (need 2–4). No experience token this year.", color, {1, 0.85, 0.4})
          end
        else
          giveExperience = true
          state.experienceYearsEarned[color] = (state.experienceYearsEarned[color] or 0) + 1
        end
      elseif level == 3 then
        if not inRange then
          local off = (workThisRound < 2) and (2 - workThisRound) or (workThisRound > 4) and (workThisRound - 4) or 0
          local satLoss = math.max(0, off) * 2
          if satLoss > 0 then satAdd(color, -satLoss) end
          state.noSpecialAwardThisYear[color] = true
          safeBroadcastToColor("📋 Public Servant (L3): You worked " .. tostring(workThisRound) .. " AP (need 2–4). " .. (satLoss > 0 and ("-" .. tostring(satLoss) .. " Satisfaction. ") or "") .. "No special award this year.", color, {1, 0.6, 0.2})
        else
          giveExperience = true
          state.noSpecialAwardThisYear[color] = false
        end
      end
    elseif vocation == VOC_CELEBRITY then
      -- Celebrity does not use experience tokens (work-based promotion only, checked at turn end)
      giveExperience = false
    else
      -- Other vocations: tokens are now given at turn end (VOC_OnTurnEnd), not at round end
      -- Skip adding tokens here to avoid double-counting
      giveExperience = false
    end

    if giveExperience and tokenEngine and tokenEngine.call then
      pcall(function()
        tokenEngine.call("TE_AddStatus_ARGS", { color = color, statusTag = TAG_STATUS_EXPERIENCE })
      end)
      if vocation == VOC_PUBLIC_SERVANT then
        safeBroadcastToColor("📋 Experience token received (work obligation met: 2–4 AP this year).", color, {0.5, 1, 0.6})
      else
        safeBroadcastToColor("📋 Experience token received (1 per year).", color, {0.5, 1, 0.6})
      end
    end

    state.workAPThisRound[color] = 0
    end -- vocation and not White
  end

  saveState()
  return true
end

-- Called by TurnController when a new round starts (after round increments)
-- Pay out Celebrity hi-tech cashback refunds at the start of the round so players can use the money
function VOC_OnRoundStart(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local currentRound = tonumber(params.round) or getCurrentRound() or 1
  
  -- Celebrity hi-tech cashback: Pay out pending refunds due this round
  state.celebrityCashbackRefunds = state.celebrityCashbackRefunds or {}
  for color, refunds in pairs(state.celebrityCashbackRefunds) do
    if type(refunds) == "table" then
      local totalRefund = 0
      local refundCount = 0
      local refundDetails = {}
      for i = #refunds, 1, -1 do
        local refund = refunds[i]
        if refund and refund.roundDue and refund.roundDue <= currentRound then
          totalRefund = totalRefund + (tonumber(refund.amount) or 0)
          refundCount = refundCount + 1
          table.insert(refundDetails, refund.cardName or "hi-tech item")
          table.remove(refunds, i)
        end
      end
      if totalRefund > 0 then
        moneyAdd(color, totalRefund)
        local detailMsg = refundCount == 1 and refundDetails[1] or (refundCount .. " items")
        safeBroadcastToColor("💰 Celebrity cashback: Received " .. totalRefund .. " VIN refund from hi-tech purchase(s) (" .. detailMsg .. ")", color, {0.9,0.7,0.3})
        broadcastToAll("💰 " .. color .. " (Celebrity) received " .. totalRefund .. " VIN cashback from hi-tech purchases.", {0.9,0.7,0.3})
      end
      -- Clean up empty refund arrays
      if #refunds == 0 then
        state.celebrityCashbackRefunds[color] = nil
      end
    end
  end
  
  return true
end

-- Called by TurnController at end of each player's turn. Adds experience tokens and checks for promotion.
-- Most vocations get 1 token per turn (if they have the vocation). Public Servant gets tokens at round end based on work obligation.
function VOC_OnTurnEnd(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color))
  if not color or color == "White" then return false end
  
  local vocation = state.vocations[color]
  if not vocation then return false end
  
  local level = state.levels[color] or 1
  local tokenEngine = findTokenEngine()
  
  -- Track regular work AP (AP moved to WORK area for salary)
  -- This is separate from vocation-specific actions which call VOC_AddWorkAP directly
  -- Get work count from params (passed by TurnController before AP is finalized)
  local workCount = tonumber(params.workAPThisTurn) or 0
  
  if VOC.log then
    VOC.log("VOC_OnTurnEnd: Checking work AP for " .. color .. " - workCount from params: " .. tostring(workCount))
  end
  
  -- Only add work AP if player actually worked (workCount > 0)
  -- Note: Vocation-specific actions already call VOC_AddWorkAP, so we're tracking regular work here
  if workCount > 0 then
    VOC_AddWorkAP({ color = color, amount = workCount })
    if VOC.log then VOC.log("VOC_OnTurnEnd: Added " .. workCount .. " regular work AP for " .. color) end
  end
  
  -- NGO Worker Crowdfunding enforcement: Check if player has unused crowdfund pool
  -- If pool exists at turn end, they failed to buy hi-tech and lose the money
  state.crowdfundPool = state.crowdfundPool or {}
  state.crowdfundPoolTurnColor = state.crowdfundPoolTurnColor or {}
  local currentTurn = (Turns and Turns.turn_color and Turns.turn_color ~= "") and normalizeColor(Turns.turn_color) or color
  if state.crowdfundPool[color] and state.crowdfundPoolTurnColor[color] == currentTurn then
    local lostPool = tonumber(state.crowdfundPool[color]) or 0
    if lostPool > 0 then
      -- Remove the money that was given to them (they didn't use it)
      -- Use resolveMoney to get money controller, then spend
      local moneyObj = resolveMoney(color)
      if moneyObj and moneyObj.call then
        pcall(function() moneyObj.call("API_spend", {amount = lostPool}) end)
      end
      safeBroadcastToColor("⚠️ Crowdfunding pool expired! You did not buy a High-Tech item this turn. Lost " .. lostPool .. " VIN from the crowdfunding pool.", color, {1,0.6,0.2})
      broadcastToAll("💰 " .. color .. " lost " .. lostPool .. " VIN from unused crowdfunding pool.", {1,0.7,0.3})
      state.crowdfundPool[color] = nil
      state.crowdfundPoolTurnColor[color] = nil
    end
  end
  
  -- Entrepreneur: Richest player satisfaction (passive perk)
  -- If Entrepreneur has highest money at end of turn, gain satisfaction based on level
  if vocation == VOC_ENTREPRENEUR then
    local entrepreneurMoney = getMoney(color) or 0
    local maxMoney = entrepreneurMoney
    local isRichest = true
    
    -- Check all playable colors to find highest money
    local colors = (VOC and VOC.COLORS) or COLORS or {"Yellow", "Blue", "Red", "Green"}
    for _, c in ipairs(colors) do
      if c ~= color then
        local otherMoney = getMoney(c) or 0
        if otherMoney > maxMoney then
          maxMoney = otherMoney
          isRichest = false
        end
      end
    end
    
    -- If Entrepreneur has highest money (or tied for highest), grant satisfaction
    if isRichest and entrepreneurMoney >= maxMoney and entrepreneurMoney > 0 then
      local satBonus = (level >= 3) and 2 or 1  -- Level 3: +2 Sat, Level 1/2: +1 Sat
      if satAdd(color, satBonus) then
        VOC.log("VOC_OnTurnEnd: Entrepreneur " .. color .. " has highest money (" .. tostring(entrepreneurMoney) .. " VIN) → +" .. tostring(satBonus) .. " Satisfaction")
        safeBroadcastAll("💰 " .. color .. " (Entrepreneur) has the highest money (" .. tostring(entrepreneurMoney) .. " VIN) → +" .. tostring(satBonus) .. " Satisfaction", {0.9, 0.7, 0.3})
      end
    end
  end
  
  -- Public Servant: tokens are given at round end based on work obligation (2-4 AP per round)
  -- Skip turn-end token for Public Servant
  if vocation == VOC_PUBLIC_SERVANT then
    return false
  end
  
  -- Celebrity: Check for automatic promotion when work AP quotas are met (work-based promotion)
  -- Also check event card obligations (L2: at least 1 event, L3: at least 2 events)
  if vocation == VOC_CELEBRITY then
    -- Check event card obligation
    state.celebrityEventsThisTurn = state.celebrityEventsThisTurn or { Yellow=0, Blue=0, Red=0, Green=0 }
    local eventsPlayed = tonumber(state.celebrityEventsThisTurn[color]) or 0
    
    if level >= 2 then
      local requiredEvents = (level >= 3) and 2 or 1
      local missingEvents = math.max(0, requiredEvents - eventsPlayed)
      
      if missingEvents > 0 then
        local satPenalty = missingEvents * 3  -- -3 SAT per missing event
        if satAdd(color, -satPenalty) then
          safeBroadcastToColor("⚠️ Celebrity obligation not met: Played " .. eventsPlayed .. " event(s) this turn, need " .. requiredEvents .. " → -" .. satPenalty .. " Satisfaction", color, {1, 0.6, 0.2})
          broadcastToAll("⚠️ " .. color .. " (Celebrity L" .. level .. ") failed event obligation: -" .. satPenalty .. " Satisfaction", {1, 0.7, 0.3})
        end
      else
        safeBroadcastToColor("✅ Celebrity obligation met: Played " .. eventsPlayed .. " event(s), need " .. requiredEvents, color, {0.7, 1, 0.7})
      end
    end
    
    -- Reset event counter for next turn
    state.celebrityEventsThisTurn[color] = 0
    
    -- Check if Celebrity meets promotion requirements
    local canPromote, reason = VOC_CanPromote({color=color})
    if canPromote then
      local promoteOk, promoteErr = VOC_Promote({color=color})
      if promoteOk then
        safeBroadcastToColor("🎉 Celebrity promotion! You have been automatically promoted!", color, {0.3, 1, 0.3})
      else
        safeBroadcastToColor("⚠️ Celebrity promotion failed: " .. tostring(promoteErr), color, {1, 0.6, 0.2})
      end
    else
      -- Surface why promotion did not happen so players see missing quotas (K/S/AP/money)
      if reason and reason ~= "" then
        safeBroadcastToColor("📋 Celebrity promotion requirements not met: " .. tostring(reason), color, {1, 0.85, 0.4})
      end
    end
    return false
  end
  
  -- Other vocations: give 1 experience token per turn (just for having the vocation)
  -- This applies to: Social Worker, NGO Worker, Entrepreneur, Gangster
  -- They get 1 token per turn regardless of whether they worked
  local giveExperience = true
  
  if giveExperience and tokenEngine and tokenEngine.call then
    local addOk, addErr = pcall(function()
      return tokenEngine.call("TE_AddStatus_ARGS", { color = color, statusTag = TAG_STATUS_EXPERIENCE })
    end)
    if addOk then
      local newCount = getExperienceTokenCount(color)
      VOC.log("VOC_OnTurnEnd: Added experience token to " .. color .. " (new count: " .. tostring(newCount) .. ")")
      safeBroadcastToColor("📋 Experience token received (1 per turn).", color, {0.5, 1, 0.6})
      
      -- Check promotion eligibility AFTER turn ends with a delay
      -- Wait 5 seconds after turn ends before checking for promotion
      Wait.time(function()
        local canPromote, reason = VOC_CanPromote({color=color})
        if canPromote then
          VOC.log("VOC_OnTurnEnd: " .. color .. " meets promotion requirements after turn ended, promoting now")
          local promoteOk, promoteErr = VOC_Promote({color=color})
          if promoteOk then
            VOC.log("VOC_OnTurnEnd: Successfully promoted " .. color)
          else
            VOC.log("VOC_OnTurnEnd: Failed to promote " .. color .. " - " .. tostring(promoteErr))
          end
        end
      end, 5.0)  -- Wait 5 seconds after turn ends before checking for promotion
      
      saveState()
      return true
    else
      VOC.log("VOC_OnTurnEnd: Failed to add experience token to " .. color .. " - " .. tostring(addErr))
    end
  end
  
  return false
end

-- =========================================================
-- DIE ROLLING
-- =========================================================
local function getDie()
  return VOC.getObjectFromGUID(DIE_GUID)
end

local function tryReadDieValue(die)
  if not die then return nil end
  -- Try multiple methods to read die value
  if die.getValue then
    local ok, v = pcall(function() return die.getValue() end)
    if ok and type(v) == "number" and v >= 1 and v <= 6 then 
      return v 
    end
  end
  -- Fallback: try getRotation to determine face value (less reliable)
  -- This is a last resort - getValue should work for standard dice
  return nil
end

local function rollPhysicalDieAndRead(callback)
  local die = getDie()
  if not die then
    callback(nil, "Die not found (GUID "..tostring(DIE_GUID)..")")
    return
  end

  pcall(function() die.randomize() end)
  pcall(function() die.roll() end)

  -- Increased timeout to 10 seconds to give die more time to settle
  local timeout = os.time() + 10

  Wait.condition(
    function()
      -- This function is called when the condition is met
      -- Wait a small moment for die to fully settle, then read
      Wait.time(function()
        local v = tryReadDieValue(die)
        if v and v >= 1 and v <= 6 then
          callback(v, nil)
        else
          callback(nil, "Failed to read die value (getValue returned invalid result).")
        end
      end, 0.3)  -- Small delay to ensure die is fully settled
    end,
    function()
      -- Condition: die is resting OR timeout reached
      local resting = false
      pcall(function() resting = die.resting end)
      if resting then return true end
      if os.time() >= timeout then return true end
      return false
    end
  )
end

-- Clear the two Entrepreneur die-halt buttons (try die first, fallback to VocationsController).
local function clearEntrepreneurDieHaltButtons()
  local h = _G.VOC_entrepreneurDieHalt
  if not h then return end
  
  -- Try to clear buttons on die first
  local die = getDie()
  if die and die.clearButtons then
    pcall(function() die.clearButtons() end)
  end
  
  -- Also clear buttons on VocationsController (fallback location)
  if self and self.clearButtons then
    pcall(function() self.clearButtons() end)
  end
  
  -- Clear button references
  h.btnReroll = nil
  h.btnGoOn = nil
end

-- Show Reroll and Go on buttons positioned above the die (always on VocationsController for stable positioning).
-- Buttons are positioned in world space above the die, then converted to controller's local coordinates.
-- Reroll only if not yet used (hasRerolled == false).
local function showEntrepreneurDieHaltButtons()
  local h = _G.VOC_entrepreneurDieHalt
  if not h then return end
  
  local die = getDie()
  if not die then
    safeBroadcastAll("⚠️ Cannot find die for reroll buttons.", {1,0.6,0.2})
    return
  end
  
  if not self or not self.createButton then
    safeBroadcastAll("⚠️ Cannot create reroll buttons - VocationsController not available.", {1,0.6,0.2})
    return
  end
  
  clearEntrepreneurDieHaltButtons()
  
  local w, height, fs = 750, 320, 260
  
  -- Get die's world position (x, y, z)
  local dieWorldPos = nil
  if die.getPosition then
    local ok, pos = pcall(function() return die.getPosition() end)
    if ok and pos and type(pos) == "table" then
      -- Handle both {x, y, z} and {x=x, y=y, z=z} formats
      if pos.x then
        dieWorldPos = {x = pos.x, y = pos.y, z = pos.z}
      elseif pos[1] then
        dieWorldPos = {x = pos[1], y = pos[2], z = pos[3]}
      end
    end
  end
  
  if not dieWorldPos then
    safeBroadcastAll("⚠️ Cannot get die position for reroll buttons.", {1,0.6,0.2})
    return
  end
  
  -- Get controller's world position and rotation
  local controllerWorldPos = nil
  local controllerRotation = nil
  if self.getPosition then
    local ok, pos = pcall(function() return self.getPosition() end)
    if ok and pos and type(pos) == "table" then
      if pos.x then
        controllerWorldPos = {x = pos.x, y = pos.y, z = pos.z}
      elseif pos[1] then
        controllerWorldPos = {x = pos[1], y = pos[2], z = pos[3]}
      end
    end
  end
  
  if self.getRotation then
    local ok, rot = pcall(function() return self.getRotation() end)
    if ok and rot and type(rot) == "table" then
      if rot.y then
        controllerRotation = rot.y  -- Y rotation (yaw) affects X/Z positioning
      elseif rot[2] then
        controllerRotation = rot[2]
      end
    end
  end
  
  if not controllerWorldPos then
    safeBroadcastAll("⚠️ Cannot get controller position for reroll buttons.", {1,0.6,0.2})
    return
  end
  
  -- Calculate button positions relative to controller
  -- Position buttons directly above the die using positionToLocal for accurate conversion
  local buttonHeightAboveDie = 1.5  -- Height above die in world space
  local buttonSpacing = 2  -- Spacing between buttons (increased significantly for better visibility)
  
  -- Calculate world-space positions above the die
  local worldPosAboveDieCenter = {
    x = dieWorldPos.x,
    y = dieWorldPos.y + buttonHeightAboveDie,
    z = dieWorldPos.z
  }
  
  local worldPosReroll = {
    x = worldPosAboveDieCenter.x - buttonSpacing,  -- Left button
    y = worldPosAboveDieCenter.y,
    z = worldPosAboveDieCenter.z
  }
  
  local worldPosGoOn = {
    x = worldPosAboveDieCenter.x + buttonSpacing,  -- Right button
    y = worldPosAboveDieCenter.y,
    z = worldPosAboveDieCenter.z
  }
  
  -- Convert world positions to controller's local coordinates using positionToLocal
  local buttonLocalPosReroll = { -0.5, 0.35, 0.0 }  -- Default fallback
  local buttonLocalPosGoOn = { 0.5, 0.35, 0.0 }     -- Default fallback
  
  if self.positionToLocal then
    -- Convert world positions to local coordinates
    -- positionToLocal expects a Vector or {x, y, z} table
    local okReroll, localReroll = pcall(function()
      -- Try passing as Vector first, then as table
      local result
      if Vector then
        result = self.positionToLocal(Vector(worldPosReroll.x, worldPosReroll.y, worldPosReroll.z))
      else
        result = self.positionToLocal(worldPosReroll)
      end
      
      if result then
        -- Handle both {x, y, z} and {x=x, y=y, z=z} formats
        if type(result) == "table" then
          if result.x then
            return {x = result.x, y = result.y, z = result.z}
          elseif result[1] then
            return {x = result[1], y = result[2], z = result[3]}
          end
        end
      end
      return nil
    end)
    
    local okGoOn, localGoOn = pcall(function()
      local result
      if Vector then
        result = self.positionToLocal(Vector(worldPosGoOn.x, worldPosGoOn.y, worldPosGoOn.z))
      else
        result = self.positionToLocal(worldPosGoOn)
      end
      
      if result then
        if type(result) == "table" then
          if result.x then
            return {x = result.x, y = result.y, z = result.z}
          elseif result[1] then
            return {x = result[1], y = result[2], z = result[3]}
          end
        end
      end
      return nil
    end)
    
    if okReroll and localReroll then
      buttonLocalPosReroll = { localReroll.x or -0.5, localReroll.y or 0.35, localReroll.z or 0.0 }
    end
    
    if okGoOn and localGoOn then
      buttonLocalPosGoOn = { localGoOn.x or 0.5, localGoOn.y or 0.35, localGoOn.z or 0.0 }
    end
  end
  
  -- If positionToLocal failed or isn't available, use direct offset calculation
  if buttonLocalPosReroll[1] == -0.5 and buttonLocalPosReroll[2] == 0.35 then
    -- Fallback: Simple offset calculation
    local dx = dieWorldPos.x - controllerWorldPos.x
    local dy = (dieWorldPos.y + buttonHeightAboveDie) - controllerWorldPos.y
    local dz = dieWorldPos.z - controllerWorldPos.z
    buttonLocalPosReroll = { dx - buttonSpacing, dy, dz }
    buttonLocalPosGoOn = { dx + buttonSpacing, dy, dz }
  end
  
  -- Create Reroll button only if not already rerolled
  if not h.hasRerolled then
    local ok, idx = pcall(function()
      return self.createButton({
        label = "Reroll",
        click_function = "OnEntrepreneurDieReroll",
        function_owner = self,
        position = buttonLocalPosReroll,
        rotation = {0, 180, 0},  -- Rotate 180 degrees to fix upside-down text
        width = w,
        height = height,
        font_size = fs,
        color = {0.9, 0.3, 0.3, 0.95},
        font_color = {1, 1, 1, 1},
        tooltip = "Spend 1 AP to reroll once. Only once per roll."
      })
    end)
    if ok and idx then
      h.btnReroll = idx
    end
  end
  
  -- Create Go on button
  local okGo, idxGo = pcall(function()
    return self.createButton({
      label = "Go on",
      click_function = "OnEntrepreneurDieGoOn",
      function_owner = self,
      position = buttonLocalPosGoOn,
      rotation = {0, 180, 0},  -- Rotate 180 degrees to fix upside-down text
      width = w,
      height = height,
      font_size = fs,
      color = {0.3, 0.9, 0.3, 0.95},
      font_color = {1, 1, 1, 1},
      tooltip = "Accept current die result and continue."
    })
  end)
  if okGo and idxGo then
    h.btnGoOn = idxGo
  end
  
  safeBroadcastAll("🎲 Entrepreneur: choose Reroll (1 AP, once) or Go on.", {1,1,0.7})
end

-- Callable: roll die then resolve interaction (avoids calling rollPhysicalDieAndRead from resolveInteractionEffects_impl chunk)
-- For Entrepreneur only: after roll we halt and show Reroll / Go on buttons instead of resolving immediately.
function RollDieAndResolveInteraction(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return end
  if not params or not params.id then return end
  local id, initiator = params.id, params.initiator
  if type(rollPhysicalDieAndRead) ~= "function" then
    if VOC.warn then VOC.warn("RollDieAndResolveInteraction: rollPhysicalDieAndRead not available") end
    return
  end
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end
    -- Entrepreneur L2 "Use your network": halt after roll and show Reroll (1 AP, once) / Go on. Only during their turn.
    local vocation = (state and state.vocations) and state.vocations[initiator] or nil
    local entLevel = (state and state.levels and state.levels[initiator]) or 1
    local activeTurn = getActiveTurnColor()
    if vocation == VOC_ENTREPRENEUR and entLevel == 2 and activeTurn == initiator then
      _G.VOC_entrepreneurDieHalt = {
        dieValue = die,
        id = id,
        initiator = initiator,
        hasRerolled = false,
        btnReroll = nil,
        btnGoOn = nil
      }
      showEntrepreneurDieHaltButtons()
      return
    end
    local me = self
    if me and me.call then
      pcall(function() me.call("ResolveInteractionEffectsWithDie", { id = id, initiator = initiator, die = die }) end)
    elseif type(resolveInteractionEffectsWithDie) == "function" then
      resolveInteractionEffectsWithDie(id, initiator, die)
    else
      if VOC2 and VOC2.warn then VOC2.warn("RollDieAndResolveInteraction: ResolveInteractionEffectsWithDie not available (chunking)") end
    end
  end)
end

-- Called when player clicks "Go on" on Entrepreneur die halt. Resolve with current die and clear halt.
function OnEntrepreneurDieGoOn(obj, color, alt_click)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return end
  local h = _G.VOC_entrepreneurDieHalt
  if not h then return end
  if color ~= h.initiator and color ~= "White" then
    safeBroadcastToColor("Only the Entrepreneur (or host) can choose Go on.", color, {1,0.6,0.2})
    return
  end
  -- Call VocationsController method directly (self is VocationsController when function_owner is set)
  -- Use direct function call since we're in the same script
  if type(VOC_ResolveEntrepreneurDieGoOn) == "function" then
    VOC_ResolveEntrepreneurDieGoOn({})
  elseif self and self.call then
    pcall(function() self.call("VOC_ResolveEntrepreneurDieGoOn", {}) end)
  end
end

-- Called when player clicks "Reroll" on Entrepreneur die halt. Spend 1 AP, reroll once, then show only Go on.
function OnEntrepreneurDieReroll(obj, color, alt_click)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return end
  local h = _G.VOC_entrepreneurDieHalt
  if not h then return end
  if color ~= h.initiator and color ~= "White" then
    safeBroadcastToColor("Only the Entrepreneur (or host) can choose Reroll.", color, {1,0.6,0.2})
    return
  end
  -- Call VocationsController method directly (self is VocationsController when function_owner is set)
  -- Use direct function call since we're in the same script
  if type(VOC_ResolveEntrepreneurDieReroll) == "function" then
    VOC_ResolveEntrepreneurDieReroll({})
  elseif self and self.call then
    pcall(function() self.call("VOC_ResolveEntrepreneurDieReroll", {}) end)
  end
end

-- Helper function to deliver die roll result via callback
local function deliverDieRollResult(requestId, dieValue)
  if not requestId or not dieValue then return end
  
  local callbackInfo = _G.VOC_DieRollCallbacks and _G.VOC_DieRollCallbacks[requestId]
  if not callbackInfo then
    if VOC and VOC.warn then VOC.warn("No callback info found for requestId: " .. tostring(requestId)) end
    return
  end
  
  -- Call back to the requesting object
  if callbackInfo.callbackObject and callbackInfo.callbackFunction then
    pcall(function()
      callbackInfo.callbackObject.call(callbackInfo.callbackFunction, {
        result = dieValue,
        requestId = requestId,
        color = callbackInfo.color
      })
    end)
  end
  
  -- Clean up callback info
  if _G.VOC_DieRollCallbacks then
    _G.VOC_DieRollCallbacks[requestId] = nil
  end
end

-- Callable: resolve current Entrepreneur die halt with stored die value and clear buttons.
function VOC_ResolveEntrepreneurDieGoOn(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing in this chunk") return end
  local h = _G.VOC_entrepreneurDieHalt
  if not h then return end
  local id, initiator, dieValue = h.id, h.initiator, h.dieValue
  local requestId = h.requestId
  
  -- If a reroll was performed, use the stored reroll value (h.dieValue was updated in VOC_ResolveEntrepreneurDieReroll)
  -- Only re-read if no reroll was performed (to ensure we have the latest value)
  if not h.hasRerolled then
    -- No reroll was done, re-read die value from physical die to ensure accuracy
    local die = getDie()
    if die then
      local currentDieValue = tryReadDieValue(die)
      if currentDieValue and currentDieValue >= 1 and currentDieValue <= 6 then
        dieValue = currentDieValue
      end
    end
  end
  
  -- Validate die value
  if not dieValue or dieValue < 1 or dieValue > 6 then
    if VOC.warn then VOC.warn("VOC_ResolveEntrepreneurDieGoOn: Invalid die value "..tostring(dieValue)..", using fallback") end
    dieValue = math.random(1, 6)
    safeBroadcastAll("⚠️ Invalid die value detected, using fallback: "..tostring(dieValue), {1,0.7,0.3})
  end
  
  -- Deliver result via callback system
  if requestId then
    deliverDieRollResult(requestId, dieValue)
    clearEntrepreneurDieHaltButtons()
    _G.VOC_entrepreneurDieHalt = nil
    return
  elseif id then
    if self and self.call then
      pcall(function() self.call("ResolveInteractionEffectsWithDie", { id = id, initiator = initiator, die = dieValue }) end)
    elseif type(resolveInteractionEffectsWithDie) == "function" then
      resolveInteractionEffectsWithDie(id, initiator, dieValue)
    end
  end
end

-- Callable: spend 1 AP, reroll once, then re-show halt UI (only "Go on" after reroll).
function VOC_ResolveEntrepreneurDieReroll(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing in this chunk") return end
  local h = _G.VOC_entrepreneurDieHalt
  if not h then return end
  if h.hasRerolled then
    safeBroadcastAll("Reroll already used once this event.", {1,0.6,0.2})
    return
  end
  local initiator = h.initiator
  if initiator ~= "White" and not canSpendAP(initiator, 1) then
    safeBroadcastToColor("Not enough AP (need 1) to reroll.", initiator, {1,0.6,0.2})
    return
  end
  if not spendAP(initiator, 1, "ENT_REROLL") then
    safeBroadcastToColor("Failed to spend 1 AP for reroll.", initiator, {1,0.6,0.2})
    return
  end
  safeBroadcastAll("Reroll: spending 1 AP, rolling again...", {1,1,0.7})
  clearEntrepreneurDieHaltButtons()
  h.hasRerolled = true
  h.btnReroll = nil
  h.btnGoOn = nil
  if type(rollPhysicalDieAndRead) ~= "function" then
    safeBroadcastAll("Die roll not available; using previous result.", {1,0.7,0.3})
    -- Show only "Go on" button since reroll was attempted
    showEntrepreneurDieHaltButtons()
    return
  end
  rollPhysicalDieAndRead(function(die, err)
    if err then
      die = h.dieValue
      safeBroadcastAll("Reroll failed, keeping previous result: "..tostring(die), {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Reroll result: "..tostring(die), {0.8,0.9,1})
      h.dieValue = die  -- Update stored die value with reroll result
      if VOC.log then VOC.log("VOC_ResolveEntrepreneurDieReroll: Updated h.dieValue to "..tostring(die)) end
    end
    
    -- After reroll, always deliver the result immediately (no "Go on" button)
    local finalDieValue = h.dieValue
    
    -- Validate die value
    if not finalDieValue or finalDieValue < 1 or finalDieValue > 6 then
      if VOC.warn then VOC.warn("VOC_ResolveEntrepreneurDieReroll: Invalid die value "..tostring(finalDieValue)..", using fallback") end
      finalDieValue = math.random(1, 6)
      safeBroadcastAll("⚠️ Invalid die value detected, using fallback: "..tostring(finalDieValue), {1,0.7,0.3})
    end
    
    -- Deliver result based on type
    if h.requestId then
      deliverDieRollResult(h.requestId, finalDieValue)
      clearEntrepreneurDieHaltButtons()
      _G.VOC_entrepreneurDieHalt = nil
      return
    elseif h.id then
      -- Interaction-based roll – resolve immediately with rerolled value
      local id, initiator = h.id, h.initiator
      if self and self.call then
        pcall(function() self.call("ResolveInteractionEffectsWithDie", { id = id, initiator = initiator, die = finalDieValue }) end)
      elseif type(resolveInteractionEffectsWithDie) == "function" then
        resolveInteractionEffectsWithDie(id, initiator, finalDieValue)
      end
    end
    
    clearEntrepreneurDieHaltButtons()
    _G.VOC_entrepreneurDieHalt = nil
  end)
end

-- Callable: returns true ONLY if this player is Entrepreneur L2 and it's their turn (so we need Reroll/Go on UI).
-- Callers use this to decide: direct roll (most cases) vs VOC_RollDieForPlayer (Entrepreneur L2 only).
function VOC_CanUseEntrepreneurReroll(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing in this chunk") return false end
  if not params or not params.color then return false end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color))
  if not color then return false end
  local vocation = (state and state.vocations) and state.vocations[color] or nil
  local entLevel = (state and state.levels and state.levels[color]) or 1
  -- Chunk-safe: use ONLY _G.VOC_CTRL.getActiveTurnColor (never local lookup)
  local gac = (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.getActiveTurnColor) == "function") and _G.VOC_CTRL.getActiveTurnColor or nil
  local activeTurn = (type(gac) == "function" and gac()) or nil
  return (vocation == VOC_ENTREPRENEUR and entLevel == 2 and activeTurn == color)
end

-- Callable: central die roll with Entrepreneur L2 "Use your network" support.
-- Params: { requestId = string, color = player color, callbackObject = object, callbackFunction = string }
-- Uses callback system to deliver results directly to requesting object.
-- IMPORTANT: Only use this when VOC_CanUseEntrepreneurReroll(color)==true; otherwise use direct physical roll.
function VOC_RollDieForPlayer(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing in this chunk") return end
  if not params or not params.requestId or not params.color then return end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color))
  local requestId = params.requestId
  if not color then return end
  
  -- Store callback info for later delivery
  if not _G.VOC_DieRollCallbacks then _G.VOC_DieRollCallbacks = {} end
  _G.VOC_DieRollCallbacks[requestId] = {
    callbackObject = params.callbackObject,  -- Object to call back to (e.g., ShopEngine object)
    callbackFunction = params.callbackFunction,  -- Function name to call (e.g., "OnDieRollResult")
    requestId = requestId,
    color = color
  }
  
  if type(rollPhysicalDieAndRead) ~= "function" then
    local fallback = math.random(1, 6)
    deliverDieRollResult(requestId, fallback)
    return
  end
  
  rollPhysicalDieAndRead(function(die, err)
    if err then
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..tostring(die), {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..tostring(die), {0.8,0.9,1})
    end
    
    local vocation = (state and state.vocations) and state.vocations[color] or nil
    local entLevel = (state and state.levels and state.levels[color]) or 1
    -- Chunk-safe: use ONLY _G.VOC_CTRL.getActiveTurnColor (never local lookup)
    local gac = (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.getActiveTurnColor) == "function") and _G.VOC_CTRL.getActiveTurnColor or nil
    local activeTurn = (type(gac) == "function" and gac()) or nil
    
    if vocation == VOC_ENTREPRENEUR and entLevel == 2 and activeTurn == color then
      -- Entrepreneur L2 during their turn: show reroll buttons
      _G.VOC_entrepreneurDieHalt = {
        dieValue = die,
        requestId = requestId,
        initiator = color,
        hasRerolled = false,
        btnReroll = nil,
        btnGoOn = nil
      }
      showEntrepreneurDieHaltButtons()
    else
      -- Normal case: deliver result immediately
      deliverDieRollResult(requestId, die)
    end
  end)
end

-- Start Social Worker Level 2 community event: "Community wellbeing session"
-- Flow:
--  - Active Social Worker (level 2+) spends 2 AP
--  - Other players may JOIN by spending 1 AP
--  - If no one joins → no effect
--  - Each participant gains +2 SAT
--  - Initiator gains +1 SAT per participant, plus +2 SAT if anyone joined
function VOC_StartSocialWorkerCommunitySession(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false, "VOC missing" end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  local effectsTarget = params.effectsTarget
  local initiatorColor = effectsTarget or color
  if VOC.log then VOC.log("VOC_StartSocialWorkerCommunitySession: color="..tostring(color)..", effectsTarget="..tostring(effectsTarget)..", initiatorColor="..tostring(initiatorColor)) end

  local vocation = state.vocations[initiatorColor]
  
  -- Bypass checks if White is testing
  if color ~= "White" and vocation ~= VOC_SOCIAL_WORKER then
    safeBroadcastToColor("Only Social Worker can use this community event.", color, {1,0.7,0.2})
    return false, "Wrong vocation"
  end

  local level = state.levels[initiatorColor] or 1
  if color ~= "White" and level ~= 2 then
    safeBroadcastToColor("⛔ This action is only available at Social Worker Level 2. Your character is Level " .. tostring(level) .. ".", initiatorColor, {1,0.6,0.2})
    return false, "Wrong level"
  end

  -- Spend 2 AP from initiator (bypass if White is testing)
  if not canSpendAP(initiatorColor, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Community wellbeing session.", initiatorColor, {1,0.6,0.2})
    return false, "Not enough AP"
  end
  local ok = spendAP(initiatorColor, 2, "SW_L2_COMMUNITY_WELLBEING")
  if not ok then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP for Community wellbeing session.", initiatorColor, {1,0.6,0.2})
    return false, "AP deduction failed"
  end
  VOC_AddWorkAP({ color = initiatorColor, amount = 2 })
  if VOC.log then VOC.log("VOC_StartSocialWorkerCommunitySession: Starting interaction with initiator="..tostring(initiatorColor)) end
  
  startInteraction({
    id = "SW_L2_COMMUNITY_WELLBEING",
    initiator = initiatorColor,  -- Use the actual player color
    title = "COMMUNITY EVENT – Community wellbeing session",
    subtitle = "Social Worker – Cost for you: Spend 2 AP",
    joinCostText = "Others may join by spending 1 AP.",
    effectText = "Each participant gains +2 Satisfaction. You gain +1 Satisfaction per participant, plus +2 extra Satisfaction if anyone joins.",
    joinCostAP = 1,
  })

  return true
end

-- =========================================================
-- SOCIAL WORKER ACTIONS
-- =========================================================

-- Social Worker Level 1: Practical workshop
function VOC_StartSocialWorkerPracticalWorkshop(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  if VOC.log then VOC.log("VOC_StartSocialWorkerPracticalWorkshop: Called with params="..tostring(params and "table" or "nil")) end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then 
    if VOC.log then VOC.log("VOC_StartSocialWorkerPracticalWorkshop: ERROR - No valid color") end
    return false, "Invalid color" 
  end
  local effectsTarget = params.effectsTarget
  local initiatorColor = effectsTarget or color
  if VOC.log then VOC.log("VOC_StartSocialWorkerPracticalWorkshop: color="..tostring(color)..", effectsTarget="..tostring(effectsTarget)..", initiatorColor="..tostring(initiatorColor)) end
  if not state or not state.vocations then
    if VOC.log then VOC.log("VOC_StartSocialWorkerPracticalWorkshop: ERROR - state or state.vocations is nil") end
    safeBroadcastToColor("Game state error. Please restart the game.", color, {1,0.6,0.2})
    return false, "State error"
  end
  
  local vocation = state.vocations[initiatorColor]
  -- White bypasses vocation checks for testing
  if color ~= "White" and vocation ~= VOC_SOCIAL_WORKER then
    safeBroadcastToColor("Only Social Worker can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = (state.levels and state.levels[initiatorColor]) or 1
  if color ~= "White" and level ~= 1 then
    safeBroadcastToColor("⛔ This action is only available at Social Worker Level 1. Your character is Level " .. tostring(level) .. ".", initiatorColor, {1,0.6,0.2})
    return false
  end

  if not canSpendAP(initiatorColor, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Practical workshop.", initiatorColor, {1,0.6,0.2})
    return false
  end
  if not spendAP(initiatorColor, 2, "SW_L1_PRACTICAL_WORKSHOP") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", initiatorColor, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = initiatorColor, amount = 2 })

  startInteraction({
    id = "SW_L1_PRACTICAL_WORKSHOP",
    initiator = initiatorColor,
    title = "PRACTICAL WORKSHOP",
    subtitle = "Social Worker Level 1 – Cost for you: Spend 2 AP",
    joinCostText = "Others may join by spending 1 AP.",
    effectText = "Each participant gains +1 Knowledge OR +1 Skill (their choice). You gain +1 Satisfaction per participant. If all other players join, you gain +1 additional Satisfaction & +1 Skill.",
    joinCostAP = 1,
  })
  return true
end

-- Social Worker Level 3: Expose a disturbing social case
function VOC_StartSocialWorkerExposeCase(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  local effectsTarget = params.effectsTarget
  local initiatorColor = effectsTarget or color
  if VOC.log then VOC.log("VOC_StartSocialWorkerExposeCase: color="..tostring(color)..", effectsTarget="..tostring(effectsTarget)..", initiatorColor="..tostring(initiatorColor)) end

  local vocation = state.vocations[initiatorColor]
  -- White bypasses vocation checks for testing
  if color ~= "White" and vocation ~= VOC_SOCIAL_WORKER then
    safeBroadcastToColor("Only Social Worker can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[initiatorColor] or 1
  if color ~= "White" and level ~= 3 then
    safeBroadcastToColor("⛔ This action is only available at Social Worker Level 3. Your character is Level " .. tostring(level) .. ".", initiatorColor, {1,0.6,0.2})
    return false
  end

  if not canSpendAP(initiatorColor, 3) then
    safeBroadcastToColor("⛔ Not enough AP (need 3 AP) to expose social case.", initiatorColor, {1,0.6,0.2})
    return false
  end
  if not spendAP(initiatorColor, 3, "SW_L3_EXPOSE_CASE") then
    safeBroadcastToColor("⛔ Failed to deduct 3 AP.", initiatorColor, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = initiatorColor, amount = 3 })

  startInteraction({
    id = "SW_L3_EXPOSE_CASE",
    initiator = initiatorColor,
    title = "EXPOSE DISTURBING SOCIAL CASE",
    subtitle = "Social Worker Level 3 – Cost for you: Spend 3 AP",
    joinCostText = "All other players MUST choose:",
    effectText = "ENGAGE DEEPLY: Gain +1 Knowledge and -2 Satisfaction. OR STAY IGNORANT: Gain +1 Satisfaction. You gain +3 Satisfaction for bringing truth to light.",
    joinCostAP = 0,  -- Mandatory choice, not optional join
  })
  return true
end

-- Social Worker Special: Homeless Shelter Breakthrough
function VOC_StartSocialWorkerHomelessShelter(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  local vocation = state.vocations[color]
  -- White bypasses vocation checks for testing
  if color ~= "White" and vocation ~= VOC_SOCIAL_WORKER then
    safeBroadcastToColor("Only Social Worker can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) for Homeless Shelter.", color, {1,0.6,0.2})
    return false
  end
  
  if not moneySpend(color, 100) then
    safeBroadcastToColor("⛔ Not enough money (need 100 VIN) for Homeless Shelter.", color, {1,0.6,0.2})
    return false
  end
  
  if not spendAP(color, 2, "SW_SPECIAL_HOMELESS") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  -- Roll D6 for outcome
  safeBroadcastAll("🎲 Rolling die for Homeless Shelter...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end
    
    local satGain = 0
    local skillGain = 0
    
    if die <= 2 then
      satGain = -1
      safeBroadcastToColor("Homeless Shelter: Leave before intake finishes → -1 Satisfaction", color, {1,0.7,0.2})
    elseif die <= 4 then
      satGain = 3
      safeBroadcastToColor("Homeless Shelter: Accept temporary shelter → +3 Satisfaction", color, {0.3,1,0.3})
    else
      satGain = 7
      skillGain = 1
      safeBroadcastToColor("Homeless Shelter: Enter long-term support → +7 Satisfaction & +1 Skill", color, {0.3,1,0.3})
    end
    
    satAdd(color, satGain)
    if skillGain > 0 then
      addSkills(color, skillGain)
    end
  end)
  
  return true
end

-- Social Worker Special: Forced Protective Removal
function VOC_StartSocialWorkerRemoval(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  
  -- If White is testing, use effectsTarget for initiator and effects
  local effectsTarget = params.effectsTarget
  local initiatorColor = effectsTarget or color
  
  if VOC.log then VOC.log("VOC_StartSocialWorkerRemoval: color="..tostring(color)..", effectsTarget="..tostring(effectsTarget)..", initiatorColor="..tostring(initiatorColor)) end

  local vocation = state.vocations[initiatorColor]
  -- White bypasses vocation checks for testing
  if color ~= "White" and vocation ~= VOC_SOCIAL_WORKER then
    safeBroadcastToColor("Only Social Worker can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(initiatorColor, 3) then
    safeBroadcastToColor("⛔ Not enough AP (need 3 AP) for Protective Removal.", initiatorColor, {1,0.6,0.2})
    return false
  end
  
  -- Show target selection UI (requires player with at least one child)
  startTargetSelection({
    initiator = initiatorColor,
    actionId = "SW_SPECIAL_REMOVAL",
    title = "SELECT TARGET FOR PROTECTIVE REMOVAL",
    subtitle = "Choose a player who has at least one child:",
    requireChildren = true,
    callback = function(targetColor)
      local V = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
      if V and V.log then V.log("Protective Removal: "..initiatorColor.." selected target: "..targetColor) end
      
      -- Verify target has children
      if not hasChildren(targetColor) then
        safeBroadcastToColor(targetColor.." does not have any children.", initiatorColor, {1,0.6,0.2})
        return
      end
      
      -- Now spend AP and execute action
      if not spendAP(initiatorColor, 3, "SW_SPECIAL_REMOVAL") then
        safeBroadcastToColor("⛔ Failed to deduct 3 AP.", initiatorColor, {1,0.6,0.2})
        return
      end
      VOC_AddWorkAP({ color = initiatorColor, amount = 3 })

      -- Roll D6 for outcome
      safeBroadcastAll("🎲 Rolling die for Protective Removal ("..initiatorColor.." → "..targetColor..")...", {1,1,0.6})
      rollPhysicalDieAndRead(function(die, err)
        local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
        if err then
          if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
          die = math.random(1, 6)
          safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
        else
          safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
        end
        
        if die <= 2 then
          -- False alarm: -1 Health & -2 Satisfaction, victim gains +3 Satisfaction
          addHealth(initiatorColor, -1)
          satAdd(initiatorColor, -2)
          satAdd(targetColor, 3)  -- Victim gains satisfaction
          safeBroadcastAll("Protective Removal: False alarm → "..initiatorColor.." loses -1 Health & -2 Satisfaction. "..targetColor.." gains +3 Satisfaction.", {1,0.7,0.2})
        elseif die <= 4 then
          satAdd(initiatorColor, 3)
          safeBroadcastAll("Protective Removal: Temporary intervention → "..initiatorColor.." gains +3 Satisfaction. "..targetColor.."'s child removed for 1 year.", {0.3,1,0.3})
          -- TODO: Child removal mechanics (remove child token for 1 year)
        else
          satAdd(initiatorColor, 4)
          satAdd(targetColor, -6)  -- Victim loses satisfaction
          safeBroadcastAll("Protective Removal: Permanent removal → "..initiatorColor.." gains +4 Satisfaction. "..targetColor.." loses -6 Satisfaction and child is permanently removed.", {0.3,1,0.3})
          -- TODO: Permanent child removal mechanics (remove child token permanently)
        end
      end)
    end
  })
  
  return true
end

-- =========================================================
-- CELEBRITY ACTIONS
-- =========================================================

function VOC_StartCelebrityStreetPerformance(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  -- When Spectator (White) starts, use current turn player for AP/costs and as initiator
  if color == "White" then color = getActiveTurnColor() or color end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_CELEBRITY then
    safeBroadcastToColor("Only Celebrity can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  if level < 1 then
    safeBroadcastToColor("Live Street Performance requires Celebrity Level 1.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Live Street Performance.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 2, "CELEB_L1_STREET_PERF") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  startInteraction({
    id = "CELEB_L1_STREET_PERF",
    initiator = color,
    title = "LIVE STREET PERFORMANCE STREAM",
    subtitle = "Celebrity Level 1 – Cost for you: Spend 2 AP",
    joinCostText = "Others may join by spending 1 AP.",
    effectText = "Each participant gains +2 Satisfaction. If someone joined, Celebrity gains +1 Skill, +150 VIN, and rolls: 1–3 → +2 SAT, 4–6 → +4 SAT.",
    joinCostAP = 1,
  })
  return true
end

function VOC_StartCelebrityMeetGreet(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  if color == "White" then color = getActiveTurnColor() or color end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_CELEBRITY then
    safeBroadcastToColor("Only Celebrity can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  -- White bypasses level checks for testing
  if color ~= "White" and level < 2 then
    safeBroadcastToColor("Meet & Greet requires Celebrity Level 2.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 1) then
    safeBroadcastToColor("⛔ Not enough AP (need 1 AP) to start Meet & Greet.", color, {1,0.6,0.2})
    return false
  end
  
  if not moneySpend(color, 200) then
    safeBroadcastToColor("⛔ Not enough money (need 200 VIN) for Meet & Greet.", color, {1,0.6,0.2})
    return false
  end
  
  if not spendAP(color, 1, "CELEB_L2_MEET_GREET") then
    safeBroadcastToColor("⛔ Failed to deduct 1 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 1 })

  startInteraction({
    id = "CELEB_L2_MEET_GREET",
    initiator = color,
    title = "MEET & GREET",
    subtitle = "Celebrity Level 2 – Cost for you: Spend 1 AP & 200 VIN",
    joinCostText = "Others may join by spending 1 AP.",
    effectText = "Each participant gains +1 Knowledge & +1 Satisfaction. Celebrity gains +3 or +5 Satisfaction (D6 roll). If no one joins, Celebrity loses 2 or 4 Satisfaction.",
    joinCostAP = 1,
  })
  return true
end

function VOC_StartCelebrityCharityStream(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  if color == "White" then color = getActiveTurnColor() or color end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_CELEBRITY then
    safeBroadcastToColor("Only Celebrity can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  -- White bypasses level checks for testing
  if color ~= "White" and level < 3 then
    safeBroadcastToColor("Extended Charity Stream requires Celebrity Level 3.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Charity Stream.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 2, "CELEB_L3_CHARITY_STREAM") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  startInteraction({
    id = "CELEB_L3_CHARITY_STREAM",
    initiator = color,
    title = "EXTENDED CHARITY STREAM",
    subtitle = "Celebrity Level 3 – Cost for you: Spend 2 AP",
    joinCostText = "Other players may join multiple times by paying 500 VIN each time.",
    effectText = "For each donation: Donor gains +2 Satisfaction. Celebrity gains +2 Satisfaction & +1 AP obligation. Celebrity receives NO money.",
    joinCostAP = 0,  -- Money cost only
  })
  return true
end

function VOC_CelebrityGetAward(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  if color == "White" then color = getActiveTurnColor() or color end

  if color ~= "White" and state.vocations[color] ~= VOC_CELEBRITY then
    safeBroadcastToColor("Only Celebrity can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  if color ~= "White" and level < 3 then
    safeBroadcastToColor("Get an award requires Celebrity Level 3.", color, {1,0.7,0.2})
    return false
  end

  local ap = state.workAPThisLevel and state.workAPThisLevel[color] or 0
  if color ~= "White" and ap < 10 then
    safeBroadcastToColor("⛔ Need 10 AP worked at Level 3 before getting the award. (You have "..tostring(ap).." AP.)", color, {1,0.6,0.2})
    return false
  end

  if state.celebrityAwardReceived and state.celebrityAwardReceived[color] then
    safeBroadcastToColor("You have already received the Celebrity award.", color, {1,0.7,0.2})
    return false
  end

  if not moneySpend(color, 4000) then
    safeBroadcastToColor("⛔ Not enough money (need 4000 VIN) to get the award.", color, {1,0.6,0.2})
    return false
  end

  if not state.celebrityAwardReceived then state.celebrityAwardReceived = {} end
  state.celebrityAwardReceived[color] = true
  safeBroadcastAll(color.." has received the Celebrity award! (4000 VIN paid.)", {0.7, 1, 0.7})
  return true
end

function VOC_StartCelebrityCollaboration(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  if color == "White" then color = getActiveTurnColor() or color end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_CELEBRITY then
    safeBroadcastToColor("Only Celebrity can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 3) then
    safeBroadcastToColor("⛔ Not enough AP (need 3 AP) for Fan Collaboration.", color, {1,0.6,0.2})
    return false
  end
  
  if not moneySpend(color, 200) then
    safeBroadcastToColor("⛔ Not enough money (need 200 VIN) for Fan Collaboration.", color, {1,0.6,0.2})
    return false
  end
  
  if not spendAP(color, 3, "CELEB_SPECIAL_COLLAB") then
    safeBroadcastToColor("⛔ Failed to deduct 3 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 3 })

  satAdd(color, 4)
  addSkills(color, 1)
  
  startInteraction({
    id = "CELEB_SPECIAL_COLLAB",
    initiator = color,
    title = "FAN TALENT COLLABORATION",
    subtitle = "Celebrity Special – Cost for you: Spend 3 AP & 200 VIN",
    joinCostText = "Others may voluntarily spend 2 AP to support.",
    effectText = "You gain +4 Satisfaction & +1 Skill. Each supporter gains +1 Knowledge & +2 Satisfaction. If someone supports, you gain +2 additional Satisfaction.",
    joinCostAP = 2,
  })
  return true
end

function VOC_StartCelebrityMeetup(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  if color == "White" then color = getActiveTurnColor() or color end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_CELEBRITY then
    safeBroadcastToColor("Only Celebrity can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) for Fan Meetup.", color, {1,0.6,0.2})
    return false
  end
  
  if not moneySpend(color, 200) then
    safeBroadcastToColor("⛔ Not enough money (need 200 VIN) for Fan Meetup.", color, {1,0.6,0.2})
    return false
  end
  
  if not spendAP(color, 2, "CELEB_SPECIAL_MEETUP") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  safeBroadcastAll("🎲 Rolling die for Fan Meetup...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end
    
    if die <= 2 then
      addHealth(color, -1)
      satAdd(color, -2)
      safeBroadcastAll("Fan Meetup Backfire: Chaos & backlash → "..color.." loses -1 Health & -2 Satisfaction.", {1,0.7,0.2})
    elseif die <= 4 then
      satAdd(color, 3)
      safeBroadcastAll("Fan Meetup Backfire: Nice but could be better → "..color.." gains +3 Satisfaction.", {0.7,1,0.7})
    else
      satAdd(color, 7)
      moneyAdd(color, 300)
      safeBroadcastAll("Fan Meetup Backfire: Enormous love → "..color.." gains +7 Satisfaction & +300 VIN.", {0.7,1,0.7})
    end
  end)
  
  return true
end

-- =========================================================
-- PUBLIC SERVANT ACTIONS
-- =========================================================

function VOC_StartPublicServantIncomeTax(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- When Spectator (White) clicks, only the current turn player can run this; give satisfaction to current turn.
  local effectiveColor = (color == "White") and getActiveTurnColor() or color
  if color == "White" and (not effectiveColor or not isPlayableColor(effectiveColor)) then
    safeBroadcastToColor("Only the current turn player can run Income Tax Campaign. Set the turn (e.g. to your seat color) first.", "White", {1,0.8,0.3})
    return false
  end
  color = effectiveColor or color

  -- White bypasses vocation checks for testing (when not using effectiveColor)
  if color ~= "White" and state.vocations[color] ~= VOC_PUBLIC_SERVANT then
    safeBroadcastToColor("Only Public Servant can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  if color ~= "White" and level ~= 1 then
    safeBroadcastToColor("⛔ This action is only available at Public Servant Level 1. Your character is Level " .. tostring(level) .. ".", color, {1,0.6,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Income Tax Campaign.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 2, "PS_L1_INCOME_TAX") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  -- Roll D6 immediately (no interaction needed). Use current turn for beneficiary (already in color).
  safeBroadcastAll("🎲 Rolling die for Income Tax Campaign...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end

    -- Beneficiary: same as color (current turn when Spectator clicked)
    local beneficiary = (Turns and Turns.turn_color and Turns.turn_color ~= "") and normalizeColor(Turns.turn_color) or color
    if not beneficiary or not isPlayableColor(beneficiary) then
      beneficiary = color
    end

    if die <= 2 then
      safeBroadcastAll("Income Tax Campaign: Some documents were missing → no taxes collected.", {0.9,0.9,0.9})
    elseif die <= 4 then
      -- Each player pays 15% of cash (Public Servant may waive their own once per level); current turn player gains +1 Satisfaction
      local totalCollected = 0
      for _, c in ipairs(COLORS) do
        if isPlayableColor(c) then
          local currentMoney = getMoney(c)
          local tax = math.floor(currentMoney * 0.15)
          totalCollected = totalCollected + collectTaxWithWaiver(c, tax, beneficiary)
        end
      end
      safeBroadcastAll("Income Tax Campaign: Each player pays 15% of cash. "..beneficiary.." gains +1 Satisfaction.", {0.7,1,0.7})
      satAdd(beneficiary, 1)
    else
      -- Each player pays 30% of cash (Public Servant may waive their own once per level); current turn player gains +3 Satisfaction
      local totalCollected = 0
      for _, c in ipairs(COLORS) do
        if isPlayableColor(c) then
          local currentMoney = getMoney(c)
          local tax = math.floor(currentMoney * 0.30)
          totalCollected = totalCollected + collectTaxWithWaiver(c, tax, beneficiary)
        end
      end
      safeBroadcastAll("Income Tax Campaign: Each player pays 30% of cash. "..beneficiary.." gains +3 Satisfaction.", {0.7,1,0.7})
      satAdd(beneficiary, 3)
    end
  end)

  return true
end

-- Public Servant perk: place Health Monitor Access (tile 657dd1) on player board; same use as shop Health Monitor
function VOC_PlacePublicServantHealthMonitorAccess(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  if color == "White" then
    safeBroadcastToColor("Choose a player color (e.g. from a board) to place Health Monitor Access.", color, {1, 0.8, 0.3})
    return false
  end
  if state.vocations[color] ~= VOC_PUBLIC_SERVANT then
    safeBroadcastToColor("Only Public Servant can use Health Monitor Access.", color, {1, 0.7, 0.2})
    return false
  end
  local shopEngine = nil
  for _, o in ipairs(VOC.getAllObjectsSafe()) do
    if o and o.hasTag and o.hasTag("WLB_SHOP_ENGINE") and o.call then
      shopEngine = o
      break
    end
  end
  if not shopEngine then
    safeBroadcastToColor("Shop Engine not found (tag WLB_SHOP_ENGINE). Cannot place Health Monitor Access.", color, {1, 0.5, 0.2})
    return false
  end
  local ok = pcall(function()
    return shopEngine.call("API_placePublicServantHealthMonitorProxy", { color = color })
  end)
  if ok then
    return true
  end
  return false
end

-- Public Servant Level 2 perk: place Anti-burglary Alarm (tile f9d04d) on player board; same effect as shop ALARM
function VOC_PlacePublicServantAlarmAccess(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  if color == "White" then
    safeBroadcastToColor("Choose a player color (e.g. from a board) to place Anti-burglary Alarm.", color, {1, 0.8, 0.3})
    return false
  end
  if state.vocations[color] ~= VOC_PUBLIC_SERVANT then
    safeBroadcastToColor("Only Public Servant can use Anti-burglary Alarm perk.", color, {1, 0.7, 0.2})
    return false
  end
  local shopEngine = nil
  for _, o in ipairs(VOC.getAllObjectsSafe()) do
    if o and o.hasTag and o.hasTag("WLB_SHOP_ENGINE") and o.call then
      shopEngine = o
      break
    end
  end
  if not shopEngine then
    safeBroadcastToColor("Shop Engine not found (tag WLB_SHOP_ENGINE). Cannot place Anti-burglary Alarm.", color, {1, 0.5, 0.2})
    return false
  end
  local ok, result = pcall(function()
    return shopEngine.call("API_placePublicServantAlarmProxy", { color = color })
  end)
  return (ok and result == true)
end

-- Public Servant Level 3 perk: place New Car (tile 1f3658) on player board; same effect as shop CAR
function VOC_PlacePublicServantCarAccess(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  if color == "White" then
    safeBroadcastToColor("Choose a player color (e.g. from a board) to place New Car.", color, {1, 0.8, 0.3})
    return false
  end
  if state.vocations[color] ~= VOC_PUBLIC_SERVANT then
    safeBroadcastToColor("Only Public Servant can use New Car perk.", color, {1, 0.7, 0.2})
    return false
  end
  local shopEngine = nil
  for _, o in ipairs(VOC.getAllObjectsSafe()) do
    if o and o.hasTag and o.hasTag("WLB_SHOP_ENGINE") and o.call then
      shopEngine = o
      break
    end
  end
  if not shopEngine then
    safeBroadcastToColor("Shop Engine not found (tag WLB_SHOP_ENGINE). Cannot place New Car.", color, {1, 0.5, 0.2})
    return false
  end
  local ok, result = pcall(function()
    return shopEngine.call("API_placePublicServantCarProxy", { color = color })
  end)
  return (ok and result == true)
end

function VOC_StartPublicServantHiTechTax(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_PUBLIC_SERVANT then
    safeBroadcastToColor("Only Public Servant can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  if color ~= "White" and level ~= 2 then
    safeBroadcastToColor("⛔ This action is only available at Public Servant Level 2. Your character is Level " .. tostring(level) .. ".", color, {1,0.6,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Hi-Tech Tax Campaign.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 2, "PS_L2_HITECH_TAX") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  -- Roll D6 immediately
  safeBroadcastAll("🎲 Rolling die for Hi-Tech Tax Campaign...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end
    
    if die <= 2 then
      safeBroadcastAll("Hi-Tech Tax Campaign: Some documents were missing → no taxes collected.", {0.9,0.9,0.9})
    elseif die <= 4 then
      -- Each player pays 200 VIN per High-Tech item; initiator gains +2 Satisfaction
      -- TODO: Count High-Tech items (need to query shop/inventory system)
      for _, c in ipairs(COLORS) do
        if c ~= color and isPlayableColor(c) then
          -- TODO: Replace with actual High-Tech item count when available
          moneySpend(c, 200)
        end
      end
      safeBroadcastAll("Hi-Tech Tax Campaign: Each player pays 200 VIN per High-Tech item. "..color.." gains +2 Satisfaction.", {0.7,1,0.7})
      satAdd(color, 2)
    else
    -- Each player pays 400 VIN per High-Tech item; initiator gains +4 Satisfaction
    -- TODO: Count High-Tech items (need to query shop/inventory system)
    for _, c in ipairs(COLORS) do
      if c ~= color and isPlayableColor(c) then
        -- TODO: Replace with actual High-Tech item count when available
        moneySpend(c, 400)
      end
    end
    safeBroadcastAll("Hi-Tech Tax Campaign: Each player pays 400 VIN per High-Tech item. "..color.." gains +4 Satisfaction.", {0.7,1,0.7})
    satAdd(color, 4)
    end
  end)
  
  return true
end

function VOC_StartPublicServantPropertyTax(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_PUBLIC_SERVANT then
    safeBroadcastToColor("Only Public Servant can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  if color ~= "White" and level ~= 3 then
    safeBroadcastToColor("⛔ This action is only available at Public Servant Level 3. Your character is Level " .. tostring(level) .. ".", color, {1,0.6,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Property Tax Campaign.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 2, "PS_L3_PROPERTY_TAX") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  -- Roll D6 immediately
  safeBroadcastAll("🎲 Rolling die for Property Tax Campaign...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end
    
    if die <= 2 then
      safeBroadcastAll("Property Tax Campaign: Some documents were missing → no taxes collected.", {0.9,0.9,0.9})
    elseif die <= 4 then
      -- Each player pays 200 VIN per property level; initiator gains +3 Satisfaction
      -- TODO: Count property levels (need to query EstateEngine)
      for _, c in ipairs(COLORS) do
        if c ~= color and isPlayableColor(c) then
          -- TODO: Replace with actual property level count when available
          moneySpend(c, 200)
        end
      end
      safeBroadcastAll("Property Tax Campaign: Each player pays 200 VIN per property level. "..color.." gains +3 Satisfaction.", {0.7,1,0.7})
      satAdd(color, 3)
    else
    -- Each player pays 400 VIN per property level; initiator gains +6 Satisfaction
    -- TODO: Count property levels (need to query EstateEngine)
    for _, c in ipairs(COLORS) do
      if c ~= color and isPlayableColor(c) then
        -- TODO: Replace with actual property level count when available
        moneySpend(c, 400)
      end
    end
    safeBroadcastAll("Property Tax Campaign: Each player pays 400 VIN per property level. "..color.." gains +6 Satisfaction.", {0.7,1,0.7})
    satAdd(color, 6)
    end
  end)
  
  return true
end

function VOC_StartPublicServantPolicy(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_PUBLIC_SERVANT then
    safeBroadcastToColor("Only Public Servant can use this action.", color, {1,0.7,0.2})
    return false
  end

  -- Check health (need -1 Health)
  -- Check AP (need 3 AP)
  
  if not canSpendAP(color, 3) then
    safeBroadcastToColor("⛔ Not enough AP (need 3 AP) for Policy Deadline.", color, {1,0.6,0.2})
    return false
  end
  
  addHealth(color, -1)
  
  if not spendAP(color, 3, "PS_SPECIAL_POLICY") then
    safeBroadcastToColor("⛔ Failed to deduct 3 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 3 })

  satAdd(color, 5)
  addKnowledge(color, 1)
  safeBroadcastAll("Policy Drafting Deadline: "..color.." gains +5 Satisfaction & +1 Knowledge.", {0.7,1,0.7})
  
  return true
end

function VOC_StartPublicServantBottleneck(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_PUBLIC_SERVANT then
    safeBroadcastToColor("Only Public Servant can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 3) then
    safeBroadcastToColor("⛔ Not enough AP (need 3 AP) for Bureaucratic Bottleneck.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 3, "PS_SPECIAL_BOTTLENECK") then
    safeBroadcastToColor("⛔ Failed to deduct 3 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 3 })

  safeBroadcastAll("🎲 Rolling die for Bureaucratic Bottleneck...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end
    
    if die <= 2 then
      -- All other players lose 2 AP; initiator loses -2 Satisfaction
      -- TODO: Deduct AP from other players
      satAdd(color, -2)
      safeBroadcastAll("Bureaucratic Bottleneck: System collapsed → All other players lose 2 AP. "..color.." loses -2 Satisfaction.", {1,0.7,0.2})
    elseif die <= 4 then
      safeBroadcastAll("Bureaucratic Bottleneck: Tried a lot but didn't manage to change anything → No effect.", {0.9,0.9,0.9})
    else
      satAdd(color, 7)
      -- All other players gain +2 Satisfaction
      for _, c in ipairs(COLORS) do
        if c ~= color and isPlayableColor(c) then
          satAdd(c, 2)
        end
      end
      safeBroadcastAll("Bureaucratic Bottleneck: Reformed the whole system → "..color.." gains +7 Satisfaction, all other players gain +2 Satisfaction.", {0.7,1,0.7})
    end
  end)
  
  return true
end

-- =========================================================
-- NGO WORKER ACTIONS
-- =========================================================

function VOC_StartNGOCharity(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  if VOC.log then VOC.log("VOC_StartNGOCharity: Called with params="..tostring(params and "table" or "nil")) end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then 
    if VOC.log then VOC.log("VOC_StartNGOCharity: ERROR - No valid color") end
    return false, "Invalid color" 
  end
  local effectsTarget = params.effectsTarget
  local initiatorColor = effectsTarget or color
  if VOC.log then VOC.log("VOC_StartNGOCharity: color="..tostring(color)..", effectsTarget="..tostring(effectsTarget)..", initiatorColor="..tostring(initiatorColor)) end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[initiatorColor] ~= VOC_NGO_WORKER then
    safeBroadcastToColor("Only NGO Worker can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[initiatorColor] or 1
  if color ~= "White" and level < 1 then
    safeBroadcastToColor("Start Charity requires NGO Worker Level 1.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(initiatorColor, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Charity.", initiatorColor, {1,0.6,0.2})
    return false
  end
  if not spendAP(initiatorColor, 2, "NGO_L1_CHARITY") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", initiatorColor, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = initiatorColor, amount = 2 })

  safeBroadcastAll("🎲 Rolling die for Start Charity ("..initiatorColor..")...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end
    
    if die <= 2 then
      safeBroadcastAll("Start Charity: Nothing happens.", {0.9,0.9,0.9})
    elseif die <= 4 then
      addAwardToken(initiatorColor)
      -- Each player pays 200 VIN
      for _, c in ipairs(COLORS) do
        if c ~= initiatorColor and isPlayableColor(c) then
          moneySpend(c, 200)
        end
      end
      safeBroadcastAll("Start Charity: Each player pays 200 VIN.", {0.7,1,0.7})
    else
      addAwardToken(initiatorColor)
      -- Each player pays 400 VIN; initiator gains 400 VIN reward
      for _, c in ipairs(COLORS) do
        if c ~= initiatorColor and isPlayableColor(c) then
          moneySpend(c, 400)
        end
      end
      moneyAdd(initiatorColor, 400)
      safeBroadcastAll("Start Charity: Each player pays 400 VIN. "..initiatorColor.." gains 400 VIN reward.", {0.7,1,0.7})
    end
  end)
  
  return true
end

-- NGO Worker L1: Take Good Karma (free) — find an open Good Karma card in shop (3 consumables) or event lane (7 cards); take it (no cost/AP), get token. Once per level. If no such card on table, action is not used and player is informed.
function VOC_StartNGOTakeGoodKarma(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  local actorColor = params.effectsTarget or color
  if actorColor == "White" then
    safeBroadcastToColor("Invalid player for Take Good Karma.", color or "White", {1,0.6,0.2})
    return false
  end
  if state.vocations[actorColor] ~= VOC_NGO_WORKER then
    safeBroadcastToColor("Only NGO Worker can use Take Good Karma.", actorColor, {1,0.7,0.2})
    return false
  end
  local level = state.levels[actorColor] or 1
  if level < 1 then
    safeBroadcastToColor("NGO Worker Level 1 required for Take Good Karma.", actorColor, {1,0.7,0.2})
    return false
  end
  state.ngoGoodKarmaUsedPerLevel = state.ngoGoodKarmaUsedPerLevel or {}
  if not state.ngoGoodKarmaUsedPerLevel[actorColor] then state.ngoGoodKarmaUsedPerLevel[actorColor] = {} end
  if state.ngoGoodKarmaUsedPerLevel[actorColor][level] then
    safeBroadcastToColor("Take Good Karma (free) can only be used once per level. Already used this level.", actorColor, {1,0.6,0.2})
    return false
  end

  -- 1) Search shop consumables (3 open cards) for a Good Karma card
  local shopList = VOC.getObjectsWithTagSafe("WLB_SHOP_ENGINE") or {}
  local shop = shopList[1]
  if shop and shop.call then
    local okShop, hasShop = pcall(function() return shop.call("API_hasVisibleGoodKarmaCard", {}) end)
    if okShop and hasShop then
      local okTake, taken = pcall(function() return shop.call("API_takeFirstGoodKarmaCardForNGO", { color = actorColor }) end)
      if okTake and taken then
        state.ngoGoodKarmaUsedPerLevel[actorColor][level] = true
        broadcastToAll("✨ " .. actorColor .. " used NGO Take Good Karma (free) — took a Good Karma card from the shop and gained one Good Karma token. (Once per level.)", {1,0.84,0.0})
        return true
      end
    end
  end

  -- 2) Search event lane (7 open cards) for a Good Karma card
  local evtCtrl = VOC.getObjectFromGUID("1339d3")
  if evtCtrl and evtCtrl.call then
    local okEvt, hasEvt = pcall(function() return evtCtrl.call("API_hasVisibleGoodKarmaCard", {}) end)
    if okEvt and hasEvt then
      local okTake, taken = pcall(function() return evtCtrl.call("API_takeFirstGoodKarmaCardFromLane", { color = actorColor }) end)
      if okTake and taken then
        state.ngoGoodKarmaUsedPerLevel[actorColor][level] = true
        broadcastToAll("✨ " .. actorColor .. " used NGO Take Good Karma (free) — took a Good Karma card from the event lane and gained one Good Karma token. (Once per level.)", {1,0.84,0.0})
        return true
      end
    end
  end

  -- No Good Karma card found on the table → do not consume the action
  safeBroadcastToColor("No Good Karma card found on the table. Check the 3 open consumable cards in the shop and the 7 open cards in the event lane. Action not used.", actorColor, {1,0.85,0.3})
  return false
end

-- NGO Worker L2: Take Trip (free) — take one visible Trip card from the shop, no cost/AP, full benefits (rest + die for SAT). Once per level.
function VOC_StartNGOTakeTrip(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  local actorColor = params.effectsTarget or color
  if actorColor == "White" then
    safeBroadcastToColor("Invalid player for Take Trip.", color or "White", {1,0.6,0.2})
    return false
  end
  if state.vocations[actorColor] ~= VOC_NGO_WORKER then
    safeBroadcastToColor("Only NGO Worker can use Take Trip (free).", actorColor, {1,0.7,0.2})
    return false
  end
  local level = state.levels[actorColor] or 1
  if level < 2 then
    safeBroadcastToColor("NGO Worker Level 2 required for Take Trip (free).", actorColor, {1,0.7,0.2})
    return false
  end
  state.ngoTakeTripUsedPerLevel = state.ngoTakeTripUsedPerLevel or {}
  if not state.ngoTakeTripUsedPerLevel[actorColor] then state.ngoTakeTripUsedPerLevel[actorColor] = {} end
  if state.ngoTakeTripUsedPerLevel[actorColor][level] then
    safeBroadcastToColor("Take Trip (free) can only be used once per level. Already used this level.", actorColor, {1,0.6,0.2})
    return false
  end
  local shopList = VOC.getObjectsWithTagSafe("WLB_SHOP_ENGINE") or {}
  local shop = shopList[1]
  if not shop or not shop.call then
    safeBroadcastToColor("Shop Engine not found. Cannot take Trip.", actorColor, {1,0.6,0.2})
    return false
  end
  -- Show "Take this Trip (free)" on each visible Trip card; perk is marked used when they pick one (Shop calls VOC_MarkNGOTakeTripUsed)
  local ok, result = pcall(function() return shop.call("API_showNGOTakeTripChoice", { color = actorColor }) end)
  if not ok or not result then
    safeBroadcastToColor("No Trip card visible in the shop consumable row. Put a Trip card (e.g. Nature Trip) in an open slot and try again.", actorColor, {1,0.6,0.2})
    return false
  end
  broadcastToAll("🌿 " .. actorColor .. " — Choose one Trip card in the shop (click \"Take this Trip (free)\" on the card you want).", {0.6,1,0.7})
  return true
end

-- Called by ShopEngine when player picks a Trip card for NGO Take Trip (free); marks perk as used for current level.
function VOC_MarkNGOTakeTripUsed(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color))
  if not color then return end
  local level = state.levels[color] or 1
  state.ngoTakeTripUsedPerLevel = state.ngoTakeTripUsedPerLevel or {}
  if not state.ngoTakeTripUsedPerLevel[color] then state.ngoTakeTripUsedPerLevel[color] = {} end
  state.ngoTakeTripUsedPerLevel[color][level] = true
end

-- NGO Worker L3: Use Investment (free, up to 1000 VIN) — activate perk; then when player clicks an Investment in the shop, first 1000 VIN is free. Once per level.
function VOC_StartNGOUseInvestment(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  local actorColor = params.effectsTarget or color
  if actorColor == "White" then
    safeBroadcastToColor("Invalid player for Use Investment.", color or "White", {1,0.6,0.2})
    return false
  end
  if state.vocations[actorColor] ~= VOC_NGO_WORKER then
    safeBroadcastToColor("Only NGO Worker can use Use Investment (free, up to 1000 VIN).", actorColor, {1,0.7,0.2})
    return false
  end
  local level = state.levels[actorColor] or 1
  if level < 3 then
    safeBroadcastToColor("NGO Worker Level 3 required for Use Investment (free).", actorColor, {1,0.7,0.2})
    return false
  end
  state.ngoUseInvestmentUsedPerLevel = state.ngoUseInvestmentUsedPerLevel or {}
  if not state.ngoUseInvestmentUsedPerLevel[actorColor] then state.ngoUseInvestmentUsedPerLevel[actorColor] = {} end
  if state.ngoUseInvestmentUsedPerLevel[actorColor][level] then
    safeBroadcastToColor("Use Investment (free, up to 1000 VIN) can only be used once per level. Already used this level.", actorColor, {1,0.6,0.2})
    return false
  end
  state.ngoInvestmentSubsidyActive = state.ngoInvestmentSubsidyActive or {}
  state.ngoInvestmentSubsidyActive[actorColor] = 1000  -- Amount in VIN; level stored for consume
  broadcastToAll("💰 " .. actorColor .. " activated NGO Use Investment (free, up to 1000 VIN). Click an Investment card in the shop to use it; first 1000 VIN free. (Once per level.)", {0.8,0.9,1})
  return true
end

-- Called by ShopEngine when processing an Investment purchase: return subsidy amount (1000) if NGO perk is active for this color.
function VOC_GetNGOInvestmentSubsidy(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return 0 end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color))
  if not color then return 0 end
  state.ngoInvestmentSubsidyActive = state.ngoInvestmentSubsidyActive or {}
  local amount = state.ngoInvestmentSubsidyActive[color]
  amount = tonumber(amount)
  if amount and amount > 0 then return amount end
  return 0
end

-- Called by ShopEngine after applying NGO investment subsidy for this color; marks perk as used for current level.
function VOC_ConsumeNGOInvestmentPerk(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color))
  if not color then return end
  local level = state.levels[color] or 1
  state.ngoInvestmentSubsidyActive = state.ngoInvestmentSubsidyActive or {}
  state.ngoInvestmentSubsidyActive[color] = nil
  state.ngoUseInvestmentUsedPerLevel = state.ngoUseInvestmentUsedPerLevel or {}
  if not state.ngoUseInvestmentUsedPerLevel[color] then state.ngoUseInvestmentUsedPerLevel[color] = {} end
  state.ngoUseInvestmentUsedPerLevel[color][level] = true
end

function VOC_StartNGOCrowdfunding(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  -- When White triggers (testing), use effectsTarget as the actual actor for AP and messages
  local actorColor = params.effectsTarget or color

  -- White bypasses vocation checks for testing
  if actorColor ~= "White" and state.vocations[actorColor] ~= VOC_NGO_WORKER then
    safeBroadcastToColor("Only NGO Worker can use this action.", actorColor, {1,0.7,0.2})
    return false
  end

  local level = state.levels[actorColor] or 1
  -- White bypasses level checks for testing
  if actorColor ~= "White" and level < 2 then
    safeBroadcastToColor("Crowdfunding Campaign requires NGO Worker Level 2.", actorColor, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(actorColor, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Crowdfunding.", actorColor, {1,0.6,0.2})
    return false
  end
  if not spendAP(actorColor, 2, "NGO_L2_CROWDFUND") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", actorColor, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = actorColor, amount = 2 })

  safeBroadcastAll("🎲 Rolling die for Crowdfunding Campaign...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end

    if die <= 2 then
      safeBroadcastAll("Crowdfunding Campaign: Nothing happens.", {0.9,0.9,0.9})
    elseif die <= 4 then
      addAwardToken(actorColor)
      local totalRaised = 0
      for _, c in ipairs(COLORS) do
        if c ~= actorColor and isPlayableColor(c) then
          local before = getMoney(c) or 0
          if moneySpend(c, 250) then
            local after = getMoney(c) or 0
            totalRaised = totalRaised + (before - after)
          end
        end
      end
      -- Store pool for this player; valid only this turn. When they buy a High-Tech item, pool is applied (excess lost; if cost > pool they pay difference).
      state.crowdfundPool = state.crowdfundPool or {}
      state.crowdfundPoolTurnColor = state.crowdfundPoolTurnColor or {}
      local currentTurn = (Turns and Turns.turn_color and Turns.turn_color ~= "") and normalizeColor(Turns.turn_color) or actorColor
      state.crowdfundPool[actorColor] = totalRaised
      state.crowdfundPoolTurnColor[actorColor] = currentTurn
      if totalRaised > 0 then
        moneyAdd(actorColor, totalRaised)
        broadcastToAll("💰 Crowdfunding: Money raised for " .. actorColor .. ": " .. totalRaised .. " VIN. Use it this turn on a High-Tech purchase (excess lost; if item costs more, you pay the difference).", {0.7,1,0.7})
      else
        safeBroadcastAll("Crowdfunding Campaign: Each player pays up to 250 VIN to "..actorColor.." (only if they have it). Total raised: 0 VIN.", {0.7,1,0.7})
      end
    else
      addAwardToken(actorColor)
      local totalRaised = 0
      for _, c in ipairs(COLORS) do
        if c ~= actorColor and isPlayableColor(c) then
          local before = getMoney(c) or 0
          if moneySpend(c, 400) then
            local after = getMoney(c) or 0
            totalRaised = totalRaised + (before - after)
          end
        end
      end
      -- Store pool for this player; valid only this turn. When they buy a High-Tech item, pool is applied (excess lost; if cost > pool they pay difference).
      state.crowdfundPool = state.crowdfundPool or {}
      state.crowdfundPoolTurnColor = state.crowdfundPoolTurnColor or {}
      local currentTurn = (Turns and Turns.turn_color and Turns.turn_color ~= "") and normalizeColor(Turns.turn_color) or actorColor
      state.crowdfundPool[actorColor] = totalRaised
      state.crowdfundPoolTurnColor[actorColor] = currentTurn
      if totalRaised > 0 then
        moneyAdd(actorColor, totalRaised)
      end
      broadcastToAll("💰 Crowdfunding: Money raised for " .. actorColor .. ": " .. totalRaised .. " VIN. Use it this turn on a High-Tech purchase (excess lost; if item costs more, you pay the difference).", {0.7,1,0.7})
    end
  end)

  return true
end

-- Called by ShopEngine when a player buys a High-Tech item. If this player has an active crowdfund pool (same turn), apply it: pool covers up to cost; excess lost; if cost > pool, return amount player must pay. Only valid the turn after using Crowdfunding.
function VOC_ApplyCrowdfundPoolForPurchase(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return { amountFromPool = 0, playerPays = 0 } end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color))
  local cost = tonumber(params.cost) or 0
  if not color or cost < 0 then
    return { amountFromPool = 0, playerPays = cost }
  end
  state.crowdfundPool = state.crowdfundPool or {}
  state.crowdfundPoolTurnColor = state.crowdfundPoolTurnColor or {}
  local currentTurn = (Turns and Turns.turn_color and Turns.turn_color ~= "") and normalizeColor(Turns.turn_color) or nil
  if not currentTurn or state.crowdfundPoolTurnColor[color] ~= currentTurn then
    return { amountFromPool = 0, playerPays = cost }
  end
  local pool = tonumber(state.crowdfundPool[color]) or 0
  if pool <= 0 then
    return { amountFromPool = 0, playerPays = cost }
  end
  local amountFromPool = math.min(pool, cost)
  local playerPays = math.max(0, cost - pool)
  state.crowdfundPool[color] = nil
  state.crowdfundPoolTurnColor[color] = nil
  if amountFromPool > 0 then
    local msg = "💰 Crowdfunding pool applied for " .. color .. ": " .. amountFromPool .. " VIN from pool."
    if playerPays > 0 then
      msg = msg .. " " .. playerPays .. " VIN from own money."
    else
      msg = msg .. " (Full cost covered by pool.)"
    end
    broadcastToAll(msg, {0.7,1,0.7})
  end
  return { amountFromPool = amountFromPool, playerPays = playerPays }
end

-- Record Celebrity event card play (for event card obligation tracking)
function VOC_RecordCelebrityEventCardPlay(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then
    return false
  end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color))
  if not color or color == "White" then
    return false
  end
  
  local vocation = state.vocations[color]
  if vocation ~= VOC_CELEBRITY then
    return false
  end
  
  state.celebrityEventsThisTurn = state.celebrityEventsThisTurn or { Yellow=0, Blue=0, Red=0, Green=0 }
  local oldCount = tonumber(state.celebrityEventsThisTurn[color]) or 0
  state.celebrityEventsThisTurn[color] = oldCount + 1
  
  return true
end

-- Record Celebrity hi-tech purchase for cashback refund next round
-- Params: { color = player color, pricePaid = actual price paid (after discounts), cardName = card name }
function VOC_RecordCelebrityHiTechPurchase(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color))
  if not color then return false end
  
  local vocation = state.vocations[color]
  if vocation ~= VOC_CELEBRITY then return false end
  
  local level = state.levels[color] or 1
  local pricePaid = tonumber(params.pricePaid) or 0
  if pricePaid <= 0 then return false end
  
  -- Calculate refund percentage based on level at purchase time
  local refundPercent = 0
  if level == 1 then
    refundPercent = 0.30  -- 30%
  elseif level == 2 then
    refundPercent = 0.50  -- 50%
  elseif level == 3 then
    refundPercent = 0.70  -- 70%
  else
    return false  -- Invalid level
  end
  
  local refundAmount = math.floor(pricePaid * refundPercent)
  if refundAmount <= 0 then return false end
  
  -- Get current round and set refund for next round
  local currentRound = getCurrentRound() or 1
  local refundRound = currentRound + 1
  
  -- Store pending refund
  state.celebrityCashbackRefunds = state.celebrityCashbackRefunds or {}
  if not state.celebrityCashbackRefunds[color] then
    state.celebrityCashbackRefunds[color] = {}
  end
  
  table.insert(state.celebrityCashbackRefunds[color], {
    amount = refundAmount,
    roundDue = refundRound,
    levelAtPurchase = level,
    cardName = params.cardName or "hi-tech item"
  })
  
  if VOC.log then
    VOC.log("VOC_RecordCelebrityHiTechPurchase: " .. color .. " (L" .. level .. ") bought hi-tech for " .. pricePaid .. " VIN → " .. refundAmount .. " VIN refund due round " .. refundRound)
  end
  
  return true
end

-- Check if player has an active crowdfund pool (must buy hi-tech before ending turn)
function VOC_HasActiveCrowdfundPool(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color))
  if not color then return false end
  
  state.crowdfundPool = state.crowdfundPool or {}
  state.crowdfundPoolTurnColor = state.crowdfundPoolTurnColor or {}
  local currentTurn = (Turns and Turns.turn_color and Turns.turn_color ~= "") and normalizeColor(Turns.turn_color) or color
  
  local pool = tonumber(state.crowdfundPool[color]) or 0
  local poolTurn = state.crowdfundPoolTurnColor[color]
  
  -- Pool is active if it exists, has value > 0, and is for current turn
  return (pool > 0 and poolTurn == currentTurn)
end

function VOC_StartNGOVoluntaryWork(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  local actorColor = params.effectsTarget or color

  if actorColor ~= "White" and state.vocations[actorColor] ~= VOC_NGO_WORKER then
    safeBroadcastToColor("Only NGO Worker can use Voluntary Work.", actorColor, {1,0.7,0.2})
    return false
  end

  local level = state.levels[actorColor] or 1
  local apCost, satGain
  if level == 1 then
    apCost, satGain = 2, 1
  elseif level == 2 then
    apCost, satGain = 3, 2
  else
    apCost, satGain = 1, 1  -- level 3
  end

  if not canSpendAP(actorColor, apCost) then
    safeBroadcastToColor("⛔ Not enough AP (need "..tostring(apCost).." AP) for Voluntary Work.", actorColor, {1,0.6,0.2})
    return false
  end
  if not spendAP(actorColor, apCost, "NGO_VOLUNTARY_WORK") then
    safeBroadcastToColor("⛔ Failed to deduct AP.", actorColor, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = actorColor, amount = apCost })

  satAdd(actorColor, satGain)
  state.voluntaryWorkAP[actorColor] = (state.voluntaryWorkAP[actorColor] or 0) + apCost
  safeBroadcastAll("Voluntary Work: "..actorColor.." spent "..tostring(apCost).." AP and gained +"..tostring(satGain).." Satisfaction.", {0.7,1,0.7})
  return true
end

function VOC_StartNGOAdvocacy(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  -- When White triggers (testing), use effectsTarget as the actual actor for AP and initiator (so initiator does not appear in join UI)
  local actorColor = params.effectsTarget or color

  -- White bypasses vocation checks for testing
  if actorColor ~= "White" and state.vocations[actorColor] ~= VOC_NGO_WORKER then
    safeBroadcastToColor("Only NGO Worker can use this action.", actorColor, {1,0.7,0.2})
    return false
  end

  local level = state.levels[actorColor] or 1
  -- White bypasses level checks for testing
  if actorColor ~= "White" and level < 3 then
    safeBroadcastToColor("Advocacy Pressure Campaign requires NGO Worker Level 3.", actorColor, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(actorColor, 3) then
    safeBroadcastToColor("⛔ Not enough AP (need 3 AP) to start Advocacy Campaign.", actorColor, {1,0.6,0.2})
    return false
  end
  if not spendAP(actorColor, 3, "NGO_L3_ADVOCACY") then
    safeBroadcastToColor("⛔ Failed to deduct 3 AP.", actorColor, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = actorColor, amount = 3 })

  -- initiator = actorColor so the player who used the action is excluded from the join UI (targets exclude initiator)
  startInteraction({
    id = "NGO_L3_ADVOCACY",
    initiator = actorColor,
    title = "ADVOCACY PRESSURE CAMPAIGN",
    subtitle = "NGO Worker Level 3 – Cost for you: Spend 3 AP",
    joinCostText = "Other players choose YES or NO:",
    effectText = "YES: Pay 300 VIN and gain +2 Satisfaction. NO: Lose -1 Satisfaction. You gain +1 Satisfaction per participant. You gain +1 Skill only when everybody chooses NO.",
    joinCostAP = 0,  -- Money cost only for YES
  })
  return true
end

function VOC_StartNGOCrisis(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_NGO_WORKER then
    safeBroadcastToColor("Only NGO Worker can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 1) then
    safeBroadcastToColor("⛔ Not enough AP (need 1 AP) for Crisis Appeal.", color, {1,0.6,0.2})
    return false
  end
  
  if not moneySpend(color, 200) then
    safeBroadcastToColor("⛔ Not enough money (need 200 VIN) for Crisis Appeal.", color, {1,0.6,0.2})
    return false
  end
  
  if not spendAP(color, 1, "NGO_SPECIAL_CRISIS") then
    safeBroadcastToColor("⛔ Failed to deduct 1 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 1 })

  startInteraction({
    id = "NGO_SPECIAL_CRISIS",
    initiator = color,
    title = "INTERNATIONAL CRISIS APPEAL",
    subtitle = "NGO Worker Special – Cost for you: Spend 1 AP & 200 VIN",
    joinCostText = "Each other player chooses:",
    effectText = "JOIN: Donate 200 VIN and gain +2 Satisfaction. OR IGNORE. You gain +2 Satisfaction for each joiner and +1 Satisfaction per refuser.",
    joinCostAP = 0,  -- Money cost only
  })
  return true
end

function VOC_StartNGOScandal(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_NGO_WORKER then
    safeBroadcastToColor("Only NGO Worker can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) for Donation Scandal.", color, {1,0.6,0.2})
    return false
  end
  
  if not moneySpend(color, 300) then
    safeBroadcastToColor("⛔ Not enough money (need 300 VIN) for Donation Scandal.", color, {1,0.6,0.2})
    return false
  end
  
  if not spendAP(color, 2, "NGO_SPECIAL_SCANDAL") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  safeBroadcastAll("🎲 Rolling die for Donation Scandal...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end
    
    if die <= 2 then
      satAdd(color, -3)
      safeBroadcastAll("Donation Scandal: Donor accuses you publicly → "..color.." loses -3 Satisfaction.", {1,0.7,0.2})
    elseif die <= 4 then
      satAdd(color, 4)
      safeBroadcastAll("Donation Scandal: Issue resolved quietly → "..color.." gains +4 Satisfaction.", {0.7,1,0.7})
    else
      satAdd(color, 6)
      addKnowledge(color, 1)
      safeBroadcastAll("Donation Scandal: Donor apologizes publicly → "..color.." gains +6 Satisfaction & +1 Knowledge.", {0.7,1,0.7})
    end
  end)
  
  return true
end

-- =========================================================
-- ENTREPRENEUR ACTIONS
-- =========================================================

function VOC_StartEntrepreneurFlashSale(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  -- When White (spectator) triggers the action, use active turn player as the Entrepreneur/initiator
  if color == "White" then color = getActiveTurnColor() or color end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_ENTREPRENEUR then
    safeBroadcastToColor("Only Entrepreneur can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  if level < 1 then
    safeBroadcastToColor("Flash Sale Promotion requires Entrepreneur Level 1.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 1) then
    safeBroadcastToColor("⛔ Not enough AP (need 1 AP) to start Flash Sale.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 1, "ENT_L1_FLASH_SALE") then
    safeBroadcastToColor("⛔ Failed to deduct 1 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 1 })

  -- Get turn order from TurnController (Entrepreneur buys first, then others in order)
  local turnOrder = {}
  local turnCtrl = findTurnController()
  if turnCtrl and turnCtrl.call then
    local ok, result = pcall(function() return turnCtrl.call("API_GetTurnOrder", {}) end)
    if ok and type(result) == "table" and #result > 0 then turnOrder = result end
  end
  if #turnOrder == 0 then
    safeBroadcastAll("⚠️ Flash Sale: could not get turn order. Start the game first.", {1,0.7,0.2})
    return true  -- AP already spent
  end
  
  -- Reorder: Entrepreneur always goes first, then others follow turn order
  local reorderedTurnOrder = {}
  
  -- Add Entrepreneur first
  table.insert(reorderedTurnOrder, color)
  
  -- Add other players in their original turn order (skip Entrepreneur if they were in the list)
  for _, c in ipairs(turnOrder) do
    local normalizedC = (VOC.normalizeColor and VOC.normalizeColor(c)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(c)) or c
    if normalizedC ~= color then
      table.insert(reorderedTurnOrder, normalizedC)
    end
  end
  
  turnOrder = reorderedTurnOrder

  local shopList = VOC.getObjectsWithTagSafe("WLB_SHOP_ENGINE") or {}
  local shop = shopList[1]
  if not shop or not shop.call then
    safeBroadcastAll("⚠️ Shop Engine not found. Flash Sale not started.", {1,0.6,0.2})
    return true
  end
  local ok = pcall(function() return shop.call("API_StartFlashSale", { initiatorColor = color, turnOrder = turnOrder }) end)
  if not ok then
    safeBroadcastAll("⚠️ Flash Sale: ShopEngine API_StartFlashSale failed.", {1,0.7,0.2})
  end
  return true
end

-- Entrepreneur L1: Spend 1 AP to "talk to shop owner" – other players pay double for consumables & hi-tech until this player's next turn
function VOC_StartEntrepreneurTalkToShopOwner(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  if color == "White" then color = getActiveTurnColor() or color end

  if color ~= "White" and state.vocations[color] ~= VOC_ENTREPRENEUR then
    safeBroadcastToColor("Only Entrepreneur can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  if level < 1 then
    safeBroadcastToColor("Talk to shop owner requires Entrepreneur Level 1.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 1) then
    safeBroadcastToColor("⛔ Not enough AP (need 1 AP) to talk to shop owner.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 1, "ENT_L1_TALK_TO_SHOP_OWNER") then
    safeBroadcastToColor("⛔ Failed to deduct 1 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 1 })

  local shopList = VOC.getObjectsWithTagSafe("WLB_SHOP_ENGINE") or {}
  local shop = shopList[1]
  if not shop or not shop.call then
    safeBroadcastToColor("Shop Engine not found. Double prices not applied.", color, {1,0.6,0.2})
    return true  -- AP already spent
  end
  local ok = pcall(function() return shop.call("SetDoublePrices", { initiatorColor = color }) end)
  if not ok then
    safeBroadcastAll("⚠️ Talk to shop owner: ShopEngine SetDoublePrices failed.", {1,0.7,0.2})
  end
  return true
end

function VOC_StartEntrepreneurTraining(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_ENTREPRENEUR then
    safeBroadcastToColor("Only Entrepreneur can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  -- White bypasses level checks for testing
  if color ~= "White" and level < 2 then
    safeBroadcastToColor("Commercial Training Course requires Entrepreneur Level 2.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to start Training Course.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 2, "ENT_L2_TRAINING") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  startInteraction({
    id = "ENT_L2_TRAINING",
    initiator = color,
    title = "COMMERCIAL TRAINING COURSE",
    subtitle = "Entrepreneur Level 2 – Cost for you: Spend 2 AP",
    joinCostText = "Others may pay 200 VIN to participate.",
    effectText = "Each participant may improve Knowledge or Skills. Exam time! D6: 1=Failed, 2-5=Passed (+1 K/S), 6=Genius (+2 K/S). You gain +1 Satisfaction per participant.",
    joinCostAP = 0,  -- Money cost only
  })
  return true
end

function VOC_StartEntrepreneurExpansion(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_ENTREPRENEUR then
    safeBroadcastToColor("Only Entrepreneur can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) for Aggressive Expansion.", color, {1,0.6,0.2})
    return false
  end
  
  if not moneySpend(color, 300) then
    safeBroadcastToColor("⛔ Not enough money (need 300 VIN) for Aggressive Expansion.", color, {1,0.6,0.2})
    return false
  end
  
  if not spendAP(color, 2, "ENT_SPECIAL_EXPANSION") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  safeBroadcastAll("🎲 Rolling die for Aggressive Expansion...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
    if err then
      if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
    end
    
    if die <= 2 then
      satAdd(color, -2)
      moneySpend(color, 200)
      safeBroadcastAll("Aggressive Expansion: Collapse → "..color.." loses -2 Satisfaction & -200 VIN.", {1,0.7,0.2})
    elseif die <= 4 then
      satAdd(color, 3)
      safeBroadcastAll("Aggressive Expansion: Moderate growth → "..color.." gains +3 Satisfaction.", {0.7,1,0.7})
    else
      satAdd(color, 6)
      moneyAdd(color, 800)
      safeBroadcastAll("Aggressive Expansion: Massive success → "..color.." gains +6 Satisfaction & +800 VIN.", {0.7,1,0.7})
    end
  end)
  
  return true
end

function VOC_StartEntrepreneurEmployeeTraining(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[color] ~= VOC_ENTREPRENEUR then
    safeBroadcastToColor("Only Entrepreneur can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) for Employee Training.", color, {1,0.6,0.2})
    return false
  end
  
  if not moneySpend(color, 500) then
    safeBroadcastToColor("⛔ Not enough money (need 500 VIN) for Employee Training.", color, {1,0.6,0.2})
    return false
  end
  
  if not spendAP(color, 2, "ENT_SPECIAL_TRAINING") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  if not moneySpend(color, 500) then
    safeBroadcastToColor("⛔ Not enough money (need 500 VIN) for Employee Training.", color, {1,0.6,0.2})
    return false
  end
  satAdd(color, 2)
  addSkills(color, 2)
  safeBroadcastAll("Employee Training: "..color.." gains +2 Satisfaction & +2 Skills.", {0.7,1,0.7})
  
  return true
end

-- Entrepreneur L3: Reposition event cards. Spend 2 AP; EventsController shows MOVE on slots 1-7, player picks 3 then assigns to slots.
function VOC_StartEntrepreneurReposition(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end

  if color ~= "White" and state.vocations[color] ~= VOC_ENTREPRENEUR then
    safeBroadcastToColor("Only Entrepreneur can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = state.levels[color] or 1
  if color ~= "White" and level < 3 then
    safeBroadcastToColor("Reposition event cards requires Entrepreneur Level 3.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("Not enough AP (need 2) for Reposition event cards.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 2, "ENT_L3_REPOSITION_EVENTS") then
    safeBroadcastToColor("Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  local evtCtrl = VOC.getObjectFromGUID("1339d3")
  if not evtCtrl or not evtCtrl.call then
    safeBroadcastAll("Events Controller not found. Reposition not started.", {1,0.6,0.2})
    return true
  end
  pcall(function() evtCtrl.call("API_StartEntrepreneurReposition", {}) end)
  return true
end

-- =========================================================
-- GANGSTER ACTIONS
-- =========================================================

-- Gangster: Extra satisfaction die (all 6 crime actions). After any successful crime, gangster rolls ONE extra die; result = +Satisfaction. Physical roll, result shown on screen.
local function AddGangsterSatFromCrimeDie(color, onDone)
  color = normalizeColor(color)
  if not color or color == "White" then
    if onDone then onDone() end
    return
  end
  onDone = onDone or function() end
  safeBroadcastAll("🎲 Roll the die for Gangster satisfaction (successful crime) – result = +Satisfaction for "..tostring(color), {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    if err or not die then
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..tostring(die), {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..tostring(die), {0.8,0.9,1})
    end
    die = math.max(1, math.min(6, tonumber(die) or 1))
    satAdd(color, die)
    safeBroadcastAll("✅ "..tostring(color).." gains +"..tostring(die).." Satisfaction (crime bonus die).", {0.7,1,0.7})
    onDone()
  end)
end

-- Gangster: Victim sorrow roll (crime against player only). After successful crime (victim wounded or money stolen), victim rolls die: 1-3 → -3 SAT, 4-6 → -5 SAT.
local function AddVictimSorrowRoll(targetColor, onDone)
  targetColor = normalizeColor(targetColor)
  if not targetColor or targetColor == "White" then
    if onDone then onDone() end
    return
  end
  onDone = onDone or function() end
  rollPhysicalDieAndRead(function(die, err)
    if err or not die then
      die = math.random(1, 6)
    end
    die = math.max(1, math.min(6, tonumber(die) or 1))
    local satLoss = (die <= 3) and 3 or 5
    satAdd(targetColor, -satLoss)
    safeBroadcastAll("💔 "..tostring(targetColor).." loses "..tostring(satLoss).." Satisfaction (victim sorrow: roll "..tostring(die)..").", {1,0.5,0.5})
    onDone()
  end)
end

-- Gangster L1: Steal hi-tech from shop. Cost 3 AP; choose one open H card (STEAL button); roll die: 1-2 fail, 3-4 success + investigation, 5-6 success + heat only.
function VOC_StartGangsterStealHitech(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  -- When White (host/spectator) triggers, use effectsTarget or active turn as the actual gangster
  if color == "White" then
    color = normalizeColor(params.effectsTarget) or getActiveTurnColor()
  end
  if not color then return false, "Invalid color" end
  if color ~= "White" and state.vocations[color] ~= VOC_GANGSTER then
    safeBroadcastToColor("Only Gangster can use this action.", color, {1,0.7,0.2})
    return false
  end
  local level = state.levels[color] or 1
  if color ~= "White" and level < 1 then
    safeBroadcastToColor("Steal hi-tech from shop requires Gangster Level 1.", color, {1,0.6,0.2})
    return false
  end
  if not canSpendAP(color, 3) then
    safeBroadcastToColor("Not enough AP (need 3) for Steal hi-tech from shop.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 3, "GANG_L1_STEAL_HITECH_SHOP") then
    safeBroadcastToColor("Failed to deduct 3 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 3 })

  local shop = nil
  for _, o in ipairs(VOC.getAllObjectsSafe()) do
    if o and o.hasTag and o.hasTag("WLB_SHOP_ENGINE") and o.call then shop = o break end
  end
  if not shop or not shop.call then
    safeBroadcastAll("Shop not found. Steal hi-tech aborted.", {1,0.6,0.2})
    return true
  end
  local ok = pcall(function() return shop.call("API_StartGangsterStealHitech", { color = color }) end)
  if not ok then
    safeBroadcastAll("Failed to start Gangster steal hi-tech on shop.", {1,0.6,0.2})
  end
  return true
end

-- Gangster L2: False money production. Cost 3 AP; roll die: 1-2 fail, 3-4 success +1000 VIN, 5-6 great success +2000 VIN. Success (3-6) = crime → investigation + heat.
function VOC_StartGangsterFalseMoney(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  -- When White (host/spectator) triggers, use effectsTarget or active turn as the actual gangster
  if color == "White" then
    color = normalizeColor(params.effectsTarget) or getActiveTurnColor()
  end
  if not color then return false, "Invalid color" end
  if color ~= "White" and state.vocations[color] ~= VOC_GANGSTER then
    safeBroadcastToColor("Only Gangster can use this action.", color, {1,0.7,0.2})
    return false
  end
  local level = state.levels[color] or 1
  if color ~= "White" and level < 2 then
    safeBroadcastToColor("False money production requires Gangster Level 2.", color, {1,0.6,0.2})
    return false
  end
  if not canSpendAP(color, 3) then
    safeBroadcastToColor("Not enough AP (need 3) for False money production.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 3, "GANG_L2_FALSE_MONEY") then
    safeBroadcastToColor("Failed to deduct 3 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 3 })

  safeBroadcastAll("🎲 Rolling die for False money production ("..tostring(color)..")...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    if err then
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..tostring(die), {0.8,0.9,1})
    end
    if die <= 2 then
      safeBroadcastAll("False money production: Failed (1-2). Nothing happens.", {0.9,0.9,0.9})
      return
    end
    local gains = (die <= 4) and 1000 or 2000
    moneyAdd(color, gains)
    safeBroadcastAll("False money production: " .. (die <= 4 and "Success (3-4)" or "Great success (5-6)") .. " → " .. tostring(color) .. " gains " .. tostring(gains) .. " VIN. Crime → investigation.", {0.7,1,0.7})
    AddGangsterSatFromCrimeDie(color, function()
      RunCrimeInvestigation({
        initiatorColor = color,
        vocationLevel = 2,
        crimeGainsVIN = gains,
      })
    end)
  end)
  return true
end

-- Gangster L3: Enforce citywide lockdown. Cost 2 AP. All opponents start their next turn with 1 AP less (moved to inactive). Gangster rolls die: 1-2 +200 VIN, 3-4 +500 VIN, 5-6 +1000 VIN and +2 SAT. Crime → investigation + heat.
function VOC_StartGangsterLockdown(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  -- When White (host/spectator) triggers, use effectsTarget or active turn as the actual gangster
  if color == "White" then
    color = normalizeColor(params.effectsTarget) or getActiveTurnColor()
  end
  if not color then return false, "Invalid color" end
  if color ~= "White" and state.vocations[color] ~= VOC_GANGSTER then
    safeBroadcastToColor("Only Gangster can use this action.", color, {1,0.7,0.2})
    return false
  end
  local level = state.levels[color] or 1
  if color ~= "White" and level < 3 then
    safeBroadcastToColor("Enforce citywide lockdown requires Gangster Level 3.", color, {1,0.6,0.2})
    return false
  end
  if not canSpendAP(color, 2) then
    safeBroadcastToColor("Not enough AP (need 2) for Enforce citywide lockdown.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 2, "GANG_L3_LOCKDOWN") then
    safeBroadcastToColor("Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  -- All opponents will lose 1 AP at start of their next turn
  state.lockdownPending = state.lockdownPending or {}
  for _, c in ipairs(COLORS) do
    if c ~= color and c ~= "White" then
      state.lockdownPending[c] = true
    end
  end
  saveState()
  safeBroadcastAll("🔒 "..tostring(color).." enforces citywide lockdown: all opponents start their next turn with 1 AP less.", {0.9, 0.5, 0.2})
  safeBroadcastAll("🎲 Rolling die for Lockdown reward ("..tostring(color)..")...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    if err then
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..tostring(die), {0.8,0.9,1})
    end
    if die <= 2 then
      moneyAdd(color, 200)
      safeBroadcastAll("Lockdown reward (1-2): "..tostring(color).." gains +200 VIN.", {0.7,1,0.7})
    elseif die <= 4 then
      moneyAdd(color, 500)
      safeBroadcastAll("Lockdown reward (3-4): "..tostring(color).." gains +500 VIN.", {0.7,1,0.7})
    else
      moneyAdd(color, 1000)
      satAdd(color, 2)
      safeBroadcastAll("Lockdown reward (5-6): "..tostring(color).." gains +1000 VIN and +2 Satisfaction.", {0.7,1,0.7})
    end
    AddGangsterSatFromCrimeDie(color, function()
      RunCrimeInvestigation({
        initiatorColor = color,
        vocationLevel = 3,
        crimeGainsVIN = (die <= 2 and 200) or (die <= 4 and 500) or 1000,
      })
    end)
  end)
  return true
end

-- Callable from TurnController when a player's turn starts. Applies Gangster lockdown: if this color has pending lockdown, move 1 AP to inactive.
function VOC_OnTurnStarted(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  if not params or not params.color then return end
  local c = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not c or c == "White" then return end
  state.lockdownPending = state.lockdownPending or {}
  if not state.lockdownPending[c] then return end
  state.lockdownPending[c] = nil
  saveState()
  local ap = findApCtrlForColor(c)
  if ap and ap.call then
    pcall(function() ap.call("moveAP", { to = "INACTIVE", amount = 1 }) end)
    safeBroadcastAll("🔒 Lockdown: "..tostring(c).." starts their turn with 1 AP moved to inactive.", {0.85, 0.6, 0.3})
  end
end

-- Callable from ShopEngine when gangster clicked STEAL on a hi-tech card. Roll die; 1-2 fail, 3-4 success + investigation, 5-6 success + heat only.
function VOC_GangsterStealHitechCardChosen(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing") return end
  if not params or not params.cardGuid or not params.color then return end
  local cardGuid = params.cardGuid
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color))
  if not color or color == "White" then return end
  safeBroadcastAll("🎲 Rolling die for Steal hi-tech ("..tostring(color)..")...", {1,1,0.6})
  rollPhysicalDieAndRead(function(die, err)
    if err then
      die = math.random(1, 6)
      safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
    else
      safeBroadcastAll("🎲 Die result: "..tostring(die), {0.8,0.9,1})
    end
    if die <= 2 then
      safeBroadcastAll("Steal hi-tech: Failed (1-2). Nothing happens.", {0.9,0.9,0.9})
      return
    end
    -- Success: give card to gangster (ShopEngine), then SAT die, then heat and optionally investigation
    local shop = nil
    for _, o in ipairs(VOC.getAllObjectsSafe()) do
      if o and o.hasTag and o.hasTag("WLB_SHOP_ENGINE") and o.call then shop = o break end
    end
    if shop and shop.call then
      pcall(function() shop.call("API_CompleteGangsterStealHitech", { cardGuid = cardGuid, toColor = color }) end)
    end
    if die >= 3 and die <= 4 then
      safeBroadcastAll("Steal hi-tech: Success (3-4). Investigation starts.", {0.7,1,0.7})
    else
      safeBroadcastAll("Steal hi-tech: Success (5-6). Heat +1.", {0.7,1,0.7})
      addAwardToken(color)
      local pawn = findHeatPawn()
      if pawn and pawn.call then
        pcall(function() pawn.call("AddHeat", 1) end)
        safeBroadcastAll("Heat +1 (police more cautious).", {0.7,0.8,1})
      end
    end
    AddGangsterSatFromCrimeDie(color, function()
      if die >= 3 and die <= 4 then
        RunCrimeInvestigation({ initiatorColor = color, vocationLevel = 1, crimeGainsVIN = 0 })
      end
    end)
  end)
end

function VOC_StartGangsterCrime(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  if not color then return false, "Invalid color" end
  
  -- If White is testing, use effectsTarget for initiator and effects
  local effectsTarget = params.effectsTarget
  local initiatorColor = effectsTarget or color
  
  VOC.log("VOC_StartGangsterCrime: color="..tostring(color)..", effectsTarget="..tostring(effectsTarget)..", initiatorColor="..tostring(initiatorColor))

  -- White bypasses vocation checks for testing
  if color ~= "White" and state.vocations[initiatorColor] ~= VOC_GANGSTER then
    safeBroadcastToColor("Only Gangster can use this action.", color, {1,0.7,0.2})
    return false
  end

  local level = tonumber(params.level) or (state.levels[initiatorColor] or 1)
  if color ~= "White" and (level < 1 or level > 3) then
    safeBroadcastToColor("Invalid crime level.", color, {1,0.7,0.2})
    return false
  end

  -- Enforce: action level must match character level (Gangster 1 → Lv1 only, etc.)
  local characterLevel = state.levels[initiatorColor] or 1
  if color ~= "White" and level ~= characterLevel then
    safeBroadcastToColor("⛔ This action is only available at Gangster Level " .. tostring(level) .. ". Your character is Level " .. tostring(characterLevel) .. ".", initiatorColor, {1,0.6,0.2})
    return false
  end

  if not canSpendAP(initiatorColor, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) to commit crime.", initiatorColor, {1,0.6,0.2})
    return false
  end
  
  -- Show target selection UI
  startTargetSelection({
    initiator = initiatorColor,
    actionId = "GANG_L"..level.."_CRIME",
    title = "SELECT TARGET FOR CRIME",
    subtitle = "Choose a player to commit crime against:",
    requireChildren = false,
    callback = function(targetColor)
      VOC.log("Crime: "..initiatorColor.." selected target: "..targetColor)
      
      -- Now spend AP and execute action
      if not spendAP(initiatorColor, 2, "GANG_L"..level.."_CRIME") then
        safeBroadcastToColor("⛔ Failed to deduct 2 AP.", initiatorColor, {1,0.6,0.2})
        return
      end
      VOC_AddWorkAP({ color = initiatorColor, amount = 2 })

      -- Roll D6 for crime outcome
      safeBroadcastAll("🎲 Rolling die for Crime ("..initiatorColor.." → "..targetColor..")...", {1,1,0.6})
      rollPhysicalDieAndRead(function(die, err)
        local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
        if err then
          if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
          die = math.random(1, 6)
          safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
        else
          safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
        end

        local function targetHasAlarm(c)
          local shop = nil
          for _, o in ipairs(VOC.getAllObjectsSafe()) do
            if o and o.hasTag and o.hasTag("WLB_SHOP_ENGINE") and o.call then shop = o break end
          end
          if not shop then return false end
          local ok, has = pcall(function() return shop.call("API_ownsHiTech", { color = c, kind = "ALARM" }) end)
          return (ok and has == true)
        end

        local stolenMoney = 0
        local canStealItem = false
        local actualStolenAmount = 0  -- for Heat & Investigation restitution (Tier 3)
        local victimHasAlarm = targetHasAlarm(targetColor)

        if level == 1 then
          if die <= 2 then
            safeBroadcastAll("Crime: Failed → nothing happens.", {0.9,0.9,0.9})
            return true
          elseif die <= 4 then
            stolenMoney = 300
            addWoundedStatus(targetColor)
            if victimHasAlarm then
              actualStolenAmount = 0
              safeBroadcastAll("🔔 Alarm raised! "..targetColor.."'s Anti-burglary Alarm prevented the theft. "..initiatorColor.."'s attempt was noticed; "..targetColor.." is WOUNDED but nothing was stolen.", {0.9,0.85,0.5})
            else
              local _, actualAmount = stealMoney(targetColor, initiatorColor, stolenMoney)
              actualStolenAmount = actualAmount or 0
              safeBroadcastAll("Crime: Partial success → "..targetColor.." gets WOUNDED and "..initiatorColor.." steals "..actualStolenAmount.." VIN.", {0.7,1,0.7})
            end
          else
            stolenMoney = 500
            canStealItem = not victimHasAlarm
            addWoundedStatus(targetColor)
            if victimHasAlarm then
              actualStolenAmount = 0
              safeBroadcastAll("🔔 Alarm raised! "..targetColor.."'s Anti-burglary Alarm prevented the theft. "..initiatorColor.."'s attempt was noticed; "..targetColor.." is WOUNDED but nothing was stolen.", {0.9,0.85,0.5})
            else
              local _, actualAmount = stealMoney(targetColor, initiatorColor, stolenMoney)
              actualStolenAmount = actualAmount or 0
              safeBroadcastAll("Crime: Full success → "..targetColor.." gets WOUNDED and "..initiatorColor.." steals "..actualStolenAmount.." VIN (or can choose High-Tech item).", {0.7,1,0.7})
            end
          end
        elseif level == 2 then
          if die <= 2 then
            safeBroadcastAll("Crime: Failed → nothing happens.", {0.9,0.9,0.9})
            return true
          elseif die <= 4 then
            stolenMoney = 750
            addWoundedStatus(targetColor)
            if victimHasAlarm then
              actualStolenAmount = 0
              safeBroadcastAll("🔔 Alarm raised! "..targetColor.."'s Anti-burglary Alarm prevented the theft. "..initiatorColor.."'s attempt was noticed; "..targetColor.." is WOUNDED but nothing was stolen.", {0.9,0.85,0.5})
            else
              local _, actualAmount = stealMoney(targetColor, initiatorColor, stolenMoney)
              actualStolenAmount = actualAmount or 0
              safeBroadcastAll("Crime: Partial success → "..targetColor.." gets WOUNDED and "..initiatorColor.." steals "..actualStolenAmount.." VIN.", {0.7,1,0.7})
            end
          else
            stolenMoney = 1000
            canStealItem = not victimHasAlarm
            addWoundedStatus(targetColor)
            if victimHasAlarm then
              actualStolenAmount = 0
              safeBroadcastAll("🔔 Alarm raised! "..targetColor.."'s Anti-burglary Alarm prevented the theft. "..initiatorColor.."'s attempt was noticed; "..targetColor.." is WOUNDED but nothing was stolen.", {0.9,0.85,0.5})
            else
              local _, actualAmount = stealMoney(targetColor, initiatorColor, stolenMoney)
              actualStolenAmount = actualAmount or 0
              safeBroadcastAll("Crime: Full success → "..targetColor.." gets WOUNDED and "..initiatorColor.." steals "..actualStolenAmount.." VIN (or can choose High-Tech item).", {0.7,1,0.7})
            end
          end
        else  -- level 3
          if die <= 2 then
            safeBroadcastAll("Crime: Failed → nothing happens.", {0.9,0.9,0.9})
            return true
          elseif die <= 4 then
            stolenMoney = 1500
            addWoundedStatus(targetColor)
            if victimHasAlarm then
              actualStolenAmount = 0
              safeBroadcastAll("🔔 Alarm raised! "..targetColor.."'s Anti-burglary Alarm prevented the theft. "..initiatorColor.."'s attempt was noticed; "..targetColor.." is WOUNDED but nothing was stolen.", {0.9,0.85,0.5})
            else
              local _, actualAmount = stealMoney(targetColor, initiatorColor, stolenMoney)
              actualStolenAmount = actualAmount or 0
              safeBroadcastAll("Crime: Partial success → "..targetColor.." gets WOUNDED and "..initiatorColor.." steals "..actualStolenAmount.." VIN.", {0.7,1,0.7})
            end
          else
            stolenMoney = 2000
            canStealItem = not victimHasAlarm
            addWoundedStatus(targetColor)
            if victimHasAlarm then
              actualStolenAmount = 0
              safeBroadcastAll("🔔 Alarm raised! "..targetColor.."'s Anti-burglary Alarm prevented the theft. "..initiatorColor.."'s attempt was noticed; "..targetColor.." is WOUNDED but nothing was stolen.", {0.9,0.85,0.5})
            else
              local _, actualAmount = stealMoney(targetColor, initiatorColor, stolenMoney)
              actualStolenAmount = actualAmount or 0
              safeBroadcastAll("Crime: Full success → "..targetColor.." gets WOUNDED and "..initiatorColor.." steals "..actualStolenAmount.." VIN (or can choose High-Tech item).", {0.7,1,0.7})
            end
          end
        end

        -- Normalize die value to ensure it's a number
        die = tonumber(die) or 1
        die = math.max(1, math.min(6, die))
        
        -- Check if crime was successful (die >= 3 means victim wounded or money stolen)
        -- If die <= 2, we already returned early above, so we only reach here if crime succeeded
        -- Flow: (1) Gangster satisfaction die, (2) Victim sorrow roll, (3) Investigation
        AddGangsterSatFromCrimeDie(initiatorColor, function()
          -- Victim sorrow roll: victim was wounded (always true if we reach here) or money was stolen
          AddVictimSorrowRoll(targetColor, function()
            -- Then run investigation
            RunCrimeInvestigation({
              initiatorColor = initiatorColor,
              vocationLevel = level,
              crimeGainsVIN = actualStolenAmount,
              targetColor = targetColor,
            })
          end)
        end)

        -- Note: High-Tech item selection needs manual player action in the current system
        if canStealItem then
          safeBroadcastToColor("You can choose to steal a High-Tech item instead of the money. (Manual selection required)", color, {1,1,0.6})
        end
      end)
    end
  })
  
  return true
end

-- =========================================================
-- CRIME, HEAT & INVESTIGATION (global heat, punishment ladder)
-- Call after any SUCCESSFUL crime (Gangster or VE card).
--
-- ORDER: (1) Investigation roll with CURRENT heat modifier (1d6 + modifier).
--        (2) Apply punishment or dismiss from result.
--        (3) After the investigation is done, Heat +1 (police get more cautious).
-- So the first crime is investigated at +0; heat only goes up after that investigation.
-- We never reuse the crime roll; investigation always uses its own physical die roll.
--
-- params: initiatorColor, vocationLevel (optional), crimeGainsVIN (optional), targetColor (optional)
--         Do NOT pass the crime roll – it is ignored; we roll again for investigation.
function RunCrimeInvestigation(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  params = params or {}
  local initiatorColor = (VOC.normalizeColor and VOC.normalizeColor(params.initiatorColor or params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.initiatorColor or params.color)) or nil
  if not initiatorColor or initiatorColor == "White" then return end
  local vocationLevel = tonumber(params.vocationLevel) or (state.levels and state.levels[initiatorColor]) or 1
  local crimeGainsVIN = math.max(0, tonumber(params.crimeGainsVIN) or 0)
  local targetColor = params.targetColor and normalizeColor(params.targetColor)

  local pawn = findHeatPawn()
  if not pawn or not pawn.call then
    VOC.log("RunCrimeInvestigation: Heat pawn (WLB_POLICE) not found – skipping heat/investigation")
    return
  end
  -- Modifier from current heat (before increasing – heat goes up after investigation)
  local modifier = 0
  pcall(function() modifier = pawn.call("GetInvestigationModifier") or 0 end)

  -- Step 1: Investigation roll (separate from the crime die)
  safeBroadcastAll("🔍 Roll the die for Investigation (modifier from current heat: +" .. tostring(modifier) .. "). After this investigation, heat will increase by 1.", {0.7, 0.8, 1})
  rollPhysicalDieAndRead(function(investigationRoll, err)
    local roll = investigationRoll  -- use only this roll; never the crime die
    if err or not roll then roll = math.random(1, 6) end
    local result = roll + (tonumber(modifier) or 0)
    safeBroadcastAll("🔍 Investigation result: 1d6=" .. tostring(roll) .. " + " .. tostring(modifier) .. " = " .. tostring(result), {0.8, 0.9, 1})

    -- Step 2: Apply outcome (punishment or dismiss)
    if result <= 2 then
      safeBroadcastAll("Investigation: No evidence found. Case dismissed.", {0.85, 0.85, 0.85})
      addAwardToken(initiatorColor)
      pcall(function() pawn.call("AddHeat", 1) end)
      safeBroadcastAll("Heat +1 (police more cautious).", {0.7, 0.8, 1})
      return
    end

    if result >= 3 and result <= 4 then
      safeBroadcastAll("Investigation: Official Warning – " .. initiatorColor .. " pays 200 VIN, loses 1 Satisfaction.", {1, 0.85, 0.3})
      pcall(function() moneySpend(initiatorColor, 200) end)
      satAdd(initiatorColor, -1)
      pcall(function() pawn.call("AddHeat", 1) end)
      safeBroadcastAll("Heat +1 (police more cautious).", {0.7, 0.8, 1})
      return
    end

    if result >= 5 and result <= 6 then
      local fine = 300 * vocationLevel
      safeBroadcastAll("Investigation: Formal Charge – " .. initiatorColor .. " pays " .. tostring(fine) .. " VIN, loses 2 Satisfaction, loses 1 AP (moved to inactive this turn).", {1, 0.7, 0.2})
      pcall(function() moneySpend(initiatorColor, fine) end)
      satAdd(initiatorColor, -2)
      local ap = findApCtrlForColor(initiatorColor)
      if ap and ap.call then
        pcall(function() ap.call("moveAP", { to = "INACTIVE", amount = 1 }) end)
      end
      pcall(function() pawn.call("AddHeat", 1) end)
      safeBroadcastAll("Heat +1 (police more cautious).", {0.7, 0.8, 1})
      return
    end

    -- result >= 7: Tier 3 – Severe
    local fine = 500 * vocationLevel
    safeBroadcastAll("Investigation: Major Conviction – " .. initiatorColor .. " pays " .. tostring(fine) .. " VIN, loses 4 Satisfaction, loses 2 AP (moved to inactive this turn), and must return stolen gains.", {1, 0.5, 0.2})
    pcall(function() moneySpend(initiatorColor, fine) end)
    satAdd(initiatorColor, -4)
    local ap = findApCtrlForColor(initiatorColor)
    if ap and ap.call then
      pcall(function() ap.call("moveAP", { to = "INACTIVE", amount = 2 }) end)
    end
    if crimeGainsVIN > 0 then
      pcall(function() moneySpend(initiatorColor, crimeGainsVIN) end)
      if targetColor and targetColor ~= "" then
        pcall(function() moneyAdd(targetColor, crimeGainsVIN) end)
        safeBroadcastAll("Restitution: " .. tostring(crimeGainsVIN) .. " VIN returned to " .. targetColor .. ".", {0.7, 1, 0.7})
      end
    end
    pcall(function() pawn.call("AddHeat", 1) end)
    safeBroadcastAll("Heat +1 (police more cautious).", {0.7, 0.8, 1})
  end)
end

function VOC_StartGangsterRobinHood(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  -- When White triggers, use effectsTarget or active turn as the actual gangster
  if color == "White" then
    color = normalizeColor(params.effectsTarget) or getActiveTurnColor()
  end
  if not color then return false, "Invalid color" end

  if color ~= "White" and state.vocations[color] ~= VOC_GANGSTER then
    safeBroadcastToColor("Only Gangster can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 2) then
    safeBroadcastToColor("⛔ Not enough AP (need 2 AP) for Robin Hood Job.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 2, "GANG_SPECIAL_ROBIN") then
    safeBroadcastToColor("⛔ Failed to deduct 2 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 2 })

  -- First: choose whom to rob (target). Then roll die to see if successful.
  local ok = startTargetSelection({
    initiator = color,
    actionId = "GANG_SPECIAL_ROBIN",
    title = "ROBIN HOOD JOB",
    subtitle = "Choose the corrupt businessman (against whom you perform this action). Then you will roll the die for success.",
    requireChildren = false,
    callback = function(targetColor)
      safeBroadcastAll("🎲 Rolling die for Robin Hood Job vs "..targetColor.."...", {1,1,0.6})
      rollPhysicalDieAndRead(function(die, err)
        local VOC2 = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
        if err then
          if VOC2 and VOC2.warn then VOC2.warn("Die roll failed: "..tostring(err).." - using fallback") end
          die = math.random(1, 6)
          safeBroadcastAll("⚠️ Die roll failed, using fallback: "..die, {1,0.7,0.3})
        else
          safeBroadcastAll("🎲 Die result: "..die, {0.8,0.9,1})
        end

        if die <= 2 then
          -- Plan leaks: initiator pays 200 VIN to bank, lose 2 Satisfaction
          moneySpend(color, 200)
          satAdd(color, -2)
          safeBroadcastAll("Robin Hood Job: Plan leaks → "..color.." pays 200 VIN to bank & loses -2 Satisfaction.", {1,0.7,0.2})
        elseif die <= 4 then
          -- Success: steal up to 500 from chosen target, donate to orphanage; +4 Satisfaction
          local maxSteal = 500
          local satGain = 4
          local targetMoney = (type(getMoney) == "function" and getMoney(targetColor)) or 0
          local amountToSteal = math.min(maxSteal, targetMoney)
          if amountToSteal > 0 then
            moneySpend(targetColor, amountToSteal)
          end
          satAdd(color, satGain)
          if amountToSteal > 0 then
            safeBroadcastAll("Robin Hood Job: "..color.." stole "..tostring(amountToSteal).." VIN from "..targetColor.." and donated to orphanage. +"..tostring(satGain).." Satisfaction.", {0.7,1,0.7})
          else
            safeBroadcastAll("Robin Hood Job: "..targetColor.." had no money to steal. "..color.." still gains +"..tostring(satGain).." Satisfaction (donation in spirit).", {0.7,1,0.7})
          end
        else
          -- Big success: steal up to 1000 from chosen target, donate to orphanage; +7 Satisfaction
          local maxSteal = 1000
          local satGain = 7
          local targetMoney = (type(getMoney) == "function" and getMoney(targetColor)) or 0
          local amountToSteal = math.min(maxSteal, targetMoney)
          if amountToSteal > 0 then
            moneySpend(targetColor, amountToSteal)
          end
          satAdd(color, satGain)
          if amountToSteal > 0 then
            safeBroadcastAll("Robin Hood Job: "..color.." stole "..tostring(amountToSteal).." VIN from "..targetColor.." and donated to orphanage. +"..tostring(satGain).." Satisfaction.", {0.7,1,0.7})
          else
            safeBroadcastAll("Robin Hood Job: "..targetColor.." had no money to steal. "..color.." still gains +"..tostring(satGain).." Satisfaction (donation in spirit).", {0.7,1,0.7})
          end
        end
      end)
    end,
  })

  if not ok then
    -- Target selection UI not available (e.g. UI nil or targetSelectionOverlay missing in Global). Refund 2 AP.
    local ap = findApCtrlForColor(color)
    if ap and ap.call then
      pcall(function() ap.call("moveAP", { to = "E", amount = -1 }) end)
      Wait.time(function()
        if ap and ap.call then pcall(function() ap.call("moveAP", { to = "E", amount = -1 }) end) end
      end, 0.5)
    end
    safeBroadcastToColor("Robin Hood Job: Target selection UI not available. 2 AP refunded. Ensure Global UI has targetSelectionOverlay and btnTargetYellow/Blue/Red/Green.", color, {1,0.85,0.3})
    return false
  end
  return true
end

function VOC_StartGangsterProtection(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  params = params or {}
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.color)) or nil
  if not color then color = getActorColor() end
  -- When White triggers, use effectsTarget or active turn as the actual gangster
  if color == "White" then
    color = normalizeColor(params.effectsTarget) or getActiveTurnColor()
  end
  if not color then return false, "Invalid color" end

  if color ~= "White" and state.vocations[color] ~= VOC_GANGSTER then
    safeBroadcastToColor("Only Gangster can use this action.", color, {1,0.7,0.2})
    return false
  end

  if not canSpendAP(color, 3) then
    safeBroadcastToColor("⛔ Not enough AP (need 3 AP) for Protection Racket.", color, {1,0.6,0.2})
    return false
  end
  if not spendAP(color, 3, "GANG_SPECIAL_PROTECTION") then
    safeBroadcastToColor("⛔ Failed to deduct 3 AP.", color, {1,0.6,0.2})
    return false
  end
  VOC_AddWorkAP({ color = color, amount = 3 })

  startInteraction({
    id = "GANG_SPECIAL_PROTECTION",
    initiator = color,
    title = "PROTECTION RACKET",
    subtitle = "Gangster Special – Cost for you: Spend 3 AP",
    joinCostText = "Each other player chooses:",
    effectText = "PAY: Spend 200 VIN per vocation level. You gain +1 Satisfaction per payer and keep the money. REFUSE: Lose -2 Health & -2 Satisfaction. This event raises heat level by 1.",
    joinCostAP = 0,  -- Money cost only for PAY
  })
  return true
end

function VOC_CanPromote(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
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
    -- Standard promotion (Public Servant, Social Worker, NGO, Entrepreneur, Gangster): need experience tokens
    local parts = {}
    if knowledge < (promotion.knowledge or 0) then
      table.insert(parts, "Need " .. tostring(promotion.knowledge) .. " Knowledge (have " .. tostring(knowledge) .. ")")
    end
    if skills < (promotion.skills or 0) then
      table.insert(parts, "Need " .. tostring(promotion.skills) .. " Skills (have " .. tostring(skills) .. ")")
    end
    local needTokens = promotion.experience or 0
    local haveTokens = getExperienceTokenCount(color)
    if needTokens > 0 and haveTokens < needTokens then
      table.insert(parts, "Need " .. tostring(needTokens) .. " experience tokens (have " .. tostring(haveTokens) .. ")")
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
      local currentMoney = getMoney(color)
      if currentMoney < promotion.additionalCost then
        return false, "Not enough money (need " .. promotion.additionalCost .. " VIN, have " .. currentMoney .. ")"
      end
    end
    return true, "All requirements met"
    
  elseif promotion.type == "award" then
    if knowledge < promotion.knowledge then
      return false, "Need " .. promotion.knowledge .. " Knowledge (have " .. knowledge .. ")"
    end
    if skills < promotion.skills then
      return false, "Need " .. promotion.skills .. " Skills (have " .. skills .. ")"
    end
    local vocation = state.vocations[color]
    if vocation == VOC_PUBLIC_SERVANT then
      if state.noSpecialAwardThisYear[color] then
        return false, "No special award this year (work obligation not met)"
      end
      local awardTokens = getAwardTokenCount(color)
      if awardTokens < 2 then
        return false, "Need 2 award tokens from successful tax collections (have " .. tostring(awardTokens) .. ")"
      end
    elseif vocation == VOC_SOCIAL_WORKER then
      local awardTokens = getAwardTokenCount(color)
      if awardTokens < 2 then
        return false, "Need 2 award tokens from community events with participants (have " .. tostring(awardTokens) .. ")"
      end
    elseif vocation == VOC_NGO_WORKER then
      local awardTokens = getAwardTokenCount(color)
      local volAP = state.voluntaryWorkAP[color] or 0
      if awardTokens >= 2 then
        -- path A: 2 campaigns
      elseif awardTokens >= 1 and volAP >= 10 then
        -- path B: 1 campaign + 10 AP voluntary work
      else
        return false, "Need 2 award tokens from social campaigns, or 1 token + 10 AP voluntary work (have " .. tostring(awardTokens) .. " tokens, " .. tostring(volAP) .. " AP voluntary)"
      end
    elseif vocation == VOC_ENTREPRENEUR then
      local tokenEngine = findTokenEngine()
      local housingLevel = "L0"
      if tokenEngine and tokenEngine.call then
        local ok, info = pcall(function() return tokenEngine.call("TE_GetFamilyInfo_ARGS", { color = color }) end)
        if ok and info and info.housingLevel then housingLevel = info.housingLevel end
      end
      if housingLevel ~= "L3" and housingLevel ~= "L4" then
        return false, "Need Level 3 or 4 house (have " .. housingLevel .. ")"
      end
      local shopList = VOC.getObjectsWithTagSafe("WLB_SHOP_ENGINE") or {}
      local hiTechCount = 0
      for _, shop in ipairs(shopList) do
        if shop and shop.call then
          local ok, list = pcall(function() return shop.call("API_getOwnedHiTech", { color = color }) end)
          if ok and type(list) == "table" then hiTechCount = #list; break end
        end
      end
      if hiTechCount < 2 then
        return false, "Need 2 High-Tech items (have " .. tostring(hiTechCount) .. ")"
      end
    elseif vocation == VOC_GANGSTER then
      local awardTokens = getAwardTokenCount(color)
      if awardTokens < 2 then
        return false, "Need 2 award tokens from crimes not caught (have " .. tostring(awardTokens) .. ")"
      end
    else
      return false, "Unknown award vocation"
    end
    return true, "All requirements met"
  end
  
  return false, "Unknown promotion type"
end

function VOC_Promote(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  if not color then return false, "Invalid color" end
  
  -- Only the owner of the vocation card can level it up
  local tileGuid = params.tileGuid
  if tileGuid and tileGuid ~= "" then
    local tile = VOC.getObjectFromGUID(tileGuid)
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
    VOC.log("Cannot promote " .. color .. ": " .. tostring(reason))
    return false, reason
  end
  
  local vocation = state.vocations[color]
  local oldLevel = state.levels[color] or 1
  local newLevel = oldLevel + 1
  
  local vocationData = VOCATION_DATA[vocation]
  if not vocationData then
    return false, "Invalid vocation data"
  end
  
  -- Replace vocation card with higher-level card first; only then update state
  local swapOk = swapTileOnPromotion(color, vocation, oldLevel, newLevel)
  if not swapOk then
    VOC.log("Promotion aborted: could not replace vocation card for " .. color .. " (Level " .. newLevel .. " tile not found or place failed)")
    return false, "Could not replace vocation card – ensure Level " .. newLevel .. " vocation tiles exist with correct tags"
  end
  
  -- Consume experience tokens if this was a standard promotion
  -- Tokens are removed from player's board and returned to the pool
  local currentLevelData = vocationData.levels[oldLevel]
  if currentLevelData and currentLevelData.promotion and currentLevelData.promotion.type == "standard" then
    local needTokens = currentLevelData.promotion.experience or 0
    if needTokens > 0 then
      local tokenEngine = findTokenEngine()
      if tokenEngine and tokenEngine.call then
        local beforeCount = getExperienceTokenCount(color)
        VOC.log("Promotion: Removing " .. tostring(needTokens) .. " experience tokens from " .. color .. " (current count: " .. tostring(beforeCount) .. ")")
        
        -- Remove tokens one at a time using sequential Wait.time callbacks (same pattern as AP refunds in EventEngine)
        -- This ensures each removal completes before the next one starts, preventing race conditions
        -- Each TE_RemoveStatus triggers TE_RefreshStatuses which uses async Wait.time operations
        -- Need longer delays to ensure each refresh fully completes before next removal
        local removedCount = 0
        for i = 1, needTokens do
          Wait.time(function()
            local removeOk, removeErr = pcall(function()
              return tokenEngine.call("TE_RemoveStatus_ARGS", { color = color, statusTag = TAG_STATUS_EXPERIENCE })
            end)
            if removeOk then
              removedCount = removedCount + 1
              VOC.log("Promotion: Removed token " .. i .. " of " .. needTokens .. " from " .. color)
              
              -- After each removal, wait and verify the token count before proceeding to next removal
              -- This ensures the refresh from this removal completes before starting the next
              if i < needTokens then
                Wait.time(function()
                  local currentCount = getExperienceTokenCount(color)
                  local expectedCount = beforeCount - removedCount
                  VOC.log("Promotion: After removing token " .. i .. ", count is " .. tostring(currentCount) .. " (expected: " .. tostring(expectedCount) .. ")")
                  if currentCount ~= expectedCount then
                    VOC.warn("Promotion: Token count mismatch after removing token " .. i .. " - refresh may not have completed")
                  end
                end, 2.0)  -- Wait 2 seconds after each removal to verify refresh completed
              end
            else
              VOC.log("ERROR: Failed to remove experience token " .. i .. " for " .. color .. " promotion: " .. tostring(removeErr))
            end
            
            -- After last removal, wait for tokens to settle and then verify
            if i == needTokens then
              VOC.log("Promotion: All " .. tostring(needTokens) .. " tokens removed, waiting for refreshes to complete")
              -- Add longer delay to let tokens settle and ensure all async operations complete
              -- This prevents round-end refreshes from restoring tokens
              Wait.time(function()
                -- Save state after all removals complete
                saveState()
                
                -- Wait additional time for all async refresh operations to complete
                -- This includes removal refreshes and any potential round-end processing
                Wait.time(function()
                  -- Force a refresh to sync physical tokens with state after all async operations complete
                  pcall(function()
                    tokenEngine.call("TE_RefreshStatuses_ARGS", { color = color })
                  end)
                  
                  -- Wait for forced refresh to complete, then verify
                  Wait.time(function()
                    saveState()  -- Save state after refresh to ensure consistency
                    
                    local afterCount = getExperienceTokenCount(color)
                    VOC.log("Promotion: Token removal complete for " .. color .. " (removed: " .. tostring(removedCount) .. ", before: " .. tostring(beforeCount) .. ", after: " .. tostring(afterCount) .. ", expected: " .. tostring(beforeCount - needTokens) .. ")")
                    
                    -- If tokens are still there after forced refresh, they may have been restored by round-end processing
                    -- Remove them again using the same sequential pattern
                    if afterCount ~= (beforeCount - needTokens) then
                      VOC.warn("Promotion: Token count incorrect for " .. color .. " after refresh - tokens may have been restored, removing again")
                      local remaining = afterCount - (beforeCount - needTokens)
                      if remaining > 0 then
                        VOC.log("Promotion: Removing " .. tostring(remaining) .. " restored tokens using sequential pattern")
                        for j = 1, remaining do
                          Wait.time(function()
                            pcall(function()
                              tokenEngine.call("TE_RemoveStatus_ARGS", { color = color, statusTag = TAG_STATUS_EXPERIENCE })
                            end)
                            if j == remaining then
                              -- After last additional removal, wait longer and force final refresh
                              Wait.time(function()
                                saveState()
                                Wait.time(function()
                                  pcall(function()
                                    tokenEngine.call("TE_RefreshStatuses_ARGS", { color = color })
                                  end)
                                  Wait.time(function()
                                    saveState()
                                    local finalCount = getExperienceTokenCount(color)
                                    VOC.log("Promotion: Final token count after additional removal: " .. tostring(finalCount) .. " (expected: " .. tostring(beforeCount - needTokens) .. ")")
                                    if finalCount ~= (beforeCount - needTokens) then
                                      VOC.warn("CRITICAL: Tokens still not removed correctly for " .. color .. " after all attempts")
                                    end
                                  end, 3.0)  -- Increased delay for final verification
                                end, 1.0)  -- Additional delay before final refresh
                              end, 0.5)  -- Increased delay after additional removals
                            end
                          end, 1.0 * j)  -- Sequential delay: 1.0s per token
                        end  -- closes for j loop
                      end
                    end
                  end, 3.0)  -- Increased delay for forced refresh to complete
                end, 2.0)  -- Additional delay to ensure all async operations complete
              end, 2.0)  -- Increased initial delay to let tokens settle
            end
          end, 3.0 * i)  -- Increased sequential delay: 3.0s per token to ensure each refresh completes
        end
      else
        VOC.log("ERROR: TokenEngine not found when trying to consume experience tokens for " .. color .. " promotion")
        VOC.warn("TokenEngine missing - experience tokens not consumed on promotion")
      end
    end
  end
  
  -- Update level and round after successful card swap
  state.levels[color] = newLevel
  state.levelUpRound[color] = getCurrentRound()
  state.workAPThisLevel[color] = 0
  state.experienceYearsEarned[color] = 0
  saveState()
  
  local newLevelData = vocationData.levels[newLevel]
  
  VOC.log("Promoted: " .. color .. " " .. vocation .. " Level " .. oldLevel .. " → " .. newLevel)
  broadcastToAll(color .. " promoted to " .. vocationData.name .. " - " .. newLevelData.jobTitle, {0.3, 1, 0.3})
  
  return true
end

-- Called before a player's turn (by TurnController at turn start): if they meet promotion requirements, promote automatically
-- and swap the next-level vocation tile (Level 2 or Level 3) with their current tile (no tile context menu needed).
function VOC_CheckAndAutoPromote(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
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

-- Testing: set to true to show ALL vocation actions (L1 + L2 + L3) at once regardless of level. Set to false for normal play.
local TESTING_UNLOCK_ALL_LEVELS = true
local MAX_ACTION_BUTTONS = 15  -- Max buttons when testing (UI may have only 5; extra use btnAction6..15 if defined)

-- UI State tracking
local uiState = {
  activeColor = nil,
  currentScreen = nil,  -- "selection", "summary", or nil
  previewedVocation = nil,
  previewedVocationOwner = nil, -- Which player owns the previewed vocation
  currentActionMap = {},  -- [buttonIndex] = actionId for current vocation/level
  testingBypassActive = false   -- True when White is testing actions (bypass all checks)
}

-- =========================================================
-- VOCATION ACTIONS SYSTEM
-- =========================================================

-- Get available actions for a vocation at a specific level
-- Optional ownerColor: when set, "Use Good Karma" is hidden if already used this game for that owner.
-- Returns array of {buttonIndex, label, actionId} where buttonIndex is 1-5 (or 1..N when TESTING_UNLOCK_ALL_LEVELS).
local function getVocationActionsForLevel(vocation, level, ownerColor)
  local actions = {}
  VOC.log("getVocationActionsForLevel: vocation="..tostring(vocation)..", level="..tostring(level)..", ownerColor="..tostring(ownerColor))
  
  if vocation == VOC_SOCIAL_WORKER then
    -- Level 1: two buttons (community event + Use Good Karma, once per game)
    if level == 1 then
      table.insert(actions, {buttonIndex = 1, label = "Community Event: Practical workshop", actionId = "SW_L1_PRACTICAL_WORKSHOP"})
      local used = (state.swGoodKarmaUsed or {})[ownerColor]
      if not used then
        table.insert(actions, {buttonIndex = 2, label = "Use Good Karma", actionId = "SW_L1_USE_GOOD_KARMA"})
      end
    elseif level == 2 then
      table.insert(actions, {buttonIndex = 1, label = "Community Wellbeing Session", actionId = "SW_L2_COMMUNITY_WELLBEING"})
      if not (state.swConsumablePerkUsed or {})[ownerColor] then
        table.insert(actions, {buttonIndex = 2, label = "Once per game: one consumable from shop free", actionId = "SW_L2_CONSUMABLE_FREE"})
      end
    elseif level == 3 then
      table.insert(actions, {buttonIndex = 1, label = "Expose social case", actionId = "SW_L3_EXPOSE_CASE"})
      if not (state.swHitechPerkUsed or {})[ownerColor] then
        table.insert(actions, {buttonIndex = 2, label = "Once per game: one hi-tech from shop free", actionId = "SW_L3_HITECH_FREE"})
      end
    end
    
  elseif vocation == VOC_CELEBRITY then
    -- One button per level (level action only; show only current level's action)
    if level == 1 then
      table.insert(actions, {buttonIndex = 1, label = "Live Street Performance", actionId = "CELEB_L1_STREET_PERF"})
    elseif level == 2 then
      table.insert(actions, {buttonIndex = 1, label = "Meet & Greet", actionId = "CELEB_L2_MEET_GREET"})
    elseif level == 3 then
      table.insert(actions, {buttonIndex = 1, label = "Extended Charity Stream", actionId = "CELEB_L3_CHARITY_STREAM"})
      -- "Get an award" available when 10 AP worked at L3 and not yet claimed (costs 4000 VIN)
      local ap = state.workAPThisLevel and state.workAPThisLevel[ownerColor] or 0
      local received = state.celebrityAwardReceived and state.celebrityAwardReceived[ownerColor]
      if ap >= 10 and not received then
        table.insert(actions, {buttonIndex = 2, label = "Get an award (4000 VIN)", actionId = "CELEB_L3_GET_AWARD"})
      end
    end
    
  elseif vocation == VOC_PUBLIC_SERVANT then
    -- Level action + level perk(s). For testing: at level 1 all three perks are available.
    if level == 1 then
      table.insert(actions, {buttonIndex = 1, label = "Income Tax Campaign", actionId = "PS_L1_INCOME_TAX"})
      -- Testing: allow taking any of the three perks at level 1
      table.insert(actions, {buttonIndex = 2, label = "Health Monitor Access", actionId = "PS_PERK_HEALTH_MONITOR_ACCESS"})
      table.insert(actions, {buttonIndex = 3, label = "Anti-burglary Alarm", actionId = "PS_PERK_ALARM_ACCESS"})
      table.insert(actions, {buttonIndex = 4, label = "New Car", actionId = "PS_PERK_CAR_ACCESS"})
    elseif level == 2 then
      table.insert(actions, {buttonIndex = 1, label = "Hi-Tech Tax Campaign", actionId = "PS_L2_HITECH_TAX"})
      table.insert(actions, {buttonIndex = 2, label = "Anti-burglary Alarm", actionId = "PS_PERK_ALARM_ACCESS"})
    elseif level == 3 then
      table.insert(actions, {buttonIndex = 1, label = "Property Tax Campaign", actionId = "PS_L3_PROPERTY_TAX"})
      table.insert(actions, {buttonIndex = 2, label = "New Car", actionId = "PS_PERK_CAR_ACCESS"})
    end

  elseif vocation == VOC_NGO_WORKER then
    -- Social campaign (1) + level perk (2) + Voluntary work (3) per level
    if level == 1 then
      table.insert(actions, {buttonIndex = 1, label = "Charity campaign", actionId = "NGO_L1_CHARITY"})
      local ngoUsed = (state.ngoGoodKarmaUsedPerLevel or {})[ownerColor]
      if not (ngoUsed and ngoUsed[1]) then
        table.insert(actions, {buttonIndex = 2, label = "Take Good Karma (free)", actionId = "NGO_L1_TAKE_GOOD_KARMA"})
      end
      table.insert(actions, {buttonIndex = 3, label = "Voluntary work: -2 AP = +1 SAT", actionId = "NGO_VOLUNTARY_WORK"})
    elseif level == 2 then
      table.insert(actions, {buttonIndex = 1, label = "Crowdfunding campaign", actionId = "NGO_L2_CROWDFUND"})
      local ngoTripUsed = (state.ngoTakeTripUsedPerLevel or {})[ownerColor]
      if not (ngoTripUsed and ngoTripUsed[2]) then
        table.insert(actions, {buttonIndex = 2, label = "Take Trip (free)", actionId = "NGO_L2_TAKE_TRIP"})
      end
      table.insert(actions, {buttonIndex = 3, label = "Voluntary work: -3 AP = +2 SAT", actionId = "NGO_VOLUNTARY_WORK"})
    elseif level == 3 then
      table.insert(actions, {buttonIndex = 1, label = "Advocacy / pressure campaign", actionId = "NGO_L3_ADVOCACY"})
      local ngoInvUsed = (state.ngoUseInvestmentUsedPerLevel or {})[ownerColor]
      if not (ngoInvUsed and ngoInvUsed[3]) then
        table.insert(actions, {buttonIndex = 2, label = "Use Investment (free, up to 1000 VIN)", actionId = "NGO_L3_USE_INVESTMENT"})
      end
      table.insert(actions, {buttonIndex = 3, label = "Voluntary work: -1 AP = +1 SAT", actionId = "NGO_VOLUNTARY_WORK"})
    end
    
  elseif vocation == VOC_ENTREPRENEUR then
    -- Level 1: two buttons; Level 2: two buttons; Level 3: one button (per level, not cumulative)
    if level == 1 then
      table.insert(actions, {buttonIndex = 1, label = "Flash Sale Promotion", actionId = "ENT_L1_FLASH_SALE"})
      table.insert(actions, {buttonIndex = 2, label = "Talk to shop owner", actionId = "ENT_L1_TALK_TO_SHOP_OWNER"})
    elseif level == 2 then
      table.insert(actions, {buttonIndex = 1, label = "Commercial training course", actionId = "ENT_L2_TRAINING"})
      -- "Use your network" (reroll after die): no button; passive L2 ability – halt after any die roll, show Reroll/Go on on die
    elseif level == 3 then
      table.insert(actions, {buttonIndex = 1, label = "Reposition event cards", actionId = "ENT_L3_REPOSITION_EVENTS"})
    end
    
  elseif vocation == VOC_GANGSTER then
    -- Two buttons per level: crime action (vs shop/false money/lockdown) + crime against player
    if level == 1 then
      table.insert(actions, {buttonIndex = 1, label = "Crime action: Steal hi-tech from shop", actionId = "GANG_L1_STEAL_HITECH_SHOP"})
      table.insert(actions, {buttonIndex = 2, label = "Crime against player (Lv1)", actionId = "GANG_L1_CRIME"})
    elseif level == 2 then
      table.insert(actions, {buttonIndex = 1, label = "Crime action: False money production", actionId = "GANG_L2_FALSE_MONEY"})
      table.insert(actions, {buttonIndex = 2, label = "Crime against player (Lv2)", actionId = "GANG_L2_CRIME"})
    elseif level == 3 then
      table.insert(actions, {buttonIndex = 1, label = "Crime action: Enforce citywide lockdown", actionId = "GANG_L3_LOCKDOWN"})
      table.insert(actions, {buttonIndex = 2, label = "Crime against player (Lv3)", actionId = "GANG_L3_CRIME"})
    end
  end
  
  return actions
end

-- When TESTING_UNLOCK_ALL_LEVELS is true, return all actions for levels 1, 2, 3 merged with sequential buttonIndex.
local function getVocationActions(vocation, level, ownerColor)
  if not TESTING_UNLOCK_ALL_LEVELS then
    return getVocationActionsForLevel(vocation, level, ownerColor)
  end
  local merged = {}
  for lvl = 1, 3 do
    local list = getVocationActionsForLevel(vocation, lvl, ownerColor)
    for _, a in ipairs(list) do
      table.insert(merged, {
        buttonIndex = #merged + 1,
        label = (a.label or "") .. " [L" .. lvl .. "]",
        actionId = a.actionId
      })
    end
  end
  VOC.log("getVocationActions: TESTING_UNLOCK_ALL_LEVELS merged "..#merged.." actions for "..tostring(vocation))
  return merged
end

-- Update action button visibility and labels
local function updateActionButtons(actions)
  if not UI then return end
  
  -- Clear previous action map
  uiState.currentActionMap = {}
  
  local numButtons = TESTING_UNLOCK_ALL_LEVELS and MAX_ACTION_BUTTONS or 5
  -- Hide all buttons first
  for i = 1, numButtons do
    pcall(function()
      UI.setAttribute("btnAction"..i, "active", "false")
      UI.setAttribute("btnAction"..i, "text", "")
    end)
  end
  
  -- Show and label buttons that have actions
  for _, action in ipairs(actions) do
    local idx = action.buttonIndex
    if idx >= 1 and idx <= numButtons then
      VOC.log("updateActionButtons: Setting button "..idx.." - label="..tostring(action.label)..", actionId="..tostring(action.actionId))
      pcall(function()
        UI.setAttribute("btnAction"..idx, "text", action.label)
        UI.setAttribute("btnAction"..idx, "active", "true")
      end)
      uiState.currentActionMap[idx] = action.actionId
    end
  end
  VOC.log("updateActionButtons: Complete. currentActionMap="..tostring(JSON.encode(uiState.currentActionMap)))
end

-- Forward declarations for UI functions
local hideSummaryUI

-- Shared router: dispatch by actionId (used by UI_VocationAction and RunVocationEventCardAction)
local function executeVocationActionById(actionId, params)
  if actionId == "SW_L1_PRACTICAL_WORKSHOP" then
    return VOC_StartSocialWorkerPracticalWorkshop(params)
  elseif actionId == "SW_L1_USE_GOOD_KARMA" then
    return VOC_StartSocialWorkerUseGoodKarma(params)
  elseif actionId == "SW_L2_COMMUNITY_WELLBEING" then
    return VOC_StartSocialWorkerCommunitySession(params)
  elseif actionId == "SW_L2_CONSUMABLE_FREE" then
    return VOC_StartSocialWorkerConsumableFree(params)
  elseif actionId == "SW_L3_EXPOSE_CASE" then
    return VOC_StartSocialWorkerExposeCase(params)
  elseif actionId == "SW_L3_HITECH_FREE" then
    return VOC_StartSocialWorkerHitechFree(params)
  elseif actionId == "SW_SPECIAL_HOMELESS" then
    return VOC_StartSocialWorkerHomelessShelter(params)
  elseif actionId == "SW_SPECIAL_REMOVAL" then
    return VOC_StartSocialWorkerRemoval(params)
  elseif actionId == "CELEB_L1_STREET_PERF" then
    return VOC_StartCelebrityStreetPerformance(params)
  elseif actionId == "CELEB_L2_MEET_GREET" then
    return VOC_StartCelebrityMeetGreet(params)
  elseif actionId == "CELEB_L3_CHARITY_STREAM" then
    return VOC_StartCelebrityCharityStream(params)
  elseif actionId == "CELEB_L3_GET_AWARD" then
    return VOC_CelebrityGetAward(params)
  elseif actionId == "CELEB_SPECIAL_COLLAB" then
    return VOC_StartCelebrityCollaboration(params)
  elseif actionId == "CELEB_SPECIAL_MEETUP" then
    return VOC_StartCelebrityMeetup(params)
  elseif actionId == "PS_L1_INCOME_TAX" then
    return VOC_StartPublicServantIncomeTax(params)
  elseif actionId == "PS_L2_HITECH_TAX" then
    return VOC_StartPublicServantHiTechTax(params)
  elseif actionId == "PS_L3_PROPERTY_TAX" then
    return VOC_StartPublicServantPropertyTax(params)
  elseif actionId == "PS_PERK_HEALTH_MONITOR_ACCESS" then
    return VOC_PlacePublicServantHealthMonitorAccess(params)
  elseif actionId == "PS_PERK_ALARM_ACCESS" then
    return VOC_PlacePublicServantAlarmAccess(params)
  elseif actionId == "PS_PERK_CAR_ACCESS" then
    return VOC_PlacePublicServantCarAccess(params)
  elseif actionId == "PS_SPECIAL_POLICY" then
    return VOC_StartPublicServantPolicy(params)
  elseif actionId == "PS_SPECIAL_BOTTLENECK" then
    return VOC_StartPublicServantBottleneck(params)
  elseif actionId == "NGO_L1_CHARITY" then
    return VOC_StartNGOCharity(params)
  elseif actionId == "NGO_L1_TAKE_GOOD_KARMA" then
    return VOC_StartNGOTakeGoodKarma(params)
  elseif actionId == "NGO_L2_CROWDFUND" then
    return VOC_StartNGOCrowdfunding(params)
  elseif actionId == "NGO_L2_TAKE_TRIP" then
    return VOC_StartNGOTakeTrip(params)
  elseif actionId == "NGO_L3_USE_INVESTMENT" then
    return VOC_StartNGOUseInvestment(params)
  elseif actionId == "NGO_L3_ADVOCACY" then
    return VOC_StartNGOAdvocacy(params)
  elseif actionId == "NGO_VOLUNTARY_WORK" then
    return VOC_StartNGOVoluntaryWork(params)
  elseif actionId == "NGO_SPECIAL_CRISIS" then
    return VOC_StartNGOCrisis(params)
  elseif actionId == "NGO_SPECIAL_SCANDAL" then
    return VOC_StartNGOScandal(params)
  elseif actionId == "ENT_L1_FLASH_SALE" then
    return VOC_StartEntrepreneurFlashSale(params)
  elseif actionId == "ENT_L1_TALK_TO_SHOP_OWNER" then
    return VOC_StartEntrepreneurTalkToShopOwner(params)
  elseif actionId == "ENT_L2_TRAINING" then
    return VOC_StartEntrepreneurTraining(params)
  elseif actionId == "ENT_SPECIAL_EXPANSION" then
    return VOC_StartEntrepreneurExpansion(params)
  elseif actionId == "ENT_SPECIAL_TRAINING" then
    return VOC_StartEntrepreneurEmployeeTraining(params)
  elseif actionId == "ENT_L3_REPOSITION_EVENTS" then
    return VOC_StartEntrepreneurReposition(params)
  elseif actionId == "GANG_L1_STEAL_HITECH_SHOP" then
    return VOC_StartGangsterStealHitech(params)
  elseif actionId == "GANG_L2_FALSE_MONEY" then
    return VOC_StartGangsterFalseMoney(params)
  elseif actionId == "GANG_L3_LOCKDOWN" then
    return VOC_StartGangsterLockdown(params)
  elseif actionId == "GANG_L1_CRIME" then
    params.level = 1
    return VOC_StartGangsterCrime(params)
  elseif actionId == "GANG_L2_CRIME" then
    params.level = 2
    return VOC_StartGangsterCrime(params)
  elseif actionId == "GANG_L3_CRIME" then
    params.level = 3
    return VOC_StartGangsterCrime(params)
  elseif actionId == "GANG_SPECIAL_ROBIN" then
    return VOC_StartGangsterRobinHood(params)
  elseif actionId == "GANG_SPECIAL_PROTECTION" then
    return VOC_StartGangsterProtection(params)
  else
    local color = params and params.color
    safeBroadcastToColor("Action not implemented: "..tostring(actionId), color or "White", {1,0.6,0.2})
    return false, "Action not implemented"
  end
end

-- Handle action button click
function UI_VocationAction(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  if VOC.log then VOC.log("=== UI_VocationAction START ===") end
  
  -- Defensive check: ensure params exists
  if not params then
    VOC.log("UI_VocationAction: ERROR - params is nil!")
    safeBroadcastToColor("Error: Action parameters missing.", "White", {1,0.6,0.2})
    return false, "Params is nil"
  end
  
  -- Defensive check: ensure uiState exists
  if not uiState then
    VOC.log("UI_VocationAction: ERROR - uiState is nil!")
    safeBroadcastToColor("Error: UI state not initialized.", "White", {1,0.6,0.2})
    return false, "uiState is nil"
  end
  
  params = params or {}
  local originalColor = params.playerColor
  local color = normalizeColor(params.playerColor)
  VOC.log("UI_VocationAction: playerColor="..tostring(originalColor)..", normalized="..tostring(color))
  VOC.log("UI_VocationAction: previewedVocation="..tostring(uiState.previewedVocation)..", previewedVocationOwner="..tostring(uiState.previewedVocationOwner))
  
  -- For White (spectator/host): find which vocation is being viewed
  -- White stays as White for bypass checks, but we track the actual player for effects
  local effectsTarget = nil  -- The actual player who receives effects
  
  if color == "White" then
    VOC.log("UI_VocationAction: White player detected - finding vocation owner")
    
    -- FIRST PRIORITY: Use the tracked owner from uiState (set when showSummaryUI was called)
    if uiState.previewedVocationOwner then
      effectsTarget = uiState.previewedVocationOwner
      VOC.log("UI_VocationAction: Using tracked vocation owner: "..tostring(effectsTarget))
    -- Second check: if viewing a specific player's vocation, find who owns it
    elseif uiState.previewedVocation then
      -- Find who owns this vocation (only one player can own each vocation)
      for _, c in ipairs(COLORS) do
        if state.vocations[c] == uiState.previewedVocation then
          effectsTarget = c
          VOC.log("UI_VocationAction: Found vocation owner via search: "..tostring(c))
          break
        end
      end
    end
    
    -- Fallback: use active turn color
    if not effectsTarget then
      effectsTarget = getActiveTurnColor()
      VOC.log("UI_VocationAction: Using active turn color as fallback: "..tostring(effectsTarget))
    end
    
    -- Fallback: use first player with a vocation
    if not effectsTarget then
      for _, c in ipairs(COLORS) do
        if state.vocations[c] then
          effectsTarget = c
          VOC.log("UI_VocationAction: Using first vocation owner as fallback: "..tostring(c))
          break
        end
      end
    end
    
    if not effectsTarget then
      VOC.log("UI_VocationAction: White player, no vocation owner found")
      safeBroadcastToColor("No vocation owner found. Assign a vocation to a player first.", "White", {1,0.6,0.2})
      return false, "No vocation owner"
    end
    
    -- White stays White for bypass, effects go to the actual player
    VOC.log("UI_VocationAction: ✓ White testing mode: color=White (bypass), effectsTarget="..tostring(effectsTarget))
    params.effectsTarget = effectsTarget
    
    -- Set bypass flag (check uiState exists first)
    if uiState then
      uiState.testingBypassActive = true
      
      -- Clear bypass flag after action completes
      Wait.time(function()
        -- Defensive: check uiState still exists in callback
        if uiState then
          uiState.testingBypassActive = false
          VOC.log("UI_VocationAction: Cleared testing bypass flag after action")
        else
          VOC.log("UI_VocationAction: WARNING - uiState is nil in Wait.time callback")
        end
      end, 5)  -- Increased delay to allow interaction to complete
    else
      VOC.log("UI_VocationAction: WARNING - uiState is nil, cannot set testing bypass flag")
    end
  elseif not color then
    color = getActorColor()
    VOC.log("UI_VocationAction: Fallback to getActorColor: "..tostring(color))
  end
  
  -- Pass color to action functions
  VOC.log("UI_VocationAction: params.color="..tostring(color)..", effectsTarget="..tostring(params.effectsTarget or "none"))
  params.color = color
  
  if not color then
    VOC.log("UI_VocationAction: Invalid color after all checks")
    safeBroadcastToColor("Invalid player color. Cannot execute action.", params.playerColor or "White", {1,0.6,0.2})
    return false, "Invalid color"
  end
  
  VOC.log("UI_VocationAction: Final color="..tostring(color))
  
  local buttonIndex = tonumber(params.buttonIndex)
  if not buttonIndex or buttonIndex < 1 or buttonIndex > 5 then
    VOC.log("UI_VocationAction: Invalid buttonIndex="..tostring(params.buttonIndex))
    safeBroadcastToColor("Invalid action button.", color, {1,0.6,0.2})
    return false, "Invalid button index"
  end
  
  VOC.log("UI_VocationAction: buttonIndex="..tostring(buttonIndex))
  VOC.log("UI_VocationAction: currentActionMap="..tostring(JSON and JSON.encode(uiState.currentActionMap) or "JSON not available"))
  
  if not uiState.currentActionMap then
    VOC.log("UI_VocationAction: ERROR - currentActionMap is nil!")
    safeBroadcastToColor("Action map not initialized. Please try reopening the vocation UI.", color, {1,0.6,0.2})
    return false, "Action map is nil"
  end
  
  local actionId = uiState.currentActionMap[buttonIndex]
  VOC.log("UI_VocationAction: actionId="..tostring(actionId))
  
  if not actionId then
    VOC.log("UI_VocationAction: No actionId found for button "..tostring(buttonIndex))
    safeBroadcastToColor("This action is not available. Button "..tostring(buttonIndex).." has no action mapped.", color, {1,0.6,0.2})
    return false, "No action for button "..buttonIndex
  end
  
  VOC.log("UI_VocationAction: Executing action "..tostring(actionId).." for "..tostring(color))
  
  -- Close the vocation explanation UI so player can see the die roll
  -- Use pcall to safely call hideSummaryUI in case of scoping issues
  pcall(function()
    if hideSummaryUI then
      hideSummaryUI()
    else
      -- Fallback: directly hide the UI panels
      if UI then
        UI.setAttribute("vocationSummaryPanel", "active", "false")
        UI.setAttribute("selectionCardPanel", "active", "false")
        if uiState then
          uiState.currentScreen = "selection"
          uiState.previewedVocation = nil
          uiState.previewedVocationOwner = nil
        end
      end
    end
  end)
  
  local result = executeVocationActionById(actionId, params)
  -- Persist state after Good Karma actions (avoids "attempt to call nil value" when saveState/self is nil in action's chunk)
  if result and self and self.call and (actionId == "SW_L1_USE_GOOD_KARMA" or actionId == "NGO_L1_TAKE_GOOD_KARMA") then
    pcall(function() self.call("VOC_SaveState", {}) end)
  end
  return result
end

-- Called by Event Engine when a player chooses a vocation side on a Vocation Event card.
-- params: { playerColor, actionId }
function RunVocationEventCardAction(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then print("[VOC_CTRL][FATAL] VOC namespace missing in this chunk") return false, "VOC nil" end
  if not params or not params.playerColor or not params.actionId then
    pcall(function() broadcastToAll("Vocation Event: missing playerColor or actionId.", {1,0.6,0.2}) end)
    return false, "Missing params"
  end
  local color = (VOC.normalizeColor and VOC.normalizeColor(params.playerColor)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params.playerColor))
  if not color then
    pcall(function() broadcastToAll("Vocation Event: invalid player color.", {1,0.6,0.2}) end)
    return false, "Invalid color"
  end
  local actionParams = {
    color = color,
    effectsTarget = color,
  }
  local result = executeVocationActionById(params.actionId, actionParams)
  if result and self and self.call and (params.actionId == "SW_L1_USE_GOOD_KARMA" or params.actionId == "NGO_L1_TAKE_GOOD_KARMA") then
    pcall(function() self.call("VOC_SaveState", {}) end)
  end
  return result
end

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


-- Define hideSummaryUI (forward-declared earlier)
hideSummaryUI = function()
  if not UI then 
    VOC.log("hideSummaryUI: UI is nil")
    return 
  end
  pcall(function()
    VOC.log("hideSummaryUI: Setting vocationSummaryPanel active=false")
    UI.setAttribute("vocationSummaryPanel", "active", "false")
    UI.setAttribute("selectionCardPanel", "active", "false")
  end)
  
  -- Defensive: check uiState exists before indexing
  if uiState then
    uiState.currentScreen = "selection"
    uiState.previewedVocation = nil
    uiState.previewedVocationOwner = nil
  else
    VOC.log("hideSummaryUI: WARNING - uiState is nil, cannot clear state")
  end
end

-- Hide the Vocation Selection UI panel
local function hideSelectionUI()
  if not UI then 
    VOC.log("hideSelectionUI: UI is nil")
    return 
  end
  pcall(function()
    VOC.log("hideSelectionUI: Setting vocationSelectionPanel active=false")
    UI.setAttribute("vocationSelectionPanel", "active", "false")
    -- Also hide overlay to completely close UI
    UI.setAttribute("vocationOverlay", "active", "false")
    local verify = UI.getAttribute("vocationSelectionPanel", "active")
    VOC.log("hideSelectionUI: Verified active=" .. tostring(verify))
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
    VOC.log("ERROR: UI system not available - UI is nil. Check that VocationsUI_Global.xml is in Global → UI tab.")
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
      VOC.log("ERROR: Panel 'vocationSelectionPanel' not found! UI XML may not be loaded in Global → UI tab.")
      VOC.log("ERROR: testOk=" .. tostring(testOk) .. ", testAttr=" .. tostring(testAttr) .. ", testErr=" .. tostring(testErr))
      error("UI panel 'vocationSelectionPanel' not found. Please check that VocationsUI_Global.xml is pasted into Global → UI tab.")
    end
    
    VOC.log("DEBUG: Panel exists! Current active state: " .. tostring(testAttr))
    
    -- CRITICAL: Verify overlay exists before activating
    local overlayTest = nil
    local overlayTestOk, overlayTestErr = pcall(function()
      overlayTest = UI.getAttribute("vocationOverlay", "active")
    end)
    
    if not overlayTestOk or overlayTest == nil then
      VOC.log("ERROR: Overlay 'vocationOverlay' not found! UI XML structure may be incorrect.")
      error("Overlay 'vocationOverlay' not found. Please check VocationsUI_Global.xml structure.")
    end
    
    VOC.log("DEBUG: Overlay found! Current active state: " .. tostring(overlayTest))
    
    -- Show overlay first (contains Cancel button and all panels)
    UI.setAttribute("vocationOverlay", "active", "true")
    VOC.log("DEBUG: Overlay activated")
    
    -- Set panel to active
    UI.setAttribute("vocationSelectionPanel", "active", "true")
    VOC.log("DEBUG: Selection panel activated")
    
    -- Hide other panels
    UI.setAttribute("vocationSummaryPanel", "active", "false")
    UI.setAttribute("sciencePointsPanel", "active", "false")
    
    -- Verify it was set
    local verifyOverlay = UI.getAttribute("vocationOverlay", "active")
    local verifyAttr = UI.getAttribute("vocationSelectionPanel", "active")
    VOC.log("DEBUG: Overlay active=" .. tostring(verifyOverlay) .. ", Panel active=" .. tostring(verifyAttr))
    
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
        local fn = (type(getSciencePointsForColor) == "function" and getSciencePointsForColor)
          or (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.getSciencePointsForColor) == "function" and _G.VOC_CTRL.getSciencePointsForColor)
        sciencePoints = (type(fn) == "function" and fn(color)) or 0
      end
      UI.setAttribute("selectionSciencePoints", "text", "Science Points: " .. tostring(sciencePoints))
      UI.setAttribute("selectionSciencePoints", "active", "true")
      UI.setAttribute("selectionKnowledgeSkillLine", "active", "false")
      VOC.log("DEBUG: Set subtitle to: Player: " .. color .. " | Science Points=" .. tostring(sciencePoints))
    else
      -- Youth (round 1 or round 6): show Knowledge • Skills on one line
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
      UI.setAttribute("selectionKnowledgeSkillLine", "text", "Knowledge: " .. tostring(k) .. "  •  Skills: " .. tostring(s))
      UI.setAttribute("selectionKnowledgeSkillLine", "active", "true")
      VOC.log("DEBUG: Set subtitle to: Player: " .. color .. " | Knowledge=" .. tostring(k) .. " Skills=" .. tostring(s))
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
        VOC.log("DEBUG: Disabled button: " .. btnId)
      else
        -- For buttons with images, don't set color (it tints the image)
        -- Keep images natural by not setting color attribute
        uiSet(btnId, "interactable", "true")
        UI.setAttribute(btnId, "opacity", "1.0")
        VOC.log("DEBUG: Enabled button: " .. btnId)
      end
    end
  end)
  
  if not ok then
    VOC.log("ERROR: Failed to show selection UI: " .. tostring(err))
    
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
      VOC.log("DEBUG: Final panel active check (after 0.1s): " .. tostring(finalCheck))
      if finalCheck ~= "true" then
        VOC.log("WARNING: Panel active state is not 'true'! It is: " .. tostring(finalCheck))
        broadcastToAll("⚠️ UI panel may not be visible. Check UI XML is loaded in Global → UI tab.", {1, 0.5, 0.2})
      end
    end
  end, 0.1)
  
  uiState.activeColor = color
  selectionState.activeColor = color  -- Also set selectionState for consistency
  uiState.currentScreen = "selection"
  VOC.log("Selection UI shown for " .. color .. " (both uiState and selectionState set)")
  return true
end

-- Show the Vocation Summary UI panel
-- forColor: when viewer is White, use this color's level for action buttons (e.g. from clicked tile's board)
local function showSummaryUI(color, vocation, previewOnly, forColor)
  VOC.log("=== showSummaryUI CALLED ===")
  VOC.log("color: " .. tostring(color) .. ", vocation: " .. tostring(vocation) .. ", previewOnly: " .. tostring(previewOnly) .. ", forColor: " .. tostring(forColor))
  
  if not UI then
    VOC.log("ERROR: UI system not available - UI is nil")
    broadcastToAll("⚠️ UI system not available. Check Global UI XML.", {1, 0.3, 0.3})
    return false
  end
  
  color = normalizeColor(color)
  if not color or not vocation then 
    VOC.log("ERROR: Invalid color or vocation. color=" .. tostring(color) .. ", vocation=" .. tostring(vocation))
    return false 
  end
  
  local vocData = VOCATION_DATA[vocation]
  if not vocData then
    VOC.log("ERROR: No data for vocation: " .. tostring(vocation))
    return false
  end
  
  local level1 = vocData.levels[1]
  local level2 = vocData.levels[2]
  
  if not level1 then
    VOC.log("ERROR: No Level 1 data for vocation: " .. tostring(vocation))
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
  
  -- Work out who actually OWNS this vocation (if anyone) - declare outside pcall
  local ownerColor = nil
  for _, c in ipairs(COLORS) do
    if state.vocations[c] == vocation then
      ownerColor = c
      break
    end
  end
  local viewerColor = color
  
  -- Also check if the viewer's vocation matches (in case they're viewing their own)
  if not ownerColor and state.vocations[viewerColor] == vocation then
    ownerColor = viewerColor
    VOC.log("showSummaryUI: Viewer owns this vocation: "..tostring(viewerColor))
  end
  
  local ok, err = pcall(function()
    VOC.log("showSummaryUI: Setting UI attributes...")
    
    -- First, verify panels exist
    local testOk, testAttr = pcall(function()
      return UI.getAttribute("vocationSummaryPanel", "active")
    end)
    if not testOk or testAttr == nil then
      VOC.log("ERROR: Panel 'vocationSummaryPanel' not found! Check UI XML.")
      broadcastToAll("⚠️ UI panel not found. Check Global → UI tab.", {1, 0.3, 0.3})
      error("Panel 'vocationSummaryPanel' not found")
    end
    VOC.log("showSummaryUI: Panel exists, current active state: " .. tostring(testAttr))
    
    -- Show overlay if not already shown
    UI.setAttribute("vocationOverlay", "active", "true")
    VOC.log("showSummaryUI: Overlay set to active")
    
    -- Hide selection panel
    UI.setAttribute("vocationSelectionPanel", "active", "false")
    VOC.log("showSummaryUI: Selection panel set to inactive")
    
    -- Show summary panel
    UI.setAttribute("vocationSummaryPanel", "active", "true")
    VOC.log("showSummaryUI: Summary panel set to active")
    
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
      VOC.log("showSummaryUI: Set explanation image for " .. vocation)
    else
      VOC.log("WARNING: No image URL for vocation: " .. tostring(vocation))
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
    
    VOC.log("showSummaryUI: ownerColor="..tostring(ownerColor)..", viewerColor="..tostring(viewerColor)..", previewOnly="..tostring(previewOnly)..", vocation="..tostring(vocation))
    if viewerColor then
      VOC.log("showSummaryUI: state.vocations["..tostring(viewerColor).."]="..tostring(state.vocations[viewerColor]))
      VOC.log("showSummaryUI: state.levels["..tostring(viewerColor).."]="..tostring(state.levels[viewerColor] or "nil"))
    end
    
    -- "Show explanation" (read-only): hide Back/Confirm, show Exit.
    -- Selection / other flows: show Back/Confirm, hide Exit.
    VOC.log("showSummaryUI: previewOnly="..tostring(previewOnly))
    if previewOnly then
      UI.setAttribute("actionButtons", "active", "false")
      UI.setAttribute("btnExit", "active", "true")
      VOC.log("showSummaryUI: Preview mode - hiding actionButtons (Back/Confirm), showing Exit")
    else
      UI.setAttribute("actionButtons", "active", "true")
      UI.setAttribute("btnExit", "active", "false")
      VOC.log("showSummaryUI: Selection mode - showing actionButtons (Back/Confirm), hiding Exit")
    end

    -- Configure vocation action buttons:
    -- - Use the LEVEL OF THE PLAYER WHO OWNS THIS VOCATION (so the button matches their card level).
    -- - When White is viewing: if we know the owner, use owner's level; else level 3 for testing.
    -- - When owner is viewing: use viewer's level (the person looking at the screen).
    local shouldShowActions = false
    local levelToUse = 1
    
    if viewerColor == "White" then
      -- White (e.g. host) viewing: use forColor's level if provided (e.g. tile on that board was clicked),
      -- else owner's level, else level 3 for testing.
      forColor = forColor and normalizeColor(forColor)
      if forColor and state.levels and state.levels[forColor] then
        levelToUse = state.levels[forColor] or 1
        shouldShowActions = true
        VOC.log("showSummaryUI: White viewer - using forColor "..tostring(forColor).." level="..tostring(levelToUse))
      elseif ownerColor then
        levelToUse = state.levels[ownerColor] or 1
        shouldShowActions = true
        VOC.log("showSummaryUI: White viewer - using owner "..tostring(ownerColor).." level="..tostring(levelToUse))
      else
        levelToUse = 3
        shouldShowActions = true
        VOC.log("showSummaryUI: White viewer - no forColor/owner, showing level 3 for testing")
      end
    elseif ownerColor then
      -- Check if viewer is the owner OR if no owner color was found but viewer has this vocation
      local isOwner = (viewerColor == ownerColor) or (state.vocations[viewerColor] == vocation)
      if isOwner then
        -- Owner viewing their own vocation - use VIEWER's level (the person at the screen)
        levelToUse = state.levels[viewerColor] or 1
        shouldShowActions = true
        VOC.log("showSummaryUI: Owner viewing own vocation - level="..tostring(levelToUse).." (viewer="..tostring(viewerColor)..")")
      else
        VOC.log("showSummaryUI: Viewer is not owner - hiding buttons (owner="..tostring(ownerColor)..", viewer="..tostring(viewerColor)..")")
      end
    else
      VOC.log("showSummaryUI: No owner found - hiding buttons (viewer="..viewerColor..")")
    end
    
    if shouldShowActions then
      local actions = getVocationActions(vocation, levelToUse, ownerColor)
      -- Public Servant: hide perk buttons once they already have that card on their board
      if vocation == VOC_PUBLIC_SERVANT and ownerColor then
        local shopEngine = nil
        for _, o in ipairs(VOC.getAllObjectsSafe()) do
          if o and o.hasTag and o.hasTag("WLB_SHOP_ENGINE") and o.call then shopEngine = o break end
        end
        if shopEngine then
          local okH, hasH = pcall(function() return shopEngine.call("API_hasHealthMonitorAccess", { color = ownerColor }) end)
          if okH and hasH then
            for i = #actions, 1, -1 do
              if actions[i].actionId == "PS_PERK_HEALTH_MONITOR_ACCESS" then table.remove(actions, i) break end
            end
          end
          local okA, hasA = pcall(function() return shopEngine.call("API_hasAlarmAccess", { color = ownerColor }) end)
          if okA and hasA then
            for i = #actions, 1, -1 do
              if actions[i].actionId == "PS_PERK_ALARM_ACCESS" then table.remove(actions, i) break end
            end
          end
          local okC, hasC = pcall(function() return shopEngine.call("API_hasCarAccess", { color = ownerColor }) end)
          if okC and hasC then
            for i = #actions, 1, -1 do
              if actions[i].actionId == "PS_PERK_CAR_ACCESS" then table.remove(actions, i) break end
            end
          end
        end
      end
      VOC.log("showSummaryUI: getVocationActions returned "..#actions.." actions for vocation="..tostring(vocation)..", level="..levelToUse)
      updateActionButtons(actions)
      UI.setAttribute("vocationActionButtons", "active", "true")
      VOC.log("showSummaryUI: Showing action buttons for "..viewerColor.." (vocation="..tostring(vocation)..", level="..levelToUse..", actions="..#actions..")")
    else
      UI.setAttribute("vocationActionButtons", "active", "false")
      VOC.log("showSummaryUI: Hiding action buttons (viewer="..viewerColor..", owner="..tostring(ownerColor)..")")
    end

    -- Public Servant: show tax waiver status (non-clickable text). Add a Text element in Global UI with id "summaryTaxWaiverStatus".
    local taxWaiverColor = ownerColor or viewerColor
    if vocation == VOC_PUBLIC_SERVANT and taxWaiverColor then
      local statusText = API_GetPublicServantTaxWaiverStatus({ color = taxWaiverColor })
      pcall(function()
        UI.setAttribute("summaryTaxWaiverStatus", "text", statusText or "Tax obligation")
        UI.setAttribute("summaryTaxWaiverStatus", "active", "true")
      end)
    else
      pcall(function()
        UI.setAttribute("summaryTaxWaiverStatus", "active", "false")
      end)
    end

    -- Experience tokens: show count for vocations that use them (all except Celebrity). Use UI element "summaryExperienceTokens" if present.
    local showColor = ownerColor or viewerColor
    local vocationUsesExperience = (vocation == VOC_PUBLIC_SERVANT or vocation == VOC_SOCIAL_WORKER or vocation == VOC_NGO_WORKER or vocation == VOC_ENTREPRENEUR or vocation == VOC_GANGSTER)
    if showColor and vocationUsesExperience then
      local expCount = getExperienceTokenCount(showColor)
      local levelToShow = state.levels[showColor] or 1
      local vocData = VOCATION_DATA[vocation]
      local needExp = nil
      if vocData and vocData.levels and vocData.levels[levelToShow] and vocData.levels[levelToShow].promotion and vocData.levels[levelToShow].promotion.type == "standard" then
        needExp = vocData.levels[levelToShow].promotion.experience or 0
      end
      local expText = "Experience: " .. tostring(expCount)
      if needExp and needExp > 0 then expText = expText .. " (need " .. tostring(needExp) .. " for next level)" end
      pcall(function()
        UI.setAttribute("summaryExperienceTokens", "text", expText)
        UI.setAttribute("summaryExperienceTokens", "active", "true")
      end)
    else
      pcall(function()
        UI.setAttribute("summaryExperienceTokens", "active", "false")
      end)
    end

    -- Verify the panel is actually active (with delay to allow UI to update)
    Wait.time(function()
      local verify = UI.getAttribute("vocationSummaryPanel", "active")
      VOC.log("showSummaryUI: Verified summary panel active=" .. tostring(verify) .. " (after 0.1s)")
      if verify ~= "true" then
        VOC.log("WARNING: Summary panel active state is not 'true'! It is: " .. tostring(verify))
        broadcastToAll("⚠️ Summary panel may not be visible. Check UI XML.", {1, 0.7, 0.2})
      else
        VOC.log("✅ Summary panel is ACTIVE - should be visible now!")
      end
    end, 0.1)
  end)
  
  if not ok then
    VOC.log("ERROR: showSummaryUI pcall failed: " .. tostring(err))
    broadcastToAll("❌ showSummaryUI error: " .. tostring(err), {1, 0.3, 0.3})
    return false
  end
  
  uiState.currentScreen = "summary"
  uiState.previewedVocation = vocation
  -- Store the OWNER's color (who actually owns this vocation), not the viewer
  uiState.previewedVocationOwner = ownerColor  -- ownerColor was determined earlier
  VOC.log("Summary UI shown for viewer=" .. color .. ", owner=" .. tostring(ownerColor) .. ", vocation=" .. vocation)
  return true
end

-- Hide the Vocation Summary UI panel (duplicate removed - already defined earlier)

-- =========================================================
-- SELECTION UI FUNCTIONS (Legacy - physical tiles)
-- =========================================================

function findSummaryTileForVocation(vocation)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return nil end
  local summaryTag = "WLB_VOC_SUMMARY_" .. vocation
  local allObjects = VOC.getAllObjectsSafe and VOC.getAllObjectsSafe() or {}
  
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
  local allObjects = VOC.getAllObjectsSafe()
  local totalChecked = 0
  local foundWithBaseTag = 0
  local foundWithLevelTag = 0
  local excludedWithColorTag = 0
  
  VOC.log("Searching for Level 1 vocation tiles...")
  
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
            VOC.log("Found available Level 1 tile: " .. name)
          end
        end
      end
    end
  end
  
  VOC.log("Tile search results:")
  VOC.log("  Total objects checked: " .. totalChecked)
  VOC.log("  Objects with WLB_VOCATION_TILE tag: " .. foundWithBaseTag)
  VOC.log("  Objects with WLB_VOC_LEVEL_1 tag: " .. foundWithLevelTag)
  VOC.log("  Excluded (have color tag): " .. excludedWithColorTag)
  VOC.log("  Available tiles found: " .. #tiles)
  
  return tiles
end

local function removeAllButtons(tile)
  if not tile or not tile.clearButtons then return end
  pcall(function() tile.clearButtons() end)
end

local function positionSelectionTiles(tiles)
  if #tiles == 0 then 
    VOC.log("No tiles to position")
    return 
  end
  
  VOC.log("Positioning " .. #tiles .. " selection tiles in center")
  
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
      
      VOC.log("Positioning tile " .. i .. " at " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
      
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
            VOC.log("Flipped tile " .. i .. " face up")
          end
        end)
      end
      
      -- Small delay between positioning for smoother animation
      Wait.time(function() end, i * 0.1)
    else
      VOC.log("Warning: Tile " .. i .. " is invalid or missing setPositionSmooth")
    end
  end
  
  VOC.log("Finished positioning " .. #tiles .. " tiles")
end

-- =========================================================
-- LEVEL 1 CARDS: place next to controller, return on cleanup
-- =========================================================
function VOC_ReturnLevel1Cards()
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  for _, card in ipairs(selectionState.level1Cards or {}) do
    if card and not card.isDestroyed and card.clearContextMenu then
      pcall(function() card.clearContextMenu() end)
    end
  end
  for guid, pos in pairs(selectionState.level1OriginalPositions or {}) do
    local card = (VOC.getObjectFromGUID and VOC.getObjectFromGUID(guid)) or (getObjectFromGUID and getObjectFromGUID(guid))
    if card and card.setPositionSmooth and pos then
      pcall(function() card.setPositionSmooth(pos, false, true) end)
    end
  end
  selectionState.level1Cards = {}
  selectionState.level1OriginalPositions = {}
  if VOC.log then VOC.log("Level 1 cards returned") end
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
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return false end
  if not self then return false end
  color = (VOC.normalizeColor and VOC.normalizeColor(color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(color)) or nil
  if not color then
    if VOC.log then VOC.log("Invalid color") end
    return false
  end

  -- Return any Level 1 cards from a previous selection (cleanup)
  VOC_ReturnLevel1Cards()

  selectionState.activeColor = color
  selectionState.shownVocation = nil
  selectionState.shownSummary = nil
  selectionState.shownExplanationCard = nil

  if VOC.log then VOC.log("Showing vocation selection menu (VOCATION_IMAGES + buttons) for " .. color) end

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

  if VOC.log then VOC.log("Vocation selection menu: " .. buttonCount .. " vocation buttons") end
  return true
end

-- Called when player picks a vocation from a Level 1 card (context menu)
function VOC_ChoseFromCard(params)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  local vocation = params and params.vocation
  local color = (VOC.normalizeColor and VOC.normalizeColor(params and params.color)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(params and params.color)) or nil
  local activeColor = selectionState.activeColor

  if not activeColor or color ~= activeColor then
    broadcastToAll("Only " .. tostring(activeColor) .. " can choose a vocation right now.", {1, 0.5, 0.2})
    return
  end
  if not vocation then return end

  if VOC.log then VOC.log("VOC_ChoseFromCard: " .. tostring(color) .. " chose " .. tostring(vocation)) end

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

  local card = VOC.getObjectFromGUID(guid)
  if not card or not card.setPositionSmooth then
    VOC.log("Explanation card not found for " .. vocation .. " (GUID: " .. tostring(guid) .. ")")
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

  VOC.log("Showing explanation card for " .. vocation .. " (GUID: " .. guid .. ")")
  return true
end

function VOC_HideExplanationCard()
  if not selectionState.shownExplanationCard then return end
  local card = selectionState.shownExplanationCard
  card.setPositionSmooth(STORAGE_EXPLANATION, false, true)
  selectionState.shownExplanationCard = nil
  selectionState.shownVocation = nil
  VOC.log("Explanation card returned to storage")
end

-- Show vocation explanation in a different way than summoning the physical card:
-- uses Global UI summary panel (image + details) or broadcasts perks text to the player.
function VOC_ShowExplanationForPlayer(params)
  local vocation = params and params.vocation
  local color = normalizeColor(params and params.color)
  if not vocation or not color then
    VOC.log("VOC_ShowExplanationForPlayer: missing vocation or color")
    return false
  end
  if not VOCATION_DATA[vocation] then
    VOC.log("VOC_ShowExplanationForPlayer: unknown vocation " .. tostring(vocation))
    return false
  end
  -- Prefer Global UI summary panel (on-screen, no physical card). When from "Show explanation" use previewOnly so only Exit is shown.
  if showSummaryUI and UI then
    local previewOnly = not not (params and params.previewOnly)
    local forColor = params and params.forColor and normalizeColor(params.forColor)
    local ok = showSummaryUI(color, vocation, previewOnly, forColor)
    if ok then
      VOC.log("VOC_ShowExplanationForPlayer: showed summary UI for " .. vocation .. " to " .. color)
      return true
    end
  end
  -- Fallback: broadcast perks text to that player (when Global UI not available)
  local vocationName = VOCATION_DATA[vocation].name or vocation
  local perksText = getPerksText(vocation)
  safeBroadcastToColor(vocationName, color, {0.4, 0.6, 1})
  safeBroadcastToColor(perksText or "No data", color, {0.9, 0.9, 0.95})
  VOC.log("VOC_ShowExplanationForPlayer: broadcast perks text to " .. color)
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
  local list = VOC.getAllObjectsSafe()
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag("WLB_VOCATIONS_CTRL") then ctrl = o; break end
  end
  if ctrl and ctrl.call then
    ctrl.call("VOC_ShowExplanationForPlayer", { vocation = vocation, color = color })
  end
end

-- Global: called when the invisible LMB button on a vocation tile (on player board) is left-clicked.
-- Shows the same explanation UI as "Show explanation" (read-only). Works even when the tile is locked.
-- When White (host) clicks, we pass forColor from the tile's board tag so the correct character level is shown.
function VOC_VocationTileClicked(obj, player_color, alt_click)
  if not obj or not obj.hasTag or type(obj.hasTag) ~= "function" then return end
  local vocation = nil
  for _, voc in ipairs(ALL_VOCATIONS) do
    if obj.hasTag("WLB_VOC_" .. voc) then vocation = voc; break end
  end
  if not vocation then return end
  player_color = normalizeColor(player_color)
  if not player_color then return end
  -- When White is clicking, determine which board's tile this is so we show that character's level
  local forColor = nil
  if player_color == "White" then
    for _, c in ipairs(COLORS) do
      if obj.hasTag(colorTag(c)) then forColor = c; break end
    end
  end
  VOC_ShowExplanationForPlayer({ vocation = vocation, color = player_color, previewOnly = true, forColor = forColor })
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
        if p.experience then table.insert(lines, "  Experience: " .. p.experience .. " tokens") end
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

  VOC.log("Showing perks for " .. vocation)
  return true
end

-- Called from "Go Back" button: return to vocation grid
function VOC_BackToSelection(obj, color, alt_click)
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  if selectionState.shownExplanationCard then
    VOC_HideExplanationCard()
  end
  selectionState.shownVocation = nil
  selectionState.shownSummary = nil
  local activeColor = selectionState.activeColor
  if not activeColor then return end
  VOC_ShowSelectionUI(activeColor)
  if VOC.log then VOC.log("Back to selection grid for " .. activeColor) end
end

-- =========================================================
-- BUTTON-BASED SELECTION UI (No physical tile movement)
-- =========================================================
local function showSelectionButtons(color)
  if not self or not self.clearButtons then
    VOC.log("Error: Cannot show buttons - self is invalid")
    return
  end
  
  -- NOTE: Don't clear buttons here - it removes debug buttons!
  -- Only clear if we're using physical buttons (legacy mode)
  -- For UI mode, we don't need to clear controller buttons
  -- self.clearButtons()  -- DISABLED: This was removing debug buttons
  
  VOC.log("Showing selection buttons for " .. color)
  
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
      
      VOC.log("Created button for: " .. vocBtn.name .. " (" .. vocBtn.id .. ")")
      buttonCount = buttonCount + 1
    else
      VOC.log("Skipping " .. vocBtn.name .. " - already taken")
    end
  end
  
  VOC.log("Finished creating " .. buttonCount .. " vocation buttons")
end

function VOC_StartSelection(params)
  local color = normalizeColor(params.color)
  if not color then return false, "Invalid color" end
  
  local points = params and params.points or 0
  
  print("[VOC] StartSelection on GUID="..self.getGUID().." color="..tostring(color).." points="..tostring(points))
  
  -- Check if already has vocation
  if state.vocations[color] then
    VOC.log("Player " .. color .. " already has a vocation")
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
      VOC.log("Global UI selection started for " .. color)
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
  VOC.log("Button Selection started for " .. color)
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
  local VOC = _G.VOC or (_G.WLB and _G.WLB.VOC) or nil
  if not VOC then return end
  local selectingColor = selectionState.activeColor
  if not selectingColor then
    if VOC.log then VOC.log("No active selection - button clicked out of turn") end
    return
  end
  
  clickerColor = (VOC.normalizeColor and VOC.normalizeColor(clickerColor)) or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(clickerColor)) or nil
  if clickerColor ~= selectingColor then
    if VOC.log then VOC.log("Wrong player clicked. Active: " .. tostring(selectingColor) .. ", Clicked: " .. tostring(clickerColor)) end
    broadcastToAll("Only " .. selectingColor .. " can choose a vocation right now.", {1, 0.5, 0.2})
    return
  end
  
  if VOC.log then VOC.log("Vocation button clicked: " .. vocation .. " by " .. tostring(clickerColor)) end
  
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
    VOC.log("Could not determine vocation from tile")
    return
  end
  
  -- Show summary for this vocation
  VOC_ShowSummary({vocation=vocation, color=color})
end

function VOC_ShowSummary(params)
  local vocation = params.vocation
  local color = normalizeColor(params.color)
  
  if not vocation or not color then
    VOC.log("Invalid parameters for ShowSummary")
    return false
  end
  
  -- Hide any previously shown summary
  if selectionState.shownSummary then
    VOC_HideSummary({color=color})
  end
  
  -- Find summary tile
  local summaryTile = findSummaryTileForVocation(vocation)
  if not summaryTile then
    VOC.log("Summary tile not found for " .. vocation)
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
  
  VOC.log("Summary shown for " .. vocation .. " to " .. color)
  
  return true
end

function VOC_ConfirmSelection(obj, color, alt_click)
  -- Get vocation and color from selection state
  local vocation = selectionState.shownVocation
  local selectingColor = selectionState.activeColor
  
  if not vocation or not selectingColor then
    VOC.log("Warning: Could not get vocation from selection state")
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

-- CHUNK-SAFE: delegate to VOC.findTurnCtrl (getAllObjects may be nil in some TTS chunks)
function findTurnController()
  return VOC.findTurnCtrl()
end
if not _G.VOC_CTRL then _G.VOC_CTRL = {} end
_G.VOC_CTRL.findTurnController = findTurnController

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
  
  VOC.log("Summary hidden for " .. actualColor)
  
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
  
  VOC.log("Selection cleaned up for " .. color)

  -- Restore debug buttons so players can test again after selection or restart
  pcall(function()
    if createDebugButtons then
      createDebugButtons()
      VOC.log("Debug buttons restored after cleanup")
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
  VOC.log("Recovering vocation tiles...")
  
  -- Find all Level 1 tiles (including those with color tags)
  local allObjects = VOC.getAllObjectsSafe()
  local tiles = {}
  
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and
       (obj.hasTag(TAG_VOCATION_TILE) or obj.hasTag("WLB_VOCATION_TILE")) and
       obj.hasTag("WLB_VOC_LEVEL_1") then
      table.insert(tiles, obj)
      local name = obj.getName and obj.getName() or "Unknown"
      VOC.log("Found tile: " .. name)
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
      VOC.log("Recovered: " .. name .. " to " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
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
  
  VOC.log("=== UI_SelectVocation CALLED IN VOCATIONSCONTROLLER ===")
  VOC.log("player/color: " .. tostring(player))
  VOC.log("player type: " .. type(player))
  VOC.log("value: " .. tostring(value))
  VOC.log("id: " .. tostring(id))
  VOC.log("uiState.activeColor: " .. tostring(uiState.activeColor))
  VOC.log("selectionState.activeColor: " .. tostring(selectionState.activeColor))
  
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
    VOC.log("ERROR: Missing color or id. color=" .. tostring(color) .. ", id=" .. tostring(id))
    return
  end
  
  VOC.log("Normalized color: " .. color)
  
  -- Special handling for "White" (spectator) - try to use active color instead
  if color == "White" then
    VOC.log("WARNING: Click detected from White (spectator). Attempting to use active color instead.")
    color = selectionState.activeColor or uiState.activeColor
    if not color then
      VOC.log("ERROR: No active selection and clicked as White spectator!")
      broadcastToAll("⚠ Please sit at a player color seat to select a vocation.", {1, 0.5, 0.2})
      return
    end
    VOC.log("Using active color instead: " .. color)
  end
  
  -- Check if selection is active
  local activeColor = selectionState.activeColor or uiState.activeColor
  if not activeColor then
    local reason = "selection not active (activeColor=nil)"
    uiState = uiState or {}
    uiState.lastRejectReason = reason
    print("[VOC][REJECT] "..reason)
    VOC.log("ERROR: No active selection! selectionState.activeColor=" .. tostring(selectionState.activeColor) .. ", uiState.activeColor=" .. tostring(uiState.activeColor))
    broadcastToAll("⚠ Vocation selection is not active. Please start selection first.", {1, 0.5, 0.2})
    return false, reason
  end
  
  -- Verify it's the active player
  if color ~= activeColor then
    VOC.log("UI_SelectVocation: Wrong player clicked. Active: " .. tostring(activeColor) .. ", Clicked: " .. color)
    safeBroadcastToColor("⚠ It's not your turn to select a vocation! Active player: " .. tostring(activeColor), color, {1, 0.5, 0.2})
    return
  end
  
  -- Map button ID to vocation constant
  -- Note: Button IDs in XML are like "btnPublicServant", "btnCelebrity", etc.
  local vocation = nil
  local idLower = string.lower(id or "")
  VOC.log("Button ID (lowercase): " .. idLower)
  
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
    VOC.log("ERROR: Unknown button ID: " .. tostring(id) .. " (lowercase: " .. idLower .. ")")
    safeBroadcastToColor("⚠ Unknown vocation button clicked. ID: " .. tostring(id), color, {1, 0.3, 0.3})
    return
  end
  
  VOC.log("Mapped to vocation: " .. tostring(vocation))
  
  -- Check if already taken
  for _, c in ipairs(COLORS) do
    if state.vocations[c] == vocation and c ~= color then
      VOC.log("Vocation already taken by: " .. c)
      safeBroadcastToColor("⚠ This vocation is already taken by " .. c .. "!", color, {1, 0.5, 0.2})
      return
    end
  end
  
  -- Show summary
  VOC.log("Calling showSummaryUI for " .. color .. " -> " .. vocation)
  local ok = showSummaryUI(color, vocation)
  if ok then
    VOC.log("showSummaryUI returned true - summary should be visible")
    safeBroadcastToColor("✅ Showing vocation summary...", color, {0.3, 1, 0.3})
  else
    VOC.log("ERROR: showSummaryUI returned false")
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
    VOC.log("WARNING: Confirm click detected from White (spectator). Attempting to use active color instead.")
    color = activeColor
    if not color then
      VOC.log("ERROR: Confirm clicked as White but no active color is set")
      broadcastToAll("⚠ Please sit at a player color seat (Yellow/Blue/Red/Green) to confirm.", {1, 0.5, 0.2})
      return
    end
    VOC.log("Using active color instead for confirm: " .. tostring(color))
  end
  
  if not color then return end
  
  -- Verify it's the active player (use combined active so 2nd player works when uiState was cleared on another object)
  if not activeColor then
    VOC.log("UI_ConfirmVocation: No active selection (activeColor=nil). selectionState.activeColor=" .. tostring(selectionState.activeColor) .. " uiState.activeColor=" .. tostring(uiState.activeColor) .. " currentPickerColor=" .. tostring(state.currentPickerColor))
    broadcastToAll("⚠ Vocation selection is not active. Please start selection first.", {1, 0.5, 0.2})
    return
  end
  if color ~= activeColor then
    VOC.log("UI_ConfirmVocation: Wrong player. Active: " .. tostring(activeColor) .. ", Clicked: " .. tostring(color))
    return
  end
  
  local vocation = uiState.previewedVocation
  if not vocation then
    VOC.log("ERROR: No vocation previewed for confirmation")
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
    uiState.previewedVocationOwner = nil
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
    local fn = (type(getSciencePointsForColor) == "function" and getSciencePointsForColor)
      or (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.getSciencePointsForColor) == "function" and _G.VOC_CTRL.getSciencePointsForColor)
    local pool = (type(fn) == "function" and fn(color)) or 0
    local k, s = 0, 0
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
    VOC.log("UI_ConfirmVocation: Showing selection card for " .. vocation .. ", pool=" .. tostring(pool) .. " K=" .. k .. " S=" .. s)
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
  VOC.log("Vocation confirmed: " .. color .. " -> " .. vocation)
  
  -- Keep selection UI visible (selection card stays on screen); do not hide overlay/panels
  uiState.activeColor = nil
  uiState.currentScreen = nil
  uiState.previewedVocation = nil
  uiState.previewedVocationOwner = nil
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
    VOC.log("UI_AllocScience: TurnController not found")
    return
  end

  local ok = pcall(function()
    return turnCtrl.call("API_AllocScience", { color = color, which = which, delta = delta })
  end)
  if not ok then
    VOC.log("UI_AllocScience: API_AllocScience failed for " .. color .. " " .. which .. " " .. tostring(delta))
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
    VOC.log("UI_ApplyAllocScience: TurnController not found")
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
    VOC.log("WARNING: Back click detected from White (spectator). Attempting to use active color instead.")
    color = uiState.activeColor or selectionState.activeColor or state.currentPickerColor
    if not color then
      VOC.log("UI_BackToSelection: No active color available (clicked as White)")
      broadcastToAll("⚠ Please sit at a player color seat (Yellow/Blue/Red/Green) to go back.", {1, 0.5, 0.2})
      return
    end
    VOC.log("Using active color instead for back: " .. tostring(color))
  end
  
  if not color then 
    -- Try to get active color from state
    color = selectionState.activeColor or uiState.activeColor or state.currentPickerColor
    if not color then
      VOC.log("UI_BackToSelection: No color available")
      return
    end
  end
  
  -- Verify it's the active player (or allow if no active player set)
  if uiState.activeColor and color ~= uiState.activeColor then
    VOC.log("UI_BackToSelection: Wrong player. Active: " .. tostring(uiState.activeColor) .. ", Clicked: " .. tostring(color))
    return
  end
  
  -- Get science points for this color (chunk-safe)
  local fn = (type(getSciencePointsForColor) == "function" and getSciencePointsForColor)
    or (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.getSciencePointsForColor) == "function" and _G.VOC_CTRL.getSciencePointsForColor)
  local sciencePoints = (type(fn) == "function" and fn(color)) or 0
  
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
  uiState.previewedVocationOwner = nil
  VOC.log("Vocation explanation closed – UI hidden, back to playing")
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
  
  VOC.log("=== UI_CancelSelection CALLED ===")
  VOC.log("player/color: " .. tostring(player))
  VOC.log("value: " .. tostring(value))
  VOC.log("id: " .. tostring(id))
  
  -- Extract color - handle both string (new) and Player object (old/direct)
  local color = nil
  if type(player) == "string" then
    color = normalizeColor(player)
  else
    color = normalizeColor(player and player.color or nil)
  end
  
  if not color then 
    VOC.log("WARNING: No color parameter, but continuing with cancel anyway")
  end
  VOC.log("Normalized color: " .. tostring(color))
  VOC.log("Current activeColor: " .. tostring(uiState.activeColor))
  
  -- Allow any player to cancel (remove restriction for now)
  -- if color ~= uiState.activeColor and uiState.activeColor ~= nil then
  --   VOC.log("UI_CancelSelection: Wrong player. Active: " .. tostring(uiState.activeColor) .. ", Clicked: " .. color)
  --   return
  -- end
  
  VOC.log("Hiding UI panels...")
  
  -- Hide all UI - direct kill switch approach
  if UI then
    pcall(function()
      VOC.log("Setting vocationSelectionPanel active=false")
      UI.setAttribute("vocationSelectionPanel", "active", "false")
      VOC.log("Setting vocationSummaryPanel active=false")
      UI.setAttribute("vocationSummaryPanel", "active", "false")
      VOC.log("Setting sciencePointsPanel active=false")
      UI.setAttribute("sciencePointsPanel", "active", "false")
      VOC.log("Setting vocationOverlay active=false")
      UI.setAttribute("vocationOverlay", "active", "false")
    end)
  else
    VOC.log("ERROR: UI is nil!")
  end
  
  hideSummaryUI()
  hideSelectionUI()
  
  -- Reset UI state
  uiState.activeColor = nil
  uiState.currentScreen = nil
  uiState.previewedVocation = nil
  uiState.previewedVocationOwner = nil
  
  VOC.log("Vocation selection cancelled by " .. tostring(color))
  broadcastToAll("Vocation selection cancelled", {0.7, 0.7, 0.7})
  
  VOC.log("=== UI_CancelSelection COMPLETE ===")
end

-- Updated VOC_StartSelection to use UI instead of buttons
function VOC_StartSelection_UI(params)
  local color = normalizeColor(params.color)
  if not color then return false, "Invalid color" end
  
  -- Check if already has vocation
  if state.vocations[color] then
    VOC.log("Player " .. color .. " already has a vocation")
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
  
  VOC.log("UI Selection started for " .. color)
  return true
end

-- =========================================================
-- RESOLVE INTERACTION (callable from die callback to avoid chunking)
-- =========================================================
function ResolveInteractionEffectsWithDie(params)
  if not params or not params.id then return end
  local id, initiator, die = params.id, params.initiator, params.die
  if type(resolveInteractionEffectsWithDie) == "function" then
    resolveInteractionEffectsWithDie(id, initiator, die)
  else
    VOC.warn("ResolveInteractionEffectsWithDie: resolver not available")
  end
end

-- =========================================================
-- INTERACTION UI CALLBACKS (JOIN / IGNORE)
-- =========================================================

function UI_Interaction_YellowJoin(params)
  local actor = params and params.playerColor
  if self and self.call then
    pcall(function() self.call("HandleInteractionResponse", { buttonColor = "Yellow", choice = "JOIN", actorColor = actor }) end)
  elseif type(handleInteractionResponse) == "function" then
    handleInteractionResponse("Yellow", "JOIN", actor)
  else
    VOC.warn("UI_Interaction_YellowJoin: HandleInteractionResponse not available")
  end
end

function UI_Interaction_YellowIgnore(params)
  local actor = params and params.playerColor
  if self and self.call then
    pcall(function() self.call("HandleInteractionResponse", { buttonColor = "Yellow", choice = "IGNORE", actorColor = actor }) end)
  elseif type(handleInteractionResponse) == "function" then
    handleInteractionResponse("Yellow", "IGNORE", actor)
  end
end

function UI_Interaction_BlueJoin(params)
  local actor = params and params.playerColor
  if self and self.call then
    pcall(function() self.call("HandleInteractionResponse", { buttonColor = "Blue", choice = "JOIN", actorColor = actor }) end)
  elseif type(handleInteractionResponse) == "function" then
    handleInteractionResponse("Blue", "JOIN", actor)
  end
end

function UI_Interaction_BlueIgnore(params)
  local actor = params and params.playerColor
  if self and self.call then
    pcall(function() self.call("HandleInteractionResponse", { buttonColor = "Blue", choice = "IGNORE", actorColor = actor }) end)
  elseif type(handleInteractionResponse) == "function" then
    handleInteractionResponse("Blue", "IGNORE", actor)
  end
end

function UI_Interaction_RedJoin(params)
  local actor = params and params.playerColor
  if self and self.call then
    pcall(function() self.call("HandleInteractionResponse", { buttonColor = "Red", choice = "JOIN", actorColor = actor }) end)
  elseif type(handleInteractionResponse) == "function" then
    handleInteractionResponse("Red", "JOIN", actor)
  end
end

function UI_Interaction_RedIgnore(params)
  local actor = params and params.playerColor
  if self and self.call then
    pcall(function() self.call("HandleInteractionResponse", { buttonColor = "Red", choice = "IGNORE", actorColor = actor }) end)
  elseif type(handleInteractionResponse) == "function" then
    handleInteractionResponse("Red", "IGNORE", actor)
  end
end

function UI_Interaction_GreenJoin(params)
  local actor = params and params.playerColor
  if self and self.call then
    pcall(function() self.call("HandleInteractionResponse", { buttonColor = "Green", choice = "JOIN", actorColor = actor }) end)
  elseif type(handleInteractionResponse) == "function" then
    handleInteractionResponse("Green", "JOIN", actor)
  end
end

function UI_Interaction_GreenIgnore(params)
  local actor = params and params.playerColor
  if self and self.call then
    pcall(function() self.call("HandleInteractionResponse", { buttonColor = "Green", choice = "IGNORE", actorColor = actor }) end)
  elseif type(handleInteractionResponse) == "function" then
    handleInteractionResponse("Green", "IGNORE", actor)
  end
end

-- =========================================================
-- TEST BUTTON (for UI debugging) - Must be defined before onLoad
-- =========================================================
local function createTestButton()
  if not self or not self.createButton then
    VOC.log("WARNING: Cannot create test button - self.createButton not available")
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
    VOC.log("✅ Test button created on VocationsController")
  end)
end

-- Button click handler for UI test (must be global function)
function btnTestUI(obj, player)
  VOC.log("=== UI TEST BUTTON CLICKED ===")
  
  if not UI then
    broadcastToAll("❌ UI system not available (Global UI is nil)", {1, 0.3, 0.3})
    VOC.log("ERROR: UI is nil - UI XML must be in Global → UI tab")
    return
  end
  
  broadcastToAll("🔍 Testing UI system (Global UI)...", {0.5, 0.5, 1})
  VOC.log("UI system is available (Global UI), testing panels...")
  
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
  VOC.log("=== TEST RESULTS ===")
  VOC.log("Overlay (vocationOverlay):")
  VOC.log("  - testOverlayOk: " .. tostring(testOverlayOk))
  VOC.log("  - overlayAttr: " .. tostring(overlayAttr))
  VOC.log("  - overlayOk: " .. tostring(overlayOk))
  if overlayErr then VOC.log("  - ERROR: " .. overlayErr) end
  
  VOC.log("Panel 1 (vocationSelectionPanel):")
  VOC.log("  - test1Ok: " .. tostring(test1Ok))
  VOC.log("  - panel1Attr: " .. tostring(panel1Attr))
  VOC.log("  - panel1Ok: " .. tostring(panel1Ok))
  if panel1Err then VOC.log("  - ERROR: " .. panel1Err) end
  
  VOC.log("Panel 2 (vocationSummaryPanel):")
  VOC.log("  - test2Ok: " .. tostring(test2Ok))
  VOC.log("  - panel2Attr: " .. tostring(panel2Attr))
  VOC.log("  - panel2Ok: " .. tostring(panel2Ok))
  if panel2Err then VOC.log("  - ERROR: " .. panel2Err) end
  
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
        VOC.log("TEST: Overlay and Selection Panel activated")
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
    VOC.log("WARNING: Cannot create debug buttons - self.createButton not available")
    return
  end
  
  -- Don't clear buttons - we want to keep debug buttons visible
  -- Only clear if explicitly requested (for testing)
  -- if self.clearButtons then
  --   pcall(function() self.clearButtons() end)
  -- end
  
  -- Create debug buttons: 2 above, 3 below, 2 more below (to avoid covering test button and overlapping)
  local buttons = {
    -- Top row (above)
    { label = "TEST\nSELECTION", fn = "btnDebugStartSelection", pos = {-0.75, 0.6, 0}, color = {0.2, 0.6, 1.0} },
    { label = "TEST\nSUMMARY", fn = "btnDebugShowSummary", pos = {0.75, 0.6, 0}, color = {0.2, 1.0, 0.6} },
    -- Middle row
    { label = "TEST\nCALLBACK", fn = "btnDebugTestCallback", pos = {-0.75, 0.0, 0}, color = {1.0, 0.6, 0.2} },
    { label = "FULL\nTEST", fn = "btnDebugFullTest", pos = {0.0, 0.0, 0}, color = {0.8, 0.2, 0.8} },
    { label = "TEST\nSW L2 EVT", fn = "btnDebug_TestSWEvent", pos = {0.75, 0.0, 0}, color = {0.9, 0.3, 0.3} },
    -- Bottom row (level management)
    { label = "SHOW\nLEVELS", fn = "btnDebug_ShowLevels", pos = {-0.5, -0.6, 0}, color = {1.0, 1.0, 0.2} },
    { label = "SET\nLEVEL 1", fn = "btnDebug_SetLevel1", pos = {0.5, -0.6, 0}, color = {0.2, 1.0, 1.0} },
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
  
  VOC.log("✅ Debug buttons created on VocationsController")
end

function onLoad()
  print("[VOC_CTRL] LOADED refactor " .. os.date("%H:%M:%S"))
  ensureSelfTag()
  loadState()
  VOC.log("VocationsController v" .. VERSION .. " loaded")

  -- Create debug buttons immediately and again after a short delay so they appear after restart.
  -- (TTS may not have the object fully ready on first frame; delayed creation ensures visibility.)
  createDebugButtons()
  if Wait and Wait.time then
    Wait.time(function()
      if self and self.createButton and createDebugButtons then
        createDebugButtons()
        VOC.log("VocationsController: debug buttons created (delayed)")
      end
      -- Ensure vocation tiles on player boards have LMB button and lock (e.g. from saved game)
      if self and self.getGUID then
        local list = VOC.getAllObjectsSafe()
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
    VOC.log("ERROR: VOC_StartSelection function not defined!")
  else
    VOC.log("VOC_StartSelection function verified")
  end
  
  -- Verify UI XML is loaded (using Global UI)
  if UI then
    VOC.log("UI system is available (Global UI)")
    
    -- Test if panels exist
    local panel1Ok, panel1Attr = pcall(function()
      return UI.getAttribute("vocationSelectionPanel", "active")
    end)
    
    local panel2Ok, panel2Attr = pcall(function()
      return UI.getAttribute("vocationSummaryPanel", "active")
    end)
    
    if panel1Ok and panel1Attr ~= nil then
      VOC.log("✅ UI Panel 'vocationSelectionPanel' found and accessible (active=" .. tostring(panel1Attr) .. ")")
      pcall(function()
        UI.setAttribute("vocationSelectionPanel", "active", "false")
      end)
    else
      VOC.log("❌ ERROR: UI Panel 'vocationSelectionPanel' NOT FOUND!")
      VOC.log("❌ This means VocationsUI_Global.xml is NOT loaded in Global → UI tab!")
      VOC.log("❌ OR the XML has parsing errors (check for typos, wrong tags, etc.)")
      VOC.log("❌ Please: 1) Go to Global → UI tab")
      VOC.log("❌ 2) Clear all (CTRL+A, Delete), 3) Paste FULL VocationsUI_Global.xml content")
      VOC.log("❌ 4) Click 'Save & Apply'")
      broadcastToAll("⚠️ VocationsController: UI XML not loaded! Check Global → UI tab.", {1, 0.5, 0.2})
    end
    
    if panel2Ok and panel2Attr ~= nil then
      VOC.log("✅ UI Panel 'vocationSummaryPanel' found and accessible (active=" .. tostring(panel2Attr) .. ")")
      pcall(function()
        UI.setAttribute("vocationSummaryPanel", "active", "false")
      end)
    else
      VOC.log("❌ ERROR: UI Panel 'vocationSummaryPanel' NOT FOUND!")
    end
  else
    VOC.log("⚠️ WARNING: UI system not available (Global UI is nil)")
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
  
  VOC.log("DEBUG TEST: Panel exists, current active: " .. tostring(attr1))
  
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
      VOC.log("DEBUG TEST: Panel active after set: " .. tostring(verify))
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
  VOC.log("=== DEBUG: Testing VOC_StartSelection ===")
  local color = "Green"  -- Default test color
  if player and player.color then
    color = normalizeColor(player.color) or "Green"
  end
  
  VOC.log("Starting selection for: " .. color)
  local ok, err = VOC_StartSelection({color = color})
  if ok then
    broadcastToAll("✅ Selection started for " .. color, {0.3, 1, 0.3})
    VOC.log("✅ Selection started successfully")
  else
    broadcastToAll("❌ Failed to start selection: " .. tostring(err), {1, 0.3, 0.3})
    VOC.log("❌ Failed: " .. tostring(err))
  end
end

-- Debug button: Test showing summary panel directly
function btnDebugShowSummary(obj, player)
  VOC.log("=== DEBUG: Testing showSummaryUI directly ===")
  
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
    VOC.log("✅ Summary panel shown successfully")
  else
    broadcastToAll("❌ Failed to show summary panel", {1, 0.3, 0.3})
    VOC.log("❌ Failed to show summary panel")
  end
end

-- Debug button: Test callback routing
function btnDebugTestCallback(obj, player)
  VOC.log("=== DEBUG: Testing callback routing ===")
  
  local color = "Green"
  if player and player.color then
    color = normalizeColor(player.color) or "Green"
  end
  
  -- Simulate what Global does
  VOC.log("Simulating Global callback with color: " .. color .. ", id: btnGangster")
  
  -- Set active color first
  selectionState.activeColor = color
  uiState.activeColor = color
  
  -- Call UI_SelectVocation directly with color string (simulating Global → Object call)
  UI_SelectVocation(color, -1, "btnGangster")
  
  broadcastToAll("✅ Callback test executed. Check logs.", {0.5, 0.5, 1})
end

-- Function to restore debug buttons if they disappear
function VOC_RestoreDebugButtons()
  VOC.log("Restoring debug buttons...")
  createDebugButtons()
  broadcastToAll("✅ Debug buttons restored", {0.3, 1, 0.3})
end

-- Debug button: Full test flow
function btnDebugFullTest(obj, player)
  VOC.log("=== DEBUG: Full test flow ===")
  
  local color = "Green"
  if player and player.color then
    color = normalizeColor(player.color) or "Green"
  end
  
  broadcastToAll("🔍 Starting full test flow for " .. color, {0.5, 0.5, 1})
  
  -- Step 1: Start selection
  VOC.log("Step 1: Starting selection...")
  local ok1, err1 = VOC_StartSelection({color = color})
  if not ok1 then
    broadcastToAll("❌ Step 1 failed: " .. tostring(err1), {1, 0.3, 0.3})
    return
  end
  
  Wait.time(function()
    -- Step 2: Simulate clicking a vocation
    VOC.log("Step 2: Simulating vocation click...")
    selectionState.activeColor = color
    uiState.activeColor = color
    UI_SelectVocation(color, -1, "btnGangster")
    
    Wait.time(function()
      -- Step 3: Verify summary panel is active
      VOC.log("Step 3: Verifying summary panel...")
      if UI then
        local ok, active = pcall(function()
          return UI.getAttribute("vocationSummaryPanel", "active")
        end)
        if ok and active == "true" then
          broadcastToAll("✅ Full test PASSED! Summary panel is active.", {0.3, 1, 0.3})
          VOC.log("✅ Full test PASSED")
        else
          broadcastToAll("❌ Full test FAILED: Summary panel not active (active=" .. tostring(active) .. ")", {1, 0.3, 0.3})
          VOC.log("❌ Full test FAILED: active=" .. tostring(active))
        end
      end
    end, 0.5)
  end, 0.5)
end

-- Debug button: Test Social Worker L2 community wellbeing session interaction
-- Debug: Show current levels for all players
function btnDebug_ShowLevels(obj, player)
  VOC.log("=== DEBUG: Showing current player levels ===")
  broadcastToAll("📊 Current Player Levels:", {1, 1, 0.6})
  
  for _, c in ipairs(COLORS) do
    local vocation = state.vocations[c] or "None"
    local level = state.levels[c] or 0
    broadcastToAll("  " .. c .. ": " .. vocation .. " (Level " .. level .. ")", {0.8, 0.8, 1})
    VOC.log("  " .. c .. ": vocation=" .. tostring(vocation) .. ", level=" .. tostring(level))
  end
end

-- Debug: Set player level to 1 (for testing)
function btnDebug_SetLevel1(obj, player)
  VOC.log("=== DEBUG: Setting player level to 1 ===")
  
  local color = nil
  if player and player.color and player.color ~= "" and player.color ~= "White" then
    color = normalizeColor(player.color)
  end
  
  if not color or not isPlayableColor(color) then
    -- Default to first player with a vocation
    for _, c in ipairs(COLORS) do
      if state.vocations[c] then
        color = c
        break
      end
    end
  end
  
  if color and state.vocations[color] then
    local oldLevel = state.levels[color] or 0
    state.levels[color] = 1
    broadcastToAll("✅ " .. color .. " level changed: " .. oldLevel .. " → 1", {0.3, 1, 0.3})
    VOC.log("Set " .. color .. " to level 1 (was " .. oldLevel .. ")")
  else
    broadcastToAll("❌ No player color found or no vocation assigned", {1, 0.6, 0.2})
  end
end

function btnDebug_TestSWEvent(obj, player)
  VOC.log("=== DEBUG: Testing Social Worker L2 community wellbeing session ===")
  
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
