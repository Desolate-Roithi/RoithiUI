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
                        set = function(info, val)
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
                        set = function(info, val)
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
                        set = function(info, val)
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
                        set = function(info, val)
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
                        set = function(info, val)
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
                        set = function(info, val)
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
                        set = function(info, val)
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
                        set = function(info, val)
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
                        set = function(info, val)
                            self.db.autoCollapseInstance = val
                            self:CheckAutoCollapse()
                        end,
                    },
                    hideInMythicPlus = {
                        type = "toggle",
                        name = L["Hide in Mythic+"] or "Hide in Mythic+",
                        desc = L["Completely hide the objective tracker when a Mythic+ dungeon run is active."] or "Completely hide the objective tracker when a Mythic+ dungeon run is active.",
                        order = 9.2,
                        get = function() return self.db.hideInMythicPlus == true end,
                        set = function(info, val)
                            self.db.hideInMythicPlus = val
                            if self.CheckMythicPlusVisibility then
                                self:CheckMythicPlusVisibility()
                            end
                            self:CheckAutoCollapse()
                        end,
                    },
                    attachedToMinimap = {
                        type = "toggle",
                        name = L["Attach to Minimap"] or "Attach to Minimap",
                        desc = L["Anchor the objective tracker directly below the minimap, matching its combined width."] or "Anchor the objective tracker directly below the minimap, matching its combined width.",
                        order = 9.5,
                        get = function() return self.db.attachedToMinimap ~= false end,
                        set = function(info, val)
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
                        set = function(info, val)
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
                            if self.RefreshTrackers then
                                self:RefreshTrackers()
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
                        set = function(info, val)
                            self.db.showQuestLevel = val
                            self:SkinAllExisting()
                        end,
                    },
                    showForeverQuestInfinity = {
                        type = "toggle",
                        name = L["Forever Quest Indicator"] or "Forever Quest Indicator",
                        desc = L["Display an infinity symbol next to the level for new quests not part of original Classic."] or "Display an infinity symbol next to the level for new quests not part of original Classic.",
                        order = 12.5,
                        hidden = function() return ns.IsRetail or (_G.WOW_PROJECT_ID and _G.WOW_PROJECT_MAINLINE and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE) end,
                        get = function() return self.db.showForeverQuestInfinity ~= false end,
                        set = function(info, val)
                            self.db.showForeverQuestInfinity = val
                            self:SkinAllExisting()
                        end,
                    },
                    showCompletedQuestIndicator = {
                        type = "toggle",
                        name = L["Completed Quest Indicator"] or "Completed Quest Indicator",
                        desc = L["Display a green checkmark and highlight the quest title in green when ready for turn-in."] or "Display a green checkmark and highlight the quest title in green when ready for turn-in.",
                        order = 12.6,
                        get = function() return self.db.showCompletedQuestIndicator ~= false end,
                        set = function(info, val)
                            self.db.showCompletedQuestIndicator = val
                            self:SkinAllExisting()
                        end,
                    },
                    hoverObjectiveText = {
                        type = "toggle",
                        name = L["Objectives on Hover Only"] or "Objectives on Hover Only",
                        desc = L["Only show quest objective text and progress when hovering over the quest."] or "Only show quest objective text and progress when hovering over the quest.",
                        order = 13,
                        get = function() return self.db.hoverObjectiveText ~= false end,
                        set = function(info, val)
                            self.db.hoverObjectiveText = val
                            self:RefreshSettings()
                        end,
                    },
                    hideCompletedObjectives = {
                        type = "toggle",
                        name = L["Hide Completed Objectives"] or "Hide Completed Objectives",
                        desc = L["Hide completed objective lines while keeping uncompleted objectives visible, dynamically adjusting quest height."] or "Hide completed objective lines while keeping uncompleted objectives visible, dynamically adjusting quest height.",
                        order = 13.2,
                        get = function() return self.db.hideCompletedObjectives == true end,
                        set = function(info, val)
                            self.db.hideCompletedObjectives = val
                            self:RefreshSettings()
                        end,
                    },
                    collapseDelay = {
                        type = "range",
                        name = L["Hover Collapse Delay"] or "Hover Collapse Delay",
                        desc = L["Delay in seconds before collapsing quest objectives when moving the mouse away, preventing abrupt accordion jumping."] or "Delay in seconds before collapsing quest objectives when moving the mouse away, preventing abrupt accordion jumping.",
                        order = 13.5,
                        min = 0.05,
                        max = 1.0,
                        step = 0.05,
                        get = function() return self.db.collapseDelay or 0.25 end,
                        set = function(info, val)
                            self.db.collapseDelay = val
                        end,
                    },
                    hideQuestIcon = {
                        type = "toggle",
                        name = L["Hide Quest POI Icon"] or "Hide Quest POI Icon",
                        desc = L["Hide the round quest POI button / icon next to quest titles."] or "Hide the round quest POI button / icon next to quest titles.",
                        order = 14,
                        get = function() return self.db.hideQuestIcon ~= false end,
                        set = function(info, val)
                            self.db.hideQuestIcon = val
                            self:SkinAllExisting()
                        end,
                    },
                    showFocusIndicator = {
                        type = "toggle",
                        name = L["Show Focus Indicator"] or "Show Focus Indicator",
                        desc = L["Display a focused marker next to the currently super-tracked / focused quest."] or "Display a focused marker next to the currently super-tracked / focused quest.",
                        order = 15,
                        get = function() return self.db.showFocusIndicator ~= false end,
                        set = function(info, val)
                            self.db.showFocusIndicator = val
                            self:SkinAllExisting()
                        end,
                    },
                    scenarioStageHeight = {
                        type = "range",
                        name = L["Scenario Stage Height"] or "Scenario Stage Height",
                        desc = L["Custom height in pixels for the scenario stage block when text-only (e.g. Awakening) or toast background is active."] or "Custom height in pixels for the scenario stage block.",
                        order = 16,
                        min = 16,
                        max = 100,
                        step = 1,
                        get = function() return self.db.scenarioStageHeight or 63 end,
                        set = function(info, val)
                            self.db.scenarioStageHeight = val
                            if self.AlignScenarioElements then
                                self:AlignScenarioElements()
                            end
                        end,
                    },
                    scenarioStageWidgetHeight = {
                        type = "range",
                        name = L["Scenario Stage Widget Height"] or "Scenario Stage Widget Height",
                        desc = L["Fallback height in pixels for scenario stage blocks when a widget is present (e.g. Horrific Visions, Delves, Torghast)."] or "Fallback height in pixels for scenario stage blocks when a widget is present.",
                        order = 17,
                        min = 50,
                        max = 140,
                        step = 1,
                        get = function() return self.db.scenarioStageWidgetHeight or 83 end,
                        set = function(info, val)
                            self.db.scenarioStageWidgetHeight = val
                            if self.AlignScenarioElements then
                                self:AlignScenarioElements()
                            end
                        end,
                    },
                    scenarioStageXOffset = {
                        type = "range",
                        name = L["Scenario Stage X-Offset"] or "Scenario Stage X-Offset",
                        desc = L["Horizontal offset in pixels for fine-tuning the scenario stage block position."] or "Horizontal offset in pixels for fine-tuning the scenario stage block position.",
                        order = 18,
                        min = -50,
                        max = 50,
                        step = 1,
                        get = function() return (self.db and self.db.scenarioStageXOffset) or 0 end,
                        set = function(info, val)
                            self.db.scenarioStageXOffset = val
                            if self.AlignScenarioElements then
                                self:AlignScenarioElements()
                            end
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
                        values = function()
                            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                            return (LSM and LSM:HashTable("font")) or (_G.AceGUIWidgetLSMlists and _G.AceGUIWidgetLSMlists.font) or {
                                ["Expressway"] = "Expressway",
                                ["Roithi Thick"] = "Roithi Thick",
                                ["Roithi Thin"] = "Roithi Thin",
                                ["Friz Quadrata TT"] = "Friz Quadrata TT",
                            }
                        end,
                        get = function()
                            local f = self.db and self.db.font
                            if not f or f == "" or f:find("\\") or f:find("%.ttf$") then
                                local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                                if LSM and f then
                                    for fontName, fontPath in pairs(LSM:HashTable("font")) do
                                        if fontPath == f then
                                            self.db.font = fontName
                                            return fontName
                                        end
                                    end
                                end
                                if self.db then self.db.font = "Expressway" end
                                return "Expressway"
                            end
                            return f
                        end,
                        set = function(_, val)
                            self.db.font = val
                            self:SkinAllExisting()
                        end,
                    },
                    fontOutline = {
                        type = "select",
                        name = L["Font Outline"] or "Font Outline",
                        order = 2,
                        values = {
                            ["NONE"] = L["None"] or "None",
                            ["OUTLINE"] = L["Outline"] or "Outline",
                            ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
                        },
                        get = function() return (self.db and self.db.fontOutline) or "OUTLINE" end,
                        set = function(_, val)
                            self.db.fontOutline = val
                            self:SkinAllExisting()
                        end,
                    },
                    headerFontSize = {
                        type = "range",
                        name = L["Header Font Size"] or "Header Font Size",
                        order = 3,
                        min = 9,
                        max = 20,
                        step = 1,
                        get = function() return (self.db and self.db.headerFontSize) or 13 end,
                        set = function(_, val)
                            self.db.headerFontSize = val
                            self:SkinAllExisting()
                        end,
                    },
                    titleFontSize = {
                        type = "range",
                        name = L["Title Font Size"] or "Title Font Size",
                        order = 4,
                        min = 9,
                        max = 20,
                        step = 1,
                        get = function() return (self.db and self.db.titleFontSize) or 12 end,
                        set = function(_, val)
                            self.db.titleFontSize = val
                            self:SkinAllExisting()
                        end,
                    },
                    objectiveFontSize = {
                        type = "range",
                        name = L["Objective Font Size"] or "Objective Font Size",
                        order = 5,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return (self.db and self.db.objectiveFontSize) or 11 end,
                        set = function(_, val)
                            self.db.objectiveFontSize = val
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
                        set = function(info, r, g, b, a)
                            self.db.objectiveColor = { r = r, g = g, b = b, a = a }
                            self:SkinAllExisting()
                        end,
                    },
                    foreverColor = {
                        type = "color",
                        name = L["Forever Indicator Color"] or "Forever Indicator Color",
                        desc = L["Color of the infinity symbol for Forever quests."] or "Color of the infinity symbol for Forever quests.",
                        hasAlpha = false,
                        order = 4,
                        get = function()
                            local c = self.db.foreverColor or { r = 0.22, g = 0.74, b = 0.97, a = 1.0 }
                            return c.r or 0.22, c.g or 0.74, c.b or 0.97
                        end,
                        set = function(info, r, g, b)
                            self.db.foreverColor = { r = r, g = g, b = b, a = 1.0 }
                            self:SkinAllExisting()
                        end,
                    },
                },
            },
        },
    }
