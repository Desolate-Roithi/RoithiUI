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
    ["MiniMapMailFrame"] = true,
    ["GarrisonLandingPageMinimapButton"] = true,
    ["MinimapZoneTextFrame"] = true,
    ["MinimapCompassTexture"] = true,
    ["MiniMapCraftingOrderFrame"] = true,
    ["AddonCompartmentButton"] = true,
    ["RoithiMinimapBorder"] = true,
    ["TimeManagerClockButton"] = true,
}

local buttonOptionsGroup = {
    type = "group",
    name = L["Addon Buttons"],
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
        for _, obj in ipairs({ frame:GetRegions() }) do
            if obj:IsObjectType("Texture") then
                local tex = obj:GetTexture()
                if tex then
                    local texStr = type(tex) == "string" and tex:lower() or ""
                    if not texStr:find("border") and not texStr:find("background") and not texStr:find("glow") and not texStr:find("shadow") then
                        return tex
                    end
                end
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do
            local tex = ScanRegions(child)
            if tex then return tex end
        end
    end

    return ScanRegions(button)
end

local isSnapping = false
local function SnapFrameToEdge(f)
    if isSnapping then return end
    isSnapping = true

    local sLeft, sBottom
    if f.GetRect then
        sLeft, sBottom = f:GetRect()
    end
    if sLeft and sBottom then
        local screenW = _G.GetScreenWidth and _G.GetScreenWidth() or 1920
        local screenH = _G.GetScreenHeight and _G.GetScreenHeight() or 1080
        local localScale = f:GetScale() or 1.0
        if localScale == 0 then localScale = 1.0 end

        -- GetRect returns layout coordinates directly in modern WoW
        local x = sLeft
        local y = sBottom
        local targetX
        local targetY

        local w, h = f:GetSize()
        local wLayout = w * localScale
        local hLayout = h * localScale

        -- Exclusive Snapping Logic:
        -- 1. If in the top 10% or bottom 10% of screen height, snap vertically only, keeping dragged X.
        -- 2. Otherwise (middle 80%), snap horizontally only to left/right edges (always snap to the closer one), keeping dragged Y.
        local inBottom10 = y < (screenH * 0.10)
        local inTop10 = (y + hLayout) > (screenH * 0.90)

        if inBottom10 then
            targetY = 0
            targetX = x
        elseif inTop10 then
            targetY = screenH - hLayout
            targetX = x
        else
            targetY = y
            local centerX = (screenW - wLayout) / 2
            if x < centerX then
                targetX = 0
            else
                targetX = screenW - wLayout
            end
        end

        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", targetX / localScale, targetY / localScale)
    end

    isSnapping = false
end

local function ProtectButton(button)
    if button.isProtected then return end

    button.originalParent = button:GetParent()
    button.originalPoints = {}
    for i = 1, button:GetNumPoints() do
        button.originalPoints[i] = { button:GetPoint(i) }
    end

    local oldSetPoint = button.SetPoint
    button.SetPoint = function(self, ...)
        if self.isAligning then
            oldSetPoint(self, ...)
        end
    end

    local oldSetParent = button.SetParent
    button.SetParent = function(self, p)
        if self.isAligning then
            oldSetParent(self, p)
        end
    end

    button.isProtected = true
end

function MinimapMod:UpdateAddonBarAutohide()
    local bar = self.addonBar
    if not bar then return end

    if not self.db.showAddonBar or (LEM and LEM:IsInEditMode()) then
        bar:SetAlpha(1)
        bar:EnableMouse(true)
        if bar.hoverLine then bar.hoverLine:Hide() end
        for _, btn in ipairs(self.activeButtons) do
            btn:SetAlpha(1)
            btn:EnableMouse(true)
            if btn.button then
                btn.button:EnableMouse(true)
            end
        end
        return
    end

    if self.db.addonBarAutohide then
        if not bar.hoverLine then
            bar.hoverLine = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            bar.hoverLine:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            })
            bar.hoverLine:SetFrameStrata("HIGH")
            bar.hoverLine:EnableMouse(true)

            local function OnEnter()
                if self.db.addonBarAutohide and not (LEM and LEM:IsInEditMode()) then
                    bar:SetAlpha(1)
                    bar:EnableMouse(true)
                    for _, btn in ipairs(self.activeButtons) do
                        btn:SetAlpha(1)
                        btn:EnableMouse(true)
                        if btn.button then
                            btn.button:EnableMouse(true)
                        end
                    end
                    bar.hoverLine:Hide()
                end
            end

            local function OnLeave()
                if self.db.addonBarAutohide and not (LEM and LEM:IsInEditMode()) and not bar:IsMouseOver() then
                    local hoveringButton = false
                    for _, btn in ipairs(self.activeButtons) do
                        if btn:IsMouseOver() or (btn.button and btn.button:IsMouseOver()) then
                            hoveringButton = true
                            break
                        end
                    end
                    if not hoveringButton then
                        bar:SetAlpha(0)
                        bar:EnableMouse(false)
                        for _, btn in ipairs(self.activeButtons) do
                            btn:SetAlpha(0)
                            btn:EnableMouse(false)
                            if btn.button then
                                btn.button:EnableMouse(false)
                            end
                        end
                        bar.hoverLine:Show()
                    end
                end
            end

            bar.hoverLine:SetScript("OnEnter", OnEnter)
            bar:SetScript("OnEnter", nil)
            bar:SetScript("OnLeave", function()
                C_Timer.After(0.1, function()
                    local hoveringButton = false
                    for _, btn in ipairs(self.activeButtons) do
                        if btn:IsMouseOver() or (btn.button and btn.button:IsMouseOver()) then
                            hoveringButton = true
                            break
                        end
                    end
                    if not bar:IsMouseOver() and not hoveringButton and (bar.hoverLine and not bar.hoverLine:IsMouseOver()) then
                        OnLeave()
                    end
                end)
            end)
        end

        local hc = self.db.addonBarHoverColor or { r = 1, g = 1, b = 1, a = 1 }
        bar.hoverLine:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)

        local screenW = _G.GetScreenWidth and _G.GetScreenWidth() or 1920
        local screenH = _G.GetScreenHeight and _G.GetScreenHeight() or 1080
        local scale = bar:GetEffectiveScale() or 1.0
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

            -- Find closest side
            local minDist = distLeft
            local side = "LEFT"

            if distRight < minDist then
                minDist = distRight
                side = "RIGHT"
            end
            if distBottom < minDist then
                minDist = distBottom
                side = "BOTTOM"
            end
            if distTop < minDist then
                minDist = distTop
                side = "TOP"
            end

            if not minDist then return end -- Silence linter warning for unused minDist assignment

            local thickness = self.db.addonBarHoverThickness or 4
            bar.hoverLine:ClearAllPoints()
            if side == "LEFT" then
                bar.hoverLine:SetSize(thickness, h)
                bar.hoverLine:SetPoint("LEFT", bar, "LEFT", 0, 0)
            elseif side == "RIGHT" then
                bar.hoverLine:SetSize(thickness, h)
                bar.hoverLine:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
            elseif side == "BOTTOM" then
                bar.hoverLine:SetSize(w, thickness)
                bar.hoverLine:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
            elseif side == "TOP" then
                bar.hoverLine:SetSize(w, thickness)
                bar.hoverLine:SetPoint("TOP", bar, "TOP", 0, 0)
            end
        end

        bar.hoverLine:Show()
        bar:SetAlpha(0)
        bar:EnableMouse(false)
        for _, btn in ipairs(self.activeButtons) do
            btn:SetAlpha(0)
            btn:EnableMouse(false)
            if btn.button then
                btn.button:EnableMouse(false)
            end
        end
    else
        if bar.hoverLine then
            bar.hoverLine:Hide()
        end
        bar:SetAlpha(1)
        bar:EnableMouse(true)
        for _, btn in ipairs(self.activeButtons) do
            btn:SetAlpha(1)
            btn:EnableMouse(true)
            if btn.button then
                btn.button:EnableMouse(true)
            end
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

    if not self.hiddenFrame then
        self.hiddenFrame = CreateFrame("Frame")
        self.hiddenFrame:Hide()
    end

    local defaults = { point = "TOPRIGHT", x = -10, y = -220 }

    if LEM then
        bar.editModeName = L["Addon Button Bar"]
        bar:SetParent(UIParent)
        bar:SetFrameStrata("HIGH")
        bar:SetFrameLevel(20)

        bar:ClearAllPoints()
        local offset = self.db.offsets and self.db.offsets[key] or defaults
        bar:SetPoint(offset.point or defaults.point, UIParent, offset.point or defaults.point, offset.x, offset.y)
        bar:Show()

        local function OnPositionChanged(f, _, point, x, y)
            local inEditMode = LEM and LEM:IsInEditMode()

            if inEditMode then
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
                return
            end

            -- Outside Edit Mode (normal load / options refresh)
            f:SetParent(UIParent)
            f:SetFrameStrata("HIGH")
            f:SetFrameLevel(20)
            f:ClearAllPoints()
            local off = self.db.offsets and self.db.offsets[key] or defaults
            f:SetPoint(off.point or defaults.point, UIParent, off.point or defaults.point, off.x, off.y)

            self:UpdateAddonBarAutohide()
        end

        LEM:AddFrame(bar, OnPositionChanged, defaults)
    else
        bar:ClearAllPoints()
        local offset = self.db.offsets and self.db.offsets[key] or defaults
        bar:SetPoint(offset.point or "TOPRIGHT", UIParent, offset.point or "TOPRIGHT", offset.x, offset.y)
        bar:Show()
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
    if self.db.addonBarAutohide and not (LEM and LEM:IsInEditMode()) then
        self.addonBar:SetAlpha(1)
        self.addonBar:EnableMouse(true)
        for _, btn in ipairs(self.activeButtons) do
            btn:SetAlpha(1)
            btn:EnableMouse(true)
            if btn.button then
                btn.button:EnableMouse(true)
            end
        end
        if self.addonBar.hoverLine then self.addonBar.hoverLine:Hide() end
    end
