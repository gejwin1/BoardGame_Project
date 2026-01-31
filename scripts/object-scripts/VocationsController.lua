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

-- =========================================================
-- CHARACTER SLOT POSITION (from scanner)
-- =========================================================
-- TODO: Replace with actual measured position from scanner
local CHARACTER_SLOT_LOCAL = {
  Yellow = {x=0.0, y=0.592, z=0.0},  -- PLACEHOLDER - Replace with measured position
  Blue = {x=0.0, y=0.592, z=0.0},    -- PLACEHOLDER - Replace with measured position
  Red = {x=0.0, y=0.592, z=0.0},     -- PLACEHOLDER - Replace with measured position
  Green = {x=0.0, y=0.592, z=0.0},   -- PLACEHOLDER - Replace with measured position
}

-- Storage position for tiles (when not on board)
local STORAGE_POSITION = {0, 5, 0}  -- Off-screen, adjust as needed

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
    if obj and obj.hasTag and
       obj.hasTag(TAG_VOCATION_TILE) and
       obj.hasTag(vocationTag) and
       obj.hasTag(levelTag) then
      -- Check if it's not on any board (no color tag)
      local hasColorTag = false
      for _, c in ipairs(COLORS) do
        if obj.hasTag(colorTag(c)) then
          hasColorTag = true
          break
        end
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
    if obj and obj.hasTag and
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
  
  log("Placed tile on " .. color .. " board")
  return true
end

-- Add "Show explanation" context menu to a vocation tile (shows Global UI summary, not physical card)
local function addExplanationContextMenuToTile(tile, vocation)
  if not tile or not tile.addContextMenuItem or not vocation then return end
  local ctrlGuid = self and self.getGUID and self.getGUID() or nil
  if not ctrlGuid then return end
  local voc = vocation
  tile.addContextMenuItem("Show explanation", function(player_color, pos, obj)
    local ctrl = getObjectFromGUID(ctrlGuid)
    if ctrl and ctrl.call then
      ctrl.call("VOC_ShowExplanationForPlayer", { vocation = voc, color = player_color, previewOnly = true })
    end
  end)
  log("Added 'Show explanation' context menu to vocation tile: " .. tostring(vocation))
end

local function removeTileFromBoard(color)
  color = normalizeColor(color)
  if not color then return nil end
  
  local tile = findTileOnPlayerBoard(color)
  if not tile then return nil end
  
  tile.removeTag(colorTag(color))
  tile.setPositionSmooth(STORAGE_POSITION, false, true)
  
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
    addExplanationContextMenuToTile(newTile, vocation)
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
    addExplanationContextMenuToTile(tile, vocation)
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
  
  local nextLevel = level + 1
  local nextLevelData = vocationData.levels[nextLevel]
  if not nextLevelData then return false, "Next level data not found" end
  
  local promotion = nextLevelData.promotion
  if not promotion then return false, "No promotion data" end
  
  -- Get Stats Controller
  local statsCtrl = findStatsController(color)
  if not statsCtrl then return false, "Stats Controller not found" end
  
  -- Check Knowledge and Skills
  local ok, knowledge = pcall(function() return statsCtrl.call("getKnowledge") end)
  local ok2, skills = pcall(function() return statsCtrl.call("getSkills") end)
  
  if not ok or not ok2 then
    return false, "Could not query stats"
  end
  
  knowledge = tonumber(knowledge) or 0
  skills = tonumber(skills) or 0
  
  -- Check requirements based on promotion type (all Level 1 and 2 need Knowledge, Skills, and Time or vocation-specific)
  if promotion.type == "standard" then
    -- Need Knowledge, Skills, and Experience (Time = rounds at current level)
    if knowledge < promotion.knowledge then
      return false, "Need " .. promotion.knowledge .. " Knowledge (have " .. knowledge .. ")"
    end
    if skills < promotion.skills then
      return false, "Need " .. promotion.skills .. " Skills (have " .. skills .. ")"
    end
    local currentRound = getCurrentRound()
    local roundAtLevel = state.levelUpRound[color] or 1
    local roundsAtLevel = math.max(0, currentRound - roundAtLevel)
    local needYears = promotion.experience or 0
    if roundsAtLevel < needYears then
      return false, "Need " .. needYears .. " years at this level (have " .. roundsAtLevel .. " rounds)"
    end
    return true, "All requirements met"
    
  elseif promotion.type == "work_based" then
    -- Need Knowledge, Skills, and Work AP on current level
    if knowledge < promotion.knowledge then
      return false, "Need " .. promotion.knowledge .. " Knowledge (have " .. knowledge .. ")"
    end
    if skills < promotion.skills then
      return false, "Need " .. promotion.skills .. " Skills (have " .. skills .. ")"
    end
    local workAP = state.workAPThisLevel[color] or 0
    if workAP < promotion.workAP then
      return false, "Need " .. promotion.workAP .. " AP work on this level (have " .. workAP .. ")"
    end
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
  
  local canPromote, reason = VOC_CanPromote({color=color})
  if not canPromote then
    log("Cannot promote " .. color .. ": " .. tostring(reason))
    return false, reason
  end
  
  local vocation = state.vocations[color]
  local oldLevel = state.levels[color] or 1
  local newLevel = oldLevel + 1
  
  -- Update level
  state.levels[color] = newLevel
  state.levelUpRound[color] = getCurrentRound()  -- Time/Experience: rounds at this level
  
  -- Reset work AP for this level (for Celebrity tracking)
  state.workAPThisLevel[color] = 0
  
  saveState()
  
  -- Swap tile on board
  swapTileOnPromotion(color, vocation, oldLevel, newLevel)
  
  local vocationData = VOCATION_DATA[vocation]
  local newLevelData = vocationData.levels[newLevel]
  
  log("Promoted: " .. color .. " " .. vocation .. " Level " .. oldLevel .. " → " .. newLevel)
  broadcastToAll(color .. " promoted to " .. vocationData.name .. " - " .. newLevelData.jobTitle, {0.3, 1, 0.3})
  
  return true
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

