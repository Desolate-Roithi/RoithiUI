-- Tests/Test_Expander_Conflict.lua
-- Reproduces the issue where other addons wiping lib.internal causes expanders to disappear.

package.path = "Tests/Mock/?.lua;" .. package.path
require("WoWAPI")

-- Mock Enum.EditModeSettingDisplayType which Blizzard defines
_G.Enum = _G.Enum or {}
_G.Enum.EditModeSettingDisplayType = {
    Dropdown = 1,
    Checkbox = 2,
    Slider = 3,
    Divider = 4,
}

local function LoadLibFile(path)
    local chunk, err = loadfile(path)
    if not chunk then error("Could not load: " .. path .. "\n" .. tostring(err)) end
    chunk()
end

print("STEP 1: Load LibStub and LibEditMode (MINOR 12)")
LoadLibFile("Libs/LibStub/LibStub.lua")
-- Force version 12
LoadLibFile("Libs/LibEditMode/LibEditMode.lua")
LoadLibFile("Libs/LibEditMode/pools.lua")
LoadLibFile("Libs/LibEditMode/widgets/dialog.lua")

local lib = _G.LibStub("LibEditMode")
-- Version 12 doesn't have hookVersion, that's a v14+ feature.

print("STEP 2: Load RoithiUI Extension")
LoadLibFile("Libs/LibRoithi/LibEditModeExtension.lua")

-- Verify initial state
assert(lib.SettingType.CollapsibleHeader == 11, "CollapsibleHeader should be 11")
assert(lib.internal:GetPool(11) ~= nil, "Pool for 11 should exist")

local myFrameV12 = CreateFrame("Frame", "TestFrameV12", UIParent)
lib:AddFrame(myFrameV12, function() end, { point = "CENTER", x = 0, y = 0 })
assert(lib.frameSelections[myFrameV12] ~= nil, "v12 Selection frame should exist")

print("STEP 3: Simulate TargetedSpells Load (MINOR 14) Wiping internal")
-- We can't change the MINOR in the file easily, but we can simulate what it does.
-- It will wipe internal, set hookVersion to 14, and load pools/dialog again.

lib.internal = {}
_G.Enum.EditModeSettingDisplayType.NewFakeType = 9 -- Simulate blizzard expansion
lib.SettingType = {}                               -- Usually done by lib.SettingType = CopyTable(...)
for k, v in pairs(_G.Enum.EditModeSettingDisplayType) do lib.SettingType[k] = v end

-- Redefine MINOR in the lib files by mocking LibStub to return 14 during their load
local old_NewLibrary = _G.LibStub.NewLibrary
_G.LibStub.NewLibrary = function(self, major, minor)
    if major == "LibEditMode" then return lib, 14 end
    return old_NewLibrary(self, major, minor)
end

-- Simulating VERSION 14 files loading
lib.hookVersion = 14
LoadLibFile("Libs/LibEditMode/pools.lua")
LoadLibFile("Libs/LibEditMode/widgets/dialog.lua")
LoadLibFile("Libs/LibEditMode/widgets/button.lua")
LoadLibFile("Libs/LibEditMode/widgets/checkbox.lua")

-- Trigger v14-style call (using the currently bound lib:AddFrame)
lib:AddFrame(CreateFrame("Frame", "TestFrameV14", UIParent), function() end, { point = "CENTER", x = 0, y = 0 })
-- Note: In this simulation, lib.internal.dialog might still be nil
-- because the v12 AddFrame is still bound to a stale closure.
-- Repair() will fix this in STEP 5.

print("STEP 4: Verify Corruption")
assert(lib.SettingType.CollapsibleHeader == nil, "CollapsibleHeader should be GONE after v14 load")
assert(lib.internal:GetPool(11) == nil, "Pool for 11 should be GONE after v14 load")

print("STEP 5: Trigger Healing (Enter Edit Mode)")
-- This triggers ALL 'enter' callbacks.
-- Version 14's enter hook will call lib.anonCallbacksEnter.
for _, callback in ipairs(lib.anonCallbacksEnter) do
    callback()
end

print("STEP 6: Verify Recovery")
if lib.SettingType.CollapsibleHeader == 11 and lib.internal:GetPool(11) then
    print("PASS: Healing restored the expanders.")

    local selection = lib.frameSelections[myFrameV12]
    if selection and selection:GetScript("OnMouseDown") then
        print("Testing Selection Frame forwarder...")
        print("  cur lib: ", lib)
        print("  cur lib.GetFrameSettings: ", lib.GetFrameSettings)
        print("  cur lib.internal: ", lib.internal)
        print("  cur lib.internal.dialog: ", lib.internal.dialog)

        selection:GetScript("OnMouseDown")(selection)

        if lib.internal.dialog and lib.internal.dialog.selection == selection then
            print("PASS: v12 Selection Frame correctly updated v14 Dialog.")
        else
            print("FAIL: v12 Selection Frame FAILED to update v14 Dialog.")
            print("  Dialog selection:", lib.internal.dialog and lib.internal.dialog.selection)
            os.exit(1)
        end
    else
        print("FAIL: Selection frame not found or missing script.")
        os.exit(1)
    end
else
    print("FAIL: Healing FAILED to restore expanders.")
    print("  SettingType.CollapsibleHeader: ", lib.SettingType.CollapsibleHeader)
    print("  Pool(11): ", lib.internal:GetPool(11))
    os.exit(1)
end
