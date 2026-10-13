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

    -- Pure visual styling only: avoid ClearAllPoints or SetWidth on WidgetContainer
    -- which triggers OnSizeChanged -> MarkDirty in tainted execution context.
    local otf = _G.ObjectiveTrackerFrame
    local trackerWidth = (otf and otf.GetWidth and otf:GetWidth()) or 220
    if trackerWidth < 50 then trackerWidth = 220 end

    local font = self:GetFontPath()
    local tSize = self.db.titleFontSize or 12
    local outline = self.db.fontOutline or "OUTLINE"
    local tc = self.db.titleColor or self.defaultSettings.titleColor

    local function SkinFS(fs)
        if fs and fs.SetFont then
            pcall(fs.SetFont, fs, font, tSize, outline)
            fs:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
            if fs.SetShadowOffset then fs:SetShadowOffset(0, 0) end
        end
    end

    local function FitWidgets()
        if not wc.widgetFrames then return end
        local maxW = trackerWidth - 4
        local prev = nil
        for _, widgetFrame in pairs(wc.widgetFrames) do
            local isComplexHeader = widgetFrame and (widgetFrame.HeaderText or widgetFrame.CurrencyContainer or widgetFrame.Frame)
            if not isComplexHeader then
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

            -- Skin typography and flush text alignment
            if widgetFrame then
                if isComplexHeader and widgetFrame.HeaderText then
                    SkinFS(widgetFrame.HeaderText)
                else
                    local hasIcon = widgetFrame.Icon and widgetFrame.Icon.IsShown and widgetFrame.Icon:IsShown() and (widgetFrame.Icon:GetTexture() or widgetFrame.Icon:GetAtlas())
                    if widgetFrame.Text then
                        SkinFS(widgetFrame.Text)
                        if widgetFrame.Text.ClearAllPoints and widgetFrame.Text.SetPoint then
                            widgetFrame.Text:ClearAllPoints()
                            if hasIcon then
                                widgetFrame.Text:SetPoint("LEFT", widgetFrame.Icon, "RIGHT", 4, 0)
                            else
                                widgetFrame.Text:SetPoint("TOPLEFT", widgetFrame, "TOPLEFT", 0, 0)
                            end
                        end
                        local th = widgetFrame.Text.GetStringHeight and widgetFrame.Text:GetStringHeight()
                        if th and th > 0 then
                            widgetFrame:SetHeight(th)
                        end
                    end
                end
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
        if _G.ObjectiveTrackerUIWidgetContainer then
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

function ObjectivesMod:SkinStageBlock(stageBlock)
    if not stageBlock then return end
    local font = self:GetFontPath()
    local hSize = self.db.headerFontSize or 13
    local tSize = self.db.titleFontSize or 12
    local outline = self.db.fontOutline or "OUTLINE"
    local tc = self.db.titleColor or self.defaultSettings.titleColor

    local hasToast = stageBlock.NormalBG and stageBlock.NormalBG:IsShown() and (stageBlock.NormalBG:GetAlpha() or 1) > 0.1
    if stageBlock.Stage and stageBlock.Stage.SetFont then
        pcall(stageBlock.Stage.SetFont, stageBlock.Stage, font, hSize, outline)
        stageBlock.Stage:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
        if stageBlock.Stage.SetShadowOffset then
            stageBlock.Stage:SetShadowOffset(0, 0)
        end
        if not hasToast and stageBlock.Stage.ClearAllPoints and stageBlock.Stage.SetPoint then
            stageBlock.Stage:ClearAllPoints()
            stageBlock.Stage:SetPoint("TOPLEFT", stageBlock, "TOPLEFT", 0, 0)
        end
    end
    if stageBlock.Name and stageBlock.Name.SetFont then
        pcall(stageBlock.Name.SetFont, stageBlock.Name, font, tSize, outline)
        stageBlock.Name:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
        if stageBlock.Name.SetShadowOffset then
            stageBlock.Name:SetShadowOffset(0, 0)
        end
    end

    local _, hasWidget = self:GetStageBlockWidgetHeight(stageBlock)
    if hasWidget then
        if stageBlock.NormalBG and stageBlock.NormalBG.SetAlpha then stageBlock.NormalBG:SetAlpha(0) end
        if stageBlock.FinalBG and stageBlock.FinalBG.SetAlpha then stageBlock.FinalBG:SetAlpha(0) end
        if stageBlock.GlowTexture and stageBlock.GlowTexture.SetAlpha then stageBlock.GlowTexture:SetAlpha(0) end
        if stageBlock.ThemeOverlay and stageBlock.ThemeOverlay.SetAlpha then stageBlock.ThemeOverlay:SetAlpha(0) end
    else
        if stageBlock.NormalBG and stageBlock.NormalBG.SetAlpha then stageBlock.NormalBG:SetAlpha(1) end
        if stageBlock.FinalBG and stageBlock.FinalBG.SetAlpha then stageBlock.FinalBG:SetAlpha(1) end
        if stageBlock.ThemeOverlay and stageBlock.ThemeOverlay.SetAlpha then stageBlock.ThemeOverlay:SetAlpha(1) end
    end
