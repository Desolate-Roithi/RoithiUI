local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

---@class UF : AceModule, AceAddon
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]

-------------------------------------------------------------------------------
-- 12.1.0 Roithi Aura Debugger (RAD) & Logging System
-------------------------------------------------------------------------------
RoithiUI.AuraDebug = RoithiUI.AuraDebug or false

local function RADLog(fmt, ...)
    if RoithiUI.AuraDebug then
        local ok, msg = pcall(string.format, fmt, ...)
        if ok then
            print("|cff00ffff[RAD 12.1.0]|r " .. msg)
            if RoithiUI.Log then
                RoithiUI:Log("[RAD 12.1.0] " .. msg)
            end
        end
    end
end

-- Slash command /rad to toggle debug logging
_G.SLASH_ROITHIAURADEBUG1 = "/rad"
_G.SlashCmdList["ROITHIAURADEBUG"] = function(_)
    RoithiUI.AuraDebug = not RoithiUI.AuraDebug
    local stateStr = RoithiUI.AuraDebug and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
    print("|cff00ffff[RAD - Roithi Aura Debugger 12.1.0]|r Debug logging is now " .. stateStr)
end

-------------------------------------------------------------------------------
-- Global Sub-Module Table & Container Registry Initialization
-------------------------------------------------------------------------------
ns.Auras = ns.Auras or {}
ns.Auras.RADLog = RADLog

UF.AuraContainers = UF.AuraContainers or {}
UF.CustomAuraContainers = UF.CustomAuraContainers or {}
UF.AuraMovers = UF.AuraMovers or {}
RoithiUI.CustomAuras = RoithiUI.CustomAuras or {}
RoithiUI.TimelessAuraCache = RoithiUI.TimelessAuraCache or {}
