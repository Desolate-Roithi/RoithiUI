local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local AB = RoithiUI:GetModule("Actionbars")
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode-Roithi", true)

local BAR_CONFIGS = {
    bar1 = { name = "RoithiActionBar1", prefix = "ActionButton", count = 12 },
    bar2 = { name = "RoithiActionBar2", prefix = "MultiBarBottomLeftButton", count = 12, actionPage = 6 },
    bar3 = { name = "RoithiActionBar3", prefix = "MultiBarBottomRightButton", count = 12, actionPage = 5 },
    bar4 = { name = "RoithiActionBar4", prefix = "MultiBarRightButton", count = 12, actionPage = 3 },
    bar5 = { name = "RoithiActionBar5", prefix = "MultiBarLeftButton", count = 12, actionPage = 4 },
    bar6 = { name = "RoithiActionBar6", prefix = "MultiBar5Button", count = 12, actionPage = 13 },
    bar7 = { name = "RoithiActionBar7", prefix = "MultiBar6Button", count = 12, actionPage = 14 },
    bar8 = { name = "RoithiActionBar8", prefix = "MultiBar7Button", count = 12, actionPage = 15 },
    pet = { name = "RoithiActionPetBar", prefix = "PetActionButton", count = 10 },
    stance = { name = "RoithiActionStanceBar", prefix = "StanceButton", count = 10, altPrefix = "ShapeshiftButton" },
    extraAction = { name = "RoithiExtraActionBar", prefix = "ExtraActionButton", count = 1 },
    zoneAction = { name = "RoithiZoneActionBar", count = 1 },
}
AB.BAR_CONFIGS = BAR_CONFIGS

local BLIZZARD_BAR_FRAMES = {
    bar1 = { "MainActionBar", "MainMenuBar", "OverrideActionBar" },
    bar2 = { "MultiBarBottomLeft" },
    bar3 = { "MultiBarBottomRight" },
    bar4 = { "MultiBarRight" },
    bar5 = { "MultiBarLeft" },
    bar6 = { "MultiBar5" },
    bar7 = { "MultiBar6" },
    bar8 = { "MultiBar7" },
    pet = { "PetActionBar", "PetActionBarFrame" },
    stance = { "StanceBar", "StanceBarFrame", "ShapeshiftBarFrame" },
    extraAction = { "ExtraActionBarFrame" },
    zoneAction = { "ZoneAbilityFrame" },
}
AB.BLIZZARD_BAR_FRAMES = BLIZZARD_BAR_FRAMES

local function IsRangeIndicator(text)
    if not text or text == "" then return false end
    if (_G.RANGE_INDICATOR and text == _G.RANGE_INDICATOR) or text == "·" or text == "•" or text:find("[\194\183\226\128\162]") then
        return true
    end
    return false
end
AB.IsRangeIndicator = IsRangeIndicator

local function FormatHotkey(text)
    if ns.Utils and ns.Utils.FormatHotkey then
        return ns.Utils.FormatHotkey(text)
    end
    return text or ""
end
AB.FormatHotkey = FormatHotkey

local function RestoreButtonUsability(btn, icon)
    if btn.UpdateUsable then
        btn:UpdateUsable()
    elseif _G.ActionButton_UpdateUsable then
        _G.ActionButton_UpdateUsable(btn)
    elseif _G.PetActionButton_Update and btn.buttonType == "PET" then
        _G.PetActionButton_Update(btn)
    elseif icon and icon.SetVertexColor then
        icon:SetVertexColor(1, 1, 1)
    end
end
AB.RestoreButtonUsability = RestoreButtonUsability

function AB:IsHideEmpty(barKey)
    local barDb = barKey and self.db and self.db[barKey]
    if barDb and barDb.hideEmpty ~= nil then
        return barDb.hideEmpty == true
    end
    if self.db and self.db.hideEmpty ~= nil then
        return self.db.hideEmpty == true
    end
    return true
end

local function ButtonHasAction(btn)
    if not btn then return false end
    if btn.HasAction then
        return btn:HasAction() == true
    end
    local action = btn.action or (btn.CalculateAction and btn:CalculateAction()) or (btn.GetPagedID and btn:GetPagedID())
    if action and action > 0 then
        if _G.C_ActionBar and _G.C_ActionBar.HasAction then
            return _G.C_ActionBar.HasAction(action) == true
        elseif _G.HasAction then
            return _G.HasAction(action) == true
        end
    end
    local barKey = btn.roithiBarKey or btn.barKey
    if not barKey then
        local bName = btn.GetName and btn:GetName() or ""
        for k, cfg in pairs(BAR_CONFIGS) do
            if cfg.prefix and bName:find("^" .. cfg.prefix) then
                barKey = k
                btn.roithiBarKey = k
                break
            end
        end
    end
    local cfg = barKey and BAR_CONFIGS[barKey]
    if cfg and cfg.actionPage then
        local id = btn.GetID and btn:GetID()
        if id and id > 0 then
            local slot = id + ((cfg.actionPage - 1) * 12)
            if _G.C_ActionBar and _G.C_ActionBar.HasAction then
                return _G.C_ActionBar.HasAction(slot) == true
            elseif _G.HasAction then
                return _G.HasAction(slot) == true
            end
        end
    end
    local name = btn.GetName and btn:GetName() or ""
    if btn.GetPetActionInfo or name:find("PetAction") then
        local id = btn.GetID and btn:GetID()
        if id and _G.GetPetActionInfo then
            local _, _, texture = _G.GetPetActionInfo(id)
            return texture ~= nil
        end
    end
    if name:find("Stance") or name:find("Shapeshift") then
        local id = btn.GetID and btn:GetID()
        if id and _G.GetShapeshiftFormInfo then
            local texture = _G.GetShapeshiftFormInfo(id)
            return texture ~= nil
        end
        return false
    end
    return false
end

local function IsExtraActionActive()
    if _G.C_ActionBar and _G.C_ActionBar.HasExtraActionBar then
        return _G.C_ActionBar.HasExtraActionBar() == true
    end
    if _G.HasExtraActionBar then
        return _G.HasExtraActionBar() == true
    end
    local btn = _G.ExtraActionButton1
    if btn then
        local action = btn.action or (btn.CalculateAction and btn:CalculateAction())
        if action and _G.HasAction and _G.HasAction(action) then
            local texture = _G.GetActionTexture and _G.GetActionTexture(action)
            return texture ~= nil and texture ~= ""
        end
    end
    return false
end
AB.IsExtraActionActive = IsExtraActionActive

local function IsZoneActionActive()
    if _G.C_ZoneAbility and _G.C_ZoneAbility.GetActiveAbilities then
        local abilities = _G.C_ZoneAbility.GetActiveAbilities()
        return abilities ~= nil and #abilities > 0
    end
    local zf = _G.ZoneAbilityFrame
    if zf then
        if zf.HasZoneAbility and zf:HasZoneAbility() then
            return true
        end
        if zf.SpellButtonContainer and zf.SpellButtonContainer.EnumerateActive then
            local iter, state = zf.SpellButtonContainer:EnumerateActive()
            if iter and iter(state) then
                return true
            end
        end
    end
    return false
end
AB.IsZoneActionActive = IsZoneActionActive

function AB:GetBarButtons(barKey)
    local cfg = BAR_CONFIGS[barKey]
    if not cfg then return {} end

    if barKey == "zoneAction" then
        local buttons = {}
        local zf = _G.ZoneAbilityFrame
        if zf then
            if zf.SpellButtonContainer and zf.SpellButtonContainer.EnumerateActive then
                for spellBtn in zf.SpellButtonContainer:EnumerateActive() do
                    table.insert(buttons, spellBtn)
                end
            end
            if #buttons == 0 and zf.SpellButton then
                table.insert(buttons, zf.SpellButton)
            end
        end
        if #buttons == 0 and _G.ZoneAbilityButton1 then
            table.insert(buttons, _G.ZoneAbilityButton1)
        end
        return buttons
    end

    local buttons = {}
    for i = 1, cfg.count do
        local btn = _G[cfg.prefix .. i]
        if not btn and cfg.altPrefix then
            btn = _G[cfg.altPrefix .. i]
        end
        if btn then
            btn.roithiBarKey = barKey
            table.insert(buttons, btn)
        end
    end
    return buttons
end

function AB:SetButtonsMouseInteractivity(enable)
    if not self.bars then return end
    for _, container in pairs(self.bars) do
        if container and LEM and LEM.frameSelections and LEM.frameSelections[container] then
            local sel = LEM.frameSelections[container]
            if sel then
                if sel.SetFrameLevel then
                    sel:SetFrameLevel(container:GetFrameLevel() + (enable and 0 or 100))
                end
                if sel.EnableMouse then
                    sel:EnableMouse(not enable)
                end
            end
        end
    end
end

function AB:IsBarMouseOver(barKey)
    local container = self.bars[barKey]
    if not container then return false end
    if container.IsMouseOver and container:IsMouseOver() then return true end
    local buttons = self:GetBarButtons(barKey)
    for _, btn in ipairs(buttons) do
        if btn.IsMouseOver and btn:IsMouseOver() then return true end
    end
    return false
end

