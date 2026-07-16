local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local MinimapMod = RoithiUI:NewModule("Minimap", "AceHook-3.0", "AceEvent-3.0")
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode-Roithi", true)
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

local Minimap = _G.Minimap
local MinimapCluster = _G.MinimapCluster
local Minimap_ZoomIn = _G.Minimap_ZoomIn
local Minimap_ZoomOut = _G.Minimap_ZoomOut
local GameTimeFrame = _G.GameTimeFrame
local MiniMapMailFrame = _G.MiniMapMailFrame
local MiniMapTracking = _G.MiniMapTracking

local UpdateDataText
local date = _G.date or os.date

MinimapMod.displayName = L["Minimap"]
MinimapMod.description = L["Enables the custom RoithiUI Minimap and Addon Button Bar module."]
MinimapMod.order = 80

function MinimapMod:OnInitialize()
    self.db = RoithiUI.db.profile.Minimap
    self.scannedButtons = {}
    self.activeButtons = {}
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function MinimapMod:ADDON_LOADED(event, name)
    if name == "Blizzard_QueueStatusFrame" then
        self:LayoutDefaultButtons()
    end
end

function MinimapMod:PLAYER_ENTERING_WORLD()
    self:LayoutDefaultButtons()
end

function MinimapMod:UpdateAnchorsMouseState(enable)
    local anchors = {
        self.zoneTextAnchor,
        self.mailAnchor,
        self.trackingAnchor,
        self.lfgAnchor,
        self.landingAnchor,
        self.zoomInAnchor,
        self.zoomOutAnchor,
        self.calendarAnchor,
    }
    for _, f in ipairs(anchors) do
        if f then
            f:EnableMouse(enable)
        end
    end
end

function MinimapMod:UpdateBlizzardButtonsMouseState(enable)
    local buttons = {
        MinimapCluster.ZoneTextButton or MinimapCluster.ZoneTextFrame or _G.MinimapZoneTextButton,
        MiniMapMailFrame or (MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame),
        MinimapCluster.Tracking or MinimapCluster.TrackingFrame or MiniMapTracking,
        _G.QueueStatusMinimapButton,
        _G.QueueStatusButton,
        _G.GarrisonLandingPageMinimapButton,
        _G.ExpansionLandingPageMinimapButton,
        Minimap.ZoomIn or _G.MinimapZoomIn,
        Minimap.ZoomOut or _G.MinimapZoomOut,
        GameTimeFrame,
    }
    for _, btn in pairs(buttons) do
        if btn then
            btn:EnableMouse(enable)
        end
    end
end

function MinimapMod:PrepareFramesForEditMode()
    local container = _G.RoithiMinimapContainer
    if not container then return end

    local frames = {
        { key = "zoneTextAnchor", frame = self.zoneTextAnchor },
        { key = "mailAnchor", frame = self.mailAnchor },
        { key = "trackingAnchor", frame = self.trackingAnchor },
        { key = "lfgAnchor", frame = self.lfgAnchor },
        { key = "landingAnchor", frame = self.landingAnchor },
        { key = "zoomInAnchor", frame = self.zoomInAnchor },
        { key = "zoomOutAnchor", frame = self.zoomOutAnchor },
        { key = "calendarAnchor", frame = self.calendarAnchor },
        { key = "addonBar", frame = self.addonBar },
    }

    for _, entry in ipairs(frames) do
        local f = entry.frame
        if f then
            local isDetached = (entry.key == "addonBar") or (self.db.detached and self.db.detached[entry.key])
            if isDetached then
                f:SetParent(UIParent)
                f:SetScale(1.0)
            end
            if f.SetFrameStrata then
                f:SetFrameStrata("DIALOG")
            end
            if f.SetFrameLevel then
                f:SetFrameLevel(50)
            end
            f:Show()
        end
    end
end

function MinimapMod:ReparentFramesAfterEditMode()
    local container = _G.RoithiMinimapContainer
    if not container then return end

    local frames = {
        { key = "zoneTextAnchor", frame = self.zoneTextAnchor, default = { point = "TOPRIGHT", x = -80, y = -10 } },
        { key = "mailAnchor", frame = self.mailAnchor, default = { point = "TOPRIGHT", x = -180, y = -30 } },
        { key = "trackingAnchor", frame = self.trackingAnchor, default = { point = "TOPRIGHT", x = -30, y = -30 } },
        { key = "lfgAnchor", frame = self.lfgAnchor, default = { point = "CENTER", x = 0, y = 0 } },
        { key = "landingAnchor", frame = self.landingAnchor, default = { point = "TOPRIGHT", x = -30, y = -180 } },
        { key = "zoomInAnchor", frame = self.zoomInAnchor, default = { point = "TOPRIGHT", x = -130, y = -30 } },
        { key = "zoomOutAnchor", frame = self.zoomOutAnchor, default = { point = "TOPRIGHT", x = -130, y = -65 } },
        { key = "calendarAnchor", frame = self.calendarAnchor, default = { point = "TOPRIGHT", x = -65, y = -30 } },
        { key = "addonBar", frame = self.addonBar, default = { point = "TOPRIGHT", x = -10, y = -220 } },
    }

    for _, entry in ipairs(frames) do
        local f = entry.frame
        if f then
            local isDetached = (entry.key == "addonBar") or (self.db.detached and self.db.detached[entry.key])
            if isDetached then
                f:SetParent(UIParent)
                f:SetScale(1.0)
                if f.SetFrameStrata then
                    f:SetFrameStrata("HIGH")
                end
                if f.SetFrameLevel then
                    f:SetFrameLevel(20)
                end
                local point, _, _, x, y = f:GetPoint(1)
                if point then
                    self.db.offsets = self.db.offsets or {}
                    self.db.offsets[entry.key] = { point = point, x = x, y = y }
                end
            else
                f:SetParent(container)
                f:SetScale(1.0)
                if f.SetFrameStrata then
                    f:SetFrameStrata("HIGH")
                end
                if f.SetFrameLevel then
                    f:SetFrameLevel(20)
                end
                local offset = self.db.offsets and self.db.offsets[entry.key] or entry.default
                f:ClearAllPoints()
                local pt = offset.point or "BOTTOMLEFT"
                f:SetPoint(pt, container, pt, offset.x, offset.y)
            end
        end
    end

    self:UpdateAllElementVisibilities()
