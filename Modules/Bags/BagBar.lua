local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local BagsMod = RoithiUI:GetModule("Bags")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode-Roithi", true)

local REGULAR_BAG_SLOTS = {
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
}

function BagsMod:SetBagButtonsMouse(enable)
    local allButtons = {
        _G.MainMenuBarBackpackButton,
        _G.KeyRingButton,
        _G.CharacterReagentBag0Slot,
        self.expanderButton,
    }
    for _, name in ipairs(REGULAR_BAG_SLOTS) do
        table.insert(allButtons, _G[name])
    end
    for _, btn in ipairs(allButtons) do
        if btn and btn.EnableMouse then
            btn:EnableMouse(enable)
        end
    end
    if self.bagBarFrame and LEM and LEM.frameSelections and LEM.frameSelections[self.bagBarFrame] then
        local sel = LEM.frameSelections[self.bagBarFrame]
        if sel then
            if sel.SetFrameLevel then sel:SetFrameLevel(self.bagBarFrame:GetFrameLevel() + 100) end
            if sel.EnableMouse then sel:EnableMouse(not enable) end
        end
    end
end

function BagsMod:SetupBagBar()
    if self.bagBarFrame then return end

    local function SuppressBagsBarSelection()
        if _G.BagsBar then
            _G.BagsBar.defaultHideSelection = true
            if _G.BagsBar.Selection then
                _G.BagsBar.Selection:Hide()
                if _G.BagsBar.Selection.EnableMouse then _G.BagsBar.Selection:EnableMouse(false) end
            end
        end
        if self.bagBarFrame and LEM and LEM.frameSelections and LEM.frameSelections[self.bagBarFrame] then
            local sel = LEM.frameSelections[self.bagBarFrame]
            local isEditMode = (LEM and LEM.IsInEditMode and LEM:IsInEditMode()) or false
            if sel.SetFrameLevel then sel:SetFrameLevel(self.bagBarFrame:GetFrameLevel() + 50) end
            if sel.EnableMouse then sel:EnableMouse(isEditMode) end
        end
    end

    if _G.BagsBar then
        SuppressBagsBarSelection()
        if _G.BagsBar.SetAlpha then _G.BagsBar:SetAlpha(0) end
        if _G.BagsBar.EnableMouse then _G.BagsBar:EnableMouse(false) end
        for _, reg in ipairs({ _G.BagsBar:GetRegions() }) do
            if reg.IsObjectType and reg:IsObjectType("Texture") then
                reg:SetAlpha(0)
            end
        end
        if _G.BagBarExpandToggle then
            _G.BagBarExpandToggle:Hide()
            _G.BagBarExpandToggle:SetAlpha(0)
            if _G.BagBarExpandToggle.EnableMouse then _G.BagBarExpandToggle:EnableMouse(false) end
        end
    end

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.bagBarEventsRegistered then
        _G.EventRegistry:RegisterCallback("EditMode.Enter", SuppressBagsBarSelection, self)
        _G.EventRegistry:RegisterCallback("MainMenuBarManager.OnExpandChanged", function()
            if self.db and self.db.enabled ~= false and self.UpdateBagBarLayout then
                self:UpdateBagBarLayout()
            end
        end, self)
        self.bagBarEventsRegistered = true
    end

    if _G.MainMenuBarBagManager and not self.bagManagerHooked and hooksecurefunc then
        if _G.MainMenuBarBagManager.OnExpandBarChanged then
            hooksecurefunc(_G.MainMenuBarBagManager, "OnExpandBarChanged", function()
                if self.db and self.db.enabled ~= false and self.UpdateBagBarLayout then
                    self:UpdateBagBarLayout()
                end
            end)
        end
        self.bagManagerHooked = true
    end

    if _G.BagsBar and not self.bagsBarHooked and hooksecurefunc then
        if _G.BagsBar.Layout then
            hooksecurefunc(_G.BagsBar, "Layout", function()
                if self.db and self.db.enabled ~= false and self.UpdateBagBarLayout then
                    self:UpdateBagBarLayout()
                end
            end)
        end
        self.bagsBarHooked = true
    end

    if _G.UIParent_ManageFramePositions and not self.managePositionsHooked and hooksecurefunc then
        hooksecurefunc("UIParent_ManageFramePositions", function()
            if self.db and self.db.enabled ~= false and self.UpdateBagBarLayout then
                self:UpdateBagBarLayout()
            end
        end)
        self.managePositionsHooked = true
    end

    if not self.bagBarAddonLoadedRegistered then
        if self.RegisterEvent then
            self:RegisterEvent("ADDON_LOADED", function(_, loadedAddon)
                if loadedAddon == "Blizzard_MainMenuBarBagButtons" then
                    if self.db and self.db.enabled ~= false then
                        self:StyleBagButtons()
                        self:UpdateBagBarLayout()
                    end
                end
            end)
        end
        self.bagBarAddonLoadedRegistered = true
    end

    local cfg = self.db.bagBar or self.defaultSettings.bagBar

    local bar = CreateFrame("Frame", "RoithiBagBar", UIParent)
    if bar.SetClampedToScreen then bar:SetClampedToScreen(true) end
    if bar.SetMovable then bar:SetMovable(true) end
    if bar.SetFrameStrata then bar:SetFrameStrata("HIGH") end

    local btnSize = cfg.buttonSize or 30
    local spacing = cfg.spacing or 4
    local initialW = btnSize + 14 + spacing
    if bar.SetSize then bar:SetSize(initialW, btnSize) end

    local pt = cfg.point or "BOTTOMLEFT"
    if bar.ClearAllPoints then bar:ClearAllPoints() end
    if bar.SetPoint then bar:SetPoint(pt, UIParent, pt, cfg.x or 10, cfg.y or 285) end

    self.bagBarFrame = bar

    if LEM and LEM.AddFrame then
        bar.editModeName = L["Bag Bar"]
        local defaults = { point = pt, x = cfg.x or 10, y = cfg.y or 285 }
        LEM:AddFrame(bar, function(f, _, newPoint, newX, newY)
            self.db.bagBar = self.db.bagBar or {}
            self.db.bagBar.point = newPoint
            self.db.bagBar.x = newX
            self.db.bagBar.y = newY
            if f and f.ClearAllPoints and f.SetPoint then
                f:ClearAllPoints()
                f:SetPoint(newPoint, UIParent, newPoint, newX, newY)
            end
            self:UpdateBagBarLayout()
        end, defaults)
        if LEM.frameSelections and LEM.frameSelections[bar] then
            local sel = LEM.frameSelections[bar]
            local isEditMode = (LEM and LEM.IsInEditMode and LEM:IsInEditMode()) or false
            if sel.SetFrameLevel then sel:SetFrameLevel(bar:GetFrameLevel() + 100) end
            if sel.EnableMouse then sel:EnableMouse(isEditMode) end
        end

        if LEM.AddFrameSettings then
            local sliderType = (LEM.SettingType and LEM.SettingType.Slider) or 2
            local settings = {
                {
                    name = L["X Position"],
                    kind = sliderType,
                    minValue = -2500,
                    maxValue = 2500,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db.bagBar and self.db.bagBar.x or 10 end,
                    set = function(_, val)
                        self.db.bagBar = self.db.bagBar or {}
                        self.db.bagBar.x = val
                        local p = self.db.bagBar.point or "BOTTOMLEFT"
                        bar:ClearAllPoints()
                        bar:SetPoint(p, UIParent, p, val, self.db.bagBar.y or 285)
                        self:UpdateBagBarLayout()
                    end,
                },
                {
                    name = L["Y Position"],
                    kind = sliderType,
                    minValue = -1500,
                    maxValue = 1500,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db.bagBar and self.db.bagBar.y or 285 end,
                    set = function(_, val)
                        self.db.bagBar = self.db.bagBar or {}
                        self.db.bagBar.y = val
                        local p = self.db.bagBar.point or "BOTTOMLEFT"
                        bar:ClearAllPoints()
                        bar:SetPoint(p, UIParent, p, self.db.bagBar.x or 10, val)
                        self:UpdateBagBarLayout()
                    end,
                },
                {
                    name = L["Button Size"],
                    kind = sliderType,
                    minValue = 20,
                    maxValue = 48,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db.bagBar and self.db.bagBar.buttonSize or 30 end,
                    set = function(_, val)
                        self.db.bagBar = self.db.bagBar or {}
                        self.db.bagBar.buttonSize = val
                        self:UpdateBagBarLayout()
                    end,
                },
                {
                    name = L["Button Spacing"],
                    kind = sliderType,
                    minValue = 0,
                    maxValue = 12,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db.bagBar and self.db.bagBar.spacing or 4 end,
                    set = function(_, val)
                        self.db.bagBar = self.db.bagBar or {}
                        self.db.bagBar.spacing = val
                        self:UpdateBagBarLayout()
                    end,
                },
            }
            LEM:AddFrameSettings(bar, settings)
        end
        if LEM.AddFrameSettingsButtons then
            LEM:AddFrameSettingsButtons(bar, {
                {
                    text = L["Open Full Settings"] or "Open Full Settings",
                    click = function()
                        if RoithiUI and RoithiUI.OpenSettings then
                            RoithiUI:OpenSettings("bags")
                        elseif LibStub("AceConfigDialog-3.0") then
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "interface_group", "bags")
                            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                        end
                    end,
                },
            })
        end
    end

    if not self.editModeBagHooked then
        if _G.EventRegistry and _G.EventRegistry.RegisterCallback then
            _G.EventRegistry:RegisterCallback("EditMode.Enter", function() self:SetBagButtonsMouse(false) end, self)
            _G.EventRegistry:RegisterCallback("EditMode.Exit", function() self:SetBagButtonsMouse(true) end, self)
        end
        if LEM and LEM.RegisterCallback then
            LEM:RegisterCallback("enter", function() self:SetBagButtonsMouse(false) end)
            LEM:RegisterCallback("exit", function() self:SetBagButtonsMouse(true) end)
        elseif LEM and LEM.anonCallbacksEnter and LEM.anonCallbacksExit then
            table.insert(LEM.anonCallbacksEnter, function() self:SetBagButtonsMouse(false) end)
            table.insert(LEM.anonCallbacksExit, function() self:SetBagButtonsMouse(true) end)
        end
        self.editModeBagHooked = true
    end

    self:CreateBagBarExpander()
    self:StyleBagButtons()
    self:UpdateBagBarLayout()