function AB:IsFaderActive(barKey)
    if _G.InCombatLockdown and _G.InCombatLockdown() then return true end
    if _G.UnitExists and _G.UnitExists("target") then return true end
    if _G.UnitCastingInfo and _G.UnitCastingInfo("player") then return true end
    if _G.UnitChannelInfo and _G.UnitChannelInfo("player") then return true end
    if _G.UnitEmpoweredChannelDuration and _G.UnitEmpoweredChannelDuration("player") then return true end
    if self:IsBarMouseOver(barKey) then return true end
    return false
end

function AB:UpdateBarMouseover(barKey)
    local container = self.bars[barKey]
    if not container then return end
    local db = self.db and self.db[barKey] or {}
    if db.enabled == false then
        if container.Hide then container:Hide() end
        return
    end

    local alpha
    if db.mouseover then
        alpha = (not self:IsBarMouseOver(barKey)) and (db.mouseoverAlpha or 0.0) or (db.alpha or 1.0)
    elseif self.db and self.db.enableFader then
        if self:IsFaderActive(barKey) then
            alpha = db.alpha or 1.0
        else
            alpha = self.db.faderIdleAlpha or 0.3
        end
    else
        alpha = db.alpha or 1.0
    end

    if container.SetAlpha then
        container:SetAlpha(alpha)
    end
end

function AB:UpdateAllBarFaders()
    if not self.bars then return end
    for barKey in pairs(BAR_CONFIGS) do
        self:UpdateBarMouseover(barKey)
    end
end

function AB:OnBarEnter(barKey)
    local db = self.db and self.db[barKey] or {}
    if db.mouseover or (self.db and self.db.enableFader) then
        local container = self.bars[barKey]
        if container and container.SetAlpha then
            container:SetAlpha(db.alpha or 1.0)
        end
    end
end

function AB:OnBarLeave(barKey)
    local db = self.db and self.db[barKey] or {}
    if (db.mouseover or (self.db and self.db.enableFader)) and _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.05, function()
            self:UpdateBarMouseover(barKey)
        end)
    end
end

function AB:UpdateEmptyButtons(barKey, customButtons)
    local db = self.db and self.db[barKey] or {}
    if db.enabled == false then return end

    local buttons = customButtons or self:GetBarButtons(barKey)
    local maxBtns = db.maxButtons or #buttons
    if maxBtns < 1 then maxBtns = 1 end
    local displayCount = math.min(#buttons, maxBtns)
    if barKey == "stance" then
        local numForms = _G.GetNumShapeshiftForms and _G.GetNumShapeshiftForms() or 0
        displayCount = math.min(displayCount, numForms)
    end
    local isQuickKeybind = (_G.QuickKeybindFrame and _G.QuickKeybindFrame.IsShown and _G.QuickKeybindFrame:IsShown()) or false
    local isEditMode = false
    if LEM and LEM.IsInEditMode and LEM:IsInEditMode() then
        isEditMode = true
    elseif _G.EditModeManagerFrame and _G.EditModeManagerFrame.IsShown and _G.EditModeManagerFrame:IsShown() then
        isEditMode = true
    end
    local hideEmpty = self:IsHideEmpty(barKey) and not self.showingGrid and not isQuickKeybind and not isEditMode

    local inCombat = (_G.InCombatLockdown and _G.InCombatLockdown()) or false

    for i, btn in ipairs(buttons) do
        if i <= displayCount then
            local hasAct = ButtonHasAction(btn)
            local canClick = hasAct or self.showingGrid or isQuickKeybind or isEditMode
            if barKey == "stance" then
                canClick = true
            end
            if not inCombat then
                if btn.EnableMouse then btn:EnableMouse(canClick) end
                if btn.SetMouseClickEnabled then btn:SetMouseClickEnabled(canClick) end
                if btn.Show and not btn:IsShown() then btn:Show() end
            else
                self.queuedMouseUpdate = true
            end

            if hideEmpty then
                if hasAct then
                    if btn.SetAlpha then btn:SetAlpha(1) end
                    if btn.roithiBackdrop and btn.roithiBackdrop.Show then btn.roithiBackdrop:Show() end
                    if btn.HotKey and btn.HotKey.SetAlpha then btn.HotKey:SetAlpha(1) end
                else
                    if btn.SetAlpha then btn:SetAlpha(0) end
                    if btn.roithiBackdrop and btn.roithiBackdrop.Hide then btn.roithiBackdrop:Hide() end
                    if btn.HotKey and btn.HotKey.SetAlpha then btn.HotKey:SetAlpha(0) end
                end
            else
                if btn.SetAlpha then btn:SetAlpha(1) end
                if btn.roithiBackdrop and btn.roithiBackdrop.Show then btn.roithiBackdrop:Show() end
                if btn.HotKey and btn.HotKey.SetAlpha then btn.HotKey:SetAlpha(1) end
            end
        else
            if not inCombat then
                if btn.EnableMouse then btn:EnableMouse(false) end
                if btn.SetMouseClickEnabled then btn:SetMouseClickEnabled(false) end
                if btn.Hide and btn:IsShown() then btn:Hide() end
            else
                self.queuedMouseUpdate = true
            end
            if btn.SetAlpha then btn:SetAlpha(0) end
            if btn.roithiBackdrop and btn.roithiBackdrop.Hide then btn.roithiBackdrop:Hide() end
        end
    end
end

function AB:UpdateAllEmptyButtons()
    for barKey in pairs(BAR_CONFIGS) do
        self:UpdateEmptyButtons(barKey)
    end
end

function AB:OnEditModeEnter()
    self:SetButtonsMouseInteractivity(false)
    if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
        self:UpdateAllEmptyButtons()
        self:LayoutBar("extraAction")
        self:LayoutBar("zoneAction")
    end
end

function AB:OnEditModeExit()
    self:SetButtonsMouseInteractivity(true)
    if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
        self:UpdateAllEmptyButtons()
        if not IsExtraActionActive() then
            if _G.ExtraActionBarFrame and _G.ExtraActionBarFrame.Hide then
                _G.ExtraActionBarFrame:Hide()
            end
            local extraContainer = self.bars and self.bars.extraAction
            if extraContainer and extraContainer.Hide then extraContainer:Hide() end
            local extraButtons = self:GetBarButtons("extraAction")
            for _, btn in ipairs(extraButtons) do
                if btn.Hide then btn:Hide() end
                if btn.SetAlpha then btn:SetAlpha(0) end
            end
        end
        if not IsZoneActionActive() then
            if _G.ZoneAbilityFrame and _G.ZoneAbilityFrame.Hide then
                _G.ZoneAbilityFrame:Hide()
            end
            local zoneContainer = self.bars and self.bars.zoneAction
            if zoneContainer and zoneContainer.Hide then zoneContainer:Hide() end
            local zoneButtons = self:GetBarButtons("zoneAction")
            for _, btn in ipairs(zoneButtons) do
                if btn.Hide then btn:Hide() end
                if btn.SetAlpha then btn:SetAlpha(0) end
            end
        end
        self:LayoutBar("extraAction")
        self:LayoutBar("zoneAction")
    end
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.05, function()
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                self:UpdateAllEmptyButtons()
                if not IsExtraActionActive() then
                    local extraContainer = self.bars and self.bars.extraAction
                    if extraContainer and extraContainer.Hide then extraContainer:Hide() end
                    local extraButtons = self:GetBarButtons("extraAction")
                    for _, btn in ipairs(extraButtons) do
                        if btn.Hide then btn:Hide() end
                        if btn.SetAlpha then btn:SetAlpha(0) end
                    end
                end
                if not IsZoneActionActive() then
                    local zoneContainer = self.bars and self.bars.zoneAction
                    if zoneContainer and zoneContainer.Hide then zoneContainer:Hide() end
                    local zoneButtons = self:GetBarButtons("zoneAction")
                    for _, btn in ipairs(zoneButtons) do
                        if btn.Hide then btn:Hide() end
                        if btn.SetAlpha then btn:SetAlpha(0) end
                    end
                end
                self:LayoutBar("extraAction")
                self:LayoutBar("zoneAction")
            end
        end)
    end
end


