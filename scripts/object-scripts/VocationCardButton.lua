-- =========================================================
-- VOCATION CARD BUTTON
-- Attach this script to vocation cards given to players.
-- Adds a small "?" in the right corner of the card. Clicking it
-- shows the vocation explanation picture in the Global UI
-- (VocationsController calls showSummaryUI with the explanation image).
-- =========================================================

local ALL_VOCATIONS = {
  "PUBLIC_SERVANT", "CELEBRITY", "SOCIAL_WORKER",
  "GANGSTER", "ENTREPRENEUR", "NGO_WORKER"
}

local function getVocationFromCard()
  if not self or not self.hasTag then return nil end
  for _, voc in ipairs(ALL_VOCATIONS) do
    if self.hasTag("WLB_VOC_" .. voc) then return voc end
  end
  return nil
end

function onLoad()
  local vocation = getVocationFromCard()
  if not vocation then return end

  if not self or not self.createButton then return end

  -- Small "?" in the right corner of the card; click shows explanation picture in UI
  self.createButton({
    click_function = "VOC_CardButtonShowExplanation",
    function_owner = self,
    label = "?",
    position = {0.48, 0.08, 0.42},
    width = 90,
    height = 90,
    font_size = 70,
    color = {0.25, 0.35, 0.55, 0.95},
    font_color = {1, 1, 1, 1},
    tooltip = "Show explanation (picture in UI)"
  })
end
