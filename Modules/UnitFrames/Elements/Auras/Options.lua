local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI", true)

local RESTRICTED_FRIENDLY_DEBUFF_SPELLS = {
    [124275] = "Light Stagger",
    [124274] = "Moderate Stagger",
    [124273] = "Heavy Stagger",
}

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
                globalNotice = {
                    type = "description",
                    name = function()
                        local gl = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
                        local count = 0
                        if gl then
                            for _, active in pairs(gl) do
                                if active then count = count + 1 end
                            end
                        end
                        if count > 0 then
                            return string.format(L["|cff00ccff%d spell(s) are already hidden by the Global Blacklist|r (Auras tab). They are not shown here — manage them there."], count)
                        end
                        return ""
                    end,
                    order = 0.6,
                    hidden = function()
                        local gl = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
                        if not gl then return true end
                        for _, active in pairs(gl) do
                            if active then return false end
                        end
                        return true
                    end,
                },
                addSpell = {
                    type = "input",
                    name = L["Add Spell ID"],
                    desc  = L["Enter a Spell ID to blacklist it on this frame only."],
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
                            -- Guard: already in global blacklist
                            local gl = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
                            if gl and gl[id] then
                                print(string.format("|cff00ccff[RoithiUI]|r Spell ID %d is already in the Global Blacklist — it is hidden on all frames. Use the Auras tab to manage it.", id))
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
                    name = L["Frame Blacklisted Spell IDs"],
                    desc  = L["Uncheck a Spell ID to remove it from this frame's blacklist. Globally blacklisted spells are managed in the Auras tab."],
                    order = 2,
                    values = function()
                        local db = GetDB()
                        local gl = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
                        local displayList = {}
                        -- Only show entries that are in the PER-FRAME blacklist and NOT already in the global one
                        if db and db.Blacklist then
                            for id, active in pairs(db.Blacklist) do
                                if active and not (gl and gl[id]) then
                                    local success, name = pcall(function()
                                        return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
                                    end)
                                    if success and name and name ~= "" then
                                        displayList[id] = string.format("%s (%d)", name, id)
                                    else
                                        displayList[id] = tostring(id)
                                    end
                                end
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
                    hidden = function()
                        local db = GetDB()
                        local gl = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
                        if not db or not db.Blacklist then return true end
                        for id, active in pairs(db.Blacklist) do
                            if active and not (gl and gl[id]) then return false end
                        end
                        return true
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
                disabledNotice = {
                    type = "description",
                    name = L["|cffff8800Note:|r The Spell Whitelist is only active when 'Show Only Whitelisted Buffs' or 'Show Only Whitelisted Debuffs' is checked above."],
                    order = 0.1,
                    hidden = function()
                        local db = GetDB()
                        return db and (db.onlyWhitelistBuffs or db.onlyWhitelistDebuffs)
                    end,
                },
                engineNotice = {
                    type = "description",
                    name = L["|cffff8800Note:|r Blizzard's 12.1.0 engine permits spell ID whitelisting on helpful buffs and enemy debuffs. Harmful debuffs on friendly units (e.g. Stagger on player/party) are protected by Blizzard anti-automation rules and cannot be whitelisted by spell ID."],
                    order = 0.5,
                    hidden = function()
                        local db = GetDB()
                        return not (db and (db.onlyWhitelistBuffs or db.onlyWhitelistDebuffs))
                    end,
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
                    disabled = function()
                        local db = GetDB()
                        return not (db and (db.onlyWhitelistBuffs or db.onlyWhitelistDebuffs))
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
                    disabled = function()
                        local db = GetDB()
                        return not (db and (db.onlyWhitelistBuffs or db.onlyWhitelistDebuffs))
                    end,
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
            globalBlacklist = {
                type = "group",
                name = L["Global Spell Blacklist"],
                order = 1,
                inline = true,
                args = {
                    notice = {
                        type = "description",
                        name = L["|cffff8800Note:|r Spells added here are hidden on ALL aura containers. Use the per-frame blacklist (inside each unit's Auras > Filters) for frame-specific overrides."],
                        order = 0.5,
                    },
                    addSpell = {
                        type = "input",
                        name = L["Add Spell ID"],
                        desc  = L["Enter a Spell ID to globally blacklist (hide on all frames)."],
                        order = 1,
                        get = function() return "" end,
                        set = function(_, v)
                            local sid = tonumber(v)
                            if sid then
                                if not RoithiUI.db.profile.Auras then RoithiUI.db.profile.Auras = {} end
                                if not RoithiUI.db.profile.Auras.Blacklist then RoithiUI.db.profile.Auras.Blacklist = {} end
                                RoithiUI.db.profile.Auras.Blacklist[sid] = true
                                ns.RefreshAllUnitFrames()
                            end
                        end,
                    },
                    removeSpell = {
                        type = "multiselect",
                        name = L["Globally Blacklisted Spell IDs"],
                        desc  = L["Uncheck a Spell ID to remove it from the global blacklist."],
                        order = 2,
                        values = function()
                            local out = {}
                            local bl = RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
                            if bl then
                                for sid, active in pairs(bl) do
                                    if active then
                                        local ok, name = pcall(function()
                                            return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)
                                        end)
                                        if ok and name and name ~= "" then
                                            out[sid] = string.format("%s (%d)", name, sid)
                                        else
                                            out[sid] = tostring(sid)
                                        end
                                    end
                                end
                            end
                            return out
                        end,
                        get = function(_, key) return true end,
                        set = function(_, key, value)
                            if not value then
                                if RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist then
                                    RoithiUI.db.profile.Auras.Blacklist[key] = nil
                                    ns.RefreshAllUnitFrames()
                                end
                            end
                        end,
                        confirm = true,
                        hidden = function()
                            local bl = RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
                            return not bl or next(bl) == nil
                        end,
                    },
                },
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
                    deleteFrame = {
                        type = "execute",
                        name = L["Delete Frame"],
                        order = 999,
                        confirm = true,
                        func = function()
                            RoithiUI.db.profile.CustomAuraFrames[id] = nil
                            ns.RefreshAllUnitFrames()
                        end,
                    },
                }
            }
            i = i + 1
        end
    end

    return group
end


ns.GetAurasOptions = GetGlobalAuraOptions
ns.GenerateAuraFilters = GenerateAuraFilters
