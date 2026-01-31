-- =========================
-- PB STATS CTRL v2.1 (TAGS + COLOR AUTO + GETTERS)
-- NEW in v2.1:
--   getHealth()
--   getState()
-- =========================

-- =========================================================
-- [SECTION 1] TAGS + STATE
-- =========================================================
local TAG_BOARD     = "WLB_BOARD"
local TAG_STATSCTRL = "WLB_STATS_CTRL"

local TAG_HEALTH    = "WLB_HEALTH_TOKEN"
local TAG_KNOWLEDGE = "WLB_KNOWLEDGE_TOKEN"
local TAG_SKILLS    = "WLB_SKILLS_TOKEN"

local state = {
  health = 9,
  knowledge = 0,
  skills = 0,
  calMode = "H", -- H/K/S
  healthPos = {},     -- [0..9]
  knowledgePos = {},  -- [0..15]
  skillsPos = {},     -- [0..15]
}

-- =========================================================
-- [SECTION 2] HELPERS
-- =========================================================
local function clamp(n, lo, hi)
  n = tonumber(n) or 0
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function clampInt(x)
  x = tonumber(x) or 0
  x = math.floor(x + 0.00001)
  return x
end

local function countMap(tbl)
  local c = 0
  if type(tbl) ~= "table" then return 0 end
  for _,v in pairs(tbl) do
    if type(v) == "table" and v.x ~= nil and v.y ~= nil and v.z ~= nil then
      c = c + 1
    end
  end
  return c
end

local function getColorTagFromSelf()
  if not self.getTags then return nil end
  for _, t in ipairs(self.getTags()) do
    if type(t) == "string" and string.sub(t, 1, 10) == "WLB_COLOR_" then
      return t
    end
  end
  return nil
end

local function findOneByTags(tagA, tagB)
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(tagA) and o.hasTag(tagB) then
      return o
    end
  end
  return nil
end

local function getBoard()
  local ctag = getColorTagFromSelf()
  if not ctag then
    print("PB-STATS: brak tagu koloru na kontrolerze (np. WLB_COLOR_Yellow)")
    return nil
  end
  local b = findOneByTags(TAG_BOARD, ctag)
  if not b then
    print("PB-STATS: nie znaleziono boardu (tagi: "..TAG_BOARD.." + "..ctag..")")
  end
  return b
end

local function getHealthToken()
  local ctag = getColorTagFromSelf()
  if not ctag then return nil end
  local t = findOneByTags(TAG_HEALTH, ctag)
  if not t then
    print("PB-STATS: brak tokena HEALTH (tagi: "..TAG_HEALTH.." + "..ctag..")")
  end
  return t
end

local function getKnowledgeToken()
  local ctag = getColorTagFromSelf()
  if not ctag then return nil end
  local t = findOneByTags(TAG_KNOWLEDGE, ctag)
  if not t then
    print("PB-STATS: brak tokena KNOWLEDGE (tagi: "..TAG_KNOWLEDGE.." + "..ctag..")")
  end
  return t
end

local function getSkillsToken()
  local ctag = getColorTagFromSelf()
  if not ctag then return nil end
  local t = findOneByTags(TAG_SKILLS, ctag)
  if not t then
    print("PB-STATS: brak tokena SKILLS (tagi: "..TAG_SKILLS.." + "..ctag..")")
  end
  return t
end

local function moveTokenTo(tbl, value, tokenObj, label)
  local board = getBoard()
  if not board then return end
  if not tokenObj then return end

  local lp = tbl[value]
  if not lp then
    print("PB-STATS: brak kalibracji "..tostring(label)..tostring(value))
    return
  end

  local wp = board.positionToWorld(lp)
  wp.y = wp.y + 0.2
  tokenObj.setPositionSmooth(wp, false, true)
end

local function moveH()
  moveTokenTo(state.healthPos, state.health, getHealthToken(), "H")
end

local function moveK()
  moveTokenTo(state.knowledgePos, state.knowledge, getKnowledgeToken(), "K")
end

local function moveS()
  moveTokenTo(state.skillsPos, state.skills, getSkillsToken(), "S")
end

-- =========================================================
-- [SECTION 3] GETTERS (NEW)
-- =========================================================
function getHealth()
  return state.health
end

function getKnowledge()
  return state.knowledge
end

function getSkills()
  return state.skills
end

function getState()
  return { h = state.health, k = state.knowledge, s = state.skills }
end

-- =========================================================
-- [SECTION 4] CAL mode
-- =========================================================
local function setCalMode(m)
  state.calMode = m
  print("PB-STATS: CAL="..tostring(m))
end

function pb_cal_h() setCalMode("H") end
function pb_cal_k() setCalMode("K") end
function pb_cal_s() setCalMode("S") end

