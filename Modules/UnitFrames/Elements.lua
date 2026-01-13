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

    -- Scripts
    local function UpdateHealth(self)
        local unit = frame.unit
        local min, max = UnitHealth(unit), UnitHealthMax(unit)
        self:SetMinMaxValues(0, max)
        self:SetValue(min)
    end
    health:SetScript("OnEvent", UpdateHealth)
    health:RegisterUnitEvent("UNIT_HEALTH", frame.unit)
    health:RegisterUnitEvent("UNIT_MAXHEALTH", frame.unit)
    -- Hook Show to force update
    health:SetScript("OnShow", UpdateHealth)

    -- Initial update
    if UnitExists(frame.unit) then UpdateHealth(health) end

    -- Target/Focus change updates
    if frame.unit == "target" then
        health:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        health:RegisterEvent("PLAYER_FOCUS_CHANGED")
    end
end

function UF:CreatePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -1)
    power:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -1)
    power:SetHeight(10)
    power:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")

    LibRoithi.mixins:CreateBackdrop(power)

    local bg = power:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1)
    power.bg = bg

    frame.Power = power

    -- Update Logic
    local function UpdatePower(self)
        local unit = frame.unit
        local min, max = UnitPower(unit), UnitPowerMax(unit)
        self:SetMinMaxValues(0, max)
        self:SetValue(min)

        -- Color
        local pType, pToken, altR, altG, altB = UnitPowerType(unit)
        local c = PowerBarColor[pToken]
        if not c and pType then c = PowerBarColor[pType] end
        if not c then c = PowerBarColor["MANA"] end -- Fallback

        if c then
            self:SetStatusBarColor(c.r, c.g, c.b)
        else
            self:SetStatusBarColor(0, 0, 1) -- Ultimate fallback
        end
    end

    power:SetScript("OnEvent", UpdatePower)
    power:RegisterUnitEvent("UNIT_POWER_UPDATE", frame.unit)
    power:RegisterUnitEvent("UNIT_MAXPOWER", frame.unit)
    power:RegisterUnitEvent("UNIT_DISPLAYPOWER", frame.unit)
    power:SetScript("OnShow", UpdatePower)

    -- Target/Focus change updates
    if frame.unit == "target" then
        power:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        power:RegisterEvent("PLAYER_FOCUS_CHANGED")
    end

    -- Initial
    if UnitExists(frame.unit) then UpdatePower(power) end
end

