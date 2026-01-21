local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local Config = RoithiUI.Config or {}
RoithiUI.Config = Config

-- ----------------------------------------------------------------------------
-- AceConfig Table Definition
-- ----------------------------------------------------------------------------
local function GetOptions()
    local options = {
        type = "group",
        name = "RoithiUI Settings",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    -- Moved from General.lua or new items ca go here
                    intro = {
                        type = "description",
                        name = "General settings for RoithiUI modules.",
                        order = 1,
                    },
                    reset = {
                        type = "execute",
                        name = "Reset to Defaults",
                        desc = "Reset all settings to default values and reload the UI. Cannot be undone.",
                        order = 10,
                        func = function() RoithiUI:ResetSettings() end,
                        width = "full",
                    },
                    -- Add global toggles here later if needed
                },
            },
            unitframes = {
                type = "group",
                name = "Unit Frames",
                order = 2,
                args = {
                    intro = {
                        type = "description",
                        name = "Configure text, auras, and indicators for Unit Frames.",
                        order = 1,
                    },
                    -- Units will be populated dynamically or defined below
                },
            },
            customtags = RoithiUI.Config.GetCustomTagsOptions and RoithiUI.Config.GetCustomTagsOptions() or nil,
            castbars = {
                type = "group",
                name = "Castbars",
                order = 3,
                args = {
                    intro = {
                        type = "description",
                        name = "Castbar settings are currently managed via Edit Mode.",
                        order = 1,
                    },
                },
            },
        },
    }

    -- Populate Unit Frame Options
    local units = {
        { "player",       "Player" },
        { "target",       "Target" },
        { "targettarget", "Target of Target" },
        { "focus",        "Focus" },
        { "focustarget",  "Focus Target" },
        { "pet",          "Pet" },
    }

    for i, u in ipairs(units) do
        local unit, label = u[1], u[2]

        -- Helper to get DB
        local function GetDB()
            if not RoithiUIDB.UnitFrames[unit] then RoithiUIDB.UnitFrames[unit] = {} end
            return RoithiUIDB.UnitFrames[unit]
        end

        options.args.unitframes.args[unit] = {
            type = "group",
            name = label,
            order = 10 + i,
            args = {
                -- Tab: Text
                text = {
                    type = "group",
                    name = "Text",
                    order = 1,
                    inline = true,
                    args = {
                        healthFormat = {
                            type = "select",
                            name = "Health Format",
                            order = 1,
                            values = { smart = "Smart", cur = "Current", percent = "Percent", curmax = "Cur / Max", deficit = "Deficit" },
                            get = function() return GetDB().healthTextFormat or "smart" end,
                            set = function(_, v)
                                GetDB().healthTextFormat = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        powerFormat = {
                            type = "select",
                            name = "Power Format",
                            order = 2,
                            values = { smart = "Smart", cur = "Current", percent = "Percent", curmax = "Cur / Max" },
                            get = function() return GetDB().powerTextFormat or "smart" end,
                            set = function(_, v)
                                GetDB().powerTextFormat = v; ns.RefreshUnitFrame(unit)
                            end,
                        },

                    },
                },
                -- Tab: Indicators
                indicators = {
                    type = "group",
                    name = "Indicators",
                    order = 2,
                    inline = true,
                    args = {
                        testMode = {
                            type = "toggle",
                            name = "|cffffd100Test Mode|r",
                            desc = "Force show all enabled indicators for easier configuration.",
                            order = 0,
                            get = function() return RoithiUIDB.IndicatorTestMode end,
                            set = function(_, v)
                                RoithiUIDB.IndicatorTestMode = v
                                ns.RefreshUnitFrame(unit)
                            end,
                            width = "full",
                        },
                        selectIndicator = {
                            type = "select",
                            name = "Select Indicator",
                            order = 1,
                            values = function()
                                local v = {
                                    combat = "Combat",
                                    leader = "Leader",
                                    raidicon = "Raid Icon",
                                    role = "Role",
                                    readycheck = "Ready Check",
                                    phase = "Phase",
                                    resurrect = "Resurrect",
                                    pvp = "PvP",
                                    tankassist = "Main Tank / Assist",
                                }
                                if unit == "target" or unit == "focus" then
                                    v.quest = "Quest"
                                end
                                return v
                            end,
                            get = function() return RoithiUIDB.tempIndicatorSelect end,
                            set = function(_, v) RoithiUIDB.tempIndicatorSelect = v end,
                        },
                        -- Details Group (Only shown if selection made)
                        details = {
                            type = "group",
                            name = "Settings",
                            order = 2,
                            inline = true,
                            hidden = function() return not RoithiUIDB.tempIndicatorSelect end,
                            args = {
                                enabled = {
                                    type = "toggle",
                                    name = "Enable",
                                    order = 1,
                                    get = function()
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.enabled
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        if not GetDB().indicators then GetDB().indicators = {} end
                                        if not GetDB().indicators[k] then GetDB().indicators[k] = {} end
                                        GetDB().indicators[k].enabled = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                },
                                size = {
                                    type = "range",
                                    name = "Size",
                                    order = 2,
                                    min = 8,
                                    max = 64,
                                    step = 1,
                                    get = function()
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.size or 20
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        if not GetDB().indicators then GetDB().indicators = {} end
                                        if not GetDB().indicators[k] then GetDB().indicators[k] = {} end
                                        GetDB().indicators[k].size = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                },
                                point = {
                                    type = "select",
                                    name = "Anchor Point",
                                    order = 3,
                                    values = {
                                        ["CENTER"] = "Center",
                                        ["TOP"] = "Top",
                                        ["BOTTOM"] = "Bottom",
                                        ["LEFT"] = "Left",
                                        ["RIGHT"] = "Right",
                                        ["TOPLEFT"] = "Top Left",
                                        ["TOPRIGHT"] = "Top Right",
                                        ["BOTTOMLEFT"] = "Bottom Left",
                                        ["BOTTOMRIGHT"] = "Bottom Right"
                                    },
                                    get = function()
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.point or "CENTER"
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        if not GetDB().indicators then GetDB().indicators = {} end
                                        if not GetDB().indicators[k] then GetDB().indicators[k] = {} end
                                        GetDB().indicators[k].point = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                },
                                x = {
                                    type = "range",
                                    name = "X Offset",
                                    order = 4,
                                    min = -100,
                                    max = 100,
                                    step = 1,
                                    get = function()
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.x or 0
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        if not GetDB().indicators then GetDB().indicators = {} end
                                        if not GetDB().indicators[k] then GetDB().indicators[k] = {} end
                                        GetDB().indicators[k].x = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                },
                                y = {
                                    type = "range",
                                    name = "Y Offset",
                                    order = 5,
                                    min = -100,
                                    max = 100,
                                    step = 1,
                                    get = function()
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.y or 0
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUIDB.tempIndicatorSelect
                                        if not GetDB().indicators then GetDB().indicators = {} end
                                        if not GetDB().indicators[k] then GetDB().indicators[k] = {} end
                                        GetDB().indicators[k].y = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                },
                            },
                        },
                    },
                },
                -- Tab: Auras (Placeholder for now)
                auras = {
                    type = "group",
                    name = "Auras",
                    order = 3,
                    inline = true,
                    args = {
                        enable = {
                            type = "toggle",
                            name = "Enable",
                            order = 1,
                            get = function() return GetDB().aurasEnabled ~= false end,
                            set = function(_, v)
                                GetDB().aurasEnabled = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        size = {
                            type = "range",
                            name = "Size",
                            order = 2,
                            min = 10,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().auraSize or 20 end,
                            set = function(_, v)
                                GetDB().auraSize = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        max = {
                            type = "range",
                            name = "Max Auras",
                            order = 3,
                            min = 1,
                            max = 40,
                            step = 1,
                            get = function() return GetDB().maxAuras or 8 end,
                            set = function(_, v)
                                GetDB().maxAuras = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                    },
                },
            },
        }
    end

    return options
end

function Config:RegisterOptions()
    -- Safety check for AceConfig
    local AC = LibStub("AceConfig-3.0", true)
    local ACD = LibStub("AceConfigDialog-3.0", true)

    if AC and ACD then
        AC:RegisterOptionsTable("RoithiUI", GetOptions)
        self.optionsFrame = ACD:AddToBlizOptions("RoithiUI", "RoithiUI")
    else
        -- If AceConfig is missing, we just don't register this table.
        -- The standalone config (if loaded) or just the lack of options is better than a crash.
        print("RoithiUI: AceConfig-3.0 not found. Detailed options disabled.")
    end
end

-- Refresh Helper (can be moved to Core/UnitFrames if scope issues arise)
function ns.RefreshUnitFrame(unit)
    local UF = RoithiUI:GetModule("UnitFrames")
    if UF and UF.UpdateFrameFromSettings then
        UF:UpdateFrameFromSettings(unit)
    end
end
