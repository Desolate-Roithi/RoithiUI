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
    local isPlayer = (unit == "player")
    if not isPlayer and UnitIsPlayer then
        local rawIsPlayer = UnitIsPlayer(unit)
        local isSecretPlayer = (issecretvalue and issecretvalue(rawIsPlayer)) or (canaccessvalue and not canaccessvalue(rawIsPlayer))
        if isSecretPlayer then
            isPlayer = (UnitPlayerControlled and UnitPlayerControlled(unit)) or false
        else
            isPlayer = (rawIsPlayer == true or rawIsPlayer == 1)
        end
    end

    if ((element.safeColorTapping or element.colorTapping) and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
        local t = element.colors.tapped
        element:SetStatusBarColor(t.r, t.g, t.b)
    elseif ((element.safeColorDisconnected or element.colorDisconnected) and not UnitIsConnected(unit)) then
        local t = element.colors.disconnected
        element:SetStatusBarColor(t.r, t.g, t.b)
    elseif ((element.safeColorClass or element.colorClass) and isPlayer and not UnitHasVehicleUI(unit)) then
        local _, class = UnitClass(unit)
        local isClassSecret = (issecretvalue and issecretvalue(class)) or (canaccessvalue and not canaccessvalue(class))
        local colorsClass = (element.colors and element.colors.class) or _G.RAID_CLASS_COLORS
        local t = (class and not isClassSecret and colorsClass) and colorsClass[class] or nil
        if t then
            element:SetStatusBarColor(t.r, t.g, t.b)
        else
            local fallback = (element.colors and element.colors.health) or { r = 0.2, g = 0.8, b = 0.2 }
            element:SetStatusBarColor(fallback.r, fallback.g, fallback.b)
        end
    elseif ((element.safeColorReaction or element.colorReaction) and (not isPlayer or UnitHasVehicleUI(unit))) then
        local reaction = UnitReaction(unit, "player")
        local isReactionSecret = (issecretvalue and issecretvalue(reaction)) or (canaccessvalue and not canaccessvalue(reaction))
        if not isReactionSecret and reaction and element.colors and element.colors.reaction then
            local t = element.colors.reaction[reaction]
            if t then
                element:SetStatusBarColor(t.r, t.g, t.b)
            end
        end
    elseif (element.safeColorSmooth or element.colorSmooth) then
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
