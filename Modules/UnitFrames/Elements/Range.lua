-- Range.lua
-- Custom oUF Range Element using LibRangeCheck-3.0
-- Replaces standard oUF Range (which uses UnitInRange) with LRC for better accuracy.

local addonName, ns = ...
if ns.skipLoad then return end
local oUF = ns.oUF or _G.oUF
local LRC = LibStub("LibRangeCheck-3.0", true)
local UF = RoithiUI:GetModule("UnitFrames")

function UF:CreateRange(frame)
    local element = {
        insideAlpha = 1,
        outsideAlpha = 0.55,
    }
    frame.RoithiRange = element
end

local function Update(self, event)
    local element = self.RoithiRange
    local unit = self.unit

    if (element.PreUpdate) then element:PreUpdate(unit) end

    local inRange = true

    if UnitIsConnected(unit) then
        -- LibRangeCheck usage is temporarily disabled due to 12.0.1 taint within library.
        -- Fallback to standard API.
        local rawInRange, rawCheckedRange = UnitInRange(unit)
        
        if not issecretvalue(rawCheckedRange) then
            if rawCheckedRange == false or rawCheckedRange == nil then
                inRange = true
            else
                inRange = rawInRange
            end
        else
            inRange = rawInRange
        end
            
        -- specific self check
        local isSelf = UnitIsUnit(unit, "player")
        if not issecretvalue(isSelf) then
            if isSelf then inRange = true end
        elseif unit == "player" then
            inRange = true
        end
    end

    local alphaValue
    if not issecretvalue(inRange) then
        alphaValue = (inRange == true) and element.insideAlpha or element.outsideAlpha
    else
        -- 12.0.1 MIDNIGHT Fix: Use secret-safe evaluator for alpha updates
        alphaValue = C_CurveUtil.EvaluateColorValueFromBoolean(inRange, element.insideAlpha, element.outsideAlpha)
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
