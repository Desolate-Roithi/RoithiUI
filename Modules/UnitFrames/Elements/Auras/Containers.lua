local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

---@class UF : AceModule, AceAddon
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]

local RADLog = function(fmt, ...) if ns.Auras and ns.Auras.RADLog then ns.Auras.RADLog(fmt, ...) end end
local GetUnitDB = function(unit) return ns.Auras and ns.Auras.GetUnitDB and ns.Auras.GetUnitDB(unit) end
local BuildCandidateFilters = function(db, fType) return ns.Auras and ns.Auras.BuildCandidateFilters and ns.Auras.BuildCandidateFilters(db, fType) end
local GetSmartFilterQueries = function(fType, db, unit) return ns.Auras and ns.Auras.GetSmartFilterQueries and ns.Auras.GetSmartFilterQueries(fType, db, unit) end
local FormatAuraButton = function(btn, key, isDebuff, size, db) if ns.Auras and ns.Auras.FormatAuraButton then ns.Auras.FormatAuraButton(btn, key, isDebuff, size, db) end end

-------------------------------------------------------------------------------
-- Container Key Maker
-------------------------------------------------------------------------------
local function MakeContainerKey(unit, containerSuffix)
    return "RoithiAuraContainer_" .. unit .. "_" .. containerSuffix
end

-------------------------------------------------------------------------------
-- 12.1.0 AuraContainer Builder for Player & Target
-------------------------------------------------------------------------------
local function GetOrCreateAuraContainer(unit, containerSuffix, parentFrame)
    local containerKey = MakeContainerKey(unit, containerSuffix)
    local container = UF.AuraContainers[containerKey]

    if not container then
        RADLog("[AuraFilter] Creating 12.1.0 AuraContainer [%s] for unit [%s]", containerKey, unit)

        -- Create native 12.1.0 AuraContainer
        container = CreateFrame("AuraContainer", containerKey, parentFrame or UIParent, "CustomAuraContainerTemplate")
        container.unit = unit
        container.containerKey = containerKey
        container.containerSuffix = containerSuffix

        UF.AuraContainers[containerKey] = container
    else
        container:SetParent(parentFrame or UIParent)
    end

    return container
end

