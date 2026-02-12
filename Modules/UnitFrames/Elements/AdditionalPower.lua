local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

---@class UF : AceModule, AceAddon
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]

function UF:CreateAdditionalPower(frame)
    if frame.unit ~= "player" then return end

    local addPower = CreateFrame("StatusBar", nil, frame)
    addPower.editModeName = "Additional Power"                      -- Missing name fixed (Crash Fix)

    addPower:SetPoint("TOPLEFT", frame.Power, "BOTTOMLEFT", 0, -14) -- Default
    addPower:SetPoint("TOPRIGHT", frame.Power, "BOTTOMRIGHT", 0, -14)
    addPower:SetHeight(8)
    addPower:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")

    LibRoithi.mixins:CreateBackdrop(addPower)

    local bg = addPower:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1)
    addPower.bg = bg

    frame.AdditionalPower = addPower

    local function Update(self)
        -- Track previous state to trigger Castbar updates only on change
        local wasShown = addPower:IsShown()

        -- Check Logic: Is Enabled?
        local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[frame.unit]
        local isEnabled = db and (db.additionalPowerEnabled ~= false)

        if not isEnabled then
            addPower:Hide()
        else
            if frame.isInEditMode then
                addPower:Show()
                addPower:SetMinMaxValues(0, 100)
                addPower:SetValue(100)
                addPower:SetStatusBarColor(0, 0.5, 1) -- Visual Indication
                if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
            else
                local pType = UnitPowerType("player")
                local maxMana = UnitPowerMax("player", 0)
                local curMana = UnitPower("player", 0)

                -- Only show if primary resource is NOT Mana (pType ~= 0) AND we have Mana (max > 0)
                if pType ~= 0 then
                    -- 12.0.1 Safety: Check for Secret
                    local isSecret = C_Secrets and C_Secrets.IsSecret and C_Secrets.IsSecret(maxMana)
                    local hasMana = isSecret or (maxMana and maxMana > 0)

                    if hasMana then
                        addPower:Show()
                        addPower:SetMinMaxValues(0, maxMana)
                        addPower:SetValue(curMana)
                        addPower:SetStatusBarColor(0, 0.5, 1) -- Mana Blue

                        -- Ensure visibility affects layout
                        if frame.UpdateAdditionalPowerLayout and not frame.isInEditMode then
                            frame.UpdateAdditionalPowerLayout()
                        end
                    else
                        addPower:Hide()
                    end
                else
                    addPower:Hide()
                end
            end
        end

        -- Post-Update: Check for Visibility Change
        local isShown = addPower:IsShown()
        if wasShown ~= isShown then
            -- Visibility changed! Update Castbar Attachment
            if ns.SetCastbarAttachment then
                -- Check if Castbar is attached (not detached)
                local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[frame.unit]
                if cbDB and not cbDB.detached then
                    ns.SetCastbarAttachment(frame.unit, true)
                end
            end
        end
    end

    addPower:SetScript("OnEvent", Update)
    addPower:RegisterEvent("UNIT_POWER_UPDATE")
    addPower:RegisterEvent("UNIT_MAXPOWER")
    addPower:RegisterEvent("UNIT_DISPLAYPOWER")
    addPower:SetScript("OnShow", Update)

    Update()

    -- Layout Update Function (Delegated to AttachmentLogic)
    frame.UpdateAdditionalPowerLayout = function()
        local AL = ns.AttachmentLogic
        if AL then
            AL:ApplyLayout(frame.unit, "AdditionalPower")
        end

        -- Visibility / Height Fallback handling (if needed specific to AddPower)
        -- AL:ApplyLayout handles sizing and positioning.
        -- We just need to ensure visibility is correct via the Update function.
    end

    -- Edit Mode Registration
    local LEM = LibStub("LibEditMode-Roithi", true)
    if LEM then
        -- Name for Selection Overlay
        addPower.editModeName = "Additional Power"

        local defaults = { point = "CENTER", x = 0, y = -120 }

        local function OnPosChanged(f, layoutName, point, x, y)
            local unit = frame.unit
            local AL = ns.AttachmentLogic

            -- 1. Check Detached State via AL
            local isDetached = AL and AL:IsDetached(unit, "AdditionalPower")

            if not isDetached then
                -- Force layout update to ensure SetMovable(false) is applied
                if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
                return
            end

            -- 2. Save Positions if Detached
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]
            if db then
                db.additionalPowerPoint = point
                db.additionalPowerX = x
                db.additionalPowerY = y
            end

            -- 3. Move Frame
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)

            -- 4. Trigger Global Refresh
            if AL then AL:GlobalLayoutRefresh(unit) end
        end

        LEM:AddFrame(addPower, OnPosChanged, defaults)
        -- NOTE: Do NOT call SetMovable(true) here explicitly. AL:ApplyLayout will handle it.

        -- Custom Visibility for Edit Mode
        LEM:RegisterCallback('enter', function()
            local unit = frame.unit
            local AL = ns.AttachmentLogic
            local isDetached = AL and AL:IsDetached(unit, "AdditionalPower")

            if isDetached then
                addPower.isInEditMode = true
                addPower:Show()
                addPower:SetAlpha(1)
                -- Visuals
                addPower:SetMinMaxValues(0, 100)
                addPower:SetValue(100)
                addPower:SetStatusBarColor(0, 0.5, 1)
            else
                addPower.isInEditMode = false
                -- Force layout to ensure locked
                if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
            end
        end)

        LEM:RegisterCallback('exit', function()
            addPower.isInEditMode = false
            Update(addPower) -- Restore normal state
            if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
        end)
    end

    -- Hook updates
    frame:HookScript("OnEvent", function(self, event)
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_DISPLAYPOWER" or event == "UPDATE_SHAPESHIFT_FORM" then
            C_Timer.After(0.1, function() frame.UpdateAdditionalPowerLayout() end)
        end
    end)

    frame.UpdateAdditionalPowerSettings = Update -- Hook for Config
    frame.UpdateAdditionalPowerLayout()          -- Initial Layout Update
end

function UF:UpdateAdditionalPowerSettings(frame)
    if frame.UpdateAdditionalPowerSettings then
        frame.UpdateAdditionalPowerSettings(frame)
    end
end
