local addonName, ns = ...
local RoithiUI = _G.RoithiUI

---@class AttachmentLogic
local AL = {}
ns.AttachmentLogic = AL

---@class UF : AceModule
---@field units table<string, table>

---@class CBCore : AceModule
---@field bars table<string, table>

-- ----------------------------------------------------------------------------
-- 1. Configuration & Hierarchy
-- ----------------------------------------------------------------------------

-- Bar Hierarchies (User Defined)
-- Strictly followed.
AL.BarHierarchies = {
    ["Power"] = { "UnitFrame" },
    ["ClassPower"] = { "Power" },                                                -- Falls back to UnitFrame if Power detached
    ["AdditionalPower"] = { "UnitFrame", { "Power", "ClassPower" } },            -- Group requires both Attached
    ["Castbar"] = { "UnitFrame", { "Power", "ClassPower" }, "AdditionalPower" }, -- Priority: Add -> Group -> UF
    ["Auras"] = { "UnitFrame" }                                                  -- Auras always attach to UnitFrame (Satellite)
}

-- Mapping of internal names to unit frame element keys
local ElementMap = {
    ["UnitFrame"] = "UnitFrame", -- Root fallback
    ["Power"] = "Power",
    ["ClassPower"] = "ClassPower",
    ["AdditionalPower"] = "AdditionalPower",
    ["Auras"] = "RoithiAuras",
}

-- Mapping of internal names to DB keys
local DBKeyMap = {
    ["Power"] = "power",
    ["ClassPower"] = "classPower",
    ["AdditionalPower"] = "additionalPower",
    ["Castbar"] = "castbar",
    ["Auras"] = "aura",
}

-- ----------------------------------------------------------------------------
-- 2. State Helpers
-- ----------------------------------------------------------------------------

-- Helper to safe-get the DB for a specific element
function AL:GetElementDB(unit, frameType)
    if frameType == "Castbar" then
        return RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[unit]
    elseif frameType:match("^CustomAura_") then
        -- Keys are stored in Global CustomAuraFrames table, assumed keyed by name?
        -- Actually CustomAuraFrames is a list or map?
        -- User said "create custom aura frames... for each uf".
        -- If we key by name globaly, we need to know which one applies to this unit.
        -- But ApplyLayout is called with (unit, type).
        -- The type "CustomAura_ID" implies specific frame.
        -- We assume CustomAuraFrames[ID] exists.
        local id = frameType:match("^CustomAura_(.+)")
        return RoithiUI.db.profile.CustomAuraFrames and RoithiUI.db.profile.CustomAuraFrames[id]
    end

    local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]
    return db
end

-- Check if a specific element is "Detached" in DB
function AL:IsDetached(unit, frameType)
    if frameType == "UnitFrame" then return false end -- Root is never detached

    local db = self:GetElementDB(unit, frameType)
    if not db then return false end

    if frameType == "Castbar" then
        return db.detached == true
    elseif frameType:match("^CustomAura_") then
        return db.detached == true
    end

    local key = DBKeyMap[frameType] .. "Detached"
    return db[key] == true
end

-- Check if a specific element is "Enabled" and available (Active)
function AL:IsActive(unit, frameType)
    if frameType == "UnitFrame" then return true end

    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    ---@diagnostic disable-next-line: undefined-field
    local frame = UF and UF.units and UF.units[unit]
    if not frame then return false end

    if frameType == "Castbar" then
        local CB = RoithiUI:GetModule("Castbar") --[[@as CBCore]]
        ---@diagnostic disable-next-line: undefined-field
        local bar = CB and CB.bars and CB.bars[unit]
        return bar and bar:IsShown()
    elseif frameType:match("^CustomAura_") then
        local id = frameType:match("^CustomAura_(.+)")
        local element = frame.CustomAuras and frame.CustomAuras[id]
        return element and element:IsShown()
    end

    local elementKey = ElementMap[frameType]
    local element = frame[elementKey]
    return element and element:IsShown()
end

-- ----------------------------------------------------------------------------
-- 3. Core Logic
-- ----------------------------------------------------------------------------

