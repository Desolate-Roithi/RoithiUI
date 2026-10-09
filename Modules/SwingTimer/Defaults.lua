local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    enabled = true,
    player = {
        colorMain = { r = 1, g = 0.82, b = 0, a = 1 },
        colorOff = { r = 0.35, g = 0.75, b = 1, a = 1 },
        colorRanged = { r = 0.2, g = 0.85, b = 0.35, a = 1 },
        enabled = true,
        height = 12,
        point = "CENTER",
        showOffhand = true,
        showText = true,
        width = 200,
        x = 0,
        y = -140,
    },
    target = {
        color = { r = 0.85, g = 0.25, b = 0.25, a = 1 },
        enabled = true,
        height = 12,
        point = "CENTER",
        showText = true,
        width = 200,
        x = 0,
        y = -160,
    },
}

local mod = RoithiUI and RoithiUI:GetModule("SwingTimer", true)
if mod then
    mod.defaultSettings = defaultSettings
    mod.dbKey = "SwingTimer"
end
if ns.Defaults and ns.Defaults.profile then
    ns.Defaults.profile.SwingTimer = defaultSettings
end
ns.SwingTimerDefaults = defaultSettings
