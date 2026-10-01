local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

-- ----------------------------------------------------------------------------
-- Serialization (Export)
-- ----------------------------------------------------------------------------
-- Serialize moved to Utils.lua

function RoithiUI:ExportSettings()
    -- Export current profile settings
    -- Export current profile settings wrapped in 'profile' key for AceDB defaults compatibility
    local exportString = "ns.Defaults = {\n    profile = " .. ns.Utils.Serialize(self.db.profile, 1) .. "\n}"
    ns.Utils.ShowExportWindow(exportString)
    self:Print("Settings exported. Press Ctrl+C to copy.")
end

-- ----------------------------------------------------------------------------
-- Reset
-- ----------------------------------------------------------------------------
function RoithiUI:ResetSettings()
    StaticPopupDialogs["ROITHI_RESET"] = {
        text = "Are you sure you want to reset all RoithiUI settings to defaults? UI will reload.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            -- Reset current profile to defaults
            RoithiUI.db:ResetProfile()
            -- OR RoithiUI.db:ResetDB() to wipe everything including other profiles?
            -- Given the prompt says "all settings", ResetDB might be cleaner for a "Hard Reset".
            -- But ResetProfile is safer. Let's stick to ResetProfile for now, or just ResetDB as per legacy behavior.
            -- Legacy: _G.RoithiUIDB = {} (Wiped everything).
            RoithiUI.db:ResetDB()
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("ROITHI_RESET")
end

local GROUP_PATH_MAP = {
    unitframes = { "combat", "unitframes" },
    castbars = { "combat", "castbars" },
    castbar = { "combat", "castbars" },
    auras = { "combat", "auras" },
    defaultauras = { "combat", "auras", "defaultAuras" },
    customtags = { "combat", "customtags" },
    encounterbar = { "combat", "encounterbar" },
    cooldownmanager = { "combat", "cooldownmanager" },
    cdm = { "combat", "cooldownmanager" },
    actionbars = { "actionbars_group", "actionbars" },
    actionbar = { "actionbars_group", "actionbars" },
    totems = { "actionbars_group", "totems" },
    totem = { "actionbars_group", "totems" },
    minimap = { "interface_group", "minimap" },
    bags = { "interface_group", "bags" },
    bag = { "interface_group", "bags" },
    menu = { "interface_group", "menu" },
    swingtimer = { "combat", "swingtimer" },
    swing = { "combat", "swingtimer" },
    chat = { "interface_group", "chat" },
    objectives = { "interface_group", "objectives" },
}

function RoithiUI:OpenSettings(group, ...)
    local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
    if not ACD then return end
    if not group then
        if ACD.OpenFrames and ACD.OpenFrames["RoithiUI"] then
            ACD:Close("RoithiUI")
        else
            ACD:Open("RoithiUI")
        end
        return
    end

    local lowGroup = tostring(group):lower()
    local basePath = GROUP_PATH_MAP[lowGroup]
    local fullPath = {}
    if basePath then
        for _, p in ipairs(basePath) do
            table.insert(fullPath, p)
        end
    else
        table.insert(fullPath, group)
    end
    for i = 1, select("#", ...) do
        local sub = select(i, ...)
        if sub then
            table.insert(fullPath, sub)
        end
    end
    ACD:SelectGroup("RoithiUI", unpack(fullPath))
    ACD:Open("RoithiUI")
end
RoithiUI.OpenConfigWindow = RoithiUI.OpenSettings

local commandHandlers
commandHandlers = {
    ["help"] = function(self)
        self:Print("Available Slash Commands:")
        print("  |cff00ccff/rui|r or |cff00ccff/roithi|r - Open free-flowing configuration window")
        print("  |cff00ccff/rui <group>|r - Open config to group (e.g. |cffffd700auras|r, |cffffd700unitframes|r, |cffffd700actionbars|r, |cffffd700minimap|r)")
        print("  |cff00ccff/rui bliz|r (or |cff00ccff/rui options|r) - Open Blizzard Settings category")
        print("  |cff00ccff/rui testsuite|r (or |cff00ccff/rui dev|r) - Open In-Game Test Suite (Pillar 2)")
        print("  |cff00ccff/rui export|r - Open profile export dialog")
        print("  |cff00ccff/rui reset|r - Reset profile to defaults")
        print("  |cff00ccff/rui debug|r (or |cff00ccff/rd|r) - Toggle debug mode")
        print("  |cff00ccff/rui test boss|r - Toggle Boss frames preview mode")
        print("  |cff00ccff/rl|r - Quick reload UI")
    end,
    ["rl"] = function()
        ReloadUI()
    end,
    ["?"] = function(self)
        commandHandlers["help"](self)
    end,
    ["testsuite"] = function(self)
        local UI = RoithiUI:GetModule("UI_TestSuite", true)
        local TS = RoithiUI:GetModule("TestSuite", true)
        if UI and UI.ToggleWindow then
            UI:ToggleWindow()
        elseif TS and TS.ToggleWindow then
            TS:ToggleWindow()
        else
            self:Print("TestSuite is only available in local development mode.")
        end
    end,
    ["dev"] = function(self) commandHandlers["testsuite"](self) end,
    ["tests"] = function(self) commandHandlers["testsuite"](self) end,
    ["bliz"] = function(self)
        if Settings and Settings.OpenToCategory then
            local categoryID = RoithiUI.SettingsCategoryID or addonName
            local ok = pcall(Settings.OpenToCategory, categoryID)
            if not ok and _G.InterfaceOptionsFrame_OpenToCategory then
                pcall(_G.InterfaceOptionsFrame_OpenToCategory, addonName)
            end
        elseif _G.InterfaceOptionsFrame_OpenToCategory then
            ---@diagnostic disable-next-line: undefined-field
            pcall(_G.InterfaceOptionsFrame_OpenToCategory, addonName)
        else
            self:Print("Options available in Game Menu -> Options -> AddOns")
        end
    end,
    ["options"] = function(self) commandHandlers["bliz"](self) end,
    ["export"] = function(self) self:ExportSettings() end,
    ["reset"] = function(self) self:ResetSettings() end,
    ["secrets"] = function(self) self:Print("Use /rs or /roithisecrets for secrets tests.") end,
    ["debug"] = function(self)
        self.debug = not self.debug
        self:Print("Debug: " .. (self.debug and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    end,
    ["rd"] = function(self) commandHandlers["debug"](self) end,
    ["test"] = function(self, arg)
        local testType = arg and arg:lower() or ""
        if testType == "boss" then
            local UF = RoithiUI:GetModule("UnitFrames")
            if UF and UF.ToggleBossTestMode then
                UF:ToggleBossTestMode()
            end
        else
            self:Print("Usage: /roithi test [boss]")
        end
    end,
}

-- ----------------------------------------------------------------------------
-- Slash Command Handler (AceConsole)
-- ----------------------------------------------------------------------------
function RoithiUI:ChatCommand(input)
    if not input or input:trim() == "" then
        self:OpenConfigWindow()
        return
    end

    local cmd, arg = self:GetArgs(input, 2)
    cmd = cmd:lower()

    local handler = commandHandlers[cmd]
    if handler then
        handler(self, arg)
    else
        self:OpenConfigWindow(cmd)
    end
end

function RoithiUI:OnInitialize_Commands()
    -- This follows OnInitialize in Init.lua, usually we can register commands in OnEnable or OnInitialize
    -- Since this file is loaded later, we can register here or assume Init called it?
    -- Actually, it is safer to register within OnInitialize of the addon.
    -- But since this is a separate file just adding methods, we will need to hook the initialization?
    -- No, AceAddon mixes in AceConsole. We can just call RegisterChatCommand in OnInitialize.
    -- BUT RoithiUI:OnInitialize is in Init.lua.

    -- Solution: We will hook OnInitialize or just run this at file load time?
    -- File load time works if RoithiUI is already created (it is).
    self:RegisterChatCommand("roithi", "ChatCommand")
    self:RegisterChatCommand("rd", "ChatCommandDebug") -- Shortcut for debug
end

function RoithiUI:ChatCommandDebug()
    self.debug = not self.debug
    if self.db and self.db.profile and self.db.profile.General then
        self.db.profile.General.debugMode = self.debug
    end
    self:Print("Debug: " .. (self.debug and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
end

-- Call Registration immediately as the addon object exists
RoithiUI:RegisterChatCommand("roithi", "ChatCommand")
RoithiUI:RegisterChatCommand("rui", "ChatCommand") -- Fix: Register /rui as alias
RoithiUI:RegisterChatCommand("rl", function()
    ReloadUI()
end)
_G.SLASH_ROITHIRL1 = "/rl"
_G.SlashCmdList["ROITHIRL"] = function()
    ReloadUI()
end
RoithiUI:RegisterChatCommand("lemdiag", function()
    local lib = LibStub("LibRoithi-1.0", true)
    if lib and lib.Diagnostic then
        lib:Diagnostic()
    end
end)
-- Register /rd explicitly or just handle in main handler.
-- Legacy had /rd separately.
RoithiUI:RegisterChatCommand("rd", "ChatCommandDebug")
RoithiUI:RegisterChatCommand("roithidebug", "ChatCommandDebug")
RoithiUI:RegisterChatCommand("kb", function()
    local AB = RoithiUI:GetModule("Actionbars", true)
    if AB and AB.ToggleQuickKeybind then
        AB:ToggleQuickKeybind()
    end
end)
RoithiUI:RegisterChatCommand("roithikb", function()
    local AB = RoithiUI:GetModule("Actionbars", true)
    if AB and AB.ToggleQuickKeybind then
        AB:ToggleQuickKeybind()
    end
end)
StaticPopupDialogs["ROITHI_RELOAD"] = {
    text = "Changing module settings requires a UI reload. Reload now?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

RoithiUI:RegisterChatCommand("rad", function()
    RoithiUI.AuraDebug = not RoithiUI.AuraDebug
    local stateStr = RoithiUI.AuraDebug and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
    print("|cff00ffff[RAD - Roithi Aura Debugger 12.1.0]|r Debug logging is now " .. stateStr)
end)
