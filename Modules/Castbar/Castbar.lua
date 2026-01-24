local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LSM = LibStub("LibSharedMedia-3.0")

-- ----------------------------------------------------------------------------
-- 1. Bar Creation
-- ----------------------------------------------------------------------------
function ns.CreateCastBar(unit)
    local bar = CreateFrame("StatusBar", "MidnightCastBar_" .. unit, UIParent)
    local texture = LSM:Fetch("statusbar", RoithiUI.db.profile.General.castbarBar or "Solid") or
        "Interface\\TargetingFrame\\UI-StatusBar"
    bar:SetStatusBarTexture(texture)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar); bg:SetColorTexture(0, 0, 0, 0.5)
    bar.Background = bg

    local icon = bar:CreateTexture(nil, "OVERLAY"); icon:SetPoint("RIGHT", bar, "LEFT", 0, 0);
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Square crop/zoom
    bar.Icon = icon

    local font = LSM:Fetch("font", RoithiUI.db.profile.General.castbarFont or "Friz Quadrata TT")
    local text = bar:CreateFontString(nil, "OVERLAY");
    text:SetFont(font, 12, "OUTLINE")
    text:SetPoint("LEFT", 4, 0); -- Align Left with padding
    bar.Text = text

    -- Time Text (Remaining Only)
    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(font, 12, "OUTLINE")
    timeText:SetPoint("RIGHT", -4, 0)
    bar.TimeFS = timeText

    -- Spark (Standard Texture)
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    bar.Spark = spark

    bar.StageTicks = {}

    -- Latency Bar (Safe Zone)
    local latency = bar:CreateTexture(nil, "ARTWORK")
    latency:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    latency:SetVertexColor(1, 0, 0, 0.5) -- Red semi-transparent
    latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    latency:SetHeight(bar:GetHeight())
    latency:Hide()
    bar.Latency = latency

    bar.unit = unit; bar:Hide()
    bar:SetClampedToScreen(true)
    return bar
end

function ns.UpdateCastBarMedia(bar)
    if not bar then return end
    local texture = LSM:Fetch("statusbar", RoithiUI.db.profile.General.castbarBar or "Solid") or
        "Interface\\TargetingFrame\\UI-StatusBar"
    bar:SetStatusBarTexture(texture)

    local font = LSM:Fetch("font", RoithiUI.db.profile.General.castbarFont or "Friz Quadrata TT")
    -- We assume standard size 12 here, or we could fetch from DB if we added size option
    if bar.Text then
        bar.Text:SetFont(font, 12, "OUTLINE")
    end
    -- Update Font for Time string
    if bar.TimeFS then bar.TimeFS:SetFont(font, 12, "OUTLINE") end
end

function ns.RefreshAllCastbars()
    if not ns.bars then return end
    for unit, bar in pairs(ns.bars) do
        ns.UpdateCastBarMedia(bar)
    end
end

function ns.InitializeBars()
    for unit, _ in pairs(ns.DEFAULTS) do
        ns.bars[unit] = ns.CreateCastBar(unit)
    end
end

-- ----------------------------------------------------------------------------
-- 1.5. Safety Wrappers (12.0.1+ Helper mocks)
-- ----------------------------------------------------------------------------
local function FormatDuration(val)
    if not val then return "" end
    -- Secret Safety: If issecretvalue(val), we can't do math.
    -- We assume val might be a formatted string or we trust it works with standard formatters if whitelisted.
    -- If it's a number:
    if type(val) == "number" then
        if val >= 60 then
            return string.format("%d:%02d", math.floor(val / 60), val % 60)
        end
        return string.format("%.1f", val)
    end
    -- Fallback for secrets or handled types
    return val
end

local function GetUnitCastBarCurrentTime(unit)
    local name, _, _, startTime, endTime = UnitCastingInfo(unit)
    if not name then
        name, _, _, startTime, endTime = UnitChannelInfo(unit)
    end
    if not startTime or not endTime then return 0 end

    -- Safe Math via pcall
    local success, result = pcall(function()
        local now = GetTime() * 1000
        -- For Cast: Current = Now - Start
        -- For Channel: Current = End - Now (Inverse) or just Now - Start?
        -- Usually bars show "elapsed".
        -- Let's stick to elapsed:
        return (now - startTime) / 1000
    end)
    return success and result or 0
end

