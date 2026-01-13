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

function UF:UpdateBlizzardVisibility()
    -- Only run if we have DB
    if not RoithiUIDB.UnitFrames then return end

    local function ToggleBlizz(frame, show)
        if not frame then return end
        if show then
            frame:SetAlpha(1)
            if frame.RegisterEvent then
                frame:RegisterEvent("PLAYER_ENTERING_WORLD")
                -- We can't easily re-register all specific events without knowing them,
                -- but usually resetting Alpha is enough if we didn't UnregisterAllEvents.
                -- However, for UnitFrames, UnregisterAllEvents is safer to prevent taint/CPU usage.
                -- Modern WoW frames use Mixins, so we might need a Reload to fully restore if we unregister stuff.
                -- For now, let's just SetAlpha(0) and DisableDrawLayer to be less destructive?
                -- No, user wants them "hidden".
                -- Let's try just Hide() and SetParent(HiddenFrame) if we could, but that taints.
                -- We'll stick to SetAlpha(0) and UnregisterAllEvents for "Hide",
                -- and tell user to Reload for "Show" if it breaks.
                -- Actually, for PlayerFrame, UnregisterAllEvents stops it from updating.
            end
        else
            frame:UnregisterAllEvents()
            frame:Hide()
            frame:SetAlpha(0)
        end
    end

    local db = RoithiUIDB.UnitFrames

    -- Player
    if PlayerFrame then
        local enabled = db.player and db.player.enabled
        ToggleBlizz(PlayerFrame, not enabled)
    end

    -- Target
    if TargetFrame then
        local enabled = db.target and db.target.enabled
        ToggleBlizz(TargetFrame, not enabled)
    end

    -- Focus
    if FocusFrame then
        local enabled = db.focus and db.focus.enabled
        ToggleBlizz(FocusFrame, not enabled)
    end

    -- Pet
    if PetFrame then
        local enabled = db.pet and db.pet.enabled
        ToggleBlizz(PetFrame, not enabled)
    end

    -- TargetTarget (ToT)
    if TargetFrameToT then
        local enabled = db.targettarget and db.targettarget.enabled
        ToggleBlizz(TargetFrameToT, not enabled)
    end

    -- Focus Target - Blizzard triggers this via FocusFrame usually?
    -- There isn't a standalone FocusTargetFrame to hide usually, it's part of FocusFrame or FocusFrameToT (Wait, FocusFrameToT doesn't exist standardly in same way?).
    -- Actually modern UI has FocusFrame.TargetFrame potentially?
    -- We'll verify if FocusFrameToT exists.
end

function UF:ToggleFrame(unit, enabled)
    local frame = self.frames[unit]
    if not frame then return end

    if InCombatLockdown() then return end -- Update later if needed

    if enabled then
        RegisterUnitWatch(frame)
        -- Provide a default state driver for visibility if UnitWatch isn't enough (UnitWatch handles exists/dead)
        -- But we want standard "Hide if unchecked" which is handled by UnregisterUnitWatch below.

        -- Also ensure it respects show/hide from UnitWatch immediately
        if UnitExists(unit) then frame:Show() end
    else
        UnregisterUnitWatch(frame)
        frame:Hide()
    end

    self:UpdateBlizzardVisibility()
end

function UF:OnEnable()
    -- Enable is handled in Units.lua effectively by spawning frames,
    -- or we trigger the spawn here if Units.lua just defines the layouts.
    -- We will let Units.lua register the specific layouts.
end
