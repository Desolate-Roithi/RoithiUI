local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local Config = RoithiUI.Config or {}
RoithiUI.Config = Config
local LSM = LibStub("LibSharedMedia-3.0")

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
                    media = {
                        type = "group",
                        name = "Media",
                        order = 5,
                        inline = true,
                        args = {
                            font = {
                                type = "select",
                                dialogControl = "LSM30_Font",
                                name = "Global Font",
                                order = 1,
                                values = LSM:HashTable("font"),
                                get = function() return RoithiUI.db.profile.font or "Friz Quadrata TT" end,
                                set = function(_, v)
                                    RoithiUI.db.profile.font = v; ns.RefreshUnitFrame("player")
                                end, -- Ideal: RefreshAll
                            },
                            statusBar = {
                                type = "select",
                                dialogControl = "LSM30_Statusbar",
                                name = "Global Status Bar",
                                order = 2,
                                values = LSM:HashTable("statusbar"),
                                get = function() return RoithiUI.db.profile.barTexture or "Solid" end,
                                set = function(_, v)
                                    RoithiUI.db.profile.barTexture = v; ns.RefreshUnitFrame("player")
                                end,
                            },
                        },
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
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(RoithiUI.db),
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
            if not RoithiUI.db.profile.UnitFrames[unit] then RoithiUI.db.profile.UnitFrames[unit] = {} end
            return RoithiUI.db.profile.UnitFrames[unit]
        end

        options.args.unitframes.args[unit] = {
            type = "group",
            name = label,
            order = 10 + i,
            args = {


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
                            get = function() return RoithiUI.db.profile.IndicatorTestMode end,
                            set = function(_, v)
                                RoithiUI.db.profile.IndicatorTestMode = v
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
                                    resting = "Resting",
                                }
                                if unit == "target" or unit == "focus" then
                                    v.quest = "Quest"
                                end
                                return v
                            end,
                            get = function() return RoithiUI.db.profile.tempIndicatorSelect end,
                            set = function(_, v) RoithiUI.db.profile.tempIndicatorSelect = v end,
                        },
                        -- Details Group (Only shown if selection made)
                        details = {
                            type = "group",
                            name = "Settings",
                            order = 2,
                            inline = true,
                            hidden = function() return not RoithiUI.db.profile.tempIndicatorSelect end,
                            args = {
                                enabled = {
                                    type = "toggle",
                                    name = "Enable",
                                    order = 1,
                                    get = function()
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.enabled
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
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
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.size or 20
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
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
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.point or "CENTER"
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
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
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.x or 0
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
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
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
                                        local db = GetDB().indicators and GetDB().indicators[k]
                                        return db and db.y or 0
                                    end,
                                    set = function(_, v)
                                        local k = RoithiUI.db.profile.tempIndicatorSelect
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
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if UF and UF.UpdateFrameFromSettings then
        UF:UpdateFrameFromSettings(unit)
    end
end