function AB:SetupBars()
    for barKey, cfg in pairs(BAR_CONFIGS) do
        if not self.bars[barKey] then
            local f = CreateFrame("Frame", cfg.name, UIParent)
            if f.SetFrameStrata then f:SetFrameStrata("MEDIUM") end
            if f.SetFrameLevel then f:SetFrameLevel(100) end
            if f.SetClampedToScreen then f:SetClampedToScreen(true) end
            if f.SetMovable then f:SetMovable(true) end
            if f.EnableMouse then f:EnableMouse(false) end
            f.barKey = barKey
            if cfg.actionPage and f.SetAttribute then
                f:SetAttribute("actionpage", cfg.actionPage)
            elseif barKey == "bar1" and f.SetAttribute then
                local page = (_G.MainActionBar and _G.MainActionBar.GetAttribute and _G.MainActionBar:GetAttribute("actionpage"))
                    or (_G.C_ActionBar and _G.C_ActionBar.GetActionBarPage and _G.C_ActionBar.GetActionBarPage())
                    or 1
                f:SetAttribute("actionpage", page)
            end
            self.bars[barKey] = f

            local db = (self.db and self.db[barKey]) or (self.defaultSettings and self.defaultSettings[barKey]) or {}
            local pt = db.point or "BOTTOM"
            if f.ClearAllPoints then f:ClearAllPoints() end
            if f.SetPoint then f:SetPoint(pt, UIParent, pt, db.x or 0, db.y or 0) end
        else
            if self.bars[barKey].SetFrameStrata then self.bars[barKey]:SetFrameStrata("MEDIUM") end
            if self.bars[barKey].SetFrameLevel then self.bars[barKey]:SetFrameLevel(100) end
            if cfg.actionPage and self.bars[barKey].SetAttribute then
                self.bars[barKey]:SetAttribute("actionpage", cfg.actionPage)
            elseif barKey == "bar1" and self.bars[barKey].SetAttribute then
                local page = (_G.MainActionBar and _G.MainActionBar.GetAttribute and _G.MainActionBar:GetAttribute("actionpage"))
                    or (_G.C_ActionBar and _G.C_ActionBar.GetActionBarPage and _G.C_ActionBar.GetActionBarPage())
                    or 1
                self.bars[barKey]:SetAttribute("actionpage", page)
            end
            local inCombat = (_G.InCombatLockdown and _G.InCombatLockdown()) or false
            if not inCombat then
                local db = (self.db and self.db[barKey]) or (self.defaultSettings and self.defaultSettings[barKey]) or {}
                local pt = db.point or "BOTTOM"
                if self.bars[barKey].ClearAllPoints then self.bars[barKey]:ClearAllPoints() end
                if self.bars[barKey].SetPoint then self.bars[barKey]:SetPoint(pt, UIParent, pt, db.x or 0, db.y or 0) end
            end
        end

        local db = (self.db and self.db[barKey]) or (self.defaultSettings and self.defaultSettings[barKey]) or {}
        if db.enabled ~= false and self.bars[barKey].Show then
            if barKey == "pet" and not (_G.PetHasActionBar and _G.PetHasActionBar()) then
                if self.bars[barKey].Hide then self.bars[barKey]:Hide() end
            elseif barKey == "stance" and (_G.GetNumShapeshiftForms and _G.GetNumShapeshiftForms() or 0) == 0 then
                if self.bars[barKey].Hide then self.bars[barKey]:Hide() end
            elseif barKey == "extraAction" and not IsExtraActionActive() then
                if self.bars[barKey].Hide then self.bars[barKey]:Hide() end
            elseif barKey == "zoneAction" and not IsZoneActionActive() then
                if self.bars[barKey].Hide then self.bars[barKey]:Hide() end
            else
                self.bars[barKey]:Show()
            end
        end
    end

    if _G.ExtraActionBarFrame and not self.extraActionBarHooked and hooksecurefunc then
        hooksecurefunc(_G.ExtraActionBarFrame, "Show", function()
            if self.layoutInProgress and self.layoutInProgress["extraAction"] then return end
            if not _G.InCombatLockdown or not _G.InCombatLockdown() then
                self:LayoutBar("extraAction")
            end
        end)
        self.extraActionBarHooked = true
    end

    if _G.ZoneAbilityFrame and not self.zoneAbilityHooked and hooksecurefunc then
        hooksecurefunc(_G.ZoneAbilityFrame, "Show", function()
            if self.layoutInProgress and self.layoutInProgress["zoneAction"] then return end
            if not _G.InCombatLockdown or not _G.InCombatLockdown() then
                self:LayoutBar("zoneAction")
            end
        end)
        self.zoneAbilityHooked = true
    end

    -- Hide Blizzard Art Frames in Classic/Forever & prevent mouse blocking
    if _G.MainMenuBarArtFrame then
        if _G.MainMenuBarArtFrame.Hide then _G.MainMenuBarArtFrame:Hide() end
        if _G.MainMenuBarArtFrame.EnableMouse then _G.MainMenuBarArtFrame:EnableMouse(false) end
    end
    if _G.MainMenuBar then
        if _G.MainMenuBar.SetAlpha then _G.MainMenuBar:SetAlpha(0) end
        if _G.MainMenuBar.EnableMouse then _G.MainMenuBar:EnableMouse(false) end
    end

    if not self.managePositionsHooked and hooksecurefunc and _G.UIParent_ManageFramePositions then
        hooksecurefunc("UIParent_ManageFramePositions", function()
            if self.layoutInProgress and self.layoutInProgress["bar1"] then return end
            if self:IsEnabled() and not InCombatLockdown() then
                self:LayoutBar("bar1")
            end
        end)
        self.managePositionsHooked = true
    end

    if _G.MainActionBar and not self.mainActionBarHooked and hooksecurefunc then
        hooksecurefunc(_G.MainActionBar, "SetAttribute", function(_, name, value)
            if name == "actionpage" and self.bars and self.bars.bar1 then
                if not (_G.InCombatLockdown and _G.InCombatLockdown()) and self.bars.bar1.SetAttribute then
                    self.bars.bar1:SetAttribute("actionpage", value)
                end
                if self.UpdateEmptyButtons then
                    self:UpdateEmptyButtons("bar1")
                end
            end
        end)
        self.mainActionBarHooked = true
    end

    self:ProtectOverrideActionBar()

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.editModeRegistered then
        _G.EventRegistry:RegisterCallback("EditMode.Enter", function()
            self:OnEditModeEnter()
            for _, bFrames in pairs(BLIZZARD_BAR_FRAMES) do
                for _, fname in ipairs(bFrames) do
                    local bf = _G[fname]
                    if bf then
                        bf.defaultHideSelection = true
                        if bf.Selection then
                            if not bf.roithiSelectionHooked and hooksecurefunc then
                                bf.roithiSelectionHooked = true
                                hooksecurefunc(bf.Selection, "Show", function(sel)
                                    sel:Hide()
                                end)
                            end
                            bf.Selection:Hide()
                            if bf.Selection.EnableMouse then bf.Selection:EnableMouse(false) end
                        end
                    end
                end
            end
        end, self)
        _G.EventRegistry:RegisterCallback("EditMode.Exit", function()
            self:OnEditModeExit()
        end, self)
        self.editModeRegistered = true
    end

    if _G.QuickKeybindFrame and not self.quickKeybindHooked and hooksecurefunc then
        hooksecurefunc(_G.QuickKeybindFrame, "Show", function()
            self:UpdateAllEmptyButtons()
        end)
        hooksecurefunc(_G.QuickKeybindFrame, "Hide", function()
            self:UpdateAllEmptyButtons()
        end)
        self.quickKeybindHooked = true
    end

    local function HandleButtonUpdate(btn)
        if not btn then return end
        local barKey = btn.roithiBarKey
        if not barKey then
            local bName = btn.GetName and btn:GetName() or ""
            for k, cfg in pairs(BAR_CONFIGS) do
                if cfg.prefix and bName:find("^" .. cfg.prefix) then
                    barKey = k
                    btn.roithiBarKey = k
                    break
                end
            end
        end
        if barKey then
            if self:IsHideEmpty(barKey) then
                self:UpdateEmptyButtons(barKey, { btn })
            end
        end
        self:UpdateButtonRange(btn)
    end

    if not self.overlayHooksRegistered and hooksecurefunc then
        if _G.ActionButton_Update then
            hooksecurefunc("ActionButton_Update", function(btn)
                if (not self.IsEnabled or self:IsEnabled()) and btn then
                    self:UpdateOverlayContainment(btn)
                    HandleButtonUpdate(btn)
                end
            end)
        end
        if _G.ActionButton_UpdateState then
            hooksecurefunc("ActionButton_UpdateState", function(btn)
                if (not self.IsEnabled or self:IsEnabled()) and btn then
                    self:UpdateOverlayContainment(btn)
                    HandleButtonUpdate(btn)
                end
            end)
        end
        if _G.ActionBarActionButtonMixin then
            if _G.ActionBarActionButtonMixin.Update then
                hooksecurefunc(_G.ActionBarActionButtonMixin, "Update", function(btn)
                    if (not self.IsEnabled or self:IsEnabled()) and btn then
                        self:UpdateOverlayContainment(btn)
                        HandleButtonUpdate(btn)
                    end
                end)
            end
            if _G.ActionBarActionButtonMixin.UpdateState then
                hooksecurefunc(_G.ActionBarActionButtonMixin, "UpdateState", function(btn)
                    if (not self.IsEnabled or self:IsEnabled()) and btn then
                        self:UpdateOverlayContainment(btn)
                        HandleButtonUpdate(btn)
                    end
                end)
            end
            if _G.ActionBarActionButtonMixin.UpdateSpellHighlightMark then
                hooksecurefunc(_G.ActionBarActionButtonMixin, "UpdateSpellHighlightMark", function(btn)
                    if (not self.IsEnabled or self:IsEnabled()) and btn then
                        self:UpdateOverlayContainment(btn)
                    end
                end)
            end
        end
        if _G.SharedActionButton_RefreshSpellHighlight then
            hooksecurefunc("SharedActionButton_RefreshSpellHighlight", function(btn)
                if (not self.IsEnabled or self:IsEnabled()) and btn then
                    self:UpdateOverlayContainment(btn)
                end
            end)
        end
        if _G.ActionButtonSpellAlertManager and _G.ActionButtonSpellAlertManager.ShowAlert then
            hooksecurefunc(_G.ActionButtonSpellAlertManager, "ShowAlert", function(_, actionButton)
                if (not self.IsEnabled or self:IsEnabled()) and actionButton and actionButton.SpellActivationAlert then
                    local w, h = actionButton:GetSize()
                    if w and h and w > 0 and h > 0 then
                        actionButton.SpellActivationAlert:SetSize(w * 1.4, h * 1.4)
                        if actionButton.SpellActivationAlert.ClearAllPoints and actionButton.SpellActivationAlert.SetPoint then
                            actionButton.SpellActivationAlert:ClearAllPoints()
                            actionButton.SpellActivationAlert:SetPoint("CENTER", actionButton, "CENTER", 0, 0)
                        end
                    end
                    if actionButton.SpellActivationAlert.SetFrameLevel and actionButton.GetFrameLevel then
                        actionButton.SpellActivationAlert:SetFrameLevel(actionButton:GetFrameLevel() + 5)
                    end
                end
            end)
        end
        if _G.ActionButton_UpdateRangeIndicator and not self.rangeIndicatorHooked then
            hooksecurefunc("ActionButton_UpdateRangeIndicator", function(btn, checksRange, inRange)
                if (not self.IsEnabled or self:IsEnabled()) and btn then
                    local hasTarget = _G.UnitExists and _G.UnitExists("target")
                    local isOutOfRange = false

                    if hasTarget and checksRange and not inRange then
                        if btn.action and _G.C_ActionBar and _G.C_ActionBar.IsActionInRange then
                            local ok, actionInRange = pcall(_G.C_ActionBar.IsActionInRange, btn.action)
                            if ok then
                                if actionInRange == false or actionInRange == 0 then
                                    isOutOfRange = true
                                end
                            else
                                isOutOfRange = true
                            end
                        else
                            isOutOfRange = true
                        end
                    end

                    local icon = btn.icon or _G[btn.GetName and btn:GetName() and (btn:GetName() .. "Icon") or ""]
                    if isOutOfRange then
                        btn.roithiIsOutOfRange = true
                        if self.db and self.db.outOfRangeColoring ~= false then
                            if icon and icon.SetVertexColor then
                                icon:SetVertexColor(0.85, 0.35, 0.35)
                            end
                        end
                        if btn.HotKey and btn.HotKey.SetVertexColor then
                            btn.HotKey:SetVertexColor(0.85, 0.35, 0.35)
                        end
                        if btn.roithiRangeDot then
                            btn.roithiRangeDot:Show()
                        end
                    else
                        if btn.roithiIsOutOfRange then
                            btn.roithiIsOutOfRange = false
                            RestoreButtonUsability(btn, icon)
                        end
                        if btn.HotKey and btn.HotKey.SetVertexColor then
                            btn.HotKey:SetVertexColor(1, 1, 1)
                        end
                        if btn.roithiRangeDot then
                            btn.roithiRangeDot:Hide()
                        end
                    end
                end
            end)
            self.rangeIndicatorHooked = true
        end
        if _G.ActionBarActionButtonMixin and _G.ActionBarActionButtonMixin.UpdateUsable and not self.updateUsableHooked then
            hooksecurefunc(_G.ActionBarActionButtonMixin, "UpdateUsable", function(btn)
                if (not self.IsEnabled or self:IsEnabled()) and btn and self.db and self.db.outOfRangeColoring ~= false and btn.roithiIsOutOfRange then
                    local stillOutOfRange = false
                    if _G.UnitExists and _G.UnitExists("target") then
                        if btn.action and _G.C_ActionBar and _G.C_ActionBar.IsActionInRange then
                            local ok, inRange = pcall(_G.C_ActionBar.IsActionInRange, btn.action)
                            if ok and (inRange == false or inRange == 0) then
                                stillOutOfRange = true
                            end
                        else
                            stillOutOfRange = true
                        end
                    end
                    if not stillOutOfRange then
                        btn.roithiIsOutOfRange = false
                        if btn.HotKey and btn.HotKey.SetVertexColor then
                            btn.HotKey:SetVertexColor(1, 1, 1)
                        end
                        if btn.roithiRangeDot then
                            btn.roithiRangeDot:Hide()
                        end
                        return
                    end
                    local icon = btn.icon or _G[btn.GetName and btn:GetName() and (btn:GetName() .. "Icon") or ""]
                    if icon and icon.SetVertexColor then
                        icon:SetVertexColor(0.85, 0.35, 0.35)
                    end
                end
            end)
            self.updateUsableHooked = true
        end
        if _G.ActionBarActionButtonMixin and _G.ActionBarActionButtonMixin.UpdateAction and not self.updateActionHooked then
            hooksecurefunc(_G.ActionBarActionButtonMixin, "UpdateAction", function(btn)
                if (not self.IsEnabled or self:IsEnabled()) and btn then
                    self:UpdateButtonRange(btn)
                end
            end)
            self.updateActionHooked = true
        end
        self.overlayHooksRegistered = true
    end
