local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

local defaultSettings = {
    backgroundColor = { r = 0.03, g = 0.045, b = 0.05, a = 0.65 },
    backgroundPaddingX = 4,
    backgroundPaddingY = 4,
    borderColor = { r = 0.15, g = 0.15, b = 0.15, a = 1 },
    borderSize = 1,
    buttonDockPosition = "INSIDE_TOP_RIGHT",
    chatIconSize = 16,
    clampToScreen = false,
    editBoxBgColor = { r = 0.05, g = 0.065, b = 0.08, a = 1 },
    editBoxBorderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
    editBoxHeight = 24,
    editBoxPosition = "INSIDE",
    enabled = true,
    font = "Roithi Thin",
    fontOutline = "NONE",
    fontSize = 16,
    height = 215,
    hideBlizzardChrome = true,
    includeEditBoxInBackground = true,
    linkURLs = true,
    point = "BOTTOMLEFT",
    shortenChannels = true,
    showBackground = true,
    showBorder = true,
    showClassIcons = true,
    showFontShadow = true,
    showNewTabButton = true,
    showRaceIcons = true,
    styleTabs = true,
    tabAlphaActive = 1,
    tabAlphaInactive = 0.45,
    tabFontSize = 12,
    tabHeight = 21,
    timestampFormat = "%H:%M:%S ",
    whisperMode = "popout_and_inline",
    width = 425,
    x = 3,
    y = 4,
}

local mod = RoithiUI and RoithiUI:GetModule("Chat", true)
if mod then
    mod.defaultSettings = defaultSettings
    mod.dbKey = "Chat"
end
if ns.Defaults and ns.Defaults.profile then
    ns.Defaults.profile.Chat = defaultSettings
end
ns.ChatDefaults = defaultSettings
