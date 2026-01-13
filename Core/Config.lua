local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

-- Config Logic
local Config = {}
RoithiUI.Config = Config

function Config:CreateDashboard()
    if self.dashboard then return end

    local f = CreateFrame("Frame", "RoithiUIDashboard", UIParent)
    f:SetSize(200, 150)
    LibRoithi.mixins:CreateBackdrop(f)

    -- Header
    local title = f:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(title, "Friz Quadrata TT", 14)
    title:SetPoint("TOP", 0, -10)
    title:SetText("RoithiUI Config")

    -- Anchor to EditModeManagerFrame
    -- We assume EditModeManagerFrame exists in 10.0+ / 12.0
    if EditModeManagerFrame then
        f:SetPoint("TOPRIGHT", EditModeManagerFrame, "TOPLEFT", -10, 0)
        -- Show/Hide with EditMode
        hooksecurefunc(EditModeManagerFrame, "Show", function() f:Show() end)
        hooksecurefunc(EditModeManagerFrame, "Hide", function() f:Hide() end)
        if not EditModeManagerFrame:IsShown() then f:Hide() end
    else
        f:SetPoint("CENTER") -- Fallback
    end

    self.dashboard = f
    self.checkboxes = {}

    local modules = {
        { key = "PlayerFrame", label = "Player Frame" },
        { key = "TargetFrame", label = "Target Frame" },
        { key = "FocusFrame",  label = "Focus Frame" },
        { key = "Castbars",    label = "Castbars" },
    }

    local prev
    for i, info in ipairs(modules) do
        local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        if prev then
            cb:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -5)
        else
            cb:SetPoint("TOPLEFT", 10, -40)
        end
        cb.text:SetText(info.label)
        cb:SetChecked(RoithiUIDB.EnabledModules[info.key])

        cb:SetScript("OnClick", function(self)
            RoithiUIDB.EnabledModules[info.key] = self:GetChecked()
            print("|cff00ccffRoithiUI:|r " .. info.label .. " requires a reload to change state.")
        end)

        prev = cb
        self.checkboxes[info.key] = cb
    end
end

-- Initialize Config when ready (usually after PLAYER_LOGIN/OnEnable)
-- We hooked EditModeManagerFrame above, but we need to create the frame ONCE.
-- Let's create it on Login.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    -- Slight delay or direct creation
    Config:CreateDashboard()
end)