end

function MinimapMod:OnBarLeave()
    if self.db.addonBarAutohide and not (LEM and LEM:IsInEditMode()) then
        C_Timer.After(0.1, function()
            if not self.addonBar:IsMouseOver() then
                local hoveringButton = false
                for _, btn in ipairs(self.activeButtons) do
                    if btn:IsMouseOver() or (btn.button and btn.button:IsMouseOver()) then
                        hoveringButton = true
                        break
                    end
                end
                if not hoveringButton and (self.addonBar.hoverLine and not self.addonBar.hoverLine:IsMouseOver()) then
                    self.addonBar:SetAlpha(0)
                    self.addonBar:EnableMouse(false)
                    for _, btn in ipairs(self.activeButtons) do
                        btn:SetAlpha(0)
                        btn:EnableMouse(false)
                        if btn.button then
                            btn.button:EnableMouse(false)
                        end
                    end
                    self.addonBar.hoverLine:Show()
                end
            end
        end)
    end
end

function MinimapMod:UpdateAddonBarOptions()
    if not buttonOptionsGroup or not buttonOptionsGroup.args then return end
    local args = buttonOptionsGroup.args
    wipe(args)
    for name, btn in pairs(self.scannedButtons) do
        local cleanName = name:gsub("MinimapButton", ""):gsub("LibDBIconMinimapButton_", ""):gsub("Button", ""):gsub("Icon", "")
        if cleanName == "" then cleanName = name end

        local icon = FindButtonIcon(btn) or "Interface\\Icons\\INV_Misc_QuestionMark"
        args[name] = {
            type = "toggle",
            name = cleanName,
            image = icon,
            get = function()
                return self.db.addonBarButtons[name] ~= false
            end,
            set = function(_, val)
                self.db.addonBarButtons[name] = val
                self:UpdateAddonBarLayout()
            end,
            order = 10,
        }
    end
