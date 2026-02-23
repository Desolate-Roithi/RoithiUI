local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local Config = RoithiUI.Config or {}
RoithiUI.Config = Config
local LSM = LibStub("LibSharedMedia-3.0")
local AL = ns.AttachmentLogic

-- ----------------------------------------------------------------------------
-- AceConfig Table Definition
-- ----------------------------------------------------------------------------
local function GetLSMKeys(mediaType)
    local list = LSM:List(mediaType)
    local out = {}
    for _, name in ipairs(list) do
        out[name] = name
    end
    return out
end

local function GenerateAuraFilters(GetDB, RefreshFunc)
    return {
        group1_global = {
            type = "group",
            name = "Global Visibility & Layout",
            order = 1,
            inline = true,
            args = {
                showBuffs = {
                    type = "toggle",
                    name = "Show Buffs",
                    desc = "Enable rendering of helpful auras.",
                    order = 1,
                    get = function() return GetDB().showBuffs ~= false end,
                    set = function(_, v)
                        GetDB().showBuffs = v; RefreshFunc()
                    end,
                },
                showDebuffs = {
                    type = "toggle",
                    name = "Show Debuffs",
                    desc = "Enable rendering of harmful auras.",
                    order = 2,
                    get = function() return GetDB().showDebuffs ~= false end,
                    set = function(_, v)
                        GetDB().showDebuffs = v; RefreshFunc()
                    end,
                },
                separateAuras = {
                    type = "toggle",
                    name = "Separate Buffs & Debuffs",
                    desc = "When checked, Buffs and Debuffs will anchor separately instead of flowing consecutively.",
                    order = 3,
                    get = function() return GetDB().separateAuras end,
                    set = function(_, v)
                        GetDB().separateAuras = v; RefreshFunc()
                    end,
                    hidden = function() return GetDB().isStandaloneCustom end,
                },
            },
        },
        group2_base = {
            type = "group",
            name = "Base Filters",
            order = 2,
            inline = true,
            args = {
                showAllBuffs = {
                    type = "toggle",
                    name = "All Buffs",
                    desc = "Overrides Smart Filters to show every active Buff on the unit.",
                    order = 1,
                    get = function() return GetDB().showAllBuffs end,
                    set = function(_, v)
                        GetDB().showAllBuffs = v; RefreshFunc()
                    end,
                },
                showAllDebuffs = {
                    type = "toggle",
                    name = "All Debuffs",
                    desc = "Overrides Smart Filters to show every active Debuff on the unit.",
                    order = 2,
                    get = function() return GetDB().showAllDebuffs end,
                    set = function(_, v)
                        GetDB().showAllDebuffs = v; RefreshFunc()
                    end,
                },
                hideTimeless = {
                    type = "toggle",
                    name = "Hide Timeless Auras",
                    desc = "Hides passive auras with no duration.",
                    order = 3,
                    get = function() return GetDB().hideTimeless == true end,
                    set = function(_, v)
                        GetDB().hideTimeless = v; RefreshFunc()
                    end,
                },
            },
        },
        group3_player = {
            type = "group",
            name = "Player Auras",
            order = 3,
            inline = true,
            args = {
                playerBuffs = {
                    type = "toggle",
                    name = "My Buffs",
                    desc = "Shows generic helpful auras cast by you.",
                    order = 1,
                    get = function() return GetDB().playerBuffs ~= false end,
                    set = function(_, v)
                        GetDB().playerBuffs = v; RefreshFunc()
                    end,
                },
                playerDebuffs = {
                    type = "toggle",
                    name = "My Debuffs",
                    desc = "Shows generic harmful auras (like DoTs) cast by you.",
                    order = 2,
                    get = function() return GetDB().playerDebuffs ~= false end,
                    set = function(_, v)
                        GetDB().playerDebuffs = v; RefreshFunc()
                    end,
                },
                raidInCombat = {
                    type = "toggle",
                    name = "My Raid HoTs/Buffs",
                    desc = "Safely shows your HoTs while in combat (bypassing native combat hiding restrictions).",
                    order = 3,
                    get = function() return GetDB().raidInCombat ~= false end,
                    set = function(_, v)
                        GetDB().raidInCombat = v; RefreshFunc()
                    end,
                },
            },
        },
        group4_mechanics = {
            type = "group",
            name = "Mechanics & Warnings",
            order = 4,
            inline = true,
            args = {
                importantBuffs = {
                    type = "toggle",
                    name = "Important Buffs",
                    desc = "Shows Buffs explicitly flagged by Blizzard developers as critical for the encounter.",
                    order = 1,
                    get = function() return GetDB().importantBuffs ~= false end,
                    set = function(_, v)
                        GetDB().importantBuffs = v; RefreshFunc()
                    end,
                },
                importantDebuffs = {
                    type = "toggle",
                    name = "Important Debuffs",
                    desc = "Shows Debuffs explicitly flagged by Blizzard developers as critical for the encounter.",
                    order = 2,
                    get = function() return GetDB().importantDebuffs ~= false end,
                    set = function(_, v)
                        GetDB().importantDebuffs = v; RefreshFunc()
                    end,
                },
                cc = {
                    type = "toggle",
                    name = "Crowd Control",
                    desc = "Shows Debuffs that restrict character control (Stuns, Fears, Roots, etc).",
                    order = 3,
                    get = function() return GetDB().cc ~= false end,
                    set = function(_, v)
                        GetDB().cc = v; RefreshFunc()
                    end,
                },
                dispellable = {
                    type = "toggle",
                    name = "Dispellable",
                    desc = "Shows Debuffs that your current Class/Spec is physically capable of dispelling.",
                    order = 4,
                    get = function() return GetDB().dispellable ~= false end,
                    set = function(_, v)
                        GetDB().dispellable = v; RefreshFunc()
                    end,
                },
            },
        },
        group5_defensives = {
            type = "group",
            name = "Defensives",
            order = 5,
            inline = true,
            args = {
                majorDefensivesBuffs = {
                    type = "toggle",
                    name = "Major Defensives (Tanks)",
                    desc = "Shows major defensive cooldowns (Buffs) on the unit (e.g. Shield Wall, Barkskin).",
                    order = 1,
                    get = function() return GetDB().majorDefensivesBuffs ~= false end,
                    set = function(_, v)
                        GetDB().majorDefensivesBuffs = v; RefreshFunc()
                    end,
                },
                majorDefensivesDebuffs = {
                    type = "toggle",
                    name = "Major Defensives (Debuffs)",
                    desc = "Shows major defensive restrictions (Debuffs) on the unit (e.g. Forbearance, Weakened Soul).",
                    order = 2,
                    get = function() return GetDB().majorDefensivesDebuffs ~= false end,
                    set = function(_, v)
                        GetDB().majorDefensivesDebuffs = v; RefreshFunc()
                    end,
                },
                externalDefensives = {
                    type = "toggle",
                    name = "External Defensives",
                    desc = "Shows major defensive buffs cast on the unit by OTHER players (e.g. Pain Suppression).",
                    order = 3,
                    get = function() return GetDB().externalDefensives ~= false end,
                    set = function(_, v)
                        GetDB().externalDefensives = v; RefreshFunc()
                    end,
                },
            },
        }
    }
