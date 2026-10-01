local addonName, ns = ...
if ns.skipLoad then return end
if not ns.IsForever and not ns.isTestEnvironment then return end
local RoithiUI = _G.RoithiUI
local Totems = RoithiUI:NewModule("Totems", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

Totems.displayName = L["Totem Bar"]
Totems.description = L["Dedicated totem, weapon enhancement, and elemental shield management bar."]
Totems.order = 95
Totems.dbKey = "Totems"

Totems.categories = { "earth", "fire", "water", "air", "shield", "weapon" }

Totems.categoryInfo = {
    earth = { name = L["Earth"], blizzSlot = 2, icon = 136097, emptyItemId = 5175, emptyIcon = "Interface\\Icons\\inv_misc_stonetablet_02", emptyColor = { r = 0.55, g = 0.85, b = 0.45, a = 0.85 } },
    fire = { name = L["Fire"], blizzSlot = 1, icon = 135824, emptyItemId = 5176, emptyIcon = "Interface\\Icons\\INV_Misc_Horn_01", emptyColor = { r = 1.0, g = 0.55, b = 0.3, a = 0.85 } },
    water = { name = L["Water"], blizzSlot = 3, icon = 136070, emptyItemId = 5177, emptyIcon = "Interface\\Icons\\INV_Potion_21", emptyColor = { r = 0.35, g = 0.75, b = 1.0, a = 0.85 } },
    air = { name = L["Air"], blizzSlot = 4, icon = 136014, emptyItemId = 5178, emptyIcon = "Interface\\Icons\\INV_Feather_05", emptyColor = { r = 0.85, g = 0.95, b = 1.0, a = 0.85 } },
    shield = { name = L["Shield"], blizzSlot = nil, icon = 136051, emptyItemId = nil, emptyIcon = "Interface\\Icons\\INV_Shield_04", emptyColor = { r = 0.85, g = 0.85, b = 0.85, a = 0.85 } },
    weapon = { name = L["Weapon"], blizzSlot = nil, icon = 136018, emptyItemId = nil, emptyIcon = "Interface\\Icons\\INV_Mace_01", emptyColor = { r = 0.85, g = 0.85, b = 0.85, a = 0.85 } },
}

Totems.spellsDatabase = {
    earth = {
        { id = 8071, name = "Stoneskin Totem" },
        { id = 8075, name = "Strength of Earth Totem" },
        { id = 8143, name = "Tremor Totem" },
        { id = 2484, name = "Earthbind Totem" },
        { id = 5730, name = "Stoneclaw Totem" },
        { id = 108285, name = "Earthgrab Totem" },
    },
    fire = {
        { id = 3599, name = "Searing Totem" },
        { id = 8190, name = "Magma Totem" },
        { id = 1535, name = "Fire Nova Totem" },
        { id = 8181, name = "Frost Resistance Totem" },
        { id = 8227, name = "Flametongue Totem" },
        { id = 2894, name = "Fire Elemental Totem" },
        { id = 192222, name = "Liquid Magma Totem" },
    },
    water = {
        { id = 5394, name = "Healing Stream Totem" },
        { id = 5675, name = "Mana Spring Totem" },
        { id = 8166, name = "Poison Cleansing Totem" },
        { id = 8170, name = "Disease Cleansing Totem" },
        { id = 8184, name = "Fire Resistance Totem" },
        { id = 16190, name = "Mana Tide Totem" },
        { id = 157153, name = "Cloudburst Totem" },
    },
    air = {
        { id = 8512, name = "Windfury Totem" },
        { id = 8835, name = "Grace of Air Totem" },
        { id = 8177, name = "Grounding Totem" },
        { id = 10595, name = "Nature Resistance Totem" },
        { id = 15107, name = "Windwall Totem" },
        { id = 6495, name = "Sentry Totem" },
        { id = 25908, name = "Tranquil Air Totem" },
        { id = 192058, name = "Capacitor Totem" },
        { id = 192077, name = "Wind Rush Totem" },
        { id = 98008, name = "Spirit Link Totem" },
    },
    shield = {
        { id = 324, name = "Lightning Shield" },
        { id = 52127, name = "Water Shield" },
        { id = 974, name = "Earth Shield" },
    },
    weapon = {
        { id = 8232, name = "Windfury Weapon" },
        { id = 8024, name = "Flametongue Weapon" },
        { id = 8017, name = "Rockbiter Weapon" },
        { id = 8033, name = "Frostbrand Weapon" },
        { id = 51730, name = "Earthliving Weapon" },
    },
}

Totems.defaultSettings = {
    enabled = true,
    showOnAllClasses = false,
    buttonSize = 36,
    spacing = 4,
    orientation = "HORIZONTAL",
    showDuration = true,
    showCooldown = true,
    showKeybind = true,
    showEarth = true,
    showFire = true,
    showWater = true,
    showAir = true,
    showShield = true,
    showWeapon = true,
    point = "CENTER",
    x = 0,
    y = -180,
    fontSize = 11,
    font = "Friz Quadrata TT",
    borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
    activeBorderColor = { r = 0.2, g = 0.8, b = 0.2, a = 1.0 },
    selectionBorderColor = { r = 1.0, g = 0.85, b = 0.0, a = 1.0 },
    selectedCategory = "earth",
    selectedSpells = {},
    disabledSpells = {},
}

function Totems:IsShaman()
    local _, playerClass = UnitClass("player")
    return playerClass == "SHAMAN"
end

function Totems:ShouldRun()
    if not ns.IsForever and not ns.isTestEnvironment then return false end
    if not self.db or self.db.enabled == false then return false end
    if self.db.showOnAllClasses then return true end
    return self:IsShaman()
end

function Totems:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Totems or self.defaultSettings
    if not self.db.disabledSpells then self.db.disabledSpells = {} end
    if not self.db.selectedSpells then self.db.selectedSpells = {} end
    self.buttons = {}
    self.availableSpells = {}
end

function Totems:HideBlizzardTotems()
    local function SuppressBar(f)
        if not f then return end
        if f.UnregisterAllEvents then f:UnregisterAllEvents() end
        if f.Hide then f:Hide() end
        if f.SetAlpha then f:SetAlpha(0) end
        if f.EnableMouse then f:EnableMouse(false) end
        if f.ClearAllPoints then f:ClearAllPoints() end
        if f.SetPoint then f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -9999, -9999) end
        if not f.roithiSuppressed and hooksecurefunc then
            hooksecurefunc(f, "Show", function(s)
                if self:IsEnabled() and self:ShouldRun() then
                    s:Hide()
                end
            end)
            f.roithiSuppressed = true
        end
    end

    SuppressBar(_G.TotemFrame)
    SuppressBar(_G.MultiCastActionBarFrame)
    SuppressBar(_G.TotemTracker)
    SuppressBar(_G.TotemBarFrame)

    if _G.MultiCastActionBarFrame_Update and hooksecurefunc and not self.multiCastHooked then
        hooksecurefunc("MultiCastActionBarFrame_Update", function()
            if self:IsEnabled() and self:ShouldRun() and _G.MultiCastActionBarFrame then
                _G.MultiCastActionBarFrame:Hide()
            end
        end)
        self.multiCastHooked = true
    end
    if _G.TotemFrame_Update and hooksecurefunc and not self.totemFrameHooked then
        hooksecurefunc("TotemFrame_Update", function()
            if self:IsEnabled() and self:ShouldRun() and _G.TotemFrame then
                _G.TotemFrame:Hide()
            end
        end)
        self.totemFrameHooked = true
    end
