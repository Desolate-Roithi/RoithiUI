local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    activeBorderColor = { r = 0.2, g = 0.8, b = 0.2, a = 1 },
    borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
    buttonSize = 36,
    disabledSpells = {},
    enabled = true,
    font = "Friz Quadrata TT",
    fontSize = 11,
    orientation = "HORIZONTAL",
    point = "BOTTOM",
    selectedCategory = "earth",
    selectedSpells = {},
    selectionBorderColor = { r = 1, g = 0.85, b = 0, a = 1 },
    showAir = true,
    showCooldown = true,
    showDuration = true,
    showEarth = true,
    showFire = true,
    showKeybind = true,
    showOnAllClasses = false,
    showShield = true,
    showWater = true,
    showWeapon = true,
    spacing = 4,
    x = -320,
    y = 190,
}

local mod = RoithiUI and RoithiUI:GetModule("Totems", true)
if mod then
    mod.defaultSettings = defaultSettings
    mod.dbKey = "Totems"
end
if ns.Defaults and ns.Defaults.profile then
    ns.Defaults.profile.Totems = defaultSettings
end
ns.TotemsDefaults = defaultSettings
