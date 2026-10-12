local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local CDM = RoithiUI:NewModule("CooldownManager", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

CDM.displayName = L["Cooldown Manager"] or "Cooldown Manager"
CDM.description = L["Modern HUD cooldown manager styling for Blizzard Retail viewers (Essential, Utility, Buffs)."] or "Modern HUD cooldown manager styling for Blizzard Retail viewers."
CDM.order = 95
CDM.dbKey = "CooldownManager"

CDM.VIEWER_KEYS = {
    Essential = "EssentialCooldownViewer",
    Utility = "UtilityCooldownViewer",
    BuffIcon = "BuffIconCooldownViewer",
    BuffBar = "BuffBarCooldownViewer",
}

CDM.defaultSettings = ns.CooldownManagerDefaults or (ns.Defaults and ns.Defaults.profile and ns.Defaults.profile.CooldownManager)
CDM.dbKey = "CooldownManager"

function CDM:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CooldownManager or self.defaultSettings
    if not self.db.viewers then
        self.db.viewers = CopyTable(self.defaultSettings.viewers)
    end
    self.hookedViewers = {}
end

function CDM:OnEnable()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CooldownManager or self.defaultSettings
    if self.db.enabled == false then return end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "OnSpecOrTalentsChanged")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "OnSpecOrTalentsChanged")
    self:RegisterEvent("SPELLS_CHANGED", "OnSpecOrTalentsChanged")

    self:HookAllViewers()
    self:StyleAllActiveItems()
    if self.InitializeAllCustomBars then
        self:InitializeAllCustomBars()
    end
end

function CDM:OnDisable()
    self:UnregisterAllEvents()
    self:RestoreAllItems()
end

function CDM:OnEnteringWorld()
    self:HookAllViewers()
    self:StyleAllActiveItems()
    for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
        local viewer = _G[globalName]
        if viewer then self:CenterIncompleteRows(viewerKey, viewer) end
    end
    if self.InitializeAllCustomBars then
        self:InitializeAllCustomBars()
    end
end

function CDM:OnSpecOrTalentsChanged()
    if not InCombatLockdown() and self:IsEnabled() and self.db and self.db.enabled ~= false then
        self:StyleAllActiveItems()
        for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
            local viewer = _G[globalName]
            if viewer then self:CenterIncompleteRows(viewerKey, viewer) end
        end
        if self.InitializeAllCustomBars then
            self:InitializeAllCustomBars()
        end
    end
end

function CDM:OnAddonLoaded(event, loadedAddonName)
    if loadedAddonName == "Blizzard_CooldownViewer" then
        self:HookAllViewers()
        self:StyleAllActiveItems()
    end
end

function CDM:HookAllViewers()
    for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
        local viewer = _G[globalName]
        if viewer and not self.hookedViewers[viewerKey] then
            self.hookedViewers[viewerKey] = true
            if viewer.RefreshLayout and hooksecurefunc then
                hooksecurefunc(viewer, "RefreshLayout", function()
                    if not InCombatLockdown() and self:IsEnabled() and self.db and self.db.enabled ~= false then
                        self:AlignViewerItems(viewerKey, viewer)
                    end
                end)
            end
            local container = (viewer.GetItemContainerFrame and viewer:GetItemContainerFrame()) or viewer
            if container and container.Layout and hooksecurefunc then
                hooksecurefunc(container, "Layout", function()
                    if not InCombatLockdown() and self:IsEnabled() and self.db and self.db.enabled ~= false then
                        self:AlignViewerItems(viewerKey, viewer)
                    end
                end)
            end
        end
    end
    self:HookItemMixins()
    self:HookCooldownViewerSettings()
    self:SetupEditMode()
end

function CDM:HookItemMixins()
    if self.itemMixinsHooked or not hooksecurefunc then return end

    local mixinMap = {
        Essential = _G.CooldownViewerEssentialItemMixin,
        Utility = _G.CooldownViewerUtilityItemMixin,
        BuffIcon = _G.CooldownViewerBuffIconItemMixin,
        BuffBar = _G.CooldownViewerBuffBarItemMixin,
    }

    for viewerKey, mixin in pairs(mixinMap) do
        if mixin and mixin.OnCooldownIDSet then
            hooksecurefunc(mixin, "OnCooldownIDSet", function(itemFrame)
                if self:IsEnabled() and self.db and self.db.enabled ~= false then
                    self:StyleItemFrame(viewerKey, itemFrame)
                end
            end)
        end
    end

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.dataChangedCallbackRegistered then
        _G.EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
            if not InCombatLockdown() and self:IsEnabled() and self.db and self.db.enabled ~= false then
                self:StyleAllActiveItems()
                for vKey, gName in pairs(self.VIEWER_KEYS) do
                    local v = _G[gName]
                    if v then self:CenterIncompleteRows(vKey, v) end
                end
            end
        end, CDM)
        self.dataChangedCallbackRegistered = true
    end

    self.itemMixinsHooked = true
end

function CDM:OnResetItemFrame(viewerKey, itemFrame)
    if not itemFrame or not self:IsEnabled() or (self.db and self.db.enabled == false) then return end
    self:StyleItemFrame(viewerKey, itemFrame)
end