-- Show the Vocation Selection UI panel
local function showSelectionUI(color, points)
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
    
    -- Update subtitle / science points (safe)
    uiSet("selectionSubtitle", "text", "Player: " .. color)
    -- Get science points: use provided points, or query TurnController, or default to 0
    local sciencePoints = points
    if not sciencePoints or sciencePoints == 0 then
      sciencePoints = getSciencePointsForColor(color)
    end
    uiSet("selectionSciencePoints", "text", "Science Points: " .. tostring(sciencePoints))
    log("DEBUG: Set subtitle to: Player: " .. color .. " | points=" .. tostring(sciencePoints))
    
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

  if self.clearButtons then
    self.clearButtons()
  end

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
  if self and self.clearButtons then
    self.clearButtons()
  end
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
  if not self or not self.clearButtons then return false end
  local color = selectionState.activeColor
  if not color then return false end

  local data = VOCATION_DATA[vocation]
  local vocationName = data and data.name or vocation
  selectionState.shownVocation = vocation
  selectionState.shownSummary = nil  -- No physical tile

  self.clearButtons()

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
    local ok = showSelectionUI(color, points)
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
  
  if self and self.clearButtons then
    pcall(function() self.clearButtons() end)
    log("Cleared selection buttons from controller")
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
  
  if not color then return end
  
  -- Verify it's the active player
  if color ~= uiState.activeColor then
    log("UI_ConfirmVocation: Wrong player. Active: " .. tostring(uiState.activeColor) .. ", Clicked: " .. color)
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
  
  -- Hide all UI
  hideSummaryUI()
  hideSelectionUI()
  
  -- Notify TurnController
  local turnCtrl = findTurnController()
  if turnCtrl and turnCtrl.call then
    pcall(function()
      turnCtrl.call("VOC_OnVocationSelected", {color = color, vocation = vocation})
    end)
  end
  
  safeBroadcastToColor("✅ You chose: " .. (VOCATION_DATA[vocation] and VOCATION_DATA[vocation].name or vocation), color, {0.3, 1, 0.3})
  log("Vocation confirmed: " .. color .. " -> " .. vocation)
  
  -- Reset UI state
  uiState.activeColor = nil
  uiState.currentScreen = nil
  uiState.previewedVocation = nil
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
-- TEST BUTTON (for UI debugging) - Must be defined before onLoad
-- =========================================================
local function createTestButton()
  if not self or not self.createButton then
    log("WARNING: Cannot create test button - self.createButton not available")
    return
  end
  
  -- Clear any existing buttons first
  if self.clearButtons then
    pcall(function() self.clearButtons() end)
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
  
  -- Create debug buttons: 2 above, 2 below (to avoid covering test button and overlapping)
  local buttons = {
    -- Top row (above)
    { label = "TEST\nSELECTION", fn = "btnDebugStartSelection", pos = {-0.75, 0.6, 0}, color = {0.2, 0.6, 1.0} },
    { label = "TEST\nSUMMARY", fn = "btnDebugShowSummary", pos = {0.75, 0.6, 0}, color = {0.2, 1.0, 0.6} },
    -- Bottom row (below)
    { label = "TEST\nCALLBACK", fn = "btnDebugTestCallback", pos = {-0.75, 0.0, 0}, color = {1.0, 0.6, 0.2} },
    { label = "FULL\nTEST", fn = "btnDebugFullTest", pos = {0.75, 0.0, 0}, color = {0.8, 0.2, 0.8} },
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
      if self and self.clearButtons then
        pcall(function() self.clearButtons() end)
      end
      if self and self.createButton and createDebugButtons then
        createDebugButtons()
        log("VocationsController: debug buttons created (delayed)")
      end
      -- Add "Show explanation" to vocation tiles (all levels) already on player boards (e.g. from saved game)
      if self and self.getGUID then
        local list = getAllObjects()
        for _, obj in ipairs(list) do
          if obj and obj.hasTag and obj.addContextMenuItem then
            local voc = getVocationFromTile(obj)
            if voc then
              local hasColor = false
              for _, c in ipairs(COLORS) do
                if obj.hasTag(colorTag(c)) then hasColor = true; break end
              end
              if hasColor then
                addExplanationContextMenuToTile(obj, voc)
              end
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
  
  -- NOTE: createTestButton() removed - it was clearing debug buttons!
  -- Debug buttons are created above in createDebugButtons()
  -- If you need the old test button, use the debug buttons instead
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