end

function Totems:RestoreBlizzardTotems()
    local function RestoreBar(f, updateEvt)
        if not f then return end
        if f.SetAlpha then f:SetAlpha(1) end
        if f.EnableMouse then f:EnableMouse(true) end
        if f.RegisterEvent then
            if updateEvt then f:RegisterEvent(updateEvt) end
            f:RegisterEvent("PLAYER_ENTERING_WORLD")
        end
        if f.Show then f:Show() end
    end

    RestoreBar(_G.TotemFrame, "PLAYER_TOTEM_UPDATE")
    RestoreBar(_G.MultiCastActionBarFrame, "UPDATE_MULTI_CAST_ACTIONBAR")

    if _G.TotemFrame_Update then _G.TotemFrame_Update() end
    if _G.MultiCastActionBarFrame_Update then _G.MultiCastActionBarFrame_Update() end
end

function Totems:OnCombatEnter()
    if self.flyout and self.flyout:IsShown() then
        self.flyout:Hide()
    end
end

function Totems:OnEnable()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Totems or self.defaultSettings
    if not self:ShouldRun() then
        if self.bar then self.bar:Hide() end
        return
    end

    self:HideBlizzardTotems()
    self:UpdateAvailableSpells()
    self:CreateTotemBar()
    self:UpdateBarLayout()
    self:SetupLEM()

    self.slotStates = {
        earth = { isActive = false, expirationTime = 0, count = 0 },
        fire = { isActive = false, expirationTime = 0, count = 0 },
        water = { isActive = false, expirationTime = 0, count = 0 },
        air = { isActive = false, expirationTime = 0, count = 0 },
        shield = { isActive = false, expirationTime = 0, count = 0 },
        weapon = { isActive = false, expirationTime = 0, count = 0 },
    }

    if self.SetupSecureKeybindButtons then
        self:SetupSecureKeybindButtons()
    end

    self:RegisterEvent("PLAYER_TOTEM_UPDATE", "OnTotemUpdate")
    self:RegisterEvent("SPELLS_CHANGED", "OnSpellsChanged")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "UpdateAllSpellCooldowns")
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnInventoryChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatEnter")
    self:RegisterEvent("UPDATE_BINDINGS", "OnUpdateBindings")

    if self.UpdateHotkeys then
        self:UpdateHotkeys()
    end
    self:UpdateAllSpellCooldowns()

    self.ticker = self:ScheduleRepeatingTimer("OnTick", 0.25)
end

function Totems:OnDisable()
    self:UnregisterAllEvents()
    if self.ticker then
        self:CancelTimer(self.ticker)
        self.ticker = nil
    end
    if self.bar then
        self.bar:Hide()
    end
    if self.flyout then
        self.flyout:Hide()
    end
    self:RestoreBlizzardTotems()
end

function Totems:BuildLearnedSpellsCache()
    local cache = {
        byName = {},
        byId = {},
    }

    if GetNumSpellTabs and GetSpellTabInfo and (GetSpellBookItemName or GetSpellBookItemInfo) then
        local numTabs = GetNumSpellTabs() or 0
        for tab = 1, numTabs do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            if offset and numSpells then
                for i = offset + 1, offset + numSpells do
                    local spellBookType = BOOKTYPE_SPELL or "spell"
                    if GetSpellBookItemInfo then
                        local _, spellId = GetSpellBookItemInfo(i, spellBookType)
                        if spellId then
                            cache.byId[spellId] = true
                        end
                    end
                    if GetSpellBookItemName then
                        local spellName = GetSpellBookItemName(i, spellBookType)
                        if spellName and spellName ~= "" then
                            cache.byName[spellName] = true
                            cache.byName[string.lower(spellName)] = true
                        end
                    end
                end
            end
        end
    end

    return cache
