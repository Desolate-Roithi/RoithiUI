local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:GetModule("Objectives")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function ObjectivesMod:GetOptions()
    return {
        type = "group",
        name = L["Objectives"] or "Objectives",
        order = 45,
        args = {
            general = {
                type = "group",
                name = L["General Settings"] or "General Settings",
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Objectives Skin"] or "Enable Objectives Skin",
                        desc = L["Enables modern restyling for the Blizzard Objective Tracker."] or "Enables modern restyling for the Blizzard Objective Tracker.",
                        order = 1,
                        get = function() return self.db.enabled ~= false end,
                        set = function(_, val)
                            self.db.enabled = val
                            if val then
                                self:OnEnable()
                            else
                                self:OnDisable()
                            end
                        end,
                    },
                    hideMasterHeader = {
                        type = "toggle",
                        name = L["Hide 'All Objectives' Header"] or "Hide 'All Objectives' Header",
                        desc = L["Hides the top master header to save vertical space."] or "Hides the top master header to save vertical space.",
                        order = 2,
                        get = function() return self.db.hideMasterHeader == true end,
                        set = function(_, val)
                            self.db.hideMasterHeader = val
                            self:ApplyMasterHeaderVisibility()
                        end,
                    },
                    showAccentDivider = {
                        type = "toggle",
                        name = L["Show Accent Divider"] or "Show Accent Divider",
                        desc = L["Displays a 1px colored accent line underneath section headers."] or "Displays a 1px colored accent line underneath section headers.",
                        order = 3,
                        get = function() return self.db.showAccentDivider ~= false end,
                        set = function(_, val)
                            self.db.showAccentDivider = val
                            self:SkinAllExisting()
                        end,
                    },
                    skinProgressBars = {
                        type = "toggle",
                        name = L["Skin Progress Bars"] or "Skin Progress Bars",
                        desc = L["Apply modern flat styling and 1px borders to quest progress bars."] or "Apply modern flat styling and 1px borders to quest progress bars.",
                        order = 4,
                        get = function() return self.db.skinProgressBars ~= false end,
                        set = function(_, val)
                            self.db.skinProgressBars = val
                            self:SkinAllExisting()
                        end,
                    },
                    dividerThickness = {
                        type = "range",
                        name = L["Divider Thickness"] or "Divider Thickness",
                        desc = L["Height in pixels of the colored accent line."] or "Height in pixels of the colored accent line.",
                        order = 5,
                        min = 1,
                        max = 4,
                        step = 1,
                        get = function() return self.db.dividerThickness or 1 end,
                        set = function(_, val)
                            self.db.dividerThickness = val
                            self:SkinAllExisting()
                        end,
                        disabled = function() return not self.db.showAccentDivider end,
                    },
                    scale = {
                        type = "range",
                        name = L["Scale"] or "Scale",
                        desc = L["Scale factor for the entire objective tracker."] or "Scale factor for the entire objective tracker.",
                        order = 6,
                        min = 0.5,
                        max = 1.5,
                        step = 0.05,
                        isPercent = true,
                        get = function() return self.db.scale or 1.0 end,
                        set = function(_, val)
                            self.db.scale = val
                            self:ApplyScaleAndHeight()
                        end,
                    },
                    maxHeight = {
                        type = "range",
                        name = L["Max Height"] or "Max Height",
                        desc = L["Maximum height in pixels for the tracker frame."] or "Maximum height in pixels for the tracker frame.",
                        order = 7,
                        min = 200,
                        max = 1400,
                        step = 25,
                        get = function() return self.db.maxHeight or 800 end,
                        set = function(_, val)
                            self.db.maxHeight = val
                            self:ApplyScaleAndHeight()
                        end,
                    },
                    autoCollapseCombat = {
                        type = "toggle",
                        name = L["Auto-Collapse in Combat"] or "Auto-Collapse in Combat",
                        desc = L["Automatically minimize the objective tracker upon entering combat."] or "Automatically minimize the objective tracker upon entering combat.",
                        order = 8,
                        get = function() return self.db.autoCollapseCombat == true end,
                        set = function(_, val)
                            self.db.autoCollapseCombat = val
                            self:CheckAutoCollapse()
                        end,
                    },
                    autoCollapseInstance = {
                        type = "toggle",
                        name = L["Auto-Collapse in Dungeons/Raids"] or "Auto-Collapse in Dungeons/Raids",
                        desc = L["Automatically minimize the objective tracker inside instances."] or "Automatically minimize the objective tracker inside instances.",
                        order = 9,
                        get = function() return self.db.autoCollapseInstance == true end,
                        set = function(_, val)
                            self.db.autoCollapseInstance = val
                            self:CheckAutoCollapse()
                        end,
                    },
                    attachedToMinimap = {
                        type = "toggle",
                        name = L["Attach to Minimap"] or "Attach to Minimap",
                        desc = L["Anchor the objective tracker directly below the minimap, matching its combined width."] or "Anchor the objective tracker directly below the minimap, matching its combined width.",
                        order = 9.5,
                        get = function() return self.db.attachedToMinimap ~= false end,
                        set = function(_, val)
                            self.db.attachedToMinimap = val
                            self:ApplyPosition()
                        end,
                    },
                    detachedWidth = {
                        type = "range",
                        name = L["Detached Width"] or "Detached Width",
                        desc = L["Width of the objective tracker when detached from the minimap."] or "Width of the objective tracker when detached from the minimap.",
                        order = 9.6,
                        min = 160,
                        max = 500,
                        step = 5,
                        disabled = function() return self.db.attachedToMinimap ~= false end,
                        get = function() return self.db.detachedWidth or self.db.width or 235 end,
                        set = function(_, val)
                            self.db.detachedWidth = val
                            self.db.width = val
                            self:ApplyPosition()
                        end,
                    },
                    resetPosition = {
                        type = "execute",
                        name = L["Reset Position"] or "Reset Position",
                        desc = L["Reset the objective tracker to its default screen position."] or "Reset the objective tracker to its default screen position.",
                        order = 10,
                        func = function()
                            self.db.attachedToMinimap = true
                            self.db.point = self.defaultSettings.point or "TOPRIGHT"
                            self.db.x = self.defaultSettings.x or -50
                            self.db.y = self.defaultSettings.y or -200
                            self:ApplyPosition()
                        end,
                    },
                    sortQuestsByZone = {
                        type = "toggle",
                        name = L["Sort Quests by Current Zone"] or "Sort Quests by Current Zone",
                        desc = L["Display quests located in your current zone at the top of the tracker."] or "Display quests located in your current zone at the top of the tracker.",
                        order = 11,
                        get = function() return self.db.sortQuestsByZone ~= false end,
                        set = function(_, val)
                            self.db.sortQuestsByZone = val
                            if _G.C_QuestLog and _G.C_QuestLog.SortQuestWatches then
                                _G.C_QuestLog.SortQuestWatches()
                            end
                            self:SkinAllExisting()
                        end,
                    },
                    showQuestLevel = {
                        type = "toggle",
                        name = L["Show Quest Level"] or "Show Quest Level",
                        desc = L["Display the quest level prefix [lvl] before the quest title."] or "Display the quest level prefix [lvl] before the quest title.",
                        order = 12,
                        get = function() return self.db.showQuestLevel ~= false end,
                        set = function(_, val)
                            self.db.showQuestLevel = val
                            self:SkinAllExisting()
                        end,
                    },
                    hoverObjectiveText = {
                        type = "toggle",
                        name = L["Objectives on Hover Only"] or "Objectives on Hover Only",
                        desc = L["Only show quest objective text and progress when hovering over the quest."] or "Only show quest objective text and progress when hovering over the quest.",
                        order = 13,
                        get = function() return self.db.hoverObjectiveText ~= false end,
                        set = function(_, val)
                            self.db.hoverObjectiveText = val
                            self:SkinAllExisting()
                        end,
                    },
                    hideQuestIcon = {
                        type = "toggle",
                        name = L["Hide Quest POI Icon"] or "Hide Quest POI Icon",
                        desc = L["Hide the round quest POI button / icon next to quest titles."] or "Hide the round quest POI button / icon next to quest titles.",
                        order = 14,
                        get = function() return self.db.hideQuestIcon ~= false end,
                        set = function(_, val)
                            self.db.hideQuestIcon = val
                            self:SkinAllExisting()
                        end,
                    },
                },
            },
            typography = {
                type = "group",
                name = L["Typography"] or "Typography",
                order = 2,
                inline = true,
                args = {
                    font = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = L["Font"] or "Font",
                        order = 1,
                        values = _G.AceGUIWidgetLSMlists and _G.AceGUIWidgetLSMlists.font or {},
                        get = function() return self.db.font or "Expressway" end,
                        set = function(_, val)
                            self.db.font = val
                            self:SkinAllExisting()
                        end,
                    },
                    headerFontSize = {
                        type = "range",
                        name = L["Header Font Size"] or "Header Font Size",
                        order = 2,
                        min = 9,
                        max = 20,
                        step = 1,
                        get = function() return self.db.headerFontSize or 13 end,
                        set = function(_, val)
                            self.db.headerFontSize = val
                            self:SkinAllExisting()
                        end,
                    },
                    titleFontSize = {
                        type = "range",
                        name = L["Title Font Size"] or "Title Font Size",
                        order = 2,
                        min = 9,
                        max = 20,
                        step = 1,
                        get = function() return self.db.titleFontSize or 12 end,
                        set = function(_, val)
                            self.db.titleFontSize = val
                            self:SkinAllExisting()
                        end,
                    },
                    objectiveFontSize = {
                        type = "range",
                        name = L["Objective Font Size"] or "Objective Font Size",
                        order = 3,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return self.db.objectiveFontSize or 11 end,
                        set = function(_, val)
                            self.db.objectiveFontSize = val
                            self:SkinAllExisting()
                        end,
                    },
                    fontOutline = {
                        type = "select",
                        name = L["Font Outline"] or "Font Outline",
                        order = 4,
                        values = {
                            ["NONE"] = L["None"] or "None",
                            ["OUTLINE"] = L["Outline"] or "Outline",
                            ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
                        },
                        get = function() return self.db.fontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.fontOutline = val
                            self:SkinAllExisting()
                        end,
                    },
                },
            },
            colors = {
                type = "group",
                name = L["Colors"] or "Colors",
                order = 3,
                inline = true,
                args = {
                    headerColor = {
                        type = "color",
                        name = L["Header Color"] or "Header Color",
                        hasAlpha = true,
                        order = 1,
                        get = function()
                            local c = self.db.headerColor or self.defaultSettings.headerColor
                            return c.r or 0.05, c.g or 0.82, c.b or 0.61, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.headerColor = { r = r, g = g, b = b, a = a }
                            self:SkinAllExisting()
                        end,
                    },
                    titleColor = {
                        type = "color",
                        name = L["Title Color"] or "Title Color",
                        hasAlpha = true,
                        order = 2,
                        get = function()
                            local c = self.db.titleColor or self.defaultSettings.titleColor
                            return c.r or 1.0, c.g or 0.85, c.b or 0.35, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.titleColor = { r = r, g = g, b = b, a = a }
                            self:SkinAllExisting()
                        end,
                    },
                    objectiveColor = {
                        type = "color",
                        name = L["Objective Color"] or "Objective Color",
                        hasAlpha = true,
                        order = 3,
                        get = function()
                            local c = self.db.objectiveColor or self.defaultSettings.objectiveColor
                            return c.r or 0.8, c.g or 0.8, c.b or 0.8, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.objectiveColor = { r = r, g = g, b = b, a = a }
                            self:SkinAllExisting()
                        end,
                    },
                },
            },
        },
    }