function UF:CreateName(frame)
    local text = frame.Health:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 12)
    text:SetPoint("CENTER", frame.Health, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    frame.Name = text

    local function UpdateName()
        local name = GetUnitName(frame.unit, true)
        text:SetText(name or "")

        -- Color by class? (Optional)
        local _, class = UnitClass(frame.unit)
        if class then
            local c = RAID_CLASS_COLORS[class]
            if c then text:SetTextColor(c.r, c.g, c.b) else text:SetTextColor(1, 1, 1) end
        else
            text:SetTextColor(1, 1, 1)
        end
    end

    -- Frame needs to handle name updates, usually attached to parent
    -- We can attach a script to a hidden frame or the main button?
    -- The main button is SecureUnitButton, scripting it is tricky if we override standard handlers.
    -- But OnEvent is fine.
    if not frame.HitRect then -- Just checking if we already added a hook
        frame:HookScript("OnEvent", function(self, event, ...)
            if event == "UNIT_NAME_UPDATE" or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
                UpdateName()
            end
        end)
        -- Register events on the main frame
        frame:RegisterUnitEvent("UNIT_NAME_UPDATE", frame.unit)
        -- Target/Focus changes are handled by attributes mostly for unit, but name update isn't automatic
        -- Since 'unit' is constant for a frame (player, target), we rely on UNIT_NAME_UPDATE or just OnShow
        frame:HookScript("OnShow", UpdateName)
    end
    -- Register generic updates? For Target, we need PLAYER_TARGET_CHANGED
    if frame.unit == "target" then
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    end

    UpdateName()
end

-- 12.0 Heal Prediction Implementation
-- 12.0 Heal Prediction Implementation
-- Standard Heal Prediction & Absorb Implementation
-- 12.0 Heal Prediction Implementation
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
    -- Debug Color (Bright Neon Yellow) and High Strata as requested
    absorb:SetStatusBarColor(1, 1, 0, 1)
    absorb:SetFrameLevel(frame.Health:GetFrameLevel() + 10)

    -- Over-absorb Glow
    local overAbsorbGlow = absorb:CreateTexture(nil, "OVERLAY")
    overAbsorbGlow:SetTexture("Interface\\RaidFrame\\Shield-Overshield-Glow")
    overAbsorbGlow:SetBlendMode("ADD")
    overAbsorbGlow:SetPoint("BOTTOMLEFT", absorb, "BOTTOMRIGHT", -7, 0)
    overAbsorbGlow:SetPoint("TOPLEFT", absorb, "TOPRIGHT", -7, 0)
    overAbsorbGlow:SetWidth(16)
    overAbsorbGlow:Hide()
    absorb.overGlow = overAbsorbGlow

    -- Using the Correct 12.0 API Usage
    ---@diagnostic disable-next-line: undefined-global
    if CreateUnitHealPredictionCalculator then
        ---@diagnostic disable-next-line: undefined-global
        local calculator = CreateUnitHealPredictionCalculator()

        frame:HookScript("OnUpdate", function()
            local status, err = pcall(function()
                ---@diagnostic disable-next-line: undefined-global
                UnitGetDetailedHealPrediction(frame.unit, "player", calculator)

                -- 1. Get Values
                local _, myIncomingHeal, otherIncomingHeal, _ = calculator:GetIncomingHeals()
                local absorbAmount, isClamped = calculator:GetDamageAbsorbs()
                absorbAmount = absorbAmount or 0

                -- Support Safe Rendering (Secret Values) using SetValue + Scaling

                -- Support Safe Rendering (Secret Values) using SetValue + Scaling
                -- We want the bar to represent 0 -> 110% of Health
                -- So we make the Frame 110% wide, and SetMinMax to 0 -> 110% MaxHealth

                local maxHealthVal = UnitHealthMax(frame.unit)
                -- UnitHealthMax returns secret; comparison crashes. Safe to pass to SetMinMaxValues.

                local width = frame.Health:GetWidth()
                if width <= 0 then return end

                -- Heal Logic (SetValue + Stacked)
                myHeal:SetWidth(width)
                myHeal:SetMinMaxValues(0, maxHealthVal)
                myHeal:SetValue(myIncomingHeal or 0)

                otherHeal:SetWidth(width)
                otherHeal:SetMinMaxValues(0, maxHealthVal)
                otherHeal:SetValue(otherIncomingHeal or 0)

                local healthTex = frame.Health:GetStatusBarTexture()
                myHeal:ClearAllPoints()
                if healthTex then
                    myHeal:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", 0, 0)
                    myHeal:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", 0, 0)
                else
                    myHeal:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", 0, 0)
                    myHeal:SetPoint("BOTTOMLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                end

                local myTex = myHeal:GetStatusBarTexture()
                otherHeal:ClearAllPoints()
                if myTex then
                    otherHeal:SetPoint("TOPLEFT", myTex, "TOPRIGHT", 0, 0)
                    otherHeal:SetPoint("BOTTOMLEFT", myTex, "BOTTOMRIGHT", 0, 0)
                else
                    otherHeal:SetPoint("TOPLEFT", myHeal, "TOPLEFT", 0, 0)
                    otherHeal:SetPoint("BOTTOMLEFT", myHeal, "BOTTOMLEFT", 0, 0)
                end

                -- Absorb Logic (Restricted Environment Safe Mode)
                -- 1. We cannot check if values are <= 0 or nil (Comparison Crash)
                -- 2. We cannot multiply maxHealth * 1.1 (Arithmetic Crash)
                -- 3. We Must pass-through values directly to widgets.

                local totalAbsorb = UnitGetTotalAbsorbs(frame.unit)

                absorb:ClearAllPoints()
                absorb:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", 0, 0)
                absorb:SetPoint("BOTTOMLEFT", frame.Health, "BOTTOMLEFT", 0, 0)

                -- Width: 100% of Health Frame (Safe UI Value)
                -- We cannot scale to 110% because we cannot multiply the MaxValue secret.
                absorb:SetWidth(width)

                -- MinMax: Pass-through from Health Bar (Secret -> Secret)
                -- We assume Health Bar has valid MinMax from its own secure update.
                local hMin, hMax = frame.Health:GetMinMaxValues()
                absorb:SetMinMaxValues(hMin, hMax)

                -- Value: Direct Pass (Secret -> Secret)
                absorb:SetValue(totalAbsorb or 0)

                absorb:Show()

                -- Color: Higher Visibility (Light Blue-Grey, Higher Alpha)
                absorb:SetStatusBarColor(0.6, 0.8, 1, 0.6)

                -- Glow: Disabled (Cannot compare total > max)
                overAbsorbGlow:Hide()
            end)

            if not status then
                local t = GetTime()
                if not frame.lastErr or (t - frame.lastErr > 3) then
                    frame.lastErr = t
                    print("[RoithiUI Error]: " .. tostring(err))
                end
            end
        end)
    end
end
