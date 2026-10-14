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

local isForever = ns.IsForever
local isRetail = ns.IsRetail

local NORMAL_ICON_COLOR = 0.9
local HOVER_ICON_COLOR = 1.0
MenuMod.NORMAL_ICON_COLOR = NORMAL_ICON_COLOR
MenuMod.HOVER_ICON_COLOR = HOVER_ICON_COLOR

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

local FOREVER_MICRO_BUTTONS = {
    "CharacterMicroButton",
    "ProfessionMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "QuestLogMicroButton",
    "GuildMicroButton",
    "SocialsMicroButton",
    "LFDMicroButton",
    "CollectionsMicroButton",
    "LegacyMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
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

MenuMod.dbKey = "Menu"
MenuMod.defaultSettings = ns.MenuDefaults or (ns.Defaults and ns.Defaults.profile and ns.Defaults.profile.Menu)

function MenuMod:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Menu or self.defaultSettings
    self.microButtons = {}
    self.backdrops = {}
    self.hookedButtons = {}
    self.btnPointHooked = {}
end

function MenuMod:GetBackdrop(btn)
    if not btn then return nil end
    return (self.backdrops and self.backdrops[btn]) or btn.roithiBackdrop
end

function MenuMod:QueueLayoutMicroMenu()
    if self.layoutTimerPending then return end
    self.layoutTimerPending = true
    _G.C_Timer.After(0.02, function()
        self.layoutTimerPending = false
        if self.db and self.db.enabled ~= false and self.db.styleMicroMenu ~= false then
            self:LayoutMicroMenu()
        end
    end)
end

function MenuMod:PLAYER_REGEN_ENABLED()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:QueueLayoutMicroMenu()
end

function MenuMod:RefreshProfile()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Menu or self.defaultSettings
    if self.container then
        local pt = self.db.point or "BOTTOMLEFT"
        self.container:ClearAllPoints()
        self.container:SetPoint(pt, UIParent, pt, self.db.x or 4, self.db.y or 235)
    end
    self:StyleAllMicroButtons()
    self:QueueLayoutMicroMenu()
end
MenuMod.RefreshSettings = MenuMod.RefreshProfile

function MenuMod:OnEnable()
    if self.db.enabled == false then return end

    -- Preload Blizzard_EncounterJournal so ToggleEncounterJournal is defined untainted
    if _G.C_AddOns and _G.C_AddOns.LoadAddOn then
        pcall(_G.C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    end

    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "QueueLayoutMicroMenu")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "QueueLayoutMicroMenu")
    self:RegisterEvent("UNIT_PORTRAIT_UPDATE", "UpdateCharacterPortrait")
    self:RegisterEvent("PORTRAITS_UPDATED", "UpdateCharacterPortrait")

    if self.db.styleMicroMenu ~= false then
        self:SetupMicroMenu()
        self:QueueLayoutMicroMenu()
    end
end

function MenuMod:UpdateCharacterPortrait(event, unit)
    if event == "UNIT_PORTRAIT_UPDATE" and unit ~= "player" then return end
    local btn = _G.CharacterMicroButton
    if not btn then return end
    local portrait = btn.Portrait or _G.MicroButtonPortrait
    if portrait and _G.SetPortraitTexture then
        _G.SetPortraitTexture(portrait, "player")
    end
end

function MenuMod:OnDisable()
    self:UnregisterAllEvents()
    self.layoutTimerPending = false
    if self.container and self.container.Hide then
        self.container:Hide()
    end
    self:RestoreMicroButtons()
end

function MenuMod:GetMicroButtons()
    local buttons = {}
    local buttonNames
    if isRetail then
        buttonNames = RETAIL_MICRO_BUTTONS
    elseif isForever then
        buttonNames = FOREVER_MICRO_BUTTONS
    else
        buttonNames = CLASSIC_MICRO_BUTTONS
    end

    for _, btnName in ipairs(buttonNames) do
        local btn = _G[btnName]
        if btn then
            table.insert(buttons, btn)
        end
    end
    if isRetail and _G.HousingMicroButton then
        local found = false
        for _, b in ipairs(buttons) do
            if b == _G.HousingMicroButton then found = true break end
        end
        if not found then
            table.insert(buttons, _G.HousingMicroButton)
        end
    end
    if _G.LegacyMicroButton then
        local found = false
        for _, b in ipairs(buttons) do
            if b == _G.LegacyMicroButton then found = true break end
        end
        if not found then
            table.insert(buttons, _G.LegacyMicroButton)
        end
    end
    return buttons
end

