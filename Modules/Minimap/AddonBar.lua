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
            targetX = x
        elseif snapEdge == "BOTTOM" then
            targetY = 0
            targetX = x
        elseif snapEdge == "LEFT" then
            targetX = 0
            targetY = y
        elseif snapEdge == "RIGHT" then
            targetX = screenW - wLayout
            targetY = y
        else -- "AUTO"
            local distLeft = x
            local distRight = screenW - (x + wLayout)
            local distBottom = y
            local distTop = screenH - (y + hLayout)

            local minDist = math.min(distLeft, distRight, distBottom, distTop)
            if minDist == distLeft then
                targetX = 0
                targetY = y
            elseif minDist == distRight then
                targetX = screenW - wLayout
                targetY = y
            elseif minDist == distTop then
                targetY = screenH - hLayout
                targetX = x
            else
                targetY = 0
                targetX = x
            end
        end

        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", targetX / localScale, targetY / localScale)
    end

    isSnapping = false
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
    LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 9, "OUTLINE")
    text:SetPoint("CENTER", expander, "CENTER", 0, 0)
    if text.SetTextColor then
        text:SetTextColor(0.8, 0.8, 0.8, 1)
    end
    text:SetText(self.db.addonBarExpanded and "▲" or "▼")
    expander.arrow = text

    expander:SetScript("OnClick", function()
        self.db.addonBarExpanded = not self.db.addonBarExpanded
        if expander.arrow then
            expander.arrow:SetText(self.db.addonBarExpanded and "▲" or "▼")
        end
        self:UpdateAddonBarLayout()
    end)

    expander:SetScript("OnEnter", function()
        self:OnBarEnter()
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(expander, "ANCHOR_LEFT")
            _G.GameTooltip:SetText(self.db.addonBarExpanded and L["Click to collapse addon buttons"] or L["Click to expand addon buttons"], 1, 1, 1)
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
    local defaults = { point = "TOPRIGHT", x = -10, y = -220 }

    if self.db.addonBarAttached ~= false then
        local parent = self.container or Minimap
        bar:SetParent(parent)
        if bar.SetFrameStrata then bar:SetFrameStrata("HIGH") end
        if bar.SetFrameLevel then bar:SetFrameLevel(25) end
        bar:ClearAllPoints()
        local spacing = self.db.addonBarAttachedSpacing or 4
        bar:SetPoint("TOPRIGHT", parent, "TOPLEFT", -spacing, 0)
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

    if not self.hiddenFrame then
        self.hiddenFrame = CreateFrame("Frame")
        self.hiddenFrame:Hide()
    end

    self:CreateAddonBarExpander()
    self:UpdateAddonBarAttachment()

    local defaults = { point = "TOPRIGHT", x = -10, y = -220 }

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
                options = {
                    ["AUTO"] = L["Auto"],
                    ["TOP"] = L["Top"],
                    ["BOTTOM"] = L["Bottom"],
                    ["LEFT"] = L["Left"],
                    ["RIGHT"] = L["Right"],
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
                name = L["Visible Buttons"],
                kind = LEM.SettingType.Slider,
                default = 4,
                minValue = 0,
                maxValue = 20,
                valueStep = 1,
                formatter = function(v) return string.format("%.0f", v) end,
                get = function() return self.db.addonBarVisibleCount or 4 end,
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
                name = L["Addon Bar Columns"],
                kind = LEM.SettingType.Slider,
                default = 1,
                minValue = 1,
                maxValue = 6,
                valueStep = 1,
                formatter = function(v) return string.format("%.0f", v) end,
                get = function() return self.db.addonBarColumns or 1 end,
                set = function(_, val)
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
        if self.expanderButton then self.expanderButton:Hide() end
        self.addonBar:SetSize(40, 40)
        self.addonBar:SetAlpha(LEM and LEM:IsInEditMode() and 1 or 0)
        return
    end

    local cols = self.db.addonBarColumns or 1
    local spacing = self.db.addonBarSpacing or 4
    local scale = self.db.addonBarScale or 1.0
    local btnSize = self.db.addonBarButtonSize or 30
    local visibleCount = self.db.addonBarVisibleCount or 4
    local isExpanded = self.db.addonBarExpanded == true

    local shownCount = isExpanded and count or math.min(count, visibleCount)

    self.addonBar:SetScale(scale)

    local rows = math.max(1, math.ceil(shownCount / cols))
    local width = cols * btnSize + (cols + 1) * spacing
    local buttonsHeight = shownCount > 0 and (rows * btnSize + (rows + 1) * spacing) or spacing
    local expanderHeight = 14
    local totalHeight = buttonsHeight + expanderHeight + spacing

    self.addonBar:SetSize(width, totalHeight)

    for idx, btn in ipairs(self.activeButtons) do
        if idx <= shownCount then
            local col = (idx - 1) % cols
            local row = math.floor((idx - 1) / cols)

            local x = spacing + col * (btnSize + spacing)
            local y = -(spacing + row * (btnSize + spacing))

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.addonBar, "TOPLEFT", x, y)
            btn:Show()
        else
            btn:Hide()
        end
    end

    if not self.expanderButton then
        self:CreateAddonBarExpander()
    end

    if self.expanderButton then
        self.expanderButton:ClearAllPoints()
        self.expanderButton:SetPoint("TOPLEFT", self.addonBar, "TOPLEFT", spacing, -buttonsHeight)
        self.expanderButton:SetSize(width - spacing * 2, expanderHeight)
        if self.expanderButton.arrow then
            self.expanderButton.arrow:SetText(isExpanded and "▲" or "▼")
        end
        self.expanderButton:Show()
    end

    self:UpdateAddonBarAttachment()
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
                disabled = function() return not self.db.showAddonBar end,
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
                name = L["Visible Buttons"],
                desc = L["Number of buttons displayed before expanding via the toggle button."],
                order = 6,
                min = 0,
                max = 20,
                step = 1,
                get = function() return self.db.addonBarVisibleCount or 4 end,
                set = function(_, val)
                    self.db.addonBarVisibleCount = val
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
