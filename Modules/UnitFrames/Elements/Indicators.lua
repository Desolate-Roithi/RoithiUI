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

    -- 9. PvP Indicator
    local pvp = parent:CreateTexture(nil, "OVERLAY")
    pvp:SetSize(24, 24)
    pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-Neutral")
    pvp:Hide()
    frame.PvPIndicator = pvp

    -- 10. Quest Indicator
    local quest = parent:CreateTexture(nil, "OVERLAY")
    quest:SetSize(20, 20)
    quest:SetTexture("Interface\\TargetingFrame\\PortraitQuestBadge")
    quest:Hide()
    frame.QuestIndicator = quest

    -- 11. Tank / Assist Indicator
    local tankassist = parent:CreateTexture(nil, "OVERLAY")
    tankassist:SetSize(16, 16)
    tankassist:Hide()
    frame.TankAssistIndicator = tankassist

    -- Update Function
    local function GetIndicatorDB(key)
        if not RoithiUIDB then return nil end
        local db = RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[frame.unit]
        if not db or not db.indicators then return nil end
        return db.indicators[key]
    end

    local function IsEnabled(key)
        local db = GetIndicatorDB(key)
        if not db then return true end -- Default enabled if no DB
        if type(db) == "table" then return db.enabled ~= false end
        return db ~= false             -- Legacy boolean support
    end

    local function UpdateLayout()
        local db = RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[frame.unit] and
            RoithiUIDB.UnitFrames[frame.unit].indicators
        if not db then return end

        local anchorParent = frame.Health or frame

        local function ApplySettings(indicator, key, defaultSize, defaultPoint, defaultRel, defaultX, defaultY)
            if not indicator then return end
            local s = db[key]

            -- Normalize defaults
            defaultSize = defaultSize or 20
            defaultPoint = defaultPoint or "CENTER"
            defaultRel = defaultRel or defaultPoint
            defaultX = defaultX or 0
            defaultY = defaultY or 0

            if not s or type(s) ~= "table" then
                indicator:SetSize(defaultSize, defaultSize)
                indicator:ClearAllPoints()
                indicator:SetPoint(defaultPoint, anchorParent, defaultRel, defaultX, defaultY)
                return
            end

            indicator:SetSize(s.size or defaultSize, s.size or defaultSize)
            indicator:ClearAllPoints()
            local point = s.point or defaultPoint
            local relativePoint = s.relativePoint or s.point or defaultRel
            indicator:SetPoint(point, anchorParent, relativePoint, s.x or defaultX, s.y or defaultY)
        end

        ApplySettings(frame.CombatIndicator, "combat", 20, "CENTER", "BOTTOMLEFT", 0, 0)
        ApplySettings(frame.RestingIndicator, "resting", 20, "CENTER", "TOPLEFT", 0, 0)
        ApplySettings(frame.LeaderIndicator, "leader", 16, "TOPLEFT", nil, 0, 8)
        ApplySettings(frame.RaidTargetIndicator, "raidicon", 20, "CENTER", "TOP", 0, 5)
        ApplySettings(frame.ReadyCheckIndicator, "readycheck", 20, "CENTER", nil, 0, 0)
        ApplySettings(frame.RoleIndicator, "role", 16, "TOPLEFT", nil, 14, 8)
        ApplySettings(frame.PhaseIndicator, "phase", 22, "CENTER", nil, 0, 0)
        ApplySettings(frame.ResurrectIndicator, "resurrect", 24, "CENTER", nil, 0, 0)
        ApplySettings(frame.PvPIndicator, "pvp", 24, "CENTER", "TOPRIGHT", -10, 10)
        ApplySettings(frame.QuestIndicator, "quest", 20, "CENTER", "TOPLEFT", 10, 10)
        ApplySettings(frame.TankAssistIndicator, "tankassist", 16, "TOPLEFT", nil, 0, 16)
    end

    -- Expose UpdateLayout
    frame.UpdateIndicatorLayout = UpdateLayout

    local function UpdateIndicators()
        local unit = frame.unit
        local inTestMode = RoithiUIDB and RoithiUIDB.IndicatorTestMode

        if not frame.IndicatorLayoutApplying then
            frame.IndicatorLayoutApplying = true
            UpdateLayout()
            frame.IndicatorLayoutApplying = false
        end

        local function ShowIndicator(indicator, key, condition)
            if not indicator then return end
            if IsEnabled(key) and (condition or inTestMode) then
                -- Unit Specific Filtering
                if key == "resting" and unit ~= "player" then
                    indicator:Hide()
                    return
                end

                indicator:Show()
            else
                indicator:Hide()
            end
        end

        -- Resurrect
        ShowIndicator(res, "resurrect", UnitHasIncomingResurrection(unit))

        -- Phase
        ShowIndicator(phase, "phase", UnitPhaseReason(unit))

        -- Combat
        ShowIndicator(combat, "combat", UnitAffectingCombat(unit))

        -- Resting
        ShowIndicator(resting, "resting", unit == "player" and IsResting())

        -- Leader
        ShowIndicator(leader, "leader", UnitIsGroupLeader(unit))

        -- Raid Target
        local raidIndex = GetRaidTargetIndex(unit)
        if IsEnabled("raidicon") and (raidIndex or inTestMode) then
            SetRaidTargetIconTexture(raidDate, raidIndex or 1)
            raidDate:Show()
        else
            raidDate:Hide()
        end

        -- Role
        local roleType = UnitGroupRolesAssigned(unit)
        if IsEnabled("role") and (roleType ~= "NONE" or inTestMode) then
            local r = roleType == "NONE" and "TANK" or roleType -- Default to tank in test mode
            if r == "TANK" then
                role:SetTexCoord(0, 19 / 64, 22 / 64, 41 / 64)
            elseif r == "HEALER" then
                role:SetTexCoord(20 / 64, 39 / 64, 1 / 64, 20 / 64)
            elseif r == "DAMAGER" then
                role:SetTexCoord(20 / 64, 39 / 64, 22 / 64, 41 / 64)
            end
            role:Show()
        else
            role:Hide()
        end

        -- Ready Check
        local rcStatus = GetReadyCheckStatus(unit)
        if IsEnabled("readycheck") and (rcStatus or inTestMode) then
            local s = rcStatus or "ready"
            if s == "ready" then
                readyCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            elseif s == "notready" then
                readyCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
            elseif s == "waiting" then
                readyCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
            end
            readyCheck:Show()
        else
            readyCheck:Hide()
        end

        -- PvP
        local pvpType = UnitIsPVPFreeForAll(unit) and "FFA" or
        (UnitIsPVP(unit) and (UnitFactionGroup(unit) or "Neutral"))
        if _G.issecretvalue and _G.issecretvalue(pvpType) then pvpType = "Neutral" end -- Safety

        if IsEnabled("pvp") and (pvpType or inTestMode) then
            local faction = pvpType or (UnitFactionGroup("player") or "Neutral")
            if faction == "FFA" then
                pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
            elseif faction == "Alliance" then
                pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
            elseif faction == "Horde" then
                pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
            else
                pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-Neutral")
            end
            pvp:Show()
        else
            pvp:Hide()
        end

        -- Quest
        ShowIndicator(quest, "quest", UnitIsQuestBoss and UnitIsQuestBoss(unit))

        -- Tank / Assist
        local isTank = UnitIsGroupAssistant(unit) or UnitIsGroupLeader(unit) -- Simplified for now, or check real MT/MA
        -- Actually Blizzard has specific MT/MA flags in some APIs.
        -- Let's check UnitIsMainTank/UnitIsMainAssist if they exist (usually oUF or similar use them)
        local isMT = _G.UnitIsMainTank and _G.UnitIsMainTank(unit)
        local isMA = _G.UnitIsMainAssist and _G.UnitIsMainAssist(unit)

        if IsEnabled("tankassist") and (isMT or isMA or inTestMode) then
            if isMT or (inTestMode and not isMA) then
                tankassist:SetTexture("Interface\\GroupFrame\\UI-Group-MainTankIcon")
            else
                tankassist:SetTexture("Interface\\GroupFrame\\UI-Group-MainAssistIcon")
            end
            tankassist:Show()
        else
            tankassist:Hide()
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