end

function MinimapMod:OnEnable()
    if self.db.enabled == false then return end

    -- Apply styling
    self:StyleMinimap()

    -- Create Addon Button Bar (always created so it is registered in Edit Mode)
    self:CreateAddonBar()
    self:UpdateAddonBarVisibility()

    -- Create Minimap Data Text Bar
    self:CreateDataTextBar()
    self:UpdateDataTextBarVisibility()

    -- Initial scan, then repeat after delay to let late addons load
    self:ScanAddonButtons()
    C_Timer.After(2, function()
        self:ScanAddonButtons()
    end)

    -- Setup LFG hook ticker to handle late-created LFG buttons safely
    if not self.lfgHookTicker and C_Timer.NewTicker then
        self.lfgHookTicker = C_Timer.NewTicker(1, function()
            local qsb = _G.QueueStatusButton
            local elp = _G.ExpansionLandingPageMinimapButton or _G.GarrisonLandingPageMinimapButton
            
            -- If we can find the buttons, try to lay them out (which hooks them)
            if qsb or elp then
                self:LayoutDefaultButtons()
            end
            
            -- We only cancel the ticker if all buttons that exist in this expansion are hooked.
            local landingSupported = C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_ExpansionLandingPage")
            local qsbHooked = not not (qsb and qsb.isRoithiHooked)
            local elpHooked = not landingSupported or not not (elp and elp.isRoithiHooked)
            
            if qsbHooked and elpHooked and self.lfgHookTicker then
                self.lfgHookTicker:Cancel()
                self.lfgHookTicker = nil
            end
        end)
    end

    -- Make anchors click-through during normal play
    self:UpdateAnchorsMouseState(false)

    if LEM then
        LEM:RegisterCallback("enter", function()
            self:UpdateAnchorsMouseState(true)
            self:UpdateBlizzardButtonsMouseState(false)


            local mail = MiniMapMailFrame or (MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame)
            if mail then
                self.mailWasShown = mail:IsShown()
                mail:Show()
            end
            local landing = _G.GarrisonLandingPageMinimapButton or _G.ExpansionLandingPageMinimapButton
            if landing then
                self.landingWasShown = landing:IsShown()
                landing:Show()
            end

            -- Temporarily show all anchors so they are visible/movable in Edit Mode
            local anchors = {
                self.zoneTextAnchor,
                self.mailAnchor,
                self.trackingAnchor,
                self.lfgAnchor,
                self.landingAnchor,
                self.zoomInAnchor,
                self.zoomOutAnchor,
                self.calendarAnchor,
            }
            for _, f in ipairs(anchors) do
                if f then f:Show() end
            end

            self:UpdateAddonBarVisibility()
            self:UpdateDataTextBarVisibility()
            self:PrepareFramesForEditMode()
            if self.addonBar then
                self.addonBar:SetAlpha(1)
            end
        end)
        LEM:RegisterCallback("exit", function()
            self:UpdateAnchorsMouseState(false)
            self:UpdateBlizzardButtonsMouseState(true)
            self:ReparentFramesAfterEditMode()
            self:UpdateAddonBarVisibility()
            self:UpdateDataTextBarVisibility()
            self:UpdateZoneTextVisibility()
            self:UpdateCalendarVisibility()
            self:UpdateZoomVisibility()

            -- Restore original visibility and Hide/SetShown of LFG, Mail, Landing buttons

            local mail = MiniMapMailFrame or (MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame)
            if mail then
                mail:SetShown(self.mailWasShown)
            end
            local landing = _G.GarrisonLandingPageMinimapButton or _G.ExpansionLandingPageMinimapButton
            if landing then
                landing:SetShown(self.landingWasShown)
            end



            if self.addonBar then
                self.addonBar:SetAlpha(self.db.addonBarHide and 0 or 1)
                self:UpdateAddonBarAutohide()
            end
        end)
    end
end