end

function MinimapMod:ScanAddonButtons()
    if not self.db.showAddonBar then return end

    local children = { Minimap:GetChildren() }
    for _, child in ipairs(children) do
        local name = child:GetName()
        if name and not IgnoredFrames[name] and not self.scannedButtons[name] then
            self.scannedButtons[name] = child
            child:HookScript("OnEnter", function() self:OnBarEnter() end)
            child:HookScript("OnLeave", function() self:OnBarLeave() end)
        end
    end

    if MinimapCluster then
        local clusterChildren = { MinimapCluster:GetChildren() }
        for _, child in ipairs(clusterChildren) do
            local name = child:GetName()
            if name and not IgnoredFrames[name] and not self.scannedButtons[name] then
                local isKnownPattern = name:find("MinimapButton") or name:find("LibDBIcon") or name:find("Button") or name:find("Icon")
                if isKnownPattern or child:IsObjectType("Button") then
                    self.scannedButtons[name] = child
                    child:HookScript("OnEnter", function() self:OnBarEnter() end)
                    child:HookScript("OnLeave", function() self:OnBarLeave() end)
                end
            end
        end
    end

    self:UpdateAddonBarLayout()
    self:UpdateAddonBarOptions()
end

function MinimapMod:UpdateAddonBarLayout()
    if not self.addonBar then return end

    self.activeButtons = {}
    self.customButtons = self.customButtons or {}

    local bg = self.db.addonBarBgColor or { r = 0, g = 0, b = 0, a = 0.6 }
    self.addonBar:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

    for name, btn in pairs(self.scannedButtons) do
        local enabled = self.db.addonBarButtons[name] ~= false
        if enabled then
            ProtectButton(btn)

            local custom = self.customButtons[name]
            if not custom then
                custom = CreateFrame("Button", "RoithiAddonButton_" .. name, self.addonBar, "BackdropTemplate")
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
                local iconTex = FindButtonIcon(btn) or "Interface\\Icons\\INV_Misc_QuestionMark"
                custom.icon:SetTexture(iconTex)
                custom.icon:SetAllPoints(custom)
                custom.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                local highlight = custom:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
                highlight:SetAllPoints(custom)
                custom:SetHighlightTexture(highlight)

                btn.isAligning = true
                btn:SetParent(custom)
                btn:ClearAllPoints()
                btn:SetAllPoints(custom)
                btn:SetAlpha(0)
                btn:Show()
                btn.isAligning = nil

                if not btn.RoithiAlphaHooked then
                    hooksecurefunc(btn, "SetAlpha", function(frame, alpha)
                        if frame.RoithiAlphaHooked and alpha ~= 0 then
                            frame:SetAlpha(0)
                        end
                    end)
                    btn.RoithiAlphaHooked = true
                end

                custom.button = btn
                self.customButtons[name] = custom
            end

            custom.button = btn
            local btnSize = self.db.addonBarButtonSize or 30
            custom:SetSize(btnSize, btnSize)
            custom:Show()

            btn.isAligning = true
            btn:SetParent(custom)
            btn:ClearAllPoints()
            btn:SetAllPoints(custom)
            btn:SetAlpha(0)
            btn:Show()
            btn.isAligning = nil
            btn.RoithiAlphaHooked = true

            table.insert(self.activeButtons, custom)
        else
            btn.isAligning = true
            btn:SetParent(self.hiddenFrame or Minimap)
            btn:Hide()
            btn.isAligning = nil
            btn.RoithiAlphaHooked = false

            if self.customButtons[name] then
                self.customButtons[name]:Hide()
            end
        end
    end

    table.sort(self.activeButtons, function(a, b)
        return a:GetName() < b:GetName()
    end)

    local count = #self.activeButtons
    if count == 0 then
        self.addonBar:SetSize(40, 40)
        self.addonBar:SetAlpha(LEM and LEM:IsInEditMode() and 1 or 0)
        return
    end

    local cols = self.db.addonBarColumns or 1
    local spacing = self.db.addonBarSpacing or 4
    local scale = self.db.addonBarScale or 1.0
    local btnSize = self.db.addonBarButtonSize or 30

    self.addonBar:SetScale(scale)

    local rows = math.ceil(count / cols)
    local width = cols * btnSize + (cols + 1) * spacing
    local height = rows * btnSize + (rows + 1) * spacing

    self.addonBar:SetSize(width, height)

    for idx, btn in ipairs(self.activeButtons) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)

        local x = spacing + col * (btnSize + spacing)
        local y = -(spacing + row * (btnSize + spacing))

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.addonBar, "TOPLEFT", x, y)
    end

    self:UpdateAddonBarAutohide()
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
            addonBarAutohide = {
                type = "toggle",
                name = L["Autohide Addon Bar"],
                desc = L["Attaches to nearest screen corner as a white line and shows on hover."],
                order = 2,
                get = function() return self.db.addonBarAutohide end,
                set = function(_, val)
                    self.db.addonBarAutohide = val
                    self:UpdateAddonBarAutohide()
                end,
                disabled = function() return not self.db.showAddonBar end,
            },
            addonBarSnap = {
                type = "toggle",
                name = L["Snap to Screen Edge"],
                desc = L["Snaps the addon button bar to the nearest screen edge or corner when dragging."],
                order = 3,
                get = function() return self.db.addonBarSnap end,
                set = function(_, val)
                    self.db.addonBarSnap = val
                    if val and self.addonBar then
                        SnapFrameToEdge(self.addonBar)
                    end
                    self:UpdateAddonBarAutohide()
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
            addonBarColumns = {
                type = "range",
                name = L["Addon Bar Columns"],
                order = 6,
                min = 1,
                max = 12,
                step = 1,
                get = function() return self.db.addonBarColumns or 1 end,
                set = function(_, val)
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
                disabled = function() return not self.db.showAddonBar end,
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
                disabled = function() return not self.db.showAddonBar or not self.db.addonBarAutohide end,
            },
            buttonsGroup = buttonOptionsGroup,
        },
    }
end
