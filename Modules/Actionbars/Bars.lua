local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local AB = RoithiUI:GetModule("Actionbars")
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode-Roithi", true)

local BAR_CONFIGS = {
    bar1 = { name = "RoithiActionBar1", prefix = "ActionButton", count = 12 },
    bar2 = { name = "RoithiActionBar2", prefix = "MultiBarBottomLeftButton", count = 12 },
    bar3 = { name = "RoithiActionBar3", prefix = "MultiBarBottomRightButton", count = 12 },
    bar4 = { name = "RoithiActionBar4", prefix = "MultiBarRightButton", count = 12 },
    bar5 = { name = "RoithiActionBar5", prefix = "MultiBarLeftButton", count = 12 },
    bar6 = { name = "RoithiActionBar6", prefix = "MultiBar5Button", count = 12 },
    bar7 = { name = "RoithiActionBar7", prefix = "MultiBar6Button", count = 12 },
    bar8 = { name = "RoithiActionBar8", prefix = "MultiBar7Button", count = 12 },
    pet = { name = "RoithiActionPetBar", prefix = "PetActionButton", count = 10 },
    stance = { name = "RoithiActionStanceBar", prefix = "StanceButton", count = 10, altPrefix = "ShapeshiftButton" },
    extraAction = { name = "RoithiExtraActionBar", prefix = "ExtraActionButton", count = 1 },
    zoneAction = { name = "RoithiZoneActionBar", count = 1 },
}
AB.BAR_CONFIGS = BAR_CONFIGS

local BLIZZARD_BAR_FRAMES = {
    bar1 = { "MainActionBar", "MainMenuBar" },
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

local function FormatHotkey(text)
    if not text or text == "" then return "" end
    if text == _G.RANGE_INDICATOR or text == "·" or text == "•" or text:find("[\194\183\226\128\162]") then
        return ""
    end
    local formatted = text
    formatted = formatted:gsub("SHIFT%-", "S")
    formatted = formatted:gsub("Shift%-", "S")
    formatted = formatted:gsub("s%-", "S")
    formatted = formatted:gsub("CTRL%-", "C")
    formatted = formatted:gsub("Ctrl%-", "C")
    formatted = formatted:gsub("c%-", "C")
    formatted = formatted:gsub("ALT%-", "A")
    formatted = formatted:gsub("Alt%-", "A")
    formatted = formatted:gsub("a%-", "A")
    formatted = formatted:gsub("STRG%-", "C")
    formatted = formatted:gsub("Strg%-", "C")
    formatted = formatted:gsub("SPACE", "Sp")
    formatted = formatted:gsub("Mouse Wheel Up", "WU")
    formatted = formatted:gsub("Mouse Wheel Down", "WD")
    return formatted
end
AB.FormatHotkey = FormatHotkey

local function ButtonHasAction(btn)
    if not btn then return false end
    if btn.HasAction then
        return btn:HasAction() == true
    end
    local action = btn.action or (btn.GetPagedID and btn:GetPagedID()) or (btn.CalculateAction and btn:CalculateAction())
    if action then
        if _G.C_ActionBar and _G.C_ActionBar.HasAction then
            return _G.C_ActionBar.HasAction(action)
        elseif _G.HasAction then
            return _G.HasAction(action)
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
    end
    return false
end

local function IsExtraActionActive()
    if _G.C_ActionBar and _G.C_ActionBar.HasExtraActionBar and _G.C_ActionBar.HasExtraActionBar() then
        return true
    end
    if _G.HasExtraActionBar and _G.HasExtraActionBar() then
        return true
    end
    local btn = _G.ExtraActionButton1
    if btn then
        if btn.HasAction and btn:HasAction() then
            return true
        end
        local action = btn.action or (btn.CalculateAction and btn:CalculateAction())
        if action and _G.HasAction and _G.HasAction(action) then
            return true
        end
    end
    return false
end
AB.IsExtraActionActive = IsExtraActionActive

local function IsZoneActionActive()
    if _G.C_ZoneAbility and _G.C_ZoneAbility.GetActiveAbilities then
        local abilities = _G.C_ZoneAbility.GetActiveAbilities()
        if abilities and #abilities > 0 then
            return true
        end
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
        local btn = zf.SpellButton or _G.ZoneAbilityButton1
        if btn and btn.HasAction and btn:HasAction() then
            return true
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
            table.insert(buttons, btn)
        end
    end
    return buttons
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

function AB:UpdateBarMouseover(barKey)
    local container = self.bars[barKey]
    if not container then return end
    local db = self.db[barKey] or {}
    if db.enabled == false then
        if container.Hide then container:Hide() end
        return
    end

    local alpha = (db.mouseover and not self:IsBarMouseOver(barKey)) and (db.mouseoverAlpha or 0.0) or (db.alpha or 1.0)
    if container.SetAlpha then
        container:SetAlpha(alpha)
    end
end

function AB:OnBarEnter(barKey)
    local db = self.db[barKey] or {}
    if db.mouseover then
        local container = self.bars[barKey]
        if container and container.SetAlpha then
            container:SetAlpha(db.alpha or 1.0)
        end
    end
end

function AB:OnBarLeave(barKey)
    local db = self.db[barKey] or {}
    if db.mouseover and _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.05, function()
            if not self:IsBarMouseOver(barKey) then
                local container = self.bars[barKey]
                if container and container.SetAlpha then
                    container:SetAlpha(db.mouseoverAlpha or 0.0)
                end
            end
        end)
    end
