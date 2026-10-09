local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
    borderSize = 1,
    centerIncompleteRows = true,
    cooldownFontOutline = "OUTLINE",
    cooldownFontSize = 14,
    cooldownOffsetX = 0,
    cooldownOffsetY = 0,
    cropIcons = true,
    enabled = true,
    font = "Friz Quadrata TT",
    stackAnchor = "BOTTOMRIGHT",
    stackFontOutline = "OUTLINE",
    stackFontSize = 11,
    stackOffsetX = -2,
    stackOffsetY = 2,
    viewers = {
        BuffBar = { barHeight = 24, barWidth = 220, enabled = true, growthDirection = "DOWN", spacing = 4 },
        BuffIcon = {
            align = "CENTER",
            centerIncompleteRows = true,
            cooldownFontSize = 12,
            cooldownOffsetX = 0,
            cooldownOffsetY = 0,
            enabled = true,
            growthDirection = "RIGHT",
            iconSize = 40,
            spacing = 4,
            stackAnchor = "BOTTOMRIGHT",
            stackFontSize = 11,
            stackOffsetX = -2,
            stackOffsetY = 2,
        },
        Essential = {
            align = "CENTER",
            centerIncompleteRows = true,
            cooldownFontSize = 14,
            cooldownOffsetX = 0,
            cooldownOffsetY = 0,
            enabled = true,
            growthDirection = "RIGHT",
            iconSize = 50,
            spacing = 4,
            stackAnchor = "BOTTOMRIGHT",
            stackFontSize = 11,
            stackOffsetX = -2,
            stackOffsetY = 2,
        },
        Utility = {
            align = "CENTER",
            centerIncompleteRows = true,
            cooldownFontSize = 12,
            cooldownOffsetX = 0,
            cooldownOffsetY = 0,
            enabled = true,
            growthDirection = "RIGHT",
            iconSize = 32,
            spacing = 4,
            stackAnchor = "BOTTOMRIGHT",
            stackFontSize = 11,
            stackOffsetX = -2,
            stackOffsetY = 2,
        },
    },
}

local mod = RoithiUI and RoithiUI:GetModule("CooldownManager", true)
if mod then
    mod.defaultSettings = defaultSettings
    mod.dbKey = "CooldownManager"
end
if ns.Defaults and ns.Defaults.profile then
    ns.Defaults.profile.CooldownManager = defaultSettings
end
ns.CooldownManagerDefaults = defaultSettings
