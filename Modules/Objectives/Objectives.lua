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
objState.barBackdrops = setmetatable({}, { __mode = "k" })
objState.blockBaseTitles = setmetatable({}, { __mode = "k" })
objState.blockQuestIDs = setmetatable({}, { __mode = "k" })
local barBackdrops = objState.barBackdrops

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

function ObjectivesMod:GetBarBackdrop(bar)
    return bar and barBackdrops[bar]
end

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

local function NormalizeFontFlags(flags)
    if ns.Utils and ns.Utils.NormalizeFontFlags then
        return ns.Utils.NormalizeFontFlags(flags)
    end
    if not flags or flags == "" or flags == "NONE" or flags == "None" or flags == "none" then
        return ""
    end
    return flags
end

local function ApplyFontStringShadow(fontString, showShadow)
    if not fontString or not fontString.SetShadowOffset then return end
    if showShadow then
        fontString:SetShadowOffset(1, -1)
        if fontString.SetShadowColor then
            fontString:SetShadowColor(0, 0, 0, 0.8)
        end
    else
        fontString:SetShadowOffset(0, 0)
    end
end

function ObjectivesMod:GetFontOutline(tierKey)
    local val = (tierKey and self.db and self.db[tierKey])
    if not val or val == "" then
        val = (self.db and self.db.fontOutline) or "OUTLINE"
    end
    return NormalizeFontFlags(val)
end

function ObjectivesMod:GetFontShadow(tierKey)
    if tierKey and self.db and self.db[tierKey] ~= nil then
        return self.db[tierKey] == true
    end
    return (self.db and self.db.showFontShadow) == true
end

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
    self:RegisterEvent("UPDATE_ALL_UI_WIDGETS", "OnScenarioUpdate")
    self:HookBelowMinimapWidget()
    self:CheckMythicPlusVisibility()
    self:CheckAutoCollapse()
end

function ObjectivesMod:OnScenarioUpdate()
    if not self:IsEnabled() then return end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end

    if self.AlignScenarioElements then
        self:AlignScenarioElements()
    end

    if self.db and self.db.attachedToMinimap ~= false then
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0, function()
                if not self.settingPosition and self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                    self:ApplyPosition()
                    self:ApplyScaleAndHeight()
                end
            end)
        else
            self:ApplyPosition()
            self:ApplyScaleAndHeight()
        end
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
    local offsetX = (self.db and self.db.blockOffsetX) or 4
    for block in pairs(skinnedBlocks) do
        if type(block) == "table" then
            if block.SetPoint then
                block:SetPoint("LEFT", offsetX, 0)
            end
            if self.ApplyQuestLevelToTitle then
                self:ApplyQuestLevelToTitle(block)
            end
            local titleFS = self.GetBlockTitleFS and self:GetBlockTitleFS(block)
            if titleFS and titleFS.SetFont then
                pcall(titleFS.SetFont, titleFS, self:GetFontPath("titleFont"), self.db.titleFontSize or 12, self:GetFontOutline("titleFontOutline"))
                ApplyFontStringShadow(titleFS, self:GetFontShadow("titleFontShadow"))
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
    if self.TrimTrackerGap then
        for _, trackerName in ipairs(SUB_TRACKERS) do
            local tracker = _G[trackerName]
            if tracker and tracker.IsShown and tracker:IsShown() then
                self:TrimTrackerGap(tracker)
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
        local bg = barBackdrops[bar]
        if bg and bg.Hide then
            bg:Hide()
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

function ObjectivesMod:GetMinimapAnchorTarget()
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
    return anchorTarget
end

function ObjectivesMod:HookBelowMinimapWidget()
    if self.belowMinimapHooked then return end
    local container = _G.UIWidgetBelowMinimapContainerFrame
    if not container then return end

    if container.HookScript then
        container:HookScript("OnShow", function()
            if not self.settingPosition and self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                self:ApplyPosition()
                self:ApplyScaleAndHeight()
            end
        end)
        container:HookScript("OnHide", function()
            if not self.settingPosition and self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                self:ApplyPosition()
                self:ApplyScaleAndHeight()
            end
        end)
        container:HookScript("OnSizeChanged", function()
            if not self.settingPosition and self.db and self.db.enabled ~= false and self.db.attachedToMinimap ~= false then
                self:ApplyPosition()
                self:ApplyScaleAndHeight()
            end
        end)
    end

    self.belowMinimapHooked = true
end

