local addonName, AT = ...
local RoithiUI = AT.RoithiUI or _G.RoithiUI
local MinimapMod = RoithiUI:GetModule("Minimap")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

local Minimap = _G.Minimap
local MinimapCluster = _G.MinimapCluster

local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode-Roithi", true)
local wipe = _G.wipe or function(t) for k in pairs(t) do t[k] = nil end return t end

local IgnoredFrames = {
    ["Minimap"] = true,
    ["MinimapCluster"] = true,
    ["MinimapContainer"] = true,
    ["MinimapZoomIn"] = true,
    ["MinimapZoomOut"] = true,
    ["MinimapBackdrop"] = true,
    ["GameTimeFrame"] = true,
    ["AddonCompartmentFrame"] = true,
    ["ExpansionLandingPageMinimapButton"] = true,
    ["MinimapZoneTextButton"] = true,
    ["QueueStatusButton"] = true,
    ["QueueStatusMinimapButton"] = true,
    ["MiniMapTracking"] = true,
    ["MiniMapTrackingButton"] = true,
    ["MiniMapMailFrame"] = true,
    ["GarrisonLandingPageMinimapButton"] = true,
    ["MinimapZoneTextFrame"] = true,
    ["MinimapCompassTexture"] = true,
    ["MiniMapCraftingOrderFrame"] = true,
    ["AddonCompartmentButton"] = true,
    ["RoithiMinimapBorder"] = true,
    ["TimeManagerClockButton"] = true,
    ["MiniMapVoiceChatFrame"] = true,
    ["MiniMapWorldMapButton"] = true,
    ["MiniMapRecordingButton"] = true,
    ["MiniMapLFGFrame"] = true,
    ["RecycleBinFrame"] = true,
}

local function NormalizeAddonKey(name)
    if not name then return "" end
    local key = name
    key = key:gsub("^LibDBIcon10_", "")
    key = key:gsub("^LibDBIcon_", "")
    key = key:gsub("MinimapButton$", "")
    key = key:gsub("MinimapIcon$", "")
    key = key:gsub("Button$", "")
    key = key:gsub("Icon$", "")
    return key:lower()
end

local function IsIgnoredButton(child)
    if not child then return true end
    local name = child.GetName and child:GetName()
    if not name or name == "" then return true end
    if IgnoredFrames[name] then return true end

    -- Ignore all internal Roithi frames except the specific minimap button
    if name:find("^Roithi") and name ~= "RoithiUIMinimapButton" then return true end
    if name:find("^LibRoithi") then return true end

    -- Ignore frames matching system or non-addon patterns
    if name:find("MinimapCluster") or name:find("MinimapContainer") or name:find("Compass")
        or name:find("ZoneText") or name:find("Tracking") or name:find("TimeManager")
        or name:find("Recording") or name:find("Selection") or name:find("Backdrop")
        or name:find("Border") or name:find("DragProxy") then
        return true
    end

    -- Must be a Button widget
    if not (child.IsObjectType and child:IsObjectType("Button")) then
        return true
    end

    return false
end

local buttonOptionsGroup = {
    type = "group",
    name = L["Arrange Addon Buttons"] or "Arrange Addon Buttons",
    order = 50,
    inline = true,
    args = {}
}

local function FindButtonIcon(button)
    if not button then return end

    if button.icon and button.icon.GetTexture and button.icon:GetTexture() then
        return button.icon:GetTexture()
    end
    if button.Icon and button.Icon.GetTexture and button.Icon:GetTexture() then
        return button.Icon:GetTexture()
    end

    local function ScanRegions(frame)
        if not frame then return end
        if frame.GetRegions then
            for _, obj in ipairs({ frame:GetRegions() }) do
                if obj and obj.IsObjectType and obj:IsObjectType("Texture") and obj.GetTexture then
                    local tex = obj:GetTexture()
                    if tex then
                        local texStr = type(tex) == "string" and tex:lower() or ""
                        if not texStr:find("border") and not texStr:find("background") and not texStr:find("glow") and not texStr:find("shadow") then
                            return tex
                        end
                    end
                end
            end
        end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                local tex = ScanRegions(child)
                if tex then return tex end
            end
        end
    end

    return ScanRegions(button)
end

local isSnapping = false
local function SnapFrameToEdge(f)
    if isSnapping then return end
    isSnapping = true

    local sLeft, sBottom, sW, sH
    if f.GetRect then
        sLeft, sBottom, sW, sH = f:GetRect()
    end
    if sLeft and sBottom then
        local screenW = _G.GetScreenWidth and _G.GetScreenWidth() or 1920
        local screenH = _G.GetScreenHeight and _G.GetScreenHeight() or 1080
        local localScale = f:GetScale() or 1.0
        if localScale == 0 then localScale = 1.0 end

        local x = sLeft
        local y = sBottom
        local targetX
        local targetY

        local w, h = f:GetSize()
        w = (w and w > 0) and w or (sW or 0)
        h = (h and h > 0) and h or (sH or 0)
        local wLayout = w * localScale
        local hLayout = h * localScale

        local snapEdge = MinimapMod.db and MinimapMod.db.addonBarSnapEdge or "AUTO"

        if snapEdge == "TOP" then
            targetY = screenH - hLayout
            targetX = math.max(0, math.min(screenW - wLayout, x))
        elseif snapEdge == "BOTTOM" then
            targetY = 0
            targetX = math.max(0, math.min(screenW - wLayout, x))
        elseif snapEdge == "LEFT" then
            targetX = 0
            targetY = math.max(0, math.min(screenH - hLayout, y))
        elseif snapEdge == "RIGHT" then
            targetX = screenW - wLayout
            targetY = math.max(0, math.min(screenH - hLayout, y))
        else -- "AUTO"
            local distLeft = x
            local distRight = screenW - (x + wLayout)
            local distBottom = y
            local distTop = screenH - (y + hLayout)

            local minDist = math.min(distLeft, distRight, distBottom, distTop)
            if minDist == distLeft then
                targetX = 0
                targetY = math.max(0, math.min(screenH - hLayout, y))
            elseif minDist == distRight then
                targetX = screenW - wLayout
                targetY = math.max(0, math.min(screenH - hLayout, y))
            elseif minDist == distTop then
                targetY = screenH - hLayout
                targetX = math.max(0, math.min(screenW - wLayout, x))
            else
                targetY = 0
                targetX = math.max(0, math.min(screenW - wLayout, x))
            end
        end

        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", targetX / localScale, targetY / localScale)
    end

    isSnapping = false
end

function MinimapMod:CalculateSnapCorner(x, y, screenW, screenH)
    screenW = screenW or (_G.GetScreenWidth and _G.GetScreenWidth() or 1920)
    screenH = screenH or (_G.GetScreenHeight and _G.GetScreenHeight() or 1080)
    local isLeft = x < (screenW / 2)
    local isBottom = y < (screenH / 2)
    if isLeft and not isBottom then
        return "TOPLEFT"
    elseif not isLeft and not isBottom then
        return "TOPRIGHT"
    elseif isLeft and isBottom then
        return "BOTTOMLEFT"
    else
        return "BOTTOMRIGHT"
    end
end

function MinimapMod:SnapAddonBarToEdge()
    if self.addonBar and self.db.addonBarSnap ~= false then
        SnapFrameToEdge(self.addonBar)
    end
end

local function ProtectButton(button)
    if button.isProtected then return end

    button.originalParent = button:GetParent()
    button.originalPoints = {}
    for i = 1, button:GetNumPoints() do
        button.originalPoints[i] = { button:GetPoint(i) }
    end

    local oldSetPoint = button.SetPoint
    button.oldSetPoint = oldSetPoint
    button.SetPoint = function(self, ...)
        if self.isAligning or (MinimapMod.db and MinimapMod.db.showAddonBar == false) then
            oldSetPoint(self, ...)
        end
    end

    local oldSetParent = button.SetParent
    button.oldSetParent = oldSetParent
    button.SetParent = function(self, p)
        if self.isAligning or (MinimapMod.db and MinimapMod.db.showAddonBar == false) then
            oldSetParent(self, p)
        end
    end

    button.isProtected = true