function MenuMod:SetupMicroMenu()
    if self.container then return end

    -- Hide / Suppress Blizzard's default micro menu bars and containers
    local function SuppressMicroMenuSelection()
        for _, f in ipairs({ _G.MicroMenu, _G.MicroMenuContainer, _G.MicroButtonAndBagsBar }) do
            if f then
                f.defaultHideSelection = true
                if f.Selection then
                    f.Selection:Hide()
                    if f.Selection.EnableMouse then f.Selection:EnableMouse(false) end
                end
            end
        end
    end

    SuppressMicroMenuSelection()

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.editModeRegistered then
        _G.EventRegistry:RegisterCallback("EditMode.Enter", SuppressMicroMenuSelection, self)
        self.editModeRegistered = true
    end

    -- Explicitly hide unsupported micro buttons in Forever / Classic
    if not isRetail then
        if _G.HousingMicroButton and _G.HousingMicroButton.Hide then _G.HousingMicroButton:Hide() end
        if _G.EJMicroButton and _G.EJMicroButton.Hide then _G.EJMicroButton:Hide() end
        if isForever and _G.AchievementMicroButton and _G.AchievementMicroButton.Hide then
            _G.AchievementMicroButton:Hide()
        end
    end

    if _G.MicroMenu then
        if _G.MicroMenu.EnableMouse then _G.MicroMenu:EnableMouse(false) end
        for _, reg in ipairs({ _G.MicroMenu:GetRegions() }) do
            if reg.IsObjectType and reg:IsObjectType("Texture") then
                reg:SetAlpha(0)
            end
        end
    end
    if _G.MicroMenuContainer then
        if _G.MicroMenuContainer.EnableMouse then _G.MicroMenuContainer:EnableMouse(false) end
        for _, reg in ipairs({ _G.MicroMenuContainer:GetRegions() }) do
            if reg.IsObjectType and reg:IsObjectType("Texture") then
                reg:SetAlpha(0)
            end
        end
    end
    if _G.MicroButtonAndBagsBar then
        if _G.MicroButtonAndBagsBar.EnableMouse then _G.MicroButtonAndBagsBar:EnableMouse(false) end
        for _, reg in ipairs({ _G.MicroButtonAndBagsBar:GetRegions() }) do
            if reg.IsObjectType and reg:IsObjectType("Texture") then
                reg:SetAlpha(0)
            end
        end
    end

    -- Set overrideScale to signal to EditModeExpanded and other frame managers not to clobber button positions
    if _G.MicroMenu then
        _G.MicroMenu.overrideScale = 1
    end

    -- Hook native layout methods to prevent Blizzard and other addons from stealing micro buttons back
    if _G.MicroMenu and not self.microMenuHooked and hooksecurefunc then
        if _G.MicroMenu.Layout then
            hooksecurefunc(_G.MicroMenu, "Layout", function()
                if self.isLayoutingMicroMenu then return end
                self:QueueLayoutMicroMenu()
            end)
        end
        if _G.MicroMenu.Update then
            hooksecurefunc(_G.MicroMenu, "Update", function()
                if self.isLayoutingMicroMenu then return end
                self:QueueLayoutMicroMenu()
            end)
        end
        self.microMenuHooked = true
    end

    if _G.MicroMenuContainer and not self.microContainerHooked and hooksecurefunc then
        if _G.MicroMenuContainer.Layout then
            hooksecurefunc(_G.MicroMenuContainer, "Layout", function()
                if self.isLayoutingMicroMenu then return end
                self:QueueLayoutMicroMenu()
            end)
        end
        if _G.MicroMenuContainer.Update then
            hooksecurefunc(_G.MicroMenuContainer, "Update", function()
                if self.isLayoutingMicroMenu then return end
                self:QueueLayoutMicroMenu()
            end)
        end
        self.microContainerHooked = true
    end

    if _G.MicroButtonAndBagsBar and not self.microBagsBarHooked and hooksecurefunc then
        if _G.MicroButtonAndBagsBar.Layout then
            hooksecurefunc(_G.MicroButtonAndBagsBar, "Layout", function()
                if self.isLayoutingMicroMenu then return end
                self:QueueLayoutMicroMenu()
            end)
        end
        self.microBagsBarHooked = true
    end

    if _G.UpdateMicroButtons and not self.updateMicroButtonsHooked and hooksecurefunc then
        hooksecurefunc("UpdateMicroButtons", function()
            if self.isUpdatingMicroButtons then return end
            self.isUpdatingMicroButtons = true
            if self.db and self.db.enabled ~= false and self.db.styleMicroMenu ~= false then
                self:StyleAllMicroButtons()
                self:QueueLayoutMicroMenu()
            end
            self.isUpdatingMicroButtons = false
        end)
        self.updateMicroButtonsHooked = true
    end

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.editModeExitHooked then
        _G.EventRegistry:RegisterCallback("EditMode.Exit", function()
            self:QueueLayoutMicroMenu()
        end, self)
        self.editModeExitHooked = true
    end

    local container = CreateFrame("Frame", "RoithiMicroMenu", UIParent, "BackdropTemplate")
    if container.SetFrameStrata then container:SetFrameStrata("BACKGROUND") end
    if container.SetClampedToScreen then container:SetClampedToScreen(true) end
    if container.SetMovable then container:SetMovable(true) end
    if container.EnableMouse then container:EnableMouse(true) end
    if container.SetScript then
        container:SetScript("OnEnter", function() self:OnContainerEnter() end)
        container:SetScript("OnLeave", function() self:OnContainerLeave() end)
    end

    local pt = self.db.point or "BOTTOMLEFT"
    local btnW = self.db.buttonWidth or 24
    local btnH = self.db.buttonHeight or 32
    local spacing = self.db.spacing or 2
    local numButtons = 11
    local isHoriz = (self.db.orientation or "HORIZONTAL") == "HORIZONTAL"
    local initialW = isHoriz and (numButtons * btnW + (numButtons - 1) * spacing) or btnW
    local initialH = isHoriz and btnH or (numButtons * btnH + (numButtons - 1) * spacing)
    if container.SetSize then container:SetSize(initialW, initialH) end

    if container.ClearAllPoints then container:ClearAllPoints() end
    if container.SetPoint then
        container:SetPoint(pt, UIParent, pt, self.db.x or 4, self.db.y or 235)
    end

    self.container = container

    if LEM and LEM.AddFrame then
        container.editModeName = L["Micro Menu"]
        local def = ns.Defaults.profile.Menu
        local defaults = { point = def.point, x = def.x, y = def.y }
        LEM:AddFrame(container, function(f, _, newPoint, newX, newY)
            self.db.point = newPoint
            self.db.x = newX
            self.db.y = newY
            if f and f.ClearAllPoints and f.SetPoint then
                f:ClearAllPoints()
                f:SetPoint(newPoint, UIParent, newPoint, newX, newY)
            end
            self:LayoutMicroMenu()
        end, defaults)

        if LEM.AddFrameSettings then
            local sliderType = (LEM.SettingType and LEM.SettingType.Slider) or 2
            local dropdownType = (LEM.SettingType and LEM.SettingType.Dropdown) or 4
            local settings = {
                {
                    name = L["X Position"],
                    kind = sliderType,
                    minValue = -2500,
                    maxValue = 2500,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db.x or 4 end,
                    set = function(_, val)
                        self.db.x = val
                        local p = self.db.point or "BOTTOMLEFT"
                        container:ClearAllPoints()
                        container:SetPoint(p, UIParent, p, val, self.db.y or 235)
                        self:LayoutMicroMenu()
                    end,
                },
                {
                    name = L["Y Position"],
                    kind = sliderType,
                    minValue = -1500,
                    maxValue = 1500,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db.y or 235 end,
                    set = function(_, val)
                        self.db.y = val
                        local p = self.db.point or "BOTTOMLEFT"
                        container:ClearAllPoints()
                        container:SetPoint(p, UIParent, p, self.db.x or 4, val)
                        self:LayoutMicroMenu()
                    end,
                },
                {
                    name = L["Orientation"],
                    kind = dropdownType,
                    values = {
                        { text = L["Horizontal"], value = "HORIZONTAL" },
                        { text = L["Vertical"], value = "VERTICAL" },
                    },
                    get = function() return self.db.orientation or "HORIZONTAL" end,
                    set = function(_, val)
                        self.db.orientation = val
                        self:LayoutMicroMenu()
                    end,
                },
                {
                    name = L["Button Width"],
                    kind = sliderType,
                    minValue = 16,
                    maxValue = 48,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db.buttonWidth or 24 end,
                    set = function(_, val)
                        self.db.buttonWidth = val
                        self:LayoutMicroMenu()
                    end,
                },
                {
                    name = L["Button Height"],
                    kind = sliderType,
                    minValue = 16,
                    maxValue = 48,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db.buttonHeight or 32 end,
                    set = function(_, val)
                        self.db.buttonHeight = val
                        self:LayoutMicroMenu()
                    end,
                },
                {
                    name = L["Button Spacing"],
                    kind = sliderType,
                    minValue = 0,
                    maxValue = 10,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db.spacing or 2 end,
                    set = function(_, val)
                        self.db.spacing = val
                        self:LayoutMicroMenu()
                    end,
                },
            }
            LEM:AddFrameSettings(container, settings)
        end
        if LEM.AddFrameSettingsButtons then
            LEM:AddFrameSettingsButtons(container, {
                {
                    text = L["Open Full Settings"] or "Open Full Settings",
                    click = function()
                        if RoithiUI and RoithiUI.OpenSettings then
                            RoithiUI:OpenSettings("menu")
                        elseif LibStub("AceConfigDialog-3.0") then
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "interface_group", "menu")
                            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                        end
                    end,
                },
            })
        end
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

    local isGuildBtn = (btn == _G.GuildMicroButton) or (btn.GetName and btn:GetName() == "GuildMicroButton")
    local isGuildTabard = isGuildBtn and (
        (btn.Emblem and btn.Emblem.IsShown and btn.Emblem:IsShown()) or
        (btn.textureName and type(btn.textureName) == "string" and btn.textureName:find("GuildColor"))
    )

    -- Ensure normal texture and portrait are visible, fitted to button, and at full alpha & brightness
    local norm = btn.GetNormalTexture and btn:GetNormalTexture()
    if norm then
        local atlas = norm.GetAtlas and norm:GetAtlas()
        if atlas and not isGuildTabard and not atlas:find("GuildColor") then
            if atlas:find("%-Disabled$") then
                norm:SetAtlas(atlas:gsub("%-Disabled$", "-Mouseover"))
            elseif atlas:find("%-Up$") then
                norm:SetAtlas(atlas:gsub("%-Up$", "-Mouseover"))
            end
        end
        local tex = norm.GetTexture and norm:GetTexture()
        if type(tex) == "string" and tex:find("Disabled") then
            norm:SetTexture(tex:gsub("Disabled", "Up"))
        end
        if norm.SetAlpha then norm:SetAlpha(1) end
        if norm.SetDesaturated and not isGuildTabard then norm:SetDesaturated(false) end
        if not isGuildTabard and norm.SetVertexColor then
            norm:SetVertexColor(NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, 1)
        end
        if norm.ClearAllPoints then norm:ClearAllPoints() end
        if norm.SetAllPoints then norm:SetAllPoints(btn) end
    end
    local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
    if pushed then
        if pushed.ClearAllPoints then pushed:ClearAllPoints() end
        if pushed.SetAllPoints then pushed:SetAllPoints(btn) end
    end
    local disabled = btn.GetDisabledTexture and btn:GetDisabledTexture()
    if disabled then
        local atlas = disabled.GetAtlas and disabled:GetAtlas()
        if atlas then
            if atlas:find("%-Disabled$") then
                disabled:SetAtlas(atlas:gsub("%-Disabled$", "-Mouseover"))
            elseif atlas:find("%-Up$") then
                disabled:SetAtlas(atlas:gsub("%-Up$", "-Mouseover"))
            end
        end
        local tex = disabled.GetTexture and disabled:GetTexture()
        if type(tex) == "string" and tex:find("Disabled") then
            disabled:SetTexture(tex:gsub("Disabled", "Up"))
        end
        if disabled.SetDesaturated then disabled:SetDesaturated(false) end
        if disabled.SetVertexColor then disabled:SetVertexColor(NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, 1) end
        if disabled.SetAlpha then disabled:SetAlpha(1) end
        if disabled.ClearAllPoints then disabled:ClearAllPoints() end
        if disabled.SetAllPoints then disabled:SetAllPoints(btn) end
    end
    local highlight = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if highlight then
        if highlight.ClearAllPoints then highlight:ClearAllPoints() end
        if highlight.SetAllPoints then highlight:SetAllPoints(btn) end
        if highlight.SetAlpha then highlight:SetAlpha(0) end
    end
    local portrait = btn.Portrait or _G.MicroButtonPortrait
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
        portrait:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
        if portrait.SetTexCoord then
            portrait:SetTexCoord(0.18, 0.82, 0.18, 0.82)
        end
        if portrait.SetAlpha then portrait:SetAlpha(1) end
        if portrait.SetDesaturated then portrait:SetDesaturated(false) end
        if portrait.SetVertexColor then portrait:SetVertexColor(NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, 1) end
        if portrait.Show then portrait:Show() end
        if _G.SetPortraitTexture then
            _G.SetPortraitTexture(portrait, "player")
        end
    end

    -- Shape PortraitMask to solid white rectangle matching button bounds (never Hide, which masks out to 0 alpha!)
    if btn.PortraitMask then
        btn.PortraitMask:ClearAllPoints()
        btn.PortraitMask:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
        btn.PortraitMask:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
        if btn.PortraitMask.SetTexture then
            btn.PortraitMask:SetTexture("Interface\\Buttons\\WHITE8x8")
        end
        if btn.PortraitMask.Show then btn.PortraitMask:Show() end
        if btn.PortraitMask.SetAlpha then btn.PortraitMask:SetAlpha(1) end
    end

    -- Guild Emblem & Tabard handling:
    -- Blizzard's native Emblem size is 12x14. Never stretch it to full button dimensions (btn:GetWidth()-2),
    -- which causes the guild crest cross to stretch excessively and hide the button background.
    local btnW = (btn.GetWidth and btn:GetWidth()) or 28
    local btnH = (btn.GetHeight and btn:GetHeight()) or 38
    local emblemW = math.max(10, math.min(14, math.floor(btnW * (12 / 28))))
    local emblemH = math.max(12, math.min(16, math.floor(btnH * (14 / 38))))

    if btn.Emblem then
        if btn.Emblem.ClearAllPoints then btn.Emblem:ClearAllPoints() end
        if btn.Emblem.SetPoint then btn.Emblem:SetPoint("CENTER", btn, "CENTER", 0, 1) end
        if btn.Emblem.SetSize then btn.Emblem:SetSize(emblemW, emblemH) end
        if btn.Emblem.SetAlpha then btn.Emblem:SetAlpha(1) end
    end

    if btn.HighlightEmblem then
        if btn.HighlightEmblem.ClearAllPoints then btn.HighlightEmblem:ClearAllPoints() end
        if btn.HighlightEmblem.SetPoint then btn.HighlightEmblem:SetPoint("CENTER", btn, "CENTER", 0, 1) end
        if btn.HighlightEmblem.SetSize then btn.HighlightEmblem:SetSize(emblemW, emblemH) end
    end

    local tabard = btn.Tabard or (btn.GetName and _G[btn:GetName() .. "Tabard"])
    if tabard and tabard ~= btn.Emblem then
        if tabard.ClearAllPoints then tabard:ClearAllPoints() end
        if tabard.SetPoint then tabard:SetPoint("CENTER", btn, "CENTER", 0, 1) end
        if tabard.SetSize then tabard:SetSize(emblemW, emblemH) end
        if tabard.emblem and tabard.emblem.SetSize then tabard.emblem:SetSize(emblemW, emblemH) end
        if tabard.background and tabard.background.SetSize then tabard.background:SetSize(emblemW, emblemH) end
    end

    if btn.UpdateTabard and not btn.roithiTabardHooked and hooksecurefunc then
        btn.roithiTabardHooked = true
        hooksecurefunc(btn, "UpdateTabard", function()
            if self.isUpdatingTabard then return end
            self.isUpdatingTabard = true
            local bW = (btn.GetWidth and btn:GetWidth()) or 28
            local bH = (btn.GetHeight and btn:GetHeight()) or 38
            local eW = math.max(10, math.min(14, math.floor(bW * (12 / 28))))
            local eH = math.max(12, math.min(16, math.floor(bH * (14 / 38))))
            if btn.Emblem and btn.Emblem.SetSize then
                btn.Emblem:SetSize(eW, eH)
            end
            if btn.HighlightEmblem and btn.HighlightEmblem.SetSize then
                btn.HighlightEmblem:SetSize(eW, eH)
            end
            self.isUpdatingTabard = false
        end)
    end

    -- 1px Custom dark backdrop behind button (parented to container, never mutating btn)
    self.backdrops = self.backdrops or {}
    local bg = self.backdrops[btn] or btn.roithiBackdrop
    if not bg then
        local parentFrame = self.container or (btn.GetParent and btn:GetParent()) or UIParent
        bg = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        if bg.SetFrameStrata then bg:SetFrameStrata("BACKGROUND") end
        if bg.EnableMouse then bg:EnableMouse(false) end
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
            local bgColor = (self.db and self.db.backgroundColor) or { r = 0.05, g = 0.05, b = 0.05, a = 0.85 }
            bg:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.85)
            bg:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
        end
        self.backdrops[btn] = bg
    else
        if bg.SetFrameStrata then bg:SetFrameStrata("BACKGROUND") end
        if bg.SetAllPoints then bg:SetAllPoints(btn) end
    end
    if self.db and self.db.showBackground and (btn.IsShown == nil or btn:IsShown()) then
        if bg.Show then bg:Show() end
    else
        if bg.Hide then bg:Hide() end
    end

    -- Hook mouseover events using internal tracking table (zero property mutations on secure btn)
    self.hookedButtons = self.hookedButtons or {}
    if not self.hookedButtons[btn] and btn.HookScript then
        btn:HookScript("OnEnter", function()
            self:OnContainerEnter()
            local b = self.backdrops and self.backdrops[btn]
            if b and self.db and self.db.showBackground and b.SetBackdropBorderColor then
                b:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
            end
            local n = btn.GetNormalTexture and btn:GetNormalTexture()
            if n then
                if n.SetAlpha then n:SetAlpha(1) end
                if n.SetVertexColor then n:SetVertexColor(HOVER_ICON_COLOR, HOVER_ICON_COLOR, HOVER_ICON_COLOR, 1) end
            end
            if btn.Portrait and btn.Portrait.SetVertexColor then
                btn.Portrait:SetVertexColor(HOVER_ICON_COLOR, HOVER_ICON_COLOR, HOVER_ICON_COLOR, 1)
            end
            local h = btn.GetHighlightTexture and btn:GetHighlightTexture()
            if h and h.SetAlpha then h:SetAlpha(0) end
        end)
        btn:HookScript("OnLeave", function()
            self:OnContainerLeave()
            local b = self.backdrops and self.backdrops[btn]
            if b and self.db and self.db.showBackground and b.SetBackdropBorderColor then
                b:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
            end
            local n = btn.GetNormalTexture and btn:GetNormalTexture()
            if n then
                if n.SetAlpha then n:SetAlpha(1) end
                if not isGuildTabard and n.SetVertexColor then
                    n:SetVertexColor(NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, 1)
                end
            end
            if btn.Portrait and btn.Portrait.SetVertexColor then
                btn.Portrait:SetVertexColor(NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, 1)
            end
        end)
        self.hookedButtons[btn] = true
    end

    -- Enforce full alpha and hook SetAlpha / SetNormalAtlas / SetDisabledAtlas to prevent Blizzard dimming
    self.btnHooks = self.btnHooks or {}
    self.settingAlpha = self.settingAlpha or {}
    self.settingAtlas = self.settingAtlas or {}
    self.settingTex = self.settingTex or {}
    self.settingDesat = self.settingDesat or {}
    self.settingColor = self.settingColor or {}
    if not self.btnHooks[btn] and hooksecurefunc then
        if btn.SetAlpha then
            hooksecurefunc(btn, "SetAlpha", function(b, a)
                if a < 1 and not self.settingAlpha[b] then
                    self.settingAlpha[b] = true
                    b:SetAlpha(1)
                    self.settingAlpha[b] = nil
                end
            end)
        end
        if btn.SetNormalAtlas then
            hooksecurefunc(btn, "SetNormalAtlas", function(b, atlasName)
                if atlasName and not self.settingAtlas[b] and not self.isUpdatingTabard then
                    if (b == _G.GuildMicroButton) or atlasName:find("GuildColor") or atlasName:find("GuildCommunities%-GuildColor") then
                        return
                    end
                    if atlasName:find("%-Up$") or atlasName:find("%-Disabled$") then
                        self.settingAtlas[b] = true
                        b:SetNormalAtlas(atlasName:gsub("%-Disabled$", "-Mouseover"):gsub("%-Up$", "-Mouseover"))
                        self.settingAtlas[b] = nil
                    end
                end
            end)
        end
        if btn.SetDisabledAtlas then
            hooksecurefunc(btn, "SetDisabledAtlas", function(b, atlas)
                if atlas and not self.settingAtlas[b] and not self.isUpdatingTabard then
                    if (b == _G.GuildMicroButton) or atlas:find("GuildColor") or atlas:find("GuildCommunities%-GuildColor") then
                        return
                    end
                    if atlas:find("%-Disabled$") or atlas:find("%-Up$") then
                        self.settingAtlas[b] = true
                        b:SetDisabledAtlas(atlas:gsub("%-Disabled$", "-Mouseover"):gsub("%-Up$", "-Mouseover"))
                        self.settingAtlas[b] = nil
                    end
                end
            end)
        end
        if btn.SetDisabledTexture then
            hooksecurefunc(btn, "SetDisabledTexture", function(b, tex)
                if type(tex) == "string" and tex:find("Disabled") and not self.settingTex[b] and not self.isUpdatingTabard then
                    self.settingTex[b] = true
                    b:SetDisabledTexture(tex:gsub("Disabled", "Up"))
                    self.settingTex[b] = nil
                end
            end)
        end
        if btn.SetButtonState then
            hooksecurefunc(btn, "SetButtonState", function(b)
                local n = b.GetNormalTexture and b:GetNormalTexture()
                if n then
                    local isTabard = (b == _G.GuildMicroButton or (b.GetName and b:GetName() == "GuildMicroButton")) and (
                        (b.Emblem and b.Emblem.IsShown and b.Emblem:IsShown()) or
                        (b.textureName and type(b.textureName) == "string" and b.textureName:find("GuildColor"))
                    )
                    if not isTabard then
                        if n.SetDesaturated then n:SetDesaturated(false) end
                        if n.SetVertexColor then
                            n:SetVertexColor(NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, 1)
                        end
                    end
                    if n.SetAlpha then n:SetAlpha(1) end
                end
            end)
        end
        if btn.SetNormal and (btn.Portrait or (btn == _G.CharacterMicroButton) or (btn.GetName and btn:GetName() == "CharacterMicroButton")) then
            hooksecurefunc(btn, "SetNormal", function(b)
                local p = b.Portrait or _G.MicroButtonPortrait
                if p then
                    p:ClearAllPoints()
                    p:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
                    p:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
                    if p.Show then p:Show() end
                end
                if b.PortraitMask then
                    b.PortraitMask:ClearAllPoints()
                    b.PortraitMask:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
                    b.PortraitMask:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
                    if b.PortraitMask.SetTexture then
                        b.PortraitMask:SetTexture("Interface\\Buttons\\WHITE8x8")
                    end
                    if b.PortraitMask.Show then b.PortraitMask:Show() end
                    if b.PortraitMask.SetAlpha then b.PortraitMask:SetAlpha(1) end
                end
            end)
        end
        if btn.SetPushed and (btn.Portrait or (btn == _G.CharacterMicroButton) or (btn.GetName and btn:GetName() == "CharacterMicroButton")) then
            hooksecurefunc(btn, "SetPushed", function(b)
                local p = b.Portrait or _G.MicroButtonPortrait
                if p then
                    p:ClearAllPoints()
                    p:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
                    p:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
                    if p.Show then p:Show() end
                end
                if b.PortraitMask then
                    b.PortraitMask:ClearAllPoints()
                    b.PortraitMask:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
                    b.PortraitMask:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
                    if b.PortraitMask.SetTexture then
                        b.PortraitMask:SetTexture("Interface\\Buttons\\WHITE8x8")
                    end
                    if b.PortraitMask.Show then b.PortraitMask:Show() end
                    if b.PortraitMask.SetAlpha then b.PortraitMask:SetAlpha(1) end
                end
            end)
        end
        self.btnHooks[btn] = true
    end
    if norm and not self.btnHooks[norm] and hooksecurefunc then
        self.btnHooks[norm] = true
        if norm.SetAtlas then
            hooksecurefunc(norm, "SetAtlas", function(t, atlasName)
                if atlasName and not self.settingAtlas[t] and not self.isUpdatingTabard then
                    if (btn == _G.GuildMicroButton) or atlasName:find("GuildColor") or atlasName:find("GuildCommunities%-GuildColor") then
                        return
                    end
                    if atlasName:find("%-Up$") or atlasName:find("%-Disabled$") then
                        self.settingAtlas[t] = true
                        t:SetAtlas(atlasName:gsub("%-Disabled$", "-Mouseover"):gsub("%-Up$", "-Mouseover"))
                        self.settingAtlas[t] = nil
                    end
                end
            end)
        end
        if norm.SetDesaturated then
            hooksecurefunc(norm, "SetDesaturated", function(t, desat)
                if desat and not self.settingDesat[t] then
                    self.settingDesat[t] = true
                    t:SetDesaturated(false)
                    self.settingDesat[t] = nil
                end
            end)
        end
        if norm.SetVertexColor then
            hooksecurefunc(norm, "SetVertexColor", function(t, r, g, b, a)
                local isTabard = (btn == _G.GuildMicroButton or (btn.GetName and btn:GetName() == "GuildMicroButton")) and (
                    (btn.Emblem and btn.Emblem.IsShown and btn.Emblem:IsShown()) or
                    (btn.textureName and type(btn.textureName) == "string" and btn.textureName:find("GuildColor"))
                )
                if not isTabard and (r < (NORMAL_ICON_COLOR - 0.1) or g < (NORMAL_ICON_COLOR - 0.1) or b < (NORMAL_ICON_COLOR - 0.1)) and not self.settingColor[t] then
                    self.settingColor[t] = true
                    t:SetVertexColor(NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, a or 1)
                    self.settingColor[t] = nil
                end
            end)
        end
    end
    if btn.Portrait and not self.btnHooks[btn.Portrait] and hooksecurefunc then
        self.btnHooks[btn.Portrait] = true
        if btn.Portrait.SetDesaturated then
            hooksecurefunc(btn.Portrait, "SetDesaturated", function(t, desat)
                if desat and not self.settingDesat[t] then
                    self.settingDesat[t] = true
                    t:SetDesaturated(false)
                    self.settingDesat[t] = nil
                end
            end)
        end
        if btn.Portrait.SetVertexColor then
            hooksecurefunc(btn.Portrait, "SetVertexColor", function(t, r, g, b, a)
                if (r < (NORMAL_ICON_COLOR - 0.1) or g < (NORMAL_ICON_COLOR - 0.1) or b < (NORMAL_ICON_COLOR - 0.1)) and not self.settingColor[t] then
                    self.settingColor[t] = true
                    t:SetVertexColor(NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, NORMAL_ICON_COLOR, a or 1)
                    self.settingColor[t] = nil
                end
            end)
        end
    end
    if btn.SetAlpha then btn:SetAlpha(1) end
