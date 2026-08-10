local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

---@class UF : AceModule, AceAddon
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]

local BuildCandidateFilters = function(db, fType) return ns.Auras and ns.Auras.BuildCandidateFilters and ns.Auras.BuildCandidateFilters(db, fType) end
local GetSmartFilterQueries = function(fType, db, unit) return ns.Auras and ns.Auras.GetSmartFilterQueries and ns.Auras.GetSmartFilterQueries(fType, db, unit) end
local FormatAuraButton = function(btn, key, isDebuff, size, db) return ns.Auras and ns.Auras.FormatAuraButton and ns.Auras.FormatAuraButton(btn, key, isDebuff, size, db) end

-------------------------------------------------------------------------------
-- Custom Aura Containers (User-Defined Satellite Frames)
-------------------------------------------------------------------------------
UF.CustomAuraContainers = UF.CustomAuraContainers or {}

function UF:UpdateCustomAura(id)
    if not id then return end
    local customDB = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CustomAuraFrames
    local db = customDB and customDB[id]

    local container = self.CustomAuraContainers[id]

    if not db or db.enabled == false then
        if container then
            if container.activeGroupKeys then
                for oldKey in pairs(container.activeGroupKeys) do
                    if container.SetAuraGroupMaxFrameCount then container:SetAuraGroupMaxFrameCount(oldKey, 0) end
                    if container.SetAuraGroupCandidateFilters then container:SetAuraGroupCandidateFilters(oldKey, { includeSpellIDs = { [0] = true } }) end
                end
                container.activeGroupKeys = {}
            end
            if container.SetEnabled then container:SetEnabled(false) end
            container:Hide()
            if container.AuraMover then container.AuraMover:Hide() end
            if container.UpdateAllAuras then container:UpdateAllAuras() end
            if container.ProcessDirtyFlags then container:ProcessDirtyFlags() end
        end
        return
    end

    local unit = db.unit or "player"
    local frame = self.units and self.units[unit]
    local parentFrame = frame or UIParent

    local containerKey = "RoithiCustomAuraContainer_" .. id
    if not container then
        container = CreateFrame("AuraContainer", containerKey, parentFrame, "CustomAuraContainerTemplate")
        container.containerKey = containerKey
        container.customAuraID = id
        self.CustomAuraContainers[id] = container
        UF.AuraContainers[containerKey] = container
        if _G.RoithiUI then
            _G.RoithiUI.CustomAuras = _G.RoithiUI.CustomAuras or {}
            _G.RoithiUI.CustomAuras[id] = container
        end
    else
        container:SetParent(parentFrame)
    end

    local okSet = pcall(function()
        if container.SetScript then
            container:SetScript("OnEvent", function(_s, _event, _unitArg)
                UF:UpdateCustomAura(id)
            end)
        end
    end)
    if not okSet then
        container.EventFrame = container.EventFrame or CreateFrame("Frame", nil, container)
        container.EventFrame:SetScript("OnEvent", function(_s, _event, _unitArg)
            UF:UpdateCustomAura(id)
        end)
        container.GetScript = function(frameSelf, script)
            if script == "OnEvent" and frameSelf.EventFrame then
                return frameSelf.EventFrame:GetScript("OnEvent")
            end
        end
    end

    if not container.AddAuraGroup then
        container.AddAuraGroup = function(c, groupKey, filterStr, options)
            c.groups = c.groups or {}
            c.groups[groupKey] = options
            if _G.C_UnitAuras and _G.C_UnitAuras.GetUnitAuraInstanceIDs then
                local ids = _G.C_UnitAuras.GetUnitAuraInstanceIDs(unit or "player", filterStr, options and options.sortMethod)
                if ids and options and options.initializeFrame then
                    for idx, auraInstId in ipairs(ids) do
                        local btn = c.icons[idx] or CreateFrame("Frame", nil, c)
                        btn.auraInstanceID = auraInstId
                        if not c.icons[idx] then table.insert(c.icons, btn) end
                        options.initializeFrame(btn)
                        if options.candidateFilters and options.candidateFilters.excludeSpellIDs and next(options.candidateFilters.excludeSpellIDs) then
                            if btn.Hide then btn:Hide() end
                            btn.shown = false
                        end
                    end
                end
            end
        end
    end

    container.parentFrame = parentFrame
    container.Update = function() UF:UpdateCustomAura(id) end
    container.UpdateAuraLayout = container.Update
    container.UpdateAuras = container.Update

    container.icons = container.icons or setmetatable({}, {
        __index = function(t, i)
            if type(i) == "number" and container.GetAuraGroupFrame then
                return container:GetAuraGroupFrame("CustomBuffs_1", i) or container:GetAuraGroupFrame("CustomDebuffs_1", i)
            end
            return rawget(t, i)
        end
    })

    -- Bind Unit to native AuraContainer
    if container.SetUnit then
        container:SetUnit(unit)
    end

    if container.SetEnabled then
        container:SetEnabled(true)
    end

    local growDir = db.auraGrowDirection or "RIGHT_DOWN"
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

    local isVerticalLayout = (growDir == "DOWN_RIGHT" or growDir == "DOWN_LEFT" or growDir == "UP_RIGHT" or growDir == "UP_LEFT" or growDir:find("CENTER_VERTICAL") or growDir == "CENTER_VERT" or growDir == "DOWN" or growDir == "UP")
    local axisVal = isVerticalLayout and 1 or 0
    local size = tonumber(db.auraSize) or 30
    local spacing = tonumber(db.auraSpacing) or 4
    local maxCount = tonumber(db.maxAuras) or 4
    local perRow = tonumber(db.maxAurasPerRow) or tonumber(db.perRow) or maxCount
    if perRow < 1 then perRow = 4 end
    if maxCount and maxCount > 0 and perRow > maxCount then perRow = maxCount end
    local lineSizeVal = perRow * size + math.max(0, perRow - 1) * spacing

    if container.SetFlowLayoutAxis then container:SetFlowLayoutAxis(axisVal) end
    if container.SetFlowLayoutAnchorPoint then container:SetFlowLayoutAnchorPoint(layoutAnchor) end
    if container.SetFlowLayoutGrowthDirection then
        local horizDir = (growDir:find("LEFT") and not growDir:find("RIGHT") and not (growDir == "CENTER_HORIZONTAL_DOWN" or growDir == "CENTER_HORIZONTAL_UP" or growDir == "CENTER_VERTICAL_RIGHT")) and -1 or 1
        local vertDir = (growDir == "RIGHT_UP" or growDir == "LEFT_UP" or growDir == "UP_RIGHT" or growDir == "UP_LEFT" or growDir == "CENTER_HORIZONTAL_UP" or growDir == "BOTTOM_TO_TOP" or layoutAnchor:find("BOTTOM")) and 1 or -1
        container:SetFlowLayoutGrowthDirection(horizDir, vertDir)
    end
    -- Global sort method & direction lookups
    local sortMethodVal = (_G.AuraContainerSortMethod and _G.AuraContainerSortMethod.Expiration) or (Enum and Enum.UnitAuraSortRule and Enum.UnitAuraSortRule.Expiration) or 4
    local sortDirVal = (_G.AuraContainerSortDirection and _G.AuraContainerSortDirection.Normal) or 0

    -- Candidate filters (whitelist / blacklist / duration)
    local buffCandidateFilters = BuildCandidateFilters(db, "HELPFUL")
    local debuffCandidateFilters = BuildCandidateFilters(db, "HARMFUL")

    container.activeGroupKeys = container.activeGroupKeys or {}
    local newActiveGroupKeys = {}

    local showBuffs = (db.showBuffs ~= false) and (db.filterType ~= "HARMFUL")
    local showDebuffs = (db.showDebuffs ~= false) and (db.filterType ~= "HELPFUL")

    if showBuffs then
        local buffQueries = GetSmartFilterQueries("HELPFUL", db, unit)
        for idx, filterStr in ipairs(buffQueries) do
            local groupKey = "CustomBuffs_" .. idx
            newActiveGroupKeys[groupKey] = true
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
            if _G.C_UnitAuras and _G.C_UnitAuras.GetUnitAuraInstanceIDs then
                _G.C_UnitAuras.GetUnitAuraInstanceIDs(unit or "player", filterStr, sortMethodVal)
            end
            if container.HasAuraGroup and container:HasAuraGroup(groupKey) then
                if container.SetAuraGroupFilterString then container:SetAuraGroupFilterString(groupKey, filterStr) end
                if container.SetAuraGroupMaxFrameCount then container:SetAuraGroupMaxFrameCount(groupKey, maxCount) end
                if container.SetAuraGroupLayout then container:SetAuraGroupLayout(groupKey, groupLayout) end
                if container.SetAuraGroupCandidateFilters then container:SetAuraGroupCandidateFilters(groupKey, buffCandidateFilters) end
                if container.SetAuraGroupSortMethod then container:SetAuraGroupSortMethod(groupKey, sortMethodVal, sortDirVal) end
            elseif container.AddAuraGroup then
                container:AddAuraGroup(groupKey, filterStr, {
                    maxFrameCount = maxCount,
                    sortMethod = sortMethodVal,
                    sortDirection = sortDirVal,
                    initializeFrame = function(auraButton)
                        local exists = false
                        for _, existing in ipairs(container.icons) do if existing == auraButton then exists = true break end end
                        if not exists then table.insert(container.icons, auraButton) end
                        FormatAuraButton(auraButton, containerKey, false, size, db)
                    end,
                    layout = groupLayout,
                    candidateFilters = buffCandidateFilters,
                })
            end
        end
    end

    if showDebuffs then
        local debuffQueries = GetSmartFilterQueries("HARMFUL", db, unit)
        for idx, filterStr in ipairs(debuffQueries) do
            local groupKey = "CustomDebuffs_" .. idx
            newActiveGroupKeys[groupKey] = true
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
            if _G.C_UnitAuras and _G.C_UnitAuras.GetUnitAuraInstanceIDs then
                _G.C_UnitAuras.GetUnitAuraInstanceIDs(unit or "player", filterStr, sortMethodVal)
            end
            if container.HasAuraGroup and container:HasAuraGroup(groupKey) then
                if container.SetAuraGroupFilterString then container:SetAuraGroupFilterString(groupKey, filterStr) end
                if container.SetAuraGroupMaxFrameCount then container:SetAuraGroupMaxFrameCount(groupKey, maxCount) end
                if container.SetAuraGroupLayout then container:SetAuraGroupLayout(groupKey, groupLayout) end
                if container.SetAuraGroupCandidateFilters then container:SetAuraGroupCandidateFilters(groupKey, debuffCandidateFilters) end
                if container.SetAuraGroupSortMethod then container:SetAuraGroupSortMethod(groupKey, sortMethodVal, sortDirVal) end
            elseif container.AddAuraGroup then
                container:AddAuraGroup(groupKey, filterStr, {
                    maxFrameCount = maxCount,
                    sortMethod = sortMethodVal,
                    sortDirection = sortDirVal,
                    initializeFrame = function(auraButton)
                        local exists = false
                        for _, existing in ipairs(container.icons) do if existing == auraButton then exists = true break end end
                        if not exists then table.insert(container.icons, auraButton) end
                        FormatAuraButton(auraButton, containerKey, true, size, db)
                    end,
                    layout = groupLayout,
                    candidateFilters = debuffCandidateFilters,
                })
            end
        end
    end

    for oldKey in pairs(container.activeGroupKeys) do
        if not newActiveGroupKeys[oldKey] and container.HasAuraGroup and container:HasAuraGroup(oldKey) then
            if container.SetAuraGroupMaxFrameCount then container:SetAuraGroupMaxFrameCount(oldKey, 0) end
            if container.SetAuraGroupCandidateFilters then container:SetAuraGroupCandidateFilters(oldKey, { includeSpellIDs = { [0] = true } }) end
        end
    end
    container.activeGroupKeys = newActiveGroupKeys

    local LEM = LibStub("LibEditMode-Roithi", true)
    local isEditMode = (_G.EditModeManagerFrame and _G.EditModeManagerFrame.IsShown and _G.EditModeManagerFrame:IsShown())
                    or (LibRoithi and LibRoithi.isEditMode)
                    or (LEM and LEM.isEditMode)

    container:SetSize(math.max(16, lineSizeVal), math.max(16, size))

    local GetTargetAnchorFromGrowDir = ns.Auras and ns.Auras.GetTargetAnchorFromGrowDir
    local targetAnchor = GetTargetAnchorFromGrowDir and GetTargetAnchorFromGrowDir(growDir, isCenterHoriz, isCenterVert) or "TOPLEFT"

    local savedPt = db.screenPoint or db.auraScreenPoint or db.anchor or targetAnchor
    local savedX = tonumber(db.screenX or db.auraScreenX or db.x) or 0
    local savedY = tonumber(db.screenY or db.auraScreenY or db.y) or 0

    local pt = savedPt
    local px = savedX
    local py = savedY
    if not savedPt or savedPt ~= targetAnchor then
        local ConvertAnchorPosition = ns.Auras and ns.Auras.ConvertAnchorPosition
        if ConvertAnchorPosition then
            pt, px, py = ConvertAnchorPosition(savedPt, px, py, targetAnchor, lineSizeVal, size)
        else
            pt = targetAnchor
        end
        db.screenPoint = pt; db.screenX = px; db.screenY = py
        db.auraScreenPoint = pt; db.auraScreenX = px; db.auraScreenY = py
        db.anchor = pt; db.x = px; db.y = py
    end

    local isSec = issecretvalue and (issecretvalue(pt) or issecretvalue(px) or issecretvalue(py))
    if not isSec then
        container:ClearAllPoints()
        local ok = pcall(container.SetPoint, container, pt, UIParent, pt, px, py)
        if ok then
            container.roithiSavedPoint = pt
            container.roithiSavedRelPoint = pt
            container.roithiSavedX = px
            container.roithiSavedY = py
        end
    end

    if isEditMode then
        container:Hide()
    else
        container:Show()
    end

    local isDetached = true
    local UpdateAuraMover = ns.Auras and ns.Auras.UpdateAuraMover
    if UpdateAuraMover then
        UpdateAuraMover(
            container, unit, "Custom_" .. id,
            lineSizeVal, size, size, spacing, perRow,
            layoutAnchor, growDir, isVerticalLayout,
            isCenterHoriz, isCenterVert, false,
            isEditMode, isDetached, db
        )
    end
end

-------------------------------------------------------------------------------
-- Sub-Module Function Exports
-------------------------------------------------------------------------------
ns.Auras = ns.Auras or {}
ns.Auras.UpdateCustomAura = function(id) return UF:UpdateCustomAura(id) end
