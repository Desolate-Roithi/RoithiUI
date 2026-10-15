local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:GetModule("Objectives")
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

local objState = ns.Objectives or {}
ns.Objectives = objState

local skinnedBlocks = objState.skinnedBlocks
local skinnedBars = objState.skinnedBars
local headerDividers = objState.headerDividers
local titleFSCache = objState.titleFSCache
local SUB_TRACKERS = objState.SUB_TRACKERS
local hoverHookedBlocks = objState.hoverHookedBlocks or setmetatable({}, { __mode = "k" })
objState.hoverHookedBlocks = hoverHookedBlocks
local barBackdrops = objState.barBackdrops or setmetatable({}, { __mode = "k" })
objState.barBackdrops = barBackdrops

local function NormalizeFontFlags(outline)
    if not outline or outline == "NONE" or outline == "" then
        return ""
    end
    return outline
end

local function ApplyFontStringShadow(fs, showShadow)
    if not fs then return end
    if fs.SetShadowOffset then
        if showShadow then
            fs:SetShadowOffset(1, -1)
        else
            fs:SetShadowOffset(0, 0)
        end
    end
    if fs.SetShadowColor then
        if showShadow then
            fs:SetShadowColor(0, 0, 0, 1)
        else
            fs:SetShadowColor(0, 0, 0, 0)
        end
    end
end

function ObjectivesMod:GetFontPath(fontKey)
    LSM = LSM or (LibStub and LibStub("LibSharedMedia-3.0", true))
    local f = (fontKey and self.db and self.db[fontKey])
        or (self.db and self.db.font)
        or (RoithiUI and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.font)
        or "Expressway"
    if LSM and LSM.Fetch and LSM:Fetch("font", f, true) then
        return LSM:Fetch("font", f)
    end
    if LSM and LSM.Fetch and LSM:Fetch("font", "Expressway", true) then
        return LSM:Fetch("font", "Expressway")
    end
    if f and f ~= "Expressway" and not f:find("\\") then
        return f
    end
    return "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf"
end

function ObjectivesMod:GetFontOutline(tierKey)
    local val = (tierKey and self.db and self.db[tierKey])
    if not val or val == "" then
        val = (self.db and self.db.fontOutline) or "OUTLINE"
    end
    return NormalizeFontFlags(val)
end

function ObjectivesMod:GetFontShadow(tierKey)
    if tierKey and self.db and self.db[tierKey] ~= nil then
        return self.db[tierKey] == true
    end
    return (self.db and self.db.showFontShadow) == true
end

