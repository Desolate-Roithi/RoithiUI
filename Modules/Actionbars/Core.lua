local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local AB = RoithiUI:NewModule("Actionbars", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

AB.displayName = L["Action Bars"]
AB.description = L["Enables RoithiUI custom action bar styling and layout."]
AB.order = 90
AB.dbKey = "Actionbars"
AB.defaultSettings = ns.ActionbarsDefaults or (ns.Defaults and ns.Defaults.profile and ns.Defaults.profile.Actionbars)

function AB:GetValidDivisors(count)
    local divisors = {}
    count = tonumber(count) or 12
    if count <= 0 then count = 1 end
    for i = 1, count do
        if count % i == 0 then
            table.insert(divisors, i)
        end
    end
    return divisors
end

function AB:GetNearestDivisor(val, count)
    local divisors = self:GetValidDivisors(count)
    if #divisors == 0 then return 1 end
    val = tonumber(val) or 1
    local best = divisors[1]
    local minDiff = math.abs(val - best)
    for i = 2, #divisors do
        local d = divisors[i]
        local diff = math.abs(val - d)
        if diff < minDiff then
            minDiff = diff
            best = d
        end
    end
    return best
end

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
    if self.UpdateAllEmptyButtons then
        self:UpdateAllEmptyButtons()
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
        if self.db[k] == nil then
            self.db[k] = type(v) == "table" and SafeCopyTable(v) or v
        end
    end
    self.bars = {}
    self.queuedLayout = false
    self.showingGrid = false
end

function AB:OnEnable()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Actionbars or self.defaultSettings
    for k, v in pairs(self.defaultSettings) do
        if self.db[k] == nil then
            self.db[k] = type(v) == "table" and SafeCopyTable(v) or v
        end
    end
    if self.db.enabled == false then return end

    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetChanged")
    if self.RegisterUnitEvent then
        self:RegisterUnitEvent("UNIT_SPELLCAST_START", "OnSpellcastEvent", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "OnSpellcastEvent", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "OnSpellcastEvent", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnSpellcastEvent", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "OnSpellcastEvent", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "OnSpellcastEvent", "player")
    else
        self:RegisterEvent("UNIT_SPELLCAST_START", "OnSpellcastEvent")
        self:RegisterEvent("UNIT_SPELLCAST_STOP", "OnSpellcastEvent")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnSpellcastEvent")
        self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnSpellcastEvent")
        self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START", "OnSpellcastEvent")
        self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP", "OnSpellcastEvent")
    end
    self:RegisterEvent("UPDATE_BINDINGS", "UpdateAllBindings")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "OnSlotChanged")
    self:RegisterEvent("ACTIONBAR_SHOWGRID", "OnShowGrid")
    self:RegisterEvent("ACTIONBAR_HIDEGRID", "OnHideGrid")
    self:RegisterEvent("PET_BAR_UPDATE", "OnPetBarUpdate")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", "OnStanceUpdate")
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED", "OnPageChanged")
    self:RegisterEvent("UPDATE_BONUS_ACTIONBAR", "OnActionBarStateUpdate")
    self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "OnActionBarStateUpdate")
    self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", "OnActionBarStateUpdate")
    self:RegisterEvent("UPDATE_EXTRA_ACTIONBAR", "OnExtraActionBarUpdate")
    self:RegisterEvent("SPELLS_CHANGED", "OnZoneAbilityUpdate")
    self:RegisterEvent("ZONE_CHANGED", "OnZoneAbilityUpdate")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneAbilityUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("ACTIONBAR_UPDATE_STATE", "OnUpdateState")

    self:SetupBars()
    self:StyleAllBars()
    self:LayoutAllBars()
    self:DisableActionPageSwitching()
    if self.ProtectOverrideActionBar then
        self:ProtectOverrideActionBar()
    end
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

function AB:PLAYER_REGEN_DISABLED()
    if _G.OverrideActionBar and _G.OverrideActionBar.slideOut then
        if _G.OverrideActionBar.slideOut.IsPlaying and _G.OverrideActionBar.slideOut:IsPlaying() then
            _G.OverrideActionBar.hideOnFinish = false
        end
    end
    self:OnFaderEvent()
end

