local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ChatMod = RoithiUI:NewModule("Chat", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0", true)
local LEM = LibStub("LibEditMode-Roithi", true) or LibStub("LibEditMode-1.0", true)

ChatMod.displayName = L["Chat"] or "Chat"
ChatMod.description = L["Modern minimalist chat reskin with restylable background, edit box, and tabs."] or "Modern minimalist chat reskin with restylable background, edit box, and tabs."
ChatMod.order = 86
ChatMod.dbKey = "Chat"
ChatMod.defaultSettings = ns.ChatDefaults or (ns.Defaults and ns.Defaults.profile and ns.Defaults.profile.Chat)

local hiddenParent = nil
local skinnedFrames = setmetatable({}, { __mode = "k" })
local skinnedTabs = setmetatable({}, { __mode = "k" })
local skinnedEditBoxes = setmetatable({}, { __mode = "k" })
local tabTextures = setmetatable({}, { __mode = "k" })

function ChatMod:GetFontPath()
    local f = self.db and self.db.font or "Interface\\AddOns\\RoithiUI\\Media\\Fonts\\Expressway.ttf"
    if LSM and LSM:Fetch("font", f, true) then
        return LSM:Fetch("font", f)
    end
    return f
end

local function GetHiddenParent()
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame")
        hiddenParent:Hide()
    end
    return hiddenParent
end

local CHAT_FRAME_TEXTURES = {
    "Background",
    "TopLeftTexture",
    "BottomLeftTexture",
    "TopRightTexture",
    "BottomRightTexture",
    "LeftTexture",
    "RightTexture",
    "BottomTexture",
    "TopTexture",
    "MiddleTexture",
    "ButtonFrameBackground",
    "ButtonFrameTopLeftTexture",
    "ButtonFrameBottomLeftTexture",
    "ButtonFrameTopRightTexture",
    "ButtonFrameBottomRightTexture",
    "ButtonFrameLeftTexture",
    "ButtonFrameRightTexture",
    "ButtonFrameBottomTexture",
    "ButtonFrameTopTexture",
}

-- Channel abbreviation filter
local CHAT_FILTER_EVENTS = {
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
}


local RACE_ATLAS_OVERRIDES = {
    scourge = "undead",
    highmountaintauren = "highmountain",
    lightforgeddraenei = "lightforged",
    magharorc = "maghar",
    zandalaritroll = "zandalari",
    darkirondwarf = "darkiron",
    kul_tiran = "kultiran",
    earthendwarf = "earthen",
}

local GROUP_CHANNELS = {
    { format = "CHAT_PARTY_LEADER_GET", default = "Party Leader", short = "PL", token = "PARTY" },
    { format = "CHAT_PARTY_GET", default = "Party", short = "P", token = "PARTY" },
    { format = "CHAT_RAID_LEADER_GET", default = "Raid Leader", short = "RL", token = "RAID" },
    { format = "CHAT_RAID_WARNING_GET", default = "Raid Warning", short = "RW", token = "RAID_WARNING" },
    { format = "CHAT_RAID_GET", default = "Raid", short = "R", token = "RAID" },
    { format = "CHAT_INSTANCE_CHAT_LEADER_GET", default = "Instance Leader", short = "IL", token = "INSTANCE_CHAT" },
    { format = "CHAT_INSTANCE_CHAT_GET", default = "Instance", short = "I", token = "INSTANCE_CHAT" },
    { format = "CHAT_GUILD_GET", default = "Guild", short = "G", token = "GUILD" },
    { format = "CHAT_OFFICER_GET", default = "Officer", short = "O", token = "OFFICER" },
}

local atlasCache = {}
local function HasAtlas(name)
    if not name then return false end
    if atlasCache[name] ~= nil then
        return atlasCache[name]
    end
    local cTexture = _G.C_Texture
    if cTexture and cTexture.GetAtlasInfo then
        local ok, info = pcall(cTexture.GetAtlasInfo, name)
        atlasCache[name] = (ok and type(info) == "table") or false
    else
        atlasCache[name] = true
    end
    return atlasCache[name]
end

local function GetRaceAtlas(race, sex)
    if not race or race == "" then return nil end
    local r = race:lower():gsub("%s+", "")
    r = RACE_ATLAS_OVERRIDES[r] or r
    local s = (sex == 3) and "female" or "male"

    local atlas = "raceicon128-" .. r .. "-" .. s
    if HasAtlas(atlas) then return atlas end

    atlas = "raceicon-" .. r .. "-" .. s
    if HasAtlas(atlas) then return atlas end

    atlas = "raceicon128-" .. r
    if HasAtlas(atlas) then return atlas end

    atlas = "raceicon-" .. r
    if HasAtlas(atlas) then return atlas end

    return nil
end

local function GetClassAtlas(class)
    if not class or class == "" then return nil end
    local c = class:lower():gsub("%s+", "")
    local atlas = "classicon-" .. c
    if HasAtlas(atlas) then return atlas end
    return nil
end

local speakers = {}
local speakerCount = 0
local MAX_SPEAKERS = 2000
local playerNameToGuid = {}

local function GetSpeakerInfo(guid)
    if not guid or guid == "" then return nil end
    if speakers[guid] then return speakers[guid] end
    local getInfo = _G.GetPlayerInfoByGUID
    if not getInfo then return nil end

    local ok, _, class, _, race, sex = pcall(getInfo, guid)
    if not ok or (not class and not race) then return nil end

    speakerCount = speakerCount + 1
    if speakerCount > MAX_SPEAKERS then
        local wipeFunc = _G.wipe
        if wipeFunc then wipeFunc(speakers) else speakers = {} end
        speakerCount = 1
    end

    speakers[guid] = {
        class = class,
        race = race,
        sex = sex,
    }
    return speakers[guid]
end

local function GetFormatBracketText(formatName, defaultText)
    local fmt = _G[formatName]
    if type(fmt) == "string" then
        local text = fmt:match("%[(.-)%]")
        if text and text ~= "" then
            return text
        end
    end
    return defaultText
end

function ChatMod:GetSpeakerIcons(guid)
    if not guid or guid == "" then return nil end
    local showClass = self.db and self.db.showClassIcons ~= false
    local showRace = self.db and self.db.showRaceIcons ~= false
    if not (showClass or showRace) then return nil end

    local info = GetSpeakerInfo(guid)
    if not info then return nil end

    local size = math.floor(tonumber(self.db and self.db.chatIconSize) or 14)
    local out = ""

    if showRace and info.race then
        local atlas = GetRaceAtlas(info.race, info.sex)
        if atlas then
            out = out .. string.format("|A:%s:%d:%d|a", atlas, size, size)
        end
    end

    if showClass and info.class then
        local atlas = GetClassAtlas(info.class)
        if atlas then
            out = out .. string.format("|A:%s:%d:%d|a", atlas, size, size)
        end
    end

    return (out ~= "") and (out .. " ") or nil
end

local function IsSecretString(str)
    if not str then return false end
    if _G.issecretvalue and _G.issecretvalue(str) then return true end
    if _G.canaccessvalue and not _G.canaccessvalue(str) then return true end
    if type(str) == "userdata" then return true end
    return false
end

local function IsChannelNoticeMessage(text, eventArgs)
    if not text or type(text) ~= "string" then return false end
    if eventArgs then
        if eventArgs.event == "CHAT_MSG_CHANNEL_NOTICE" or eventArgs.event == "CHAT_MSG_CHANNEL_NOTICE_USER" then
            return true
        end
        if eventArgs[1] == "CHAT_MSG_CHANNEL_NOTICE" or eventArgs[1] == "CHAT_MSG_CHANNEL_NOTICE_USER" then
            return true
        end
    end
    local noticeGlobals = {
        _G.CHAT_YOU_JOINED_NOTICE,
        _G.CHAT_YOU_JOINED_NOTICE_BN,
        _G.CHAT_YOU_LEFT_NOTICE,
        _G.CHAT_YOU_LEFT_NOTICE_BN,
        _G.CHAT_YOU_CHANGED_NOTICE,
        _G.CHAT_YOU_CHANGED_NOTICE_BN,
        _G.CHAT_SUSPENDED_NOTICE,
    }
    for _, gStr in ipairs(noticeGlobals) do
        if gStr and gStr ~= "" then
            local prefix = gStr:match("^([^|]+)")
            if prefix and text:find(prefix, 1, true) then
                return true
            end
        end
    end
    if text:find("Joined Channel", 1, true)
        or text:find("Left Channel", 1, true)
        or text:find("Changed Channel", 1, true)
        or text:find("Channel beigetreten", 1, true)
        or text:find("Channel verlassen", 1, true)
        or text:find("Channel gewechselt", 1, true)
        or text:find("Kanal beigetreten", 1, true)
        or text:find("Kanal verlassen", 1, true)
        or text:find("Kanal gewechselt", 1, true) then
        return true
    end
    return false
end

function ChatMod:FormatChatMessageText(text, eventArgs)
    if not text or IsSecretString(text) or type(text) ~= "string" or text == "" then return text end
    local out = text

    -- 1. Channel Resolution & Shortening
    local isNotice = IsChannelNoticeMessage(out, eventArgs)
    if isNotice then
        -- Exclude channel notices from number shortening; resolve full channel name
        out = out:gsub("(|Hchannel:[^|]*(%d+)|h)%[(.-)%](|h)", function(linkOpen, chanNumStr, innerText, linkClose)
            local chanNum = tonumber(chanNumStr)
            local chanName = innerText
            if chanNum and _G.GetChannelName then
                local _, resolvedName = _G.GetChannelName(chanNum)
                if resolvedName and resolvedName ~= "" then
                    chanName = resolvedName
                end
            end
            local cleanName = chanName:match("^%d+%.%s*(.+)$") or chanName
            local formattedLabel = chanNumStr .. ". " .. cleanName
            return linkOpen .. "[" .. formattedLabel .. "]" .. linkClose
        end)
    elseif self.db and self.db.shortenChannels ~= false then
        out = out:gsub("(|Hchannel:[^|]*(%d+)|h)%[(.-)%](|h)", "%1[%2]%4")

        for _, grp in ipairs(GROUP_CHANNELS) do
            local label = GetFormatBracketText(grp.format, grp.default)
            if label and label ~= "" then
                local escaped = label:gsub("(%W)", "%%%1")
                if grp.token then
                    out = out:gsub("(|Hchannel:" .. grp.token .. "|h)%[" .. escaped .. "%](|h)", "%1[" .. grp.short .. "]%2")
                end
                out = out:gsub("(|Hchannel:[^|]+|h)%[" .. escaped .. "%](|h)", "%1[" .. grp.short .. "]%2")
                out = out:gsub("^%[" .. escaped .. "%]", "[" .. grp.short .. "]")
            end
            if grp.default and grp.default ~= label then
                local defEscaped = grp.default:gsub("(%W)", "%%%1")
                if grp.token then
                    out = out:gsub("(|Hchannel:" .. grp.token .. "|h)%[" .. defEscaped .. "%](|h)", "%1[" .. grp.short .. "]%2")
                end
                out = out:gsub("(|Hchannel:[^|]+|h)%[" .. defEscaped .. "%](|h)", "%1[" .. grp.short .. "]%2")
                out = out:gsub("^%[" .. defEscaped .. "%]", "[" .. grp.short .. "]")
            end
        end
    end

    -- 2. Race and Class Icons
    local showClass = self.db and self.db.showClassIcons ~= false
    local showRace = self.db and self.db.showRaceIcons ~= false
    if showClass or showRace then
        local guid = nil
        if type(eventArgs) == "table" then
            guid = rawget(eventArgs, 12)
        end

        local playerAt = out:find("|Hplayer:", 1, true)
        if playerAt then
            if not guid then
                local senderName = out:match("|Hplayer:([^:|]+)")
                if senderName and playerNameToGuid[senderName] then
                    guid = playerNameToGuid[senderName]
                end
            end

            if guid then
                local lead = out:sub(1, playerAt - 1)
                if not (lead:find("|A:raceicon", 1, true) or lead:find("|A:classicon%-", 1, true)) then
                    local icons = self:GetSpeakerIcons(guid)
                    if icons and icons ~= "" then
                        out = out:sub(1, playerAt - 1) .. icons .. out:sub(playerAt)
                    end
                end
            end
        end
    end

    return out
end

function ChatMod:FormatChatMessage(frame, text, eventArgs)
    if not self.db or self.db.enabled == false then return end
    if not text or IsSecretString(text) or type(text) ~= "string" or text == "" then return end

    local newText = self:FormatChatMessageText(text, eventArgs)
    if newText and newText ~= text then
        if type(frame.TransformMessages) == "function" then
            pcall(frame.TransformMessages, frame,
                function(msg)
                    local usable, same = pcall(function() return msg == text end)
                    return usable and same
                end,
                function(msg, ...)
                    return newText, ...
                end
            )
        end
    end
end

local function ShortenChannelFilter(frame, event, msg, sender, ...)
    -- GUID is at offset 9 of ... (after msg+sender consumed: lang=1, chanStr=2,
    -- target=3, flags=4, unk=5, chanNum=6, chanName=7, lineID=8, guid=9)
    local guid = select(9, ...)
    if sender and guid and type(sender) == "string" and type(guid) == "string" then
        playerNameToGuid[sender] = guid
    end
    if ChatMod.db and ChatMod.db.linkURLs and msg and type(msg) == "string" then
        msg = msg:gsub("((https?://%S+))", "|cff1e90ff|Hurl:%1|h[%1]|h|r")
        msg = msg:gsub("((www%.%S+))", "|cff1e90ff|Hurl:%1|h[%1]|h|r")
    end
    -- CRITICAL: sender must be included in the return or all positional args shift
    -- left by one, landing the GUID in lineID position and crashing IsChatLineCensored.
    return false, msg, sender, ...
end

function ChatMod:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Chat or self.defaultSettings
    if self.db then
        for k, v in pairs(self.defaultSettings) do
            if self.db[k] == nil then
                self.db[k] = v
            end
        end
    end

    if _G.StaticPopupDialogs and not _G.StaticPopupDialogs["ROITHI_CHAT_COPY_URL"] then
        _G.StaticPopupDialogs["ROITHI_CHAT_COPY_URL"] = {
            text = "URL: (Ctrl+C to Copy)",
            button1 = _G.OKAY or "OK",
            hasEditBox = true,
            hasWideEditBox = true,
            editBoxWidth = 350,
            OnShow = function(dlg, data)
                local eb = dlg.wideEditBox or dlg.editBox
                if eb then
                    eb:SetText(data or "")
                    eb:SetFocus()
                    eb:HighlightText()
                end
            end,
            EditBoxOnEnterPressed = function(dlg)
                dlg:GetParent():Hide()
            end,
            EditBoxOnEscapePressed = function(dlg)
                dlg:GetParent():Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
    end

    if not self.urlHooked and hooksecurefunc then
        hooksecurefunc("SetItemRef", function(link)
            if link and type(link) == "string" and link:sub(1, 4) == "url:" then
                local url = link:sub(5)
                if _G.StaticPopup_Show then
                    _G.StaticPopup_Show("ROITHI_CHAT_COPY_URL", url, nil, url)
                end
            end
        end)
        self.urlHooked = true
    end
end

function ChatMod:OnEnable()
    if self.db.enabled == false then return end

    self:CreateChatBackground()
    self:SkinAllChatFrames()
    self:ApplyTimestampFormat()
    self:UpdateButtonsDock()
    self:ApplyScreenClamping()
    self:RegisterWithEditMode()

    -- Hook EditModeManagerFrame to ensure chat clamp insets never restrict edge movement
    if _G.EditModeManagerFrame and not self.editModeHooked and hooksecurefunc then
        self.editModeHooked = true
        _G.EditModeManagerFrame:HookScript("OnShow", function()
            self:ApplyScreenClamping()
            if self.UpdateEditModeSelection then
                self:UpdateEditModeSelection()
            end
        end)
        _G.EditModeManagerFrame:HookScript("OnHide", function()
            self:ApplyScreenClamping()
            self:UpdateBackgroundPosition()
        end)
    end

    -- Voice Chat events to refresh button dock
    self:RegisterEvent("VOICE_CHAT_LOGIN", "OnVoiceStateChanged")
    self:RegisterEvent("VOICE_CHAT_LOGOUT", "OnVoiceStateChanged")
    self:RegisterEvent("VOICE_CHAT_MUTED_CHANGED", "OnVoiceStateChanged")
    self:RegisterEvent("VOICE_CHAT_DEAFENED_CHANGED", "OnVoiceStateChanged")

    -- Events for dynamic whisper windows without hooking FCF_OpenTemporaryWindow
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisperEvent")
    self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "OnWhisperEvent")
    self:RegisterEvent("CHAT_MSG_BN_WHISPER", "OnWhisperEvent")
    self:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM", "OnWhisperEvent")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    -- Re-apply timestamp CVar after Blizzard has fully initialized all CVars
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")

    if _G.FCF_OpenNewWindow and not self:IsHooked("FCF_OpenNewWindow") then
        self:SecureHook("FCF_OpenNewWindow", function()
            C_Timer.After(0.1, function()
                if self.SkinAllChatFrames then
                    self:SkinAllChatFrames()
                end
            end)
        end)
    end

    if _G.FloatingChatFrame_Update and not self:IsHooked("FloatingChatFrame_Update") then
        self:SecureHook("FloatingChatFrame_Update", function()
            if self.UpdateButtonsDock then
                self:UpdateButtonsDock()
            end
        end)
    end
    if _G.FCFDock_UpdateTabs and not self:IsHooked("FCFDock_UpdateTabs") then
        self:SecureHook("FCFDock_UpdateTabs", function()
            if self.UpdateButtonsDock then
                self:UpdateButtonsDock()
            end
        end)
    end

    if _G.ChatFrame_AddMessageEventFilter and not self.filterRegistered then
        for _, ev in ipairs(CHAT_FILTER_EVENTS) do
            _G.ChatFrame_AddMessageEventFilter(ev, ShortenChannelFilter)
        end
        self.filterRegistered = true
    end
end

function ChatMod:OnDisable()
    if self.bgPanel then
        self.bgPanel:Hide()
    end
    if self.buttonDock then
        self.buttonDock:Hide()
    end
    if self.copyWindow then
        self.copyWindow:Hide()
    end
    self:UnregisterAllEvents()
    self:UnhookAll()
end

function ChatMod:OnPlayerEnteringWorld()
    C_Timer.After(0.2, function()
        if self.SkinAllChatFrames then
            self:SkinAllChatFrames()
        end
        if self.UpdateBackgroundPosition then
            self:UpdateBackgroundPosition()
        end
        if self.UpdateButtonsDock then
            self:UpdateButtonsDock()
        end
        if self.ApplyTimestampFormat then
            self:ApplyTimestampFormat()
        end
    end)
end

function ChatMod:OnPlayerLogin()
    -- CVars are fully initialized at PLAYER_LOGIN; force-apply timestamp format here
    -- to guarantee it takes effect even if OnEnable fired before CVar tables were ready.
    C_Timer.After(0, function()
        if self.ApplyTimestampFormat then
            self:ApplyTimestampFormat()
        end
    end)

    -- Settings.SetValue only works after Blizzard_SettingsDefinitions_Frame loads.
    -- Hook ADDON_LOADED to catch it if it loads after PLAYER_LOGIN (e.g. on-demand).
    if not self.settingsAddonHooked then
        self.settingsAddonHooked = true
        local function OnAddonLoaded(_, loadedAddon)
            if loadedAddon == "Blizzard_SettingsDefinitions_Frame" then
                C_Timer.After(0, function()
                    if self.ApplyTimestampFormat then
                        self:ApplyTimestampFormat()
                    end
                end)
            end
        end
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", OnAddonLoaded)
        self.settingsAddonFrame = f
    end
end

function ChatMod:OnWhisperEvent()
    C_Timer.After(0.05, function()
        if self.SkinAllChatFrames then
            self:SkinAllChatFrames()
        end
    end)
end

function ChatMod:OnVoiceStateChanged()
    if self.UpdateButtonsDock then
        self:UpdateButtonsDock()
    end
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
    local padX = (self.db.backgroundPaddingX ~= nil) and self.db.backgroundPaddingX or 4
    local padY = (self.db.backgroundPaddingY ~= nil) and self.db.backgroundPaddingY or 4
    local includeEb = (self.db.includeEditBoxInBackground == true)
    local tabH = (self.db.styleTabs ~= false) and (self.db.tabHeight or 22) or 0
    local topExtra = tabH + (isTop and (includeEb and (ebHeight + 4) or 0) or 0)

    self.bgPanel:ClearAllPoints()
    if isTop then
        self.bgPanel:SetPoint("TOPLEFT", cf1, "TOPLEFT", -padX, topExtra + padY)
        self.bgPanel:SetPoint("BOTTOMRIGHT", cf1, "BOTTOMRIGHT", padX, -padY)
    else
        local botOffset = -padY - (includeEb and (ebHeight + 4) or 0)
        self.bgPanel:SetPoint("TOPLEFT", cf1, "TOPLEFT", -padX, topExtra + padY)
        self.bgPanel:SetPoint("BOTTOMRIGHT", cf1, "BOTTOMRIGHT", padX, botOffset)
    end

    if _G.ChatFrame1EditBox and self.RepositionEditBox then
        self:RepositionEditBox(_G.ChatFrame1EditBox, cf1)
    end

    if self.UpdateButtonsDock then
        self:UpdateButtonsDock()
    end

    if self.UpdateEditModeSelection then
        self:UpdateEditModeSelection(cf1)
    end
end

function ChatMod:ApplyChatPosition()
    local cf1 = _G.ChatFrame1
    if not cf1 then return end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end

    local pt = self.db.point or "BOTTOMLEFT"
    local x = self.db.x or 0
    local y = self.db.y or 30
    local w = self.db.width or 460
    local h = self.db.height or 200

    cf1:ClearAllPoints()
    cf1:SetPoint(pt, UIParent, pt, x, y)
    if cf1.SetSize then
        cf1:SetSize(w, h)
    end

    self:UpdateBackgroundPosition()
    if self.UpdateButtonsDock then
        self:UpdateButtonsDock()
    end
end

function ChatMod:RegisterWithEditMode()
    local cf1 = _G.ChatFrame1
    if not cf1 or not LEM or cf1.roithiEditModeRegistered then return end
    cf1.roithiEditModeRegistered = true

    if cf1.SetMovable then cf1:SetMovable(true) end
    if cf1.SetClampedToScreen then cf1:SetClampedToScreen(self.db.clampToScreen == true) end

    cf1.editModeName = L["Chat"] or "Chat"
    local defaults = { point = "BOTTOMLEFT", x = 0, y = 30 }

    local function OnPositionChanged(f, _, point, x, y)
        self.db.point = point
        self.db.x = x
        self.db.y = y
        f:ClearAllPoints()
        f:SetPoint(point, UIParent, point, x, y)
        self:UpdateBackgroundPosition()
        if self.UpdateButtonsDock then
            self:UpdateButtonsDock()
        end
    end

    if _G.Enum and _G.Enum.EditModeSystem and _G.Enum.EditModeSystem.ChatFrame and LEM.AddSystemSettings and self.GetLEMFrameSettings then
        LEM:AddSystemSettings(_G.Enum.EditModeSystem.ChatFrame, self:GetLEMFrameSettings())
        local addSysBtn = LEM.AddSystemSettingsButtons or LEM.AddSystemButtons
        if addSysBtn then
            addSysBtn(LEM, _G.Enum.EditModeSystem.ChatFrame, {
                {
                    text = L["Open Full Settings"] or "Open Full Settings",
                    click = function()
                        if RoithiUI and RoithiUI.OpenSettings then
                            RoithiUI:OpenSettings("chat")
                        elseif LibStub("AceConfigDialog-3.0") then
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "interface_group", "chat")
                            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                        end
                    end,
                },
            })
        end
    end

    if not (_G.Enum and _G.Enum.EditModeSystem and _G.Enum.EditModeSystem.ChatFrame) then
        LEM:AddFrame(cf1, OnPositionChanged, defaults)
        if LEM.AddFrameSettings and self.GetLEMFrameSettings then
            LEM:AddFrameSettings(cf1, self:GetLEMFrameSettings())
        end
        if LEM.AddFrameSettingsButtons then
            LEM:AddFrameSettingsButtons(cf1, {
                {
                    text = L["Open Full Settings"] or "Open Full Settings",
                    click = function()
                        if RoithiUI and RoithiUI.OpenSettings then
                            RoithiUI:OpenSettings("chat")
                        elseif LibStub("AceConfigDialog-3.0") then
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "interface_group", "chat")
                            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                        end
                    end,
                },
            })
        end
    end
