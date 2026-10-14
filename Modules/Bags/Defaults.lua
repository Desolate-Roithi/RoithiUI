local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    activeCategory = "ALL",
    autoSellJunk = false,
    bagBar = { buttonSize = 30, enabled = true, expanded = false, point = "BOTTOMLEFT", spacing = 4, x = 286, y = 285 },
    bagWindow = { point = "BOTTOMRIGHT", x = -10, y = 10, width = 380, height = 420 },
    colorItemLevelByQuality = true,
    columns = 10,
    customCategoryAssignments = {},
    customFilters = {},
    enabled = true,
    favorites = {},
    newItemRetentionTimer = 20,
    qualityBorders = true,
    showItemLevel = true,
    slotSize = 36,
    spacing = 4,
    font = "Friz Quadrata TT",
    fontOutline = "OUTLINE",
    categoryFontSize = 12,
    freeSlotsFontSize = 12,
    freeSlotsAnchor = "RIGHT",
    goldFontSize = 12,
    searchFontSize = 12,
    itemCountFont = "Roithi Thick",
    itemCountFontOutline = "OUTLINE",
    itemCountFontSize = 12,
    itemCountAnchor = "BOTTOMRIGHT",
    itemCountX = -2,
    itemCountY = 2,
    itemLevelFont = "Roithi Thick",
    itemLevelFontOutline = "OUTLINE",
    itemLevelFontSize = 12,
    itemLevelAnchor = "TOPLEFT",
    itemLevelX = 2,
    itemLevelY = -2,
    questIndicatorSize = 16,
    questIndicatorAnchor = "BOTTOMLEFT",
    questIndicatorX = 1,
    questIndicatorY = 1,
    showJunkIndicator = true,
    junkIndicatorSize = 14,
    junkIndicatorAnchor = "BOTTOMLEFT",
    junkIndicatorX = 1,
    junkIndicatorY = 1,
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
