local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LSM = LibStub("LibSharedMedia-3.0")

-- ----------------------------------------------------------------------------
-- 1. Bar Creation
-- ----------------------------------------------------------------------------
function ns.CreateCastBar(unit)
    local bar = CreateFrame("StatusBar", "MidnightCastBar_" .. unit, UIParent)
    local texture = LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar"
    bar:SetStatusBarTexture(texture)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar); bg:SetColorTexture(0, 0, 0, 0.5)
    bar.Background = bg

    local icon = bar:CreateTexture(nil, "OVERLAY"); icon:SetPoint("RIGHT", bar, "LEFT", 0, 0);
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Square crop/zoom
    bar.Icon = icon
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); text:SetPoint("CENTER"); bar.Text = text
    -- Spark (Standard Texture)
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    bar.Spark = spark

    bar.StageTicks = {}
    bar.unit = unit; bar:Hide()
    return bar
end

function ns.InitializeBars()
    for unit, _ in pairs(ns.DEFAULTS) do
        ns.bars[unit] = ns.CreateCastBar(unit)
    end
end

-- ----------------------------------------------------------------------------
-- 2. Update Logic
-- ----------------------------------------------------------------------------

function ns.UpdateCast(bar)
    local unit = bar.unit
    -- respecting enabled flag
    local db = RoithiUIDB.Castbar[unit]
    if not db or not db.enabled then
        bar:Hide(); bar:SetScript("OnUpdate", nil)
        return
    end

    -- If in Edit Mode, do NOT update (keep dummy bar visible)
    if bar.isInEditMode then return end

    if bar.isInterrupted then return end
    local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, numStages
    local state = "cast"

    -- Empowered / Channel Check
    -- UnitChannelInfo: name ... spellID, isEmpowered, numEmpowerStages
    local chName, chText, chTexture, chStart, chEnd, _, chNotInt, chSpellID, isEmpowered, numEmpowerStages =
        UnitChannelInfo(unit)

    local isEmpoweredSafe = false
    local numStagesSafe = 0

    if chName then
        -- 1. Trust 'isEmpowered' return if true
        pcall(function()
            if isEmpowered then isEmpoweredSafe = true end
        end)

        -- 2. Trust 'numEmpowerStages' return if > 0
        pcall(function()
            if numEmpowerStages and numEmpowerStages > 0 then
                isEmpoweredSafe = true
                numStagesSafe = numEmpowerStages
            end
        end)

        -- 3. Fallback: Check Stage Percentages
        if not isEmpoweredSafe and _G.UnitEmpoweredStagePercentages then
            local percentages = _G.UnitEmpoweredStagePercentages(unit)
            if percentages and #percentages > 0 then
                isEmpoweredSafe = true
                -- Use this count if reliable
                if numStagesSafe == 0 then numStagesSafe = #percentages end
            end
        end

        -- 4. Deep Fallback: Check Spell Data directly
        -- This handles cases where UnitChannelInfo flags are nil for non-player units
        if not isEmpoweredSafe and chSpellID and C_Spell and C_Spell.GetSpellEmpowerStageInfo then
            local stageInfo = C_Spell.GetSpellEmpowerStageInfo(chSpellID, 1)
            if stageInfo then
                isEmpoweredSafe = true
                -- We can't determine current stage easily without UnitEmpoweredStagePercentages,
                -- but we know it's an empowered cast.
                -- Try to get max stages
                if numStagesSafe == 0 then
                    -- Loop to find max? Or just default to 1 so bars show?
                    -- Usually 3-4.
                    numStagesSafe = 1 -- Better than nothing
                end
            end
        end

        if isEmpoweredSafe then
            state = "empowered"
            name, text, texture, startTime, endTime, spellID, numStages = chName, chText, chTexture, chStart, chEnd,
                chSpellID, numStagesSafe
        else
            state = "channel"
            name, text, texture, startTime, endTime, spellID = chName, chText, chTexture, chStart, chEnd, chSpellID
        end
    else
        name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID = UnitCastingInfo(unit)
    end

    if not name then
        -- Stop any existing empower state
        if bar.isEmpower and ns.StopEmpower then ns.StopEmpower(bar) end

        bar:Hide(); bar:SetScript("OnUpdate", nil)
        return
    end

    local colors = RoithiUIDB.Castbar[unit].colors
    local c = colors[state] or colors.cast

    local safeNotInt = false
    -- Safely check secret boolean
    pcall(function() if notInterruptible then safeNotInt = true end end)

    if safeNotInt and colors.shield then
        c = colors.shield
        if bar.Spark then bar.Spark:Hide() end
    else
        if bar.Spark then bar.Spark:Show() end
    end

    -- Use Raw Secret Values (Matches Blizzard UI exactly)
    bar:SetMinMaxValues(startTime, endTime)

    if RoithiUIDB.Castbar[unit].showIcon then
        bar.Icon:Show(); bar.Icon:SetTexture(texture)
    else
        bar.Icon:Hide()
    end
    bar.Text:SetText(text)

    if state == "empowered" then
        bar:SetReverseFill(false)

        -- Start Empower Logic (only if not already started for this cast)
        -- We detect 'start' by checking if we are already in empower mode for this start time
        local needSetup = true
        if bar.isEmpower and bar.empowerTimeline and bar.empowerTimeline.startTime == (startTime / 1000) then
            needSetup = false
        end

        if needSetup then
            ns.SetupEmpower(bar)
        end

        -- Default start color (Grey/Start)
        -- Dynamic updates happen in OnEmpowerUpdate
        bar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
    elseif state == "channel" then
        if bar.isEmpower then ns.StopEmpower(bar) end

        -- Drain Effect (Masking)
        bar:SetReverseFill(true)
        bar:SetStatusBarColor(0, 0, 0, 1) -- Mask
        if bar.Background then bar.Background:SetColorTexture(c[1], c[2], c[3], c[4]) end
    else
        if bar.isEmpower then ns.StopEmpower(bar) end

        -- Standard Cast
        bar:SetReverseFill(false)
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
        if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
    end

    bar:Show()

    -- OnUpdate Loop
    bar:SetScript("OnUpdate", function(self, elapsed)
        self:SetValue(GetTime() * 1000)
        if self.isEmpower and ns.OnEmpowerUpdate then
            ns.OnEmpowerUpdate(self)
        end
    end)
end

function ns.HandleInterrupt(bar)
    if bar.isEmpower then ns.StopEmpower(bar) end

    -- Freeze progress so background is visible
    bar.isInterrupted = true; bar:SetScript("OnUpdate", nil)

    local c = RoithiUIDB.Castbar[bar.unit].colors.interrupted
    -- Change Background to Interrupt Color
    if bar.Background and c then
        bar.Background:SetColorTexture(c[1], c[2], c[3], c[4])
    end

    bar.Text:SetText("INTERRUPTED"); bar.Spark:Hide()
    C_Timer.After(1.0, function()
        bar.isInterrupted = false; bar:Hide()
    end)
end
