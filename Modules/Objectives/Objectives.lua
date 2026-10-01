local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:NewModule("Objectives", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode-Roithi", true)

ObjectivesMod.displayName = L["Objectives"] or "Objectives"
ObjectivesMod.description = L["Modern restyling for the Blizzard Objective Tracker with clean typography and status bars."] or "Modern restyling for the Blizzard Objective Tracker with clean typography and status bars."
ObjectivesMod.order = 87
ObjectivesMod.dbKey = "Objectives"

ObjectivesMod.defaultSettings = {
    enabled = true,
    font = "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf",
    fontOutline = "OUTLINE",
    headerFontSize = 13,
    titleFontSize = 12,
    objectiveFontSize = 11,
    headerColor = { r = 0.05, g = 0.82, b = 0.61, a = 1.0 }, -- Accent teal/green
    titleColor = { r = 1.0, g = 0.85, b = 0.35, a = 1.0 }, -- Gold
    objectiveColor = { r = 0.8, g = 0.8, b = 0.8, a = 1.0 }, -- Gray
    completedColor = { r = 0.25, g = 1.0, b = 0.35, a = 1.0 }, -- Green
    showAccentDivider = true,
    skinProgressBars = true,
    hideMasterHeader = false,
    point = "TOPRIGHT",
    x = -50,
    y = -200,
}

-- Weak-keyed state tables to strictly prevent mutating Blizzard-owned tables (taint prevention)
local skinnedBlocks = setmetatable({}, { __mode = "k" })
local skinnedBars = setmetatable({}, { __mode = "k" })
local hookedTrackers = setmetatable({}, { __mode = "k" })
local headerDividers = setmetatable({}, { __mode = "k" })
local titleFSCache = setmetatable({}, { __mode = "k" })

local SUB_TRACKERS = {
    "ScenarioObjectiveTracker",
    "UIWidgetObjectiveTracker",
    "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker",
    "AdventureObjectiveTracker",
    "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker",
    "ProfessionsRecipeTracker",
    "BonusObjectiveTracker",
    "WorldQuestObjectiveTracker",
    "InitiativeTasksObjectiveTracker",
}

local function SharesWidgetPool(tracker)
    return tracker == _G.ScenarioObjectiveTracker or tracker == _G.UIWidgetObjectiveTracker
end

function ObjectivesMod:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Objectives or self.defaultSettings
end

function ObjectivesMod:OnEnable()
    if self.db.enabled == false then return end

    self:RegisterWithEditMode()
    self:HookAllTrackers()
    self:SkinAllExisting()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
end

function ObjectivesMod:OnDisable()
    -- Subtrackers remain hooked without re-skinning
end

function ObjectivesMod:OnPlayerEnteringWorld()
    C_Timer.After(0.3, function()
        if self.SkinAllExisting then
            self:SkinAllExisting()
        end
    end)
end

-------------------------------------------------------------------------------
-- LibEditMode Integration
-------------------------------------------------------------------------------
function ObjectivesMod:RegisterWithEditMode()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not LEM or otf.roithiEditModeRegistered then return end
    otf.roithiEditModeRegistered = true

    otf.editModeName = L["Objective Tracker"] or "Objective Tracker"

    local defaults = {
        point = self.defaultSettings.point or "TOPRIGHT",
        x = self.defaultSettings.x or -50,
        y = self.defaultSettings.y or -200,
    }

    local function OnPositionChanged(f, _, point, x, y)
        self.db.point = point
        self.db.x = x
        self.db.y = y
        f:ClearAllPoints()
        f:SetPoint(point, UIParent, point, x, y)
    end

    LEM:AddFrame(otf, OnPositionChanged, defaults)

    local settings = {
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

    if LEM.AddFrameSettings then
        LEM:AddFrameSettings(otf, settings)
    end

    if LEM.AddFrameSettingsButtons then
        LEM:AddFrameSettingsButtons(otf, {
            {
                text = "Open Full Settings",
                click = function()
                    if RoithiUI and RoithiUI.OpenSettings then
                        RoithiUI:OpenSettings("objectives")
                    elseif LibStub("AceConfigDialog-3.0") then
                        LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "interface_group", "objectives")
                        LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                    end
                end,
            }
        })
    end
end

-------------------------------------------------------------------------------
-- Tracker Hooking
-------------------------------------------------------------------------------
function ObjectivesMod:HookAllTrackers()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end

    if otf.Header then
        self:SkinHeader(otf.Header)
    end
    if otf.HeaderMenu then
        self:SkinHeader(otf.HeaderMenu)
    end

    for _, trackerName in ipairs(SUB_TRACKERS) do
        local tracker = _G[trackerName]
        if tracker then
            self:HookTracker(tracker)
        end
    end

    self:ApplyMasterHeaderVisibility()
end

function ObjectivesMod:HookTracker(tracker)
    if not tracker or hookedTrackers[tracker] then return end
    hookedTrackers[tracker] = true

    if tracker.Header then
        self:SkinHeader(tracker.Header)
        if tracker.Header.SetCollapsed then
            self:SecureHook(tracker.Header, "SetCollapsed", function(h)
                self:SkinHeader(h)
            end)
        end
    end

    -- If this tracker shares the UI-widget pool (Scenario / UIWidget), stop here!
    -- DO NOT skin child blocks (crucial taint protection).
    if SharesWidgetPool(tracker) then return end

    if tracker.AddBlock then
        self:SecureHook(tracker, "AddBlock", function(_, block)
            if block then
                skinnedBlocks[block] = nil
                self:SkinBlock(block)
            end
        end)
    end

    -- Hook update via lightweight dirty flag
    local isDirty = false
    if tracker.Update then
        self:SecureHook(tracker, "Update", function()
            if isDirty then return end
            isDirty = true
            C_Timer.After(0, function()
                isDirty = false
                if tracker.Header then
                    self:EnsureAccentDivider(tracker.Header)
                end
                self:SkinExistingBlocks(tracker)
            end)
        end)
    end
end

-------------------------------------------------------------------------------
-- Header Skinning
-------------------------------------------------------------------------------
function ObjectivesMod:SkinHeader(header)
    if not header then return end

    -- Strip decorative textures via SetTexture("") to avoid taint
    local decorNames = { "Background", "Line", "LineSheen", "LineGlow", "Divider", "Sheen", "Glow", "Stripe" }
    for _, k in ipairs(decorNames) do
        local tex = header[k]
        if tex and tex.SetTexture then
            tex:SetTexture("")
        end
    end

    -- Sweep top-level texture regions
    if header.GetRegions then
        for _, region in ipairs({ header:GetRegions() }) do
            if region and region:GetObjectType() == "Texture" then
                if region ~= (header.MinimizeButton and header.MinimizeButton:GetNormalTexture())
                   and region ~= (header.MinimizeButton and header.MinimizeButton:GetPushedTexture())
                   and region.SetTexture then
                    region:SetTexture("")
                end
            end
        end
    end

    -- Style FontString
    local text = header.Text
    if text then
        local font = self.db.font or "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf"
        local size = self.db.headerFontSize or 13
        local outline = self.db.fontOutline or "OUTLINE"
        pcall(text.SetFont, text, font, size, outline)

        local hc = self.db.headerColor or self.defaultSettings.headerColor
        text:SetTextColor(hc.r or 0.05, hc.g or 0.82, hc.b or 0.61, 1.0)
    end

    self:EnsureAccentDivider(header)
end

function ObjectivesMod:EnsureAccentDivider(header)
    if not header or not self.db.showAccentDivider then
        if headerDividers[header] then
            headerDividers[header]:Hide()
        end
        return
    end

    local divider = headerDividers[header]
    if not divider then
        local otf = _G.ObjectiveTrackerFrame
        if not otf then return end
        divider = otf:CreateTexture(nil, "OVERLAY")
        divider:SetHeight(1)
        divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -2)
        divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, -2)
        headerDividers[header] = divider
    end

    local hc = self.db.headerColor or self.defaultSettings.headerColor
    divider:SetColorTexture(hc.r or 0.05, hc.g or 0.82, hc.b or 0.61, 0.8)
    divider:SetShown(header:IsShown() and (_G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame:IsShown()))