function MinimapMod:StyleMinimap()
    -- 1. Setup Minimap Container
    if not self.container then
        self.container = CreateFrame("Frame", "RoithiMinimapContainer", UIParent)
        self.container:SetClampedToScreen(true)
        self.container:SetMovable(true)
        self.container:EnableMouse(true)
        self.container.editModeName = L["Minimap"]

        -- Parent the default Minimap to our container
        Minimap:SetParent(self.container)
        Minimap:ClearAllPoints()
        Minimap:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, 0)
        Minimap:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", 0, 0)
        Minimap:Show()

        self.container:ClearAllPoints()
        local defaults = { point = "TOPRIGHT", x = -10, y = -10 }
        local offset = self.db.offsets and self.db.offsets["container"] or defaults
        self.container:SetPoint(offset.point or defaults.point, UIParent, offset.point or defaults.point, offset.x, offset.y)
        self.container:Show()

        -- Register with LibEditMode-Roithi
        LEM:AddFrame(self.container, function(f, _, point, x, y)
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
            self.db.offsets = self.db.offsets or {}
            self.db.offsets["container"] = { point = point, x = x, y = y }
        end, defaults)
    end

    -- Register Edit Mode settings for self.container
    if LEM then
        local settings = {
            {
                name = L["Minimap Shape"],
                kind = LEM.SettingType.Dropdown,
                values = {
                    { text = L["Square"], value = "SQUARE" },
                    { text = L["Round"], value = "ROUND" },
                },
                get = function() return self.db.shape or "SQUARE" end,
                set = function(_, val)
                    self.db.shape = val
                    self:UpdateMinimapShape()
                end,
            },
            {
                name = L["Minimap Width"],
                kind = LEM.SettingType.Slider,
                minValue = 100,
                maxValue = 400,
                valueStep = 5,
                get = function() return self.db.width or self.db.size or 200 end,
                set = function(_, val)
                    self.db.width = val
                    self:UpdateMinimapSize()
                end,
            },
            {
                name = L["Minimap Height"],
                kind = LEM.SettingType.Slider,
                minValue = 100,
                maxValue = 400,
                valueStep = 5,
                get = function() return self.db.height or self.db.size or 200 end,
                set = function(_, val)
                    self.db.height = val
                    self:UpdateMinimapSize()
                end,
            },
            {
                name = L["Minimap Scale"],
                kind = LEM.SettingType.Slider,
                minValue = 0.5,
                maxValue = 2.0,
                valueStep = 0.05,
                formatter = function(v) return string.format("%.2f", v) end,
                get = function() return self.db.scale or 1.0 end,
                set = function(_, val)
                    self.db.scale = val
                    self:UpdateMinimapSize()
                end,
            },
            {
                name = L["Show Zone Text"],
                kind = LEM.SettingType.Checkbox,
                get = function() return self.db.showZoneText end,
                set = function(_, val)
                    self.db.showZoneText = val
                    self:UpdateZoneTextVisibility()
                end,
            },
            {
                name = L["Show Calendar"],
                kind = LEM.SettingType.Checkbox,
                get = function() return self.db.showCalendar end,
                set = function(_, val)
                    self.db.showCalendar = val
                    self:UpdateCalendarVisibility()
                end,
            },
            {
                name = L["Show Zoom Buttons"],
                kind = LEM.SettingType.Checkbox,
                get = function() return self.db.showZoom end,
                set = function(_, val)
                    self.db.showZoom = val
                    self:UpdateZoomVisibility()
                end,
            },
            {
                name = L["Show Data Text Bar"],
                kind = LEM.SettingType.Checkbox,
                get = function() return self.db.showDataTextBar end,
                set = function(_, val)
                    self.db.showDataTextBar = val
                    self:UpdateDataTextBarVisibility()
                end,
            },
            {
                name = L["Data Text Type"],
                kind = LEM.SettingType.Dropdown,
                values = {
                    { text = L["Friends"], value = "Friends" },
                    { text = L["Time"], value = "Time" },
                    { text = L["Date"], value = "Date" },
                    { text = L["FPS"], value = "FPS" },
                    { text = L["Zone"], value = "Zone" },
                    { text = L["Latency"], value = "Latency" },
                },
                get = function() return self.db.dataTextType or "Time" end,
                set = function(_, val)
                    self.db.dataTextType = val
                    if self.dataTextBar then
                        UpdateDataText(self.dataTextBar)
                    end
                end,
            },
            {
                name = L["Zone Text X Offset"],
                kind = LEM.SettingType.Slider,
                minValue = -200,
                maxValue = 200,
                valueStep = 1,
                get = function() return self.db.zoneTextX or 0 end,
                set = function(_, val)
                    self.db.zoneTextX = val
                    self:LayoutDefaultButtons()
                end,
            },
            {
                name = L["Zone Text Y Offset"],
                kind = LEM.SettingType.Slider,
                minValue = -200,
                maxValue = 200,
                valueStep = 1,
                get = function() return self.db.zoneTextY or 0 end,
                set = function(_, val)
                    self.db.zoneTextY = val
                    self:LayoutDefaultButtons()
                end,
            },
        }
        LEM:AddFrameSettings(self.container, settings)

        LEM:AddFrameSettingsButtons(self.container, {
            {
                text = "Open Full Settings",
                click = function()
                    if LibStub("AceConfigDialog-3.0") then
                        LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "minimap")
                        LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                    end
                end,
            }
        })
    end

    -- 2. Clean MinimapCluster and hide Blizzard's Selection border
    if MinimapCluster then
        MinimapCluster:Show()
        MinimapCluster:SetAlpha(1)

        if MinimapCluster.BorderTop then
            MinimapCluster.BorderTop:Hide()
            MinimapCluster.BorderTop:SetAlpha(0)
            if not self.isBorderTopHooked then
                hooksecurefunc(MinimapCluster.BorderTop, "Show", function(s) s:Hide() end)
                self.isBorderTopHooked = true
            end
        end

        local backdrop = MinimapCluster.MinimapBackdrop or _G.MinimapBackdrop
        if backdrop then
            backdrop:Hide()
            backdrop:SetAlpha(0)
            if not self.isBackdropHooked then
                hooksecurefunc(backdrop, "Show", function(s) s:Hide() end)
                self.isBackdropHooked = true
            end
        end

        local compass = _G.MinimapCompassTexture
        if compass then
            compass:Hide()
            compass:SetAlpha(0)
            if not self.isCompassHooked then
                hooksecurefunc(compass, "Show", function(s) s:Hide() end)
                self.isCompassHooked = true
            end
        end

        if MinimapCluster.Selection then
            MinimapCluster.Selection:Hide()
            if not self.isSelectionHooked then
                hooksecurefunc(MinimapCluster.Selection, "Show", function(s) s:Hide() end)
                self.isSelectionHooked = true
            end
        end
    end

    -- 3. Setup Minimap Border (needs BackdropTemplate)
    if not self.borderFrame then
        self.borderFrame = CreateFrame("Frame", "RoithiMinimapBorder", Minimap, "BackdropTemplate")
        self:UpdateMinimapBorder()
    end

    -- Hide other default textures/frames inside Minimap
    if Minimap.ZoomHitArea then Minimap.ZoomHitArea:Hide() end

    -- 4. Mouse Wheel Zoom
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            Minimap_ZoomIn()
        else
            Minimap_ZoomOut()
        end
    end)

    -- 5. Right Click for Tracking Menu
    Minimap:SetScript("OnMouseUp", function(s, button)
        if button == "RightButton" then
            local trackingBtn = MinimapCluster.Tracking and MinimapCluster.Tracking.Button
            if trackingBtn then
                if trackingBtn.ToggleMenu then
                    trackingBtn:ToggleMenu()
                elseif trackingBtn.Click then
                    trackingBtn:Click()
                end
            end
        else
            if s.OnClick then
                s:OnClick()
            end
        end
    end)

    -- 6. Apply configured shape, size, scale
    self:UpdateMinimapShape()
    self:UpdateMinimapSize()
    self:LayoutDefaultButtons()
    self:UpdateAllElementVisibilities()
end

function MinimapMod:UpdateMinimapBorder()
    if not self.borderFrame then return end
    local size = self.db.borderSize or 1
    self.borderFrame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = size,
    })
    self.borderFrame:ClearAllPoints()
    self.borderFrame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -size, size)
    self.borderFrame:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", size, -size)

    local width = self.db.width or self.db.size or 200
    local height = self.db.height or self.db.size or 200
    self.borderFrame:SetSize(width + size * 2, height + size * 2)

    local color = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
    self.borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
end

