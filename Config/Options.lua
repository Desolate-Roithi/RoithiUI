local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local Config = RoithiUI.Config or {}
RoithiUI.Config = Config
local LSM = LibStub("LibSharedMedia-3.0")
local AL = ns.AttachmentLogic
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local SafeNum = function(val, default)
    if val == nil or (issecretvalue and issecretvalue(val)) then
        return default or 0
    end
    local num = tonumber(val)
    return num or default or 0
end

local RESTRICTED_FRIENDLY_DEBUFF_SPELLS = {
    [124275] = "Light Stagger",
    [124274] = "Moderate Stagger",
    [124273] = "Heavy Stagger",
}

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
            name = L["Global Visibility & Container Settings"],
            order = 1,
            inline = true,
            args = {
                showBuffs = {
                    type = "toggle",
                    name = L["Show Buffs"],
                    desc  = L["Enable rendering of helpful auras."],
                    order = 1,
                    get = function() return GetDB().showBuffs ~= false end,
                    set = function(_, v)
                        GetDB().showBuffs = v; RefreshFunc()
                    end,
                },
                showDebuffs = {
                    type = "toggle",
                    name = L["Show Debuffs"],
                    desc  = L["Enable rendering of harmful auras."],
                    order = 2,
                    get = function() return GetDB().showDebuffs ~= false end,
                    set = function(_, v)
                        GetDB().showDebuffs = v; RefreshFunc()
                    end,
                },
                separateAuras = {
                    type = "toggle",
                    name = L["Separate Buffs & Debuffs"],
                    desc  = L["When checked, Buffs and Debuffs will anchor separately instead of flowing consecutively."],
                    order = 3,
                    get = function() return GetDB().separateAuras == true end,
                    set = function(_, v)
                        GetDB().separateAuras = v; RefreshFunc()
                    end,
                    hidden = function() return GetDB().isStandaloneCustom end,
                },
                hideTimeless = {
                    type = "toggle",
                    name = L["Hide Timeless Auras"],
                    desc  = L["Hides passive auras with no duration."],
                    order = 4,
                    get = function() return GetDB().hideTimeless == true end,
                    set = function(_, v)
                        GetDB().hideTimeless = v; RefreshFunc()
                    end,
                },
            },
        },
        group2_buffs = {
            type = "group",
            name = L["Helpful Aura Filters (Buffs)"],
            order = 2,
            inline = true,
            args = {
                showAllBuffs = {
                    type = "toggle",
                    name = L["All Buffs"],
                    desc  = L["Shows every active Buff on the unit. Overrides specific buff sub-filters below."],
                    order = 1,
                    get = function() return GetDB().showAllBuffs == true end,
                    set = function(_, v)
                        GetDB().showAllBuffs = v
                        if v then GetDB().onlyWhitelistBuffs = false end
                        RefreshFunc()
                    end,
                    disabled = function() return GetDB().onlyWhitelistBuffs == true end,
                },
                playerBuffs = {
                    type = "toggle",
                    name = L["My Buffs"],
                    desc  = L["Shows generic helpful auras cast by you."],
                    order = 2,
                    get = function() return GetDB().playerBuffs == true end,
                    set = function(_, v)
                        GetDB().playerBuffs = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllBuffs == true or GetDB().onlyWhitelistBuffs == true end,
                },
                raidInCombat = {
                    type = "toggle",
                    name = L["My Raid HoTs/Buffs"],
                    desc  = L["Safely shows your HoTs while in combat."],
                    order = 3,
                    get = function() return GetDB().raidInCombat == true end,
                    set = function(_, v)
                        GetDB().raidInCombat = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllBuffs == true or GetDB().onlyWhitelistBuffs == true end,
                },
                importantBuffs = {
                    type = "toggle",
                    name = L["Important Buffs"],
                    desc  = L["Shows Buffs explicitly flagged by Blizzard developers as critical for the encounter."],
                    order = 4,
                    get = function() return GetDB().importantBuffs == true end,
                    set = function(_, v)
                        GetDB().importantBuffs = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllBuffs == true or GetDB().onlyWhitelistBuffs == true end,
                },
                majorDefensivesBuffs = {
                    type = "toggle",
                    name = L["Major Defensives (Tanks)"],
                    desc  = L["Shows major defensive cooldowns (Buffs) on the unit (e.g. Shield Wall, Barkskin)."],
                    order = 5,
                    get = function() return GetDB().majorDefensivesBuffs == true or GetDB().majorDefensives == true end,
                    set = function(_, v)
                        GetDB().majorDefensivesBuffs = v; GetDB().majorDefensives = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllBuffs == true or GetDB().onlyWhitelistBuffs == true end,
                },
                externalDefensives = {
                    type = "toggle",
                    name = L["External Defensives"],
                    desc  = L["Shows major defensive buffs cast on the unit by OTHER players (e.g. Pain Suppression)."],
                    order = 6,
                    get = function() return GetDB().externalDefensives == true end,
                    set = function(_, v)
                        GetDB().externalDefensives = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllBuffs == true or GetDB().onlyWhitelistBuffs == true end,
                },
                onlyWhitelistBuffs = {
                    type = "toggle",
                    name = L["Show Only Whitelisted Buffs"],
                    desc  = L["Hides all Buffs except those explicitly added to the Spell Whitelist."],
                    order = 7,
                    get = function() return GetDB().onlyWhitelistBuffs == true end,
                    set = function(_, v)
                        GetDB().onlyWhitelistBuffs = v
                        if v then GetDB().showAllBuffs = false end
                        RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllBuffs == true end,
                },
            },
        },
        group3_debuffs = {
            type = "group",
            name = L["Harmful Aura Filters (Debuffs)"],
            order = 3,
            inline = true,
            args = {
                showAllDebuffs = {
                    type = "toggle",
                    name = L["All Debuffs"],
                    desc  = L["Shows every active Debuff on the unit. Overrides specific debuff sub-filters below."],
                    order = 1,
                    get = function() return GetDB().showAllDebuffs == true end,
                    set = function(_, v)
                        GetDB().showAllDebuffs = v
                        if v then GetDB().onlyWhitelistDebuffs = false end
                        RefreshFunc()
                    end,
                    disabled = function() return GetDB().onlyWhitelistDebuffs == true end,
                },
                playerDebuffs = {
                    type = "toggle",
                    name = L["My Debuffs"],
                    desc  = L["Shows generic harmful auras (like DoTs) cast by you."],
                    order = 2,
                    get = function() return GetDB().playerDebuffs == true end,
                    set = function(_, v)
                        GetDB().playerDebuffs = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllDebuffs == true or GetDB().onlyWhitelistDebuffs == true end,
                },
                importantDebuffs = {
                    type = "toggle",
                    name = L["Important Debuffs"],
                    desc  = L["Shows Debuffs explicitly flagged by Blizzard developers as critical for the encounter."],
                    order = 3,
                    get = function() return GetDB().importantDebuffs == true end,
                    set = function(_, v)
                        GetDB().importantDebuffs = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllDebuffs == true or GetDB().onlyWhitelistDebuffs == true end,
                },
                cc = {
                    type = "toggle",
                    name = L["Crowd Control"],
                    desc  = L["Shows Debuffs that restrict character control (Stuns, Fears, Roots, etc)."],
                    order = 4,
                    get = function() return GetDB().cc == true end,
                    set = function(_, v)
                        GetDB().cc = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllDebuffs == true or GetDB().onlyWhitelistDebuffs == true end,
                },
                dispellable = {
                    type = "toggle",
                    name = L["Dispellable"],
                    desc  = L["Shows Debuffs that your current Class/Spec is physically capable of dispelling."],
                    order = 5,
                    get = function() return GetDB().dispellable == true or GetDB().onlyDispellable == true end,
                    set = function(_, v)
                        GetDB().dispellable = v; GetDB().onlyDispellable = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllDebuffs == true or GetDB().onlyWhitelistDebuffs == true end,
                },
                majorDefensivesDebuffs = {
                    type = "toggle",
                    name = L["Major Defensives (Debuffs)"],
                    desc  = L["Shows major defensive restrictions (Debuffs) on the unit (e.g. Forbearance, Weakened Soul)."],
                    order = 6,
                    get = function() return GetDB().majorDefensivesDebuffs == true end,
                    set = function(_, v)
                        GetDB().majorDefensivesDebuffs = v; RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllDebuffs == true or GetDB().onlyWhitelistDebuffs == true end,
                },
                onlyWhitelistDebuffs = {
                    type = "toggle",
                    name = L["Show Only Whitelisted Debuffs"],
                    desc  = L["Hides all Debuffs except those explicitly added to the Spell Whitelist."],
                    order = 7,
                    get = function() return GetDB().onlyWhitelistDebuffs == true end,
                    set = function(_, v)
                        GetDB().onlyWhitelistDebuffs = v
                        if v then GetDB().showAllDebuffs = false end
                        RefreshFunc()
                    end,
                    disabled = function() return GetDB().showAllDebuffs == true end,
                },
            },
        },
        group6_blacklist = {
            type = "group",
            name = L["Spell Blacklist"],
            order = 6,
            inline = true,
            args = {
                engineNotice = {
                    type = "description",
                    name = L["|cffff8800Note:|r Blizzard's 12.1.0 engine permits spell ID blacklisting on helpful buffs and enemy debuffs. Harmful debuffs on friendly units (e.g. Stagger on player/party) are protected by Blizzard anti-automation rules and cannot be hidden by spell ID."],
                    order = 0.5,
                },
                addSpell = {
                    type = "input",
                    name = L["Add Spell ID"],
                    desc  = L["Enter a Spell ID to blacklist it (hide)."],
                    order = 1,
                    get = function() return "" end,
                    set = function(_, v)
                        local id = tonumber(v)
                        if id then
                            if RESTRICTED_FRIENDLY_DEBUFF_SPELLS[id] then
                                local sName = RESTRICTED_FRIENDLY_DEBUFF_SPELLS[id]
                                print(string.format("|cffff8800[RoithiUI]|r Spell ID %d (%s) cannot be blacklisted because Blizzard's 12.1.0 engine protects harmful debuffs on friendly units from identity filtering.", id, sName))
                                return
                            end
                            local db = GetDB()
                            if not db.Blacklist then db.Blacklist = {} end
                            db.Blacklist[id] = true
                            RefreshFunc()
                        end
                    end,
                },
                removeSpell = {
                    type = "multiselect",
                    name = L["Blacklisted Spell IDs"],
                    desc  = L["Uncheck a Spell ID to remove it from the blacklist."],
                    order = 2,
                    values = function()
                        local db = GetDB()
                        local out = {}

                        -- 1. Default blacklist
                        local defaultBlacklist = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
                        if defaultBlacklist then
                            for id, active in pairs(defaultBlacklist) do
                                if active then
                                    out[id] = true
                                end
                            end
                        end

                        -- 2. Local overrides
                        if db and db.Blacklist then
                            for id, active in pairs(db.Blacklist) do
                                if active then
                                    out[id] = true
                                elseif active == false then
                                    out[id] = nil
                                end
                            end
                        end

                        -- 3. Resolve names
                        local displayList = {}
                        for id in pairs(out) do
                            local success, name = pcall(function()
                                return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
                            end)
                            if success and name and name ~= "" then
                                displayList[id] = string.format("%s (%d)", name, id)
                            else
                                displayList[id] = tostring(id)
                            end
                        end
                        return displayList
                    end,
                    get = function(_, key)
                        local db = GetDB()
                        local id = tonumber(key) or key
                        if db and db.Blacklist and db.Blacklist[id] ~= nil then
                            return db.Blacklist[id]
                        end
                        local defaultBlacklist = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
                        if defaultBlacklist and defaultBlacklist[id] ~= nil then
                            return defaultBlacklist[id]
                        end
                        return false
                    end,
                    set = function(_, key, value)
                        local db = GetDB()
                        if db then
                            local id = tonumber(key) or key
                            if not db.Blacklist then db.Blacklist = {} end
                            db.Blacklist[id] = value
                            RefreshFunc()
                        end
                    end,
                },
            },
        },
        group7_whitelist = {
            type = "group",
            name = L["Spell Whitelist"],
            order = 7,
            inline = true,
            args = {
                engineNotice = {
                    type = "description",
                    name = L["|cffff8800Note:|r Blizzard's 12.1.0 engine permits spell ID whitelisting on helpful buffs and enemy debuffs. Harmful debuffs on friendly units (e.g. Stagger on player/party) are protected by Blizzard anti-automation rules and cannot be whitelisted by spell ID."],
                    order = 0.5,
                },
                addSpell = {
                    type = "input",
                    name = L["Add Spell ID"],
                    desc  = L["Enter a Spell ID to whitelist it (always show)."],
                    order = 1,
                    get = function() return "" end,
                    set = function(_, v)
                        local id = tonumber(v)
                        if id then
                            if RESTRICTED_FRIENDLY_DEBUFF_SPELLS[id] then
                                local sName = RESTRICTED_FRIENDLY_DEBUFF_SPELLS[id]
                                print(string.format("|cffff8800[RoithiUI]|r Spell ID %d (%s) cannot be whitelisted because Blizzard's 12.1.0 engine protects harmful debuffs on friendly units from identity filtering.", id, sName))
                                return
                            end
                            local db = GetDB()
                            if not db.Whitelist then db.Whitelist = {} end
                            db.Whitelist[id] = true
                            RefreshFunc()
                        end
                    end,
                },
                removeSpell = {
                    type = "multiselect",
                    name = L["Whitelisted Spell IDs"],
                    desc  = L["Uncheck a Spell ID to remove it from the whitelist."],
                    order = 2,
                    values = function()
                        local db = GetDB()
                        local out = {}
                        if db and db.Whitelist then
                            for id, active in pairs(db.Whitelist) do
                                if active then
                                    local success, name = pcall(function()
                                        return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
                                    end)
                                    if success and name and name ~= "" then
                                        out[id] = string.format("%s (%d)", name, id)
                                    else
                                        out[id] = tostring(id)
                                    end
                                end
                            end
                        end
                        return out
                    end,
                    get = function(_, key) return true end,
                    set = function(_, key, value)
                        if not value then
                            local db = GetDB()
                            if db and db.Whitelist then
                                db.Whitelist[key] = nil
                                RefreshFunc()
                            end
                        end
                    end,
                    confirm = true,
                    hidden = function()
                        local db = GetDB()
                        return not db or not db.Whitelist or next(db.Whitelist) == nil
                    end,
                },
            },
        }
    }
