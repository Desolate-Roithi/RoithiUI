local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local UF = RoithiUI:GetModule("UnitFrames")

-- Mock DB
RoithiUI.db = {
    profile = {
        UnitFrames = {
            player = { enabled = true },
            target = { enabled = false }, -- Disabled initially
            boss1 = { enabled = true },   -- Boss enabled
        }
    }
}

-- Tests
local function Test_LazyCreation()
    -- Reset Units
    UF.units = {}

    -- Initialize
    UF:InitializeUnits()

    -- Player should exist (Enabled)
    assert(UF.units["player"], "Player frame should be created (Enabled)")
    assert(UF.units["player"]:IsShown(), "Player frame should be shown")

    -- Target should NOT exist (Disabled)
    assert(UF.units["target"] == nil, "Target frame should NOT be created (Disabled)")

    print("Test_LazyCreation: PASS")
end

local function Test_Toggle_Individual()
    -- Enable Target (Update DB First!)
    RoithiUI.db.profile.UnitFrames["target"].enabled = true
    UF:ToggleFrame("target", true)

    -- Should now exist
    local target = UF.units["target"]
    assert(target, "Target frame should be created after Toggle(true)")
    assert(target:IsShown(), "Target frame should be shown after Toggle(true)")

    -- Disable Target (Update DB First!)
    RoithiUI.db.profile.UnitFrames["target"].enabled = false
    UF:ToggleFrame("target", false)

    -- Should still exist (object) but be hidden and disabled
    assert(target:IsShown() == false, "Target frame should be hidden after Toggle(false)")
    -- Mock check for Disable() called? Hard to check without spy, but IsShown is good proxy + visual verification later.

    print("Test_Toggle_Individual: PASS")
end

local function Test_Boss_Group()
    -- Reset
    UF.units = {}

    -- Ensure boss1 enabled in DB for init
    RoithiUI.db.profile.UnitFrames["boss1"] = { enabled = true }
    UF:InitializeUnits()

    -- Boss1 should exist
    assert(UF.units["boss1"], "Boss1 should be created")

    -- Simulate Config Toggling Group OFF
    -- Config calls ToggleFrame for boss1..5
    for i = 1, 5 do
        -- Mock DB Update
        if not RoithiUI.db.profile.UnitFrames["boss" .. i] then
            RoithiUI.db.profile.UnitFrames["boss" .. i] = {}
        end
        RoithiUI.db.profile.UnitFrames["boss" .. i].enabled = false

        UF:ToggleFrame("boss" .. i, false)
    end

    assert(UF.units["boss1"]:IsShown() == false, "Boss1 should be hidden")
    if UF.units["boss2"] then
        assert(UF.units["boss2"]:IsShown() == false, "Boss2 should be hidden")
    end

    print("Test_Boss_Group: PASS")
end

local function Test_EditMode_Persistence()
    -- Player is enabled. Target is disabled (from previous test state, let's reset)
    UF:ToggleFrame("player", true)
    RoithiUI.db.profile.UnitFrames["target"].enabled = false
    UF:ToggleFrame("target", false)

    local player = UF.units["player"]
    local target = UF.units["target"]

    -- Enter Edit Mode
    -- Simulate EditMode Enter Logic (manually derived from Units.lua)
    if UF:IsUnitEnabled("target") then
        -- Should not reach here
        assert(false, "Target reported enabled erroneously")
    else
        -- Correct
    end

    print("Test_EditMode_Persistence: PASS")
end

-- Run
Test_LazyCreation()
Test_Toggle_Individual()
Test_Boss_Group()
Test_EditMode_Persistence()