end

function MenuMod:StyleAllMicroButtons()
    if self.isStylingMicroButtons then return end
    self.isStylingMicroButtons = true
    local buttons = self:GetMicroButtons()
    for _, btn in ipairs(buttons) do
        self:StyleMicroButton(btn)
    end
    self.isStylingMicroButtons = false
end

function MenuMod:LayoutMicroMenu()
    if self.isLayoutingMicroMenu then return end
    self.isLayoutingMicroMenu = true

    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.isLayoutingMicroMenu = false
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    if not self.container then
        self.isLayoutingMicroMenu = false
        return
    end

    local buttons = self:GetMicroButtons()
    local activeButtons = {}
    for _, btn in ipairs(buttons) do
        if btn and (btn.IsShown == nil or btn:IsShown()) then
            table.insert(activeButtons, btn)
        else
            local bg = self.backdrops and self.backdrops[btn]
            if bg and bg.Hide then bg:Hide() end
        end
    end
    if #activeButtons == 0 then
        self.isLayoutingMicroMenu = false
        return
    end

    local btnW = self.db.buttonWidth or 24
    local btnH = self.db.buttonHeight or 32
    local spacing = self.db.spacing or 2
    local isHoriz = (self.db.orientation or "HORIZONTAL") == "HORIZONTAL"

    local totalW = isHoriz and (#activeButtons * btnW + (#activeButtons - 1) * spacing) or btnW
    local totalH = isHoriz and btnH or (#activeButtons * btnH + (#activeButtons - 1) * spacing)
    if self.container.SetSize then
        self.container:SetSize(totalW, totalH)
    end

    for i, btn in ipairs(activeButtons) do
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

        self.btnPointHooked = self.btnPointHooked or {}
        if not self.btnPointHooked[btn] and hooksecurefunc and btn.SetPoint then
            hooksecurefunc(btn, "SetPoint", function(b)
                if self.isLayoutingMicroMenu then return end
                if _G.InCombatLockdown and _G.InCombatLockdown() then return end
                local _, relTo = b:GetPoint(1)
                if relTo ~= self.container then
                    self:QueueLayoutMicroMenu()
                end
            end)
            self.btnPointHooked[btn] = true
        end

        self:StyleMicroButton(btn)
    end

    self:UpdateContainerBackdrop()
    self:UpdateMicroMenuAlpha()
    self.isLayoutingMicroMenu = false
end

function MenuMod:UpdateContainerBackdrop()
    if self.backdrops then
        local bgColor = (self.db and self.db.backgroundColor) or { r = 0.05, g = 0.05, b = 0.05, a = 0.85 }
        for btn, bg in pairs(self.backdrops) do
            if self.db and self.db.showBackground and (btn.IsShown == nil or btn:IsShown()) then
                if bg.Show then bg:Show() end
                if bg.SetFrameStrata then bg:SetFrameStrata("BACKGROUND") end
                if bg.SetBackdropColor then
                    bg:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.85)
                end
            else
                if bg.Hide then bg:Hide() end
            end
        end
    end
    if not self.container then return end
    if self.container.SetBackdrop then
        self.container:SetBackdrop(nil)
    end
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

function MenuMod:ApplyMicroMenuAlpha(alpha)
    if self.container and self.container.SetAlpha then
        self.container:SetAlpha(alpha)
    end
    if _G.MicroMenu and _G.MicroMenu.SetAlpha then
        _G.MicroMenu:SetAlpha(alpha)
    end
    if _G.MicroButtonAndBagsBar and _G.MicroButtonAndBagsBar.SetAlpha then
        _G.MicroButtonAndBagsBar:SetAlpha(alpha)
    end
    if not _G.MicroMenu and not _G.MicroButtonAndBagsBar then
        for _, btn in ipairs(self:GetMicroButtons()) do
            if btn.SetAlpha then btn:SetAlpha(alpha) end
        end
    end
end

function MenuMod:UpdateMicroMenuAlpha()
    local targetAlpha
    if self.db.mouseover then
        targetAlpha = self:IsMicroMenuMouseOver() and (self.db.alpha or 1.0) or (self.db.mouseoverAlpha or 0.0)
    else
        targetAlpha = self.db.alpha or 1.0
    end
    self:ApplyMicroMenuAlpha(targetAlpha)
end

function MenuMod:OnContainerEnter()
    if self.db.mouseover then
        self:ApplyMicroMenuAlpha(self.db.alpha or 1.0)
    end
end

function MenuMod:OnContainerLeave()
    if self.db.mouseover and _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.05, function()
            if not self:IsMicroMenuMouseOver() then
                self:ApplyMicroMenuAlpha(self.db.mouseoverAlpha or 0.0)
            end
        end)
    end
end

function MenuMod:RefreshSettings()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Menu or self.defaultSettings
    if self.container then
        local pt = self.db.point or "BOTTOMRIGHT"
        if self.container.ClearAllPoints then self.container:ClearAllPoints() end
        if self.container.SetPoint then
            self.container:SetPoint(pt, UIParent, pt, self.db.x or -280, self.db.y or 0)
        end
    end
    self:StyleAllMicroButtons()
    self:LayoutMicroMenu()
    if LEM and LEM.RefreshFrameSettings and self.container then
        LEM:RefreshFrameSettings(self.container)
    end
end
MenuMod.RefreshProfile = MenuMod.RefreshSettings
