local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
---@diagnostic disable-next-line: undefined-field
local oUF = ns.oUF or _G.oUF

local LEM = LibStub("LibEditMode", true)

function UF:CreateUnitFrame(unit, name)
    local frameName = "Roithi" .. (name or unit:gsub("^%l", string.upper))
    local frame = oUF:Spawn(unit, frameName)
    if not self.units then self.units = {} end
    self.units[unit] = frame

    -- Edit Mode Registration
    if LEM then
        frame.editModeName = name or unit


        -- Selection Overlay
        local overlay = frame:CreateTexture(nil, "OVERLAY")
        overlay:SetAllPoints()
        overlay:SetColorTexture(0, 0.8, 1, 0.3)
        overlay:Hide()
        frame.EditModeOverlay = overlay

        LEM:RegisterCallback('enter', function()
            frame.isInEditMode = true
            overlay:Show()
            -- Force Show Frame if hidden (e.g. Boss frames when no boss)
            if not frame:IsShown() then
                frame.forceShowEditMode = true
                frame:Show()
            end

            -- Trigger layout updates on sub-elements
            if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
            if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
        end)

        LEM:RegisterCallback('exit', function()
            frame.isInEditMode = false
            overlay:Hide()
            if frame.forceShowEditMode then
                frame.forceShowEditMode = nil
                frame:Hide()
            end

            -- Refresh
            if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
            if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
        end)
    end

    return frame
end

function UF:UpdateFrameFromSettings(unit)
    local frame = self.units[unit]
    if not frame then return end

    local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]
    if not db then return end

    if db.width then frame:SetWidth(db.width) end
    if db.height then frame:SetHeight(db.height) end
    if db.point then
        frame:ClearAllPoints()
        frame:SetPoint(db.point, UIParent, db.point, db.x or 0, db.y or 0)
    end

    -- Update Elements Live
    if self.UpdateHealthBarSettings then self:UpdateHealthBarSettings(frame) end
    if self.UpdatePowerBarSettings then self:UpdatePowerBarSettings(frame) end
    if self.UpdateTags then self:UpdateTags(frame) end
    if self.UpdateIndicators then self:UpdateIndicators(frame) end
    if self.UpdateAuras then self:UpdateAuras(frame) end
    if self.UpdateAdditionalPowerSettings then self:UpdateAdditionalPowerSettings(frame) end
end

function UF:InitializeBossFrames()
    for i = 1, 5 do
        local unit = "boss" .. i
        -- Use generic creation
        local frame = self:CreateUnitFrame(unit, "Boss" .. i)

        -- Default Positioning logic (mirrors old Core.lua but allows DB override via UpdateFrameFromSettings if we wanted,
        -- but simpler to keep the hardcoded relative logic for boss frames if no DB entries exist yet,
        -- OR implement the loop logic here).

        -- Applying the logic from Core.lua:
        if i == 1 then
            frame:SetPoint("RIGHT", -100, 100)
        else
            frame:SetPoint("TOP", self.units["boss" .. (i - 1)], "BOTTOM", 0, -30)
        end
        frame:SetSize(180, 40)

        -- Apply Settings override if exists
        self:UpdateFrameFromSettings(unit)
    end
end

function UF:IsUnitEnabled(unit)
    if not RoithiUI.db.profile.UnitFrames then return true end
    if not RoithiUI.db.profile.UnitFrames[unit] then return true end
    return RoithiUI.db.profile.UnitFrames[unit].enabled ~= false
end

function UF:ShouldCreate(unit)
    -- Always create to allow toggling, unless disabled at addon load?
    -- User wants to toggle. So we must create them.
    return true
end

function UF:ToggleFrame(unit, enabled)
    local frame = self.units[unit]
    if not frame then return end

    if enabled then
        if frame.Enable then frame:Enable() end
        frame:Show()
    else
        if frame.Disable then frame:Disable() end
        frame:Hide()
    end
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
    -- self:CreateHealthBar(frame) -- REMOVED: Core.lua (Shared Style) creates SafeHealth which acts as frame.Health
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
        self:EnableTags(frame) -- Hook events
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
    self:InitializeBossFrames()
end

-- Hook OnEnable to run initialization
-- We do this here so Elements.lua and Core.lua are already loaded
local baseEnable = UF.OnEnable
function UF:OnEnable()
    if baseEnable then baseEnable(self) end
    self:InitializeUnits()
    if ns.InitializeUnitFrameConfig then ns.InitializeUnitFrameConfig() end
end
