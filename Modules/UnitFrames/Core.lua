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
        -- Default settings if not present
        if not RoithiUIDB.UnitFrames then RoithiUIDB.UnitFrames = {} end
        if not RoithiUIDB.UnitFrames[unit] then RoithiUIDB.UnitFrames[unit] = {} end

        local db = RoithiUIDB.UnitFrames[unit]

        -- Ensure defaults exist (even if table was created by config toggle)
        if not db.point then db.point = "CENTER" end
        if not db.x then db.x = 0 end
        if not db.y then db.y = 0 end

        local defaults = { point = db.point, x = db.x, y = db.y }

        frame.editModeName = name .. " Frame" -- Used by LEM

        local function OnPositionChanged(f, layoutName, point, x, y)
            db.point = point
            db.x = x
            db.y = y
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
        end

        LEM:AddFrame(frame, OnPositionChanged, defaults)

        -- Apply initial pos
        frame:ClearAllPoints()
        frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    end

    return frame
end

function UF:OnEnable()
    -- Enable is handled in Units.lua effectively by spawning frames,
    -- or we trigger the spawn here if Units.lua just defines the layouts.
    -- We will let Units.lua register the specific layouts.
end
