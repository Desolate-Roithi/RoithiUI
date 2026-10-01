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
    bar1 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, maxButtons = 12, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 30, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar2 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, maxButtons = 12, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 70, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar3 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, maxButtons = 12, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 110, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar4 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, maxButtons = 12, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 150, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar5 = { enabled = true, buttonSize = 36, spacing = 4, buttonsPerRow = 12, maxButtons = 12, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 190, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar6 = { enabled = false, buttonSize = 36, spacing = 4, buttonsPerRow = 12, maxButtons = 12, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 230, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar7 = { enabled = false, buttonSize = 36, spacing = 4, buttonsPerRow = 12, maxButtons = 12, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 270, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    bar8 = { enabled = false, buttonSize = 36, spacing = 4, buttonsPerRow = 12, maxButtons = 12, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 310, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    pet = { enabled = true, buttonSize = 30, spacing = 4, buttonsPerRow = 10, maxButtons = 10, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 230, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    stance = { enabled = true, buttonSize = 30, spacing = 4, buttonsPerRow = 10, maxButtons = 10, orientation = "HORIZONTAL", point = "BOTTOM", x = 0, y = 265, alpha = 1.0, mouseover = false, mouseoverAlpha = 0, hideEmpty = false },
    extraAction = { enabled = true, buttonSize = 52, maxButtons = 1, point = "CENTER", x = 0, y = -100, alpha = 1.0 },
    zoneAction = { enabled = true, buttonSize = 52, maxButtons = 1, point = "CENTER", x = 0, y = -160, alpha = 1.0 },
}

function AB:ToggleQuickKeybind()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        if _G.UIErrorsFrame then
            _G.UIErrorsFrame:AddMessage(_G.ERR_NOT_IN_COMBAT or "Cannot do that in combat.", 1.0, 0.1, 0.1, 1.0)
        end
        return
    end

    local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
    if ACD then
        ACD:Close("RoithiUI")
    end

    if not _G.QuickKeybindFrame and _G.C_AddOns and _G.C_AddOns.LoadAddOn then
        pcall(_G.C_AddOns.LoadAddOn, "Blizzard_QuickKeybind")
    end
    if _G.QuickKeybindFrame then
        if _G.QuickKeybindFrame:IsShown() then
            _G.QuickKeybindFrame:Hide()
        else
            if _G.SettingsPanel and _G.SettingsPanel:IsShown() then
                _G.SettingsPanel:Close(true)
            end
            _G.QuickKeybindFrame:Show()
        end
    elseif _G.KeyBindingFrame_LoadUI then
        _G.KeyBindingFrame_LoadUI()
        if _G.KeyBindingFrame then
            if _G.KeyBindingFrame:IsShown() then _G.KeyBindingFrame:Hide() else _G.KeyBindingFrame:Show() end
        end
    elseif _G.Settings and _G.Settings.OpenToCategory then
        pcall(_G.Settings.OpenToCategory, "Keybindings")
    end
end

local function SafeCopyTable(src)
    if _G.CopyTable then return _G.CopyTable(src) end
    if type(src) ~= "table" then return src end
    local dest = {}
    for k, v in pairs(src) do
        dest[k] = type(v) == "table" and SafeCopyTable(v) or v
    end
    return dest
end

function AB:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Actionbars or self.defaultSettings
    for k, v in pairs(self.defaultSettings) do
        if type(v) == "table" and not self.db[k] then
            self.db[k] = SafeCopyTable(v)
        end
    end
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
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED", "OnPageChanged")
    self:RegisterEvent("UPDATE_EXTRA_ACTIONBAR", "OnExtraActionBarUpdate")
    self:RegisterEvent("SPELLS_CHANGED", "OnZoneAbilityUpdate")
    self:RegisterEvent("ZONE_CHANGED", "OnZoneAbilityUpdate")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneAbilityUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("ACTIONBAR_UPDATE_STATE", "OnUpdateState")

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
    if self.LayoutBar then
        self:LayoutBar("pet")
    end
    if self.UpdateEmptyButtons then
        self:UpdateEmptyButtons("pet")
    end
end

function AB:OnStanceUpdate()
    if self.LayoutBar then
        self:LayoutBar("stance")
    end
    if self.UpdateEmptyButtons then
        self:UpdateEmptyButtons("stance")
    end
end

function AB:OnPageChanged()
    if self.LayoutBar then
        if _G.InCombatLockdown and _G.InCombatLockdown() then
            self.queuedLayout = true
        else
            self:LayoutBar("bar1")
        end
    end
end

function AB:OnExtraActionBarUpdate()
    if self.LayoutBar then
        if _G.InCombatLockdown and _G.InCombatLockdown() then
            self.queuedLayout = true
        else
            self:LayoutBar("extraAction")
        end
    end
end

function AB:OnZoneAbilityUpdate()
    if self.LayoutBar then
        if _G.InCombatLockdown and _G.InCombatLockdown() then
            self.queuedLayout = true
        else
            self:LayoutBar("zoneAction")
        end
    end
end

function AB:OnEnteringWorld()
    if self.UpdateAllEmptyButtons then
        self:UpdateAllEmptyButtons()
    end
    if self.LayoutBar then
        self:LayoutBar("extraAction")
        self:LayoutBar("zoneAction")
    end
end

function AB:SafeLayout(callback)
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedLayout = true
        return
    end
    if callback then callback() end
end

function AB:OnUpdateState()
    if not self.GetBarButtons or not self.UpdateOverlayContainment then return end
    local configs = self.BAR_CONFIGS or {}
    for barKey in pairs(configs) do
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            self:UpdateOverlayContainment(btn)
        end
    end
end
