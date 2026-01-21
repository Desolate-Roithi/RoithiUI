local addonName, ns = ...
local RoithiUI = _G.RoithiUI

-- ----------------------------------------------------------------------------
-- Serialization (Export)
-- ----------------------------------------------------------------------------
local function Serialize(tbl, indent)
    indent = indent or 0
    local parts = {}
    table.insert(parts, "{\n")

    local keys = {}
    for k in pairs(tbl) do table.insert(keys, k) end
    table.sort(keys, function(a, b)
        if type(a) == "number" and type(b) == "number" then return a < b end
        return tostring(a) < tostring(b)
    end)

    for _, k in ipairs(keys) do
        local v = tbl[k]
        local keyStr
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            keyStr = k
        else
            keyStr = "[" .. (type(k) == "string" and string.format("%q", k) or k) .. "]"
        end

        local valStr
        if type(v) == "table" then
            valStr = Serialize(v, indent + 1)
        elseif type(v) == "string" then
            valStr = string.format("%q", v)
        else
            valStr = tostring(v)
        end

        table.insert(parts, string.rep("    ", indent + 1) .. keyStr .. " = " .. valStr .. ",\n")
    end
    table.insert(parts, string.rep("    ", indent) .. "}")
    return table.concat(parts)
end

function RoithiUI:ExportSettings()
    local exportString = "ns.Defaults = " .. Serialize(RoithiUIDB)

    -- Show in a copy-paste dialog
    local f = RoithiUIExportFrame or CreateFrame("Frame", "RoithiUIExportFrame", UIParent, "DialogBoxFrame")
    f:SetSize(600, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    if not f.Scroll then
        f.Scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        f.Scroll:SetPoint("TOPLEFT", 16, -30)
        f.Scroll:SetPoint("BOTTOMRIGHT", -30, 40)

        f.EditBox = CreateFrame("EditBox", nil, f.Scroll)
        f.EditBox:SetMultiLine(true)
        f.EditBox:SetFontObject(ChatFontNormal)
        f.EditBox:SetWidth(550)
        f.Scroll:SetScrollChild(f.EditBox)

        f.Close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.Close:SetPoint("BOTTOM", 0, 10)
        f.Close:SetSize(100, 25)
        f.Close:SetText("Close")
        f.Close:SetScript("OnClick", function() f:Hide() end)
    end

    f.EditBox:SetText(exportString)
    f.EditBox:HighlightText()
    f:Show()
    print("|cff00ccffRoithiUI:|r Settings exported. Press Ctrl+C to copy.")
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
            _G.RoithiUIDB = {}
            if ns.Defaults then
                _G.RoithiUIDB = CopyTable(ns.Defaults)
            end
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
-- Slash Command Handler
-- ----------------------------------------------------------------------------
SLASH_ROITHI1 = "/roithi"
SlashCmdList["ROITHI"] = function(msg)
    local cmd = msg:lower():trim()
    if cmd == "export" then
        RoithiUI:ExportSettings()
    elseif cmd == "reset" then
        RoithiUI:ResetSettings()
    elseif cmd == "secrets on" or cmd == "secrets off" then
        -- Forward to existing secrets handler if present, or advise user
        -- We won't duplicate verify logic here
        print("Use /rs or /roithisecrets for secrets tests.")
    else
        -- Default: Open Options
        if RoithiUI.Config and RoithiUI.Config.optionsFrame then
            -- modern 10.0+ / 12.0.1 Method
            if Settings and Settings.OpenToCategory then
                Settings.OpenToCategory(addonName)
            elseif _G.InterfaceOptionsFrame_OpenToCategory then
                -- Legacy / Compatibility
                _G.InterfaceOptionsFrame_OpenToCategory(addonName)
            end
        else
            print("RoithiUI Options available in Game Menu -> Options -> AddOns")
        end
        print("|cff00ccffRoithiUI Commands:|r")
        print("  /roithi export - Export current profile to text")
        print("  /roithi reset - Reset to defaults")
    end
end

SLASH_ROITHIDEBUG1 = "/rd"
SLASH_ROITHIDEBUG2 = "/roithidebug"
SlashCmdList["ROITHIDEBUG"] = function()
    RoithiUI.debug = not RoithiUI.debug
    print("|cff00ccffRoithiUI Debug:|r " .. (RoithiUI.debug and "|cff00ff00Enabled" or "|cffff0000Disabled"))
end