end

function AB:UpdateButtonRange(btn)
    if not btn or (self.IsEnabled and not self:IsEnabled()) then return end
    local icon = btn.icon or _G[btn.GetName and btn:GetName() and (btn:GetName() .. "Icon") or ""]
    local hasTarget = _G.UnitExists and _G.UnitExists("target")
    local isOutOfRange = false

    if hasTarget then
        if btn.action and _G.C_ActionBar and _G.C_ActionBar.IsActionInRange then
            local ok, inRange = pcall(_G.C_ActionBar.IsActionInRange, btn.action)
            if ok and (inRange == false or inRange == 0) then
                isOutOfRange = true
            end
        elseif btn.buttonType == "PET" and _G.GetPetActionInfo and btn.GetID and btn:GetID() then
            local _, _, _, _, _, _, _, petChecksRange, petInRange = _G.GetPetActionInfo(btn:GetID())
            if petChecksRange and not petInRange then
                isOutOfRange = true
            end
        end
    end

    if isOutOfRange then
        btn.roithiIsOutOfRange = true
        if self.db and self.db.outOfRangeColoring ~= false then
            if icon and icon.SetVertexColor then
                icon:SetVertexColor(0.85, 0.35, 0.35)
            end
        end
        if btn.HotKey and btn.HotKey.SetVertexColor then
            btn.HotKey:SetVertexColor(0.85, 0.35, 0.35)
        end
        if btn.roithiRangeDot then
            btn.roithiRangeDot:Show()
        end
    else
        if btn.roithiIsOutOfRange then
            btn.roithiIsOutOfRange = false
            RestoreButtonUsability(btn, icon)
        end
        if btn.HotKey and btn.HotKey.SetVertexColor then
            btn.HotKey:SetVertexColor(1, 1, 1)
        end
        if btn.roithiRangeDot then
            btn.roithiRangeDot:Hide()
        end
    end
end

function AB:UpdateAllButtonsRange()
    if not self.bars then return end
    for barKey in pairs(BAR_CONFIGS) do
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            self:UpdateButtonRange(btn)
        end
    end
end

function AB:UpdateRangeColoringState()
    if not self.bars then return end
    local enabled = self.db and self.db.outOfRangeColoring ~= false
    for barKey in pairs(BAR_CONFIGS) do
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            if not enabled then
                if btn.roithiIsOutOfRange then
                    btn.roithiIsOutOfRange = false
                    local icon = btn.icon or _G[btn.GetName and btn:GetName() and (btn:GetName() .. "Icon") or ""]
                    RestoreButtonUsability(btn, icon)
                end
            else
                self:UpdateButtonRange(btn)
            end
        end
    end
end