end

function AB:UpdateEmptyButtons(barKey)
    local db = self.db[barKey] or {}
    if db.enabled == false then return end

    local buttons = self:GetBarButtons(barKey)
    local maxBtns = db.maxButtons or #buttons
    if maxBtns < 1 then maxBtns = 1 end
    local displayCount = math.min(#buttons, maxBtns)
    local isEditMode = (LEM and LEM.isInEditMode) or false
    if barKey == "stance" and not isEditMode then
        local numForms = _G.GetNumShapeshiftForms and _G.GetNumShapeshiftForms() or 0
        displayCount = math.min(displayCount, numForms)
    end
    local hideEmpty = db.hideEmpty == true and not self.showingGrid

    local inCombat = (_G.InCombatLockdown and _G.InCombatLockdown()) or false

    for i, btn in ipairs(buttons) do
        if i > displayCount then
            if btn.SetAlpha then btn:SetAlpha(0) end
            if not inCombat and btn.Hide then btn:Hide() end
            if btn.roithiBackdrop and btn.roithiBackdrop.Hide then btn.roithiBackdrop:Hide() end
        elseif hideEmpty then
            local hasAct = ButtonHasAction(btn)
            if hasAct then
                if not inCombat and btn.Show and not btn:IsShown() then btn:Show() end
                if btn.SetAlpha then btn:SetAlpha(1) end
                if btn.roithiBackdrop and btn.roithiBackdrop.Show then btn.roithiBackdrop:Show() end
            else
                if btn.SetAlpha then btn:SetAlpha(0) end
                if btn.roithiBackdrop and btn.roithiBackdrop.Hide then btn.roithiBackdrop:Hide() end
            end
        else
            if not inCombat and btn.Show and not btn:IsShown() then btn:Show() end
            if btn.SetAlpha then btn:SetAlpha(1) end
            if btn.roithiBackdrop and btn.roithiBackdrop.Show then btn.roithiBackdrop:Show() end
        end
    end
end

function AB:UpdateAllEmptyButtons()
    for barKey in pairs(BAR_CONFIGS) do
        self:UpdateEmptyButtons(barKey)
    end
end

local hiddenParent
local function GetHiddenParent()
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame", "RoithiUI_HiddenActionBars", UIParent)
        hiddenParent:Hide()
    end
    return hiddenParent
end

function AB:SetupBars()
    for barKey, cfg in pairs(BAR_CONFIGS) do
        if not self.bars[barKey] then
            local f = CreateFrame("Frame", cfg.name, UIParent)
            if f.SetClampedToScreen then f:SetClampedToScreen(true) end
            if f.SetMovable then f:SetMovable(true) end
            if f.EnableMouse then f:EnableMouse(false) end
            f.barKey = barKey
            self.bars[barKey] = f

            local db = self.db[barKey] or {}
            local pt = db.point or "BOTTOM"
            if f.ClearAllPoints then f:ClearAllPoints() end
            if f.SetPoint then f:SetPoint(pt, UIParent, pt, db.x or 0, db.y or 0) end
        end

        local db = self.db[barKey] or {}
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
            if not _G.InCombatLockdown or not _G.InCombatLockdown() then
                self:LayoutBar("extraAction")
            end
        end)
        hooksecurefunc(_G.ExtraActionBarFrame, "Hide", function()
            if not _G.InCombatLockdown or not _G.InCombatLockdown() then
                self:LayoutBar("extraAction")
            end
        end)
        self.extraActionBarHooked = true
    end

    if _G.ZoneAbilityFrame and not self.zoneAbilityHooked and hooksecurefunc then
        hooksecurefunc(_G.ZoneAbilityFrame, "Show", function()
            if not _G.InCombatLockdown or not _G.InCombatLockdown() then
                self:LayoutBar("zoneAction")
            end
        end)
        hooksecurefunc(_G.ZoneAbilityFrame, "Hide", function()
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
            if self:IsEnabled() and not InCombatLockdown() then
                self:LayoutBar("bar1")
            end
        end)
        self.managePositionsHooked = true
    end

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.editModeRegistered then
        _G.EventRegistry:RegisterCallback("EditMode.Enter", function()
            for _, bFrames in pairs(BLIZZARD_BAR_FRAMES) do
                for _, fname in ipairs(bFrames) do
                    local bf = _G[fname]
                    if bf then
                        bf.defaultHideSelection = true
                        if bf.Selection then
                            bf.Selection:Hide()
                            if bf.Selection.EnableMouse then bf.Selection:EnableMouse(false) end
                        end
                    end
                end
            end
        end, self)
        self.editModeRegistered = true
    end

    if not self.overlayHooksRegistered and hooksecurefunc then
        if _G.ActionButton_Update then
            hooksecurefunc("ActionButton_Update", function(btn)
                if (not self.IsEnabled or self:IsEnabled()) and btn then
                    self:UpdateOverlayContainment(btn)
                end
            end)
        end
        if _G.ActionButton_UpdateState then
            hooksecurefunc("ActionButton_UpdateState", function(btn)
                if (not self.IsEnabled or self:IsEnabled()) and btn then
                    self:UpdateOverlayContainment(btn)
                end
            end)
        end
        if _G.ActionBarActionButtonMixin then
            if _G.ActionBarActionButtonMixin.Update then
                hooksecurefunc(_G.ActionBarActionButtonMixin, "Update", function(btn)
                    if (not self.IsEnabled or self:IsEnabled()) and btn then
                        self:UpdateOverlayContainment(btn)
                    end
                end)
            end
            if _G.ActionBarActionButtonMixin.UpdateState then
                hooksecurefunc(_G.ActionBarActionButtonMixin, "UpdateState", function(btn)
                    if (not self.IsEnabled or self:IsEnabled()) and btn then
                        self:UpdateOverlayContainment(btn)
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
                        actionButton.SpellActivationAlert:SetSize(w, h)
                    end
                end
            end)
        end
        self.overlayHooksRegistered = true
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