-- Find the first active, attached parent in the hierarchy
function AL:GetValidAnchor(unit, frameType)
    local hierarchy = self.BarHierarchies[frameType]
    if not hierarchy and frameType:match("^CustomAura_") then
        hierarchy = { "UnitFrame" } -- Custom Auras always attach to UnitFrame
    end
    if not hierarchy then return nil end

    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    ---@diagnostic disable-next-line: undefined-field
    local uFrame = UF and UF.units and UF.units[unit]
    if not uFrame then return nil end

    -- Iterate backwards (Highest Priority first)
    for i = #hierarchy, 1, -1 do
        local entry = hierarchy[i]

        if type(entry) == "table" then
            -- [GROUP ENTRY] (e.g. { "Power", "ClassPower" })
            local groupValid = true
            for _, name in ipairs(entry) do
                local isDetached = self:IsDetached(unit, name)
                if frameType == "AdditionalPower" and RoithiUI.db.profile.General.debugMode then
                    RoithiUI:Log(string.format("AL Debug: AddPower Group Check | Member: %s | Detached: %s", name,
                        tostring(isDetached)))
                end

                if isDetached then
                    groupValid = false
                    break
                end
            end

            if groupValid then
                -- Find specific active anchor within the group
                for j = #entry, 1, -1 do
                    local name = entry[j]
                    if self:IsActive(unit, name) then
                        local elementKey = ElementMap[name]
                        if uFrame[elementKey] then
                            if frameType == "AdditionalPower" and RoithiUI.db.profile.General.debugMode then
                                RoithiUI:Log(string.format(
                                    "AL Debug: AddPower Group Valid -> Selected: %s (Active=true, FrameExists=true)",
                                    name))
                            end
                            return uFrame[elementKey]
                        elseif frameType == "AdditionalPower" and RoithiUI.db.profile.General.debugMode then
                            RoithiUI:Log(string.format("AL Debug: AddPower Group Member Active but Frame Missing: %s",
                                name))
                        end
                    elseif frameType == "AdditionalPower" and RoithiUI.db.profile.General.debugMode then
                        RoithiUI:Log(string.format("AL Debug: AddPower Group Member Inactive: %s", name))
                    end
                end
            end
        elseif entry == "UnitFrame" then
            -- [ROOT ENTRY]
            -- Always Valid fallback
            if frameType == "AdditionalPower" and RoithiUI.db.profile.General.debugMode then
                local anchorName = uFrame.GetName and uFrame:GetName() or "Unknown"
                RoithiUI:Log("AL Debug: AddPower Fallback to UnitFrame via Hierarchy -> " .. anchorName)
            end
            return uFrame
        else
            -- [SINGLE ENTRY] (e.g. "Power")
            -- LOOSE: Valid even if parent is DETACHED.
            -- User Rule: "Even if Power is detached it should stay with power" (for ClassPower)
            if self:IsActive(unit, entry) then
                local elementKey = ElementMap[entry]
                if frameType == "Castbar" and entry == "AdditionalPower" then
                    -- Special case: Castbar anchoring to AdditionalPower frame
                    return uFrame[ElementMap["AdditionalPower"]]
                elseif uFrame[elementKey] then
                    if frameType == "AdditionalPower" and RoithiUI.db.profile.General.debugMode then
                        RoithiUI:Log("AL Debug: AddPower Single Entry Selected: " ..
                            entry)
                    end
                    return uFrame[elementKey]
                end
            end
        end
    end

    -- Absolute fallback handled by caller usually, but returning uFrame ensures safety.
    -- However, if hierarchies are exhaustive, we might not reach here unless all inactive.
    if frameType == "AdditionalPower" and RoithiUI.db.profile.General.debugMode then
        local anchorName = uFrame.GetName and uFrame:GetName() or "Unknown"
        RoithiUI:Log("AL Debug: AddPower Absolute Fallback to UnitFrame -> " .. anchorName)
    end
    return uFrame
end