end

function ChatMod:UpdateEditModeSelection(cf)
    cf = cf or _G.ChatFrame1
    if not cf or not cf.Selection then return end
    local anchorFrame = (cf == _G.ChatFrame1 and self.bgPanel and self.db.showBackground) and self.bgPanel or cf
    local name = cf.GetName and cf:GetName()
    local tab = name and _G[name .. "Tab"] or cf.Tab
    local eb = name and _G[name .. "EditBox"] or _G.ChatFrame1EditBox
    local isTop = (self.db.editBoxPosition == "TOP")

    cf.Selection:ClearAllPoints()
    cf.Selection:SetPoint("LEFT", anchorFrame, "LEFT", -2, 0)
    cf.Selection:SetPoint("RIGHT", anchorFrame, "RIGHT", 2, 0)

    -- Top boundary: encompass chat tabs and/or top-positioned editbox unconditionally
    if isTop and eb then
        cf.Selection:SetPoint("TOP", eb, "TOP", 0, 2)
    elseif tab and (tab.IsShown == nil or tab:IsShown()) then
        cf.Selection:SetPoint("TOP", tab, "TOP", 0, 2)
    else
        local tabH = (self.db.styleTabs ~= false) and (self.db.tabHeight or 22) or 0
        cf.Selection:SetPoint("TOP", anchorFrame, "TOP", 0, tabH + 2)
    end

    -- Bottom boundary: encompass bottom-positioned editbox unconditionally to prevent screen clipping
    if (not isTop) and eb then
        cf.Selection:SetPoint("BOTTOM", eb, "BOTTOM", 0, -2)
    else
        cf.Selection:SetPoint("BOTTOM", anchorFrame, "BOTTOM", 0, -2)
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

    if not self.fcfColorsHooked and hooksecurefunc then
        hooksecurefunc("FCFTab_UpdateColors", function(selectedTab, selected)
            if self:IsEnabled() and self.UpdateTabVisuals then
                self:UpdateTabVisuals(selectedTab, selected)
            end
        end)
        self.fcfColorsHooked = true
    end

    if not self.fcfSelectDockHooked and hooksecurefunc then
        hooksecurefunc("FCF_SelectDockFrame", function(dock, selectedChatFrame)
            if not self:IsEnabled() or not dock or not dock.DOCKED_CHAT_FRAMES then return end
            for _, dockedFrame in ipairs(dock.DOCKED_CHAT_FRAMES) do
                local t = _G[dockedFrame:GetName() .. "Tab"]
                if t and self.UpdateTabVisuals then
                    self:UpdateTabVisuals(t, dockedFrame == selectedChatFrame)
                end
            end
        end)
        self.fcfSelectDockHooked = true
    end

    if self.db.hideBlizzardChrome then
        self:HideBlizzardChrome()
    end