function MinimapMod:UpdateMinimapShape()
    if self.db.shape == "SQUARE" then
        Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
        if self.borderFrame then
            self.borderFrame:Show()
            self:UpdateMinimapBorder()
        end
    else
        -- Restore default circular shape mask in Retail
        Minimap:SetMaskTexture("Interface\\Masks\\MinimapMask")
        if self.borderFrame then self.borderFrame:Hide() end
    end
    self:LayoutDefaultButtons()
    if LEM then
        LEM:RefreshFrameSettings(self.container)
    end
end

function MinimapMod:UpdateMinimapSize()
    local width = self.db.width or self.db.size or 200
    local height = self.db.height or self.db.size or 200
    local scale = self.db.scale or 1.0

    if self.container then
        self.container:SetSize(width, height)
        self.container:SetScale(scale)
    end

    Minimap:SetSize(width, height)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, 0)
    Minimap:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", 0, 0)

    -- Force a C-level redraw of the minimap 3D render to ensure size/scale update immediately
    local zoom = Minimap:GetZoom()
    Minimap:SetZoom(zoom == 0 and 1 or 0)
    Minimap:SetZoom(zoom)

    self:UpdateMinimapBorder()
    if LEM then
        LEM:RefreshFrameSettings(self.container)
    end
end

MinimapMod.defaultAnchorPositions = {
    zoneTextAnchor = { point = "TOPRIGHT", x = -80, y = -10 },
    mailAnchor = { point = "TOPRIGHT", x = -180, y = -30 },
    trackingAnchor = { point = "TOPRIGHT", x = -30, y = -30 },
    lfgAnchor = { point = "CENTER", x = 0, y = 0 },
    landingAnchor = { point = "TOPRIGHT", x = -30, y = -180 },
    zoomInAnchor = { point = "TOPRIGHT", x = -130, y = -30 },
    zoomOutAnchor = { point = "TOPRIGHT", x = -130, y = -65 },
    calendarAnchor = { point = "TOPRIGHT", x = -65, y = -30 },
    addonBar = { point = "TOPRIGHT", x = -10, y = -220 },
}

function MinimapMod:UpdateFrameAttachment(f, key, isDetached)
    local container = _G.RoithiMinimapContainer
    if not container then return end

    local sLeft, sBottom = f:GetRect()
    local fScale = f:GetEffectiveScale() or 1.0

    if isDetached then
        -- Detach: parent to UIParent and preserve current layout/screen coordinates
        f:SetParent(UIParent)
        f:SetScale(1.0)
        if f.SetFrameStrata then
            f:SetFrameStrata("HIGH")
        end
        if f.SetFrameLevel then
            f:SetFrameLevel(20)
        end
        f:ClearAllPoints()

        if sLeft and sBottom then
            local uiScale = UIParent:GetEffectiveScale() or 1.0
            local dx = sLeft * (fScale / uiScale)
            local dy = sBottom * (fScale / uiScale)
            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", dx, dy)
            self.db.offsets = self.db.offsets or {}
            self.db.offsets[key] = { point = "BOTTOMLEFT", x = dx, y = dy }
        else
            local defaultPos = self.defaultAnchorPositions[key] or { point = "TOPRIGHT", x = -10, y = -220 }
            f:SetPoint(defaultPos.point, UIParent, defaultPos.point, defaultPos.x, defaultPos.y)
            self.db.offsets = self.db.offsets or {}
            self.db.offsets[key] = { point = defaultPos.point, x = defaultPos.x, y = defaultPos.y }
        end
    else
        -- Attach: calculate offset relative to container and re-parent
        local pLeft, pBottom = container:GetRect()
        local pScale = container:GetEffectiveScale() or 1.0

        f:SetParent(container)
        f:SetScale(1.0)
        if f.SetFrameStrata then
            f:SetFrameStrata("HIGH")
        end
        if f.SetFrameLevel then
            f:SetFrameLevel(20)
        end
        f:ClearAllPoints()

        if sLeft and pLeft then
            local dx = sLeft * (fScale / pScale) - pLeft
            local dy = sBottom * (fScale / pScale) - pBottom
            self.db.offsets = self.db.offsets or {}
            self.db.offsets[key] = { point = "BOTTOMLEFT", x = dx, y = dy }
            f:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", dx, dy)
        else
            local defaultPos = self.defaultAnchorPositions[key] or { point = "TOPRIGHT", x = -10, y = -220 }
            f:SetPoint(defaultPos.point, container, defaultPos.point, defaultPos.x, defaultPos.y)
        end
    end
end