end

function Totems:IsSpellLearned(entry, cache)
    if not entry then return false end

    if self.mockKnownSpells then
        return self.mockKnownSpells[entry.id] == true or (entry.name and self.mockKnownSpells[entry.name] == true)
    end

    if ns and ns.isTestEnvironment then
        return true
    end

    local spellId = entry.id
    if spellId then
        if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellId) then
            return true
        end
        if IsPlayerSpell and IsPlayerSpell(spellId) then
            return true
        end
        if IsSpellKnown and IsSpellKnown(spellId) then
            return true
        end
        if cache and cache.byId and cache.byId[spellId] then
            return true
        end
    end

    if cache and cache.byName then
        local locName = nil
        if spellId then
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(spellId)
                if info and info.name then locName = info.name end
            elseif GetSpellInfo then
                locName = GetSpellInfo(spellId)
            end
        end

        if locName then
            if cache.byName[locName] or cache.byName[string.lower(locName)] then
                return true
            end
        end

        if entry.name then
            if cache.byName[entry.name] or cache.byName[string.lower(entry.name)] then
                return true
            end
        end
    end

    return false
end

function Totems:UpdateAvailableSpells()
    local cache = self:BuildLearnedSpellsCache()

    for _, catKey in ipairs(self.categories) do
        self.availableSpells[catKey] = {}
        local spellList = self.spellsDatabase[catKey] or {}
        for _, entry in ipairs(spellList) do
            local isSpellDisabled = self.db.disabledSpells and (self.db.disabledSpells[entry.id] == true or (entry.name and self.db.disabledSpells[entry.name] == true))
            if not isSpellDisabled and self:IsSpellLearned(entry, cache) then
                table.insert(self.availableSpells[catKey], entry)
            end
        end

        local current = self.db.selectedSpells[catKey]
        local exists = false
        if current then
            for _, s in ipairs(self.availableSpells[catKey]) do
                if s.id == current or s.name == current then
                    exists = true
                    break
                end
            end
        end
        if not exists then
            if #self.availableSpells[catKey] > 0 then
                self.db.selectedSpells[catKey] = self.availableSpells[catKey][1].id
            else
                self.db.selectedSpells[catKey] = nil
            end
        end
    end
end

local function FormatTimeSeconds(seconds)
    if not seconds or seconds <= 0 then return "" end
    if seconds >= 60 then
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        return string.format("%d:%02d", m, s)
    elseif seconds >= 10 then
        local mExact = math.floor(seconds)
        return string.format("%d", mExact)
    else
        return string.format("%.1f", seconds)
    end
end