function CDM:PopulateSettingsPanel(panel)
    if self.selectedOptionsBar then
        panel.selectedBar = self.selectedOptionsBar
        self.selectedOptionsBar = nil
        if panel.RebuildTabs then panel:RebuildTabs() end
        if panel.RefreshView then panel:RefreshView() end
    end
    if panel.populated then
        return
    end

    panel.selectedBar = panel.selectedBar or "Essential"

    local function StyleModernButton(btn, isAccent)
        if not btn or btn.roithiStyled then return end
        if btn.Left and btn.Left.SetAlpha then btn.Left:SetAlpha(0) end
        if btn.Right and btn.Right.SetAlpha then btn.Right:SetAlpha(0) end
        if btn.Middle and btn.Middle.SetAlpha then btn.Middle:SetAlpha(0) end

        local normalTex = btn.GetNormalTexture and btn:GetNormalTexture()
        if normalTex and normalTex.SetAlpha then normalTex:SetAlpha(0) end
        local pushTex = btn.GetPushedTexture and btn:GetPushedTexture()
        if pushTex and pushTex.SetAlpha then pushTex:SetAlpha(0) end
        local disTex = btn.GetDisabledTexture and btn:GetDisabledTexture()
        if disTex and disTex.SetAlpha then disTex:SetAlpha(0) end

        local bg = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        bg:SetAllPoints(btn)
        bg:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        if isAccent then
            bg:SetBackdropColor(0.08, 0.22, 0.32, 0.85)
            bg:SetBackdropBorderColor(0, 0.7, 0.9, 0.9)
        else
            bg:SetBackdropColor(0.08, 0.08, 0.1, 0.85)
            bg:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.9)
        end
        bg:SetFrameLevel(math.max(0, btn:GetFrameLevel() - 1))
        btn.roithiBg = bg

        btn:HookScript("OnEnter", function()
            if btn.IsEnabled and not btn:IsEnabled() then return end
            bg:SetBackdropBorderColor(0, 0.85, 1, 1)
            bg:SetBackdropColor(0.12, 0.16, 0.22, 0.95)
        end)
        btn:HookScript("OnLeave", function()
            if btn.roithiActive then
                bg:SetBackdropColor(0.05, 0.3, 0.42, 0.95)
                bg:SetBackdropBorderColor(0, 0.85, 1, 1)
            elseif isAccent then
                bg:SetBackdropColor(0.08, 0.22, 0.32, 0.85)
                bg:SetBackdropBorderColor(0, 0.7, 0.9, 0.9)
            else
                bg:SetBackdropColor(0.08, 0.08, 0.1, 0.85)
                bg:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.9)
            end
        end)

        btn.roithiStyled = true
    end

    local function SetModernButtonActive(btn, active)
        if not btn or not btn.roithiBg then return end
        btn.roithiActive = active
        if active then
            btn.roithiBg:SetBackdropColor(0.05, 0.3, 0.42, 0.95)
            btn.roithiBg:SetBackdropBorderColor(0, 0.85, 1, 1)
            if btn.GetFontString and btn:GetFontString() then
                btn:GetFontString():SetTextColor(0, 0.9, 1, 1)
            end
        else
            btn.roithiBg:SetBackdropColor(0.08, 0.08, 0.1, 0.85)
            btn.roithiBg:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.9)
            if btn.GetFontString and btn:GetFontString() then
                btn:GetFontString():SetTextColor(1, 1, 1, 1)
            end
        end
    end

    panel.StyleModernButton = StyleModernButton
    panel.SetModernButtonActive = SetModernButtonActive

    -- Row 1: Native Blizzard Viewers Navigation (positioned cleanly on black background)
    local nativeTabButtons = {}
    local nativeTabs = {
        { key = "Essential", text = L["Essential"] or "Essential", width = 78 },
        { key = "Utility", text = L["Utility"] or "Utility", width = 78 },
        { key = "BuffIcon", text = L["Buff Icons"] or "Buff Icons", width = 86 },
        { key = "BuffBar", text = L["Buff Bars"] or "Buff Bars", width = 86 },
    }

    local nativeContainer = CreateFrame("Frame", nil, panel)
    nativeContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
    nativeContainer:SetSize(360, 24)

    -- Row 2: Custom Bars Toolbar
    local customToolbar = CreateFrame("Frame", nil, panel)
    customToolbar:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -42)
    customToolbar:SetSize(360, 24)

    local btnCustomDropdown = CreateFrame("Button", nil, customToolbar, "UIPanelButtonTemplate")
    btnCustomDropdown:SetSize(115, 24)
    btnCustomDropdown:SetPoint("LEFT", customToolbar, "LEFT", 0, 0)
    StyleModernButton(btnCustomDropdown, false)

    -- Arrow icon indicating dropdown
    local dropArrow = btnCustomDropdown:CreateTexture(nil, "OVERLAY")
    dropArrow:SetSize(14, 14)
    dropArrow:SetPoint("RIGHT", btnCustomDropdown, "RIGHT", -6, 0)
    dropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    dropArrow:SetVertexColor(0, 0.85, 1, 1)
    btnCustomDropdown.dropArrow = dropArrow

    local btnAddNewBar = CreateFrame("Button", nil, customToolbar, "UIPanelButtonTemplate")
    btnAddNewBar:SetSize(115, 24)
    btnAddNewBar:SetPoint("LEFT", btnCustomDropdown, "RIGHT", 5, 0)
    btnAddNewBar:SetText(L["+ Add New Bar"] or "+ Add New Bar")
    StyleModernButton(btnAddNewBar, true)

    local btnDeleteBar = CreateFrame("Button", nil, customToolbar, "UIPanelButtonTemplate")
    btnDeleteBar:SetSize(100, 24)
    btnDeleteBar:SetPoint("LEFT", btnAddNewBar, "RIGHT", 5, 0)
    btnDeleteBar:SetText(L["- Delete Bar"] or "- Delete Bar")
    StyleModernButton(btnDeleteBar, false)
    btnDeleteBar:Hide()

    -- Custom Bar Popout Menu
    local customMenu = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    customMenu:SetFrameStrata("DIALOG")
    customMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    customMenu:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    customMenu:SetBackdropBorderColor(0, 0.8, 1, 1)
    customMenu:SetPoint("TOPLEFT", btnCustomDropdown, "BOTTOMLEFT", 0, -2)
    customMenu:SetWidth(125)
    customMenu:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", "RoithiUI_CDM_ScrollFrame", panel)
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -74)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 10)
    scrollFrame:EnableMouseWheel(true)

    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(356, 500)
    scrollFrame:SetScrollChild(contentFrame)
    panel.scrollFrame = scrollFrame

    scrollFrame:SetScript("OnMouseWheel", function(selfScroll, delta)
        local cur = selfScroll:GetVerticalScroll()
        local maxScroll = math.max(0, (contentFrame.neededHeight or 500) - selfScroll:GetHeight())
        local newScroll = math.min(maxScroll, math.max(0, cur - (delta * 30)))
        selfScroll:SetVerticalScroll(newScroll)
    end)

    local function CreateSlider(cParent, name, minVal, maxVal, step, getVal, setVal, yOffset, xOffset)
        local slider = CreateFrame("Slider", nil, cParent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", cParent, "TOPLEFT", xOffset or 12, yOffset)
        slider:SetWidth(165)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        slider.Text = slider.Text or _G[slider:GetName() and (slider:GetName() .. "Text") or ""]
        slider.Low = slider.Low or _G[slider:GetName() and (slider:GetName() .. "Low") or ""]
        slider.High = slider.High or _G[slider:GetName() and (slider:GetName() .. "High") or ""]
        if slider.Low then slider.Low:SetText(tostring(minVal)) end
        if slider.High then slider.High:SetText(tostring(maxVal)) end
        local val = getVal() or minVal
        slider:SetValue(val)
        local label = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 3)
        label:SetPoint("RIGHT", slider, "TOPRIGHT", -46, 3)
        label:SetJustifyH("LEFT")
        if label.SetWordWrap then label:SetWordWrap(false) end
        label:SetText(name)

        local editBox = CreateFrame("EditBox", nil, slider, "BackdropTemplate")
        editBox:SetSize(42, 18)
        editBox:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 1)
        editBox:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        editBox:SetBackdropColor(0.08, 0.08, 0.1, 0.9)
        editBox:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.9)
        if editBox.SetFontObject then editBox:SetFontObject("GameFontHighlightSmall") end
        if editBox.SetJustifyH then editBox:SetJustifyH("RIGHT") end
        if editBox.SetTextInsets then editBox:SetTextInsets(2, 4, 0, 0) end
        if editBox.SetAutoFocus then editBox:SetAutoFocus(false) end
        if editBox.SetText then editBox:SetText(tostring(val)) end

        editBox:SetScript("OnEditFocusGained", function(eb)
            eb:SetBackdropBorderColor(0, 0.85, 1, 1)
            eb:HighlightText()
        end)
        editBox:SetScript("OnEditFocusLost", function(eb)
            eb:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.9)
            eb:SetText(tostring(slider:GetValue()))
        end)
        editBox:SetScript("OnEnterPressed", function(eb)
            local num = tonumber(eb:GetText())
            if num then
                num = math.min(maxVal, math.max(minVal, num))
                num = math.floor((num - minVal) / step + 0.5) * step + minVal
                slider:SetValue(num)
                setVal(num)
            end
            eb:ClearFocus()
        end)
        editBox:SetScript("OnEscapePressed", function(eb)
            eb:SetText(tostring(slider:GetValue()))
            eb:ClearFocus()
        end)

        slider:SetScript("OnValueChanged", function(_, v)
            v = math.floor((v - minVal) / step + 0.5) * step + minVal
            v = math.min(maxVal, math.max(minVal, v))
            if not editBox:HasFocus() then
                editBox:SetText(tostring(v))
            end
            setVal(v)
        end)
        return slider
    end

    local function CreateCheckbox(cParent, text, getVal, setVal, xOffset, yOffset)
        local cb = CreateFrame("CheckButton", nil, cParent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", cParent, "TOPLEFT", xOffset, yOffset)
        cb:SetChecked(getVal())
        cb.text = cb.text or _G[cb:GetName() and (cb:GetName() .. "Text") or ""]
        if not cb.text then
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        end
        cb.text:SetText(text)
        cb:SetScript("OnClick", function(selfBtn)
            setVal(selfBtn:GetChecked())
        end)
        return cb
    end

    local sharedAnchorMenu = CreateFrame("Frame", "RoithiUI_CDM_AnchorMenu", panel, "BackdropTemplate")
    sharedAnchorMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    sharedAnchorMenu:SetFrameLevel(2600)
    sharedAnchorMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    sharedAnchorMenu:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    sharedAnchorMenu:SetBackdropBorderColor(0, 0.85, 1, 1)
    sharedAnchorMenu:SetWidth(165)
    sharedAnchorMenu:Hide()
    sharedAnchorMenu.buttons = {}

    panel:HookScript("OnHide", function() sharedAnchorMenu:Hide() end)

    local function CreateAnchorDropdown(cParent, labelPrefix, getVal, setVal, xOffset, yOffset, customList)
        local ddBtn = CreateFrame("Button", nil, cParent, "UIPanelButtonTemplate")
        ddBtn:SetSize(165, 22)
        ddBtn:SetPoint("TOPLEFT", cParent, "TOPLEFT", xOffset, yOffset)
        StyleModernButton(ddBtn, false)

        local arrowTex = ddBtn:CreateTexture(nil, "OVERLAY")
        arrowTex:SetSize(12, 12)
        arrowTex:SetPoint("RIGHT", ddBtn, "RIGHT", -5, 0)
        arrowTex:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        arrowTex:SetVertexColor(0, 0.85, 1, 1)
        ddBtn.dropArrow = arrowTex

        local pointsList = customList or (ns.Utils and ns.Utils.ANCHOR_POINTS) or {
            "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"
        }

        local function UpdateText()
            local curVal = getVal() or "CENTER"
            local rawName = (ns.Utils and ns.Utils.ANCHOR_NAMES and ns.Utils.ANCHOR_NAMES[curVal]) or curVal
            local locName = (L and L[rawName]) or rawName
            ddBtn:SetText(string.format("%s: %s", labelPrefix, locName))
            local fs = ddBtn.GetFontString and ddBtn:GetFontString()
            if fs then
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", ddBtn, "LEFT", 8, 0)
                fs:SetPoint("RIGHT", arrowTex, "LEFT", -2, 0)
                fs:SetJustifyH("LEFT")
                fs:SetWordWrap(false)
            end
        end
        UpdateText()

        ddBtn:SetScript("OnClick", function()
            if sharedAnchorMenu:IsShown() and sharedAnchorMenu.owner == ddBtn then
                sharedAnchorMenu:Hide()
                return
            end
            sharedAnchorMenu.owner = ddBtn
            sharedAnchorMenu:ClearAllPoints()
            sharedAnchorMenu:SetPoint("TOPLEFT", ddBtn, "BOTTOMLEFT", 0, -2)
            sharedAnchorMenu:SetWidth(ddBtn:GetWidth())

            for _, b in ipairs(sharedAnchorMenu.buttons) do
                b:Hide()
            end

            local itemHeight = 20
            local curVal = getVal() or "CENTER"
            for idx, pt in ipairs(pointsList) do
                local itemBtn = sharedAnchorMenu.buttons[idx]
                if not itemBtn then
                    itemBtn = CreateFrame("Button", nil, sharedAnchorMenu)
                    itemBtn:SetHeight(itemHeight)
                    local hl = itemBtn:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetColorTexture(0, 0.85, 1, 0.25)
                    local text = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    text:SetPoint("LEFT", itemBtn, "LEFT", 8, 0)
                    itemBtn.text = text
                    sharedAnchorMenu.buttons[idx] = itemBtn
                end
                itemBtn:ClearAllPoints()
                itemBtn:SetPoint("TOPLEFT", sharedAnchorMenu, "TOPLEFT", 1, -((idx - 1) * itemHeight + 1))
                itemBtn:SetPoint("TOPRIGHT", sharedAnchorMenu, "TOPRIGHT", -1, -((idx - 1) * itemHeight + 1))

                local rawName = (ns.Utils and ns.Utils.ANCHOR_NAMES and ns.Utils.ANCHOR_NAMES[pt]) or pt
                local locName = (L and L[rawName]) or rawName
                if pt == curVal then
                    itemBtn.text:SetText(string.format("|cff00ffff%s|r", locName))
                else
                    itemBtn.text:SetText(locName)
                end
                itemBtn:SetScript("OnClick", function()
                    setVal(pt)
                    UpdateText()
                    sharedAnchorMenu:Hide()
                end)
                itemBtn:Show()
            end
            sharedAnchorMenu:SetHeight(#pointsList * itemHeight + 2)
            sharedAnchorMenu:Show()
        end)

        return ddBtn
    end

    local function RenderBarSettings()
        if sharedAnchorMenu then sharedAnchorMenu:Hide() end
        if contentFrame.widgets then
            for _, w in ipairs(contentFrame.widgets) do
                w:Hide()
                w:SetParent(nil)
            end
        end
        contentFrame.widgets = {}

        local bKey = panel.selectedBar
        local isCustom = bKey:find("^CustomBar") ~= nil

        if isCustom then
            btnDeleteBar:Show()
            local customIdx = tonumber(bKey:match("%d+"))
            local customList = CDM.GetCustomBars and CDM:GetCustomBars() or {}
            local cData = customList[customIdx]
            if not cData then return end

            local lblCustom = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lblCustom:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 12, -4)
            lblCustom:SetText(string.format("|cff00ccff%s|r", cData.name or "Custom Bar"))
            table.insert(contentFrame.widgets, lblCustom)

            -- Sliders & Controls for Custom Bar
            -- Column 1 (x=12, width=165)
            local sSize = CreateSlider(contentFrame, L["Icon Size"] or "Icon Size", 20, 80, 2,
                function() return cData.iconSize or 40 end,
                function(val)
                    cData.iconSize = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, -35, 12)
            table.insert(contentFrame.widgets, sSize)

            local sSpacing = CreateSlider(contentFrame, L["Icon Spacing / Padding"] or "Icon Spacing / Padding", 0, 20, 1,
                function() return cData.spacing or 0 end,
                function(val)
                    cData.spacing = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, -75, 12)
            table.insert(contentFrame.widgets, sSpacing)

            local sStackX = CreateSlider(contentFrame, L["Stacks Offset X"] or "Stacks Offset X", -30, 30, 1,
                function() return cData.stackOffsetX or -2 end,
                function(val)
                    cData.stackOffsetX = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, -115, 12)
            table.insert(contentFrame.widgets, sStackX)

            local sStackY = CreateSlider(contentFrame, L["Stacks Offset Y"] or "Stacks Offset Y", -30, 30, 1,
                function() return cData.stackOffsetY or 2 end,
                function(val)
                    cData.stackOffsetY = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, -155, 12)
            table.insert(contentFrame.widgets, sStackY)

            local sCdX = CreateSlider(contentFrame, L["Timer Offset X"] or "Timer Offset X", -30, 30, 1,
                function() return cData.timerOffsetX or 0 end,
                function(val)
                    cData.timerOffsetX = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, -195, 12)
            table.insert(contentFrame.widgets, sCdX)

            local sCdY = CreateSlider(contentFrame, L["Timer Offset Y"] or "Timer Offset Y", -30, 30, 1,
                function() return cData.timerOffsetY or 0 end,
                function(val)
                    cData.timerOffsetY = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, -235, 12)
            table.insert(contentFrame.widgets, sCdY)

            local cbCrop = CreateCheckbox(contentFrame, L["Modern Square Crop"] or "Modern Square Crop",
                function() return cData.cropIcons ~= false end,
                function(val)
                    cData.cropIcons = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, 12, -275)
            table.insert(contentFrame.widgets, cbCrop)

            local cbAdaptable = CreateCheckbox(contentFrame, L["Adaptable Bar (Auto-fit)"] or "Adaptable Bar (Auto-fit)",
                function() return cData.adaptable ~= false end,
                function(val)
                    cData.adaptable = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                    RenderBarSettings()
                end, 12, -300)
            table.insert(contentFrame.widgets, cbAdaptable)

            -- Optional Max Icons slider when Adaptable is unchecked
            if cData.adaptable == false then
                local sMaxIcons = CreateSlider(contentFrame, L["Max Icons (Fixed)"] or "Max Icons (Fixed)", 1, 16, 1,
                    function() return cData.maxIcons or 8 end,
                    function(val)
                        cData.maxIcons = val
                        if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                        RenderBarSettings()
                    end, -335, 12)
                table.insert(contentFrame.widgets, sMaxIcons)
            end

            -- Column 2 (x=188, width=165): Orientation, Timer, Stacks, Actions
            local btnGrowth = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
            btnGrowth:SetSize(165, 22)
            btnGrowth:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 188, -35)
            StyleModernButton(btnGrowth, false)
            local growthNames = {
                ["LEFT_TO_RIGHT"] = L["Grow: Left -> Right"] or "Grow: Left -> Right",
                ["RIGHT_TO_LEFT"] = L["Grow: Right -> Left"] or "Grow: Right -> Left",
                ["CENTER_HORIZONTAL"] = L["Grow: Centered Horiz"] or "Grow: Centered Horiz",
                ["TOP_TO_BOTTOM"] = L["Grow: Top -> Down"] or "Grow: Top -> Down",
                ["BOTTOM_TO_TOP"] = L["Grow: Down -> Up"] or "Grow: Down -> Up",
                ["CENTER_VERTICAL"] = L["Grow: Centered Vert"] or "Grow: Centered Vert",
            }
            local function GetEffectiveGrowth()
                local g = cData.growthDirection
                if g == "DOWN" then return "TOP_TO_BOTTOM" end
                if g == "UP" then return "BOTTOM_TO_TOP" end
                if g == "LEFT" then return "RIGHT_TO_LEFT" end
                if g == "RIGHT" then return "LEFT_TO_RIGHT" end
                if g == "CENTER" then return "CENTER_HORIZONTAL" end
                return g or (cData.orientation == "VERTICAL" and "TOP_TO_BOTTOM" or "LEFT_TO_RIGHT")
            end
            local function UpdateGrowthText()
                local cur = GetEffectiveGrowth()
                btnGrowth:SetText(growthNames[cur] or string.format("Growth: %s", cur))
            end
            UpdateGrowthText()
            btnGrowth:SetScript("OnClick", function()
                local cur = GetEffectiveGrowth()
                local nxt
                if cur == "LEFT_TO_RIGHT" then nxt = "RIGHT_TO_LEFT"
                elseif cur == "RIGHT_TO_LEFT" then nxt = "CENTER_HORIZONTAL"
                elseif cur == "CENTER_HORIZONTAL" then nxt = "TOP_TO_BOTTOM"
                elseif cur == "TOP_TO_BOTTOM" then nxt = "BOTTOM_TO_TOP"
                elseif cur == "BOTTOM_TO_TOP" then nxt = "CENTER_VERTICAL"
                else nxt = "LEFT_TO_RIGHT" end
                cData.growthDirection = nxt
                if nxt == "TOP_TO_BOTTOM" or nxt == "BOTTOM_TO_TOP" or nxt == "CENTER_VERTICAL" then
                    cData.orientation = "VERTICAL"
                else
                    cData.orientation = "HORIZONTAL"
                end
                UpdateGrowthText()
                if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
            end)
            table.insert(contentFrame.widgets, btnGrowth)

            local btnOrient = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
            btnOrient:SetSize(165, 22)
            btnOrient:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 188, -62)
            StyleModernButton(btnOrient, false)
            local function UpdateOrientText()
                local orient = cData.orientation or "HORIZONTAL"
                btnOrient:SetText(string.format("Orientation: %s", orient))
            end
            UpdateOrientText()
            btnOrient:SetScript("OnClick", function()
                cData.orientation = (cData.orientation == "VERTICAL") and "HORIZONTAL" or "VERTICAL"
                if cData.orientation == "VERTICAL" then
                    if cData.growthDirection == "LEFT_TO_RIGHT" or cData.growthDirection == "RIGHT_TO_LEFT" then
                        cData.growthDirection = "TOP_TO_BOTTOM"
                    end
                else
                    if cData.growthDirection == "TOP_TO_BOTTOM" or cData.growthDirection == "BOTTOM_TO_TOP" then
                        cData.growthDirection = "LEFT_TO_RIGHT"
                    end
                end
                UpdateOrientText()
                UpdateGrowthText()
                RenderBarSettings()
                if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
            end)
            table.insert(contentFrame.widgets, btnOrient)

            local cbTimer = CreateCheckbox(contentFrame, L["Show Countdown Timer"] or "Show Countdown Timer",
                function() return cData.showTimer ~= false end,
                function(val)
                    cData.showTimer = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, 188, -90)
            table.insert(contentFrame.widgets, cbTimer)

            local sCdFont = CreateSlider(contentFrame, L["Timer Font Size"] or "Timer Font Size", 8, 28, 1,
                function() return cData.cooldownFontSize or 14 end,
                function(val)
                    cData.cooldownFontSize = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, -125, 188)
            table.insert(contentFrame.widgets, sCdFont)

            local ddTimerPos = CreateAnchorDropdown(contentFrame, "Timer Pos",
                function() return cData.timerAnchor or "CENTER" end,
                function(val)
                    cData.timerAnchor = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, 188, -165)
            table.insert(contentFrame.widgets, ddTimerPos)

            local cbStacks = CreateCheckbox(contentFrame, L["Show Stacks / Charges"] or "Show Stacks / Charges",
                function() return cData.showStacks ~= false end,
                function(val)
                    cData.showStacks = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, 188, -195)
            table.insert(contentFrame.widgets, cbStacks)

            local sStackFont = CreateSlider(contentFrame, L["Stack Font Size"] or "Stack Font Size", 8, 24, 1,
                function() return cData.stackFontSize or 11 end,
                function(val)
                    cData.stackFontSize = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, -230, 188)
            table.insert(contentFrame.widgets, sStackFont)

            local ddStackPos = CreateAnchorDropdown(contentFrame, "Stack Pos",
                function() return cData.stackAnchor or "BOTTOMRIGHT" end,
                function(val)
                    cData.stackAnchor = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                end, 188, -270)
            table.insert(contentFrame.widgets, ddStackPos)

            local btnEditMode = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
            btnEditMode:SetSize(165, 22)
            btnEditMode:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 188, -300)
            btnEditMode:SetText(L["Open Edit Mode"] or "Open Edit Mode")
            StyleModernButton(btnEditMode, false)
            btnEditMode:SetScript("OnClick", function()
                if _G.EditModeManagerFrame and _G.EditModeManagerFrame.Show then
                    _G.EditModeManagerFrame:Show()
                end
            end)
            table.insert(contentFrame.widgets, btnEditMode)

            local cbOverrideGlobal = CreateCheckbox(contentFrame, L["Override Global Settings"] or "Override Global Settings",
                function() return cData.overrideGlobal == true end,
                function(val)
                    cData.overrideGlobal = val
                    if CDM.InitializeCustomBar then CDM:InitializeCustomBar(customIdx) end
                    RenderBarSettings()
                end, 188, -326)
            table.insert(contentFrame.widgets, cbOverrideGlobal)

            -- ==============================================================
            -- Assigned Spells Management (Bottom Half)
            -- ==============================================================
            local sepLineY = (cData.adaptable == false) and -395 or -355
            local sepLine = contentFrame:CreateTexture(nil, "ARTWORK")
            sepLine:SetSize(342, 1)
            sepLine:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 12, sepLineY)
            sepLine:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            table.insert(contentFrame.widgets, sepLine)

            local baseSpellsY = sepLineY - 8
            local lblSpells = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lblSpells:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 12, baseSpellsY)
            lblSpells:SetText("|cff00ccff" .. (L["Assigned Spells"] or "Assigned Spells") .. "|r")
            table.insert(contentFrame.widgets, lblSpells)

            local lblSub = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lblSub:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 12, baseSpellsY - 15)
            lblSub:SetText(L["Drag spells from Spellbook onto bar or list below, or enter ID/Name:"] or "Drag spells from Spellbook onto bar or list below, or enter ID/Name:")
            table.insert(contentFrame.widgets, lblSub)

            local spellInput = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
            spellInput:SetSize(230, 22)
            spellInput:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 16, baseSpellsY - 35)
            spellInput:SetAutoFocus(false)
            spellInput:SetMaxLetters(50)
            table.insert(contentFrame.widgets, spellInput)

            local btnAddSpell = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
            btnAddSpell:SetSize(100, 22)
            btnAddSpell:SetPoint("LEFT", spellInput, "RIGHT", 6, 0)
            btnAddSpell:SetText(L["+ Add Spell"] or "+ Add Spell")
            StyleModernButton(btnAddSpell, true)
            table.insert(contentFrame.widgets, btnAddSpell)

            local function AddSpellAction()
                local text = spellInput:GetText()
                if text and text:match("%S") then
                    cData.spells = cData.spells or {}
                    local nextSlot = #cData.spells + 1
                    local ok = CDM:AssignSpellToCustomBar(customIdx, nextSlot, text)
                    if ok then
                        spellInput:SetText("")
                        spellInput:ClearFocus()
                        RenderBarSettings()
                    else
                        print("|cff00ccff[RoithiUI]|r Could not find spell: " .. text)
                    end
                end
            end

            btnAddSpell:SetScript("OnClick", AddSpellAction)
            spellInput:SetScript("OnEnterPressed", AddSpellAction)

            -- Spell List Display (Assigned Spells + Interactive Drop Zone)
            cData.spells = cData.spells or {}
            local yStart = baseSpellsY - 65

            for slotI = 1, #cData.spells do
                local sData = cData.spells[slotI]
                local slotRow = CreateFrame("Button", nil, contentFrame, "BackdropTemplate")
                slotRow:SetSize(342, 24)
                slotRow:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 12, yStart - ((slotI - 1) * 26))
                slotRow:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                slotRow:SetBackdropColor(0.06, 0.06, 0.06, 0.6)
                slotRow:SetBackdropBorderColor(0.18, 0.18, 0.18, 0.8)

                slotRow:RegisterForClicks("AnyUp")
                if slotRow.RegisterForDrag then slotRow:RegisterForDrag("LeftButton") end

                local function HandleRowDrop()
                    local spellID = CDM:GetCursorSpellInfo()
                    if spellID then
                        CDM:AssignSpellToCustomBar(customIdx, slotI, spellID)
                        _G.ClearCursor()
                        RenderBarSettings()
                    end
                end

                slotRow:SetScript("OnReceiveDrag", HandleRowDrop)
                slotRow:SetScript("OnClick", function(_, btn)
                    if btn == "RightButton" and _G.IsShiftKeyDown() then
                        CDM:RemoveSpellFromCustomBar(customIdx, slotI)
                        RenderBarSettings()
                    else
                        HandleRowDrop()
                    end
                end)
                slotRow:SetScript("OnEnter", function(selfRow)
                    selfRow:SetBackdropBorderColor(0, 0.8, 1, 1)
                    if sData and sData.spellID and _G.GameTooltip then
                        _G.GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                        if _G.GameTooltip.SetSpellByID then
                            _G.GameTooltip:SetSpellByID(sData.spellID)
                        end
                        _G.GameTooltip:Show()
                    end
                end)
                slotRow:SetScript("OnLeave", function(selfRow)
                    selfRow:SetBackdropBorderColor(0.18, 0.18, 0.18, 0.8)
                    if _G.GameTooltip then _G.GameTooltip:Hide() end
                end)

                local slotNum = slotRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                slotNum:SetPoint("LEFT", slotRow, "LEFT", 4, 0)
                slotNum:SetWidth(20)
                slotNum:SetText(string.format("#%d", slotI))

                local sIcon = slotRow:CreateTexture(nil, "ARTWORK")
                sIcon:SetSize(20, 20)
                sIcon:SetPoint("LEFT", slotNum, "RIGHT", 4, 0)
                sIcon:SetTexture(sData.icon or (_G.C_Spell and _G.C_Spell.GetSpellTexture and _G.C_Spell.GetSpellTexture(sData.spellID)) or 134400)
                sIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

                local sIconBorder = CreateFrame("Frame", nil, slotRow, "BackdropTemplate")
                sIconBorder:SetAllPoints(sIcon)
                sIconBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                sIconBorder:SetBackdropBorderColor(0, 0, 0, 1)

                local sText = slotRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                sText:SetPoint("LEFT", sIcon, "RIGHT", 6, 0)
                sText:SetWidth(180)
                sText:SetJustifyH("LEFT")
                sText:SetText(string.format("%s (|cff888888%d|r)", sData.name or "Unknown", sData.spellID))

                if slotI > 1 then
                    local btnUp = CreateFrame("Button", nil, slotRow, "UIPanelButtonTemplate")
                    btnUp:SetSize(22, 18)
                    btnUp:SetPoint("LEFT", slotRow, "LEFT", 260, 0)
                    btnUp:SetText("^")
                    StyleModernButton(btnUp, false)
                    btnUp:SetScript("OnClick", function()
                        CDM:MoveSpellInCustomBar(customIdx, slotI, -1)
                        RenderBarSettings()
                    end)
                end

                if slotI < #cData.spells then
                    local btnDown = CreateFrame("Button", nil, slotRow, "UIPanelButtonTemplate")
                    btnDown:SetSize(22, 18)
                    btnDown:SetPoint("LEFT", slotRow, "LEFT", 286, 0)
                    btnDown:SetText("v")
                    StyleModernButton(btnDown, false)
                    btnDown:SetScript("OnClick", function()
                        CDM:MoveSpellInCustomBar(customIdx, slotI, 1)
                        RenderBarSettings()
                    end)
                end

                local btnRemove = CreateFrame("Button", nil, slotRow, "UIPanelButtonTemplate")
                btnRemove:SetSize(22, 18)
                btnRemove:SetPoint("LEFT", slotRow, "LEFT", 312, 0)
                StyleModernButton(btnRemove, false)
                btnRemove:SetText("")

                local removeIcon = btnRemove:CreateTexture(nil, "OVERLAY")
                removeIcon:SetSize(12, 12)
                removeIcon:SetPoint("CENTER", btnRemove, "CENTER", 0, 0)
                local atlasOk = false
                if removeIcon.SetAtlas and _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo("common-icon-redx") then
                    atlasOk = pcall(function() removeIcon:SetAtlas("common-icon-redx") end)
                end
                if not atlasOk then
                    removeIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                end
                btnRemove.icon = removeIcon

                btnRemove:SetScript("OnEnter", function(b)
                    if _G.GameTooltip then
                        _G.GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                        _G.GameTooltip:SetText(L["Remove Spell"] or "Remove Spell", 1, 0.3, 0.3)
                        _G.GameTooltip:Show()
                    end
                end)
                btnRemove:SetScript("OnLeave", function()
                    if _G.GameTooltip then _G.GameTooltip:Hide() end
                end)
                btnRemove:SetScript("OnClick", function()
                    CDM:RemoveSpellFromCustomBar(customIdx, slotI)
                    RenderBarSettings()
                end)

                table.insert(contentFrame.widgets, slotRow)
            end

            -- Interactive Drop Zone to Append New Spell
            local dropZoneY = yStart - (#cData.spells * 26)
            local dropZone = CreateFrame("Button", nil, contentFrame, "BackdropTemplate")
            dropZone:SetSize(342, 28)
            dropZone:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 12, dropZoneY)
            dropZone:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            dropZone:SetBackdropColor(0, 0.25, 0.35, 0.2)
            dropZone:SetBackdropBorderColor(0, 0.6, 0.8, 0.7)

            local dropText = dropZone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            dropText:SetPoint("CENTER", dropZone, "CENTER", 0, 0)
            dropText:SetText("|cff00ccff+ " .. (L["Drag & drop spell from Spellbook here"] or "Drag & drop spell from Spellbook here") .. "|r")

            dropZone:RegisterForClicks("AnyUp")
            if dropZone.RegisterForDrag then dropZone:RegisterForDrag("LeftButton") end

            local function HandleDropZone()
                local spellID = CDM:GetCursorSpellInfo()
                if spellID then
                    CDM:AssignSpellToCustomBar(customIdx, #cData.spells + 1, spellID)
                    _G.ClearCursor()
                    RenderBarSettings()
                else
                    spellInput:SetFocus()
                end
            end

            dropZone:SetScript("OnReceiveDrag", HandleDropZone)
            dropZone:SetScript("OnClick", HandleDropZone)
            dropZone:SetScript("OnEnter", function(selfZone)
                selfZone:SetBackdropBorderColor(0, 0.9, 1, 1)
                selfZone:SetBackdropColor(0, 0.35, 0.5, 0.35)
            end)
            dropZone:SetScript("OnLeave", function(selfZone)
                selfZone:SetBackdropBorderColor(0, 0.6, 0.8, 0.7)
                selfZone:SetBackdropColor(0, 0.25, 0.35, 0.2)
            end)

            table.insert(contentFrame.widgets, dropZone)

            contentFrame.neededHeight = math.abs(dropZoneY) + 60
            contentFrame:SetHeight(math.max(500, contentFrame.neededHeight))
            if scrollFrame then scrollFrame:SetVerticalScroll(0) end

            return
        end

        btnDeleteBar:Hide()
        local vConf = CDM.db.viewers and CDM.db.viewers[bKey]
        if not vConf then return end

        if bKey == "BuffBar" then
            -- Column 1 (x=12): Bar Dimensions & Icon Settings
            local sWidth = CreateSlider(contentFrame, L["Bar Width"] or "Bar Width", 100, 400, 5,
                function() return vConf.barWidth or 220 end,
                function(val) vConf.barWidth = val; CDM:ApplyViewerConfig("BuffBar") end, -45, 12)
            table.insert(contentFrame.widgets, sWidth)

            local sHeight = CreateSlider(contentFrame, L["Bar Height"] or "Bar Height", 14, 50, 1,
                function() return vConf.barHeight or 24 end,
                function(val) vConf.barHeight = val; CDM:ApplyViewerConfig("BuffBar") end, -85, 12)
            table.insert(contentFrame.widgets, sHeight)

            local sSpacing = CreateSlider(contentFrame, L["Bar Spacing"] or "Bar Spacing", 0, 20, 1,
                function() return vConf.spacing or 4 end,
                function(val) vConf.spacing = val; CDM:ApplyViewerConfig("BuffBar") end, -125, 12)
            table.insert(contentFrame.widgets, sSpacing)

            local cbSquare = CreateCheckbox(contentFrame, L["Modern Square Corners"] or "Modern Square Corners",
                function() return vConf.squareCorners ~= false end,
                function(val) vConf.squareCorners = val; CDM:ApplyViewerConfig("BuffBar") end, 12, -165)
            table.insert(contentFrame.widgets, cbSquare)

            local cbShowIcon = CreateCheckbox(contentFrame, L["Show Icon"] or "Show Icon",
                function() return vConf.showIcon ~= false end,
                function(val) vConf.showIcon = val; CDM:ApplyViewerConfig("BuffBar") end, 12, -190)
            table.insert(contentFrame.widgets, cbShowIcon)

            local cbMatchHeight = CreateCheckbox(contentFrame, L["Icon Match Bar Height"] or "Icon Match Bar Height",
                function() return vConf.iconMatchBarHeight ~= false end,
                function(val)
                    vConf.iconMatchBarHeight = val
                    CDM:ApplyViewerConfig("BuffBar")
                    RenderBarSettings()
                end, 12, -215)
            table.insert(contentFrame.widgets, cbMatchHeight)

            if vConf.iconMatchBarHeight == false then
                local sIconSize = CreateSlider(contentFrame, L["Icon Size"] or "Icon Size", 14, 60, 1,
                    function() return vConf.iconSize or vConf.barHeight or 24 end,
                    function(val)
                        vConf.iconSize = val
                        vConf.iconWidth = val
                        vConf.iconHeight = val
                        CDM:ApplyViewerConfig("BuffBar")
                    end, -250, 12)
                table.insert(contentFrame.widgets, sIconSize)
            end

            -- Column 2 (x=188): Typography & Positions
            local cbName = CreateCheckbox(contentFrame, L["Show Ability Name"] or "Show Ability Name",
                function() return vConf.showName ~= false end,
                function(val) vConf.showName = val; CDM:ApplyViewerConfig("BuffBar") end, 188, -45)
            table.insert(contentFrame.widgets, cbName)

            local sNameFont = CreateSlider(contentFrame, L["Name Font Size"] or "Name Font Size", 8, 24, 1,
                function() return vConf.nameFontSize or 11 end,
                function(val) vConf.nameFontSize = val; CDM:ApplyViewerConfig("BuffBar") end, -85, 188)
            table.insert(contentFrame.widgets, sNameFont)

            local sNameX = CreateSlider(contentFrame, L["Name Offset X"] or "Name Offset X", -50, 50, 1,
                function() return vConf.nameOffsetX or 5 end,
                function(val) vConf.nameOffsetX = val; CDM:ApplyViewerConfig("BuffBar") end, -125, 188)
            table.insert(contentFrame.widgets, sNameX)

            local btnNamePos = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
            btnNamePos:SetSize(165, 22)
            btnNamePos:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 188, -165)
            StyleModernButton(btnNamePos, false)
            local function UpdateNamePosText()
                local pos = vConf.namePosition or "LEFT"
                btnNamePos:SetText(string.format("Name Pos: %s", pos))
            end
            UpdateNamePosText()
            btnNamePos:SetScript("OnClick", function()
                local cur = vConf.namePosition or "LEFT"
                if cur == "LEFT" then vConf.namePosition = "CENTER"
                elseif cur == "CENTER" then vConf.namePosition = "RIGHT"
                else vConf.namePosition = "LEFT" end
                UpdateNamePosText()
                CDM:ApplyViewerConfig("BuffBar")
            end)
            table.insert(contentFrame.widgets, btnNamePos)

            local cbTimer = CreateCheckbox(contentFrame, L["Show Duration Timer"] or "Show Duration Timer",
                function() return vConf.showTimer ~= false end,
                function(val) vConf.showTimer = val; CDM:ApplyViewerConfig("BuffBar") end, 188, -195)
            table.insert(contentFrame.widgets, cbTimer)

            local sTimerFont = CreateSlider(contentFrame, L["Timer Font Size"] or "Timer Font Size", 8, 24, 1,
                function() return vConf.timerFontSize or 11 end,
                function(val) vConf.timerFontSize = val; CDM:ApplyViewerConfig("BuffBar") end, -235, 188)
            table.insert(contentFrame.widgets, sTimerFont)

            local sTimerX = CreateSlider(contentFrame, L["Timer Offset X"] or "Timer Offset X", -50, 50, 1,
                function() return vConf.timerOffsetX or -8 end,
                function(val) vConf.timerOffsetX = val; CDM:ApplyViewerConfig("BuffBar") end, -275, 188)
            table.insert(contentFrame.widgets, sTimerX)

            local ddTimerPos = CreateAnchorDropdown(contentFrame, "Timer Pos",
                function() return vConf.timerPosition or "RIGHT" end,
                function(val)
                    vConf.timerPosition = val
                    CDM:ApplyViewerConfig("BuffBar")
                end, 188, -310, { "RIGHT", "LEFT", "CENTER" })
            table.insert(contentFrame.widgets, ddTimerPos)

            local ddGrowth = CreateAnchorDropdown(contentFrame, "Growth",
                function() return vConf.growthDirection or "DOWN" end,
                function(val)
                    vConf.growthDirection = val
                    CDM:ApplyViewerConfig("BuffBar")
                end, 188, -345, { "DOWN", "UP" })
            table.insert(contentFrame.widgets, ddGrowth)

            local cbOverrideGlobal = CreateCheckbox(contentFrame, L["Override Global Settings"] or "Override Global Settings",
                function() return vConf.overrideGlobal == true end,
                function(val)
                    vConf.overrideGlobal = val
                    CDM:ApplyViewerConfig("BuffBar")
                    RenderBarSettings()
                end, 188, -380)
            table.insert(contentFrame.widgets, cbOverrideGlobal)
        else
            -- Column 1: Sizing & Offsets
            local sSize = CreateSlider(contentFrame, L["Icon Size"] or "Icon Size", 20, 80, 2,
                function() return vConf.iconSize or 40 end,
                function(val) vConf.iconSize = val; CDM:ApplyViewerConfig(bKey) end, -45, 12)
            table.insert(contentFrame.widgets, sSize)

            local sSpacing = CreateSlider(contentFrame, L["Icon Spacing / Padding"] or "Icon Spacing / Padding", 0, 20, 1,
                function() return vConf.spacing or 0 end,
                function(val) vConf.spacing = val; CDM:ApplyViewerConfig(bKey) end, -85, 12)
            table.insert(contentFrame.widgets, sSpacing)

            local sStackX = CreateSlider(contentFrame, L["Stacks Offset X"] or "Stacks Offset X", -30, 30, 1,
                function() return vConf.stackOffsetX or CDM.db.stackOffsetX or -2 end,
                function(val) vConf.stackOffsetX = val; CDM:ApplyViewerConfig(bKey) end, -125, 12)
            table.insert(contentFrame.widgets, sStackX)

            local sStackY = CreateSlider(contentFrame, L["Stacks Offset Y"] or "Stacks Offset Y", -30, 30, 1,
                function() return vConf.stackOffsetY or CDM.db.stackOffsetY or 2 end,
                function(val) vConf.stackOffsetY = val; CDM:ApplyViewerConfig(bKey) end, -165, 12)
            table.insert(contentFrame.widgets, sStackY)

            local sCdX = CreateSlider(contentFrame, L["Timer Offset X"] or "Timer Offset X", -30, 30, 1,
                function() return vConf.cooldownOffsetX or CDM.db.cooldownOffsetX or 0 end,
                function(val) vConf.cooldownOffsetX = val; CDM:ApplyViewerConfig(bKey) end, -205, 12)
            table.insert(contentFrame.widgets, sCdX)

            local sCdY = CreateSlider(contentFrame, L["Timer Offset Y"] or "Timer Offset Y", -30, 30, 1,
                function() return vConf.cooldownOffsetY or CDM.db.cooldownOffsetY or 0 end,
                function(val) vConf.cooldownOffsetY = val; CDM:ApplyViewerConfig(bKey) end, -245, 12)
            table.insert(contentFrame.widgets, sCdY)

            -- Column 2 (x=188): Typography & Positions
            local sCdFont = CreateSlider(contentFrame, L["Cooldown Font Size"] or "Cooldown Font Size", 8, 28, 1,
                function() return vConf.cooldownFontSize or CDM.db.cooldownFontSize or 14 end,
                function(val) vConf.cooldownFontSize = val; CDM:ApplyViewerConfig(bKey) end, -45, 188)
            table.insert(contentFrame.widgets, sCdFont)

            local sStackFont = CreateSlider(contentFrame, L["Stack Font Size"] or "Stack Font Size", 8, 24, 1,
                function() return vConf.stackFontSize or CDM.db.stackFontSize or 11 end,
                function(val) vConf.stackFontSize = val; CDM:ApplyViewerConfig(bKey) end, -85, 188)
            table.insert(contentFrame.widgets, sStackFont)

            local ddStackPos = CreateAnchorDropdown(contentFrame, "Stack Pos",
                function() return vConf.stackAnchor or "BOTTOMRIGHT" end,
                function(val)
                    vConf.stackAnchor = val
                    CDM:ApplyViewerConfig(bKey)
                end, 188, -125)
            table.insert(contentFrame.widgets, ddStackPos)

            local ddTimerPos = CreateAnchorDropdown(contentFrame, "Timer Pos",
                function() return vConf.cooldownAnchor or "CENTER" end,
                function(val)
                    vConf.cooldownAnchor = val
                    CDM:ApplyViewerConfig(bKey)
                end, 188, -160)
            table.insert(contentFrame.widgets, ddTimerPos)

            local ddAlign = CreateAnchorDropdown(contentFrame, "Alignment",
                function() return vConf.align or "CENTER" end,
                function(val)
                    vConf.align = val
                    CDM:ApplyViewerConfig(bKey)
                end, 188, -195, { "CENTER", "LEFT", "RIGHT" })
            table.insert(contentFrame.widgets, ddAlign)

            local cbOverrideGlobal = CreateCheckbox(contentFrame, L["Override Global Settings"] or "Override Global Settings",
                function() return vConf.overrideGlobal == true end,
                function(val)
                    vConf.overrideGlobal = val
                    CDM:ApplyViewerConfig(bKey)
                    RenderBarSettings()
                end, 188, -230)
            table.insert(contentFrame.widgets, cbOverrideGlobal)

            local cbCenter = CreateCheckbox(contentFrame, L["Center Incomplete Rows"] or "Center Incomplete Rows",
                function() return vConf.centerIncompleteRows ~= false end,
                function(val) vConf.centerIncompleteRows = val; CDM:ApplyViewerConfig(bKey) end, 188, -260)
            table.insert(contentFrame.widgets, cbCenter)
        end

        contentFrame.neededHeight = 350
        contentFrame:SetHeight(500)
        if scrollFrame then scrollFrame:SetVerticalScroll(0) end
    end

    local function RebuildTabs()
        -- Rebuild Row 1 Native Tabs
        for _, b in ipairs(nativeTabButtons) do
            b:Hide()
            b:SetParent(nil)
        end
        nativeTabButtons = {}

        local xNative = 0
        for _, tabInfo in ipairs(nativeTabs) do
            local btn = CreateFrame("Button", nil, nativeContainer, "UIPanelButtonTemplate")
            btn:SetSize(tabInfo.width, 24)
            btn:SetPoint("LEFT", nativeContainer, "LEFT", xNative, 0)
            btn:SetText(tabInfo.text)
            StyleModernButton(btn, false)
            SetModernButtonActive(btn, panel.selectedBar == tabInfo.key)
            btn:SetScript("OnClick", function()
                panel.selectedBar = tabInfo.key
                customMenu:Hide()
                RebuildTabs()
                RenderBarSettings()
            end)
            table.insert(nativeTabButtons, btn)
            xNative = xNative + tabInfo.width + 4
        end

        -- Rebuild Row 2 Custom Toolbar
        local customList = CDM.GetCustomBars and CDM:GetCustomBars() or {}
        local hasCustom = #customList > 0
        local isCustomSelected = panel.selectedBar:find("^CustomBar") ~= nil

        if hasCustom then
            btnCustomDropdown:Show()
            btnCustomDropdown:ClearAllPoints()
            btnCustomDropdown:SetPoint("LEFT", customToolbar, "LEFT", 0, 0)

            local currentCustomName = "Custom Bars"
            if isCustomSelected then
                local cIdx = tonumber(panel.selectedBar:match("%d+"))
                if cIdx and customList[cIdx] then
                    currentCustomName = customList[cIdx].name or string.format("Bar %d", cIdx)
                end
            end
            btnCustomDropdown:SetText(currentCustomName)
            SetModernButtonActive(btnCustomDropdown, isCustomSelected)

            btnAddNewBar:ClearAllPoints()
            btnAddNewBar:SetPoint("LEFT", btnCustomDropdown, "RIGHT", 5, 0)

            btnDeleteBar:ClearAllPoints()
            btnDeleteBar:SetPoint("LEFT", btnAddNewBar, "RIGHT", 5, 0)
            if isCustomSelected then
                btnCustomDropdown:SetWidth(115)
                btnAddNewBar:SetWidth(115)
                btnDeleteBar:SetWidth(100)
                btnDeleteBar:Show()
            else
                btnCustomDropdown:SetWidth(120)
                btnAddNewBar:SetWidth(125)
                btnDeleteBar:Hide()
            end

            -- Populate custom menu items
            if customMenu.items then
                for _, itm in ipairs(customMenu.items) do
                    itm:Hide()
                    itm:SetParent(nil)
                end
            end
            customMenu.items = {}

            local mY = -4
            for idx, cInfo in ipairs(customList) do
                local mBtn = CreateFrame("Button", nil, customMenu, "UIPanelButtonTemplate")
                mBtn:SetSize(117, 22)
                mBtn:SetPoint("TOPLEFT", customMenu, "TOPLEFT", 4, mY)
                mBtn:SetText(cInfo.name or string.format("Bar %d", idx))
                StyleModernButton(mBtn, false)
                if panel.selectedBar == ("CustomBar" .. idx) then
                    SetModernButtonActive(mBtn, true)
                end
                mBtn:SetScript("OnClick", function()
                    panel.selectedBar = "CustomBar" .. idx
                    customMenu:Hide()
                    RebuildTabs()
                    RenderBarSettings()
                end)
                table.insert(customMenu.items, mBtn)
                mY = mY - 24
            end
            customMenu:SetHeight(math.abs(mY) + 4)

            btnCustomDropdown:SetScript("OnClick", function()
                if customMenu:IsShown() then
                    customMenu:Hide()
                else
                    customMenu:Show()
                end
            end)
        else
            btnCustomDropdown:Hide()
            customMenu:Hide()
            btnDeleteBar:Hide()
            btnAddNewBar:ClearAllPoints()
            btnAddNewBar:SetPoint("LEFT", customToolbar, "LEFT", 0, 0)
            btnAddNewBar:SetWidth(160)
        end
    end

    panel.RebuildTabs = RebuildTabs
    RebuildTabs()

    btnAddNewBar:SetScript("OnClick", function()
        if CDM.CreateCustomBar then
            local newIdx = CDM:CreateCustomBar()
            panel.selectedBar = "CustomBar" .. newIdx
            customMenu:Hide()
            RebuildTabs()
            RenderBarSettings()
        end
    end)

    btnDeleteBar:SetScript("OnClick", function()
        if CDM.DeleteCustomBar and panel.selectedBar:find("^CustomBar") then
            local idx = tonumber(panel.selectedBar:match("%d+"))
            if idx then
                CDM:DeleteCustomBar(idx)
                panel.selectedBar = "Essential"
                customMenu:Hide()
                RebuildTabs()
                RenderBarSettings()
            end
        end
    end)

    CDM.RefreshSettingsPanelSpells = RenderBarSettings
    panel.RefreshView = RenderBarSettings
    RenderBarSettings()
    panel.populated = true
