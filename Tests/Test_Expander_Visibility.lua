-- Tests/Test_Expander_Visibility.lua
-- Verifies that UnitFrame settings are conditionally inserted based on expander state, causing missing settings.

-- 1. Mock Environment
dofile("Tests/Mock/WoWAPI.lua")

-- Mock RoithiUI and DB
_G.RoithiUI = {
    db = {
        profile = {
            UnitFrames = {
                player = {
                    powerSectionExpanded = false, -- START COLLAPSED
                    powerEnabled = true,
                }
            },
            Castbar = {},
        }
    },
    GetModule = function(self, name)
        if name == "UnitFrames" then
            return {
                units = { player = CreateFrame("Frame") },
                frames = { player = CreateFrame("Frame") },
                UpdateFrameFromSettings = function() end
            }
        end
    end
}

-- Mock LibEditMode
local mockLEM = {
    SettingType = {
        Checkbox = "Checkbox",
        Slider = "Slider",
        Expander = "Expander",
        Divider = "Divider",
        Button = "Button",
    },
    AddFrame = function() end,
    RegisterCallback = function() end,
    RefreshFrameSettings = function() end,
}

-- Mock AddFrameSettings to capture the settings table
local capturedSettings = nil
function mockLEM:AddFrameSettings(frame, settings)
    capturedSettings = settings
end

-- Hook LibStub to return our mock LEM
local oldLibStub = _G.LibStub
_G.LibStub = function(name, silent)
    if name == "LibEditMode-Roithi" then return mockLEM end
    return oldLibStub(name, silent)
end

-- 2. Load the Config File
local ns = {}
local chunk, err = loadfile("Config/LEMConfig/UnitFrames.lua")
if not chunk then
    print("FAIL: Could not load UnitFrames.lua: " .. err)
    os.exit(1)
end
chunk("RoithiUI", ns)

-- 3. Run Initialization (with Expanded = FALSE)
print("--- TEST CASE 1: Initialized with Collapsed Expander ---")
_G.RoithiUI.db.profile.UnitFrames.player.powerSectionExpanded = false
ns.InitializeUnitFrameConfig()

local countCollapsed = #capturedSettings
print("Settings Count (Collapsed): " .. countCollapsed)

-- 4. Run Initialization (with Expanded = TRUE)
print("--- TEST CASE 2: Initialized with Expanded Expander ---")
_G.RoithiUI.db.profile.UnitFrames.player.powerSectionExpanded = true
ns.InitializeUnitFrameConfig() -- Re-run (simulate reload or initial load state change)

local countExpanded = #capturedSettings
print("Settings Count (Expanded): " .. countExpanded)

-- 5. Analyze Results
if countExpanded == countCollapsed then
    print("RESULT: Verified Fix - Settings count matches!")
    print("Collapsed Count: " .. countCollapsed)
    print("Expanded Count: " .. countExpanded)
    print("TDD STATUS: GREEN (Fix Verified - Settings always inserted)")
    os.exit(0)
else
    print("RESULT: Fix Failed - Counts still differ.")
    print("Collapsed: " .. countCollapsed)
    print("Expanded: " .. countExpanded)
    print("Difference: " .. (countExpanded - countCollapsed))
    print("TDD STATUS: FAIL (Bug still present)")
    os.exit(1)
end
