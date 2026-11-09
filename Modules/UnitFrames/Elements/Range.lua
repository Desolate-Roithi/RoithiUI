-- Range.lua
-- Custom oUF Range Element using LibRangeCheck-3.0
-- Replaces standard oUF Range (which uses UnitInRange) with LRC for better accuracy.

local addonName, ns = ...
if ns.skipLoad then return end
local oUF = ns.oUF or _G.oUF
local UF = RoithiUI:GetModule("UnitFrames")

local function IsSecret(v)
    if ns.Utils and ns.Utils.IsSecret then
        return ns.Utils.IsSecret(v)
    end
    if v == nil then return false end
    if _G.issecretvalue and _G.issecretvalue(v) then return true end
    if _G.canaccessvalue and not _G.canaccessvalue(v) then return true end
    return type(v) == "userdata"
end

function UF:CreateRange(frame)
    local element = {
        insideAlpha = 1,
        outsideAlpha = 0.55,
    }
    frame.RoithiRange = element
end

local function Update(self, _)
    local element = self.RoithiRange
    local unit = self.unit

    if (element.PreUpdate) then element:PreUpdate(unit) end

    local inRange = true

    local isConnected = UnitIsConnected and UnitIsConnected(unit)
    local isConnectedSecret = IsSecret(isConnected)
    if (not isConnectedSecret and isConnected) or isConnectedSecret then
        -- LibRangeCheck usage is temporarily disabled due to 12.0.1 taint within library.
        -- Fallback to standard API.
        local rawInRange, rawCheckedRange = UnitInRange(unit)
        
        if not IsSecret(rawCheckedRange) then
            if rawCheckedRange == false or rawCheckedRange == nil then
                inRange = true
            else
                inRange = rawInRange
            end
        else
            inRange = rawInRange
        end
            
        -- specific self check
        if ns.Utils and ns.Utils.SafeUnitIsUnit then
            local isSelf, isSelfSecret = ns.Utils.SafeUnitIsUnit(unit, "player")
            if isSelf or (isSelfSecret and unit == "player") then
                inRange = true
            end
        elseif unit == "player" then
            inRange = true
        end
    end

    local alphaValue
    if not IsSecret(inRange) then
        alphaValue = (inRange == true) and element.insideAlpha or element.outsideAlpha
    elseif _G.C_CurveUtil and _G.C_CurveUtil.EvaluateColorValueFromBoolean then
        -- 12.0.1 MIDNIGHT Fix: Use secret-safe evaluator for alpha updates
        alphaValue = _G.C_CurveUtil.EvaluateColorValueFromBoolean(inRange, element.insideAlpha, element.outsideAlpha)
    else
        alphaValue = element.insideAlpha
    end
    self:SetAlpha(alphaValue)

    if (element.PostUpdate) then element:PostUpdate(unit, inRange) end
end

local function Path(self, ...)
    return (self.RoithiRange.Override or Update)(self, ...)
end

local function ForceUpdate(element)
    return Path(element.__owner, "ForceUpdate")
end

local function Enable(self)
    local element = self.RoithiRange
    if (element) then
        element.__owner = self
        element.ForceUpdate = ForceUpdate

        -- Defaults
        if not element.insideAlpha then element.insideAlpha = 1 end
        if not element.outsideAlpha then element.outsideAlpha = 0.55 end

        -- Use native events instead of fast OnUpdate polling to avoid secret bool flickering
        if self.RegisterEvent then
            self:RegisterEvent("UNIT_IN_RANGE_UPDATE", Path)
            self:RegisterEvent("PLAYER_TARGET_CHANGED", Path, true)
            self:RegisterEvent("GROUP_ROSTER_UPDATE", Path, true)
        end

        return true
    end
end

local function Disable(self)
    local element = self.RoithiRange
    if (element) then
        if self.UnregisterEvent then
            self:UnregisterEvent("UNIT_IN_RANGE_UPDATE", Path)
            self:UnregisterEvent("PLAYER_TARGET_CHANGED", Path)
            self:UnregisterEvent("GROUP_ROSTER_UPDATE", Path)
        end
        self:SetAlpha(element.insideAlpha)
    end
end

-- Rename to RoithiRange to avoid conflict with standard oUF Range element
oUF:AddElement("RoithiRange", Update, Enable, Disable)