end

function CDM:HookCooldownViewerSettings()
    if not _G.CooldownViewerSettings or self.settingsTabCreated then return end
    local parent = _G.CooldownViewerSettings
    local groupBuffsTab = parent.GroupBuffsTab
    if not groupBuffsTab then return end

    local lastTab = parent.GroupBuffsTab or parent.AurasTab or parent.SpellsTab
    local tab = CreateFrame("Button", "RoithiUI_CDM_SettingsTab", parent, "CooldownViewerSettingsTabTemplate")
    if not tab then
        tab = CreateFrame("Button", "RoithiUI_CDM_SettingsTab", parent, "LargeSideTabButtonTemplate")
    end
    tab:SetFrameStrata("HIGH")
    tab:ClearAllPoints()
    tab:SetPoint("TOP", lastTab, "BOTTOM", 0, -6)

    tab.tooltipText = "|cff00ccffRoithiUI|r " .. (L["Cooldown Manager"] or "Cooldown Manager")

    local activeAtlas = "GM-icon-settings"
    local inactiveAtlas = "GM-icon-settings"
    tab.activeAtlas = activeAtlas
    tab.inactiveAtlas = inactiveAtlas

    local function ApplyTabVisual(checked)
        if not tab.Icon then return end
        local atlas = checked and tab.activeAtlas or tab.inactiveAtlas
        local atlasOk = false
        if atlas and _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(atlas) then
            atlasOk = pcall(function() tab.Icon:SetAtlas(atlas, true) end)
        end
        if not atlasOk then
            if _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo("GM-icon-settings") then
                pcall(function() tab.Icon:SetAtlas("GM-icon-settings", true) end)
            else
                tab.Icon:SetTexture("Interface\\Icons\\INV_Gizmo_02")
                tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
        end
        tab.Icon:SetSize(28, 28)
        tab.Icon:ClearAllPoints()
        tab.Icon:SetPoint("CENTER", tab, "CENTER", -2, 0)
        if checked then
            tab.Icon:SetDesaturated(false)
            tab.Icon:SetVertexColor(0, 0.85, 1, 1)
        else
            tab.Icon:SetDesaturated(true)
            tab.Icon:SetVertexColor(0.7, 0.7, 0.7, 0.8)
        end
    end

    local origSetChecked = tab.SetChecked
    tab.SetChecked = function(selfTab, checked)
        if origSetChecked then
            origSetChecked(selfTab, checked)
        end
        ApplyTabVisual(checked)
    end
    ApplyTabVisual(false)

    local panel = CreateFrame("Frame", "RoithiUI_CDM_SettingsPanel", parent)
    if parent.Inset then
        panel:SetAllPoints(parent.Inset)
    else
        panel:SetAllPoints(parent)
    end
    panel:SetFrameLevel(parent:GetFrameLevel() + 5)
    panel:Hide()
    self.customSettingsPanel = panel

    tab:SetScript("OnEnter", function(btn)
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(tab.tooltipText or "|cff00ccffRoithiUI|r Cooldown Manager")
            _G.GameTooltip:Show()
        end
    end)
    tab:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)

    local function SwitchToRoithiPanel()
        parent.displayMode = "RoithiUI_CDM"
        if parent.SetTitle then
            parent:SetTitle("|cff00ccffRoithiUI|r " .. (L["Cooldown Settings"] or "Cooldown Settings"))
        elseif parent.TitleContainer and parent.TitleContainer.TitleText then
            parent.TitleContainer.TitleText:SetText("|cff00ccffRoithiUI|r " .. (L["Cooldown Settings"] or "Cooldown Settings"))
        end
        if parent.TabButtons then
            for _, frame in ipairs(parent.TabButtons) do
                if frame.SetChecked then frame:SetChecked(false) end
            end
        end
        if parent.SpellsTab and parent.SpellsTab.SetChecked then parent.SpellsTab:SetChecked(false) end
        if parent.AurasTab and parent.AurasTab.SetChecked then parent.AurasTab:SetChecked(false) end
        if parent.GroupBuffsTab and parent.GroupBuffsTab.SetChecked then parent.GroupBuffsTab:SetChecked(false) end
        if tab.SetChecked then tab:SetChecked(true) end
        if parent.SearchBox and parent.SearchBox.Hide then parent.SearchBox:Hide() end
        if parent.SettingsDropdown and parent.SettingsDropdown.Hide then parent.SettingsDropdown:Hide() end
        if parent.CooldownScroll and parent.CooldownScroll.Hide then parent.CooldownScroll:Hide() end
        if parent.GroupBuffFilter and parent.GroupBuffFilter.Hide then parent.GroupBuffFilter:Hide() end
        if _G.CooldownViewerSettingsEditAlert and _G.CooldownViewerSettingsEditAlert.Hide then
            _G.CooldownViewerSettingsEditAlert:Hide()
        end
        if _G.GroupBuffFilterEditVisualAlert and _G.GroupBuffFilterEditVisualAlert.Hide then
            _G.GroupBuffFilterEditVisualAlert:Hide()
        end
        panel:Show()
        CDM:PopulateSettingsPanel(panel)
        if CDM.InitializeAllCustomBars then
            CDM:InitializeAllCustomBars()
        end
    end

    tab:SetScript("OnClick", function()
        SwitchToRoithiPanel()
    end)

    local function RestoreBlizzardHeader()
        if parent.SetTitle and _G.COOLDOWN_VIEWER_SETTINGS_TITLE then
            parent:SetTitle(_G.COOLDOWN_VIEWER_SETTINGS_TITLE)
        end
        if parent.SearchBox and parent.SearchBox.Show then parent.SearchBox:Show() end
        if parent.SettingsDropdown and parent.SettingsDropdown.Show then parent.SettingsDropdown:Show() end
    end

    if parent.SetDisplayMode and hooksecurefunc and not self.settingsDisplayModeHooked then
        hooksecurefunc(parent, "SetDisplayMode", function()
            if panel:IsShown() then
                panel:Hide()
                RestoreBlizzardHeader()
            end
            if tab.SetChecked then
                tab:SetChecked(false)
            end
            if CDM.InitializeAllCustomBars then
                CDM:InitializeAllCustomBars()
            end
        end)
        self.settingsDisplayModeHooked = true
    end

    if parent.HookScript then
        parent:HookScript("OnHide", function()
            if panel:IsShown() then
                panel:Hide()
                RestoreBlizzardHeader()
            end
            if tab.SetChecked then tab:SetChecked(false) end
            if CDM.InitializeAllCustomBars then
                CDM:InitializeAllCustomBars()
            end
        end)
    end

    self.settingsTab = tab
    _G.RoithiUI_CDM_SettingsTab = tab
    self.settingsTabCreated = true