function AB:UpdateOverlayContainment(button)
    if not button or (self.IsEnabled and not self:IsEnabled()) then return end

    -- 1. Inset and contain Icon
    local icon = button.icon or _G[button.GetName and button:GetName() and (button:GetName() .. "Icon") or ""]
    if icon then
        if icon.ClearAllPoints and icon.SetPoint then
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        end
        if button.IconMask and icon.RemoveMaskTexture then
            icon:RemoveMaskTexture(button.IconMask)
            if button.IconMask.Hide then button.IconMask:Hide() end
        end
    end

    -- 2. Contain textures: Highlight, Pushed, Checked, Cooldown
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight and highlight.ClearAllPoints and highlight.SetPoint then
        highlight:ClearAllPoints()
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        if highlight.SetColorTexture then
            highlight:SetColorTexture(1, 1, 1, 0.2)
        end
    end

    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed and pushed.ClearAllPoints and pushed.SetPoint then
        pushed:ClearAllPoints()
        pushed:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        pushed:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        if pushed.SetColorTexture then
            pushed:SetColorTexture(1, 1, 1, 0.25)
        end
    end

    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked and checked.ClearAllPoints and checked.SetPoint then
        checked:ClearAllPoints()
        checked:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        checked:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        if checked.SetColorTexture then
            checked:SetColorTexture(1, 1, 1, 0.25)
        end
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then
        if normal.ClearAllPoints and normal.SetPoint then
            normal:ClearAllPoints()
            normal:SetAllPoints(button)
        end
        if normal.SetAlpha then
            normal:SetAlpha(0)
        end
    end

    local cd = button.cooldown or _G[button.GetName and button:GetName() and (button:GetName() .. "Cooldown") or ""]
    if cd and cd.ClearAllPoints and cd.SetPoint then
        cd:ClearAllPoints()
        cd:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        cd:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    end

    -- 3. Constrain overlays (SpellHighlight, Flash, NewAction, AutoCast, SpellFX)
    local subOverlays = {
        button.SpellHighlightTexture,
        button.Flash,
        button.NewActionTexture,
        button.AutoCastOverlay,
        button.SpellCastAnimFrame,
        button.TargetReticleAnimFrame,
        button.InterruptDisplay,
        button.CooldownFlash,
    }
    for _, overlay in ipairs(subOverlays) do
        if overlay and overlay.ClearAllPoints and overlay.SetPoint then
            overlay:ClearAllPoints()
            overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        end
        if overlay then
            if overlay.EnableMouse then overlay:EnableMouse(false) end
            if overlay.SetMouseClickEnabled then overlay:SetMouseClickEnabled(false) end
            if overlay.SetMouseMotionEnabled then overlay:SetMouseMotionEnabled(false) end
        end
    end

    if button.SlotArt and button.SlotArt.SetAlpha then button.SlotArt:SetAlpha(0) end
    if button.SlotBackground and button.SlotBackground.SetAlpha then button.SlotBackground:SetAlpha(0) end

    -- 4. Border / Active Aura / Equipped Action Containment
    local border = button.Border or _G[button.GetName and button:GetName() and (button:GetName() .. "Border") or ""]
    if border then
        if border.ClearAllPoints and border.SetPoint then
            border:ClearAllPoints()
            border:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        end
        -- Always suppress Blizzard's bulky rounded 46x45 atlas
        if border.SetAlpha then
            border:SetAlpha(0)
        end
    end

    -- 5. Dynamic 1px Border Color for Active Auras / Equipped Actions / Stances
    if button.roithiBackdrop and button.roithiBackdrop.SetBackdropBorderColor then
        local isEquipped = false
        local action = button.action or (button.GetPagedID and button:GetPagedID()) or (button.CalculateAction and button:CalculateAction())
        if action then
            if _G.C_ActionBar and _G.C_ActionBar.IsEquippedAction then
                isEquipped = _G.C_ActionBar.IsEquippedAction(action)
            elseif _G.IsEquippedAction then
                isEquipped = _G.IsEquippedAction(action)
            end
        elseif border and border.IsShown and border:IsShown() then
            isEquipped = true
        end

        local rawChecked = button.GetChecked and button:GetChecked()
        local isChecked = (rawChecked == true or rawChecked == 1)

        if isEquipped or isChecked then
            -- Crisp 1px green border for equipped items and active stances/auras, perfectly fitting the frame
            button.roithiBackdrop:SetBackdropBorderColor(0.2, 0.9, 0.2, 1.0)
        else
            local bc = self.db and self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
            button.roithiBackdrop:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        end
    end
end

