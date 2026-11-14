local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    attachedToMinimap = true,
    hideInCombat = false,
    hideInInstance = false,
    blockOffsetX = 4,
    hideInMythicPlus = true,
    collapseDelay = 0.5,
    completedColor = { r = 0.20, g = 0.90, b = 0.60, a = 1 },
    delveWidgetXOffset = 0,
    detachedWidth = 235,
    dividerThickness = 2,
    enabled = true,
    font = "Roithi Thick",
    headerFont = "Roithi Thick",
    headerFontOutline = "NONE",
    headerFontShadow = true,
    titleFont = "Roithi Thick",
    titleFontOutline = "NONE",
    titleFontShadow = true,
    questLevelFont = "Expressway",
    questLevelFontSize = 12,
    questLevelFontOutline = "OUTLINE",
    questLevelFontShadow = false,
    scenarioStageFont = "Expressway",
    scenarioStageFontSize = 13,
    scenarioStageFontOutline = "OUTLINE",
    scenarioStageFontShadow = false,
    progressBarFont = "Expressway",
    progressBarFontSize = 10,
    progressBarFontOutline = "OUTLINE",
    progressBarFontShadow = false,
    objectiveFont = "Roithi Thin",
    objectiveFontOutline = "NONE",
    objectiveFontShadow = true,
    fontOutline = "NONE",
    foreverColor = { r = 0.30, g = 0.60, b = 1.0, a = 1 },
    headerColor = { r = 0.20, g = 0.80, b = 1.0, a = 1 },
    headerFontSize = 16,
    hideCompletedObjectives = true,
    hideMasterHeader = false,
    hideQuestIcon = true,
    hoverObjectiveText = true,
    maxHeight = 850,
    objectiveColor = { r = 0.93, g = 0.95, b = 0.98, a = 1 },
    objectiveFontSize = 14,
    offsetX = 0,
    offsetY = -5,
    pinnedQuests = {},
    point = "TOPRIGHT",
    scale = 1,
    scenarioStageHeight = 63,
    scenarioStageWidgetHeight = 83,
    scenarioStageWidth = 253,
    scenarioStageXOffset = 0,
    showAccentDivider = true,
    showCompletedQuestIndicator = true,
    showFocusIndicator = true,
    showFontShadow = true,
    showForeverQuestInfinity = true,
    showQuestLevel = false,
    skinProgressBars = true,
    sortQuestsByZone = true,
    titleColor = { r = 0.94, g = 0.96, b = 1.0, a = 1 },
    titleFontSize = 14,
    x = -50,
    y = -200,
}

local mod = RoithiUI and RoithiUI:GetModule("Objectives", true)
if mod then
    mod.defaultSettings = defaultSettings
    mod.dbKey = "Objectives"
end
if ns.Defaults and ns.Defaults.profile then
    ns.Defaults.profile.Objectives = defaultSettings
end
ns.ObjectivesDefaults = defaultSettings
