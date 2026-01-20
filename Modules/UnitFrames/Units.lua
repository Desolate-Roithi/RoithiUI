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
    if unit == "player" then
        frame:SetPoint("CENTER", UIParent, "CENTER", -250, -100)
    elseif unit == "target" then
        frame:SetPoint("CENTER", UIParent, "CENTER", 250, -100)
    elseif unit == "focus" then
        frame:SetPoint("CENTER", UIParent, "CENTER", -350, 0)
    elseif unit == "pet" then
        frame:SetPoint("CENTER", UIParent, "CENTER", -250, -150)
    elseif unit == "targettarget" then
        frame:SetPoint("CENTER", UIParent, "CENTER", 250, -150)
    elseif unit == "focustarget" then
        frame:SetPoint("CENTER", UIParent, "CENTER", -350, -50)
    end

    -- Create ALL elements for every frame to ensure consistent structure
    self:CreateHealthBar(frame)
    self:CreatePowerBar(frame) -- Restored
    self:CreateHealPrediction(frame)
    -- self:CreateName(frame) -- Replaced by Tag 1
    self:CreateIndicators(frame)
    self:CreateAuras(frame)
    self:CreateRange(frame)

    -- Ensure Default Tags exist
    if RoithiUIDB and RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[unit] then
        local db = RoithiUIDB.UnitFrames[unit]
        if not db.tags then db.tags = {} end

        -- Default 1: Name
        if not db.tags[1] then
            db.tags[1] = { enabled = true, formatString = "@name", point = "BOTTOM", anchorTo = "Frame", x = 0, y = 35 } -- Above frame
        end
        -- Default 2: Health
        if not db.tags[2] then
            db.tags[2] = {
                enabled = true,
                formatString = "@health.current / @health.maximum",
                point = "CENTER",
                anchorTo =
                "Health",
                x = 0,
                y = 0
            }
        end
        -- Default 3: Power
        if not db.tags[3] then
            db.tags[3] = { enabled = true, formatString = "@power.current:short", point = "CENTER", anchorTo = "Power", x = 0, y = 0 }
        end
    end

    self:CreateClassPower(frame)
    self:CreateAdditionalPower(frame)
    self:CreateEncounterResource(frame)
    local TM = self.TagManager
    if TM then
        self:UpdateTags(frame) -- Build tags from DB

        -- Register lightweight updates
        if not frame.RoithiTagsHooked then
            local function UpdateTags() self:UpdateCustomTags(frame) end
            frame:HookScript("OnEvent", function(_, event, unit)
                if unit == frame.unit then UpdateTags() end
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
