local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local CDM = RoithiUI:GetModule("CooldownManager")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

local function CreateIconViewerGroup(viewerKey, viewerName, defaultSize, orderNum)
    return {
        type = "group",
        name = viewerName,
        order = orderNum,
        inline = true,
        args = {
            size = {
                type = "range",
                name = L["Icon Size"] or "Icon Size",
                order = 1,
                min = 20,
                max = 80,
                step = 2,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.iconSize or defaultSize
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].iconSize = val
                    CDM:StyleAllActiveItems()
                    CDM:RefreshAllViewerLayouts()
                end,
            },
            spacing = {
                type = "range",
                name = L["Icon Spacing / Padding"] or "Icon Spacing / Padding",
                order = 2,
                min = 0,
                max = 20,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.spacing or 4
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].spacing = val
                    CDM:RefreshAllViewerLayouts()
                end,
            },
            font = {
                type = "select",
                dialogControl = "LSM30_Font",
                name = L["Font Override"] or "Font Override",
                order = 3,
                values = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font or {},
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.font or CDM.db.font or "Friz Quadrata TT"
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].font = val
                    CDM:StyleAllActiveItems()
                end,
            },
            cooldownFontSize = {
                type = "range",
                name = L["Cooldown Font Size"] or "Cooldown Font Size",
                desc = L["Font size for cooldown countdown text (set to 0 to hide)."] or "Font size for cooldown countdown text.",
                order = 4,
                min = 0,
                max = 36,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.cooldownFontSize or CDM.db.cooldownFontSize or 14
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].cooldownFontSize = val
                    CDM:StyleAllActiveItems()
                end,
            },
            cooldownOffsetX = {
                type = "range",
                name = L["Cooldown Offset X"] or "Cooldown Offset X",
                order = 5,
                min = -30,
                max = 30,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.cooldownOffsetX or CDM.db.cooldownOffsetX or 0
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].cooldownOffsetX = val
                    CDM:StyleAllActiveItems()
                end,
            },
            cooldownOffsetY = {
                type = "range",
                name = L["Cooldown Offset Y"] or "Cooldown Offset Y",
                order = 6,
                min = -30,
                max = 30,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.cooldownOffsetY or CDM.db.cooldownOffsetY or 0
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].cooldownOffsetY = val
                    CDM:StyleAllActiveItems()
                end,
            },
            stackSize = {
                type = "range",
                name = L["Stack Font Size"] or "Stack Font Size",
                order = 7,
                min = 8,
                max = 24,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.stackFontSize or CDM.db.stackFontSize or 11
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].stackFontSize = val
                    CDM:StyleAllActiveItems()
                end,
            },
            stackAnchor = {
                type = "select",
                name = L["Stack Anchor"] or "Stack Anchor",
                order = 8,
                values = {
                    ["TOPLEFT"] = "TOPLEFT",
                    ["TOP"] = "TOP",
                    ["TOPRIGHT"] = "TOPRIGHT",
                    ["LEFT"] = "LEFT",
                    ["CENTER"] = "CENTER",
                    ["RIGHT"] = "RIGHT",
                    ["BOTTOMLEFT"] = "BOTTOMLEFT",
                    ["BOTTOM"] = "BOTTOM",
                    ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                },
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.stackAnchor or CDM.db.stackAnchor or "BOTTOMRIGHT"
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].stackAnchor = val
                    CDM:StyleAllActiveItems()
                end,
            },
            stackOffsetX = {
                type = "range",
                name = L["Stack Offset X"] or "Stack Offset X",
                order = 9,
                min = -30,
                max = 30,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.stackOffsetX or CDM.db.stackOffsetX or -2
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].stackOffsetX = val
                    CDM:StyleAllActiveItems()
                end,
            },
            stackOffsetY = {
                type = "range",
                name = L["Stack Offset Y"] or "Stack Offset Y",
                order = 10,
                min = -30,
                max = 30,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.stackOffsetY or CDM.db.stackOffsetY or 2
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].stackOffsetY = val
                    CDM:StyleAllActiveItems()
                end,
            },
        },
    }
end

