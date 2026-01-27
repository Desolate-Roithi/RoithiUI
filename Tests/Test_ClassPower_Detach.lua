-- Tests/Test_ClassPower_Detach.lua
-- Goal: Reproduce "Cursed" detachment behavior (instabilities in coordinates)

local testName = "Test_ClassPower_Detach"
print("\n[+] Loading " .. testName)

-- 1. Mock Framework
local mocks = {}
local DB = {
    profile = {
        General = { unitFrameFont = "Arial" },
        UnitFrames = {
            player = {
                classPowerEnabled = true,
                classPowerDetached = false,
                classPowerWidth = 200,
                classPowerHeight = 10,
                width = 200,
                height = 50,
            }
        }
    }
}

-- Global Mocks
-- Global Mocks
local UF_Module = { -- Singleton
    units = { player = mocks.playerFrame }
}
_G.RoithiUI = {
    db = DB,
    GetModule = function(self, name)
        return UF_Module
    end
}
_G.LibStub = function(name)
    if name == "LibRoithi-1.0" then
        return { mixins = { CreateBackdrop = function() end, SetFont = function() end } }
    elseif name == "LibSharedMedia-3.0" then
        return {}
    elseif name == "LibEditMode" then
        return {
            SettingType = { Checkbox = 1, Slider = 2 },
            AddFrame = function(self, frame, callback, defaults)
                frame._lemCallback = callback
                frame._lemDefaults = defaults
            end,
            RegisterCallback = function() end,
            RefreshFrameSettings = function() end
        }
    end
end
_G.UnitClass = function() return "DRUID" end
_G.GetSpecialization = function() return 1 end -- Balance
_G.Enum = { PowerType = { ComboPoints = 3, Energy = 4 } }
_G.UIParent = { GetEffectiveScale = function() return 1 end, GetSize = function() return 1920, 1080 end }

-- Mock Frame Factory
local function CreateMockFrame(name, parent)
    local f = {
        name = name,
        parent = parent,
        points = {},
        shown = true,
        size = { w = 200, h = 50 },
        scripts = {},

        SetPoint = function(self, point, relFrame, relPoint, x, y)
            -- Handle varargs for SetPoint (3, 4, or 5 args)
            if type(relFrame) == "number" then
                x = relFrame; relFrame = nil
            end

            self.points[1] = { p = point, r = relFrame, rp = relPoint, x = x, y = y }
        end,
        SetAllPoints = function(self) end,
        ClearAllPoints = function(self) self.points = {} end,
        GetPoint = function(self)
            if self.points[1] then
                local pt = self.points[1]
                return pt.p, pt.r, pt.rp, pt.x, pt.y
            end
        end,
        SetSize = function(self, w, h)
            self.size.w = w; self.size.h = h
        end,
        SetWidth = function(self, w) self.size.w = w end,
        SetHeight = function(self, h) self.size.h = h end,
        GetWidth = function(self) return self.size.w end,
        GetHeight = function(self) return self.size.h end,
        GetCenter = function(self) return 960, 540 end, -- Middle of screen
        SetParent = function(self, p) self.parent = p end,
        GetParent = function(self) return self.parent end,
        Hide = function(self) self.shown = false end,
        Show = function(self) self.shown = true end,
        GetName = function(self) return self.name end,
        CreateFontString = function() return { SetPoint = function() end, SetText = function() end, Hide = function() end } end,
        CreateTexture = function() return { SetAllPoints = function() end, SetColorTexture = function() end, SetAlpha = function() end, Hide = function() end, SetSize = function() end, ClearAllPoints = function() end, SetPoint = function() end, SetHeight = function() end, SetVertexColor = function() end } end,
        HookScript = function(self, script, func) self.scripts[script] = func end,
        SetScript = function(self, script, func) self.scripts[script] = func end,
        RegisterEvent = function() end, -- No-op
        SetMovable = function() end,
        SetClampedToScreen = function() end,
        GetFrameLevel = function() return 1 end,
        SetFrameLevel = function() end,
        SetStatusBarTexture = function() end,
        SetStatusBarColor = function() end,
        SetMinMaxValues = function() end,
        SetValue = function() end,
        GetStatusBarTexture = function() return { SetHorizTile = function() end } end,
    }
    return f