function AB:StyleButton(button)
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
    else
        if button.roithiBackdrop.EnableMouse then button.roithiBackdrop:EnableMouse(false) end
        if button.roithiBackdrop.SetMouseClickEnabled then button.roithiBackdrop:SetMouseClickEnabled(false) end
        if button.roithiBackdrop.SetMouseMotionEnabled then button.roithiBackdrop:SetMouseMotionEnabled(false) end
        if button.roithiBackdrop.Show then button.roithiBackdrop:Show() end
        local bc = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
        if button.roithiBackdrop.SetBackdropBorderColor then
            button.roithiBackdrop:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        end
    end

    -- Secure non-interactive TextOverlayContainer
    local toc = button.TextOverlayContainer
    if toc then
        if toc.EnableMouse then toc:EnableMouse(false) end
        if toc.SetMouseClickEnabled then toc:SetMouseClickEnabled(false) end
        if toc.SetMouseMotionEnabled then toc:SetMouseMotionEnabled(false) end
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
    local hotkey = button.HotKey or _G[button.GetName and button:GetName() and (button:GetName() .. "HotKey") or ""]
    if hotkey then
        if hotkey.EnableMouse then hotkey:EnableMouse(false) end
        if hotkey.SetMouseClickEnabled then hotkey:SetMouseClickEnabled(false) end
        if hotkey.SetMouseMotionEnabled then hotkey:SetMouseMotionEnabled(false) end
        if hotkey.SetShown then
            hotkey:SetShown(self.db.showHotkeys ~= false)
        end
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(hotkey, self.db.font or "Friz Quadrata TT", self.db.fontSize or 11, "OUTLINE")
        end
        if not hotkey.roithiHooked and hooksecurefunc then
            hooksecurefunc(hotkey, "SetText", function(s, txt)
                if s.roithiFormatting then return end
                local formatted = FormatHotkey(txt)
                if formatted ~= txt then
                    s.roithiFormatting = true
                    s:SetText(formatted)
                    s.roithiFormatting = false
                end
            end)
            hotkey.roithiHooked = true
        end
        local currentText = hotkey.GetText and hotkey:GetText()
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
        if name.SetShown then
            name:SetShown(self.db.showMacroText ~= false)
        end
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(name, self.db.font or "Friz Quadrata TT", math.max(8, (self.db.fontSize or 11) - 2), "OUTLINE")
        end
    end

    -- 7. Item / Charge Count Styling
    local count = button.Count or _G[button.GetName and button:GetName() and (button:GetName() .. "Count") or ""]
    if count then
        if count.EnableMouse then count:EnableMouse(false) end
        if count.SetMouseClickEnabled then count:SetMouseClickEnabled(false) end
        if count.SetMouseMotionEnabled then count:SetMouseMotionEnabled(false) end
        if count.SetShown then
            count:SetShown(self.db.showCount ~= false)
        end
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(count, self.db.font or "Friz Quadrata TT", math.max(8, (self.db.fontSize or 11) - 1), "OUTLINE")
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
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedLayout = true
        return
    end

    local container = self.bars[barKey]
    if not container then return end

    local db = self.db[barKey]
    local buttons = self:GetBarButtons(barKey)
    local blizzFrames = BLIZZARD_BAR_FRAMES[barKey]

    if not db or db.enabled == false then
        if container.Hide then container:Hide() end
        for _, btn in ipairs(buttons) do
            if btn.Hide then btn:Hide() end
            if btn.SetAlpha then btn:SetAlpha(0) end
        end
        if blizzFrames then
            for _, fname in ipairs(blizzFrames) do
                local bf = _G[fname]
                if bf then
                    if bf.Hide then bf:Hide() end
                    if bf.SetAlpha then bf:SetAlpha(0) end
                    if bf.Selection and bf.Selection.Hide then bf.Selection:Hide() end
                end
            end
        end
        if LEM and LEM.frameSelections and LEM.frameSelections[container] then
            local sel = LEM.frameSelections[container]
            if sel and sel.Hide then sel:Hide() end
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
        if not IsExtraActionActive() then
            if container.Hide then container:Hide() end
            for _, btn in ipairs(buttons) do
                if btn.Hide then btn:Hide() end
            end
            return
        end
    end

    -- 4. Zone Action Bar: Hide if not active and not in Edit Mode
    if barKey == "zoneAction" and not isEditMode then
        if not IsZoneActionActive() then
            if container.Hide then container:Hide() end
            for _, btn in ipairs(buttons) do
                if btn.Hide then btn:Hide() end
            end
            return
        end
    end

    if container.Show then container:Show() end

    -- Hide Blizzard native frames for this bar to prevent duplicate displays & Edit Mode outlines
    if blizzFrames then
        for _, fname in ipairs(blizzFrames) do
            local bf = _G[fname]
            if bf then
                if not bf.roithiOriginalParent and bf.GetParent then
                    bf.roithiOriginalParent = bf:GetParent()
                end
                if fname ~= "MainActionBar" and fname ~= "MainMenuBar" then
                    local hp = GetHiddenParent()
                    if bf.SetParent and hp then
                        bf:SetParent(hp)
                    end
                end
                bf.defaultHideSelection = true
                if bf.SetAlpha then bf:SetAlpha(0) end
                if bf.Hide then bf:Hide() end
                if bf.Selection then
                    if bf.Selection.Hide then bf.Selection:Hide() end
                    if bf.Selection.EnableMouse then bf.Selection:EnableMouse(false) end
                end
            end
        end
    end

    local btnSize = db.buttonSize or 36
    local spacing = db.spacing or 4
    local isVertical = (db.orientation == "VERTICAL")
    local maxBtns = db.maxButtons or (BAR_CONFIGS[barKey] and BAR_CONFIGS[barKey].count) or #buttons
    if maxBtns < 1 then maxBtns = 1 end
    local displayCount = math.min(#buttons, maxBtns)
    if barKey == "stance" and not isEditMode then
        local numForms = _G.GetNumShapeshiftForms and _G.GetNumShapeshiftForms() or 0
        displayCount = math.min(displayCount, numForms)
    end

    local perLine = db.buttonsPerRow or #buttons
    if perLine < 1 then perLine = 1 end

    local layoutCount = math.max(1, displayCount)
    local numCols, numRows
    if isVertical then
        numRows = math.min(layoutCount, perLine)
        numCols = math.ceil(layoutCount / perLine)
    else
        numCols = math.min(layoutCount, perLine)
        numRows = math.ceil(layoutCount / perLine)
    end
    if numCols < 1 then numCols = 1 end
    if numRows < 1 then numRows = 1 end

    local totalW = (numCols * btnSize) + math.max(0, (numCols - 1) * spacing)
    local totalH = (numRows * btnSize) + math.max(0, (numRows - 1) * spacing)
    if container.SetSize then container:SetSize(totalW, totalH) end

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
            if container.GetFrameLevel and btn.SetFrameLevel then
                btn:SetFrameLevel(container:GetFrameLevel() + 10)
            end
            if btn.SetAlpha then btn:SetAlpha(1) end
            if btn.Show then btn:Show() end
            if btn.ClearAllPoints then btn:ClearAllPoints() end

            local col, row
            if isVertical then
                row = (i - 1) % perLine
                col = math.floor((i - 1) / perLine)
            else
                col = (i - 1) % perLine
                row = math.floor((i - 1) / perLine)
            end
            local x = col * (btnSize + spacing)
            local y = -row * (btnSize + spacing)

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
                    if bf.roithiOriginalParent and bf.SetParent then
                        bf:SetParent(bf.roithiOriginalParent)
                    elseif fname ~= "MainActionBar" and fname ~= "MainMenuBar" and bf.SetParent then
                        bf:SetParent(UIParent)
                    end
                    if bf.SetAlpha then bf:SetAlpha(1) end
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
