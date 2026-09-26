local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local CDM = RoithiUI:NewModule("CooldownManager", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

CDM.displayName = L["Cooldown Manager"] or "Cooldown Manager"
CDM.description = L["Modern HUD cooldown manager styling for Blizzard Retail viewers (Essential, Utility, Buffs)."] or "Modern HUD cooldown manager styling for Blizzard Retail viewers."
CDM.order = 95
CDM.dbKey = "CooldownManager"

CDM.VIEWER_KEYS = {
    Essential = "EssentialCooldownViewer",
    Utility = "UtilityCooldownViewer",
    BuffIcon = "BuffIconCooldownViewer",
    BuffBar = "BuffBarCooldownViewer",
}

CDM.defaultSettings = {
    enabled = true,
    cropIcons = true,
    centerIncompleteRows = true,
    borderSize = 1,
    borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
    font = "Friz Quadrata TT",
    cooldownFontSize = 14,
    cooldownFontOutline = "OUTLINE",
    stackAnchor = "BOTTOMRIGHT",
    stackOffsetX = -2,
    stackOffsetY = 2,
    stackFontSize = 11,
    stackFontOutline = "OUTLINE",
    viewers = {
        Essential = {
            enabled = true,
            iconSize = 50,
            spacing = 4,
            growthDirection = "RIGHT",
            align = "CENTER",
            centerIncompleteRows = true,
        },
        Utility = {
            enabled = true,
            iconSize = 32,
            spacing = 4,
            growthDirection = "RIGHT",
            align = "CENTER",
            centerIncompleteRows = true,
        },
        BuffIcon = {
            enabled = true,
            iconSize = 40,
            spacing = 4,
            growthDirection = "RIGHT",
            align = "CENTER",
            centerIncompleteRows = true,
        },
        BuffBar = {
            enabled = true,
            barWidth = 220,
            barHeight = 24,
            spacing = 4,
            growthDirection = "DOWN",
        },
    },
}

function CDM:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CooldownManager or self.defaultSettings
    if not self.db.viewers then
        self.db.viewers = CopyTable(self.defaultSettings.viewers)
    end
    self.hookedViewers = {}
end

function CDM:OnEnable()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CooldownManager or self.defaultSettings
    if self.db.enabled == false then return end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")

    self:HookAllViewers()
    self:StyleAllActiveItems()
end

function CDM:OnDisable()
    self:UnregisterAllEvents()
    self:RestoreAllItems()
end

function CDM:OnEnteringWorld()
    self:HookAllViewers()
    self:StyleAllActiveItems()
end

function CDM:OnAddonLoaded(event, loadedAddonName)
    if loadedAddonName == "Blizzard_CooldownViewer" then
        self:HookAllViewers()
        self:StyleAllActiveItems()
    end
end

function CDM:HookAllViewers()
    for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
        local viewer = _G[globalName]
        if viewer and not self.hookedViewers[viewerKey] then
            self:HookViewer(viewerKey, viewer)
            self.hookedViewers[viewerKey] = true
        end
    end
end

function CDM:HookViewer(viewerKey, viewer)
    if not viewer then return end

    local container = (viewer.GetItemContainerFrame and viewer:GetItemContainerFrame()) or viewer
    if container and container.Layout and hooksecurefunc and not container.roithiLayoutHooked then
        hooksecurefunc(container, "Layout", function()
            if self:IsEnabled() and self.db and self.db.enabled ~= false then
                self:OnViewerLayoutRefreshed(viewerKey, viewer)
            end
        end)
        container.roithiLayoutHooked = true
    end

    if viewer.OnAcquireItemFrame and hooksecurefunc then
        hooksecurefunc(viewer, "OnAcquireItemFrame", function(v, itemFrame)
            if self:IsEnabled() and self.db and self.db.enabled ~= false then
                self:StyleItemFrame(viewerKey, itemFrame)
            end
        end)
    end

    if viewer.RefreshLayout and hooksecurefunc then
        hooksecurefunc(viewer, "RefreshLayout", function(v)
            if self:IsEnabled() and self.db and self.db.enabled ~= false then
                self:OnViewerLayoutRefreshed(viewerKey, v)
            end
        end)
    end
end

function CDM:CenterIncompleteRows(viewerKey, viewer)
    if not viewer or not self.db then return end
    if viewerKey == "BuffBar" then return end

    local vConf = self.db.viewers and self.db.viewers[viewerKey]
    local shouldCenter = true
    if self.db.centerIncompleteRows ~= nil then
        shouldCenter = self.db.centerIncompleteRows
    end
    if vConf and vConf.centerIncompleteRows ~= nil then
        shouldCenter = vConf.centerIncompleteRows
    end

    if not viewer.itemFramePool or not viewer.itemFramePool.EnumerateActive then return end

    local container = (viewer.GetItemContainerFrame and viewer:GetItemContainerFrame()) or viewer
    local isHorizontal = true
    if viewer.IsHorizontal then
        isHorizontal = viewer:IsHorizontal()
    elseif container.isHorizontal ~= nil then
        isHorizontal = container.isHorizontal
    end

    local items = {}
    for itemFrame in viewer.itemFramePool:EnumerateActive() do
        if itemFrame:IsShown() then
            table.insert(items, itemFrame)
        end
    end
    if #items <= 1 then return end

    table.sort(items, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    local stride = container.stride or (viewer.GetStride and viewer:GetStride()) or viewer.stride or 0
    if stride <= 0 then
        stride = #items
    end

    local lines = {}
    local currentLine = {}
    for i, itemFrame in ipairs(items) do
        table.insert(currentLine, itemFrame)
        if #currentLine == stride or i == #items then
            table.insert(lines, currentLine)
            currentLine = {}
        end
    end
    if #lines <= 1 and #items <= stride then
        return
    end

    local maxCount = 0
    for _, line in ipairs(lines) do
        if #line > maxCount then
            maxCount = #line
        end
    end
    if maxCount <= 0 then return end

    if isHorizontal then
        local firstItem = items[1]
        local itemW = firstItem:GetWidth()
        if not itemW or itemW <= 0 then
            itemW = (vConf and vConf.iconSize) or 40
        end
        local spacing = container.childXPadding
        if not spacing or spacing <= 0 then
            if viewer.iconPadding then
                local extra = (viewer.GetAdditionalPaddingOffset and viewer:GetAdditionalPaddingOffset()) or 0
                spacing = viewer.iconPadding + extra
            else
                spacing = (vConf and vConf.spacing) or 4
            end
        end
        local pitch = itemW + spacing
        local mult = (container.layoutFramesGoingRight == false) and -1 or 1

        for _, line in ipairs(lines) do
            local count = #line
            if count < maxCount then
                local xShift = shouldCenter and (mult * ((maxCount - count) * pitch) / 2) or 0
                for idx, itemFrame in ipairs(line) do
                    local numPoints = itemFrame:GetNumPoints()
                    if numPoints and numPoints > 0 then
                        local point, relTo, relPoint, _, y = itemFrame:GetPoint(1)
                        if point and y then
                            local xFinal = mult * ((idx - 1) * pitch) + xShift
                            itemFrame:ClearAllPoints()
                            itemFrame:SetPoint(point, relTo, relPoint, xFinal, y)
                        end
                    end
                end
            end
        end
    else
        local firstItem = items[1]
        local itemH = firstItem:GetHeight()
        if not itemH or itemH <= 0 then
            itemH = (vConf and vConf.iconSize) or 40
        end
        local spacing = container.childYPadding
        if not spacing or spacing <= 0 then
            if viewer.iconPadding then
                local extra = (viewer.GetAdditionalPaddingOffset and viewer:GetAdditionalPaddingOffset()) or 0
                spacing = viewer.iconPadding + extra
            else
                spacing = (vConf and vConf.spacing) or 4
            end
        end
        local pitch = itemH + spacing
        local mult = container.layoutFramesGoingUp and 1 or -1

        for _, line in ipairs(lines) do
            local count = #line
            if count < maxCount then
                local yShift = shouldCenter and (mult * ((maxCount - count) * pitch) / 2) or 0
                for idx, itemFrame in ipairs(line) do
                    local numPoints = itemFrame:GetNumPoints()
                    if numPoints and numPoints > 0 then
                        local point, relTo, relPoint, x, _ = itemFrame:GetPoint(1)
                        if point and x then
                            local yFinal = mult * ((idx - 1) * pitch) + yShift
                            itemFrame:ClearAllPoints()
                            itemFrame:SetPoint(point, relTo, relPoint, x, yFinal)
                        end
                    end
                end
            end
        end
    end
end

function CDM:OnViewerLayoutRefreshed(viewerKey, viewer)
    if not viewer or not viewer.itemFramePool then return end
    if viewer.itemFramePool.EnumerateActive then
        for itemFrame in viewer.itemFramePool:EnumerateActive() do
            self:StyleItemFrame(viewerKey, itemFrame)
        end
    end
    self:CenterIncompleteRows(viewerKey, viewer)
end

function CDM:RefreshAllViewerLayouts()
    for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
        local viewer = _G[globalName]
        if viewer then
            local container = (viewer.GetItemContainerFrame and viewer:GetItemContainerFrame()) or viewer
            if container and container.Layout then
                container:Layout()
            elseif viewer.RefreshLayout then
                viewer:RefreshLayout()
            end
            self:OnViewerLayoutRefreshed(viewerKey, viewer)
        end
    end
end

function CDM:StyleAllActiveItems()
    for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
        local viewer = _G[globalName]
        if viewer and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
            for itemFrame in viewer.itemFramePool:EnumerateActive() do
                self:StyleItemFrame(viewerKey, itemFrame)
            end
        end
    end
end

function CDM:RestoreAllItems()
    for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
        local viewer = _G[globalName]
        if viewer and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
            for itemFrame in viewer.itemFramePool:EnumerateActive() do
                self:RestoreItemFrame(itemFrame)
            end
        end
    end
end
