local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

local UF = RoithiUI:GetModule("UnitFrames")

function UF:CreateHealthBar(frame)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetAllPoints(frame)
    health:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    health:SetStatusBarColor(0.2, 0.8, 0.2) -- Default green

    -- Backdrop for health
    local bg = health:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1)
    health.bg = bg

    frame.Health = health

    -- Text
    local text = health:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 12)
    text:SetPoint("CENTER")
    frame.Health.Text = text
end

function UF:CreatePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -1)
    power:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -1)
    power:SetHeight(10)
    power:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    power:SetStatusBarColor(0, 0.5, 1) -- Mana blue default

    LibRoithi.mixins:CreateBackdrop(power)

    local bg = power:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1)
    power.bg = bg

    frame.Power = power
end

-- 12.0 Heal Prediction Implementation
function UF:CreateHealPrediction(frame)
    local myHeal = CreateFrame("StatusBar", nil, frame.Health)
    myHeal:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    myHeal:SetStatusBarColor(0, 0.6, 0.3, 0.6)
    myHeal:SetFrameLevel(frame.Health:GetFrameLevel() + 1)

    local otherHeal = CreateFrame("StatusBar", nil, frame.Health)
    otherHeal:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    otherHeal:SetStatusBarColor(0, 0.6, 0, 0.6)
    otherHeal:SetFrameLevel(frame.Health:GetFrameLevel() + 1)

    local absorb = CreateFrame("StatusBar", nil, frame.Health)
    absorb:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    absorb:SetStatusBarColor(1, 1, 1, 0.6)                 -- White for absorbs
    absorb:SetFrameLevel(frame.Health:GetFrameLevel() + 2) -- Absorbs on top of heals usually? Or layered.

    -- Using the 12.0 API as requested
    ---@diagnostic disable-next-line: undefined-global
    if CreateUnitHealPredictionCalculator then
        ---@diagnostic disable-next-line: undefined-global
        local calculator = CreateUnitHealPredictionCalculator(frame.unit)

        frame:HookScript("OnUpdate", function()
            -- Retrieve values using UnitGetDetailedHealPrediction(unitGUID)
            -- But the calculator might be an object watcher.
            -- The prompt asks to "Use CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction".
            -- We assume UnitGetDetailedHealPrediction takes the unit or GUID.

            ---@diagnostic disable-next-line: undefined-global
            local myIncomingHeal, otherIncomingHeal, absorbed, healAbsorb, _, _ = UnitGetDetailedHealPrediction(
            frame.unit, nil, calculator)

            if not myIncomingHeal then return end

            local health = frame.Health:GetValue()
            local maxHealth = frame.Health:GetMinMaxValues() -- (min calls it max usually, checking returns)
            local _, maxHealthVal = frame.Health:GetMinMaxValues()

            -- Simple bar positioning logic (horizontal)
            local width = frame.Health:GetWidth()
            local healthPct = health / maxHealthVal
            local hpWidth = width * healthPct

            -- Position MyHeal
            myHeal:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", hpWidth, 0)
            myHeal:SetPoint("BOTTOMLEFT", frame.Health, "BOTTOMLEFT", hpWidth, 0)
            local myWidth = (myIncomingHeal / maxHealthVal) * width
            myHeal:SetWidth(math.max(1, myWidth))

            -- Position OtherHeal
            otherHeal:SetPoint("TOPLEFT", myHeal, "TOPRIGHT", 0, 0)
            otherHeal:SetPoint("BOTTOMLEFT", myHeal, "BOTTOMRIGHT", 0, 0)
            local otherWidth = (otherIncomingHeal / maxHealthVal) * width
            otherHeal:SetWidth(math.max(1, otherWidth))

            -- Position Absorb (Total Absorb overlay)
            -- Usually absorbs overlay health + prediction, but lets append for clarity or overlay at end
            -- ElvUI usually overlays it at the end of health.
            absorb:SetPoint("TOPLEFT", otherHeal, "TOPRIGHT", 0, 0)
            absorb:SetPoint("BOTTOMLEFT", otherHeal, "BOTTOMRIGHT", 0, 0)
            local absorbWidth = (absorbed / maxHealthVal) * width
            absorb:SetWidth(math.max(1, absorbWidth))
        end)
    end
end