local function IsBelowMinimapWidgetShowing(widgetContainer)
    if not widgetContainer or not widgetContainer.IsShown or not widgetContainer:IsShown() then
        return false
    end
    if widgetContainer.HasAnyWidgetsShowing then
        return widgetContainer:HasAnyWidgetsShowing() == true
    end
    if widgetContainer.GetNumWidgetsShowing then
        return (widgetContainer:GetNumWidgetsShowing() or 0) > 0
    end
    if widgetContainer.widgetFrames then
        for _, widget in pairs(widgetContainer.widgetFrames) do
            if widget and widget.IsShown and widget:IsShown() then
                return true
            end
        end
    end
    return false
end

function ObjectivesMod:GetBelowMinimapWidgetOffset(anchorTarget)
    local widgetContainer = _G.UIWidgetBelowMinimapContainerFrame
    if not IsBelowMinimapWidgetShowing(widgetContainer) then
        return 0
    end

    if anchorTarget and anchorTarget.GetBottom and widgetContainer.GetBottom then
        local targetBottom = anchorTarget:GetBottom()
        local widgetBottom = widgetContainer:GetBottom()
        if targetBottom and widgetBottom and targetBottom > widgetBottom then
            return targetBottom - widgetBottom
        end
    end

    local widgetHeight = (widgetContainer.GetHeight and widgetContainer:GetHeight()) or 0
    if widgetHeight > 1 then
        return widgetHeight
    end

    return 0
end

function ObjectivesMod:ApplyPosition()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end

    self:HookBelowMinimapWidget()

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
                local expectedTarget = self:GetMinimapAnchorTarget()
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
            if self.db and self.db.enabled ~= false then
                if self.db.attachedToMinimap ~= false then
                    self:ApplyPosition()
                end
                self:ApplyScaleAndHeight()
            end
        end, self)
        _G.EventRegistry:RegisterCallback("EditMode.Exit", function()
            if self.db and self.db.enabled ~= false then
                if self.db.attachedToMinimap ~= false then
                    self:ApplyPosition()
                end
                self:ApplyScaleAndHeight()
            end
        end, self)
        self.editModeEventsRegistered = true
    end

    if self.db.attachedToMinimap ~= false then
        if otf.SetClampedToScreen then otf:SetClampedToScreen(false) end
        local mmMod = RoithiUI and RoithiUI.GetModule and RoithiUI:GetModule("Minimap", true)
        local anchorTarget = self:GetMinimapAnchorTarget()

        if anchorTarget and otf.ClearAllPoints and otf.SetPoint then
            local mmWidth = (mmMod and mmMod.container and mmMod.container:GetWidth()) or anchorTarget:GetWidth() or 200
            if mmMod and mmMod.addonBar and mmMod.addonBar:IsShown() and (mmMod.db and mmMod.db.showAddonBar ~= false and mmMod.db.addonBarPosition ~= "SEPARATE" and mmMod.db.addonBarAttached ~= false) then
                local barWidth = (mmMod.GetAddonBarExpandedWidth and mmMod:GetAddonBarExpandedWidth())
                    or (mmMod.addonBar and mmMod.addonBar.expandedWidth)
                    or mmMod.addonBar:GetWidth()
                    or 30
                mmWidth = mmWidth + barWidth
            end

            local extraY = self:GetBelowMinimapWidgetOffset(anchorTarget)
            self.settingPosition = true
            otf:ClearAllPoints()
            local xOffset = self.db.offsetX or 0
            local yOffset = self.db.offsetY or -5
            otf:SetPoint("TOPRIGHT", anchorTarget, "BOTTOMRIGHT", xOffset, yOffset - extraY)
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
        if otf.SetClampedToScreen then otf:SetClampedToScreen(true) end
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

    if otf.UpdateHeight and not self.updateHeightHooked and hooksecurefunc then
        hooksecurefunc(otf, "UpdateHeight", function()
            if not self.settingHeight and self.db and self.db.enabled ~= false then
                self.settingHeight = true
                self:ApplyScaleAndHeight()
                self.settingHeight = nil
            end
        end)
        self.updateHeightHooked = true
    end

    local scale = self.db.scale or 1.0
    if otf.SetScale then
        otf:SetScale(scale)
    end

    local maxH = self.db.maxHeight or 800
    if self.db.attachedToMinimap ~= false then
        local anchorTarget = self:GetMinimapAnchorTarget()
        if anchorTarget and anchorTarget.GetBottom then
            local bottomY = anchorTarget:GetBottom()
            if bottomY and bottomY > 50 then
                local bottomMargin = 20
                local extraY = self:GetBelowMinimapWidgetOffset(anchorTarget)
                local availableH = math.floor(bottomY - extraY - bottomMargin)
                if availableH > 100 then
                    maxH = math.min(maxH, availableH)
                end
            end
        end
        if otf.SetClampedToScreen then
            otf:SetClampedToScreen(false)
        end
    else
        if otf.SetClampedToScreen then
            otf:SetClampedToScreen(true)
        end
    end

    self.lastMaxHeight = maxH
    if otf.SetHeight then
        otf:SetHeight(maxH)
    end