function CDM:GetOptions()
    return {
        type = "group",
        name = L["Cooldown Manager"] or "Cooldown Manager",
        order = 95,
        args = {
            openBlizzardSettings = {
                type = "execute",
                name = L["Open Cooldown Manager / Bar Creator"] or "Open Cooldown Manager / Bar Creator",
                desc = L["Opens Blizzard's native Cooldown Viewer Settings where you can create new bars, assign spells, and organize categories."] or "Opens Blizzard's native Cooldown Viewer Settings.",
                order = 0.5,
                width = "double",
                func = function()
                    self:OpenBlizzardSettings()
                end,
            },
            general = {
                type = "group",
                name = L["General Settings"] or "General Settings",
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable"] or "Enable",
                        order = 1,
                        get = function() return self.db.enabled ~= false end,
                        set = function(_, val)
                            self.db.enabled = val
                            if val then self:Enable() else self:Disable() end
                        end,
                    },
                    cropIcons = {
                        type = "toggle",
                        name = L["Crop Icons (Square)"] or "Crop Icons (Square)",
                        desc = L["Crops icon textures for a clean, modern square look."] or "Crops icon textures for a modern square look.",
                        order = 2,
                        get = function() return self.db.cropIcons ~= false end,
                        set = function(_, val)
                            self.db.cropIcons = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    borderSize = {
                        type = "range",
                        name = L["Border Size"] or "Border Size",
                        order = 3,
                        min = 1,
                        max = 4,
                        step = 1,
                        get = function() return self.db.borderSize or 1 end,
                        set = function(_, val)
                            self.db.borderSize = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    borderColor = {
                        type = "color",
                        name = L["Border Color"] or "Border Color",
                        order = 4,
                        hasAlpha = true,
                        get = function()
                            local c = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.borderColor = { r = r, g = g, b = b, a = a }
                            self:StyleAllActiveItems()
                        end,
                    },
                    font = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = L["Font"] or "Font",
                        order = 5,
                        values = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font or {},
                        get = function() return self.db.font or "Friz Quadrata TT" end,
                        set = function(_, val)
                            self.db.font = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    centerIncompleteRows = {
                        type = "toggle",
                        name = L["Center Incomplete Rows"] or "Center Incomplete Rows",
                        desc = L["Horizontally center rows in cooldown viewers that are not completely full."] or "Horizontally center rows in cooldown viewers that are not completely full.",
                        order = 6,
                        get = function() return self.db.centerIncompleteRows ~= false end,
                        set = function(_, val)
                            self.db.centerIncompleteRows = val
                            self:RefreshAllViewerLayouts()
                        end,
                    },
                },
            },
            cooldownTextSettings = {
                type = "group",
                name = L["Cooldown Text (Global Defaults)"] or "Cooldown Text (Global Defaults)",
                order = 2,
                inline = true,
                args = {
                    cooldownFontSize = {
                        type = "range",
                        name = L["Font Size"] or "Font Size",
                        desc = L["Font size for cooldown countdown text (set to 0 to hide)."] or "Font size for cooldown countdown text.",
                        order = 1,
                        min = 0,
                        max = 36,
                        step = 1,
                        get = function() return self.db.cooldownFontSize or 14 end,
                        set = function(_, val)
                            self.db.cooldownFontSize = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    cooldownFontOutline = {
                        type = "select",
                        name = L["Outline"] or "Outline",
                        order = 2,
                        values = {
                            ["NONE"] = "NONE",
                            ["OUTLINE"] = "OUTLINE",
                            ["THICKOUTLINE"] = "THICKOUTLINE",
                        },
                        get = function() return self.db.cooldownFontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.cooldownFontOutline = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    cooldownOffsetX = {
                        type = "range",
                        name = L["Offset X"] or "Offset X",
                        order = 3,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.cooldownOffsetX or 0 end,
                        set = function(_, val)
                            self.db.cooldownOffsetX = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    cooldownOffsetY = {
                        type = "range",
                        name = L["Offset Y"] or "Offset Y",
                        order = 4,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.cooldownOffsetY or 0 end,
                        set = function(_, val)
                            self.db.cooldownOffsetY = val
                            self:StyleAllActiveItems()
                        end,
                    },
                },
            },
            stackSettings = {
                type = "group",
                name = L["Charges & Stack Counter (Global Defaults)"] or "Charges & Stack Counter",
                order = 3,
                inline = true,
                args = {
                    stackAnchor = {
                        type = "select",
                        name = L["Anchor Point"] or "Anchor Point",
                        order = 1,
                        values = {
                            ["TOPLEFT"] = "TOPLEFT",
                            ["TOP"] = "TOP",
                            ["TOPRIGHT"] = "TOPRIGHT",
                            ["LEFT"] = "LEFT",
                            ["CENTER"] = "CENTER",
                            ["RIGHT"] = "RIGHT",
                            ["BOTTOMLEFT"] = "BOTTOMLEFT",
                            ["BOTTOM"] = "BOTTOM",
                            ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                        },
                        get = function() return self.db.stackAnchor or "BOTTOMRIGHT" end,
                        set = function(_, val)
                            self.db.stackAnchor = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    stackFontSize = {
                        type = "range",
                        name = L["Font Size"] or "Font Size",
                        order = 2,
                        min = 8,
                        max = 24,
                        step = 1,
                        get = function() return self.db.stackFontSize or 11 end,
                        set = function(_, val)
                            self.db.stackFontSize = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    stackFontOutline = {
                        type = "select",
                        name = L["Outline"] or "Outline",
                        order = 3,
                        values = {
                            ["NONE"] = "NONE",
                            ["OUTLINE"] = "OUTLINE",
                            ["THICKOUTLINE"] = "THICKOUTLINE",
                        },
                        get = function() return self.db.stackFontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.stackFontOutline = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    stackOffsetX = {
                        type = "range",
                        name = L["Offset X"] or "Offset X",
                        order = 4,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.stackOffsetX or -2 end,
                        set = function(_, val)
                            self.db.stackOffsetX = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    stackOffsetY = {
                        type = "range",
                        name = L["Offset Y"] or "Offset Y",
                        order = 5,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.stackOffsetY or 2 end,
                        set = function(_, val)
                            self.db.stackOffsetY = val
                            self:StyleAllActiveItems()
                        end,
                    },
                },
            },
            viewers = {
                type = "group",
                name = L["Viewers"] or "Viewers",
                order = 4,
                inline = true,
                args = {
                    essentialGroup = CreateIconViewerGroup("Essential", L["Essential Cooldowns"] or "Essential Cooldowns", 50, 1),
                    utilityGroup = CreateIconViewerGroup("Utility", L["Utility Cooldowns"] or "Utility Cooldowns", 32, 2),
                    buffIconGroup = CreateIconViewerGroup("BuffIcon", L["Buff Icons"] or "Buff Icons", 40, 3),
                    buffBarGroup = {
                        type = "group",
                        name = L["Buff Bars"] or "Buff Bars",
                        order = 4,
                        inline = true,
                        args = {
                            barWidth = {
                                type = "range",
                                name = L["Bar Width"] or "Bar Width",
                                order = 1,
                                min = 100,
                                max = 400,
                                step = 5,
                                get = function()
                                    return self.db.viewers and self.db.viewers.BuffBar and self.db.viewers.BuffBar.barWidth or 220
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.barWidth = val
                                    self:RefreshAllViewerLayouts()
                                end,
                            },
                            barHeight = {
                                type = "range",
                                name = L["Bar Height"] or "Bar Height",
                                order = 2,
                                min = 14,
                                max = 50,
                                step = 1,
                                get = function()
                                    return self.db.viewers and self.db.viewers.BuffBar and self.db.viewers.BuffBar.barHeight or 24
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.barHeight = val
                                    self:RefreshAllViewerLayouts()
                                end,
                            },
                            spacing = {
                                type = "range",
                                name = L["Bar Spacing"] or "Bar Spacing",
                                order = 3,
                                min = 0,
                                max = 20,
                                step = 1,
                                get = function()
                                    return self.db.viewers and self.db.viewers.BuffBar and self.db.viewers.BuffBar.spacing or 4
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.spacing = val
                                    self:RefreshAllViewerLayouts()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
end