function MinimapMod:RegisterAnchorSettings(f, key)
    if not LEM then return end

    local configMap = {
        zoneTextAnchor = { toggle = "showZoneText", default = { point = "TOPRIGHT", x = -80, y = -10 }, updateVis = "UpdateZoneTextVisibility" },
        mailAnchor = { toggle = "showMail", default = { point = "TOPRIGHT", x = -180, y = -30 }, updateVis = "UpdateMailVisibility" },
        trackingAnchor = { toggle = "showTracking", default = { point = "TOPRIGHT", x = -30, y = -30 }, updateVis = "UpdateTrackingVisibility" },
        lfgAnchor = { toggle = "showLFG", default = { point = "CENTER", x = 0, y = 0 }, updateVis = "UpdateLFGVisibility" },
        landingAnchor = { toggle = "showLanding", default = { point = "TOPRIGHT", x = -30, y = -180 }, updateVis = "UpdateLandingVisibility" },
        zoomInAnchor = { toggle = "showZoomIn", default = { point = "TOPRIGHT", x = -130, y = -30 }, updateVis = "UpdateZoomVisibility" },
        zoomOutAnchor = { toggle = "showZoomOut", default = { point = "TOPRIGHT", x = -130, y = -65 }, updateVis = "UpdateZoomVisibility" },
        calendarAnchor = { toggle = "showCalendar", default = { point = "TOPRIGHT", x = -65, y = -30 }, updateVis = "UpdateCalendarVisibility" },
        addonBar = { toggle = "showAddonBar", default = { point = "TOPRIGHT", x = -10, y = -220 }, updateVis = "UpdateAddonBarVisibility" },
    }

    local cfg = configMap[key]
    if not cfg then return end

    local toggle = cfg.toggle
    local default = cfg.default
    local updateVis = cfg.updateVis

    LEM:AddFrameSettings(f, {
        {
            name = L["Detached"],
            kind = LEM.SettingType.Checkbox,
            get = function()
                return self.db.detached and self.db.detached[key] == true
            end,
            set = function(_, val)
                self.db.detached = self.db.detached or {}
                self.db.detached[key] = val

                self:UpdateFrameAttachment(f, key, val)

                if LEM.RefreshFrameSettings then
                    LEM:RefreshFrameSettings(f)
                end

                -- Apply layout immediately if outside Edit Mode
                if not (LEM and LEM:IsInEditMode()) then
                    if key == "addonBar" then
                        self:UpdateAddonBarLayout()
                    elseif key == "dataTextBar" then
                        self:UpdateDataTextBarVisibility()
                    else
                        self:LayoutDefaultButtons()
                    end
                end
            end,
        },
        {
            name = L["Show"],
            kind = LEM.SettingType.Checkbox,
            get = function()
                return self.db[toggle] ~= false
            end,
            set = function(_, val)
                self.db[toggle] = val
                if self[updateVis] then
                    self[updateVis](self)
                end
            end,
        },
        {
            name = L["X Offset"],
            kind = LEM.SettingType.Slider,
            minValue = -400,
            maxValue = 400,
            valueStep = 1,
            get = function()
                local offset = self.db.offsets and self.db.offsets[key]
                return offset and offset.x or default.x
            end,
            set = function(_, val)
                self.db.offsets = self.db.offsets or {}
                self.db.offsets[key] = self.db.offsets[key] or { point = default.point, x = default.x, y = default.y }
                self.db.offsets[key].x = val
                self:UpdateAnchorPosition(key)
            end,
        },
        {
            name = L["Y Offset"],
            kind = LEM.SettingType.Slider,
            minValue = -400,
            maxValue = 400,
            valueStep = 1,
            get = function()
                local offset = self.db.offsets and self.db.offsets[key]
                return offset and offset.y or default.y
            end,
            set = function(_, val)
                self.db.offsets = self.db.offsets or {}
                self.db.offsets[key] = self.db.offsets[key] or { point = default.point, x = default.x, y = default.y }
                self.db.offsets[key].y = val
                self:UpdateAnchorPosition(key)
            end,
        }
    })
end

local function CreateAnchorFrame(mod, key, name, editModeName, w, h, defaultPos)
    if not mod[key] then
        local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
        f.defaultPos = defaultPos
        f:SetSize(w, h)
        if f.SetFrameStrata then
            f:SetFrameStrata("HIGH")
        end
        if f.SetFrameLevel then
            f:SetFrameLevel(20)
        end
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        local oldStartMoving = f.StartMoving
        f.StartMoving = function(frame, ...)
            local isDet = mod.db.detached and mod.db.detached[key]
            if isDet then
                frame:SetMovable(true)
                oldStartMoving(frame, ...)
            else
                frame:SetMovable(false)
            end
        end
        f.editModeName = editModeName
        f.Layout = function() end -- Protect against native GetParent():Layout() errors

        local container = _G.RoTransitionMinimapContainer or _G.RoithiMinimapContainer
        local isDetached = mod.db.detached and mod.db.detached[key]

        if isDetached or not container then
            f:SetParent(UIParent)
            f:ClearAllPoints()
            local offset = mod.db.offsets and mod.db.offsets[key]
            if not offset or not offset.point or not offset.x or not offset.y then
                offset = defaultPos
            end
            f:SetPoint(offset.point, UIParent, offset.point, offset.x, offset.y)
        else
            f:SetParent(container)
            f:ClearAllPoints()
            local offset = mod.db.offsets and mod.db.offsets[key]
            if not offset or not offset.point or not offset.x or not offset.y then
                offset = defaultPos
            end
            f:SetPoint(offset.point, container, offset.point, offset.x, offset.y)
        end
        f:Show()

        local function OnPositionChanged(self, _, point, x, y)
            local isDet = mod.db.detached and mod.db.detached[key]
            if isDet then
                self:ClearAllPoints()
                self:SetPoint(point, UIParent, point, x, y)
                mod.db.offsets = mod.db.offsets or {}
                mod.db.offsets[key] = { point = point, x = x, y = y }
            else
                -- Attached: snap back to container relative position
                local c = _G.RoithiMinimapContainer
                if c then
                    self:ClearAllPoints()
                    self:SetParent(c)
                    local off = mod.db.offsets and mod.db.offsets[key]
                    if not off or not off.point or not off.x or not off.y then
                        off = defaultPos
                    end
                    local pt = off.point or "BOTTOMLEFT"
                    self:SetPoint(pt, c, pt, off.x, off.y)
                end
            end
        end

        LEM:AddFrame(f, OnPositionChanged, defaultPos)
        local selection = LEM.frameSelections and LEM.frameSelections[f]
        if selection then
            local oldOnDragStart = selection:GetScript("OnDragStart")
            selection:SetScript("OnDragStart", function(sf, button)
                local isDet = mod.db.detached and mod.db.detached[key]
                if isDet then
                    if oldOnDragStart then
                        oldOnDragStart(sf, button)
                    end
                end
            end)
        end
        mod[key] = f
        mod:RegisterAnchorSettings(f, key)
    end
    return mod[key]
end