end

function ChatMod:SkinScrollToBottomButton(btn)
    if not btn or btn.roithiRestyled then return end
    btn.roithiRestyled = true

    if btn.SetSize then btn:SetSize(20, 20) end

    -- Strip default Blizzard textures (beveled borders, corner notches)
    local nt = btn.GetNormalTexture and btn:GetNormalTexture()
    if nt then
        if nt.SetTexture then nt:SetTexture("") end
        if nt.SetAlpha then nt:SetAlpha(0) end
    end
    local pt = btn.GetPushedTexture and btn:GetPushedTexture()
    if pt then
        if pt.SetTexture then pt:SetTexture("") end
        if pt.SetAlpha then pt:SetAlpha(0) end
    end
    local dt = btn.GetDisabledTexture and btn:GetDisabledTexture()
    if dt then
        if dt.SetTexture then dt:SetTexture("") end
        if dt.SetAlpha then dt:SetAlpha(0) end
    end
    if btn.Flash and btn.Flash.SetTexture then
        btn.Flash:SetTexture("")
        if btn.Flash.SetAlpha then btn.Flash:SetAlpha(0) end
    end

    -- Clean RoithiUI backdrop tile
    if not btn.roithiBackdrop then
        local bg = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        bg:SetAllPoints(btn)
        bg:SetFrameLevel(math.max(0, btn:GetFrameLevel() - 1))
        bg:EnableMouse(false)
        LibRoithi.mixins:CreateBackdrop(bg)
        bg:SetBackdropColor(0.08, 0.11, 0.14, 0.85)
        bg:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)
        btn.roithiBackdrop = bg
    end

    -- Clean golden downward chevron icon
    if not btn.roithiArrow then
        local arrow = btn:CreateTexture(nil, "ARTWORK")
        arrow:SetPoint("CENTER", btn, "CENTER", 0, 0)
        arrow:SetSize(12, 12)
        local hasChevron = _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo("uitools-icon-chevron-down")
        if hasChevron and arrow.SetAtlas then
            arrow:SetAtlas("uitools-icon-chevron-down")
            if arrow.SetVertexColor then arrow:SetVertexColor(1, 0.82, 0, 1) end
        else
            arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up")
            arrow:SetTexCoord(0.33, 0.67, 0.33, 0.67)
        end
        btn.roithiArrow = arrow
    end

    if btn.HookScript and not btn.roithiPushedHooked then
        btn.roithiPushedHooked = true
        btn:HookScript("OnMouseDown", function()
            if btn.roithiArrow then
                btn.roithiArrow:SetPoint("CENTER", btn, "CENTER", 0, -1)
            end
        end)
        btn:HookScript("OnMouseUp", function()
            if btn.roithiArrow then
                btn.roithiArrow:SetPoint("CENTER", btn, "CENTER", 0, 0)
            end
        end)
    end

    if btn.SetHighlightTexture then
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        local ht = btn.GetHighlightTexture and btn:GetHighlightTexture()
        if ht then
            if ht.ClearAllPoints then ht:ClearAllPoints() end
            if ht.SetAllPoints then ht:SetAllPoints(btn) end
        end
    end
