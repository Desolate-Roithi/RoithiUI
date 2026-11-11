local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

-- Bare seconds numeric rule formatter cache (removes 's' suffix: "45", "2m", "1h", "1d")
local bareSecondsFormatterCache = nil
local function BuildSecondsFallbackFormatter()
    local csu = _G.C_StringUtil
    local ccu = _G.C_CurveUtil
    local enum = _G.Enum
    if not (csu and csu.CreateSecondsFormatter and ccu and ccu.CreateCurve and enum and enum.SecondsFormatterInterval and enum.SecondsFormatterAbbreviation) then
        return nil
    end
    local ok, fmt = pcall(function()
        local curve = ccu.CreateCurve()
        curve:AddPoint(61, enum.SecondsFormatterInterval.Minutes)
        curve:AddPoint(3601, enum.SecondsFormatterInterval.Hours)
        curve:AddPoint(86401, enum.SecondsFormatterInterval.Days)

        local f = csu.CreateSecondsFormatter()
        f:SetDefaultAbbreviation(enum.SecondsFormatterAbbreviation.OneLetter)
        f:SetMinInterval(enum.SecondsFormatterInterval.Seconds)
        f:SetMaxIntervalCurve(curve)
        f:SetDesiredUnitCount(1)
        if f.SetStripIntervalWhitespace and enum.SecondsFormatterIntervalWhitespace then
            f:SetStripIntervalWhitespace(enum.SecondsFormatterIntervalWhitespace.Strip)
        end
        return f
    end)
    if ok and fmt then
        return fmt
    end
    return nil
end

local function GetBareSecondsFormatter()
    if bareSecondsFormatterCache ~= nil then return bareSecondsFormatterCache end
    local csu = _G.C_StringUtil
    local enum = _G.Enum
    if csu and csu.CreateNumericRuleFormatter and enum and enum.NumericRuleFormatRounding then
        local ok, fmt = pcall(function()
            local down = enum.NumericRuleFormatRounding.Down
            local up   = enum.NumericRuleFormatRounding.Up
            local f = csu.CreateNumericRuleFormatter()
            -- Breakpoint-level rounding avoids engine rejection from nested rounding inside components
            if f.SetBreakpoints then
                f:SetBreakpoints({
                    { threshold = 0,     step = 1, rounding = up,   min = 1, format = "%d" },
                    { threshold = 60,    step = 1, rounding = down, min = 1, format = "%dm", components = { { div = 60 } } },
                    { threshold = 3600,  step = 1, rounding = down, min = 1, format = "%dh", components = { { div = 3600 } } },
                    { threshold = 86400, step = 1, rounding = down, min = 1, format = "%dd", components = { { div = 86400 } } },
                })
            else
                f:AddBreakpoint({ threshold = 0,     step = 1, rounding = up,   min = 1, format = "%d" })
                f:AddBreakpoint({ threshold = 60,    step = 1, rounding = down, min = 1, format = "%dm", components = { { div = 60 } } })
                f:AddBreakpoint({ threshold = 3600,  step = 1, rounding = down, min = 1, format = "%dh", components = { { div = 3600 } } })
                f:AddBreakpoint({ threshold = 86400, step = 1, rounding = down, min = 1, format = "%dd", components = { { div = 86400 } } })
            end
            return f
        end)
        if ok and fmt then
            bareSecondsFormatterCache = fmt
            return bareSecondsFormatterCache
        end
    end
    local fallback = BuildSecondsFallbackFormatter()
    if fallback then
        bareSecondsFormatterCache = fallback
        return bareSecondsFormatterCache
    end
    bareSecondsFormatterCache = false
    return false
end

local function ShouldUseLegacyFormatterKey()
    local acu = _G.C_AuraContainerUtil
    return acu ~= nil and type(acu.ProcessCustomAuraButtonDurationTextOptions) ~= "function"
end

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
        local roithi = _G.RoithiUI or RoithiUI
        if roithi and roithi.AuraDebug then
            local dbgBg = auraButton.DbgBg or auraButton:CreateTexture(nil, "BACKGROUND", nil, -7)
            dbgBg:SetAllPoints(auraButton)
            dbgBg:SetColorTexture(0, 1, 0, 0.4)
            dbgBg:Show()
            auraButton.DbgBg = dbgBg
        elseif auraButton.DbgBg then
            pcall(auraButton.DbgBg.Hide, auraButton.DbgBg)
        end

        -- Font settings from profile options
        local fontName = (roithi and roithi.db and roithi.db.profile and roithi.db.profile.General and roithi.db.profile.General.unitFrameFont) or "Friz Quadrata TT"

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

                local utils = ns.Utils or (_G.RoithiUI and _G.RoithiUI.Utils)
                if utils and utils.ApplyTypography then
                    utils.ApplyTypography(durationText, fontName, timerFontSize, "OUTLINE", false, "Expressway", true)
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
                local durationBound = false
                if auraButton.SetDurationText then
                    if auraButton.ClearDurationText then
                        pcall(auraButton.ClearDurationText, auraButton)
                    end
                    local fmt = GetBareSecondsFormatter()
                    local useLegacyKey = ShouldUseLegacyFormatterKey()
                    local durationOpts = {}
                    if fmt then
                        if useLegacyKey then
                            durationOpts.formatter = fmt
                        else
                            durationOpts.textFormatter = fmt
                        end
                    end
                    local ok = pcall(auraButton.SetDurationText, auraButton, durationText, durationOpts)
                    if ok then
                        durationBound = true
                    elseif fmt then
                        local altOpts = useLegacyKey and { textFormatter = fmt } or { formatter = fmt }
                        local okAlt = pcall(auraButton.SetDurationText, auraButton, durationText, altOpts)
                        if okAlt then
                            durationBound = true
                        end
                    end
                    if not durationBound then
                        local okBare = pcall(auraButton.SetDurationText, auraButton, durationText, {})
                        if okBare then
                            durationBound = true
                        end
                    end
                end

                -- Manage Cooldown swipe countdown numbers:
                -- Suppress native countdown numbers only if user hid the timer OR if native SetDurationText is actively bound.
                -- In WoW Forever / environments without SetDurationText, keep countdown numbers enabled so native/OmniCC timers show.
                if cd and cd.SetHideCountdownNumbers then
                    local suppressCooldownNumbers = (hideTimer == true) or durationBound
                    cd:SetHideCountdownNumbers(suppressCooldownNumbers)
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

                local utils = ns.Utils or (_G.RoithiUI and _G.RoithiUI.Utils)
                if utils and utils.ApplyTypography then
                    utils.ApplyTypography(countText, fontName, stackFontSize, "OUTLINE", false, "Expressway", true)
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
    end)
end

-------------------------------------------------------------------------------
-- Sub-Module Function Exports
-------------------------------------------------------------------------------
ns.Auras = ns.Auras or {}
ns.Auras.FormatAuraButton = FormatAuraButton
