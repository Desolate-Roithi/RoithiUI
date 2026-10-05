local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:NewModule("Objectives", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode-Roithi", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

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
    dividerThickness = 1,
    skinProgressBars = true,
    hideMasterHeader = false,
    scale = 1.0,
    maxHeight = 800,
    autoCollapseCombat = false,
    autoCollapseInstance = false,
    sortQuestsByZone = true,
    showQuestLevel = true,
    hoverObjectiveText = true,
    hideQuestIcon = true,
    attachedToMinimap = true,
    detachedWidth = 235,
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

function ObjectivesMod:GetFontPath()
    local f = self.db and self.db.font or "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf"
    if LSM and LSM:Fetch("font", f, true) then
        return LSM:Fetch("font", f)
    end
    return f
end

function ObjectivesMod:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Objectives or self.defaultSettings
    if self.db then
        for k, v in pairs(self.defaultSettings) do
            if self.db[k] == nil then
                self.db[k] = v
            end
        end
    end
end

function ObjectivesMod:OnEnable()
    if self.db.enabled == false then return end

    self:RegisterWithEditMode()
    self:ApplyPosition()
    self:HookAllTrackers()
    self:SkinAllExisting()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "CheckAutoCollapse")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "CheckAutoCollapse")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
    self:RegisterEvent("ZONE_CHANGED", "OnZoneChanged")
end

function ObjectivesMod:OnZoneChanged()
    self:CheckAutoCollapse()
    if self.db.sortQuestsByZone and _G.C_QuestLog and _G.C_QuestLog.SortQuestWatches then
        _G.C_QuestLog.SortQuestWatches()
    end
end

function ObjectivesMod:RestoreDefaultView()
    -- 1. Hide all dividers
    for _, divider in pairs(headerDividers) do
        if divider then divider:Hide() end
    end

    -- 2. Restore master header & scale
    local otf = _G.ObjectiveTrackerFrame
    if otf then
        if otf.Header then otf.Header:Show() end
        if otf.HeaderMenu then otf.HeaderMenu:Show() end
        if otf.SetScale then otf:SetScale(1.0) end
    end

    -- 3. Reset progress bars
    for bar in pairs(skinnedBars) do
        if bar and bar.roithiBackdrop then
            bar.roithiBackdrop:Hide()
        end
    end

    -- 4. Reset font strings on tracked blocks
    for block in pairs(skinnedBlocks) do
        local fs = titleFSCache[block]
        if fs and fs.SetFontObject then
            pcall(fs.SetFontObject, fs, "GameFontNormal")
            pcall(fs.SetTextColor, fs, 1, 0.82, 0)
        end
    end
end

function ObjectivesMod:OnDisable()
    self:RestoreDefaultView()
    self:UnregisterAllEvents()
    self:UnhookAll()
end

function ObjectivesMod:CheckAutoCollapse()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not self.db.enabled then return end

    local shouldCollapse = false
    if self.db.autoCollapseCombat and _G.InCombatLockdown and _G.InCombatLockdown() then
        shouldCollapse = true
    end
    if self.db.autoCollapseInstance and _G.IsInInstance and _G.IsInInstance() then
        shouldCollapse = true
    end

    if shouldCollapse then
        if otf.SetCollapsed and not (otf.IsCollapsed and otf:IsCollapsed()) then
            otf:SetCollapsed(true)
        end
    end
end

