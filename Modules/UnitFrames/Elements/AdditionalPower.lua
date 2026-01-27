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

    -- Layout Update Function (Dynamic Anchoring)
    -- This ensures we sit below the "lowest" visible element
    frame.UpdateAdditionalPowerLayout = function()
        -- Get DB
        local db
        if RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[frame.unit] then
            db = RoithiUI.db.profile.UnitFrames[frame.unit]
        else
            return
        end

        local detached = db.additionalPowerDetached

        if frame.isInEditMode then
            addPower.isInEditMode = true
        end

        local height = db.additionalPowerHeight or 10
        addPower:SetHeight(height)

        if detached then
            addPower:SetParent(UIParent)
            local point = db.additionalPowerPoint or "CENTER"
            local x = db.additionalPowerX or 0
            local y = db.additionalPowerY or -120
            addPower:ClearAllPoints()
            addPower:SetPoint(point, UIParent, point, x, y)

            local width = db.additionalPowerWidth or frame:GetWidth()
            addPower:SetWidth(width)
        else
            addPower:SetParent(frame)
            addPower:ClearAllPoints()
            addPower:SetWidth(frame:GetWidth())

            -- Anchoring Logic: Lowest Visible Bar
            local cp = frame.ClassPower
            local p = frame.Power
            local spacing = 4

            local cpVisible = cp and cp:IsShown()
            local pVisible = p and p:IsShown()

            -- Check detached states of parents
            local pDetached = db.powerDetached
            local cpDetached = db.classPowerDetached

            -- Logic:
            -- 1. If CP is attached and visible, anchor to CP. (CP is assumed below Power if Power attached)
            -- 2. Else if Power is attached and visible, anchor to Power.
            -- 3. Else anchor to Frame.

            if cpVisible and not cpDetached then
                -- CP is here. CP anchors to Power (if att) or Frame?
                -- CP logic: attached to Power.
                -- If Power is DETACHED, CP follows it (usually).
                -- User rule: "if primary power is detached, class power should stay attached to this bar [primary power]"
                -- So if Power is detached, CP is with it.
                -- User rule: "additional power should stay attached to the health frame unless its detached by itself"
                -- So AP stays with Health.

                -- So if Power (and thus CP) is DETACHED, AP is alone on Frame.
                if pDetached then
                    addPower:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -spacing)
                    addPower:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -spacing)
                else
                    -- Power is ATTACHED. CP is ATTACHED (to Power).
                    -- So we anchor to CP.
                    addPower:SetPoint("TOPLEFT", cp, "BOTTOMLEFT", 0, -spacing)
                    addPower:SetPoint("TOPRIGHT", cp, "BOTTOMRIGHT", 0, -spacing)
                end
            elseif pVisible and not pDetached then
                -- CP Hidden or Detached. Power is here.
                -- Anchor to Power.
                addPower:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -spacing)
                addPower:SetPoint("TOPRIGHT", p, "BOTTOMRIGHT", 0, -spacing)
            else
                -- Power Hidden or Detached.
                -- Anchor to Frame.
                addPower:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -spacing)
                addPower:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -spacing)
            end
        end
    end

    -- Edit Mode Registration
    local LEM = LibStub("LibEditMode", true)
    if LEM then
        -- Name for Selection Overlay
        addPower.editModeName = "Additional Power"

        local defaults = { point = "CENTER", x = 0, y = -120 }

        local function OnPosChanged(f, layoutName, point, x, y)
            local unit = frame.unit
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]

            -- If not detached, ignore movement and enforce attached layout
            if not db or not db.additionalPowerDetached then
                f:ClearAllPoints()
                if frame.ClassPower and frame.ClassPower:IsShown() then
                    f:SetParent(frame.ClassPower)
                    f:SetPoint("TOPLEFT", frame.ClassPower, "BOTTOMLEFT", 0, -4)
                    f:SetPoint("TOPRIGHT", frame.ClassPower, "BOTTOMRIGHT", 0, -4)
                else
                    f:SetParent(frame.Power)
                    f:SetPoint("TOPLEFT", frame.Power, "BOTTOMLEFT", 0, -4)
                    f:SetPoint("TOPRIGHT", frame.Power, "BOTTOMRIGHT", 0, -4)
                end
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

        LEM:AddFrame(addPower, OnPosChanged, defaults)
        addPower:SetMovable(true)

        LEM:RegisterCallback('enter', function()
            addPower.isInEditMode = true
            addPower:Show()
            addPower:SetStatusBarColor(0, 0.5, 1)
            addPower:SetValue(UnitPowerMax("player", 0))
            frame.UpdateAdditionalPowerLayout() -- Force check layout
        end)

        LEM:RegisterCallback('exit', function()
            addPower.isInEditMode = false
            Update()
            frame.UpdateAdditionalPowerLayout()
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