end

function ObjectivesMod:TrimScenarioTrailingGap(sot, lastLine)
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    if not sot or not sot.SetHeight or not sot.GetTop then return end
    if not (sot.IsShown and sot:IsShown()) then return end

    local lowest = nil
    if lastLine and lastLine.GetBottom and (lastLine.IsShown == nil or lastLine:IsShown()) then
        lowest = lastLine:GetBottom()
        local bar = lastLine.progressBar
        if bar and bar.IsShown and bar:IsShown() and bar.GetBottom then
            local b = bar:GetBottom()
            if b and lowest and b < lowest then lowest = b end
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
        local bottomPad = 4
        local desired = math.floor(top - lowest + bottomPad + 0.5)
        local current = (sot.GetHeight and sot:GetHeight()) or 0
        if desired > 0 and math.abs(desired - current) > 0.5 then
            sot:SetHeight(desired)
        end
    end
end

function ObjectivesMod:AlignScenarioElements()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
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

    if sot.StageBlock then
        self:SkinStageBlock(sot.StageBlock)
        local sb = sot.StageBlock
        local widgetH, hasWidget, widgetW, hasFrameTexture = self:GetStageBlockWidgetHeight(sb)
        local customH = (self.db and self.db.scenarioStageHeight) or 63
        local hasToast = sb.NormalBG and sb.NormalBG:IsShown() and (sb.NormalBG:GetAlpha() or 1) > 0.1
        local isTextOnly = (hasWidget and not hasFrameTexture) or (not hasWidget and not hasToast)

        local otf = _G.ObjectiveTrackerFrame
        local trackerWidth = (otf and otf.GetWidth and otf:GetWidth()) or (self.db and self.db.detachedWidth) or 235
        if trackerWidth < 100 then trackerWidth = 235 end

        local stageW = isTextOnly and trackerWidth or ((hasWidget and (widgetW or 253)) or 218)
        local stageXOff = (self.db and self.db.scenarioStageXOffset) or 0
        local dungeonBaseX = (not isTextOnly and not hasWidget) and -16 or 0
        local xOffset = isTextOnly and stageXOff or (math.floor((trackerWidth - stageW) / 2) + dungeonBaseX + stageXOff)

        local desiredH = isTextOnly and 16 or (hasWidget and (widgetH or ((self.db and self.db.scenarioStageWidgetHeight) or 83)) or customH)
        local yOffset = -6

        if sb.ClearAllPoints and sb.SetPoint then
            sb:ClearAllPoints()
            local relTo = sot.Header and sot.Header:IsShown() and sot.Header or (sot.ContentsFrame or sot)
            local relPt = (relTo == (sot.ContentsFrame or sot)) and "TOPLEFT" or "BOTTOMLEFT"
            sb:SetPoint("TOPLEFT", relTo, relPt, xOffset, yOffset)
        end
        if sb.SetWidth then
            sb:SetWidth(stageW)
        end
        sb:SetHeight(desiredH)

        if hasWidget and sb.WidgetContainer then
            self:AlignWidgetContainer(sb.WidgetContainer, sb, 0)
        end

        if sb.HookScript and not self.hookedStageBlockOnShow then
            self.hookedStageBlockOnShow = true
            sb:HookScript("OnShow", function()
                if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                    self:AlignScenarioElements()
                end
            end)
        end
    end

    local cmBlock = sot.ChallengeModeBlock
    if cmBlock then
        if cmBlock.ClearAllPoints and cmBlock.SetPoint and cmBlock.GetPoint and cmBlock:GetNumPoints() > 0 then
            local _, relativeTo, relativePoint = cmBlock:GetPoint(1)
            if relativeTo then
                cmBlock:ClearAllPoints()
                local relPt = (relativePoint == "TOP" or relativePoint == "TOPRIGHT" or relativePoint == "TOPLEFT") and "TOPRIGHT" or "BOTTOMRIGHT"
                cmBlock:SetPoint("TOPRIGHT", relativeTo, relPt, -4, -6)
                if cmBlock.SetWidth then cmBlock:SetWidth(251) end
            end
        end
        local font = self:GetFontPath()
        local tSize = self.db.titleFontSize or 12
        local outline = self.db.fontOutline or "OUTLINE"
        local tc = self.db.titleColor or self.defaultSettings.titleColor
        local textChildren = { "Level", "TimeLeft", "TimeLost" }
        for _, key in ipairs(textChildren) do
            local fs = cmBlock[key]
            if fs and fs.SetFont then
                pcall(fs.SetFont, fs, font, tSize, outline)
                if fs.SetTextColor then
                    fs:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
                end
                if fs.SetShadowOffset then fs:SetShadowOffset(0, 0) end
            end
        end
    end

    local pgBlock = sot.ProvingGroundsBlock
    if pgBlock then
        if pgBlock.ClearAllPoints and pgBlock.SetPoint and pgBlock.GetPoint and pgBlock:GetNumPoints() > 0 then
            local _, relativeTo, relativePoint = pgBlock:GetPoint(1)
            if relativeTo then
                pgBlock:ClearAllPoints()
                local relPt = (relativePoint == "TOP" or relativePoint == "TOPRIGHT" or relativePoint == "TOPLEFT") and "TOPRIGHT" or "BOTTOMRIGHT"
                pgBlock:SetPoint("TOPRIGHT", relativeTo, relPt, -4, -6)
                if pgBlock.SetWidth then pgBlock:SetWidth(251) end
            end
        end
    end

    local lastLine = nil
    local SCENARIO_LINE_INSET = 12
    local ob = sot.ObjectivesBlock
    if ob then
        if ob.ClearAllPoints and ob.SetPoint then
            local relTo = (sot.StageBlock and sot.StageBlock:IsShown() and sot.StageBlock)
                or (sot.Header and sot.Header:IsShown() and sot.Header)
                or (sot.ContentsFrame or sot)
            local relPt = (relTo == (sot.ContentsFrame or sot)) and "TOPLEFT" or "BOTTOMLEFT"
            local isUnderStageBlock = (relTo == sot.StageBlock)
            local stageBottomOffsetY = isUnderStageBlock and -16 or -4
            ob:ClearAllPoints()
            ob:SetPoint("RIGHT", sot.ContentsFrame or sot, "RIGHT", -4, 0)
            ob:SetPoint("TOPLEFT", relTo, relPt, SCENARIO_LINE_INSET, stageBottomOffsetY)
        end

        local font = self:GetFontPath()
        local objSize = self.db.objectiveFontSize or 11
        local outline = self.db.fontOutline or "OUTLINE"
        local oc = self.db.objectiveColor or self.defaultSettings.objectiveColor

        local forEach = self.ForEachBlockLine or objState.ForEachBlockLine
        if forEach then
            forEach(ob, function(line)
            if line then
                if line.Dash then
                    if line.Dash.SetText then line.Dash:SetText("") end
                    if line.Dash.SetAlpha then line.Dash:SetAlpha(0) end
                    if line.Dash.Hide then line.Dash:Hide() end
                end
                if line.Icon then
                    if line.Icon.SetAlpha then line.Icon:SetAlpha(0) end
                    if line.Icon.Hide then line.Icon:Hide() end
                end
                if line.CheckGlow then
                    if line.CheckGlow.SetAlpha then line.CheckGlow:SetAlpha(0) end
                    if line.CheckGlow.Hide then line.CheckGlow:Hide() end
                end
                if line.Check then
                    if line.Check.SetAlpha then line.Check:SetAlpha(0) end
                    if line.Check.Hide then line.Check:Hide() end
                end

                if line.Text then
                    if line.Text.ClearAllPoints and line.Text.SetPoint then
                        line.Text:ClearAllPoints()
                        line.Text:SetPoint("RIGHT", line, "RIGHT", 0, 0)
                        line.Text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
                    end

                    if line.Text.SetFont then
                        pcall(line.Text.SetFont, line.Text, font, objSize, outline)
                    end
                    if line.Text.SetShadowOffset then
                        line.Text:SetShadowOffset(0, 0)
                    end

                    local txt = line.Text.GetText and line.Text:GetText()
                    local isComp = false
                    if line.state and _G.ObjectiveTrackerAnimLineState and line.state == _G.ObjectiveTrackerAnimLineState.Completing then
                        isComp = true
                    elseif line.color and _G.OBJECTIVE_TRACKER_COLOR and line.color == _G.OBJECTIVE_TRACKER_COLOR["Complete"] then
                        isComp = true
                    elseif line.Icon and line.Icon.GetAtlas and line.Icon:GetAtlas() == "ui-questtracker-tracker-check" then
                        isComp = true
                    elseif txt and (txt:find("^1/1") or (txt:find("^(%d+)/(%d+)") and not txt:find("^0/"))) then
                        local cur, total = txt:match("^(%d+)/(%d+)")
                        if cur and total and tonumber(cur) >= tonumber(total) and tonumber(total) > 0 then
                            isComp = true
                        end
                    end

                    if isComp then
                        line.Text:SetTextColor(0.35, 0.88, 0.45, 1.0)
                    else
                        line.Text:SetTextColor(oc.r or 0.92, oc.g or 0.92, oc.b or 0.92, 1.0)
                    end

                    local lh = line.Text.GetStringHeight and line.Text:GetStringHeight()
                    if lh and lh > 0 then
                        line:SetHeight(lh)
                    end
                end
            end
        end)
        end

        if ob.usedLines then
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
        end
        if ob.usedProgressBars then
            for _, bar in pairs(ob.usedProgressBars) do
                self:SkinProgressBar(bar)
            end
        end
    end

    if sot.usedProgressBars then
        for _, bar in pairs(sot.usedProgressBars) do
            self:SkinProgressBar(bar)
        end
    end

    self:TrimScenarioTrailingGap(sot, lastLine)
    self.isAligningScenario = nil
end
