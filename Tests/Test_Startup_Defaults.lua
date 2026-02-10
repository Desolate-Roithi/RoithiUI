-- Tests/Test_Startup_Defaults.lua

local function Test_Defaults_Loading()
    print("  > Test_Defaults_Loading...")
    -- 1. Mock the namespace table
    local ns = {}

    -- 2. Load the file as a chunk
    -- Note: Paths are relative to CWD (Addon Root) when running via TestRunner
    local chunk, err = loadfile("Config/Defaults.lua")
    if not chunk then
        error("Failed to load Config/Defaults.lua: " .. tostring(err))
    end

    -- 3. Execute chunk with mocked varargs (addonName, ns)
    chunk("RoithiUI", ns)

    -- 4. Assertions
    if type(ns.Defaults) ~= "table" then
        error("ns.Defaults was not created.")
    end

    if type(ns.Defaults.profile) ~= "table" then
        error("ns.Defaults.profile is missing.")
    end

    if type(ns.Defaults.profile.General) ~= "table" then
        error("ns.Defaults.profile.General is missing (Core crash cause).")
    end

    -- Check a specific value just to be sure
    if ns.Defaults.profile.General.Theme ~= "Class" then
        error("Unexpected default Theme value: " .. tostring(ns.Defaults.profile.General.Theme))
    end

    if ns.Defaults.profile.General.debugMode ~= false then
        error("debugMode should be false by default")
    end

    print("  > OK")
end

-- Run
Test_Defaults_Loading()
