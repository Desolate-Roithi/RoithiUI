local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

---@class UF : AceModule, AceAddon
---@class UF : AceModule, AceAddon
local UF = RoithiUI:GetModule("UnitFrames")

-- Default Power Colors (Fallback)
local DefaultPowerColors = {
    ["MANA"] = { r = 0, g = 0, b = 1 },
    ["RAGE"] = { r = 1, g = 0, b = 0 },
    ["FOCUS"] = { r = 1, g = 0.5, b = 0.25 },
    ["ENERGY"] = { r = 1, g = 1, b = 0 },
    ["COMBO_POINTS"] = { r = 1, g = 0.96, b = 0.41 },
    ["RUNES"] = { r = 0.5, g = 0.5, b = 0.5 },
    ["RUNIC_POWER"] = { r = 0, g = 0.82, b = 1 },
    ["SOUL_SHARDS"] = { r = 0.5, g = 0.32, b = 0.55 },
    ["LUNAR_POWER"] = { r = 0.3, g = 0.52, b = 0.9 },
    ["HOLY_POWER"] = { r = 0.95, g = 0.9, b = 0.6 },
    ["MAELSTROM"] = { r = 0, g = 0.5, b = 1 },
    ["INSANITY"] = { r = 0.4, g = 0, b = 0.8 },
    ["CHI"] = { r = 0.71, g = 1, b = 0.92 },
    ["ARCANE_CHARGES"] = { r = 0.1, g = 0.1, b = 0.98 },
    ["FURY"] = { r = 0.788, g = 0.259, b = 0.992 },
    ["PAIN"] = { r = 1, g = 0.611, b = 0 },
    ["ESSENCE"] = { r = 0.4, g = 0.8, b = 1 },
}
-- Assign numeric indices for classic lookup
DefaultPowerColors[0] = DefaultPowerColors["MANA"]
DefaultPowerColors[1] = DefaultPowerColors["RAGE"]
DefaultPowerColors[2] = DefaultPowerColors["FOCUS"]
DefaultPowerColors[3] = DefaultPowerColors["ENERGY"]

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

        -- Fix: Register UNIT_TARGET for sub-units to ensure health updates immediately
    elseif frame.unit == "targettarget" or frame.unit == "focustarget" or frame.unit == "pettarget" then
        health:RegisterEvent("UNIT_TARGET")
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
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]

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
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]
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
            -- Visibility handled by Update, but ensure we don't vanish if valid
            -- Actually, UpdatePower will handle showing it if unit exists.
            -- But we can trigger an update?
            if UnitExists(frame.unit) then
                if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
                -- Force color update
                if power.SetStatusBarColor then power:SetStatusBarColor(0, 0, 1) end -- Reset? No.
                -- Just let next update handle it or force one.
                if power:GetScript("OnShow") then power:GetScript("OnShow")(power) end
            else
                power:Hide()
            end
        end)
    end

    -- Layout Updater
    local function UpdatePowerLayout()
        local unit = frame.unit
        local db
        local db
        if RoithiUI.db.profile.UnitFrames then db = RoithiUI.db.profile.UnitFrames[unit] end

        -- Special Handling for Boss Frames (Inheritance)
        if string.match(unit, "^boss[2-5]$") then
            local driverDB = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames["boss1"]
            if driverDB then
                local specificDB = db or {}
                db = setmetatable({}, {
                    __index = function(_, k)
                        -- Inherit Power Settings
                        if k == "powerHeight" or k == "powerEnabled" then
                            return driverDB[k]
                        end
                        -- Force Detach OFF for passengers
                        if k == "powerDetached" then
                            return false
                        end
                        return specificDB[k]
                    end
                })
            end
        end

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
        end
    end
    frame.UpdatePowerLayout = UpdatePowerLayout
    UpdatePowerLayout() -- Initial

    -- Update Logic (Main Power)
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

        -- Main Power always shows unless specifically disabled?
        -- Actually main power logic is usually just "Show".
        power:Show()

        local cur = UnitPower(unit)
        local max = UnitPowerMax(unit)
        self:SetMinMaxValues(0, max)
        self:SetValue(cur)

        local pTypeIndex, pToken = UnitPowerType(unit)

        -- Safe Color Lookup
        local info = PowerBarColor and (PowerBarColor[pToken] or PowerBarColor[pTypeIndex])
        if not info then
            info = DefaultPowerColors[pToken] or DefaultPowerColors[pTypeIndex] or DefaultPowerColors["MANA"]
        end

        if info then
            self:SetStatusBarColor(info.r, info.g, info.b)
        else
            -- Debugging Color Failure
            local pName = UnitName(unit) or "?"
            print(string.format("[RoithiUI Dbg] Unit: %s | Type: %s (%s) | Info: Nil? Fallback to Blue.", pName,
                tostring(pToken), tostring(pTypeIndex)))
            if not DefaultPowerColors["RAGE"] then print("[RoithiUI Dbg] DefaultPowerColors[RAGE] is missing!") end

            self:SetStatusBarColor(0, 0, 1) -- Fallback Blue
        end
    end

    power:SetScript("OnEvent", UpdatePower)
    power:RegisterUnitEvent("UNIT_POWER_UPDATE", frame.unit)
    power:RegisterUnitEvent("UNIT_MAXPOWER", frame.unit)
    power:RegisterUnitEvent("UNIT_DISPLAYPOWER", frame.unit)
    -- Also hook OnShow
    power:SetScript("OnShow", UpdatePower)

    -- Target/Focus change updates (Mirroring Health Bar Logic)
    if frame.unit == "target" then
        power:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        power:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "targettarget" or frame.unit == "focustarget" or frame.unit == "pettarget" then
        power:RegisterEvent("UNIT_TARGET")
    end

    -- Initial Update
    if UnitExists(frame.unit) then UpdatePower(power) end
