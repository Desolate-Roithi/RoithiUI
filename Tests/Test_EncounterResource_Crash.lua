-- Test_EncounterResource_Crash.lua
-- Fix regression: PlayerPowerBarAlt crashes accessing 'barInfo' because we Show() without Event

local tests = {}

-- MOCKS
_G.DoNothing = function() end
_G.UIParent = {
    SetScale = DoNothing,
    GetScale = function() return 1 end
}

-- 1. Mock PlayerPowerBarAlt
_G.PlayerPowerBarAlt = {
    scripts = {},
    events = {},
    shown = false,

    GetScript = function(self, s) return self.scripts[s] end,
    SetScript = function(self, s, f) self.scripts[s] = f end,
    RegisterEvent = function(self, e) self.events[e] = true end,
    UnregisterEvent = function(self, e) self.events[e] = false end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    IsShown = function(self) return self.shown end,
}
_G.hooksecurefunc = function(t, method, hook)
    -- Rudimentary hook mock
    local old = t[method]
    t[method] = function(...)
        if old then old(...) end
        hook(...)
    end
end
_G.UnitPowerBarID = function(unit) return 123 end -- Return valid ID

-- Mock OnUpdate script (Blizzard's)
local MockBlizzardOnUpdate = function(self)
    -- Mimic crash if barInfo missing
    if not self.barInfo then
        error("CRASH: attempt to index field 'barInfo' (a nil value)")
    end
end
_G.PlayerPowerBarAlt.scripts["OnUpdate"] = MockBlizzardOnUpdate

-- Mock OnEvent (Blizzard's setup)
local MockBlizzardOnEvent = function(self, event, unit)
    -- Simulation: Blizzard code checks if unit == "player" (or nil implying player for some events)
    -- We'll require "player" to mock the failure cleanly if it was missing.
    -- AND we allow 'failMode' to simulate GetUnitPowerBarInfo returning nil despite ID.
    if event == "UNIT_POWER_BAR_SHOW" then
        if unit == "player" and not self.failMode then
            self.barInfo = { someData = true }
        else
            -- If arg missing or failMode, barInfo stays nil
        end
    end
end
_G.PlayerPowerBarAlt.scripts["OnEvent"] = MockBlizzardOnEvent


-- Load Module
local chunk, err = loadfile("Modules/UnitFrames/Elements/EncounterResource.lua")
if not chunk then error(err) end

-- Mock RoithiUI Core
_G.RoithiUI = {
    GetModule = function() return {} end, -- return empty table as UF module holder
    db = { profile = {} }
}
-- Mock Libs
_G.LibStub = function(name)
    if name == "LibRoithi-1.0" then
        return { mixins = { CreateBackdrop = DoNothing, SetFont = DoNothing, SafeFormat = string.format } }
    elseif name == "LibSharedMedia-3.0" then
        return { Fetch = function() return "Texture" end }
    elseif name == "LibEditMode" then
        return nil
    end
end

-- Run Module Loader
-- Note: Module code does "local UF = RoithiUI:GetModule..."
-- So we need RoithiUI to work.
-- We also need to capture what UF "is".
-- The file executes immediately. We need to pass arguments.
local UF_Hub = { frames = {} }
_G.RoithiUI.GetModule = function() return UF_Hub end

chunk("RoithiUI", {})

-- TEST: Crash Reproduction
local function Test_Restoration_Crash()
    -- 1. Enable Roithi Encounter Bar (Disable Blizzard)
    -- This removes OnUpdate and hook Show
    UF_Hub:ToggleEncounterResource(true)

    if _G.PlayerPowerBarAlt.scripts["OnUpdate"] ~= nil then
        error("FAIL: OnUpdate should be nil after disable")
    end

    -- 2. Disable Roithi Encounter Bar (Enable Blizzard)
    -- This RESTORES OnUpdate and calls Show()
    -- CURRENTLY: logic does NOT fire OnEvent, so barInfo remains nil.
    -- Calling Show() puts it in state where OnUpdate (restored) will run next frame.

    -- We simulate the "Next Frame" via manually calling OnUpdate if it exists?
    -- The ToggleBlizzard function re-assigns OnUpdate.

    UF_Hub:ToggleEncounterResource(false)

    local onUpdate = _G.PlayerPowerBarAlt:GetScript("OnUpdate")
    if not onUpdate then
        error("FAIL: OnUpdate not restored")
    end

    if not _G.PlayerPowerBarAlt:IsShown() then
        -- Wait, if barInfo is nil, we expect it NOT to be shown now with the fix!
        -- So my previous assertion "Should be shown" is now WRONG if we are testing the "failMode" branch logic?
        -- But here we expect SUCCESS. We expect barInfo to be present.
        -- So it SHOULD be shown.
        if _G.PlayerPowerBarAlt.barInfo then
            error("FAIL: Should be shown if ID exists and barInfo is present")
        else
            -- If barInfo is nil (unexpected), then not shown is Correct behavior (Safe), but failure of restoration.
            -- But in this test run, we expect it to work.
        end
    end

    -- 3. Simulate Frame Render -> OnUpdate
    -- This SHOULD crash if barInfo is nil
    local status, err = pcall(onUpdate, _G.PlayerPowerBarAlt)
    if not status then
        return true -- It crashed
    end
    return false
end

-- Run scenario: Fix Applied
-- We expect NO Crash.
local crashed = Test_Restoration_Crash()
if crashed then
    error("FAIL: Regression! PlayerPowerBarAlt crashed on restore.")
else
    print("PASS: PlayerPowerBarAlt restoration safe (No Crash).")
end