-- Apply layout (Point, Parent, Width) for a frame
function AL:ApplyLayout(unit, frameType)
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    ---@diagnostic disable-next-line: undefined-field
    local uFrame = UF and UF.units and UF.units[unit]
    if not uFrame then return end

    local frame
    if frameType == "Castbar" then
        local CB = RoithiUI:GetModule("Castbar") --[[@as CBCore]]
        ---@diagnostic disable-next-line: undefined-field
        local bars = CB and CB.bars
        frame = bars and bars[unit]
    elseif frameType:match("^CustomAura_") then
        local id = frameType:match("^CustomAura_(.+)")
        frame = uFrame.CustomAuras and uFrame.CustomAuras[id]
    else
        local mappedKey = ElementMap[frameType]
        if mappedKey then
            frame = uFrame[mappedKey]
        end
    end

    if not frame then return end

    local db = self:GetElementDB(unit, frameType)
    local isDetached = self:IsDetached(unit, frameType)

    if frameType == "AdditionalPower" and RoithiUI.db.profile.General.debugMode then
        RoithiUI:Log(string.format("AL Debug: ApplyLayout %s | Detached: %s", frameType, tostring(isDetached)))
    end

    -- Save-on-Transition Logic:
    -- If we are switching to Attached (isDetached == false), but the frame is currently Detached (IsMovable == true),
    -- then the user just unchecked "Detached". We must save the current manual position before it gets wiped/snapped.
    if not isDetached and frame:IsMovable() then
        local p, _, rp, x, y = frame:GetPoint()
        if p then
            if frameType == "Castbar" then
                db.point, db.x, db.y = p, x, y
            else
                local prefix = DBKeyMap[frameType]
                db[prefix .. "Point"] = p
                db[prefix .. "X"] = x
                db[prefix .. "Y"] = y
            end
            if RoithiUI.db.profile.General.debugMode then
                RoithiUI:Log(string.format("AL Debug: Transition to Attached -> Saved Manual Pos for %s", frameType))
            end
        end
    end

    frame:ClearAllPoints()

    if isDetached then
        -- DETACHED: Restore manual position and manual width
        frame:SetMovable(true)
        local point, x, y, width
        if frameType == "Castbar" then
            point = db.point or "CENTER"
            x, y = db.x or 0, db.y or 0
            width = db.width or 250
        elseif frameType == "Auras" or frameType:match("^CustomAura_") then
            -- Use specialized Screen Coordinates keys for Auras to preserve Satellite offsets
            if frameType == "Auras" then
                point = db.auraScreenPoint or "CENTER"
                x, y = db.auraScreenX or 0, db.auraScreenY or 0
            else
                point = db.screenPoint or "CENTER"
                x, y = db.screenX or 0, db.screenY or -50
            end
            width = db.auraWidth or 200 -- Managed by aura config usually
        else
            local prefix = DBKeyMap[frameType]
            point = db[prefix .. "Point"] or "CENTER"
            x, y = db[prefix .. "X"] or 0, db[prefix .. "Y"] or -100
            width = db[prefix .. "Width"] or 200
        end

        frame:SetParent(UIParent)
        frame:SetPoint(point, UIParent, point, x, y)
        if frameType ~= "Auras" and not frameType:match("^CustomAura_") then frame:SetWidth(width) end -- Auras manage their own width/growth
    else
        -- ATTACHED: Anchor to valid parent
        frame:SetMovable(false)
        local anchor = self:GetValidAnchor(unit, frameType)
        if anchor then
            frame:SetParent(anchor)
            if frameType == "Auras" or frameType:match("^CustomAura_") then
                -- SATELLITE MODE: Respect configured relative offsets
                local p = "BOTTOM"
                local x = 0
                local y = 0
                if frameType == "Auras" then
                    p = db.auraAnchor or "BOTTOM"
                    x = db.auraX or 0
                    y = db.auraY or 0
                else
                    p = db.anchorPoint or "BOTTOM"
                    x = db.xOffset or 0
                    y = db.yOffset or 0
                end
                frame:ClearAllPoints()
                frame:SetPoint(p, anchor, p, x, y)
                -- Width is auto-calculated by icons usually
            else
                -- STACKED MODE (Bars)
                frame:SetPoint("TOP", anchor, "BOTTOM", 0, -1)
                frame:SetWidth(anchor:GetWidth())
            end
        end
    end
end

-- Refresh the entire hierarchy for a unit
function AL:GlobalLayoutRefresh(unit)
    -- Refresh in dependency order: Power -> Class -> Add -> Cast -> Auras
    local refreshOrder = { "Power", "ClassPower", "AdditionalPower", "Castbar", "Auras" }
    for _, frameType in ipairs(refreshOrder) do
        self:ApplyLayout(unit, frameType)
    end
    -- Also try to refresh custom auras if any exist
    local customDB = RoithiUI.db.profile.CustomAuraFrames
    if customDB then
        for id, conf in pairs(customDB) do
            if conf.unit == unit then
                self:ApplyLayout(unit, "CustomAura_" .. id)
            end
        end
    end
end