end

function ChatMod:SkinChatFrame(cf, idx)
    if not cf then return end

    local cfName = cf:GetName()
    if not cfName then return end

    -- Strip all Blizzard background and border textures (eliminates black shadow on right)
    for _, suffix in ipairs(CHAT_FRAME_TEXTURES) do
        local tex = _G[cfName .. suffix] or (cf and cf[suffix])
        if tex then
            if tex.SetTexture then tex:SetTexture("") end
            if tex.SetAlpha then tex:SetAlpha(0) end
            if tex.Hide then tex:Hide() end
        end
    end

    -- Hook cf.Background so Blizzard cannot re-fade it back on mouseover or window alpha updates
    local bg = cf.Background or _G[cfName .. "Background"]
    if bg then
        if bg.SetTexture then bg:SetTexture("") end
        if bg.SetAlpha then bg:SetAlpha(0) end
        if bg.Hide then bg:Hide() end
        if not bg.roithiHooked and hooksecurefunc then
            hooksecurefunc(bg, "SetAlpha", function(f, a)
                if a ~= 0 and ChatMod.db and ChatMod.db.enabled then
                    f:SetAlpha(0)
                end
            end)
            hooksecurefunc(bg, "Show", function(f)
                if ChatMod.db and ChatMod.db.enabled then
                    f:Hide()
                end
            end)
            bg.roithiHooked = true
        end
    end

    -- Sweep stray ChatFrame texture regions
    if cf.GetRegions then
        for _, region in ipairs({ cf:GetRegions() }) do
            if region and region:GetObjectType() == "Texture" then
                local texPath = region.GetTexture and region:GetTexture()
                if texPath and type(texPath) == "string" and (texPath:find("ChatFrame") or texPath:find("UI%-ChatFrame")) then
                    if region.SetTexture then region:SetTexture("") end
                    if region.SetAlpha then region:SetAlpha(0) end
                end
            end
        end
    end

    -- Completely hide per-frame button frame and its textures
    local btnFrame = cf.buttonFrame or _G[cfName .. "ButtonFrame"]
    if btnFrame then
        btnFrame:SetParent(GetHiddenParent())
        btnFrame:Hide()
        btnFrame:SetAlpha(0)
        if btnFrame.GetRegions then
            for _, region in ipairs({ btnFrame:GetRegions() }) do
                if region and region:GetObjectType() == "Texture" then
                    if region.SetTexture then region:SetTexture("") end
                    if region.SetAlpha then region:SetAlpha(0) end
                end
            end
        end
    end

    -- Completely hide Blizzard scrollbar and all its texture elements
    local bar = cf.ScrollBar or _G[cfName .. "ScrollBar"]
    if bar then
        bar:SetParent(GetHiddenParent())
        bar:Hide()
        bar:SetAlpha(0)
        if bar.GetRegions then
            for _, region in ipairs({ bar:GetRegions() }) do
                if region and region:GetObjectType() == "Texture" then
                    if region.SetTexture then region:SetTexture("") end
                    if region.SetAlpha then region:SetAlpha(0) end
                end
            end
        end
        if bar.ThumbTexture then
            bar.ThumbTexture:SetTexture("")
            bar.ThumbTexture:SetAlpha(0)
        end
    end

    -- Restyle Blizzard's default ScrollToBottomButton (Classic & Retail)
    local scrollBottom = cf.ScrollToBottomButton
        or cf.bottomButton
        or cf.BottomButton
        or (cf.buttonFrame and (cf.buttonFrame.bottomButton or cf.buttonFrame.BottomButton))
        or _G[cfName .. "ScrollToBottomButton"]
        or _G[cfName .. "BottomButton"]
    if scrollBottom then
        self:SkinScrollToBottomButton(scrollBottom)
        if scrollBottom.ClearAllPoints and scrollBottom.SetPoint then
            scrollBottom:ClearAllPoints()
            scrollBottom:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -2, 2)
        end
    end

    -- Apply font and shadow
    if cf.SetFont then
        local font = self:GetFontPath()
        local size = self.db.fontSize or 12
        local outline = self.db.fontOutline or "OUTLINE"
        pcall(cf.SetFont, cf, font, size, outline)
        if cf.SetShadowOffset then
            if self.db.showFontShadow then
                cf:SetShadowOffset(1, -1)
                if cf.SetShadowColor then cf:SetShadowColor(0, 0, 0, 1) end
            else
                cf:SetShadowOffset(0, 0)
                if cf.SetShadowColor then cf:SetShadowColor(0, 0, 0, 0) end
            end
        end
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

    -- Re-anchor Blizzard ResizeButton to bottom right of chat frame
    local resizeBtn = cf.ResizeButton or _G[cfName .. "ResizeButton"]
    if resizeBtn then
        resizeBtn:ClearAllPoints()
        resizeBtn:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -1, 1)
        resizeBtn:SetFrameLevel(cf:GetFrameLevel() + 10)
    end

    -- Re-anchor Blizzard EditMode Selection frame flush with styled chat panel
    if cf.Selection then
        if not cf.roithiSelectionHooked then
            cf.roithiSelectionHooked = true
            if cf.Selection.HookScript then
                cf.Selection:HookScript("OnShow", function()
                    self:UpdateEditModeSelection(cf)
                end)
            elseif hooksecurefunc then
                hooksecurefunc(cf.Selection, "Show", function()
                    self:UpdateEditModeSelection(cf)
                end)
            end
        end
        self:UpdateEditModeSelection(cf)
    end
    if cf == _G.ChatFrame1 and not self.cf1SelectionHooked then
        self.cf1SelectionHooked = true
        if cf.OnEditModeEnter and hooksecurefunc then
            hooksecurefunc(cf, "OnEditModeEnter", function()
                self:UpdateEditModeSelection(cf)
            end)
        end
    end

    -- Scroll chat to bottom so messages sit flush against the bottom
    if cf.ScrollToBottom then
        pcall(cf.ScrollToBottom, cf)
    end

    -- Screen Clamping (allow moving directly to the screen edge)
    local clamp = (self.db.clampToScreen == true)
    if cf.SetClampedToScreen then
        cf:SetClampedToScreen(clamp)
    end
    if cf.SetClampRectInsets then
        cf:SetClampRectInsets(0, 0, 0, 0)
    end

    if cf.UpdateClampOffsets and not cf.roithiClampHooked and hooksecurefunc then
        cf.roithiClampHooked = true
        hooksecurefunc(cf, "UpdateClampOffsets", function(s)
            if self:IsEnabled() then
                if self.db.clampToScreen == false and s.SetClampedToScreen then
                    s:SetClampedToScreen(false)
                end
                if s.SetClampRectInsets then
                    s:SetClampRectInsets(0, 0, 0, 0)
                end
            end
        end)
    end

    if cf.HookScript and not cf.roithiSizeHooked then
        cf:HookScript("OnSizeChanged", function()
            if self:IsEnabled() then
                if self.UpdateBackgroundPosition then
                    self:UpdateBackgroundPosition()
                end
                local editBox = _G[cfName .. "EditBox"]
                if editBox and self.RepositionEditBox then
                    self:RepositionEditBox(editBox, cf)
                end
            end
        end)
        cf.roithiSizeHooked = true
    end

    if not cf.roithiAddMessageHooked and hooksecurefunc then
        cf.roithiAddMessageHooked = true
        hooksecurefunc(cf, "AddMessage", function(frame, text, ...)
            local argCount = select("#", ...)
            local eventArgs = nil
            for argIdx = 1, argCount do
                local candidate = select(argIdx, ...)
                if type(candidate) == "table" and rawget(candidate, 12) ~= nil then
                    eventArgs = candidate
                    break
                end
            end
            if not eventArgs and argCount >= 8 then
                local candidate = select(8, ...)
                if type(candidate) == "table" then eventArgs = candidate end
            end
            self:FormatChatMessage(frame, text, eventArgs)
        end)
    end

    skinnedFrames[cf] = true
