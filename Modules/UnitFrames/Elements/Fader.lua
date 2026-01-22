local _, ns = ...
local oUF = ns.oUF

-- Combat Fader
-- Fades the unit frame when out of combat, no target, and full health.
-- Config:
--   insideAlpha: 1.0 (Active)
--   outsideAlpha: 0.4 (Inactive)

local function Update(self, event)
    local unit = self.unit

    -- 1. Check Combat
    if UnitAffectingCombat("player") then
        self:SetAlpha(1)
        return
    end

    -- 2. Check Target
    if UnitExists("target") then
        self:SetAlpha(1)
        return
    end

    -- 3. Check Casting (Optional, usually desired)
    if UnitCastingInfo("player") or UnitChannelInfo("player") then
        self:SetAlpha(1)
        return
    end

    -- 4. Check Health < Max (Injured)
    -- Using Safe Health logic/APIs
    -- 4. Check Health < Max (Injured)
    -- Using Safe Health logic/APIs
    local cur = UnitHealth("player")
    local max = UnitHealthMax("player")

    -- Protected API check: Compare via pcall to avoid Secret crash
    local isInjured = false
    local success, result = pcall(function() return cur < max end)
    if success then
        isInjured = result
    else
        -- If comparison failed (secret), assume injured/active to avoid hiding important info
        isInjured = true
    end

    if isInjured then
        self:SetAlpha(1)
        return
    end

    -- 5. Default Fade
    local alpha = self.CombatFader and self.CombatFader.outsideAlpha or 0.4
    self:SetAlpha(alpha)
end

local function Enable(self)
    if self.CombatFader then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", Update, true)
        self:RegisterEvent("PLAYER_REGEN_DISABLED", Update, true)
        self:RegisterEvent("PLAYER_TARGET_CHANGED", Update, true)
        self:RegisterEvent("UNIT_HEALTH", Update)
        self:RegisterEvent("UNIT_SPELLCAST_START", Update)
        self:RegisterEvent("UNIT_SPELLCAST_STOP", Update)
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", Update)
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", Update)

        Update(self)
        return true
    end
end

local function Disable(self)
    if self.CombatFader then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED", Update)
        self:UnregisterEvent("PLAYER_REGEN_DISABLED", Update)
        self:UnregisterEvent("PLAYER_TARGET_CHANGED", Update)
        self:UnregisterEvent("UNIT_HEALTH", Update)
        self:UnregisterEvent("UNIT_SPELLCAST_START", Update)
        self:UnregisterEvent("UNIT_SPELLCAST_STOP", Update)
        self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START", Update)
        self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", Update)
        self:SetAlpha(1)
    end
end

oUF:AddElement("CombatFader", Update, Enable, Disable)