function ObjectivesMod:SkinHeader(header)
    if not header then return end

    local otf = _G.ObjectiveTrackerFrame
    local parent = header:GetParent()
    local targetWidth = (otf and otf.GetWidth and otf:GetWidth())
    if not targetWidth or targetWidth < 50 then
        targetWidth = (parent and parent.GetWidth and parent:GetWidth()) or 235
    end
    if targetWidth and targetWidth > 50 then
        if header.SetWidth then header:SetWidth(targetWidth) end
        local parentFrame = header:GetParent()
        if parentFrame and parentFrame ~= otf and parentFrame.SetWidth then
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                parentFrame:SetWidth(targetWidth)
            end
        end
    end

    local mb = header.MinimizeButton
    if mb then
        -- Anti-taint: Preserve Blizzard's native Anchor to <Anchor point="RIGHT" x="-1"/>.
        -- Never call ClearAllPoints() on Blizzard's MinimizeButton to prevent poisoning OnClick.
        -- Reposition only if not already right-anchored (e.g. headless unit tests with mock CENTER default point).
        local hasRightAnchor = false
        if mb.GetNumPoints and mb:GetNumPoints() > 0 and mb.GetPoint then
            local pt, rel, relPt = mb:GetPoint(1)
            if (pt == "RIGHT" or relPt == "RIGHT") and (rel == header or not rel) then
                hasRightAnchor = true
            end
        end
        if not hasRightAnchor and mb.ClearAllPoints and mb.SetPoint then
            mb:ClearAllPoints()
            mb:SetPoint("RIGHT", header, "RIGHT", -4, 0)
        end
        if mb.Show then mb:Show() end

        local hc = self.db.headerColor or self.defaultSettings.headerColor
        local r, g, b = (hc and hc.r) or 0.05, (hc and hc.g) or 0.82, (hc and hc.b) or 0.61
        local function tint(tex)
            if not tex then return end
            if tex.SetDesaturated then tex:SetDesaturated(true) end
            if tex.SetVertexColor then tex:SetVertexColor(r, g, b) end
        end
        tint(mb.GetNormalTexture and mb:GetNormalTexture())
        tint(mb.GetPushedTexture and mb:GetPushedTexture())
        tint(mb.GetHighlightTexture and mb:GetHighlightTexture())
        tint(mb.GetDisabledTexture and mb:GetDisabledTexture())
        if mb.GetRegions then
            for _, rg in ipairs({ mb:GetRegions() }) do
                if rg and ((rg.GetObjectType and rg:GetObjectType() == "Texture") or (rg.IsObjectType and rg:IsObjectType("Texture"))) then
                    tint(rg)
                end
            end
        end
    end

    -- Build keep table for MinimizeButton textures so StripTextures does not blank them
    local keep = {}
    if mb then
        keep[mb] = true
        if mb.GetNormalTexture and mb:GetNormalTexture() then keep[mb:GetNormalTexture()] = true end
        if mb.GetPushedTexture and mb:GetPushedTexture() then keep[mb:GetPushedTexture()] = true end
        if mb.GetHighlightTexture and mb:GetHighlightTexture() then keep[mb:GetHighlightTexture()] = true end
        if mb.GetDisabledTexture and mb:GetDisabledTexture() then keep[mb:GetDisabledTexture()] = true end
        if mb.GetRegions then
            for _, reg in ipairs({ mb:GetRegions() }) do
                keep[reg] = true
            end
        end
    end
    if headerDividers[header] then
        keep[headerDividers[header]] = true
    end

    -- Strip decorative textures via SetTexture("") ONLY (anti-taint pattern from EllesmereUI)
    local decorNames = { "Background", "Line", "LineSheen", "LineGlow", "Divider", "Sheen", "Glow", "Stripe" }
    for _, k in ipairs(decorNames) do
        local tex = header[k]
        if tex and not keep[tex] and tex.SetTexture then
            tex:SetTexture("")
        end
    end

    -- Sweep top-level texture regions
    if header.GetRegions then
        for _, region in ipairs({ header:GetRegions() }) do
            if region and ((region.GetObjectType and region:GetObjectType() == "Texture") or (region.IsObjectType and region:IsObjectType("Texture"))) then
                if not keep[region] and region.SetTexture then
                    region:SetTexture("")
                end
            end
        end
    end

    -- Style FontString
    local text = header.Text or header.Title or header.Label or header.HeaderText
    if not text and header.GetRegions then
        for _, region in ipairs({ header:GetRegions() }) do
            if region and ((region.GetObjectType and region:GetObjectType() == "FontString") or (region.IsObjectType and region:IsObjectType("FontString"))) then
                text = region
                break
            end
        end
    end
    if text then
        local font = self:GetFontPath("headerFont")
        local size = self.db.headerFontSize or 13
        local outline = self:GetFontOutline("headerFontOutline")
        pcall(text.SetFont, text, font, size, outline)

        local hc = self.db.headerColor or self.defaultSettings.headerColor
        text:SetTextColor(hc.r or 0.05, hc.g or 0.82, hc.b or 0.61, 1.0)
        ApplyFontStringShadow(text, self:GetFontShadow("headerFontShadow"))

        text:ClearAllPoints()
        text:SetPoint("LEFT", header, "LEFT", 4, 0)
        text:SetPoint("RIGHT", header, "RIGHT", -20, 0)
    end

    self:EnsureAccentDivider(header)
end

function ObjectivesMod:UpdateAllDividers()
    for _, divider in pairs(headerDividers) do
        if divider then
            if not self.db.enabled or not self.db.showAccentDivider then
                divider:Hide()
            else
                divider:SetShown(true)
            end
        end
    end
end

function ObjectivesMod:GetAccentDivider(header)
    return header and headerDividers[header]
end

function ObjectivesMod:EnsureAccentDivider(header)
    if not header or not self.db.showAccentDivider then
        if headerDividers[header] then
            headerDividers[header]:Hide()
        end
        return
    end

    local divider = headerDividers[header]
    if not divider then
        divider = header:CreateTexture(nil, "OVERLAY")
        headerDividers[header] = divider
    end

    local otf = _G.ObjectiveTrackerFrame
    local parent = header:GetParent()
    local targetWidth = (otf and otf.GetWidth and otf:GetWidth())
    if not targetWidth or targetWidth < 50 then
        targetWidth = (parent and parent.GetWidth and parent:GetWidth()) or 235
    end

    if targetWidth and targetWidth > 50 then
        divider:ClearAllPoints()
        divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -2)
        divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMLEFT", targetWidth, -2)
    else
        divider:ClearAllPoints()
        divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -2)
        divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, -2)
    end

    local thickness = self.db.dividerThickness or 1
    divider:SetHeight(thickness)

    local hc = self.db.headerColor or self.defaultSettings.headerColor
    divider:SetColorTexture(hc.r or 0.05, hc.g or 0.82, hc.b or 0.61, 0.8)
    divider:SetShown(true)
end

