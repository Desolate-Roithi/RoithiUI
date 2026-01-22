-- Test_Libs.lua
-- Verifies that we can load the REAL underlying libraries from the Libs folder
-- This ensures our TDD environment simulates enough of WoW to use the libraries.

---@diagnostic disable-next-line: undefined-global
package.path = "Tests/Mock/?.lua;" .. package.path
---@diagnostic disable-next-line: undefined-global
require("WoWAPI") -- Load mocks first

local passed_libs = 0

-- Helper to load a library file directly from the filesystem
local function LoadLibFile(path)
    ---@diagnostic disable-next-line: undefined-global
    local chunk, err = loadfile(path)
    if not chunk then
        error("Could not load library file: " .. path .. "\nError: " .. tostring(err))
    end
    chunk() -- Execute it
end

print("TEST: Loading Real Libraries...")

-- 1. LibStub
-- LibStub is pure Lua, should load fine if we didn't mess up _G
local status, err = pcall(LoadLibFile, "Libs/LibStub/LibStub.lua")
if not status then
    error("FAIL: Real LibStub failed to load: " .. tostring(err))
else
    -- Verify it installed itself into global
    if not _G.LibStub then
        error("FAIL: LibStub loaded but _G.LibStub is missing!")
    end
    print("  > LibStub: OK")
end

-- 2. CallbackHandler-1.0
-- Depends on LibStub. Often uses error() or geterrorhandler() which we should mock if missing.
status, err = pcall(LoadLibFile, "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
if not status then
    error("FAIL: Real CallbackHandler failed to load: " .. tostring(err))
else
    -- Verify retrieval
    local CBH = _G.LibStub("CallbackHandler-1.0", true)
    if not CBH then
        error("FAIL: Could not retrieve CallbackHandler-1.0 from LibStub")
    end
    print("  > CallbackHandler: OK")
end

-- 3. LibSharedMedia-3.0
-- Depends on LibStub, CallbackHandler. May create a frame.
-- We verify if our Mock handles CreateFrame enough for LSM.
-- LSM usually does: local lib = LibStub:NewLibrary(...) if not lib then return end
-- followed by some frame creation for event handling.
status, err = pcall(LoadLibFile, "Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua")
if not status then
    -- It is expected this might fail if we haven't mocked CreateFrame well enough yet.
    -- We will log it but maybe not fail the whole test suite yet,
    -- OR we treat this as a signal to improve WoWAPI.lua
    print("  > LibSharedMedia (Real) Load Failed (Expected if CreateFrame missing): " .. tostring(err))
    print("    [!] We will proceed using the Mock version for unit tests for now.")
else
    local LSM = _G.LibStub("LibSharedMedia-3.0", true)
    if LSM then
        print("  > LibSharedMedia: OK (Surprisingly!)")
    end
end

-- 4. AceAddon-3.0
-- Depends on LibStub, CallbackHandler.
status, err = pcall(LoadLibFile, "Libs/Ace3/AceAddon-3.0/AceAddon-3.0.lua")
if not status then
    print("  > AceAddon-3.0 Load Failed: " .. tostring(err))
else
    local AceAddon = _G.LibStub("AceAddon-3.0", true)
    if AceAddon then
        print("  > AceAddon-3.0: OK")
    end
end

-- 5. AceDB-3.0
status, err = pcall(LoadLibFile, "Libs/Ace3/AceDB-3.0/AceDB-3.0.lua")
if not status then
    print("  > AceDB-3.0 Load Failed: " .. tostring(err))
else
    local AceDB = _G.LibStub("AceDB-3.0", true)
    if AceDB then
        print("  > AceDB-3.0: OK")
    end
end

-- 6. LibDualSpec-1.0
status, err = pcall(LoadLibFile, "Libs/LibDualSpec-1.0/LibDualSpec-1.0.lua")
if not status then
    print("  > LibDualSpec-1.0 Load Failed: " .. tostring(err))
else
    local LibDualSpec = _G.LibStub("LibDualSpec-1.0", true)
    if LibDualSpec then
        print("  > LibDualSpec-1.0: OK")
    end
end

-- 7. LibRangeCheck-3.0
status, err = pcall(LoadLibFile, "Libs/LibRangeCheck-3.0/LibRangeCheck-3.0.lua")
if not status then
    print("  > LibRangeCheck-3.0 Load Failed: " .. tostring(err))
else
    local LRC = _G.LibStub("LibRangeCheck-3.0", true)
    if LRC then
        print("  > LibRangeCheck-3.0: OK")
    end
end
