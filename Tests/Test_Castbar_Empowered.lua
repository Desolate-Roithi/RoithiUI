-- Tests/Test_Castbar_Empowered.lua
local addonName = "RoithiUI"
local ns = {}

-- ----------------------------------------------------------------------------
-- MOCK ENVIRONMENT
-- ----------------------------------------------------------------------------
_G.RoithiUI = {
    db = {
        profile = {
            Castbar = {
                player = {
                    colors = {
                        empower1 = { 1, 0, 0, 1 },
                        empower2 = { 1, 1, 0, 1 },
                        empower3 = { 0, 1, 0, 1 },
                        empower4 = { 0, 0, 1, 1 },
                        empowerHold = { 0, 1, 1, 1 }
                    }
                }
            }
        }
    }
}

-- Mock "Secret" Userdata type
local SecretMeta = { __tostring = function() return "SecretUserdata" end }
local function MockSecret()
    local u = newproxy(true)
    getmetatable(u).__tostring = SecretMeta.__tostring
    return u
end

-- Mock WoW Constants & API
_G.GetTime = function() return 1000 end

-- Mock UnitChannelInfo
local mockChannelInfo = {}
_G.UnitChannelInfo = function(unit)
    if mockChannelInfo[unit] then
        return unpack(mockChannelInfo[unit])
    end
    return nil
end

_G.UnitCastingInfo = function() return nil end

-- Mock Empowered APIs
local mockStageDurations = {}
local mockStagePercentages = {}

_G.UnitEmpoweredStageDurations = function(unit)
    if not mockStageDurations[unit] then return {} end

    -- Wrap mock values in objects if they aren't already
    local ret = {}
    for i, obj in ipairs(mockStageDurations[unit]) do
        table.insert(ret, obj)
    end
    return ret
end

_G.UnitEmpoweredStagePercentages = function(unit)
    return mockStagePercentages[unit]
end

_G.GetUnitEmpowerHoldAtMaxTime = function(unit)
    return 1000
end

_G.UnitEmpoweredChannelDuration = function(unit)
    return {
        GetSeconds = function() return 6.0 end,
        GetTotalDuration = function() return 6.0 end,
        GetMilliseconds = function() return 6000 end,
        HasSecretValues = function() return false end,
        IsZero = function() return false end
    }
end

-- Mock StatusBar
_G.CreateFrame = function() return {} end


-- ----------------------------------------------------------------------------
-- LOAD MODULE UNDER TEST
-- ----------------------------------------------------------------------------
local chunk, err = loadfile("Modules/Castbar/Empower.lua")
if not chunk then
    error("Failed to load Empower.lua: " .. tostring(err))
end
chunk(addonName, ns)

-- ----------------------------------------------------------------------------
-- TESTS
-- ----------------------------------------------------------------------------

function Test_Empower_BlockedBySecretTimestamps()
    print("Test_Empower_HandlesSecretTimestamps: Running...")

    local unit = "player"
    local bar = {
        unit = unit,
        GetWidth = function() return 200 end,
        GetHeight = function() return 20 end,
        CreateTexture = function() return { SetPoint = function() end, SetSize = function() end, SetColorTexture = function() end, Hide = function() end, Show = function() end, ClearAllPoints = function() end, SetWidth = function() end, SetHeight = function() end } end,
        SetTimerDuration = function() end,
        CreateAnimationGroup = function() return { CreateAnimation = function() return { SetFromAlpha = function() end, SetToAlpha = function() end, SetDuration = function() end, SetTarget = function() end } end, SetScript = function() end, Stop = function() end, Play = function() end } end
    }

    local secretStart = MockSecret()
    local secretEnd = MockSecret()

    mockChannelInfo[unit] = {
        "Fire Breath", "Casting", "icon",
        secretStart, secretEnd,
        false, false, 12345, true, 3
    }

    -- Mock Duration Objects
    local function MockDurObj(sec)
        return {
            GetTotalDuration = function() return sec end,
            GetSeconds = function() return sec end,
            GetMilliseconds = function() return sec * 1000 end,
            HasSecretValues = function() return false end,
            IsZero = function() return sec == 0 end
        }
    end

    mockStageDurations[unit] = { MockDurObj(2), MockDurObj(2), MockDurObj(1) }

    -- ACT
    ns.SetupEmpower(bar)

    -- ASSERT
    local tl = bar.empowerTimeline
    if not tl then
        error("FAIL: Timeline not created")
    end

    if tl.totalDuration ~= 6.0 then
        error("FAIL: Expected totalDuration=6.0, got " .. tostring(tl.totalDuration))
    end

    print("PASS: BuildEmpowerTimeline processed Duration Objects correctly.")
end

function Test_Empower_Layout_Normalized_Success()
    print("Test_Empower_Layout_Normalized_Success: Running...")

    local unit = "player"
    local bar = {
        unit = unit,
        GetWidth = function() return 200 end,
        GetHeight = function() return 20 end,
        CreateTexture = function() return { SetPoint = function() end, SetSize = function() end, SetColorTexture = function() end, Hide = function() end, Show = function() end, ClearAllPoints = function() end, SetWidth = function() end, SetHeight = function() end } end,
        SetTimerDuration = function() end,
        CreateAnimationGroup = function() return { CreateAnimation = function() return { SetFromAlpha = function() end, SetToAlpha = function() end, SetDuration = function() end, SetTarget = function() end } end, SetScript = function() end, Stop = function() end, Play = function() end } end
    }

    local secretStart = MockSecret()
    local secretEnd = MockSecret()

    -- Mock Duration Objects
    local function MockDurObj(sec)
        return {
            GetTotalDuration = function() return sec end,
            GetSeconds = function() return sec end,
            GetMilliseconds = function() return sec * 1000 end,
            HasSecretValues = function() return false end,
            IsZero = function() return sec == 0 end
        }
    end

    mockChannelInfo[unit] = { "Fire Breath", "Casting", "icon", secretStart, secretEnd, false, false, 12345, true, 3 }

    mockStageDurations[unit] = { MockDurObj(2.0), MockDurObj(2.0), MockDurObj(1.0) }

    -- ACT
    ns.SetupEmpower(bar)

    -- ASSERT
    local tl = bar.empowerTimeline
    if not tl then error("FAIL: BuildEmpowerTimeline returned nil") end

    if #tl.stageEnds ~= 3 then
        error("FAIL: Expected 3 stage ends, got " .. #tl.stageEnds)
    end

    if tl.stageEnds[1] ~= 2.0 then
        error("FAIL: Expected stage 1 end to be 2.0s, got " .. tostring(tl.stageEnds[1]))
    end

    print("PASS: Timeline stage logic verified!")
end

-- RUN
Test_Empower_BlockedBySecretTimestamps()
Test_Empower_Layout_Normalized_Success()
