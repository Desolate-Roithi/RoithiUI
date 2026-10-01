local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ChatMod = RoithiUI:NewModule("Chat", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LibRoithi = LibStub("LibRoithi-1.0")

ChatMod.displayName = L["Chat"] or "Chat"
ChatMod.description = L["Modern minimalist chat reskin with restylable background, edit box, and tabs."] or "Modern minimalist chat reskin with restylable background, edit box, and tabs."
ChatMod.order = 86
ChatMod.dbKey = "Chat"

ChatMod.defaultSettings = {
    enabled = true,
    showBackground = true,
    backgroundColor = { r = 0.03, g = 0.045, b = 0.05, a = 0.65 },
    showBorder = true,
    borderColor = { r = 0.15, g = 0.15, b = 0.15, a = 1.0 },
    borderSize = 1,
    font = "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf",
    fontSize = 12,
    fontOutline = "OUTLINE",
    editBoxHeight = 24,
    editBoxPosition = "BOTTOM", -- "BOTTOM" or "TOP"
    editBoxBgColor = { r = 0.05, g = 0.065, b = 0.08, a = 0.9 },
    editBoxBorderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
    hideBlizzardChrome = true,
    styleTabs = true,
    tabHeight = 22,
    tabFontSize = 11,
    tabAlphaInactive = 0.5,
    tabAlphaActive = 1.0,
}

local hiddenParent = nil
local skinnedFrames = setmetatable({}, { __mode = "k" })
local skinnedTabs = setmetatable({}, { __mode = "k" })
local skinnedEditBoxes = setmetatable({}, { __mode = "k" })

local function GetHiddenParent()
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame")
        hiddenParent:Hide()
    end
    return hiddenParent
end

function ChatMod:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Chat or self.defaultSettings
end

function ChatMod:OnEnable()
    if self.db.enabled == false then return end

    self:CreateChatBackground()
    self:SkinAllChatFrames()

    -- Events for dynamic whisper windows without hooking FCF_OpenTemporaryWindow
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisperEvent")
    self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "OnWhisperEvent")
    self:RegisterEvent("CHAT_MSG_BN_WHISPER", "OnWhisperEvent")
    self:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM", "OnWhisperEvent")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    if _G.FCF_OpenNewWindow then
        self:SecureHook("FCF_OpenNewWindow", function()
            C_Timer.After(0.1, function()
                if self.SkinAllChatFrames then
                    self:SkinAllChatFrames()
                end
            end)
        end)
    end
end

function ChatMod:OnDisable()
    if self.bgPanel then
        self.bgPanel:Hide()
    end
end

function ChatMod:OnPlayerEnteringWorld()
    C_Timer.After(0.2, function()
        if self.SkinAllChatFrames then
            self:SkinAllChatFrames()
        end
        if self.UpdateBackgroundPosition then
            self:UpdateBackgroundPosition()
        end
    end)
end

function ChatMod:OnWhisperEvent()
    C_Timer.After(0.05, function()
        if self.SkinAllChatFrames then
            self:SkinAllChatFrames()
        end
    end)
end

