-- WoWAPI.lua
-- Mocks WoW 12.0.0+ API environment for testing
-- Focuses on mimicking secret values and restricted APIs

local Mock = {}

-- 1. Helper to simulate "Secret" values
-- In WoW, these are UserData or unique types that crash on match/compare
local SecretMT = {
    __add = function() error("LUA_ERR: Attempt to perform arithmetic on secret") end,
    __sub = function() error("LUA_ERR: Attempt to perform arithmetic on secret") end,
    __mul = function() error("LUA_ERR: Attempt to perform arithmetic on secret") end,
    __div = function() error("LUA_ERR: Attempt to perform arithmetic on secret") end,
    __eq = function() error("LUA_ERR: Attempt to compare secret") end,
    __lt = function() error("LUA_ERR: Attempt to compare secret") end,
    __le = function() error("LUA_ERR: Attempt to compare secret") end,
    __tostring = function() return "SecretValue" end, -- Even tostring is risky, but we return a safe string for debug
}

function Mock.MakeSecret(val)
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)
    for k, v in pairs(SecretMT) do mt[k] = v end
    mt.__index = function() error("LUA_ERR: Attempt to index secret") end
    mt.val = val -- Store hidden real value for verification if needed by "private" blizz code
    return proxy
end

-- 2. Global API Mocks
_G.issecretvalue = function(val)
    -- In our mock, we check if it has our SecretMT
    -- This is imperfect but usually sufficient for "protected" check logic
    if type(val) == "userdata" then
        -- We assume all userdata in this mock env is secret for simplicity
        return true
    end
    return false
end

_G.canaccessvalue = function(val)
    return not _G.issecretvalue(val)
end

-- Mocking C_UnitHealth (Protected in 12.0)
_G.C_UnitHealth = {}
function _G.C_UnitHealth.GetHealthPercentage(unit)
    -- Simulate restrictions based on unit
    if unit == "target" then
        return Mock.MakeSecret(0.85) -- Secret health for target
    else
        return 0.85
    end
end

-- Mocking UnitPower (Protected)
_G.UnitPower = function(unit, type)
    if unit == "target" then
        return Mock.MakeSecret(1000)
    end
    return 1000
end

_G.UnitPowerMax = function(unit, type)
    if unit == "target" then
        return Mock.MakeSecret(2000)
    end
    return 2000
end

_G.UnitHealth = function(unit)
    if unit == "target" then
        return Mock.MakeSecret(50000)
    end
    return 50000
end

_G.UnitHealthMax = function(unit)
    if unit == "target" then
        return Mock.MakeSecret(100000)
    end
    return 100000
end

-- Mocking Helpers needed for "Safe" access
_G.UnitHealthPercent = function(unit, exact, curve)
    -- In 12.0, this returns a localized string or number depending on flags
    -- We'll mock the happy path
    return 50.0
end

_G.UnitPowerPercent = function(unit, exact, curve)
    return 50.0
end

_G.CurveConstants = {
    ScaleTo100 = "ScaleTo100"
}

-- Mocking Standard WoW Globals
_G.strmatch = string.match
_G.strformat = string.format
_G.strfind = string.find
_G.strsub = string.sub
_G.GetLocale = function() return "enUS" end
_G.GetRealmName = function() return "TestRealm" end
_G.GetAddOnMetadata = function() return "1.0" end
_G.UnitName = function() return "TestPlayer" end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitFactionGroup = function() return "Alliance", "Alliance" end
_G.UnitRace = function() return "Human", "Human" end
_G.GetCurrentRegion = function() return 1 end
_G.GetCVar = function(cvar) return nil end
_G.GetBuildInfo = function() return "11.0.0", "123456", "Jan 01 2025", 110000 end
---@diagnostic disable-next-line: undefined-global
_G.GetTime = function() return os.time() end
_G.Enum = {
    SpellBookSpellBank = { Player = 0, Pet = 1 },
}

_G.C_SpellBook = {
    GetSpellBookItemType = function() return "SPELL", 123 end
}