end

function ChatMod:ApplyScreenClamping()
    local clamp = (self.db.clampToScreen == true)
    for i = 1, 20 do
        local cf = _G["ChatFrame" .. i]
        if cf then
            if cf.SetClampedToScreen then
                cf:SetClampedToScreen(clamp)
            end
            if cf.SetClampRectInsets then
                cf:SetClampRectInsets(0, 0, 0, 0)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- EditBox Skinning
-------------------------------------------------------------------------------
function ChatMod:RepositionEditBox(eb, cf)
    if not eb or not cf then return end

    local ebHeight = self.db.editBoxHeight or 24
    local isTop = (self.db.editBoxPosition == "TOP")
    local padX = (self.db.backgroundPaddingX ~= nil) and self.db.backgroundPaddingX or 4
    local includeEb = (self.db.includeEditBoxInBackground == true)

    local anchorFrame = (cf == _G.ChatFrame1 and self.bgPanel and self.db.showBackground) and self.bgPanel or cf

    eb:ClearAllPoints()
    if anchorFrame == self.bgPanel then
        if includeEb then
            if isTop then
                eb:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 4, -4)
                eb:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT", -4, -4)
            else
                eb:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMLEFT", 4, 4)
                eb:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", -4, 4)
            end
        else
            if isTop then
                eb:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 4)
                eb:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 4)
            else
                eb:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
                eb:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -4)
            end
        end
    else
        if isTop then
            eb:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", -padX, 28)
            eb:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT", padX, 28)
        else
            eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -padX, -6)
            eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", padX, -6)
        end
    end
    eb:SetHeight(ebHeight)
end

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
    self:RepositionEditBox(eb, cf)

    if not eb.roithiShowHooked and eb.HookScript then
        eb:HookScript("OnShow", function(editBox)
            if self:IsEnabled() and self.RepositionEditBox then
                self:RepositionEditBox(editBox, cf)
            end
        end)
        eb.roithiShowHooked = true
    end

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
    local font = self:GetFontPath()
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
function ChatMod:UpdateTabVisuals(tab, isSelected)
    if not tab then return end
    local texs = tabTextures[tab]
    local tabName = tab.GetName and tab:GetName()
    local tabText = (texs and texs.text) or tab.Text or (tabName and _G[tabName .. "Text"])
    local cfTarget = (texs and texs.cf) or tab.chatFrame or (tabName and _G[tabName:gsub("Tab$", "")])

    local isSel = isSelected
    if isSel == nil then
        if _G.SELECTED_CHAT_FRAME and cfTarget then
            isSel = (_G.SELECTED_CHAT_FRAME == cfTarget)
        else
            isSel = (cfTarget and cfTarget:IsShown())
        end
    end

    local alpha = isSel and (self.db.tabAlphaActive or 1.0) or (self.db.tabAlphaInactive or 0.5)
    if tab.SetAlpha then tab:SetAlpha(alpha) end

    if tabText and tabText.SetTextColor then
        if isSel then
            -- Selected tab: bright gold highlight text
            tabText:SetTextColor(1.0, 0.85, 0.35, 1.0)
        else
            -- Inactive tab: muted gray text
            tabText:SetTextColor(0.65, 0.65, 0.65, 0.8)
        end
    end

    if texs then
        local bgColor = self.db.backgroundColor or self.defaultSettings.backgroundColor
        local borderColor = self.db.borderColor or self.defaultSettings.borderColor

        if isSel then
            -- Selected tab: distinct elevated dark fill with bright gold top accent line
            texs.bg:SetColorTexture(0.08, 0.11, 0.14, 0.85)
            texs.top:SetHeight(2)
            texs.top:SetColorTexture(1.0, 0.82, 0.0, 1.0)
            texs.bottom:SetColorTexture(0, 0, 0, 0)
            texs.left:SetColorTexture(borderColor.r or 0.15, borderColor.g or 0.15, borderColor.b or 0.15, 0.8)
            texs.right:SetColorTexture(borderColor.r or 0.15, borderColor.g or 0.15, borderColor.b or 0.15, 0.8)
        else
            -- Inactive tab: subtle, muted
            texs.bg:SetColorTexture(bgColor.r or 0.03, bgColor.g or 0.045, bgColor.b or 0.05, 0.35)
            texs.top:SetHeight(1)
            texs.top:SetColorTexture(borderColor.r or 0.15, borderColor.g or 0.15, borderColor.b or 0.15, 0.4)
            texs.bottom:SetHeight(1)
            texs.bottom:SetColorTexture(borderColor.r or 0.15, borderColor.g or 0.15, borderColor.b or 0.15, 0.4)
            texs.left:SetColorTexture(borderColor.r or 0.15, borderColor.g or 0.15, borderColor.b or 0.15, 0.3)
            texs.right:SetColorTexture(borderColor.r or 0.15, borderColor.g or 0.15, borderColor.b or 0.15, 0.3)
        end
    end
