local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local MinimapMod = RoithiUI:GetModule('Minimap')
local L = LibStub('AceLocale-3.0'):GetLocale('RoithiUI')

function MinimapMod:GetOptions()
    local options = {
        type = "group",
        name = L["Minimap"],
        order = 80,
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                inline = true,
                args = {
                    shape = {
                        type = "select",
                        name = L["Minimap Shape"],
                        order = 1,
                        values = {
                            ["SQUARE"] = L["Square"],
                            ["ROUND"] = L["Round"],
                        },
                        get = function() return self.db.shape or "SQUARE" end,
                        set = function(_, val)
                            self.db.shape = val
                            self:UpdateMinimapShape()
                        end,
                    },
                    width = {
                        type = "range",
                        name = L["Minimap Width"],
                        order = 2,
                        min = 100,
                        max = 400,
                        step = 5,
                        get = function() return self.db.width or self.db.size or 200 end,
                        set = function(_, val)
                            self.db.width = val
                            self:UpdateMinimapSize()
                        end,
                    },
                    height = {
                        type = "range",
                        name = L["Minimap Height"],
                        order = 3,
                        min = 100,
                        max = 400,
                        step = 5,
                        get = function() return self.db.height or self.db.size or 200 end,
                        set = function(_, val)
                            self.db.height = val
                            self:UpdateMinimapSize()
                        end,
                    },
                    scale = {
                        type = "range",
                        name = L["Minimap Scale"],
                        order = 4,
                        min = 0.5,
                        max = 2.0,
                        step = 0.05,
                        get = function() return self.db.scale or 1.0 end,
                        set = function(_, val)
                            self.db.scale = val
                            self:UpdateMinimapSize()
                        end,
                    },
                    rotateMinimap = {
                        type = "toggle",
                        name = L["Rotate Minimap"] or "Rotate Minimap",
                        desc = L["Rotate the minimap with player facing instead of keeping north up."] or "Rotate the minimap with player facing instead of keeping north up.",
                        order = 4.5,
                        get = function() return self:IsRotateMinimap() end,
                        set = function(_, val)
                            self:SetRotateMinimap(val)
                        end,
                    },
                    borderSize = {
                        type = "range",
                        name = L["Minimap Border Size"],
                        order = 5,
                        min = 1,
                        max = 10,
                        step = 1,
                        get = function() return self.db.borderSize or 1 end,
                        set = function(_, val)
                            self.db.borderSize = val
                            self:UpdateMinimapBorder()
                        end,
                        disabled = function() return self.db.shape ~= "SQUARE" end,
                    },
                    borderColor = {
                        type = "color",
                        name = L["Minimap Border Color"],
                        order = 6,
                        hasAlpha = true,
                        get = function()
                            local c = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.borderColor = { r = r, g = g, b = b, a = a }
                            self:UpdateMinimapBorder()
                        end,
                        disabled = function() return self.db.shape ~= "SQUARE" end,
                    },
                },
            },
            infoBoxes = {
                type = "group",
                name = L["Minimap Info Boxes"],
                order = 2,
                inline = true,
                args = {
                    showZoneText = {
                        type = "toggle",
                        name = L["Show Zone Text"],
                        order = 1,
                        get = function() return self.db.showZoneText end,
                        set = function(_, val)
                            self.db.showZoneText = val
                            self:UpdateZoneTextVisibility()
                        end,
                    },
                    showCalendar = {
                        type = "toggle",
                        name = L["Show Calendar"],
                        order = 2,
                        get = function() return self.db.showCalendar end,
                        set = function(_, val)
                            self.db.showCalendar = val
                            self:UpdateCalendarVisibility()
                        end,
                    },
                    showZoom = {
                        type = "toggle",
                        name = L["Show Zoom Buttons"],
                        order = 3,
                        get = function() return self.db.showZoom end,
                        set = function(_, val)
                            self.db.showZoom = val
                            self:UpdateZoomVisibility()
                        end,
                    },
                    showCoords = {
                        type = "toggle",
                        name = L["Show Coordinates"],
                        desc = L["Toggle player map coordinates on the minimap."],
                        order = 4,
                        get = function() return self.db.showCoords ~= false end,
                        set = function(_, val)
                            self.db.showCoords = val
                            self:UpdateCoordsVisibility()
                        end,
                    },
                    showDifficulty = {
                        type = "toggle",
                        name = L["Show Instance Difficulty"] or "Show Instance Difficulty",
                        order = 5,
                        get = function() return self.db.showDifficulty ~= false end,
                        set = function(_, val)
                            self.db.showDifficulty = val
                            self:UpdateDifficultyVisibility()
                        end,
                    },
                },
            },
            addonBar = self.GetAddonBarOptions and self:GetAddonBarOptions() or nil,
            dataTextBar = {
                type = "group",
                name = L["Minimap Data Text"],
                order = 4,
                args = {
                    showDataTextBar = {
                        type = "toggle",
                        name = L["Show Data Text Bar"],
                        order = 1,
                        get = function() return self.db.showDataTextBar end,
                        set = function(_, val)
                            self.db.showDataTextBar = val
                            self:UpdateDataTextBarVisibility()
                        end,
                    },
                    dataTextPosition = {
                        type = "select",
                        name = L["Data Text Position"],
                        order = 2,
                        values = {
                            ["INSIDE"] = L["Inside Minimap"],
                            ["OUTSIDE"] = L["Outside Minimap"],
                        },
                        get = function() return self.db.dataTextPosition or "OUTSIDE" end,
                        set = function(_, val)
                            self.db.dataTextPosition = val
                            self:UpdateDataTextBarVisibility()
                        end,
                        disabled = function() return not self.db.showDataTextBar end,
                    },
                    dataTextTimeFormat = {
                        type = "select",
                        name = L["Time Format"],
                        order = 2.5,
                        values = {
                            ["12H"] = L["12-hour (AM/PM)"],
                            ["24H"] = L["24-hour"],
                        },
                        get = function() return self.db.dataTextTimeFormat or "24H" end,
                        set = function(_, val)
                            self.db.dataTextTimeFormat = val
                            self:UpdateDataTextBarVisibility()
                        end,
                        disabled = function() return not self.db.showDataTextBar end,
                    },
                    dataTextTimeType = {
                        type = "select",
                        name = L["Time Source"],
                        order = 2.6,
                        values = {
                            ["LOCAL"] = L["Local Time"],
                            ["REALM"] = L["Realm Time"],
                        },
                        get = function() return self.db.dataTextTimeType or "LOCAL" end,
                        set = function(_, val)
                            self.db.dataTextTimeType = val
                            self:UpdateDataTextBarVisibility()
                        end,
                        disabled = function() return not self.db.showDataTextBar end,
                    },
                    dataTextBgColor = {
                        type = "color",
                        name = L["Bar Background Color"],
                        order = 3,
                        hasAlpha = true,
                        get = function()
                            local c = self.db.dataTextBgColor or { r = 0.05, g = 0.05, b = 0.05, a = 0.6 }
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.dataTextBgColor = { r = r, g = g, b = b, a = a }
                            self:UpdateDataTextBarVisibility()
                        end,
                        disabled = function() return not self.db.showDataTextBar end,
                    },
                    leftSec = {
                        type = "group",
                        name = L["Left Section"],
                        order = 10,
                        inline = true,
                        disabled = function() return not self.db.showDataTextBar end,
                        args = {
                            type = {
                                type = "select",
                                name = L["Data Text Type"],
                                order = 1,
                                values = {
                                    ["FPS_MS"] = L["FPS & Latency"],
                                    ["FPS"] = L["FPS"],
                                    ["Latency"] = L["Latency"],
                                    ["Time"] = L["Time"],
                                    ["Date"] = L["Date"],
                                    ["Social"] = L["Social (Friends & Guild)"],
                                    ["Friends"] = L["Friends"],
                                    ["Guild"] = L["Guild"],
                                    ["Coordinates"] = L["Coordinates"],
                                    ["Zone"] = L["Zone"],
                                    ["None"] = L["None"],
                                },
                                get = function() return self.db.dataTextLeftType or "None" end,
                                set = function(_, val)
                                    self.db.dataTextLeftType = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                            fontSize = {
                                type = "range",
                                name = L["Font Size"],
                                order = 2,
                                min = 8,
                                max = 20,
                                step = 1,
                                get = function() return self.db.dataTextLeftFontSize or 12 end,
                                set = function(_, val)
                                    self.db.dataTextLeftFontSize = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                            xOffset = {
                                type = "range",
                                name = L["X Offset"],
                                order = 3,
                                min = -100,
                                max = 100,
                                step = 1,
                                get = function() return self.db.dataTextLeftX or 0 end,
                                set = function(_, val)
                                    self.db.dataTextLeftX = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                            yOffset = {
                                type = "range",
                                name = L["Y Offset"],
                                order = 4,
                                min = -100,
                                max = 100,
                                step = 1,
                                get = function() return self.db.dataTextLeftY or 0 end,
                                set = function(_, val)
                                    self.db.dataTextLeftY = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                        },
                    },
                    middleSec = {
                        type = "group",
                        name = L["Middle Section"],
                        order = 11,
                        inline = true,
                        disabled = function() return not self.db.showDataTextBar end,
                        args = {
                            type = {
                                type = "select",
                                name = L["Data Text Type"],
                                order = 1,
                                values = {
                                    ["FPS_MS"] = L["FPS & Latency"],
                                    ["FPS"] = L["FPS"],
                                    ["Latency"] = L["Latency"],
                                    ["Time"] = L["Time"],
                                    ["Date"] = L["Date"],
                                    ["Social"] = L["Social (Friends & Guild)"],
                                    ["Friends"] = L["Friends"],
                                    ["Guild"] = L["Guild"],
                                    ["Coordinates"] = L["Coordinates"],
                                    ["Zone"] = L["Zone"],
                                    ["None"] = L["None"],
                                },
                                get = function() return self.db.dataTextMiddleType or "Time" end,
                                set = function(_, val)
                                    self.db.dataTextMiddleType = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                            fontSize = {
                                type = "range",
                                name = L["Font Size"],
                                order = 2,
                                min = 8,
                                max = 20,
                                step = 1,
                                get = function() return self.db.dataTextMiddleFontSize or 12 end,
                                set = function(_, val)
                                    self.db.dataTextMiddleFontSize = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                            xOffset = {
                                type = "range",
                                name = L["X Offset"],
                                order = 3,
                                min = -100,
                                max = 100,
                                step = 1,
                                get = function() return self.db.dataTextMiddleX or 0 end,
                                set = function(_, val)
                                    self.db.dataTextMiddleX = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                            yOffset = {
                                type = "range",
                                name = L["Y Offset"],
                                order = 4,
                                min = -100,
                                max = 100,
                                step = 1,
                                get = function() return self.db.dataTextMiddleY or 0 end,
                                set = function(_, val)
                                    self.db.dataTextMiddleY = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                        },
                    },
                    rightSec = {
                        type = "group",
                        name = L["Right Section"],
                        order = 12,
                        inline = true,
                        disabled = function() return not self.db.showDataTextBar end,
                        args = {
                            type = {
                                type = "select",
                                name = L["Data Text Type"],
                                order = 1,
                                values = {
                                    ["FPS_MS"] = L["FPS & Latency"],
                                    ["FPS"] = L["FPS"],
                                    ["Latency"] = L["Latency"],
                                    ["Time"] = L["Time"],
                                    ["Date"] = L["Date"],
                                    ["Social"] = L["Social (Friends & Guild)"],
                                    ["Friends"] = L["Friends"],
                                    ["Guild"] = L["Guild"],
                                    ["Coordinates"] = L["Coordinates"],
                                    ["Zone"] = L["Zone"],
                                    ["None"] = L["None"],
                                },
                                get = function() return self.db.dataTextRightType or "None" end,
                                set = function(_, val)
                                    self.db.dataTextRightType = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                            fontSize = {
                                type = "range",
                                name = L["Font Size"],
                                order = 2,
                                min = 8,
                                max = 20,
                                step = 1,
                                get = function() return self.db.dataTextRightFontSize or 12 end,
                                set = function(_, val)
                                    self.db.dataTextRightFontSize = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                            xOffset = {
                                type = "range",
                                name = L["X Offset"],
                                order = 3,
                                min = -100,
                                max = 100,
                                step = 1,
                                get = function() return self.db.dataTextRightX or 0 end,
                                set = function(_, val)
                                    self.db.dataTextRightX = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                            yOffset = {
                                type = "range",
                                name = L["Y Offset"],
                                order = 4,
                                min = -100,
                                max = 100,
                                step = 1,
                                get = function() return self.db.dataTextRightY or 0 end,
                                set = function(_, val)
                                    self.db.dataTextRightY = val
                                    self:UpdateDataTextBarVisibility()
                                end,
                            },
                        },
                    },
                },
            },
            buffsStyling = {
                type = "group",
                name = L["Default Auras Styling"] or "Default Auras Styling",
                order = 5,
                inline = true,
                args = {
                    displaceBuffs = {
                        type = "toggle",
                        name = L["Displace Auras when Addon Bar Expands"] or "Displace Auras when Addon Bar Expands",
                        order = 1,
                        get = function() return self.db.displaceBuffs ~= false end,
                        set = function(_, val)
                            self.db.displaceBuffs = val
                            if self.UpdateBuffFrameDisplacement then
                                self:UpdateBuffFrameDisplacement()
                            end
                        end,
                    },
                    buffFrameEnableSkinning = {
                        type = "toggle",
                        name = L["Enable Aura Skinning"] or "Enable Aura Skinning",
                        desc = L["Apply modern border and typography styling to default Buffs and Debuffs."] or "Apply modern styling to default Buffs and Debuffs.",
                        order = 2,
                        get = function() return self.db.buffFrameEnableSkinning ~= false end,
                        set = function(_, val)
                            self.db.buffFrameEnableSkinning = val
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                    },
                    buffFrameShowBorder = {
                        type = "toggle",
                        name = L["Show 1px Pixel Border"] or "Show 1px Pixel Border",
                        order = 3,
                        get = function() return self.db.buffFrameShowBorder == true end,
                        set = function(_, val)
                            self.db.buffFrameShowBorder = val
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                    },
                    buffFrameBorderSize = {
                        type = "range",
                        name = L["Border Size"] or "Border Size",
                        order = 4,
                        min = 1,
                        max = 5,
                        step = 1,
                        get = function() return self.db.buffFrameBorderSize or 1 end,
                        set = function(_, val)
                            self.db.buffFrameBorderSize = val
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                        disabled = function() return not self.db.buffFrameShowBorder end,
                    },
                    buffFrameBorderColor = {
                        type = "color",
                        name = L["Border Color"] or "Border Color",
                        order = 5,
                        hasAlpha = true,
                        get = function()
                            local c = self.db.buffFrameBorderColor or { r = 0, g = 0, b = 0, a = 1 }
                            return c.r or 0, c.g or 0, c.b or 0, c.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            self.db.buffFrameBorderColor = { r = r, g = g, b = b, a = a }
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                        disabled = function() return not self.db.buffFrameShowBorder end,
                    },
                    buffFrameZoomIcons = {
                        type = "toggle",
                        name = L["Zoom Icons (Square Look)"] or "Zoom Icons (Square Look)",
                        order = 6,
                        get = function() return self.db.buffFrameZoomIcons ~= false end,
                        set = function(_, val)
                            self.db.buffFrameZoomIcons = val
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                    },
                    buffFrameFont = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = L["Font"] or "Font",
                        order = 7,
                        values = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font,
                        get = function() return self.db.buffFrameFont or "Friz Quadrata TT" end,
                        set = function(_, val)
                            self.db.buffFrameFont = val
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                    },
                    buffFrameFontOutline = {
                        type = "select",
                        name = L["Font Outline"] or "Font Outline",
                        order = 8,
                        values = {
                            ["NONE"] = L["None"] or "None",
                            ["OUTLINE"] = L["Outline"] or "Outline",
                            ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
                            ["MONOCHROME"] = L["Monochrome"] or "Monochrome",
                        },
                        get = function() return self.db.buffFrameFontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.buffFrameFontOutline = val
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                    },
                    buffFrameShowShadow = {
                        type = "toggle",
                        name = L["Show Text Shadow"] or "Show Text Shadow",
                        desc = L["Toggle drop shadow behind duration and stack text."] or "Toggle drop shadow behind duration and stack text.",
                        order = 9,
                        get = function() return self.db.buffFrameShowShadow == true end,
                        set = function(_, val)
                            self.db.buffFrameShowShadow = val
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                    },
                    buffFrameDurationSize = {
                        type = "range",
                        name = L["Duration Font Size"] or "Duration Font Size",
                        order = 10,
                        min = 6,
                        max = 24,
                        step = 1,
                        get = function() return self.db.buffFrameDurationSize or 10 end,
                        set = function(_, val)
                            self.db.buffFrameDurationSize = val
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                    },
                    buffFrameCountSize = {
                        type = "range",
                        name = L["Stack Count Font Size"] or "Stack Count Font Size",
                        order = 11,
                        min = 6,
                        max = 24,
                        step = 1,
                        get = function() return self.db.buffFrameCountSize or 10 end,
                        set = function(_, val)
                            self.db.buffFrameCountSize = val
                            if self.RefreshBuffFrameStyling then self:RefreshBuffFrameStyling() end
                        end,
                    },
                },
            },
        },
    }

    if self.UpdateAddonBarOptions then
        self:UpdateAddonBarOptions()
    end
    return options
end

