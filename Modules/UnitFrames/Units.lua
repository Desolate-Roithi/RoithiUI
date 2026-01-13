local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local UF = RoithiUI:GetModule("UnitFrames")

function UF:LayoutUnit(unit)
    -- Just a helper if we wanted distinctive layouts per unit
end

function UF:IsUnitEnabled(unit)
    if not RoithiUIDB.UnitFrames then return true end
    if not RoithiUIDB.UnitFrames[unit] then return true end
    return RoithiUIDB.UnitFrames[unit].enabled ~= false
end

function UF:ShouldCreate(unit)
    -- Always create to allow toggling, unless disabled at addon load?
    -- User wants to toggle. So we must create them.
    return true
end

function UF:InitializeUnits()
    -- Player Frame
    if self:ShouldCreate("player") then
        local frame = self:CreateUnitFrame("player", "Player")
        frame:SetPoint("CENTER", UIParent, "CENTER", -250, -100)
        self:CreateHealthBar(frame)
        self:CreatePowerBar(frame)
        self:CreateHealPrediction(frame)
        self:CreateName(frame)
        self:ToggleFrame("player", self:IsUnitEnabled("player"))
    end

    -- Target Frame
    if self:ShouldCreate("target") then
        local frame = self:CreateUnitFrame("target", "Target")
        frame:SetPoint("CENTER", UIParent, "CENTER", 250, -100)
        self:CreateHealthBar(frame)
        self:CreatePowerBar(frame)
        self:CreateHealPrediction(frame)
        self:CreateName(frame)
        self:ToggleFrame("target", self:IsUnitEnabled("target"))
    end

    -- Focus Frame
    if self:ShouldCreate("focus") then
        local frame = self:CreateUnitFrame("focus", "Focus")
        frame:SetPoint("CENTER", UIParent, "CENTER", -350, 0)
        self:CreateHealthBar(frame)
        self:CreatePowerBar(frame)
        self:CreateHealPrediction(frame)
        self:CreateName(frame)
        self:ToggleFrame("focus", self:IsUnitEnabled("focus"))
    end

    -- Pet Frame
    if self:ShouldCreate("pet") then
        local frame = self:CreateUnitFrame("pet", "Pet")
        frame:SetPoint("CENTER", UIParent, "CENTER", -250, -150)
        self:CreateHealthBar(frame)
        self:CreatePowerBar(frame)
        self:CreateName(frame)
        -- No HealPred for pet typically, or optional
        self:ToggleFrame("pet", self:IsUnitEnabled("pet"))
    end

    -- Target of Target (ToT)
    if self:ShouldCreate("targettarget") then
        local frame = self:CreateUnitFrame("targettarget", "ToT")
        frame:SetPoint("CENTER", UIParent, "CENTER", 250, -150)
        self:CreateHealthBar(frame)
        self:CreateName(frame)
        -- Power optional for ToT usually
        self:ToggleFrame("targettarget", self:IsUnitEnabled("targettarget"))
    end

    -- Focus Target
    if self:ShouldCreate("focustarget") then
        local frame = self:CreateUnitFrame("focustarget", "FocusTarget")
        frame:SetPoint("CENTER", UIParent, "CENTER", -350, -50)
        self:CreateHealthBar(frame)
        self:CreateName(frame)
        self:ToggleFrame("focustarget", self:IsUnitEnabled("focustarget"))
    end
end

-- Hook OnEnable to run initialization
-- We do this here so Elements.lua and Core.lua are already loaded
local baseEnable = UF.OnEnable
function UF:OnEnable()
    if baseEnable then baseEnable(self) end
    self:InitializeUnits()
end
