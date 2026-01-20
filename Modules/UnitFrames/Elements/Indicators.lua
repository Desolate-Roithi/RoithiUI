local addonName, ns = ...
local RoithiUI = _G.RoithiUI

local UF = RoithiUI:GetModule("UnitFrames")

function UF:CreateIndicators(frame)
    local parent = frame.Health or frame

    -- 1. Combat Indicator (Swords)
    local combat = parent:CreateTexture(nil, "OVERLAY")
    combat:SetSize(20, 20)
    combat:SetPoint("CENTER", frame, "CENTER", 0, 0)         -- Centered on frame usually, or verify placement
    combat:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2) -- Alternate: Bottom Left?
    -- Let's put it on the edge
    combat:ClearAllPoints()
    combat:SetPoint("CENTER", frame, "BOTTOMLEFT", 0, 0)
    combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    combat:SetTexCoord(0.5, 1, 0, 0.49)
    combat:Hide()
    frame.CombatIndicator = combat

    -- 2. Resting Indicator (Zzz)
    local resting = parent:CreateTexture(nil, "OVERLAY")
    resting:SetSize(20, 20)
    resting:SetPoint("CENTER", frame, "TOPLEFT", 0, 0)
    resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    resting:SetTexCoord(0, 0.5, 0, 0.421875)
    resting:Hide()
    frame.RestingIndicator = resting

    -- 3. Leader Indicator (Crown)
    local leader = parent:CreateTexture(nil, "OVERLAY")
    leader:SetSize(16, 16)
    leader:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 8)
    leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    leader:Hide()
    frame.LeaderIndicator = leader

    -- 4. Raid Target Indicator (Skull, X, etc.)
    local raidDate = parent:CreateTexture(nil, "OVERLAY")
    raidDate:SetSize(20, 20)
    raidDate:SetPoint("CENTER", frame, "TOP", 0, 5)
    raidDate:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    raidDate:Hide()
    frame.RaidTargetIndicator = raidDate

    -- 5. Ready Check Indicator
    local readyCheck = parent:CreateTexture(nil, "OVERLAY")
    readyCheck:SetSize(20, 20)
    readyCheck:SetPoint("CENTER", frame, "CENTER", 0, 0)
    readyCheck:Hide()
    frame.ReadyCheckIndicator = readyCheck

    -- 6. Role Indicator
    local role = parent:CreateTexture(nil, "OVERLAY")
    role:SetSize(16, 16)
    role:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, 8) -- Offset from leader
    role:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    role:Hide()
    frame.RoleIndicator = role

    -- 7. Phase Indicator
    local phase = parent:CreateTexture(nil, "OVERLAY")
    phase:SetSize(22, 22)
    phase:SetPoint("CENTER", frame, "CENTER", 0, 0)
    phase:SetTexture("Interface\\TargetingFrame\\UI-PhasingIcon")
    phase:Hide()
    frame.PhaseIndicator = phase

    -- 8. Resurrect Indicator
    local res = parent:CreateTexture(nil, "OVERLAY")
    res:SetSize(24, 24)
    res:SetPoint("CENTER", frame, "CENTER", 0, 0)
    res:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
    res:Hide()
    frame.ResurrectIndicator = res

    -- Update Function
    local function IsEnabled(key)
        if not RoithiUIDB then return true end
        local db = RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[unit]
        if not db or not db.indicators then return true end
        return db.indicators[key] ~= false -- Default true
    end

    -- Update Function
    local function UpdateIndicators()
        local unit = frame.unit -- Refresh just in case

        -- Resurrect
        if IsEnabled("resurrect") and UnitHasIncomingResurrection(unit) then
            res:Show()
        else
            res:Hide()
        end

        -- Phase
        if IsEnabled("phase") and UnitPhaseReason(unit) then
            phase:Show()
        else
            phase:Hide()
        end

        -- Combat
        if IsEnabled("combat") and UnitAffectingCombat(unit) then
            combat:Show()
        else
            combat:Hide()
        end

        -- Resting (Player only typically)
        if IsEnabled("resting") and unit == "player" and IsResting() then
            resting:Show()
        else
            resting:Hide()
        end

        -- Leader
        if IsEnabled("leader") and UnitIsGroupLeader(unit) then
            leader:Show()
        else
            leader:Hide()
        end

        -- Raid Target
        local index = GetRaidTargetIndex(unit)
        if IsEnabled("raidicon") and index then
            SetRaidTargetIconTexture(raidDate, index)
            raidDate:Show()
        else
            raidDate:Hide()
        end

        -- Role
        local roleType = UnitGroupRolesAssigned(unit)
        if IsEnabled("role") then
            if roleType == "TANK" then
                role:SetTexCoord(0, 19 / 64, 22 / 64, 41 / 64)
                role:Show()
            elseif roleType == "HEALER" then
                role:SetTexCoord(20 / 64, 39 / 64, 1 / 64, 20 / 64)
                role:Show()
            elseif roleType == "DAMAGER" then
                role:SetTexCoord(20 / 64, 39 / 64, 22 / 64, 41 / 64)
                role:Show()
            else
                role:Hide()
            end
        else
            role:Hide()
        end

        -- Ready Check
        local status = GetReadyCheckStatus(unit)
        if IsEnabled("readycheck") and status then
            -- Logic simplified for brevity, assuming generic enablement sufficient
            -- Actually must replicate icon logic
            if status == "ready" then
                readyCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                readyCheck:Show()
            elseif status == "notready" then
                readyCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
                readyCheck:Show()
            elseif status == "waiting" then
                readyCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
                readyCheck:Show()
            else
                readyCheck:Hide()
            end
        else
            readyCheck:Hide()
        end
    end

    frame.UpdateIndicators = UpdateIndicators

    -- Event Hooks
    frame:HookScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "UNIT_FLAGS" then
            UpdateIndicators()
        elseif event == "PLAYER_UPDATE_RESTING" then
            UpdateIndicators()
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
            UpdateIndicators()
        elseif event == "RAID_TARGET_UPDATE" then
            UpdateIndicators()
        elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            UpdateIndicators()
        elseif event == "UNIT_PHASE" or event == "UNIT_CONNECTION" then
            UpdateIndicators()
        elseif event == "INCOMING_RESURRECT_CHANGED" then
            UpdateIndicators()
        end
    end)
    frame:HookScript("OnShow", UpdateIndicators)

    -- Register Events
    if frame.unit == "player" then
        frame:RegisterEvent("PLAYER_UPDATE_RESTING")
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("RAID_TARGET_UPDATE")
    frame:RegisterEvent("READY_CHECK")
    frame:RegisterEvent("READY_CHECK_CONFIRM")
    frame:RegisterEvent("READY_CHECK_FINISHED")
    if frame.unit then
        frame:RegisterUnitEvent("UNIT_FLAGS", frame.unit)
        frame:RegisterUnitEvent("UNIT_PHASE", frame.unit)
        frame:RegisterUnitEvent("UNIT_CONNECTION", frame.unit)
        frame:RegisterUnitEvent("INCOMING_RESURRECT_CHANGED", frame.unit)
    end

    -- Initial
    UpdateIndicators()
end
