-- Tests/Test_Castbar_Fix.lua
local ns = {}
local RoithiUI = {}
_G.RoithiUI = RoithiUI

-- Mocks
RoithiUI.db = {
    profile = {
        General = { castbarBar = "Solid", castbarFont = "Friz Quadrata TT" },
        Castbar = {
            player = { enabled = true, width = 200, height = 20, colors = { cast = { 1, 1, 0, 1 } }, attachToUnitFrame = true }
        }
    }
}
RoithiUI.NewModule = function(self, name)
    self[name] = { OnEnable = function() end, OnInitialize = function() end }
    return self[name]
end
RoithiUI.GetModule = function(self, name) return self[name] end

_G.CreateFrame = function(type, name, parent)
    local f = {
        GetName = function() return name end,
        SetPoint = function() end,
        ClearAllPoints = function() end,
        SetParent = function() end,
        SetSize = function() end,
        SetStatusBarTexture = function() end,
        GetStatusBarTexture = function() return { SetAllPoints = function() end } end,
        SetStatusBarColor = function() end,
        SetReverseFill = function() end,
        Hide = function() end,
        Show = function() end,
        CreateTexture = function() return { SetAllPoints = function() end, SetColorTexture = function() end, SetPoint = function() end, SetTexCoord = function() end, Hide = function() end, Show = function() end, SetSize = function() end, SetVertexColor = function() end, SetTexture = function() end, SetBlendMode = function() end, SetHeight = function() end, SetWidth = function() end, GetWidth = function() return 100 end, GetHeight = function() return 20 end, ClearAllPoints = function() end } end,
        CreateFontString = function() return { SetFont = function() end, SetPoint = function() end, SetText = function() end } end,
        SetClampedToScreen = function() end,
        GetParent = function() return parent end,
        RegisterEvent = function() end,
        SetScript = function() end,
        IsShown = function() return true end,
        GetWidth = function() return 200 end,
        GetHeight = function() return 20 end,
    }
    return f
end

_G.CopyTable = function(t)
    local res = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            res[k] = _G.CopyTable(v)
        else
            res[k] = v
        end
    end
    return res
end

_G.UIParent = { GetName = function() return "UIParent" end }
_G.SlashCmdList = {}
_G.TargetFrame = { spellbar = { SetAlpha = function() end, Hide = function() end, Show = function() end } }
_G.FocusFrame = { spellbar = { SetAlpha = function() end, Hide = function() end, Show = function() end } }
_G.PlayerFrame = { Spellbar = { SetAlpha = function() end, Hide = function() end, Show = function() end } }
_G.PetFrame = { spellbar = { SetAlpha = function() end, Hide = function() end, Show = function() end } }
_G.PlayerCastingBarFrame = { SetAlpha = function() end, Hide = function() end, Show = function() end }
_G.hooksecurefunc = function() end
_G.GetNetStats = function() return 0, 0, 50, 50 end
_G.LibStub = function(name)
    if name == "LibSharedMedia-3.0" then
        return { Fetch = function() return "mock" end }
    end
    return { NewModule = function() return {} end }
end

_G.UnitCastingInfo = function() return "Hearthstone", "Casting", "icon", 0, 10, false, 1, false, 123 end
_G.UnitChannelInfo = function() return nil end
_G.issecretvalue = function() return false end

-- Load files (Simulated)
-- Normally we would do loadfile, but for simple tests we can just define relevant functions
-- I'll use the real files where possible if the environment allows

print("RUNNING: Test_Castbar_Fix.lua")

-- Load the real files using loadfile
local function LoadFile(path)
    local chunk, err = loadfile(path)
    if not chunk then error("Failed to load " .. path .. ": " .. err) end
    -- Pass addonName, ns
    chunk("RoithiUI", ns)
end

-- We need to mock RoithiUI.db.profile.UnitFrames too
RoithiUI.db.profile.UnitFrames = {
    player = { enabled = true, width = 200, height = 50 }
}

-- Mock oUF
ns.oUF = {
    RegisterStyle = function() end,
    SetActiveStyle = function() end,
    Spawn = function() return _G.CreateFrame() end
}

-- Load
LoadFile("Modules/Castbar/Core.lua")
ns.InitializeCastbarConfig = function() end
-- Empower.lua usually defines things in ns
LoadFile("Modules/Castbar/Empower.lua")
LoadFile("Modules/Castbar/Castbar.lua")

print("Files loaded.")

-- 1. Initialize
local Castbar = RoithiUI:GetModule("Castbar")
Castbar:OnInitialize()
Castbar:OnEnable()

-- 2. Check if bars created
if not ns.bars["player"] then
    print("FAIL: player castbar not created in ns.bars")
    os.exit(1)
end

-- 3. Verify Schema Standardization
-- Check if boss defaults have 'detached'
if ns.DEFAULTS.boss1.detached == nil then
    print("FAIL: boss DEFAULTS missing 'detached' key")
    os.exit(1)
end

-- 4. Verify Anchoring Logic
local playerBar = ns.bars["player"]
local parentSet = nil
local pointSet = nil
local anchorSet = nil

playerBar.SetParent = function(self, p) parentSet = p end
playerBar.SetPoint = function(self, p, rel, rp, x, y)
    pointSet = p
    anchorSet = rel
end

-- Mock UnitFrames
local UF = { units = { player = _G.CreateFrame(nil, "PlayerFrameMock") } }
UF.units.player.IsShown = function() return true end
UF.units.player.Power = _G.CreateFrame(nil, "PlayerPowerMock")
UF.units.player.Power.IsShown = function() return true end

RoithiUI.GetModule = function(self, name)
    if name == "UnitFrames" then return UF end
    return self[name]
end

-- Force detachment to false in DB
RoithiUI.db.profile.Castbar.player.detached = false
RoithiUI.db.profile.Castbar.player.attached = nil -- Clean up for test

ns.SetCastbarAttachment("player", true)

if parentSet ~= UF.units.player then
    print("FAIL: Castbar parent not set to unit frame during attachment")
    os.exit(1)
end

if anchorSet ~= UF.units.player.Power then
    print("FAIL: Castbar not anchored to Power bar (preferred over frame)")
    os.exit(1)
end

-- 5. Test Auto-Detachment (Simulate Units.lua logic)
RoithiUI.db.profile.Castbar.player.detached = false
-- We call ns.SetCastbarAttachment with attached=false
ns.SetCastbarAttachment("player", false)

if parentSet ~= _G.UIParent then
    print("FAIL: Castbar not returned to UIParent during detachment")
    os.exit(1)
end

-- 6. Simulate Cast
local showCalled = false
playerBar.Show = function() showCalled = true end
_G.UnitCastingDuration = function()
    return {
        HasSecretValues = function() return false end,
        IsZero = function() return false end,
        GetTotalDuration = function() return 10 end,
        GetRemainingDuration = function() return 5 end,
    }
end
playerBar.SetTimerDuration = function() end

ns.UpdateCast(playerBar)

if not showCalled then
    print("FAIL: bar:Show() not called during UpdateCast")
    os.exit(1)
end

print("SUCCESS: Test_Castbar_Fix.lua logic and anchoring verified.")
