local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
-- DB resolved in functions

-- ----------------------------------------------------------------------------
-- Constants & Configuration
-- ----------------------------------------------------------------------------
local FLASH_DURATION = 0.25
local FLASH_WIDTH = 6
local TICK_WIDTH = 2
local TICK_COLOR = { 0, 0, 0, 1 }

-- ----------------------------------------------------------------------------
-- Helper: Duration Object Extraction
-- ----------------------------------------------------------------------------
local function GetSecondsFromObject(obj)
    if not obj then return 0 end
    if type(obj) == "number" then return obj end

    -- 12.0.1 DurationObject Methods
    -- If Secret, return 0 to be safe (layout effectively collapses)
    if obj.HasSecretValues and obj:HasSecretValues() then return 0 end

    if obj.GetTotalDuration then return obj:GetTotalDuration() end
    if obj.GetSeconds then return obj:GetSeconds() end
    if obj.GetMilliseconds then return obj:GetMilliseconds() / 1000 end

    return 0
end

-- ----------------------------------------------------------------------------
-- Timeline Logic (Strict SSOT)
-- ----------------------------------------------------------------------------
local function BuildEmpowerTimeline(unit)
    -- 1. FETCH TOTAL DURATION (SSOT)
    -- UnitEmpoweredChannelDuration(unit, true) -> DurationObject
    local totalObj = nil
    if UnitEmpoweredChannelDuration then
        totalObj = UnitEmpoweredChannelDuration(unit, true)
    end

    local totalDuration = GetSecondsFromObject(totalObj)
    local isSecretDuration = totalObj and totalObj.HasSecretValues and totalObj:HasSecretValues()

    -- 2. FETCH STAGE DATA (SSOT)
    local stageObjs = nil
    if UnitEmpoweredStageDurations then
        stageObjs = UnitEmpoweredStageDurations(unit)
    end

    -- 3. FETCH STAGE PERCENTAGES (12.0.1+ Native Layout Helper - Non-Secret)
    local stagePcts = nil
    if UnitEmpoweredStagePercentages then
        stagePcts = UnitEmpoweredStagePercentages(unit)
    end

    local stageEnds = {}
    local totalStages = 0

    if stagePcts and #stagePcts > 0 then
        totalStages = #stagePcts
        local accum = 0
        for i, pct in ipairs(stagePcts) do
            -- Convert to 0-1 ratio safely in case the API provides 0-100 integers
            if pct > 1.0 and totalStages > 1 then
                pct = pct / 100.0
            end
            
            if isSecretDuration then
                accum = accum + pct
                stageEnds[i] = accum
            else
                accum = accum + (pct * totalDuration)
                stageEnds[i] = accum
            end
        end
    elseif stageObjs then
        -- Legacy/Fallback: Calculate from durations if percentages missing
        totalStages = #stageObjs
        local accum = 0
        for i, obj in ipairs(stageObjs) do
            local dur = GetSecondsFromObject(obj)
            accum = accum + dur
            stageEnds[i] = accum
        end
    end

    return {
        stageEnds = stageEnds,
        totalDuration = isSecretDuration and 1 or totalDuration, -- If secret, 'total' is 1.0 (normalized)
        totalStages = totalStages,
        isSecret = isSecretDuration
    }
end

-- ----------------------------------------------------------------------------
-- Visuals
-- ----------------------------------------------------------------------------
local function CreateOrGetTexture(bar, collection, index, layer, subLevel)
    if not bar[collection] then bar[collection] = {} end
    local tex = bar[collection][index]
    if not tex then
        tex = bar:CreateTexture(nil, layer, nil, subLevel or 0)
        bar[collection][index] = tex
    end
    return tex
end

local function BlinkTick(bar, tick)
    if not tick or not bar then return end
    local flash = tick.Flash
    if not flash then
        flash = bar:CreateTexture(nil, "OVERLAY")
        flash:SetTexture("Interface\\Buttons\\WHITE8x8")
        flash:SetBlendMode("ADD")
        flash:SetPoint("CENTER", tick, "CENTER", 0, 0)
        flash:SetSize(FLASH_WIDTH, tick:GetHeight())
        flash:SetVertexColor(1, 1, 1, 1)
        flash:Hide()
        tick.Flash = flash
    end
    flash:Show()
    flash:SetAlpha(1)
    local animGroup = tick.AnimGroup
    if not animGroup then
        animGroup = bar:CreateAnimationGroup()
        local alpha = animGroup:CreateAnimation("Alpha")
        alpha:SetFromAlpha(1); alpha:SetToAlpha(0); alpha:SetDuration(FLASH_DURATION)
        alpha:SetTarget(flash)
        animGroup.Alpha = alpha
        animGroup:SetScript("OnFinished", function() flash:Hide() end)
        tick.AnimGroup = animGroup
    end
    tick.AnimGroup:Stop()
    tick.AnimGroup:Play()
