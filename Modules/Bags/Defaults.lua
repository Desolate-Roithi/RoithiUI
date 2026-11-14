local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    activeCategory = "ALL",
    autoRepair = true,
    autoRepairCostThreshold = 2000,
    autoRepairSource = "GUILD",
    autoSellJunk = true,
    bagBar = { buttonSize = 30, enabled = true, expanded = false, point = "BOTTOMLEFT", spacing = 2, x = 290, y = 250 },
    bagWindow = { point = "BOTTOMRIGHT", x = 0, y = 0, width = 546, height = 759 },
    colorItemLevelByQuality = true,
    columns = 14,
    customCategoryAssignments = {},
    customFilters = {},
    enabled = true,
    favorites = {},
    newItemRetentionTimer = 20,
    qualityBorders = true,
    showItemLevel = true,
    slotSize = 36,
    spacing = 2,
    font = "Friz Quadrata TT",
    fontOutline = "OUTLINE",
    categoryFontSize = 12,
    freeSlotsFontSize = 12,
    freeSlotsAnchor = "RIGHT",
    goldFontSize = 14,
    searchFontSize = 12,
    itemCountFont = "Roithi Thick",
    itemCountFontOutline = "OUTLINE",
    itemCountFontSize = 14,
    itemCountAnchor = "BOTTOMRIGHT",
    itemCountX = -2,
    itemCountY = 2,
    itemLevelFont = "Roithi Thick",
    itemLevelFontOutline = "OUTLINE",
    itemLevelFontSize = 14,
    itemLevelAnchor = "TOPLEFT",
    itemLevelX = 1,
    itemLevelY = -1,
    questIndicatorSize = 16,
    questIndicatorAnchor = "BOTTOMLEFT",
    questIndicatorX = 1,
    questIndicatorY = 1,
    showJunkIndicator = true,
    junkIndicatorSize = 14,
    junkIndicatorAnchor = "BOTTOMLEFT",
    junkIndicatorX = 1,
    junkIndicatorY = 1,
    showReagentQuality = true,
    reagentQualitySize = 32,
    reagentQualityAnchor = "TOPLEFT",
    reagentQualityX = -6,
    reagentQualityY = 6,
}

local mod = RoithiUI and RoithiUI:GetModule("Bags", true)
if mod then
    mod.defaultSettings = defaultSettings
    mod.dbKey = "Bags"
end
if ns.Defaults and ns.Defaults.profile then
    ns.Defaults.profile.Bags = defaultSettings
end
ns.BagsDefaults = defaultSettings
