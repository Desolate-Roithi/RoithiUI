local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:GetModule("Objectives")
local objState = ns.Objectives or {}
ns.Objectives = objState

local SCENARIO_LINE_SPACING = 10 -- Comfortable breathing room between boss criteria lines

local function SharesWidgetPool(tracker)
    if not tracker then return true end
    if tracker == _G.ScenarioObjectiveTracker or tracker == _G.UIWidgetObjectiveTracker then
        return true
    end
    local name = tracker.GetName and tracker:GetName()
    if name == "ScenarioObjectiveTracker" or name == "UIWidgetObjectiveTracker" then
        return true
    end
    if tracker.StageBlock or tracker.ChallengeModeBlock or tracker.ProvingGroundsBlock or tracker.isScenario then
        return true
    end
    if tracker.uiWidgetSet or tracker.widgetSetID then
        return true
    end
    return false
end
objState.SharesWidgetPool = SharesWidgetPool
ObjectivesMod.SharesWidgetPool = SharesWidgetPool

function ObjectivesMod:GetStageBlockWidgetHeight(stageBlock)
    if not stageBlock then return nil, false, nil, false end

    local wc = stageBlock.WidgetContainer
    local hasWidget = false

    if wc and (wc.IsShown == nil or wc:IsShown()) then
        if (wc.HasAnyWidgetsShowing and wc:HasAnyWidgetsShowing())
            or (wc.GetNumWidgetsShowing and wc:GetNumWidgetsShowing() > 0)
        then
            hasWidget = true
        elseif wc.widgetFrames then
            for _, wf in pairs(wc.widgetFrames) do
                if wf and (wf.IsShown == nil or wf:IsShown()) then
                    hasWidget = true
                    break
                end
            end
        end
    end

    if not hasWidget and stageBlock.widgetSetID and type(stageBlock.widgetSetID) == "number" and stageBlock.widgetSetID > 0 then
        if not wc or (wc.IsShown == nil or wc:IsShown()) then
            hasWidget = true
        end
    end

    if not hasWidget then
        return nil, false, nil, false
    end

    local fallbackH = (self.db and self.db.scenarioStageWidgetHeight) or 83
    local measuredHeight = 0
    local measuredWidth = 0
    local sbTop = stageBlock.GetTop and stageBlock:GetTop()

    local lowestBottom = nil
    local hasFrameTexture = false

    if wc and wc.widgetFrames then
        for _, wf in pairs(wc.widgetFrames) do
            if wf and (wf.IsShown == nil or wf:IsShown()) then
                -- Check if this is a complex header widget with a frame texture (Visions / Delves)
                if wf.Frame and wf.Frame.GetHeight then
                    hasFrameTexture = true
                    local fh = wf.Frame:GetHeight() or 0
                    if fh > measuredHeight then measuredHeight = fh end
                end
                if wf.Frame and wf.Frame.GetWidth then
                    local fw = wf.Frame:GetWidth() or 0
                    if fw > measuredWidth then measuredWidth = fw end
                elseif wf.GetWidth then
                    local w = wf:GetWidth() or 0
                    if w > measuredWidth then measuredWidth = w end
                end

                local b = (wf.Text and wf.Text.IsShown and wf.Text:IsShown() and wf.Text.GetBottom and wf.Text:GetBottom())
                    or (wf.GetBottom and wf:GetBottom())
                if b and type(b) == "number" and (not lowestBottom or b < lowestBottom) then
                    lowestBottom = b
                end

                if wf.CurrencyContainer and wf.CurrencyContainer.IsShown and wf.CurrencyContainer:IsShown() and wf.CurrencyContainer.GetBottom then
                    local cb = wf.CurrencyContainer:GetBottom()
                    if cb and type(cb) == "number" and (not lowestBottom or cb < lowestBottom) then
                        lowestBottom = cb
                    end
                end
            end
        end
    end

    if not lowestBottom and wc and wc.GetBottom then
        lowestBottom = wc:GetBottom()
    end

    if sbTop and lowestBottom and type(sbTop) == "number" and type(lowestBottom) == "number" and sbTop > lowestBottom then
        local screenExt = math.floor(sbTop - lowestBottom + 0.5)
        if hasFrameTexture then
            screenExt = screenExt + 4
        end
        if screenExt > measuredHeight then
            measuredHeight = screenExt
        end
    end

    local finalH = (measuredHeight and measuredHeight >= 12) and measuredHeight or fallbackH
    local finalW = (measuredWidth and measuredWidth > 0) and measuredWidth or nil
    return finalH, true, finalW, hasFrameTexture
