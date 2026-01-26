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
    local db = RoithiUI.db.profile.Castbar[unit]
    if not db or not db.enabled then
        bar:Hide(); bar:SetScript("OnUpdate", nil)
        return
    end

    if bar.isInEditMode then return end

    -- ------------------------------------------------------------------------
    -- A. Determine State & Fetch Duration Object
    -- ------------------------------------------------------------------------
    local name, text, texture, eventType, notInterruptible, spellID
    local durationObj
    local state = "cast" -- cast | channel | empowered

    -- 1. Check Channel / Empowered
    local chName, chText, chTexture, _, _, _, chNotInt, chSpellID, isEmpowered, numEmpowerStages = UnitChannelInfo(unit)

    if chName then
        name = chName
        text = chText
        texture = chTexture
        spellID = chSpellID
        notInterruptible = chNotInt

        -- Empowered Check
        if isEmpowered or (numEmpowerStages and numEmpowerStages > 0) then
            state = "empowered"
            if UnitEmpoweredChannelDuration then
                durationObj = UnitEmpoweredChannelDuration(unit, true)
            end
        else
            state = "channel"
            if UnitChannelDuration then
                durationObj = UnitChannelDuration(unit)
            end
        end
    else
        -- 2. Check Standard Cast
        local cName, cText, cTexture, _, _, _, _, cNotInt, cSpellID = UnitCastingInfo(unit)
        if cName then
            state = "cast"
            name = cName
            text = cText
            texture = cTexture
            spellID = cSpellID
            notInterruptible = cNotInt

            if UnitCastingDuration then
                durationObj = UnitCastingDuration(unit)
            end
        end
    end

    -- If no active cast (or API missing), hide
    if not name or not durationObj then
        if bar.isEmpower and ns.StopEmpower then ns.StopEmpower(bar) end
        if not bar.isInterrupted then
            bar:Hide(); bar:SetScript("OnUpdate", nil)
        end
        return
    end

    -- Clear Interrupt State
    bar.isInterrupted = false

    -- ------------------------------------------------------------------------
    -- B. Visual Setup (Colors, Icon, Spark)
    -- ------------------------------------------------------------------------
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

    if RoithiUI.db.profile.Castbar[unit].showIcon then
        bar.Icon:Show(); bar.Icon:SetTexture(texture)
    else
        bar.Icon:Hide()
    end



    -- Feature: Cap cast name length at 22
    if text and string.len(text) > 22 then
        text = string.sub(text, 1, 22) .. "..."
    end
    bar.Text:SetText(text)


    -- ------------------------------------------------------------------------
    -- C. Apply Duration Object (Native 12.0 API)
    -- ------------------------------------------------------------------------
    -- The Magic: This handles MinMax, Value, and Animation automatically (incl. Secrets)
    if bar.SetTimerDuration then
        bar:SetTimerDuration(durationObj)
    else
        -- Fallback for pre-12.0 environments (should never happen based on user context)
        print("Error: SetTimerDuration not supported on this client.")
    end

    -- Store for Latency/OnUpdate
    bar.durationObj = durationObj

    -- ------------------------------------------------------------------------
    -- D. Mode Specific Logic
    -- ------------------------------------------------------------------------
    if state == "empowered" then
        bar:SetReverseFill(false)

        -- Empower Setup
        local needSetup = true
        -- Can we check equality of DurationObjects? assume yes or just always setup
        if bar.isEmpower then needSetup = false end

        if needSetup then
            ns.SetupEmpower(bar) -- Will use UnitEmpoweredStageDurations
        end

        bar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
    elseif state == "channel" then
        if bar.isEmpower then ns.StopEmpower(bar) end
        bar:SetReverseFill(true)
        bar:SetStatusBarColor(0, 0, 0, 1)
        if bar.Background then bar.Background:SetColorTexture(c[1], c[2], c[3], c[4]) end
    else
        -- Standard
        if bar.isEmpower then ns.StopEmpower(bar) end
        bar:SetReverseFill(false)
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
        if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
    end

    -- ------------------------------------------------------------------------
    -- E. Latency (Requires TotalDuration)
    -- ------------------------------------------------------------------------
    if bar.Latency then
        local showLatency = false

        -- Check if safe to calculate using Native Object Methods
        -- CRITICAL: Check HasSecretValues() FIRST. If true, IsZero() might return a Secret<bool> which crashes on 'not'.
        if not durationObj:HasSecretValues() and not durationObj:IsZero() then
            local totalSec = durationObj:GetTotalDuration()
            local latencySec = GetSafeLatency()

            -- We trust totalSec is a number because HasSecretValues() is false
            if totalSec > 0 then
                local width = bar:GetWidth() * (latencySec / totalSec)
                if width > bar:GetWidth() then width = bar:GetWidth() end

                bar.Latency:SetWidth(width)
                bar.Latency:SetHeight(bar:GetHeight())
                bar.Latency:ClearAllPoints()
                if state == "channel" then
                    bar.Latency:SetPoint("LEFT", bar, "LEFT", 0, 0)
                else
                    bar.Latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
                end
                showLatency = true
            end
        end

        if showLatency then
            bar.Latency:Show()
        else
            bar.Latency:Hide()
        end
    end

    bar:Show()

    -- ------------------------------------------------------------------------
    -- F. OnUpdate (Text Only)
    -- ------------------------------------------------------------------------
    -- SetTimerDuration handles progress. We only need to update the text.
    bar:SetScript("OnUpdate", function(self, elapsed)
        -- We do NOT call SetValue here anymore.

        if self.TimeFS and self.durationObj then
            local textVal = ""
            -- Safe Check: If secret, we cannot read remaining duration for text.
            if not self.durationObj:HasSecretValues() then
                if self.durationObj.GetRemainingDuration then
                    local rem = self.durationObj:GetRemainingDuration()
                    textVal = FormatDuration(rem)
                end
            end
            self.TimeFS:SetText(textVal)
        end

        if self.isEmpower and ns.OnEmpowerUpdate then
            ns.OnEmpowerUpdate(self)
        end
    end)
end

function ns.HandleInterrupt(bar)
    if bar.isEmpower then ns.StopEmpower(bar) end

    -- 1. Visual Updates FIRST (Ensure Text/Color always apply)
    bar.Text:SetText("INTERRUPTED"); bar.Spark:Hide()

    local c = RoithiUI.db.profile.Castbar[bar.unit].colors.interrupted
    if bar.Background and c then
        bar.Background:SetColorTexture(c[1], c[2], c[3], c[4])
        -- Fix V3: Visual Mask (Foreground == Background) to hide filling
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    end


    -- 2. Freeze progress
    bar.isInterrupted = true; bar:SetScript("OnUpdate", nil)
    local frozenVal = bar:GetValue()
    bar:SetValue(frozenVal) -- Explicitly freeze visual state

    -- 3. FIX CRASH: Stop Native Animation Safely (12.0)
    if bar.SetTimerDuration then
        -- Use pcall to prevent crashes if API is strict about arguments
        -- Pass 0 instead of nil if that helps, or just swallow the error
        pcall(bar.SetTimerDuration, bar, 0)
    end

    -- 4. Vanish after 1 second
    C_Timer.After(1.0, function()
        -- Only hide if we are STILL interrupted (didn't start a new cast)
        -- Using local closure safety
        if bar.isInterrupted then
            bar.isInterrupted = false
            bar:Hide()
        end
    end)
end
