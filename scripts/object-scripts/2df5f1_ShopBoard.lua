-- =========================================================
-- SHOP BOARD (GUID: 2df5f1) – Shops Board with shop slots, heat track
-- Tag: WLB_SHOP_BOARD
--
-- Displays "DOUBLE PRICES!" reminder when Entrepreneur L1 "Talk to shop owner"
-- is active (other players pay double for consumables & hi-tech).
-- Shop Engine calls API_RefreshDoublePricesUI when state changes.
-- =========================================================

SHOP_BOARD_GUID = "2df5f1"
TAG_SHOP_BOARD = "WLB_SHOP_BOARD"
TAG_SHOP_ENGINE = "WLB_SHOP_ENGINE"

local function findShopEngine()
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_SHOP_ENGINE) and o.call then return o end
  end
  return nil
end

local function clearDoublePricesButtons()
  if not self.clearButtons then return end
  self.clearButtons()
end

local function addDoublePricesButtons(initiatorColor)
  if not self.createButton then return end
  local redBg = {0.85, 0.15, 0.15}
  local whiteFg = {1, 1, 1}
  local tooltip = "Entrepreneur ability: other players pay double for consumables & hi-tech until " .. tostring(initiatorColor) .. "'s next turn."
  -- Two symmetric buttons (left and right) - local coords relative to board. Adjust position if needed for your board layout.
  self.createButton({
    label = "DOUBLE PRICES!",
    click_function = "ShopBoard_Noop",
    function_owner = self,
    position = {-2.5, 0.3, 4},
    rotation = {0, 180, 0},
    width = 500, height = 220,
    font_size = 140,
    color = redBg,
    font_color = whiteFg,
    tooltip = tooltip
  })
  self.createButton({
    label = "DOUBLE PRICES!",
    click_function = "ShopBoard_Noop",
    function_owner = self,
    position = {2.5, 0.3, 4},
    rotation = {0, 180, 0},
    width = 500, height = 220,
    font_size = 140,
    color = redBg,
    font_color = whiteFg,
    tooltip = tooltip
  })
end

function ShopBoard_Noop() end

-- Called by Shop Engine when double prices state changes (SetDoublePrices or API_OnTurnChanged)
function API_RefreshDoublePricesUI(params)
  local shop = findShopEngine()
  if not shop or not shop.call then
    clearDoublePricesButtons()
    return
  end
  local ok, initiator = pcall(function() return shop.call("API_GetDoublePricesInitiator", {}) end)
  if ok and initiator and initiator ~= "" then
    clearDoublePricesButtons()
    addDoublePricesButtons(initiator)
  else
    clearDoublePricesButtons()
  end
end