end

function ObjectivesMod:AlignWidgetContainer(wc, parentBlock, topOffsetY)
    if not wc or not parentBlock then return end
    if not self:IsAwakeningTheMachine() then return end

    -- Pure visual styling only: avoid ClearAllPoints or SetWidth on WidgetContainer
    -- which triggers OnSizeChanged -> MarkDirty in tainted execution context.
    local otf = _G.ObjectiveTrackerFrame
    local trackerWidth = (otf and otf.GetWidth and otf:GetWidth()) or 220
    if trackerWidth < 50 then trackerWidth = 220 end

    local function FitWidgets()
        if not wc.widgetFrames then return end
        local maxW = trackerWidth - 4
        local prev = nil
        for _, widgetFrame in pairs(wc.widgetFrames) do
            local isComplexHeader = widgetFrame and (widgetFrame.HeaderText or widgetFrame.CurrencyContainer or widgetFrame.Frame)
            local isBarWidget = widgetFrame and (widgetFrame.Bar or widgetFrame.StatusBar)
            local isTextOnly = self.IsTextOnlyWidget and self:IsTextOnlyWidget(widgetFrame)

            if not isComplexHeader and not isBarWidget then
                if widgetFrame and widgetFrame.GetWidth then
                    local w = widgetFrame:GetWidth()
                    if w and w > maxW and maxW > 50 then
                        local scale = math.min(1, maxW / w)
                        widgetFrame:SetScale(scale)
                    else
                        widgetFrame:SetScale(1)
                    end
                end
                if widgetFrame and widgetFrame.ClearAllPoints and widgetFrame.SetPoint then
                    widgetFrame:ClearAllPoints()
                    if not prev then
                        widgetFrame:SetPoint("TOPLEFT", wc, "TOPLEFT", 0, 0)
                    else
                        widgetFrame:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
                    end
                    prev = widgetFrame
                end
            end

            -- Apply fonts and flush text alignment ONLY to text-only widgets!
            if isTextOnly and self.SkinTextWidget then
                self:SkinTextWidget(widgetFrame)
            end
        end
    end

    FitWidgets()
end

function ObjectivesMod:AlignEventTracker(tracker)
    if not tracker then return end
    local otf = _G.ObjectiveTrackerFrame
    local targetWidth = (otf and otf.GetWidth and otf:GetWidth())
    if targetWidth and targetWidth > 50 then
        if tracker.SetWidth and math.abs((tracker.GetWidth and tracker:GetWidth() or 0) - targetWidth) > 1 then
            tracker:SetWidth(targetWidth)
        end
        if tracker.Header and tracker.Header.SetWidth and math.abs((tracker.Header.GetWidth and tracker.Header:GetWidth() or 0) - targetWidth) > 1 then
            tracker.Header:SetWidth(targetWidth)
        end
        if tracker.Block and tracker.Block.SetWidth then
            tracker.Block:SetWidth(math.max(100, targetWidth - 8))
        end
    end

    if tracker.Block then
        if _G.ObjectiveTrackerUIWidgetContainer and self:IsAwakeningTheMachine() then
            self:AlignWidgetContainer(_G.ObjectiveTrackerUIWidgetContainer, tracker.Block, 0)
        end
    end
    if tracker.Header and not self.settingHeaderPoint then
        self.settingHeaderPoint = true
        tracker.Header:ClearAllPoints()
        tracker.Header:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, 0)
        self.settingHeaderPoint = nil
    end
