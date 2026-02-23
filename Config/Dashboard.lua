local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

-- Config Logic
-- ============================================================================
-- THE DASHBOARD WINDOW
-- This file controls the "RoithiUI Dashboard" floating window.
-- ============================================================================
local Config = RoithiUI.Config or {}
RoithiUI.Config = Config

function Config:CreateDashboard()
    if self.dashboard then return end

    -- Main Container
    local f = CreateFrame("Frame", "RoithiUIDashboard", UIParent, "BackdropTemplate")
    f:SetSize(220, 80) -- Initial size
    f:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", 2, 0)

    LibRoithi.mixins:CreateBackdrop(f)

    -- Header
    local header = CreateFrame("Button", nil, f)
    header:SetPoint("TOPLEFT", 5, -5)
    header:SetPoint("TOPRIGHT", -5, -5)
    header:SetHeight(30)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    title:SetText("RoithiUI Dashboard")

    -- Content Container
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 0, -35)
    content:SetPoint("BOTTOMRIGHT", 0, 5) 
    f.content = content

    -- Bottom "Open Settings" Button
    local settingsBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    settingsBtn:SetPoint("CENTER", 0, 0)
    settingsBtn:SetSize(160, 30)
    settingsBtn:SetText("Open Full Settings")
    settingsBtn:SetScript("OnClick", function()
        -- Open AceConfig Dialog
        if LibStub("AceConfigDialog-3.0") then
            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
        else
            print("RoithiUI: Settings not available.")
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