-- Align default buttons to custom Edit Mode anchors
function MinimapMod:LayoutDefaultButtons()
    if not LEM then return end

    local function HookBlizzardButton(btn, anchor)
        if not btn or btn.isRoithiHooked then return end
        btn.isRoithiHooked = true

        local originalSetParent = btn.SetParent
        btn.SetParent = function(frame, parent)
            originalSetParent(frame, anchor)
        end

        local originalSetPoint = btn.SetPoint
        btn.SetPoint = function(frame, point, relF, relP, x, y)
            originalSetPoint(frame, "CENTER", anchor, "CENTER", 0, 0)
        end

        btn.SetAllPoints = function(frame, relF)
            originalSetPoint(frame, "CENTER", anchor, "CENTER", 0, 0)
        end

        local originalClearAllPoints = btn.ClearAllPoints
        btn.ClearAllPoints = function(frame)
            originalClearAllPoints(frame)
            originalSetPoint(frame, "CENTER", anchor, "CENTER", 0, 0)
        end

        originalSetParent(btn, anchor)
        originalClearAllPoints(btn)
        originalSetPoint(btn, "CENTER", anchor, "CENTER", 0, 0)
    end

    -- Setup Zone Text Anchor
    local zoneTextAnchor = CreateAnchorFrame(self, "zoneTextAnchor", "RoithiZoneTextAnchor", L["Minimap Zone Text"], 130, 20, { point = "TOPRIGHT", x = -80, y = -10 })
    local zoneText = MinimapCluster.ZoneTextButton or MinimapCluster.ZoneTextFrame or _G.MinimapZoneTextButton
    if zoneText then
        zoneText:SetParent(zoneTextAnchor)
        zoneText:ClearAllPoints()
        zoneText:SetPoint("CENTER", zoneTextAnchor, "CENTER", self.db.zoneTextX or 0, self.db.zoneTextY or 0)
    end

    -- Setup Mail Anchor
    local mailAnchor = CreateAnchorFrame(self, "mailAnchor", "RoithiMailAnchor", L["Minimap Mail Frame"], 32, 32, { point = "TOPRIGHT", x = -180, y = -30 })
    local mail = MiniMapMailFrame or (MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame)
    if mail then
        HookBlizzardButton(mail, mailAnchor)
    end

    -- Setup Tracking Anchor
    local trackingAnchor = CreateAnchorFrame(self, "trackingAnchor", "RoithiTrackingAnchor", L["Minimap Tracking Frame"], 32, 32, { point = "TOPRIGHT", x = -30, y = -30 })
    local tracking = MinimapCluster.Tracking or MinimapCluster.TrackingFrame or MiniMapTracking
    if tracking then
        HookBlizzardButton(tracking, trackingAnchor)
    end

    -- Setup LFG Anchor
    local lfgAnchor = CreateAnchorFrame(self, "lfgAnchor", "RoithiLFGAnchor", L["Minimap LFG Frame"], 32, 32, { point = "CENTER", x = 0, y = 0 })
    local lfgs = {}
    if _G.QueueStatusMinimapButton then table.insert(lfgs, _G.QueueStatusMinimapButton) end
    if _G.QueueStatusButton then table.insert(lfgs, _G.QueueStatusButton) end
    for _, lfg in ipairs(lfgs) do
        if lfg then
            if lfg.UpdatePosition then
                lfg.UpdatePosition = function() end
            end
            HookBlizzardButton(lfg, lfgAnchor)
        end
    end

    -- Setup Landing Anchor
    local landingAnchor = CreateAnchorFrame(self, "landingAnchor", "RoithiLandingAnchor", L["Minimap Landing Button"], 36, 36, { point = "TOPRIGHT", x = -30, y = -180 })
    local landings = {}
    if _G.GarrisonLandingPageMinimapButton then table.insert(landings, _G.GarrisonLandingPageMinimapButton) end
    if _G.ExpansionLandingPageMinimapButton then table.insert(landings, _G.ExpansionLandingPageMinimapButton) end
    for _, landing in ipairs(landings) do
        if landing then
            HookBlizzardButton(landing, landingAnchor)

            -- Prevent Blizzard's mixin from offsetting the button relative to landingAnchor
            landing.SetLandingPageIconOffset = function(frame, customOffset)
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", landingAnchor, "CENTER", 0, 0)
            end
            landing.ResetLandingPageIconOffset = function(frame)
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", landingAnchor, "CENTER", 0, 0)
            end
        end
    end

    -- Setup Zoom In Anchor
    local zoomInAnchor = CreateAnchorFrame(self, "zoomInAnchor", "RoithiZoomInAnchor", L["Minimap Zoom In"], 32, 32, { point = "TOPRIGHT", x = -130, y = -30 })
    local zoomIn = Minimap.ZoomIn or _G.MinimapZoomIn
    if zoomIn then
        zoomIn:SetParent(zoomInAnchor)
        zoomIn:ClearAllPoints()
        zoomIn:SetPoint("CENTER", zoomInAnchor, "CENTER", 0, 0)
    end

    -- Setup Zoom Out Anchor
    local zoomOutAnchor = CreateAnchorFrame(self, "zoomOutAnchor", "RoithiZoomOutAnchor", L["Minimap Zoom Out"], 32, 32, { point = "TOPRIGHT", x = -130, y = -65 })
    local zoomOut = Minimap.ZoomOut or _G.MinimapZoomOut
    if zoomOut then
        zoomOut:SetParent(zoomOutAnchor)
        zoomOut:ClearAllPoints()
        zoomOut:SetPoint("CENTER", zoomOutAnchor, "CENTER", 0, 0)
    end

    -- Setup Calendar Anchor
    local calendarAnchor = CreateAnchorFrame(self, "calendarAnchor", "RoithiCalendarAnchor", L["Minimap Calendar Button"], 36, 36, { point = "TOPRIGHT", x = -65, y = -30 })
    if GameTimeFrame then
        GameTimeFrame:SetParent(calendarAnchor)
        GameTimeFrame:ClearAllPoints()
        GameTimeFrame:SetPoint("CENTER", calendarAnchor, "CENTER", 0, 0)

        if not self.isCalendarHooked then
            hooksecurefunc(GameTimeFrame, "Show", function(s)
                if not self.db.showCalendar then
                    s:Hide()
                end
            end)
            self.isCalendarHooked = true
        end
    end
end

function MinimapMod:UpdateAnchorPosition(key)
    local f = self[key]
    if not f or not f.defaultPos then return end
    local container = _G.RoithiMinimapContainer
    local isDetached = self.db.detached and self.db.detached[key]
    self.db.offsets = self.db.offsets or {}
    local offset = self.db.offsets[key]
    if not offset then
        offset = { point = f.defaultPos.point, x = f.defaultPos.x, y = f.defaultPos.y }
        self.db.offsets[key] = offset
    end
    
    offset.x = offset.x or f.defaultPos.x
    offset.y = offset.y or f.defaultPos.y
    offset.point = offset.point or f.defaultPos.point

    if isDetached or not container then
        f:ClearAllPoints()
        f:SetParent(UIParent)
        f:SetPoint(offset.point, UIParent, offset.point, offset.x, offset.y)
    else
        f:ClearAllPoints()
        f:SetParent(container)
        f:SetPoint(offset.point, container, offset.point, offset.x, offset.y)
    end
end

function MinimapMod:UpdateMailVisibility()
    local show = (self.db.showMail ~= false)
    if self.mailAnchor then
        self.mailAnchor:SetShown(show)
    end
end