end

function BagsMod:CreateBagBarExpander()
    if self.expanderButton or not self.bagBarFrame then return end

    local expander = CreateFrame("Button", "RoithiBagBarExpander", self.bagBarFrame, "BackdropTemplate")
    local cfg = self.db.bagBar or self.defaultSettings.bagBar
    local btnSize = cfg.buttonSize or 30
    expander:SetSize(14, btnSize)

    if expander.SetBackdrop then
        expander:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeSize = 1,
        })
        expander:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        expander:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end

    local text = expander:CreateFontString(nil, "OVERLAY")
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 10, "OUTLINE")
    end
    text:ClearAllPoints()
    text:SetPoint("CENTER", expander, "CENTER", 0, 0)
    if text.SetJustifyH then text:SetJustifyH("CENTER") end
    if text.SetJustifyV then text:SetJustifyV("MIDDLE") end
    if text.SetTextColor then text:SetTextColor(0.8, 0.8, 0.8, 1) end

    local isExpanded = (cfg and cfg.expanded == true) or false
    text:SetText(isExpanded and "<" or ">")
    expander.arrow = text

    expander:SetScript("OnClick", function()
        self.db.bagBar = self.db.bagBar or {}
        self.db.bagBar.expanded = not self.db.bagBar.expanded
        local expanded = self.db.bagBar.expanded
        if expander.arrow then
            expander.arrow:SetText(expanded and "<" or ">")
        end
        self:UpdateBagBarLayout()
    end)

    expander:SetScript("OnEnter", function()
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(expander, "ANCHOR_LEFT")
            local isExp = self.db.bagBar and (self.db.bagBar.expanded == true)
            _G.GameTooltip:SetText(isExp and L["Click to collapse bags"] or L["Click to expand bags"], 1, 1, 1)
            _G.GameTooltip:Show()
        end
    end)
    expander:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)

    self.expanderButton = expander