function ObjectivesMod:ApplyMasterHeaderVisibility()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end

    local hide = self.db.hideMasterHeader == true
    if otf.Header then
        if hide then
            otf.Header:Hide()
            if otf.Header.SetAlpha then otf.Header:SetAlpha(0) end
        else
            otf.Header:Show()
            if otf.Header.SetAlpha then otf.Header:SetAlpha(1) end
        end
    end
    if otf.HeaderMenu then
        if hide then
            otf.HeaderMenu:Hide()
            if otf.HeaderMenu.SetAlpha then otf.HeaderMenu:SetAlpha(0) end
        else
            otf.HeaderMenu:Show()
            if otf.HeaderMenu.SetAlpha then otf.HeaderMenu:SetAlpha(1) end
        end
    end
end

local function HookOrSetScript(frame, script, handler)
    if not frame then return end
    if frame.HasScript and not frame:HasScript(script) then return end
    if frame.GetScript and frame:GetScript(script) then
        pcall(frame.HookScript, frame, script, handler)
    elseif frame.SetScript then
        pcall(frame.SetScript, frame, script, handler)
    end
end

local origHeaderClick = setmetatable({}, { __mode = "k" })

local lastClickTime = 0
local lastClickBlock = nil
local function HandleBlockClick(block, mouseButton)
    if not block then return end
    local now = (_G.GetTime and _G.GetTime()) or 0
    if block == lastClickBlock and (now - lastClickTime) < 0.2 then
        return
    end
    if _G.IsControlKeyDown and _G.IsControlKeyDown() then
        lastClickTime = now
        lastClickBlock = block
        if ObjectivesMod.TogglePinQuest then
            ObjectivesMod:TogglePinQuest(block)
        end
    elseif (_G.IsAltKeyDown and _G.IsAltKeyDown()) or mouseButton == "MiddleButton" then
        lastClickTime = now
        lastClickBlock = block
        if ObjectivesMod.ToggleSuperTrackQuest then
            ObjectivesMod:ToggleSuperTrackQuest(block)
        end
    end
end

local function OnHeaderButtonClicked(btn, mouseButton, down)
    local block = btn:GetParent()
    if not block then return end

    local isCtrl = _G.IsControlKeyDown and _G.IsControlKeyDown()
    local isAlt = _G.IsAltKeyDown and _G.IsAltKeyDown()

    if isCtrl or isAlt or mouseButton == "MiddleButton" then
        HandleBlockClick(block, mouseButton)
        return
    end

    local orig = origHeaderClick[btn]
    if orig then
        orig(btn, mouseButton, down)
    elseif _G.ObjectiveTrackerBlockHeaderMixin and _G.ObjectiveTrackerBlockHeaderMixin.OnClick then
        _G.ObjectiveTrackerBlockHeaderMixin.OnClick(btn, mouseButton, down)
    elseif block.OnHeaderClick then
        block:OnHeaderClick(mouseButton)
    end
end

function ObjectivesMod:ApplyQuestIconVisibility(block)
    if not block then return end
    if self.db and self.db.hideQuestIcon then
        if block.poiButton then
            block.poiButton:Hide()
            if block.poiButton.SetAlpha then block.poiButton:SetAlpha(0) end
        end
    end
end

