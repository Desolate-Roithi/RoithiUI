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
        hidden = function() return (CDM.selectedOptionsBar or "Essential") ~= viewerKey end,
        args = {
            overrideGlobal = {
                type = "toggle",
                name = L["Override Global Settings"] or "Override Global Settings",
                desc = L["Enable to configure unique typography, anchors, and offsets for this bar instead of inheriting from Global Defaults."] or "Enable to configure unique settings for this bar.",
                order = 0.5,
                width = "double",
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.overrideGlobal == true
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].overrideGlobal = val
                    CDM:StyleAllActiveItems()
                    CDM:RefreshAllViewerLayouts()
                end,
            },
            resetToGlobal = {
                type = "execute",
                name = L["Reset to Global Defaults"] or "Reset to Global Defaults",
                desc = L["Restores this bar to inherit directly from Global Defaults."] or "Restores this bar to global defaults.",
                order = 0.6,
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                func = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v then
                        v.overrideGlobal = false
                        v.cooldownFontSize = CDM.db.cooldownFontSize
                        v.cooldownFontOutline = CDM.db.cooldownFontOutline
                        v.cooldownAnchor = CDM.db.cooldownAnchor
                        v.cooldownOffsetX = CDM.db.cooldownOffsetX
                        v.cooldownOffsetY = CDM.db.cooldownOffsetY
                        v.stackFontSize = CDM.db.stackFontSize
                        v.stackFontOutline = CDM.db.stackFontOutline
                        v.stackAnchor = CDM.db.stackAnchor
                        v.stackOffsetX = CDM.db.stackOffsetX
                        v.stackOffsetY = CDM.db.stackOffsetY
                        v.font = CDM.db.font
                        CDM:StyleAllActiveItems()
                        CDM:RefreshAllViewerLayouts()
                    end
                end,
            },
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
            align = {
                type = "select",
                name = L["Alignment / Growth"] or "Alignment / Growth",
                order = 2.5,
                values = {
                    ["CENTER"] = L["Centered (Grow Symmetrically)"] or "Centered (Grow Symmetrically)",
                    ["LEFT"] = L["Left-Aligned (Grow Right)"] or "Left-Aligned (Grow Right)",
                    ["RIGHT"] = L["Right-Aligned (Grow Left)"] or "Right-Aligned (Grow Left)",
                },
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return v and v.align or "CENTER"
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].align = val
                    CDM:RefreshAllViewerLayouts()
                end,
            },
            font = {
                type = "select",
                dialogControl = "LSM30_Font",
                name = L["Font Override"] or "Font Override",
                order = 3,
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                values = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font or {},
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v and v.overrideGlobal then return v.font or CDM.db.font or "Friz Quadrata TT" end
                    return CDM.db.font or "Friz Quadrata TT"
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
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                min = 0,
                max = 36,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v and v.overrideGlobal then return v.cooldownFontSize or CDM.db.cooldownFontSize or 14 end
                    return CDM.db.cooldownFontSize or 14
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].cooldownFontSize = val
                    CDM:StyleAllActiveItems()
                end,
            },
            cooldownAnchor = {
                type = "select",
                name = L["Cooldown Anchor"] or "Cooldown Anchor",
                order = 4.5,
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                values = (ns.Utils and ns.Utils.GetAnchorDropdownValues) and ns.Utils.GetAnchorDropdownValues() or {},
                sorting = (ns.Utils and ns.Utils.ANCHOR_POINTS) or nil,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v and v.overrideGlobal then return v.cooldownAnchor or v.timerAnchor or CDM.db.cooldownAnchor or "CENTER" end
                    return CDM.db.cooldownAnchor or "CENTER"
                end,
                set = function(_, val)
                    if not CDM.db.viewers then CDM.db.viewers = {} end
                    if not CDM.db.viewers[viewerKey] then CDM.db.viewers[viewerKey] = {} end
                    CDM.db.viewers[viewerKey].cooldownAnchor = val
                    CDM.db.viewers[viewerKey].timerAnchor = val
                    CDM:StyleAllActiveItems()
                end,
            },
            cooldownOffsetX = {
                type = "range",
                name = L["Cooldown Offset X"] or "Cooldown Offset X",
                order = 5,
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                min = -30,
                max = 30,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v and v.overrideGlobal then return v.cooldownOffsetX or CDM.db.cooldownOffsetX or 0 end
                    return CDM.db.cooldownOffsetX or 0
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
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                min = -30,
                max = 30,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v and v.overrideGlobal then return v.cooldownOffsetY or CDM.db.cooldownOffsetY or 0 end
                    return CDM.db.cooldownOffsetY or 0
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
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                min = 8,
                max = 24,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v and v.overrideGlobal then return v.stackFontSize or CDM.db.stackFontSize or 11 end
                    return CDM.db.stackFontSize or 11
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
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                values = (ns.Utils and ns.Utils.GetAnchorDropdownValues) and ns.Utils.GetAnchorDropdownValues() or {},
                sorting = (ns.Utils and ns.Utils.ANCHOR_POINTS) or nil,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v and v.overrideGlobal then return v.stackAnchor or CDM.db.stackAnchor or "BOTTOMRIGHT" end
                    return CDM.db.stackAnchor or "BOTTOMRIGHT"
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
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                min = -30,
                max = 30,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v and v.overrideGlobal then return v.stackOffsetX or CDM.db.stackOffsetX or -2 end
                    return CDM.db.stackOffsetX or -2
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
                disabled = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    return not (v and v.overrideGlobal)
                end,
                min = -30,
                max = 30,
                step = 1,
                get = function()
                    local v = CDM.db.viewers and CDM.db.viewers[viewerKey]
                    if v and v.overrideGlobal then return v.stackOffsetY or CDM.db.stackOffsetY or 2 end
                    return CDM.db.stackOffsetY or 2
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
                    local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
                    if ACD then ACD:Close("RoithiUI") end
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
                    cooldownAnchor = {
                        type = "select",
                        name = L["Anchor Point"] or "Anchor Point",
                        order = 2.5,
                        values = (ns.Utils and ns.Utils.GetAnchorDropdownValues) and ns.Utils.GetAnchorDropdownValues() or {},
                        sorting = (ns.Utils and ns.Utils.ANCHOR_POINTS) or nil,
                        get = function() return self.db.cooldownAnchor or "CENTER" end,
                        set = function(_, val)
                            self.db.cooldownAnchor = val
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
                        values = (ns.Utils and ns.Utils.GetAnchorDropdownValues) and ns.Utils.GetAnchorDropdownValues() or {},
                        sorting = (ns.Utils and ns.Utils.ANCHOR_POINTS) or nil,
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
                    applyGlobalToAll = {
                        type = "execute",
                        name = L["Apply Global Settings to All Bars"] or "Apply Global Settings to All Bars",
                        desc = L["Applies these global typography, anchor, and offset settings to all viewers and custom bars, resetting any individual overrides."] or "Applies global settings to all bars.",
                        order = 6,
                        width = "double",
                        func = function()
                            if self.db and self.db.viewers then
                                for _, v in pairs(self.db.viewers) do
                                    v.overrideGlobal = false
                                    v.cooldownFontSize = self.db.cooldownFontSize
                                    v.cooldownFontOutline = self.db.cooldownFontOutline
                                    v.cooldownAnchor = self.db.cooldownAnchor
                                    v.cooldownOffsetX = self.db.cooldownOffsetX
                                    v.cooldownOffsetY = self.db.cooldownOffsetY
                                    v.stackFontSize = self.db.stackFontSize
                                    v.stackFontOutline = self.db.stackFontOutline
                                    v.stackAnchor = self.db.stackAnchor
                                    v.stackOffsetX = self.db.stackOffsetX
                                    v.stackOffsetY = self.db.stackOffsetY
                                    v.font = self.db.font
                                end
                            end
                            if self.GetCustomBars then
                                local list = self:GetCustomBars()
                                for _, c in ipairs(list) do
                                    c.overrideGlobal = false
                                    c.cooldownFontSize = self.db.cooldownFontSize
                                    c.timerAnchor = self.db.cooldownAnchor
                                    c.timerOffsetX = self.db.cooldownOffsetX
                                    c.timerOffsetY = self.db.cooldownOffsetY
                                    c.stackFontSize = self.db.stackFontSize
                                    c.stackAnchor = self.db.stackAnchor
                                    c.stackOffsetX = self.db.stackOffsetX
                                    c.stackOffsetY = self.db.stackOffsetY
                                end
                                if self.InitializeAllCustomBars then self:InitializeAllCustomBars() end
                            end
                            self:StyleAllActiveItems()
                            self:RefreshAllViewerLayouts()
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
                    selectedBar = {
                        type = "select",
                        name = L["Select Bar to Configure"] or "Select Bar to Configure",
                        desc = L["Choose which cooldown bar or viewer to adjust."] or "Choose which cooldown bar or viewer to adjust.",
                        order = 0.1,
                        values = {
                            ["Essential"] = L["Essential Cooldowns"] or "Essential Cooldowns",
                            ["Utility"] = L["Utility Cooldowns"] or "Utility Cooldowns",
                            ["BuffIcon"] = L["Buff Icons"] or "Buff Icons",
                            ["BuffBar"] = L["Buff Bars"] or "Buff Bars",
                        },
                        get = function() return CDM.selectedOptionsBar or "Essential" end,
                        set = function(_, val) CDM.selectedOptionsBar = val end,
                    },
                    essentialGroup = CreateIconViewerGroup("Essential", L["Essential Cooldowns"] or "Essential Cooldowns", 50, 1),
                    utilityGroup = CreateIconViewerGroup("Utility", L["Utility Cooldowns"] or "Utility Cooldowns", 32, 2),
                    buffIconGroup = CreateIconViewerGroup("BuffIcon", L["Buff Icons"] or "Buff Icons", 40, 3),
                    buffBarGroup = {
                        type = "group",
                        name = L["Buff Bars"] or "Buff Bars",
                        order = 4,
                        inline = true,
                        hidden = function() return (CDM.selectedOptionsBar or "Essential") ~= "BuffBar" end,
                        args = {
                            overrideGlobal = {
                                type = "toggle",
                                name = L["Override Global Settings"] or "Override Global Settings",
                                desc = L["Enable to configure unique typography, anchors, and offsets for this bar instead of inheriting from Global Defaults."] or "Enable to configure unique settings for this bar.",
                                order = 0.5,
                                width = "double",
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.overrideGlobal == true
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.overrideGlobal = val
                                    self:StyleAllActiveItems()
                                    self:RefreshAllViewerLayouts()
                                end,
                            },
                            resetToGlobal = {
                                type = "execute",
                                name = L["Reset to Global Defaults"] or "Reset to Global Defaults",
                                desc = L["Restores this bar to inherit directly from Global Defaults."] or "Restores this bar to global defaults.",
                                order = 0.6,
                                disabled = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return not (v and v.overrideGlobal)
                                end,
                                func = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    if v then
                                        v.overrideGlobal = false
                                        v.font = self.db.font
                                        self:StyleAllActiveItems()
                                        self:RefreshAllViewerLayouts()
                                    end
                                end,
                            },
                            growthDirection = {
                                type = "select",
                                name = L["Growth Direction"] or "Growth Direction",
                                order = 0.7,
                                values = {
                                    ["DOWN"] = L["Top to Bottom (Grow Down)"] or "Top to Bottom (Grow Down)",
                                    ["UP"] = L["Bottom to Top (Grow Up)"] or "Bottom to Top (Grow Up)",
                                },
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.growthDirection or "DOWN"
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.growthDirection = val
                                    self:RefreshAllViewerLayouts()
                                end,
                            },
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
                            font = {
                                type = "select",
                                dialogControl = "LSM30_Font",
                                name = L["Font Override"] or "Font Override",
                                order = 3.5,
                                disabled = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return not (v and v.overrideGlobal)
                                end,
                                values = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font or {},
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    if v and v.overrideGlobal then return v.font or self.db.font or "Friz Quadrata TT" end
                                    return self.db.font or "Friz Quadrata TT"
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.font = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            squareCorners = {
                                type = "toggle",
                                name = L["Modern Square Corners"] or "Modern Square Corners",
                                desc = L["Removes Blizzard rounded pips and caps for clean modern square statusbars."] or "Removes rounded pips for square statusbars.",
                                order = 4,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.squareCorners ~= false
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.squareCorners = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            showName = {
                                type = "toggle",
                                name = L["Show Ability Name"] or "Show Ability Name",
                                order = 5,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.showName ~= false
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.showName = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            nameFontSize = {
                                type = "range",
                                name = L["Ability Name Font Size"] or "Ability Name Font Size",
                                order = 5.1,
                                min = 8,
                                max = 24,
                                step = 1,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.nameFontSize or 11
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.nameFontSize = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            nameOffsetX = {
                                type = "range",
                                name = L["Ability Name Offset X"] or "Ability Name Offset X",
                                order = 5.2,
                                min = -50,
                                max = 50,
                                step = 1,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.nameOffsetX or 5
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.nameOffsetX = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            nameOffsetY = {
                                type = "range",
                                name = L["Ability Name Offset Y"] or "Ability Name Offset Y",
                                order = 5.3,
                                min = -20,
                                max = 20,
                                step = 1,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.nameOffsetY or 0
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.nameOffsetY = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            namePosition = {
                                type = "select",
                                name = L["Ability Name Position"] or "Ability Name Position",
                                order = 5.4,
                                values = {
                                    ["LEFT"] = L["Left"] or "Left",
                                    ["CENTER"] = L["Center"] or "Center",
                                    ["RIGHT"] = L["Right"] or "Right",
                                },
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.namePosition or "LEFT"
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.namePosition = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            showTimer = {
                                type = "toggle",
                                name = L["Show Duration Timer"] or "Show Duration Timer",
                                order = 6,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.showTimer ~= false
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.showTimer = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            timerFontSize = {
                                type = "range",
                                name = L["Duration Timer Font Size"] or "Duration Timer Font Size",
                                order = 6.1,
                                disabled = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return not (v and v.overrideGlobal)
                                end,
                                min = 8,
                                max = 24,
                                step = 1,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    if v and v.overrideGlobal then return v.timerFontSize or self.db.cooldownFontSize or 11 end
                                    return self.db.cooldownFontSize or 11
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.timerFontSize = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            timerOffsetX = {
                                type = "range",
                                name = L["Duration Timer Offset X"] or "Duration Timer Offset X",
                                order = 6.2,
                                min = -50,
                                max = 50,
                                step = 1,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.timerOffsetX or -8
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.timerOffsetX = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            timerOffsetY = {
                                type = "range",
                                name = L["Duration Timer Offset Y"] or "Duration Timer Offset Y",
                                order = 6.3,
                                min = -20,
                                max = 20,
                                step = 1,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.timerOffsetY or 0
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.timerOffsetY = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            timerPosition = {
                                type = "select",
                                name = L["Timer Position"] or "Timer Position",
                                order = 7,
                                values = {
                                    ["LEFT"] = L["Left"] or "Left",
                                    ["CENTER"] = L["Center"] or "Center",
                                    ["RIGHT"] = L["Right"] or "Right",
                                },
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.timerPosition or "RIGHT"
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.timerPosition = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            showIcon = {
                                type = "toggle",
                                name = L["Show Icon"] or "Show Icon",
                                order = 8,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.showIcon ~= false
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.showIcon = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            iconMatchBarHeight = {
                                type = "toggle",
                                name = L["Icon Match Bar Height"] or "Icon Match Bar Height",
                                desc = L["Keep the icon width and height matched 1:1 with the statusbar height."] or "Keep icon matched to statusbar height.",
                                order = 9,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.iconMatchBarHeight ~= false
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.iconMatchBarHeight = val
                                    self:StyleAllActiveItems()
                                end,
                            },
                            iconSize = {
                                type = "range",
                                name = L["Icon Size"] or "Icon Size",
                                order = 9.5,
                                min = 14,
                                max = 60,
                                step = 1,
                                disabled = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.iconMatchBarHeight ~= false
                                end,
                                get = function()
                                    local v = self.db.viewers and self.db.viewers.BuffBar
                                    return v and v.iconSize or 24
                                end,
                                set = function(_, val)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.iconSize = val
                                    self.db.viewers.BuffBar.iconWidth = val
                                    self.db.viewers.BuffBar.iconHeight = val
                                    self:StyleAllActiveItems()
                                    self:RefreshAllViewerLayouts()
                                end,
                            },
                            barColor = {
                                type = "color",
                                name = L["Bar Color"] or "Bar Color",
                                hasAlpha = true,
                                order = 10,
                                get = function()
                                    local c = self.db.viewers and self.db.viewers.BuffBar and self.db.viewers.BuffBar.barColor
                                    if c then return c.r, c.g, c.b, c.a end
                                    return 0.2, 0.6, 1.0, 1.0
                                end,
                                set = function(_, r, g, b, a)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.barColor = { r = r, g = g, b = b, a = a }
                                    self:StyleAllActiveItems()
                                end,
                            },
                            barBgColor = {
                                type = "color",
                                name = L["Bar Background Color"] or "Bar Background Color",
                                hasAlpha = true,
                                order = 11,
                                get = function()
                                    local c = self.db.viewers and self.db.viewers.BuffBar and self.db.viewers.BuffBar.barBgColor
                                    if c then return c.r, c.g, c.b, c.a end
                                    return 0.1, 0.1, 0.1, 0.8
                                end,
                                set = function(_, r, g, b, a)
                                    if not self.db.viewers then self.db.viewers = {} end
                                    if not self.db.viewers.BuffBar then self.db.viewers.BuffBar = {} end
                                    self.db.viewers.BuffBar.barBgColor = { r = r, g = g, b = b, a = a }
                                    self:StyleAllActiveItems()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
end
