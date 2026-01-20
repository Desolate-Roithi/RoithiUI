local addonName, ns = ...
local RoithiUI = _G.RoithiUI
-- DB resolved in functions

-- ----------------------------------------------------------------------------
-- Constants & Configuration
-- ----------------------------------------------------------------------------


-- Flash Settings
local FLASH_DURATION = 0.25
local FLASH_WIDTH = 6
local TICK_WIDTH = 2
local TICK_COLOR = { 0, 0, 0, 1 }

-- ----------------------------------------------------------------------------
-- Timeline Logic
-- ----------------------------------------------------------------------------
local function BuildEmpowerTimeline(unit)
    local stageEnds = {}
    local totalStage = 0

    -- 1. Duration from UnitChannelInfo (usually Charge Duration)
    -- Empowered spells are channels, but UnitCastingInfo might return data too.
    -- Empowered spells are channels, but UnitCastingInfo might return data too.
    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID, _, numStages
    local isEmpowered -- Declare local
    name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID, _, numStages =
        UnitCastingInfo(unit)

    if not name then
        name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, isEmpowered, numStages =
            UnitChannelInfo(unit)
    end

    -- Safety Check for Secret Values (Protected Targets)
    if not startTime or not endTime or type(startTime) ~= "number" or type(endTime) ~= "number" then
        return nil
    end

    local chargeDuration = (endTime - startTime) / 1000
    local startSec = startTime / 1000

    -- 2. Stage Percentages (12.0 API)
    -- These define the breakpoints relative to the chargeDuration.
    -- 2. Stage Logic (12.0 API Support)
    -- Priorities:
    -- 1. UnitEmpoweredStageDurations (New 12.0.1 preferred)
    -- 2. UnitEmpoweredStagePercentages (Legacy/Deprecated?)
    -- 3. Fallback (Equal Split)

    local durations
    if UnitEmpoweredStageDurations then
        durations = UnitEmpoweredStageDurations(unit)
    end

    local percentages
    if not durations and _G.UnitEmpoweredStagePercentages then
        percentages = _G.UnitEmpoweredStagePercentages(unit)
    end

    if durations and #durations > 0 then
        -- Durations -> Ends
        local accum = 0
        for i, dur in ipairs(durations) do
            -- Duration is likely in ms or seconds? Usually match UnitChannelInfo format.
            -- If huge, normalize. If small, assume seconds.
            -- UnitChannelInfo returns ms but we converted to seconds (chargeDuration).
            -- Let's verify standard API return. Usually Duration APIs return MS if integer, Seconds if float.
            -- Safest: if dur > 100 then dur = dur / 1000 end

            if dur > 50 then dur = dur / 1000 end

            accum = accum + dur
            stageEnds[i] = accum
        end
        totalStage = accum -- Total duration defined by sum of stages

        -- Override chargeDuration source of truth?
        -- Sometimes chargeDuration (from ChannelInfo) differs slightly from sum of stages due to latency window.
        -- We trust sum of stages for the timeline visual.
        chargeDuration = totalStage
    elseif percentages and #percentages > 0 then
        for i, pct in ipairs(percentages) do
            stageEnds[i] = pct * chargeDuration
        end
        totalStage = stageEnds[#stageEnds] or chargeDuration
    else
        -- Fallback if no data (guess)
        if chargeDuration > 0 then
            local count = numStages or 3
            if count < 1 then count = 3 end -- safety

            stageEnds = {}
            for i = 1, count do
                stageEnds[i] = chargeDuration * (i / count)
            end
            totalStage = chargeDuration
        end
    end

    -- 3. Hold Phase
    local holdDuration = 0
    if GetUnitEmpowerHoldAtMaxTime then
        holdDuration = GetUnitEmpowerHoldAtMaxTime(unit) or 0
    end

    -- If the API returns seconds (e.g. 2.0), we use it.
    -- Some 12.0 APIs might return milliseconds, so normalize if huge.
    if holdDuration > 20 then holdDuration = holdDuration / 1000 end

    local totalDuration = chargeDuration + holdDuration

    return {
        stageEnds = stageEnds,
        chargeDuration = chargeDuration, -- Duration of the stages
        holdDuration = holdDuration,     -- Extra time after stages
        totalDuration = totalDuration,   -- Combined
        startTime = startSec,
        endTime = endTime / 1000         -- Original simplified charge end
    }
end

-- ----------------------------------------------------------------------------
-- Visuals: Ticks & Segments
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

    -- Create Flash on the BAR (Parent), anchored to the TICK
    -- Use a cache on the tick to store reference to its flash texture
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

    -- Animation
    flash:Show()
    flash:SetAlpha(1)

    local animGroup = tick.AnimGroup
    if not animGroup then
        animGroup = bar:CreateAnimationGroup() -- Parent anim to bar (safe)
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

    local width = bar:GetWidth() or 1
    local height = bar:GetHeight() or 1
    local db = RoithiUIDB.Castbar[bar.unit]
    local colors = db and db.colors

    -- Clean existing
    if bar.StageTicks then for _, t in pairs(bar.StageTicks) do t:Hide() end end
    if bar.StageZones then for _, z in pairs(bar.StageZones) do z:Hide() end end

    local lastPos = 0
    local stageEnds = tl.stageEnds
    local total = tl.totalDuration

    -- Avoid div/0
    if total <= 0 then total = 0.001 end

    -- Draw Start -> Charge End
    for i, endSec in ipairs(stageEnds) do
        local pct = endSec / total
        if pct > 1 then pct = 1 end

        -- Draw Zone
        local zone = CreateOrGetTexture(bar, "StageZones", i, "BACKGROUND")
        zone:ClearAllPoints()
        zone:SetPoint("LEFT", bar, "LEFT", width * lastPos, 0)
        zone:SetWidth(math.max(0, (pct - lastPos) * width))
        zone:SetHeight(height)

        -- Determine Color based on Specific Logic
        local c = { 0.5, 0.5, 0.5, 1 } -- Default Grey for Stage 0 (i=1)

        if i == 1 then
            -- Stage 0 (Start -> Pip 1): Grey (Hardcoded)
            c = { 0.5, 0.5, 0.5, 1 }
        elseif i == 2 then
            -- Stage 1 (Pip 1 -> Pip 2): Empower 1
            if colors and colors.empower1 then c = colors.empower1 end
        elseif i == 3 then
            -- Stage 2 (Pip 2 -> Pip 3): Empower 2
            if colors and colors.empower2 then c = colors.empower2 end
        elseif i == 4 then
            -- Stage 3 (Pip 3 -> Pip 4/End): Empower 3
            if colors and colors.empower3 then c = colors.empower3 end
        elseif i >= 5 then
            -- Stage 4+ (Pip 4 -> End): Empower 4 (Blue)
            if colors and colors.empower4 then c = colors.empower4 end
        end

        zone:SetColorTexture(c[1], c[2], c[3], c[4])
        zone:Show()

        -- Draw Tick
        if pct < 0.995 then
            local tick = CreateOrGetTexture(bar, "StageTicks", i, "ARTWORK")
            tick:ClearAllPoints()
            tick:SetPoint("CENTER", bar, "LEFT", width * pct, 0)
            tick:SetSize(TICK_WIDTH, height)
            tick:SetColorTexture(TICK_COLOR[1], TICK_COLOR[2], TICK_COLOR[3], TICK_COLOR[4])
            tick:Show()

            if tick.Flash then tick.Flash:SetHeight(height) end
        end

        lastPos = pct
    end

    -- Draw Hold Phase (if any)
    if lastPos < 0.995 then
        local i = #stageEnds + 1
        local zone = CreateOrGetTexture(bar, "StageZones", i, "BACKGROUND")
        zone:ClearAllPoints()
        zone:SetPoint("LEFT", bar, "LEFT", width * lastPos, 0)
        zone:SetWidth(math.max(0, (1.0 - lastPos) * width))
        zone:SetHeight(height)

        -- Hold Phase uses the color of the FINAL stage achieved
        -- If we have 3 pips (#stageEnds=3), the stages were:
        -- i=1 (Grey), i=2 (Emp1), i=3 (Emp2).
        -- The segment AFTER i=3 is "Stage 3" (Green).

        -- Logic:
        -- If #stageEnds == 3 -> implies standard 3-stage spell. Hold is Stage 3 (Empower 3).
        -- If #stageEnds == 4 -> implies 4-stage spell. Hold is Stage 4 (Empower 4).

        local c = { 0.2, 1, 0.2, 1 } -- Fallback Green

        if #stageEnds == 3 then
            -- Standard 3-stage spell
            if colors and colors.empower3 then c = colors.empower3 end
        elseif #stageEnds >= 4 then
            -- 4-stage spell or more
            if colors and colors.empower4 then c = colors.empower4 end
        else
            -- Unusual (1 or 2 stages?), use Emp1 or Emp2
            if colors and colors.empower1 then c = colors.empower1 end
        end

        zone:SetColorTexture(c[1], c[2], c[3], c[4])
        zone:Show()
    end

    -- Update the Castbar MinMax to match the NEW total duration including hold
    if bar.SetMinMaxValues then
        bar:SetMinMaxValues(0, total)
    end

    bar.empowerStartTime = tl.startTime
end

-- ----------------------------------------------------------------------------
-- Main Interface
-- ----------------------------------------------------------------------------

function ns.SetupEmpower(bar)
    local tl = BuildEmpowerTimeline(bar.unit)
    if not tl then return end

    bar.empowerTimeline = tl
    bar.isEmpower = true
    bar.empowerNextStageIndex = 1

    LayoutEmpower(bar)
end

function ns.OnEmpowerUpdate(bar)
    if not bar.isEmpower or not bar.empowerTimeline then return end

    -- Calculate elapsed based on OUR timeline start
    -- (Castbar.lua SetValue might be setting absolute time, but for logic we use relative)
    local now = GetTime()
    local elapsed = now - bar.empowerTimeline.startTime
    local total = bar.empowerTimeline.totalDuration

    if elapsed < 0 then elapsed = 0 end
    if elapsed > total then elapsed = total end

    -- Override the visual value to match our 0..total scale
    if bar.SetValue then
        bar:SetValue(elapsed)
    end

    local stageEnds = bar.empowerTimeline.stageEnds

    -- Check if we passed a stage end
    local idx = bar.empowerNextStageIndex
    while idx <= #stageEnds do
        local endSec = stageEnds[idx]
        if elapsed >= endSec then
            -- Trigger Flash on the tick correspond to this stage end
            if bar.StageTicks and bar.StageTicks[idx] then
                BlinkTick(bar, bar.StageTicks[idx])
            end

            idx = idx + 1
        else
            break
        end
    end

    -- Dynamic Color Update (Change Bar Color based on current stage)
    -- We use the NEXT stage index (idx) to determine current stage logic
    -- If idx=1 (Waiting for Stage 1 End) -> Stage 0 (Grey)
    -- If idx=2 (Passed Stage 1 End, waiting for Stage 2) -> Stage 1 (Org)
    local stageColorIdx = idx - 1
    if stageColorIdx < 0 then stageColorIdx = 0 end -- Safety

    local db = RoithiUIDB.Castbar[bar.unit]
    local colors = db and db.colors
    local c = { 0.5, 0.5, 0.5, 1 } -- Default Grey

    if stageColorIdx == 0 then
        c = { 0.5, 0.5, 0.5, 1 }
    elseif stageColorIdx == 1 then
        if colors and colors.empower1 then c = colors.empower1 end
    elseif stageColorIdx == 2 then
        if colors and colors.empower2 then c = colors.empower2 end
    elseif stageColorIdx == 3 then
        if colors and colors.empower3 then c = colors.empower3 end
    elseif stageColorIdx >= 4 then
        if colors and colors.empower4 then c = colors.empower4 end
    end

    if bar.SetStatusBarColor then
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    end

    bar.empowerNextStageIndex = idx
end

function ns.StopEmpower(bar)
    bar.isEmpower = false
    bar.empowerTimeline = nil

    if bar.StageTicks then for _, t in pairs(bar.StageTicks) do t:Hide() end end
    if bar.StageZones then for _, z in pairs(bar.StageZones) do z:Hide() end end
end
