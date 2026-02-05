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

-- 12.0.1 Secrets Namespace
_G.C_Secrets = {
    ShouldUnitHealthMaxBeSecret = function(unit) return unit == "target" end,
    ShouldUnitPowerBeSecret = function(unit) return unit == "target" end,
}

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

_G.UnitGetTotalAbsorbs = function(unit)
    if unit == "target" then
        return Mock.MakeSecret(5000)
    end
    return 0
end

-- State Drivers
_G.RegisterStateDriver = function(frame, state, condition) end
_G.UnregisterStateDriver = function(frame, state) end

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
_G.issecurevariable = function() return false end
_G.DefaultTooltipMixin = {
    OnLeave = function() end,
}
_G.InCombatLockdown = function() return false end

_G.GenerateClosure = function(func, ...)
    local args = { ... }
    return function(...)
        local callArgs = { unpack(args) }
        local moreArgs = { ... }
        for _, v in ipairs(moreArgs) do
            table.insert(callArgs, v)
        end
        return func(unpack(callArgs))
    end
end
_G.GetCVar = function(cvar) return nil end
_G.GetBuildInfo = function() return "11.0.0", "123456", "Jan 01 2025", 110000 end
---@diagnostic disable-next-line: undefined-global
_G.GetTime = function() return os.time() end
_G.Enum = {
    SpellBookSpellBank = { Player = 0, Pet = 1 },
    EditModeSettingDisplayType = { Checkbox = 0, Dropdown = 1, Slider = 2, Divider = 3 },
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

-- Global Frames (mocked)
_G.UIParent = {
    name = "UIParent",
    GetSize = function() return 1920, 1080 end,
    GetWidth = function() return 1920 end,
    GetHeight = function() return 1080 end,
    GetParent = function() return nil end,
    IsVisible = function() return true end,
    GetScale = function() return 1 end,
}

_G.CreateFrame = function(type, name, parent, template)
    local frame = {
        name = name,
        parent = parent,
        Layout = function() end,
        SetSize = function() end,
        SetPoint = function() end,
        GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
        ClearAllPoints = function() end,
        SetAllPoints = function() end,
        SetParent = function() end,
        GetParent = function() return parent end,
        GetWidth = function() return 350 end,
        GetHeight = function() return 50 end,
        GetSize = function() return 350, 50 end,
        Hide = function() end,
        Show = function() end,
        SetShown = function() end,
        IsVisible = function() return true end,
        IsShown = function() return true end,
        SetAlpha = function() end,
        SetScale = function() end,
        GetScale = function() return 1 end,
        SetText = function() end,
        SetEnabled = function() end,
        SetOnClickHandler = function() end,
        SetMovable = function() end,
        StartMoving = function() end,
        StopMovingOrSizing = function() end,
        SetClampedToScreen = function() end,
        SetDontSavePosition = function() end,
        SetFrameStrata = function() end,
        SetFrameLevel = function() end,
        SetPropagateKeyboardInput = function() end,
        SetAttribute = function() end,
        EnableMouse = function() end,
        RegisterForDrag = function() end,
        SetRegisterForClicks = function() end,
        ShowSelected = function() end,
        ShowSelectedFromSecret = function() end,
        GetName = function(self) return self.name or "" end,
        RegisterEvent = function() end,
        UnregisterEvent = function() end,
        scripts = {},
        SetScript = function(self, script, handler)
            self.scripts = self.scripts or {}
            self.scripts[script] = handler
        end,
        GetScript = function(self, script)
            self.scripts = self.scripts or {}
            return self.scripts[script]
        end,

        GetLeft = function() return 0 end,
        GetTop = function() return 0 end,
        GetRight = function() return 0 end,
        GetBottom = function() return 0 end,
        CreateFontString = function()
            return {
                SetPoint = function() end,
                SetText = function() end,
                SetTextColor = function() end,
                SetFont = function() end,
                GetStringWidth = function() return 100 end,
                SetJustifyH = function() end,
                SetJustifyV = function() end,
                SetWidth = function() end,
                SetHeight = function() end,
                SetSize = function() end,
                Show = function() end,
                Hide = function() end,
                SetAlpha = function() end,
                ClearAllPoints = function() end,
                SetShadowOffset = function() end,
            }
        end,
        CreateTexture = function()
            return {
                SetTexture = function() end,
                SetAllPoints = function() end,
                SetPoint = function() end,
                SetSize = function() end,
                SetAlpha = function() end,
                SetBlendMode = function() end,
                Show = function() end,
                Hide = function() end,
                SetShown = function() end,
                SetColorTexture = function() end,
            }
        end,
        SetShownFromSecret = function(self, secret)
            if not issecretvalue(secret) then
                error("LUA_ERR: SetShownFromSecret requires a secret value")
            end
            -- In mock, we assume it works.
        end,
        SetAllPoints = function() end,               -- Added missing mixin
        HookScript = function(self, script, handler) -- Added for 12.0.1+ Elements
            -- Mock: Store handler? Or just no-op.
            -- No-op is fine for simple visibility tests.
        end,
    }
    return frame
end

-- WoW 10.0+ Object Pools
_G.CreateUnsecuredObjectPool = function(creationFunc, resetterFunc)
    local pool = {
        activeObjects = {},
        inactiveObjects = {},
        creationFunc = creationFunc,
        resetterFunc = resetterFunc,
    }
    function pool:Acquire(...)
        local obj = table.remove(self.inactiveObjects)
        local isNew = false
        if not obj then
            obj = self.creationFunc(self, ...)
            isNew = true
        end
        table.insert(self.activeObjects, obj)
        return obj, isNew
    end

    function pool:Release(obj)
        for i, o in ipairs(self.activeObjects) do
            if o == obj then
                table.remove(self.activeObjects, i)
                break
            end
        end
        if self.resetterFunc then
            self.resetterFunc(self, obj)
        end
        table.insert(self.inactiveObjects, obj)
    end

    function pool:ReleaseAll()
        for _, obj in ipairs(self.activeObjects) do
            if self.resetterFunc then
                self.resetterFunc(self, obj)
            end
            table.insert(self.inactiveObjects, obj)
        end
        self.activeObjects = {}
    end

    return pool
end

-- WoW Mixin Utility
_G.Mixin = function(target, ...)
    for i = 1, select("#", ...) do
        local source = select(i, ...)
        for k, v in pairs(source or {}) do
            target[k] = v
        end
    end
    return target
end

-- Global Frames (mocked)
_G.EditModeManagerFrame = _G.CreateFrame("Frame", "EditModeManagerFrame", _G.UIParent)
_G.EditModeManagerFrame.ClearSelectedSystem = function() end
_G.EditModeSystemSettingsDialog = _G.CreateFrame("Frame", "EditModeSystemSettingsDialog", _G.UIParent)

-- EventRegistry Mock
_G.EventRegistry = {
    callbacks = {},
    RegisterCallback = function(self, event, func)
        self.callbacks[event] = self.callbacks[event] or {}
        table.insert(self.callbacks[event], func)
    end,
    TriggerEvent = function(self, event, ...)
        if self.callbacks[event] then
            for _, func in ipairs(self.callbacks[event]) do
                func(event, ...)
            end
        end
    end,
    RegisterFrameEventAndCallback = function(self, event, func)
        self:RegisterCallback(event, func)
    end
}

-- C_EditMode Mock
_G.BACKDROP_TUTORIAL_16_16 = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

_G.WHITE_FONT_COLOR = { r = 1, g = 1, b = 1, GetRGB = function() return 1, 1, 1 end }
_G.DISABLED_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5, GetRGB = function() return 0.5, 0.5, 0.5 end }

