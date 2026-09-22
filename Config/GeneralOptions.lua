local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI", true)
local LSM = LibStub("LibSharedMedia-3.0")

local function GetLSMKeys(mediaType)
    local list = LSM:List(mediaType)
    local out = {}
    for _, name in ipairs(list) do
        out[name] = name
    end
    return out
end

function ns.GetGeneralOptions()
    return {
        type = "group",
        name = L["General"],
        order = 1,
        args = {
            intro = {
                type = "description",
                name = L["General settings for RoithiUI modules."],
                order = 1,
            },
            media = {
                type = "group",
                name = L["Media"],
                order = 5,
                inline = true,
                args = {
                    ufHeader = {
                        type = "header",
                        name = L["Unit Frames"],
                        order = 1,
                    },
                    ufFont = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = L["Font"],
                        order = 2,
                        values = function() return GetLSMKeys("font") end,
                        get = function() return RoithiUI.db.profile.General.unitFrameFont end,
                        set = function(_, v)
                            RoithiUI.db.profile.General.unitFrameFont = v
                            if ns.RefreshAllUnitFrames then ns.RefreshAllUnitFrames() end
                        end,
                    },
                    ufBar = {
                        type = "select",
                        dialogControl = "LSM30_Statusbar",
                        name = L["Status Bar"],
                        order = 3,
                        values = function() return GetLSMKeys("statusbar") end,
                        get = function() return RoithiUI.db.profile.General.unitFrameBar end,
                        set = function(_, v)
                            RoithiUI.db.profile.General.unitFrameBar = v
                            if ns.RefreshAllUnitFrames then ns.RefreshAllUnitFrames() end
                        end,
                    },
                    cbHeader = {
                        type = "header",
                        name = L["Castbars"],
                        order = 10,
                    },
                    cbFont = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = L["Font"],
                        order = 11,
                        values = function() return GetLSMKeys("font") end,
                        get = function() return RoithiUI.db.profile.General.castbarFont end,
                        set = function(_, v)
                            RoithiUI.db.profile.General.castbarFont = v
                            if ns.RefreshAllCastbars then ns.RefreshAllCastbars() end
                        end,
                    },
                    cbBar = {
                        type = "select",
                        dialogControl = "LSM30_Statusbar",
                        name = L["Status Bar"],
                        order = 12,
                        values = function() return GetLSMKeys("statusbar") end,
                        get = function() return RoithiUI.db.profile.General.castbarBar end,
                        set = function(_, v)
                            RoithiUI.db.profile.General.castbarBar = v
                            if ns.RefreshAllCastbars then ns.RefreshAllCastbars() end
                        end,
                    },
                },
            },
            reset = {
                type = "execute",
                name = L["Reset to Defaults"],
                desc  = L["Reset all settings to default values and reload the UI. Cannot be undone."],
                order = 10,
                func = function() RoithiUI:ResetSettings() end,
                width = "full",
            },
            testBoss = {
                type = "toggle",
                name = L["Boss Frames Test Mode"],
                desc  = L["Toggle dummy boss frames for positioning."],
                order = 11,
                get = function()
                    local UF = RoithiUI:GetModule("UnitFrames")
                    return UF and UF.BossTestMode
                end,
                set = function(_, v)
                    local UF = RoithiUI:GetModule("UnitFrames")
                    if UF and UF.ToggleBossTestMode then UF:ToggleBossTestMode() end
                end,
                width = "full",
            },
            debugMode = {
                type = "toggle",
                name = L["|cffff0000Debug Mode|r"],
                desc  = L["Enable debug logging to the chat window."],
                order = 50,
                get = function() return RoithiUI.db.profile.General.debugMode end,
                set = function(_, v) RoithiUI.db.profile.General.debugMode = v end,
                width = "full",
            },
        },
    }
end
