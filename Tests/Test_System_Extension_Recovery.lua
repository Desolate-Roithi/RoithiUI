-- Tests/Test_System_Extension_Recovery.lua
-- Verifies that Blizzard system extensions (internal.extension) are recovered
-- when another addon wipes the LibEditMode internal state.

require("Tests/Mock/WoWAPI")
local LibStub = _G.LibStub

print("STEP 1: Load LibEditMode (MINOR 14)")
require("Libs/LibEditMode/LibEditMode")
require("Libs/LibEditMode/pools")
require("Libs/LibEditMode/widgets/button")
require("Libs/LibEditMode/widgets/checkbox")
require("Libs/LibEditMode/widgets/dialog")
require("Libs/LibEditMode/widgets/divider")
require("Libs/LibEditMode/widgets/dropdown")
require("Libs/LibEditMode/widgets/expander")
require("Libs/LibEditMode/widgets/extension")
require("Libs/LibEditMode/widgets/slider")
require("Libs/LibEditMode/widgets/colorpicker")
local lib = LibStub("LibEditMode-Roithi")

print("STEP 2: Load RoithiUI Extension (The Bridge)")
require("Libs/LibRoithi/LibEditModeExtension")

print("STEP 3: Register a Blizzard System Setting")
-- Enum.EditModeSystem.UnitFrameBoss = 3 (approx, using 3 for test)
local systemID = 3
lib:AddSystemSettings(systemID, {
    {
        kind = lib.SettingType.Checkbox,
        name = "Roithi Boss Fix",
        get = function() return true end,
        set = function() end,
    }
})

local originalExtension = lib.internal.extension
if not originalExtension then
    print("FAIL: Extension not created after AddSystemSettings")
    os.exit(1)
end
print("  Extension Created: " .. tostring(originalExtension))

print("STEP 4: Simulate Wipe (Another Addon Loads)")
print("  Lib MT: " .. tostring(getmetatable(lib)))
lib.internal = {}
print("  Lib Internal Now: " .. tostring(lib.internal))
if lib.internal.extension then
    print("FAIL: Wipe failed to clear internal")
    os.exit(1)
end
print("  Internal Wiped. Extension Lost.")

print("STEP 5: Trigger Healing (Select System)")
-- Mock SelectSystem behavior
_G.EditModeManagerFrame.GetSelectedSystem = function()
    return { system = systemID, systemIndex = nil }
end

-- Force Repair (In real game, timer or hook would do this)
if _G.Repair then _G.Repair() end

print("STEP 6: Verify Recovery")
local newExtension = lib.internal.extension
if newExtension and newExtension ~= originalExtension then
    print("PASS: Extension RECOVERED (New Instance Created)")
elseif newExtension == originalExtension then
    print("PASS: Extension RECOVERED (Same Instance? Unlikely but OK)")
else
    print("FAIL: Extension NOT RECOVERED")
    os.exit(1)
end

-- Verify internal methods are still bridged
if lib.internal.GetSystemSettings then
    local settings, num = lib.internal:GetSystemSettings(systemID)
    if num > 0 and settings[1].name == "Roithi Boss Fix" then
        print("PASS: Settings still tracked through bridge.")
    else
        print("FAIL: Settings lost or bridge broken. Num: " .. tostring(num))
        os.exit(1)
    end
else
    print("FAIL: internal.GetSystemSettings missing")
    os.exit(1)
end

print("ALL SYSTEM EXTENSION RECOVERY TESTS PASSED!")