end


function ObjectivesMod:TrimScenarioTrailingGap(sot, lastLine)
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    if not sot or not sot.SetHeight or not sot.GetTop then return end
    if not (sot.IsShown and sot:IsShown()) then return end

    local isDelve = false
    if _G.C_Scenario and _G.C_Scenario.GetInfo then
        local _, _, _, _, _, _, _, _, _, scenarioType = _G.C_Scenario.GetInfo()
        if scenarioType == "delves-scenario" then
            isDelve = true
        end
    end
    if not isDelve and _G.C_ScenarioInfo and _G.C_ScenarioInfo.IsTieredEntranceScenario and _G.C_ScenarioInfo.IsTieredEntranceScenario() then
        isDelve = true
    end

    if not self:IsAwakeningTheMachine() and not isDelve then return end

    local lowest = nil
    if lastLine and lastLine.GetBottom and (lastLine.IsShown == nil or lastLine:IsShown()) then
        lowest = lastLine:GetBottom()
        local bar = lastLine.progressBar
        if bar and bar.IsShown and bar:IsShown() and bar.GetBottom then
            local b = bar:GetBottom()
            if b and lowest and b < lowest then lowest = b end
        end
    end

    local ob = sot.ObjectivesBlock
    if ob and ob.usedLines then
        for _, line in pairs(ob.usedLines) do
            if line and (line.IsShown == nil or line:IsShown()) and line.GetBottom then
                local b = line:GetBottom()
                if b and (not lowest or b < lowest) then lowest = b end
            end
        end
    end
    if ob and ob.usedProgressBars then
        for _, bar in pairs(ob.usedProgressBars) do
            if bar and (bar.IsShown == nil or bar:IsShown()) and bar.GetBottom then
                local b = bar:GetBottom()
                if b and (not lowest or b < lowest) then lowest = b end
            end
        end
    end
    if sot.usedProgressBars then
        for _, bar in pairs(sot.usedProgressBars) do
            if bar and (bar.IsShown == nil or bar:IsShown()) and bar.GetBottom then
                local b = bar:GetBottom()
                if b and (not lowest or b < lowest) then lowest = b end
            end
        end
    end

    if not lowest and sot.StageBlock and sot.StageBlock.IsShown and sot.StageBlock:IsShown() and sot.StageBlock.GetBottom then
        lowest = sot.StageBlock:GetBottom()
    end

    if not lowest and sot.Header and sot.Header.IsShown and sot.Header:IsShown() and sot.Header.GetBottom then
        lowest = sot.Header:GetBottom()
    end

    local top = sot:GetTop()
    if type(top) == "number" and type(lowest) == "number" and top > lowest then
        local bottomPad = -4
        local desired = math.floor(top - lowest + bottomPad + 0.5)
        local current = (sot.GetHeight and sot:GetHeight()) or 0
        if desired > 0 and math.abs(desired - current) > 0.5 then
            sot:SetHeight(desired)
        end
    end
end

