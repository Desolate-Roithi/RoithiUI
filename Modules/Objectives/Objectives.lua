local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:NewModule("Objectives", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LEM = LibStub("LibEditMode-Roithi", true)

ObjectivesMod.displayName = L["Objectives"] or "Objectives"
ObjectivesMod.description = L["Modern restyling for the Blizzard Objective Tracker with clean typography and status bars."] or "Modern restyling for the Blizzard Objective Tracker with clean typography and status bars."
ObjectivesMod.order = 87
ObjectivesMod.dbKey = "Objectives"
ObjectivesMod.defaultSettings = ns.ObjectivesDefaults or (ns.Defaults and ns.Defaults.profile and ns.Defaults.profile.Objectives)

-- Shared module state registry
local objState = ns.Objectives or {}
ns.Objectives = objState

objState.skinnedBlocks = setmetatable({}, { __mode = "k" })
objState.skinnedBars = setmetatable({}, { __mode = "k" })
objState.hookedTrackers = setmetatable({}, { __mode = "k" })
objState.headerDividers = setmetatable({}, { __mode = "k" })
objState.titleFSCache = setmetatable({}, { __mode = "k" })

local function ForEachTrackerBlock(tracker, callback)
    if not tracker or not callback then return end
    if tracker.EnumerateActiveBlocks then
        tracker:EnumerateActiveBlocks(callback)
        return
    end
    if tracker.usedBlocks then
        for _, val in pairs(tracker.usedBlocks) do
            if type(val) == "table" then
                if val.IsObjectType or val.GetObjectType or val.SetPoint then
                    callback(val)
                else
                    for _, subBlock in pairs(val) do
                        if type(subBlock) == "table" and (subBlock.IsObjectType or subBlock.GetObjectType or subBlock.SetPoint) then
                            callback(subBlock)
                        end
                    end
                end
            end
        end
    end
    if tracker.blocks then
        for _, block in pairs(tracker.blocks) do
            if type(block) == "table" and (block.IsObjectType or block.GetObjectType or block.SetPoint) then
                callback(block)
            end
        end
    end
end
objState.ForEachTrackerBlock = ForEachTrackerBlock
ObjectivesMod.ForEachTrackerBlock = ForEachTrackerBlock

local SUB_TRACKERS = {
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
objState.SUB_TRACKERS = SUB_TRACKERS

-- Headless testing loader fallback (where XML includes are not evaluated by standalone Lua)
if _G.loadfile then
    local basePath = "Modules/Objectives/"
    local subFiles = { "Defaults.lua", "Skinning.lua", "Quests.lua", "Scenario.lua" }
    for _, f in ipairs(subFiles) do
        local chunk = _G.loadfile(basePath .. f)
        if chunk then
            chunk(addonName, ns)
        end
    end
end

local hookedTrackers = objState.hookedTrackers
local skinnedBlocks = objState.skinnedBlocks
local skinnedBars = objState.skinnedBars
local titleFSCache = objState.titleFSCache

function ObjectivesMod:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Objectives or self.defaultSettings
    if self.db and self.defaultSettings then
        for k, v in pairs(self.defaultSettings) do
            if self.db[k] == nil then
                self.db[k] = v
            end
        end
    end
    if self.db and self.db.font and (self.db.font:find("\\") or self.db.font:find("%.ttf$")) then
        self.db.font = "Expressway"
    end
    self:RegisterWithEditMode()
end

function ObjectivesMod:OnEnable()
    local otf = _G.ObjectiveTrackerFrame
    if otf then
        otf:Show()
    end

    self:ApplyScaleAndHeight()
    self:ApplyPosition()
    self:HookAllTrackers()
    self:SkinAllExisting()

    self:RegisterEvent("PLAYER_REGEN_DISABLED", "CheckAutoCollapse")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
    self:RegisterEvent("ZONE_CHANGED", "OnZoneChanged")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "OnZoneChanged")
    self:RegisterEvent("QUEST_LOG_UPDATE", "OnQuestLogUpdate")
    self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", "OnQuestLogUpdate")
    self:RegisterEvent("SUPER_TRACKING_CHANGED", "OnSuperTrackingChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("CHALLENGE_MODE_START", "OnChallengeModeChanged")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "OnChallengeModeChanged")
    self:RegisterEvent("SCENARIO_UPDATE", "OnScenarioUpdate")
    self:RegisterEvent("SCENARIO_CRITERIA_UPDATE", "OnScenarioUpdate")
    self:RegisterEvent("UPDATE_UI_WIDGET", "OnScenarioUpdate")
    self:CheckMythicPlusVisibility()
    self:CheckAutoCollapse()
end

function ObjectivesMod:OnScenarioUpdate()
    if not self:IsEnabled() then return end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end

    if self.AlignScenarioElements then
        self:AlignScenarioElements()
    end
end

function ObjectivesMod:OnRegenEnabled()
    if self.pendingCombatUpdate then
        self.pendingCombatUpdate = nil
        local otf = _G.ObjectiveTrackerFrame
        if otf and otf.Update then
            otf:Update()
        end
    end
    if self.pendingMPlusHide then
        self.pendingMPlusHide = nil
        local otf = _G.ObjectiveTrackerFrame
        if otf then otf:Hide() end
    elseif self.pendingMPlusShow then
        self.pendingMPlusShow = nil
        local otf = _G.ObjectiveTrackerFrame
        if otf then otf:Show() end
    end
    self:CheckMythicPlusVisibility()
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
        if type(block) == "table" and self.ApplyQuestLevelToTitle then
            self:ApplyQuestLevelToTitle(block)
        end
    end
end

function ObjectivesMod:OnQuestLogUpdate()
    for block in pairs(skinnedBlocks) do
        if type(block) == "table" and self.ApplyQuestLevelToTitle then
            self:ApplyQuestLevelToTitle(block)
        end
    end
end

function ObjectivesMod:RefreshTrackers()
    for block in pairs(skinnedBlocks) do
        if type(block) == "table" then
            if self.ApplyQuestLevelToTitle then
                self:ApplyQuestLevelToTitle(block)
            end
            local titleFS = self.GetBlockTitleFS and self:GetBlockTitleFS(block)
            if titleFS and titleFS.SetFont then
                pcall(titleFS.SetFont, titleFS, self:GetFontPath(), self.db.titleFontSize or 12, self.db.fontOutline or "OUTLINE")
            end
            if self.ForEachBlockLine then
                self.ForEachBlockLine(block, function(line)
                    self:StyleObjectiveLine(line)
                end)
            end
            local initHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
            if self.UpdateBlockHoverObjectives then
                self:UpdateBlockHoverObjectives(block, initHovered or false)
            end
        end
    end
end

function ObjectivesMod:OnZoneChanged()
    if self.UpdateQuestLogData then
        self:UpdateQuestLogData()
    end
    self:CheckMythicPlusVisibility()
    self:CheckAutoCollapse()
end

function ObjectivesMod:RestoreDefaultView()
    local headerDividers = objState.headerDividers
    if headerDividers then
        for _, divider in pairs(headerDividers) do
            if divider and divider.Hide then
                divider:Hide()
            end
        end
    end

    local otf = _G.ObjectiveTrackerFrame
    if otf then
        if otf.Header then otf.Header:Show() end
        if otf.HeaderMenu then otf.HeaderMenu:Show() end
        if otf.SetScale then otf:SetScale(1.0) end
    end

    for bar in pairs(skinnedBars) do
        if bar and bar.roithiBackdrop then
            bar.roithiBackdrop:Hide()
        end
    end

    for block in pairs(skinnedBlocks) do
        local fs = titleFSCache[block]
        if fs and fs.SetFontObject then
            pcall(fs.SetFontObject, fs, "GameFontNormal")
            pcall(fs.SetTextColor, fs, 1, 0.82, 0)
        end
    end

    local sot = _G.ScenarioObjectiveTracker
    if sot and sot.StageBlock then
        sot.StageBlock:Show()
        if sot.StageBlock.SetAlpha then sot.StageBlock:SetAlpha(1) end
        if sot.StageBlock.NormalBG and sot.StageBlock.NormalBG.SetAlpha then sot.StageBlock.NormalBG:SetAlpha(1) end
        if sot.StageBlock.FinalBG and sot.StageBlock.FinalBG.SetAlpha then sot.StageBlock.FinalBG:SetAlpha(1) end
        if sot.StageBlock.ThemeOverlay and sot.StageBlock.ThemeOverlay.SetAlpha then sot.StageBlock.ThemeOverlay:SetAlpha(1) end
    end
end

function ObjectivesMod:OnDisable()
    self:RestoreDefaultView()
    self:UnregisterAllEvents()
    self:UnhookAll()
end

function ObjectivesMod:CheckMythicPlusVisibility()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not self.db or not self.db.enabled then return end

    local isMPlusActive = _G.C_ChallengeMode and _G.C_ChallengeMode.IsChallengeModeActive and _G.C_ChallengeMode.IsChallengeModeActive()
    if self.db.hideInMythicPlus then
        if isMPlusActive then
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                otf:Hide()
            else
                self.pendingMPlusHide = true
            end
        else
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                otf:Show()
            else
                self.pendingMPlusShow = true
            end
        end
    end
end

function ObjectivesMod:OnChallengeModeChanged()
    self:CheckMythicPlusVisibility()
    self:CheckAutoCollapse()
end

function ObjectivesMod:CheckAutoCollapse()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not self.db or not self.db.enabled then return end

    local shouldCollapse = false
    local inCombat = _G.InCombatLockdown and _G.InCombatLockdown()
    if self.db.autoCollapseCombat and inCombat then
        shouldCollapse = true
    elseif self.db.autoCollapseInstance and _G.IsInInstance and _G.IsInInstance() then
        shouldCollapse = true
    end

    if shouldCollapse and not (otf.IsCollapsed and otf:IsCollapsed()) then
        if inCombat then
            otf.isCollapsed = true
            if otf.Header and otf.Header.SetCollapsed then
                otf.Header:SetCollapsed(true)
            end
            if otf.modules then
                for _, mod in ipairs(otf.modules) do
                    if mod and mod.SetShown then mod:SetShown(false) end
                end
            end
            self.pendingCombatUpdate = true
        elseif otf.SetCollapsed then
            otf:SetCollapsed(true)
        end
    end
end

function ObjectivesMod:ApplyPosition()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end

    otf.ignoreFramePositionManager = true

    if not self.managedHooked and hooksecurefunc then
        if _G.UIParent_ManageFramePositions then
            hooksecurefunc("UIParent_ManageFramePositions", function()
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
            local mmWidth = (mmMod and mmMod.container and mmMod.container:GetWidth()) or anchorTarget:GetWidth() or 200
            if mmMod and mmMod.addonBar and mmMod.addonBar:IsShown() and (mmMod.db and mmMod.db.showAddonBar ~= false and mmMod.db.addonBarPosition ~= "SEPARATE" and mmMod.db.addonBarAttached ~= false) then
                local barWidth = (mmMod.GetAddonBarExpandedWidth and mmMod:GetAddonBarExpandedWidth())
                    or (mmMod.addonBar and mmMod.addonBar.expandedWidth)
                    or mmMod.addonBar:GetWidth()
                    or 30
                mmWidth = mmWidth + barWidth
            end

            self.settingPosition = true
            otf:ClearAllPoints()
            local xOffset = self.db.offsetX or 0
            local yOffset = self.db.offsetY or -2
            otf:SetPoint("TOPRIGHT", anchorTarget, "BOTTOMRIGHT", xOffset, yOffset)
            self.settingPosition = nil

            if mmWidth > 50 then
                if otf.SetWidth then otf:SetWidth(mmWidth) end
                if otf.Header and otf.Header.SetWidth and math.abs((otf.Header.GetWidth and otf.Header:GetWidth() or 0) - mmWidth) > 1 then
                    otf.Header:SetWidth(mmWidth)
                end
                if otf.HeaderMenu and otf.HeaderMenu.SetWidth then otf.HeaderMenu:SetWidth(mmWidth) end
            end
        end
    else
        local parent = otf:GetParent() or _G.UIParent
        if parent and otf.ClearAllPoints and otf.SetPoint then
            self.settingPosition = true
            local p = self.db.point or "TOPRIGHT"
            local rp = self.db.relativePoint or "TOPRIGHT"
            local x = self.db.detachedX or self.db.x or -20
            local y = self.db.detachedY or self.db.y or -200
            otf:ClearAllPoints()
            otf:SetPoint(p, parent, rp, x, y)
            self.settingPosition = nil

            local customWidth = self.db.detachedWidth or 235
            if customWidth > 50 then
                if otf.SetWidth then otf:SetWidth(customWidth) end
                if otf.Header and otf.Header.SetWidth and math.abs((otf.Header.GetWidth and otf.Header:GetWidth() or 0) - customWidth) > 1 then
                    otf.Header:SetWidth(customWidth)
                end
                if otf.HeaderMenu and otf.HeaderMenu.SetWidth then otf.HeaderMenu:SetWidth(customWidth) end
            end
        end
    end
end

function ObjectivesMod:ApplyScaleAndHeight()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not self.db or not self.db.enabled then return end

    local scale = self.db.scale or 1.0
    if otf.SetScale then
        otf:SetScale(scale)
    end

    local maxH = self.db.maxHeight or 800
    if otf.SetHeight then
        otf:SetHeight(maxH)
    end
end

function ObjectivesMod:OnPlayerEnteringWorld()
    C_Timer.After(0.3, function()
        self:HookAllTrackers()
        self:SkinAllExisting()
        self:ApplyPosition()
        self:CheckAutoCollapse()
        self:RefreshTrackers()
    end)
end

function ObjectivesMod:RegisterWithEditMode()
    if not LEM or not self.db then return end
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end

    if otf.SetMovable then otf:SetMovable(true) end
    if otf.SetClampedToScreen then otf:SetClampedToScreen(true) end

    local defaults = {
        point = "TOPRIGHT",
        relativePoint = "TOPRIGHT",
        x = -20,
        y = -200,
    }

    local settings = {
        {
            name = L["Attached to Minimap"] or "Attached to Minimap",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return self.db.attachedToMinimap ~= false end,
            set = function(_, val)
                self.db.attachedToMinimap = val
                self:ApplyPosition()
            end,
        },
    }

    local buttons = {
        {
            text = L["Open Full Settings"] or "Open Full Settings",
            onClick = function()
                RoithiUI:OpenSettings("Objectives")
            end,
        },
    }

    pcall(function()
        LEM:AddFrame(otf, function()
            if self.db.attachedToMinimap == false then
                local point, _, relPoint, x, y = otf:GetPoint(1)
                if point then
                    self.db.point = point
                    self.db.relativePoint = relPoint
                    self.db.detachedX = x
                    self.db.detachedY = y
                end
            end
        end, defaults)
        LEM:AddFrameSettings(otf, settings)
        LEM:AddFrameSettingsButtons(otf, buttons)
    end)
end

function ObjectivesMod:HookAllTrackers()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not self.db or not self.db.enabled then return end

    if otf.Header then
        self:SkinHeader(otf.Header)
    end
    if otf.HeaderMenu then
        self:SkinHeader(otf.HeaderMenu)
    end


    for _, trackerName in ipairs(SUB_TRACKERS) do
        local tracker = _G[trackerName]
        if tracker and not (objState.SharesWidgetPool and objState.SharesWidgetPool(tracker)) then
            self:HookTracker(tracker)
        end
    end

    local sot = _G.ScenarioObjectiveTracker
    if sot then
        if sot.Header then
            self:SkinHeader(sot.Header)
        end
    end

    self:ApplyMasterHeaderVisibility()
end

function ObjectivesMod:HookTracker(tracker)
    if not tracker or hookedTrackers[tracker] then return end
    hookedTrackers[tracker] = true

    if objState.SharesWidgetPool and objState.SharesWidgetPool(tracker) then
        return
    end

    tracker.blockOffsetX = 4
    tracker.leftMargin = 0
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
    end

    if tracker.GetProgressBar and not self:IsHooked(tracker, "GetProgressBar") then
        self:SecureHook(tracker, "GetProgressBar", function(_, line, _)
            if line and line.progressBar then
                self:SkinProgressBar(line.progressBar)
            end
        end)
    end

    if tracker.AddBlock and not self:IsHooked(tracker, "AddBlock") then
        self:SecureHook(tracker, "AddBlock", function(_, block)
            if block then
                self:SkinBlock(block)
            end
        end)
    end

    if tracker.LayoutContents and not self:IsHooked(tracker, "LayoutContents") then
        self:SecureHook(tracker, "LayoutContents", function()
            local font = self:GetFontPath()
            local objSize = self.db.objectiveFontSize or 11
            local outline = self.db.fontOutline or "OUTLINE"

            ForEachTrackerBlock(tracker, function(block)
                if not skinnedBlocks[block] then
                    self:SkinBlock(block)
                else
                    if self.ApplyQuestLevelToTitle then
                        self:ApplyQuestLevelToTitle(block)
                    end
                    if self.UpdateBlockHoverObjectives then
                        local isHovered = block.IsMouseOver and block:IsMouseOver()
                        self:UpdateBlockHoverObjectives(block, isHovered or false)
                    end
                    local formatLine = function(line)
                        if line then
                            if line.Dash and line.Dash.SetFont then
                                pcall(line.Dash.SetFont, line.Dash, font, objSize, outline)
                            end
                            if line.Text and line.Text.SetFont then
                                pcall(line.Text.SetFont, line.Text, font, objSize, outline)
                            end
                        end
                    end
                    if self.ForEachBlockLine then
                        self.ForEachBlockLine(block, formatLine)
                    elseif block.usedLines then
                        for _, line in pairs(block.usedLines) do formatLine(line) end
                    end
                end
            end)
            self:UpdateAllDividers()
        end)
    end
end

function ObjectivesMod:RefreshSettings()
    if not self.db then return end
    self:ApplyScaleAndHeight()
    self:ApplyPosition()
    self:ApplyMasterHeaderVisibility()
    self:UpdateFonts()
    self:SkinAllExisting()
    self:CheckMythicPlusVisibility()
    self:CheckAutoCollapse()
end
