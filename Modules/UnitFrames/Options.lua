local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI", true)
local AL = ns.AttachmentLogic
local SafeNum = ns.SafeNum

function ns.BuildUnitAndCastbarOptions(options)
    -- Populate Unit Frame Options
    local units = {
        { "player",       "Player" },
        { "target",       "Target" },
        { "targettarget", "Target of Target" },
        { "focus",        "Focus" },
        { "focustarget",  "Focus Target" },
        { "pet",          "Pet" },
        { "boss1",        "Boss 1" },
        { "boss2",        "Boss 2" },
        { "boss3",        "Boss 3" },
        { "boss4",        "Boss 4" },
        { "boss5",        "Boss 5" },
    }

    for i, u in ipairs(units) do
        local unit, label = u[1], u[2]

        -- Helper to get DB
        local function GetDB()
            if not RoithiUI.db.profile.UnitFrames[unit] then RoithiUI.db.profile.UnitFrames[unit] = {} end
            return RoithiUI.db.profile.UnitFrames[unit]
        end

        local function CreateQuickLinks(currentContext)
            local args = {}
            local order = 1
            local ufUnit = (unit:match("^boss%d$")) and "boss" or unit
            if currentContext ~= "unitframes" then
                args.unitframes = {
                    type = "execute",
                    name = L["> Unit Frames"],
                    order = order,
                    func = function()
                        if unit:find("^boss%d+$") then
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", "boss", unit)
                        else
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", ufUnit)
                        end
                    end,
                }
                order = order + 1
            end
            if currentContext ~= "castbars" and not unit:match("^boss%d$") then
                args.castbars = {
                    type = "execute",
                    name = L["> Castbars"],
                    order = order,
                    func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "castbars", unit) end,
                }
                order = order + 1
            end
            if currentContext ~= "auras" then
                local isBoss = unit:match("^boss%d$")
                args.auras = {
                    type = "execute",
                    name = L["> Auras"],
                    order = order,
                    func = function()
                        if isBoss then
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "units", "bossFrames", unit)
                        else
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "units", unit)
                        end
                    end,
                }
                order = order + 1
            end
            if RoithiUI.Config.GetCustomTagsOptions and currentContext ~= "customtags" then
                args.customtags = {
                    type = "execute",
                    name = L["> Custom Tags"],
                    order = order,
                    func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "customtags", unit) end,
                }
            end
            return {
                type = "group",
                name = L["Quick Links"],
                inline = true,
                order = 999,
                args = args
            }
        end

        if not unit:match("^boss%d$") then
            options.args.unitframes.args[unit] = {
                type = "group",
                name = L[label] or label,
                order = 10 + i,
                args = {
                    frameGroup = {
                        type = "group",
                        name = L["Frame & Layout"],
                        order = 5,
                        inline = true,
                        args = {
                            enable = {
                                type = "toggle",
                                name = L["Enable Unit Frame"],
                                order = 1,
                                get = function()
                                    if not RoithiUI.db.profile.UnitFrames then return true end
                                    if not RoithiUI.db.profile.UnitFrames[unit] then return true end
                                    return RoithiUI.db.profile.UnitFrames[unit].enabled ~= false
                                end,
                                set = function(_, v)
                                    if not RoithiUI.db.profile.UnitFrames then RoithiUI.db.profile.UnitFrames = {} end
                                    if not RoithiUI.db.profile.UnitFrames[unit] then RoithiUI.db.profile.UnitFrames[unit] = {} end
                                    RoithiUI.db.profile.UnitFrames[unit].enabled = v
                                    local ufModule = RoithiUI:GetModule("UnitFrames")
                                    if ufModule then ufModule:ToggleFrame(unit, v) end
                                    if EditModeManagerFrame and EditModeManagerFrame:IsShown() and ns.UpdateBlizzardVisibility then
                                        ns.UpdateBlizzardVisibility()
                                    end
                                end,
                            },
                            width = {
                                type = "range",
                                name = L["Width"],
                                order = 2,
                                min = 50, max = 400, step = 1,
                                scope = "both",
                                get = function() return GetDB().width or 200 end,
                                set = function(_, v)
                                    GetDB().width = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            height = {
                                type = "range",
                                name = L["Height"],
                                order = 3,
                                min = 20, max = 150, step = 1,
                                scope = "both",
                                get = function() return GetDB().height or 40 end,
                                set = function(_, v)
                                    GetDB().height = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            scale = {
                                type = "range",
                                name = L["Scale"],
                                order = 4,
                                min = 0.5, max = 2.0, step = 0.05,
                                scope = "both",
                                get = function() return GetDB().scale or 1.0 end,
                                set = function(_, v)
                                    GetDB().scale = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            x = {
                                type = "range",
                                name = L["X Position"],
                                order = 5,
                                min = -2500, max = 2500, step = 1,
                                scope = "both",
                                get = function() return GetDB().x or 0 end,
                                set = function(_, v)
                                    GetDB().x = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            y = {
                                type = "range",
                                name = L["Y Position"],
                                order = 6,
                                min = -1500, max = 1500, step = 1,
                                scope = "both",
                                get = function() return GetDB().y or 0 end,
                                set = function(_, v)
                                    GetDB().y = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                        }
                    },
                    powerGroup = {
                        type = "group",
                        name = L["Power Bar"],
                        order = 10,
                        args = (function()
                            local pArgs = {
                                powerEnabled = {
                                    type = "toggle",
                                    name = L["Enable Power"],
                                    order = 1,
                                    scope = "both",
                                    get = function() return GetDB().powerEnabled ~= false end,
                                    set = function(_, v)
                                        GetDB().powerEnabled = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                },
                                powerHeight = {
                                    type = "range",
                                    name = L["Power Height"],
                                    order = 2,
                                    min = 1, max = 50, step = 1,
                                    scope = "both",
                                    get = function() return GetDB().powerHeight or 10 end,
                                    set = function(_, v)
                                        GetDB().powerHeight = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                },
                                powerDetached = {
                                    type = "toggle",
                                    name = L["Detached"],
                                    order = 3,
                                    scope = "both",
                                    get = function() return GetDB().powerDetached == true end,
                                    set = function(_, v)
                                        GetDB().powerDetached = v
                                        if v == true and not GetDB().powerWidth then
                                            GetDB().powerWidth = 180
                                        end
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                },
                                powerWidth = {
                                    type = "range",
                                    name = L["Power Width"],
                                    order = 4,
                                    min = 50, max = 400, step = 1,
                                    scope = "both",
                                    get = function() return GetDB().powerWidth or 180 end,
                                    set = function(_, v)
                                        GetDB().powerWidth = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                    hidden = function() return not GetDB().powerDetached end,
                                },
                                powerX = {
                                    type = "range",
                                    name = L["X Position"],
                                    order = 5,
                                    min = -1000, max = 1000, step = 1,
                                    scope = "both",
                                    get = function() return GetDB().powerX or 0 end,
                                    set = function(_, v)
                                        GetDB().powerX = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                    hidden = function() return not GetDB().powerDetached end,
                                },
                                powerY = {
                                    type = "range",
                                    name = L["Y Position"],
                                    order = 6,
                                    min = -1000, max = 1000, step = 1,
                                    scope = "both",
                                    get = function() return GetDB().powerY or -50 end,
                                    set = function(_, v)
                                        GetDB().powerY = v
                                        ns.RefreshUnitFrame(unit)
                                    end,
                                    hidden = function() return not GetDB().powerDetached end,
                                },
                            }

                            if unit == "player" then
                                pArgs.classPowerGroup = {
                                    type = "group",
                                    name = L["Class Power"],
                                    order = 10,
                                    inline = true,
                                    args = {
                                        classPowerEnabled = {
                                            type = "toggle",
                                            name = L["Enable Class Power"],
                                            order = 1,
                                            scope = "both",
                                            get = function() return GetDB().classPowerEnabled ~= false end,
                                            set = function(_, v)
                                                GetDB().classPowerEnabled = v
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                        },
                                        classPowerHeight = {
                                            type = "range",
                                            name = L["Height"],
                                            order = 2,
                                            min = 2, max = 50, step = 1,
                                            scope = "both",
                                            get = function() return GetDB().classPowerHeight or 10 end,
                                            set = function(_, v)
                                                GetDB().classPowerHeight = v
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                        },
                                        classPowerDetached = {
                                            type = "toggle",
                                            name = L["Detached"],
                                            order = 3,
                                            scope = "both",
                                            get = function() return GetDB().classPowerDetached == true end,
                                            set = function(_, v)
                                                GetDB().classPowerDetached = v
                                                if v == true and not GetDB().classPowerWidth then
                                                    GetDB().classPowerWidth = 200
                                                end
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                        },
                                        classPowerWidth = {
                                            type = "range",
                                            name = L["Width"],
                                            order = 4,
                                            min = 50, max = 400, step = 1,
                                            scope = "both",
                                            get = function() return math.floor((GetDB().classPowerWidth or 200) + 0.5) end,
                                            set = function(_, v)
                                                GetDB().classPowerWidth = math.floor(v + 0.5)
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                            hidden = function() return not GetDB().classPowerDetached end,
                                        },
                                        classPowerX = {
                                            type = "range",
                                            name = L["X Position"],
                                            order = 5,
                                            min = -1000, max = 1000, step = 1,
                                            scope = "both",
                                            get = function() return GetDB().classPowerX or 0 end,
                                            set = function(_, v)
                                                GetDB().classPowerX = v
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                            hidden = function() return not GetDB().classPowerDetached end,
                                        },
                                        classPowerY = {
                                            type = "range",
                                            name = L["Y Position"],
                                            order = 6,
                                            min = -1000, max = 1000, step = 1,
                                            scope = "both",
                                            get = function() return GetDB().classPowerY or -50 end,
                                            set = function(_, v)
                                                GetDB().classPowerY = v
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                            hidden = function() return not GetDB().classPowerDetached end,
                                        },
                                    }
                                }

                                pArgs.additionalPowerGroup = {
                                    type = "group",
                                    name = L["Additional Power"],
                                    order = 20,
                                    inline = true,
                                    args = {
                                        additionalPowerEnabled = {
                                            type = "toggle",
                                            name = L["Enable Additional Power"],
                                            order = 1,
                                            scope = "both",
                                            get = function() return GetDB().additionalPowerEnabled ~= false end,
                                            set = function(_, v)
                                                GetDB().additionalPowerEnabled = v
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                        },
                                        additionalPowerHeight = {
                                            type = "range",
                                            name = L["Height"],
                                            order = 2,
                                            min = 2, max = 50, step = 1,
                                            scope = "both",
                                            get = function() return GetDB().additionalPowerHeight or 10 end,
                                            set = function(_, v)
                                                GetDB().additionalPowerHeight = v
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                        },
                                        additionalPowerDetached = {
                                            type = "toggle",
                                            name = L["Detached"],
                                            order = 3,
                                            scope = "both",
                                            get = function() return GetDB().additionalPowerDetached == true end,
                                            set = function(_, v)
                                                GetDB().additionalPowerDetached = v
                                                if v == true and not GetDB().additionalPowerWidth then
                                                    GetDB().additionalPowerWidth = 200
                                                end
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                        },
                                        additionalPowerWidth = {
                                            type = "range",
                                            name = L["Width"],
                                            order = 4,
                                            min = 50, max = 400, step = 1,
                                            scope = "both",
                                            get = function() return math.floor((GetDB().additionalPowerWidth or 200) + 0.5) end,
                                            set = function(_, v)
                                                GetDB().additionalPowerWidth = math.floor(v + 0.5)
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                            hidden = function() return not GetDB().additionalPowerDetached end,
                                        },
                                        additionalPowerX = {
                                            type = "range",
                                            name = L["X Position"],
                                            order = 5,
                                            min = -1000, max = 1000, step = 1,
                                            scope = "both",
                                            get = function() return GetDB().additionalPowerX or 0 end,
                                            set = function(_, v)
                                                GetDB().additionalPowerX = v
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                            hidden = function() return not GetDB().additionalPowerDetached end,
                                        },
                                        additionalPowerY = {
                                            type = "range",
                                            name = L["Y Position"],
                                            order = 6,
                                            min = -1000, max = 1000, step = 1,
                                            scope = "both",
                                            get = function() return GetDB().additionalPowerY or -50 end,
                                            set = function(_, v)
                                                GetDB().additionalPowerY = v
                                                ns.RefreshUnitFrame(unit)
                                            end,
                                            hidden = function() return not GetDB().additionalPowerDetached end,
                                        },
                                    }
                                }
                            end

                            return pArgs
                        end)()
                    },
                    aurasGroup = {
                        type = "group",
                        name = L["Auras"],
                        order = 20,
                        args = {
                            aurasEnabled = {
                                type = "toggle",
                                name = L["Enable Auras"],
                                order = 1,
                                scope = "both",
                                get = function() return GetDB().aurasEnabled ~= false end,
                                set = function(_, v)
                                    GetDB().aurasEnabled = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            showBuffs = {
                                type = "toggle",
                                name = L["Show Buffs"],
                                order = 2,
                                scope = "both",
                                get = function() return GetDB().showBuffs ~= false end,
                                set = function(_, v)
                                    GetDB().showBuffs = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            showDebuffs = {
                                type = "toggle",
                                name = L["Show Debuffs"],
                                order = 3,
                                scope = "both",
                                get = function() return GetDB().showDebuffs ~= false end,
                                set = function(_, v)
                                    GetDB().showDebuffs = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            separateAuras = {
                                type = "toggle",
                                name = L["Separate Buffs & Debuffs"],
                                desc = L["When checked, Buffs and Debuffs anchor separately instead of flowing consecutively."],
                                order = 3.5,
                                scope = "both",
                                get = function() return GetDB().separateAuras == true end,
                                set = function(_, v)
                                    GetDB().separateAuras = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            ShowOnlyPlayer = {
                                type = "toggle",
                                name = L["Show Only My Auras"],
                                order = 4,
                                scope = "both",
                                get = function() return GetDB().ShowOnlyPlayer == true end,
                                set = function(_, v)
                                    GetDB().ShowOnlyPlayer = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            auraSize = {
                                type = "range",
                                name = L["Aura Size"],
                                order = 5,
                                min = 10, max = 40, step = 1,
                                scope = "both",
                                get = function() return GetDB().auraSize or 20 end,
                                set = function(_, v)
                                    GetDB().auraSize = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            maxAuras = {
                                type = "range",
                                name = L["Max Auras"],
                                order = 6,
                                min = 1, max = 20, step = 1,
                                scope = "both",
                                get = function() return GetDB().maxAuras or 4 end,
                                set = function(_, v)
                                    GetDB().maxAuras = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            auraAnchor = {
                                type = "select",
                                name = L["Anchor Point"],
                                order = 7,
                                scope = "both",
                                values = {
                                    ["TOPLEFT"] = "Top Left",
                                    ["LEFT"] = "Left",
                                    ["BOTTOMLEFT"] = "Bottom Left",
                                    ["TOP"] = "Top",
                                    ["CENTER"] = "Center",
                                    ["BOTTOM"] = "Bottom",
                                    ["TOPRIGHT"] = "Top Right",
                                    ["RIGHT"] = "Right",
                                    ["BOTTOMRIGHT"] = "Bottom Right"
                                },
                                get = function() return GetDB().auraAnchor or "BOTTOM" end,
                                set = function(_, v)
                                    GetDB().auraAnchor = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            auraGrowDirection = {
                                type = "select",
                                name = L["Grow Direction"],
                                order = 8,
                                scope = "both",
                                values = {
                                    ["RIGHT_DOWN"]             = "Right then Down",
                                    ["RIGHT_UP"]               = "Right then Up",
                                    ["LEFT_DOWN"]              = "Left then Down",
                                    ["LEFT_UP"]                = "Left then Up",
                                    ["DOWN_RIGHT"]             = "Down then Right",
                                    ["DOWN_LEFT"]              = "Down then Left",
                                    ["UP_RIGHT"]               = "Up then Right",
                                    ["UP_LEFT"]                = "Up then Left",
                                    ["CENTER_HORIZONTAL"]      = "Centered Horizontal",
                                    ["CENTER_VERTICAL"]        = "Centered Vertical",
                                },
                                sorting = { "RIGHT_DOWN", "RIGHT_UP", "LEFT_DOWN", "LEFT_UP", "DOWN_RIGHT", "DOWN_LEFT", "UP_RIGHT", "UP_LEFT", "CENTER_HORIZONTAL", "CENTER_VERTICAL" },
                                get = function()
                                    local dir = GetDB().auraGrowDirection
                                    if dir == "RIGHT" then return "RIGHT_DOWN" end
                                    if dir == "LEFT" then return "LEFT_DOWN" end
                                    return dir or "RIGHT_DOWN"
                                end,
                                set = function(_, v)
                                    GetDB().auraGrowDirection = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            auraX = {
                                type = "range",
                                name = L["Aura X"],
                                order = 9,
                                min = -100, max = 100, step = 1,
                                scope = "both",
                                get = function() return GetDB().auraX or 0 end,
                                set = function(_, v)
                                    GetDB().auraX = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                            auraY = {
                                type = "range",
                                name = L["Aura Y"],
                                order = 10,
                                min = -100, max = 100, step = 1,
                                scope = "both",
                                get = function() return GetDB().auraY or 4 end,
                                set = function(_, v)
                                    GetDB().auraY = v
                                    ns.RefreshUnitFrame(unit)
                                end,
                            },
                        }
                    },
                    quickLinks = CreateQuickLinks("unitframes"),

                    -- Tab: Indicators
                    indicators = {
                        type = "group",
                        name = L["Indicators"],
                        order = 2,
                        inline = true,
                        args = {
                            testMode = {
                                type = "toggle",
                                name = L["|cffffd100Test Mode|r"],
                                desc  = L["Force show all enabled indicators for easier configuration."],
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
                                name = L["Select Indicator"],
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
                                name = L["Settings"],
                                order = 2,
                                inline = true,
                                hidden = function() return not RoithiUI.db.profile.tempIndicatorSelect end,
                                args = {
                                    enabled = {
                                        type = "toggle",
                                        name = L["Enable"],
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
                                        name = L["Size"],
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
                                        name = L["Anchor Point"],
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
                                        name = L["X Offset"],
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
                                        name = L["Y Offset"],
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
                },
            }
        end

        -- Populate the Global > Auras > Units table safely if auras options tree exists
        if options and options.args and options.args.auras and options.args.auras.args and options.args.auras.args.units and options.args.auras.args.units.args then
            local targetArgs = options.args.auras.args.units.args
            if unit:match("^boss%d$") then
                if not targetArgs.bossFrames then
                    targetArgs.bossFrames = {
                        type = "group",
                        name = L["Boss Frames"],
                        order = 30,
                        args = {}
                    }
                end
                targetArgs = targetArgs.bossFrames.args
            end

            targetArgs[unit] = {
            type = "group",
            name = L[label] or label,
            order = i,
            args = {
                enable = {
                    type = "toggle",
                    name = L["Enable"],
                    order = 1,
                    get = function() return GetDB().aurasEnabled ~= false end,
                    set = function(_, v)
                        GetDB().aurasEnabled = v; ns.RefreshUnitFrame(unit)
                    end,
                },
                showBuffs = {
                    type = "toggle",
                    name = L["Show Buffs"],
                    order = 2,
                    get = function() return GetDB().showBuffs ~= false end,
                    set = function(_, v)
                        GetDB().showBuffs = v; ns.RefreshUnitFrame(unit)
                    end,
                },
                showDebuffs = {
                    type = "toggle",
                    name = L["Show Debuffs"],
                    order = 2.1,
                    get = function() return GetDB().showDebuffs ~= false end,
                    set = function(_, v)
                        GetDB().showDebuffs = v; ns.RefreshUnitFrame(unit)
                    end,
                },
                separateAuras = {
                    type = "toggle",
                    name = L["Separate Buffs & Debuffs"],
                    desc = L["When checked, Buffs and Debuffs anchor separately instead of flowing consecutively."],
                    order = 2.2,
                    get = function() return GetDB().separateAuras == true end,
                    set = function(_, v)
                        GetDB().separateAuras = v; ns.RefreshUnitFrame(unit)
                    end,
                },
                quickLinks = CreateQuickLinks("auras"),

                size = {
                    type = "range",
                    name = L["Size"],
                    order = 3,
                    min = 10,
                    max = 100,
                    step = 1,
                    get = function() return SafeNum(GetDB().auraSize, 20) end,
                    set = function(_, v)
                        GetDB().auraSize = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                spacing = {
                    type = "range",
                    name = L["Spacing"],
                    order = 3.5,
                    min = 0,
                    max = 40,
                    step = 1,
                    get = function() return SafeNum(GetDB().auraSpacing, 4) end,
                    set = function(_, v)
                        GetDB().auraSpacing = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                max = {
                    type = "range",
                    name = L["Max Auras"],
                    desc = L["Maximum number of total aura icons to display."],
                    order = 4,
                    min = 1,
                    max = 40,
                    step = 1,
                    get = function() return SafeNum(GetDB().maxAuras, 16) end,
                    set = function(_, v)
                        GetDB().maxAuras = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                perRow = {
                    type = "range",
                    name = L["Icons Per Row"],
                    desc = L["Number of aura icons per row before line wrapping."],
                    order = 4.5,
                    min = 1,
                    max = 20,
                    step = 1,
                    get = function() return SafeNum(GetDB().aurasPerRow, 8) end,
                    set = function(_, v)
                        GetDB().aurasPerRow = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                anchor = {
                    type = "select",
                    name = L["Anchor Point"],
                    order = 5,
                    values = {
                        ["TOPLEFT"] = "Top Left",
                        ["LEFT"] = "Left",
                        ["BOTTOMLEFT"] = "Bottom Left",
                        ["TOP"] = "Top",
                        ["CENTER"] = "Center",
                        ["BOTTOM"] = "Bottom",
                        ["TOPRIGHT"] = "Top Right",
                        ["RIGHT"] = "Right",
                        ["BOTTOMRIGHT"] = "Bottom Right"
                    },
                    sorting = { "TOPLEFT", "LEFT", "BOTTOMLEFT", "TOP", "CENTER", "BOTTOM", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT" },
                    get = function() return GetDB().auraAnchor or "BOTTOM" end,
                    set = function(_, v)
                        GetDB().auraAnchor = v; ns.RefreshUnitFrame(unit)
                    end,
                    disabled = function() return GetDB().auraDetached == true end,
                    hidden = function() return GetDB().separateAuras end,
                },
                grow = {
                    type = "select",
                    name = L["Grow Direction"],
                    order = 6,
                    values = {
                        ["RIGHT_DOWN"]             = "Right then Down",
                        ["RIGHT_UP"]               = "Right then Up",
                        ["LEFT_DOWN"]              = "Left then Down",
                        ["LEFT_UP"]                = "Left then Up",
                        ["DOWN_RIGHT"]             = "Down then Right",
                        ["DOWN_LEFT"]              = "Down then Left",
                        ["UP_RIGHT"]               = "Up then Right",
                        ["UP_LEFT"]                = "Up then Left",
                        ["CENTER_HORIZONTAL"]      = "Centered Horizontal",
                        -- ["CENTER_HORIZONTAL_DOWN"] = "Centered Horizontal (Grow Down)",
                        -- ["CENTER_HORIZONTAL_UP"]   = "Centered Horizontal (Grow Up)",
                        ["CENTER_VERTICAL"]        = "Centered Vertical",
                        -- ["CENTER_VERTICAL_RIGHT"]  = "Centered Vertical (Grow Right)",
                        -- ["CENTER_VERTICAL_LEFT"]   = "Centered Vertical (Grow Left)",
                    },
                    sorting = { "RIGHT_DOWN", "RIGHT_UP", "LEFT_DOWN", "LEFT_UP", "DOWN_RIGHT", "DOWN_LEFT", "UP_RIGHT", "UP_LEFT", "CENTER_HORIZONTAL", "CENTER_VERTICAL" --[[, "CENTER_HORIZONTAL_DOWN", "CENTER_HORIZONTAL_UP", "CENTER_VERTICAL_RIGHT", "CENTER_VERTICAL_LEFT"]] },
                    get = function() return GetDB().auraGrowDirection or "RIGHT_DOWN" end,
                    set = function(_, v)
                        GetDB().auraGrowDirection = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                x = {
                    type = "range",
                    name = L["X Offset (Attached)"],
                    order = 7,
                    min = -1000,
                    max = 1000,
                    step = 1,
                    get = function() return SafeNum(GetDB().auraX, 0) end,
                    set = function(_, v)
                        GetDB().auraX = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras or GetDB().auraDetached == true end,
                },
                y = {
                    type = "range",
                    name = L["Y Offset (Attached)"],
                    order = 8,
                    min = -1000,
                    max = 1000,
                    step = 1,
                    get = function() return SafeNum(GetDB().auraY, 4) end,
                    set = function(_, v)
                        GetDB().auraY = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras or GetDB().auraDetached == true end,
                },
                detached = {
                    type = "toggle",
                    name = L["Detach (Satellite Mode)"],
                    desc  = L["Detach aura frame to move it independently via Edit Mode."],
                    order = 9,
                    get = function() return AL:IsDetached(unit, "Auras") end,
                    set = function(_, v)
                        GetDB().auraDetached = v
                        ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                screenX = {
                    type = "range",
                    name = L["X Position (Detached)"],
                    order = 7,
                    min = -1000,
                    max = 1000,
                    step = 1,
                    get = function() return SafeNum(GetDB().auraScreenX, 0) end,
                    set = function(_, v)
                        GetDB().auraScreenX = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras or not GetDB().auraDetached end,
                },
                screenY = {
                    type = "range",
                    name = L["Y Position (Detached)"],
                    order = 8,
                    min = -1000,
                    max = 1000,
                    step = 1,
                    get = function() return SafeNum(GetDB().auraScreenY, 0) end,
                    set = function(_, v)
                        GetDB().auraScreenY = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras or not GetDB().auraDetached end,
                },
                buffGroup = {
                    type = "group",
                    name = L["Buffs Bar Settings"],
                    order = 9.1,
                    hidden = function() return not GetDB().separateAuras end,
                    args = {
                        size = {
                            type = "range",
                            name = L["Size"],
                            order = 1,
                            min = 10,
                            max = 100,
                            step = 1,
                            get = function() return SafeNum(GetDB().buffSize or GetDB().auraSize, 20) end,
                            set = function(_, v)
                                GetDB().buffSize = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        max = {
                            type = "range",
                            name = L["Max Auras"],
                            desc = L["Maximum number of total aura icons to display."],
                            order = 2,
                            min = 1,
                            max = 40,
                            step = 1,
                            get = function() return SafeNum(GetDB().buffMaxAuras or GetDB().maxAuras, 16) end,
                            set = function(_, v)
                                GetDB().buffMaxAuras = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        perRow = {
                            type = "range",
                            name = L["Icons Per Row"],
                            desc = L["Number of aura icons per row before line wrapping."],
                            order = 2.5,
                            min = 1,
                            max = 20,
                            step = 1,
                            get = function() return SafeNum(GetDB().buffsPerRow or GetDB().aurasPerRow, 8) end,
                            set = function(_, v)
                                GetDB().buffsPerRow = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        spacing = {
                            type = "range",
                            name = L["Spacing"],
                            order = 3,
                            min = 0,
                            max = 40,
                            step = 1,
                            get = function() return SafeNum(GetDB().buffSpacing or GetDB().auraSpacing, 4) end,
                            set = function(_, v)
                                GetDB().buffSpacing = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        anchor = {
                            type = "select",
                            name = L["Anchor Point"],
                            order = 4,
                            values = {
                                ["TOPLEFT"] = "Top Left",
                                ["LEFT"] = "Left",
                                ["BOTTOMLEFT"] = "Bottom Left",
                                ["TOP"] = "Top",
                                ["CENTER"] = "Center",
                                ["BOTTOM"] = "Bottom",
                                ["TOPRIGHT"] = "Top Right",
                                ["RIGHT"] = "Right",
                                ["BOTTOMRIGHT"] = "Bottom Right"
                            },
                            sorting = { "TOPLEFT", "LEFT", "BOTTOMLEFT", "TOP", "CENTER", "BOTTOM", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT" },
                            get = function() return GetDB().buffAnchor or GetDB().auraAnchor or "BOTTOM" end,
                            set = function(_, v)
                                GetDB().buffAnchor = v; ns.RefreshUnitFrame(unit)
                            end,
                            disabled = function() return GetDB().buffDetached == true end,
                        },
                        grow = {
                            type = "select",
                            name = L["Grow Direction"],
                            order = 5,
                            values = {
                                ["RIGHT_DOWN"]             = "Right then Down",
                                ["RIGHT_UP"]               = "Right then Up",
                                ["LEFT_DOWN"]              = "Left then Down",
                                ["LEFT_UP"]                = "Left then Up",
                                ["DOWN_RIGHT"]             = "Down then Right",
                                ["DOWN_LEFT"]              = "Down then Left",
                                ["UP_RIGHT"]               = "Up then Right",
                                ["UP_LEFT"]                = "Up then Left",
                                ["CENTER_HORIZONTAL"]      = "Centered Horizontal",
                                -- ["CENTER_HORIZONTAL_DOWN"] = "Centered Horizontal (Grow Down)",
                                -- ["CENTER_HORIZONTAL_UP"]   = "Centered Horizontal (Grow Up)",
                                ["CENTER_VERTICAL"]        = "Centered Vertical",
                                -- ["CENTER_VERTICAL_RIGHT"]  = "Centered Vertical (Grow Right)",
                                -- ["CENTER_VERTICAL_LEFT"]   = "Centered Vertical (Grow Left)",
                            },
                            sorting = { "RIGHT_DOWN", "RIGHT_UP", "LEFT_DOWN", "LEFT_UP", "DOWN_RIGHT", "DOWN_LEFT", "UP_RIGHT", "UP_LEFT", "CENTER_HORIZONTAL", "CENTER_VERTICAL" --[[, "CENTER_HORIZONTAL_DOWN", "CENTER_HORIZONTAL_UP", "CENTER_VERTICAL_RIGHT", "CENTER_VERTICAL_LEFT"]] },
                            get = function() return GetDB().buffGrowDirection or GetDB().auraGrowDirection or "RIGHT_DOWN" end,
                            set = function(_, v)
                                GetDB().buffGrowDirection = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        detached = {
                            type = "toggle",
                            name = L["Detach (Move in Edit Mode)"],
                            order = 6,
                            get = function() return GetDB().buffDetached == true end,
                            set = function(_, v)
                                GetDB().buffDetached = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        x = {
                            type = "range",
                            name = L["X Offset (Attached)"],
                            order = 7,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return SafeNum(GetDB().buffXOffset or GetDB().auraX, 0) end,
                            set = function(_, v)
                                GetDB().buffXOffset = v; ns.RefreshUnitFrame(unit)
                            end,
                            hidden = function() return GetDB().buffDetached == true end,
                        },
                        y = {
                            type = "range",
                            name = L["Y Offset (Attached)"],
                            order = 8,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return SafeNum(GetDB().buffYOffset or GetDB().auraY, 4) end,
                            set = function(_, v)
                                GetDB().buffYOffset = v; ns.RefreshUnitFrame(unit)
                            end,
                            hidden = function() return GetDB().buffDetached == true end,
                        },
                        screenX = {
                            type = "range",
                            name = L["X Position (Detached)"],
                            order = 7,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return SafeNum(GetDB().buffScreenX, 0) end,
                            set = function(_, v)
                                GetDB().buffScreenX = v; ns.RefreshUnitFrame(unit)
                            end,
                            hidden = function() return not GetDB().buffDetached end,
                        },
                        screenY = {
                            type = "range",
                            name = L["Y Position (Detached)"],
                            order = 8,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return SafeNum(GetDB().buffScreenY, 0) end,
                            set = function(_, v)
                                GetDB().buffScreenY = v; ns.RefreshUnitFrame(unit)
                            end,
                            hidden = function() return not GetDB().buffDetached end,
                        },
                    }
                },
                debuffGroup = {
                    type = "group",
                    name = L["Debuffs Bar Settings"],
                    order = 9.2,
                    hidden = function() return not GetDB().separateAuras end,
                    args = {
                        size = {
                            type = "range",
                            name = L["Size"],
                            order = 1,
                            min = 10,
                            max = 100,
                            step = 1,
                            get = function() return SafeNum(GetDB().debuffSize or GetDB().auraSize, 20) end,
                            set = function(_, v)
                                GetDB().debuffSize = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        max = {
                            type = "range",
                            name = L["Max Auras"],
                            desc = L["Maximum number of total aura icons to display."],
                            order = 2,
                            min = 1,
                            max = 40,
                            step = 1,
                            get = function() return SafeNum(GetDB().debuffMaxAuras or GetDB().maxAuras, 16) end,
                            set = function(_, v)
                                GetDB().debuffMaxAuras = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        perRow = {
                            type = "range",
                            name = L["Icons Per Row"],
                            desc = L["Number of aura icons per row before line wrapping."],
                            order = 2.5,
                            min = 1,
                            max = 20,
                            step = 1,
                            get = function() return SafeNum(GetDB().debuffsPerRow or GetDB().aurasPerRow, 8) end,
                            set = function(_, v)
                                GetDB().debuffsPerRow = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        spacing = {
                            type = "range",
                            name = L["Spacing"],
                            order = 3,
                            min = 0,
                            max = 40,
                            step = 1,
                            get = function() return SafeNum(GetDB().debuffSpacing or GetDB().auraSpacing, 4) end,
                            set = function(_, v)
                                GetDB().debuffSpacing = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        anchor = {
                            type = "select",
                            name = L["Anchor Point"],
                            order = 4,
                            values = {
                                ["TOPLEFT"] = "Top Left",
                                ["LEFT"] = "Left",
                                ["BOTTOMLEFT"] = "Bottom Left",
                                ["TOP"] = "Top",
                                ["CENTER"] = "Center",
                                ["BOTTOM"] = "Bottom",
                                ["TOPRIGHT"] = "Top Right",
                                ["RIGHT"] = "Right",
                                ["BOTTOMRIGHT"] = "Bottom Right"
                            },
                            sorting = { "TOPLEFT", "LEFT", "BOTTOMLEFT", "TOP", "CENTER", "BOTTOM", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT" },
                            get = function() return GetDB().debuffAnchor or GetDB().auraAnchor or "BOTTOM" end,
                            set = function(_, v)
                                GetDB().debuffAnchor = v; ns.RefreshUnitFrame(unit)
                            end,
                            disabled = function() return GetDB().debuffDetached == true end,
                        },
                        grow = {
                            type = "select",
                            name = L["Grow Direction"],
                            order = 5,
                            values = {
                                ["RIGHT_DOWN"]             = "Right then Down",
                                ["RIGHT_UP"]               = "Right then Up",
                                ["LEFT_DOWN"]              = "Left then Down",
                                ["LEFT_UP"]                = "Left then Up",
                                ["DOWN_RIGHT"]             = "Down then Right",
                                ["DOWN_LEFT"]              = "Down then Left",
                                ["UP_RIGHT"]               = "Up then Right",
                                ["UP_LEFT"]                = "Up then Left",
                                ["CENTER_HORIZONTAL"]      = "Centered Horizontal",
                                ["CENTER_VERTICAL"]        = "Centered Vertical",
                            },
                            sorting = { "RIGHT_DOWN", "RIGHT_UP", "LEFT_DOWN", "LEFT_UP", "DOWN_RIGHT", "DOWN_LEFT", "UP_RIGHT", "UP_LEFT", "CENTER_HORIZONTAL", "CENTER_VERTICAL" },
                            get = function()
                                local dir = GetDB().debuffGrowDirection or GetDB().auraGrowDirection
                                if dir == "RIGHT" then return "RIGHT_DOWN" end
                                if dir == "LEFT" then return "LEFT_DOWN" end
                                return dir or "RIGHT_DOWN"
                            end,
                            set = function(_, v)
                                GetDB().debuffGrowDirection = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        detached = {
                            type = "toggle",
                            name = L["Detach (Move in Edit Mode)"],
                            order = 6,
                            get = function() return GetDB().debuffDetached == true end,
                            set = function(_, v)
                                GetDB().debuffDetached = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        x = {
                            type = "range",
                            name = L["X Offset (Attached)"],
                            order = 7,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return SafeNum(GetDB().debuffXOffset or GetDB().auraX, 0) end,
                            set = function(_, v)
                                GetDB().debuffXOffset = v; ns.RefreshUnitFrame(unit)
                            end,
                            hidden = function() return GetDB().debuffDetached == true end,
                        },
                        y = {
                            type = "range",
                            name = L["Y Offset (Attached)"],
                            order = 8,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return SafeNum(GetDB().debuffYOffset or GetDB().auraY, 4) end,
                            set = function(_, v)
                                GetDB().debuffYOffset = v; ns.RefreshUnitFrame(unit)
                            end,
                            hidden = function() return GetDB().debuffDetached == true end,
                        },
                        screenX = {
                            type = "range",
                            name = L["X Position (Detached)"],
                            order = 7,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return SafeNum(GetDB().debuffScreenX, 0) end,
                            set = function(_, v)
                                GetDB().debuffScreenX = v; ns.RefreshUnitFrame(unit)
                            end,
                            hidden = function() return not GetDB().debuffDetached end,
                        },
                        screenY = {
                            type = "range",
                            name = L["Y Position (Detached)"],
                            order = 8,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return SafeNum(GetDB().debuffScreenY, 0) end,
                            set = function(_, v)
                                GetDB().debuffScreenY = v; ns.RefreshUnitFrame(unit)
                            end,
                            hidden = function() return not GetDB().debuffDetached end,
                        },
                    }
                },
                styling = {
                    type = "group",
                    name = L["Styling & Texts"],
                    order = 9.5,
                    inline = true,
                    args = {

                        zoom = {
                            type = "range",
                            name = L["Icon Zoom (%)"],
                            order = 2,
                            min = 0,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().zoomPercent ~= nil and GetDB().zoomPercent or 15 end,
                            set = function(_, v)
                                GetDB().zoomPercent = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        -- Timer Settings:
                        timerFontSize = {
                            type = "range",
                            name = L["Timer Font Size"],
                            order = 10,
                            min = 6,
                            max = 24,
                            step = 1,
                            get = function() return GetDB().timerFontSize or 10 end,
                            set = function(_, v)
                                GetDB().timerFontSize = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        timerAnchor = {
                            type = "select",
                            name = L["Timer Anchor"],
                            order = 11,
                            values = {
                                ["TOPLEFT"] = "Top Left",
                                ["LEFT"] = "Left",
                                ["BOTTOMLEFT"] = "Bottom Left",
                                ["TOP"] = "Top",
                                ["CENTER"] = "Center",
                                ["BOTTOM"] = "Bottom",
                                ["TOPRIGHT"] = "Top Right",
                                ["RIGHT"] = "Right",
                                ["BOTTOMRIGHT"] = "Bottom Right"
                            },
                            sorting = { "TOPLEFT", "LEFT", "BOTTOMLEFT", "TOP", "CENTER", "BOTTOM", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT" },
                            get = function() return GetDB().timerAnchor or "CENTER" end,
                            set = function(_, v)
                                GetDB().timerAnchor = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        timerX = {
                            type = "range",
                            name = L["Timer X Offset"],
                            order = 12,
                            min = -50,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().timerX or 0 end,
                            set = function(_, v)
                                GetDB().timerX = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        timerY = {
                            type = "range",
                            name = L["Timer Y Offset"],
                            order = 13,
                            min = -50,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().timerY or 0 end,
                            set = function(_, v)
                                GetDB().timerY = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        -- Stack Settings:
                        stackFontSize = {
                            type = "range",
                            name = L["Stack Font Size"],
                            order = 20,
                            min = 6,
                            max = 24,
                            step = 1,
                            get = function() return GetDB().stackFontSize or 10 end,
                            set = function(_, v)
                                GetDB().stackFontSize = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        stackAnchor = {
                            type = "select",
                            name = L["Stack Anchor"],
                            order = 21,
                            values = {
                                ["TOPLEFT"] = "Top Left",
                                ["LEFT"] = "Left",
                                ["BOTTOMLEFT"] = "Bottom Left",
                                ["TOP"] = "Top",
                                ["CENTER"] = "Center",
                                ["BOTTOM"] = "Bottom",
                                ["TOPRIGHT"] = "Top Right",
                                ["RIGHT"] = "Right",
                                ["BOTTOMRIGHT"] = "Bottom Right"
                            },
                            sorting = { "TOPLEFT", "LEFT", "BOTTOMLEFT", "TOP", "CENTER", "BOTTOM", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT" },
                            get = function() return GetDB().stackAnchor or "BOTTOMRIGHT" end,
                            set = function(_, v)
                                GetDB().stackAnchor = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        stackX = {
                            type = "range",
                            name = L["Stack X Offset"],
                            order = 22,
                            min = -50,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().stackX or 2 end,
                            set = function(_, v)
                                GetDB().stackX = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        stackY = {
                            type = "range",
                            name = L["Stack Y Offset"],
                            order = 23,
                            min = -50,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().stackY or -2 end,
                            set = function(_, v)
                                GetDB().stackY = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                    }
                },
                filtersAndVisibility = {
                    type = "group",
                    name = L["Filters & Layout"],
                    order = 10,
                    args = (ns.GenerateAuraFilters and ns.GenerateAuraFilters(GetDB, function() ns.RefreshUnitFrame(unit) end)) or {},
                }
            }
        }
        end
    end

    -- Add Boss Frames settings to Unit Frames group
    options.args.unitframes.args["boss"] = {
        type = "group",
        name = L["Boss Frames"],
        order = 30,
        args = {
            enable = {
                type = "toggle",
                name = L["Enable Boss Frames"],
                order = 1,
                get = function()
                    if not RoithiUI.db.profile.UnitFrames then return true end
                    if not RoithiUI.db.profile.UnitFrames["boss1"] then return true end
                    return RoithiUI.db.profile.UnitFrames["boss1"].enabled ~= false
                end,
                set = function(_, v)
                    if not RoithiUI.db.profile.UnitFrames then RoithiUI.db.profile.UnitFrames = {} end
                    local ufModule = RoithiUI:GetModule("UnitFrames")
                    for i = 1, 5 do
                        local bUnit = "boss" .. i
                        if unpack and not RoithiUI.db.profile.UnitFrames[bUnit] then RoithiUI.db.profile.UnitFrames[bUnit] = {} end
                        RoithiUI.db.profile.UnitFrames[bUnit].enabled = v
                        if ufModule then ufModule:ToggleFrame(bUnit, v) end
                    end
                    if EditModeManagerFrame and EditModeManagerFrame:IsShown() and ns.UpdateBlizzardVisibility then
                        ns
                            .UpdateBlizzardVisibility()
                    end
                end,
            },
        }
    }

    -- Per-Boss sub-groups (boss1–boss5)
    local bossUnitList = { "boss1", "boss2", "boss3", "boss4", "boss5" }
    for bossIdx, bUnit in ipairs(bossUnitList) do
        local bLabel = "Boss " .. bossIdx
        local function GetBossDB()
            if not RoithiUI.db.profile.UnitFrames then RoithiUI.db.profile.UnitFrames = {} end
            if not RoithiUI.db.profile.UnitFrames[bUnit] then RoithiUI.db.profile.UnitFrames[bUnit] = {} end
            return RoithiUI.db.profile.UnitFrames[bUnit]
        end
        options.args.unitframes.args["boss"].args[bUnit] = {
            type = "group",
            name = L[bLabel] or bLabel,
            order = 10 + bossIdx,
            args = {
                frameGroup = {
                    type = "group",
                    name = L["Frame & Layout"],
                    order = 5,
                    inline = true,
                    hidden = function() return bUnit ~= "boss1" end,
                    args = {
                        width = {
                            type = "range",
                            name = L["Width"],
                            order = 1,
                            min = 50, max = 400, step = 1,
                            get = function() return GetBossDB().width or 200 end,
                            set = function(_, v)
                                GetBossDB().width = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                        height = {
                            type = "range",
                            name = L["Height"],
                            order = 2,
                            min = 20, max = 150, step = 1,
                            get = function() return GetBossDB().height or 40 end,
                            set = function(_, v)
                                GetBossDB().height = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                        scale = {
                            type = "range",
                            name = L["Scale"],
                            order = 3,
                            min = 0.5, max = 2.0, step = 0.05,
                            get = function() return GetBossDB().scale or 1.0 end,
                            set = function(_, v)
                                GetBossDB().scale = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                            hidden = function() return bUnit ~= "boss1" end,
                        },
                        x = {
                            type = "range",
                            name = L["X Position"],
                            order = 4,
                            min = -2500, max = 2500, step = 1,
                            get = function() return GetBossDB().x or 0 end,
                            set = function(_, v)
                                GetBossDB().x = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                            hidden = function() return bUnit ~= "boss1" end,
                        },
                        y = {
                            type = "range",
                            name = L["Y Position"],
                            order = 5,
                            min = -1500, max = 1500, step = 1,
                            get = function() return GetBossDB().y or 0 end,
                            set = function(_, v)
                                GetBossDB().y = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                            hidden = function() return bUnit ~= "boss1" end,
                        },
                    }
                },
                powerGroup = {
                    type = "group",
                    name = L["Power Bar"],
                    order = 10,
                    args = {
                        powerEnabled = {
                            type = "toggle",
                            name = L["Enable Power"],
                            order = 1,
                            get = function() return GetBossDB().powerEnabled ~= false end,
                            set = function(_, v)
                                GetBossDB().powerEnabled = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                        powerHeight = {
                            type = "range",
                            name = L["Power Height"],
                            order = 2,
                            min = 1, max = 50, step = 1,
                            get = function() return GetBossDB().powerHeight or 10 end,
                            set = function(_, v)
                                GetBossDB().powerHeight = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                        powerDetached = {
                            type = "toggle",
                            name = L["Detached"],
                            order = 3,
                            get = function() return GetBossDB().powerDetached == true end,
                            set = function(_, v)
                                GetBossDB().powerDetached = v
                                if v == true and not GetBossDB().powerWidth then
                                    GetBossDB().powerWidth = 180
                                end
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                        powerWidth = {
                            type = "range",
                            name = L["Power Width"],
                            order = 4,
                            min = 50, max = 400, step = 1,
                            get = function() return GetBossDB().powerWidth or 180 end,
                            set = function(_, v)
                                GetBossDB().powerWidth = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                            hidden = function() return not GetBossDB().powerDetached end,
                        },
                        powerX = {
                            type = "range",
                            name = L["X Position"],
                            order = 5,
                            min = -1000, max = 1000, step = 1,
                            get = function() return GetBossDB().powerX or 0 end,
                            set = function(_, v)
                                GetBossDB().powerX = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                            hidden = function() return not GetBossDB().powerDetached end,
                        },
                        powerY = {
                            type = "range",
                            name = L["Y Position"],
                            order = 6,
                            min = -1000, max = 1000, step = 1,
                            get = function() return GetBossDB().powerY or -50 end,
                            set = function(_, v)
                                GetBossDB().powerY = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                            hidden = function() return not GetBossDB().powerDetached end,
                        },
                    }
                },
                aurasGroup = {
                    type = "group",
                    name = L["Auras"],
                    order = 20,
                    args = {
                        aurasEnabled = {
                            type = "toggle",
                            name = L["Enable Auras"],
                            order = 1,
                            get = function() return GetBossDB().aurasEnabled ~= false end,
                            set = function(_, v)
                                GetBossDB().aurasEnabled = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                        showBuffs = {
                            type = "toggle",
                            name = L["Show Buffs"],
                            order = 2,
                            get = function() return GetBossDB().showBuffs ~= false end,
                            set = function(_, v)
                                GetBossDB().showBuffs = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                        showDebuffs = {
                            type = "toggle",
                            name = L["Show Debuffs"],
                            order = 3,
                            get = function() return GetBossDB().showDebuffs ~= false end,
                            set = function(_, v)
                                GetBossDB().showDebuffs = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                        separateAuras = {
                            type = "toggle",
                            name = L["Separate Buffs & Debuffs"],
                            order = 4,
                            get = function() return GetBossDB().separateAuras == true end,
                            set = function(_, v)
                                GetBossDB().separateAuras = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                        auraSize = {
                            type = "range",
                            name = L["Aura Size"],
                            order = 5,
                            min = 10, max = 40, step = 1,
                            get = function() return GetBossDB().auraSize or 20 end,
                            set = function(_, v)
                                GetBossDB().auraSize = v
                                ns.RefreshUnitFrame(bUnit)
                            end,
                        },
                    }
                },
                quickLinks = {
                    type = "group",
                    name = L["Quick Links"],
                    inline = true,
                    order = 999,
                    args = {
                        auras = {
                            type = "execute",
                            name = L["> Auras"],
                            order = 1,
                            func = function()
                                LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "units", "bossFrames", bUnit)
                            end,
                        },
                        castbars = {
                            type = "execute",
                            name = L["> Castbars"],
                            order = 2,
                            func = function()
                                LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "castbars", "bosses", bUnit)
                            end,
                        },
                        customtags = {
                            type = "execute",
                            name = L["> Custom Tags"],
                            order = 3,
                            func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "customtags", bUnit) end,
                        },
                    }
                },
            }
        }
    end

    -- Global boss quick links (at the top boss group level)
    options.args.unitframes.args["boss"].args.quickLinks = {
        type = "group",
        name = L["Quick Links"],
        inline = true,
        order = 999,
        args = {
            auras = {
                type = "execute",
                name = L["> Auras (Boss 1)"],
                order = 1,
                func = function()
                    LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "units", "bossFrames", "boss1")
                end,
            },
            castbars = {
                type = "execute",
                name = L["> Boss Castbars"],
                order = 2,
                func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "castbars", "bosses") end,
            },
        }
    }


    if ns.OptionsEngine and ns.OptionsEngine.RegisterModuleOptions then
        if options and options.args then
            if options.args.unitframes then
                ns.OptionsEngine:RegisterModuleOptions("unitframes", options.args.unitframes)
            end
            if options.args.castbars then
                ns.OptionsEngine:RegisterModuleOptions("castbars", options.args.castbars)
            end
        end
    end
end

function ns.RefreshUnitFrame(unit)
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if UF then
        if unit and unit:find("^boss%d+$") then
            for i = 1, 5 do
                local bUnit = "boss" .. i
                if UF.UpdateFrameFromSettings then
                    UF:UpdateFrameFromSettings(bUnit)
                end
            end
        elseif UF.UpdateFrameFromSettings then
            UF:UpdateFrameFromSettings(unit)
        end
    end
end

function ns.RefreshAllUnitFrames()
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if UF and UF.units then
        for unit in pairs(UF.units) do
            ns.RefreshUnitFrame(unit)
        end
    end
    if UF and UF.UpdateAllCustomAuras then
        UF:UpdateAllCustomAuras()
    end
end

-- Register unitframes and castbars module schemas immediately on file load for OptionsEngine
local dummyContainer = {
    args = {
        unitframes = { type = "group", name = L["Unit Frames"], order = 2, args = {} },
        castbars = { type = "group", name = L["Castbars"], order = 3, args = {} }
    }
}
ns.BuildUnitAndCastbarOptions(dummyContainer)

-- ============================================================================
-- EDIT MODE (LIBEDITMODE) CONFIGURATION FOR UNIT FRAMES & BOSS FRAMES
-- Single Source of Truth - Moved from Config/LEMConfig/
-- ============================================================================

local LEM = LibStub("LibEditMode-Roithi", true)

local function GetUnitDB(unit)
    if not RoithiUI.db.profile.UnitFrames[unit] then RoithiUI.db.profile.UnitFrames[unit] = {} end
    return RoithiUI.db.profile.UnitFrames[unit]
end

local function UpdateFrameFromSettings(unit)
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if UF and UF.UpdateFrameFromSettings then
        UF:UpdateFrameFromSettings(unit)
    end
end

local function GetSettingsForPower(unit)
    if not LEM then return {} end
    return {
        {
            name = "Enable",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return GetUnitDB(unit).powerEnabled ~= false end,
            set = function(_, value)
                GetUnitDB(unit).powerEnabled = value
                UpdateFrameFromSettings(unit)
                AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 10,
            minValue = 2,
            maxValue = 50,
            valueStep = 1,
            get = function() return GetUnitDB(unit).powerHeight or 10 end,
            set = function(_, value)
                GetUnitDB(unit).powerHeight = value
                UpdateFrameFromSettings(unit)
            end,
        },
        {
            name = "Detached",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function() return GetUnitDB(unit).powerDetached end,
            set = function(_, value)
                if value == true and not GetUnitDB(unit).powerWidth then
                    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                    local frame = UF and UF.units and UF.units[unit]
                    if frame and frame.Power then
                        local w = frame.Power:GetWidth()
                        GetUnitDB(unit).powerWidth = w and math.floor(w + 0.5) or 180
                    end
                end

                GetUnitDB(unit).powerDetached = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.Power then LEM:RefreshFrameSettings(frame.Power) end

                AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetUnitDB(unit).powerX or 0 end,
            set = function(_, value)
                GetUnitDB(unit).powerX = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetUnitDB(unit).powerDetached end,
        },
        {
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            default = -50,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetUnitDB(unit).powerY or -50 end,
            set = function(_, value)
                GetUnitDB(unit).powerY = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetUnitDB(unit).powerDetached end,
        },
        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 400,
            valueStep = 1,
            get = function() return math.floor((GetUnitDB(unit).powerWidth or 200) + 0.5) end,
            set = function(_, value)
                GetUnitDB(unit).powerWidth = math.floor(value + 0.5)
                UpdateFrameFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.0f", v) end,
            hidden = function() return not GetUnitDB(unit).powerDetached end,
        },
    }
end

local function GetSettingsForClassPower(unit)
    if not LEM then return {} end
    return {
        {
            name = "Enable",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return GetUnitDB(unit).classPowerEnabled ~= false end,
            set = function(_, value)
                GetUnitDB(unit).classPowerEnabled = value
                UpdateFrameFromSettings(unit)
                AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 10,
            minValue = 2,
            maxValue = 50,
            valueStep = 1,
            get = function() return GetUnitDB(unit).classPowerHeight or 10 end,
            set = function(_, value)
                GetUnitDB(unit).classPowerHeight = value
                UpdateFrameFromSettings(unit)
            end,
        },
        {
            name = "Detached",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function() return GetUnitDB(unit).classPowerDetached end,
            set = function(_, value)
                if value == true and not GetUnitDB(unit).classPowerWidth then
                    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                    local frame = UF and UF.units and UF.units[unit]
                    if frame and frame.ClassPower then
                        local w = frame.ClassPower:GetWidth()
                        GetUnitDB(unit).classPowerWidth = w and math.floor(w + 0.5) or 200
                    end
                end

                GetUnitDB(unit).classPowerDetached = value
                UpdateFrameFromSettings(unit)

                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.ClassPower then
                    LEM:RefreshFrameSettings(frame.ClassPower)
                end

                AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetUnitDB(unit).classPowerX or 0 end,
            set = function(_, value)
                GetUnitDB(unit).classPowerX = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetUnitDB(unit).classPowerDetached end,
        },
        {
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            default = -50,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetUnitDB(unit).classPowerY or -50 end,
            set = function(_, value)
                GetUnitDB(unit).classPowerY = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetUnitDB(unit).classPowerDetached end,
        },
        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 400,
            valueStep = 1,
            get = function() return math.floor((GetUnitDB(unit).classPowerWidth or 200) + 0.5) end,
            set = function(_, value)
                GetUnitDB(unit).classPowerWidth = math.floor(value + 0.5)
                UpdateFrameFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.0f", v) end,
            hidden = function() return not GetUnitDB(unit).classPowerDetached end,
        },
    }
end

local function GetSettingsForAdditionalPower(unit)
    if not LEM then return {} end
    return {
        {
            name = "Enable",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return GetUnitDB(unit).additionalPowerEnabled ~= false end,
            set = function(_, value)
                GetUnitDB(unit).additionalPowerEnabled = value
                UpdateFrameFromSettings(unit)
                if ns.SetCastbarAttachment then
                    local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[unit]
                    if cbDB and not cbDB.detached then
                        ns.SetCastbarAttachment(unit, true)
                    end
                end
            end,
        },
        {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 10,
            minValue = 2,
            maxValue = 50,
            valueStep = 1,
            get = function() return GetUnitDB(unit).additionalPowerHeight or 10 end,
            set = function(_, value)
                GetUnitDB(unit).additionalPowerHeight = value
                UpdateFrameFromSettings(unit)
            end,
        },
        {
            name = "Detached",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function() return GetUnitDB(unit).additionalPowerDetached end,
            set = function(_, value)
                if value == true and not GetUnitDB(unit).additionalPowerWidth then
                    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                    local frame = UF and UF.units and UF.units[unit]
                    if frame and frame.AdditionalPower then
                        local w = frame.AdditionalPower:GetWidth()
                        GetUnitDB(unit).additionalPowerWidth = w and math.floor(w + 0.5) or 200
                    end
                end

                GetUnitDB(unit).additionalPowerDetached = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.AdditionalPower then
                    LEM:RefreshFrameSettings(frame.AdditionalPower)
                end

                AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetUnitDB(unit).additionalPowerX or 0 end,
            set = function(_, value)
                GetUnitDB(unit).additionalPowerX = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetUnitDB(unit).additionalPowerDetached end,
        },
        {
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            default = -50,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetUnitDB(unit).additionalPowerY or -50 end,
            set = function(_, value)
                GetUnitDB(unit).additionalPowerY = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetUnitDB(unit).additionalPowerDetached end,
        },
        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 400,
            valueStep = 1,
            get = function() return math.floor((GetUnitDB(unit).additionalPowerWidth or 200) + 0.5) end,
            set = function(_, value)
                GetUnitDB(unit).additionalPowerWidth = math.floor(value + 0.5)
                UpdateFrameFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.0f", v) end,
            hidden = function() return not GetUnitDB(unit).additionalPowerDetached end,
        },
    }
end

local function GetSettingsForMainFrame(unit, frame)
    if not LEM then return {} end
    local settings = {
        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 400,
            valueStep = 1,
            get = function() return GetUnitDB(unit).width end,
            set = function(_, value)
                GetUnitDB(unit).width = value
                UpdateFrameFromSettings(unit)
                AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
        },
        {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 50,
            minValue = 20,
            maxValue = 150,
            valueStep = 1,
            get = function() return GetUnitDB(unit).height end,
            set = function(_, value)
                GetUnitDB(unit).height = value
                UpdateFrameFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.1f", v) end,
        },
        {
            name = "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -2500,
            maxValue = 2500,
            valueStep = 1,
            get = function() return GetUnitDB(unit).x end,
            set = function(_, value)
                GetUnitDB(unit).x = value
                UpdateFrameFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.1f", v) end,
        },
        {
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1500,
            maxValue = 1500,
            valueStep = 1,
            get = function() return GetUnitDB(unit).y end,
            set = function(_, value)
                GetUnitDB(unit).y = value
                UpdateFrameFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.1f", v) end,
        },
        { kind = LEM.SettingType.Divider },
        {
            name = "Primary Power",
            kind = LEM.SettingType.Expander,
            get = function() return GetUnitDB(unit).powerSectionExpanded end,
            set = function(_, value)
                GetUnitDB(unit).powerSectionExpanded = value
                LEM:RefreshFrameSettings(frame)
            end,
        },
    }

    local pSettings = GetSettingsForPower(unit)
    for _, s in ipairs(pSettings) do
        local originalHidden = s.hidden
        s.hidden = function()
            if not GetUnitDB(unit).powerSectionExpanded then return true end
            if originalHidden then return originalHidden() end
            return false
        end
        table.insert(settings, s)
    end

    if unit == "player" then
        table.insert(settings, { kind = LEM.SettingType.Divider })
        table.insert(settings, {
            name = "Secondary Power",
            kind = LEM.SettingType.Expander,
            get = function() return GetUnitDB(unit).classPowerSectionExpanded end,
            set = function(_, value)
                GetUnitDB(unit).classPowerSectionExpanded = value
                LEM:RefreshFrameSettings(frame)
            end,
        })

        local cSettings = GetSettingsForClassPower(unit)
        for _, s in ipairs(cSettings) do
            local originalHidden = s.hidden
            s.hidden = function()
                if not GetUnitDB(unit).classPowerSectionExpanded then return true end
                if originalHidden then return originalHidden() end
                return false
            end
            table.insert(settings, s)
        end

        table.insert(settings, { kind = LEM.SettingType.Divider })
        table.insert(settings, {
            name = "Additional Power",
            kind = LEM.SettingType.Expander,
            get = function() return GetUnitDB(unit).additionalPowerSectionExpanded end,
            set = function(_, value)
                GetUnitDB(unit).additionalPowerSectionExpanded = value
                LEM:RefreshFrameSettings(frame)
            end,
        })

        local aSettings = GetSettingsForAdditionalPower(unit)
        for _, s in ipairs(aSettings) do
            local originalHidden = s.hidden
            s.hidden = function()
                if not GetUnitDB(unit).additionalPowerSectionExpanded then return true end
                if originalHidden then return originalHidden() end
                return false
            end
            table.insert(settings, s)
        end
    end

    return settings
end

local function OnUnitFramePositionChanged(frame, layoutName, point, x, y)
    local unit = frame.unit
    x = math.floor(x * 10 + 0.5) / 10
    y = math.floor(y * 10 + 0.5) / 10

    local db = GetUnitDB(unit)
    db.point = point
    db.x = x
    db.y = y

    if frame then
        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, point, x, y)
        if LEM then LEM:RefreshFrameSettings(frame) end
    end
end

function ns.InitializeUnitFrameConfig()
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if not UF or not UF.units then return end

    for unit, frame in pairs(UF.units) do
        if not string.find(unit, "boss") then
            local db = GetUnitDB(unit)
            if not db.width then db.width = frame:GetWidth() end
            if not db.height then db.height = frame:GetHeight() end

            if LEM then
                frame.editModeName = "Roithi " .. unit:gsub("^%l", string.upper)
                frame:SetMovable(true)
                frame:SetClampedToScreen(true)

                local defaults = {
                    point = db.point or "CENTER",
                    x = db.x or 0,
                    y = db.y or 0
                }

                if not db.point then db.point = defaults.point end
                if not db.x then db.x = defaults.x end
                if not db.y then db.y = defaults.y end

                LEM:AddFrame(frame, OnUnitFramePositionChanged, defaults)

                pcall(function()
                    LEM:AddFrameSettings(frame, GetSettingsForMainFrame(unit, frame))
                    frame.extraButtons = nil
                    LEM:AddFrameSettingsButtons(frame, {
                        {
                            text = "Open Full Settings",
                            click = function()
                                if LibStub("AceConfigDialog-3.0") then
                                    LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", unit)
                                    LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                                end
                            end
                        }
                    })
                end)

                if frame.Power then
                    pcall(function() LEM:AddFrameSettings(frame.Power, GetSettingsForPower(unit)) end)
                end
                if frame.ClassPower then
                    pcall(function() LEM:AddFrameSettings(frame.ClassPower, GetSettingsForClassPower(unit)) end)
                end
                if frame.AdditionalPower then
                    pcall(function() LEM:AddFrameSettings(frame.AdditionalPower, GetSettingsForAdditionalPower(unit)) end)
                end
            end
        end
    end
end

function ns.ApplyLEMBossConfiguration(frame, unit)
    if not LEM then return end
    local function GetBossDB()
        if not RoithiUI.db.profile.UnitFrames["boss1"] then RoithiUI.db.profile.UnitFrames["boss1"] = {} end
        return RoithiUI.db.profile.UnitFrames["boss1"]
    end

    local function GetBossSettings()
        local settings = {}
        table.insert(settings, {
            name = "Size & Spacing",
            expandedLabel = "Collapse size & spacing",
            collapsedLabel = "Expand size & spacing",
            kind = LEM.SettingType.Expander,
            default = false,
            get = function() return GetBossDB().sizeSectionExpanded end,
            set = function(_, v)
                GetBossDB().sizeSectionExpanded = v
                LEM:AddFrameSettings(frame, GetBossSettings())
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetBossDB().sizeSectionExpanded then
            local sizeSettings = {
                {
                    name = "Width",
                    kind = LEM.SettingType.Slider,
                    default = 200,
                    minValue = 50,
                    maxValue = 400,
                    valueStep = 1,
                    get = function() return GetBossDB().width or 200 end,
                    set = function(_, value)
                        GetBossDB().width = value
                        for i = 1, 5 do UpdateFrameFromSettings("boss" .. i) end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    name = "Height",
                    kind = LEM.SettingType.Slider,
                    default = 50,
                    minValue = 20,
                    maxValue = 150,
                    valueStep = 1,
                    get = function() return GetBossDB().height or 50 end,
                    set = function(_, value)
                        GetBossDB().height = value
                        for i = 1, 5 do UpdateFrameFromSettings("boss" .. i) end
                        local UF = RoithiUI:GetModule("UnitFrames")
                        if UF and UF.UpdateBossAnchors then UF:UpdateBossAnchors() end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    name = "X Position",
                    kind = LEM.SettingType.Slider,
                    default = -250,
                    minValue = -2500,
                    maxValue = 2500,
                    valueStep = 1,
                    get = function() return GetBossDB().x or -250 end,
                    set = function(_, value)
                        GetBossDB().x = value
                        local UF = RoithiUI:GetModule("UnitFrames")
                        if UF then
                            UF:UpdateFrameFromSettings("boss1")
                            if UF.UpdateBossAnchors then UF:UpdateBossAnchors() end
                        end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    name = "Y Position",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = -1500,
                    maxValue = 1500,
                    valueStep = 1,
                    get = function() return GetBossDB().y or 0 end,
                    set = function(_, value)
                        GetBossDB().y = value
                        local UF = RoithiUI:GetModule("UnitFrames")
                        if UF then
                            UF:UpdateFrameFromSettings("boss1")
                            if UF.UpdateBossAnchors then UF:UpdateBossAnchors() end
                        end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Spacing",
                    get = function() return GetBossDB().spacing or 30 end,
                    set = function(_, v)
                        GetBossDB().spacing = v
                        local UF = RoithiUI:GetModule("UnitFrames")
                        if UF and UF.UpdateBossAnchors then
                            UF:UpdateBossAnchors()
                        end
                    end,
                    minValue = 0,
                    maxValue = 100,
                    valueStep = 1,
                },
            }
            for _, s in ipairs(sizeSettings) do table.insert(settings, s) end
        end

        table.insert(settings, { kind = LEM.SettingType.Divider })

        table.insert(settings, {
            name = "Power",
            expandedLabel = "Collapse power",
            collapsedLabel = "Expand power",
            kind = LEM.SettingType.Expander,
            default = false,
            get = function() return GetBossDB().powerSectionExpanded end,
            set = function(_, v)
                GetBossDB().powerSectionExpanded = v
                LEM:AddFrameSettings(frame, GetBossSettings())
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetBossDB().powerSectionExpanded then
            local powerSettings = {
                {
                    name = "Enable Power",
                    kind = LEM.SettingType.Checkbox,
                    default = true,
                    get = function() return GetBossDB().powerEnabled ~= false end,
                    set = function(_, value)
                        GetBossDB().powerEnabled = value
                        for i = 1, 5 do UpdateFrameFromSettings("boss" .. i) end
                    end,
                },
                {
                    name = "Height",
                    kind = LEM.SettingType.Slider,
                    default = 10,
                    minValue = 2,
                    maxValue = 50,
                    valueStep = 1,
                    get = function() return GetBossDB().powerHeight or 10 end,
                    set = function(_, value)
                        GetBossDB().powerHeight = value
                        for i = 1, 5 do UpdateFrameFromSettings("boss" .. i) end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    name = "Detached",
                    kind = LEM.SettingType.Checkbox,
                    default = false,
                    get = function() return GetBossDB().powerDetached end,
                    set = function(_, value)
                        GetBossDB().powerDetached = value
                        for i = 1, 5 do UpdateFrameFromSettings("boss" .. i) end
                        LEM:AddFrameSettings(frame, GetBossSettings())
                        LEM:RefreshFrameSettings(frame)
                    end,
                },
            }
            if GetBossDB().powerDetached then
                table.insert(powerSettings, {
                    name = "X Position",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = -1000,
                    maxValue = 1000,
                    valueStep = 1,
                    get = function() return GetBossDB().powerX or 0 end,
                    set = function(_, value)
                        GetBossDB().powerX = value
                        for i = 1, 5 do UpdateFrameFromSettings("boss" .. i) end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                })
                table.insert(powerSettings, {
                    name = "Y Position",
                    kind = LEM.SettingType.Slider,
                    default = -50,
                    minValue = -1000,
                    maxValue = 1000,
                    valueStep = 1,
                    get = function() return GetBossDB().powerY or -50 end,
                    set = function(_, value)
                        GetBossDB().powerY = value
                        for i = 1, 5 do UpdateFrameFromSettings("boss" .. i) end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                })
                table.insert(powerSettings, {
                    name = "Width",
                    kind = LEM.SettingType.Slider,
                    default = 200,
                    minValue = 50,
                    maxValue = 400,
                    valueStep = 1,
                    get = function() return GetBossDB().powerWidth or 200 end,
                    set = function(_, value)
                        GetBossDB().powerWidth = value
                        for i = 1, 5 do UpdateFrameFromSettings("boss" .. i) end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                })
            end
            for _, s in ipairs(powerSettings) do table.insert(settings, s) end
        end

        table.insert(settings, { kind = LEM.SettingType.Divider })

        table.insert(settings, {
            name = "Castbar",
            expandedLabel = "Collapse castbar",
            collapsedLabel = "Expand castbar",
            kind = LEM.SettingType.Expander,
            default = false,
            get = function() return GetBossDB().castbarSectionExpanded end,
            set = function(_, v)
                GetBossDB().castbarSectionExpanded = v
                LEM:AddFrameSettings(frame, GetBossSettings())
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetBossDB().castbarSectionExpanded then
            local castbarSettings = {
                {
                    name = "Enable Castbar",
                    kind = LEM.SettingType.Checkbox,
                    default = true,
                    get = function()
                        local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss1"]
                        return cbDB and cbDB.enabled ~= false
                    end,
                    set = function(_, value)
                        for i = 1, 5 do
                            local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss" .. i]
                            if cbDB then cbDB.enabled = value end
                            if ns.UpdateCast and ns.bars and ns.bars["boss" .. i] then
                                ns.UpdateCast(ns.bars["boss" .. i])
                            end
                        end
                    end,
                },
                {
                    name = "Height",
                    kind = LEM.SettingType.Slider,
                    default = 20,
                    minValue = 10,
                    maxValue = 60,
                    valueStep = 1,
                    get = function()
                        local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss1"]
                        return cbDB and cbDB.height or 20
                    end,
                    set = function(_, value)
                        for i = 1, 5 do
                            local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss" .. i]
                            if cbDB then cbDB.height = value end
                            if ns.UpdateCast and ns.bars and ns.bars["boss" .. i] then
                                ns.UpdateCast(ns.bars["boss" .. i])
                            end
                        end
                    end,
                },
                {
                    name = "Detached",
                    kind = LEM.SettingType.Checkbox,
                    default = false,
                    get = function()
                        local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss1"]
                        return cbDB and cbDB.detached
                    end,
                    set = function(_, value)
                        for i = 1, 5 do
                            local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss" .. i]
                            if cbDB then cbDB.detached = value end
                            if ns.UpdateCast and ns.bars and ns.bars["boss" .. i] then
                                ns.UpdateCast(ns.bars["boss" .. i])
                            end
                        end
                        LEM:AddFrameSettings(frame, GetBossSettings())
                        LEM:RefreshFrameSettings(frame)
                    end,
                },
            }
            local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss1"]
            if cbDB and cbDB.detached then
                table.insert(castbarSettings, {
                    name = "X Position",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = -1000,
                    maxValue = 1000,
                    valueStep = 1,
                    get = function()
                        local bDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss1"]
                        return bDB and bDB.x or 0
                    end,
                    set = function(_, value)
                        for i = 1, 5 do
                            local bDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss" .. i]
                            if bDB then bDB.x = value end
                            if ns.UpdateCast and ns.bars and ns.bars["boss" .. i] then
                                ns.UpdateCast(ns.bars["boss" .. i])
                            end
                        end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                })
                table.insert(castbarSettings, {
                    name = "Y Position",
                    kind = LEM.SettingType.Slider,
                    default = -50,
                    minValue = -1000,
                    maxValue = 1000,
                    valueStep = 1,
                    get = function()
                        local bDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss1"]
                        return bDB and bDB.y or -50
                    end,
                    set = function(_, value)
                        for i = 1, 5 do
                            local bDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["boss" .. i]
                            if bDB then bDB.y = value end
                            if ns.UpdateCast and ns.bars and ns.bars["boss" .. i] then
                                ns.UpdateCast(ns.bars["boss" .. i])
                            end
                        end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                })
            end
            for _, s in ipairs(castbarSettings) do table.insert(settings, s) end
        end

        return settings
    end

    LEM:AddFrameSettings(frame, GetBossSettings())
    frame.extraButtons = nil
    LEM:AddFrameSettingsButtons(frame, {
        {
            text = "Open Full Settings",
            click = function()
                if LibStub("AceConfigDialog-3.0") then
                    LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", "boss", "boss1")
                    LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                end
            end
        }
    })
end
