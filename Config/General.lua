local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

-- Config Logic
-- Config Logic
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
    title:SetText("RoithiUI Edit Mode")

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
                -- Generic frame toggle logic (mostly for castbars)
                if enabled then
                    frameObj:Show()
                    if frameObj.isInEditMode ~= nil then
                        frameObj.isInEditMode = true
                        if LibStub("LibEditMode") then LibStub("LibEditMode"):RefreshFrameSettings(frameObj) end
                    end
                else
                    if frameObj.isInEditMode ~= nil then frameObj.isInEditMode = false end
                    frameObj:Hide()
                end
            end

            if ns.UpdateBlizzardVisibility then ns.UpdateBlizzardVisibility() end
            if ns.UpdateCast and frameObj then ns.UpdateCast(frameObj) end

            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        return cb
    end

    -- 1. General Section
    local generalContent = CreateSection("General", 55)

    -- Encounter Bar
    if not RoithiUIDB.EncounterResource then RoithiUIDB.EncounterResource = { enabled = true } end
    local ufModule = RoithiUI:GetModule("UnitFrames")

    CreateCheck(generalContent, "Encounter Bar", RoithiUIDB.EncounterResource, "enabled", 15, -5, nil, function(enabled)
        if ufModule then ufModule:ToggleEncounterResource(enabled) end
    end)

    -- Battle Res
    if not RoithiUIDB.Timers then RoithiUIDB.Timers = {} end
    if not RoithiUIDB.Timers.BattleRes then RoithiUIDB.Timers.BattleRes = { enabled = true } end
    local brFrame = _G["RoithiBattleRes"]
    CreateCheck(generalContent, "Battle Res", RoithiUIDB.Timers.BattleRes, "enabled", 15, -30, brFrame, function(enabled)
        if brFrame then
            if enabled then
                brFrame:Show(); if brFrame.Update then brFrame:Update() end
            else
                brFrame:Hide()
            end
        end
    end)

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

        local ufFrame = ufModule and ufModule.frames and ufModule.frames[unit]

        -- UnitFrame Check
        if ufFrame then
            if not RoithiUIDB.UnitFrames then RoithiUIDB.UnitFrames = {} end
            if not RoithiUIDB.UnitFrames[unit] then RoithiUIDB.UnitFrames[unit] = { enabled = true } end

            CreateCheck(unitContent, "Frame", RoithiUIDB.UnitFrames[unit], "enabled", 15, -5, ufFrame, function(enabled)
                if ufModule then ufModule:ToggleFrame(unit, enabled) end
            end)
        end

        -- Castbar Check
        if ns.bars and ns.bars[unit] then
            if not RoithiUIDB.Castbar then RoithiUIDB.Castbar = {} end
            if not RoithiUIDB.Castbar[unit] then RoithiUIDB.Castbar[unit] = { enabled = true } end

            -- Place next to Frame checkbox (approx 100px offset?)
            CreateCheck(unitContent, "Castbar", RoithiUIDB.Castbar[unit], "enabled", 110, -5, ns.bars[unit])
        end
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
