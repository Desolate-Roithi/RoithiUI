local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

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
    local LEM = LibStub("LibEditMode-Roithi", true)
    if LEM then
        -- We won't AddFrame immediately, but prepare for it?
        -- Actually, usually better to Add once.
        frame.Power.editModeName = (frame.editModeName or frame:GetName()) .. " Power"

        local defUnit = ns.Defaults.profile.UnitFrames[frame.unit] or ns.Defaults.profile.UnitFrames.player
        local defaults = {
            point = defUnit.powerPoint,
            x = defUnit.powerX,
            y = defUnit.powerY,
        }

        local function OnPowerPosChanged(f, layoutName, point, x, y)
            local unit = frame.unit
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]

            -- If not detached, ignore movement and enforce attached layout
            if not db or not db.powerDetached then
                -- Optional: Immediately snap back? Or just rely on UpdatePowerLayout
                if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
                return
            end

            if db then
                db.powerPoint = point
                db.powerX = x
                db.powerY = y
            end
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)

            local AL = ns.AttachmentLogic
            if AL then AL:GlobalLayoutRefresh(unit) end
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
                -- Force layout update to ensure SetMovable(false) is applied
                if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
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
        local AL = ns.AttachmentLogic
        if AL then
            AL:ApplyLayout(frame.unit, "Power")
        end

        local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[frame.unit]
        local height = db and db.powerHeight or 10
        local enabled = db and db.powerEnabled ~= false

        if not enabled then power:Hide() else power:Show() end

        -- Sync Edit Mode State from Parent Frame
        if frame.isInEditMode then
            power.isInEditMode = true
            power:SetAlpha(1)
        end
        power:SetHeight(height)
    end
    frame.UpdatePowerLayout = UpdatePowerLayout
    UpdatePowerLayout() -- Initial

    -- Update Logic (Main Power)
    local function UpdatePower(_)
        if power.isInEditMode then
            power:SetMinMaxValues(0, 100)
            power:SetValue(100)
            power:SetStatusBarColor(0, 0, 1)
            if power.Text then power.Text:Show() end
            return
        end
        if power.Text then power.Text:Hide() end

        local unit = frame.unit
        if unit == "player" then
            if (_G.UnitHasVehicleUI and _G.UnitHasVehicleUI("player")) or (_G.UnitInVehicle and _G.UnitInVehicle("player")) then
                if _G.UnitExists("vehicle") then
                    unit = "vehicle"
                end
            end
        end
        if not UnitExists(unit) then return end

        local db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[frame.unit]
        if db and db.powerEnabled == false then
            power:Hide()
            return
        end

        power:Show()

        local cur = UnitPower(unit)
        local max = UnitPowerMax(unit)
        power:SetMinMaxValues(0, max)
        power:SetValue(cur)

        local pTypeIndex, pToken = UnitPowerType(unit)
        local tokenSafe = pToken and not (ns.Utils and ns.Utils.IsSecret and ns.Utils.IsSecret(pToken))
        local indexSafe = pTypeIndex and not (ns.Utils and ns.Utils.IsSecret and ns.Utils.IsSecret(pTypeIndex))

        -- Safe Color Lookup
        local info = PowerBarColor and ((tokenSafe and PowerBarColor[pToken]) or (indexSafe and PowerBarColor[pTypeIndex]))
        if not info then
            info = (tokenSafe and DefaultPowerColors[pToken]) or (indexSafe and DefaultPowerColors[pTypeIndex]) or DefaultPowerColors["MANA"]
        end

        if info then
            power:SetStatusBarColor(info.r, info.g, info.b)
        else
            -- Debugging Color Failure
            local pName = UnitName(unit)
            if ns.Utils and ns.Utils.IsSecret and ns.Utils.IsSecret(pName) then pName = "?" end
            pName = pName or "?"
            local sType = indexSafe and tostring(pTypeIndex) or "?"
            local sToken = tokenSafe and tostring(pToken) or "?"
            RoithiUI:Log(string.format("Unit: %s | Type: %s (%s) | Info: Nil? Fallback to Blue.", pName,
                sType, sToken))
            if not DefaultPowerColors["RAGE"] then RoithiUI:Log("DefaultPowerColors[RAGE] is missing!") end

            power:SetStatusBarColor(0, 0, 1) -- Fallback Blue
        end
    end

    power:SetScript("OnEvent", UpdatePower)
    if frame.unit == "player" then
        power:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", "vehicle")
        power:RegisterUnitEvent("UNIT_MAXPOWER", "player", "vehicle")
        power:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", "vehicle")
        power:RegisterEvent("UNIT_ENTERED_VEHICLE")
        power:RegisterEvent("UNIT_EXITED_VEHICLE")
    else
        power:RegisterUnitEvent("UNIT_POWER_UPDATE", frame.unit)
        power:RegisterUnitEvent("UNIT_MAXPOWER", frame.unit)
        power:RegisterUnitEvent("UNIT_DISPLAYPOWER", frame.unit)
    end
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

