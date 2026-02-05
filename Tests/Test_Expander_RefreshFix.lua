-- Tests/Test_Expander_RefreshFix.lua
-- TDD RED: Reproduce 'attempt to call method Refresh (a nil value)'

package.path = "Tests/Mock/?.lua;" .. package.path
require("WoWAPI")

local function LoadLibFile(path)
    local chunk, err = loadfile(path)
    if not chunk then error("Could not load: " .. path .. "\n" .. tostring(err)) end
    chunk()
end

-- Initialize LibStub if not already present or if it's a mock (function)
if type(_G.LibStub) ~= "table" then
    _G.LibStub = nil -- Clear mock
    LoadLibFile("Libs/LibStub/LibStub.lua")
end

-- Mock Enum.EditModeSettingDisplayType
_G.Enum = _G.Enum or {}
if not _G.Enum.EditModeSettingDisplayType then
    _G.Enum.EditModeSettingDisplayType = {
        Dropdown = 1,
        Checkbox = 2,
        Slider = 3,
        Divider = 4,
    }
end

-- Load Library Core if not already loaded
if not _G.LibStub("LibEditMode-Roithi", true) then
    LoadLibFile("Libs/LibEditMode/LibEditMode.lua")
    LoadLibFile("Libs/LibEditMode/pools.lua")
    LoadLibFile("Libs/LibEditMode/widgets/expander.lua")

    -- Load the Fix
    LoadLibFile("Libs/LibRoithi/LibEditModeExtension.lua")
end

local lib = LibStub("LibEditMode-Roithi")
local expanderPool = lib.internal:GetPool(lib.SettingType.Expander)

print("--- TDD: Verifying Expander Refresh Fix ---")

if not expanderPool then
    print("FAIL: Expander pool not created!")
    os.exit(1)
end

local frame = expanderPool:Acquire(UIParent)
local data = {
    kind = "expander",
    name = "Primary Power",
    get = function() return true end,
    set = function() end,
}

print("Executing frame:Setup(data)...")
local ok, err = pcall(function()
    frame:Setup(data)
end)

if ok then
    print("RESULT: frame:Setup(data) completed successfully!")

    -- Verify Refresh method exists
    if type(frame.Refresh) == "function" then
        print("TDD STATUS: GREEN (SUCCESS) - Refresh method successfully bridged.")
        os.exit(0)
    else
        print("TDD STATUS: FAIL - Refresh method still missing despite successful pcall.")
        os.exit(1)
    end
else
    print("TDD STATUS: FAIL (Error still occurring)")
    print("Error Message: " .. tostring(err))
    os.exit(1)
end
