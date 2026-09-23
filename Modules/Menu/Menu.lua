local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local MenuMod = RoithiUI:NewModule("Menu", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LEM = LibStub("LibEditMode-Roithi", true)

MenuMod.displayName = L["Menu"]
MenuMod.description = L["Enables modern borderless styling for the Micro Menu."]
MenuMod.order = 85
MenuMod.dbKey = "Menu"

local isMainline = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)

local RETAIL_MICRO_BUTTONS = {
    "CharacterMicroButton",
    "ProfessionMicroButton",
    "PlayerSpellsMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "GuildMicroButton",
    "LFDMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
}

local CLASSIC_MICRO_BUTTONS = {
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "GuildMicroButton",
    "WorldMapMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
}

MenuMod.defaultSettings = {
    enabled = true,
    styleMicroMenu = true,
    buttonWidth = 24,
    buttonHeight = 32,
    spacing = 2,
    orientation = "HORIZONTAL", -- HORIZONTAL or VERTICAL
    alpha = 1.0,
    mouseover = false,
    mouseoverAlpha = 0.0,
    point = "BOTTOMRIGHT",
    x = -280,
    y = 0,
}

function MenuMod:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Menu or self.defaultSettings
    self.microButtons = {}
    self.backdrops = {}
    self.hookedButtons = {}
end

function MenuMod:GetBackdrop(btn)
    if not btn then return nil end
    return (self.backdrops and self.backdrops[btn]) or btn.roithiBackdrop
end