local function calibrate(idx)
  local board = getBoard()
  if not board then return end

  if state.calMode == "H" then
    if idx < 0 or idx > 9 then print("PB-STATS: H tylko 0..9"); return end
    local t = getHealthToken(); if not t then return end
    local lp = board.positionToLocal(t.getPosition())
    state.healthPos[idx] = {x=lp.x, y=lp.y, z=lp.z}
    print("PB-STATS: zapisano H"..tostring(idx))
    if state.health == idx then moveH() end
    return
  end

  if state.calMode == "K" then
    if idx < 0 or idx > 15 then print("PB-STATS: K tylko 0..15"); return end
    local t = getKnowledgeToken(); if not t then return end
    local lp = board.positionToLocal(t.getPosition())
    state.knowledgePos[idx] = {x=lp.x, y=lp.y, z=lp.z}
    print("PB-STATS: zapisano K"..tostring(idx))
    if state.knowledge == idx then moveK() end
    return
  end

  if state.calMode == "S" then
    if idx < 0 or idx > 15 then print("PB-STATS: S tylko 0..15"); return end
    local t = getSkillsToken(); if not t then return end
    local lp = board.positionToLocal(t.getPosition())
    state.skillsPos[idx] = {x=lp.x, y=lp.y, z=lp.z}
    print("PB-STATS: zapisano S"..tostring(idx))
    if state.skills == idx then moveS() end
    return
  end
end

-- =========================================================
-- [SECTION 5] +/- controls
-- =========================================================
function pb_h_minus() state.health = clamp(state.health - 1, 0, 9);  moveH() end
function pb_h_plus()  state.health = clamp(state.health + 1, 0, 9);  moveH() end
function pb_k_minus() state.knowledge = clamp(state.knowledge - 1, 0, 15); moveK() end
function pb_k_plus()  state.knowledge = clamp(state.knowledge + 1, 0, 15); moveK() end
function pb_s_minus() state.skills = clamp(state.skills - 1, 0, 15); moveS() end
function pb_s_plus()  state.skills = clamp(state.skills + 1, 0, 15); moveS() end

-- =========================================================
-- [SECTION 6] AdultStart API
-- =========================================================
function adultStart_apply(params)
  local k = clampInt(params and params.k)
  local s = clampInt(params and params.s)
  if k < 0 then k = 0 end
  if s < 0 then s = 0 end

  local beforeK = state.knowledge
  local beforeS = state.skills

  state.knowledge = clamp(state.knowledge + k, 0, 15)
  state.skills    = clamp(state.skills + s, 0, 15)

  moveK()
  moveS()

  print("PB-STATS: adultStart_apply | +"..tostring(k).."K +"..tostring(s).."S => K "..tostring(beforeK).."->"..tostring(state.knowledge).." | S "..tostring(beforeS).."->"..tostring(state.skills))

  return {
    ok = true,
    addedK = k,
    addedS = s,
    beforeK = beforeK,
    beforeS = beforeS,
    afterK = state.knowledge,
    afterS = state.skills
  }
end

-- =========================================================
-- [SECTION 7] Engine compat API
-- =========================================================
function applyDelta(d)
  if not d then return end
  local dh = tonumber(d.h or 0) or 0
  local dk = tonumber(d.k or 0) or 0
  local ds = tonumber(d.s or 0) or 0

  state.health    = clamp(state.health + dh, 0, 9)
  state.knowledge = clamp(state.knowledge + dk, 0, 15)
  state.skills    = clamp(state.skills + ds, 0, 15)

  moveH(); moveK(); moveS()

  print("PB-STATS: applyDelta | dh="..dh.." dk="..dk.." ds="..ds..
        " => H="..state.health.." K="..state.knowledge.." S="..state.skills)

  return { ok=true, h=state.health, k=state.knowledge, s=state.skills }
end

-- =========================================================
-- [SECTION 8] Public API
-- =========================================================
function resetNewGame()
  state.health = 9
  state.knowledge = 0
  state.skills = 0
  moveH(); moveK(); moveS()
  print("PB-STATS: resetNewGame OK")
end

-- =========================================================
-- [SECTION 9] UI
-- =========================================================
function pb_cal_0()  calibrate(0) end
function pb_cal_1()  calibrate(1) end
function pb_cal_2()  calibrate(2) end
function pb_cal_3()  calibrate(3) end
function pb_cal_4()  calibrate(4) end
function pb_cal_5()  calibrate(5) end
function pb_cal_6()  calibrate(6) end
function pb_cal_7()  calibrate(7) end
function pb_cal_8()  calibrate(8) end
function pb_cal_9()  calibrate(9) end
function pb_cal_10() calibrate(10) end
function pb_cal_11() calibrate(11) end
function pb_cal_12() calibrate(12) end
function pb_cal_13() calibrate(13) end
function pb_cal_14() calibrate(14) end
function pb_cal_15() calibrate(15) end