end

function CDM:OpenBlizzardSettings(fromEditMode)
    if InCombatLockdown() then
        RoithiUI:Print(L["Cannot open cooldown settings while in combat."] or "Cannot open cooldown settings while in combat.")
        return
    end
    if fromEditMode and _G.EditModeManagerFrame and _G.EditModeManagerFrame.CheckHideAndLockEditMode then
        _G.EditModeManagerFrame:CheckHideAndLockEditMode()
    end
    if C_AddOns and C_AddOns.LoadAddOn and not (C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer")) then
        pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownViewer")
    elseif _G.UIParentLoadAddOn and not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer")) then
        pcall(_G.UIParentLoadAddOn, "Blizzard_CooldownViewer")
    end
    if self.HookCooldownViewerSettings then
        self:HookCooldownViewerSettings()
    end
    if _G.CooldownViewerSettings then
        if _G.CooldownViewerSettings.ShowUIPanel then
            _G.CooldownViewerSettings:ShowUIPanel(false)
        elseif _G.CooldownViewerSettings.Show then
            _G.CooldownViewerSettings:Show()
        end
    else
        RoithiUI:Print(L["Blizzard Cooldown Viewer is not available."] or "Blizzard Cooldown Viewer is not available.")
    end
end

function CDM:SetupEditMode()
    local LEM = LibStub and LibStub("LibEditMode-Roithi", true)
    if not LEM then return end

    if not self.editModeButtonsRegistered and LEM.AddSystemSettingsButtons and _G.Enum and _G.Enum.EditModeSystem and _G.Enum.EditModeSystem.CooldownViewer then
        LEM:AddSystemSettingsButtons(Enum.EditModeSystem.CooldownViewer, {
            {
                text = L["RoithiUI Cooldown Settings"] or "RoithiUI Cooldown Settings",
                click = function()
                    if RoithiUI and RoithiUI.OpenSettings then
                        RoithiUI:OpenSettings("cooldownmanager")
                    elseif LibStub and LibStub("AceConfigDialog-3.0", true) then
                        local ACD = LibStub("AceConfigDialog-3.0", true)
                        ACD:SelectGroup("RoithiUI", "combat", "cooldownmanager")
                        ACD:Open("RoithiUI")
                    end
                end,
            },
            {
                text = L["Create / Edit Bars"] or "Create / Edit Bars",
                click = function()
                    CDM:OpenBlizzardSettings(true)
                end,
            },
        })
        self.editModeButtonsRegistered = true
    end

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.roithiEditModeCallbacksRegistered then
        _G.EventRegistry:RegisterCallback("EditMode.Enter", function()
            if CDM.InitializeAllCustomBars then CDM:InitializeAllCustomBars() end
        end, CDM)
        _G.EventRegistry:RegisterCallback("EditMode.Exit", function()
            if CDM.InitializeAllCustomBars then CDM:InitializeAllCustomBars() end
            if not InCombatLockdown() and CDM:IsEnabled() and CDM.db and CDM.db.enabled ~= false then
                CDM:StyleAllActiveItems()
                for vKey, gName in pairs(CDM.VIEWER_KEYS) do
                    local v = _G[gName]
                    if v then CDM:CenterIncompleteRows(vKey, v) end
                end
            end
        end, CDM)
        self.roithiEditModeCallbacksRegistered = true
    end
end

function CDM:AlignViewerItems(viewerKey, viewer)
    if InCombatLockdown() then return end
    if not viewer or not self.db then return end

    local vConf = self.db.viewers and self.db.viewers[viewerKey]

    if viewerKey == "BuffBar" then
        local growthDir = (vConf and vConf.growthDirection) or "DOWN"
        if growthDir == "UP" then
            if not viewer.itemFramePool or not viewer.itemFramePool.EnumerateActive then return end
            local items = {}
            for itemFrame in viewer.itemFramePool:EnumerateActive() do
                if itemFrame:IsShown() then
                    table.insert(items, itemFrame)
                end
            end
            if #items <= 1 then return end
            table.sort(items, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
            local container = (viewer.GetItemContainerFrame and viewer:GetItemContainerFrame()) or viewer
            local barHeight = (vConf and vConf.barHeight) or (items[1].Bar and items[1].Bar:GetHeight()) or 24
            local spacing = (vConf and vConf.spacing) or 4
            local pitch = barHeight + spacing
            for idx, itemFrame in ipairs(items) do
                local numPoints = itemFrame:GetNumPoints()
                if numPoints and numPoints > 0 then
                    local _, relTo, _, x, _ = itemFrame:GetPoint(1)
                    itemFrame:ClearAllPoints()
                    itemFrame:SetPoint("BOTTOMLEFT", relTo or container, "BOTTOMLEFT", x or 0, (idx - 1) * pitch)
                end
            end
        end
        return
    end

    local shouldCenter = true
    if self.db.centerIncompleteRows ~= nil then
        shouldCenter = self.db.centerIncompleteRows
    end
    if vConf and vConf.centerIncompleteRows ~= nil then
        shouldCenter = vConf.centerIncompleteRows
    end

    if not viewer.itemFramePool or not viewer.itemFramePool.EnumerateActive then return end

    local container = (viewer.GetItemContainerFrame and viewer:GetItemContainerFrame()) or viewer
    local isHorizontal = true
    if viewer.IsHorizontal then
        isHorizontal = viewer:IsHorizontal()
    elseif container.isHorizontal ~= nil then
        isHorizontal = container.isHorizontal
    end

    local items = {}
    for itemFrame in viewer.itemFramePool:EnumerateActive() do
        if itemFrame:IsShown() then
            table.insert(items, itemFrame)
        end
    end
    if #items == 0 then return end

    table.sort(items, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    local stride = container.stride or (viewer.GetStride and viewer:GetStride()) or viewer.stride or 0
    if stride <= 0 then
        stride = #items
    end

    local align = (vConf and vConf.align) or "CENTER"

    -- BuffIcon single row alignment & centering
    if viewerKey == "BuffIcon" then
        if align == "CENTER" or align == "RIGHT" then
            local firstItem = items[1]
            local itemW = (vConf and vConf.iconSize) or firstItem:GetWidth() or 40
            local spacing = (vConf and vConf.spacing) or (container.childXPadding or 0)
            local pitch = itemW + spacing
            local totalW = (#items * itemW) + math.max(0, #items - 1) * spacing
            local cW = container:GetWidth() or 0
            if cW > 0 then
                local shift = (align == "CENTER") and ((cW - totalW) / 2) or (cW - totalW)
                for idx, itemFrame in ipairs(items) do
                    local numPoints = itemFrame:GetNumPoints()
                    if numPoints and numPoints > 0 then
                        local point, relTo, relPoint, _, y = itemFrame:GetPoint(1)
                        if point and y then
                            itemFrame:ClearAllPoints()
                            itemFrame:SetPoint(point, relTo, relPoint, shift + (idx - 1) * pitch, y)
                        end
                    end
                end
            end
        end
        return
    end

    if #items <= 1 then return end
    if not shouldCenter then return end

    local lines = {}
    local currentLine = {}
    for i, itemFrame in ipairs(items) do
        table.insert(currentLine, itemFrame)
        if #currentLine == stride or i == #items then
            table.insert(lines, currentLine)
            currentLine = {}
        end
    end
    if #lines <= 1 and #items <= stride then
        return
    end

    local maxCount = 0
    for _, line in ipairs(lines) do
        if #line > maxCount then
            maxCount = #line
        end
    end
    if maxCount <= 0 then return end

    if isHorizontal then
        local firstItem = items[1]
        local itemW = (vConf and vConf.iconSize) or firstItem:GetWidth()
        if not itemW or itemW <= 0 then
            itemW = 40
        end
        local spacing = (vConf and vConf.spacing)
        if spacing == nil then
            spacing = container.childXPadding or 0
        end
        local pitch = itemW + spacing
        local mult = (container.layoutFramesGoingRight == false) and -1 or 1

        for _, line in ipairs(lines) do
            local count = #line
            if count < maxCount then
                local xShift = mult * ((maxCount - count) * pitch) / 2
                for idx, itemFrame in ipairs(line) do
                    local numPoints = itemFrame:GetNumPoints()
                    if numPoints and numPoints > 0 then
                        local point, relTo, relPoint, _, y = itemFrame:GetPoint(1)
                        if point and y then
                            local xFinal = mult * ((idx - 1) * pitch) + xShift
                            itemFrame:ClearAllPoints()
                            itemFrame:SetPoint(point, relTo, relPoint, xFinal, y)
                        end
                    end
                end
            end
        end
    else
        local firstItem = items[1]
        local itemH = (vConf and vConf.iconSize) or firstItem:GetHeight()
        if not itemH or itemH <= 0 then
            itemH = 40
        end
        local spacing = (vConf and vConf.spacing)
        if spacing == nil then
            spacing = container.childYPadding or 0
        end
        local pitch = itemH + spacing
        local mult = container.layoutFramesGoingUp and 1 or -1

        for _, line in ipairs(lines) do
            local count = #line
            if count < maxCount then
                local yShift = mult * ((maxCount - count) * pitch) / 2
                for idx, itemFrame in ipairs(line) do
                    local numPoints = itemFrame:GetNumPoints()
                    if numPoints and numPoints > 0 then
                        local point, relTo, relPoint, x, _ = itemFrame:GetPoint(1)
                        if point and x then
                            local yFinal = mult * ((idx - 1) * pitch) + yShift
                            itemFrame:ClearAllPoints()
                            itemFrame:SetPoint(point, relTo, relPoint, x, yFinal)
                        end
                    end
                end
            end
        end
    end
end
CDM.CenterIncompleteRows = CDM.AlignViewerItems

function CDM:OnViewerLayoutRefreshed(viewerKey, viewer)
    if not viewer or not viewer.itemFramePool then return end
    if viewer.itemFramePool.EnumerateActive then
        for itemFrame in viewer.itemFramePool:EnumerateActive() do
            self:StyleItemFrame(viewerKey, itemFrame)
        end
    end
    self:CenterIncompleteRows(viewerKey, viewer)
end

function CDM:ApplyViewerConfig(viewerKey)
    if InCombatLockdown() then return end
    if not viewerKey or not self.VIEWER_KEYS then return end
    local globalName = self.VIEWER_KEYS[viewerKey]
    if not globalName then return end
    local viewer = _G[globalName]
    if not viewer then return end

    local vConf = self.db and self.db.viewers and self.db.viewers[viewerKey]
    local spacing = vConf and vConf.spacing
    local container = (viewer.GetItemContainerFrame and viewer:GetItemContainerFrame()) or viewer

    if spacing ~= nil then
        if container then
            container.childXPadding = spacing
            container.childYPadding = spacing
        end
        viewer.childXPadding = spacing
        viewer.childYPadding = spacing
    end

    if viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
        for itemFrame in viewer.itemFramePool:EnumerateActive() do
            self:StyleItemFrame(viewerKey, itemFrame)
        end
    end

    self:CenterIncompleteRows(viewerKey, viewer)
end

function CDM:RefreshAllViewerLayouts()
    for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
        local viewer = _G[globalName]
        if viewer then
            self:ApplyViewerConfig(viewerKey)
        end
    end
end

function CDM:StyleAllActiveItems()
    for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
        local viewer = _G[globalName]
        if viewer and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
            for itemFrame in viewer.itemFramePool:EnumerateActive() do
                self:StyleItemFrame(viewerKey, itemFrame)
            end
        end
    end
end

function CDM:RestoreAllItems()
    for viewerKey, globalName in pairs(self.VIEWER_KEYS) do
        local viewer = _G[globalName]
        if viewer and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
            for itemFrame in viewer.itemFramePool:EnumerateActive() do
                self:RestoreItemFrame(itemFrame)
            end
        end
    end
end

function CDM:RefreshProfile()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CooldownManager or self.defaultSettings
    self:RefreshAllViewerLayouts()
    self:StyleAllActiveItems()
end
CDM.RefreshSettings = CDM.RefreshProfile
