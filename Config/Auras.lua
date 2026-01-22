local _, ns = ...
local oUF = ns.oUF

-- Defaults
local Defaults = {
    ShowOnlyPlayer = false, -- Only show my auras
    UseLibCustomGlow = true,
    Whitelist = {
        -- [spellID] = true (Always Show)
    },
    Blacklist = {
        -- [spellID] = true (Always Hide)
        [36032] = true, -- Arcane Charges (Power bar usually handles this)
    },
    Ignored = {
        -- Duration 0 (Infinite) check?
    }
}

-- Filter Function for oUF
local function CustomFilter(element, unit, data)
    local db = ns.db.profile.Auras

    -- 1. Whitelist (Always Show)
    if db.Whitelist[data.spellId] then
        return true
    end

    -- 2. Blacklist (Always Hide)
    if db.Blacklist[data.spellId] then
        return false
    end

    -- 3. ShowOnlyPlayer
    if db.ShowOnlyPlayer and not data.isCastByPlayer then
        return false
    end

    -- 4. Infinite Duration Hide? (Optional, configurable later)
    -- if data.duration == 0 then return false end

    -- 5. Standard Pass
    return true
end

ns.AuraFilter = CustomFilter
ns.DefaultAuraConfig = Defaults
