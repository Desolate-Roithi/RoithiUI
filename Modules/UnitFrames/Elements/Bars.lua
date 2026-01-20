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
    local power = CreateFrame("StatusBar", frame:GetName() .. "_Power", frame)
    -- Initial defaults
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

    -- Title for Edit Mode
    power.Text = power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    power.Text:SetPoint("CENTER")
    power.Text:SetText("POWER")
    power.Text:Hide()

    frame.Power = power

    -- Edit Mode Registration (Lazy)
    local LEM = LibStub("LibEditMode", true)
    if LEM then
        -- We won't AddFrame immediately, but prepare for it?
        -- Actually, usually better to Add once.
        frame.Power.editModeName = (frame.editModeName or frame:GetName()) .. " Power"

        -- Default position (detached)
        local defaults = { point = "CENTER", x = 0, y = -100 }

        local function OnPowerPosChanged(f, layoutName, point, x, y)
            local unit = frame.unit
            local db = RoithiUIDB and RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[unit]

            -- If not detached, ignore movement and enforce attached layout
            if not db or not db.powerDetached then
                -- Optional: Immediately snap back? Or just rely on UpdatePowerLayout
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -1)
                f:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -1)
                return
            end

            if db then
                db.powerPoint = point
                db.powerX = x
                db.powerY = y
            end
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
        end

        LEM:AddFrame(power, OnPowerPosChanged, defaults)

        -- Custom Visibility for Edit Mode
        -- Only show overlay/movable if Detached
        LEM:RegisterCallback('enter', function()
            local unit = frame.unit
            local db = RoithiUIDB and RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[unit]
            if db and db.powerDetached then
                power.isInEditMode = true
                power:SetAlpha(1)
                power:Show()
            else
                power.isInEditMode = false
                -- Do not show distinct edit overlay if attached (it moves with main frame)
            end
        end)

        LEM:RegisterCallback('exit', function()
            power.isInEditMode = false
            -- Revert to normal visibility handled by OnEvent
            -- If detached, we might need to ensure it hides if unit missing?
            -- Yes, normal OnShow/OnEvent handles this.
            local UnitExists = UnitExists(frame.unit)
            if not UnitExists then power:Hide() end
        end)
    end

    -- Layout Updater
    local function UpdatePowerLayout()
        local unit = frame.unit
        local db
        if RoithiUIDB and RoithiUIDB.UnitFrames then db = RoithiUIDB.UnitFrames[unit] end

        local height = db and db.powerHeight or 10
        local detached = db and db.powerDetached
        local enabled = db and (db.powerEnabled ~= false)

        if not enabled then
            power:Hide()
            return
        end
        power:Show()

        -- Sync Edit Mode State from Parent Frame
        if frame.isInEditMode then
            power.isInEditMode = true
            power:SetAlpha(1)
            -- If strictly detached, we might want to ensure it shows.
            -- UpdatePower handles text/dummy display if isInEditMode is set.
        end

        power:SetHeight(height)
        power:ClearAllPoints()

        if detached then
            -- Independent
            power:SetParent(UIParent)
            -- If we have saved pos, use it
            local point = db and db.powerPoint or "CENTER"
            local x = db and db.powerX or 0
            local y = db and db.powerY or -50

            power:SetPoint(point, UIParent, point, x, y)

            -- Independent Width
            local width = db and db.powerWidth or frame:GetWidth()
            power:SetWidth(width)
        else
            -- Attached
            power:SetParent(frame)
            -- Reset position relative to frame
            -- Typically bottom
            power:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -1)
            power:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -1)
            -- Width is implicit by anchors, but explicit set helps if we changed it previously?
            -- Anchors override SetWidth usually, but safe to reset if we detach then reattach without reload.
            -- Actually Anchors TOPLEFT/TOPRIGHT force width.
        end
    end
    frame.UpdatePowerLayout = UpdatePowerLayout
    UpdatePowerLayout() -- Initial


    -- Update Logic
    local function UpdatePower(self)
        if power.isInEditMode then
            self:SetMinMaxValues(0, 100)
            self:SetValue(100)
            self:SetStatusBarColor(0, 0, 1) -- Blue dummy
            if power.Text then power.Text:Show() end
            return
        end
        if power.Text then power.Text:Hide() end

        local unit = frame.unit
        if not UnitExists(unit) then return end -- Safety for detached

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