function ObjectivesMod:ApplyPosition()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end

    if self.db.attachedToMinimap ~= false then
        local mmMod = RoithiUI and RoithiUI.GetModule and RoithiUI:GetModule("Minimap", true)
        local anchorTarget = (mmMod and mmMod.container) or _G.MinimapCluster or _G.Minimap
        if anchorTarget and otf.ClearAllPoints and otf.SetPoint then
            otf:ClearAllPoints()
            otf:SetPoint("TOPRIGHT", anchorTarget, "BOTTOMRIGHT", 0, -4)

            local mmWidth = anchorTarget:GetWidth() or 220
            if mmMod and mmMod.addonBar and mmMod.addonBar:IsShown() and (mmMod.db and mmMod.db.addonBarPosition ~= "SEPARATE") then
                local barWidth = mmMod.addonBar:GetWidth() or 30
                mmWidth = mmWidth + barWidth
            end
            if mmWidth > 50 and otf.SetWidth then
                otf:SetWidth(mmWidth)
            end
        end
    else
        if otf.ClearAllPoints and otf.SetPoint then
            local pt = self.db.point or "TOPRIGHT"
            local x = self.db.x or -50
            local y = self.db.y or -200
            otf:ClearAllPoints()
            otf:SetPoint(pt, UIParent, pt, x, y)
            local customWidth = self.db.detachedWidth or self.db.width or 235
            if otf.SetWidth and customWidth > 50 then
                otf:SetWidth(customWidth)
            end
        end
    end

    self:ApplyScaleAndHeight()
end

function ObjectivesMod:ApplyScaleAndHeight()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end
    if self.db.scale and otf.SetScale then
        otf:SetScale(self.db.scale)
    end
    if self.db.maxHeight and otf.SetHeight then
        otf:SetHeight(self.db.maxHeight)
    end
end

