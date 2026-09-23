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
    showCount = true,
    iconZoom = 0.07,
    font = "Friz Quadrata TT",
    fontSize = 11,
    borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
    bar1 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "BOTTOM", x = 0, y = 30, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar2 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "BOTTOM", x = 0, y = 70, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar3 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "BOTTOM", x = 0, y = 110, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar4 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "RIGHT", x = -40, y = 0, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar5 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, point = "RIGHT", x = 0, y = 0, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    pet = { enabled = true, buttonSize = 30, spacing = 4, buttonsPerRow = 10, point = "BOTTOM", x = 0, y = 150, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    stance = { enabled = true, buttonSize = 30, spacing = 4, buttonsPerRow = 10, point = "BOTTOM", x = 0, y = 190, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
}

function AB:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Actionbars or self.defaultSettings
    self.bars = {}
    self.queuedLayout = false
    self.showingGrid = false
end

function AB:OnEnable()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Actionbars or self.defaultSettings
    if self.db.enabled == false then return end

    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("UPDATE_BINDINGS", "UpdateAllBindings")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "OnSlotChanged")
    self:RegisterEvent("ACTIONBAR_SHOWGRID", "OnShowGrid")
    self:RegisterEvent("ACTIONBAR_HIDEGRID", "OnHideGrid")
    self:RegisterEvent("PET_BAR_UPDATE", "OnPetBarUpdate")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", "OnStanceUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")

    self:SetupBars()
    self:StyleAllBars()
    self:LayoutAllBars()
    self:SetupLEM()
end

function AB:OnDisable()
    self:UnregisterAllEvents()
    self:UnstyleAllBars()
    self:RestoreBlizzardBars()
    if self.TeardownLEM then
        self:TeardownLEM()
    end
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

function AB:OnShowGrid()
    self.showingGrid = true
    if self.UpdateAllEmptyButtons then
        self:UpdateAllEmptyButtons()
    end
end

function AB:OnHideGrid()
    self.showingGrid = false
    if self.UpdateAllEmptyButtons then
        self:UpdateAllEmptyButtons()
    end
end

function AB:OnSlotChanged()
    if self.UpdateAllEmptyButtons then
        self:UpdateAllEmptyButtons()
    end
end

function AB:OnPetBarUpdate()
    if self.UpdateEmptyButtons then
        self:UpdateEmptyButtons("pet")
    end
end

function AB:OnStanceUpdate()
    if self.UpdateEmptyButtons then
        self:UpdateEmptyButtons("stance")
    end
end

function AB:OnEnteringWorld()
    if self.UpdateAllEmptyButtons then
        self:UpdateAllEmptyButtons()
    end
end

function AB:SafeLayout(callback)
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedLayout = true
        return
    end
    if callback then callback() end
end
