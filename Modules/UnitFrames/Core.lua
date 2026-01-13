local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode")

local UF = RoithiUI:NewModule("UnitFrames")

-- Frame Factory
function UF:CreateUnitFrame(unit, name)
    local frameName = "Roithi" .. name
    -- Secure Header
    local frame = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate, BackdropTemplate")

    frame:SetAttribute("unit", unit)
    frame:SetAttribute("type1", "target") -- Target on left click
    frame:RegisterForClicks("AnyUp")

    -- Visual Setup
    frame:SetSize(200, 50) -- Default size, can be overridden
    LibRoithi.mixins:CreateBackdrop(frame)

    frame.unit = unit

    -- Store referencing for configuration
    self.frames = self.frames or {}
    self.frames[unit] = frame

    -- Register with LibEditMode if available
    if LEM then
        -- Assuming a standard usage of LibEditMode:RegisterFrame(frame, displayName, dbTable)
        -- We won't implement the full logic here as we don't have the library source,
        -- but we'll show the intent as requested.
        -- We use RoithiUIDB.EditMode positions which LEM handles usually.
        LEM:RegisterFrame(frame, name .. " Frame", RoithiUIDB.EditMode)
    end

    return frame
end

function UF:OnEnable()
    -- Enable is handled in Units.lua effectively by spawning frames,
    -- or we trigger the spawn here if Units.lua just defines the layouts.
    -- We will let Units.lua register the specific layouts.
end
