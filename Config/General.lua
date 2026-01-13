local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

-- Config Logic
local Config = {}
RoithiUI.Config = Config

function Config:CreateDashboard()
    if self.dashboard then return end

    -- Main Container
    local f = CreateFrame("Frame", "RoithiUIDashboard", UIParent, "BackdropTemplate")
    f:SetSize(220, 260) -- Initial sizes, will adjust
    f:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", 2, 0)

    LibRoithi.mixins:CreateBackdrop(f)

    -- State
    f.isExpanded = true

    -- Header / Toggle Button
    local header = CreateFrame("Button", nil, f)
    header:SetPoint("TOPLEFT", 5, -5)
    header:SetPoint("TOPRIGHT", -5, -5)
    header:SetHeight(30)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    title:SetText("RoithiUI Config")

    local arrow = header:CreateTexture(nil, "ARTWORK")
    arrow:SetAtlas("Options-List-Expand-Up")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    f.menuArrow = arrow

    -- Content Container
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 0, -35)
    content:SetPoint("BOTTOMRIGHT", 0, 0)
    f.content = content

    -- Toggling Logic
    header:SetScript("OnClick", function()
        f.isExpanded = not f.isExpanded
        if f.isExpanded then
            f:SetHeight(260) -- Expanded Height
            content:Show()
            arrow:SetAtlas("Options-List-Expand-Up")
        else
            f:SetHeight(40) -- Collapsed Height
            content:Hide()
            arrow:SetAtlas("Options-List-Expand-Down")
        end
    end)

    -- Section Generator
    local currentY = -10
    local function CreateSection(labelString, unit)
        -- Header
        local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 15, currentY)
        label:SetText(labelString)
        currentY = currentY - 20

        -- Checkboxes
        local function CreateCheck(text, dbTable, key, frameObj)
            local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 25, currentY)
            cb:SetSize(20, 20)
            cb.text:SetFontObject("GameFontHighlightSmall")
            cb.text:SetText(text)

            cb:SetScript("OnShow", function(self)
                self:SetChecked(dbTable and dbTable[key])
            end)

            cb:SetScript("OnClick", function(self)
                local enabled = self:GetChecked()
                if dbTable then dbTable[key] = enabled end

                -- Toggle Frame Visibility Immediately
                if frameObj then
                    if enabled then
                        -- For Castbars, re-enabling might require more (edit mode re-init)
                        -- But for simple visibility:
                        frameObj:Show()
                        -- Castbar specific logic
                        if frameObj.isInEditMode ~= nil then
                            frameObj.isInEditMode = true
                            if LibStub("LibEditMode") then LibStub("LibEditMode"):RefreshFrameSettings(frameObj) end
                        end
                    else
                        if frameObj.isInEditMode ~= nil then frameObj.isInEditMode = false end
                        frameObj:Hide()
                    end
                end

                -- Specific Castbar Updates
                if ns.UpdateBlizzardVisibility then ns.UpdateBlizzardVisibility() end
                if ns.UpdateCast and frameObj then ns.UpdateCast(frameObj) end

                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end)

            return cb
        end

        local ufModule = RoithiUI:GetModule("UnitFrames")
        local ufFrame = ufModule and ufModule.frames and ufModule.frames[unit]

        -- 1. UnitFrame Check
        if ufFrame then
            -- Ensure DB exists
            if not RoithiUIDB.UnitFrames then RoithiUIDB.UnitFrames = {} end
            if not RoithiUIDB.UnitFrames[unit] then RoithiUIDB.UnitFrames[unit] = { enabled = true } end

            local cbUF = CreateCheck("UnitFrame", RoithiUIDB.UnitFrames[unit], "enabled", ufFrame)
        end

        -- 2. Castbar Check
        local cbBar = CreateCheck("Castbar", RoithiUIDB.Castbar[unit], "enabled", ns.bars[unit])
        cbBar:SetPoint("TOPLEFT", 110, currentY) -- Shift right

        currentY = currentY - 25
    end

    local units = {
        { "Player",       "player" },
        { "Target",       "target" },
        { "ToT",          "targettarget" },
        { "Focus",        "focus" },
        { "Focus Target", "focustarget" },
        { "Pet",          "pet" },
    }

    for _, u in ipairs(units) do
        CreateSection(u[1], u[2])
    end

    local totalHeight = math.abs(currentY) + 40
    f:SetHeight(totalHeight)

    -- Update toggle script with precise height
    header:SetScript("OnClick", function()
        f.isExpanded = not f.isExpanded
        if f.isExpanded then
            f:SetHeight(totalHeight)
            content:Show()
            arrow:SetAtlas("Options-List-Expand-Up")
        else
            f:SetHeight(40)
            content:Hide()
            arrow:SetAtlas("Options-List-Expand-Down")
        end
    end)


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
