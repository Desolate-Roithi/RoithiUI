local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local RADLog = function(fmt, ...) if ns.Auras and ns.Auras.RADLog then ns.Auras.RADLog(fmt, ...) end end

-------------------------------------------------------------------------------
-- Helper: Anchor Position Converter
-------------------------------------------------------------------------------
local function ConvertAnchorPosition(oldPoint, oldX, oldY, newPoint, mW, mH)
    oldPoint = oldPoint or "TOPLEFT"
    newPoint = newPoint or "TOPLEFT"
    oldX = oldX or 0
    oldY = oldY or 0
    mW = mW or 200
    mH = mH or 30

    if oldPoint == newPoint then return newPoint, oldX, oldY end

    local uW, uH = UIParent:GetWidth(), UIParent:GetHeight()

    local leftX, topY
    if oldPoint == "TOPLEFT" then
        leftX = oldX
        topY = oldY
    elseif oldPoint == "BOTTOMLEFT" then
        leftX = oldX
        topY = oldY + mH - uH
    elseif oldPoint == "TOPRIGHT" then
        leftX = oldX + uW - mW
        topY = oldY
    elseif oldPoint == "BOTTOMRIGHT" then
        leftX = oldX + uW - mW
        topY = oldY + mH - uH
    elseif oldPoint == "TOP" then
        leftX = oldX + uW/2 - mW/2
        topY = oldY
    elseif oldPoint == "BOTTOM" then
        leftX = oldX + uW/2 - mW/2
        topY = oldY + mH - uH
    elseif oldPoint == "LEFT" then
        leftX = oldX
        topY = oldY + uH/2 + mH/2 - uH
    elseif oldPoint == "RIGHT" then
        leftX = oldX + uW - mW
        topY = oldY + uH/2 + mH/2 - uH
    else -- "CENTER"
        leftX = oldX + uW/2 - mW/2
        topY = oldY + uH/2 + mH/2 - uH
    end

    local newX, newY
    if newPoint == "TOPLEFT" then
        newX = leftX
        newY = topY
    elseif newPoint == "BOTTOMLEFT" then
        newX = leftX
        newY = topY - mH + uH
    elseif newPoint == "TOPRIGHT" then
        newX = leftX - uW + mW
        newY = topY
    elseif newPoint == "BOTTOMRIGHT" then
        newX = leftX - uW + mW
        newY = topY - mH + uH
    elseif newPoint == "TOP" then
        newX = leftX - uW/2 + mW/2
        newY = topY
    elseif newPoint == "BOTTOM" then
        newX = leftX - uW/2 + mW/2
        newY = topY - mH + uH
    elseif newPoint == "LEFT" then
        newX = leftX
        newY = topY - mH/2 - uH/2 + uH
    elseif newPoint == "RIGHT" then
        newX = leftX - uW + mW
        newY = topY - mH/2 - uH/2 + uH
    else -- "CENTER"
        newX = leftX - uW/2 + mW/2
        newY = topY - mH/2 - uH/2 + uH
    end

    newX = math.floor(newX * 10 + 0.5) / 10
    newY = math.floor(newY * 10 + 0.5) / 10
    RADLog("[ConvertAnchorPosition] Converted (%s, %.1f, %.1f) → (%s, %.1f, %.1f)",
        oldPoint, oldX, oldY, newPoint, newX, newY)
    return newPoint, newX, newY
end

-------------------------------------------------------------------------------
-- Supported Unit Check
-------------------------------------------------------------------------------
local function IsSupportedUnit(unit)
    if not unit then return false end
    if unit == "player" or unit == "target" or unit == "focus" or unit == "pet" then
        return true
    end
    if unit:find("^boss%d+$") then
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- Get Profile DB for a Unit
-------------------------------------------------------------------------------
local function GetUnitDB(unit)
    local profile = RoithiUI.db and RoithiUI.db.profile
    if not profile or not profile.UnitFrames then return {} end

    if unit:find("^boss%d+$") then
        local bossDB = profile.UnitFrames.boss or {}
        local copy = {}
        for k, v in pairs(bossDB) do copy[k] = v end
        if profile.UnitFrames[unit] then
            for k, v in pairs(profile.UnitFrames[unit]) do copy[k] = v end
        end
        return copy
    end

    return profile.UnitFrames[unit] or {}