end

function ObjectivesMod:ApplyMasterHeaderVisibility()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end
    local h = otf.Header or otf.HeaderMenu
    if not h then return end

    if self.db.hideMasterHeader then
        h:Hide()
    else
        h:Show()
    end
end

-------------------------------------------------------------------------------
-- Block Skinning
-------------------------------------------------------------------------------
local function GetBlockTitleFS(block)
    if not block then return nil end
    local cached = titleFSCache[block]
    if cached then return cached end
    if not block.GetRegions then return nil end

    for _, rg in ipairs({ block:GetRegions() }) do
        if rg.GetObjectType and rg:GetObjectType() == "FontString" then
            titleFSCache[block] = rg
            return rg
        end
    end
    return nil
end

function ObjectivesMod:SkinBlock(block)
    if not block or skinnedBlocks[block] then return end
    skinnedBlocks[block] = true

    local font = self.db.font or "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf"
    local titleSize = self.db.titleFontSize or 12
    local outline = self.db.fontOutline or "OUTLINE"

    -- Style title fontstring
    local titleFS = GetBlockTitleFS(block)
    if titleFS then
        pcall(titleFS.SetFont, titleFS, font, titleSize, outline)
        local tc = self.db.titleColor or self.defaultSettings.titleColor
        titleFS:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
    end

    -- Style objective lines
    if block.lines then
        for _, line in pairs(block.lines) do
            self:StyleObjectiveLine(line)
        end
    end

    -- Style progress bars
    if self.db.skinProgressBars and block.ProgressBar then
        self:SkinProgressBar(block.ProgressBar)
    end
