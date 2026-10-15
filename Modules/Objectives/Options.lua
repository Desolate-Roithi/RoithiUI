local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:GetModule("Objectives")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

local function GetFontValues()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    return (LSM and LSM:HashTable("font")) or (_G.AceGUIWidgetLSMlists and _G.AceGUIWidgetLSMlists.font) or {
        ["Expressway"] = "Expressway",
        ["Roithi Thick"] = "Roithi Thick",
        ["Roithi Thin"] = "Roithi Thin",
        ["Friz Quadrata TT"] = "Friz Quadrata TT",
    }
end

local function CreateFontOption(name, order, dbKey, defaultVal)
    return {
        type = "select",
        dialogControl = "LSM30_Font",
        name = name,
        order = order,
        values = GetFontValues,
        get = function()
            local f = ObjectivesMod.db and ObjectivesMod.db[dbKey]
            if not f or f == "" or f:find("\\") or f:find("%.ttf$") then
                local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                if LSM and f then
                    for fontName, fontPath in pairs(LSM:HashTable("font")) do
                        if fontPath == f then
                            ObjectivesMod.db[dbKey] = fontName
                            return fontName
                        end
                    end
                end
                if ObjectivesMod.db then ObjectivesMod.db[dbKey] = defaultVal or "Expressway" end
                return defaultVal or "Expressway"
            end
            return f
        end,
        set = function(_, val)
            ObjectivesMod.db[dbKey] = val
            ObjectivesMod:UpdateFonts()
            ObjectivesMod:SkinAllExisting()
        end,
    }
end

local function CreateOutlineOption(name, order, dbKey, defaultVal)
    return {
        type = "select",
        name = name,
        order = order,
        values = {
            ["NONE"] = L["None"] or "None",
            ["OUTLINE"] = L["Outline"] or "Outline",
            ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
            ["MONOCHROME"] = L["Monochrome"] or "Monochrome",
        },
        get = function() return (ObjectivesMod.db and ObjectivesMod.db[dbKey]) or defaultVal or "OUTLINE" end,
        set = function(_, val)
            if ObjectivesMod.db then ObjectivesMod.db[dbKey] = val end
            ObjectivesMod:UpdateFonts()
            ObjectivesMod:SkinAllExisting()
        end,
    }
end

local function CreateShadowOption(name, order, dbKey, defaultVal)
    return {
        type = "toggle",
        name = name,
        desc = L["Display a drop shadow behind text."] or "Display a drop shadow behind text.",
        order = order,
        get = function()
            if ObjectivesMod.db and ObjectivesMod.db[dbKey] ~= nil then
                return ObjectivesMod.db[dbKey] == true
            end
            return defaultVal == true
        end,
        set = function(_, val)
            if ObjectivesMod.db then ObjectivesMod.db[dbKey] = val end
            ObjectivesMod:UpdateFonts()
            ObjectivesMod:SkinAllExisting()
        end,
    }
end