end

function UF:CreateAdditionalPower(frame)
    if frame.unit ~= "player" then return end
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
        local defaults = { point = "CENTER", x = 0, y = 0 }

        local function OnPosChanged(f, layoutName, point, x, y)
            local unit = frame.unit
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]

            if not db or not db.additionalPowerDetached then
                f:ClearAllPoints()
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
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]
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
        if RoithiUI.db.profile.UnitFrames then db = RoithiUI.db.profile.UnitFrames[unit] end

        local height = db and db.additionalPowerHeight or 10
        local detached = db and db.additionalPowerDetached
        local enabled = db and (db.additionalPowerEnabled ~= false)

        if not enabled then
            power:Hide()
            return
        end

        -- Sync Edit Mode State
        if frame.isInEditMode then
            power.isInEditMode = true
            power:SetAlpha(1)
        end

        power:SetHeight(height)
        power:ClearAllPoints()

        if detached then
            power:SetParent(UIParent)
            -- Default 0,0
            local point = db and db.additionalPowerPoint or "CENTER"
            local x = db and db.additionalPowerX or 0
            local y = db and db.additionalPowerY or 0

            power:SetPoint(point, UIParent, point, x, y)

            -- Independent Width
            local width = db and db.additionalPowerWidth or frame:GetWidth()
            power:SetWidth(width)
        else
            power:SetParent(frame)
            -- Stacking Logic: "Add is still at the unitframe"
            -- We only anchor to Class/Power if they are ALSO at the unitframe.

            local anchor = frame.Health
            local offset = -1

            local powerIsAtUF = not (db and db.powerDetached) and frame.Power:IsShown()
            local classIsAtUF = not (db and db.classPowerDetached) and frame.ClassPower and frame.ClassPower:IsShown() and
                powerIsAtUF

            -- Note: ClassPower is only "At UF" if Power is also "At UF", because Class follows Power.
            -- If Power is detached, Class follows it away, so Class is NOT at UF.

            if classIsAtUF then
                anchor = frame.ClassPower
                offset = -4
            elseif powerIsAtUF then
                anchor = frame.Power
                offset = -1
            else
                anchor = frame.Health
                offset = -1
            end

            power:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offset)
            power:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, offset)

            -- Force Frame Width when attached
            power:SetWidth(frame:GetWidth())
        end
    end
    frame.UpdateAdditionalPowerLayout = UpdateLayout

    -- Default Power Colors (Fallback) Moved to File Scope


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

        if not show then
            power:Hide()
            return
        end
        power:Show()

        local cur = UnitPower(unit, 0) -- Always Mana (0)
        local max = UnitPowerMax(unit, 0)
        self:SetMinMaxValues(0, max)
        self:SetValue(cur)

        local pTypeIndex, pToken = UnitPowerType(unit)

        -- Safe Color Lookup
        local info = PowerBarColor and (PowerBarColor[pToken] or PowerBarColor[pTypeIndex])
        if not info then
            info = DefaultPowerColors[pToken] or DefaultPowerColors[pTypeIndex] or DefaultPowerColors["MANA"]
        end

        if info then
            self:SetStatusBarColor(info.r, info.g, info.b)
        else
            self:SetStatusBarColor(0, 0, 1) -- Ultimate Fallback Blue
        end
    end

    power:SetScript("OnEvent", UpdatePower)
    power:RegisterEvent("UNIT_POWER_UPDATE")
    power:RegisterEvent("UNIT_MAXPOWER")
    power:RegisterEvent("UNIT_DISPLAYPOWER")
    power:SetScript("OnShow", UpdatePower)

    -- Initial
    if UnitExists(frame.unit) then UpdatePower(power) end
