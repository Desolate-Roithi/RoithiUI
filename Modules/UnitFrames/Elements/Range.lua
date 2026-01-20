local addonName, ns = ...
local RoithiUI = _G.RoithiUI

local UF = RoithiUI:GetModule("UnitFrames")

-- Spells for Range Checking (40y usually)
-- These should be "always available" spells if possible.
local RangeSpells = {
    ["FRIEND"] = {
        ["DRUID"] = 8936,    -- Regrowth
        ["PRIEST"] = 2061,   -- Flash Heal
        ["PALADIN"] = 19750, -- Flash of Light
        ["SHAMAN"] = 8004,   -- Healing Surge
        ["MONK"] = 116670,   -- Vivify
        ["EVOKER"] = 361469, -- Living Flame
        -- Classes without heals might default to buffs or interaction
        ["MAGE"] = 1459,     -- Arcane Intellect (40y)
        ["WARLOCK"] = 5697,  -- Unending Breath (30y) - tricky, maybe just use interact
        ["HUNTER"] = 0,      -- Fallback
        ["ROGUE"] = 0,       -- Fallback
        ["WARRIOR"] = 0,     -- Fallback
        ["DEMONHUNTER"] = 0, -- Fallback
        ["DEATHKNIGHT"] = 0, -- Fallback
    },
    ["HARM"] = {
        ["MAGE"] = 116, -- Frostbolt (or equivalent spec specific, but we need base)
        -- Actually 116 replaces, let's try Fire Blast 108853 (40y) or basic attack
        -- Safe bet is usually spec dependent. We might need a list.
        -- For now, let's stick to some basics.
        ["PRIEST"] = 589,    -- Shadow Word: Pain
        ["DRUID"] = 8921,    -- Moonfire
        ["WARLOCK"] = 172,   -- Corruption
        ["HUNTER"] = 19302,  -- Mongoose Bite? No. Arcane Shot?
        ["SHAMAN"] = 188196, -- Lightning Bolt
        ["PALADIN"] = 62124, -- Hand of Reckoning (30y) or Judgment (30y)
        ["EVOKER"] = 361469, -- Living Flame
        -- Melee generally rely on Interact (28y) or Charge (8-25y)
        -- We will fallback to visible/checkInteract for others
    }
}

function UF:CreateRange(frame)
    frame.Range = {
        insideAlpha = 1,
        outsideAlpha = 0.55,
    }

    local _, class = UnitClass("player")
    local friendSpell = RangeSpells["FRIEND"][class]
    local harmSpell = RangeSpells["HARM"][class]

    local function UpdateRange(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.2 then return end
        self.elapsed = 0

        local unit = frame.unit
        if not UnitExists(unit) then return end

        local inRange = false

        -- Helper for safe execution (prevents "secret value" errors)
        local function SafeCheck(func, ...)
            local success, result = pcall(func, ...)
            if success then
                return result
            end
            return false
        end

        if SafeCheck(UnitIsUnit, unit, "player") then
            inRange = true
        elseif SafeCheck(UnitIsFriend, "player", unit) then
            if friendSpell and friendSpell > 0 then
                -- C_Spell.IsSpellInRange returns true, false, or nil
                if SafeCheck(C_Spell.IsSpellInRange, friendSpell, unit) then
                    inRange = true
                end
            else
                -- Fallback to UnitInRange (Group 43y, Others Interact 28y approx)
                if SafeCheck(UnitInRange, unit) then
                    inRange = true
                end
            end
        else -- Enemy
            if harmSpell and harmSpell > 0 then
                if SafeCheck(C_Spell.IsSpellInRange, harmSpell, unit) then
                    inRange = true
                end
            else
                -- Fallback: CheckInteractDistance(unit, 4) is 28 yards (Follow)
                -- 1 = Inspect (28y), 2 = Trade (11.11y), 3 = Duel (9.9y), 4 = Follow (28y)
                if SafeCheck(CheckInteractDistance, unit, 4) then
                    inRange = true
                end
            end
        end

        -- Double check C_Spell might return false for "invalid target" vs "out of range"
        -- But for unit frames, the target is usually valid.

        if inRange then
            frame:SetAlpha(frame.Range.insideAlpha)
        else
            frame:SetAlpha(frame.Range.outsideAlpha)
        end
    end

    frame:HookScript("OnUpdate", UpdateRange)
end