function MinimapMod:UpdateTrackingVisibility()
    local show = (self.db.showTracking ~= false)
    if self.trackingAnchor then
        self.trackingAnchor:SetShown(show)
    end
end

function MinimapMod:UpdateLFGVisibility()
    local show = (self.db.showLFG ~= false)
    if self.lfgAnchor then
        self.lfgAnchor:SetShown(show)
    end
end

function MinimapMod:UpdateLandingVisibility()
    local show = (self.db.showLanding ~= false)
    if self.landingAnchor then
        self.landingAnchor:SetShown(show)
    end
end

function MinimapMod:UpdateAllElementVisibilities()
    self:UpdateZoneTextVisibility()
    self:UpdateCalendarVisibility()
    self:UpdateZoomVisibility()
    self:UpdateMailVisibility()
    self:UpdateTrackingVisibility()
    self:UpdateLFGVisibility()
    self:UpdateLandingVisibility()
end

function MinimapMod:UpdateZoomVisibility()
    local zoomIn = Minimap.ZoomIn or _G.MinimapZoomIn
    local zoomOut = Minimap.ZoomOut or _G.MinimapZoomOut

    local showIn = (self.db.showZoomIn ~= false) and self.db.showZoom
    local showOut = (self.db.showZoomOut ~= false) and self.db.showZoom

    if zoomIn then zoomIn:SetShown(showIn) end
    if self.zoomInAnchor then self.zoomInAnchor:SetShown(showIn) end

    if zoomOut then zoomOut:SetShown(showOut) end
    if self.zoomOutAnchor then self.zoomOutAnchor:SetShown(showOut) end
end

function MinimapMod:UpdateZoneTextVisibility()
    local zoneText = MinimapCluster.ZoneTextButton or MinimapCluster.ZoneTextFrame or _G.MinimapZoneTextButton
    if zoneText then
        if self.db.showZoneText then
            zoneText:Show()
            if self.zoneTextAnchor then self.zoneTextAnchor:Show() end
        else
            zoneText:Hide()
            if self.zoneTextAnchor then self.zoneTextAnchor:Hide() end
        end
    end
end

function MinimapMod:UpdateCalendarVisibility()
    if GameTimeFrame then
        if self.db.showCalendar then
            GameTimeFrame:Show()
            if self.calendarAnchor then self.calendarAnchor:Show() end
        else
            GameTimeFrame:Hide()
            if self.calendarAnchor then self.calendarAnchor:Hide() end
        end
    end
end




-- ----------------------------------------------------------------------------
-- Minimap Data Text Bar
-- ----------------------------------------------------------------------------
local function GetSectionText(dataType)
    if not dataType or dataType == "None" then
        return ""
    end
    if dataType == "Friends" then
        local onlineBNet = 0
        local onlineChar = 0
        pcall(function()
            if C_BattleNet and C_BattleNet.GetFriendNumOnline then
                onlineBNet = C_BattleNet.GetFriendNumOnline() or 0
            end
        end)
        pcall(function()
            if C_FriendList and C_FriendList.GetNumFriends then
                local numFriends = C_FriendList.GetNumFriends() or 0
                for i = 1, numFriends do
                    local info = C_FriendList.GetFriendInfoByIndex(i)
                    if info and info.connected then
                        onlineChar = onlineChar + 1
                    end
                end
            end
        end)
        return string.format("Friends: |cff00ff00%d|r", onlineBNet + onlineChar)
    elseif dataType == "Time" then
        local formatStr = (MinimapMod.db and MinimapMod.db.dataTextTimeFormat == "24H") and "%H:%M" or "%I:%M %p"
        return date(formatStr)
    elseif dataType == "Date" then
        return date("%a, %b %d")
    elseif dataType == "FPS" then
        return string.format("%d FPS", math.floor(GetFramerate()))
    elseif dataType == "Zone" then
        return GetZoneText() or ""
    elseif dataType == "Latency" then
        local _, _, latencyHome = GetNetStats()
        return string.format("%d ms", latencyHome or 0)
    elseif dataType == "Coordinates" then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                local x, y = pos:GetXY()
                if x and y and x > 0 and y > 0 then
                    return string.format("%.1f, %.1f", x * 100, y * 100)
                end
            end
        end
        return "--, --"
    end
    return ""
end

UpdateDataText = function(bar)
    local db = MinimapMod.db
    if not db.showDataTextBar then return end

    if bar.textLeft then
        bar.textLeft:SetText(GetSectionText(db.dataTextLeftType or "None"))
    end
    if bar.textMiddle then
        bar.textMiddle:SetText(GetSectionText(db.dataTextMiddleType or "Time"))
    end
    if bar.textRight then
        bar.textRight:SetText(GetSectionText(db.dataTextRightType or "None"))
    end
end

local function OnDataTextClick(self, button)
    local db = MinimapMod.db
    local types = {
        db.dataTextMiddleType or "Time",
        db.dataTextLeftType or "None",
        db.dataTextRightType or "None"
    }
    for _, dataType in ipairs(types) do
        if dataType == "Friends" then
            ToggleFriendsFrame()
            break
        elseif dataType == "Time" then
            Stopwatch_Toggle()
            break
        elseif dataType == "Date" then
            ToggleCalendar()
            break
        elseif dataType == "Zone" then
            ToggleWorldMap()
            break
        end
    end
end