end

local function UnprotectButton(button)
    if not button or not button.isProtected then return end
    if button.oldSetPoint then
        button.SetPoint = button.oldSetPoint
        button.oldSetPoint = nil
    end
    if button.oldSetParent then
        button.SetParent = button.oldSetParent
        button.oldSetParent = nil
    end
    button.isProtected = nil
end

function MinimapMod:UpdateAddonBarAutohide()
    local bar = self.addonBar
    if not bar then return end

    if not self.db.showAddonBar or (LEM and LEM:IsInEditMode()) then
        bar:SetAlpha(1)
        bar:EnableMouse(true)
        if bar.hoverLine then bar.hoverLine:Hide() end
        for _, custom in ipairs(self.activeButtons) do
            custom:SetAlpha(1)
            custom:EnableMouse(false)
            if custom.button then
                custom.button:SetAlpha(1)
                custom.button:EnableMouse(true)
            end
        end
        return
    end

    if self.db.addonBarAutohide and self.db.addonBarAttached == false then
        if not bar.hoverLine then
            bar.hoverLine = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            bar.hoverLine:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            })
            bar.hoverLine:SetFrameStrata("HIGH")
            bar.hoverLine:EnableMouse(true)

            local function OnEnter()
                if self.db.addonBarAutohide and self.db.addonBarAttached == false and not (LEM and LEM:IsInEditMode()) then
                    self.autohideHovered = true
                    bar:SetAlpha(1)
                    bar:EnableMouse(true)
                    self:UpdateAddonBarLayout()
                    for _, custom in ipairs(self.activeButtons) do
                        custom:SetAlpha(1)
                        custom:EnableMouse(false)
                        if custom.button then
                            custom.button:SetAlpha(1)
                            custom.button:EnableMouse(true)
                        end
                    end
                end
            end

            local function OnLeave()
                if self.db.addonBarAutohide and self.db.addonBarAttached == false and not (LEM and LEM:IsInEditMode()) then
                    C_Timer.After(0.2, function()
                        if not self.db.addonBarAutohide or self.db.addonBarAttached ~= false or (LEM and LEM:IsInEditMode()) then return end
                        local hoveringButton = false
                        for _, custom in ipairs(self.activeButtons) do
                            if (custom.button and custom.button:IsMouseOver()) or custom:IsMouseOver() then
                                hoveringButton = true
                                break
                            end
                        end
                        if not bar:IsMouseOver() and not hoveringButton and (not bar.hoverLine or not bar.hoverLine:IsMouseOver()) then
                            self.autohideHovered = false
                            bar:SetAlpha(0)
                            bar:EnableMouse(false)
                            for _, custom in ipairs(self.activeButtons) do
                                custom:SetAlpha(0)
                                custom:EnableMouse(false)
                                if custom.button then
                                    custom.button:EnableMouse(false)
                                end
                            end
                            if bar.hoverLine then
                                bar.hoverLine:Show()
                            end
                            self:UpdateAddonBarLayout()
                        end
                    end)
                end
            end

            bar.hoverLine:SetScript("OnEnter", OnEnter)
            bar.hoverLine:SetScript("OnLeave", OnLeave)
            bar:SetScript("OnEnter", OnEnter)
            bar:SetScript("OnLeave", OnLeave)
        end

        local hc = self.db.addonBarHoverColor or { r = 1, g = 1, b = 1, a = 1 }
        bar.hoverLine:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)

        local screenW = _G.GetScreenWidth and _G.GetScreenWidth() or 1920
        local screenH = _G.GetScreenHeight and _G.GetScreenHeight() or 1080
        local scale = bar.GetEffectiveScale and bar:GetEffectiveScale() or (bar.GetScale and bar:GetScale() or 1.0)
        if scale == 0 then scale = 1.0 end
        local sLeft, sBottom
        if bar.GetRect then
            sLeft, sBottom = bar:GetRect()
        end

        if sLeft and sBottom then
            local x = sLeft
            local y = sBottom
            local w, h = bar:GetSize()
            local barW = w * scale
            local barH = h * scale

            -- Distance to each screen edge
            local distLeft = x
            local distRight = screenW - (x + barW)
            local distBottom = y
            local distTop = screenH - (y + barH)

            -- Determine edge side (respect explicit snapEdge if configured)
            local snapEdge = self.db.addonBarSnapEdge or "AUTO"
            local side = "LEFT"
            if snapEdge == "TOP" or snapEdge == "BOTTOM" or snapEdge == "LEFT" or snapEdge == "RIGHT" then
                side = snapEdge
            else
                local minDist = distLeft
                if distRight < minDist then
                    minDist = distRight
                    side = "RIGHT"
                end
                if distBottom < minDist then
                    minDist = distBottom
                    side = "BOTTOM"
                end
                if distTop < minDist then
                    side = "TOP"
                end
            end

            local thickness = self.db.addonBarHoverThickness or 4
            bar.hoverLine:ClearAllPoints()
            local centerY = (sBottom + barH / 2) - screenH / 2
            local centerX = (sLeft + barW / 2) - screenW / 2

            if side == "LEFT" then
                bar.hoverLine:SetSize(thickness, math.max(60, h))
                bar.hoverLine:SetPoint("LEFT", UIParent, "LEFT", 0, centerY)
            elseif side == "RIGHT" then
                bar.hoverLine:SetSize(thickness, math.max(60, h))
                bar.hoverLine:SetPoint("RIGHT", UIParent, "RIGHT", 0, centerY)
            elseif side == "BOTTOM" then
                bar.hoverLine:SetSize(math.max(60, w), thickness)
                bar.hoverLine:SetPoint("BOTTOM", UIParent, "BOTTOM", centerX, 0)
            elseif side == "TOP" then
                bar.hoverLine:SetSize(math.max(60, w), thickness)
                bar.hoverLine:SetPoint("TOP", UIParent, "TOP", centerX, 0)
            end
        end

        bar.hoverLine:Show()
        bar:SetAlpha(0)
        bar:EnableMouse(false)
        for _, custom in ipairs(self.activeButtons) do
            custom:SetAlpha(0)
            custom:EnableMouse(false)
            if custom.button then
                custom.button:EnableMouse(false)
            end
        end
    else
        if bar.hoverLine then
            bar.hoverLine:Hide()
        end
        bar:SetAlpha(1)
        bar:EnableMouse(true)
        for _, custom in ipairs(self.activeButtons) do
            custom:SetAlpha(1)
            custom:EnableMouse(false)
            if custom.button then
                custom.button:EnableMouse(true)
            end
        end
    end
end

function MinimapMod:IsMouseOverBarOrButtons()
    if not self.addonBar then return false end
    if self.addonBar:IsMouseOver() then return true end
    if self.flyoutTrigger and self.flyoutTrigger:IsMouseOver() then return true end
    if self.expanderButton and self.expanderButton:IsMouseOver() then return true end
    for _, custom in ipairs(self.activeButtons or {}) do
        if custom:IsMouseOver() or (custom.button and custom.button:IsMouseOver()) then
            return true
        end
    end
    return false
end

