local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local UF = RoithiUI:GetModule("UnitFrames")

-- ----------------------------------------------------------------------------
-- Health Text
-- ----------------------------------------------------------------------------
function UF:CreateHealthText(frame)
    -- Parent to Health Bar so it layers correctly
    local parent = frame.Health or frame
    local text = parent:CreateFontString(nil, "OVERLAY")
    local font = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.unitFrameFont) or "Roithi Thick"
    local outline = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.fontOutline) or "OUTLINE"
    LibRoithi.mixins:SetFont(text, font, 12, outline)
    if text.SetDrawLayer then text:SetDrawLayer("OVERLAY", 7) end
    if text.SetShadowOffset then
        if outline ~= "NONE" and outline ~= "" then
            text:SetShadowOffset(0, 0)
        else
            text:SetShadowOffset(1, -1)
        end
    end
    text:SetPoint("CENTER", parent, "CENTER", 0, 0)
    frame.HealthText = text

    local function Update()
        if not UnitExists(frame.unit) then return end
        local curr = UnitHealth(frame.unit)
        local max = UnitHealthMax(frame.unit)

        -- Use SafeFormat from LibRoithi to handle Secret values
        text:SetText(LibRoithi.mixins:SafeFormat("%s / %s", curr, max))
    end

    -- Event Listener
    local el = CreateFrame("Frame", nil, parent)
    el:SetScript("OnEvent", Update)
    el:RegisterUnitEvent("UNIT_HEALTH", frame.unit)
    el:RegisterUnitEvent("UNIT_MAXHEALTH", frame.unit)

    frame:HookScript("OnShow", Update)
    if UnitExists(frame.unit) then Update() end

    frame.UpdateHealthText = Update
end

-- ----------------------------------------------------------------------------
-- Power Text
-- ----------------------------------------------------------------------------
function UF:CreatePowerText(frame)
    local parent = frame.Power or frame
    local text = parent:CreateFontString(nil, "OVERLAY")
    local font = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.unitFrameFont) or "Roithi Thick"
    local outline = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.fontOutline) or "OUTLINE"
    LibRoithi.mixins:SetFont(text, font, 12, outline)
    if text.SetDrawLayer then text:SetDrawLayer("OVERLAY", 7) end
    if text.SetShadowOffset then
        if outline ~= "NONE" and outline ~= "" then
            text:SetShadowOffset(0, 0)
        else
            text:SetShadowOffset(1, -1)
        end
    end
    text:SetPoint("CENTER", parent, "CENTER", 0, 0)
    frame.PowerText = text

    local function Update()
        local unit = frame.unit
        if unit == "player" then
            if (_G.UnitHasVehicleUI and _G.UnitHasVehicleUI("player")) or (_G.UnitInVehicle and _G.UnitInVehicle("player")) then
                if _G.UnitExists("vehicle") then
                    unit = "vehicle"
                end
            end
        end
        if not UnitExists(unit) then return end
        local curr = UnitPower(unit)
        local max = UnitPowerMax(unit)

        text:SetText(LibRoithi.mixins:SafeFormat("%s / %s", curr, max))
    end

    local el = CreateFrame("Frame", nil, parent)
    el:SetScript("OnEvent", Update)
    if frame.unit == "player" then
        el:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", "vehicle")
        el:RegisterUnitEvent("UNIT_MAXPOWER", "player", "vehicle")
        el:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", "vehicle")
        el:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
        el:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    else
        el:RegisterUnitEvent("UNIT_POWER_UPDATE", frame.unit)
        el:RegisterUnitEvent("UNIT_MAXPOWER", frame.unit)
        el:RegisterUnitEvent("UNIT_DISPLAYPOWER", frame.unit)
    end

    frame:HookScript("OnShow", Update)
    if UnitExists(frame.unit) then Update() end

    frame.UpdatePowerText = Update
end

-- ----------------------------------------------------------------------------
-- Name Text
-- ----------------------------------------------------------------------------
function UF:CreateName(frame)
    local text = frame:CreateFontString(nil, "OVERLAY")
    local font = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.unitFrameFont) or "Roithi Thick"
    local outline = (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.fontOutline) or "OUTLINE"
    LibRoithi.mixins:SetFont(text, font, 12, outline)
    if text.SetDrawLayer then text:SetDrawLayer("OVERLAY", 7) end
    if text.SetShadowOffset then
        if outline ~= "NONE" and outline ~= "" then
            text:SetShadowOffset(0, 0)
        else
            text:SetShadowOffset(1, -1)
        end
    end
    -- Default position: Top of frame
    text:SetPoint("BOTTOM", frame, "TOP", 0, 4)
    frame.Name = text

    local function Update()
        if not UnitExists(frame.unit) then return end
        local name = UnitName(frame.unit) or "Unknown"
        text:SetText(name)

        -- Color by class?
        local _, class = UnitClass(frame.unit)
        local color = RAID_CLASS_COLORS[class]
        if color then
            text:SetTextColor(color.r, color.g, color.b)
        else
            text:SetTextColor(1, 1, 1)
        end
    end

    local el = CreateFrame("Frame", nil, frame)
    el:SetScript("OnEvent", Update)
    el:RegisterUnitEvent("UNIT_NAME_UPDATE", frame.unit)
    el:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", frame.unit)
    el:RegisterUnitEvent("UNIT_EXITED_VEHICLE", frame.unit)

    frame:HookScript("OnShow", Update)
    if UnitExists(frame.unit) then Update() end

    frame.UpdateName = Update
end