end

function ObjectivesMod:StyleObjectiveLine(line)
    if not line or not line.Text then return end
    local font = self.db.font or "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf"
    local objSize = self.db.objectiveFontSize or 11
    local outline = self.db.fontOutline or "OUTLINE"

    pcall(line.Text.SetFont, line.Text, font, objSize, outline)
    local oc = self.db.objectiveColor or self.defaultSettings.objectiveColor
    line.Text:SetTextColor(oc.r or 0.8, oc.g or 0.8, oc.b or 0.8, 1.0)

    if line.Dash then
        pcall(line.Dash.SetFont, line.Dash, font, objSize, outline)
        line.Dash:SetTextColor(oc.r or 0.8, oc.g or 0.8, oc.b or 0.8, 1.0)
    end
end

function ObjectivesMod:SkinProgressBar(bar)
    if not bar or skinnedBars[bar] then return end
    skinnedBars[bar] = true

    if bar.BarFrame2 then bar.BarFrame2:SetTexture("") end
    if bar.BarFrame3 then bar.BarFrame3:SetTexture("") end
    if bar.BarGlow then bar.BarGlow:SetTexture("") end
    if bar.Sheen then bar.Sheen:SetTexture("") end

    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture(LibRoithi:GetStatusBarTexture())
    end

    if not bar.roithiBackdrop then
        local bg = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        bg:SetAllPoints(bar)
        bg:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
        bg:EnableMouse(false)
        LibRoithi.mixins:CreateBackdrop(bg)
        bg:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        bg:SetBackdropBorderColor(0, 0, 0, 1)
        bar.roithiBackdrop = bg
    end
end

function ObjectivesMod:SkinExistingBlocks(tracker)
    if not tracker or SharesWidgetPool(tracker) then return end

    if tracker.usedBlocks then
        for _, byTemplate in pairs(tracker.usedBlocks) do
            if type(byTemplate) == "table" then
                for _, block in pairs(byTemplate) do
                    if type(block) == "table" then
                        self:SkinBlock(block)
                    end
                end
            end
        end
    end
end

function ObjectivesMod:SkinAllExisting()
    for _, trackerName in ipairs(SUB_TRACKERS) do
        local tracker = _G[trackerName]
        if tracker then
            if tracker.Header then
                self:SkinHeader(tracker.Header)
            end
            self:SkinExistingBlocks(tracker)
        end
    end
end

function ObjectivesMod:RefreshSettings()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Objectives or self.defaultSettings
    self:ApplyMasterHeaderVisibility()
    self:SkinAllExisting()
end