end

function BagsMod:StyleExpandToggle(toggleBtn)
    if not toggleBtn then return end
    if not toggleBtn.roithiBackdrop then
        local bg = CreateFrame("Frame", nil, toggleBtn, "BackdropTemplate")
        if bg.SetAllPoints then bg:SetAllPoints(toggleBtn) end
        if bg.SetFrameLevel and toggleBtn.GetFrameLevel then
            bg:SetFrameLevel(math.max(0, toggleBtn:GetFrameLevel() - 1))
        end
        if bg.SetBackdrop then
            bg:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            bg:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
            bg:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
        end
        toggleBtn.roithiBackdrop = bg
    end
end

function BagsMod:UpdateBagButtonVisual(btn)
    if not btn then return end
    local icon = btn.icon or btn.Icon or _G[btn.GetName and btn:GetName() and (btn:GetName() .. "IconTexture")]
    if not icon and btn.CreateTexture then
        icon = btn:CreateTexture(nil, "BORDER")
        btn.icon = icon
    end
    if not icon then return end

    -- Strip all circular masks from icon
    if icon.GetMaskTextures then
        for _, mask in ipairs({ icon:GetMaskTextures() }) do
            if icon.RemoveMaskTexture then icon:RemoveMaskTexture(mask) end
        end
    end
    if btn.CircleMask and icon.RemoveMaskTexture then
        icon:RemoveMaskTexture(btn.CircleMask)
    end
    if btn.CircleMask and btn.CircleMask.Hide then
        btn.CircleMask:Hide()
    end

    if icon.ClearAllPoints then icon:ClearAllPoints() end
    if icon.SetPoint then
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    end
    if icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    local btnName = btn.GetName and btn:GetName() or ""
    if btn == _G.MainMenuBarBackpackButton or btnName == "MainMenuBarBackpackButton" then
        if icon.SetTexture then icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up") end
        if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
        if icon.SetAlpha then icon:SetAlpha(1) end
        if icon.Show then icon:Show() end
    elseif btn == _G.KeyRingButton or btnName == "KeyRingButton" then
        if icon.SetTexture then icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03") end
        if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
        if icon.SetAlpha then icon:SetAlpha(1) end
        if icon.Show then icon:Show() end
    elseif btn == _G.CharacterReagentBag0Slot or btnName == "CharacterReagentBag0Slot" then
        local invID = btn.GetID and btn:GetID()
        local hasItem = invID and _G.GetInventoryItemTexture and _G.GetInventoryItemTexture("player", invID)
        if hasItem then
            if icon.SetTexture then icon:SetTexture(hasItem) end
            if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
        else
            if icon.SetTexture then icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag") end
            if icon.SetVertexColor then icon:SetVertexColor(0.25, 0.5, 0.6, 0.65) end
        end
        if icon.SetAlpha then icon:SetAlpha(1) end
        if icon.Show then icon:Show() end
    else
        local invID = btn.GetID and btn:GetID()
        local hasItem = invID and _G.GetInventoryItemTexture and _G.GetInventoryItemTexture("player", invID)
        if hasItem then
            if icon.SetTexture then icon:SetTexture(hasItem) end
            if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
        else
            if icon.SetTexture then icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag") end
            if icon.SetVertexColor then icon:SetVertexColor(0.35, 0.35, 0.35, 0.6) end
        end
        if icon.SetAlpha then icon:SetAlpha(1) end
        if icon.Show then icon:Show() end
    end
