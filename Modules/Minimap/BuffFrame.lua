local addonName, AT = ...
if AT.skipLoad then return end
local RoithiUI = AT.RoithiUI or _G.RoithiUI
local MinimapMod = RoithiUI:GetModule("Minimap")
local LibRoithi = LibStub("LibRoithi-1.0")

local isStylingBuffs = false

local function StyleAuraButton(button)
    if not button then return end

    local db = MinimapMod.db
    local showBorder = db and db.buffFrameShowBorder == true

    local icon = button.Icon or button.icon
    if icon and icon.SetTexCoord then
        if db and db.buffFrameZoomIcons == false then
            icon:SetTexCoord(0, 1, 0, 1)
        else
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end

    if not button.backdrop then
        local bg = CreateFrame("Frame", nil, button, "BackdropTemplate")
        bg:SetAllPoints(button)
        bg:SetFrameLevel(button:GetFrameLevel() > 0 and (button:GetFrameLevel() - 1) or 0)
        button.backdrop = bg
    end

    if button.backdrop then
        if showBorder then
            local edgeSize = (db and db.buffFrameBorderSize) or 1
            local col = (db and db.buffFrameBorderColor) or { r = 0, g = 0, b = 0, a = 1 }
            button.backdrop:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = edgeSize,
            })
            button.backdrop:SetBackdropBorderColor(col.r or 0, col.g or 0, col.b or 0, col.a or 1)
            button.backdrop:Show()
        else
            button.backdrop:Hide()
        end
    end

    if db and db.buffFrameEnableSkinning == false then return end

    local duration = button.Duration or button.duration
    local count = button.Count or button.count
    local font = (db and db.buffFrameFont) or "Friz Quadrata TT"
    local outline = (db and db.buffFrameFontOutline) or "OUTLINE"
    local showShadow = db and db.buffFrameShowShadow == true

    if duration then
        if LibRoithi and LibRoithi.mixins then
            local size = (db and db.buffFrameDurationSize) or 10
            LibRoithi.mixins:SetFont(duration, font, size, outline)
        end
        if duration.SetShadowOffset then
            if showShadow then
                duration:SetShadowOffset(1, -1)
                duration:SetShadowColor(0, 0, 0, 1)
            else
                duration:SetShadowOffset(0, 0)
                duration:SetShadowColor(0, 0, 0, 0)
            end
        end
    end

    if count then
        if LibRoithi and LibRoithi.mixins then
            local size = (db and db.buffFrameCountSize) or 10
            LibRoithi.mixins:SetFont(count, font, size, outline)
        end
        if count.SetShadowOffset then
            if showShadow then
                count:SetShadowOffset(1, -1)
                count:SetShadowColor(0, 0, 0, 1)
            else
                count:SetShadowOffset(0, 0)
                count:SetShadowColor(0, 0, 0, 0)
            end
        end
    end

    button.roithiStyled = true
end

function MinimapMod:RefreshBuffFrameStyling()
    if _G.BuffFrame and _G.BuffFrame.auraFrames then
        for _, auraFrame in ipairs(_G.BuffFrame.auraFrames) do
            StyleAuraButton(auraFrame)
        end
    end
    if _G.DebuffFrame and _G.DebuffFrame.auraFrames then
        for _, auraFrame in ipairs(_G.DebuffFrame.auraFrames) do
            StyleAuraButton(auraFrame)
        end
    end
end

function MinimapMod:HookBuffFrameStyling()
    if isStylingBuffs then return end
    isStylingBuffs = true

    if _G.BuffFrame and _G.BuffFrame.UpdateAuraButtons then
        hooksecurefunc(_G.BuffFrame, "UpdateAuraButtons", function(frame)
            if frame.auraFrames then
                for _, auraFrame in ipairs(frame.auraFrames) do
                    StyleAuraButton(auraFrame)
                end
            end
        end)
    end

    if _G.DebuffFrame and _G.DebuffFrame.UpdateAuraButtons then
        hooksecurefunc(_G.DebuffFrame, "UpdateAuraButtons", function(frame)
            if frame.auraFrames then
                for _, auraFrame in ipairs(frame.auraFrames) do
                    StyleAuraButton(auraFrame)
                end
            end
        end)
    end

    if _G.BuffFrame and _G.BuffFrame.CollapseAndExpandButton then
        local btn = _G.BuffFrame.CollapseAndExpandButton
        if not btn.roithiHooked and btn.HookScript then
            btn:HookScript("OnClick", function()
                if MinimapMod.UpdateBuffFrameDisplacement then
                    MinimapMod:UpdateBuffFrameDisplacement()
                end
            end)
            btn.roithiHooked = true
        end
    end
end

function MinimapMod:UpdateBuffFrameDisplacement()
    local anchorTarget = self.container or _G.Minimap
    if not anchorTarget then return end

    local baseOffset = -8
    local displacement = 0

    -- Only displace if addon bar is attached, shown, and displaceBuffs is enabled
    if self.addonBar and self.db and self.db.addonBarAttached ~= false and self.db.showAddonBar and self.db.displaceBuffs ~= false then
        local w = self.addonBar:GetWidth() or 0
        local h = self.addonBar:GetHeight() or 0
        local isBarExpanded = (w > 25) and (h > 25)
        if isBarExpanded then
            displacement = w
        end
    end

    local finalX = baseOffset - displacement

    local buffFrame = _G.BuffFrame
    if buffFrame and buffFrame.ClearAllPoints and buffFrame.SetPoint then
        buffFrame:ClearAllPoints()
        buffFrame:SetPoint("TOPRIGHT", anchorTarget, "TOPLEFT", finalX, 0)
    end

    local debuffFrame = _G.DebuffFrame
    if debuffFrame and debuffFrame.ClearAllPoints and debuffFrame.SetPoint then
        debuffFrame:ClearAllPoints()
        debuffFrame:SetPoint("TOPRIGHT", anchorTarget, "TOPLEFT", finalX, -120)
    end
end
