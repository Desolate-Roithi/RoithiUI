-- Range.lua
-- Custom oUF Range Element using LibRangeCheck-3.0
-- Replaces standard oUF Range (which uses UnitInRange) with LRC for better accuracy.

local addonName, ns = ...
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

    local inRange, checkedRange = false, nil

    if UnitIsConnected(unit) then
        if LRC then
            -- LibRangeCheck usage
            local minRange, maxRange = LRC:GetRange(unit)
            if minRange and maxRange then
                -- Check against 40y standard (most healers)
                -- Or check if maxRange is within visible bounds
                if maxRange <= 40 then
                    inRange = true
                end
            elseif minRange then
                -- sometimes only min is returned?
                if minRange <= 40 then inRange = true end
            end

            -- Fallback or specific "Interact" checks if LRC fails or returns nil (e.g. self)
            if UnitIsUnit(unit, "player") then inRange = true end
        else
            -- Fallback to standard API if LRC missing
            inRange = UnitInRange(unit)
        end
    end

    if inRange then
        self:SetAlpha(element.insideAlpha)
    else
        self:SetAlpha(element.outsideAlpha)
    end

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

        -- Timer for range checking
        -- oUF Range usually runs on OnUpdate. We can do the same.
        self:HookScript("OnUpdate", function(_, elapsed)
            element.timer = (element.timer or 0) + elapsed
            if element.timer >= 0.2 then
                Path(self, "OnUpdate")
                element.timer = 0
            end
        end)

        return true
    end
end

local function Disable(self)
    local element = self.RoithiRange
    if (element) then
        self:SetAlpha(element.insideAlpha)
    end
end

-- Rename to RoithiRange to avoid conflict with standard oUF Range element
oUF:AddElement("RoithiRange", Update, Enable, Disable)