function ObjectivesMod:AlignScenarioElements()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    if _G.C_ChallengeMode and _G.C_ChallengeMode.IsChallengeModeActive and _G.C_ChallengeMode.IsChallengeModeActive() then return end
    local sot = _G.ScenarioObjectiveTracker
    if not sot or not self.db or not self.db.enabled then return end
    if self.isAligningScenario then return end
    self.isAligningScenario = true

    if sot.EndLayout and not self.hookedScenarioEndLayout then
        self.hookedScenarioEndLayout = true
        _G.hooksecurefunc(sot, "EndLayout", function()
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                self:AlignScenarioElements()
            end
        end)
    end

    if sot.Header then
        self:SkinHeader(sot.Header)
    end

    local sb = sot.StageBlock
    local widgetH, hasWidget, widgetW, hasFrameTexture = nil, false, nil, false
    if sb and self.GetStageBlockWidgetHeight then
        widgetH, hasWidget, widgetW, hasFrameTexture = self:GetStageBlockWidgetHeight(sb)
    end
    local cmBlock = sot.ChallengeModeBlock
    local pgBlock = sot.ProvingGroundsBlock
    local hasDungeonHeader = (cmBlock and cmBlock.IsShown and cmBlock:IsShown())
        or (pgBlock and pgBlock.IsShown and pgBlock:IsShown())

    local isDelve = false
    if _G.C_Scenario and _G.C_Scenario.GetInfo then
        local _, _, _, _, _, _, _, _, _, scenarioType = _G.C_Scenario.GetInfo()
        if scenarioType == "delves-scenario" then
            isDelve = true
        end
    end
    if not isDelve and _G.C_ScenarioInfo and _G.C_ScenarioInfo.IsTieredEntranceScenario and _G.C_ScenarioInfo.IsTieredEntranceScenario() then
        isDelve = true
    end
    if not isDelve and hasFrameTexture then
        isDelve = true
    end

    local hasToast = not hasWidget and not isDelve and sb and sb.IsShown and sb:IsShown() and (
        (sb.NormalBG and sb.NormalBG.IsShown and sb.NormalBG:IsShown() and (sb.NormalBG:GetAlpha() or 1) > 0.1)
        or (sb.FinalBG and sb.FinalBG.IsShown and sb.FinalBG:IsShown() and (sb.FinalBG:GetAlpha() or 1) > 0.1)
    )

    local isTextOnly = (hasWidget and not hasFrameTexture and not isDelve) or (not hasWidget and not isDelve and not hasToast and not hasDungeonHeader)
    local isDelveWidget = (isDelve or (hasWidget and hasFrameTexture)) and not hasDungeonHeader

    -- Complete Non-Interference: If a standard scenario toast or dungeon header is present, NEVER touch, move, or style it!
    if hasToast or hasDungeonHeader then
        self.isAligningScenario = nil
        return
    end

    if sb and sb.IsShown and sb:IsShown() and not hasDungeonHeader then
        self:SkinStageBlock(sb)

        local otf = _G.ObjectiveTrackerFrame
        local trackerWidth = (otf and otf.GetWidth and otf:GetWidth()) or (self.db and self.db.detachedWidth) or 235
        if trackerWidth < 100 then trackerWidth = 235 end

        local stageW = (isDelveWidget and (widgetW or 253)) or (isTextOnly and trackerWidth) or ((hasWidget and (widgetW or 253)) or 218)
        local xOffset
        if isDelveWidget then
            local delveXOff = (self.db and self.db.delveWidgetXOffset) or 0
            xOffset = math.floor((trackerWidth - stageW) / 2 + 0.5) + delveXOff
        else
            local stageXOff = (self.db and self.db.scenarioStageXOffset) or 0
            local textOnlyX = 4
            xOffset = textOnlyX + stageXOff
        end
        local desiredH = isTextOnly and 16 or (isDelveWidget and (widgetH or 64)) or (hasWidget and (widgetH or ((self.db and self.db.scenarioStageWidgetHeight) or 83)) or 63)
        local yOffset = -10

        local relTo = sot.Header and sot.Header:IsShown() and sot.Header or (sot.ContentsFrame or sot)
        local relPt = (relTo == (sot.ContentsFrame or sot)) and "TOPLEFT" or "BOTTOMLEFT"

        local isSbPositioned = false
        if sb.GetPoint then
            local p, rel, rp, x, y = sb:GetPoint(1)
            if p == "TOPLEFT" and rel == relTo and rp == relPt and math.abs((x or 0) - xOffset) < 0.5 and math.abs((y or 0) - yOffset) < 0.5 then
                isSbPositioned = true
            end
        end

        if not isSbPositioned and sb.ClearAllPoints and sb.SetPoint then
            sb:ClearAllPoints()
            sb:SetPoint("TOPLEFT", relTo, relPt, xOffset, yOffset)
        end
        if sb.SetWidth and math.abs(((sb.GetWidth and sb:GetWidth()) or 0) - stageW) > 0.5 then
            sb:SetWidth(stageW)
        end
        if sb.SetHeight and math.abs(((sb.GetHeight and sb:GetHeight()) or 0) - desiredH) > 0.5 then
            sb:SetHeight(desiredH)
        end

        if hasWidget and sb.WidgetContainer and self:IsAwakeningTheMachine() then
            self:AlignWidgetContainer(sb.WidgetContainer, sb, 0)
        end
    end

    local lastLine = nil
    local SCENARIO_LINE_INSET = 12
    local ob = sot.ObjectivesBlock
    if ob then
        local relTo = (sb and sb:IsShown() and sb)
            or (sot.Header and sot.Header:IsShown() and sot.Header)
            or (sot.ContentsFrame or sot)
        local relPt = (relTo == (sot.ContentsFrame or sot)) and "TOPLEFT" or "BOTTOMLEFT"
        local isUnderStageBlock = (relTo == sb)
        local stageBottomOffsetY = isUnderStageBlock and -4 or -2
        local parentFrame = sot.ContentsFrame or sot

        local isObPositioned = false
        if ob.GetPoint then
            local p, rel, rp, _, y = ob:GetPoint(1)
            if p == "TOP" and rel == relTo and rp == relPt and math.abs((y or 0) - stageBottomOffsetY) < 0.5 then
                isObPositioned = true
            end
        end

        if not isObPositioned and ob.ClearAllPoints and ob.SetPoint then
            ob:ClearAllPoints()
            ob:SetPoint("RIGHT", parentFrame, "RIGHT", -4, 0)
            ob:SetPoint("LEFT", parentFrame, "LEFT", SCENARIO_LINE_INSET, 0)
            ob:SetPoint("TOP", relTo, relPt, 0, stageBottomOffsetY)
        end

        local forEach = self.ForEachBlockLine or objState.ForEachBlockLine
        if forEach and self:IsAwakeningTheMachine() then
            forEach(ob, function(line)
                if line and self.SkinScenarioLine then
                    self:SkinScenarioLine(line)
                end
            end)
        end

        if self:IsAwakeningTheMachine() and ob.usedLines then
            local keys = {}
            for key, line in pairs(ob.usedLines) do
                if type(key) == "number" and line and line.SetPoint then
                    keys[#keys + 1] = key
                end
            end
            table.sort(keys)
            local prev
            for _, key in ipairs(keys) do
                local line = ob.usedLines[key]
                line:ClearAllPoints()
                line:SetPoint("RIGHT", ob, "RIGHT", 0, 0)
                if prev then
                    local anchor = prev
                    local bar = prev.progressBar
                    if bar and bar.IsShown and bar:IsShown() then anchor = bar end
                    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -SCENARIO_LINE_SPACING)
                else
                    line:SetPoint("TOPLEFT", ob, "TOPLEFT", 0, 0)
                end
                prev = line
            end
            lastLine = prev
        elseif ob.usedLines then
            local maxKey = 0
            for key in pairs(ob.usedLines) do
                if type(key) == "number" and key > maxKey then maxKey = key end
            end
            lastLine = ob.usedLines[maxKey]
        end

        if ob.usedProgressBars and self:IsAwakeningTheMachine() then
            for _, bar in pairs(ob.usedProgressBars) do
                self:SkinProgressBar(bar)
            end
        end
    end

    if sot.usedProgressBars and self:IsAwakeningTheMachine() then
        for _, bar in pairs(sot.usedProgressBars) do
            self:SkinProgressBar(bar)
        end
    end

    self:TrimScenarioTrailingGap(sot, lastLine)
    self.isAligningScenario = nil
end