function MinimapMod:UpdateDataTextBarLayout()
    local bar = self.dataTextBar
    if not bar then return end

    local container = self.container
    if not container then return end

    if not self.db.showDataTextBar then
        bar:Hide()
        return
    end
    bar:Show()

    local width = self.db.width or self.db.size or 200
    bar:SetSize(width, 20)

    bar:ClearAllPoints()
    bar:SetParent(container)

    -- Background / Border Styling
    local bg = self.db.dataTextBgColor or { r = 0.05, g = 0.05, b = 0.05, a = 0.6 }
    bar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

    if self.db.dataTextPosition == "OUTSIDE" then
        -- State 2: outside bottom with semi transparent border
        bar:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 0, -2)
        bar:SetPoint("TOPRIGHT", container, "BOTTOMRIGHT", 0, -2)
        bar:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.5)
    else
        -- State 1: inside bottom with transparent border
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        bar:SetBackdropBorderColor(0, 0, 0, 0)
        bar:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    end

    -- Create Left, Middle, Right FontStrings if not present
    if not bar.textLeft then
        bar.textLeft = bar:CreateFontString(nil, "OVERLAY")
    end
    if not bar.textMiddle then
        bar.textMiddle = bar:CreateFontString(nil, "OVERLAY")
    end
    if not bar.textRight then
        bar.textRight = bar:CreateFontString(nil, "OVERLAY")
    end

    local font = self.db.unitFrameFont or "Friz Quadrata TT"

    -- Left Section
    bar.textLeft:ClearAllPoints()
    bar.textLeft:SetPoint("LEFT", bar, "LEFT", self.db.dataTextLeftX or 0, self.db.dataTextLeftY or 0)
    LibRoithi.mixins:SetFont(bar.textLeft, font, self.db.dataTextLeftFontSize or 12, "OUTLINE")

    -- Middle Section
    bar.textMiddle:ClearAllPoints()
    bar.textMiddle:SetPoint("CENTER", bar, "CENTER", self.db.dataTextMiddleX or 0, self.db.dataTextMiddleY or 0)
    LibRoithi.mixins:SetFont(bar.textMiddle, font, self.db.dataTextMiddleFontSize or 12, "OUTLINE")

    -- Right Section
    bar.textRight:ClearAllPoints()
    bar.textRight:SetPoint("RIGHT", bar, "RIGHT", self.db.dataTextRightX or 0, self.db.dataTextRightY or 0)
    LibRoithi.mixins:SetFont(bar.textRight, font, self.db.dataTextRightFontSize or 12, "OUTLINE")

    UpdateDataText(bar)
end

function MinimapMod:CreateDataTextBar()
    if self.dataTextBar then return end

    local bar = CreateFrame("Frame", "RoithiMinimapDataTextBar", self.container, "BackdropTemplate")
    bar:SetSize(200, 20)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(true)

    LibRoithi.mixins:CreateBackdrop(bar)

    self.dataTextBar = bar

    bar:SetScript("OnMouseUp", OnDataTextClick)

    local elapsed = 0
    bar:SetScript("OnUpdate", function(f, elap)
        elapsed = elapsed + elap
        if elapsed >= 1.0 then
            UpdateDataText(f)
            elapsed = 0
        end
    end)

    self:UpdateDataTextBarLayout()
end

function MinimapMod:UpdateDataTextBarVisibility()
    self:UpdateDataTextBarLayout()
end




-- ----------------------------------------------------------------------------
-- Options Generation
-- ----------------------------------------------------------------------------
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
                        get = function() return self.db.dataTextPosition or "INSIDE" end,
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
                        get = function() return self.db.dataTextTimeFormat or "12H" end,
                        set = function(_, val)
                            self.db.dataTextTimeFormat = val
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
                                    ["Friends"] = L["Friends"],
                                    ["Time"] = L["Time"],
                                    ["Date"] = L["Date"],
                                    ["FPS"] = L["FPS"],
                                    ["Zone"] = L["Zone"],
                                    ["Latency"] = L["Latency"],
                                    ["Coordinates"] = L["Coordinates"],
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
                                    ["Friends"] = L["Friends"],
                                    ["Time"] = L["Time"],
                                    ["Date"] = L["Date"],
                                    ["FPS"] = L["FPS"],
                                    ["Zone"] = L["Zone"],
                                    ["Latency"] = L["Latency"],
                                    ["Coordinates"] = L["Coordinates"],
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
                                    ["Friends"] = L["Friends"],
                                    ["Time"] = L["Time"],
                                    ["Date"] = L["Date"],
                                    ["FPS"] = L["FPS"],
                                    ["Zone"] = L["Zone"],
                                    ["Latency"] = L["Latency"],
                                    ["Coordinates"] = L["Coordinates"],
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
        },
    }

    if self.UpdateAddonBarOptions then
        self:UpdateAddonBarOptions()
    end
    return options
end

_G.GetMinimapShape = function()
    return MinimapMod.db and MinimapMod.db.shape or "SQUARE"
end

_G.SlashCmdList["ROITHIDEBUG"] = function()
    local debugFrames = {
        { name = "QueueStatusMinimapButton", ref = _G.QueueStatusMinimapButton },
        { name = "QueueStatusButton", ref = _G.QueueStatusButton },
        { name = "ExpansionLandingPageMinimapButton", ref = _G.ExpansionLandingPageMinimapButton },
        { name = "GarrisonLandingPageMinimapButton", ref = _G.GarrisonLandingPageMinimapButton }
    }
    for _, item in ipairs(debugFrames) do
        local lfg = item.ref
        print(string.format("|cff00ff00[RoithiUI Debug]|r %s state:", item.name))
        if not lfg then
            print(string.format("  %s is nil!", item.name))
        else
            print(string.format("  %s exists!", item.name))
            print("    Shown:", lfg:IsShown())
            print("    Visible:", lfg:IsVisible())
            local parent = lfg:GetParent()
            print("    Parent:", parent and (parent.GetName and parent:GetName() or tostring(parent)) or "nil")
            local numPoints = lfg:GetNumPoints()
            print("    NumPoints:", numPoints)
            for i = 1, numPoints do
                local point, relTo, relPoint, x, y = lfg:GetPoint(i)
                print(string.format("      Point %d: %s -> %s (%s) @ %d, %d", i, point, relTo and (relTo.GetName and relTo:GetName() or tostring(relTo)) or "nil", relPoint, x, y))
            end
            print("    Scale:", lfg:GetScale())
            print("    Alpha:", lfg:GetAlpha())
            print("    isRoithiHooked:", lfg.isRoithiHooked)
            if lfg.SetFrameStrata then
                print("    Strata:", lfg:GetFrameStrata())
                print("    Level:", lfg:GetFrameLevel())
            end
        end
    end
    local anchor = _G.RoithiLFGAnchor
    if not anchor then
        print("  RoithiLFGAnchor is nil!")
    else
        print("  RoithiLFGAnchor state:")
        print("    Shown:", anchor:IsShown())
        print("    Visible:", anchor:IsVisible())
        local parent = anchor:GetParent()
        print("    Parent:", parent and (parent.GetName and parent:GetName() or tostring(parent)) or "nil")
        print("    Scale:", anchor:GetScale())
        print("    Alpha:", anchor:GetAlpha())
    end
end
_G.SLASH_ROITHIDEBUG1 = "/roithidebug"