-------------------------------------------------------------------------------
-- Background Panel
-------------------------------------------------------------------------------
function ChatMod:CreateChatBackground()
    if self.bgPanel then return end

    local panel = CreateFrame("Frame", "RoithiChatBackground", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("BACKGROUND")
    panel:SetFrameLevel(1)
    panel:EnableMouse(false)

    LibRoithi.mixins:CreateBackdrop(panel)
    self.bgPanel = panel
    self:UpdateBackgroundStyle()
    self:UpdateBackgroundPosition()
end

function ChatMod:UpdateBackgroundStyle()
    if not self.bgPanel then return end
    if not self.db.showBackground then
        self.bgPanel:Hide()
        return
    end

    self.bgPanel:Show()
    local bg = self.db.backgroundColor or self.defaultSettings.backgroundColor
    self.bgPanel:SetBackdropColor(bg.r or 0.03, bg.g or 0.045, bg.b or 0.05, bg.a or 0.65)

    if self.db.showBorder then
        local border = self.db.borderColor or self.defaultSettings.borderColor
        self.bgPanel:SetBackdropBorderColor(border.r or 0.15, border.g or 0.15, border.b or 0.15, border.a or 1.0)
    else
        self.bgPanel:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

function ChatMod:UpdateBackgroundPosition()
    if not self.bgPanel then return end
    local cf1 = _G.ChatFrame1
    if not cf1 then return end

    local ebHeight = self.db.editBoxHeight or 24
    local isTop = (self.db.editBoxPosition == "TOP")

    self.bgPanel:ClearAllPoints()
    if isTop then
        self.bgPanel:SetPoint("TOPLEFT", cf1, "TOPLEFT", -6, 26 + ebHeight + 4)
        self.bgPanel:SetPoint("BOTTOMRIGHT", cf1, "BOTTOMRIGHT", 6, -6)
    else
        self.bgPanel:SetPoint("TOPLEFT", cf1, "TOPLEFT", -6, 26)
        self.bgPanel:SetPoint("BOTTOMRIGHT", cf1, "BOTTOMRIGHT", 6, -6 - ebHeight - 4)
    end
end

-------------------------------------------------------------------------------
-- Frame Skinning
-------------------------------------------------------------------------------
function ChatMod:SkinAllChatFrames()
    if self.db.enabled == false then return end

    for i = 1, 20 do
        local cf = _G["ChatFrame" .. i]
        if cf then
            self:SkinChatFrame(cf, i)
        end
    end

    if self.db.hideBlizzardChrome then
        self:HideBlizzardChrome()
    end
end

function ChatMod:SkinChatFrame(cf, idx)
    if not cf then return end

    local cfName = cf:GetName()
    if not cfName then return end

    -- Hide Blizzard standard textures
    local topTex = _G[cfName .. "TopTexture"]
    local midTex = _G[cfName .. "MiddleTexture"]
    local botTex = _G[cfName .. "BottomTexture"]
    if topTex and topTex.SetTexture then topTex:SetTexture("") end
    if midTex and midTex.SetTexture then midTex:SetTexture("") end
    if botTex and botTex.SetTexture then botTex:SetTexture("") end

    -- Apply font
    if cf.SetFont then
        local font = self.db.font or "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf"
        local size = self.db.fontSize or 12
        local outline = self.db.fontOutline or "OUTLINE"
        pcall(cf.SetFont, cf, font, size, outline)
    end

    -- Scrollbar styling: hide arrow buttons
    if cf.ScrollBar and not skinnedFrames[cf.ScrollBar] then
        local bar = cf.ScrollBar
        local hp = GetHiddenParent()
        if bar.Back then bar.Back:SetParent(hp) end
        if bar.Forward then bar.Forward:SetParent(hp) end
        skinnedFrames[bar] = true
    end

    -- Skin EditBox
    local eb = _G[cfName .. "EditBox"]
    if eb then
        self:SkinEditBox(eb, cf, idx)
    end

    -- Skin Tab
    local tab = _G[cfName .. "Tab"]
    if tab then
        self:SkinTab(tab, cf, idx)
    end

    -- Hide per-frame button frame
    local btnFrame = _G[cfName .. "ButtonFrame"]
    if btnFrame and self.db.hideBlizzardChrome then
        btnFrame:SetParent(GetHiddenParent())
    end

    skinnedFrames[cf] = true
end

-------------------------------------------------------------------------------
-- EditBox Skinning
-------------------------------------------------------------------------------
function ChatMod:SkinEditBox(eb, cf, idx)
    if not eb or skinnedEditBoxes[eb] then return end
    skinnedEditBoxes[eb] = true

    local name = cf:GetName()
    if not name then return end

    -- Strip default Blizzard textures
    local texList = {
        name .. "EditBoxLeft", name .. "EditBoxMid", name .. "EditBoxRight",
        name .. "EditBoxFocusLeft", name .. "EditBoxFocusMid", name .. "EditBoxFocusRight",
    }
    for _, texName in ipairs(texList) do
        local tex = _G[texName]
        if tex and tex.SetAlpha then tex:SetAlpha(0) end
    end
    if eb.focusLeft then eb.focusLeft:SetAlpha(0) end
    if eb.focusMid then eb.focusMid:SetAlpha(0) end
    if eb.focusRight then eb.focusRight:SetAlpha(0) end

    -- Reposition EditBox
    local ebHeight = self.db.editBoxHeight or 24
    local isTop = (self.db.editBoxPosition == "TOP")

    eb:ClearAllPoints()
    if isTop then
        eb:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", -2, 28)
        eb:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT", 2, 28)
    else
        eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -2, -6)
        eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 2, -6)
    end
    eb:SetHeight(ebHeight)

    -- Create backdrop frame behind editbox
    if not eb.roithiBackdrop then
        local bg = CreateFrame("Frame", nil, eb, "BackdropTemplate")
        bg:SetAllPoints(eb)
        bg:SetFrameLevel(math.max(0, eb:GetFrameLevel() - 1))
        bg:EnableMouse(false)
        LibRoithi.mixins:CreateBackdrop(bg)

        local cfgBg = self.db.editBoxBgColor or self.defaultSettings.editBoxBgColor
        local cfgBorder = self.db.editBoxBorderColor or self.defaultSettings.editBoxBorderColor
        bg:SetBackdropColor(cfgBg.r or 0.05, cfgBg.g or 0.065, cfgBg.b or 0.08, cfgBg.a or 0.9)
        bg:SetBackdropBorderColor(cfgBorder.r or 0.2, cfgBorder.g or 0.2, cfgBorder.b or 0.2, cfgBorder.a or 1.0)
        eb.roithiBackdrop = bg
    end

    -- Font & insets
    local font = self.db.font or "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf"
    local size = self.db.fontSize or 12
    local outline = self.db.fontOutline or "OUTLINE"
    pcall(eb.SetFont, eb, font, size, outline)
    eb:SetTextInsets(6, 6, 0, 0)

    -- Alt arrow key handling
    if eb.SetAltArrowKeyMode then
        eb:SetAltArrowKeyMode(false)
    end

    -- Hook focus for header text styling (only for docked frames 1-10)
    if idx <= 10 then
        eb:HookScript("OnEditFocusGained", function()
            if eb.header then
                pcall(eb.header.SetFont, eb.header, font, size, outline)
            end
            if eb.headerSuffix then
                pcall(eb.headerSuffix.SetFont, eb.headerSuffix, font, size, outline)
            end
        end)
    end