function AB:StyleButton(button, explicitBarKey)
    if not button then return end

    -- Suppress Blizzard bulky style/placeholder artwork on Extra Action & Zone Ability buttons
    if button.style and not button.roithiStyleHooked then
        button.style:SetAlpha(0)
        if button.style.Hide then button.style:Hide() end
        if hooksecurefunc then
            hooksecurefunc(button.style, "Show", function(s)
                s:SetAlpha(0)
                if s.Hide then s:Hide() end
            end)
        end
        button.roithiStyleHooked = true
    end
    if _G.ZoneAbilityFrame and _G.ZoneAbilityFrame.Style and not _G.ZoneAbilityFrame.roithiStyleHooked then
        _G.ZoneAbilityFrame.Style:SetAlpha(0)
        if _G.ZoneAbilityFrame.Style.Hide then _G.ZoneAbilityFrame.Style:Hide() end
        if hooksecurefunc then
            hooksecurefunc(_G.ZoneAbilityFrame.Style, "Show", function(s)
                s:SetAlpha(0)
                if s.Hide then s:Hide() end
            end)
        end
        _G.ZoneAbilityFrame.roithiStyleHooked = true
    end

    -- 1. Icon TexCoords (Zoomed to create modern square look)
    local zoom = self.db.iconZoom or 0.07
    local zoomMax = tonumber(string.format("%.4f", 1 - zoom)) or (1 - zoom)
    local icon = button.icon or _G[button.GetName and button:GetName() and (button:GetName() .. "Icon") or ""]
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(zoom, zoomMax, zoom, zoomMax)
    end

    -- 2. 1px Custom Backdrop
    if not button.roithiBackdrop then
        local bg = CreateFrame("Frame", nil, button, "BackdropTemplate")
        if bg.SetAllPoints then
            bg:SetAllPoints(button)
        end
        if bg.SetFrameLevel and button.GetFrameLevel then
            bg:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
        end
        if bg.EnableMouse then bg:EnableMouse(false) end
        if bg.SetMouseClickEnabled then bg:SetMouseClickEnabled(false) end
        if bg.SetMouseMotionEnabled then bg:SetMouseMotionEnabled(false) end
        if bg.SetBackdrop then
            bg:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            bg:SetBackdropColor(0, 0, 0, 0)
            local bc = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
            bg:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        end
        button.roithiBackdrop = bg
        if button.roithiBackdrop.EnableMouse then button.roithiBackdrop:EnableMouse(false) end
        if button.roithiBackdrop.SetMouseClickEnabled then button.roithiBackdrop:SetMouseClickEnabled(false) end
        if button.roithiBackdrop.SetMouseMotionEnabled then button.roithiBackdrop:SetMouseMotionEnabled(false) end
        local bc = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
        if button.roithiBackdrop.SetBackdropBorderColor then
            button.roithiBackdrop:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        end
    end

    -- Secure non-interactive TextOverlayContainer (elevated frame level to render above buttons and borders)
    local toc = button.TextOverlayContainer
    if toc then
        if toc.EnableMouse then toc:EnableMouse(false) end
        if toc.SetMouseClickEnabled then toc:SetMouseClickEnabled(false) end
        if toc.SetMouseMotionEnabled then toc:SetMouseMotionEnabled(false) end
        if toc.SetFrameStrata and button.GetFrameStrata then
            toc:SetFrameStrata(button:GetFrameStrata())
        end
        if toc.SetFrameLevel and button.GetFrameLevel then
            toc:SetFrameLevel((button:GetFrameLevel() or 10) + 25)
        end
    end

    -- 3. Securely hook Border Show/Hide and Checked states
    local border = button.Border or _G[button.GetName and button:GetName() and (button:GetName() .. "Border") or ""]
    if border and not border.roithiBorderHooked and hooksecurefunc then
        hooksecurefunc(border, "Show", function(b)
            if b.SetAlpha then b:SetAlpha(0) end
            AB:UpdateOverlayContainment(button)
        end)
        hooksecurefunc(border, "Hide", function()
            AB:UpdateOverlayContainment(button)
        end)
        border.roithiBorderHooked = true
    end

    if button.SetChecked and not button.roithiCheckedHooked and hooksecurefunc then
        hooksecurefunc(button, "SetChecked", function(btn)
            AB:UpdateOverlayContainment(btn)
        end)
        button.roithiCheckedHooked = true
    end

    -- 4. Overlay & Aura Sizing Containment
    self:UpdateOverlayContainment(button)

    -- 5. Keybind Hotkey Styling
    local barKey = explicitBarKey or button.barKey
    local barDb = (barKey and self.db and self.db[barKey]) or {}

    -- 5. HotKey Styling
    local hotkey = button.HotKey or _G[button.GetName and button:GetName() and (button:GetName() .. "HotKey") or ""]
    if hotkey then
        if hotkey.EnableMouse then hotkey:EnableMouse(false) end
        if hotkey.SetMouseClickEnabled then hotkey:SetMouseClickEnabled(false) end
        if hotkey.SetMouseMotionEnabled then hotkey:SetMouseMotionEnabled(false) end
        local showHotkeys = self.db.showHotkeys ~= false
        if barDb.showHotkeys ~= nil then
            showHotkeys = barDb.showHotkeys
        end
        local currentText = hotkey.GetText and hotkey:GetText()
        local isRange = IsRangeIndicator(currentText)
        if not isRange and hotkey.SetShown then
            hotkey:SetShown(showHotkeys)
        end
        if hotkey.ClearAllPoints and hotkey.SetPoint then
            local pos = barDb.hotkeyPosition or "TOPRIGHT"
            local ox = barDb.hotkeyOffsetX or 0
            local oy = barDb.hotkeyOffsetY or -2
            hotkey:ClearAllPoints()
            hotkey:SetPoint(pos, button, pos, ox, oy)
        end
        local hotkeyFont = (barDb and barDb.font) or self.db.font or "Roithi Thick"
        local hotkeyFontSize = (barDb and barDb.fontSize) or self.db.fontSize or 11
        local hotkeyFontOutline = (barDb and barDb.fontOutline) or self.db.fontOutline or "OUTLINE"
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(hotkey, hotkeyFont, hotkeyFontSize, hotkeyFontOutline)
        end
        if hotkey.SetDrawLayer then hotkey:SetDrawLayer("OVERLAY", 7) end
        if hotkey.SetShadowOffset then
            if hotkeyFontOutline ~= "NONE" and hotkeyFontOutline ~= "" then
                hotkey:SetShadowOffset(0, 0)
            else
                hotkey:SetShadowOffset(1, -1)
            end
        end
        if not hotkey.roithiHooked and hooksecurefunc then
            hooksecurefunc(hotkey, "SetText", function(s, txt)
                if s.roithiFormatting then return end
                if IsRangeIndicator(txt) then
                    if not button.roithiRangeDot then
                        local dot = button:CreateTexture(nil, "OVERLAY")
                        dot:SetSize(8, 8)
                        local pos = barDb.hotkeyPosition or "TOPRIGHT"
                        local ox = barDb.hotkeyOffsetX or -2
                        local oy = barDb.hotkeyOffsetY or -2
                        dot:SetPoint(pos, button, pos, ox, oy)
                        dot:SetTexture("Interface\\Common\\Indicator-Red")
                        button.roithiRangeDot = dot
                    end
                    if button.roithiRangeDot then button.roithiRangeDot:Show() end
                    s.roithiFormatting = true
                    s:SetText("")
                    s.roithiFormatting = false
                    return
                else
                    if button.roithiRangeDot then button.roithiRangeDot:Hide() end
                end
                local formatted = FormatHotkey(txt)
                if formatted ~= txt then
                    s.roithiFormatting = true
                    s:SetText(formatted)
                    s.roithiFormatting = false
                end
                -- Re-lock colour to white; Blizzard resets it via SetFontObject
                if s.SetTextColor then s:SetTextColor(1, 1, 1, 1) end
            end)
            -- Hook SetFontObject: WoW's ActionButton_UpdateHotkeys calls this with
            -- NumberFontNormalSmallGray, which bakes in a grey colour. Lock it back.
            if hotkey.SetFontObject then
                hooksecurefunc(hotkey, "SetFontObject", function(s)
                    if s.SetTextColor then s:SetTextColor(1, 1, 1, 1) end
                end)
            end
            hotkey.roithiHooked = true
        end
        currentText = hotkey.GetText and hotkey:GetText()
        if currentText then
            local formatted = FormatHotkey(currentText)
            if formatted ~= currentText then
                hotkey.roithiFormatting = true
                hotkey:SetText(formatted)
                hotkey.roithiFormatting = false
            end
        end
    end

    -- 6. Macro Text Styling
    local name = button.Name or _G[button.GetName and button:GetName() and (button:GetName() .. "Name") or ""]
    if name then
        if name.EnableMouse then name:EnableMouse(false) end
        if name.SetMouseClickEnabled then name:SetMouseClickEnabled(false) end
        if name.SetMouseMotionEnabled then name:SetMouseMotionEnabled(false) end
        local showMacro = self.db.showMacroText ~= false
        if barDb.showMacroText ~= nil then
            showMacro = barDb.showMacroText
        end
        if name.SetShown then
            name:SetShown(showMacro)
        end
        if name.ClearAllPoints and name.SetPoint then
            local pos = barDb.macroPosition or "BOTTOM"
            local ox = barDb.macroOffsetX or 0
            local oy = barDb.macroOffsetY or 2
            name:ClearAllPoints()
            name:SetPoint(pos, button, pos, ox, oy)
        end
        local nameFont = (barDb and barDb.font) or self.db.font or "Roithi Thick"
        local nameFontSize = math.max(8, ((barDb and barDb.fontSize) or self.db.fontSize or 11) - 2)
        local nameFontOutline = (barDb and barDb.fontOutline) or self.db.fontOutline or "OUTLINE"
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(name, nameFont, nameFontSize, nameFontOutline)
        end
        if name.SetDrawLayer then name:SetDrawLayer("OVERLAY", 7) end
        if name.SetShadowOffset then
            if nameFontOutline ~= "NONE" and nameFontOutline ~= "" then
                name:SetShadowOffset(0, 0)
            else
                name:SetShadowOffset(1, -1)
            end
        end
        -- Lock colour to white; Blizzard may reset via SetFontObject
        if name.SetTextColor then name:SetTextColor(1, 1, 1, 1) end
        if name.SetFontObject and not name.roithiFontObjectHooked and hooksecurefunc then
            hooksecurefunc(name, "SetFontObject", function(s)
                if s.SetTextColor then s:SetTextColor(1, 1, 1, 1) end
            end)
            name.roithiFontObjectHooked = true
        end
    end

    -- 7. Item / Charge Count Styling (elevated to HIGH strata above buttons and borders)
    local count = button.Count or _G[button.GetName and button:GetName() and (button:GetName() .. "Count") or ""]
    if count then
        if count.EnableMouse then count:EnableMouse(false) end
        if count.SetMouseClickEnabled then count:SetMouseClickEnabled(false) end
        if count.SetMouseMotionEnabled then count:SetMouseMotionEnabled(false) end
        local countParent = count.GetParent and count:GetParent()
        if countParent and countParent ~= button and countParent.SetFrameStrata and button.GetFrameStrata then
            countParent:SetFrameStrata(button:GetFrameStrata())
            if countParent.SetFrameLevel and button.GetFrameLevel then
                countParent:SetFrameLevel((button:GetFrameLevel() or 10) + 25)
            end
        elseif countParent and countParent == button then
            local countOverlay = button.roithiCountOverlay
            if not countOverlay and CreateFrame then
                countOverlay = CreateFrame("Frame", nil, button)
                countOverlay:SetAllPoints(button)
                if countOverlay.SetFrameStrata and button.GetFrameStrata then
                    countOverlay:SetFrameStrata(button:GetFrameStrata())
                end
                if button.GetFrameLevel then
                    countOverlay:SetFrameLevel((button:GetFrameLevel() or 10) + 25)
                end
                if countOverlay.EnableMouse then countOverlay:EnableMouse(false) end
                button.roithiCountOverlay = countOverlay
            end
            if countOverlay and count.SetParent then
                pcall(count.SetParent, count, countOverlay)
            end
        end
        if count.SetDrawLayer then
            count:SetDrawLayer("OVERLAY", 7)
        end
        local showCount = self.db.showCount ~= false
        if barDb.showCount ~= nil then
            showCount = barDb.showCount
        end
        if count.SetShown then
            count:SetShown(showCount)
        end
        if count.ClearAllPoints and count.SetPoint then
            local pos = barDb.countPosition or "BOTTOMRIGHT"
            local ox = barDb.countOffsetX or -2
            local oy = barDb.countOffsetY or 2
            count:ClearAllPoints()
            count:SetPoint(pos, button, pos, ox, oy)
        end
        local countFont = (barDb and barDb.font) or self.db.font or "Roithi Thick"
        local countFontSize = math.max(8, ((barDb and barDb.fontSize) or self.db.fontSize or 11) - 1)
        local countFontOutline = (barDb and barDb.fontOutline) or self.db.fontOutline or "OUTLINE"
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(count, countFont, countFontSize, countFontOutline)
        end
        if count.SetShadowOffset then
            if countFontOutline ~= "NONE" and countFontOutline ~= "" then
                count:SetShadowOffset(0, 0)
            else
                count:SetShadowOffset(1, -1)
            end
        end
    end

    -- 8. Hook Mouseover
    if not button.roithiMouseoverHooked and button.HookScript then
        button:HookScript("OnEnter", function()
            if button.barKey then
                self:OnBarEnter(button.barKey)
            end
        end)
        button:HookScript("OnLeave", function()
            if button.barKey then
                self:OnBarLeave(button.barKey)
            end
        end)
        button.roithiMouseoverHooked = true
    end

    local bKey = explicitBarKey or button.roithiBarKey or button.barKey
    if not bKey then
        local bName = button.GetName and button:GetName() or ""
        for k, cfg in pairs(BAR_CONFIGS) do
            if cfg.prefix and bName:find("^" .. cfg.prefix) then
                bKey = k
                button.roithiBarKey = k
                button.barKey = k
                break
            end
        end
    end
    local isQuickKeybind = (_G.QuickKeybindFrame and _G.QuickKeybindFrame.IsShown and _G.QuickKeybindFrame:IsShown()) or false
    local isEditMode = false
    if LEM and LEM.IsInEditMode and LEM:IsInEditMode() then
        isEditMode = true
    elseif _G.EditModeManagerFrame and _G.EditModeManagerFrame.IsShown and _G.EditModeManagerFrame:IsShown() then
        isEditMode = true
    end
    local hideEmpty = self:IsHideEmpty(bKey) and not self.showingGrid and not isQuickKeybind and not isEditMode
    local hasAct = ButtonHasAction(button)
    if hideEmpty and not hasAct then
        if button.SetAlpha then button:SetAlpha(0) end
        if button.roithiBackdrop and button.roithiBackdrop.Hide then button.roithiBackdrop:Hide() end
        if button.HotKey and button.HotKey.SetAlpha then button.HotKey:SetAlpha(0) end
    else
        if button.roithiBackdrop and button.roithiBackdrop.Show then button.roithiBackdrop:Show() end
        if button.HotKey and button.HotKey.SetAlpha then button.HotKey:SetAlpha(1) end
    end
