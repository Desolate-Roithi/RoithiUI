local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local UF = RoithiUI:GetModule("UnitFrames")

function UF:LayoutUnit(unit)
    -- Just a helper if we wanted distinctive layouts per unit
end

function UF:IsUnitEnabled(unit)
    if not RoithiUIDB.UnitFrames then return true end
    if not RoithiUIDB.UnitFrames[unit] then return true end
    return RoithiUIDB.UnitFrames[unit].enabled ~= false
end

function UF:ShouldCreate(unit)
    -- Always create to allow toggling, unless disabled at addon load?
    -- User wants to toggle. So we must create them.
    return true
end

function UF:CreateStandardLayout(unit, name)
    if not self:ShouldCreate(unit) then return end

    local frame = self:CreateUnitFrame(unit, name)

    -- Default Positions (Can be overridden by DB later)
    -- Apply Settings (Dimensions, Position, etc. from DB)
    if self.UpdateFrameFromSettings then
        self:UpdateFrameFromSettings(unit)
    end

    -- Create ALL elements for every frame to ensure consistent structure
    self:CreateHealthBar(frame)
    self:CreatePowerBar(frame)
    self:CreateHealPrediction(frame)
    self:CreateIndicators(frame)
    self:CreateAuras(frame)
    self:CreateRange(frame)

    self:CreateClassPower(frame)
    self:CreateAdditionalPower(frame)
    self:CreateEncounterResource(frame)
    local TM = self.TagManager
    if TM then
        self:UpdateTags(frame) -- Build tags from DB

        -- Register lightweight updates
        -- Register lightweight updates
        if not frame.RoithiTagsHooked then
            local function UpdateTags() self:UpdateCustomTags(frame) end

            -- Key events for stats
            if frame.unit then
                frame:RegisterUnitEvent("UNIT_HEALTH", frame.unit)
                frame:RegisterUnitEvent("UNIT_MAXHEALTH", frame.unit)
                frame:RegisterUnitEvent("UNIT_POWER_UPDATE", frame.unit)
                frame:RegisterUnitEvent("UNIT_MAXPOWER", frame.unit)
                frame:RegisterUnitEvent("UNIT_NAME_UPDATE", frame.unit)
                frame:RegisterUnitEvent("UNIT_LEVEL", frame.unit)
                frame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", frame.unit)
            end

            -- Context events for target switching
            if frame.unit == "target" then
                frame:RegisterEvent("PLAYER_TARGET_CHANGED")
            elseif frame.unit == "focus" then
                frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
            elseif frame.unit == "targettarget" or frame.unit == "focustarget" or frame.unit == "pettarget" then
                frame:RegisterEvent("UNIT_TARGET")
            end

            frame:HookScript("OnEvent", function(_, event, unit)
                -- Standard Unit Events
                if unit == frame.unit then
                    UpdateTags()
                    -- Context Switch Events
                elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
                    UpdateTags()
                elseif event == "UNIT_TARGET" then
                    -- Check if parent unit changed (e.g. target changed for targettarget)
                    UpdateTags()
                end
            end)

            -- Also update on Show to ensure fresh data
            frame:HookScript("OnShow", UpdateTags)
            frame.RoithiTagsHooked = true
        end
    end

    self:ToggleFrame(unit, self:IsUnitEnabled(unit))
end

function UF:InitializeUnits()
    self:CreateStandardLayout("player", "Player")
    self:CreateStandardLayout("target", "Target")
    self:CreateStandardLayout("focus", "Focus")
    self:CreateStandardLayout("pet", "Pet")
    self:CreateStandardLayout("targettarget", "Target of Target")
    self:CreateStandardLayout("focustarget", "Focus Target")
end

-- Hook OnEnable to run initialization
-- We do this here so Elements.lua and Core.lua are already loaded
local baseEnable = UF.OnEnable
function UF:OnEnable()
    if baseEnable then baseEnable(self) end
    self:InitializeUnits()
    if ns.InitializeUnitFrameConfig then ns.InitializeUnitFrameConfig() end
end