end

local function GetGlobalAuraOptions()
    local group = {
        type = "group",
        name = "Auras",
        order = 4,
        args = {
            intro = {
                type = "description",
                name = "Manage Smart Filters (12.0.1) and Custom Aura Frames.",
                order = 0,
            },
            custom = {
                type = "group",
                name = "Custom Frames",
                order = 2,
                args = {
                    addName = {
                        type = "input",
                        name = "Create New Frame (ID)",
                        desc = "Enter a unique name for the new custom aura frame and press Enter.",
                        order = 1,
                        get = function() return "" end,
                        set = function(_, v)
                            if v and v:match("%S") then
                                v = v:gsub("%s+", "")
                                RoithiUI.db.profile.CustomAuraFrames = RoithiUI.db.profile.CustomAuraFrames or {}
                                if not RoithiUI.db.profile.CustomAuraFrames[v] then
                                    RoithiUI.db.profile.CustomAuraFrames[v] = {
                                        unit = "player",
                                        enabled = true,
                                        auraSize = 30,
                                        maxAuras = 4,
                                        showBuffs = true,
                                        showDebuffs = true,
                                        separateAuras = false,
                                        auraAnchor = "BOTTOM",
                                        auraGrowDirection = "RIGHT",
                                        detached = true,
                                        debuffSize = 30,
                                        debuffSpacing = 4,
                                        debuffAnchor = "BOTTOM",
                                        debuffGrowDirection = "RIGHT",
                                        debuffDetached = true,
                                    }
                                    ns.RefreshAllUnitFrames()
                                end
                            end
                        end,
                    },
                }
            },
            units = {
                type = "group",
                name = "Unit Aura Settings",
                order = 3,
                args = {}
            }
        }
    }

    if RoithiUI.db.profile.CustomAuraFrames then
        local i = 10
        local unitsList = {
            player = "Player",
            target = "Target",
            focus = "Focus",
            pet = "Pet",
            targettarget = "Target of Target",
            focustarget = "Focus Target"
        }

        for id, conf in pairs(RoithiUI.db.profile.CustomAuraFrames) do
            local function GetDB()
                return RoithiUI.db.profile.CustomAuraFrames[id]
            end

            group.args.custom.args[id] = {
                type = "group",
                name = id,
                order = i,
                args = {
                    delete = {
                        type = "execute",
                        name = "Delete Frame",
                        order = 1,
                        confirm = true,
                        func = function()
                            RoithiUI.db.profile.CustomAuraFrames[id] = nil
                            ns.RefreshAllUnitFrames()
                        end,
                    },
                    unit = {
                        type = "select",
                        name = "Request Buffs From Unit",
                        order = 2,
                        values = unitsList,
                        get = function() return GetDB().unit or "player" end,
                        set = function(_, v)
                            GetDB().unit = v; ns.RefreshAllUnitFrames()
                        end,
                    },
                    enabled = {
                        type = "toggle",
                        name = "Enable",
                        order = 3,
                        get = function() return GetDB().enabled == true end,
                        set = function(_, v)
                            GetDB().enabled = v; ns.RefreshAllUnitFrames()
                        end,
                    },
                    size = {
                        type = "range",
                        name = "Aura Size",
                        order = 4,
                        min = 10,
                        max = 100,
                        step = 1,
                        get = function() return GetDB().auraSize or 30 end,
                        set = function(_, v)
                            GetDB().auraSize = v; ns.RefreshAllUnitFrames()
                        end,
                    },
                    max = {
                        type = "range",
                        name = "Max Auras",
                        order = 5,
                        min = 1,
                        max = 40,
                        step = 1,
                        get = function() return GetDB().maxAuras or 4 end,
                        set = function(_, v)
                            GetDB().maxAuras = v; ns.RefreshAllUnitFrames()
                        end,
                    },
                    spacing = {
                        type = "range",
                        name = "Spacing",
                        order = 6,
                        min = 0,
                        max = 40,
                        step = 1,
                        get = function() return GetDB().auraSpacing or 4 end,
                        set = function(_, v)
                            GetDB().auraSpacing = v; ns.RefreshAllUnitFrames()
                        end,
                    },
                    x = {
                        type = "range",
                        name = "X Offset (from Screen Center)",
                        order = 7,
                        min = -2000,
                        max = 2000,
                        step = 1,
                        get = function() return GetDB().screenX or 0 end,
                        set = function(_, v)
                            GetDB().screenX = v; ns.RefreshAllUnitFrames()
                        end,
                    },
                    y = {
                        type = "range",
                        name = "Y Offset (from Screen Center)",
                        order = 8,
                        min = -2000,
                        max = 2000,
                        step = 1,
                        get = function() return GetDB().screenY or -50 end,
                        set = function(_, v)
                            GetDB().screenY = v; ns.RefreshAllUnitFrames()
                        end,
                    },
                    grow = {
                        type = "select",
                        name = "Grow Direction",
                        order = 8,
                        values = { ["RIGHT"] = "Left to Right", ["LEFT"] = "Right to Left", ["UP"] = "Bottom to Top", ["DOWN"] = "Top to Bottom", ["CENTER_HORIZONTAL"] = "Centered Horizontal", ["CENTER_VERTICAL"] = "Centered Vertical" },
                        get = function() return GetDB().auraGrowDirection or "RIGHT" end,
                        set = function(_, v)
                            GetDB().auraGrowDirection = v; ns.RefreshAllUnitFrames()
                        end,
                    },
                    filtersGroup = {
                        type = "group",
                        name = "Filters & Visibility",
                        order = 20,
                        args = GenerateAuraFilters(function()
                            local db = GetDB()
                            db.isStandaloneCustom = true
                            return db
                        end, function() ns.RefreshAllUnitFrames() end),
                    },
                }
            }
            i = i + 1
        end
    end

    return group