function MinimapMod:CreateRoithiUIMinimapButton()
    if self.roithiButton then return end

    local btn = CreateFrame("Button", "RoithiUIMinimapButton", Minimap)
    btn:SetSize(30, 30)
    if btn.RegisterForClicks then
        btn:RegisterForClicks("AnyUp")
    end

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexture("Interface\\Icons\\INV_Gizmo_02")
    btn.icon = icon

    btn:SetScript("OnClick", function(_, mouseBtn)
        if mouseBtn == "RightButton" then
            if RoithiUI.OpenConfigWindow then
                RoithiUI:OpenConfigWindow("minimap")
            end
        else
            if RoithiUI.OpenConfigWindow then
                RoithiUI:OpenConfigWindow()
            end
        end
    end)

    btn:SetScript("OnEnter", function(s)
        self:OnBarEnter()
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(s, "ANCHOR_LEFT")
            _G.GameTooltip:AddLine("RoithiUI", 1, 0.8, 0)
            _G.GameTooltip:AddLine(L["Left-Click: Open Addon Settings"] or "Left-Click: Open Addon Settings", 0.8, 0.8, 0.8)
            _G.GameTooltip:AddLine(L["Right-Click: Open Minimap Button Settings"] or "Right-Click: Open Minimap Button Settings", 0.8, 0.8, 0.8)
            _G.GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function()
        self:OnBarLeave()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)

    self.roithiButton = btn
    self.scannedButtons = self.scannedButtons or {}
    self.scannedButtons["RoithiUIMinimapButton"] = btn
end

function MinimapMod:CreateFlyoutTrigger()
    if self.flyoutTrigger or not self.addonBar then return end

    local ft = CreateFrame("Button", "RoithiAddonBarFlyoutTrigger", self.addonBar, "BackdropTemplate")
    ft:SetSize(30, 12)
    if ft.SetBackdrop then
        ft:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeSize = 1,
        })
        ft:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
        ft:SetBackdropBorderColor(0.2, 0.5, 0.9, 0.8)
    end

    local text = ft:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 8, "OUTLINE")
    text:SetPoint("CENTER", ft, "CENTER", 0, 0)
    text:SetText("•••")
    if text.SetTextColor then
        text:SetTextColor(0.4, 0.8, 1, 1)
    end
    ft.arrow = text

    ft:SetScript("OnEnter", function()
        self:OnBarEnter()
        self.flyoutHovered = true
        self:UpdateAddonBarLayout()
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(ft, "ANCHOR_LEFT")
            _G.GameTooltip:SetText(L["Hover to expand all addon buttons"] or "Hover to expand all addon buttons", 1, 1, 1)
            _G.GameTooltip:Show()
        end
    end)

    ft:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        self:OnBarLeave()
    end)

    self.flyoutTrigger = ft
end

function MinimapMod:CreateAddonBarExpander()
    if self.expanderButton or not self.addonBar then return end

    local expander = CreateFrame("Button", "RoithiAddonBarExpander", self.addonBar, "BackdropTemplate")
    expander:SetSize(30, 14)
    if expander.SetBackdrop then
        expander:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeSize = 1,
        })
        expander:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        expander:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end

    local text = expander:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 10, "OUTLINE")
    if text.SetJustifyH then text:SetJustifyH("CENTER") end
    if text.SetJustifyV then text:SetJustifyV("MIDDLE") end
    text:SetPoint("CENTER", expander, "CENTER", 0, -1)
    if text.SetTextColor then
        text:SetTextColor(0.8, 0.8, 0.8, 1)
    end
    local isExpanded = self.db.addonBarExpanded ~= false
    text:SetText(isExpanded and "v" or "^")
    expander.arrow = text

    expander:SetScript("OnClick", function()
        local currentlyExpanded = self.db.addonBarExpanded ~= false
        self.db.addonBarExpanded = not currentlyExpanded
        self.flyoutHovered = false
        if _G.GameTooltip and _G.GameTooltip:GetOwner() == expander then
            _G.GameTooltip:SetText(self.db.addonBarExpanded and L["Click to collapse addon buttons"] or L["Click to expand addon buttons"], 1, 1, 1)
        end
        self:UpdateAddonBarLayout()
    end)

    expander:SetScript("OnEnter", function()
        self:OnBarEnter()
        if _G.GameTooltip then
            local exp = self.db.addonBarExpanded ~= false
            _G.GameTooltip:SetOwner(expander, "ANCHOR_LEFT")
            _G.GameTooltip:SetText(exp and L["Click to collapse addon buttons"] or L["Click to expand addon buttons"], 1, 1, 1)
            _G.GameTooltip:Show()
        end
    end)
    expander:SetScript("OnLeave", function()
        self:OnBarLeave()
        if _G.GameTooltip then
            _G.GameTooltip:Hide()
        end
    end)

    self.expanderButton = expander
end

function MinimapMod:UpdateAddonBarAttachment()
    local bar = self.addonBar
    if not bar then return end

    local key = "addonBar"
    local defaults = { point = "BOTTOMLEFT", x = 10, y = 100 }

    if self.db.addonBarAttached ~= false then
        local parent = self.container or Minimap
        local anchorTarget = parent
        if self.db.showDataTextBar and (self.db.dataTextPosition or "OUTSIDE") == "OUTSIDE" and self.dataTextBar and (not self.dataTextBar.IsShown or self.dataTextBar:IsShown()) then
            anchorTarget = self.dataTextBar
        end

        bar:SetParent(parent)
        if bar.SetFrameStrata then bar:SetFrameStrata("HIGH") end
        if bar.SetFrameLevel then bar:SetFrameLevel(20) end
        bar:ClearAllPoints()
        local spacing = self.db.addonBarAttachedSpacing or 4
        bar:SetPoint("BOTTOMRIGHT", anchorTarget, "BOTTOMLEFT", -spacing, 0)
    else
        bar:SetParent(UIParent)
        if bar.SetFrameStrata then bar:SetFrameStrata("HIGH") end
        if bar.SetFrameLevel then bar:SetFrameLevel(20) end
        bar:ClearAllPoints()
        local offset = self.db.offsets and self.db.offsets[key] or defaults
        bar:SetPoint(offset.point or defaults.point, UIParent, offset.point or defaults.point, offset.x, offset.y)
    end
end

function MinimapMod:ReleaseAllAddonButtons()
    if not self.scannedButtons then return end
    for name, btn in pairs(self.scannedButtons) do
        btn.isAligning = true
        btn.RoithiAlphaHooked = false
        if btn.originalParent then
            btn:SetParent(btn.originalParent)
        else
            btn:SetParent(Minimap)
        end
        btn:ClearAllPoints()
        for _, pt in ipairs(btn.originalPoints or {}) do
            btn:SetPoint(unpack(pt))
        end
        btn:SetAlpha(1)
        btn:Show()
        btn.isAligning = nil

        if self.customButtons and self.customButtons[name] then
            self.customButtons[name]:Hide()
        end
    end
end