end

-- 12.0 Heal Prediction Implementation
function UF:CreateHealPrediction(frame)
    local health = frame.Health or frame.SafeHealth
    if not health then return end
    local clipFrame = CreateFrame("Frame", nil, health)
    clipFrame:SetAllPoints()
    -- Safety wrap for older clients or environments where this might strict-error
    pcall(function() clipFrame:SetClipsChildren(true) end)
    frame.Health.ClipFrame = clipFrame

    local texture = LSM:Fetch("statusbar", RoithiUI.db.profile.barTexture or "Solid") or
        "Interface\\TargetingFrame\\UI-StatusBar"

    local myHeal = CreateFrame("StatusBar", nil, clipFrame)
    myHeal:SetStatusBarTexture(texture)
    myHeal:SetStatusBarColor(0, 0.6, 0.3, 0.6)
    myHeal:SetFrameLevel(health:GetFrameLevel() + 1)

    local otherHeal = CreateFrame("StatusBar", nil, clipFrame)
    otherHeal:SetStatusBarTexture(texture)
    otherHeal:SetStatusBarColor(0, 0.6, 0, 0.6)
    otherHeal:SetFrameLevel(health:GetFrameLevel() + 1)

    local absorb = CreateFrame("StatusBar", nil, clipFrame)
    absorb:SetStatusBarTexture(texture)
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

-- ----------------------------------------------------------------------------
-- Update Wrappers (Called by Units.lua when DB changes)
-- ----------------------------------------------------------------------------

function UF:UpdateHealthBarSettings(frame)
    if not frame.Health then return end
    local db = RoithiUI.db.profile.UnitFrames[frame.unit]
    local texture = LSM:Fetch("statusbar", RoithiUI.db.profile.General.unitFrameBar or "Solid") or
        "Interface\\TargetingFrame\\UI-StatusBar"

    frame.Health:SetStatusBarTexture(texture)
    if frame.Health.bg then frame.Health.bg:SetTexture(texture) end

    -- Force update to re-color if needed
    local onShow = frame.Health:GetScript("OnShow")
    if onShow then onShow(frame.Health) end
end

function UF:UpdatePowerBarSettings(frame)
    if frame.UpdatePowerLayout then
        frame.UpdatePowerLayout()
    end
    if frame.UpdateAdditionalPowerLayout then
        frame.UpdateAdditionalPowerLayout()
    end
end