local function GetUnitCastBarRemainingTime(unit)
    local name, _, _, startTime, endTime = UnitCastingInfo(unit)
    if not name then
        name, _, _, startTime, endTime = UnitChannelInfo(unit)
    end
    if not startTime or not endTime then return 0 end

    -- Remaining = End - Now
    local success, result = pcall(function()
        local now = GetTime() * 1000
        local remaining = (endTime - now) / 1000
        if remaining < 0 then remaining = 0 end
        return remaining
    end)
    return success and result or 0
end

local function GetSafeLatency()
    -- Try C_Castbar first (12.0.1)
    if C_Castbar and C_Castbar.GetLatencyAspect then
        local success, latency = pcall(C_Castbar.GetLatencyAspect)
        if success and latency then return latency / 1000 end
    end
    -- Fallback: Network World Latency
    local _, _, home, world = GetNetStats()
    return (world or home) / 1000
end

-- ----------------------------------------------------------------------------
-- 2. Update Logic
-- ----------------------------------------------------------------------------

function ns.UpdateCast(bar)
    local unit = bar.unit
    -- respecting enabled flag
    local db = RoithiUI.db.profile.Castbar[unit]
    if not db or not db.enabled then
        bar:Hide(); bar:SetScript("OnUpdate", nil)
        return
    end

    -- If in Edit Mode, do NOT update (keep dummy bar visible)
    if bar.isInEditMode then return end

    -- If inside the Interrupt animation, we allow new casts to OVERRIDE it.
    -- We do NOT return early anymore.

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
        ---@diagnostic disable-next-line: undefined-field
        if not isEmpoweredSafe and _G.UnitEmpoweredStagePercentages then
            ---@diagnostic disable-next-line: undefined-field
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

        -- Only hide if we aren't showing an interrupt animation
        if not bar.isInterrupted then
            bar:Hide(); bar:SetScript("OnUpdate", nil)
        end
        return
    end

    -- New Cast Detected: Clear Interrupt State so pending timers don't hide us
    bar.isInterrupted = false

    local colors = RoithiUI.db.profile.Castbar[unit].colors
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

    -- Latency Indicator
    if bar.Latency then
        local latencySec = GetSafeLatency()
        local duration = (endTime - startTime) / 1000
        if duration > 0 then
            local width = bar:GetWidth() * (latencySec / duration)
            -- Cap width to bar width
            if width > bar:GetWidth() then width = bar:GetWidth() end

            bar.Latency:SetWidth(width)
            bar.Latency:SetHeight(bar:GetHeight()) -- Ensure height matches if bar resizes
            bar.Latency:ClearAllPoints()

            -- If Channeling or Reverse Fill, safe zone is on LEFT (start of bar visually? No, channeling depletes L->R or R->L?)
            -- Standard Cast: Fills L->R. Safe zone is at end (RIGHT).
            -- Channel: Depletes R->L (usually). Safe zone is at end of cast (LEFT).
            if state == "channel" then
                bar.Latency:SetPoint("LEFT", bar, "LEFT", 0, 0)
            else
                bar.Latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
            end
            bar.Latency:Show()
        else
            bar.Latency:Hide()
        end
    end

    if RoithiUI.db.profile.Castbar[unit].showIcon then
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

        -- Time Text Updates (Remaining Only)
        if self.TimeFS then
            local remaining = GetUnitCastBarRemainingTime(unit)
            self.TimeFS:SetText(FormatDuration(remaining))
        end

        if self.isEmpower and ns.OnEmpowerUpdate then
            ns.OnEmpowerUpdate(self)
        end
    end)
end

function ns.HandleInterrupt(bar)
    if bar.isEmpower then ns.StopEmpower(bar) end

    -- Freeze progress so background is visible
    bar.isInterrupted = true; bar:SetScript("OnUpdate", nil)

    local c = RoithiUI.db.profile.Castbar[bar.unit].colors.interrupted
    -- Change Background to Interrupt Color
    if bar.Background and c then
        bar.Background:SetColorTexture(c[1], c[2], c[3], c[4])
    end

    bar.Text:SetText("INTERRUPTED"); bar.Spark:Hide()
    C_Timer.After(1.0, function()
        -- Only hide if we are STILL interrupted (didn't start a new cast)
        if bar.isInterrupted then
            bar.isInterrupted = false; bar:Hide()
        end
    end)
end