end

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
        local font = self:GetFontPath()
        local size = self.db.tabFontSize or 11
        local outline = self.db.fontOutline or "OUTLINE"
        pcall(tabText.SetFont, tabText, font, size, outline)
        -- Center tabText inside tab away from the bottom edge so it doesn't collide with chat text
        tabText:ClearAllPoints()
        tabText:SetPoint("CENTER", tab, "CENTER", 0, 1)
    end

    local tabHeight = self.db.tabHeight or 22
    tab:SetHeight(tabHeight)

    -- Tab background and border textures
    if not tabTextures[tab] and tab.CreateTexture then
        local bg = tab:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)

        local top = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
        top:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
        top:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -1, -1)
        top:SetHeight(1)

        local bottom = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
        bottom:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 1, 1)
        bottom:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
        bottom:SetHeight(1)

        local left = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
        left:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
        left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 1, 1)
        left:SetWidth(1)

        local right = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
        right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -1, -1)
        right:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
        right:SetWidth(1)

        tabTextures[tab] = { bg = bg, top = top, bottom = bottom, left = left, right = right, text = tabText, cf = cf }
    end

    -- Tab hover hooks
    tab:HookScript("OnEnter", function()
        self:UpdateTabVisuals(tab, true)
    end)
    tab:HookScript("OnLeave", function()
        local cfTarget = cf or _G[tab:GetName():gsub("Tab$", "")]
        local isSel = (_G.SELECTED_CHAT_FRAME == cfTarget) or (cfTarget and cfTarget:IsShown())
        self:UpdateTabVisuals(tab, isSel)
    end)

    local isInitSel = (_G.SELECTED_CHAT_FRAME == cf) or (cf and cf:IsShown())
    self:UpdateTabVisuals(tab, isInitSel)
end

-------------------------------------------------------------------------------
-- Timestamps & Button Dock
-------------------------------------------------------------------------------
function ChatMod:ApplyTimestampFormat()
    local fmt = self.db.timestampFormat or "%H:%M "
    if fmt == "" then fmt = "none" end

    -- Primary: Settings framework (requires Blizzard_SettingsDefinitions_Frame to be loaded)
    -- This is the path ChatFrameUtil.GetTimestampFormat() reads from.
    if _G.Settings and _G.Settings.SetValue then
        pcall(_G.Settings.SetValue, "showTimestamps", fmt)
    end

    -- Fallback: direct CVar write (takes effect if Settings framework not yet registered)
    local setCVar = _G.SetCVar or (_G.C_CVar and _G.C_CVar.SetCVar)
    if setCVar then
        pcall(setCVar, "showTimestamps", fmt)
    end
end