end

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
                            ufHeader = {
                                type = "header",
                                name = "Unit Frames",
                                order = 1,
                            },
                            ufFont = {
                                type = "select",
                                dialogControl = "LSM30_Font",
                                name = "Font",
                                order = 2,
                                values = function() return GetLSMKeys("font") end,
                                get = function() return RoithiUI.db.profile.General.unitFrameFont end,
                                set = function(_, v)
                                    RoithiUI.db.profile.General.unitFrameFont = v
                                    ns.RefreshAllUnitFrames()
                                end,
                            },
                            ufBar = {
                                type = "select",
                                dialogControl = "LSM30_Statusbar",
                                name = "Status Bar",
                                order = 3,
                                values = function() return GetLSMKeys("statusbar") end,
                                get = function() return RoithiUI.db.profile.General.unitFrameBar end,
                                set = function(_, v)
                                    RoithiUI.db.profile.General.unitFrameBar = v
                                    ns.RefreshAllUnitFrames()
                                end,
                            },
                            cbHeader = {
                                type = "header",
                                name = "Castbars",
                                order = 10,
                            },
                            cbFont = {
                                type = "select",
                                dialogControl = "LSM30_Font",
                                name = "Font",
                                order = 11,
                                values = function() return GetLSMKeys("font") end,
                                get = function() return RoithiUI.db.profile.General.castbarFont end,
                                set = function(_, v)
                                    RoithiUI.db.profile.General.castbarFont = v
                                    -- Add RefreshAllCastbars call here once implemented
                                    if ns.RefreshAllCastbars then ns.RefreshAllCastbars() end
                                end,
                            },
                            cbBar = {
                                type = "select",
                                dialogControl = "LSM30_Statusbar",
                                name = "Status Bar",
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
                        name = "Reset to Defaults",
                        desc = "Reset all settings to default values and reload the UI. Cannot be undone.",
                        order = 10,
                        func = function() RoithiUI:ResetSettings() end,
                        width = "full",
                    },
                    testBoss = {
                        type = "toggle",
                        name = "Boss Frames Test Mode",
                        desc = "Toggle dummy boss frames for positioning.",
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
                    utilityFrames = {
                        type = "toggle",
                        name = "Encounter Resource Bar",
                        desc = "Toggle the Encounter Resource Bar (e.g., Vigor).",
                        order = 12,
                        get = function()
                            local db = RoithiUI.db.profile
                            return db.EncounterResource and db.EncounterResource.enabled
                        end,
                        set = function(_, v)
                            local db = RoithiUI.db.profile
                            if not db.EncounterResource then db.EncounterResource = {} end
                            db.EncounterResource.enabled = v

                            -- Update Live
                            local ufModule = RoithiUI:GetModule("UnitFrames")
                            if ufModule and ufModule.ToggleEncounterResource then ufModule:ToggleEncounterResource(v) end
                        end,
                        width = "full",
                    },
                    debugMode = {
                        type = "toggle",
                        name = "|cffff0000Debug Mode|r",
                        desc = "Enable debug logging to the chat window.",
                        order = 50,
                        get = function() return RoithiUI.db.profile.General.debugMode end,
                        set = function(_, v) RoithiUI.db.profile.General.debugMode = v end,
                        width = "full",
                    },
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
                    -- Populated below
                },
            },
            auras = GetGlobalAuraOptions(),
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
                    name = "> Unit Frames",
                    order = order,
                    func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", ufUnit) end,
                }
                order = order + 1
            end
            if currentContext ~= "castbars" and not unit:match("^boss%d$") then
                args.castbars = {
                    type = "execute",
                    name = "> Castbars",
                    order = order,
                    func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "castbars", unit) end,
                }
                order = order + 1
            end
            if currentContext ~= "auras" then
                local isBoss = unit:match("^boss%d$")
                args.auras = {
                    type = "execute",
                    name = "> Auras",
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
                    name = "> Custom Tags",
                    order = order,
                    func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "customtags", unit) end,
                }
                order = order + 1
            end
            return {
                type = "group",
                name = "Quick Links",
                inline = true,
                order = 2,
                args = args
            }
        end

        if not unit:match("^boss%d$") then
            options.args.unitframes.args[unit] = {
                type = "group",
                name = label,
                order = 10 + i,
                args = {
                    enable = {
                        type = "toggle",
                        name = "Enable Unit Frame",
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
                    quickLinks = CreateQuickLinks("unitframes"),

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
                },
            }
        end

        -- Populate the Global > Auras > Units table
        local targetArgs = options.args.auras.args.units.args
        if unit:match("^boss%d$") then
            if not targetArgs.bossFrames then
                targetArgs.bossFrames = {
                    type = "group",
                    name = "Boss Frames",
                    order = 30,
                    args = {}
                }
            end
            targetArgs = targetArgs.bossFrames.args
        end

        targetArgs[unit] = {
            type = "group",
            name = label,
            order = i,
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
                quickLinks = CreateQuickLinks("auras"),

                size = {
                    type = "range",
                    name = "Size",
                    order = 3,
                    min = 10,
                    max = 100,
                    step = 1,
                    get = function() return GetDB().auraSize or 20 end,
                    set = function(_, v)
                        GetDB().auraSize = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                spacing = {
                    type = "range",
                    name = "Spacing",
                    order = 3.5,
                    min = 0,
                    max = 40,
                    step = 1,
                    get = function() return GetDB().auraSpacing or 4 end,
                    set = function(_, v)
                        GetDB().auraSpacing = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                max = {
                    type = "range",
                    name = "Max Auras",
                    order = 4,
                    min = 1,
                    max = 40,
                    step = 1,
                    get = function() return GetDB().maxAuras or 8 end,
                    set = function(_, v)
                        GetDB().maxAuras = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                anchor = {
                    type = "select",
                    name = "Anchor Point",
                    order = 5,
                    values = { ["TOP"] = "Top", ["BOTTOM"] = "Bottom", ["LEFT"] = "Left", ["RIGHT"] = "Right", ["TOPLEFT"] = "Top Left", ["TOPRIGHT"] = "Top Right", ["BOTTOMLEFT"] = "Bottom Left", ["BOTTOMRIGHT"] = "Bottom Right", ["CENTER"] = "Center" },
                    get = function() return GetDB().auraAnchor or "BOTTOM" end,
                    set = function(_, v)
                        GetDB().auraAnchor = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                grow = {
                    type = "select",
                    name = "Grow Direction",
                    order = 6,
                    values = { ["RIGHT"] = "Left to Right", ["LEFT"] = "Right to Left", ["CENTER_HORIZONTAL"] = "Centered Horizontal", ["UP"] = "Bottom to Top", ["DOWN"] = "Top to Bottom", ["CENTER_VERTICAL"] = "Centered Vertical" },
                    get = function() return GetDB().auraGrowDirection or "RIGHT" end,
                    set = function(_, v)
                        GetDB().auraGrowDirection = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                x = {
                    type = "range",
                    name = "X Offset (Attached)",
                    order = 7,
                    min = -1000,
                    max = 1000,
                    step = 1,
                    get = function() return GetDB().auraX or 0 end,
                    set = function(_, v)
                        GetDB().auraX = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                y = {
                    type = "range",
                    name = "Y Offset (Attached)",
                    order = 8,
                    min = -1000,
                    max = 1000,
                    step = 1,
                    get = function() return GetDB().auraY or 4 end,
                    set = function(_, v)
                        GetDB().auraY = v; ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                detached = {
                    type = "toggle",
                    name = "Detach (Satellite Mode)",
                    desc = "Detach aura frame to move it independently via Edit Mode.",
                    order = 9,
                    get = function() return AL:IsDetached(unit, "Auras") end,
                    set = function(_, v)
                        GetDB().auraDetached = v
                        ns.RefreshUnitFrame(unit)
                    end,
                    hidden = function() return GetDB().separateAuras end,
                },
                buffGroup = {
                    type = "group",
                    name = "Buffs Bar Settings",
                    order = 9.1,
                    hidden = function() return not GetDB().separateAuras end,
                    args = {
                        size = {
                            type = "range",
                            name = "Size",
                            order = 1,
                            min = 10,
                            max = 100,
                            step = 1,
                            get = function() return GetDB().buffSize or GetDB().auraSize or 20 end,
                            set = function(_, v)
                                GetDB().buffSize = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        max = {
                            type = "range",
                            name = "Max Auras",
                            order = 2,
                            min = 1,
                            max = 40,
                            step = 1,
                            get = function() return GetDB().buffMaxAuras or GetDB().maxAuras or 8 end,
                            set = function(_, v)
                                GetDB().buffMaxAuras = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        spacing = {
                            type = "range",
                            name = "Spacing",
                            order = 3,
                            min = 0,
                            max = 40,
                            step = 1,
                            get = function() return GetDB().buffSpacing or GetDB().auraSpacing or 4 end,
                            set = function(_, v)
                                GetDB().buffSpacing = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        anchor = {
                            type = "select",
                            name = "Anchor Point",
                            order = 4,
                            values = { ["TOP"] = "Top", ["BOTTOM"] = "Bottom", ["LEFT"] = "Left", ["RIGHT"] = "Right", ["TOPLEFT"] = "Top Left", ["TOPRIGHT"] = "Top Right", ["BOTTOMLEFT"] = "Bottom Left", ["BOTTOMRIGHT"] = "Bottom Right", ["CENTER"] = "Center" },
                            get = function() return GetDB().buffAnchor or GetDB().auraAnchor or "BOTTOM" end,
                            set = function(_, v)
                                GetDB().buffAnchor = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        grow = {
                            type = "select",
                            name = "Grow Direction",
                            order = 5,
                            values = { ["RIGHT"] = "Left to Right", ["LEFT"] = "Right to Left", ["CENTER_HORIZONTAL"] = "Centered Horizontal", ["UP"] = "Bottom to Top", ["DOWN"] = "Top to Bottom", ["CENTER_VERTICAL"] = "Centered Vertical" },
                            get = function() return GetDB().buffGrowDirection or GetDB().auraGrowDirection or "RIGHT" end,
                            set = function(_, v)
                                GetDB().buffGrowDirection = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        detached = {
                            type = "toggle",
                            name = "Detach (Move in Edit Mode)",
                            order = 6,
                            get = function() return GetDB().buffDetached == true end,
                            set = function(_, v)
                                GetDB().buffDetached = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        x = {
                            type = "range",
                            name = "X Offset (Attached)",
                            order = 7,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return GetDB().buffXOffset or GetDB().auraX or 0 end,
                            set = function(_, v)
                                GetDB().buffXOffset = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        y = {
                            type = "range",
                            name = "Y Offset (Attached)",
                            order = 8,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return GetDB().buffYOffset or GetDB().auraY or 4 end,
                            set = function(_, v)
                                GetDB().buffYOffset = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                    }
                },
                debuffGroup = {
                    type = "group",
                    name = "Debuffs Bar Settings",
                    order = 9.2,
                    hidden = function() return not GetDB().separateAuras end,
                    args = {
                        size = {
                            type = "range",
                            name = "Size",
                            order = 1,
                            min = 10,
                            max = 100,
                            step = 1,
                            get = function() return GetDB().debuffSize or GetDB().auraSize or 20 end,
                            set = function(_, v)
                                GetDB().debuffSize = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        max = {
                            type = "range",
                            name = "Max Auras",
                            order = 2,
                            min = 1,
                            max = 40,
                            step = 1,
                            get = function() return GetDB().debuffMaxAuras or GetDB().maxAuras or 8 end,
                            set = function(_, v)
                                GetDB().debuffMaxAuras = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        spacing = {
                            type = "range",
                            name = "Spacing",
                            order = 3,
                            min = 0,
                            max = 40,
                            step = 1,
                            get = function() return GetDB().debuffSpacing or GetDB().auraSpacing or 4 end,
                            set = function(_, v)
                                GetDB().debuffSpacing = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        anchor = {
                            type = "select",
                            name = "Anchor Point",
                            order = 4,
                            values = { ["TOP"] = "Top", ["BOTTOM"] = "Bottom", ["LEFT"] = "Left", ["RIGHT"] = "Right", ["TOPLEFT"] = "Top Left", ["TOPRIGHT"] = "Top Right", ["BOTTOMLEFT"] = "Bottom Left", ["BOTTOMRIGHT"] = "Bottom Right", ["CENTER"] = "Center" },
                            get = function() return GetDB().debuffAnchor or GetDB().auraAnchor or "BOTTOM" end,
                            set = function(_, v)
                                GetDB().debuffAnchor = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        grow = {
                            type = "select",
                            name = "Grow Direction",
                            order = 5,
                            values = { ["RIGHT"] = "Left to Right", ["LEFT"] = "Right to Left", ["CENTER_HORIZONTAL"] = "Centered Horizontal", ["UP"] = "Bottom to Top", ["DOWN"] = "Top to Bottom", ["CENTER_VERTICAL"] = "Centered Vertical" },
                            get = function() return GetDB().debuffGrowDirection or GetDB().auraGrowDirection or "RIGHT" end,
                            set = function(_, v)
                                GetDB().debuffGrowDirection = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        detached = {
                            type = "toggle",
                            name = "Detach (Move in Edit Mode)",
                            order = 6,
                            get = function() return GetDB().debuffDetached == true end,
                            set = function(_, v)
                                GetDB().debuffDetached = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        x = {
                            type = "range",
                            name = "X Offset (Attached)",
                            order = 7,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return GetDB().debuffXOffset or GetDB().auraX or 0 end,
                            set = function(_, v)
                                GetDB().debuffXOffset = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        y = {
                            type = "range",
                            name = "Y Offset (Attached)",
                            order = 8,
                            min = -1000,
                            max = 1000,
                            step = 1,
                            get = function() return GetDB().debuffYOffset or GetDB().auraY or 4 end,
                            set = function(_, v)
                                GetDB().debuffYOffset = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                    }
                },
                filtersAndVisibility = {
                    type = "group",
                    name = "Filters & Layout",
                    order = 10,
                    args = GenerateAuraFilters(GetDB, function() ns.RefreshUnitFrame(unit) end),
                }
            }
        }

        if not unit:match("^boss%d$") then
            options.args.castbars.args[unit] = {
                type = "group",
                name = label,
                order = 10 + i,
                args = {
                    enable = {
                        type = "toggle",
                        name = "Enable Castbar",
                        order = 1,
                        get = function()
                            if not RoithiUI.db.profile.Castbar then return true end
                            if not RoithiUI.db.profile.Castbar[unit] then return true end
                            return RoithiUI.db.profile.Castbar[unit].enabled ~= false
                        end,
                        set = function(_, v)
                            if not RoithiUI.db.profile.Castbar then RoithiUI.db.profile.Castbar = {} end
                            if not RoithiUI.db.profile.Castbar[unit] then RoithiUI.db.profile.Castbar[unit] = {} end
                            RoithiUI.db.profile.Castbar[unit].enabled = v
                            if ns.UpdateCast and ns.bars and ns.bars[unit] then ns.UpdateCast(ns.bars[unit]) end
                            if EditModeManagerFrame and EditModeManagerFrame:IsShown() and ns.UpdateBlizzardVisibility then
                                ns.UpdateBlizzardVisibility()
                            end
                        end,
                    },
                    quickLinks = CreateQuickLinks("castbars"),
                }
            }
        end
    end

    -- Add Boss Frames settings to Unit Frames group
    options.args.unitframes.args["boss"] = {
        type = "group",
        name = "Boss Frames",
        order = 30,
        args = {
            enable = {
                type = "toggle",
                name = "Enable Boss Frames",
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
            quickLinks = {
                type = "group",
                name = "Quick Links",
                inline = true,
                order = 2,
                args = {
                    auras = {
                        type = "execute",
                        name = "> Auras",
                        order = 1,
                        func = function()
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "units",
                                "boss1")
                        end,
                    },
                    customtags = {
                        type = "execute",
                        name = "> Custom Tags",
                        order = 2,
                        func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "customtags", "boss1") end,
                    },
                }
            },
        }
    }

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