function ObjectivesMod:OnPlayerEnteringWorld()
    C_Timer.After(0.3, function()
        if self.SkinAllExisting then
            self:SkinAllExisting()
        end
        if self.ApplyPosition then
            self:ApplyPosition()
        end
        if self.CheckAutoCollapse then
            self:CheckAutoCollapse()
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

    if otf.SetMovable then otf:SetMovable(true) end
    if otf.SetClampedToScreen then otf:SetClampedToScreen(true) end

    otf.editModeName = L["Objective Tracker"] or "Objective Tracker"

    local defaults = {
        point = self.defaultSettings.point or "TOPRIGHT",
        x = self.defaultSettings.x or -50,
        y = self.defaultSettings.y or -200,
    }

    local function OnPositionChanged(f, _, point, x, y)
        if self.db.attachedToMinimap ~= false then
            self.db.attachedToMinimap = false
        end
        self.db.point = point
        self.db.x = x
        self.db.y = y
        f:ClearAllPoints()
        f:SetPoint(point, UIParent, point, x, y)
    end

    LEM:AddFrame(otf, OnPositionChanged, defaults)

    if LEM.frameSelections and LEM.frameSelections[otf] then
        LEM.frameSelections[otf]:SetFrameLevel(otf:GetFrameLevel() + 50)
    end

    if LEM.AddFrameSettings and self.GetLEMFrameSettings then
        LEM:AddFrameSettings(otf, self:GetLEMFrameSettings())
    end

    if LEM.AddFrameSettingsButtons and self.GetLEMFrameButtons then
        LEM:AddFrameSettingsButtons(otf, self:GetLEMFrameButtons())
    end
end

-------------------------------------------------------------------------------
-- Tracker Hooking
-------------------------------------------------------------------------------
function ObjectivesMod:HookAllTrackers()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end

    if otf.SetCollapsed and not self:IsHooked(otf, "SetCollapsed") then
        self:SecureHook(otf, "SetCollapsed", function()
            self:UpdateAllDividers()
        end)
    end
    if otf.ToggleCollapsed and not self:IsHooked(otf, "ToggleCollapsed") then
        self:SecureHook(otf, "ToggleCollapsed", function()
            self:UpdateAllDividers()
        end)
    end

    if otf.Header then
        self:SkinHeader(otf.Header)
        if otf.Header.SetCollapsed and not self:IsHooked(otf.Header, "SetCollapsed") then
            self:SecureHook(otf.Header, "SetCollapsed", function()
                self:UpdateAllDividers()
            end)
        end
    end
    if otf.HeaderMenu then
        self:SkinHeader(otf.HeaderMenu)
        if otf.HeaderMenu.SetCollapsed and not self:IsHooked(otf.HeaderMenu, "SetCollapsed") then
            self:SecureHook(otf.HeaderMenu, "SetCollapsed", function()
                self:UpdateAllDividers()
            end)
        end
    end

    local mb = (otf.HeaderMenu and otf.HeaderMenu.MinimizeButton) or (otf.Header and otf.Header.MinimizeButton)
    if mb and mb.HookScript then
        mb:HookScript("OnClick", function()
            C_Timer.After(0.05, function()
                self:UpdateAllDividers()
            end)
        end)
    end

    for _, trackerName in ipairs(SUB_TRACKERS) do
        local tracker = _G[trackerName]
        if tracker then
            self:HookTracker(tracker)
        end
    end

    self:ApplyMasterHeaderVisibility()
end

local function IsQuestInCurrentZone(questID)
    if not questID then return false end
    local currentMap = _G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")
    if not currentMap then return false end

    if _G.C_TaskQuest and _G.C_TaskQuest.GetQuestZoneID then
        local qMap = _G.C_TaskQuest.GetQuestZoneID(questID)
        if qMap and qMap == currentMap then return true end
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetQuestTagInfo then
        local tag = _G.C_QuestLog.GetQuestTagInfo(questID)
        if tag and tag.mapID and tag.mapID == currentMap then return true end
    end
    return false
end

local function SortInfosByCurrentZone(infos)
    if not infos or #infos <= 1 then return infos end
    table.sort(infos, function(a, b)
        local qA = a.quest and (a.quest.questID or a.quest.id)
        local qB = b.quest and (b.quest.questID or b.quest.id)
        local inZoneA = IsQuestInCurrentZone(qA)
        local inZoneB = IsQuestInCurrentZone(qB)
        if inZoneA ~= inZoneB then
            return inZoneA
        end
        return (a.index or 0) < (b.index or 0)
    end)
    return infos
end

function ObjectivesMod:HookTracker(tracker)
    if not tracker or hookedTrackers[tracker] then return end
    hookedTrackers[tracker] = true

    if tracker.SetCollapsed and not self:IsHooked(tracker, "SetCollapsed") then
        self:SecureHook(tracker, "SetCollapsed", function()
            self:UpdateAllDividers()
        end)
    end

    if tracker.Header then
        self:SkinHeader(tracker.Header)
        if tracker.Header.SetCollapsed and not self:IsHooked(tracker.Header, "SetCollapsed") then
            self:SecureHook(tracker.Header, "SetCollapsed", function()
                self:UpdateAllDividers()
            end)
        end
        if tracker.Header.MinimizeButton and tracker.Header.MinimizeButton.HookScript then
            tracker.Header.MinimizeButton:HookScript("OnClick", function()
                C_Timer.After(0.05, function()
                    self:UpdateAllDividers()
                end)
            end)
        end
    end

    -- If this tracker shares the UI-widget pool (Scenario / UIWidget), stop here!
    -- DO NOT skin child blocks (crucial taint protection).
    if SharesWidgetPool(tracker) then return end

    if tracker.BuildQuestWatchInfos and not tracker.roithiSortHooked then
        tracker.roithiSortHooked = true
        local origBuild = tracker.BuildQuestWatchInfos
        tracker.BuildQuestWatchInfos = function(t)
            local infos = origBuild(t)
            if self.db and self.db.sortQuestsByZone and infos and #infos > 1 then
                SortInfosByCurrentZone(infos)
            end
            return infos
        end
    end

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
                self:UpdateAllDividers()
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
        local font = self:GetFontPath()
        local size = self.db.headerFontSize or 13
        local outline = self.db.fontOutline or "OUTLINE"
        pcall(text.SetFont, text, font, size, outline)

        local hc = self.db.headerColor or self.defaultSettings.headerColor
        text:SetTextColor(hc.r or 0.05, hc.g or 0.82, hc.b or 0.61, 1.0)
    end

    self:EnsureAccentDivider(header)
end

local function ShouldShowDivider(header)
    if not header or not header:IsShown() then return false end
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not otf:IsShown() then return false end
    if (otf.IsCollapsed and otf:IsCollapsed()) or otf.isCollapsed then return false end

    -- Check if header belongs to a subtracker module
    local parent = header:GetParent()
    if parent then
        if (parent.IsCollapsed and parent:IsCollapsed()) or parent.isCollapsed then return false end
        if parent.hasVisibleBlocks == false then return false end
    end
    return true
end

function ObjectivesMod:UpdateAllDividers()
    for header, divider in pairs(headerDividers) do
        if divider then
            if not self.db.enabled or not self.db.showAccentDivider then
                divider:Hide()
            else
                divider:SetShown(ShouldShowDivider(header))
            end
        end
    end
end

function ObjectivesMod:GetAccentDivider(header)
    return header and headerDividers[header]
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
        divider = header:CreateTexture(nil, "OVERLAY")
        divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -2)
        divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, -2)
        headerDividers[header] = divider
    end

    local thickness = self.db.dividerThickness or 1
    divider:SetHeight(thickness)

    local hc = self.db.headerColor or self.defaultSettings.headerColor
    divider:SetColorTexture(hc.r or 0.05, hc.g or 0.82, hc.b or 0.61, 0.8)
    divider:SetShown(ShouldShowDivider(header))
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