function ObjectivesMod:GetOptions()
    local generalArgs = {
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
        dividerThickness = {
            type = "range",
            name = L["Divider Thickness"] or "Divider Thickness",
            desc = L["Height in pixels of the colored accent line."] or "Height in pixels of the colored accent line.",
            order = 4,
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
        skinProgressBars = {
            type = "toggle",
            name = L["Skin Progress Bars"] or "Skin Progress Bars",
            desc = L["Apply modern flat styling and 1px borders to quest progress bars."] or "Apply modern flat styling and 1px borders to quest progress bars.",
            order = 5,
            get = function() return self.db.skinProgressBars ~= false end,
            set = function(info, val)
                self.db.skinProgressBars = val
                self:SkinAllExisting()
            end,
        },
        autoCollapseCombat = {
            type = "toggle",
            name = L["Auto-Collapse in Combat"] or "Auto-Collapse in Combat",
            desc = L["Automatically minimize the objective tracker upon entering combat."] or "Automatically minimize the objective tracker upon entering combat.",
            order = 6,
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
            order = 7,
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
            order = 8,
            get = function() return self.db.hideInMythicPlus == true end,
            set = function(info, val)
                self.db.hideInMythicPlus = val
                if self.CheckMythicPlusVisibility then
                    self:CheckMythicPlusVisibility()
                end
                self:CheckAutoCollapse()
            end,
        },
    }

    local positionArgs = {
        scale = {
            type = "range",
            name = L["Scale"] or "Scale",
            desc = L["Scale factor for the entire objective tracker."] or "Scale factor for the entire objective tracker.",
            order = 1,
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
            order = 2,
            min = 200,
            max = 1400,
            step = 25,
            get = function() return self.db.maxHeight or 800 end,
            set = function(info, val)
                self.db.maxHeight = val
                self:ApplyScaleAndHeight()
            end,
        },
        attachedToMinimap = {
            type = "toggle",
            name = L["Attach to Minimap"] or "Attach to Minimap",
            desc = L["Anchor the objective tracker directly below the minimap, matching its combined width."] or "Anchor the objective tracker directly below the minimap, matching its combined width.",
            order = 3,
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
            order = 4,
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
        blockOffsetX = {
            type = "range",
            name = L["Quest Text Left Offset"] or "Quest Text Left Offset",
            desc = L["Horizontal indent for quest titles and blocks to align inline with category headers (default: 4)."] or "Horizontal indent for quest titles and blocks to align inline with category headers (default: 4).",
            order = 5,
            min = 0,
            max = 20,
            step = 1,
            get = function() return (self.db and self.db.blockOffsetX) or 4 end,
            set = function(info, val)
                self.db.blockOffsetX = val
                self:UpdateFonts()
                self:SkinAllExisting()
            end,
        },
        resetPosition = {
            type = "execute",
            name = L["Reset Position"] or "Reset Position",
            desc = L["Reset the objective tracker to its default screen position."] or "Reset the objective tracker to its default screen position.",
            order = 6,
            func = function()
                self.db.attachedToMinimap = true
                self.db.point = self.defaultSettings.point or "TOPRIGHT"
                self.db.x = self.defaultSettings.x or -50
                self.db.y = self.defaultSettings.y or -200
                self:ApplyPosition()
            end,
        },
    }

    local questsArgs = {
        sortQuestsByZone = {
            type = "toggle",
            name = L["Sort Quests by Current Zone"] or "Sort Quests by Current Zone",
            desc = L["Display quests located in your current zone at the top of the tracker."] or "Display quests located in your current zone at the top of the tracker.",
            order = 1,
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
            order = 2,
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
            order = 3,
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
            order = 4,
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
            order = 5,
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
            order = 6,
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
            order = 7,
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
            order = 8,
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
            order = 9,
            get = function() return self.db.showFocusIndicator ~= false end,
            set = function(info, val)
                self.db.showFocusIndicator = val
                self:SkinAllExisting()
            end,
        },
    }

    local typographyArgs = {
        headerHeader = {
            type = "header",
            name = L["Category Headers"] or "Category Headers",
            order = 1,
        },
        headerFont = CreateFontOption(L["Header Font"] or "Header Font", 2, "headerFont", "Expressway"),
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
                self:UpdateFonts()
                self:SkinAllExisting()
            end,
        },
        headerFontOutline = CreateOutlineOption(L["Header Font Outline"] or "Header Font Outline", 4, "headerFontOutline", "OUTLINE"),
        headerFontShadow = CreateShadowOption(L["Header Text Shadow"] or "Header Text Shadow", 5, "headerFontShadow", false),

        titleHeader = {
            type = "header",
            name = L["Quest & Block Titles"] or "Quest & Block Titles",
            order = 6,
        },
        titleFont = CreateFontOption(L["Title Font"] or "Title Font", 7, "titleFont", "Expressway"),
        titleFontSize = {
            type = "range",
            name = L["Title Font Size"] or "Title Font Size",
            order = 8,
            min = 9,
            max = 20,
            step = 1,
            get = function() return (self.db and self.db.titleFontSize) or 12 end,
            set = function(_, val)
                self.db.titleFontSize = val
                self:UpdateFonts()
                self:SkinAllExisting()
            end,
        },
        titleFontOutline = CreateOutlineOption(L["Title Font Outline"] or "Title Font Outline", 9, "titleFontOutline", "OUTLINE"),
        titleFontShadow = CreateShadowOption(L["Title Text Shadow"] or "Title Text Shadow", 10, "titleFontShadow", false),

        objectiveHeader = {
            type = "header",
            name = L["Objective Lines"] or "Objective Lines",
            order = 11,
        },
        objectiveFont = CreateFontOption(L["Objective Font"] or "Objective Font", 12, "objectiveFont", "Expressway"),
        objectiveFontSize = {
            type = "range",
            name = L["Objective Font Size"] or "Objective Font Size",
            order = 13,
            min = 8,
            max = 18,
            step = 1,
            get = function() return (self.db and self.db.objectiveFontSize) or 11 end,
            set = function(_, val)
                self.db.objectiveFontSize = val
                self:UpdateFonts()
                self:SkinAllExisting()
            end,
        },
        objectiveFontOutline = CreateOutlineOption(L["Objective Font Outline"] or "Objective Font Outline", 14, "objectiveFontOutline", "OUTLINE"),
        objectiveFontShadow = CreateShadowOption(L["Objective Text Shadow"] or "Objective Text Shadow", 15, "objectiveFontShadow", false),

        globalHeader = {
            type = "header",
            name = L["Global Fallbacks"] or "Global Fallbacks",
            order = 16,
        },
        font = CreateFontOption(L["Global Fallback Font"] or "Global Fallback Font", 17, "font", "Expressway"),
        fontOutline = CreateOutlineOption(L["Global Fallback Outline"] or "Global Fallback Outline", 18, "fontOutline", "OUTLINE"),
        showFontShadow = CreateShadowOption(L["Global Fallback Text Shadow"] or "Global Fallback Text Shadow", 19, "showFontShadow", false),
    }

    local colorsArgs = {
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
        completedColor = {
            type = "color",
            name = L["Completed Quest Color"] or "Completed Quest Color",
            desc = L["Color for quest titles ready to turn in."] or "Color for quest titles ready to turn in.",
            hasAlpha = false,
            order = 4,
            get = function()
                local c = self.db.completedColor or (self.defaultSettings and self.defaultSettings.completedColor) or { r = 0.25, g = 1, b = 0.35, a = 1.0 }
                return c.r or 0.25, c.g or 1.0, c.b or 0.35
            end,
            set = function(info, r, g, b)
                self.db.completedColor = { r = r, g = g, b = b, a = 1.0 }
                self:SkinAllExisting()
            end,
        },
        foreverColor = {
            type = "color",
            name = L["Forever Indicator Color"] or "Forever Indicator Color",
            desc = L["Color of the infinity symbol for Forever quests."] or "Color of the infinity symbol for Forever quests.",
            hasAlpha = false,
            order = 5,
            get = function()
                local c = self.db.foreverColor or { r = 0.22, g = 0.74, b = 0.97, a = 1.0 }
                return c.r or 0.22, c.g or 0.74, c.b or 0.97
            end,
            set = function(info, r, g, b)
                self.db.foreverColor = { r = r, g = g, b = b, a = 1.0 }
                self:SkinAllExisting()
            end,
        },
    }

    local scenarioArgs = {
        scenarioStageHeight = {
            type = "range",
            name = L["Scenario Stage Height"] or "Scenario Stage Height",
            desc = L["Custom height in pixels for the scenario stage block when text-only (e.g. Awakening) or toast background is active."] or "Custom height in pixels for the scenario stage block.",
            order = 1,
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
            order = 2,
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
            order = 3,
            min = -100,
            max = 100,
            step = 1,
            get = function() return (self.db and self.db.scenarioStageXOffset) or 0 end,
            set = function(info, val)
                self.db.scenarioStageXOffset = val
                if self.AlignScenarioElements then
                    self:AlignScenarioElements()
                end
            end,
        },
        delveWidgetXOffset = {
            type = "range",
            name = L["Delve Widget X-Offset"] or "Delve Widget X-Offset",
            desc = L["Horizontal offset in pixels for fine-tuning the Delves stage block position."] or "Horizontal offset in pixels for fine-tuning the Delves stage block position.",
            order = 4,
            min = -100,
            max = 100,
            step = 1,
            get = function() return (self.db and self.db.delveWidgetXOffset) or 0 end,
            set = function(info, val)
                self.db.delveWidgetXOffset = val
                if self.AlignScenarioElements then
                    self:AlignScenarioElements()
                end
            end,
        },
    }

    local options = {
        type = "group",
        name = L["Objectives"] or "Objectives",
        order = 45,
        childGroups = "select",
        args = {
            general = {
                type = "group",
                name = L["General"] or "General",
                order = 1,
                args = generalArgs,
            },
            position = {
                type = "group",
                name = L["Position & Sizing"] or "Position & Sizing",
                order = 2,
                args = positionArgs,
            },
            quests = {
                type = "group",
                name = L["Quests & Tracking"] or "Quests & Tracking",
                order = 3,
                args = questsArgs,
            },
            typography = {
                type = "group",
                name = L["Typography"] or "Typography",
                order = 4,
                args = typographyArgs,
            },
            colors = {
                type = "group",
                name = L["Colors & Textures"] or "Colors & Textures",
                order = 5,
                args = colorsArgs,
            },
            scenario = {
                type = "group",
                name = L["Scenario & Delves"] or "Scenario & Delves",
                order = 6,
                args = scenarioArgs,
            },
        },
    }

    setmetatable(generalArgs, {
        __index = function(_, k)
            return positionArgs[k] or questsArgs[k] or scenarioArgs[k]
        end,
    })

    return options
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


