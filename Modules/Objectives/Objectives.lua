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
    foreverColor = { r = 0.22, g = 0.74, b = 0.97, a = 1.0 }, -- Light blue (WoW Forever background)
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
    showForeverQuestInfinity = true,
    hoverObjectiveText = true,
    hideCompletedObjectives = false,
    collapseDelay = 0.25,
    pinnedQuests = {},
    showFocusIndicator = true,
    showCompletedQuestIndicator = true,
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

local GetBlockTitleFS
local ForEachBlockLine
local UpdateQuestLogData

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
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
    self:RegisterEvent("ZONE_CHANGED", "OnZoneChanged")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "OnZoneChanged")
    self:RegisterEvent("SUPER_TRACKING_CHANGED", "OnSuperTrackingChanged")
    self:RegisterEvent("QUEST_LOG_UPDATE", "OnQuestLogUpdate")
    self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", "OnQuestLogUpdate")
    self:RegisterEvent("QUEST_ACCEPTED", "OnQuestLogUpdate")
    self:RegisterEvent("QUEST_TURNED_IN", "OnQuestLogUpdate")
    self:RegisterEvent("QUEST_REMOVED", "OnQuestLogUpdate")
    self:RegisterEvent("QUEST_WATCH_UPDATE", "OnQuestLogUpdate")
end

function ObjectivesMod:OnRegenEnabled()
    self:CheckAutoCollapse()
    if self.pendingSuperTrackQuestID then
        local qid = self.pendingSuperTrackQuestID
        self.pendingSuperTrackQuestID = nil
        if _G.C_SuperTrack and _G.C_SuperTrack.SetSuperTrackedQuestID then
            _G.C_SuperTrack.SetSuperTrackedQuestID(qid)
        end
    end
end

function ObjectivesMod:OnSuperTrackingChanged()
    for block in pairs(skinnedBlocks) do
        if type(block) == "table" then
            self:ApplyQuestLevelToTitle(block)
        end
    end
end

function ObjectivesMod:OnQuestLogUpdate()
    UpdateQuestLogData()
    for block in pairs(skinnedBlocks) do
        if type(block) == "table" then
            self:ApplyQuestLevelToTitle(block)
            local initHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
            self:UpdateBlockHoverObjectives(block, initHovered or false)
        end
    end
end

function ObjectivesMod:RefreshTrackers()
    for block in pairs(skinnedBlocks) do
        if type(block) == "table" then
            self:ApplyQuestLevelToTitle(block)
            local titleFS = GetBlockTitleFS(block)
            if titleFS then
                pcall(titleFS.SetFont, titleFS, self:GetFontPath(), self.db.titleFontSize or 12, self.db.fontOutline or "OUTLINE")
            end
            ForEachBlockLine(block, function(line)
                self:StyleObjectiveLine(line)
            end)
            local initHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
            self:UpdateBlockHoverObjectives(block, initHovered or false)
        end
    end
end