end

function BagsMod:StyleBagButton(btn)
    if not btn then return end

    -- Hide circular mask
    if btn.CircleMask and btn.CircleMask.Hide then
        btn.CircleMask:Hide()
    end
    if btn.SlotHighlightTexture then
        if btn.SlotHighlightTexture.SetTexture then btn.SlotHighlightTexture:SetTexture(nil) end
        if btn.SlotHighlightTexture.SetAlpha then btn.SlotHighlightTexture:SetAlpha(0) end
        if btn.SlotHighlightTexture.Hide then btn.SlotHighlightTexture:Hide() end
    end

    local icon = btn.icon or btn.Icon or _G[btn.GetName and btn:GetName() and (btn:GetName() .. "IconTexture")]
    if not icon and btn.CreateTexture then
        icon = btn:CreateTexture(nil, "BORDER")
        btn.icon = icon
    end

    -- Remove any mask textures attached to the icon
    if icon and icon.GetMaskTextures then
        for _, mask in ipairs({ icon:GetMaskTextures() }) do
            if icon.RemoveMaskTexture then icon:RemoveMaskTexture(mask) end
        end
    end
    if icon and btn.CircleMask and icon.RemoveMaskTexture then
        icon:RemoveMaskTexture(btn.CircleMask)
    end

    -- Hide native borders, circular rings, and atlases without touching icon
    for _, region in ipairs({ btn:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") and region ~= icon then
            local isStripped = false
            local tex = region.GetTexture and region:GetTexture()
            if type(tex) == "string" then
                local texPath = tex:lower()
                if texPath:find("border") or texPath:find("normal") or texPath:find("slot") or texPath:find("glow") or texPath:find("ring") then
                    region:SetAlpha(0)
                    if region.SetTexture then region:SetTexture(nil) end
                    isStripped = true
                end
            end
            local atlas = region.GetAtlas and region:GetAtlas()
            if not isStripped and type(atlas) == "string" then
                local atlasStr = atlas:lower()
                if atlasStr:find("border") or atlasStr:find("normal") or atlasStr:find("slot") or atlasStr:find("glow") or atlasStr:find("ring") or atlasStr:find("bag%-") or atlasStr:find("main") then
                    region:SetAlpha(0)
                    if region.SetTexture then region:SetTexture(nil) end
                end
            end
        end
    end

    local norm = btn.GetNormalTexture and btn:GetNormalTexture()
    if norm then
        if norm.SetTexture then norm:SetTexture(nil) end
        if norm.SetAlpha then norm:SetAlpha(0) end
    end
    local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
    if pushed then
        if pushed.SetTexture then pushed:SetTexture(nil) end
        if pushed.SetAlpha then pushed:SetAlpha(0) end
    end
    local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if hl then
        if hl.SetColorTexture then hl:SetColorTexture(1, 1, 1, 0.2) end
        if hl.SetAllPoints then hl:SetAllPoints(btn) end
    end

    -- Hook UpdateTextures so Blizzard does not re-apply circular atlases over our styled square button
    if not btn.roithiTexturesHooked and btn.UpdateTextures then
        hooksecurefunc(btn, "UpdateTextures", function(selfBtn)
            local n = selfBtn.GetNormalTexture and selfBtn:GetNormalTexture()
            if n then
                if n.SetTexture then n:SetTexture(nil) end
                if n.SetAlpha then n:SetAlpha(0) end
            end
            local p = selfBtn.GetPushedTexture and selfBtn:GetPushedTexture()
            if p then
                if p.SetTexture then p:SetTexture(nil) end
                if p.SetAlpha then p:SetAlpha(0) end
            end
            if selfBtn.SlotHighlightTexture then
                if selfBtn.SlotHighlightTexture.SetTexture then selfBtn.SlotHighlightTexture:SetTexture(nil) end
                if selfBtn.SlotHighlightTexture.SetAlpha then selfBtn.SlotHighlightTexture:SetAlpha(0) end
                if selfBtn.SlotHighlightTexture.Hide then selfBtn.SlotHighlightTexture:Hide() end
            end
            if selfBtn.CircleMask and selfBtn.CircleMask.Hide then selfBtn.CircleMask:Hide() end
            BagsMod:UpdateBagButtonVisual(selfBtn)
        end)
        btn.roithiTexturesHooked = true
    end

    -- 1px dark backdrop
    if not btn.roithiBackdrop then
        local bg = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        if bg.SetAllPoints then bg:SetAllPoints(btn) end
        if bg.SetFrameLevel and btn.GetFrameLevel then
            bg:SetFrameLevel(math.max(0, btn:GetFrameLevel() - 1))
        end
        if bg.SetBackdrop then
            bg:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            bg:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
            bg:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
        end
        btn.roithiBackdrop = bg
    else
        if btn.roithiBackdrop.SetBackdropColor then
            btn.roithiBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
            btn.roithiBackdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
        end
        if btn.roithiBackdrop.Show then btn.roithiBackdrop:Show() end
    end

    self:UpdateBagButtonVisual(btn)
end

function BagsMod:UpdateBagButtonsVisual()
    local allButtons = {
        _G.MainMenuBarBackpackButton,
        _G.KeyRingButton,
        _G.CharacterReagentBag0Slot,
    }
    for _, name in ipairs(REGULAR_BAG_SLOTS) do
        table.insert(allButtons, _G[name])
    end

    if _G.MainMenuBarBagManager and _G.MainMenuBarBagManager.EnumerateBagButtons then
        for _, btn in _G.MainMenuBarBagManager:EnumerateBagButtons() do
            table.insert(allButtons, btn)
        end
    end

    for _, btn in ipairs(allButtons) do
        if btn then
            self:UpdateBagButtonVisual(btn)
        end
    end
end

function BagsMod:StyleBagButtons()
    local allButtons = {
        _G.MainMenuBarBackpackButton,
        _G.KeyRingButton,
        _G.CharacterReagentBag0Slot,
    }
    for _, name in ipairs(REGULAR_BAG_SLOTS) do
        table.insert(allButtons, _G[name])
    end

    if _G.MainMenuBarBagManager and _G.MainMenuBarBagManager.EnumerateBagButtons then
        for _, btn in _G.MainMenuBarBagManager:EnumerateBagButtons() do
            table.insert(allButtons, btn)
        end
    end

    for _, btn in ipairs(allButtons) do
        if btn then
            self:StyleBagButton(btn)
        end
    end

    if _G.MainMenuBarBackpackButton and not self.backpackSlotHooked and _G.MainMenuBarBackpackButton.HookScript then
        _G.MainMenuBarBackpackButton:HookScript("OnClick", function()
            if self.db and self.db.enabled ~= false then
                self:ToggleBags("ALL")
            end
        end)
        self.backpackSlotHooked = true
    end

    for _, name in ipairs(REGULAR_BAG_SLOTS) do
        local btn = _G[name]
        if btn and not btn.roithiBagHooked and btn.HookScript then
            btn:HookScript("OnClick", function()
                if self.db and self.db.enabled ~= false then
                    self:ToggleBags("ALL")
                end
            end)
            btn.roithiBagHooked = true
        end
    end

    if _G.CharacterReagentBag0Slot and not self.reagentSlotHooked and _G.CharacterReagentBag0Slot.HookScript then
        _G.CharacterReagentBag0Slot:HookScript("OnClick", function()
            if self.db and self.db.enabled ~= false and self.OpenCategory then
                self:OpenCategory("REAGENTS")
            end
        end)
        self.reagentSlotHooked = true
    end

    if _G.KeyRingButton and not self.keyRingSlotHooked and _G.KeyRingButton.HookScript then
        _G.KeyRingButton:HookScript("OnClick", function()
            if self.db and self.db.enabled ~= false and self.OpenCategory then
                self:OpenCategory("KEYRING")
            end
        end)
        self.keyRingSlotHooked = true
    end
end

function BagsMod:RestoreBlizzardBagBar()
    if _G.BagsBar then
        if _G.BagsBar.SetAlpha then _G.BagsBar:SetAlpha(1) end
        if _G.BagsBar.EnableMouse then _G.BagsBar:EnableMouse(true) end
        if _G.BagsBar.Show then _G.BagsBar:Show() end
    end
    local allButtons = {
        _G.MainMenuBarBackpackButton,
        _G.KeyRingButton,
        _G.CharacterReagentBag0Slot,
    }
    for _, name in ipairs(REGULAR_BAG_SLOTS) do
        table.insert(allButtons, _G[name])
    end
    for _, btn in ipairs(allButtons) do
        if btn then
            if btn.originalParent and btn.SetParent then
                btn:SetParent(btn.originalParent)
            elseif _G.BagsBar and btn.SetParent then
                btn:SetParent(_G.BagsBar)
            end
            if btn.Show then btn:Show() end
        end
    end
    if self.bagBarFrame and self.bagBarFrame.Hide then
        self.bagBarFrame:Hide()
    end
    if self.expanderButton and self.expanderButton.Hide then
        self.expanderButton:Hide()
    end
    if _G.BagsBar and _G.BagsBar.Layout then
        pcall(_G.BagsBar.Layout, _G.BagsBar)
    end
end

function BagsMod:UpdateBagBarLayout()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.pendingBagBarLayout = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerRegenEnabledBagBar")
        return
    end

    local cfg = self.db.bagBar or self.defaultSettings.bagBar
    if not cfg or cfg.enabled == false then
        self:RestoreBlizzardBagBar()
        return
    end

    if not self.bagBarFrame then return end
    if self.bagBarFrame.Show then self.bagBarFrame:Show() end
    local btnSize = cfg.buttonSize or 30
    local spacing = cfg.spacing or 4
    local isExpanded = cfg.expanded == true

    local isEditMode = (LEM and LEM.IsInEditMode and LEM:IsInEditMode()) or false
    local btnMouse = not isEditMode

    local xOffset = 0

    -- 1. Main backpack
    local backpack = _G.MainMenuBarBackpackButton
    if backpack then
        self:StyleBagButton(backpack)
        self:UpdateBagButtonVisual(backpack)
        if not backpack.originalParent and backpack.GetParent then
            backpack.originalParent = backpack:GetParent()
        end
        if backpack.SetParent then backpack:SetParent(self.bagBarFrame) end
        if backpack.SetFrameLevel and self.bagBarFrame.GetFrameLevel then
            backpack:SetFrameLevel(self.bagBarFrame:GetFrameLevel() + 10)
        end
        if backpack.EnableMouse then backpack:EnableMouse(btnMouse) end
        if backpack.ClearAllPoints then backpack:ClearAllPoints() end
        if backpack.SetSize then backpack:SetSize(btnSize, btnSize) end
        if backpack.SetPoint then backpack:SetPoint("LEFT", self.bagBarFrame, "LEFT", xOffset, 0) end
        if backpack.Show then backpack:Show() end
        xOffset = xOffset + btnSize + spacing
    end

    -- 2. Expander button
    if self.expanderButton then
        self.expanderButton:ClearAllPoints()
        self.expanderButton:SetSize(14, btnSize)
        if self.expanderButton.SetFrameLevel and self.bagBarFrame.GetFrameLevel then
            self.expanderButton:SetFrameLevel(self.bagBarFrame:GetFrameLevel() + 10)
        end
        if self.expanderButton.EnableMouse then self.expanderButton:EnableMouse(btnMouse) end
        self.expanderButton:SetPoint("LEFT", self.bagBarFrame, "LEFT", xOffset, 0)
        if self.expanderButton.arrow then
            self.expanderButton.arrow:SetText(isExpanded and "<" or ">")
        end
        self.expanderButton:Show()
        xOffset = xOffset + 14 + spacing
    end

    -- 3. Regular expandable bag slots (Bag 1-4)
    for _, name in ipairs(REGULAR_BAG_SLOTS) do
        local btn = _G[name]
        if btn then
            self:StyleBagButton(btn)
            self:UpdateBagButtonVisual(btn)
            if not btn.originalParent and btn.GetParent then
                btn.originalParent = btn:GetParent()
            end
            if btn.SetParent then btn:SetParent(self.bagBarFrame) end
            if btn.SetFrameLevel and self.bagBarFrame.GetFrameLevel then
                btn:SetFrameLevel(self.bagBarFrame:GetFrameLevel() + 10)
            end
            if btn.EnableMouse then btn:EnableMouse(btnMouse) end
            if isExpanded then
                if btn.ClearAllPoints then btn:ClearAllPoints() end
                if btn.SetSize then btn:SetSize(btnSize, btnSize) end
                if btn.SetPoint then btn:SetPoint("LEFT", self.bagBarFrame, "LEFT", xOffset, 0) end
                if btn.Show then btn:Show() end
                xOffset = xOffset + btnSize + spacing
            else
                if btn.Hide then btn:Hide() end
            end
        end
    end

    -- 4. Reagent Bag (Retail/Forever)
    local reagentBag = _G.CharacterReagentBag0Slot
    if reagentBag then
        self:StyleBagButton(reagentBag)
        self:UpdateBagButtonVisual(reagentBag)
        if not reagentBag.originalParent and reagentBag.GetParent then
            reagentBag.originalParent = reagentBag:GetParent()
        end
        if reagentBag.SetParent then reagentBag:SetParent(self.bagBarFrame) end
        if reagentBag.SetFrameLevel and self.bagBarFrame.GetFrameLevel then
            reagentBag:SetFrameLevel(self.bagBarFrame:GetFrameLevel() + 10)
        end
        if reagentBag.EnableMouse then reagentBag:EnableMouse(btnMouse) end
        if reagentBag.ClearAllPoints then reagentBag:ClearAllPoints() end
        if reagentBag.SetSize then reagentBag:SetSize(btnSize, btnSize) end
        if reagentBag.SetPoint then reagentBag:SetPoint("LEFT", self.bagBarFrame, "LEFT", xOffset, 0) end
        if reagentBag.Show then reagentBag:Show() end
        xOffset = xOffset + btnSize + spacing
    end

    -- 5. Keyring (Classic/Forever)
    local keyring = _G.KeyRingButton
    if keyring then
        self:StyleBagButton(keyring)
        self:UpdateBagButtonVisual(keyring)
        if not keyring.originalParent and keyring.GetParent then
            keyring.originalParent = keyring:GetParent()
        end
        if keyring.SetParent then keyring:SetParent(self.bagBarFrame) end
        if keyring.SetFrameLevel and self.bagBarFrame.GetFrameLevel then
            keyring:SetFrameLevel(self.bagBarFrame:GetFrameLevel() + 10)
        end
        if keyring.EnableMouse then keyring:EnableMouse(btnMouse) end
        if keyring.ClearAllPoints then keyring:ClearAllPoints() end
        if keyring.SetSize then keyring:SetSize(btnSize, btnSize) end
        if keyring.SetPoint then keyring:SetPoint("LEFT", self.bagBarFrame, "LEFT", xOffset, 0) end
        if keyring.Show then keyring:Show() end
        xOffset = xOffset + btnSize + spacing
    end

    local totalW = math.max(40, xOffset - spacing)
    local totalH = btnSize
    if self.bagBarFrame.SetSize then
        self.bagBarFrame:SetSize(totalW, totalH)
    end
    if self.SetBagButtonsMouse then
        self:SetBagButtonsMouse(not isEditMode)
    end
end

function BagsMod:OnPlayerRegenEnabledBagBar()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if self.pendingBagBarLayout then
        self.pendingBagBarLayout = nil
        self:UpdateBagBarLayout()
    end
end
