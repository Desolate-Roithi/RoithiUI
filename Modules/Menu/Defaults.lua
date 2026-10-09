local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    alpha = 1,
    backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.85 },
    borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
    buttonHeight = 32,
    buttonWidth = 24,
    enabled = true,
    mouseover = false,
    mouseoverAlpha = 0,
    orientation = "HORIZONTAL",
    point = "BOTTOMLEFT",
    showBackground = true,
    spacing = 2,
    styleMicroMenu = true,
    x = 2,
    y = 285,
}

local mod = RoithiUI and RoithiUI:GetModule("Menu", true)
if mod then
    mod.defaultSettings = defaultSettings
    mod.dbKey = "Menu"
end
if ns.Defaults and ns.Defaults.profile then
    ns.Defaults.profile.Menu = defaultSettings
end
ns.MenuDefaults = defaultSettings
