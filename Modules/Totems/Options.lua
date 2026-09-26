local addonName, ns = ...
if ns.skipLoad then return end
if not ns.IsForever and not ns.isTestEnvironment then return end
local RoithiUI = _G.RoithiUI
local Totems = RoithiUI:GetModule("Totems", true)
if not Totems then return end
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function Totems:GetOptions()
    local options = {
        type = "group",
        name = L["Totem Bar"],
        order = 95,
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Totem Bar"],
                        desc = L["Enables the dedicated Totem Bar module."],
                        order = 1,
                        get = function() return self.db.enabled ~= false end,
                        set = function(_, val)
                            self.db.enabled = val
                            if val then self:Enable() else self:Disable() end
                        end,
                    },
                    showOnAllClasses = {
                        type = "toggle",
                        name = L["Show On All Classes"],
                        desc = L["Display the Totem Bar even on non-Shaman classes for testing or custom setups."],
                        order = 2,
                        get = function() return self.db.showOnAllClasses == true end,
                        set = function(_, val)
                            self.db.showOnAllClasses = val
                            if self:ShouldRun() then
                                self:Enable()
                            else
                                self:Disable()
                            end
                        end,
                    },
                },
            },
            layout = {
                type = "group",
                name = L["Layout & Sizing"],
                order = 2,
                inline = true,
                disabled = function() return not self.db.enabled end,
                args = {
                    orientation = {
                        type = "select",
                        name = L["Orientation"],
                        order = 1,
                        values = {
                            ["HORIZONTAL"] = L["Horizontal"],
                            ["VERTICAL"] = L["Vertical"],
                        },
                        get = function() return self.db.orientation or "HORIZONTAL" end,
                        set = function(_, val)
                            self.db.orientation = val
                            self:UpdateBarLayout()
                        end,
                    },
                    buttonSize = {
                        type = "range",
                        name = L["Button Size"],
                        order = 2,
                        min = 20,
                        max = 64,
                        step = 1,
                        get = function() return self.db.buttonSize or 36 end,
                        set = function(_, val)
                            self.db.buttonSize = val
                            self:UpdateBarLayout()
                        end,
                    },
                    spacing = {
                        type = "range",
                        name = L["Spacing"],
                        order = 3,
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function() return self.db.spacing or 4 end,
                        set = function(_, val)
                            self.db.spacing = val
                            self:UpdateBarLayout()
                        end,
                    },
                },
            },
            elements = {
                type = "group",
                name = L["Slots & Display"],
                order = 3,
                inline = true,
                disabled = function() return not self.db.enabled end,
                args = {
                    showDuration = {
                        type = "toggle",
                        name = L["Show Timers"],
                        desc = L["Show active remaining duration timers directly on the buttons."],
                        order = 1,
                        get = function() return self.db.showDuration ~= false end,
                        set = function(_, val)
                            self.db.showDuration = val
                            self:OnTick()
                        end,
                    },
                    showCooldown = {
                        type = "toggle",
                        name = L["Show Cooldown Swipes"],
                        desc = L["Display cooldown animations on totem buttons."],
                        order = 2,
                        get = function() return self.db.showCooldown ~= false end,
                        set = function(_, val)
                            self.db.showCooldown = val
                        end,
                    },
                    showEarth = {
                        type = "toggle",
                        name = L["Show Earth Slot"],
                        order = 3,
                        get = function() return self.db.showEarth ~= false end,
                        set = function(_, val)
                            self.db.showEarth = val
                            self:UpdateBarLayout()
                        end,
                    },
                    showFire = {
                        type = "toggle",
                        name = L["Show Fire Slot"],
                        order = 4,
                        get = function() return self.db.showFire ~= false end,
                        set = function(_, val)
                            self.db.showFire = val
                            self:UpdateBarLayout()
                        end,
                    },
                    showWater = {
                        type = "toggle",
                        name = L["Show Water Slot"],
                        order = 5,
                        get = function() return self.db.showWater ~= false end,
                        set = function(_, val)
                            self.db.showWater = val
                            self:UpdateBarLayout()
                        end,
                    },
                    showAir = {
                        type = "toggle",
                        name = L["Show Air Slot"],
                        order = 6,
                        get = function() return self.db.showAir ~= false end,
                        set = function(_, val)
                            self.db.showAir = val
                            self:UpdateBarLayout()
                        end,
                    },
                    showShield = {
                        type = "toggle",
                        name = L["Show Shield Slot"],
                        desc = L["Display elemental shield selector (Lightning, Water, Earth Shield)."],
                        order = 7,
                        get = function() return self.db.showShield ~= false end,
                        set = function(_, val)
                            self.db.showShield = val
                            self:UpdateBarLayout()
                        end,
                    },
                    showWeapon = {
                        type = "toggle",
                        name = L["Show Weapon Slot"],
                        desc = L["Display weapon imbue selector (Windfury, Flametongue, Rockbiter, etc.)."],
                        order = 8,
                        get = function() return self.db.showWeapon ~= false end,
                        set = function(_, val)
                            self.db.showWeapon = val
                            self:UpdateBarLayout()
                        end,
                    },
                },
            },
            colors = {
                type = "group",
                name = L["Colors"],
                order = 4,
                inline = true,
                disabled = function() return not self.db.enabled end,
                args = {
                    borderColor = {
                        type = "color",
                        name = L["Border Color"],
                        order = 1,
                        hasAlpha = true,
                        get = function()
                            local c = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.borderColor = { r = r, g = g, b = b, a = a }
                            self:OnTick()
                        end,
                    },
                    activeBorderColor = {
                        type = "color",
                        name = L["Active Totem Border Color"],
                        order = 2,
                        hasAlpha = true,
                        get = function()
                            local c = self.db.activeBorderColor or { r = 0.2, g = 0.8, b = 0.2, a = 1.0 }
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.activeBorderColor = { r = r, g = g, b = b, a = a }
                            self:OnTick()
                        end,
                    },
                    selectionBorderColor = {
                        type = "color",
                        name = L["Selected Section Highlight Color"],
                        order = 3,
                        hasAlpha = true,
                        get = function()
                            local c = self.db.selectionBorderColor or { r = 1.0, g = 0.85, b = 0.0, a = 1.0 }
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.selectionBorderColor = { r = r, g = g, b = b, a = a }
                            self:UpdateAllSlotBorders()
                        end,
                    },
                },
            },
            totemFilter = {
                type = "group",
                name = L["Totem Selection"],
                desc = L["Enable or deselect totems for this element."],
                order = 5,
                inline = true,
                disabled = function() return not self.db.enabled end,
                args = {},
            },
            keybindings = {
                type = "group",
                name = L["Keybindings & Usage"],
                order = 6,
                inline = true,
                args = {
                    info = {
                        type = "description",
                        name = L["Configure keybindings in WoW's native Keybinding menu under the 'RoithiUI Totem Bar' category.\n\nSupported Keybind Actions:\n- Cycle Category: Switch between Earth, Fire, Water, Air, Shield, and Weapon\n- Cycle Spell: Cycle through known spells in the active category\n- Cast Current: Cast the selected spell of the active category\n- Cast Earth / Fire / Water / Air / Shield / Weapon: Dedicated binds for each slot\n- Unsummon All Totems: Calls Totemic Recall or destroys all active totems\n- Unsummon Element: Dismisses specific active totem element\n\nRight-Click any slot button out of combat to open the spell flyout selector."],
                        order = 1,
                    },
                },
            },
        },
    }

    local catOrder = 1
    for _, catKey in ipairs(self.categories or { "earth", "fire", "water", "air", "shield", "weapon" }) do
        local catName = L[catKey:gsub("^%l", string.upper)] or catKey
        local spellList = self.spellsDatabase and self.spellsDatabase[catKey] or {}
        if #spellList > 0 then
            local catGroup = {
                type = "group",
                name = catName,
                order = catOrder,
                inline = true,
                args = {},
            }
            catOrder = catOrder + 1

            for sIdx, entry in ipairs(spellList) do
                local spellId = entry.id
                local spellName = entry.name
                catGroup.args["spell_" .. spellId] = {
                    type = "toggle",
                    name = spellName or tostring(spellId),
                    order = sIdx,
                    width = "normal",
                    get = function()
                        if not self.db.disabledSpells then return true end
                        return self.db.disabledSpells[spellId] ~= true
                    end,
                    set = function(_, val)
                        if not self.db.disabledSpells then self.db.disabledSpells = {} end
                        self.db.disabledSpells[spellId] = not val
                        self:UpdateAvailableSpells()
                        self:UpdateAllButtonAttributes()
                        if self.UpdateCurrentActionButton then
                            self:UpdateCurrentActionButton()
                        end
                        self:OnTick()
                    end,
                }
            end
            options.args.totemFilter.args[catKey] = catGroup
        end
    end

    return options
end