function MinimapMod:CreateAddonBar()
    if self.addonBar then return end

    local bar = CreateFrame("Frame", "RoithiAddonBar", UIParent, "BackdropTemplate")
    bar:SetSize(40, 40)
    if bar.SetFrameStrata then
        bar:SetFrameStrata("HIGH")
    end
    if bar.SetFrameLevel then
        bar:SetFrameLevel(20)
    end
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    local key = "addonBar"

    LibRoithi.mixins:CreateBackdrop(bar)
    local bg = self.db.addonBarBgColor or { r = 0, g = 0, b = 0, a = 0.6 }
    bar:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

    self.addonBar = bar
    self.bar = bar

    if not self.hiddenFrame then
        self.hiddenFrame = CreateFrame("Frame")
        self.hiddenFrame:Hide()
    end

    self:CreateAddonBarExpander()
    self:UpdateAddonBarAttachment()

    local defaults = { point = "BOTTOMLEFT", x = 10, y = 100 }

    if LEM then
        bar.editModeName = L["Addon Button Bar"]

        local function OnPositionChanged(f, _, point, x, y)
            local inEditMode = LEM and LEM:IsInEditMode()

            if inEditMode then
                if not self.db.addonBarAttached then
                    f:SetParent(UIParent)
                    f:SetFrameStrata("HIGH")
                    f:SetFrameLevel(20)
                    f:ClearAllPoints()
                    f:SetPoint(point, UIParent, point, x, y)

                    self.db.offsets = self.db.offsets or {}
                    self.db.offsets[key] = { point = point, x = x, y = y }

                    if self.db.addonBarSnap then
                        SnapFrameToEdge(f)
                        local sPoint, _, _, sX, sY = f:GetPoint(1)
                        if sPoint then
                            self.db.offsets[key] = { point = sPoint, x = sX, y = sY }
                        end
                    end
                else
                    self:UpdateAddonBarAttachment()
                end
                return
            end

            -- Outside Edit Mode
            self:UpdateAddonBarAttachment()
            self:UpdateAddonBarAutohide()
        end

        LEM:AddFrame(bar, OnPositionChanged, defaults)

        local settings = {
            {
                name = L["Attached to Minimap"],
                kind = LEM.SettingType.Checkbox,
                default = true,
                get = function() return self.db.addonBarAttached ~= false end,
                set = function(_, val)
                    self.db.addonBarAttached = val
                    self:UpdateAddonBarAttachment()
                    LEM:RefreshFrameSettings(bar)
                end,
            },
            {
                name = L["Snap Edge"],
                kind = LEM.SettingType.Dropdown,
                default = "AUTO",
                values = {
                    { text = L["Auto"], value = "AUTO" },
                    { text = L["Top"], value = "TOP" },
                    { text = L["Bottom"], value = "BOTTOM" },
                    { text = L["Left"], value = "LEFT" },
                    { text = L["Right"], value = "RIGHT" },
                },
                get = function() return self.db.addonBarSnapEdge or "AUTO" end,
                set = function(_, val)
                    self.db.addonBarSnapEdge = val
                    if not self.db.addonBarAttached then
                        SnapFrameToEdge(bar)
                    end
                end,
            },
            {
                name = L["Expansion Mode"] or "Expansion Mode",
                kind = LEM.SettingType.Dropdown,
                default = "STANDARD",
                values = {
                    { text = L["Standard (Base + Hover All)"] or "Standard (Base + Hover All)", value = "STANDARD" },
                    { text = L["Direct (Full Expand on Click)"] or "Direct (Full Expand on Click)", value = "DIRECT_ALL" },
                    { text = L["Always Base (Toggle All on Click)"] or "Always Base (Toggle All on Click)", value = "ALWAYS_BASE" },
                },
                get = function() return self.db.addonBarExpansionMode or "STANDARD" end,
                set = function(_, val)
                    self.db.addonBarExpansionMode = val
                    self:UpdateAddonBarLayout()
                end,
            },
            {
                name = L["Visible Buttons"],
                kind = LEM.SettingType.Slider,
                default = 3,
                minValue = 1,
                maxValue = 10,
                valueStep = 1,
                formatter = function(v) return string.format("%.0f", v) end,
                get = function() return self.db.addonBarVisibleCount or 3 end,
                set = function(_, val)
                    self.db.addonBarVisibleCount = val
                    self:UpdateAddonBarLayout()
                end,
            },
            {
                name = L["Button Size"],
                kind = LEM.SettingType.Slider,
                default = 30,
                minValue = 16,
                maxValue = 48,
                valueStep = 1,
                formatter = function(v) return string.format("%.0f", v) end,
                get = function() return self.db.addonBarButtonSize or 30 end,
                set = function(_, val)
                    self.db.addonBarButtonSize = val
                    self:ScanAddonButtons()
                end,
            },
            {
                name = L["Button Spacing"],
                kind = LEM.SettingType.Slider,
                default = 4,
                minValue = 0,
                maxValue = 20,
                valueStep = 1,
                formatter = function(v) return string.format("%.0f", v) end,
                get = function() return self.db.addonBarSpacing or 4 end,
                set = function(_, val)
                    self.db.addonBarSpacing = val
                    self:UpdateAddonBarLayout()
                end,
            },
            {
                name = L["Grow Direction"] or "Grow Direction",
                kind = LEM.SettingType.Dropdown,
                default = "UP_LEFT",
                values = {
                    { text = L["Left, Wrap Down"] or "Left, Wrap Down", value = "LEFT_DOWN" },
                    { text = L["Left, Wrap Up"] or "Left, Wrap Up", value = "LEFT_UP" },
                    { text = L["Right, Wrap Down"] or "Right, Wrap Down", value = "RIGHT_DOWN" },
                    { text = L["Right, Wrap Up"] or "Right, Wrap Up", value = "RIGHT_UP" },
                    { text = L["Down, Wrap Left"] or "Down, Wrap Left", value = "DOWN_LEFT" },
                    { text = L["Down, Wrap Right"] or "Down, Wrap Right", value = "DOWN_RIGHT" },
                    { text = L["Up, Wrap Left"] or "Up, Wrap Left", value = "UP_LEFT" },
                    { text = L["Up, Wrap Right"] or "Up, Wrap Right", value = "UP_RIGHT" },
                },
                get = function() return self.db.addonBarGrowDirection or "UP_LEFT" end,
                set = function(_, val)
                    self.db.addonBarGrowDirection = val
                    self:UpdateAddonBarLayout()
                end,
            },
            {
                name = L["Breakpoint (Button Amount)"] or "Breakpoint (Button Amount)",
                kind = LEM.SettingType.Slider,
                default = 5,
                minValue = 1,
                maxValue = 20,
                valueStep = 1,
                formatter = function(v) return string.format("%.0f", v) end,
                get = function() return self.db.addonBarBreakpoint or self.db.addonBarColumns or 5 end,
                set = function(_, val)
                    self.db.addonBarBreakpoint = val
                    self.db.addonBarColumns = val
                    self:UpdateAddonBarLayout()
                end,
            },
        }
        if LEM.AddFrameSettings then
            LEM:AddFrameSettings(bar, settings)
        end
    end

    bar:SetScript("OnEnter", function() self:OnBarEnter() end)
    bar:SetScript("OnLeave", function() self:OnBarLeave() end)
end


function MinimapMod:UpdateAddonBarVisibility()
    if not self.addonBar then return end
    if self.db.showAddonBar then
        self.addonBar:SetShown(true)
        self:ScanAddonButtons()
    else
        local inEditMode = LEM and LEM:IsInEditMode()
        self.addonBar:SetShown(inEditMode)

        for name, btn in pairs(self.scannedButtons) do
            btn.isAligning = true
            btn.RoithiAlphaHooked = false
            if btn.originalParent then
                btn:SetParent(btn.originalParent)
            else
                btn:SetParent(Minimap)
            end
            btn:ClearAllPoints()
            for _, pt in ipairs(btn.originalPoints or {}) do
                btn:SetPoint(unpack(pt))
            end
            btn:SetAlpha(1)
            btn:Show()
            btn.isAligning = nil

            if self.customButtons and self.customButtons[name] then
                self.customButtons[name]:Hide()
            end
        end
    end
end

function MinimapMod:OnBarEnter()
    if self.db.addonBarAutohide and self.db.addonBarAttached == false and not (LEM and LEM:IsInEditMode()) then
        self.autohideHovered = true
        self.addonBar:SetAlpha(1)
        self.addonBar:EnableMouse(true)
        self:UpdateAddonBarLayout()
        for _, custom in ipairs(self.activeButtons) do
            custom:SetAlpha(1)
            custom:EnableMouse(false)
            if custom.button then
                custom.button:EnableMouse(true)
            end
        end
        if self.addonBar.hoverLine then self.addonBar.hoverLine:Hide() end
    end
end

function MinimapMod:OnBarLeave()
    if self.flyoutHovered then
        C_Timer.After(0.2, function()
            if not self:IsMouseOverBarOrButtons() then
                self.flyoutHovered = false
                self:UpdateAddonBarLayout()
            end
        end)
    end

    if self.db.addonBarAutohide and self.db.addonBarAttached == false and not (LEM and LEM:IsInEditMode()) then
        C_Timer.After(0.1, function()
            if not self.addonBar:IsMouseOver() then
                local hoveringButton = false
                for _, custom in ipairs(self.activeButtons) do
                    if custom:IsMouseOver() or (custom.button and custom.button:IsMouseOver()) then
                        hoveringButton = true
                        break
                    end
                end
                if not hoveringButton and (self.addonBar.hoverLine and not self.addonBar.hoverLine:IsMouseOver()) then
                    self.autohideHovered = false
                    self.addonBar:SetAlpha(0)
                    self.addonBar:EnableMouse(false)
                    for _, custom in ipairs(self.activeButtons) do
                        custom:SetAlpha(0)
                        custom:EnableMouse(false)
                        if custom.button then
                            custom.button:EnableMouse(false)
                        end
                    end
                    self.addonBar.hoverLine:Show()
                    self:UpdateAddonBarLayout()
                end
            end
        end)
    end
