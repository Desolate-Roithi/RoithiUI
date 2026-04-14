local _, ns = ...

-- Custom Health Prediction Element (12.0.1 Secret-Safe Implementation)
-- Logic:
-- 1. MyHeal + OtherHeal = IncidentHeal (Grow from current HP)
-- 2. Absorb = Overlay from Left (Set via SetValue with secret pass-through)
-- 3. HealAbsorb = Overlay from Right (Reverse direction)

-- Safety Check
local CreateUnitHealPredictionCalculator = _G.CreateUnitHealPredictionCalculator
local UnitGetDetailedHealPrediction = _G.UnitGetDetailedHealPrediction
local UnitHealthMax = _G.UnitHealthMax

-- Shared Calculator to minimize churn
local calculator = CreateUnitHealPredictionCalculator and CreateUnitHealPredictionCalculator()

-- Update must exist so oUF fires PostUpdate on UNIT_HEAL_PREDICTION events.
-- Actual value-fetching is done inside PostUpdate via the Calculator.
local function Update(self, _, unit)
    if self.unit ~= unit then return end
end

local function PostUpdate(self, unit, _, _, _, _, _, _)
    local element = self
    local frame = self.__owner
    if not frame or not unit or not calculator then return end

    -- 12.0.1 Protocol: Fetch fresh detailed values via Calculator
    UnitGetDetailedHealPrediction(unit, "player", calculator)
    local _, myIncomingHeal, otherIncomingHeal, _ = calculator:GetIncomingHeals()
    local absorbAmount = calculator:GetDamageAbsorbs() or 0
    local healAbsorbAmount = calculator:GetHealAbsorbs() or 0

    local maxHealth = UnitHealthMax(unit)

    -- Ensure we don't do illegal math on Secrets
    -- Logic: Standard StatusBar:SetValue() supports Secret values.
    
    -- 1. My Healing (Appended to current Health)
    if element.myBar then
        element.myBar:SetMinMaxValues(0, maxHealth)
        element.myBar:SetValue(myIncomingHeal or 0)
        
        local healthTex = frame.Health and frame.Health:GetStatusBarTexture()
        if healthTex then
            element.myBar:ClearAllPoints()
            element.myBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", 0, 0)
            element.myBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", 0, 0)
        end
    end

    -- 2. Other Healing (Appended to My Healing)
    if element.otherBar then
        element.otherBar:SetMinMaxValues(0, maxHealth)
        element.otherBar:SetValue(otherIncomingHeal or 0)
        
        local myTex = element.myBar and element.myBar:GetStatusBarTexture()
        if myTex then
            element.otherBar:ClearAllPoints()
            element.otherBar:SetPoint("TOPLEFT", myTex, "TOPRIGHT", 0, 0)
            element.otherBar:SetPoint("BOTTOMLEFT", myTex, "BOTTOMRIGHT", 0, 0)
        end
    end

    -- 3. Absorb (Overlay from Left)
    if element.absorbBar then
        element.absorbBar:SetMinMaxValues(0, maxHealth)
        -- Clamping must be handled by the widget or by trusting the calculator.
        element.absorbBar:SetValue(absorbAmount)
    end

    -- 4. Heal Absorb (Anti-Heal overlay)
    if element.healAbsorbBar then
        element.healAbsorbBar:SetMinMaxValues(0, maxHealth)
        element.healAbsorbBar:SetValue(healAbsorbAmount)
    end
end

ns.HealthPrediction = {
    PostUpdate = PostUpdate,
    Update = Update
}