local function createButtons()
  self.clearButtons()

  self.createButton({label="H-", click_function="pb_h_minus", function_owner=self, position={-1.20,0.25, 0.60}, width=320,height=320,font_size=150})
  self.createButton({label="H+", click_function="pb_h_plus",  function_owner=self, position={-0.75,0.25, 0.60}, width=320,height=320,font_size=150})
  self.createButton({label="K-", click_function="pb_k_minus", function_owner=self, position={-0.10,0.25, 0.60}, width=320,height=320,font_size=150})
  self.createButton({label="K+", click_function="pb_k_plus",  function_owner=self, position={ 0.35,0.25, 0.60}, width=320,height=320,font_size=150})
  self.createButton({label="S-", click_function="pb_s_minus", function_owner=self, position={ 1.00,0.25, 0.60}, width=320,height=320,font_size=150})
  self.createButton({label="S+", click_function="pb_s_plus",  function_owner=self, position={ 1.45,0.25, 0.60}, width=320,height=320,font_size=150})

  self.createButton({label="CAL:H", click_function="pb_cal_h", function_owner=self, position={-1.10,0.25, 0.10}, width=420,height=220,font_size=110})
  self.createButton({label="CAL:K", click_function="pb_cal_k", function_owner=self, position={-0.30,0.25, 0.10}, width=420,height=220,font_size=110})
  self.createButton({label="CAL:S", click_function="pb_cal_s", function_owner=self, position={ 0.50,0.25, 0.10}, width=420,height=220,font_size=110})

  local startX, step = -1.55, 0.26
  for i=0,15 do
    self.createButton({
      label=tostring(i),
      click_function="pb_cal_"..tostring(i),
      function_owner=self,
      position={startX + i*step, 0.25, -0.55},
      width=220,height=220,font_size=90
    })
  end
end

-- =========================================================
-- [SECTION 10] persistence (string) + lifecycle
-- =========================================================
local function packPosIdx(prefix, tbl, maxIdx)
  local parts = {}
  for i=0,maxIdx do
    local v = tbl[i]
    if v and tonumber(v.x) and tonumber(v.y) and tonumber(v.z) then
      table.insert(parts, tostring(i)..","..tostring(v.x)..","..tostring(v.y)..","..tostring(v.z))
    end
  end
  return prefix .. table.concat(parts, "|") .. ";"
end

local function unpackPosIdx(line, maxIdx)
  local out = {}
  if not line or line == "" then return out end
  for chunk in string.gmatch(line, "([^|]+)") do
    local a,b,c,d = string.match(chunk, "^(%-?%d+),([%-?%d%.eE]+),([%-?%d%.eE]+),([%-?%d%.eE]+)$")
    local i=tonumber(a); local x=tonumber(b); local y=tonumber(c); local z=tonumber(d)
    if i ~= nil and i>=0 and i<=maxIdx and x and y and z then out[i]={x=x,y=y,z=z} end
  end
  return out
end

function onSave()
  local s = ""
  s = s .. "H="..tostring(state.health)..";"
  s = s .. "K="..tostring(state.knowledge)..";"
  s = s .. "S="..tostring(state.skills)..";"
  s = s .. "M="..tostring(state.calMode)..";"
  s = s .. packPosIdx("HP:", state.healthPos, 9)
  s = s .. packPosIdx("KP:", state.knowledgePos, 15)
  s = s .. packPosIdx("SP:", state.skillsPos, 15)
  return s
end

function onLoad(saved_data)
  createButtons()

  if saved_data and saved_data ~= "" then
    local h = string.match(saved_data, "H=(%-?%d+);")
    local k = string.match(saved_data, "K=(%-?%d+);")
    local ss= string.match(saved_data, "S=(%-?%d+);")
    local m = string.match(saved_data, "M=([HKS]);")

    if h then state.health = clamp(tonumber(h) or 9, 0, 9) end
    if k then state.knowledge = clamp(tonumber(k) or 0, 0, 15) end
    if ss then state.skills = clamp(tonumber(ss) or 0, 0, 15) end
    if m then state.calMode = m end

    state.healthPos    = unpackPosIdx(string.match(saved_data, "HP:([^;]*);"), 9)
    state.knowledgePos = unpackPosIdx(string.match(saved_data, "KP:([^;]*);"), 15)
    state.skillsPos    = unpackPosIdx(string.match(saved_data, "SP:([^;]*);"), 15)
  end

  Wait.time(function() moveH(); moveK(); moveS() end, 0.2)

  local ctag = getColorTagFromSelf()
  print("PB-STATS v2.1 loaded | COLOR="..tostring(ctag)..
    " | HP="..tostring(countMap(state.healthPos))..
    " KP="..tostring(countMap(state.knowledgePos))..
    " SP="..tostring(countMap(state.skillsPos)))
end