end

function MinimapMod:UpdateAddonBarOptions()
    if not buttonOptionsGroup or not buttonOptionsGroup.args then return end
    local args = buttonOptionsGroup.args
    wipe(args)
    args.arranger = {
        type = "input",
        dialogControl = "RoithiButtonArranger",
        name = "",
        width = "full",
        order = 1,
        get = function() return "" end,
        set = function() end,
    }
end

function MinimapMod:ScanAddonButtons()
    if not self.db.showAddonBar then return end
    self.scannedButtons = self.scannedButtons or {}

    -- Clean up any invalid, non-button, or ignored frames from earlier scans
    for sName, sBtn in pairs(self.scannedButtons) do
        if IsIgnoredButton(sBtn) then
            self.scannedButtons[sName] = nil
            if self.customButtons and self.customButtons[sName] then
                self.customButtons[sName]:Hide()
                self.customButtons[sName] = nil
            end
        end
    end

    self:CreateRoithiUIMinimapButton()

    local knownKeys = {}
    local knownButtons = {}

    local function RegisterButton(btn, keyName, rawName)
        if not btn or knownButtons[btn] then return end
        local norm = NormalizeAddonKey(keyName or rawName)
        if norm ~= "" and knownKeys[norm] then return end

        knownButtons[btn] = true
        if norm ~= "" then knownKeys[norm] = true end
        self.scannedButtons[rawName] = btn

        if btn.HookScript and btn.HasScript and btn:HasScript("OnEnter") and not btn.roithiEnterHooked then
            btn:HookScript("OnEnter", function() self:OnBarEnter() end)
            btn.roithiEnterHooked = true
        end
        if btn.HookScript and btn.HasScript and btn:HasScript("OnLeave") and not btn.roithiLeaveHooked then
            btn:HookScript("OnLeave", function() self:OnBarLeave() end)
            btn.roithiLeaveHooked = true
        end
    end

    -- 1. Scan LibDBIcon FIRST (canonical registered addon buttons)
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDBIcon and LDBIcon.GetButtonList then
        for _, btnName in ipairs(LDBIcon:GetButtonList()) do
            local btn = LDBIcon:GetMinimapButton(btnName)
            if btn and not IsIgnoredButton(btn) then
                local actualName = btn:GetName() or ("LibDBIcon10_" .. btnName)
                RegisterButton(btn, btnName, actualName)
            end
        end
    end

    -- 2. Scan Minimap, MinimapCluster, MinimapBackdrop for non-LibDBIcon standalone buttons
    local function TryAddButton(child)
        if not child or IsIgnoredButton(child) then return end
        local name = (child.GetName and child:GetName()) or nil
        if not name or name == "" then return end

        -- Prevent scanning children of self.addonBar or custom buttons
        local parent = child.GetParent and child:GetParent()
        local parentName = (parent and parent.GetName and parent:GetName()) or nil
        if parent == self.addonBar or (parentName and parentName:find("^RoithiAddonButton_")) then
            return
        end

        -- Prevent scanning children of already-registered buttons
        for _, existing in pairs(self.scannedButtons) do
            if child == existing or parent == existing then
                return
            end
        end

        RegisterButton(child, name, name)
    end

    if Minimap and Minimap.GetChildren then
        for _, child in ipairs({ Minimap:GetChildren() }) do
            TryAddButton(child)
        end
    end

    if MinimapCluster and MinimapCluster.GetChildren then
        for _, child in ipairs({ MinimapCluster:GetChildren() }) do
            TryAddButton(child)
        end
    end

    if _G.MinimapBackdrop and _G.MinimapBackdrop.GetChildren then
        for _, child in ipairs({ _G.MinimapBackdrop:GetChildren() }) do
            TryAddButton(child)
        end
    end

    self:UpdateAddonBarLayout()
    self:UpdateAddonBarOptions()
end