_G.GetInventorySlotInfo = function() return 1 end
_G.GetInventoryItemID = function() return 12345 end
_G.GetItemInfo = function() return "ItemName", "Link", 1, 1, 1, "Type", "SubType", 1, "", "", 1 end

_G.C_Seasons = {
    GetActiveSeason = function() return 1 end
}

---@diagnostic disable-next-line: assign-type-mismatch
_G.UIParent = {
    firstTimeLoaded = true,
    variablesLoaded = true
}

_G.C_Timer = {
    After = function(duration, func)
        -- Immediate execution for tests, or ignore?
        -- Executing immediately might break logic expecting delay, but for load test it is fine usually.
        -- Often better to just store it or do nothing if not validating the timer logic itself.
        -- LibRangeCheck uses it for delayed init. Let's call it.
        func()
    end,
    NewTicker = function(duration, func, iterations) return {} end
}

_G.C_UnitAuras = {
    IsAuraInRefreshWindow = function(unit, auraInstanceID)
        -- Returns a Secret Boolean (mocked as user data)
        return Mock.MakeSecret(true) -- Always return true for test simplicity
    end,
    GetAuraDataByIndex = function(unit, index)
        -- Simulating an AuraData object
        return {
            auraInstanceID = 100 + index,
            spellId = 12345,
            duration = 10,
            expirationTime = _G.GetTime() + 9, -- Not pandemic
            isStealable = false,
            isBossDebuff = false,
            isCastByPlayer = true,
        }
    end
}

_G.CreateFrame = function(type, name, parent, template)
    local frame = {
        name = name,
        SetScript = function() end,
        RegisterEvent = function() end,
        UnregisterEvent = function() end,
        UnregisterAllEvents = function() end,
        SetParent = function() end,
        SetPoint = function() end,
        SetSize = function() end,
        Hide = function() end,
        Show = function() end,
        GetParent = function() return parent end,
        GetName = function(self) return self.name end,
        IsVisible = function() return true end,
        SetAlpha = function() end,
        EnableMouse = function() end,
        CreateTexture = function()
            return {
                SetTexture = function() end,
                SetAllPoints = function() end,
                SetPoint = function() end,
                SetVertexColor = function() end,
                Show = function() end,
                Hide = function() end,
                SetBlendMode = function() end,
            }
        end,
        -- 12.0.1 Secret API
        SetShownFromSecret = function(self, secret)
            if not issecretvalue(secret) then
                error("LUA_ERR: SetShownFromSecret requires a secret value")
            end
            -- In mock, we assume it works.
        end,
        SetAllPoints = function() end, -- Added missing mixin
    }
    return frame
end

-- Mocking bit library (WoW 5.1 extension)
_G.bit = {
    band   = function(a, b) return 0 end, -- Dummy
    bor    = function(a, b) return 0 end,
    lshift = function(a, n) return 0 end,
    rshift = function(a, n) return 0 end,
}

-- Mocking SharedMedia via a compatible LibStub
-- Real LibStub checks for .minor, so we provide a mock with minor=0 to be overwritten
_G.LibStub = {
    libs = {},
    minors = {},
    minor = 0, -- Force upgrade by real lib
    GetLibrary = function(self, major, silent)
        if major == "LibSharedMedia-3.0" then
            return {
                Register = function() end,
                Fetch = function(_, _, default) return default or "Interface\\Addons\\Mock\\Texture" end,
                MediaType = { STATUSBAR = "statusbar", FONT = "font" }
            }
        end
        return self.libs[major]
    end,
    NewLibrary = function(self, major, minor)
        self.libs[major] = {}
        self.minors[major] = minor
        return self.libs[major]
    end
}
setmetatable(_G.LibStub, { __call = _G.LibStub.GetLibrary })


-- Global Aliases (WoW 5.1+)
_G.tinsert = table.insert
_G.tremove = table.remove
---@diagnostic disable-next-line: duplicate-set-field
_G.wipe = function(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

return Mock
