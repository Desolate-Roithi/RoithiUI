local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

-------------------------------------------------------------------------------
-- FormatAuraButton Callback for 12.1.0 AuraButtons
-------------------------------------------------------------------------------
local function FormatAuraButton(auraButton, containerKey, isDebuff, buttonSize, db, isWhitelistGroup)
    if not auraButton then return end

    pcall(function()
        buttonSize = buttonSize or 28

        if auraButton.SetSize then
            pcall(auraButton.SetSize, auraButton, buttonSize, buttonSize)
        end

        db = db or {}

        -- 1. Backdrop (Hidden: No normal generic box borders)
        if auraButton.RoithiBg then
            pcall(auraButton.RoithiBg.Hide, auraButton.RoithiBg)
        end

        -- Visual Debug helper background (ONLY when /rad is enabled)
        if RoithiUI.AuraDebug then
            local dbgBg = auraButton.DbgBg or auraButton:CreateTexture(nil, "BACKGROUND", nil, -7)
            dbgBg:SetAllPoints(auraButton)
            dbgBg:SetColorTexture(0, 1, 0, 0.4)
            dbgBg:Show()
            auraButton.DbgBg = dbgBg
        elseif auraButton.DbgBg then
            pcall(auraButton.DbgBg.Hide, auraButton.DbgBg)
        end

        -- Font settings from profile options
        local fontName = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.unitFrameFont) or "Friz Quadrata TT"

        -- Visibility Flags
        local hideIcon = isDebuff and (db.hideDebuffIcon or db.hideIcon) or (db.hideBuffIcon or db.hideIcon)
        local hideTimer = isDebuff and (db.hideDebuffTimer or db.hideTimer) or (db.hideBuffTimer or db.hideTimer)
        local hideCount = isDebuff and (db.hideDebuffCount or db.hideCount) or (db.hideBuffCount or db.hideCount)

        -- 2. Icon Texture with Zoom %
        local icon = auraButton.Icon or auraButton:CreateTexture(nil, "ARTWORK")
        if icon then
            if icon.SetAllPoints then icon:SetAllPoints(auraButton) end
            local zoomPercent = db.zoomPercent
            if zoomPercent == nil then zoomPercent = 15 end
            local offset = (tonumber(zoomPercent) or 15) / 100
            if icon.SetTexCoord then icon:SetTexCoord(offset, 1 - offset, offset, 1 - offset) end
            if icon.SetShown then
                icon:SetShown(not hideIcon)
            elseif hideIcon and icon.Hide then
                icon:Hide()
            elseif icon.Show then
                icon:Show()
            end
            auraButton.Icon = icon
            if auraButton.SetIcon then
                pcall(auraButton.SetIcon, auraButton, icon)
            end
        end

        -- 3. Duration Cooldown Swipe
        local cd = auraButton.Cooldown or auraButton.cooldown or CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        if cd then
            if cd.SetAllPoints then cd:SetAllPoints(auraButton) end
            if cd.SetReverse then cd:SetReverse(true) end
            if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
            local hideSwipe = hideIcon or hideTimer
            if cd.SetDrawSwipe then cd:SetDrawSwipe(not hideSwipe) end
            if cd.SetDrawEdge then cd:SetDrawEdge(not hideSwipe) end
            if cd.SetDrawBling then cd:SetDrawBling(not hideSwipe) end
            if cd.SetShown then
                cd:SetShown(not hideSwipe)
            elseif hideSwipe and cd.Hide then
                cd:Hide()
            elseif cd.Show then
                cd:Show()
            end
            auraButton.Cooldown = cd
            if auraButton.SetDurationCooldown then
                pcall(auraButton.SetDurationCooldown, auraButton, cd)
            end
        end

        -- Bare seconds numeric rule formatter cache (removes 's' suffix: "45", "2m", "1h")
        local bareSecondsFormatterCache = nil
        local function GetBareSecondsFormatter()
            if bareSecondsFormatterCache ~= nil then return bareSecondsFormatterCache end
            if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum and Enum.NumericRuleFormatRounding) then
                bareSecondsFormatterCache = false
                return false
            end
            local ok, fmt = pcall(function()
                local down = Enum.NumericRuleFormatRounding.Down
                local up   = Enum.NumericRuleFormatRounding.Up
                local f = C_StringUtil.CreateNumericRuleFormatter()
                f:AddBreakpoint({ threshold = 0, step = 1, rounding = up, min = 1, format = "%d" })
                f:AddBreakpoint({ threshold = 60, step = 1, rounding = down, min = 1, format = "%dm", components = { { div = 60, rounding = up } } })
                f:AddBreakpoint({ threshold = 3600, step = 1, rounding = down, min = 1, format = "%dh", components = { { div = 3600, rounding = up } } })
                return f
            end)
            bareSecondsFormatterCache = (ok and fmt) or false
            return bareSecondsFormatterCache
        end

        -- Text Overlay Frame: High FrameLevel parented to auraButton so timer & stack text render ABOVE the swipe and never get hidden by dormant Cooldown frames
        local textFrame = auraButton.TextFrame or CreateFrame("Frame", nil, auraButton)
        if textFrame then
            if textFrame.SetAllPoints then textFrame:SetAllPoints(auraButton) end
            local baseLevel = 1
            if auraButton.GetFrameLevel then
                local ok, lvl = pcall(auraButton.GetFrameLevel, auraButton)
                if ok and type(lvl) == "number" then baseLevel = lvl end
            end
            if textFrame.SetFrameLevel then textFrame:SetFrameLevel(baseLevel + 25) end
            auraButton.TextFrame = textFrame

            -- 4. Duration / Timer Text Option Hook
            local durationText = auraButton.DurationText or textFrame:CreateFontString(nil, "OVERLAY")
            if durationText then
                if durationText.SetDrawLayer then
                    durationText:SetDrawLayer("OVERLAY", 7)
                end
                local timerFontSize = isDebuff and (db.debuffTimerFontSize or db.timerFontSize) or (db.buffTimerFontSize or db.timerFontSize) or 10
                local timerAnchor = isDebuff and (db.debuffTimerAnchor or db.timerAnchor) or (db.buffTimerAnchor or db.timerAnchor) or "CENTER"
                local timerX = isDebuff and (db.debuffTimerX or db.timerX) or (db.buffTimerX or db.timerX) or 0
                local timerY = isDebuff and (db.debuffTimerY or db.timerY) or (db.buffTimerY or db.timerY) or 0

                if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
                    LibRoithi.mixins:SetFont(durationText, fontName, timerFontSize, "OUTLINE")
                end
                if durationText.ClearAllPoints then durationText:ClearAllPoints() end
                if durationText.SetPoint then durationText:SetPoint(timerAnchor, auraButton, timerAnchor, timerX, timerY) end
                if durationText.SetShown then
                    durationText:SetShown(not hideTimer)
                elseif hideTimer and durationText.Hide then
                    durationText:Hide()
                elseif durationText.Show then
                    durationText:Show()
                end

                auraButton.DurationText = durationText
                if auraButton.SetDurationText then
                    local fmt = GetBareSecondsFormatter()
                    if fmt then
                        local opts = {}
                        if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
                            local b = C_DurationUtil.CreateDurationTextBinding()
                            if b.SetFormatter then b:SetFormatter(fmt) end
                            if b.SetEnabled then b:SetEnabled(true) end
                            opts.binding = b
                        else
                            opts.formatter = fmt
                        end
                        pcall(auraButton.SetDurationText, auraButton, durationText, opts)
                    else
                        pcall(auraButton.SetDurationText, auraButton, durationText)
                    end
                end
            end

            -- 5. Application Count / Stack Count Text Option Hook
            local countText = auraButton.CountText or textFrame:CreateFontString(nil, "OVERLAY")
            if countText then
                if countText.SetDrawLayer then
                    countText:SetDrawLayer("OVERLAY", 7)
                end
                local stackFontSize = isDebuff and (db.debuffStackFontSize or db.stackFontSize) or (db.buffStackFontSize or db.stackFontSize) or 10
                local stackAnchor = isDebuff and (db.debuffStackAnchor or db.stackAnchor) or (db.buffStackAnchor or db.stackAnchor) or "BOTTOMRIGHT"
                local stackX = isDebuff and (db.debuffStackX or db.stackX) or (db.buffStackX or db.stackX) or 2
                local stackY = isDebuff and (db.debuffStackY or db.stackY) or (db.buffStackY or db.stackY) or -2

                if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
                    LibRoithi.mixins:SetFont(countText, fontName, stackFontSize, "OUTLINE")
                end
                if countText.ClearAllPoints then countText:ClearAllPoints() end
                if countText.SetPoint then countText:SetPoint(stackAnchor, auraButton, stackAnchor, stackX, stackY) end
                if countText.SetShown then
                    countText:SetShown(not hideCount)
                elseif hideCount and countText.Hide then
                    countText:Hide()
                elseif countText.Show then
                    countText:Show()
                end
                auraButton.CountText = countText
                if auraButton.SetApplicationCount then
                    pcall(auraButton.SetApplicationCount, auraButton, countText)
                end
            end
        end

        -- 6. Dispel Type Top Line Indicator (Only 2px top line debuff border, no normal 4-sided borders)
        local borderTex = auraButton.Border or auraButton:CreateTexture(nil, "OVERLAY")
        if borderTex then
            if borderTex.ClearAllPoints then borderTex:ClearAllPoints() end
            if borderTex.SetPoint then
                borderTex:SetPoint("TOPLEFT", auraButton, "TOPLEFT", 0, 0)
                borderTex:SetPoint("TOPRIGHT", auraButton, "TOPRIGHT", 0, 0)
            end
            if borderTex.SetHeight then borderTex:SetHeight(2) end
            if borderTex.SetColorTexture then borderTex:SetColorTexture(1, 1, 1, 1) end
            auraButton.Border = borderTex

            if auraButton.SetAuraBorder then
                pcall(auraButton.SetAuraBorder, auraButton, borderTex)
            end

            if isDebuff and not hideIcon then
                if borderTex.SetVertexColor then borderTex:SetVertexColor(0.8, 0.1, 0.1, 1) end
                if borderTex.Show then borderTex:Show() end
            else
                if borderTex.Hide then borderTex:Hide() end
            end
        end

        -- 7. Right-Click to Cancel Aura ("RightButtonUp" is valid for RegisterForClicks)
        if auraButton.SetCancelAuraButtons then
            pcall(auraButton.SetCancelAuraButtons, auraButton, "RightButtonUp")
        end

        auraButton.roithiStyled = true
    end)
end

-------------------------------------------------------------------------------
-- Sub-Module Function Exports
-------------------------------------------------------------------------------
ns.Auras = ns.Auras or {}
ns.Auras.FormatAuraButton = FormatAuraButton
