local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    attachedToMinimap = true,
    autoCollapseCombat = false,
    autoCollapseInstance = false,
    hideInMythicPlus = true,
    collapseDelay = 0.25,
    completedColor = { r = 0.25, g = 1, b = 0.35, a = 1 },
    delveWidgetXOffset = 0,
    detachedWidth = 235,
    dividerThickness = 1,
    enabled = true,
    font = "Expressway",
    fontOutline = "OUTLINE",
    foreverColor = { r = 0.22, g = 0.74, b = 0.97, a = 1 },
    headerColor = { r = 0.05, g = 0.82, b = 0.61, a = 1 },
    headerFontSize = 13,
    hideCompletedObjectives = false,
    hideMasterHeader = false,
    hideQuestIcon = true,
    hoverObjectiveText = true,
    maxHeight = 800,
    objectiveColor = { r = 0.8, g = 0.8, b = 0.8, a = 1 },
    objectiveFontSize = 11,
    offsetX = 0,
    offsetY = -5,
    pinnedQuests = {},
    point = "TOPRIGHT",
    scale = 1,
    scenarioStageHeight = 63,
    scenarioStageWidgetHeight = 83,
    scenarioStageXOffset = 0,
    showAccentDivider = true,
    showFocusIndicator = true,
    showForeverQuestInfinity = true,
    showQuestLevel = true,
    skinProgressBars = true,
    sortQuestsByZone = true,
    titleColor = { r = 1, g = 0.85, b = 0.35, a = 1 },
    titleFontSize = 12,
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
