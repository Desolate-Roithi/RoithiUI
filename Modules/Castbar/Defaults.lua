local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local function GetCastbarColors(extra)
    local colors = {
        cast = { 1, 0.95, 0, 1 },
        channel = { 0, 0.98, 1, 1 },
        empower1 = { 0.8, 0.5, 0.1, 1 },
        empower2 = { 0.9, 0.9, 0.2, 1 },
        empower3 = { 0.2, 0.7, 0.2, 1 },
        empower4 = { 0.3, 0.65, 1, 1 },
        interrupted = { 1, 0, 0, 1 },
        shield = { 0.5, 0.5, 0.5, 1 },
    }
    if extra then
        for k, v in pairs(extra) do
            colors[k] = v
        end
    end
    return colors
end

local function CreateBossCastbar()
    return {
        colors = GetCastbarColors(),
        detached = false,
        enabled = true,
        fontSize = 10,
        height = 10,
        iconScale = 1,
        point = "CENTER",
        relPoint = "BOTTOM",
        showIcon = false,
        width = 180,
        x = 0,
        y = 0,
    }
end

local castbarDefaults = {
    colors_v4 = true,
    boss1 = CreateBossCastbar(),
    boss2 = CreateBossCastbar(),
    boss3 = CreateBossCastbar(),
    boss4 = CreateBossCastbar(),
    boss5 = CreateBossCastbar(),
    focus = {
        colors = GetCastbarColors({
                interruptible = { 1, 0, 0, 1 },
            }),
        detached = true,
        enabled = true,
        fontSize = 12,
        height = 25,
        iconScale = 1,
        point = "CENTER",
        relPoint = "CENTER",
        relativeTo = "UIParent",
        showIcon = false,
        width = 250,
        x = 0,
        y = 250,
    },
    focustarget = {
        colors = GetCastbarColors(),
        detached = false,
        enabled = false,
        fontSize = 10,
        height = 15,
        iconScale = 1,
        point = "CENTER",
        relPoint = "CENTER",
        relativeTo = "FocusTargetFrame",
        showIcon = true,
        width = 120,
        x = 0,
        y = 0,
    },
    pet = {
        colors = GetCastbarColors(),
        detached = false,
        enabled = true,
        fontSize = 10,
        height = 15,
        iconScale = 1,
        point = "CENTER",
        relPoint = "CENTER",
        relativeTo = "PetFrame",
        showIcon = false,
        width = 120,
        x = 0,
        y = 0,
    },
    player = {
        colors = GetCastbarColors({
                failed = { 1, 0, 0, 1 },
                success = { 0, 1, 0, 1 },
            }),
        detached = false,
        enabled = true,
        fontSize = 12,
        height = 20,
        icon = true,
        iconScale = 1,
        point = "CENTER",
        relPoint = "CENTER",
        showIcon = false,
        time = true,
        width = 235,
        x = 0,
        y = 0,
    },
    target = {
        colors = GetCastbarColors({
                interruptible = { 1, 0, 0, 1 },
            }),
        detached = false,
        enabled = true,
        fontSize = 12,
        height = 20,
        iconScale = 1,
        point = "CENTER",
        relPoint = "CENTER",
        relativeTo = "TargetFrame",
        showIcon = true,
        width = 200,
        x = 0,
        y = 0,
    },
    targettarget = {
        colors = GetCastbarColors(),
        attached = false,
        detached = false,
        enabled = false,
        fontSize = 10,
        height = 15,
        iconScale = 1,
        point = "CENTER",
        relPoint = "CENTER",
        relativeTo = "TargetTargetFrame",
        showIcon = true,
        width = 120,
        x = 0,
        y = 0,
    },
}

local CastbarMod = RoithiUI and RoithiUI:GetModule("Castbar", true)
if CastbarMod then
    CastbarMod.defaultSettings = castbarDefaults
end
if ns.Defaults and ns.Defaults.profile then
    ns.Defaults.profile.Castbar = castbarDefaults
end
ns.CastbarDefaults = castbarDefaults
