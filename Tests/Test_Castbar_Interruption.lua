-- Tests/Test_Castbar_Interruption.lua
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
                        interrupted = { 1, 0, 0, 1 },
                        cast = { 1, 1, 0, 1 }
                    }
                }
            }
        }
    }
}

_G.C_Timer = {
    After = function(dur, func)
        _G.MockTimerCall = { dur = dur, func = func }
    end
}

-- MOCK BAR OBJECT
local function CreateMockBar()
    local bar = {}

    -- Properties
    bar.unit = "player"
    bar.value = 50
    bar.timerActive = false
    bar.lastSBColor = nil
    bar.lastBgColor = nil

    -- Sub-Frames
    bar.Background = {
        SetColorTexture = function(self, r, g, b, a)
            bar.lastBgColor = { r, g, b, a }
        end
    }
    bar.Text = {
        text = "",
        SetText = function(self, val) self.text = val end
    }
    bar.Spark = {
        Hide = function() end
    }

    -- Methods
    bar.SetScript = function() end
    bar.GetValue = function(self) return self.value end
    bar.SetValue = function(self, val) self.value = val end
    bar.Hide = function(self) self.hidden = true end
    bar.SetStatusBarColor = function(self, r, g, b, a)
        self.lastSBColor = { r, g, b, a }
    end

    -- Mock the 12.0 API with Crash Simulation
    function bar:SetTimerDuration(durationObj)
        if durationObj == nil then
            -- Simulate the crash reported by user
            error("bad argument #2 to '?' (Usage: self:SetTimerDuration(duration [, interpolation, direction]))")
        end
        if durationObj == 0 then
            self.timerActive = false  -- 0 stops it safely
        else
            self.timerActive = true
        end
    end

    return bar
end


-- ----------------------------------------------------------------------------
-- LOAD MODULE UNDER TEST
-- ----------------------------------------------------------------------------
local chunk, err = loadfile("Modules/Castbar/Castbar.lua")
if not chunk then
    error("Failed to load Castbar.lua: " .. tostring(err))
end
chunk(addonName, ns)

-- ----------------------------------------------------------------------------
-- TESTS
-- ----------------------------------------------------------------------------

local function Test_HandleInterrupt_VisualMask()
    print("Test_HandleInterrupt_VisualMask: Running...")

    -- Arrange
    local bar = CreateMockBar()
    bar:SetTimerDuration(100) -- Start it
    _G.MockTimerCall = nil

    -- Act
    ns.HandleInterrupt(bar)

    -- Assertions

    -- 1. Visuals must be set (Text)
    if bar.Text.text ~= "INTERRUPTED" then
        error("FAIL: Text was not set to INTERRUPTED. Got: '" .. tostring(bar.Text.text) .. "'")
    end

    -- 2. Visual Mask Check (Foreground == Background == Interrupted Color)
    -- Default Interrupted Color in Mock RoithiUI db is { 1, 0, 0, 1 } (Red)

    if not bar.lastBgColor then error("FAIL: Background color not set.") end
    if bar.lastBgColor[1] ~= 1 or bar.lastBgColor[2] ~= 0 then
        error("FAIL: Bg Color incorrect.")
    end

    -- THIS SHOULD FAIL initially as we haven't implemented SetStatusBarColor yet
    if not bar.lastSBColor then error("FAIL: StatusBar color not set (Visual Mask missing).") end

    if bar.lastSBColor[1] ~= 1 or bar.lastSBColor[2] ~= 0 then
        error("FAIL: StatusBar Color incorrect (Mask mismatch).")
    end

    print("PASS: Visual Mask logic verified.")
end

-- RUN
Test_HandleInterrupt_VisualMask()