end
_G.CreateFrame = CreateMockFrame

-- Setup Player Frame
mocks.playerFrame = CreateMockFrame("RoithiPlayer", UIParent)
mocks.playerFrame.unit = "player"
mocks.playerFrame.Power = CreateMockFrame("RoithiPlayerPower", mocks.playerFrame)

-- 2. Load ClassPower Code (by executing the file strictly)
-- We need to mock '...' arguments for the file load
local chunk, err = loadfile("Modules/UnitFrames/Elements/ClassPower.lua")
if not chunk then error("Failed to load ClassPower: " .. err) end
chunk("RoithiUI", {})

-- 3. Load Config Code Logic (Simulated)
-- We won't load the full LEMConfig file to avoid complexity,
-- but we will simulate the logic from the Checkbox Setter we analyzed.
local function ToggleDetach(unit, value)
    local db = DB.profile.UnitFrames[unit]
    local frame = mocks.playerFrame

    -- Logic copied from LEMConfig/UnitFrames.lua
    if value == true and not db.classPowerDetached then
        -- Classic Detach Logic (Jump to saved)
        if not db.classPowerX then db.classPowerX = 0 end
        if not db.classPowerY then db.classPowerY = 0 end
        if not db.classPowerPoint then db.classPowerPoint = "CENTER" end

        if not db.classPowerWidth and frame.ClassPower then
            db.classPowerWidth = frame.ClassPower:GetWidth()
        end
    elseif value == false then
        db.classPowerWidth = nil
    end

    db.classPowerDetached = value
    frame.UpdateClassPowerLayout()
end

-- 4. Execute Tests
local UF = _G.RoithiUI:GetModule("UnitFrames")
UF:CreateClassPower(mocks.playerFrame)
mocks.playerFrame.UpdateClassPowerLayout()

-- TEST 1: Initial State (Attached)
local cp = mocks.playerFrame.ClassPower
if cp:GetParent() ~= mocks.playerFrame.Power then
    error("FAIL: Initial parent should be Power Frame")
end
print("PASS: Initial Attachment")

-- TEST 2: Detach (Should reset to 0,0)
ToggleDetach("player", true)
if cp:GetParent() ~= UIParent then
    error("FAIL: Should be parented to UIParent")
end
local p, r, rp, x, y = cp:GetPoint()
if x ~= 0 or y ~= 0 then
    error("FAIL: Did not reset to 0,0. Got " .. tostring(x) .. "," .. tostring(y))
end
print("PASS: Detach Reset to 0,0")

-- TEST 3: Move while Detached
-- Simulate LibEditMode callback
DB.profile.UnitFrames.player.classPowerX = 100
DB.profile.UnitFrames.player.classPowerY = 100
DB.profile.UnitFrames.player.classPowerPoint = "TOPLEFT"
-- Update layout should respect this
mocks.playerFrame.UpdateClassPowerLayout()
p, r, rp, x, y = cp:GetPoint()
if x ~= 100 then
    error("FAIL: Movement update failed. Got " .. tostring(x))
end
print("PASS: Movement update")

-- TEST 4: Re-Attach
ToggleDetach("player", false)
if cp:GetParent() ~= mocks.playerFrame.Power then
    error("FAIL: Did not re-attach to Power")
end
print("PASS: Re-attach")

-- TEST 5: Classic Detach (Immediate Jump to Saved)
-- Move PlayerFrame to specific location
mocks.playerFrame.GetCenter = function() return 200, 200 end
if mocks.playerFrame.ClassPower then
    mocks.playerFrame.ClassPower.GetCenter = function() return 200, 200 end
end

-- Pre-set some "saved" coordinates to verify it jumps THERE
local savedX, savedY = 50, -50
local db = _G.RoithiUI.db.profile.UnitFrames["player"]
db.classPowerX = savedX
db.classPowerY = savedY
db.classPowerPoint = "CENTER"

ToggleDetach("player", true)

p, r, rp, x, y = cp:GetPoint()
print("DEBUG: Detach Coords:", x, y)

if x == savedX and y == savedY then
    print("PASS: Detach jumped to Saved Position correctly!")
else
    error(string.format("FAIL: Did not jump to saved position. Got %s, %s expected %s, %s", tostring(x), tostring(y),
        tostring(savedX), tostring(savedY)))
end
