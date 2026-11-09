-- SafeHealth.lua
-- Custom oUF Health Element that safely handles WoW 12.0.1+ Secret Values
-- Prevents crashes from arithmetic/comparison on Secret properties.
-- Uses `UnitHealthPercent` for logic and `StatusBar:SetValue` for display.

local _, ns = ...
local oUF = ns.oUF or _G.oUF

local smoothCurveCache = nil
local function GetSmoothColorCurve(grad)
    if smoothCurveCache then return smoothCurveCache end
    if not (_G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve and _G.CreateColor) then
        return nil
    end
    local ok, curve = pcall(function()
        local c = _G.C_CurveUtil.CreateColorCurve()
        local g = grad or { 1, 0, 0, 1, 1, 0, 0, 1, 0 }
        c:AddPoint(0.0, _G.CreateColor(g[1] or 1, g[2] or 0, g[3] or 0))
        c:AddPoint(0.5, _G.CreateColor(g[4] or 1, g[5] or 1, g[6] or 0))
        c:AddPoint(1.0, _G.CreateColor(g[7] or 0, g[8] or 1, g[9] or 0))
        return c
    end)
    if ok and curve then
        smoothCurveCache = curve
        return curve
    end
    return nil
end

local function Update(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_TARGET" and self.unit == "targettarget") or event == "ForceUpdate" then
        unit = self.unit
    end
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

    if not isPlayer and UnitGUID and unit == "targettarget" then
        local guid = UnitGUID(unit)
        local isSecretGuid = (issecretvalue and issecretvalue(guid)) or (canaccessvalue and not canaccessvalue(guid))
        if not isSecretGuid and guid and type(guid) == "string" and (guid:find("^Player%-") or guid:find("^Item%-")) then
            isPlayer = true
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
        if not class and UnitGUID then
            local guid = UnitGUID(unit)
            local isSecretGuid = (ns.Utils and ns.Utils.IsSecret and ns.Utils.IsSecret(guid)) or (issecretvalue and issecretvalue(guid))
            if not isSecretGuid and guid and _G.GetPlayerInfoByGUID then
                local _, guidClass = _G.GetPlayerInfoByGUID(guid)
                class = guidClass
            end
        end
        if not class and ns.Utils and ns.Utils.SafeUnitIsUnit then
            local isPlayerMatch = ns.Utils.SafeUnitIsUnit(unit, "player")
            if isPlayerMatch then
                local _, pClass = UnitClass("player")
                class = pClass
            else
                local isTargetMatch = ns.Utils.SafeUnitIsUnit(unit, "target")
                if isTargetMatch then
                    local _, tClass = UnitClass("target")
                    class = tClass
                end
            end
        end

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
        local isPerSecret = (ns.Utils and ns.Utils.IsSecret and ns.Utils.IsSecret(per)) or (issecretvalue and issecretvalue(per))
        if not isPerSecret and self.ColorGradient then
            local r, g, b = self:ColorGradient(per, 100, unpack(element.smoothGradient or self.colors.smooth))
            element:SetStatusBarColor(r, g, b)
        else
            local curve = GetSmoothColorCurve(element.smoothGradient or (self.colors and self.colors.smooth))
            local colored = false
            if curve and _G.UnitHealthPercent then
                local ok, col = pcall(_G.UnitHealthPercent, unit, false, curve)
                if ok and col and col.GetRGB then
                    local cr, cg, cb = col:GetRGB()
                    element:SetStatusBarColor(cr, cg, cb)
                    colored = true
                end
            end
            if not colored then
                local fallback = (element.colors and element.colors.health) or { r = 0.2, g = 0.8, b = 0.2 }
                element:SetStatusBarColor(fallback.r, fallback.g, fallback.b)
            end
        end
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
        if self.unit == "targettarget" then
            self:RegisterEvent("UNIT_TARGET", Path)
            self:RegisterEvent("PLAYER_TARGET_CHANGED", Path)
        end

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
        if self.unit == "targettarget" then
            self:UnregisterEvent("UNIT_TARGET", Path)
            self:UnregisterEvent("PLAYER_TARGET_CHANGED", Path)
        end
    end
end

oUF:AddElement("SafeHealth", Update, Enable, Disable)