function MenuMod:OnEnable()
    if self.db.enabled == false then return end

    -- Preload Blizzard_EncounterJournal so ToggleEncounterJournal is defined untainted
    if _G.C_AddOns and _G.C_AddOns.LoadAddOn then
        pcall(_G.C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    end

    if self.db.styleMicroMenu ~= false then
        self:SetupMicroMenu()
    end
end

function MenuMod:OnDisable()
    if self.container and self.container.Hide then
        self.container:Hide()
    end
    self:RestoreMicroButtons()
end

function MenuMod:GetMicroButtons()
    local buttons = {}
    local buttonNames = isMainline and RETAIL_MICRO_BUTTONS or CLASSIC_MICRO_BUTTONS
    for _, btnName in ipairs(buttonNames) do
        local btn = _G[btnName]
        if btn then
            table.insert(buttons, btn)
        end
    end
    if isMainline and _G.HousingMicroButton then
        local found = false
        for _, b in ipairs(buttons) do
            if b == _G.HousingMicroButton then found = true break end
        end
        if not found then
            table.insert(buttons, _G.HousingMicroButton)
        end
    end
    return buttons
end

function MenuMod:SetupMicroMenu()
    if self.container then return end

    -- Hide / Suppress Blizzard's default micro menu bars and containers
    if _G.MicroMenu then
        if _G.MicroMenu.SetAlpha then _G.MicroMenu:SetAlpha(0) end
        if _G.MicroMenu.EnableMouse then _G.MicroMenu:EnableMouse(false) end
        for _, reg in ipairs({ _G.MicroMenu:GetRegions() }) do
            if reg.IsObjectType and reg:IsObjectType("Texture") then
                reg:SetAlpha(0)
            end
        end
    end
    if _G.MicroMenuContainer then
        if _G.MicroMenuContainer.SetAlpha then _G.MicroMenuContainer:SetAlpha(0) end
        if _G.MicroMenuContainer.EnableMouse then _G.MicroMenuContainer:EnableMouse(false) end
        for _, reg in ipairs({ _G.MicroMenuContainer:GetRegions() }) do
            if reg.IsObjectType and reg:IsObjectType("Texture") then
                reg:SetAlpha(0)
            end
        end
    end
    if _G.MicroButtonAndBagsBar then
        if _G.MicroButtonAndBagsBar.SetAlpha then _G.MicroButtonAndBagsBar:SetAlpha(0) end
        if _G.MicroButtonAndBagsBar.EnableMouse then _G.MicroButtonAndBagsBar:EnableMouse(false) end
        for _, reg in ipairs({ _G.MicroButtonAndBagsBar:GetRegions() }) do
            if reg.IsObjectType and reg:IsObjectType("Texture") then
                reg:SetAlpha(0)
            end
        end
    end

    -- Hook native layout methods to prevent Blizzard from stealing micro buttons back
    if _G.MicroMenu and not self.microMenuHooked and hooksecurefunc then
        if _G.MicroMenu.Layout then
            hooksecurefunc(_G.MicroMenu, "Layout", function()
                if self.db and self.db.enabled ~= false and self.db.styleMicroMenu ~= false then
                    self:LayoutMicroMenu()
                end
            end)
        end
        if _G.MicroMenu.Update then
            hooksecurefunc(_G.MicroMenu, "Update", function()
                if self.db and self.db.enabled ~= false and self.db.styleMicroMenu ~= false then
                    self:LayoutMicroMenu()
                end
            end)
        end
        self.microMenuHooked = true
    end

    if _G.UpdateMicroButtons and not self.updateMicroButtonsHooked and hooksecurefunc then
        hooksecurefunc("UpdateMicroButtons", function()
            if self.db and self.db.enabled ~= false and self.db.styleMicroMenu ~= false then
                self:LayoutMicroMenu()
            end
        end)
        self.updateMicroButtonsHooked = true
    end

    local container = CreateFrame("Frame", "RoithiMicroMenu", UIParent)
    if container.SetClampedToScreen then container:SetClampedToScreen(true) end
    if container.SetMovable then container:SetMovable(true) end
    if container.EnableMouse then container:EnableMouse(true) end
    if container.SetScript then
        container:SetScript("OnEnter", function() self:OnContainerEnter() end)
        container:SetScript("OnLeave", function() self:OnContainerLeave() end)
    end

    local pt = self.db.point or "BOTTOMRIGHT"
    if container.ClearAllPoints then container:ClearAllPoints() end
    if container.SetPoint then
        container:SetPoint(pt, UIParent, pt, self.db.x or -280, self.db.y or 0)
    end

    self.container = container

    if LEM and LEM.AddFrame then
        container.editModeName = L["Micro Menu"]
        local defaults = { point = pt, x = self.db.x or -280, y = self.db.y or 0 }
        LEM:AddFrame(container, function(_, _, newPoint, newX, newY)
            self.db.point = newPoint
            self.db.x = newX
            self.db.y = newY
        end, defaults)
    end

    if self.container.Show then self.container:Show() end
    self:LayoutMicroMenu()
end

function MenuMod:StyleMicroButton(btn)
    if not btn then return end

    -- Hide default Blizzard ornate textures and backgrounds
    if btn.FlashContent and btn.FlashContent.Hide then btn.FlashContent:Hide() end
    if btn.FlashBorder and btn.FlashBorder.Hide then btn.FlashBorder:Hide() end
    if btn.Background and btn.Background.SetAlpha then btn.Background:SetAlpha(0) end
    if btn.PushedBackground and btn.PushedBackground.SetAlpha then btn.PushedBackground:SetAlpha(0) end
    if btn.Shadow and btn.Shadow.SetAlpha then btn.Shadow:SetAlpha(0) end
    if btn.PushedShadow and btn.PushedShadow.SetAlpha then btn.PushedShadow:SetAlpha(0) end
    if btn.QuickKeybindHighlightTexture and btn.QuickKeybindHighlightTexture.SetAlpha then
        btn.QuickKeybindHighlightTexture:SetAlpha(0)
    end

    -- Strip texture regions (both file and atlas)
    for _, region in ipairs({ btn:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            local isStripped = false
            local tex = region.GetTexture and region:GetTexture()
            if type(tex) == "string" then
                local texPath = tex:lower()
                if texPath:find("border") or texPath:find("shadow") or texPath:find("frame") or texPath:find("highlight") or texPath:find("buttonbg") then
                    region:SetAlpha(0)
                    isStripped = true
                end
            end
            local atlas = region.GetAtlas and region:GetAtlas()
            if not isStripped and type(atlas) == "string" then
                local atlasStr = atlas:lower()
                if atlasStr:find("border") or atlasStr:find("shadow") or atlasStr:find("frame") or atlasStr:find("highlight") or atlasStr:find("buttonbg") then
                    region:SetAlpha(0)
                end
            end
        end
    end

    -- Remove portrait mask circle if present so portrait is clean
    if btn.PortraitMask and btn.PortraitMask.Hide then
        btn.PortraitMask:Hide()
    end
    if btn.Portrait and btn.Portrait.SetTexCoord then
        btn.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    end

    -- 1px Custom dark backdrop behind button (parented to container, never mutating btn)
    self.backdrops = self.backdrops or {}
    local bg = self.backdrops[btn] or btn.roithiBackdrop
    if not bg then
        local parentFrame = self.container or (btn.GetParent and btn:GetParent()) or UIParent
        bg = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
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
        self.backdrops[btn] = bg
    else
        if bg.Show then bg:Show() end
        if bg.SetAllPoints then bg:SetAllPoints(btn) end
    end

    -- Hook mouseover events using internal tracking table (zero property mutations on secure btn)
    self.hookedButtons = self.hookedButtons or {}
    if not self.hookedButtons[btn] and btn.HookScript then
        btn:HookScript("OnEnter", function() self:OnContainerEnter() end)
        btn:HookScript("OnLeave", function() self:OnContainerLeave() end)
        self.hookedButtons[btn] = true
    end
end

function MenuMod:StyleAllMicroButtons()
    local buttons = self:GetMicroButtons()
    for _, btn in ipairs(buttons) do
        self:StyleMicroButton(btn)
    end
end

function MenuMod:LayoutMicroMenu()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end

    if not self.container then return end

    local buttons = self:GetMicroButtons()
    if #buttons == 0 then return end

    local btnW = self.db.buttonWidth or 24
    local btnH = self.db.buttonHeight or 32
    local spacing = self.db.spacing or 2
    local isHoriz = (self.db.orientation or "HORIZONTAL") == "HORIZONTAL"

    local totalW = isHoriz and (#buttons * btnW + (#buttons - 1) * spacing) or btnW
    local totalH = isHoriz and btnH or (#buttons * btnH + (#buttons - 1) * spacing)
    if self.container.SetSize then
        self.container:SetSize(totalW, totalH)
    end

    for i, btn in ipairs(buttons) do
        -- NOTE: We intentionally do NOT call btn:SetParent(self.container) or btn:Show()!
        -- Reparenting secure Blizzard buttons (e.g. MainMenuMicroButton) breaks their secure hierarchy
        -- and taints GameMenu / EditMode execution context.
        if btn.ClearAllPoints then btn:ClearAllPoints() end
        if btn.SetSize then btn:SetSize(btnW, btnH) end

        if btn.SetPoint then
            if isHoriz then
                local x = (i - 1) * (btnW + spacing)
                btn:SetPoint("TOPLEFT", self.container, "TOPLEFT", x, 0)
            else
                local y = -((i - 1) * (btnH + spacing))
                btn:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, y)
            end
        end

        self:StyleMicroButton(btn)
    end

    self:UpdateMicroMenuAlpha()
end

function MenuMod:RestoreMicroButtons()
    local buttons = self:GetMicroButtons()
    for _, btn in ipairs(buttons) do
        local bg = (self.backdrops and self.backdrops[btn]) or btn.roithiBackdrop
        if bg and bg.Hide then
            bg:Hide()
        end
    end
end

function MenuMod:IsMicroMenuMouseOver()
    if self.container and self.container.IsMouseOver and self.container:IsMouseOver() then return true end
    if _G.MicroMenu and _G.MicroMenu.IsMouseOver and _G.MicroMenu:IsMouseOver() then return true end
    for _, btn in ipairs(self:GetMicroButtons()) do
        if btn.IsMouseOver and btn:IsMouseOver() then return true end
    end
    return false
end

function MenuMod:UpdateNativeMicroMenuAlpha()
    local target = _G.MicroMenu or _G.MicroButtonAndBagsBar
    if not target then return end

    if self.db.mouseover then
        local targetAlpha = self:IsMicroMenuMouseOver() and (self.db.alpha or 1.0) or (self.db.mouseoverAlpha or 0.0)
        if target.SetAlpha then target:SetAlpha(targetAlpha) end
    else
        if target.SetAlpha then target:SetAlpha(self.db.alpha or 1.0) end
    end
end

function MenuMod:UpdateMicroMenuAlpha()
    if _G.MicroMenu then
        self:UpdateNativeMicroMenuAlpha()
        return
    end

    if not self.container then return end
    if self.db.mouseover then
        local targetAlpha = self:IsMicroMenuMouseOver() and (self.db.alpha or 1.0) or (self.db.mouseoverAlpha or 0.0)
        if self.container.SetAlpha then self.container:SetAlpha(targetAlpha) end
    else
        if self.container.SetAlpha then self.container:SetAlpha(self.db.alpha or 1.0) end
    end
end

function MenuMod:OnContainerEnter()
    if self.db.mouseover then
        local target = _G.MicroMenu or _G.MicroButtonAndBagsBar or self.container
        if target and target.SetAlpha then
            target:SetAlpha(self.db.alpha or 1.0)
        end
    end
end

function MenuMod:OnContainerLeave()
    if self.db.mouseover and _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.05, function()
            if not self:IsMicroMenuMouseOver() then
                local target = _G.MicroMenu or _G.MicroButtonAndBagsBar or self.container
                if target and target.SetAlpha then
                    target:SetAlpha(self.db.mouseoverAlpha or 0.0)
                end
            end
        end)
    end
end