end

local function LayoutEmpower(bar)
    local tl = bar.empowerTimeline
    if not tl then return end

    local width = bar:GetWidth()
    if not width or width < 1 then
        bar.empowerLayoutPending = true
        return
    end
    bar.empowerLayoutPending = nil

    -- Note: We do NOT SetMinMaxValues here. Castbar.lua calls SetTimerDuration.
    -- We assume the bar max is tl.totalDuration for layout ratio purposes.

    local height = bar:GetHeight() or 20
    if bar.StageTicks then for _, t in pairs(bar.StageTicks) do t:Hide() end end
    if bar.StageZones then for _, z in pairs(bar.StageZones) do z:Hide() end end

    local total = tl.totalDuration
    -- Avoid div/0 visual errors
    if total <= 0.001 then total = 1 end

    local lastPos = 0

    -- DRAW ZONES & TICKS (Iterate 1 to TotalStages)
    -- Zones are drawn on BORDER layer (behind main fill) to act as background indicators.
    -- Ticks are drawn on ARTWORK (above fill) to remain visible.

    for i, absVal in ipairs(tl.stageEnds) do
        local pct = absVal / total
        if pct > 1 then pct = 1 end
        if pct < 0 then pct = 0 end

        -- 1. Draw Zone (Background)
        local zone = CreateOrGetTexture(bar, "StageZones", i, "BORDER", 2)
        zone:ClearAllPoints()

        local segWidth = (pct - lastPos) * width
        -- Minimum width check
        if segWidth < 0.1 then
            -- If segments are weirdly small, just hide or cap.
            -- For visual consistency we keep it.
            segWidth = 0.1
        end

        zone:SetPoint("LEFT", bar, "LEFT", width * lastPos, 0)
        zone:SetWidth(segWidth)
        zone:SetHeight(height)

        -- Determine Zone Color (Static Map)
        local db = RoithiUI.db.profile.Castbar[bar.unit]
        local colors = db and db.colors
        local c = { 0.5, 0.5, 0.5, 0.5 } -- Default greyish background

        -- STRICT USER MAPPING:
        -- 0 -> 1 = Grey
        -- 1 -> 2 = empower1
        -- 2 -> 3 = empower2
        -- 3 -> 4 = empower3 (Only applies if >3 stages)

        if i == 1 then
            c = { 0.5, 0.5, 0.5, 1 } -- Stage 1 is always Grey
        elseif i == 2 and colors.empower1 then
            c = colors.empower1
        elseif i == 3 and colors.empower2 then
            c = colors.empower2
        elseif i == 4 and colors.empower3 then
            c = colors.empower3
        elseif i >= 5 and colors.empower4 then
            c = colors.empower4
        end

        -- Mute the background alpha significantly to provide distinct visual contrast against the actual cast bar filling up
        local a = c[4] or 1
        zone:SetColorTexture(c[1], c[2], c[3], a * 0.35)
        zone:Show()

        -- 2. Draw Tick (Separator)
        -- Do not draw tick at the very end of the bar
        if i < tl.totalStages then
            local tick = CreateOrGetTexture(bar, "StageTicks", i, "ARTWORK", 3)
            tick:ClearAllPoints()
            tick:SetPoint("CENTER", bar, "LEFT", width * pct, 0)
            tick:SetSize(TICK_WIDTH, height)
            tick:SetColorTexture(TICK_COLOR[1], TICK_COLOR[2], TICK_COLOR[3], TICK_COLOR[4])
            tick:Show()
        end

        lastPos = pct
    end
end

-- ----------------------------------------------------------------------------
-- Main Interface
-- ----------------------------------------------------------------------------

function ns.SetupEmpower(bar)
    local tl = BuildEmpowerTimeline(bar.unit)
    if not tl then return end

    bar.empowerTimeline = tl
    bar.isEmpower = true
    bar.currentEmpowerStage = 0 -- Reset for player/event-driven logic

    LayoutEmpower(bar)
end

function ns.OnEmpowerStage(bar, _, stageIndex)
    if not bar.isEmpower then return end
    bar.currentEmpowerStage = stageIndex or 0

    -- Trigger Tick Flash (One-shot)
    if stageIndex and bar.StageTicks and bar.StageTicks[stageIndex] then
        BlinkTick(bar, bar.StageTicks[stageIndex])
    end
end