function ChatMod:UpdateButtonsDock()
    local cf1 = _G.ChatFrame1
    if not cf1 then return end

    local pos = self.db.buttonDockPosition or "INSIDE_TOP_RIGHT"
    if pos == "HIDDEN" or not self.db.enabled then
        if self.buttonDock then
            self.buttonDock:Hide()
        end
        return
    end

    if not self.buttonDock then
        local dock = CreateFrame("Frame", "RoithiChatButtonDock", UIParent)
        dock:SetFrameStrata("MEDIUM")
        dock:SetFrameLevel(cf1:GetFrameLevel() + 10)
        self.buttonDock = dock
    end
    if self.scrollBtn and self.scrollBtn.Hide then
        self.scrollBtn:Hide()
    end

    local dock = self.buttonDock
    dock:SetFrameStrata("HIGH")
    dock:SetFrameLevel(300)
    dock:Show()
    dock:ClearAllPoints()

    local isOutside = (pos == "OUTSIDE_LEFT")
    local isTopLeft = (pos == "INSIDE_TOP_LEFT")
    local isAbove = (pos == "ABOVE_CHAT")

    if isOutside then
        dock:SetPoint("TOPRIGHT", cf1, "TOPLEFT", -4, 0)
        dock:SetSize(22, 132)
    elseif isTopLeft then
        dock:SetPoint("TOPLEFT", cf1, "TOPLEFT", 4, -2)
        dock:SetSize(132, 22)
    elseif isAbove then
        local fps = _G.ForeverPlus and _G.ForeverPlusChatSearch
        if fps and fps:IsShown() then
            dock:SetPoint("BOTTOMRIGHT", fps, "TOPRIGHT", 0, 4)
        elseif self.bgPanel and self.bgPanel:IsShown() then
            dock:SetPoint("BOTTOMRIGHT", self.bgPanel, "TOPRIGHT", 0, 4)
        else
            dock:SetPoint("BOTTOMRIGHT", cf1, "TOPRIGHT", -2, 4)
        end
        dock:SetSize(140, 22)
    else -- "INSIDE_TOP_RIGHT" (Default)
        local fps = _G.ForeverPlus and _G.ForeverPlusChatSearch
        if fps and fps:IsShown() then
            dock:SetPoint("BOTTOMRIGHT", fps, "TOPRIGHT", 0, 4)
        else
            local padX = (self.db.backgroundPaddingX ~= nil) and self.db.backgroundPaddingX or 4
            local padY = (self.db.backgroundPaddingY ~= nil) and self.db.backgroundPaddingY or 4

            if self.bgPanel and self.bgPanel:IsShown() then
                dock:SetPoint("TOPRIGHT", self.bgPanel, "TOPRIGHT", -padX, -padY)
            else
                dock:SetPoint("TOPRIGHT", cf1, "TOPRIGHT", -2, -2)
            end
        end
        local tabH = (self.db.styleTabs ~= false) and (self.db.tabHeight or 22) or 22
        dock:SetSize(140, tabH)
    end

    if not self.copyBtn then
        local copyBtn = CreateFrame("Button", "RoithiChatCopyButton", dock)
        if copyBtn.SetSize then copyBtn:SetSize(20, 20) end
        if copyBtn.SetNormalTexture then copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up") end
        if copyBtn.SetPushedTexture then copyBtn:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down") end
        if copyBtn.SetHighlightTexture then copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight") end
        if copyBtn.SetScript then
            copyBtn:SetScript("OnClick", function()
                local cf = _G.SELECTED_CHAT_FRAME or _G.ChatFrame1
                self:OpenChatCopyWindow(cf)
            end)
            copyBtn:SetScript("OnEnter", function(btn)
                if _G.GameTooltip then
                    _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                    _G.GameTooltip:SetText(L["Copy Chat"] or "Copy Chat", 1, 1, 1)
                    _G.GameTooltip:AddLine(L["Click to open copyable chat window."] or "Click to open copyable chat window.", 0.8, 0.8, 0.8)
                    _G.GameTooltip:Show()
                end
            end)
            copyBtn:SetScript("OnLeave", function()
                if _G.GameTooltip and _G.GameTooltip.Hide then
                    _G.GameTooltip:Hide()
                end
            end)
        end
        self.copyBtn = copyBtn
    end

    -- Ensure copyBtn textures are active and visible
    if self.copyBtn then
        if self.copyBtn.SetNormalTexture then
            self.copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
            local nt = self.copyBtn:GetNormalTexture()
            if nt and nt.SetAlpha then nt:SetAlpha(1) end
        end
        if self.copyBtn.SetPushedTexture then
            self.copyBtn:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")
            local pt = self.copyBtn:GetPushedTexture()
            if pt and pt.SetAlpha then pt:SetAlpha(1) end
        end
    end

    local voiceLoggedIn = false
    if _G.C_VoiceChat and _G.C_VoiceChat.IsLoggedIn then
        local ok, loggedIn = pcall(_G.C_VoiceChat.IsLoggedIn)
        voiceLoggedIn = ok and (loggedIn == true)
    end

    local buttons = {
        _G.ChatFrameChannelButton,
        _G.ChatFrameMenuButton,
        self.copyBtn,
        _G.QuickJoinToastButton,
    }

    if voiceLoggedIn then
        if _G.ChatFrameToggleVoiceDeafenButton then
            table.insert(buttons, _G.ChatFrameToggleVoiceDeafenButton)
        end
        if _G.ChatFrameToggleVoiceMuteButton then
            table.insert(buttons, _G.ChatFrameToggleVoiceMuteButton)
        end
    else
        if _G.ChatFrameToggleVoiceDeafenButton and _G.ChatFrameToggleVoiceDeafenButton.Hide then
            _G.ChatFrameToggleVoiceDeafenButton:Hide()
        end
        if _G.ChatFrameToggleVoiceMuteButton and _G.ChatFrameToggleVoiceMuteButton.Hide then
            _G.ChatFrameToggleVoiceMuteButton:Hide()
        end
    end

    -- Ensure fallback atlases if channel or voice buttons exist
    local channelBtn = _G.ChatFrameChannelButton
    if channelBtn and channelBtn.Icon then
        local atlas = (channelBtn.Icon.GetAtlas and channelBtn.Icon:GetAtlas()) or ""
        if atlas == "" and channelBtn.Icon.SetAtlas then
            channelBtn.Icon:SetAtlas("chatframe-button-icon-voicechat")
        end
        channelBtn.Icon:Show()
        channelBtn.Icon:SetAlpha(1)
    end

    local deafenBtn = _G.ChatFrameToggleVoiceDeafenButton
    if deafenBtn and deafenBtn.Icon then
        local atlas = (deafenBtn.Icon.GetAtlas and deafenBtn.Icon:GetAtlas()) or ""
        if atlas == "" and deafenBtn.Icon.SetAtlas then
            deafenBtn.Icon:SetAtlas("chatframe-button-icon-speaker-on")
        end
        deafenBtn.Icon:Show()
        deafenBtn.Icon:SetAlpha(1)
    end

    local muteBtn = _G.ChatFrameToggleVoiceMuteButton
    if muteBtn and muteBtn.Icon then
        local atlas = (muteBtn.Icon.GetAtlas and muteBtn.Icon:GetAtlas()) or ""
        if atlas == "" and muteBtn.Icon.SetAtlas then
            muteBtn.Icon:SetAtlas("chatframe-button-icon-mic-on")
        end
        muteBtn.Icon:Show()
        muteBtn.Icon:SetAlpha(1)
    end

    local function StripChatButtonBorder(btn)
        if not btn then return end
        if btn == self.copyBtn then return end

        -- 1. ChatFrameMenuButton (Speech bubble / chat menu button)
        if btn == _G.ChatFrameMenuButton then
            if btn.Icon then
                btn.Icon:Hide()
                btn.Icon:SetTexture(nil)
                btn.Icon:ClearAllPoints()
                btn.Icon:SetSize(0.001, 0.001)
            end

            local function ApplyMenuButtonTextures(b)
                local nt = b.GetNormalTexture and b:GetNormalTexture()
                if nt then
                    nt:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
                    nt:SetTexCoord(0.28, 0.72, 0.28, 0.72)
                    nt:ClearAllPoints()
                    nt:SetAllPoints(b)
                    nt:SetAlpha(1)
                end
                local pt = b.GetPushedTexture and b:GetPushedTexture()
                if pt then
                    pt:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Down")
                    pt:SetTexCoord(0.28, 0.72, 0.28, 0.72)
                    pt:ClearAllPoints()
                    pt:SetAllPoints(b)
                    pt:SetAlpha(1)
                end
                local dt = b.GetDisabledTexture and b:GetDisabledTexture()
                if dt then
                    dt:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Disabled")
                    dt:SetTexCoord(0.28, 0.72, 0.28, 0.72)
                    dt:ClearAllPoints()
                    dt:SetAllPoints(b)
                end
            end

            ApplyMenuButtonTextures(btn)

            if not btn.roithiMenuHooked then
                btn.roithiMenuHooked = true
                local isApplying = false
                if btn.SetNormalTexture and ChatMod.SecureHook then
                    ChatMod:SecureHook(btn, "SetNormalTexture", function(b)
                        if isApplying then return end
                        isApplying = true
                        ApplyMenuButtonTextures(b)
                        isApplying = false
                    end)
                end
                if btn.SetPushedTexture and ChatMod.SecureHook then
                    ChatMod:SecureHook(btn, "SetPushedTexture", function(b)
                        if isApplying then return end
                        isApplying = true
                        ApplyMenuButtonTextures(b)
                        isApplying = false
                    end)
                end
            end

            if btn.SetHighlightTexture then
                btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            end
            return
        end

        -- 2. QuickJoinToastButton (Friends list button)
        if btn == _G.QuickJoinToastButton then
            if btn.FriendsButton then
                btn.FriendsButton:ClearAllPoints()
                btn.FriendsButton:SetAllPoints(btn)
                if not btn.roithiFriendsHooked then
                    btn.roithiFriendsHooked = true
                    local settingFriendsAtlas = false
                    if _G.hooksecurefunc and btn.FriendsButton.SetAtlas then
                        _G.hooksecurefunc(btn.FriendsButton, "SetAtlas", function(tex, atlas)
                            if settingFriendsAtlas then return end
                            if atlas == "quickjoin-button-friendslist-up" or atlas == "quickjoin-button-friendslist-down" then
                                settingFriendsAtlas = true
                                tex:SetAtlas("friends-icon-tab-friends")
                                settingFriendsAtlas = false
                            end
                        end)
                    end
                end
                if btn.FriendsButton.SetAtlas then
                    btn.FriendsButton:SetAtlas("friends-icon-tab-friends")
                end
                btn.FriendsButton:Show()
            end
            if btn.QueueButton then
                btn.QueueButton:ClearAllPoints()
                btn.QueueButton:SetAllPoints(btn)
            end
            if btn.FriendCount then
                btn.FriendCount:ClearAllPoints()
                btn.FriendCount:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
                btn.FriendCount:Show()
            end
            local nt = btn.GetNormalTexture and btn:GetNormalTexture()
            if nt then if nt.SetTexture then nt:SetTexture("") end if nt.SetAlpha then nt:SetAlpha(0) end end
            local pt = btn.GetPushedTexture and btn:GetPushedTexture()
            if pt then if pt.SetTexture then pt:SetTexture("") end if pt.SetAlpha then pt:SetAlpha(0) end end
            if btn.SetHighlightTexture then
                btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            end
            return
        end

        -- 3. Voice Toggle Buttons with btn.Icon
        if btn.Icon then
            local nt = btn.GetNormalTexture and btn:GetNormalTexture()
            if nt then
                if nt.SetTexture then nt:SetTexture("") end
                if nt.SetAlpha then nt:SetAlpha(0) end
            end
            local pt = btn.GetPushedTexture and btn:GetPushedTexture()
            if pt then
                if pt.SetTexture then pt:SetTexture("") end
                if pt.SetAlpha then pt:SetAlpha(0) end
            end
            local dt = btn.GetDisabledTexture and btn:GetDisabledTexture()
            if dt then
                if dt.SetTexture then dt:SetTexture("") end
                if dt.SetAlpha then dt:SetAlpha(0) end
            end

            if not btn.roithiBorderStripped then
                btn.roithiBorderStripped = true
                if btn.SetNormalTexture and ChatMod.SecureHook then
                    ChatMod:SecureHook(btn, "SetNormalTexture", function(b)
                        local bnt = b:GetNormalTexture()
                        if bnt and bnt.GetAlpha and bnt:GetAlpha() > 0 then
                            if bnt.SetTexture then bnt:SetTexture("") end
                            if bnt.SetAlpha then bnt:SetAlpha(0) end
                        end
                    end)
                end
                if btn.SetPushedTexture and ChatMod.SecureHook then
                    ChatMod:SecureHook(btn, "SetPushedTexture", function(b)
                        local bpt = b:GetPushedTexture()
                        if bpt and bpt.GetAlpha and bpt:GetAlpha() > 0 then
                            if bpt.SetTexture then bpt:SetTexture("") end
                            if bpt.SetAlpha then bpt:SetAlpha(0) end
                        end
                    end)
                end
            end

            btn.Icon:ClearAllPoints()
            btn.Icon:SetAllPoints(btn)
            btn.Icon:Show()
            btn.Icon:SetAlpha(1)

            local currentAtlas = (btn.Icon.GetAtlas and btn.Icon:GetAtlas()) or ""
            if currentAtlas == "" and btn.Icon.SetAtlas then
                if btn == _G.ChatFrameChannelButton then
                    btn.Icon:SetAtlas("chatframe-button-icon-voicechat")
                elseif btn == _G.ChatFrameToggleVoiceDeafenButton then
                    btn.Icon:SetAtlas("chatframe-button-icon-speaker-on")
                elseif btn == _G.ChatFrameToggleVoiceMuteButton then
                    btn.Icon:SetAtlas("chatframe-button-icon-mic-on")
                end
            end
        else
            -- 4. Classic buttons without btn.Icon: keep NormalTexture with cropped border
            local nt = btn.GetNormalTexture and btn:GetNormalTexture()
            if nt then
                nt:SetAlpha(1)
                nt:SetTexCoord(0.18, 0.82, 0.18, 0.82)
                nt:ClearAllPoints()
                nt:SetAllPoints(btn)
            end
            local pt = btn.GetPushedTexture and btn:GetPushedTexture()
            if pt then
                pt:SetAlpha(1)
                pt:SetTexCoord(0.18, 0.82, 0.18, 0.82)
                pt:ClearAllPoints()
                pt:SetAllPoints(btn)
            end
        end

        if btn.SetHighlightTexture then
            btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        end

        if not btn.roithiDockHooked and hooksecurefunc then
            btn.roithiDockHooked = true
            local isRepositioning = false
            hooksecurefunc(btn, "SetPoint", function(b)
                if isRepositioning then return end
                if ChatMod.db and ChatMod.db.buttonDockPosition ~= "HIDDEN" and ChatMod.buttonDock and b:GetParent() ~= ChatMod.buttonDock then
                    isRepositioning = true
                    ChatMod:UpdateButtonsDock()
                    isRepositioning = false
                end
            end)
        end
    end

    local prevBtn = nil
    for _, btn in ipairs(buttons) do
        if btn then
            StripChatButtonBorder(btn)
            btn:SetParent(dock)
            btn:SetFrameStrata("HIGH")
            btn:SetFrameLevel(310)
            btn:Show()
            btn:ClearAllPoints()
            btn:SetSize(20, 20)
            if not prevBtn then
                if isTopLeft then
                    btn:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
                else
                    btn:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, 0)
                end
            else
                if isOutside then
                    btn:SetPoint("TOP", prevBtn, "BOTTOM", 0, -2)
                elseif isTopLeft then
                    btn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
                else
                    btn:SetPoint("RIGHT", prevBtn, "LEFT", -2, 0)
                end
            end
            prevBtn = btn
        end
    end

    if self.scrollBtn and self.scrollBtn.Hide then
        self.scrollBtn:Hide()
    end