end

-------------------------------------------------------------------------------
-- Helper to Build Dynamic Filter Queries for 12.1.0 AuraGroups
-------------------------------------------------------------------------------
local function GetSmartFilterQueries(filterType, db, unit)
    db = db or {}
    local queries = {}

    if filterType == "HELPFUL" then
        if db.onlyWhitelistBuffs then
            return { "HELPFUL" }
        end
        if db.showAllBuffs then
            return { "HELPFUL" }
        end
        if db.playerBuffs == true then
            table.insert(queries, "HELPFUL|PLAYER")
        end
        if db.importantBuffs == true then
            table.insert(queries, "HELPFUL|IMPORTANT")
        end
        if db.majorDefensives == true or db.majorDefensivesBuffs == true then
            table.insert(queries, "HELPFUL|BIG_DEFENSIVE")
        end
        if db.externalDefensives == true then
            table.insert(queries, "HELPFUL|EXTERNAL_DEFENSIVE")
        end
        if db.raidInCombat == true then
            table.insert(queries, "HELPFUL|RAID_IN_COMBAT|PLAYER")
        end
        -- Fallback: ONLY if NO explicit buff filter toggles have been set at all
        local hasAnyBuffToggle = (db.showAllBuffs ~= nil) or (db.playerBuffs ~= nil) or (db.importantBuffs ~= nil) or (db.majorDefensives ~= nil) or (db.externalDefensives ~= nil) or (db.raidInCombat ~= nil) or (db.onlyWhitelistBuffs ~= nil)
        if #queries == 0 and not hasAnyBuffToggle then
            table.insert(queries, unit == "player" and "HELPFUL" or "HELPFUL|PLAYER")
        end
    elseif filterType == "HARMFUL" then
        if db.onlyWhitelistDebuffs then
            return { "HARMFUL" }
        end
        if db.showAllDebuffs then
            return { "HARMFUL" }
        end
        if db.playerDebuffs == true then
            table.insert(queries, "HARMFUL|PLAYER")
        end
        if db.importantDebuffs == true then
            table.insert(queries, "HARMFUL|IMPORTANT")
        end
        if db.crowdControl == true or db.cc == true then
            table.insert(queries, "HARMFUL|CROWD_CONTROL")
        end
        if db.onlyDispellable == true or db.dispellable == true then
            table.insert(queries, "HARMFUL|RAID_PLAYER_DISPELLABLE")
        end
        if db.majorDefensivesDebuff == true then
            table.insert(queries, "HARMFUL|BIG_DEFENSIVE")
        end
        -- Fallback: ONLY if NO explicit debuff filter toggles have been set at all
        local hasAnyDebuffToggle = (db.showAllDebuffs ~= nil) or (db.playerDebuffs ~= nil) or (db.importantDebuffs ~= nil) or (db.crowdControl ~= nil) or (db.dispellable ~= nil) or (db.majorDefensivesDebuff ~= nil) or (db.onlyWhitelistDebuffs ~= nil)
        if #queries == 0 and not hasAnyDebuffToggle then
            table.insert(queries, "HARMFUL|PLAYER")
        end
    end

    return queries
end

