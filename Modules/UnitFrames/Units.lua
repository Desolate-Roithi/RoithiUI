local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local UF = RoithiUI:GetModule("UnitFrames")

function UF:LayoutUnit(unit)
    -- Just a helper if we wanted distinctive layouts per unit
end

function UF:InitializeUnits()
    -- Player Frame
    if RoithiUIDB.EnabledModules.PlayerFrame then
        local frame = self:CreateUnitFrame("player", "Player")
        -- Initial Position (LibEditMode will likely override this on load)
        frame:SetPoint("CENTER", UIParent, "CENTER", -250, -100)

        self:CreateHealthBar(frame)
        self:CreatePowerBar(frame)
        self:CreateHealPrediction(frame)

        -- Player specific: Class Power? (Not requested, keeping simple)
    end

    -- Target Frame
    if RoithiUIDB.EnabledModules.TargetFrame then
        local frame = self:CreateUnitFrame("target", "Target")
        frame:SetPoint("CENTER", UIParent, "CENTER", 250, -100)

        self:CreateHealthBar(frame)
        self:CreatePowerBar(frame)
        self:CreateHealPrediction(frame)
    end

    -- Focus Frame
    if RoithiUIDB.EnabledModules.FocusFrame then
        local frame = self:CreateUnitFrame("focus", "Focus")
        frame:SetPoint("CENTER", UIParent, "CENTER", -350, 0)

        self:CreateHealthBar(frame)
        self:CreatePowerBar(frame)
        self:CreateHealPrediction(frame)
    end
end

-- Hook OnEnable to run initialization
-- We do this here so Elements.lua and Core.lua are already loaded
local baseEnable = UF.OnEnable
function UF:OnEnable()
    if baseEnable then baseEnable(self) end
    self:InitializeUnits()
end