-------------------------------------------------------------------------------
-- Configure Native 12.1.0 AuraContainer Frame (Exact 1:1 from Auras_12_1.lua)
-------------------------------------------------------------------------------
local function ConfigureAuraContainer(container, unit, containerSuffix)
    if not container then return end
    local db = GetUnitDB(unit)

    local isBuffs = (containerSuffix == "Buffs")
    local isDebuffs = (containerSuffix == "Debuffs")
    local isCombined = (containerSuffix == "Combined")

    local showBuffs = db.showBuffs ~= false
    local showDebuffs = db.showDebuffs ~= false

    local size = isCombined and (tonumber(db.auraSize) or 28)
                or (isDebuffs and (tonumber(db.debuffSize) or tonumber(db.auraSize) or 28)
                or (tonumber(db.buffSize) or tonumber(db.auraSize) or 28))
    local spacing = isCombined and (tonumber(db.auraSpacing) or 4)
                   or (isDebuffs and (tonumber(db.debuffSpacing) or tonumber(db.auraSpacing) or 4)
                   or (tonumber(db.buffSpacing) or tonumber(db.auraSpacing) or 4))
    local maxCount = isCombined and (tonumber(db.maxAuras) or 16)
                 or (isDebuffs and (tonumber(db.debuffMaxAuras) or tonumber(db.maxAuras) or 16)
                 or (tonumber(db.buffMaxAuras) or tonumber(db.maxAuras) or 16))
    local perRow = isCombined and (tonumber(db.aurasPerRow) or 8)
                or (isDebuffs and (tonumber(db.debuffsPerRow) or tonumber(db.aurasPerRow) or 8)
                or (tonumber(db.buffsPerRow) or tonumber(db.aurasPerRow) or 8))
    if perRow < 1 then perRow = 8 end
    if maxCount and maxCount > 0 and perRow > maxCount then perRow = maxCount end

    if container.SetMaxFrameCount then
        container:SetMaxFrameCount(maxCount)
    end

    local growDir = isDebuffs and (db.debuffGrowDirection or db.auraGrowDirection or "RIGHT_DOWN")
                   or (db.buffGrowDirection or db.auraGrowDirection or "RIGHT_DOWN")

    local isVerticalLayout = (growDir == "DOWN" or growDir == "UP" or growDir == "DOWN_RIGHT" or growDir == "DOWN_LEFT" or growDir == "UP_RIGHT" or growDir == "UP_LEFT" or growDir == "CENTER_VERTICAL" or growDir == "CENTER_VERT" or growDir == "VERTICAL" or growDir == "TOP_TO_BOTTOM" or growDir == "BOTTOM_TO_TOP")
    local axisVal = isVerticalLayout and 1 or 0
    local lineSizeVal = (perRow * size) + ((perRow - 1) * spacing)

    RADLog("Configuring Container [%s]: Size=%d, Spacing=%d, MaxCount=%d, PerRow=%d, GrowDir=%s", container.containerKey, size, spacing, maxCount, perRow, growDir)

    -- Force High Strata and Level so container renders above unitframe elements
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel(50)

    -- Debug Background texture (ONLY when /rad is active)
    if RoithiUI.AuraDebug then
        local cBg = container.DbgBg or container:CreateTexture(nil, "BACKGROUND", nil, -8)
        cBg:SetAllPoints(container)
        cBg:SetColorTexture(1, 0, 0, 0.3)
        cBg:Show()
        container.DbgBg = cBg
    elseif container.DbgBg then
        container.DbgBg:Hide()
    end

    -- Bind Unit to native AuraContainer
    if container.SetUnit then
        container:SetUnit(unit)
    end

    -- Enable AuraContainer so event registrations (UNIT_AURA) and updates are active
    if container.SetEnabled then
        container:SetEnabled(true)
    end

    -- Determine FlowLayout Anchor & Alignment parameters based on growDir option
    local layoutAnchor = "TOPLEFT"
    local isCenterHoriz = (growDir:find("CENTER_HORIZONTAL") or growDir == "CENTER_HORIZ")
    local isCenterVert = (growDir:find("CENTER_VERTICAL") or growDir == "CENTER_VERT")

    if growDir == "RIGHT_DOWN" or growDir == "DOWN" or growDir == "DOWN_RIGHT" or growDir == "TOP_TO_BOTTOM" or growDir == "RIGHT" then
        layoutAnchor = "TOPLEFT"
    elseif growDir == "RIGHT_UP" or growDir == "UP" or growDir == "UP_RIGHT" or growDir == "BOTTOM_TO_TOP" then
        layoutAnchor = "BOTTOMLEFT"
    elseif growDir == "LEFT_DOWN" or growDir == "DOWN_LEFT" or growDir == "LEFT" then
        layoutAnchor = "TOPRIGHT"
    elseif growDir == "LEFT_UP" or growDir == "UP_LEFT" then
        layoutAnchor = "BOTTOMRIGHT"
    elseif growDir == "CENTER_HORIZONTAL_UP" then
        layoutAnchor = "BOTTOMLEFT"
    elseif growDir == "CENTER_HORIZONTAL_DOWN" or isCenterHoriz then
        layoutAnchor = "TOPLEFT"
    elseif growDir == "CENTER_VERTICAL_LEFT" then
        layoutAnchor = "TOPRIGHT"
    elseif growDir == "CENTER_VERTICAL_RIGHT" or isCenterVert then
        layoutAnchor = "TOPLEFT"
    end

    -- Apply Container-Level FlowLayout Settings natively to C-Engine
    if container.SetFlowLayoutAxis then
        container:SetFlowLayoutAxis(axisVal)
    end
    if container.SetFlowLayoutAnchorPoint then
        container:SetFlowLayoutAnchorPoint(layoutAnchor)
    end
    if container.SetFlowLayoutGrowthDirection then
        local horizDir = (growDir:find("LEFT") and not growDir:find("RIGHT") and not (growDir == "CENTER_HORIZONTAL_DOWN" or growDir == "CENTER_HORIZONTAL_UP" or growDir == "CENTER_VERTICAL_RIGHT")) and -1 or 1
        local vertDir = (growDir == "RIGHT_UP" or growDir == "LEFT_UP" or growDir == "UP_RIGHT" or growDir == "UP_LEFT" or growDir == "CENTER_HORIZONTAL_UP" or growDir == "BOTTOM_TO_TOP" or layoutAnchor:find("BOTTOM")) and 1 or -1
        container:SetFlowLayoutGrowthDirection(horizDir, vertDir)
    end
    if container.SetFlowLayoutMaximumLineSize then
        container:SetFlowLayoutMaximumLineSize(lineSizeVal)
    end

    -- Global sort method & direction lookups
    local sortMethodVal = (_G.AuraContainerSortMethod and _G.AuraContainerSortMethod.Expiration) or 4
    local sortDirVal = (_G.AuraContainerSortDirection and _G.AuraContainerSortDirection.Normal) or 0

    local buffCandidateFilters = BuildCandidateFilters(db, "HELPFUL")
    local debuffCandidateFilters = BuildCandidateFilters(db, "HARMFUL")

    -- Dynamic AuraGroup management
    container.activeGroupKeys = container.activeGroupKeys or {}
    local newActiveGroupKeys = {}

    -- 1. Configure Buff AuraGroups
    if (isCombined or isBuffs) and showBuffs then
        local buffQueries = GetSmartFilterQueries("HELPFUL", db, unit)
        for idx, filterStr in ipairs(buffQueries) do
            local groupKey = "Buffs_" .. idx
            newActiveGroupKeys[groupKey] = true
            RADLog("Setting AuraGroup [%s] FilterString: %s", groupKey, filterStr)

            local groupLayout = {
                anchorPoint = layoutAnchor,
                layoutAxis = axisVal,
                maximumLineSize = lineSizeVal,
                elementSpacing = spacing,
                lineSpacing = spacing,
                forceNewLine = false,
                elementWidth = size,
                elementHeight = size,
            }

            if container.HasAuraGroup and container:HasAuraGroup(groupKey) then
                if container.SetAuraGroupFilterString then
                    container:SetAuraGroupFilterString(groupKey, filterStr)
                end
                if container.SetAuraGroupMaxFrameCount then
                    container:SetAuraGroupMaxFrameCount(groupKey, maxCount)
                end
                if container.SetAuraGroupLayout then
                    container:SetAuraGroupLayout(groupKey, groupLayout)
                end
                if container.SetAuraGroupCandidateFilters then
                    container:SetAuraGroupCandidateFilters(groupKey, buffCandidateFilters)
                end
                if container.SetAuraGroupSortMethod then
                    container:SetAuraGroupSortMethod(groupKey, sortMethodVal, sortDirVal)
                end
            else
                container:AddAuraGroup(groupKey, filterStr, {
                    maxFrameCount = maxCount,
                    sortMethod = sortMethodVal,
                    sortDirection = sortDirVal,
                    initializeFrame = function(auraButton)
                        FormatAuraButton(auraButton, container.containerKey, false, size, db)
                    end,
                    layout = groupLayout,
                    candidateFilters = buffCandidateFilters,
                })
            end

            if container.GetAuraGroupFrameCount then
                local count = container:GetAuraGroupFrameCount(groupKey)
                for i = 1, count do
                    local btn = container:GetAuraGroupFrame(groupKey, i)
                    if btn then FormatAuraButton(btn, container.containerKey, false, size, db) end
                end
            end
        end

        -- Additional Whitelisted Buffs group (ONLY if Whitelist has active spell IDs)
        local buffWLCandidateFilters = BuildCandidateFilters(db, "HELPFUL", true)
        if (db.additionalWhitelistBuffs or db.additionalWhitelist) and not db.onlyWhitelistBuffs and not db.onlyWhitelist and not db.showAllBuffs and buffWLCandidateFilters and buffWLCandidateFilters.includeSpellIDs then
            local groupKey = "Buffs_Whitelist"
            newActiveGroupKeys[groupKey] = true
            RADLog("Setting Additional Whitelist AuraGroup [%s]", groupKey)

            local groupLayout = {
                anchorPoint = layoutAnchor,
                layoutAxis = axisVal,
                maximumLineSize = lineSizeVal,
                elementSpacing = spacing,
                lineSpacing = spacing,
                forceNewLine = false,
                elementWidth = size,
                elementHeight = size,
            }

            if container.HasAuraGroup and container:HasAuraGroup(groupKey) then
                if container.SetAuraGroupFilterString then
                    container:SetAuraGroupFilterString(groupKey, "HELPFUL")
                end
                if container.SetAuraGroupMaxFrameCount then
                    container:SetAuraGroupMaxFrameCount(groupKey, maxCount)
                end
                if container.SetAuraGroupLayout then
                    container:SetAuraGroupLayout(groupKey, groupLayout)
                end
                if container.SetAuraGroupCandidateFilters then
                    container:SetAuraGroupCandidateFilters(groupKey, buffWLCandidateFilters)
                end
                if container.SetAuraGroupSortMethod then
                    container:SetAuraGroupSortMethod(groupKey, sortMethodVal, sortDirVal)
                end
            else
                container:AddAuraGroup(groupKey, "HELPFUL", {
                    maxFrameCount = maxCount,
                    sortMethod = sortMethodVal,
                    sortDirection = sortDirVal,
                    initializeFrame = function(auraButton)
                        auraButton.unit = unit
                        FormatAuraButton(auraButton, container.containerKey, false, size, db)
                    end,
                    layout = groupLayout,
                    candidateFilters = buffWLCandidateFilters,
                })
            end

            if container.GetAuraGroupFrameCount then
                local count = container:GetAuraGroupFrameCount(groupKey)
                for i = 1, count do
                    local btn = container:GetAuraGroupFrame(groupKey, i)
                    if btn then
                        btn.unit = unit
                        FormatAuraButton(btn, container.containerKey, false, size, db)
                    end
                end
            end
        end
    end

    -- 2. Configure Debuff AuraGroups
    if (isCombined or isDebuffs) and showDebuffs then
        local debuffQueries = GetSmartFilterQueries("HARMFUL", db, unit)
        for idx, filterStr in ipairs(debuffQueries) do
            local groupKey = "Debuffs_" .. idx
            newActiveGroupKeys[groupKey] = true
            RADLog("Setting AuraGroup [%s] FilterString: %s", groupKey, filterStr)

            local groupLayout = {
                anchorPoint = layoutAnchor,
                layoutAxis = axisVal,
                maximumLineSize = lineSizeVal,
                elementSpacing = spacing,
                lineSpacing = spacing,
                forceNewLine = false,
                elementWidth = size,
                elementHeight = size,
            }

            local debuffMaxCount = isCombined and math.max(0, maxCount - ((container.GetAuraGroupFrameCount and container:GetAuraGroupFrameCount("Buffs_1")) or 0)) or maxCount

            if container.HasAuraGroup and container:HasAuraGroup(groupKey) then
                if container.SetAuraGroupFilterString then
                    container:SetAuraGroupFilterString(groupKey, filterStr)
                end
                if container.SetAuraGroupMaxFrameCount then
                    container:SetAuraGroupMaxFrameCount(groupKey, debuffMaxCount)
                end
                if container.SetAuraGroupLayout then
                    container:SetAuraGroupLayout(groupKey, groupLayout)
                end
                if container.SetAuraGroupCandidateFilters then
                    container:SetAuraGroupCandidateFilters(groupKey, debuffCandidateFilters)
                end
                if container.SetAuraGroupSortMethod then
                    container:SetAuraGroupSortMethod(groupKey, sortMethodVal, sortDirVal)
                end
            else
                container:AddAuraGroup(groupKey, filterStr, {
                    maxFrameCount = debuffMaxCount,
                    sortMethod = sortMethodVal,
                    sortDirection = sortDirVal,
                    initializeFrame = function(auraButton)
                        auraButton.unit = unit
                        FormatAuraButton(auraButton, container.containerKey, true, size, db)
                    end,
                    layout = groupLayout,
                    candidateFilters = debuffCandidateFilters,
                })
            end

            if container.GetAuraGroupFrameCount then
                local count = container:GetAuraGroupFrameCount(groupKey)
                for i = 1, count do
                    local btn = container:GetAuraGroupFrame(groupKey, i)
                    if btn then
                        btn.unit = unit
                        FormatAuraButton(btn, container.containerKey, true, size, db)
                    end
                end
            end
        end

        -- Additional Whitelisted Debuffs group (ONLY if Whitelist has active spell IDs)
        local debuffWLCandidateFilters = BuildCandidateFilters(db, "HARMFUL", true)
        if (db.additionalWhitelistDebuffs or db.additionalWhitelist) and not db.onlyWhitelistDebuffs and not db.onlyWhitelist and not db.showAllDebuffs and debuffWLCandidateFilters and debuffWLCandidateFilters.includeSpellIDs then
            local groupKey = "Debuffs_Whitelist"
            newActiveGroupKeys[groupKey] = true
            RADLog("Setting Additional Whitelist AuraGroup [%s]", groupKey)

            local groupLayout = {
                anchorPoint = layoutAnchor,
                layoutAxis = axisVal,
                maximumLineSize = lineSizeVal,
                elementSpacing = spacing,
                lineSpacing = spacing,
                forceNewLine = false,
                elementWidth = size,
                elementHeight = size,
            }

            local debuffMaxCount = isCombined and math.max(0, maxCount - ((container.GetAuraGroupFrameCount and container:GetAuraGroupFrameCount("Buffs_1")) or 0)) or maxCount
            local debuffWLCandidateFilters = BuildCandidateFilters(db, "HARMFUL", true)

            if container.HasAuraGroup and container:HasAuraGroup(groupKey) then
                if container.SetAuraGroupFilterString then
                    container:SetAuraGroupFilterString(groupKey, "HARMFUL")
                end
                if container.SetAuraGroupMaxFrameCount then
                    container:SetAuraGroupMaxFrameCount(groupKey, debuffMaxCount)
                end
                if container.SetAuraGroupLayout then
                    container:SetAuraGroupLayout(groupKey, groupLayout)
                end
                if container.SetAuraGroupCandidateFilters then
                    container:SetAuraGroupCandidateFilters(groupKey, debuffWLCandidateFilters)
                end
                if container.SetAuraGroupSortMethod then
                    container:SetAuraGroupSortMethod(groupKey, sortMethodVal, sortDirVal)
                end
            else
                container:AddAuraGroup(groupKey, "HARMFUL", {
                    maxFrameCount = debuffMaxCount,
                    sortMethod = sortMethodVal,
                    sortDirection = sortDirVal,
                    initializeFrame = function(auraButton)
                        auraButton.unit = unit
                        FormatAuraButton(auraButton, container.containerKey, true, size, db)
                    end,
                    layout = groupLayout,
                    candidateFilters = debuffWLCandidateFilters,
                })
            end

            if container.GetAuraGroupFrameCount then
                local count = container:GetAuraGroupFrameCount(groupKey)
                for i = 1, count do
                    local btn = container:GetAuraGroupFrame(groupKey, i)
                    if btn then
                        btn.unit = unit
                        FormatAuraButton(btn, container.containerKey, true, size, db)
                    end
                end
            end
        end
    end

    if isCombined and container.SetAuraGroupMaxFrameCount then
        if not container.hookedCombinedCap then
            container.hookedCombinedCap = true
            if container.OnLayoutComplete then
                hooksecurefunc(container, "OnLayoutComplete", function(self)
                    if self.GetAuraGroupFrameCount and self.HasAuraGroup and self:HasAuraGroup("Debuffs_1") then
                        local bCount = self:GetAuraGroupFrameCount("Buffs_1") or 0
                        local targetDebuffMax = math.max(0, maxCount - bCount)
                        self:SetAuraGroupMaxFrameCount("Debuffs_1", targetDebuffMax)
                    end
                end)
            end
        end
    end

    -- 3. Clean up inactive AuraGroups by reconfiguring them to match 0 auras
    for oldKey in pairs(container.activeGroupKeys) do
        if not newActiveGroupKeys[oldKey] and container.HasAuraGroup and container:HasAuraGroup(oldKey) then
            RADLog("Filtering away inactive AuraGroup [%s] from container [%s]", oldKey, container.containerKey)
            if container.SetAuraGroupMaxFrameCount then
                container:SetAuraGroupMaxFrameCount(oldKey, 0)
            end
            if container.SetAuraGroupCandidateFilters then
                container:SetAuraGroupCandidateFilters(oldKey, { includeSpellIDs = { [0] = true } })
            end
        end
    end
    container.activeGroupKeys = newActiveGroupKeys

    -- Mark dirty then immediately process synchronously so aura frames are
    -- released/re-acquired RIGHT NOW rather than waiting for the next OnUpdate
    -- tick (which only runs when the container is visible: RunWhenVisibleOnce).
    if container.UpdateAllAuras then
        container:UpdateAllAuras()
    end
    if container.ProcessDirtyFlags then
        container:ProcessDirtyFlags()
    end

    -- Explicitly anchor container relative to unitframe parent or restored drag position
    local parent = container.parentFrame or container:GetParent() or UIParent

    -- Dynamic Multi-Row Container Dimension Recalculation
    local activeFrameCount = 0
    if container.GetAuraGroupFrameCount then
        for groupKey in pairs(container.activeGroupKeys) do
            activeFrameCount = activeFrameCount + (container:GetAuraGroupFrameCount(groupKey) or 0)
        end
    end

    -- Edit Mode Visualization & Interactivity
    local isDetached = isDebuffs and (db.debuffDetached == true)
                    or isBuffs and (db.buffDetached == true)
                    or (db.auraDetached == true)

    local LEM = LibStub("LibEditMode-Roithi", true)
    local parentIsShown = parent and (parent == UIParent or parent:IsShown() or isDetached)
    local isEditMode = parentIsShown and ((parent and (parent.isInEditMode or parent.forceShowEditMode or parent.forceShowTest))
                    or (_G.EditModeManagerFrame and _G.EditModeManagerFrame.IsShown and _G.EditModeManagerFrame:IsShown())
                    or (LEM and LEM.isEditMode))

    local sampleDisplayCount = isCombined and math.min(maxCount, 10) or math.min(maxCount, 5)
    local currentCount = isEditMode and sampleDisplayCount or (activeFrameCount > 0 and activeFrameCount or 1)

    local cols = isVerticalLayout and math.ceil((currentCount > 0 and currentCount or 1) / perRow)
                 or math.min(currentCount > 0 and currentCount or 1, perRow)
    local rows = isVerticalLayout and math.min(currentCount > 0 and currentCount or 1, perRow)
                 or math.ceil((currentCount > 0 and currentCount or 1) / perRow)

    local calcWidth = cols * size + (cols - 1) * spacing
    local calcHeight = rows * size + (rows - 1) * spacing
    container:SetSize(math.max(calcWidth, size), math.max(calcHeight, size))

    container:ClearAllPoints()

    local hasSavedPos = false
    if isDetached then
        local savedPt = (containerSuffix == "Buffs" and db.buffScreenPoint)
                     or (containerSuffix == "Debuffs" and db.debuffScreenPoint)
                     or (containerSuffix == "Combined" and db.auraScreenPoint) or "TOPLEFT"
        local px = (containerSuffix == "Buffs" and db.buffScreenX)
                or (containerSuffix == "Debuffs" and db.debuffScreenX)
                or (containerSuffix == "Combined" and db.auraScreenX) or 0
        local py = (containerSuffix == "Buffs" and db.buffScreenY)
                or (containerSuffix == "Debuffs" and db.debuffScreenY)
                or (containerSuffix == "Combined" and db.auraScreenY) or 0

        local isSec = issecretvalue and (issecretvalue(savedPt) or issecretvalue(px) or issecretvalue(py))
        if not isSec then
            local ok = pcall(container.SetPoint, container, savedPt, UIParent, savedPt, px, py)
            if ok then
                hasSavedPos = true
                container.roithiSavedPoint = savedPt
                container.roithiSavedRelPoint = savedPt
                container.roithiSavedX = px
                container.roithiSavedY = py
            end
        end
    end

    if not hasSavedPos then
        local userAnchor = isDebuffs and db.debuffAnchor
                        or isBuffs and db.buffAnchor
                        or db.auraAnchor or (unit == "target" and "TOPLEFT" or "BOTTOMLEFT")

        local userX = isCombined and (tonumber(db.auraX) or tonumber(db.auraXOffset) or 0)
                   or (isDebuffs and (tonumber(db.debuffX) or tonumber(db.debuffXOffset) or tonumber(db.auraX) or 0)
                   or (tonumber(db.buffX) or tonumber(db.buffXOffset) or tonumber(db.auraX) or 0))

        local userY = isCombined and (tonumber(db.auraY) or tonumber(db.auraYOffset) or 0)
                   or (isDebuffs and (tonumber(db.debuffY) or tonumber(db.debuffYOffset) or tonumber(db.auraY) or (unit == "target" and -10 or 10))
                   or (tonumber(db.buffY) or tonumber(db.buffYOffset) or tonumber(db.auraY) or (unit == "target" and -45 or 10)))

        local anchorFrame = parent

        if isDebuffs and db.separateAuras and db.debuffAnchorToBuffs then
            local buffContainer = UF.AuraContainers["RoithiAuraContainer_" .. unit .. "_Buffs"]
            if buffContainer and buffContainer:IsShown() then
                anchorFrame = buffContainer
            end
        end

        local containerPoint = layoutAnchor or userAnchor
        local targetRelPoint = userAnchor

        if isCenterHoriz then
            if userAnchor:find("TOP") then
                containerPoint = "TOP"
            elseif userAnchor:find("BOTTOM") then
                containerPoint = "BOTTOM"
            else
                containerPoint = "CENTER"
            end
        elseif isCenterVert then
            if userAnchor:find("RIGHT") then
                containerPoint = "RIGHT"
            elseif userAnchor:find("LEFT") then
                containerPoint = "LEFT"
            else
                containerPoint = "CENTER"
            end
        end

        container:SetPoint(containerPoint, anchorFrame, targetRelPoint, userX, userY)
        -- Store for re-application after ProcessDirtyFlags (Edit Mode only)
        container.roithiContainerPoint = containerPoint
        container.roithiAnchorFrame = anchorFrame
        container.roithiTargetRelPoint = targetRelPoint
        container.roithiUserX = userX
        container.roithiUserY = userY
        container.roithiSavedPoint = containerPoint
        container.roithiSavedRelPoint = targetRelPoint
        container.roithiSavedX = userX
        container.roithiSavedY = userY
        container.roithiIsCentered = isCenterHoriz or isCenterVert
        container.roithiCalcWidth = calcWidth
        container.roithiCalcHeight = calcHeight
        container.roithiIsEditMode = isEditMode
    end

    ---------------------------------------------------------------------------
    -- Edit Mode Visualization via AuraMover
    ---------------------------------------------------------------------------
    local UpdateAuraMover = ns.Auras and ns.Auras.UpdateAuraMover
    if UpdateAuraMover then
        UpdateAuraMover(
            container, unit, containerSuffix,
            calcWidth, calcHeight, size, spacing, perRow,
            layoutAnchor, growDir, isVerticalLayout,
            isCenterHoriz, isCenterVert, isCombined,
            isEditMode, isDetached, db
        )
    end

    if isEditMode then
        container:Hide()
    elseif (isBuffs and not showBuffs) or (isDebuffs and not showDebuffs) then
        container:Hide()
    else
        container:Show()
    end

    if container.ProcessDirtyFlags then
        container:ProcessDirtyFlags()
    elseif container.UpdateAllAuras then
        container:UpdateAllAuras()
    end