function ObjectivesMod:SkinBlock(block)
    if not block or type(block) ~= "table" then return end
    if not (block.IsObjectType or block.GetObjectType or block.SetPoint) then return end
    if skinnedBlocks[block] then return end
    skinnedBlocks[block] = true

    local font = self:GetFontPath("titleFont")
    local tSize = self.db.titleFontSize or 12
    local outline = self:GetFontOutline("titleFontOutline")
    local tc = self.db.titleColor or self.defaultSettings.titleColor
    local titleShadow = self:GetFontShadow("titleFontShadow")

    local titleFS = self.GetBlockTitleFS and self:GetBlockTitleFS(block)
    if titleFS then
        titleFSCache[block] = titleFS
        if titleFS.SetFont then
            pcall(titleFS.SetFont, titleFS, font, tSize, outline)
        end
        if titleFS.SetTextColor then
            titleFS:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
        end
        ApplyFontStringShadow(titleFS, titleShadow)
        if self.ApplyQuestLevelToTitle then
            self:ApplyQuestLevelToTitle(block)
        end
    end

    local offsetX = (self.db and self.db.blockOffsetX) or 4
    if block.SetPoint then
        local parent = (block.GetParent and block:GetParent())
        if parent then
            block:SetPoint("LEFT", parent, "LEFT", offsetX, 0)
        else
            block:SetPoint("LEFT", offsetX, 0)
        end
    end

    self:ApplyQuestIconVisibility(block)
    if block.AddPOIButton and not self:IsHooked(block, "AddPOIButton") then
        self:SecureHook(block, "AddPOIButton", function(b)
            self:ApplyQuestIconVisibility(b)
        end)
    end

    if block.lines then
        for _, line in pairs(block.lines) do
            self:StyleObjectiveLine(line)
        end
    end
    if block.usedLines then
        for _, line in pairs(block.usedLines) do
            self:StyleObjectiveLine(line)
        end
    end

    if block.AddProgressBar and not self:IsHooked(block, "AddProgressBar") then
        self:SecureHook(block, "AddProgressBar", function(b)
            local bar = b and b.lastRegion
            if bar then
                self:SkinProgressBar(bar)
            end
        end)
    end

    if block.UpdateHighlight and not self:IsHooked(block, "UpdateHighlight") then
        self:SecureHook(block, "UpdateHighlight", function(b)
            local oc = self.db.objectiveColor or (self.defaultSettings and self.defaultSettings.objectiveColor) or { r = 1, g = 1, b = 1 }
            local lines = b.usedLines or b.lines
            if lines then
                for _, line in pairs(lines) do
                    if line.Text and line.Text.SetTextColor then
                        line.Text:SetTextColor(oc.r or 1.0, oc.g or 1.0, oc.b or 1.0, 1.0)
                    end
                    if line.Dash and line.Dash.SetTextColor then
                        line.Dash:SetTextColor(oc.r or 1.0, oc.g or 1.0, oc.b or 1.0, 1.0)
                    end
                end
            end
        end)
    end

    if not hoverHookedBlocks[block] then
        hoverHookedBlocks[block] = true
        if block.EnableMouse then block:EnableMouse(true) end
        if block.HookScript then
            block:HookScript("OnEnter", function(b)
                if self.HandleBlockEnter then
                    self:HandleBlockEnter(b)
                elseif self.UpdateBlockHoverObjectives then
                    self:UpdateBlockHoverObjectives(b, true)
                end
            end)
            block:HookScript("OnLeave", function(b)
                if self.HandleBlockLeave then
                    self:HandleBlockLeave(b)
                elseif self.UpdateBlockHoverObjectives then
                    self:UpdateBlockHoverObjectives(b, false)
                end
            end)
        end
        HookOrSetScript(block, "OnMouseDown", function(b, btn)
            if btn == "MiddleButton" or (_G.IsAltKeyDown and _G.IsAltKeyDown()) or (_G.IsControlKeyDown and _G.IsControlKeyDown()) then
                HandleBlockClick(b, btn)
            end
        end)
        if block.HeaderButton then
            if block.HeaderButton.HookScript then
                block.HeaderButton:HookScript("OnEnter", function()
                    if self.HandleBlockEnter then
                        self:HandleBlockEnter(block)
                    elseif self.UpdateBlockHoverObjectives then
                        self:UpdateBlockHoverObjectives(block, true)
                    end
                end)
                block.HeaderButton:HookScript("OnLeave", function()
                    if self.HandleBlockLeave then
                        self:HandleBlockLeave(block)
                    elseif self.UpdateBlockHoverObjectives then
                        self:UpdateBlockHoverObjectives(block, false)
                    end
                end)
            end
            if not origHeaderClick[block.HeaderButton] then
                local orig = block.HeaderButton.GetScript and block.HeaderButton:GetScript("OnClick")
                if orig and orig ~= OnHeaderButtonClicked then
                    origHeaderClick[block.HeaderButton] = orig
                end
            end
            if block.HeaderButton.SetScript then
                block.HeaderButton:SetScript("OnClick", OnHeaderButtonClicked)
            end
            HookOrSetScript(block.HeaderButton, "OnMouseDown", function(_, btn)
                if btn == "MiddleButton" then
                    HandleBlockClick(block, btn)
                end
            end)
        end
    end

    local itemBtn = block.itemButton or block.ItemButton or (block.GetItemButton and block:GetItemButton())
    if itemBtn then
        if itemBtn.SetFrameLevel and block.GetFrameLevel then
            itemBtn:SetFrameLevel(block:GetFrameLevel() + 20)
        end
        if itemBtn.EnableMouse then itemBtn:EnableMouse(true) end
        if itemBtn.HookScript then
            itemBtn:HookScript("OnEnter", function()
                if self.HandleBlockEnter then
                    self:HandleBlockEnter(block)
                elseif self.UpdateBlockHoverObjectives then
                    self:UpdateBlockHoverObjectives(block, true)
                end
            end)
            itemBtn:HookScript("OnLeave", function()
                if self.HandleBlockLeave then
                    self:HandleBlockLeave(block)
                elseif self.UpdateBlockHoverObjectives then
                    self:UpdateBlockHoverObjectives(block, false)
                end
            end)
        end
    end

    if self.UpdateBlockHoverObjectives then
        local isHovered = self.IsMouseOverBlock and self:IsMouseOverBlock(block)
        self:UpdateBlockHoverObjectives(block, isHovered or false)
    end
end

