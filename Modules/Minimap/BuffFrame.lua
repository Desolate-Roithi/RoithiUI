local addonName, AT = ...
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

    local duration = button.Duration or button.duration
    if duration and LibRoithi and LibRoithi.mixins then
        local font = (db and db.buffFrameFont) or "Friz Quadrata TT"
        local size = (db and db.buffFrameDurationSize) or 10
        LibRoithi.mixins:SetFont(duration, font, size, "OUTLINE")
    end

    local count = button.Count or button.count
    if count and LibRoithi and LibRoithi.mixins then
        local font = (db and db.buffFrameFont) or "Friz Quadrata TT"
        local size = (db and db.buffFrameCountSize) or 10
        LibRoithi.mixins:SetFont(count, font, size, "OUTLINE")
    end

    button.roithiStyled = true
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
