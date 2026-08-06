local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

-------------------------------------------------------------------------------
-- FormatAuraButton Callback for 12.1.0 AuraButtons
-------------------------------------------------------------------------------
local function FormatAuraButton(auraButton, containerKey, isDebuff, buttonSize, db)
    if not auraButton then return end

    buttonSize = buttonSize or 28
    auraButton:SetSize(buttonSize, buttonSize)

    db = db or {}

    -- 1. Backdrop (Hidden: No normal generic box borders)
    if auraButton.RoithiBg then
        auraButton.RoithiBg:Hide()
    end

    -- Visual Debug helper background (ONLY when /rad is enabled)
    if RoithiUI.AuraDebug then
        local dbgBg = auraButton.DbgBg or auraButton:CreateTexture(nil, "BACKGROUND", nil, -7)
        dbgBg:SetAllPoints(auraButton)
        dbgBg:SetColorTexture(0, 1, 0, 0.4)
        dbgBg:Show()
        auraButton.DbgBg = dbgBg
    elseif auraButton.DbgBg then
        auraButton.DbgBg:Hide()
    end

    -- Font settings from profile options
    local fontName = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.unitFrameFont) or "Friz Quadrata TT"

    -- 2. Icon Texture with Zoom %
    local icon = auraButton.Icon or auraButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(auraButton)
    local zoomPercent = db.zoomPercent
    if zoomPercent == nil then zoomPercent = 15 end
    local offset = (tonumber(zoomPercent) or 15) / 100
    icon:SetTexCoord(offset, 1 - offset, offset, 1 - offset)
    auraButton.Icon = icon
    if auraButton.SetIcon then
        auraButton:SetIcon(icon)
    end

    -- 3. Duration Cooldown Swipe
    local cd = auraButton.Cooldown or CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
    cd:SetAllPoints(auraButton)
    cd:SetReverse(true)
    cd:SetHideCountdownNumbers(true) -- Native duration text FontString handles text
    auraButton.Cooldown = cd
    if auraButton.SetDurationCooldown then
        auraButton:SetDurationCooldown(cd)
    end

    -- Text Overlay Frame: High FrameLevel parented to auraButton so timer & stack text render ABOVE the swipe and never get hidden by dormant Cooldown frames
    local textFrame = auraButton.TextFrame or CreateFrame("Frame", nil, auraButton)
    textFrame:SetAllPoints(auraButton)
    textFrame:SetFrameLevel(auraButton:GetFrameLevel() + 25)
    auraButton.TextFrame = textFrame

    -- 4. Duration / Timer Text Option Hook
    local durationText = auraButton.DurationText or textFrame:CreateFontString(nil, "OVERLAY")
    durationText:SetDrawLayer("OVERLAY", 7)
    local timerFontSize = isDebuff and (db.debuffTimerFontSize or db.timerFontSize) or (db.buffTimerFontSize or db.timerFontSize) or 10
    local timerAnchor = isDebuff and (db.debuffTimerAnchor or db.timerAnchor) or (db.buffTimerAnchor or db.timerAnchor) or "CENTER"
    local timerX = isDebuff and (db.debuffTimerX or db.timerX) or (db.buffTimerX or db.timerX) or 0
    local timerY = isDebuff and (db.debuffTimerY or db.timerY) or (db.buffTimerY or db.timerY) or 0
    local hideTimer = isDebuff and (db.hideDebuffTimer or db.hideTimer) or (db.hideBuffTimer or db.hideTimer)

    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(durationText, fontName, timerFontSize, "OUTLINE")
    end
    durationText:ClearAllPoints()
    durationText:SetPoint(timerAnchor, auraButton, timerAnchor, timerX, timerY)
    durationText:SetShown(not hideTimer)
    auraButton.DurationText = durationText
    if auraButton.SetDurationText then
        auraButton:SetDurationText(durationText)
    end

    -- 5. Application Count / Stack Count Text Option Hook
    local countText = auraButton.CountText or textFrame:CreateFontString(nil, "OVERLAY")
    countText:SetDrawLayer("OVERLAY", 7)
    local stackFontSize = isDebuff and (db.debuffStackFontSize or db.stackFontSize) or (db.buffStackFontSize or db.stackFontSize) or 10
    local stackAnchor = isDebuff and (db.debuffStackAnchor or db.stackAnchor) or (db.buffStackAnchor or db.stackAnchor) or "BOTTOMRIGHT"
    local stackX = isDebuff and (db.debuffStackX or db.stackX) or (db.buffStackX or db.stackX) or 2
    local stackY = isDebuff and (db.debuffStackY or db.stackY) or (db.buffStackY or db.stackY) or -2
    local hideCount = isDebuff and (db.hideDebuffCount or db.hideCount) or (db.hideBuffCount or db.hideCount)

    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(countText, fontName, stackFontSize, "OUTLINE")
    end
    countText:ClearAllPoints()
    countText:SetPoint(stackAnchor, auraButton, stackAnchor, stackX, stackY)
    countText:SetShown(not hideCount)
    auraButton.CountText = countText
    if auraButton.SetApplicationCount then
        auraButton:SetApplicationCount(countText)
    end

    -- 6. Dispel Type Top Line Indicator (Only 2px top line debuff border, no normal 4-sided borders)
    local borderTex = auraButton.Border or auraButton:CreateTexture(nil, "OVERLAY")
    borderTex:ClearAllPoints()
    borderTex:SetPoint("TOPLEFT", auraButton, "TOPLEFT", 0, 0)
    borderTex:SetPoint("TOPRIGHT", auraButton, "TOPRIGHT", 0, 0)
    borderTex:SetHeight(2)
    borderTex:SetColorTexture(1, 1, 1, 1) -- White base texture for native SetVertexColor tinting
    auraButton.Border = borderTex

    -- Always register native debuff border handler
    if auraButton.SetAuraBorder then
        auraButton:SetAuraBorder(borderTex)
    end

    if isDebuff then
        borderTex:SetVertexColor(0.8, 0.1, 0.1, 1) -- Red top line for sample debuff
        borderTex:Show()
    else
        borderTex:Hide()
    end

    -- 7. Right-Click to Cancel Aura ("RightButtonUp" is valid for RegisterForClicks)
    if auraButton.SetCancelAuraButtons then
        auraButton:SetCancelAuraButtons("RightButtonUp")
    end

    auraButton.roithiStyled = true
end

-------------------------------------------------------------------------------
-- Sub-Module Function Exports
-------------------------------------------------------------------------------
ns.Auras = ns.Auras or {}
ns.Auras.FormatAuraButton = FormatAuraButton