function ns.OnEmpowerUpdate(bar)
    if not bar.isEmpower or not bar.empowerTimeline then return end

    if bar.empowerLayoutPending then
        LayoutEmpower(bar)
        if bar.empowerLayoutPending then return end
    end

    local tl = bar.empowerTimeline
    local total = tl.totalDuration
    local progressRatio = 0

    -- Use Duration Object for Elapsed Time if available (Preferred)
    if bar.durationObj and bar.durationObj.GetElapsedDuration then
        -- 12.0.1: If duration is secret, we must use a percentage-based approach or
        -- rely on the fact that bar:GetValue() might return a normalized value.
        -- HOWEVER, standard StatusBars in 12.0.1 handle secret casting via SetTimerDuration.
        -- To trigger our ticks/colors, we need a ratio.

        if tl.isSecret and bar.durationObj.GetProgress then
            progressRatio = bar.durationObj:GetProgress()
        else
            local elapsed = bar.durationObj:GetElapsedDuration()
            -- 12.0.1 MIDNIGHT Fix: Extra safety check for secret duration objects
            if issecretvalue and issecretvalue(elapsed) then
                if bar.durationObj.GetProgress then
                    progressRatio = bar.durationObj:GetProgress()
                else
                    progressRatio = 0 -- Fallback to prevent crash
                end
            elseif total > 0 then
                progressRatio = elapsed / total
            end
        end
    else
        -- Fallback
        if bar.GetValue then
            local elapsed = bar:GetValue()
            if total > 0 then progressRatio = elapsed / total end
        end
    end

    -- -----------------------------------------
    -- Visual Triggers (Ticks) & Color Logic
    -- -----------------------------------------
    local isRatioSecret = issecretvalue and issecretvalue(progressRatio)

    if not isRatioSecret then
        if progressRatio > 1 then progressRatio = 1 end

        -- Auto-Reset: If progress drops to near zero, assume new cast or restart.
        if progressRatio < 0.05 then
            if bar.empowerFlashed then
                for k in pairs(bar.empowerFlashed) do bar.empowerFlashed[k] = nil end
            else
                bar.empowerFlashed = {}
            end
        end
    end
    if not bar.empowerFlashed then bar.empowerFlashed = {} end

    -- Determine Dynamic Stage (Color) & Trigger Ticks
    local currentStage = 1

    if isRatioSecret then
        -- 12.0.1 MIDNIGHT: Use the event-synced stage for secret casts
        currentStage = (bar.currentEmpowerStage or 0) + 1
    else
        for i, threshold in ipairs(tl.stageEnds) do
            local targetRatio = threshold / total

            -- Check if we passed this stage
            if progressRatio >= targetRatio then
                -- We have completed stage 'i'. So we are at least in stage 'i+1'.
                currentStage = i + 1

                -- Trigger Tick Flash (One-shot)
                if i < tl.totalStages then
                    if not bar.empowerFlashed[i] then
                        if bar.StageTicks and bar.StageTicks[i] then
                            BlinkTick(bar, bar.StageTicks[i])
                        end
                        bar.empowerFlashed[i] = true
                    end
                end
            else
                -- We are IN stage 'i'.
                currentStage = i
                break
            end
        end
    end

    -- Bound to prevent index errors
    if currentStage > tl.totalStages + 1 then currentStage = tl.totalStages + 1 end

    -- Color Logic (Progressive)
    local db = RoithiUI.db.profile.Castbar[bar.unit]
    local colors = db and db.colors
    local c = { 1, 1, 0, 1 }

    if currentStage > tl.totalStages then
        -- HOLD PHASE (Matches Final Charge Level)
        local stagesCount = tl.totalStages

        -- "stage 3 -> hold = empower3"
        -- "stage 4 -> hold = empower4"
        if stagesCount == 3 and colors.empower3 then
            c = colors.empower3
        elseif stagesCount == 4 and colors.empower4 then
            c = colors.empower4
        elseif stagesCount == 2 and colors.empower2 then
            c = colors.empower2
        elseif stagesCount == 1 and colors.empower1 then
            c = colors.empower1
        elseif colors.empowerHold then
            -- Fallback if mapped color missing or unexpected >4
            c = colors.empowerHold
        else
            c = { 0, 0, 1, 1 } -- Blue default
        end
    else
        -- CHARGE PHASE (Filling Up)
        -- 0->1: Grey
        -- 1->2: emp1
        -- 2->3: emp2
        -- 3->4: emp3
        if currentStage == 1 then
            c = { 0.5, 0.5, 0.5, 1 } -- Grey
        elseif currentStage == 2 and colors.empower1 then
            c = colors.empower1
        elseif currentStage == 3 and colors.empower2 then
            c = colors.empower2
        elseif currentStage == 4 and colors.empower3 then
            c = colors.empower3
        elseif currentStage >= 5 and colors.empower4 then
            c = colors.empower4
        end
    end

    if bar.SetStatusBarColor then
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    end
end

function ns.StopEmpower(bar)
    bar.isEmpower = false
    bar.empowerTimeline = nil
    -- Also clear flashed state
    bar.empowerFlashed = nil

    if bar.StageTicks then for _, t in pairs(bar.StageTicks) do t:Hide() end end
    if bar.StageZones then for _, z in pairs(bar.StageZones) do z:Hide() end end
end