-- 12.0 Heal Prediction Implementation (Event-driven, COMBAT-FRAME-BUDGET compliant)
function UF:CreateHealPrediction(frame)
    if not frame or frame.RoithiHealPrediction then return end
    local health = frame.Health or frame.SafeHealth
    if not health then return end
    local clipFrame = CreateFrame("Frame", nil, health)
    clipFrame:SetAllPoints()
    -- Safety wrap for older clients or environments where this might strict-error
    if clipFrame.SetClipsChildren then
        ns.Utils.SafeCall(clipFrame.SetClipsChildren, clipFrame, true)
    end
    health.ClipFrame = clipFrame

    local textureName = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.unitFrameBar) or
        (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.barTexture) or "Solid"
    local texture = LSM:Fetch("statusbar", textureName) or
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
    absorb:SetFrameLevel(health:GetFrameLevel() + 10)

    -- Over-absorb Glow
    local overAbsorbGlow = absorb:CreateTexture(nil, "OVERLAY")
    overAbsorbGlow:SetTexture("Interface\\RaidFrame\\Shield-Overshield-Glow")
    overAbsorbGlow:SetBlendMode("ADD")
    overAbsorbGlow:SetPoint("BOTTOMLEFT", absorb, "BOTTOMRIGHT", -7, 0)
    overAbsorbGlow:SetPoint("TOPLEFT", absorb, "TOPRIGHT", -7, 0)
    overAbsorbGlow:SetWidth(16)
    overAbsorbGlow:Hide()
    absorb.overGlow = overAbsorbGlow

    local healAbsorb = CreateFrame("StatusBar", nil, clipFrame)
    healAbsorb:SetStatusBarTexture(texture)
    -- Dark red for healing absorb
    healAbsorb:SetStatusBarColor(0.5, 0.0, 0.0, 0.7)
    healAbsorb:SetFrameLevel(health:GetFrameLevel() + 11)
    healAbsorb:SetReverseFill(true)
    healAbsorb:Hide()

    frame.RoithiHealPrediction = {
        myHeal = myHeal,
        otherHeal = otherHeal,
        absorb = absorb,
        healAbsorb = healAbsorb,
    }

    -- Using the Correct 12.0 API Usage
    ---@diagnostic disable-next-line: undefined-global
    if CreateUnitHealPredictionCalculator then
        ---@diagnostic disable-next-line: undefined-global
        local calculator = CreateUnitHealPredictionCalculator()

        local function SafeValOrZero(v)
            if v == nil then return 0 end
            if ns.Utils and ns.Utils.IsSecret and ns.Utils.IsSecret(v) then return v end
            return v
        end

        local function RunHealPredictionUpdate()
            if not frame.unit or not UnitExists(frame.unit) then return end
            ---@diagnostic disable-next-line: undefined-global
            UnitGetDetailedHealPrediction(frame.unit, "player", calculator)

            -- 1. Get Values
            local _, myIncomingHeal, otherIncomingHeal, _ = calculator:GetIncomingHeals()
            calculator:GetDamageAbsorbs()
            local healAbsorbAmount = calculator:GetHealAbsorbs() or 0

            local maxHealthVal = UnitHealthMax(frame.unit)
            local healthBar = frame.Health or frame.SafeHealth or health
            if not healthBar then return end
            local width = healthBar:GetWidth()
            if width <= 0 then return end

            -- Heal Logic (SetValue + Stacked)
            myHeal:SetWidth(width)
            myHeal:SetMinMaxValues(0, maxHealthVal)
            myHeal:SetValue(SafeValOrZero(myIncomingHeal))

            otherHeal:SetWidth(width)
            otherHeal:SetMinMaxValues(0, maxHealthVal)
            otherHeal:SetValue(SafeValOrZero(otherIncomingHeal))

            local healthTex = healthBar:GetStatusBarTexture()
            myHeal:ClearAllPoints()
            if healthTex then
                myHeal:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", 0, 0)
                myHeal:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", 0, 0)
            else
                myHeal:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
                myHeal:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", 0, 0)
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

            healAbsorb:SetWidth(width)
            healAbsorb:SetMinMaxValues(0, maxHealthVal)
            healAbsorb:SetValue(SafeValOrZero(healAbsorbAmount))
            healAbsorb:ClearAllPoints()
            if healthTex then
                healAbsorb:SetPoint("TOPRIGHT", healthTex, "TOPRIGHT", 0, 0)
                healAbsorb:SetPoint("BOTTOMRIGHT", healthTex, "BOTTOMRIGHT", 0, 0)
            else
                healAbsorb:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
                healAbsorb:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
            end
            healAbsorb:Show()

            local totalAbsorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(frame.unit) or 0

            absorb:ClearAllPoints()
            absorb:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
            absorb:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", 0, 0)

            absorb:SetWidth(width)

            local hMin, hMax = healthBar:GetMinMaxValues()
            absorb:SetMinMaxValues(hMin, hMax)
            absorb:SetValue(SafeValOrZero(totalAbsorb))
            absorb:Show()
            absorb:SetStatusBarColor(0.6, 0.8, 1, 0.6)
            overAbsorbGlow:Hide()
        end

        local listener = CreateFrame("Frame", nil, clipFrame)
        local function OnHealPredEvent(_, _, u)
            if u and frame.unit then
                if ns.Utils and ns.Utils.SafeUnitIsUnit then
                    local isMatch, isSecret = ns.Utils.SafeUnitIsUnit(u, frame.unit)
                    if not isMatch and not isSecret then return end
                elseif u ~= frame.unit then
                    return
                end
            end
            ns.Utils.SafeCall(RunHealPredictionUpdate)
        end
        listener:SetScript("OnEvent", OnHealPredEvent)

        if frame.unit and listener.RegisterUnitEvent then
            listener:RegisterUnitEvent("UNIT_HEAL_PREDICTION", frame.unit)
            listener:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", frame.unit)
            listener:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", frame.unit)
            listener:RegisterUnitEvent("UNIT_HEALTH", frame.unit)
            listener:RegisterUnitEvent("UNIT_MAXHEALTH", frame.unit)
        elseif frame.unit then
            listener:RegisterEvent("UNIT_HEAL_PREDICTION")
            listener:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
            listener:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
            listener:RegisterEvent("UNIT_HEALTH")
            listener:RegisterEvent("UNIT_MAXHEALTH")
        end

        if frame.unit == "target" then
            listener:RegisterEvent("PLAYER_TARGET_CHANGED")
        elseif frame.unit == "focus" then
            listener:RegisterEvent("PLAYER_FOCUS_CHANGED")
        elseif frame.unit == "targettarget" or frame.unit == "focustarget" or frame.unit == "pettarget" then
            listener:RegisterEvent("UNIT_TARGET")
        end

        frame:HookScript("OnShow", function() ns.Utils.SafeCall(RunHealPredictionUpdate) end)
        local hookHealth = frame.Health or frame.SafeHealth or health
        if hookHealth and hookHealth.HookScript then
            hookHealth:HookScript("OnSizeChanged", function() ns.Utils.SafeCall(RunHealPredictionUpdate) end)
        end

        ns.Utils.SafeCall(RunHealPredictionUpdate)
    end
end

-- ----------------------------------------------------------------------------
-- Update Wrappers (Called by Units.lua when DB changes)
-- ----------------------------------------------------------------------------

function UF:UpdateHealthBarSettings(frame)
    if not frame.Health then return end
    local textureName = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.unitFrameBar) or
        (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.barTexture) or "Solid"
    local texture = LSM:Fetch("statusbar", textureName) or
        "Interface\\TargetingFrame\\UI-StatusBar"

    frame.Health:SetStatusBarTexture(texture)
    if frame.Health.bg then frame.Health.bg:SetTexture(texture) end

    if frame.RoithiHealPrediction and type(frame.RoithiHealPrediction) == "table" then
        if frame.RoithiHealPrediction.myHeal then frame.RoithiHealPrediction.myHeal:SetStatusBarTexture(texture) end
        if frame.RoithiHealPrediction.otherHeal then frame.RoithiHealPrediction.otherHeal:SetStatusBarTexture(texture) end
        if frame.RoithiHealPrediction.absorb then frame.RoithiHealPrediction.absorb:SetStatusBarTexture(texture) end
        if frame.RoithiHealPrediction.healAbsorb then frame.RoithiHealPrediction.healAbsorb:SetStatusBarTexture(texture) end
    end

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