function MinimapMod:UpdateAddonBarLayout()
    if not self.addonBar then return end

    if self.db.showAddonBar == false then
        if self.addonBar then self.addonBar:Hide() end
        if self.expanderButton then self.expanderButton:Hide() end
        if self.flyoutTrigger then self.flyoutTrigger:Hide() end
        for _, btn in pairs(self.scannedButtons or {}) do
            UnprotectButton(btn)
            btn.isAligning = true
            if btn.originalParent and btn.SetParent then
                btn:SetParent(btn.originalParent)
            elseif Minimap and btn.SetParent then
                btn:SetParent(Minimap)
            end
            if btn.originalPoints and #btn.originalPoints > 0 and btn.ClearAllPoints and btn.SetPoint then
                btn:ClearAllPoints()
                for _, pt in ipairs(btn.originalPoints) do
                    btn:SetPoint(unpack(pt))
                end
            end
            btn.isAligning = nil
            if btn.Show then btn:Show() end
        end
        return
    end

    self.activeButtons = {}
    self.customButtons = self.customButtons or {}

    local bg = self.db.addonBarBgColor or { r = 0, g = 0, b = 0, a = 0.6 }
    self.addonBar:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

    self.db.addonBarButtons = self.db.addonBarButtons or {}
    for name, btn in pairs(self.scannedButtons) do
        local enabled = self.db.addonBarButtons[name] ~= false
        if enabled then
            ProtectButton(btn)

            local custom = self.customButtons[name]
            if not custom then
                custom = CreateFrame("Frame", "RoithiAddonButton_" .. name, self.addonBar, "BackdropTemplate")
                if custom.SetBackdrop then
                    custom:SetBackdrop({
                        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
                        edgeSize = 1,
                    })
                    custom:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
                    custom:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                end

                custom.icon = custom:CreateTexture(nil, "ARTWORK")
                if custom.icon then
                    local iconTex = FindButtonIcon(btn) or "Interface\\Icons\\INV_Misc_QuestionMark"
                    if custom.icon.SetTexture then custom.icon:SetTexture(iconTex) end
                    if custom.icon.SetAllPoints then custom.icon:SetAllPoints(custom) end
                    if custom.icon.SetTexCoord then custom.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                end

                custom:EnableMouse(false)

                custom.button = btn
                self.customButtons[name] = custom
            end

            custom.button = btn
            local btnSize = self.db.addonBarButtonSize or 30
            custom:SetSize(btnSize, btnSize)
            custom:EnableMouse(false)
            custom:Show()

            local function CleanTexture(region)
                if region and region:IsObjectType("Texture") then
                    local tex = region:GetTexture()
                    local texPath = type(tex) == "string" and tex:lower() or ""
                    local isBorder = texPath:find("border") or texPath:find("tracking") or texPath:find("overlay") or texPath:find("shine") or texPath:find("background")
                    if not isBorder and type(tex) == "number" then
                        if tex == 136430 or tex == 136467 or tex == 136468 then
                            isBorder = true
                        end
                    end
                    if isBorder then
                        region:SetAlpha(0)
                    end
                end
            end

            if btn.GetRegions then
                for _, region in ipairs({ btn:GetRegions() }) do
                    CleanTexture(region)
                end
            end
            if btn.GetChildren then
                for _, child in ipairs({ btn:GetChildren() }) do
                    if child.GetRegions and not (child.IsObjectType and child:IsObjectType("Button")) then
                        for _, region in ipairs({ child:GetRegions() }) do
                            CleanTexture(region)
                        end
                    end
                end
            end

            local bIcon = btn.icon or btn.Icon or _G[btn:GetName() and (btn:GetName() .. "Icon")]
            if bIcon and bIcon.SetTexCoord then
                bIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                if bIcon.ClearAllPoints then bIcon:ClearAllPoints() end
                if bIcon.SetAllPoints then bIcon:SetAllPoints(btn) end
            end

            local barLevel = (self.addonBar and self.addonBar.GetFrameLevel and self.addonBar:GetFrameLevel()) or 20
            local barStrata = (self.addonBar and self.addonBar.GetFrameStrata and self.addonBar:GetFrameStrata()) or "HIGH"

            if custom.SetFrameStrata then
                custom:SetFrameStrata(barStrata)
            end
            if custom.SetFrameLevel then
                custom:SetFrameLevel(barLevel + 2)
            end
            custom:EnableMouse(false)

            btn.isAligning = true
            btn:SetParent(custom)
            if btn.SetFixedFrameStrata then
                btn:SetFixedFrameStrata(false)
            end
            if btn.SetFixedFrameLevel then
                btn:SetFixedFrameLevel(false)
            end
            if btn.SetFrameStrata then
                btn:SetFrameStrata(barStrata)
            end
            if btn.SetFrameLevel then
                btn:SetFrameLevel(barLevel + 5)
            end
            if btn.ClearAllPoints then btn:ClearAllPoints() end
            if btn.SetAllPoints then btn:SetAllPoints(custom) end
            if btn.SetSize then btn:SetSize(btnSize, btnSize) end
            if btn.EnableMouse then btn:EnableMouse(true) end
            if btn.RegisterForClicks then
                btn:RegisterForClicks("AnyUp")
            end
            if btn.SetAlpha then btn:SetAlpha(1) end
            if btn.Show then btn:Show() end
            btn.isAligning = nil

            table.insert(self.activeButtons, custom)
        else
            btn.isAligning = true
            if btn.SetParent then btn:SetParent(self.hiddenFrame or Minimap) end
            if btn.Hide then btn:Hide() end
            btn.isAligning = nil
            btn.RoithiAlphaHooked = false

            if self.customButtons[name] then
                self.customButtons[name]:Hide()
            end
        end
    end

    table.sort(self.activeButtons, function(a, b)
        local order = self.db.addonBarButtonOrder
        local nameA = a.button and a.button:GetName() or a:GetName()
        local nameB = b.button and b.button:GetName() or b:GetName()
        if order and #order > 0 then
            local idxA, idxB
            for i, n in ipairs(order) do
                if n == nameA then idxA = i end
                if n == nameB then idxB = i end
            end
            if idxA and idxB then return idxA < idxB end
            if idxA then return true end
            if idxB then return false end
        end
        return nameA < nameB
    end)

    local count = #self.activeButtons
    local cols = self.db.addonBarColumns or 1
    local spacing = self.db.addonBarSpacing or 4
    local scale = self.db.addonBarScale or 1.0
    local btnSize = self.db.addonBarButtonSize or 30
    local expanderHeight = self.db.addonBarExpanderSize or 16

    if count == 0 then
        if self.expanderButton then self.expanderButton:Hide() end
        if self.flyoutTrigger then self.flyoutTrigger:Hide() end
        self.addonBar:SetSize(40, 40)
        self.addonBar:SetAlpha(LEM and LEM:IsInEditMode() and 1 or 0)
        return
    end

    local mode = self.db.addonBarExpansionMode or "STANDARD"
    if mode ~= "STANDARD" then
        self.flyoutHovered = false
    end
    local visibleCount = self.db.addonBarVisibleCount or 3
    if visibleCount < 1 then visibleCount = 3 end
    local isExpanded = self.db.addonBarExpanded ~= false
    local isFlyout = self.flyoutHovered == true

    local isAutohideActive = self.db.addonBarAutohide and self.db.addonBarAttached == false
    local shownCount
    if isAutohideActive then
        if self.autohideHovered then
            shownCount = count
        else
            shownCount = 0
        end
    elseif mode == "ALWAYS_BASE" then
        if isExpanded or isFlyout then
            shownCount = count
        else
            shownCount = math.min(count, visibleCount)
        end
    elseif mode == "DIRECT_ALL" then
        if isExpanded or isFlyout then
            shownCount = count
        else
            shownCount = 0
        end
    else -- "STANDARD"
        if isFlyout then
            shownCount = count
        elseif isExpanded then
            shownCount = math.min(count, visibleCount)
        else
            shownCount = 0
        end
    end

    self.addonBar:SetScale(scale)

    local isAttached = self.db.addonBarAttached ~= false
    local userBreakpoint = self.db.addonBarBreakpoint or (cols > 1 and cols) or 1
    if userBreakpoint < 1 then userBreakpoint = 1 end

    local growDir = self.db.addonBarGrowDirection
    if not growDir then
        if cols > 1 then
            growDir = "RIGHT_DOWN"
        elseif isAttached then
            growDir = "UP_LEFT"
        else
            growDir = "DOWN_RIGHT"
        end
    end

    local cellW = btnSize + spacing
    local cellH = btnSize + spacing
    local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080

    local primAxis, primSign, secSign
    if growDir == "LEFT_DOWN" then
        primAxis, primSign, secSign = "X", -1, -1
    elseif growDir == "LEFT_UP" then
        primAxis, primSign, secSign = "X", -1, 1
    elseif growDir == "RIGHT_DOWN" then
        primAxis, primSign, secSign = "X", 1, -1
    elseif growDir == "RIGHT_UP" then
        primAxis, primSign, secSign = "X", 1, 1
    elseif growDir == "DOWN_LEFT" then
        primAxis, primSign, secSign = "Y", -1, -1
    elseif growDir == "DOWN_RIGHT" then
        primAxis, primSign, secSign = "Y", -1, 1
    elseif growDir == "UP_LEFT" then
        primAxis, primSign, secSign = "Y", 1, -1
    elseif growDir == "UP_RIGHT" then
        primAxis, primSign, secSign = "Y", 1, 1
    else
        primAxis, primSign, secSign = "X", -1, -1
    end

    -- Screen-edge capacity detection
    local maxFitPrim = userBreakpoint
    if isAttached then
        local anchorTarget = self.container or Minimap
        if self.db.showDataTextBar and (self.db.dataTextPosition or "OUTSIDE") == "OUTSIDE" and self.dataTextBar and (not self.dataTextBar.IsShown or self.dataTextBar:IsShown()) then
            anchorTarget = self.dataTextBar
        end
        local anchorLeft = (anchorTarget and anchorTarget.GetLeft and anchorTarget:GetLeft())
            or (self.container and self.container.GetLeft and self.container:GetLeft())
            or (Minimap and Minimap.GetLeft and Minimap:GetLeft())
        local anchorBottom = (anchorTarget and anchorTarget.GetBottom and anchorTarget:GetBottom())
            or (self.container and self.container.GetBottom and self.container:GetBottom())
            or (Minimap and Minimap.GetBottom and Minimap:GetBottom())
        local anchorTop = (anchorTarget and anchorTarget.GetTop and anchorTarget:GetTop())
            or (self.container and self.container.GetTop and self.container:GetTop())
            or (Minimap and Minimap.GetTop and Minimap:GetTop())

        if primAxis == "X" then
            if primSign == -1 and anchorLeft then
                local availDist = anchorLeft - spacing
                if availDist > 0 then
                    maxFitPrim = math.max(1, math.floor((availDist - spacing) / cellW))
                end
            elseif primSign == 1 and anchorLeft then
                local availDist = screenW - anchorLeft - spacing
                if availDist > 0 then
                    maxFitPrim = math.max(1, math.floor((availDist - spacing) / cellW))
                end
            end
        else
            if primSign == -1 and anchorBottom then
                local availDist = anchorBottom - spacing - expanderHeight
                if availDist > 0 then
                    maxFitPrim = math.max(1, math.floor((availDist - spacing) / cellH))
                end
            elseif primSign == 1 then
                local baseBottom = anchorBottom or (anchorTop and (anchorTop - 200))
                local availDist = baseBottom and (screenH - baseBottom - spacing) or (screenH - (anchorTop or 0) - spacing)
                if availDist > 0 then
                    maxFitPrim = math.max(1, math.floor((availDist - spacing) / cellH))
                end
            end
        end
    else
        local barLeft = self.addonBar and self.addonBar.GetLeft and self.addonBar:GetLeft()
        local barRight = self.addonBar and self.addonBar.GetRight and self.addonBar:GetRight()
        local barTop = self.addonBar and self.addonBar.GetTop and self.addonBar:GetTop()
        local barBottom = self.addonBar and self.addonBar.GetBottom and self.addonBar:GetBottom()

        if barLeft and barRight and barTop and barBottom then
            if primAxis == "X" then
                if primSign == -1 then
                    local availDist = barRight
                    maxFitPrim = math.max(1, math.floor((availDist - spacing) / cellW))
                else
                    local availDist = screenW - barLeft
                    maxFitPrim = math.max(1, math.floor((availDist - spacing) / cellW))
                end
            else
                if primSign == -1 then
                    local availDist = barTop - expanderHeight
                    maxFitPrim = math.max(1, math.floor((availDist - spacing) / cellH))
                else
                    local availDist = screenH - barBottom
                    maxFitPrim = math.max(1, math.floor((availDist - spacing) / cellH))
                end
            end
        end
    end

    local effectiveBreakpoint = isAttached and math.min(userBreakpoint, maxFitPrim) or userBreakpoint
    if effectiveBreakpoint < 1 then effectiveBreakpoint = 1 end

    local primCount = math.min(math.max(1, shownCount), effectiveBreakpoint)
    local secCount = math.ceil(math.max(1, shownCount) / effectiveBreakpoint)
    if secCount < 1 then secCount = 1 end

    local totalCols, totalRows
    if primAxis == "X" then
        totalCols = primCount
        totalRows = secCount
    else
        totalCols = secCount
        totalRows = primCount
    end

    local normalWidth = totalCols * btnSize + (totalCols + 1) * spacing

    if shownCount == 0 then
        if self.flyoutTrigger then self.flyoutTrigger:Hide() end
        for _, customBtn in ipairs(self.activeButtons) do
            customBtn:Hide()
            if customBtn.button then customBtn.button:Hide() end
        end

        local collapsedWidth = math.max(16, math.floor(normalWidth / 4))
        local collapsedHeight = (self.db.showDataTextBar and 20) or expanderHeight
        self.addonBar:SetSize(collapsedWidth, collapsedHeight)

        if not self.expanderButton then
            self:CreateAddonBarExpander()
        end
        if self.expanderButton then
            self.expanderButton:ClearAllPoints()
            self.expanderButton:SetAllPoints(self.addonBar)
            if self.expanderButton.arrow then
                self.expanderButton.arrow:ClearAllPoints()
                self.expanderButton.arrow:SetPoint("CENTER", self.expanderButton, "CENTER", 0, -1)
                self.expanderButton.arrow:SetText("^")
            end
            self.expanderButton:Show()
        end
    else
        local width = normalWidth
        local buttonsHeight = totalRows * btnSize + (totalRows + 1) * spacing
        local showFlyoutTrigger = (mode == "STANDARD" and not isFlyout and shownCount < count)
        local flyoutHeight = showFlyoutTrigger and 12 or 0
        local totalHeight = buttonsHeight + expanderHeight + spacing + (flyoutHeight > 0 and (flyoutHeight + spacing) or 0)

        self.addonBar:SetSize(width, totalHeight)

        local startY = spacing
        if showFlyoutTrigger then
            if not self.flyoutTrigger then
                self:CreateFlyoutTrigger()
            end
            local barLevel = (self.addonBar and self.addonBar.GetFrameLevel and self.addonBar:GetFrameLevel()) or 20
            local barStrata = (self.addonBar and self.addonBar.GetFrameStrata and self.addonBar:GetFrameStrata()) or "HIGH"
            if self.flyoutTrigger.SetFrameStrata then self.flyoutTrigger:SetFrameStrata(barStrata) end
            if self.flyoutTrigger.SetFrameLevel then self.flyoutTrigger:SetFrameLevel(barLevel + 5) end
            self.flyoutTrigger:ClearAllPoints()
            self.flyoutTrigger:SetPoint("TOPLEFT", self.addonBar, "TOPLEFT", spacing, -spacing)
            self.flyoutTrigger:SetSize(width - spacing * 2, flyoutHeight)
            self.flyoutTrigger:Show()
            startY = spacing + flyoutHeight + spacing
        else
            if self.flyoutTrigger then self.flyoutTrigger:Hide() end
        end

        for idx, customBtn in ipairs(self.activeButtons) do
            if idx <= shownCount then
                local primIdx = (idx - 1) % effectiveBreakpoint
                local secIdx = math.floor((idx - 1) / effectiveBreakpoint)

                local col, row
                if primAxis == "X" then
                    col = (primSign == 1) and primIdx or ((primCount - 1) - primIdx)
                    row = (secSign == -1) and secIdx or ((secCount - 1) - secIdx)
                else
                    row = (primSign == -1) and primIdx or ((primCount - 1) - primIdx)
                    col = (secSign == 1) and secIdx or ((secCount - 1) - secIdx)
                end

                local x = spacing + col * cellW
                local y = -(startY + row * cellH)

                customBtn:ClearAllPoints()
                customBtn:SetPoint("TOPLEFT", self.addonBar, "TOPLEFT", x, y)
                customBtn:Show()
                if customBtn.button then
                    customBtn.button:Show()
                end
            else
                customBtn:Hide()
                if customBtn.button then
                    customBtn.button:Hide()
                end
            end
        end

        if not self.expanderButton then
            self:CreateAddonBarExpander()
        end

        if self.expanderButton then
            local barLevel = (self.addonBar and self.addonBar.GetFrameLevel and self.addonBar:GetFrameLevel()) or 20
            local barStrata = (self.addonBar and self.addonBar.GetFrameStrata and self.addonBar:GetFrameStrata()) or "HIGH"
            if self.expanderButton.SetFrameStrata then self.expanderButton:SetFrameStrata(barStrata) end
            if self.expanderButton.SetFrameLevel then self.expanderButton:SetFrameLevel(barLevel + 5) end
            self.expanderButton:ClearAllPoints()
            self.expanderButton:SetPoint("TOPLEFT", self.addonBar, "TOPLEFT", spacing, -(startY + buttonsHeight))
            self.expanderButton:SetSize(width - spacing * 2, expanderHeight)
            if self.expanderButton.arrow then
                local arrowGlyph
                if mode == "ALWAYS_BASE" then
                    arrowGlyph = (isExpanded or isFlyout) and "v" or "^"
                else
                    arrowGlyph = (shownCount > 0) and "v" or "^"
                end
                self.expanderButton.arrow:SetText(arrowGlyph)
            end
            self.expanderButton:Show()
        end
    end

    self:UpdateAddonBarAttachment()
    self:UpdateAddonBarAutohide()
    if self.UpdateBuffFrameDisplacement then
        self:UpdateBuffFrameDisplacement()
    end