function ObjectivesMod:OnZoneChanged()
    self:ApplyPosition()
    self:CheckAutoCollapse()
    UpdateQuestLogData()
    self:RefreshTrackers()
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
    if not otf or not self.db or not self.db.enabled then return end

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
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end

    -- Release ObjectiveTrackerFrame from Blizzard's RightManagedFrameContainer
    -- which forces a massive gap (-100px below MinimapCluster)
    otf.ignoreFramePositionManager = true
    otf.isRightManagedFrame = false
    local rmc = _G.GetRightManagedFrameContainer and _G.GetRightManagedFrameContainer()
    if rmc and rmc.RemoveManagedFrame then
        rmc:RemoveManagedFrame(otf)
    end
    if otf.GetParent and otf:GetParent() ~= UIParent then
        otf:SetParent(UIParent)
    end

    if not self.managedHooked and hooksecurefunc then
        if _G.UIParent_ManageFramePositions then
            hooksecurefunc("UIParent_ManageFramePositions", function()
                if not self.settingPosition and self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                    self:ApplyPosition()
                end
            end)
        end
        if rmc and rmc.UpdateManagedFrames then
            hooksecurefunc(rmc, "UpdateManagedFrames", function()
                if not self.settingPosition and self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                    self:ApplyPosition()
                end
            end)
        end
        self.managedHooked = true
    end

    if not self.positionHooked and hooksecurefunc then
        hooksecurefunc(otf, "SetPoint", function(_, _, relativeTo)
            if not self.settingPosition and self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                local mmMod = RoithiUI and RoithiUI.GetModule and RoithiUI:GetModule("Minimap", true)
                local expectedTarget = (mmMod and mmMod.dataTextBar and mmMod.dataTextBar:IsShown() and mmMod.db and mmMod.db.showDataTextBar and mmMod.db.dataTextPosition == "OUTSIDE" and mmMod.dataTextBar)
                    or (mmMod and mmMod.container)
                    or _G.RoithiMinimapDataTextBar or _G.RoithiMinimapContainer or _G.Minimap
                if relativeTo ~= expectedTarget then
                    self:ApplyPosition()
                end
            end
        end)
        self.positionHooked = true
    end

    if otf.UpdateHeight and not self.updateHeightHooked and hooksecurefunc then
        hooksecurefunc(otf, "UpdateHeight", function()
            if not self.settingHeight and self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                self:ApplyScaleAndHeight()
            end
        end)
        self.updateHeightHooked = true
    end

    if otf.ApplySystemAnchor and not self.applyAnchorHooked and hooksecurefunc then
        hooksecurefunc(otf, "ApplySystemAnchor", function()
            if not self.settingPosition and self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                self:ApplyPosition()
            end
        end)
        self.applyAnchorHooked = true
    end

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.editModeEventsRegistered then
        _G.EventRegistry:RegisterCallback("EditMode.Enter", function()
            if self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                self:ApplyPosition()
            end
        end, self)
        _G.EventRegistry:RegisterCallback("EditMode.Exit", function()
            if self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                self:ApplyPosition()
            end
        end, self)
        self.editModeEventsRegistered = true
    end

    if self.db.attachedToMinimap ~= false then
        if otf.SetClampedToScreen then otf:SetClampedToScreen(true) end
        local mmMod = RoithiUI and RoithiUI.GetModule and RoithiUI:GetModule("Minimap", true)
        local anchorTarget = nil
        if mmMod and mmMod.dataTextBar and mmMod.dataTextBar:IsShown() and (mmMod.db and mmMod.db.showDataTextBar and mmMod.db.dataTextPosition == "OUTSIDE") then
            anchorTarget = mmMod.dataTextBar
        elseif mmMod and mmMod.container and mmMod.container:IsShown() then
            anchorTarget = mmMod.container
        end
        if not anchorTarget then
            anchorTarget = _G.RoithiMinimapDataTextBar or _G.RoithiMinimapContainer or _G.Minimap
        end

        if anchorTarget and otf.ClearAllPoints and otf.SetPoint then
            self.settingPosition = true
            otf:ClearAllPoints()
            otf:SetPoint("TOPRIGHT", anchorTarget, "BOTTOMRIGHT", 0, -2)
            self.settingPosition = nil

            local mmWidth = (mmMod and mmMod.container and mmMod.container:GetWidth()) or anchorTarget:GetWidth() or 200
            if mmMod and mmMod.addonBar and mmMod.addonBar:IsShown() and (mmMod.db and mmMod.db.showAddonBar ~= false and mmMod.db.addonBarPosition ~= "SEPARATE" and mmMod.db.addonBarAttached ~= false) then
                local barWidth = (mmMod.GetAddonBarExpandedWidth and mmMod:GetAddonBarExpandedWidth())
                    or (mmMod.addonBar and mmMod.addonBar.expandedWidth)
                    or mmMod.addonBar:GetWidth()
                    or 30
                mmWidth = mmWidth + barWidth
            end
            if mmWidth > 50 and otf.SetWidth then
                otf:SetWidth(mmWidth)
            end

            for _, trackerName in ipairs(SUB_TRACKERS) do
                local tracker = _G[trackerName]
                if tracker then
                    tracker.blockOffsetX = 4
                    if tracker.SetWidth then tracker:SetWidth(mmWidth) end
                    if tracker.Header and tracker.Header.SetWidth then
                        tracker.Header:SetWidth(mmWidth)
                    end
                end
            end
            if otf.Header and otf.Header.SetWidth then otf.Header:SetWidth(mmWidth) end
            if otf.HeaderMenu and otf.HeaderMenu.SetWidth then otf.HeaderMenu:SetWidth(mmWidth) end
            self:UpdateAllDividers()
        end
    else
        if otf.SetClampedToScreen then otf:SetClampedToScreen(true) end
        if otf.ClearAllPoints and otf.SetPoint then
            local pt = self.db.point or "TOPRIGHT"
            local x = self.db.x or -50
            local y = self.db.y or -200
            self.settingPosition = true
            otf:ClearAllPoints()
            otf:SetPoint(pt, UIParent, pt, x, y)
            self.settingPosition = nil
            local customWidth = self.db.detachedWidth or self.db.width or 235
            if otf.SetWidth and customWidth > 50 then
                otf:SetWidth(customWidth)
            end

            for _, trackerName in ipairs(SUB_TRACKERS) do
                local tracker = _G[trackerName]
                if tracker then
                    tracker.blockOffsetX = 4
                    if tracker.SetWidth then tracker:SetWidth(customWidth) end
                    if tracker.Header and tracker.Header.SetWidth then
                        tracker.Header:SetWidth(customWidth)
                    end
                end
            end
            if otf.Header and otf.Header.SetWidth then otf.Header:SetWidth(customWidth) end
            if otf.HeaderMenu and otf.HeaderMenu.SetWidth then otf.HeaderMenu:SetWidth(customWidth) end
            self:UpdateAllDividers()
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
    if self.db.attachedToMinimap ~= false then
        local mmMod = RoithiUI and RoithiUI.GetModule and RoithiUI:GetModule("Minimap", true)
        local anchorTarget = nil
        if mmMod and mmMod.dataTextBar and mmMod.dataTextBar:IsShown() and (mmMod.db and mmMod.db.showDataTextBar and mmMod.db.dataTextPosition == "OUTSIDE") then
            anchorTarget = mmMod.dataTextBar
        elseif mmMod and mmMod.container and mmMod.container:IsShown() then
            anchorTarget = mmMod.container
        end
        if not anchorTarget then
            anchorTarget = _G.RoithiMinimapDataTextBar or _G.RoithiMinimapContainer or _G.Minimap
        end
        local screenH = (_G.UIParent and _G.UIParent:GetHeight()) or 768
        local bottomCoord = (anchorTarget and anchorTarget.GetBottom and anchorTarget:GetBottom())
        if not bottomCoord or bottomCoord <= 50 then
            bottomCoord = screenH - 240
        end
        local maxAllowedHeight = math.max(150, math.floor(bottomCoord - 20))
        otf.editModeHeight = maxAllowedHeight
        if otf.SetHeight then
            self.settingHeight = true
            otf:SetHeight(maxAllowedHeight)
            self.settingHeight = nil
        end
    elseif self.db.maxHeight and otf.SetHeight then
        otf.editModeHeight = self.db.maxHeight
        otf:SetHeight(self.db.maxHeight)
    end
end