-------------------------------------------------------------------------------
-- Helper to Build candidateFilters pipeline for 12.1.0 AuraGroups
-------------------------------------------------------------------------------
local function BuildCandidateFilters(db, filterType)
    db = db or {}
    local candidateFilters = {}

    if db.hideTimeless then
        candidateFilters.maxDuration = 86400
    end

    -- "Show Only Whitelisted" Mode check
    local isOnlyWhitelist = (filterType == "HELPFUL" and db.onlyWhitelistBuffs)
                         or (filterType == "HARMFUL" and db.onlyWhitelistDebuffs)
                         or db.onlyWhitelist

    if isOnlyWhitelist then
        if db.Whitelist and next(db.Whitelist) then
            candidateFilters.includeSpellIDs = db.Whitelist
        else
            -- Whitelist is empty → match spell ID 0 to hide all auras in this group
            candidateFilters.includeSpellIDs = { [0] = true }
        end
    else
        -- Standard Blacklist & Whitelist merging
        local combinedBlacklist = {}
        local globalBlacklist = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Auras and RoithiUI.db.profile.Auras.Blacklist
        if globalBlacklist then
            for spellID, active in pairs(globalBlacklist) do
                if active then combinedBlacklist[spellID] = true end
            end
        end
        if db.Blacklist then
            for spellID, active in pairs(db.Blacklist) do
                if active then
                    combinedBlacklist[spellID] = true
                elseif active == false then
                    combinedBlacklist[spellID] = nil
                end
            end
        end
        if next(combinedBlacklist) then
            candidateFilters.excludeSpellIDs = combinedBlacklist
        end

        if db.Whitelist and next(db.Whitelist) then
            candidateFilters.includeSpellIDs = db.Whitelist
        end
    end

    if not next(candidateFilters) then
        return nil
    end
    return candidateFilters
end

-------------------------------------------------------------------------------
-- Helper: Screen Center Anchor Calculator (Always CENTER at 0/0)
-------------------------------------------------------------------------------
local function GetClosestScreenAnchor(frame, point, inX, inY)
    if not frame or not UIParent then return "CENTER", 0, 0 end
    local uW, uH = UIParent:GetWidth(), UIParent:GetHeight()
    if not uW or not uH or uW <= 0 or uH <= 0 then return "CENTER", 0, 0 end

    local fW = (frame.GetWidth and frame:GetWidth()) or 200
    local fH = (frame.GetHeight and frame:GetHeight()) or 30
    if fW <= 0 then fW = 200 end
    if fH <= 0 then fH = 30 end

    local fLeft = frame.GetLeft and frame:GetLeft()
    local fTop = frame.GetTop and frame:GetTop()

    if (not fLeft or not fTop) and point then
        inX = tonumber(inX) or 0
        inY = tonumber(inY) or 0

        if point == "TOPLEFT" then
            fLeft = inX
            fTop = uH + inY
        elseif point == "BOTTOMLEFT" then
            fLeft = inX
            fTop = inY + fH
        elseif point == "TOPRIGHT" then
            fLeft = uW + inX - fW
            fTop = uH + inY
        elseif point == "BOTTOMRIGHT" then
            fLeft = uW + inX - fW
            fTop = inY + fH
        elseif point == "TOP" then
            fLeft = uW / 2 + inX - fW / 2
            fTop = uH + inY
        elseif point == "BOTTOM" then
            fLeft = uW / 2 + inX - fW / 2
            fTop = inY + fH
        elseif point == "LEFT" then
            fLeft = inX
            fTop = uH / 2 + inY + fH / 2
        elseif point == "RIGHT" then
            fLeft = uW + inX - fW
            fTop = uH / 2 + inY + fH / 2
        else -- "CENTER"
            fLeft = uW / 2 + inX - fW / 2
            fTop = uH / 2 + inY + fH / 2
        end
    end

    if not fLeft or not fTop then
        return "CENTER", tonumber(inX) or 0, tonumber(inY) or 0
    end

    local cX = fLeft + fW / 2
    local cY = fTop - fH / 2

    local outX = cX - uW / 2
    local outY = cY - uH / 2

    outX = math.floor(outX * 10 + 0.5) / 10
    outY = math.floor(outY * 10 + 0.5) / 10

    RADLog("[GetClosestScreenAnchor] Screen Center anchor [CENTER] at (%.1f, %.1f)", outX, outY)
    return "CENTER", outX, outY
end

-------------------------------------------------------------------------------
-- Sub-Module Function Exports
-------------------------------------------------------------------------------
ns.Auras = ns.Auras or {}
ns.Auras.ConvertAnchorPosition = ConvertAnchorPosition
ns.Auras.IsSupportedUnit = IsSupportedUnit
ns.Auras.GetUnitDB = GetUnitDB
ns.Auras.GetSmartFilterQueries = GetSmartFilterQueries
ns.Auras.BuildCandidateFilters = BuildCandidateFilters
ns.Auras.GetClosestScreenAnchor = GetClosestScreenAnchor
