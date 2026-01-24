-- Tests/Test_Bars_Regression.lua
-- Regression Test for Power Bar White Rectangle (Missing PowerBarColor Global)

local passed = 0
local failed = 0

local function Assert(cond, msg)
    if cond then
        passed = passed + 1
        -- print("PASS: " .. (msg or ""))
    else
        failed = failed + 1
        print("FAIL: " .. (msg or ""))
        error(msg or "Assertion Failed")
    end
end

-- 1. Mock Environment
_G.RoithiUI = {
    GetModule = function(self, name)
        return self[name] or {}
    end,
    db = { profile = { UnitFrames = {} } } -- Minimal DB
}
_G.RoithiUI.UnitFrames = {}                -- Mock Module

-- Fix: Ensure DB entry exists for player so it doesn't default to hidden
_G.RoithiUI.db.profile.UnitFrames["player"] = { powerEnabled = true }

-- Mock LibStub & Libs
_G.LibStub = {
    GetLibrary = function(self, lib) return self.libs[lib] end,
    libs = {}
}
setmetatable(_G.LibStub, { __call = function(t, lib) return t:GetLibrary(lib) end })

-- Mock LibRoithi
_G.LibStub.libs["LibRoithi-1.0"] = {
    mixins = {
        CreateBackdrop = function() end
    }
}
-- Mock LSM
_G.LibStub.libs["LibSharedMedia-3.0"] = {
    Fetch = function() return "Interface\\SomeTexture" end
}
-- Mock WoW API
_G.CreateFrame = function(type, name, parent)
    local f = {
        GetName = function() return name or "MockFrame" end,
        SetPoint = function() end,
        ClearAllPoints = function() end,
        SetParent = function() end,
        SetAlpha = function() end,
        SetHeight = function() end,
        SetWidth = function() end,
        GetFrameLevel = function() return 1 end,
        SetFrameLevel = function() end,
        GetStatusBarTexture = function() end,
        SetStatusBarTexture = function() end,
        CreateTexture = function()
            return {
                SetAllPoints = function() end,
                SetTexture = function() end,
                SetVertexColor = function() end,
                SetBlendMode = function() end,
                SetPoint = function() end,
                SetWidth = function() end,
                Hide = function() end,
                Show = function() end,
                SetAlpha = function() end,
            }
        end,
        CreateFontString = function()
            return {
                SetPoint = function() end,
                SetText = function() end,
                Hide = function() end,
                Show = function() end
            }
        end,
        Hide = function() end,
        Show = function(s) s.isShow = true end,
        SetScript = function(s, k, v)
            s.scripts = s.scripts or {}; s.scripts[k] = v
        end,
        HookScript = function() end,
        RegisterEvent = function() end,
        RegisterUnitEvent = function() end,
        SetStatusBarColor = function(s, r, g, b)
            s.r = r; s.g = g; s.b = b
        end,
        SetMinMaxValues = function() end,
        SetValue = function() end,
        GetWidth = function() return 100 end,           -- Added
        GetMinMaxValues = function() return 0, 100 end, -- Added
    }
    return f
end
_G.UnitExists = function() return true end
_G.UnitPowerType = function() return 0, "MANA" end
_G.UnitPowerMax = function() return 100 end
_G.UnitPower = function() return 50 end

-- 2. Load Bars.lua (We need to manually execute it or loadfile it)
-- Since we are in a separate process, we loadfile the target
local chunk, err = loadfile("Modules/UnitFrames/Elements/Bars.lua")
if not chunk then
    print("CRITICAL: Could not load Bars.lua: " .. tostring(err))
    os.exit(1)
end
-- Run the chunk with the mocks in _G
chunk("RoithiUI", _G.RoithiUI)

-- 3. Execute Registry Test
local UF = RoithiUI.UnitFrames

print("[TEST] Setup: PowerBarColor is NIL (Testing Fallback)")
_G.PowerBarColor = nil -- FORCE ERROR CONDITION

local mockFrame = CreateFrame("Frame", "MockUnit", nil)
mockFrame.unit = "player"

-- Initialize Power Bar
UF:CreatePowerBar(mockFrame)

-- Trigger UpdatePower
local OnShow = mockFrame.Power.scripts["OnShow"]

if not OnShow then
    print("[FAIL] OnShow script not registered! Logic likely aborted early.")
    os.exit(1)
end

print("[TEST] Running UpdatePower...")
local status, err = pcall(function()
    OnShow(mockFrame.Power)
end)

if not status then
    print("[FAIL] Crash Reproduced (Fix Failed): " .. tostring(err))
    os.exit(1)
else
    print("[PASS] UpdatePower ran safely with PowerBarColor = nil")
    -- Verify Color was set to Fallback Blue (Mana default in my table)
    -- Mana is 0, 0, 1
    local p = mockFrame.Power
    if p.r == 0 and p.g == 0 and p.b == 1 then
        print("[PASS] Fallback Color Correct (Blue)")
        passed = passed + 1
    else
        print("[FAIL] Color Mismatch: " .. tostring(p.r) .. "," .. tostring(p.g) .. "," .. tostring(p.b))
        failed = failed + 1
    end
end