end

function ObjectivesMod:OnPlayerEnteringWorld()
    C_Timer.After(0.3, function()
        self:HookBelowMinimapWidget()
        self:HookAllTrackers()
        self:SkinAllExisting()
        self:ApplyScaleAndHeight()
        self:ApplyPosition()
        self:CheckAutoCollapse()
        self:RefreshTrackers()
    end)
    -- Second pass: Blizzard re-lays out blocks from QUEST_LOG_UPDATE after our first pass.
    -- This deferred refresh ensures block heights are correct without requiring a hover.
    C_Timer.After(1.0, function()
        if self:IsEnabled() then
            self:RefreshTrackers()
        end
    end)
end

function ObjectivesMod:RegisterWithEditMode()
    if not LEM or not self.db then return end
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end

    if otf.SetMovable then otf:SetMovable(true) end
    if otf.SetClampedToScreen then otf:SetClampedToScreen(self.db.attachedToMinimap == false) end

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
                if otf.SetClampedToScreen then otf:SetClampedToScreen(not val) end
                self:ApplyPosition()
                self:ApplyScaleAndHeight()
            end,
        },
    }

    local buttons = {
        {
            text = L["Open Full Settings"] or "Open Full Settings",
            click = function()
                if RoithiUI and RoithiUI.OpenSettings then
                    RoithiUI:OpenSettings("objectives")
                end
            end,
            onClick = function()
                if RoithiUI and RoithiUI.OpenSettings then
                    RoithiUI:OpenSettings("objectives")
                end
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

    if tracker.SetCollapsed and not self:IsHooked(tracker, "SetCollapsed") then
        self:SecureHook(tracker, "SetCollapsed", function()
            self:UpdateAllDividers()
        end)
    end

    if tracker.EndLayout and not self:IsHooked(tracker, "EndLayout") then
        self:SecureHook(tracker, "EndLayout", function()
            ForEachTrackerBlock(tracker, function(block)
                if self.UpdateBlockHoverObjectives then
                    local isHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
                    self:UpdateBlockHoverObjectives(block, isHovered or false)
                end
            end)
            if self.TrimTrackerGap then
                self:TrimTrackerGap(tracker)
            end
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

    if tracker.AnchorBlock and not self:IsHooked(tracker, "AnchorBlock") then
        self:SecureHook(tracker, "AnchorBlock", function(t, block)
            if block and block.SetPoint then
                local offsetX = (self.db and self.db.blockOffsetX) or 4
                local parent = (block.GetParent and block:GetParent()) or t
                block:SetPoint("LEFT", parent, "LEFT", offsetX, 0)
            end
        end)
    end

    if tracker.GetProgressBar and not self:IsHooked(tracker, "GetProgressBar") then
        self:SecureHook(tracker, "GetProgressBar", function(t, line, _)
            local bar = (t and t.usedProgressBars and t.usedProgressBars[line]) or (line and line.progressBar)
            if bar then
                self:SkinProgressBar(bar)
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
            local font = self:GetFontPath("objectiveFont")
            local objSize = self.db.objectiveFontSize or 11
            local outline = self:GetFontOutline("objectiveFontOutline")
            local useShadow = self:GetFontShadow("objectiveFontShadow")

            -- Collect the blocks to re-skin / re-update so we can defer
            -- the height correction to the next frame. Blizzard's own
            -- LayoutContents continues after this hook and resets block
            -- heights; a C_Timer.After(0) deferred call wins the race.
            local pendingBlocks = {}
            ForEachTrackerBlock(tracker, function(block)
                if not skinnedBlocks[block] then
                    self:SkinBlock(block)
                else
                    if self.ApplyQuestLevelToTitle then
                        self:ApplyQuestLevelToTitle(block)
                    end
                    local formatLine = function(line)
                        if line then
                            if line.Dash and line.Dash.SetFont then
                                pcall(line.Dash.SetFont, line.Dash, font, objSize, outline)
                                ApplyFontStringShadow(line.Dash, useShadow)
                            end
                            if line.Text and line.Text.SetFont then
                                pcall(line.Text.SetFont, line.Text, font, objSize, outline)
                                ApplyFontStringShadow(line.Text, useShadow)
                            end
                        end
                    end
                    if self.ForEachBlockLine then
                        self.ForEachBlockLine(block, formatLine)
                    elseif block.usedLines then
                        for _, line in pairs(block.usedLines) do formatLine(line) end
                    end
                    pendingBlocks[#pendingBlocks + 1] = block
                end
            end)

            if tracker.usedProgressBars then
                for _, bar in pairs(tracker.usedProgressBars) do
                    self:SkinProgressBar(bar)
                end
            end
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