end

function ObjectivesMod:GetLEMFrameSettings()
    local LEM = LibStub("LibEditMode-1.0", true)
    if not LEM or not LEM.SettingType then return {} end

    return {
        {
            name = L["Attach to Minimap"] or "Attach to Minimap",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return self.db.attachedToMinimap ~= false end,
            set = function(_, val)
                self.db.attachedToMinimap = val
                self:ApplyPosition()
            end,
        },
        {
            name = L["Detached Width"] or "Detached Width",
            kind = LEM.SettingType.Slider,
            default = 235,
            minValue = 160,
            maxValue = 500,
            valueStep = 5,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return self.db.detachedWidth or self.db.width or 235 end,
            set = function(_, val)
                self.db.detachedWidth = val
                self.db.width = val
                self:ApplyPosition()
            end,
        },
        {
            name = L["Header Font Size"] or "Header Font Size",
            kind = LEM.SettingType.Slider,
            default = 13,
            minValue = 9,
            maxValue = 20,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return self.db.headerFontSize or 13 end,
            set = function(_, val)
                self.db.headerFontSize = val
                self:SkinAllExisting()
            end,
        },
        {
            name = L["Title Font Size"] or "Title Font Size",
            kind = LEM.SettingType.Slider,
            default = 12,
            minValue = 9,
            maxValue = 20,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return self.db.titleFontSize or 12 end,
            set = function(_, val)
                self.db.titleFontSize = val
                self:SkinAllExisting()
            end,
        },
        {
            name = L["Objective Font Size"] or "Objective Font Size",
            kind = LEM.SettingType.Slider,
            default = 11,
            minValue = 8,
            maxValue = 18,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return self.db.objectiveFontSize or 11 end,
            set = function(_, val)
                self.db.objectiveFontSize = val
                self:SkinAllExisting()
            end,
        },
        {
            name = L["Hide Master Header"] or "Hide Master Header",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function() return self.db.hideMasterHeader == true end,
            set = function(_, val)
                self.db.hideMasterHeader = val
                self:ApplyMasterHeaderVisibility()
            end,
        },
    }
end

function ObjectivesMod:GetLEMFrameButtons()
    return {
        {
            text = L["Open Full Settings"] or "Open Full Settings",
            click = function()
                if RoithiUI and RoithiUI.OpenSettings then
                    RoithiUI:OpenSettings("objectives")
                elseif LibStub("AceConfigDialog-3.0") then
                    LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "interface_group", "objectives")
                    LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                end
            end,
        }
    }
end