end

local function GetGlobalAuraOptions()
    local group = {
        type = "group",
        name = L["Auras"],
        order = 4,
        args = {
            intro = {
                type = "description",
                name = L["Manage Smart Filters (12.0.1) and Custom Aura Frames."],
                order = 0,
            },
            custom = {
                type = "group",
                name = L["Custom Frames"],
                order = 2,
                args = {
                    addName = {
                        type = "input",
                        name = L["Create New Frame (ID)"],
                        desc  = L["Enter a unique name for the new custom aura frame and press Enter."],
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
                                        stackFontSize = 10,
                                        stackAnchor = "BOTTOMRIGHT",
                                        stackX = 2,
                                        stackY = -2,
                                        hideBorder = true,
                                        zoomPercent = 15,
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
                name = L["Unit Aura Settings"],
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
                    layoutGroup = {
                        type = "group",
                        name = L["General Layout Settings"],
                        order = 1,
                        inline = true,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = L["Enable"],
                                order = 1,
                                get = function() return GetDB().enabled == true end,
                                set = function(_, v)
                                    GetDB().enabled = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            unit = {
                                type = "select",
                                name = L["Request Buffs From Unit"],
                                order = 2,
                                values = unitsList,
                                get = function() return GetDB().unit or "player" end,
                                set = function(_, v)
                                    GetDB().unit = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            size = {
                                type = "range",
                                name = L["Aura Size"],
                                order = 3,
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
                                name = L["Max Auras"],
                                order = 4,
                                min = 1,
                                max = 40,
                                step = 1,
                                get = function() return GetDB().maxAuras or 4 end,
                                set = function(_, v)
                                    GetDB().maxAuras = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            perRow = {
                                type = "range",
                                name = L["Icons Per Row"],
                                desc  = L["Number of aura icons per row before line wrapping."],
                                order = 4.5,
                                min = 1,
                                max = 40,
                                step = 1,
                                get = function() return GetDB().maxAurasPerRow or GetDB().perRow or GetDB().maxAuras or 4 end,
                                set = function(_, v)
                                    GetDB().maxAurasPerRow = v; GetDB().perRow = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            spacing = {
                                type = "range",
                                name = L["Spacing"],
                                order = 5,
                                min = 0,
                                max = 40,
                                step = 1,
                                get = function() return GetDB().auraSpacing or 4 end,
                                set = function(_, v)
                                    GetDB().auraSpacing = v; ns.RefreshAllUnitFrames()
                                end,
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
                                    GetDB().auraGrowDirection = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            zoom = {
                                type = "range",
                                name = L["Icon Zoom (%)"],
                                order = 8,
                                min = 0,
                                max = 50,
                                step = 1,
                                get = function() return GetDB().zoomPercent ~= nil and GetDB().zoomPercent or 15 end,
                                set = function(_, v)
                                    GetDB().zoomPercent = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            delete = {
                                type = "execute",
                                name = L["Delete Frame"],
                                order = 9,
                                confirm = true,
                                func = function()
                                    RoithiUI.db.profile.CustomAuraFrames[id] = nil
                                    ns.RefreshAllUnitFrames()
                                end,
                            },
                        }
                    },
                    positionGroup = {
                        type = "group",
                        name = L["Screen Position Settings"],
                        order = 2,
                        inline = true,
                        args = {
                            x = {
                                type = "range",
                                name = L["X Offset (from Screen Center)"],
                                order = 1,
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
                                name = L["Y Offset (from Screen Center)"],
                                order = 2,
                                min = -2000,
                                max = 2000,
                                step = 1,
                                get = function() return GetDB().screenY or -50 end,
                                set = function(_, v)
                                    GetDB().screenY = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                        }
                    },
                    timerGroup = {
                        type = "group",
                        name = L["Timer Text Settings"],
                        order = 3,
                        inline = true,
                        args = {
                            timerFontSize = {
                                type = "range",
                                name = L["Timer Font Size"],
                                order = 1,
                                min = 6,
                                max = 24,
                                step = 1,
                                get = function() return GetDB().timerFontSize or 10 end,
                                set = function(_, v)
                                    GetDB().timerFontSize = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            timerAnchor = {
                                type = "select",
                                name = L["Timer Anchor"],
                                order = 2,
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
                                    GetDB().timerAnchor = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            timerX = {
                                type = "range",
                                name = L["Timer X Offset"],
                                order = 3,
                                min = -50,
                                max = 50,
                                step = 1,
                                get = function() return GetDB().timerX or 0 end,
                                set = function(_, v)
                                    GetDB().timerX = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            timerY = {
                                type = "range",
                                name = L["Timer Y Offset"],
                                order = 4,
                                min = -50,
                                max = 50,
                                step = 1,
                                get = function() return GetDB().timerY or 0 end,
                                set = function(_, v)
                                    GetDB().timerY = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                        }
                    },
                    stackGroup = {
                        type = "group",
                        name = L["Stack Count Settings"],
                        order = 4,
                        inline = true,
                        args = {
                            stackFontSize = {
                                type = "range",
                                name = L["Stack Font Size"],
                                order = 1,
                                min = 6,
                                max = 24,
                                step = 1,
                                get = function() return GetDB().stackFontSize or 10 end,
                                set = function(_, v)
                                    GetDB().stackFontSize = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            stackAnchor = {
                                type = "select",
                                name = L["Stack Anchor"],
                                order = 2,
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
                                    GetDB().stackAnchor = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            stackX = {
                                type = "range",
                                name = L["Stack X Offset"],
                                order = 3,
                                min = -50,
                                max = 50,
                                step = 1,
                                get = function() return GetDB().stackX or 2 end,
                                set = function(_, v)
                                    GetDB().stackX = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                            stackY = {
                                type = "range",
                                name = L["Stack Y Offset"],
                                order = 4,
                                min = -50,
                                max = 50,
                                step = 1,
                                get = function() return GetDB().stackY or -2 end,
                                set = function(_, v)
                                    GetDB().stackY = v; ns.RefreshAllUnitFrames()
                                end,
                            },
                        }
                    },
                    filtersGroup = {
                        type = "group",
                        name = L["Filters & Visibility"],
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
    local profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(RoithiUI.db)
    profileOptions.args.sharing = {
        type = "group",
        name = L["Sharing"],
        order = 100,
        args = {
            intro = {
                type = "description",
                name = L["Export or Import your RoithiUI profile settings as a compressed string."],
                order = 1,
            },
            exportGroup = {
                type = "group",
                name = L["Export"],
                order = 10,
                inline = true,
                args = {
                    exportString = {
                        type = "input",
                        name = L["Your Export String"],
                        desc  = L["Copy this string to share your profile with others."],
                        order = 1,
                        width = "full",
                        multiline = 5,
                        get = function()
                            local PS = RoithiUI:GetModule("ProfileSharing")
                            return PS and PS:ExportProfile() or ""
                        end,
                        set = function() end, -- Read-only
                    },
                },
            },
            importGroup = {
                type = "group",
                name = L["Import"],
                order = 20,
                inline = true,
                args = {
                    importString = {
                        type = "input",
                        name = L["Paste Import String"],
                        desc  = L["Paste a RoithiUI profile string here and click Import."],
                        order = 1,
                        width = "full",
                        multiline = 5,
                        get = function() return RoithiUI.db.profile.tempImportString or "" end,
                        set = function(_, v) RoithiUI.db.profile.tempImportString = v end,
                    },
                    importBtn = {
                        type = "execute",
                        name = L["Import Profile"],
                        desc  = L["Applying an imported profile will overwrite your current settings and reload the UI."],
                        order = 2,
                        confirm = true,
                        func = function()
                            local PS = RoithiUI:GetModule("ProfileSharing")
                            if PS then
                                local success, msg = PS:ImportProfile(RoithiUI.db.profile.tempImportString)
                                if success then
                                    RoithiUI.db.profile.tempImportString = nil
                                    ReloadUI()
                                else
                                    print("|cffff0000RoithiUI Import Error:|r " .. tostring(msg))
                                end
                            end
                        end,
                    },
                },
            },
        },
    }

    local options = {
        type = "group",
        name = L["RoithiUI Settings"],
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                args = {
                    -- Moved from General.lua or new items ca go here
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
                                    ns.RefreshAllUnitFrames()
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
                                    ns.RefreshAllUnitFrames()
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
                                    -- Add RefreshAllCastbars call here once implemented
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
            },
            unitframes = {
                type = "group",
                name = L["Unit Frames"],
                order = 2,
                args = {
                    intro = {
                        type = "description",
                        name = L["Configure text, auras, and indicators for Unit Frames."],
                        order = 1,
                    },
                    -- Units will be populated dynamically or defined below
                },
            },
            customtags = RoithiUI.Config.GetCustomTagsOptions and RoithiUI.Config.GetCustomTagsOptions() or nil,
            castbars = {
                type = "group",
                name = L["Castbars"],
                order = 3,
                args = {
                    -- Populated below
                },
            },
            auras = GetGlobalAuraOptions(),
            encounterbar = {
                type = "group",
                name = L["Encounter Resource Bar"],
                order = 5,
                args = {
                    intro = {
                        type = "description",
                        name = L["Configure the custom Encounter Resource Bar. Position it via LibEditMode (Edit Mode)."],
                        order = 0,
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable"],
                        desc  = L["Show the custom encounter resource bar (hides the Blizzard default)."],
                        order = 1,
                        width = "full",
                        get = function()
                            local db = RoithiUI.db.profile.EncounterResource
                            return db and db.enabled
                        end,
                        set = function(_, v)
                            local db = RoithiUI.db.profile
                            if not db.EncounterResource then db.EncounterResource = {} end
                            db.EncounterResource.enabled = v
                            local EB = RoithiUI:GetModule("EncounterBar")
                            if EB and EB.Toggle then EB:Toggle(v) end
                        end,
                    },
                    sizeGroup = {
                        type = "group",
                        name = L["Size"],
                        order = 10,
                        inline = true,
                        args = {
                            width = {
                                type = "range",
                                name = L["Width"],
                                order = 1,
                                min = 50, max = 700, step = 1,
                                get = function() return (RoithiUI.db.profile.EncounterResource or {}).width or 250 end,
                                set = function(_, v)
                                    local db = RoithiUI.db.profile.EncounterResource
                                    if db then db.width = v end
                                    local bar = _G.RoithiEncounterResource
                                    if bar then bar:SetWidth(v) end
                                end,
                            },
                            height = {
                                type = "range",
                                name = L["Height"],
                                order = 2,
                                min = 4, max = 60, step = 1,
                                get = function() return (RoithiUI.db.profile.EncounterResource or {}).height or 20 end,
                                set = function(_, v)
                                    local db = RoithiUI.db.profile.EncounterResource
                                    if db then db.height = v end
                                    local bar = _G.RoithiEncounterResource
                                    if bar then bar:SetHeight(v) end
                                end,
                            },
                        },
                    },
                    fontGroup = {
                        type = "group",
                        name = L["Text"],
                        order = 20,
                        inline = true,
                        args = {
                            fontSize = {
                                type = "range",
                                name = L["Font Size"],
                                order = 1,
                                min = 6, max = 24, step = 1,
                                get = function() return (RoithiUI.db.profile.EncounterResource or {}).fontSize or 12 end,
                                set = function(_, v)
                                    local db = RoithiUI.db.profile.EncounterResource
                                    if db then db.fontSize = v end
                                    local bar = _G.RoithiEncounterResource
                                    if bar and bar.Text then
                                        local LibR = LibStub("LibRoithi-1.0")
                                        if LibR then LibR.mixins:SetFont(bar.Text, "Friz Quadrata TT", v, "OUTLINE") end
                                    end
                                end,
                            },
                            texture = {
                                type = "select",
                                dialogControl = "LSM30_Statusbar",
                                name = L["Bar Texture"],
                                order = 2,
                                values = function() return GetLSMKeys("statusbar") end,
                                get = function() return (RoithiUI.db.profile.EncounterResource or {}).texture or "Solid" end,
                                set = function(_, v)
                                    local db = RoithiUI.db.profile.EncounterResource
                                    if db then db.texture = v end
                                    local bar = _G.RoithiEncounterResource
                                    if bar then
                                        bar:SetStatusBarTexture(
                                            LSM:Fetch("statusbar", v) or "Interface\\TargetingFrame\\UI-StatusBar"
                                        )
                                    end
                                end,
                            },
                        },
                    },
                    whitelistGroup = {
                        type = "group",
                        name = L["Widget Whitelist"],
                        order = 30,
                        inline = true,
                        args = {
                            addID = {
                                type = "input",
                                name = L["Add Widget ID"],
                                desc  = L["Enter a Widget ID to whitelist it."],
                                order = 1,
                                get = function() return "" end,
                                set = function(_, v)
                                    local id = tonumber(v)
                                    if id then
                                        local db = RoithiUI.db.profile.EncounterResource
                                        if not db.whitelist then db.whitelist = {} end
                                        db.whitelist[id] = true
                                    end
                                end,
                            },
                            removeID = {
                                type = "multiselect",
                                name = L["Whitelisted IDs"],
                                desc  = L["Uncheck an ID to remove it from the whitelist."],
                                order = 2,
                                values = function()
                                    local db = RoithiUI.db.profile.EncounterResource
                                    local out = {}
                                    if db and db.whitelist then
                                        for id, _ in pairs(db.whitelist) do
                                            out[id] = tostring(id)
                                        end
                                    end
                                    return out
                                end,
                                get = function(_, key) return true end,
                                set = function(_, key, value)
                                    if not value then
                                        local db = RoithiUI.db.profile.EncounterResource
                                        if db and db.whitelist then
                                            db.whitelist[key] = nil
                                        end
                                    end
                                end,
                                confirm = true,
                                hidden = function()
                                    local db = RoithiUI.db.profile.EncounterResource
                                    return not db or not db.whitelist or next(db.whitelist) == nil
                                end,
                            },
                        },
                    },
                    posNote = {
                        type = "description",
                        name = L["\n|cffffd100Tip:|r Use Edit Mode (default key: Alt+C) to drag and reposition the bar on screen."],
                        order = 30,
                    },
                },
            },
            profiles = profileOptions,
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
                    name = L["> Unit Frames"],
                    order = order,
                    func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", ufUnit) end,
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

        -- Populate the Global > Auras > Units table
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
            name = label,
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
                                -- ["CENTER_HORIZONTAL_DOWN"] = "Centered Horizontal (Grow Down)",
                                -- ["CENTER_HORIZONTAL_UP"]   = "Centered Horizontal (Grow Up)",
                                ["CENTER_VERTICAL"]        = "Centered Vertical",
                                -- ["CENTER_VERTICAL_RIGHT"]  = "Centered Vertical (Grow Right)",
                                -- ["CENTER_VERTICAL_LEFT"]   = "Centered Vertical (Grow Left)",
                            },
                            sorting = { "RIGHT_DOWN", "RIGHT_UP", "LEFT_DOWN", "LEFT_UP", "DOWN_RIGHT", "DOWN_LEFT", "UP_RIGHT", "UP_LEFT", "CENTER_HORIZONTAL", "CENTER_VERTICAL" --[[, "CENTER_HORIZONTAL_DOWN", "CENTER_HORIZONTAL_UP", "CENTER_VERTICAL_RIGHT", "CENTER_VERTICAL_LEFT"]] },
                            get = function() return GetDB().debuffGrowDirection or GetDB().auraGrowDirection or "RIGHT_DOWN" end,
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
                        name = L["Enable Castbar"],
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
            quickLinks = {
                type = "group",
                name = L["Quick Links"],
                inline = true,
                order = 2,
                args = {
                    auras = {
                        type = "execute",
                        name = L["> Auras"],
                        order = 1,
                        func = function()
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "units",
                                "boss1")
                        end,
                    },
                    customtags = {
                        type = "execute",
                        name = L["> Custom Tags"],
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
        if not self.optionsFrame then
            -- AceConfigDialog's AddToBlizOptions can error if already registered in Blizzard Settings
            local success, frame, categoryID = pcall(ACD.AddToBlizOptions, ACD, "RoithiUI", "RoithiUI")
            if success then
                self.optionsFrame = frame
                RoithiUI.SettingsCategoryID = categoryID
            end
        end
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
