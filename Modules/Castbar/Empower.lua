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

    -- 1. Get Cast Data
    -- Note: We check ChannelInfo first because most Empowered spells are channels.
    local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, isEmpowered, numStages =
        UnitChannelInfo(unit)

    if not name then
        -- Fallback to CastingInfo (unlikely for Empowered, but possible)
        -- Note: casting info return values differ slightly
        local castID
        name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unit)
        isEmpowered = false
    end

    -- 2. SECRET VALUE SAFETY CHECK
    -- In 12.0.1, 'startTime' is a Secret (userdata) for the Player in combat.
    -- We CANNOT do math on it. If it's not a number, we must abort the visual ticks.
    -- This allows the bar to work for Targets (where it's a number) without crashing on Player.
    if not startTime or not endTime or type(startTime) ~= "number" or type(endTime) ~= "number" then
        return nil
    end

    local chargeDuration = (endTime - startTime) / 1000
    local startSec = startTime / 1000

    -- 3. Stage Configuration (12.0.1+ API)
    -- The new APIs return vectors where the LAST element is the HOLD phase.
    -- We can simply accumulate these to get the full timeline landmarks.

    local percentages
    local durations

    -- Priority 1: UnitEmpoweredStageDurations (Absolute Sequence)
    if UnitEmpoweredStageDurations then
        durations = UnitEmpoweredStageDurations(unit)
    end

    -- Safety: Ensure durations are numbers. If they are Userdata (Secrets), we cannot use them.
    if durations and #durations > 0 and type(durations[1]) ~= "number" then
        durations = nil
    end

    if durations and #durations > 0 then
        local accum = 0
        for i, dur in ipairs(durations) do
            -- Normalize MS to S (Duration objects usually return MS in this context)
            if dur > 50 then dur = dur / 1000 end
            accum = accum + dur
            stageEnds[i] = accum
        end
        totalStage = accum

        -- If the API is accurate, totalStage should roughly equal chargeDuration (endTime - startTime).
        -- We trust the stage sums for the visual milestones.

        -- Priority 2: UnitEmpoweredStagePercentages (Relative Sequence)
    else
        if UnitEmpoweredStagePercentages then
            percentages = UnitEmpoweredStagePercentages(unit)
        end

        if percentages and #percentages > 0 then
            -- Percentages also include the Hold Phase as the last element.
            -- So they map 0-100% of the UnitEmpoweredChannelDuration (or chargeDuration).

            for i, pct in ipairs(percentages) do
                -- Normalize 0-100 to 0-1 if necessary
                if pct > 1.0 then pct = pct / 100 end
                stageEnds[i] = pct * chargeDuration
            end
            totalStage = stageEnds[#stageEnds] or chargeDuration
        else
            -- Priority 3: Fallback (Equal Split)
            -- If no API data, we assume standard behavior.
            -- We assume chargeDuration is mostly Charging if we lack hold info.
            if chargeDuration > 0 then
                local count = numStages or 3
                if count < 1 then count = 3 end

                for i = 1, count do
                    stageEnds[i] = chargeDuration * (i / count)
                end
                totalStage = chargeDuration
            end
        end
    end

    -- 4. Hold Phase
    -- Since the new APIs include Hold in the stages vector as the last element,
    -- we treat it as just another stage end in our stageEnds array.
    -- We do NOT add an extra Hold Duration on top.

    -- Safety: If APIs calculated a total > chargeDuration, trust the API sum.
    local finalDuration = totalStage
    if finalDuration <= 0 then finalDuration = chargeDuration end

    return {
        stageEnds = stageEnds,
        chargeDuration = chargeDuration,
        holdDuration = 0, -- Effectively handled inside stageEnds
        totalDuration = finalDuration,
        startTime = startSec,
        endTime = endTime / 1000
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
    local db = RoithiUI.db.profile.Castbar[bar.unit]
    local colors = db and db.colors

    -- Clean existing
    if bar.StageTicks then for _, t in pairs(bar.StageTicks) do t:Hide() end end
    if bar.StageZones then for _, z in pairs(bar.StageZones) do z:Hide() end end

    local lastPos = 0
    local stageEnds = tl.stageEnds
    local total = tl.totalDuration

    -- Avoid div/0
    if total <= 0 then total = 0.001 end

    -- Draw Stages (including Hold Phase which is now the last stage)
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
        -- i=1 is Stage 0 -> 1 (Grey)
        -- i=last is potentially Hold Phase

        local c = { 0.5, 0.5, 0.5, 1 } -- Default

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
            -- Stage 3 (Pip 3 -> End or Hold): Empower 3 (Green)
            if colors and colors.empower3 then c = colors.empower3 end
        elseif i >= 5 then
            -- Stage 4+ (Pip 4 -> End): Empower 4 (Blue)
            if colors and colors.empower4 then c = colors.empower4 end
        end

        zone:SetColorTexture(c[1], c[2], c[3], c[4])
        zone:Show()

        -- Draw Tick at the END of this stage (unless it's the very last one/Hold)
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

    local db = RoithiUI.db.profile.Castbar[bar.unit]
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