end

function AB:UnstyleButton(button)
    if not button then return end

    local icon = button.icon or _G[button.GetName and button:GetName() and (button:GetName() .. "Icon") or ""]
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0, 1, 0, 1)
    end

    local border = button.Border or _G[button.GetName and button:GetName() and (button:GetName() .. "Border") or ""]
    if border and border.SetAlpha then
        border:SetAlpha(1)
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal and normal.SetAlpha then
        normal:SetAlpha(1)
    end

    if button.roithiBackdrop and button.roithiBackdrop.Hide then
        button.roithiBackdrop:Hide()
    end
end

function AB:StyleAllBars()
    for barKey in pairs(BAR_CONFIGS) do
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            self:StyleButton(btn)
        end
    end
end

function AB:UnstyleAllBars()
    for barKey in pairs(BAR_CONFIGS) do
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            self:UnstyleButton(btn)
        end
    end
end

function AB:LayoutBar(barKey)
    if not barKey then return end
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedLayout = true
        return
    end

    self:SuppressBlizzardBarSelections()

    if not self.layoutInProgress then self.layoutInProgress = {} end
    if self.layoutInProgress[barKey] then return end
    self.layoutInProgress[barKey] = true

    local ok, err = pcall(self.LayoutBarInternal, self, barKey)
    self.layoutInProgress[barKey] = nil
    if not ok and err then
        if _G.geterrorhandler then
            _G.geterrorhandler()(err)
        end
    end
end

function AB:LayoutBarInternal(barKey)
    local container = self.bars[barKey]
    if not container then return end

    local db = (self.db and self.db[barKey]) or (self.defaultSettings and self.defaultSettings[barKey])
    if self.db and not self.db[barKey] and self.defaultSettings and self.defaultSettings[barKey] then
        local copy = _G.CopyTable or function(t)
            local d = {}
            for k, v in pairs(t) do d[k] = type(v) == "table" and (_G.CopyTable and _G.CopyTable(v) or v) or v end
            return d
        end
        self.db[barKey] = copy(self.defaultSettings[barKey])
        db = self.db[barKey]
    end

    local buttons = self:GetBarButtons(barKey)
    local blizzFrames = BLIZZARD_BAR_FRAMES[barKey]

    -- Suppress Blizzard native frames for this bar without reparenting or mutating internal manager properties
    if blizzFrames then
        for _, fname in ipairs(blizzFrames) do
            local bf = _G[fname]
            if bf then
                if bf.SetAlpha then bf:SetAlpha(0) end
                if bf.EnableMouse then bf:EnableMouse(false) end
                if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                    if bf.Hide and bf:IsShown() then bf:Hide() end
                    if bf.Selection then
                        if not bf.roithiSelectionHooked and hooksecurefunc then
                            bf.roithiSelectionHooked = true
                            hooksecurefunc(bf.Selection, "Show", function(sel)
                                sel:Hide()
                            end)
                        end
                        if bf.Selection.Hide and bf.Selection:IsShown() then bf.Selection:Hide() end
                        if bf.Selection.EnableMouse then bf.Selection:EnableMouse(false) end
                    end
                end
            end
        end
    end

    if not db or db.enabled == false then
        if container.Hide and container:IsShown() then container:Hide() end
        for _, btn in ipairs(buttons) do
            if btn.Hide and btn:IsShown() then btn:Hide() end
            if btn.SetAlpha then btn:SetAlpha(0) end
        end
        if LEM and LEM.frameSelections and LEM.frameSelections[container] then
            local sel = LEM.frameSelections[container]
            if sel and sel.Hide and sel:IsShown() then sel:Hide() end
        end
        return
    end

    local isEditMode = false
    if LEM and LEM.IsInEditMode and LEM:IsInEditMode() then
        isEditMode = true
    elseif _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then
        isEditMode = true
    end

    -- Class & Capability check:
    -- 1. Pet Bar: Hide if player class does not have an active pet action bar and not in Edit Mode
    if barKey == "pet" and not isEditMode then
        local hasPet = false
        if _G.PetHasActionBar and _G.PetHasActionBar() then
            hasPet = true
        elseif _G.UnitExists and _G.UnitExists("pet") and _G.HasPetUI and _G.HasPetUI() then
            hasPet = true
        end
        if not hasPet then
            if container.Hide then container:Hide() end
            for _, btn in ipairs(buttons) do
                if btn.Hide then btn:Hide() end
            end
            return
        end
    end

    -- 2. Stance Bar: Hide if player class does not have shapeshift/stance forms and not in Edit Mode
    if barKey == "stance" and not isEditMode then
        local numForms = _G.GetNumShapeshiftForms and _G.GetNumShapeshiftForms() or 0
        if numForms == 0 then
            if container.Hide then container:Hide() end
            for _, btn in ipairs(buttons) do
                if btn.Hide then btn:Hide() end
            end
            return
        end
    end

    -- 3. Extra Action Bar: Hide if not active and not in Edit Mode
    if barKey == "extraAction" and not isEditMode then
        local active = IsExtraActionActive()
        if _G.ExtraActionBarFrame and _G.ExtraActionBarFrame.EnableMouse then
            _G.ExtraActionBarFrame:EnableMouse(active)
        end
        if not active then
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                if _G.ExtraActionBarFrame and _G.ExtraActionBarFrame.Hide then
                    _G.ExtraActionBarFrame:Hide()
                end
            end
            if container.Hide and container:IsShown() then container:Hide() end
            for _, btn in ipairs(buttons) do
                if btn.Hide and btn:IsShown() then btn:Hide() end
                if btn.SetAlpha then btn:SetAlpha(0) end
            end
            return
        end
    end

    -- 4. Zone Action Bar: Hide if not active and not in Edit Mode
    if barKey == "zoneAction" and not isEditMode then
        if not IsZoneActionActive() then
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                if _G.ZoneAbilityFrame and _G.ZoneAbilityFrame.Hide then
                    _G.ZoneAbilityFrame:Hide()
                end
            end
            if container.Hide and container:IsShown() then container:Hide() end
            for _, btn in ipairs(buttons) do
                if btn.Hide and btn:IsShown() then btn:Hide() end
                if btn.SetAlpha then btn:SetAlpha(0) end
            end
            return
        end
    end

    if container.Show then container:Show() end

    local btnSize = db.buttonSize or 36
    local spacing = db.spacing or 4
    local isVertical = (db.orientation == "VERTICAL")
    local maxBtns = db.maxButtons or (BAR_CONFIGS[barKey] and BAR_CONFIGS[barKey].count) or #buttons
    if maxBtns < 1 then maxBtns = 1 end
    local displayCount = math.min(#buttons, maxBtns)
    if barKey == "stance" then
        local numForms = _G.GetNumShapeshiftForms and _G.GetNumShapeshiftForms() or 0
        if numForms > 0 then
            displayCount = math.min(displayCount, numForms)
        end
    end

    local perLine
    if db.numRows then
        perLine = math.ceil(displayCount / db.numRows)
    else
        perLine = db.buttonsPerRow or #buttons
    end
    if perLine < 1 then perLine = 1 end

    local layoutCount = math.max(1, displayCount)
    local totalW, totalH
    if ns.Utils and ns.Utils.GetGridDimensions then
        local _, _, gridW, gridH = ns.Utils.GetGridDimensions(layoutCount, perLine, btnSize, btnSize, spacing, spacing, isVertical)
        totalW, totalH = gridW, gridH
    else
        local numCols = isVertical and math.ceil(layoutCount / perLine) or math.min(layoutCount, perLine)
        local numRows = isVertical and math.min(layoutCount, perLine) or math.ceil(layoutCount / perLine)
        totalW = (numCols * btnSize) + math.max(0, (numCols - 1) * spacing)
        totalH = (numRows * btnSize) + math.max(0, (numRows - 1) * spacing)
    end
    if container.SetSize then container:SetSize(totalW, totalH) end
    local inCombat = (_G.InCombatLockdown and _G.InCombatLockdown()) or false
    if not inCombat and container.ClearAllPoints and container.SetPoint then
        local pt = db.point or "BOTTOM"
        container:ClearAllPoints()
        container:SetPoint(pt, UIParent, pt, db.x or 0, db.y or 0)
    end

    if #buttons == 0 then return end

    for i, btn in ipairs(buttons) do
        if i <= displayCount then
            btn.barKey = barKey
            if not btn.originalParent and btn.GetParent then
                btn.originalParent = btn:GetParent()
            end
            if not btn.roithiOriginalPoints and btn.GetNumPoints then
                btn.roithiOriginalPoints = {}
                for p = 1, btn:GetNumPoints() do
                    local pt, relTo, relPt, x, y = btn:GetPoint(p)
                    table.insert(btn.roithiOriginalPoints, { point = pt, relTo = relTo, relPt = relPt, x = x, y = y })
                end
                if btn.GetSize then
                    local w, h = btn:GetSize()
                    btn.roithiOriginalWidth = w
                    btn.roithiOriginalHeight = h
                end
            end
            if btn.SetParent then
                btn:SetParent(container)
            end
            local barCfg = BAR_CONFIGS[barKey]
            if barCfg and barCfg.actionPage and btn.SetAttribute then
                btn:SetAttribute("actionpage", barCfg.actionPage)
            elseif barKey == "bar1" and btn.SetAttribute then
                btn:SetAttribute("actionpage", nil)
            end
            if btn.SetFrameStrata then
                btn:SetFrameStrata("MEDIUM")
            end
            if container.GetFrameLevel and btn.SetFrameLevel then
                btn:SetFrameLevel(container:GetFrameLevel() + 10)
            end
            if btn.SetAlpha then btn:SetAlpha(1) end
            if btn.Show then btn:Show() end
            if btn.ClearAllPoints then btn:ClearAllPoints() end

            local x, y
            if ns.Utils and ns.Utils.GetGridItemOffset then
                x, y = ns.Utils.GetGridItemOffset("LEFT_TO_RIGHT", i, displayCount, perLine, btnSize, btnSize, spacing, spacing, isVertical)
            else
                local col = isVertical and math.floor((i - 1) / perLine) or ((i - 1) % perLine)
                local row = isVertical and ((i - 1) % perLine) or math.floor((i - 1) / perLine)
                x = col * (btnSize + spacing)
                y = -row * (btnSize + spacing)
            end

            if btn.SetSize then btn:SetSize(btnSize, btnSize) end
            if btn.SetPoint then btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y) end
        else
            if btn.Hide then btn:Hide() end
            if btn.SetAlpha then btn:SetAlpha(0) end
            if btn.roithiBackdrop and btn.roithiBackdrop.Hide then
                btn.roithiBackdrop:Hide()
            end
        end
    end

    self:UpdateBarMouseover(barKey)
    self:UpdateEmptyButtons(barKey)
