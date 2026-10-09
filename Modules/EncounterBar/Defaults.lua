local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    enabled = true,
    fontSize = 12,
    height = 20,
    point = "TOP",
    texture = "Solid",
    whitelist = {},
    widgetDebug = false,
    widgetLogMode = false,
    width = 250,
    x = 0,
    y = -100,
}

local mod = RoithiUI and RoithiUI:GetModule("EncounterBar", true)
if mod then
    mod.defaultSettings = defaultSettings
    mod.dbKey = "EncounterResource"
end
if ns.Defaults and ns.Defaults.profile then
    ns.Defaults.profile.EncounterResource = defaultSettings
end
ns.EncounterBarDefaults = defaultSettings
