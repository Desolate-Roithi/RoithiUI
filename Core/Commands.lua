local addonName, ns = ...
local RoithiUI = _G.RoithiUI

-- ----------------------------------------------------------------------------
-- Serialization (Export)
-- ----------------------------------------------------------------------------
-- Serialize moved to Utils.lua

function RoithiUI:ExportSettings()
    -- Export current profile settings
    local exportString = "ns.Defaults = " .. ns.Utils.Serialize(self.db.profile)
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

-- ----------------------------------------------------------------------------
-- Slash Command Handler (AceConsole)
-- ----------------------------------------------------------------------------
function RoithiUI:ChatCommand(input)
    if not input or input:trim() == "" then
        -- Default: Open Options
        if self.Config and self.Config.optionsFrame then
            -- Logic to open options
            -- (Placeholder if we had a direct function)
        elseif Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(addonName)
            ---@diagnostic disable-next-line: undefined-field
        elseif _G.InterfaceOptionsFrame_OpenToCategory then
            ---@diagnostic disable-next-line: undefined-field
            _G.InterfaceOptionsFrame_OpenToCategory(addonName)
        else
            self:Print("Options available in Game Menu -> Options -> AddOns")
        end
        self:Print("Commands:")
        self:Print("  /rui export - Export current profile")
        self:Print("  /rui reset - Reset defaults")
        return
    end

    local cmd, arg = self:GetArgs(input, 2)
    cmd = cmd:lower()

    if cmd == "export" then
        self:ExportSettings()
    elseif cmd == "reset" then
        self:ResetSettings()
    elseif cmd == "secrets" then
        self:Print("Use /rs or /roithisecrets for secrets tests.")
    elseif cmd == "debug" or cmd == "rd" then
        self.debug = not self.debug
        self:Print("Debug: " .. (self.debug and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    else
        self:Print("Unknown command.")
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
    self:Print("Debug: " .. (self.debug and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
end

-- Call Registration immediately as the addon object exists
RoithiUI:RegisterChatCommand("roithi", "ChatCommand")
-- Register /rd explicitly or just handle in main handler.
-- Legacy had /rd separately.
RoithiUI:RegisterChatCommand("rd", "ChatCommandDebug")
RoithiUI:RegisterChatCommand("roithidebug", "ChatCommandDebug")