end

-------------------------------------------------------------------------------
-- Container Frame Flush Helper
-------------------------------------------------------------------------------
local function FlushContainerFrames(cFrame)
    if not cFrame then return end
    if cFrame.activeGroupKeys then
        for key in pairs(cFrame.activeGroupKeys) do
            if cFrame.HasAuraGroup and cFrame:HasAuraGroup(key) then
                if cFrame.SetAuraGroupMaxFrameCount then cFrame:SetAuraGroupMaxFrameCount(key, 0) end
                if cFrame.SetAuraGroupCandidateFilters then cFrame:SetAuraGroupCandidateFilters(key, { includeSpellIDs = { [0] = true } }) end
            end
        end
        cFrame.activeGroupKeys = {}
    end
    if cFrame.SetEnabled then cFrame:SetEnabled(false) end
    cFrame:Hide()
    if cFrame.AuraMover then cFrame.AuraMover:Hide() end
    if cFrame.UpdateAllAuras then cFrame:UpdateAllAuras() end
    if cFrame.ProcessDirtyFlags then cFrame:ProcessDirtyFlags() end
end

-------------------------------------------------------------------------------
-- Sub-Module Function Exports
-------------------------------------------------------------------------------
ns.Auras = ns.Auras or {}
ns.Auras.MakeContainerKey = MakeContainerKey
ns.Auras.GetOrCreateAuraContainer = GetOrCreateAuraContainer
ns.Auras.ConfigureAuraContainer = ConfigureAuraContainer
ns.Auras.FlushContainerFrames = FlushContainerFrames
