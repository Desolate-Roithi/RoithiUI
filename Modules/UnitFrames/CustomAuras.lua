local _, ns = ...

-- Defaults
local Defaults = {
    ShowOnlyPlayer = false, -- Only show my auras
    UseLibCustomGlow = true,
    Whitelist = {
        -- [spellID] = true (Always Show)
    },
    Blacklist = {
        -- [spellID] = true (Always Hide)
        [36032] = true,  -- Arcane Charges (Power bar usually handles this)
        [57724] = true,  -- Sated (Bloodlust)
        [57723] = true,  -- Exhaustion (Heroism)
        [80354] = true,  -- Temporal Displacement (Time Warp)
        [95809] = true,  -- Insanity (Ancient Hysteria)
        [264689] = true, -- Fatigued (Primal Rage)
        [390435] = true, -- Allied Ether (Fury of the Aspects debuff)
        [124275] = true, -- Light Stagger
        [124274] = true, -- Moderate Stagger
        [124273] = true, -- Heavy Stagger
    },
    Ignored = {
        -- Duration 0 (Infinite) check?
    }
}

-- Filter Function for oUF
local function CustomFilter(element, unit, data)
    local db = ns.db.profile.Auras
    local issecretvalue = _G.issecretvalue or function(...) return false end
    local RoithiUI = _G.RoithiUI

    local isSecretSpell = issecretvalue(data.spellId)
    local isSecretIcon = issecretvalue(data.icon)

    -- 1. Whitelist (Always Show)
    if not isSecretSpell and db.Whitelist and db.Whitelist[data.spellId] then
        return true
    end

    -- 2. Blacklist (Always Hide)
    local inCombat = InCombatLockdown and InCombatLockdown()
    local isBlacklisted = false
    if db.Blacklist then
        if not inCombat and not isSecretSpell then
            if db.Blacklist[data.spellId] then
                isBlacklisted = true
                if data.icon and not isSecretIcon then
                    RoithiUI.BlacklistCache = RoithiUI.BlacklistCache or {}
                    RoithiUI.BlacklistCache[data.icon] = true
                end
            end
        end
        if not isBlacklisted and data.icon and not isSecretIcon then
            RoithiUI.BlacklistCache = RoithiUI.BlacklistCache or {}
            if RoithiUI.BlacklistCache[data.icon] then
                isBlacklisted = true
            end
        end
    end

    if isBlacklisted then
        return false
    end

    -- 3. ShowOnlyPlayer
    if db.ShowOnlyPlayer and not data.isCastByPlayer then
        return false
    end

    -- 5. Standard Pass
    return true
end

ns.AuraFilter = CustomFilter
ns.DefaultAuraConfig = Defaults