function AB:PLAYER_REGEN_ENABLED()
    if _G.OverrideActionBar and _G.OverrideActionBar.IsShown and _G.OverrideActionBar:IsShown() then
        local hasSpecialBar = _G.C_ActionBar and (
            (_G.C_ActionBar.HasOverrideActionBar and _G.C_ActionBar.HasOverrideActionBar()) or
            (_G.C_ActionBar.HasVehicleActionBar and _G.C_ActionBar.HasVehicleActionBar())
        )
        if not hasSpecialBar and _G.OverrideActionBar.Hide then
            _G.OverrideActionBar:Hide()
        end
    end
    if self.queuedLayout then
        self.queuedLayout = false
        self:LayoutAllBars()
    end
    if self.queuedMouseUpdate then
        self.queuedMouseUpdate = false
        if self.UpdateAllEmptyButtons then
            self:UpdateAllEmptyButtons()
        end
    end
    self:OnFaderEvent()
end

function AB:OnTargetChanged()
    if self.UpdateAllBarFaders then
        self:UpdateAllBarFaders()
    end
    if self.UpdateAllButtonsRange then
        self:UpdateAllButtonsRange()
    end
end

function AB:OnFaderEvent()
    if self.UpdateAllBarFaders then
        self:UpdateAllBarFaders()
    end
end

function AB:OnSpellcastEvent(event, unit)
    if unit == "player" and self.UpdateAllBarFaders then
        self:UpdateAllBarFaders()
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
    if self.UpdateAllButtonsRange then
        self:UpdateAllButtonsRange()
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
    if self.SyncBar1Page then
        self:SyncBar1Page()
    end
    if self.LayoutBar then
        if _G.InCombatLockdown and _G.InCombatLockdown() then
            self.queuedLayout = true
        else
            self:LayoutBar("bar1")
        end
    end
    if self.UpdateEmptyButtons then
        self:UpdateEmptyButtons("bar1")
    end
    if self.UpdateAllButtonsRange then
        self:UpdateAllButtonsRange()
    end
end

function AB:OnActionBarStateUpdate()
    if self.SyncBar1Page then
        self:SyncBar1Page()
    end
    if self.UpdateEmptyButtons then
        self:UpdateEmptyButtons("bar1")
    end
    if self.UpdateAllButtonsRange then
        self:UpdateAllButtonsRange()
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
    if self.SyncBar1Page then
        self:SyncBar1Page()
    end
    if self.UpdateAllEmptyButtons then
        self:UpdateAllEmptyButtons()
    end
    if self.LayoutBar then
        self:LayoutBar("extraAction")
        self:LayoutBar("zoneAction")
    end
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.1, function()
            if self.UpdateAllEmptyButtons then self:UpdateAllEmptyButtons() end
            if self.LayoutBar then
                self:LayoutBar("extraAction")
                self:LayoutBar("zoneAction")
            end
        end)
        _G.C_Timer.After(0.5, function()
            if self.UpdateAllEmptyButtons then self:UpdateAllEmptyButtons() end
            if self.LayoutBar then
                self:LayoutBar("extraAction")
                self:LayoutBar("zoneAction")
            end
        end)
        _G.C_Timer.After(1.0, function()
            if self.UpdateAllEmptyButtons then self:UpdateAllEmptyButtons() end
            if self.LayoutBar then
                self:LayoutBar("extraAction")
                self:LayoutBar("zoneAction")
            end
        end)
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
    if self.UpdateAllEmptyButtons then
        self:UpdateAllEmptyButtons()
    end
    if not self.GetBarButtons or not self.UpdateOverlayContainment then return end
    local configs = self.BAR_CONFIGS or {}
    for barKey in pairs(configs) do
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            self:UpdateOverlayContainment(btn)
        end
    end
end

function AB:RefreshProfile()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Actionbars or self.defaultSettings
    for k, v in pairs(self.defaultSettings) do
        if self.db[k] == nil then
            self.db[k] = type(v) == "table" and SafeCopyTable(v) or v
        end
    end
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedLayout = true
        return
    end
    if self.LayoutAllBars then
        self:LayoutAllBars()
    end
    if self.StyleAllBars then
        self:StyleAllBars()
    end
    if self.UpdateAllEmptyButtons then
        self:UpdateAllEmptyButtons()
    end
    local LEM = LibStub and LibStub("LibEditMode-Roithi", true)
    if LEM and LEM.RefreshFrameSettings and self.bars then
        for _, bar in pairs(self.bars) do
            LEM:RefreshFrameSettings(bar)
        end
    end
end
AB.RefreshSettings = AB.RefreshProfile

function AB:UpdateFonts()
    if self.StyleAllBars then
        self:StyleAllBars()
    end
end
