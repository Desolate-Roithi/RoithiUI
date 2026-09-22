local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local AB = RoithiUI:NewModule("Actionbars", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

AB.displayName = L["Action Bars"]
AB.description = L["Enables RoithiUI custom action bar styling and layout."]
AB.order = 90
AB.dbKey = "Actionbars"

AB.defaultSettings = {
    enabled = true,
    showHotkeys = true,
    showMacroText = true,
    font = "Friz Quadrata TT",
    fontSize = 11,
    borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
    bar1 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "BOTTOM", x = 0, y = 30 },
    bar2 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "BOTTOM", x = 0, y = 70 },
    bar3 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "BOTTOM", x = 0, y = 110 },
    bar4 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "RIGHT", x = -40, y = 0 },
    bar5 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "RIGHT", x = 0, y = 0 },
    pet = { enabled = true, buttonSize = 30, spacing = 4, buttonsPerRow = 10, point = "BOTTOM", x = 0, y = 150 },
    stance = { enabled = true, buttonSize = 30, spacing = 4, buttonsPerRow = 10, point = "BOTTOM", x = 0, y = 190 },
}

function AB:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Actionbars or self.defaultSettings
    self.bars = {}
    self.queuedLayout = false
end

function AB:OnEnable()
    if self.db.enabled == false then return end

    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("UPDATE_BINDINGS", "UpdateAllBindings")

    self:SetupBars()
    self:StyleAllBars()
    self:LayoutAllBars()
    self:SetupLEM()
end

function AB:OnDisable()
    self:UnregisterAllEvents()
    self:UnstyleAllBars()
    self:RestoreBlizzardBars()
end

function AB:PLAYER_REGEN_ENABLED()
    if self.queuedLayout then
        self.queuedLayout = false
        self:LayoutAllBars()
    end
end

function AB:UpdateAllBindings()
    self:StyleAllBars()
end

function AB:SafeLayout(callback)
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedLayout = true
        return
    end
    if callback then callback() end
end