end

function MinimapMod:GetAddonBarOptions()
    return {
        type = "group",
        name = L["Addon Button Bar"],
        order = 3,
        args = {
            showAddonBar = {
                type = "toggle",
                name = L["Show Addon Button Bar"],
                order = 1,
                get = function() return self.db.showAddonBar end,
                set = function(_, val)
                    self.db.showAddonBar = val
                    self:UpdateAddonBarVisibility()
                end,
            },
            addonBarAttached = {
                type = "toggle",
                name = L["Attached to Minimap"],
                desc = L["Attach the addon bar directly to the left of the Minimap."],
                order = 2,
                get = function() return self.db.addonBarAttached ~= false end,
                set = function(_, val)
                    self.db.addonBarAttached = val
                    self:UpdateAddonBarAttachment()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarExpansionMode = {
                type = "select",
                name = L["Expansion Mode"] or "Expansion Mode",
                desc = L["Choose how the addon bar expands: Standard (Base 3 buttons + hover all), Direct All (expand all on click), or Always Base (always show 3 buttons, expand all on click)."] or "Choose expansion mode",
                order = 2.5,
                values = {
                    ["STANDARD"] = L["Standard (Base + Hover All)"] or "Standard (Base + Hover All)",
                    ["DIRECT_ALL"] = L["Direct (Full Expand on Click)"] or "Direct (Full Expand on Click)",
                    ["ALWAYS_BASE"] = L["Always Base (Toggle All on Click)"] or "Always Base (Toggle All on Click)",
                },
                get = function() return self.db.addonBarExpansionMode or "STANDARD" end,
                set = function(_, val)
                    self.db.addonBarExpansionMode = val
                    self:UpdateAddonBarLayout()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            displaceBuffs = {
                type = "toggle",
                name = L["Displace Auras"] or "Displace Auras",
                desc = L["Displace Auras when Addon Bar Expands"] or "Automatically shift player auras when expanding.",
                order = 2.8,
                get = function() return self.db.displaceBuffs ~= false end,
                set = function(_, val)
                    self.db.displaceBuffs = val
                    if self.UpdateBuffFrameDisplacement then
                        self:UpdateBuffFrameDisplacement()
                    end
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarAutohide = {
                type = "toggle",
                name = L["Autohide Addon Bar"],
                desc = L["Attaches to nearest screen corner as a white line and shows on hover."],
                order = 3,
                get = function() return self.db.addonBarAutohide end,
                set = function(_, val)
                    self.db.addonBarAutohide = val
                    self:UpdateAddonBarAutohide()
                end,
                disabled = function() return not self.db.showAddonBar or self.db.addonBarAttached end,
            },
            addonBarSnap = {
                type = "toggle",
                name = L["Snap to Screen Edge"],
                desc = L["Snaps the addon button bar to the nearest screen edge or corner when dragging."],
                order = 4,
                get = function() return self.db.addonBarSnap end,
                set = function(_, val)
                    self.db.addonBarSnap = val
                    if val and self.addonBar and not self.db.addonBarAttached then
                        SnapFrameToEdge(self.addonBar)
                    end
                    self:UpdateAddonBarAutohide()
                end,
                disabled = function() return not self.db.showAddonBar or self.db.addonBarAttached end,
            },
            addonBarSnapEdge = {
                type = "select",
                name = L["Snap Edge"],
                desc = L["Select which screen edge or corner the detached bar snaps to."],
                order = 5,
                values = {
                    ["AUTO"] = L["Auto"],
                    ["TOP"] = L["Top"],
                    ["BOTTOM"] = L["Bottom"],
                    ["LEFT"] = L["Left"],
                    ["RIGHT"] = L["Right"],
                },
                get = function() return self.db.addonBarSnapEdge or "AUTO" end,
                set = function(_, val)
                    self.db.addonBarSnapEdge = val
                    if self.addonBar and not self.db.addonBarAttached then
                        SnapFrameToEdge(self.addonBar)
                    end
                end,
                disabled = function() return not self.db.showAddonBar or self.db.addonBarAttached end,
            },
            addonBarVisibleCount = {
                type = "range",
                name = L["Primary Visible Buttons"] or "Primary Visible Buttons",
                desc = L["Number of primary buttons displayed in Base view (default: 3)."] or "Number of primary buttons displayed in Base view.",
                order = 6,
                min = 1,
                max = 10,
                step = 1,
                get = function() return self.db.addonBarVisibleCount or 3 end,
                set = function(_, val)
                    self.db.addonBarVisibleCount = val
                    self:UpdateAddonBarLayout()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarExpanderSize = {
                type = "range",
                name = L["Expander Size"] or "Expander Size",
                desc = L["Height of the expander toggle button."] or "Height of the expander toggle button.",
                order = 6.5,
                min = 10,
                max = 30,
                step = 1,
                get = function() return self.db.addonBarExpanderSize or 16 end,
                set = function(_, val)
                    self.db.addonBarExpanderSize = val
                    self:UpdateAddonBarLayout()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarButtonSize = {
                type = "range",
                name = L["Button Size"],
                order = 4,
                min = 16,
                max = 48,
                step = 1,
                get = function() return self.db.addonBarButtonSize or 30 end,
                set = function(_, val)
                    self.db.addonBarButtonSize = val
                    self:ScanAddonButtons()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarSpacing = {
                type = "range",
                name = L["Button Spacing"],
                order = 5,
                min = 0,
                max = 20,
                step = 1,
                get = function() return self.db.addonBarSpacing or 4 end,
                set = function(_, val)
                    self.db.addonBarSpacing = val
                    self:UpdateAddonBarLayout()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarGrowDirection = {
                type = "select",
                name = L["Grow Direction"] or "Grow Direction",
                desc = L["Select the direction in which buttons grow and wrap."] or "Select grow direction.",
                order = 6.6,
                values = {
                    ["LEFT_DOWN"] = L["Left, Wrap Down"] or "Left, Wrap Down",
                    ["LEFT_UP"] = L["Left, Wrap Up"] or "Left, Wrap Up",
                    ["RIGHT_DOWN"] = L["Right, Wrap Down"] or "Right, Wrap Down",
                    ["RIGHT_UP"] = L["Right, Wrap Up"] or "Right, Wrap Up",
                    ["DOWN_LEFT"] = L["Down, Wrap Left"] or "Down, Wrap Left",
                    ["DOWN_RIGHT"] = L["Down, Wrap Right"] or "Down, Wrap Right",
                    ["UP_LEFT"] = L["Up, Wrap Left"] or "Up, Wrap Left",
                    ["UP_RIGHT"] = L["Up, Wrap Right"] or "Up, Wrap Right",
                },
                get = function() return self.db.addonBarGrowDirection or "UP_LEFT" end,
                set = function(_, val)
                    self.db.addonBarGrowDirection = val
                    self:UpdateAddonBarLayout()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarBreakpoint = {
                type = "range",
                name = L["Breakpoint (Button Amount)"] or "Breakpoint (Button Amount)",
                desc = L["Number of buttons to display before breaking to the next row or column (based strictly on button amount, not frame width)."] or "Number of buttons before wrapping.",
                order = 6.7,
                min = 1,
                max = 20,
                step = 1,
                get = function() return self.db.addonBarBreakpoint or self.db.addonBarColumns or 5 end,
                set = function(_, val)
                    self.db.addonBarBreakpoint = val
                    self.db.addonBarColumns = val
                    self:UpdateAddonBarLayout()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarBgColor = {
                type = "color",
                name = L["Bar Background Color"],
                order = 7,
                hasAlpha = true,
                get = function()
                    local c = self.db.addonBarBgColor or { r = 0, g = 0, b = 0, a = 0.6 }
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    self.db.addonBarBgColor = { r = r, g = g, b = b, a = a }
                    self:UpdateAddonBarLayout()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarHoverColor = {
                type = "color",
                name = L["Hover Line Color"],
                order = 8,
                hasAlpha = true,
                get = function()
                    local c = self.db.addonBarHoverColor or { r = 1, g = 1, b = 1, a = 1 }
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    self.db.addonBarHoverColor = { r = r, g = g, b = b, a = a }
                    self:UpdateAddonBarAutohide()
                end,
                disabled = function() return not self.db.showAddonBar or self.db.addonBarAttached or not self.db.addonBarAutohide end,
            },
            addonBarHoverThickness = {
                type = "range",
                name = L["Hover Line Thickness"],
                order = 9,
                min = 2,
                max = 20,
                step = 1,
                get = function() return self.db.addonBarHoverThickness or 4 end,
                set = function(_, val)
                    self.db.addonBarHoverThickness = val
                    self:UpdateAddonBarAutohide()
                end,
                disabled = function() return not self.db.showAddonBar or self.db.addonBarAttached or not self.db.addonBarAutohide end,
            },
            buttonsGroup = buttonOptionsGroup,
        },
    }
end