_G.C_EditMode = {
    GetLayouts = function()
        return {
            activeLayout = 1,
            layouts = {
                { layoutName = "Modern" },
                { layoutName = "Classic" }
            }
        }
    end
}

_G.CopyTable = function(t)
    if not t then return nil end
    local res = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            res[k] = _G.CopyTable(v)
        else
            res[k] = v
        end
    end
    return res
end

-- Secure call mocks
_G.securecallfunction = function(f, ...) return f(...) end
_G.hooksecurefunc = function(t, k, f)
    local original = t[k]
    t[k] = function(...)
        original(...)
        f(...)
    end
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
    minor = 0,
    GetLibrary = function(self, major, silent)
        if major == "LibSharedMedia-3.0" and not self.libs[major] then
            return {
                Register = function() end,
                Fetch = function(_, _, default) return default or "Interface\\Addons\\Mock\\Texture" end,
                MediaType = { STATUSBAR = "statusbar", FONT = "font" }
            }
        end
        if not self.libs[major] and not silent then
            error("Library " .. major .. " not found")
        end
        return self.libs[major], self.minors[major]
    end,
    NewLibrary = function(self, major, minor)
        if self.minors[major] and self.minors[major] >= minor then
            return nil
        end
        self.libs[major] = self.libs[major] or {}
        self.minors[major] = minor
        return self.libs[major], minor
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
table.wipe = _G.wipe


_G.UnitExists = function(unit)
    -- Mock: return true if unit has some valid string?
    -- For tests, usually "player", "target" etc are valid.
    -- Or check if unit is in some mock db?
    -- Simplest: Return true for now, or true for standard units.
    return unit and
        (unit == "player" or unit == "target" or unit == "focus" or unit == "pet" or string.match(unit, "boss%d"))
end

return Mock