end

-------------------------------------------------------------------------------
-- Blizzard Chrome Suppression
-------------------------------------------------------------------------------
function ChatMod:HideBlizzardChrome()
    if self.db.buttonDockPosition == "HIDDEN" then
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
    else
        self:UpdateButtonsDock()
    end
end

function ChatMod:GetOrCreateChatCopyWindow()
    if self.copyWindow then return self.copyWindow end

    local win = CreateFrame("Frame", "RoithiChatCopyWindow", UIParent, "BackdropTemplate")
    win:SetSize(600, 420)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    win:SetFrameStrata("DIALOG")
    win:SetFrameLevel(500)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(f) if f.StartMoving then f:StartMoving() end end)
    win:SetScript("OnDragStop", function(f) if f.StopMovingOrSizing then f:StopMovingOrSizing() end end)

    LibRoithi.mixins:CreateBackdrop(win)
    win:SetBackdropColor(0.04, 0.05, 0.07, 0.95)
    win:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)

    if _G.UISpecialFrames then
        table.insert(_G.UISpecialFrames, "RoithiChatCopyWindow")
    end

    -- Title
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
    title:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -10)
    title:SetText(L["Copy Chat"] or "Copy Chat")
    win.title = title

    -- Subtitle / instruction
    local sub = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("LEFT", title, "RIGHT", 10, 0)
    sub:SetText("(" .. (L["Ctrl+C to Copy | ESC to Close"] or "Ctrl+C to Copy | ESC to Close") .. ")")
    win.sub = sub

    -- Close button (top right)
    local closeBtn = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() win:Hide() end)
    win.closeBtn = closeBtn

    -- ScrollFrame container
    local scrollArea = CreateFrame("ScrollFrame", "RoithiChatCopyScrollFrame", win, "UIPanelScrollFrameTemplate")
    scrollArea:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -34)
    scrollArea:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -32, 40)

    local eb = CreateFrame("EditBox", "RoithiChatCopyEditBox", scrollArea)
    eb:SetMultiLine(true)
    eb:SetMaxLetters(0)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    if eb.SetSpacing then eb:SetSpacing(0) end
    if eb.SetTextInsets then eb:SetTextInsets(4, 4, 4, 4) end
    eb:SetWidth(550)
    eb:SetScript("OnEscapePressed", function() win:Hide() end)

    if eb.SetScript then
        eb:SetScript("OnCursorChanged", function(editBoxObj, x, y, w, h)
            if not y or not h or not scrollArea then return end
            local offset = -y
            local currentScroll = scrollArea.GetVerticalScroll and scrollArea:GetVerticalScroll() or 0
            local height = scrollArea.GetHeight and scrollArea:GetHeight() or 0
            if height > 0 then
                if offset < currentScroll and scrollArea.SetVerticalScroll then
                    scrollArea:SetVerticalScroll(offset)
                elseif offset + h > currentScroll + height and scrollArea.SetVerticalScroll then
                    scrollArea:SetVerticalScroll(offset + h - height)
                end
            end
        end)
    end

    if scrollArea.SetScript then
        scrollArea:SetScript("OnSizeChanged", function(s, w)
            if w and w > 20 and eb and eb.SetWidth then
                eb:SetWidth(w - 8)
            end
        end)
    end

    scrollArea:SetScrollChild(eb)

    win.editBox = eb
    win.scrollArea = scrollArea

    -- Bottom action buttons: "Select All" and "Close"
    local selectAllBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(100, 22)
    selectAllBtn:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 12, 10)
    selectAllBtn:SetText(L["Select All"] or "Select All")
    selectAllBtn:SetScript("OnClick", function()
        eb:SetFocus()
        eb:HighlightText()
    end)
    win.selectAllBtn = selectAllBtn

    local bottomCloseBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    bottomCloseBtn:SetSize(80, 22)
    bottomCloseBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -12, 10)
    bottomCloseBtn:SetText(_G.CLOSE or "Close")
    bottomCloseBtn:SetScript("OnClick", function() win:Hide() end)
    win.bottomCloseBtn = bottomCloseBtn

    win:Hide()
    self.copyWindow = win
    return win
end

function ChatMod:OpenChatCopyWindow(cf)
    cf = cf or _G.SELECTED_CHAT_FRAME or _G.ChatFrame1
    if not cf then return end

    local win = self:GetOrCreateChatCopyWindow()
    local cfName = cf.GetName and cf:GetName() or "Chat"
    local tabText = _G[cfName .. "Tab"] and _G[cfName .. "Tab"].GetText and _G[cfName .. "Tab"]:GetText()
    if tabText and tabText ~= "" then
        win.title:SetText((L["Copy Chat"] or "Copy Chat") .. " - " .. tabText)
    else
        win.title:SetText(L["Copy Chat"] or "Copy Chat")
    end

    local lines = {}
    local num = cf.GetNumMessages and cf:GetNumMessages() or 0
    if num > 0 and cf.GetMessageInfo then
        for i = 1, num do
            local text = cf:GetMessageInfo(i)
            if text and text ~= "" then

                local clean = tostring(text)
                clean = clean:gsub("|c%x%x%x%x%x%x%x%x", "")
                clean = clean:gsub("|r", "")
                clean = clean:gsub("|T.-|t", "")
                clean = clean:gsub("|A.-|a", "")
                clean = clean:gsub("|K.-|k", "")
                clean = clean:gsub("|H.-|h(.-)|h", "%1")
                table.insert(lines, clean)
            end
        end
    end

    local fullText = table.concat(lines, "\n")
    if win.editBox.SetTextColor then win.editBox:SetTextColor(0.95, 0.95, 0.95, 1) end
    win.editBox:SetText(fullText)
    win:Show()

    local w = win.scrollArea:GetWidth()
    if w and w > 20 then
        win.editBox:SetWidth(w - 8)
    else
        win.editBox:SetWidth(550)
    end

    if win.scrollArea.SetVerticalScroll and win.scrollArea.GetVerticalScrollRange then
        win.scrollArea:SetVerticalScroll(win.scrollArea:GetVerticalScrollRange() or 0)
    end

    win.editBox:SetFocus()
    win.editBox:HighlightText()
end

function ChatMod:RefreshSettings()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Chat or self.defaultSettings
    self:ApplyChatPosition()
    self:UpdateBackgroundStyle()
    self:UpdateBackgroundPosition()
    self:SkinAllChatFrames()
    self:ApplyTimestampFormat()
    self:UpdateButtonsDock()
    local cf1 = _G.ChatFrame1
    if cf1 and _G.ChatFrame1EditBox and self.RepositionEditBox then
        self:RepositionEditBox(_G.ChatFrame1EditBox, cf1)
    end
    if LEM and LEM.RefreshFrameSettings and cf1 then
        LEM:RefreshFrameSettings(cf1)
    end
end
ChatMod.RefreshProfile = ChatMod.RefreshSettings

