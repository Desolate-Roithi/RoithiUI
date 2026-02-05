local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

-- Config Logic
-- ============================================================================
-- THE DASHBOARD WINDOW
-- This file controls the "RoithiUI Dashboard" floating window.
-- It is the MASTER CONTROLLER for enabling/disabling frames.
-- ============================================================================
local Config = RoithiUI.Config or {}
RoithiUI.Config = Config

function Config:CreateDashboard()
    if self.dashboard then return end

    -- Main Container
    local f = CreateFrame("Frame", "RoithiUIDashboard", UIParent, "BackdropTemplate")
    f:SetSize(220, 300) -- Initial size
    f:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", 2, 0)

    LibRoithi.mixins:CreateBackdrop(f)

    -- State
    f.isExpanded = true
    f.sections = {}

    -- Header / Toggle Button
    local header = CreateFrame("Button", nil, f)
    header:SetPoint("TOPLEFT", 5, -5)
    header:SetPoint("TOPRIGHT", -5, -5)
    header:SetHeight(30)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    title:SetText("RoithiUI Dashboard")

    -- Main Expand/Collapse Arrow
    local function CreateArrow(parent)
        local arrow = parent:CreateTexture(nil, "ARTWORK")
        arrow:SetAtlas("Options-List-Expand-Up")
        arrow:SetSize(14, 14)
        return arrow
    end

    local arrow = CreateArrow(header)
    arrow:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    f.menuArrow = arrow

    -- Content Container
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 0, -35)
    content:SetPoint("BOTTOMRIGHT", 0, 30) -- Leave room for bottom button
    f.content = content

    -- Layout Updater
    local function UpdateLayout()
        local currentY = -10
        for _, section in ipairs(f.sections) do
            section.header:ClearAllPoints()
            section.header:SetPoint("TOPLEFT", content, "TOPLEFT", 5, currentY)
            section.header:SetPoint("TOPRIGHT", content, "TOPRIGHT", -5, currentY)

            currentY = currentY - 25 -- Header height + padding

            if section.isExpanded then
                section.content:Show()
                section.content:ClearAllPoints()
                section.content:SetPoint("TOPLEFT", content, "TOPLEFT", 0, currentY)
                section.content:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, currentY)

                currentY = currentY - section.contentHeight
                section.indicator:SetAtlas("Options-List-Expand-Up")
            else
                section.content:Hide()
                section.indicator:SetAtlas("Options-List-Expand-Down")
            end

            currentY = currentY - 5 -- Spacing between sections
        end

        local totalHeight = math.abs(currentY) + 70 -- Top header + Bottom button padding
        if f.isExpanded then
            f:SetHeight(totalHeight)
        else
            f:SetHeight(40)
        end
    end

    -- Section Generator
    local function CreateSection(titleText, height)
        local section = {
            isExpanded = false,
            contentHeight = height
        }

        -- Section Header
        local sHeader = CreateFrame("Button", nil, content, "BackdropTemplate")
        sHeader:SetHeight(20)
        LibRoithi.mixins:CreateBackdrop(sHeader)
        sHeader:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        sHeader:SetBackdropBorderColor(0, 0, 0, 0) -- No border

        local sTitle = sHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sTitle:SetPoint("LEFT", 10, 0)
        sTitle:SetText(titleText)

        local sArrow = CreateArrow(sHeader)
        sArrow:SetAtlas("Options-List-Expand-Down")
        sArrow:SetSize(10, 10)
        sArrow:SetPoint("RIGHT", -10, 0)
        section.indicator = sArrow

        sHeader:SetScript("OnClick", function()
            section.isExpanded = not section.isExpanded
            UpdateLayout()
        end)
        section.header = sHeader

        -- Section Content
        local sContent = CreateFrame("Frame", nil, content)
        sContent:SetHeight(height)
        section.content = sContent
        sContent:Hide()

        table.insert(f.sections, section)
        return sContent
    end

    -- Helpers for Edit Mode States
    local function SetEditModeState(frame, enabled)
        if not frame then return end
        if enabled then
            frame.isInEditMode = true
            frame:SetAlpha(1)
            frame:Show()

            -- If user has oUF frames (like Boss/UnitFrames), they need more persuasion
            -- We assume LibEditMode usually handles this via callbacks,
            -- but the dashboard is a manual trigger.
            -- Check if frame has an EditModeOverlay (UnitFrames)
            if frame.EditModeOverlay then frame.EditModeOverlay:Show() end

            -- Force Layout Updates
            if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end

            -- Prevent oUF from hiding it immediately via RegisterUnitWatch?
            -- We can set a temporary override flag if needed, like 'forceShowEditMode'
            frame.forceShowEditMode = true

            -- Fix: Disable UnitWatch for oUF frames
            if frame.unit or frame.style then
                UnregisterUnitWatch(frame)
            end
        else
            frame.isInEditMode = false
            if frame.EditModeOverlay then frame.EditModeOverlay:Hide() end
            frame.forceShowEditMode = nil

            -- Let normal visibility rules take over
            -- We hide it explicitly first to ensure 'Edit Mode State' is cleared visually
            frame:Hide()

            -- FIX: Only restore UnitWatch if the frame is actually enabled in settings
            local isEnabled = true
            if frame.unit and RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[frame.unit] then
                isEnabled = RoithiUI.db.profile.UnitFrames[frame.unit].enabled ~= false
            end

            -- Also check Boss Frames if applicable (simplified check)

            if isEnabled then
                -- If unit exists, RegisterUnitWatch usually shows it again on next update?
                -- Or we can trigger an update.
                if frame.unit or frame.style then
                    RegisterUnitWatch(frame)
                end

                if frame.unit and UnitExists(frame.unit) then
                    frame:Show()
                end
            else
                -- Ensure it stays dead
                if frame.unit or frame.style then
                    UnregisterUnitWatch(frame)
                end
                frame:Hide()
            end
        end
    end

    local function SetCastbarEditModeState(bar, enabled)
        if not bar then return end
        if enabled then
            bar.isInEditMode = true
            bar:Show()
            -- Fake Data for Visibility
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            local c = { 1, 0.95, 0, 1 } -- Default Cast Color
            if RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[bar.unit] then
                c = RoithiUI.db.profile.Castbar[bar.unit].colors.cast
            end
            bar:SetStatusBarColor(c[1], c[2], c[3], 1)
            if bar.Text then bar.Text:SetText(string.upper(bar.unit or "CASTBAR")) end
            if bar.Icon then
                bar.Icon:SetTexture(136243); bar.Icon:Show()
            end
            if bar.Spark then bar.Spark:Show() end
        else
            bar.isInEditMode = false
            bar:Hide()
        end
    end

    -- Checkbox Helper

    local function CreateCheck(parent, text, dbTable, key, xOffset, yOffset, frameObj, customToggleFunc)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", xOffset, yOffset)
        cb:SetSize(20, 20)
        cb.text:SetFontObject("GameFontHighlightSmall")
        cb.text:SetText(text)

        cb:SetScript("OnShow", function(self)
            if dbTable then self:SetChecked(dbTable[key]) end
        end)

        cb:SetScript("OnClick", function(self)
            local enabled = self:GetChecked()
            if dbTable then dbTable[key] = enabled end

            if customToggleFunc then
                customToggleFunc(enabled)
            elseif frameObj then
                -- Auto-detect type
                if frameObj.StageTicks or frameObj.Spark then -- Is Castbar?
                    SetCastbarEditModeState(frameObj, enabled)
                else
                    SetEditModeState(frameObj, enabled)
                end
            end

            if ns.UpdateBlizzardVisibility then ns.UpdateBlizzardVisibility() end
            if ns.UpdateCast and frameObj then ns.UpdateCast(frameObj) end

            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        return cb
    end

    -- 1. General Section (Hidden by user request & Direction moved out)
    -- local generalContent = CreateSection("General", 35)
    local ufModule = RoithiUI:GetModule("UnitFrames") --[[@as UF]]

    -- Combined Utility Frames
    -- Combined Utility Frames (DISABLED & HIDDEN per user request)
    -- CreateCheck(generalContent, "Utility Frames", nil, nil, 15, -5, nil, ...)

    -- Direction Indicators (Moved to RoithiQoL)
    -- local directionModule = RoithiUI:GetModule("Direction")
    -- CreateCheck(generalContent, "Direction Indicators", RoithiUI.db.profile.Direction, "enabled", 15, -5, nil,
    --     function(enabled)
    --         if directionModule then directionModule:Toggle(enabled) end
    --         local left = _G["RoithiDirectionLeft"]
    --         local right = _G["RoithiDirectionRight"]
    --         SetEditModeState(left, enabled)
    --         SetEditModeState(right, enabled)
    --     end)

    -- 2. Unit Sections
    local units = {
        { "Player",       "player" },
        { "Target",       "target" },
        { "ToT",          "targettarget" },
        { "Focus",        "focus" },
        { "Focus Target", "focustarget" },
        { "Pet",          "pet" },
    }

    for _, u in ipairs(units) do
        local label, unit = u[1], u[2]
        local unitContent = CreateSection(label, 35) -- Reduced height for single row

        -- Fix: Use .units instead of .frames
        local ufFrame = ufModule and ufModule.units and ufModule.units[unit]

        -- UnitFrame Check
        if ufFrame then
            if not RoithiUI.db.profile.UnitFrames then RoithiUI.db.profile.UnitFrames = {} end
            if not RoithiUI.db.profile.UnitFrames[unit] then RoithiUI.db.profile.UnitFrames[unit] = { enabled = true } end

            CreateCheck(unitContent, "Frame", RoithiUI.db.profile.UnitFrames[unit], "enabled", 15, -5, ufFrame,
                function(enabled)
                    if ufModule then ufModule:ToggleFrame(unit, enabled) end
                    -- Force Visuals
                    SetEditModeState(ufFrame, enabled)
                end)
        end

        -- Castbar Check
        if ns.bars and ns.bars[unit] then
            if not RoithiUI.db.profile.Castbar then RoithiUI.db.profile.Castbar = {} end
            if not RoithiUI.db.profile.Castbar[unit] then RoithiUI.db.profile.Castbar[unit] = { enabled = true } end

            -- Place next to Frame checkbox (approx 100px offset?)
            CreateCheck(unitContent, "Castbar", RoithiUI.db.profile.Castbar[unit], "enabled", 110, -5, ns.bars[unit])
        end
    end

    -- 3. Boss Frames Section
    local bossContent = CreateSection("Boss Frames", 35)
    local bossUnit = "boss1" -- Driver
    -- We assume enabling Boss1 enables the group usually, or we iterate all.
    -- UF:ToggleFrame handles simple Hide/Show.
    -- Let's just create one checkbox "Enable" that toggles all 5?
    -- Currently Config logic stores per-unit enabled state.

    local bossFrame = ufModule and ufModule.units and ufModule.units[bossUnit]
    if bossFrame then
        if not RoithiUI.db.profile.UnitFrames[bossUnit] then RoithiUI.db.profile.UnitFrames[bossUnit] = { enabled = true } end

        CreateCheck(bossContent, "Frame", RoithiUI.db.profile.UnitFrames[bossUnit], "enabled", 15, -5, nil,
            function(enabled)
                -- Toggle ALL boss frames
                if ufModule then
                    for i = 1, 5 do
                        local f = ufModule.units["boss" .. i]
                        if f then
                            ufModule:ToggleFrame("boss" .. i, enabled)
                            SetEditModeState(f, enabled)
                        end
                    end
                end
            end)
    end

    -- Bottom "Open Settings" Button
    local settingsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    settingsBtn:SetPoint("BOTTOM", 0, 5)
    settingsBtn:SetSize(140, 24)
    settingsBtn:SetText("Open Settings")
    settingsBtn:SetScript("OnClick", function()
        -- Open AceConfig Dialog
        if LibStub("AceConfigDialog-3.0") then
            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
        else
            print("RoithiUI: Settings not available.")
        end
    end)


    -- Main Toggle Script
    header:SetScript("OnClick", function()
        f.isExpanded = not f.isExpanded
        if f.isExpanded then
            UpdateLayout() -- Recalculate full height
            content:Show()
            settingsBtn:Show()
            arrow:SetAtlas("Options-List-Expand-Up")
        else
            f:SetHeight(40)
            content:Hide()
            settingsBtn:Hide()
            arrow:SetAtlas("Options-List-Expand-Down")
        end
    end)

    -- Init Layout
    UpdateLayout()
    -- Force start expanded
    f.isExpanded = true
    content:Show()
    settingsBtn:Show()
    arrow:SetAtlas("Options-List-Expand-Up")
    UpdateLayout()


    -- Anchor to EditMode
    if EditModeManagerFrame then
        f:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", 2, 0)
        hooksecurefunc(EditModeManagerFrame, "Show", function() f:Show() end)
        hooksecurefunc(EditModeManagerFrame, "Hide", function() f:Hide() end)
        if not EditModeManagerFrame:IsShown() then f:Hide() end
    end

    self.dashboard = f
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    Config:CreateDashboard()
end)
