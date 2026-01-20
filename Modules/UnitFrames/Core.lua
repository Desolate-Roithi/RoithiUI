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

    -- "togglemenu" is the correct secure action for 11.0+ context menus (matches User Example)
    frame:SetAttribute("type2", "togglemenu")
    frame:SetAttribute("*type2", "togglemenu")

    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")

    -- Debug Hook only (Removed manual logic)
    -- frame:HookScript("OnClick", function(self, button) end)

    frame:HookScript("OnEnter", function(self)
        -- Mouse enter
    end)

    -- No longer assigning frame.menu as we handle it in OnClick directly
    frame.menu = nil

    -- Visual Setup
    frame:SetSize(200, 50) -- Default size, can be overridden
    LibRoithi.mixins:CreateBackdrop(frame)

    -- Mouseover Highlight
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.2)
    frame.Highlight = highlight

    frame.unit = unit

    -- Store referencing for configuration
    self.frames = self.frames or {}
    self.frames[unit] = frame

    -- Register with LibEditMode if available
    -- Moved to Config/UnitFrames.lua to centralize settings and registration
    if LEM then
        -- We still set the editModeName for Config/UnitFrames.lua to use
        frame.editModeName = name .. " Frame"
    end

    return frame
end

function UF:UpdateBlizzardVisibility()
    -- Only run if we have DB
    if not RoithiUIDB.UnitFrames then return end

    -- Safe Hiding Infrastructure
    local HiddenFrame = CreateFrame("Frame")
    HiddenFrame:Hide()

    local function ToggleBlizz(frame, show)
        if not frame then return end
        if show then
            -- Restore original parent if known, otherwise default to UIParent
            local parent = frame.RoithiOriginalParent or UIParent
            frame:SetParent(parent)

            frame:SetAlpha(1)
            frame:EnableMouse(true)
            -- Restore visibility driver
            RegisterUnitWatch(frame)

            local unit = frame.unit or (frame.GetAttribute and frame:GetAttribute("unit"))
            if unit and UnitExists(unit) then
                frame:Show()
            end
        else
            -- Cache original parent once
            if not frame.RoithiOriginalParent then
                frame.RoithiOriginalParent = frame:GetParent()
            end

            -- "Unregister" by moving to the shadow realm
            -- This hides the frame AND all its children (Auras) automatically
            UnregisterUnitWatch(frame)
            frame:SetParent(HiddenFrame)
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
        -- Check if we are in Edit Mode
        if LEM and LEM:IsInEditMode() then
            -- Force Show
            UnregisterUnitWatch(frame)
            frame:Show()
            frame:SetAlpha(1)
            frame.isInEditMode = true
        else
            -- Standard Gameplay
            RegisterUnitWatch(frame)
            -- Provide a default state driver for visibility if UnitWatch isn't enough (UnitWatch handles exists/dead)
            -- But we want standard "Hide if unchecked" which is handled by UnregisterUnitWatch below.

            -- Also ensure it respects show/hide from UnitWatch immediately
            if UnitExists(unit) then frame:Show() end
        end
    else
        UnregisterUnitWatch(frame)
        frame:Hide()
        frame.isInEditMode = false
    end

    self:UpdateBlizzardVisibility()
end

function UF:OnEnable()
    -- Enable is handled in Units.lua effectively by spawning frames,
    -- or we trigger the spawn here if Units.lua just defines the layouts.
    -- We will let Units.lua register the specific layouts.
end