end

-------------------------------------------------------------------------------
-- Tab Skinning
-------------------------------------------------------------------------------
function ChatMod:SkinTab(tab, cf, idx)
    if not tab or skinnedTabs[tab] then return end
    skinnedTabs[tab] = true

    -- Strip default tab textures
    local regions = { tab:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region:GetObjectType() == "Texture" then
            if region.SetTexture then
                region:SetTexture("")
            end
        end
    end

    local tabText = tab.Text or _G[tab:GetName() .. "Text"]
    if tabText then
        local font = self.db.font or "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf"
        local size = self.db.tabFontSize or 11
        local outline = self.db.fontOutline or "OUTLINE"
        pcall(tabText.SetFont, tabText, font, size, outline)
    end

    local tabHeight = self.db.tabHeight or 22
    tab:SetHeight(tabHeight)

    -- Tab selection hook for active/inactive alpha
    tab:HookScript("OnEnter", function()
        tab:SetAlpha(self.db.tabAlphaActive or 1.0)
    end)
    tab:HookScript("OnLeave", function()
        local isSelected = (cf and cf:IsShown())
        tab:SetAlpha(isSelected and (self.db.tabAlphaActive or 1.0) or (self.db.tabAlphaInactive or 0.5))
    end)

    local isSelected = (cf and cf:IsShown())
    tab:SetAlpha(isSelected and (self.db.tabAlphaActive or 1.0) or (self.db.tabAlphaInactive or 0.5))
end

-------------------------------------------------------------------------------
-- Blizzard Chrome Suppression
-------------------------------------------------------------------------------
function ChatMod:HideBlizzardChrome()
    local hp = GetHiddenParent()

    local framesToHide = {
        _G.ChatFrameChannelButton,
        _G.ChatFrameMenuButton,
        _G.QuickJoinToastButton,
        _G.ChatAlertFrame,
    }

    for _, frame in ipairs(framesToHide) do
        if frame then
            frame:SetParent(hp)
        end
    end
end

function ChatMod:RefreshSettings()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Chat or self.defaultSettings
    self:UpdateBackgroundStyle()
    self:UpdateBackgroundPosition()
    self:SkinAllChatFrames()
end
