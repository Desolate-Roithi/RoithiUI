local addonName, ns = ...

-- Only load if manually invoked or configured? 
-- Ideally this is a separate file we can /run or /load.
-- But since it's a file in the addon, it executes on load unless we wrap it.

SLASH_ROITHISECRETS1 = "/roithi_secrets"
SLASH_ROITHISECRETS2 = "/rs"

local isSimulating = false
local originalUnitPower = UnitPower
local originalUnitPowerMax = UnitPowerMax
local originalC_Secrets = C_Secrets

-- Mock Secret Userdata
local SecretMetatable = {
    __tostring = function() return "SecretUserdata" end,
    __add = function() error("Cannot perform arithmetic on Secret") end,
    __sub = function() error("Cannot perform arithmetic on Secret") end,
    __mul = function() error("Cannot perform arithmetic on Secret") end,
    __div = function() error("Cannot perform arithmetic on Secret") end,
    __lt = function() error("Cannot compare Secret") end,
    __le = function() error("Cannot compare Secret") end,
    __eq = function() return false end, -- Secrets are unique?
}

local function CreateSecret(value)
    local secret = newproxy(true)
    local meta = getmetatable(secret)
    meta.__tostring = SecretMetatable.__tostring
    meta.__add = SecretMetatable.__add
    meta.__lt = SecretMetatable.__lt
    -- incomplete validation but enough to crash loose code
    return secret
end

local function EnableSecrets()
    if isSimulating then return end
    isSimulating = true
    print("|cff00ff00RoithiUI:|r Secrets Simulation [ENABLED]")

    -- Mock C_Secrets
    if not C_Secrets then
        C_Secrets = {}
    end
    
    C_Secrets.IsSecret = function(val)
        return type(val) == "userdata" and tostring(val) == "SecretUserdata"
    end

    -- Hook UnitPower
    UnitPower = function(unit, type, unmodified)
        if unit == "player" then
            -- Simulate everything as secret for player to test robustness
            return CreateSecret(0)
        end
        return originalUnitPower(unit, type, unmodified)
    end
    
    -- Hook UnitPowerMax
    UnitPowerMax = function(unit, type, unmodified)
        if unit == "player" then
            return CreateSecret(0)
        end
        return originalUnitPowerMax(unit, type, unmodified)
    end
end

local function DisableSecrets()
    if not isSimulating then return end
    isSimulating = false
    print("|cff00ff00RoithiUI:|r Secrets Simulation [DISABLED]")
    
    UnitPower = originalUnitPower
    UnitPowerMax = originalUnitPowerMax
    
    if originalC_Secrets == nil then
        C_Secrets = nil
    end
end

SlashCmdList["ROITHISECRETS"] = function(msg)
    if msg == "on" then
        EnableSecrets()
    elseif msg == "off" then
        DisableSecrets()
    else
        print("Usage: /rs [on|off]")
    end
end
