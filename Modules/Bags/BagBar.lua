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

function BagsMod:SetupBagBar()
    if self.bagBarFrame then return end

    if _G.BagsBar then
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

    local cfg = self.db.bagBar or self.defaultSettings.bagBar

    local bar = CreateFrame("Frame", "RoithiBagBar", UIParent)
    if bar.SetClampedToScreen then bar:SetClampedToScreen(true) end
    if bar.SetMovable then bar:SetMovable(true) end
    if bar.SetFrameStrata then bar:SetFrameStrata("HIGH") end

    local pt = cfg.point or "BOTTOMRIGHT"
    if bar.ClearAllPoints then bar:ClearAllPoints() end
    if bar.SetPoint then bar:SetPoint(pt, UIParent, pt, cfg.x or -10, cfg.y or 40) end

    self.bagBarFrame = bar

    if LEM and LEM.AddFrame then
        bar.editModeName = L["Bag Bar"]
        local defaults = { point = pt, x = cfg.x or -10, y = cfg.y or 40 }
        LEM:AddFrame(bar, function(_, _, newPoint, newX, newY)
            self.db.bagBar = self.db.bagBar or {}
            self.db.bagBar.point = newPoint
            self.db.bagBar.x = newX
            self.db.bagBar.y = newY
        end, defaults)
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
        LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 9, "OUTLINE")
    end
    text:SetPoint("CENTER", expander, "CENTER", 0, 0)
    if text.SetTextColor then text:SetTextColor(0.8, 0.8, 0.8, 1) end

    local isExpanded = cfg.expanded == true
    text:SetText(isExpanded and "▶" or "◀")
    expander.arrow = text

    expander:SetScript("OnClick", function()
        self.db.bagBar = self.db.bagBar or {}
        self.db.bagBar.expanded = not self.db.bagBar.expanded
        local expanded = self.db.bagBar.expanded
        if expander.arrow then
            expander.arrow:SetText(expanded and "▶" or "◀")
        end
        self:UpdateBagBarLayout()
    end)

    expander:SetScript("OnEnter", function()
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(expander, "ANCHOR_LEFT")
            _G.GameTooltip:SetText(self.db.bagBar.expanded and L["Click to collapse bags"] or L["Click to expand bags"], 1, 1, 1)
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

function BagsMod:StyleBagButton(btn)
    if not btn then return end

    -- Hide circular mask
    if btn.CircleMask and btn.CircleMask.Hide then
        btn.CircleMask:Hide()
    end
    if btn.SlotHighlightTexture and btn.SlotHighlightTexture.SetAlpha then
        btn.SlotHighlightTexture:SetAlpha(0)
    end

    -- Hide native borders and textures (both file and atlas)
    for _, region in ipairs({ btn:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            local isStripped = false
            local tex = region.GetTexture and region:GetTexture()
            if type(tex) == "string" then
                local texPath = tex:lower()
                if texPath:find("border") or texPath:find("normal") or texPath:find("slot") or texPath:find("glow") or texPath:find("bag") then
                    region:SetAlpha(0)
                    isStripped = true
                end
            end
            local atlas = region.GetAtlas and region:GetAtlas()
            if not isStripped and type(atlas) == "string" then
                local atlasStr = atlas:lower()
                if atlasStr:find("border") or atlasStr:find("normal") or atlasStr:find("slot") or atlasStr:find("glow") or atlasStr:find("bag") then
                    region:SetAlpha(0)
                end
            end
        end
    end

    local norm = btn.GetNormalTexture and btn:GetNormalTexture()
    if norm and norm.SetAlpha then norm:SetAlpha(0) end
    local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
    if pushed and pushed.SetAlpha then pushed:SetAlpha(0) end

    -- Hook UpdateTextures so Blizzard does not re-apply the atlas over our styled button
    if not btn.roithiTexturesHooked and btn.UpdateTextures then
        hooksecurefunc(btn, "UpdateTextures", function(selfBtn)
            if selfBtn.GetNormalTexture and selfBtn:GetNormalTexture() then selfBtn:GetNormalTexture():SetAlpha(0) end
            if selfBtn.GetPushedTexture and selfBtn:GetPushedTexture() then selfBtn:GetPushedTexture():SetAlpha(0) end
            if selfBtn.SlotHighlightTexture then selfBtn.SlotHighlightTexture:SetAlpha(0) end
            if selfBtn.CircleMask then selfBtn.CircleMask:Hide() end
        end)
        btn.roithiTexturesHooked = true
    end

    -- Zoom icon
    local icon = btn.icon or _G[btn.GetName and btn:GetName() and (btn:GetName() .. "IconTexture")] or btn.Icon
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
        if btn.roithiBackdrop.Show then btn.roithiBackdrop:Show() end
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

    for _, btn in ipairs(allButtons) do
        if btn then
            self:StyleBagButton(btn)
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

function BagsMod:UpdateBagBarLayout()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end

    if not self.bagBarFrame then return end

    local cfg = self.db.bagBar or self.defaultSettings.bagBar
    local btnSize = cfg.buttonSize or 30
    local spacing = cfg.spacing or 4
    local isExpanded = cfg.expanded == true

    local alwaysShown = {}
    -- 1. Main backpack
    if _G.MainMenuBarBackpackButton then
        table.insert(alwaysShown, _G.MainMenuBarBackpackButton)
    end
    -- 2. Keyring (Classic/Forever)
    if _G.KeyRingButton then
        table.insert(alwaysShown, _G.KeyRingButton)
    end
    -- 3. Reagent Bag (Retail/Forever)
    if _G.CharacterReagentBag0Slot then
        table.insert(alwaysShown, _G.CharacterReagentBag0Slot)
    end

    local expandableButtons = {}
    for _, name in ipairs(REGULAR_BAG_SLOTS) do
        local btn = _G[name]
        if btn then
            table.insert(expandableButtons, btn)
        end
    end

    -- Position always shown buttons first (from left to right)
    local xOffset = 0
    for _, btn in ipairs(alwaysShown) do
        if not btn.originalParent and btn.GetParent then
            btn.originalParent = btn:GetParent()
        end
        if btn.SetParent then btn:SetParent(self.bagBarFrame) end
        if btn.ClearAllPoints then btn:ClearAllPoints() end
        if btn.SetSize then btn:SetSize(btnSize, btnSize) end
        if btn.SetPoint then
            btn:SetPoint("LEFT", self.bagBarFrame, "LEFT", xOffset, 0)
        end
        if btn.Show then btn:Show() end
        xOffset = xOffset + btnSize + spacing
    end

    -- Expander button
    if self.expanderButton then
        self.expanderButton:ClearAllPoints()
        self.expanderButton:SetSize(14, btnSize)
        self.expanderButton:SetPoint("LEFT", self.bagBarFrame, "LEFT", xOffset, 0)
        self.expanderButton:Show()
        xOffset = xOffset + 14 + spacing
    end

    -- Position expandable regular bags if expanded, otherwise hide them
    for _, btn in ipairs(expandableButtons) do
        if not btn.originalParent and btn.GetParent then
            btn.originalParent = btn:GetParent()
        end
        if btn.SetParent then btn:SetParent(self.bagBarFrame) end
        if isExpanded then
            if btn.ClearAllPoints then btn:ClearAllPoints() end
            if btn.SetSize then btn:SetSize(btnSize, btnSize) end
            if btn.SetPoint then
                btn:SetPoint("LEFT", self.bagBarFrame, "LEFT", xOffset, 0)
            end
            if btn.Show then btn:Show() end
            xOffset = xOffset + btnSize + spacing
        else
            if btn.Hide then btn:Hide() end
        end
    end

    local totalW = math.max(40, xOffset - spacing)
    local totalH = btnSize
    if self.bagBarFrame.SetSize then
        self.bagBarFrame:SetSize(totalW, totalH)
    end
end