function ObjectivesMod:OnPlayerEnteringWorld()
    C_Timer.After(0.3, function()
        if self.HookAllTrackers then
            self:HookAllTrackers()
        end
        if self.SkinAllExisting then
            self:SkinAllExisting()
        end
        if self.ApplyPosition then
            self:ApplyPosition()
        end
        if self.CheckAutoCollapse then
            self:CheckAutoCollapse()
        end
        if self.RefreshTrackers then
            self:RefreshTrackers()
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

    otf.defaultHideSelection = true
    if otf.Selection then
        otf.Selection:Hide()
        if otf.Selection.EnableMouse then otf.Selection:EnableMouse(false) end
    end

    otf.editModeName = L["Objective Tracker"] or "Objective Tracker"

    local defObj = (ns.Defaults and ns.Defaults.profile and ns.Defaults.profile.Objectives) or self.defaultSettings
    local defaults = { point = defObj.point or "TOPRIGHT", x = defObj.x or -50, y = defObj.y or -200 }

    local function OnPositionChanged(f, _, point, x, y)
        if self.db.attachedToMinimap ~= false then
            self:ApplyPosition()
            if LEM and LEM.RefreshFrameSettings and _G.ObjectiveTrackerFrame then
                LEM:RefreshFrameSettings(_G.ObjectiveTrackerFrame)
            end
            return
        end
        self.db.point = point
        self.db.x = x
        self.db.y = y
        self.settingPosition = true
        f:ClearAllPoints()
        f:SetPoint(point, UIParent, point, x, y)
        self.settingPosition = nil
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

    if otf and otf.modules then
        for _, trackerModule in ipairs(otf.modules) do
            if trackerModule then
                self:HookTracker(trackerModule)
            end
        end
    end

    self:ApplyMasterHeaderVisibility()
end

local questZoneCache = {}
local questTitleCache = {}

local function WipeTable(tbl)
    if _G.wipe then
        _G.wipe(tbl)
    else
        for k in pairs(tbl) do
            tbl[k] = nil
        end
    end
    return tbl
end

local function SafeTrim(str)
    if not str then return "" end
    return (str:match("^%s*(.-)%s*$") or str)
end

function UpdateQuestLogData()
    WipeTable(questZoneCache)
    WipeTable(questTitleCache)
    local numEntries = (_G.C_QuestLog and _G.C_QuestLog.GetNumQuestLogEntries and _G.C_QuestLog.GetNumQuestLogEntries())
        or (_G.GetNumQuestLogEntries and _G.GetNumQuestLogEntries())
        or 0

    local currentHeader = ""
    for i = 1, numEntries do
        if _G.C_QuestLog and _G.C_QuestLog.GetInfo then
            local info = _G.C_QuestLog.GetInfo(i)
            if info then
                if info.isHeader then
                    currentHeader = info.title or ""
                elseif info.questID and info.questID > 0 then
                    questZoneCache[info.questID] = currentHeader
                    if info.title and info.title ~= "" then
                        questTitleCache[info.questID] = info.title
                    end
                end
            end
        elseif _G.GetQuestLogTitle then
            local title, _, _, isHeader, _, _, _, questID = _G.GetQuestLogTitle(i)
            if isHeader then
                currentHeader = title or ""
            elseif questID and questID > 0 then
                questZoneCache[questID] = currentHeader
                if title and title ~= "" then
                    questTitleCache[questID] = title
                end
            end
        end
    end
end

local function GetQuestZone(questID)
    if not questID then return "" end
    if _G.C_QuestLog and _G.C_QuestLog.GetHeaderIndexForQuest then
        local headerIndex = _G.C_QuestLog.GetHeaderIndexForQuest(questID)
        if headerIndex then
            local info = _G.C_QuestLog.GetInfo and _G.C_QuestLog.GetInfo(headerIndex)
            if info and info.title and info.title ~= "" then
                return info.title
            end
        end
    end
    if questZoneCache[questID] and questZoneCache[questID] ~= "" then
        return questZoneCache[questID]
    end
    return ""
end

local function GetCurrentZoneHierarchy()
    local subzoneNames = {}
    local zoneNames = {}
    local subZone = _G.GetSubZoneText and _G.GetSubZoneText()
    if subZone and subZone ~= "" then
        subzoneNames[string.lower(SafeTrim(subZone))] = true
    end

    local realZone = _G.GetRealZoneText and _G.GetRealZoneText()
    if realZone and realZone ~= "" then
        zoneNames[string.lower(SafeTrim(realZone))] = true
    end
    local zone = _G.GetZoneText and _G.GetZoneText()
    if zone and zone ~= "" then
        zoneNames[string.lower(SafeTrim(zone))] = true
    end

    local currentMapID = _G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")
    local parentMapID = nil
    if currentMapID and _G.C_Map and _G.C_Map.GetMapInfo then
        local mapInfo = _G.C_Map.GetMapInfo(currentMapID)
        if mapInfo then
            if mapInfo.name and mapInfo.name ~= "" then
                subzoneNames[string.lower(SafeTrim(mapInfo.name))] = true
            end
            if mapInfo.parentMapID and mapInfo.parentMapID > 0 then
                parentMapID = mapInfo.parentMapID
                local parentInfo = _G.C_Map.GetMapInfo(parentMapID)
                if parentInfo and parentInfo.name and parentInfo.name ~= "" then
                    zoneNames[string.lower(SafeTrim(parentInfo.name))] = true
                end
            end
        end
    end

    return subzoneNames, zoneNames, currentMapID, parentMapID
end

local function GetQuestMapID(questID)
    if not questID then return nil end
    if _G.C_TaskQuest and _G.C_TaskQuest.GetQuestZoneID then
        local qMap = _G.C_TaskQuest.GetQuestZoneID(questID)
        if qMap and qMap > 0 then return qMap end
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetMapForQuestPOIs then
        local pMap = _G.C_QuestLog.GetMapForQuestPOIs(questID)
        if pMap and pMap > 0 then return pMap end
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetQuestTagInfo then
        local tag = _G.C_QuestLog.GetQuestTagInfo(questID)
        if tag and tag.mapID and tag.mapID > 0 then return tag.mapID end
    end
    return nil
end

local function IsQuestEntryComplete(questID, questObj)
    if questObj and questObj.IsComplete and type(questObj.IsComplete) == "function" then
        local comp = questObj:IsComplete()
        if comp ~= nil then return (comp == true or comp == 1) end
    end
    if ObjectivesMod and ObjectivesMod.IsQuestComplete then
        return ObjectivesMod:IsQuestComplete(questID)
    end
    return false
end

local function GetQuestSortTitle(questID, questObj)
    if questObj and questObj.title and questObj.title ~= "" then
        return questObj.title
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetTitleForQuestID then
        local t = _G.C_QuestLog.GetTitleForQuestID(questID)
        if t and t ~= "" then return t end
    end
    if questTitleCache[questID] and questTitleCache[questID] ~= "" then
        return questTitleCache[questID]
    end
    return ""
end

local function GetQuestSortTier(questID, questZone, questObj, subzoneNames, zoneNames, currentMapID, parentMapID)
    local isComplete = IsQuestEntryComplete(questID, questObj)
    local qMap = GetQuestMapID(questID)
    local cleanZone = questZone and string.lower(SafeTrim(questZone)) or ""

    local inSubzone = (currentMapID and qMap == currentMapID) or (cleanZone ~= "" and subzoneNames and subzoneNames[cleanZone])
    if inSubzone then
        return isComplete and 2 or 1
    end

    local inZone = (parentMapID and qMap == parentMapID) or (cleanZone ~= "" and zoneNames and zoneNames[cleanZone])
    if inZone then
        return isComplete and 4 or 3
    end

    return isComplete and 6 or 5
end

local function GetQuestLevel(questID)
    if not questID then return 0 end
    if _G.C_QuestLog and _G.C_QuestLog.GetQuestDifficultyLevel then
        local lvl = _G.C_QuestLog.GetQuestDifficultyLevel(questID)
        if lvl and lvl > 0 then return lvl end
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetQuestLevel then
        local lvl = _G.C_QuestLog.GetQuestLevel(questID)
        if lvl and lvl > 0 then return lvl end
    end
    return 0
end

local function SortInfosByCurrentZone(infos)
    if not infos or #infos <= 1 then return infos end

    UpdateQuestLogData()
    local subzoneNames, zoneNames, currentMapID, parentMapID = GetCurrentZoneHierarchy()

    local meta = {}
    for index, item in ipairs(infos) do
        local qObj = item.quest
        local qID = (type(qObj) == "table" and (qObj.questID or qObj.id))
            or (type(item) == "table" and (item.questID or item.id))
        local zName = GetQuestZone(qID)
        local tier = GetQuestSortTier(qID, zName, qObj, subzoneNames, zoneNames, currentMapID, parentMapID)
        local title = GetQuestSortTitle(qID, qObj)
        local level = GetQuestLevel(qID)
        meta[item] = {
            tier = tier,
            level = level,
            zone = zName or "",
            title = title or "",
            index = item.index or index,
        }
    end

    table.sort(infos, function(a, b)
        local mA = meta[a]
        local mB = meta[b]
        if not mA or not mB then
            return (a.index or 0) < (b.index or 0)
        end

        -- 1. Compare tier (1: Subzone Incomplete, 2: Subzone Complete, 3: Parent Zone Incomplete, 4: Parent Zone Complete, 5: Other Incomplete, 6: Other Complete)
        if mA.tier ~= mB.tier then
            return mA.tier < mB.tier
        end

        -- 2. Within the same tier, sort level ascending (lower level on top, higher level at bottom)
        if mA.level ~= mB.level then
            if mA.level == 0 then return false end
            if mB.level == 0 then return true end
            return mA.level < mB.level
        end

        -- 3. Within same tier & level, sort zone alphabetically for other zones
        if mA.tier >= 5 and mA.zone ~= mB.zone then
            if mA.zone == "" then return false end
            if mB.zone == "" then return true end
            local lowerZoneA = string.lower(mA.zone)
            local lowerZoneB = string.lower(mB.zone)
            if lowerZoneA ~= lowerZoneB then
                return lowerZoneA < lowerZoneB
            end
        end

        -- 4. Within the same tier, level, and zone, sort alphabetically by title
        if mA.title ~= mB.title and mA.title ~= "" and mB.title ~= "" then
            local lowerTitleA = string.lower(mA.title)
            local lowerTitleB = string.lower(mB.title)
            if lowerTitleA ~= lowerTitleB then
                return lowerTitleA < lowerTitleB
            end
        end

        -- 5. Stable fallback to watch index
        return mA.index < mB.index
    end)

    return infos
end

local function IsQuestInCurrentZone(questID, questZone)
    local subzoneNames, zoneNames, currentMapID, parentMapID = GetCurrentZoneHierarchy()
    local tier = GetQuestSortTier(questID, questZone, nil, subzoneNames, zoneNames, currentMapID, parentMapID)
    return tier <= 4
end

ObjectivesMod.GetQuestSortTier = GetQuestSortTier
ObjectivesMod.GetQuestZone = GetQuestZone
ObjectivesMod.IsQuestInCurrentZone = IsQuestInCurrentZone
ObjectivesMod.SortInfosByCurrentZone = SortInfosByCurrentZone
ObjectivesMod.UpdateQuestLogData = UpdateQuestLogData

local function GetBlockHeaderHeight(b)
    if not b or not b.HeaderText then return 16 end
    if b.HeaderText.GetStringHeight then
        local sh = b.HeaderText:GetStringHeight()
        if sh and sh > 0 then return sh end
    end
    if b.HeaderText.GetHeight then
        local h = b.HeaderText:GetHeight()
        if h and h > 0 then return h end
    end
    return 16
end

function ForEachBlockLine(block, func)
    if not block or not func then return end
    local seen = {}
    if block.usedLines then
        for _, line in pairs(block.usedLines) do
            if line and not seen[line] then
                seen[line] = true
                func(line)
            end
        end
    end
    if block.lines then
        for _, line in pairs(block.lines) do
            if line and not seen[line] then
                seen[line] = true
                func(line)
            end
        end
    end
end

function ObjectivesMod:HookTracker(tracker)
    if not tracker or hookedTrackers[tracker] then return end
    hookedTrackers[tracker] = true

    tracker.blockOffsetX = 4
    if self.db and self.db.hoverObjectiveText then
        tracker.fromBlockOffsetY = -4
    end

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

    tracker.blockOffsetX = 4
    tracker.fromHeaderOffsetY = -10

    if tracker.LayoutBlock and not self:IsHooked(tracker, "LayoutBlock") then
        self:RawHook(tracker, "LayoutBlock", function(t, block)
            if block and self.db and self.db.hoverObjectiveText then
                local isPinned = self:IsQuestPinned(block)
                if not isPinned then
                    local headerHeight = GetBlockHeaderHeight(block)
                    block.height = headerHeight
                    if block.SetHeight then block:SetHeight(headerHeight) end
                    ForEachBlockLine(block, function(line)
                        if line.Hide then line:Hide() end
                        if line.SetHeight then line:SetHeight(0.001) end
                        if line.SetAlpha then line:SetAlpha(0) end
                    end)
                    if block.ProgressBar then
                        if block.ProgressBar.Hide then block.ProgressBar:Hide() end
                        if block.ProgressBar.SetHeight then block.ProgressBar:SetHeight(0.001) end
                        if block.ProgressBar.SetAlpha then block.ProgressBar:SetAlpha(0) end
                    end
                end
            end
            return self.hooks[tracker].LayoutBlock(t, block)
        end, true)
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
                local otf = _G.ObjectiveTrackerFrame
                local targetWidth = (otf and otf.GetWidth and otf:GetWidth())
                if targetWidth and targetWidth > 50 then
                    if tracker.SetWidth then tracker:SetWidth(targetWidth) end
                    if tracker.Header and tracker.Header.SetWidth then
                        tracker.Header:SetWidth(targetWidth)
                    end
                end
                if tracker.Header then
                    self:EnsureAccentDivider(tracker.Header)
                    self:SkinHeader(tracker.Header)
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

    -- Adjust header width to ObjectiveTrackerFrame container so MinimizeButton lines up perfectly
    local otf = _G.ObjectiveTrackerFrame
    local targetWidth = (otf and otf.GetWidth and otf:GetWidth())
    if not targetWidth or targetWidth < 50 then
        local parent = header:GetParent()
        targetWidth = (parent and parent.GetWidth and parent:GetWidth()) or 235
    end
    if targetWidth and targetWidth > 50 then
        header:SetWidth(targetWidth)
        local parent = header:GetParent()
        if parent and parent ~= otf and parent.SetWidth then
            parent:SetWidth(targetWidth)
        end
    end

    -- Position and ensure minimize button is visible and aligned
    local mb = header.MinimizeButton
    if mb then
        mb:ClearAllPoints()
        local isMaster = (otf and (header == otf.Header or header == otf.HeaderMenu))
        local xOffset = isMaster and -2 or -3
        mb:SetPoint("RIGHT", header, "RIGHT", xOffset, 0)
        mb:Show()
    end

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
                if region ~= (mb and mb:GetNormalTexture())
                   and region ~= (mb and mb:GetPushedTexture())
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

        text:ClearAllPoints()
        text:SetPoint("LEFT", header, "LEFT", 4, 0)
        if mb then
            text:SetPoint("RIGHT", mb, "LEFT", -4, 0)
        else
            text:SetPoint("RIGHT", header, "RIGHT", -4, 0)
        end
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
function GetBlockTitleFS(block)
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

local function IsForeverQuest(questID)
    -- The infinity icon is strictly for Classic Season of Discovery / "Forever" servers, never Retail
    if ns.IsRetail or (_G.WOW_PROJECT_ID and _G.WOW_PROJECT_MAINLINE and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE) then
        return false
    end
    if not questID or type(questID) ~= "number" then return false end
    -- Classic 1.12 original quests were sequentially numbered <= 9550.
    -- Quests added specifically in "Forever" / Season of Discovery use quest IDs > 9550 (typically 70000+).
    if _G.GetQuestExpansion then
        local exp = _G.GetQuestExpansion(questID)
        if exp and exp > 0 then
            return true
        end
    end
    return questID > 9550
end

function ObjectivesMod:GetBlockQuestID(block)
    if not block then return nil end
    if type(block) == "number" then return block end
    return block.id or block.questID or (block.quest and (block.quest.questID or block.quest.id))
end

function ObjectivesMod:IsQuestPinned(block)
    local qid = self:GetBlockQuestID(block)
    if not qid or not self.db or not self.db.pinnedQuests then return false end
    return self.db.pinnedQuests[qid] == true
end

function ObjectivesMod:TogglePinQuest(block)
    local qid = self:GetBlockQuestID(block)
    if not qid or not self.db then return false end
    self.db.pinnedQuests = self.db.pinnedQuests or {}
    if self.db.pinnedQuests[qid] then
        self.db.pinnedQuests[qid] = nil
    else
        self.db.pinnedQuests[qid] = true
    end
    if type(block) == "table" then
        self:ApplyQuestLevelToTitle(block)
        local isHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
        if self.UpdateBlockHoverObjectives then
            self:UpdateBlockHoverObjectives(block, isHovered or false)
        end
        if block.parentModule and block.parentModule.MarkDirty then
            block.parentModule:MarkDirty()
        end
    else
        for b in pairs(skinnedBlocks) do
            if type(b) == "table" and self:GetBlockQuestID(b) == qid then
                self:ApplyQuestLevelToTitle(b)
                local isHovered = (b.IsMouseOver and b:IsMouseOver()) or (b.HeaderButton and b.HeaderButton.IsMouseOver and b.HeaderButton:IsMouseOver())
                if self.UpdateBlockHoverObjectives then
                    self:UpdateBlockHoverObjectives(b, isHovered or false)
                end
                if b.parentModule and b.parentModule.MarkDirty then
                    b.parentModule:MarkDirty()
                end
            end
        end
    end
    return self.db.pinnedQuests[qid] == true
end

function ObjectivesMod:ToggleSuperTrackQuest(block)
    local qid = self:GetBlockQuestID(block)
    if not qid then return end
    if _G.C_SuperTrack and _G.C_SuperTrack.GetSuperTrackedQuestID and _G.C_SuperTrack.SetSuperTrackedQuestID then
        local current = _G.C_SuperTrack.GetSuperTrackedQuestID()
        local targetID = (current == qid) and 0 or qid
        if _G.InCombatLockdown and _G.InCombatLockdown() then
            self.pendingSuperTrackQuestID = targetID
            return
        end
        _G.C_SuperTrack.SetSuperTrackedQuestID(targetID)
        if type(block) == "table" then
            self:ApplyQuestLevelToTitle(block)
        else
            for b in pairs(skinnedBlocks) do
                if type(b) == "table" and self:GetBlockQuestID(b) == qid then
                    self:ApplyQuestLevelToTitle(b)
                end
            end
        end
    end
end

function ObjectivesMod:IsQuestComplete(questID, block)
    local qid = questID or self:GetBlockQuestID(block)
    if not qid then return false end
    if block then
        if block.poiIsComplete then return true end
        if block.quest and block.quest.IsComplete and block.quest:IsComplete() then return true end
    end
    if _G.C_QuestLog then
        if _G.C_QuestLog.IsComplete and _G.C_QuestLog.IsComplete(qid) then
            return true
        end
        if _G.C_QuestLog.ReadyForTurnIn and _G.C_QuestLog.ReadyForTurnIn(qid) then
            return true
        end
        if _G.C_QuestLog.GetLogIndexForQuestID and _G.C_QuestLog.GetInfo then
            local idx = _G.C_QuestLog.GetLogIndexForQuestID(qid)
            if idx then
                local info = _G.C_QuestLog.GetInfo(idx)
                if info and (info.isComplete == true or info.isComplete == 1) then
                    return true
                end
            end
        end
    end
    if _G.GetNumQuestLogEntries and _G.GetQuestLogTitle then
        for i = 1, _G.GetNumQuestLogEntries() do
            local _, _, _, isHeader, _, isComplete, _, id = _G.GetQuestLogTitle(i)
            if not isHeader and id == qid then
                if isComplete == 1 or isComplete == true then
                    return true
                end
            end
        end
    end
    return false
end

local CHECKMARK_TEXTURE = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t "
local TRACKED_TEXTURE = "|TInterface\\ChatFrame\\ChatFrameExpandArrow:10:10:0:0|t "

local function GetCleanQuestTitle(block, questID, curText)
    -- 1. Try modern C_QuestLog title API
    if _G.C_QuestLog and _G.C_QuestLog.GetTitleForQuestID then
        local t = _G.C_QuestLog.GetTitleForQuestID(questID)
        if t and t ~= "" then
            if block then
                block.roithiBaseTitle = t
                block.roithiQuestID = questID
            end
            return t
        end
    end

    -- 2. Try QuestCache (Blizzard Objective Tracker cache)
    if _G.QuestCache and _G.QuestCache.Get then
        local q = _G.QuestCache:Get(questID)
        if q and q.title and q.title ~= "" then
            if block then
                block.roithiBaseTitle = q.title
                block.roithiQuestID = questID
            end
            return q.title
        end
    end

    -- 3. Try block.quest.title (Blizzard block property)
    if block and block.quest and block.quest.title and block.quest.title ~= "" then
        block.roithiBaseTitle = block.quest.title
        block.roithiQuestID = questID
        return block.quest.title
    end

    -- 4. Try Classic Quest Log entries (GetQuestLogTitle)
    if _G.GetNumQuestLogEntries and _G.GetQuestLogTitle then
        local numEntries = _G.GetNumQuestLogEntries()
        for i = 1, numEntries do
            local qTitle, _, _, isHeader, _, _, _, id = _G.GetQuestLogTitle(i)
            if not isHeader and id == questID and qTitle and qTitle ~= "" then
                if block then
                    block.roithiBaseTitle = qTitle
                    block.roithiQuestID = questID
                end
                return qTitle
            end
        end
    end

    -- 5. Try C_QuestLog.GetInfo(logIndex)
    if _G.C_QuestLog and _G.C_QuestLog.GetLogIndexForQuestID and _G.C_QuestLog.GetInfo then
        local logIndex = _G.C_QuestLog.GetLogIndexForQuestID(questID)
        if logIndex and logIndex > 0 then
            local info = _G.C_QuestLog.GetInfo(logIndex)
            if info and info.title and info.title ~= "" then
                if block then
                    block.roithiBaseTitle = info.title
                    block.roithiQuestID = questID
                end
                return info.title
            end
        end
    end

    -- 6. Check block cached base title if matched to same questID
    if block and block.roithiBaseTitle and block.roithiQuestID == questID then
        return block.roithiBaseTitle
    end

    if not curText or curText == "" then return "" end

    local baseText = curText
    -- Strip color codes and escape sequences
    baseText = baseText:gsub("|c%x%x%x%x%x%x%x%x", "")
    baseText = baseText:gsub("|r", "")
    baseText = baseText:gsub("|T.-|t", "")
    baseText = baseText:gsub("|A.-|a", "")
    baseText = baseText:gsub("^%s+", "")

    -- Thoroughly strip markers and levels in a loop
    local stripped
    repeat
        stripped = false
        -- Arrow ► (\226\150\186)
        local s, n = baseText:gsub("^\226\150\186%s*", "")
        if n > 0 then baseText = s; stripped = true end
        -- Pin *
        s, n = baseText:gsub("^%*%s*", "")
        if n > 0 then baseText = s; stripped = true end
        -- Checkmarks ✔ (\226\156\148), ✓ (\226\156\147)
        s, n = baseText:gsub("^\226\156\148%s*", "")
        if n > 0 then baseText = s; stripped = true end
        s, n = baseText:gsub("^\226\156\147%s*", "")
        if n > 0 then baseText = s; stripped = true end
        -- Infinity ∞ (\226\136\158)
        s, n = baseText:gsub("^\226\136\158%s*", "")
        if n > 0 then baseText = s; stripped = true end
        -- Level [number] e.g. [25] - strips repeated levels
        s, n = baseText:gsub("^%[%d+%]%s*", "")
        if n > 0 then baseText = s; stripped = true end
        -- Strip any extra whitespace
        s, n = baseText:gsub("^%s+", "")
        if n > 0 then baseText = s; stripped = true end
    until not stripped

    baseText = baseText:gsub("%s+$", "")

    if block then
        block.roithiBaseTitle = baseText
        block.roithiQuestID = questID
    end
    return baseText
end

function ObjectivesMod:ApplyQuestLevelToTitle(block)
    if not block or not self.db then return end
    local questID = self:GetBlockQuestID(block)
    if not questID or type(questID) ~= "number" then return end

    local titleFS = block.HeaderText or GetBlockTitleFS(block)
    if not (titleFS and titleFS.GetText and titleFS.SetText) then return end

    local curText = titleFS:GetText()
    if not curText or curText == "" then return end

    local lvl = GetQuestLevel(questID)

    -- Extract difficulty color via API or fallback from curText
    local colorCode = nil
    if lvl and lvl > 0 and _G.GetQuestDifficultyColor then
        local diff = _G.GetQuestDifficultyColor(lvl)
        if diff and diff.r then
            colorCode = string.format("|cff%02x%02x%02x", math.floor((diff.r or 1) * 255 + 0.5), math.floor((diff.g or 1) * 255 + 0.5), math.floor((diff.b or 1) * 255 + 0.5))
        end
    end
    if not colorCode then
        colorCode = curText:match("^(|c%x%x%x%x%x%x%x%x)")
    end

    local isNewQuest = IsForeverQuest(questID)
    local isRetail = ns.IsRetail or (_G.WOW_PROJECT_ID and _G.WOW_PROJECT_MAINLINE and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)
    local showInfinity = (not isRetail) and (self.db.showForeverQuestInfinity ~= false) and isNewQuest
    local showLevel = (self.db.showQuestLevel ~= false) and lvl and lvl > 0

    local isSuperTracked = false
    if self.db.showFocusIndicator ~= false and _G.C_SuperTrack and _G.C_SuperTrack.GetSuperTrackedQuestID then
        isSuperTracked = (_G.C_SuperTrack.GetSuperTrackedQuestID() == questID)
    end
    local isPinned = self:IsQuestPinned(questID)

    local isComplete = false
    if self.db.showCompletedQuestIndicator ~= false then
        isComplete = self:IsQuestComplete(questID, block)
    end

    local prefix = ""
    if isSuperTracked then
        prefix = prefix .. TRACKED_TEXTURE
    end
    if isPinned then
        prefix = prefix .. "|cffffd200*|r "
    end
    if isComplete then
        prefix = prefix .. CHECKMARK_TEXTURE
    end

    -- If curText was originally formatted with colored level e.g. |cffffd200[70]|r Defeat Onyxia:
    if curText:match("^|c%x%x%x%x%x%x%x%x%[%d+%]%|r") and not showInfinity and prefix == "" and not isComplete then
        return
    end

    local baseText = GetCleanQuestTitle(block, questID, curText)

    local compColor = self.db.completedColor or self.defaultSettings.completedColor or { r = 0.25, g = 1.0, b = 0.35 }
    local compHex = string.format("ff%02x%02x%02x", math.floor((compColor.r or 0.25) * 255 + 0.5), math.floor((compColor.g or 1.0) * 255 + 0.5), math.floor((compColor.b or 0.35) * 255 + 0.5))
    local activeColorCode = isComplete and ("|c" .. compHex) or colorCode

    local fc = self.db.foreverColor or self.defaultSettings.foreverColor or { r = 0.22, g = 0.74, b = 0.97 }
    local infinityHex = string.format("ff%02x%02x%02x", math.floor((fc.r or 0.22) * 255 + 0.5), math.floor((fc.g or 0.74) * 255 + 0.5), math.floor((fc.b or 0.97) * 255 + 0.5))
    local infinityStr = string.format("|c%s\226\136\158|r", infinityHex)

    local newText
    if activeColorCode then
        if showLevel and showInfinity then
            newText = string.format("%s%s[%d] %s%s %s|r", prefix, activeColorCode, lvl, infinityStr, activeColorCode, baseText)
        elseif showLevel then
            newText = string.format("%s%s[%d] %s|r", prefix, activeColorCode, lvl, baseText)
        elseif showInfinity then
            newText = string.format("%s%s %s%s|r", prefix, infinityStr, activeColorCode, baseText)
        else
            newText = string.format("%s%s%s|r", prefix, activeColorCode, baseText)
        end
    else
        if showLevel and showInfinity then
            newText = string.format("%s[%d] %s %s", prefix, lvl, infinityStr, baseText)
        elseif showLevel then
            newText = string.format("%s[%d] %s", prefix, lvl, baseText)
        elseif showInfinity then
            newText = string.format("%s%s %s", prefix, infinityStr, baseText)
        else
            newText = string.format("%s%s", prefix, baseText)
        end
    end

    if newText ~= curText then
        titleFS:SetText(newText)
    end
end

local function ApplyQuestLevelToTitle(block)
    ObjectivesMod:ApplyQuestLevelToTitle(block)
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

local function IsLineCompleted(line, block)
    if not line then return false end
    if line.isCompleted == true or line.completed == true or line.state == "Complete" then
        return true
    end
    if line.Check and line.Check.IsShown and line.Check:IsShown() then
        return true
    end
    local qid = block and (block.id or block.questID)
    if qid and line.objectiveIndex and _G.C_QuestLog and _G.C_QuestLog.GetQuestObjectives then
        local ok, objs = pcall(_G.C_QuestLog.GetQuestObjectives, qid)
        if ok and objs and objs[line.objectiveIndex] then
            return objs[line.objectiveIndex].finished == true
        end
    end
    return false
end

function ObjectivesMod:UpdateBlockHoverObjectives(block, isHovered)
    if not block then return end

    local isPinned = self:IsQuestPinned(block)
    local isExpanded = isHovered or isPinned
    local hoverMode = self.db and self.db.hoverObjectiveText
    local hideCompleted = self.db and self.db.hideCompletedObjectives

    local headerHeight = GetBlockHeaderHeight(block)
    local lineSpacing = (block.parentModule and block.parentModule.lineSpacing) or 2
    local fullHeight = headerHeight + 2

    ForEachBlockLine(block, function(line)
        local isComp = IsLineCompleted(line, block)
        if hideCompleted and isComp then
            if line.Hide then line:Hide() end
            if line.SetAlpha then line:SetAlpha(0) end
            if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(0) end
            if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(0) end
            if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(0) end
            if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(0) end
            if line.SetHeight then line:SetHeight(0.001) end
        elseif not hoverMode or isExpanded then
            if line.Show then line:Show() end
            if line.SetAlpha then line:SetAlpha(1) end
            if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(1) end
            if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(1) end
            if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(1) end
            if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(1) end
            local lh = line.roithiOrigHeight
            if not lh or lh <= 1 then
                if line.Text and line.Text.GetStringHeight then
                    lh = line.Text:GetStringHeight()
                end
                if not lh or lh <= 1 then
                    lh = (line.Text and line.Text.GetHeight and line.Text:GetHeight()) or 14
                end
            end
            if not lh or lh < 14 then lh = 14 end
            line.roithiOrigHeight = lh
            if line.SetHeight then line:SetHeight(lh) end
            fullHeight = fullHeight + lh + lineSpacing
        else
            if line.GetHeight then
                local currH = line:GetHeight()
                if currH and currH > 1 then
                    line.roithiOrigHeight = currH
                end
            end
            if line.Hide then line:Hide() end
            if line.SetAlpha then line:SetAlpha(0) end
            if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(0) end
            if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(0) end
            if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(0) end
            if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(0) end
            if line.SetHeight then line:SetHeight(0.001) end
        end
    end)

    if block.ProgressBar then
        if not hoverMode or isExpanded then
            local pbh = block.ProgressBar.roithiOrigHeight or (block.ProgressBar.GetHeight and block.ProgressBar:GetHeight()) or 16
            if pbh < 14 then pbh = 14 end
            if block.ProgressBar.SetHeight then block.ProgressBar:SetHeight(pbh) end
            if block.ProgressBar.Show then block.ProgressBar:Show() end
            if block.ProgressBar.SetAlpha then block.ProgressBar:SetAlpha(1) end
            fullHeight = fullHeight + pbh + lineSpacing
        else
            if block.ProgressBar.GetHeight then
                local currH = block.ProgressBar:GetHeight()
                if currH and currH > 1 then
                    block.ProgressBar.roithiOrigHeight = currH
                end
            end
            if block.ProgressBar.Hide then block.ProgressBar:Hide() end
            if block.ProgressBar.SetAlpha then block.ProgressBar:SetAlpha(0) end
            if block.ProgressBar.SetHeight then block.ProgressBar:SetHeight(0.001) end
        end
    end

    fullHeight = fullHeight + 2

    local oldHeight = block.height or GetBlockHeaderHeight(block)
    local newHeight = (not hoverMode or isExpanded) and fullHeight or headerHeight

    block.height = newHeight
    if block.SetHeight then block:SetHeight(newHeight) end

    local diff = newHeight - oldHeight
    if diff ~= 0 and block.parentModule then
        if block.parentModule.SetHeightModifier and block.parentModule.ClearHeightModifier then
            if isExpanded and diff > 0 then
                block.parentModule:SetHeightModifier(block, diff)
            else
                block.parentModule:ClearHeightModifier(block)
            end
        elseif block.parentModule.GetHeight and block.parentModule.SetHeight then
            local mHeight = block.parentModule:GetHeight()
            if mHeight and mHeight > 0 then
                block.parentModule:SetHeight(mHeight + diff)
            end
        end
    end

    -- Display full quest objectives in the tooltip when hovering
    if isHovered then
        local questID = self:GetBlockQuestID(block)
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
            _G.GameTooltip:AddLine(" ")
            local pinStatus = self:IsQuestPinned(questID) and "|cffff6060Unpin|r" or "|cff00ff00Pin (Keep Expanded)|r"
            _G.GameTooltip:AddDoubleLine("|cffffd200Ctrl + Click:|r", pinStatus, 0.7, 0.7, 0.7, 1, 1, 1)
            _G.GameTooltip:AddDoubleLine("|cffffd200Alt + Click / Middle-Click:|r", "|cff38bdf7Focus / Super-Track|r", 0.7, 0.7, 0.7, 1, 1, 1)
            _G.GameTooltip:Show()
        end
    else
        if _G.GameTooltip and _G.GameTooltip:GetOwner() == block then
            _G.GameTooltip:Hide()
        end
    end
end

local function UpdateBlockHoverObjectives(block, isHovered)
    ObjectivesMod:UpdateBlockHoverObjectives(block, isHovered)
end

local pendingCollapseBlock = nil
local collapseTimerToken = 0

local function CancelCollapseTimer()
    collapseTimerToken = collapseTimerToken + 1
    pendingCollapseBlock = nil
end

local function HandleBlockEnter(block)
    if not block then return end
    if pendingCollapseBlock and pendingCollapseBlock ~= block then
        local prevBlock = pendingCollapseBlock
        CancelCollapseTimer()
        UpdateBlockHoverObjectives(prevBlock, false)
    else
        CancelCollapseTimer()
    end
    UpdateBlockHoverObjectives(block, true)
end

local function HandleBlockLeave(block)
    if not block then return end
    if _G.GameTooltip and _G.GameTooltip:GetOwner() == block then
        _G.GameTooltip:Hide()
    end

    if ObjectivesMod:IsQuestPinned(block) then
        UpdateBlockHoverObjectives(block, false)
        return
    end

    local delay = (ObjectivesMod.db and ObjectivesMod.db.collapseDelay) or 0.25
    if delay <= 0 or not _G.C_Timer or not _G.C_Timer.After then
        UpdateBlockHoverObjectives(block, false)
        return
    end

    CancelCollapseTimer()
    pendingCollapseBlock = block
    local currentToken = collapseTimerToken
    _G.C_Timer.After(delay, function()
        if collapseTimerToken == currentToken and pendingCollapseBlock == block then
            pendingCollapseBlock = nil
            UpdateBlockHoverObjectives(block, false)
        end
    end)
end

local function HookOrSetScript(frame, script, handler)
    if not frame then return end
    if frame.HasScript and not frame:HasScript(script) then return end
    if frame.GetScript and frame:GetScript(script) then
        pcall(frame.HookScript, frame, script, handler)
    elseif frame.SetScript then
        pcall(frame.SetScript, frame, script, handler)
    end
end

local lastClickTime = 0
local lastClickBlock = nil
local function HandleBlockClick(block, mouseButton)
    if not block then return end
    local now = (_G.GetTime and _G.GetTime()) or 0
    if block == lastClickBlock and (now - lastClickTime) < 0.2 then
        return
    end
    if _G.IsControlKeyDown and _G.IsControlKeyDown() then
        lastClickTime = now
        lastClickBlock = block
        ObjectivesMod:TogglePinQuest(block)
    elseif (_G.IsAltKeyDown and _G.IsAltKeyDown()) or mouseButton == "MiddleButton" then
        lastClickTime = now
        lastClickBlock = block
        ObjectivesMod:ToggleSuperTrackQuest(block)
    end
end

function ObjectivesMod:SkinBlock(block)
    if not block or skinnedBlocks[block] then return end
    skinnedBlocks[block] = true

    local font = self:GetFontPath()
    local titleSize = self.db.titleFontSize or 12
    local outline = self.db.fontOutline or "OUTLINE"

    -- Align quest block with the header text
    block.offsetX = 4

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
            ForEachBlockLine(b, function(line)
                self:StyleObjectiveLine(line)
            end)
            local isHovered = (b.IsMouseOver and b:IsMouseOver()) or (b.HeaderButton and b.HeaderButton.IsMouseOver and b.HeaderButton:IsMouseOver())
            UpdateBlockHoverObjectives(b, isHovered or false)
        end)
    end

    -- Style objective lines
    ForEachBlockLine(block, function(line)
        self:StyleObjectiveLine(line)
    end)

    -- Style progress bars
    if self.db.skinProgressBars and block.ProgressBar then
        self:SkinProgressBar(block.ProgressBar)
    end

    if not block.roithiHoverHooked then
        block.roithiHoverHooked = true
        if block.EnableMouse then block:EnableMouse(true) end
        if block.HookScript then
            block:HookScript("OnEnter", function(b) HandleBlockEnter(b) end)
            block:HookScript("OnLeave", function(b) HandleBlockLeave(b) end)
        end
        HookOrSetScript(block, "OnMouseDown", function(b, btn)
            if btn == "MiddleButton" or (_G.IsAltKeyDown and _G.IsAltKeyDown()) or (_G.IsControlKeyDown and _G.IsControlKeyDown()) then
                HandleBlockClick(b, btn)
            end
        end)
        if block.HeaderButton then
            if block.HeaderButton.HookScript then
                block.HeaderButton:HookScript("OnEnter", function() HandleBlockEnter(block) end)
                block.HeaderButton:HookScript("OnLeave", function() HandleBlockLeave(block) end)
                block.HeaderButton:HookScript("OnClick", function(_, btn)
                    HandleBlockClick(block, btn)
                end)
            end
            HookOrSetScript(block.HeaderButton, "OnMouseDown", function(_, btn)
                if btn == "MiddleButton" or (_G.IsAltKeyDown and _G.IsAltKeyDown()) or (_G.IsControlKeyDown and _G.IsControlKeyDown()) then
                    HandleBlockClick(block, btn)
                end
            end)
        end
    end
    local itemBtn = block.itemButton or block.ItemButton or (block.GetItemButton and block:GetItemButton())
    if itemBtn then
        if itemBtn.SetFrameLevel and block.GetFrameLevel then
            itemBtn:SetFrameLevel(block:GetFrameLevel() + 20)
        end
        if itemBtn.EnableMouse then itemBtn:EnableMouse(true) end
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

    local lineItem = line.itemButton or line.ItemButton or (line.GetItemButton and line:GetItemButton())
    if lineItem then
        if lineItem.SetFrameLevel and line.GetFrameLevel then
            lineItem:SetFrameLevel(line:GetFrameLevel() + 20)
        end
        if lineItem.EnableMouse then lineItem:EnableMouse(true) end
    end

    if not line.roithiClickHooked and line.EnableMouse then
        line.roithiClickHooked = true
        line:EnableMouse(true)
        HookOrSetScript(line, "OnMouseDown", function(_, btn)
            if btn == "MiddleButton" or (_G.IsAltKeyDown and _G.IsAltKeyDown()) or (_G.IsControlKeyDown and _G.IsControlKeyDown()) then
                local b = line.parentBlock or (line.GetParent and line:GetParent())
                if b then
                    HandleBlockClick(b, btn)
                end
            end
        end)
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
            tracker.blockOffsetX = 4
            tracker.fromHeaderOffsetY = -10
            if tracker.Header then
                self:SkinHeader(tracker.Header)
            end
            self:SkinExistingBlocks(tracker)
        end
    end

    for block in pairs(skinnedBlocks) do
        if type(block) == "table" then
            ApplyQuestLevelToTitle(block)
            ApplyQuestIconVisibility(block)
            if block.lines then
                local isHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
                UpdateBlockHoverObjectives(block, isHovered or false)
            end
        end
    end
end

function ObjectivesMod:RefreshSettings()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Objectives or self.defaultSettings
    self:ApplyPosition()
    self:ApplyMasterHeaderVisibility()
    self:SkinAllExisting()
    for _, trackerName in ipairs(SUB_TRACKERS) do
        local tracker = _G[trackerName]
        if tracker then
            tracker.blockOffsetX = 4
            if self.db and self.db.hoverObjectiveText then
                tracker.fromBlockOffsetY = -4
            else
                tracker.fromBlockOffsetY = -10
            end
        end
    end
    if LEM and LEM.RefreshFrameSettings and _G.ObjectiveTrackerFrame then
        LEM:RefreshFrameSettings(_G.ObjectiveTrackerFrame)
    end
end
ObjectivesMod.RefreshProfile = ObjectivesMod.RefreshSettings
