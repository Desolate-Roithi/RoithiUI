-- SafeHealth.lua
-- Custom oUF Health Element that safely handles WoW 12.0.1+ Secret Values
-- Prevents crashes from arithmetic/comparison on Secret properties.
-- Uses `UnitHealthPercent` for logic and `StatusBar:SetValue` for display.

local _, ns = ...
local oUF = ns.oUF or _G.oUF

local function Update(self, event, unit)
    if (not unit or self.unit ~= unit) then return end
    local element = self.SafeHealth

    if (element.PreUpdate) then element:PreUpdate(unit) end

    -- 1. Get Values
    -- UnitHealth returns a Secret (UserData) in restricted scenarios
    local cur = UnitHealth(unit)
    local max = UnitHealthMax(unit)

    -- 2. Get Safe Percentage for Logic/Colors
    -- UnitHealthPercent(unit, exact, curve) -> safe number 0-100
    -- CurveConstants.ScaleTo100 is required for 0-100 scale
    local per = UnitHealthPercent(unit, false, CurveConstants.ScaleTo100) or 100
    -- Convert to 0-1 ratio if needed, but usually we handle 0-100 or 0-1.
    -- oUF usually expects 0-1 for some internal color math, but we should be careful.
    -- Let's assume per is 0-100.

    -- 3. Update StatusBar
    -- SetMinMaxValues and SetValue are SAFE to call with Secrets (Blizzard allow-list)
    element:SetMinMaxValues(0, max)
    element:SetValue(cur)

    -- 4. Color Update
    -- Do NOT use cur/max. Use 'per'.
    if (element.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
        local t = element.colors.tapped
        element:SetStatusBarColor(t.r, t.g, t.b)
    elseif (element.colorDisconnected and not UnitIsConnected(unit)) then
        local t = element.colors.disconnected
        element:SetStatusBarColor(t.r, t.g, t.b)
    elseif (element.colorClass and UnitIsPlayer(unit)) then
        local _, class = UnitClass(unit)
        local t = element.colors.class[class]
        if t then
            element:SetStatusBarColor(t.r, t.g, t.b)
        else
            element:SetStatusBarColor(1, 1, 1)                          -- Fallback
        end
    elseif (element.colorReaction and UnitIsPlayer(unit) == false) then -- check Reaction
        local reaction = UnitReaction(unit, "player")
        if reaction then
            local t = element.colors.reaction[reaction]
            element:SetStatusBarColor(t.r, t.g, t.b)
        end
    elseif (element.colorSmooth) then
        -- oUF Smooth Color usually relies on value/max.
        -- We must use 'per/100' here.
        local r, g, b = self:ColorGradient(per, 100, unpack(element.smoothGradient or self.colors.smooth))
        element:SetStatusBarColor(r, g, b)
    elseif (element.colorHealth) then
        local t = element.colors.health
        element:SetStatusBarColor(t.r, t.g, t.b)
    end

    -- 5. Store values for Tags/Text
    element.cur = cur
    element.max = max
    element.per = per -- Expose percentage for tags to use safely

    if (element.PostUpdate) then element:PostUpdate(unit, cur, max, per) end
end

local function Path(self, ...)
    return (self.SafeHealth.Override or Update)(self, ...)
end

local function ForceUpdate(element)
    return Path(element.__owner, "ForceUpdate", element.__owner.unit)
end

local function Enable(self)
    local element = self.SafeHealth
    if (element) then
        element.__owner = self
        element.ForceUpdate = ForceUpdate

        self:RegisterEvent("UNIT_HEALTH", Path)
        self:RegisterEvent("UNIT_MAXHEALTH", Path)
        self:RegisterEvent("UNIT_CONNECTION", Path)
        -- self:RegisterEvent("UNIT_FACTION", Path) -- If needed for tapping

        if (element.colorSmooth) then
            element.smoothGradient = {
                1, 0, 0, -- R, G, B for 0
                1, 1, 0, -- R, G, B for 50
                0, 1, 0  -- R, G, B for 100
            }
        end

        -- Fallback colors from oUF or defaults
        element.colors = oUF.colors

        return true
    end
end

local function Disable(self)
    local element = self.SafeHealth
    if (element) then
        self:UnregisterEvent("UNIT_HEALTH", Path)
        self:UnregisterEvent("UNIT_MAXHEALTH", Path)
        self:UnregisterEvent("UNIT_CONNECTION", Path)
    end
end

oUF:AddElement("SafeHealth", Update, Enable, Disable)