function Totems:CreateTotemBar()
    if self.bar then return end

    local bar = CreateFrame("Frame", "RoithiTotemBar", UIParent)
    bar:SetSize(250, 40)
    bar:SetPoint(self.db.point or "CENTER", UIParent, self.db.point or "CENTER", self.db.x or 0, self.db.y or -180)
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    self.bar = bar

    for _, catKey in ipairs(self.categories) do
        local btn = CreateFrame("Button", "RoithiTotemButton_" .. catKey, bar, "SecureActionButtonTemplate, BackdropTemplate")
        if btn.RegisterForClicks then
            btn:RegisterForClicks("AnyUp", "AnyDown")
        end
        btn.categoryKey = catKey

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(btn)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn.icon = icon

        local cd = CreateFrame("Cooldown", "$parentCooldown", btn, "CooldownFrameTemplate")
        cd:SetAllPoints(btn)
        if cd.SetDrawEdge then
            cd:SetDrawEdge(false)
        end
        if cd.SetHideCountdownNumbers then
            cd:SetHideCountdownNumbers(false)
        end
        cd.noCooldownCount = nil
        cd.noOCC = nil
        btn.cooldown = cd

        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local fontPath = (LSM and LSM:Fetch("font", "Roithi Thick")) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

        local fsCooldown = btn:CreateFontString(nil, "OVERLAY", nil, 7)
        fsCooldown:SetPoint("CENTER", btn, "CENTER", 0, 0)
        fsCooldown:SetFont(fontPath, (self.db.fontSize or 11) + 2, "OUTLINE")
        fsCooldown:SetTextColor(1, 0.82, 0, 1)
        fsCooldown:SetJustifyH("CENTER")
        fsCooldown:Hide()
        btn.cooldownText = fsCooldown

        local fsTimer = btn:CreateFontString(nil, "OVERLAY")
        fsTimer:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        fsTimer:SetFont(fontPath, self.db.fontSize or 11, "OUTLINE")
        fsTimer:SetJustifyH("CENTER")
        btn.timerText = fsTimer

        local fsHotkey = btn:CreateFontString(nil, "OVERLAY")
        fsHotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
        fsHotkey:SetFont(fontPath, 9, "OUTLINE")
        fsHotkey:SetJustifyH("RIGHT")
        btn.hotkeyText = fsHotkey

        local fsCount = btn:CreateFontString(nil, "OVERLAY")
        fsCount:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        fsCount:SetFont(fontPath, 10, "OUTLINE")
        fsCount:SetJustifyH("RIGHT")
        btn.countText = fsCount

        -- Selection / Active Border
        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(btn)
        border:SetColorTexture(0, 0, 0, 0)
        btn.border = border

        if btn.SetBackdrop then
            btn:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            if btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(self.db.borderColor.r, self.db.borderColor.g, self.db.borderColor.b, self.db.borderColor.a)
            end
        end

        -- Extender Button
        local ext = CreateFrame("Button", "$parentExtender", btn, "BackdropTemplate")
        ext:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        ext:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
        ext:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)

        local arrow = ext:CreateTexture(nil, "OVERLAY")
        arrow:SetPoint("CENTER", ext, "CENTER", 0, 0)
        arrow:SetSize(10, 8)
        arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
        arrow:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        ext.arrow = arrow

        ext:SetScript("OnEnter", function(s)
            s:SetBackdropColor(0.25, 0.25, 0.25, 0.95)
            if s.arrow and s.arrow.SetVertexColor then
                s.arrow:SetVertexColor(1.0, 0.82, 0.0, 1.0)
            end
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(L["Change Totem"], 1, 1, 1)
            GameTooltip:AddLine(L["Click to select which totem to place."], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        ext:SetScript("OnLeave", function(s)
            s:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
            if s.arrow and s.arrow.SetVertexColor then
                s.arrow:SetVertexColor(0.85, 0.85, 0.85, 1.0)
            end
            GameTooltip:Hide()
        end)
        ext:SetScript("OnClick", function()
            self:ToggleFlyout(btn)
        end)
        btn.extender = ext

        -- Selection Overlay / Highlight
        local selHilight = btn:CreateTexture(nil, "OVERLAY", nil, 6)
        selHilight:SetAllPoints(btn)
        selHilight:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        selHilight:SetBlendMode("ADD")
        selHilight:Hide()
        btn.selectionHighlight = selHilight

        local selBorder = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        selBorder:SetAllPoints(btn)
        selBorder:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        local sc = self.db.selectionBorderColor or { r = 1.0, g = 0.85, b = 0.0, a = 1.0 }
        selBorder:SetBackdropBorderColor(sc.r, sc.g, sc.b, sc.a)
        selBorder:Hide()
        btn.selectionBorder = selBorder

        -- Flyout Selector on Right Click (for non-totem slots like shield/weapon) and Selection on Left Click
        if btn.HookScript then
            btn:HookScript("OnMouseDown", function(buttonSelf, mouseBtn)
                if not InCombatLockdown() then
                    if mouseBtn == "RightButton" then
                        local info = self.categoryInfo[catKey]
                        if not (info and info.blizzSlot) then
                            self:ToggleFlyout(buttonSelf)
                        end
                    elseif mouseBtn == "LeftButton" then
                        self.isKeyboardHighlight = false
                        self.db.selectedCategory = catKey
                        self:UpdateAllSlotBorders()
                        if self.UpdateCurrentActionButton then
                            self:UpdateCurrentActionButton()
                        end
                    end
                end
            end)
        end

        self.buttons[catKey] = btn
    end

    self:CreateFlyoutMenu()
    self:UpdateAllButtonAttributes()
end

function Totems:UpdateExtenderArrow(btn, isOpen)
    if not btn or not btn.extender or not btn.extender.arrow then return end
    local isHorizontal = (self.db.orientation or "HORIZONTAL") == "HORIZONTAL"
    if isHorizontal then
        if isOpen then
            if btn.extender.arrow.SetTexture then
                btn.extender.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
                btn.extender.arrow:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            elseif btn.extender.arrow.SetText then
                btn.extender.arrow:SetText("v")
            end
        else
            if btn.extender.arrow.SetTexture then
                btn.extender.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
                btn.extender.arrow:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            elseif btn.extender.arrow.SetText then
                btn.extender.arrow:SetText("^")
            end
        end
    else
        if isOpen then
            if btn.extender.arrow.SetTexture then
                btn.extender.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
                btn.extender.arrow:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            elseif btn.extender.arrow.SetText then
                btn.extender.arrow:SetText("<")
            end
        else
            if btn.extender.arrow.SetTexture then
                btn.extender.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
                btn.extender.arrow:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            elseif btn.extender.arrow.SetText then
                btn.extender.arrow:SetText(">")
            end
        end
    end
end

function Totems:CreateFlyoutMenu()
    if self.flyout then return end
    local flyout = CreateFrame("Frame", "RoithiTotemFlyout", UIParent, "BackdropTemplate")
    flyout:SetFrameStrata("DIALOG")
    flyout:SetClampedToScreen(true)
    flyout:Hide()
    flyout:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    flyout:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    flyout:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)

    if flyout.SetScript then
        flyout:SetScript("OnHide", function()
            for _, b in pairs(self.buttons) do
                self:UpdateExtenderArrow(b, false)
            end
        end)
    end

    flyout.spellButtons = {}
    self.flyout = flyout
end

function Totems:ToggleFlyout(anchorButton)
    if not self.flyout then return end
    if self.flyout:IsShown() and self.flyout.currentAnchor == anchorButton then
        self.flyout:Hide()
        self:UpdateExtenderArrow(anchorButton, false)
        return
    end

    local catKey = anchorButton.categoryKey
    local spells = self.availableSpells[catKey] or {}
    if #spells == 0 then
        self.flyout:Hide()
        self:UpdateExtenderArrow(anchorButton, false)
        return
    end

    for _, b in pairs(self.buttons) do
        self:UpdateExtenderArrow(b, false)
    end

    self.flyout.currentAnchor = anchorButton
    self.flyout:ClearAllPoints()

    local isHorizontal = (self.db.orientation or "HORIZONTAL") == "HORIZONTAL"
    if isHorizontal then
        self.flyout:SetPoint("BOTTOM", anchorButton, "TOP", 0, 14)
    else
        self.flyout:SetPoint("LEFT", anchorButton, "RIGHT", 14, 0)
    end

    local btnSize = self.db.buttonSize or 36
    local count = #spells
    self.flyout:SetSize(btnSize + 8, (btnSize + 4) * count + 4)

    for i, spellEntry in ipairs(spells) do
        local fBtn = self.flyout.spellButtons[i]
        if not fBtn then
            fBtn = CreateFrame("Button", nil, self.flyout, "BackdropTemplate")
            fBtn:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            local icon = fBtn:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(fBtn)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            fBtn.icon = icon
            self.flyout.spellButtons[i] = fBtn
        end

        fBtn:SetSize(btnSize, btnSize)
        fBtn:SetPoint("BOTTOM", self.flyout, "BOTTOM", 0, 4 + (i - 1) * (btnSize + 4))

        local texture = nil
        if C_Spell and C_Spell.GetSpellTexture then
            texture = C_Spell.GetSpellTexture(spellEntry.id)
        elseif GetSpellTexture then
            texture = GetSpellTexture(spellEntry.id) or (spellEntry.name and GetSpellTexture(spellEntry.name))
        end
        fBtn.icon:SetTexture(texture or self.categoryInfo[catKey].icon)

        local isCurrent = (self.db.selectedSpells[catKey] == spellEntry.id or self.db.selectedSpells[catKey] == spellEntry.name)
        if isCurrent then
            fBtn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        else
            fBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
        end

        fBtn:SetScript("OnEnter", function(s)
            if not isCurrent then
                s:SetBackdropBorderColor(0.6, 0.6, 0.6, 1.0)
            end
            if GameTooltip and GameTooltip.SetOwner then
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                if spellEntry.id and GameTooltip.SetSpellByID then
                    GameTooltip:SetSpellByID(spellEntry.id)
                elseif spellEntry.name and GameTooltip.SetText then
                    GameTooltip:SetText(spellEntry.name, 1, 1, 1)
                end
                GameTooltip:Show()
            end
        end)
        fBtn:SetScript("OnLeave", function(s)
            if isCurrent then
                s:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
            else
                s:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
            end
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end)

        fBtn:SetScript("OnClick", function()
            if InCombatLockdown() then
                if UIErrorsFrame and UIErrorsFrame.AddMessage then
                    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Cannot change totem during combat.", 1.0, 0.1, 0.1, 1.0)
                end
                return
            end
            self:SelectSpell(catKey, spellEntry.id)
            self.flyout:Hide()
        end)
        fBtn:Show()
    end

    -- Deselect / None Button
    local deselectIndex = count + 1
    local deselectBtn = self.flyout.spellButtons[deselectIndex]
    if not deselectBtn then
        deselectBtn = CreateFrame("Button", nil, self.flyout, "BackdropTemplate")
        deselectBtn:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        local icon = deselectBtn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(deselectBtn)
        deselectBtn.icon = icon
        self.flyout.spellButtons[deselectIndex] = deselectBtn
    end
    deselectBtn:SetSize(btnSize, btnSize)
    deselectBtn:SetPoint("BOTTOM", self.flyout, "BOTTOM", 0, 4 + (deselectIndex - 1) * (btnSize + 4))
    deselectBtn.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    local isNone = (self.db.selectedSpells[catKey] == nil)
    if isNone then
        deselectBtn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
    else
        deselectBtn:SetBackdropBorderColor(0.4, 0.2, 0.2, 1.0)
    end
    deselectBtn:SetScript("OnEnter", function(s)
        if not isNone then
            s:SetBackdropBorderColor(0.8, 0.2, 0.2, 1.0)
        end
        if GameTooltip and GameTooltip.SetOwner then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["Deselect Totem"], 1, 1, 1)
            GameTooltip:AddLine(L["Clear the active totem for this slot."], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    deselectBtn:SetScript("OnLeave", function(s)
        if isNone then
            s:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        else
            s:SetBackdropBorderColor(0.4, 0.2, 0.2, 1.0)
        end
        if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)
    deselectBtn:SetScript("OnClick", function()
        if InCombatLockdown() then
            if UIErrorsFrame and UIErrorsFrame.AddMessage then
                UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Cannot change totem during combat.", 1.0, 0.1, 0.1, 1.0)
            end
            return
        end
        self:SelectSpell(catKey, nil)
        self.flyout:Hide()
    end)
    deselectBtn:Show()

    for i = count + 2, #self.flyout.spellButtons do
        self.flyout.spellButtons[i]:Hide()
    end

    self.flyout:Show()
    self:UpdateExtenderArrow(anchorButton, true)
end

function Totems:SelectSpell(catKey, spellId)
    self.db.selectedSpells[catKey] = spellId
    self.db.selectedCategory = catKey
    self:UpdateButtonAttributes(catKey)
    self:UpdateTotemDisplay(catKey)
    self:UpdateAllSlotBorders()
    if self.UpdateCurrentActionButton then
        self:UpdateCurrentActionButton()
    end
end

function Totems:UpdateAllButtonAttributes()
    for _, catKey in ipairs(self.categories) do
        self:UpdateButtonAttributes(catKey)
    end
end

function Totems:UpdateButtonAttributes(catKey)
    local btn = self.buttons[catKey]
    if not btn then return end

    local spellId = self.db.selectedSpells[catKey]
    local spellName = nil
    local spellTexture = nil

    if spellId then
        if C_Spell and C_Spell.GetSpellInfo then
            local spellInfo = C_Spell.GetSpellInfo(spellId)
            if spellInfo then
                spellName = spellInfo.name
                spellTexture = spellInfo.iconID
            end
        elseif GetSpellInfo then
            local name, _, icon = GetSpellInfo(spellId)
            spellName = name
            spellTexture = icon
        end
    end

    local info = self.categoryInfo[catKey]
    if spellTexture then
        btn.icon:SetTexture(spellTexture)
        btn.icon:SetVertexColor(1, 1, 1, 1)
    else
        local emptyIcon = nil
        if info and info.emptyItemId and _G.GetItemIcon then
            emptyIcon = _G.GetItemIcon(info.emptyItemId)
        end
        if not emptyIcon and info then
            emptyIcon = info.emptyIcon or info.icon
        end
        btn.icon:SetTexture(emptyIcon or 136097)
        local c = (info and info.emptyColor) or { r = 0.8, g = 0.8, b = 0.8, a = 0.8 }
        btn.icon:SetVertexColor(c.r, c.g, c.b, c.a)
    end

    if not InCombatLockdown() then
        if spellName or spellId then
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("spell", spellName or spellId)
        else
            btn:SetAttribute("type", nil)
            btn:SetAttribute("spell", nil)
        end

        -- Configure unsummon / destroy on right click
        if info and info.blizzSlot then
            btn:SetAttribute("type2", "destroytotem")
            btn:SetAttribute("totem-slot", info.blizzSlot)
        end
    end
end

function Totems:UpdateBarLayout()
    if not self.bar then return end

    local size = self.db.buttonSize or 36
    local spacing = self.db.spacing or 4
    local isHorizontal = (self.db.orientation or "HORIZONTAL") == "HORIZONTAL"

    local visibleCategories = {}
    for _, catKey in ipairs(self.categories) do
        local optKey = "show" .. catKey:gsub("^%l", string.upper)
        local enabledByOpt = (self.db[optKey] ~= false)
        local hasKnownSpells = self.availableSpells[catKey] and (#self.availableSpells[catKey] > 0)
        if enabledByOpt and hasKnownSpells then
            table.insert(visibleCategories, catKey)
        end
    end

    local numVisible = #visibleCategories
    if numVisible == 0 then
        for _, btn in pairs(self.buttons) do
            btn:Hide()
            if btn.extender then
                btn.extender:Hide()
            end
        end
        self.bar:Hide()
        return
    end

    if isHorizontal then
        self.bar:SetSize(numVisible * size + (numVisible - 1) * spacing, size)
    else
        self.bar:SetSize(size, numVisible * size + (numVisible - 1) * spacing)
    end

    for _, catKey in ipairs(self.categories) do
        local btn = self.buttons[catKey]
        if btn then
            local isVisible = false
            for idx, vKey in ipairs(visibleCategories) do
                if vKey == catKey then
                    isVisible = true
                    btn:SetSize(size, size)
                    btn:ClearAllPoints()
                    if isHorizontal then
                        btn:SetPoint("LEFT", self.bar, "LEFT", (idx - 1) * (size + spacing), 0)
                    else
                        btn:SetPoint("TOP", self.bar, "TOP", 0, -((idx - 1) * (size + spacing)))
                    end
                    break
                end
            end

            if isVisible then
                btn:Show()
                if btn.timerText then
                    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                    local fontPath = (LSM and LSM:Fetch("font", "Roithi Thick")) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
                    btn.timerText:SetFont(fontPath, self.db.fontSize or 11, "OUTLINE")
                end
                if btn.extender then
                    btn.extender:ClearAllPoints()
                    if isHorizontal then
                        btn.extender:SetPoint("BOTTOM", btn, "TOP", 0, 1)
                        btn.extender:SetSize(size, 10)
                        if btn.extender.arrow then
                            if btn.extender.arrow.SetTexture then
                                btn.extender.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
                                btn.extender.arrow:SetTexCoord(0.25, 0.75, 0.25, 0.75)
                            elseif btn.extender.arrow.SetText then
                                btn.extender.arrow:SetText("^")
                            end
                        end
                    else
                        btn.extender:SetPoint("LEFT", btn, "RIGHT", 1, 0)
                        btn.extender:SetSize(10, size)
                        if btn.extender.arrow then
                            if btn.extender.arrow.SetTexture then
                                btn.extender.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
                                btn.extender.arrow:SetTexCoord(0.25, 0.75, 0.25, 0.75)
                            elseif btn.extender.arrow.SetText then
                                btn.extender.arrow:SetText(">")
                            end
                        end
                    end
                    btn.extender:Show()
                end
            else
                btn:Hide()
                if btn.extender then
                    btn.extender:Hide()
                end
            end
        end
    end

    self:UpdateAllSlotBorders()
    self.bar:Show()
end

function Totems:UpdateSpellCooldown(catKey)
    local btn = self.buttons[catKey]
    if not btn or not btn.cooldown then return end

    if not self.db.showCooldown then
        btn.cooldownEnd = nil
        if btn.cooldownText then btn.cooldownText:Hide() end
        CooldownFrame_Set(btn.cooldown, 0, 0, false)
        if btn.cooldown.Clear then btn.cooldown:Clear() end
        return
    end

    local spellId = self.db.selectedSpells and self.db.selectedSpells[catKey]
    local start, duration, enabled = 0, 0, false

    if spellId then
        if C_Spell and C_Spell.GetSpellCooldown then
            local cdInfo = C_Spell.GetSpellCooldown(spellId)
            if cdInfo then
                start = cdInfo.startTime or 0
                duration = cdInfo.duration or 0
                enabled = cdInfo.isEnabled
            end
        elseif _G.GetSpellCooldown then
            start, duration, enabled = _G.GetSpellCooldown(spellId)
        end
    end

    if btn.cooldown.SetHideCountdownNumbers then
        btn.cooldown:SetHideCountdownNumbers(false)
    end
    btn.cooldown.noCooldownCount = nil

    local isSecret = false
    if _G.issecretvalue and (_G.issecretvalue(duration) or _G.issecretvalue(start)) then
        isSecret = true
    elseif type(duration) == "userdata" or type(start) == "userdata" then
        isSecret = true
    else
        local ok, _ = pcall(function() return duration > 1.5 end)
        if not ok then
            isSecret = true
        end
    end

    if isSecret then
        btn.cooldownEnd = nil
        if btn.cooldownText then btn.cooldownText:Hide() end
        CooldownFrame_Set(btn.cooldown, start, duration, enabled)
    elseif start and duration and duration > 1.5 then
        btn.cooldownEnd = start + duration
        CooldownFrame_Set(btn.cooldown, start, duration, enabled)
    elseif start and duration and duration > 0 then
        btn.cooldownEnd = nil
        if btn.cooldownText then btn.cooldownText:Hide() end
        CooldownFrame_Set(btn.cooldown, start, duration, enabled)
    else
        btn.cooldownEnd = nil
        if btn.cooldownText then btn.cooldownText:Hide() end
        CooldownFrame_Set(btn.cooldown, 0, 0, false)
        if btn.cooldown.Clear then btn.cooldown:Clear() end
    end
end

function Totems:UpdateAllSpellCooldowns()
    for _, catKey in ipairs(self.categories) do
        self:UpdateSpellCooldown(catKey)
    end
end

function Totems:UpdateTotemSlots()
    local now = GetTime()
    for _, catKey in ipairs(self.categories) do
        local info = self.categoryInfo[catKey]
        if info and info.blizzSlot then
            local state = self.slotStates[catKey]
            local haveTotem, _, startTime, duration, _ = false, nil, 0, 0, nil
            if GetTotemInfo then
                haveTotem, _, startTime, duration, _ = GetTotemInfo(info.blizzSlot)
            end

            local isActive = false
            local expTime = 0
            local ok, active = pcall(function()
                return haveTotem and duration and duration > 0 and (startTime + duration) > now
            end)
            if ok and active then
                isActive = true
                expTime = startTime + duration
            elseif not ok and haveTotem then
                isActive = true
                expTime = 0
            end

            state.isActive = isActive
            state.expirationTime = expTime
            self:UpdateSlotBorder(catKey)
        end
    end
    self:UpdateAllSpellCooldowns()
end

function Totems:UpdateShieldSlot()
    local state = self.slotStates.shield
    local btn = self.buttons.shield
    local isActive = false
    local expiration = 0
    local count = 0

    local shieldSpells = { [324] = true, [52127] = true, [974] = true }
    if UnitAura then
        for i = 1, 40 do
            local name, _, buffCount, _, _, expirationTime, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
            if not name then break end
            if shieldSpells[spellId] or (name and (name:find("Shield") or name:find("Schild"))) then
                isActive = true
                count = buffCount or 0
                expiration = expirationTime or 0
                break
            end
        end
    end

    state.isActive = isActive
    state.expirationTime = expiration
    state.count = count

    if btn then
        if count and count > 1 then
            btn.countText:SetText(tostring(count))
        else
            btn.countText:SetText("")
        end
    end
    self:UpdateSlotBorder("shield")
end

function Totems:UpdateWeaponSlot()
    local state = self.slotStates.weapon
    local btn = self.buttons.weapon
    local isActive = false
    local expiration = 0
    local count = 0

    if GetWeaponEnchantInfo then
        local hasMainHandEnchant, mainHandExpiration, mainHandCharges = GetWeaponEnchantInfo()
        if hasMainHandEnchant then
            isActive = true
            if mainHandExpiration and mainHandExpiration > 0 then
                expiration = GetTime() + (mainHandExpiration / 1000)
            end
            count = mainHandCharges or 0
        end
    end

    state.isActive = isActive
    state.expirationTime = expiration
    state.count = count

    if btn then
        if count and count > 1 then
            btn.countText:SetText(tostring(count))
        else
            btn.countText:SetText("")
        end
    end
    self:UpdateSlotBorder("weapon")
end

function Totems:UpdateSlotBorder(catKey)
    local btn = self.buttons[catKey]
    if not btn then return end

    local state = self.slotStates and self.slotStates[catKey]
    local isSelected = (self.db.selectedCategory == catKey) and (self.isKeyboardHighlight == true)

    if isSelected then
        if btn.selectionHighlight then btn.selectionHighlight:Show() end
        if btn.selectionBorder then
            local sc = self.db.selectionBorderColor or { r = 1.0, g = 0.85, b = 0.0, a = 1.0 }
            btn.selectionBorder:SetBackdropBorderColor(sc.r, sc.g, sc.b, sc.a)
            btn.selectionBorder:Show()
        end
        btn:SetBackdropBorderColor(1.0, 0.85, 0.0, 1.0)
    elseif state and state.isActive then
        if btn.selectionHighlight then btn.selectionHighlight:Hide() end
        if btn.selectionBorder then
            local c = self.db.activeBorderColor or { r = 0.2, g = 0.8, b = 0.2, a = 1.0 }
            btn.selectionBorder:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
            btn.selectionBorder:Show()
        end
        local c = self.db.activeBorderColor or { r = 0.2, g = 0.8, b = 0.2, a = 1.0 }
        btn:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    else
        if btn.selectionHighlight then btn.selectionHighlight:Hide() end
        if btn.selectionBorder then btn.selectionBorder:Hide() end
        local c = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
        btn:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end
end

function Totems:UpdateAllSlotBorders()
    for _, catKey in ipairs(self.categories) do
        self:UpdateSlotBorder(catKey)
    end
end

function Totems:UpdateTotemDisplay(catKey)
    local info = self.categoryInfo[catKey]
    if info and info.blizzSlot then
        self:UpdateTotemSlots()
    elseif catKey == "shield" then
        self:UpdateShieldSlot()
    elseif catKey == "weapon" then
        self:UpdateWeaponSlot()
    end
    self:OnTick()
end

function Totems:OnTick()
    local now = GetTime()
    for _, catKey in ipairs(self.categories) do
        local btn = self.buttons[catKey]
        local state = self.slotStates and self.slotStates[catKey]
        if btn and btn:IsShown() then
            if btn.cooldownText then
                local isCdActive = false
                if btn.cooldownEnd then
                    local ok, cmp = pcall(function() return btn.cooldownEnd > now end)
                    isCdActive = ok and cmp
                end
                if isCdActive and self.db.showCooldown ~= false then
                    btn.cooldownText:SetText(FormatTimeSeconds(btn.cooldownEnd - now))
                    btn.cooldownText:Show()
                else
                    btn.cooldownText:SetText("")
                    btn.cooldownText:Hide()
                end
            end
            if state then
                local isExpActive = false
                local isTimedOut = false
                if state.isActive and state.expirationTime then
                    local ok, cmp = pcall(function() return state.expirationTime > now end)
                    if ok and cmp then
                        isExpActive = true
                    elseif ok and not cmp and state.expirationTime > 0 then
                        isTimedOut = true
                    end
                end
                if isExpActive then
                    if self.db.showDuration then
                        btn.timerText:SetText(FormatTimeSeconds(state.expirationTime - now))
                    else
                        btn.timerText:SetText("")
                    end
                else
                    btn.timerText:SetText("")
                    if isTimedOut then
                        -- Timed out: refresh this slot
                        state.isActive = false
                        state.expirationTime = 0
                        local info = self.categoryInfo[catKey]
                        if info and info.blizzSlot then
                            self:UpdateTotemSlots()
                        elseif catKey == "shield" then
                            self:UpdateShieldSlot()
                        elseif catKey == "weapon" then
                            self:UpdateWeaponSlot()
                        end
                    end
                end
            end
        end
    end
end

function Totems:OnTotemUpdate()
    self:UpdateTotemSlots()
    self:OnTick()
end

function Totems:OnSpellsChanged()
    self:UpdateAvailableSpells()
    self:UpdateAllButtonAttributes()
    self:UpdateBarLayout()
end

function Totems:OnUnitAura(_, unit)
    if unit == "player" then
        self:UpdateShieldSlot()
        self:OnTick()
    end
end

function Totems:OnInventoryChanged()
    self:UpdateWeaponSlot()
    self:OnTick()
end

function Totems:OnUpdateBindings()
    if self.UpdateHotkeys then
        self:UpdateHotkeys()
    end
end

function Totems:OnEnteringWorld()
    self:HideBlizzardTotems()
    self:UpdateAvailableSpells()
    self:UpdateAllButtonAttributes()
    self:UpdateBarLayout()
    self:UpdateTotemSlots()
    self:UpdateShieldSlot()
    self:UpdateWeaponSlot()
    self:OnUpdateBindings()
    self:OnTick()
end

function Totems:SetupLEM()
    local LEM = LibStub and LibStub("LibEditMode-Roithi", true)
    if not LEM or not self.bar then return end

    local defaultPos = {
        point = "CENTER",
        x = 0,
        y = -180,
    }
    LEM:AddFrame(self.bar, function(f, _, newPoint, newX, newY)
        self.db.point = newPoint
        self.db.x = newX
        self.db.y = newY
    end, defaultPos, L["Totem Bar"])

    if LEM.AddFrameSettingsButtons then
        LEM:AddFrameSettingsButtons(self.bar, {
            {
                text = L["Open Full Settings"] or "Open Full Settings",
                click = function()
                    if RoithiUI and RoithiUI.OpenSettings then
                        RoithiUI:OpenSettings("totems")
                    elseif LibStub("AceConfigDialog-3.0") then
                        LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "actionbars_group", "totems")
                        LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                    end
                end,
            },
        })
    end
end
