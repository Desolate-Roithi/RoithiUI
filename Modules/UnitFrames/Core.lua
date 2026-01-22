local addonName, ns = ...
local RoithiUI = _G.RoithiUI
---@diagnostic disable-next-line: undefined-field
local oUF = ns.oUF or _G.oUF

-- Initialize Module
---@class UF : AceAddon, AceModule
---@field CreateUnitFrame fun(self: UF, unit: string, name: string): table
---@field InitializeBossFrames fun(self: UF)
---@field IsUnitEnabled fun(self: UF, unit: string): boolean
---@field ShouldCreate fun(self: UF, unit: string): boolean
---@field CreateStandardLayout fun(self: UF, unit: string, name: string)
---@field CreateHealthBar fun(self: UF, frame: table)
---@field CreatePowerBar fun(self: UF, frame: table)
---@field CreateHealPrediction fun(self: UF, frame: table)
---@field CreateIndicators fun(self: UF, frame: table)
---@field CreateAuras fun(self: UF, frame: table)
---@field CreateTags fun(self: UF, frame: table)
---@field UpdateTags fun(self: UF, frame: table)
---@field CreateRange fun(self: UF, frame: table)
---@field CreateClassPower fun(self: UF, frame: table)
---@field CreateAdditionalPower fun(self: UF, frame: table)
---@field CreateEncounterResource fun(self: UF, frame: table)
---@field UpdateFrameFromSettings fun(self: UF, unit: string)
---@field ToggleFrame fun(self: UF, unit: string, enabled: boolean)
---@field InitializeUnits fun(self: UF)
---@field ToggleEncounterResource fun(self: UF, enabled: boolean)
---@field frames table<string, table>
local UF = RoithiUI:NewModule("UnitFrames")

-- ----------------------------------------------------------------------------
-- Style Function
-- ----------------------------------------------------------------------------
local function Shared(self, unit)
    -- 1. Basics
    self:SetScript("OnEnter", UnitFrame_OnEnter)
    self:SetScript("OnLeave", UnitFrame_OnLeave)

    self:RegisterForClicks("AnyUp")
    self:SetAttribute("type1", "target")
    self:SetAttribute("type2", "togglemenu")

    -- 2. Backdrop
    if not self.SetBackdrop then
        Mixin(self, BackdropTemplateMixin)
    end
    self:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    self:SetBackdropColor(0.1, 0.1, 0.1, 1)
    self:SetBackdropBorderColor(0, 0, 0, 1)

    -- 3. Health (SafeHealth)
    local Health = CreateFrame("StatusBar", nil, self)
    Health:SetPoint("TOPLEFT", 1, -1)
    Health:SetPoint("BOTTOMRIGHT", -1, 1)
    Health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    -- Options
    Health.colorTapping = true
    Health.colorDisconnected = true
    Health.colorClass = true
    Health.colorReaction = true
    Health.colorSmooth = true -- Uses our SafeHealth gradient logic

    self.SafeHealth = Health  -- Register as "SafeHealth" element
    self.Health = Health      -- Register as standard "Health" for compatibility with other elements

    -- 4. Text (Tags)
    if UF.CreateTags then
        UF:CreateTags(self)
        -- Ensure unit is set for DB lookup
        self.unit = unit
        if UF.UpdateTags then
            UF:UpdateTags(self)
        end
    end

    -- 5. Range (Phase 3 Prep)
    self.RoithiRange = {
        insideAlpha = 1,
        outsideAlpha = 0.4,
    }
    -- 6. Health Prediction
    if UF.CreateHealPrediction then
        UF:CreateHealPrediction(self)
    end

    -- 7. Combat Fader
    self.CombatFader = {
        outsideAlpha = 0.4
    }

    -- 8. Auras (Removed: Handled by Units.lua custom element)
    -- local Auras = CreateFrame("Frame", nil, self)
    -- ...
end

-- ----------------------------------------------------------------------------
-- Initialization
-- ----------------------------------------------------------------------------
function UF:OnInitialize()
    -- Register Style
    oUF:RegisterStyle("Roithi", Shared)
    oUF:SetActiveStyle("Roithi")
end

function UF:OnEnable()
    -- Reset Test Mode on Reload
    if RoithiUI.db and RoithiUI.db.profile then
        RoithiUI.db.profile.IndicatorTestMode = false
    end

    -- Initialize Units table container if not exists
    if not self.units then self.units = {} end

    -- Note: Actual spawning is handled by Units.lua hooking OnEnable and calling InitializeUnits
end