end

function ObjectivesMod:GetLEMFrameSettings()
    local LEM = LibStub("LibEditMode-Roithi", true) or LibStub("LibEditMode-1.0", true)
    if not LEM or not LEM.SettingType then return {} end

    local settings = {
        {
            name = L["Attach to Minimap"] or "Attach to Minimap",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return self.db.attachedToMinimap ~= false end,
            set = function(_, val)
                self.db.attachedToMinimap = val
                self:ApplyPosition()
                self:ApplyScaleAndHeight()
                if LEM.RefreshFrameSettings and _G.ObjectiveTrackerFrame then
                    LEM:RefreshFrameSettings(_G.ObjectiveTrackerFrame)
                end
            end,
        },
        {
            name = L["Objectives on Hover Only"] or "Objectives on Hover Only",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return self.db.hoverObjectiveText ~= false end,
            set = function(_, val)
                self.db.hoverObjectiveText = val
                self:RefreshSettings()
            end,
        },
        {
            name = L["X Position"] or "X Position",
            kind = LEM.SettingType.Slider,
            default = -50,
            minValue = -2500,
            maxValue = 2500,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            disabled = function() return self.db.attachedToMinimap ~= false end,
            get = function() return self.db.x or -50 end,
            set = function(_, val)
                self.db.x = val
                self.db.attachedToMinimap = false
                self:ApplyPosition()
            end,
        },
        {
            name = L["Y Position"] or "Y Position",
            kind = LEM.SettingType.Slider,
            default = -200,
            minValue = -1500,
            maxValue = 1500,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            disabled = function() return self.db.attachedToMinimap ~= false end,
            get = function() return self.db.y or -200 end,
            set = function(_, val)
                self.db.y = val
                self.db.attachedToMinimap = false
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
    return settings
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