function ObjectivesMod:StyleObjectiveLine(line)
    if not line then return end
    local font = self:GetFontPath("objectiveFont")
    local objSize = self.db.objectiveFontSize or 11
    local outline = self:GetFontOutline("objectiveFontOutline")
    local oc = self.db.objectiveColor or self.defaultSettings.objectiveColor
    local useShadow = self:GetFontShadow("objectiveFontShadow")

    if line.Dash and line.Dash.SetFont then
        pcall(line.Dash.SetFont, line.Dash, font, objSize, outline)
        line.Dash:SetTextColor(oc.r or 1.0, oc.g or 1.0, oc.b or 1.0, 1.0)
        ApplyFontStringShadow(line.Dash, useShadow)
    end

    if line.Text and line.Text.SetFont then
        pcall(line.Text.SetFont, line.Text, font, objSize, outline)
        line.Text:SetTextColor(oc.r or 1.0, oc.g or 1.0, oc.b or 1.0, 1.0)
        ApplyFontStringShadow(line.Text, useShadow)
    end

    if line.progressBar then
        self:SkinProgressBar(line.progressBar)
    end
end

function ObjectivesMod:SkinProgressBar(bar)
    if not bar or skinnedBars[bar] then return end
    if not self.db.skinProgressBars then return end
    skinnedBars[bar] = true

    local barTex = LibRoithi:GetStatusBarTexture(self.db.progressBarTexture)
    local height = self.db.progressBarHeight or 8

    local sb = bar.Bar or bar
    if bar.Bar and bar.Bar ~= bar and bar.Bar.ClearAllPoints and bar.Bar.SetPoint then
        bar.Bar:ClearAllPoints()
        bar.Bar:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        bar.Bar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    end

    if sb and sb.SetStatusBarTexture then
        sb:SetStatusBarTexture(barTex)
        if sb.SetHeight then sb:SetHeight(height) end
    end

    if bar.SetHeight then bar:SetHeight(height) end

    local bg = barBackdrops[bar]
    if not bg then
        bg = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
        bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
        bg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        bg:SetBackdropColor(0.08, 0.08, 0.10, 0.8)
        bg:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)
        bg:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
        barBackdrops[bar] = bg
    end
    if bg then
        local isShown = bar.IsShown and bar:IsShown()
        bg:SetShown(isShown)
        bg:SetAlpha((bar.GetAlpha and bar:GetAlpha()) or 1)
    end

    if sb and sb.GetRegions then
        local activeBarTex = sb.GetStatusBarTexture and sb:GetStatusBarTexture()
        for regionIdx, region in ipairs({ sb:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") and region ~= activeBarTex then
                if region.SetAlpha then
                    region:SetAlpha(0)
                end
            end
        end
    end

    local decorNames = { "Border", "BorderLeft", "BorderRight", "BorderMid", "BarFrame", "BarFrame2", "BarFrame3", "BarBG", "IconBG", "Sheen" }
    for decorIdx, k in ipairs(decorNames) do
        local tex = bar[k] or (sb and sb[k])
        if tex and tex.SetAlpha then
            tex:SetAlpha(0)
        end
    end

    local label = (sb and sb.Label) or bar.Label
    if label and label.SetFont then
        local outline = self:GetFontOutline("objectiveFontOutline")
        pcall(label.SetFont, label, self:GetFontPath("objectiveFont"), self.db.objectiveFontSize or 10, outline)
        ApplyFontStringShadow(label, self:GetFontShadow("objectiveFontShadow"))
        if label.SetDrawLayer then
            label:SetDrawLayer("OVERLAY", 7)
        end
    end
end

function ObjectivesMod:SkinExistingBlocks(tracker)
    if not tracker then return end
    local isShared = objState.SharesWidgetPool and objState.SharesWidgetPool(tracker)
    if isShared then return end

    local forEachBlock = objState.ForEachTrackerBlock or self.ForEachTrackerBlock
    if forEachBlock then
        forEachBlock(tracker, function(block)
            if not skinnedBlocks[block] then
                self:SkinBlock(block)
            end
        end)
    end

    if tracker.usedProgressBars then
        for _, bar in pairs(tracker.usedProgressBars) do
            self:SkinProgressBar(bar)
        end
    end
end

function ObjectivesMod:SkinAllExisting()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not self.db or not self.db.enabled then return end

    if otf.Header then
        self:SkinHeader(otf.Header)
    end
    if otf.HeaderMenu then
        self:SkinHeader(otf.HeaderMenu)
    end

    local sot = _G.ScenarioObjectiveTracker
    if sot then
        if sot.Header then
            self:SkinHeader(sot.Header)
        end
        if sot.StageBlock and self.SkinStageBlock then
            self:SkinStageBlock(sot.StageBlock)
        end
        if self.AlignScenarioElements then
            self:AlignScenarioElements()
        end
    end

    if otf.ForEachModule then
        otf:ForEachModule(function(module)
            if module then
                if module.Header then
                    self:SkinHeader(module.Header)
                end
                if not (objState.SharesWidgetPool and objState.SharesWidgetPool(module)) then
                    self:SkinExistingBlocks(module)
                end
            end
        end)
    elseif otf.modules then
        for _, module in ipairs(otf.modules) do
            if module then
                if module.Header then
                    self:SkinHeader(module.Header)
                end
                if not (objState.SharesWidgetPool and objState.SharesWidgetPool(module)) then
                    self:SkinExistingBlocks(module)
                end
            end
        end
    end

    local titleFont = self:GetFontPath("titleFont")
    local objFont = self:GetFontPath("objectiveFont")
    local titleSize = self.db.titleFontSize or 12
    local objSize = self.db.objectiveFontSize or 11
    local titleOutline = self:GetFontOutline("titleFontOutline")
    local objOutline = self:GetFontOutline("objectiveFontOutline")
    local tc = self.db.titleColor or (self.defaultSettings and self.defaultSettings.titleColor) or { r = 1, g = 0.85, b = 0.35 }
    local oc = self.db.objectiveColor or (self.defaultSettings and self.defaultSettings.objectiveColor) or { r = 1, g = 1, b = 1 }
    local titleShadow = self:GetFontShadow("titleFontShadow")
    local objShadow = self:GetFontShadow("objectiveFontShadow")
    local offsetX = (self.db and self.db.blockOffsetX) or 4

    for block in pairs(skinnedBlocks) do
        if type(block) == "table" then
            if block.SetPoint then
                local parent = (block.GetParent and block:GetParent())
                if parent then
                    block:SetPoint("LEFT", parent, "LEFT", offsetX, 0)
                else
                    block:SetPoint("LEFT", offsetX, 0)
                end
            end
            local titleFS = (self.GetBlockTitleFS and self:GetBlockTitleFS(block)) or titleFSCache[block]
            if titleFS and titleFS.SetFont then
                pcall(titleFS.SetFont, titleFS, titleFont, titleSize, titleOutline)
                if titleFS.SetTextColor then
                    titleFS:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
                end
                ApplyFontStringShadow(titleFS, titleShadow)
            end

            if self.ForEachBlockLine then
                self:ForEachBlockLine(block, function(line)
                    if line.Text and line.Text.SetFont then
                        pcall(line.Text.SetFont, line.Text, objFont, objSize, objOutline)
                        if line.Text.SetTextColor then
                            line.Text:SetTextColor(oc.r or 0.8, oc.g or 0.8, oc.b or 0.8, 1.0)
                        end
                        ApplyFontStringShadow(line.Text, objShadow)
                    end
                    if line.Dash and line.Dash.SetFont then
                        pcall(line.Dash.SetFont, line.Dash, objFont, objSize, objOutline)
                        if line.Dash.SetTextColor then
                            line.Dash:SetTextColor(oc.r or 0.8, oc.g or 0.8, oc.b or 0.8, 1.0)
                        end
                        ApplyFontStringShadow(line.Dash, objShadow)
                    end
                end)
            end

            if self.ApplyQuestLevelToTitle then
                self:ApplyQuestLevelToTitle(block)
            end
            if self.ApplyQuestIconVisibility then
                self:ApplyQuestIconVisibility(block)
            end
            if (block.usedLines or block.lines or block.HeaderText) and self.UpdateBlockHoverObjectives then
                local isHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
                self:UpdateBlockHoverObjectives(block, isHovered or false)
            end
        end
    end
end

function ObjectivesMod:UpdateFonts()
    if not self.db or not self.db.enabled then return end
    local hFont = self:GetFontPath("headerFont")
    local tFont = self:GetFontPath("titleFont")
    local oFont = self:GetFontPath("objectiveFont")
    local hSize = self.db.headerFontSize or 13
    local tSize = self.db.titleFontSize or 12
    local objSize = self.db.objectiveFontSize or 11
    local hOutline = self:GetFontOutline("headerFontOutline")
    local tOutline = self:GetFontOutline("titleFontOutline")
    local oOutline = self:GetFontOutline("objectiveFontOutline")
    local hShadow = self:GetFontShadow("headerFontShadow")
    local tShadow = self:GetFontShadow("titleFontShadow")
    local oShadow = self:GetFontShadow("objectiveFontShadow")

    if _G.ObjectiveTrackerHeaderFont and _G.ObjectiveTrackerHeaderFont.SetFont then
        pcall(_G.ObjectiveTrackerHeaderFont.SetFont, _G.ObjectiveTrackerHeaderFont, hFont, hSize, hOutline)
        ApplyFontStringShadow(_G.ObjectiveTrackerHeaderFont, hShadow)
    end
    if _G.ObjectiveTrackerLineFont and _G.ObjectiveTrackerLineFont.SetFont then
        pcall(_G.ObjectiveTrackerLineFont.SetFont, _G.ObjectiveTrackerLineFont, oFont, objSize, oOutline)
        ApplyFontStringShadow(_G.ObjectiveTrackerLineFont, oShadow)
    end

    local otf = _G.ObjectiveTrackerFrame
    if otf then
        local mh = otf.Header or otf.HeaderMenu
        if mh and mh.Text and mh.Text.SetFont then
            pcall(mh.Text.SetFont, mh.Text, hFont, hSize, hOutline)
            ApplyFontStringShadow(mh.Text, hShadow)
        end
    end

    for _, trackerName in ipairs(SUB_TRACKERS) do
        local tracker = _G[trackerName]
        if tracker and tracker.Header and tracker.Header.Text and tracker.Header.Text.SetFont then
            pcall(tracker.Header.Text.SetFont, tracker.Header.Text, hFont, hSize, hOutline)
            ApplyFontStringShadow(tracker.Header.Text, hShadow)
        end
    end

    local sot = _G.ScenarioObjectiveTracker
    if sot then
        if sot.Header and sot.Header.Text and sot.Header.Text.SetFont then
            pcall(sot.Header.Text.SetFont, sot.Header.Text, hFont, hSize, hOutline)
            ApplyFontStringShadow(sot.Header.Text, hShadow)
        end
        if sot.StageBlock and self.SkinStageBlock then
            self:SkinStageBlock(sot.StageBlock)
        end
    end

    local offsetX = (self.db and self.db.blockOffsetX) or 4
    for block in pairs(skinnedBlocks) do
        if block.SetPoint then
            local parent = (block.GetParent and block:GetParent())
            if parent then
                block:SetPoint("LEFT", parent, "LEFT", offsetX, 0)
            else
                block:SetPoint("LEFT", offsetX, 0)
            end
        end
        local titleFS = titleFSCache[block] or (self.GetBlockTitleFS and self:GetBlockTitleFS(block))
        if titleFS and titleFS.SetFont then
            pcall(titleFS.SetFont, titleFS, tFont, tSize, tOutline)
            ApplyFontStringShadow(titleFS, tShadow)
            if self.ApplyQuestLevelToTitle then
                self:ApplyQuestLevelToTitle(block)
            end
        end

        local formatLine = function(line)
            if line then
                if line.Dash and line.Dash.SetFont then
                    pcall(line.Dash.SetFont, line.Dash, oFont, objSize, oOutline)
                    ApplyFontStringShadow(line.Dash, oShadow)
                end
                if line.Text and line.Text.SetFont then
                    pcall(line.Text.SetFont, line.Text, oFont, objSize, oOutline)
                    ApplyFontStringShadow(line.Text, oShadow)
                end
            end
        end

        if self.ForEachBlockLine then
            self:ForEachBlockLine(block, formatLine)
        elseif block.usedLines then
            for _, line in pairs(block.usedLines) do formatLine(line) end
        end
    end

    self:UpdateAllDividers()
end

function ObjectivesMod:IsAwakeningTheMachine()
    if not _G.C_Scenario or not _G.C_Scenario.GetInfo then
        return true
    end
    local name = _G.C_Scenario.GetInfo()
    if name and name:find("Awakening the Machine") then
        return true
    end
    local sot = _G.ScenarioObjectiveTracker
    local sb = sot and sot.StageBlock
    local stageText = sb and sb.Name and sb.Name.GetText and sb.Name:GetText()
    if stageText and stageText:find("Awakening the Machine") then
        return true
    end
    local headerText = sot and sot.Header and sot.Header.Text and sot.Header.Text.GetText and sot.Header.Text:GetText()
    if headerText and headerText:find("Awakening the Machine") then
        return true
    end
    return false
end

function ObjectivesMod:SkinStageBlock(stageBlock)
    if not stageBlock then return end
    if not self:IsAwakeningTheMachine() then return end
    local hasToast = (stageBlock.NormalBG and stageBlock.NormalBG.IsShown and stageBlock.NormalBG:IsShown() and (stageBlock.NormalBG:GetAlpha() or 1) > 0.1)
        or (stageBlock.FinalBG and stageBlock.FinalBG.IsShown and stageBlock.FinalBG:IsShown() and (stageBlock.FinalBG:GetAlpha() or 1) > 0.1)
    local hasWidget, hasFrameTexture = false, false
    if self.GetStageBlockWidgetHeight then
        local _, hw, _, hft = self:GetStageBlockWidgetHeight(stageBlock)
        hasWidget = hw and true or false
        hasFrameTexture = hft and true or false
    end
    if hasToast or hasFrameTexture then
        return
    end

    local hFont = self:GetFontPath("headerFont")
    local tFont = self:GetFontPath("titleFont")
    local hSize = self.db.headerFontSize or 13
    local tSize = self.db.titleFontSize or 12
    local hOutline = self:GetFontOutline("headerFontOutline")
    local tOutline = self:GetFontOutline("titleFontOutline")
    local tc = self.db.titleColor or self.defaultSettings.titleColor
    local hShadow = self:GetFontShadow("headerFontShadow")
    local tShadow = self:GetFontShadow("titleFontShadow")
    if stageBlock.Stage and stageBlock.Stage.SetFont then
        pcall(stageBlock.Stage.SetFont, stageBlock.Stage, hFont, hSize, hOutline)
        stageBlock.Stage:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
        ApplyFontStringShadow(stageBlock.Stage, hShadow)
        if not hasToast and stageBlock.Stage.ClearAllPoints and stageBlock.Stage.SetPoint then
            stageBlock.Stage:ClearAllPoints()
            stageBlock.Stage:SetPoint("TOPLEFT", stageBlock, "TOPLEFT", 0, 0)
        end
    end
    if stageBlock.Name and stageBlock.Name.SetFont then
        pcall(stageBlock.Name.SetFont, stageBlock.Name, tFont, tSize, tOutline)
        stageBlock.Name:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
        ApplyFontStringShadow(stageBlock.Name, tShadow)
    end

    if not hasWidget and self.GetStageBlockWidgetHeight then
        local _, hw = self:GetStageBlockWidgetHeight(stageBlock)
        hasWidget = hw and true or false
    end
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

function ObjectivesMod:SkinChallengeModeBlock(cmBlock)
    if not cmBlock then return end
    local font = self:GetFontPath("titleFont")
    local tSize = self.db.titleFontSize or 12
    local outline = self:GetFontOutline("titleFontOutline")
    local tc = self.db.titleColor or self.defaultSettings.titleColor
    local useShadow = self:GetFontShadow("titleFontShadow")
    local textChildren = { "Level", "TimeLeft", "TimeLost" }
    for _, key in ipairs(textChildren) do
        local fs = cmBlock[key]
        if fs and fs.SetFont then
            pcall(fs.SetFont, fs, font, tSize, outline)
            if fs.SetTextColor then
                fs:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
            end
            ApplyFontStringShadow(fs, useShadow)
        end
    end
end

function ObjectivesMod:SkinScenarioLine(line)
    if not line or line.progressBar then return end
    if not self:IsAwakeningTheMachine() then return end
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

        local font = self:GetFontPath("objectiveFont")
        local objSize = self.db.objectiveFontSize or 11
        local outline = self:GetFontOutline("objectiveFontOutline")
        local oc = self.db.objectiveColor or self.defaultSettings.objectiveColor
        local useShadow = self:GetFontShadow("objectiveFontShadow")

        if line.Text.SetFont then
            pcall(line.Text.SetFont, line.Text, font, objSize, outline)
        end
        ApplyFontStringShadow(line.Text, useShadow)

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

        if line.Text.SetTextColor then
            if isComp then
                line.Text:SetTextColor(0.35, 0.88, 0.45, 1.0)
            else
                line.Text:SetTextColor(oc.r or 0.92, oc.g or 0.92, oc.b or 0.92, 1.0)
            end
        end

        local lh = line.Text.GetStringHeight and line.Text:GetStringHeight()
        if lh and lh > 0 then
            line:SetHeight(lh)
        end
    end
end

function ObjectivesMod:IsTextOnlyWidget(wf)
    if not wf then return false end
    if wf.Bar or wf.StatusBar or wf.Frame or wf.CurrencyContainer or wf.Spell or wf.Item or wf.Progress or wf.CaptureBar then
        return false
    end
    local wType = wf.widgetType
    local visEnum = _G.Enum and _G.Enum.UIWidgetVisualizationType
    if visEnum then
        if wType == visEnum.StatusBar or wType == visEnum.CaptureBar or wType == visEnum.ScenarioHeaderCurrenciesAndBackground
            or wType == visEnum.ScenarioHeaderDelves or wType == visEnum.ScenarioHeaderTimer or wType == visEnum.HorizontalCurrencies then
            return false
        end
        if wType == visEnum.TextWithState or wType == visEnum.TextWithSubtext then
            return true
        end
        if wType ~= nil then
            return false
        end
    end
    return (wf.Text ~= nil) and not wf.Bar and not wf.StatusBar and not wf.Frame and not wf.CurrencyContainer and not wf.Icon
end

function ObjectivesMod:SkinTextWidget(wf)
    if not self:IsTextOnlyWidget(wf) then return end
    if not self:IsAwakeningTheMachine() then return end
    local font = self:GetFontPath("titleFont")
    local tSize = self.db.titleFontSize or 12
    local outline = self:GetFontOutline("titleFontOutline")
    local tc = self.db.titleColor or self.defaultSettings.titleColor
    local useShadow = self:GetFontShadow("titleFontShadow")

    local function SkinFS(fs)
        if fs and fs.SetFont then
            pcall(fs.SetFont, fs, font, tSize, outline)
            if fs.SetTextColor then
                fs:SetTextColor(tc.r or 1.0, tc.g or 0.85, tc.b or 0.35, 1.0)
            end
            ApplyFontStringShadow(fs, useShadow)
        end
    end

    if wf.Text then
        SkinFS(wf.Text)
        if wf.Text.ClearAllPoints and wf.Text.SetPoint then
            wf.Text:ClearAllPoints()
            wf.Text:SetPoint("TOPLEFT", wf, "TOPLEFT", 0, 0)
        end
        local th = wf.Text.GetStringHeight and wf.Text:GetStringHeight()
        if th and th > 0 then
            wf:SetHeight(th)
        end
    end
    if wf.SubText then
        SkinFS(wf.SubText)
    end
end

