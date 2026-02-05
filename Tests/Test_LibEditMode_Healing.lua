package.path = "Tests/Mock/?.lua;" .. package.path
require("WoWAPI")

-- Additional Mocks for LibEditMode dependencies
_G.Mixin = function(obj, ...)
    for i = 1, select("#", ...) do
        local m = select(i, ...)
        for k, v in pairs(m) do obj[k] = v end
    end
    return obj
end
_G.GenerateClosure = function(func, ...)
    local args = { ... }
    return function() return func(unpack(args)) end
end
_G.CreateUnsecuredObjectPool = function(c, r)
    return {
        Acquire = function()
            local obj = _G.CreateFrame("Frame") -- Mock object
            return obj, true
        end,
        Release = function() end
    }
end
_G.EditModeSystemSettingsDialog = _G.CreateFrame("Frame")
_G.EditModeManagerFrame = _G.CreateFrame("Frame")
_G.EventRegistry = {
    RegisterCallback = function() end,
    RegisterFrameEventAndCallback = function() end
}
_G.hooksecurefunc = function() end
_G.Enum = { EditModeSettingDisplayType = {} } -- Mock Enum
_G.CopyTable = function(t)
    local n = {}
    for k, v in pairs(t) do n[k] = v end
    return n
end
_G.InCombatLockdown = function() return false end
_G.ColorPickerFrame = _G.CreateFrame("Frame")
_G.ColorPickerFrame.GetColorRGB = function() return 1, 1, 1 end
_G.ColorPickerFrame.GetColorAlpha = function() return 1 end


-- Helper to load file
local function LoadLibFile(path)
    local chunk, err = loadfile(path)
    if not chunk then error(err) end
    chunk()
end

-- Load LibStub (Real)
LoadLibFile("Libs/LibStub/LibStub.lua")

-- Load LibEditMode (Real)
LoadLibFile("Libs/LibEditMode/LibEditMode.lua")

-- Verify LibEditMode loaded
local lib = LibStub("LibEditMode-Roithi")

-- Verify Widgets Installed (Phase 1)
if lib.SettingType.CollapsibleHeader ~= 11 then
    error("FAIL: CollapsibleHeader should be 11, got " .. tostring(lib.SettingType.CollapsibleHeader))
end
if not lib.internal.GetPool then
    -- Polyfill check
    error("FAIL: internal.CreatePool polyfill missing")
end
if not lib.internal:GetPool(11) then
    error("FAIL: Pool 11 should exist")
end

print("Initial Load: OK")

-- SIMULATE WIPE (Targeted Spells Scenario)
-- Simulate what happens if another addon reloads LibEditMode
print("Simulating Wipe...")
lib.internal = {}    -- Wipe internal!
lib.SettingType = {} -- Wipe SettingType!

-- Verify Broken State
if lib.internal.GetPool then error("FAIL: Wipe failed to clear internal") end
if lib.SettingType.CollapsibleHeader then error("FAIL: Wipe failed to clear SettingType") end

-- TRIGGER HEALING
-- We registered a callback on 'enter'. Trigger it.
-- LibEditMode stores callbacks in lib.anonCallbacksEnter
local callbacks = lib.anonCallbacksEnter
if #callbacks == 0 then
    error("FAIL: No 'enter' callbacks registered! Healing mechanism not installed.")
end

print("Triggering Enter Callbacks (" .. #callbacks .. ")...")
for _, cb in ipairs(callbacks) do
    cb()
end

-- VERIFY HEALING (Phase 2)
if lib.SettingType.CollapsibleHeader ~= 11 then
    error("FAIL: CollapsibleHeader NOT restored! Healing failed.")
end
if not lib.internal.GetPool then
    error("FAIL: internal.CreatePool polyfill NOT restored!")
end
if not lib.internal:GetPool(11) then
    error("FAIL: Pool 11 NOT restored!")
end

print("Self-Healing: SUCCESS")