end

function AB:LayoutAllBars()
    for barKey in pairs(BAR_CONFIGS) do
        self:LayoutBar(barKey)
    end
end

function AB:RestoreBlizzardBars()
    for barKey, container in pairs(self.bars) do
        if container.Hide then container:Hide() end
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            if btn.originalParent and btn.SetParent then
                btn:SetParent(btn.originalParent)
            end
            if btn.roithiOriginalPoints and #btn.roithiOriginalPoints > 0 then
                if btn.ClearAllPoints then btn:ClearAllPoints() end
                for _, pt in ipairs(btn.roithiOriginalPoints) do
                    if btn.SetPoint then
                        btn:SetPoint(pt.point, pt.relTo, pt.relPt, pt.x, pt.y)
                    end
                end
            end
            if btn.roithiOriginalWidth and btn.roithiOriginalHeight and btn.SetSize then
                btn:SetSize(btn.roithiOriginalWidth, btn.roithiOriginalHeight)
            end
            if btn.SetAlpha then btn:SetAlpha(1) end
            if btn.Show then btn:Show() end
        end

        local blizzFrames = BLIZZARD_BAR_FRAMES[barKey]
        if blizzFrames then
            for _, fname in ipairs(blizzFrames) do
                local bf = _G[fname]
                if bf then
                    if bf.SetAlpha then bf:SetAlpha(1) end
                    if bf.EnableMouse then bf:EnableMouse(true) end
                    if bf.Show then bf:Show() end
                    if bf.Selection and bf.Selection.Show then bf.Selection:Show() end
                    if bf.UpdateGridLayout then
                        pcall(bf.UpdateGridLayout, bf)
                    end
                end
            end
        end
    end

    if _G.EditModeManagerFrame and _G.EditModeManagerFrame.UpdateActionBarLayout then
        for _, blizzFrames in pairs(BLIZZARD_BAR_FRAMES) do
            for _, fname in ipairs(blizzFrames) do
                local bf = _G[fname]
                if bf then
                    pcall(_G.EditModeManagerFrame.UpdateActionBarLayout, _G.EditModeManagerFrame, bf)
                end
            end
        end
    end

    if _G.MultiActionBar_Update then
        pcall(_G.MultiActionBar_Update)
    end
    if _G.UIParent_ManageFramePositions then
        pcall(_G.UIParent_ManageFramePositions)
    end

    if _G.MainMenuBarArtFrame and _G.MainMenuBarArtFrame.Show then
        _G.MainMenuBarArtFrame:Show()
    end
end

AB.UpdateBarLayout = AB.LayoutBar

function AB:SuppressBlizzardBarSelections()
    if self.blizzardSelectionsSuppressed then return end
    self.blizzardSelectionsSuppressed = true
    for _, bFrames in pairs(BLIZZARD_BAR_FRAMES) do
        for _, fname in ipairs(bFrames) do
            local bf = _G[fname]
            if bf then
                bf.defaultHideSelection = true
                if bf.Selection then
                    if not bf.roithiSelectionHooked and hooksecurefunc then
                        bf.roithiSelectionHooked = true
                        hooksecurefunc(bf.Selection, "Show", function(sel)
                            sel:Hide()
                        end)
                    end
                    bf.Selection:Hide()
                    if bf.Selection.EnableMouse then bf.Selection:EnableMouse(false) end
                end
            end
        end
    end
end

local isResettingActionBarPage = false
function AB:DisableActionPageSwitching()
    local db = self.db and (self.db.disableBarPaging ~= nil and self.db.disableBarPaging or (self.db.general and self.db.general.disableBarPaging))
    if _G.MainMenuBar and _G.MainMenuBar.EnableMouseWheel then
        _G.MainMenuBar:EnableMouseWheel(db == false)
    end
    if not self.pageSwitchHooked and hooksecurefunc and _G.ChangeActionBarPage then
        hooksecurefunc("ChangeActionBarPage", function(page)
            if isResettingActionBarPage then return end
            local pagingDisabled = self.db and (self.db.disableBarPaging ~= nil and self.db.disableBarPaging or (self.db.general and self.db.general.disableBarPaging))
            if pagingDisabled ~= false and page ~= 1 then
                if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                    local hasSpecialBar = _G.C_ActionBar and (
                        (_G.C_ActionBar.HasOverrideActionBar and _G.C_ActionBar.HasOverrideActionBar()) or
                        (_G.C_ActionBar.HasVehicleActionBar and _G.C_ActionBar.HasVehicleActionBar()) or
                        (_G.C_ActionBar.HasBonusActionBar and _G.C_ActionBar.HasBonusActionBar()) or
                        (_G.C_ActionBar.HasTempShapeshiftActionBar and _G.C_ActionBar.HasTempShapeshiftActionBar())
                    )
                    if not hasSpecialBar then
                        isResettingActionBarPage = true
                        _G.ChangeActionBarPage(1)
                        isResettingActionBarPage = false
                    end
                end
            end
        end)
        self.pageSwitchHooked = true
    end
end

function AB:ProtectOverrideActionBar()
    if _G.OverrideActionBar and _G.OverrideActionBar.slideOut and not self.overrideSlideOutHooked and hooksecurefunc then
        hooksecurefunc(_G.OverrideActionBar.slideOut, "Play", function()
            if _G.InCombatLockdown and _G.InCombatLockdown() then
                if _G.OverrideActionBar then
                    _G.OverrideActionBar.hideOnFinish = false
                end
            end
        end)
        self.overrideSlideOutHooked = true
    end
end

function AB:SyncBar1Page()
    local bar1 = self.bars and self.bars.bar1
    local page
    if _G.MainActionBar and _G.MainActionBar.GetAttribute then
        page = _G.MainActionBar:GetAttribute("actionpage")
    end
    if not page and _G.C_ActionBar then
        if _G.C_ActionBar.HasBonusActionBar and _G.C_ActionBar.HasBonusActionBar() and _G.C_ActionBar.GetActionBarPage and _G.C_ActionBar.GetActionBarPage() == 1 then
            page = _G.C_ActionBar.GetBonusBarIndex and _G.C_ActionBar.GetBonusBarIndex()
        elseif _G.C_ActionBar.HasOverrideActionBar and _G.C_ActionBar.HasOverrideActionBar() then
            page = _G.C_ActionBar.GetOverrideBarIndex and _G.C_ActionBar.GetOverrideBarIndex()
        elseif _G.C_ActionBar.HasVehicleActionBar and _G.C_ActionBar.HasVehicleActionBar() then
            page = _G.C_ActionBar.GetVehicleBarIndex and _G.C_ActionBar.GetVehicleBarIndex()
        else
            page = _G.C_ActionBar.GetActionBarPage and _G.C_ActionBar.GetActionBarPage()
        end
    end
    page = page or 1
    if bar1 and bar1.SetAttribute and not (_G.InCombatLockdown and _G.InCombatLockdown()) then
        bar1:SetAttribute("actionpage", page)
    end
    local buttons = self:GetBarButtons("bar1")
    for _, btn in ipairs(buttons) do
        if not (_G.InCombatLockdown and _G.InCombatLockdown()) and btn.SetAttribute then
            btn:SetAttribute("actionpage", nil)
        end
        if btn.UpdateAction then
            btn:UpdateAction()
        end
    end
end