function UF:CreateAdditionalPower(frame)
    local power = CreateFrame("StatusBar", frame:GetName() .. "_AdditionalPower", frame)
    -- Initial defaults
    power:SetPoint("TOPLEFT", frame.Power, "BOTTOMLEFT", 0, -4)
    power:SetPoint("TOPRIGHT", frame.Power, "BOTTOMRIGHT", 0, -4)
    power:SetHeight(10)
    power:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")

    LibRoithi.mixins:CreateBackdrop(power)

    local bg = power:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1)
    power.bg = bg

    -- Title for Edit Mode
    power.Text = power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    power.Text:SetPoint("CENTER")
    power.Text:SetText("ADDITIONAL POWER")
    power.Text:Hide()

    frame.AdditionalPower = power

    -- Edit Mode Registration
    local LEM = LibStub("LibEditMode", true)
    if LEM then
        frame.AdditionalPower.editModeName = (frame.editModeName or frame:GetName()) .. " Additional Power"

        -- Default position (detached)
        local defaults = { point = "CENTER", x = 0, y = -125 }

        local function OnPosChanged(f, layoutName, point, x, y)
            local unit = frame.unit
            local db = RoithiUIDB and RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[unit]

            if not db or not db.additionalPowerDetached then
                f:ClearAllPoints()
                -- Attached Stack Logic
                -- If ClassPower is visible and attached, this goes below ClassPower?
                -- Or Health > Power > Additional > ClassPower?
                -- Usually Additional Power (Mana) is less important than Class Power (Combo Points).
                -- Let's stack: Health -> Power -> ClassPower -> AdditionalPower
                -- BUT ClassPower might be hidden. We need dynamic layout in UpdateLayout.
                -- For now default reset:
                -- We entrust UpdateLayout to handle attached positioning.
                return
            end

            if db then
                db.additionalPowerPoint = point
                db.additionalPowerX = x
                db.additionalPowerY = y
            end
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
        end

        LEM:AddFrame(power, OnPosChanged, defaults)

        LEM:RegisterCallback('enter', function()
            local unit = frame.unit
            local db = RoithiUIDB and RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[unit]
            if db and db.additionalPowerDetached then
                power.isInEditMode = true
                power:SetAlpha(1)
                power:Show()
            else
                power.isInEditMode = false
            end
        end)

        LEM:RegisterCallback('exit', function()
            power.isInEditMode = false
            -- Visibility handled by Update
            local UnitExists = UnitExists(frame.unit)
            if not UnitExists then power:Hide() end
        end)
    end

    -- Layout Updater
    local function UpdateLayout()
        local unit = frame.unit
        local db
        if RoithiUIDB and RoithiUIDB.UnitFrames then db = RoithiUIDB.UnitFrames[unit] end

        local height = db and db.additionalPowerHeight or 10
        local detached = db and db.additionalPowerDetached
        local enabled = db and (db.additionalPowerEnabled ~= false)

        if not enabled then
            power:Hide()
            return
        end
        -- Note: Actual visibility is controlled by power type check in Update,
        -- but here we handle sizing and positioning.

        -- Sync Edit Mode State
        if frame.isInEditMode then
            power.isInEditMode = true
            power:SetAlpha(1)
        end

        power:SetHeight(height)
        power:ClearAllPoints()

        if detached then
            power:SetParent(UIParent)
            local point = db and db.additionalPowerPoint or "CENTER"
            local x = db and db.additionalPowerX or 0
            local y = db and db.additionalPowerY or -125

            power:SetPoint(point, UIParent, point, x, y)

            -- Independent Width
            local width = db and db.additionalPowerWidth or frame:GetWidth()
            power:SetWidth(width)
        else
            power:SetParent(frame)
            -- Stacking Logic:
            -- Ideally we want: Health -> Power -> ClassPower -> AdditionalPower
            -- But ClassPower visibility varies.
            -- We anchor to ClassPower if shown, else Power.

            local anchor = frame.Power
            local offset = -1

            if frame.ClassPower and frame.ClassPower:IsShown() and not (db and db.classPowerDetached) then
                anchor = frame.ClassPower
                offset = -4  -- Spacing between bars
            elseif frame.Power and frame.Power:IsShown() and not (db and db.powerDetached) then
                anchor = frame.Power
                offset = -1
            else
                anchor = frame.Health  -- Fallback if everything else detached/hidden
                offset = -1
            end

            power:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offset)
            power:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, offset)
        end
    end
    frame.UpdateAdditionalPowerLayout = UpdateLayout

    -- Update Logic
    local function UpdatePower(self)
        if power.isInEditMode then
            self:SetMinMaxValues(0, 100)
            self:SetValue(100)
            self:SetStatusBarColor(0, 0, 1)
            if power.Text then power.Text:Show() end
            return
        end
        if power.Text then power.Text:Hide() end

        local unit = frame.unit
        if not UnitExists(unit) then return end

        local pType = UnitPowerType(unit)

        -- Visibility Rule:
        -- Show only if current power is NOT Mana (0), AND we have Max Mana > 0.
        -- This covers Druids in Form, Shamans/Priests/Paladins who have Mana but use other resources.

        local show = false
        if pType ~= 0 then -- Not Mana
            local maxMana = UnitPowerMax(unit, 0)
            if maxMana and maxMana > 0 then
                show = true
            end
        end

        -- Override for Edit Mode testing if force enabled? No, stick to game logic.

        if not show then
            power:Hide()
            return
        end
        power:Show()

        local cur = UnitPower(unit, 0) -- Always Mana (0)
        local max = UnitPowerMax(unit, 0)
        self:SetMinMaxValues(0, max)
        self:SetValue(cur)

        -- Color (Mana Blue)
        local c = PowerBarColor["MANA"]
        if c then
            self:SetStatusBarColor(c.r, c.g, c.b)
        else
            self:SetStatusBarColor(0, 0, 1)
        end
    end

    power:SetScript("OnEvent", UpdatePower)
    power:RegisterUnitEvent("UNIT_POWER_UPDATE", frame.unit)
    power:RegisterUnitEvent("UNIT_MAXPOWER", frame.unit)
    power:RegisterUnitEvent("UNIT_DISPLAYPOWER", frame.unit)
    power:SetScript("OnShow", UpdatePower)

    -- Initial
    if UnitExists(frame.unit) then UpdatePower(power) end
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