local function GetQuestLevel(questID)
    if not questID then return nil end
    if _G.C_QuestLog and _G.C_QuestLog.GetQuestDifficultyLevel then
        local lvl = _G.C_QuestLog.GetQuestDifficultyLevel(questID)
        if lvl and lvl > 0 then return lvl end
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetLogIndexForQuestID and _G.C_QuestLog.GetInfo then
        local idx = _G.C_QuestLog.GetLogIndexForQuestID(questID)
        if idx then
            local info = _G.C_QuestLog.GetInfo(idx)
            if info and info.level and info.level > 0 then
                return info.level
            end
        end
    end
    if _G.GetQuestLogTitle and _G.GetNumQuestLogEntries then
        for i = 1, _G.GetNumQuestLogEntries() do
            local _, level, _, isHeader, _, _, _, id = _G.GetQuestLogTitle(i)
            if not isHeader and id == questID then
                if level and level > 0 then return level end
            end
        end
    end
    return nil
end

local function ApplyQuestLevelToTitle(block)
    if not block or not ObjectivesMod.db or not ObjectivesMod.db.showQuestLevel then return end
    local questID = block.id
    if not questID or type(questID) ~= "number" then return end
    local lvl = GetQuestLevel(questID)
    if not lvl or lvl <= 0 then return end
    local titleFS = block.HeaderText or GetBlockTitleFS(block)
    if titleFS and titleFS.GetText and titleFS.SetText then
        local curText = titleFS:GetText()
        if curText and curText ~= "" then
            local cleanText = curText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if cleanText:match("^%s*%[%d+%]") then
                return
            end
            titleFS:SetText(string.format("[%d] %s", lvl, curText))
        end
    end
end

local function ApplyQuestIconVisibility(block)
    if not block then return end
    if ObjectivesMod.db and ObjectivesMod.db.hideQuestIcon then
        if block.poiButton then
            block.poiButton:Hide()
            if block.poiButton.SetAlpha then block.poiButton:SetAlpha(0) end
        end
    end
end

