-- TestRunner.lua
-- Simple test runner for RoithiUI TDD

---@diagnostic disable-next-line: undefined-global
local lfs_ok, lfs = pcall(require, "lfs")
local tests = {}

function RunTests()
    local passed = 0
    local failed = 0

    print("========================================")
    print("  RoithiUI Test Runner (Lua " .. _VERSION .. ")")
    print("========================================")

    if _VERSION ~= "Lua 5.1" then
        print("WARNING: WoW Retail uses Lua 5.1. You are using " .. _VERSION)
        print("Tests may not accurately reflect the game environment.")
        -- We won't abort, but we warn heavily.
    end

    for _, testFile in ipairs(tests) do
        print("\n[+] Loading " .. testFile)
        ---@diagnostic disable-next-line: undefined-global
        local chunk, err = loadfile(testFile)
        if not chunk then
            print("FAILED to load: " .. err)
            failed = failed + 1
        else
            -- Run the test file chunk
            local success, msg = pcall(chunk)
            if success then
                print("    PASS")
                passed = passed + 1
            else
                print("    FAIL: " .. tostring(msg))
                failed = failed + 1
            end
        end
    end

    print("\n========================================")
    print("SUMMARY: " .. passed .. " Passed, " .. failed .. " Failed")
    print("========================================")

    if failed > 0 then
        ---@diagnostic disable-next-line: undefined-global
        os.exit(1)
    end
end

-- Naive discovery: Just add the files we know about for now
-- In a real environment with lfs, we could scan.
table.insert(tests, "Tests/Test_UnitFrames.lua")
table.insert(tests, "Tests/Test_Libs.lua")
table.insert(tests, "Tests/Test_BossFrames_EditMode.lua")
table.insert(tests, "Tests/Tests_UnitFrames_Persistence.lua")
table.insert(tests, "Tests/Test_Castbar_Empowered.lua")
table.insert(tests, "Tests/Test_Startup_Defaults.lua")
table.insert(tests, "Tests/Test_Castbar_Interruption.lua")

RunTests()