local function UpdateBlockHoverObjectives(block, isHovered)
    if not block then return end
    if not ObjectivesMod.db or not ObjectivesMod.db.hoverObjectiveText then
        if block.lines then
            for _, line in pairs(block.lines) do
                if line then
                    if line.SetAlpha then line:SetAlpha(1) end
                    if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(1) end
                    if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(1) end
                    if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(1) end
                    if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(1) end
                end
            end
        end
        if block.ProgressBar and block.ProgressBar.SetAlpha then
            block.ProgressBar:SetAlpha(1)
        end
        return
    end

    local alpha = isHovered and 1 or 0
    if block.lines then
        for _, line in pairs(block.lines) do
            if line then
                if line.SetAlpha then line:SetAlpha(alpha) end
                if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(alpha) end
                if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(alpha) end
                if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(alpha) end
                if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(alpha) end
            end
        end
    end
    if block.ProgressBar and block.ProgressBar.SetAlpha then
        block.ProgressBar:SetAlpha(alpha)
    end

    if isHovered then
        local questID = block.id
        if questID and type(questID) == "number" and _G.GameTooltip then
            _G.GameTooltip:SetOwner(block, "ANCHOR_RIGHT")
            local title = (block.HeaderText and block.HeaderText:GetText()) or "Quest"
            _G.GameTooltip:SetText(title, 1, 0.85, 0.35)
            if _G.C_QuestLog and _G.C_QuestLog.GetQuestObjectives then
                local objs = _G.C_QuestLog.GetQuestObjectives(questID)
                if objs then
                    for _, obj in ipairs(objs) do
                        if obj.text and obj.text ~= "" then
                            local r, g, b = 0.8, 0.8, 0.8
                            if obj.finished then
                                r, g, b = 0.25, 1.0, 0.35
                            end
                            _G.GameTooltip:AddLine(" • " .. obj.text, r, g, b)
                        end
                    end
                end
            end
            _G.GameTooltip:Show()
        end
    else
        if _G.GameTooltip and _G.GameTooltip:GetOwner() == block then
            _G.GameTooltip:Hide()
        end
    end
end

function ObjectivesMod:SkinBlock(block)
    if not block or skinnedBlocks[block] then return end
    skinnedBlocks[block] = true

    local font = self:GetFontPath()
    local titleSize = self.db.titleFontSize or 12
    local outline = self.db.fontOutline or "OUTLINE"

    -- Style title fontstring
    local titleFS = GetBlockTitleFS(block)
    if titleFS then
        pcall(titleFS.SetFont, titleFS, font, titleSize, outline)
        local tc = self.db.titleColor or self.defaultSettings.titleColor
        titleFS:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
    end

    ApplyQuestLevelToTitle(block)
    if block.SetHeader and not self:IsHooked(block, "SetHeader") then
        self:SecureHook(block, "SetHeader", function(b)
            ApplyQuestLevelToTitle(b)
        end)
    end

    ApplyQuestIconVisibility(block)
    if block.AddPOIButton and not self:IsHooked(block, "AddPOIButton") then
        self:SecureHook(block, "AddPOIButton", function(b)
            ApplyQuestIconVisibility(b)
        end)
    end

    if block.AddObjective and not self:IsHooked(block, "AddObjective") then
        self:SecureHook(block, "AddObjective", function(b)
            if b.lines then
                for _, line in pairs(b.lines) do
                    self:StyleObjectiveLine(line)
                end
            end
            local isHovered = (b.IsMouseOver and b:IsMouseOver()) or (b.HeaderButton and b.HeaderButton.IsMouseOver and b.HeaderButton:IsMouseOver())
            UpdateBlockHoverObjectives(b, isHovered or false)
        end)
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

    if not block.roithiHoverHooked then
        block.roithiHoverHooked = true
        if block.EnableMouse then block:EnableMouse(true) end
        if block.HookScript then
            block:HookScript("OnEnter", function(b) UpdateBlockHoverObjectives(b, true) end)
            block:HookScript("OnLeave", function(b) UpdateBlockHoverObjectives(b, false) end)
        end
        if block.HeaderButton and block.HeaderButton.HookScript then
            block.HeaderButton:HookScript("OnEnter", function() UpdateBlockHoverObjectives(block, true) end)
            block.HeaderButton:HookScript("OnLeave", function() UpdateBlockHoverObjectives(block, false) end)
        end
    end
    local initHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
    UpdateBlockHoverObjectives(block, initHovered or false)
end

function ObjectivesMod:StyleObjectiveLine(line)
    if not line or not line.Text then return end
    local font = self:GetFontPath()
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

    for block in pairs(skinnedBlocks) do
        if type(block) == "table" and block.lines then
            local isHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
            UpdateBlockHoverObjectives(block, isHovered or false)
        end
    end
end

function ObjectivesMod:RefreshSettings()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Objectives or self.defaultSettings
    self:ApplyMasterHeaderVisibility()
    self:SkinAllExisting()
end
