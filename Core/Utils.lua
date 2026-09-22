local _, ns = ...
if ns.skipLoad then return end

-- -------------------------------------------------------------------------
-- Environment & Client Flavor Detection
-- -------------------------------------------------------------------------
local GetBuildInfo = _G.GetBuildInfo
local C_GameRules = _G.C_GameRules
local WOW_PROJECT_ID = _G.WOW_PROJECT_ID
local WOW_PROJECT_MAINLINE = _G.WOW_PROJECT_MAINLINE

local _, _, _, interfaceVersion = GetBuildInfo()
ns.InterfaceVersion = tonumber(interfaceVersion) or 0
ns.IsForever = (ns.InterfaceVersion == 16001) or (C_GameRules and C_GameRules.IsForever and C_GameRules.IsForever() or false)
ns.IsRetail = not ns.IsForever and (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

-- -------------------------------------------------------------------------
-- Utils Module
-- -------------------------------------------------------------------------
ns.Utils = {}

-- -------------------------------------------------------------------------
-- Table Helpers
-- -------------------------------------------------------------------------
function ns.Utils.MergeTable(target, source)
    if type(target) ~= "table" then target = {} end
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = CopyTable(v)
            else
                ns.Utils.MergeTable(target[k], v)
            end
        else
            if target[k] == nil then
                target[k] = v
            end
        end
    end
    return target
end

-- -------------------------------------------------------------------------
-- Serialization (Export)
-- -------------------------------------------------------------------------
function ns.Utils.Serialize(tbl, indent)
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
        if type(k) == "string" and k:match("^[a_][%w_]*$") then
            keyStr = k
        else
            keyStr = "[" .. (type(k) == "string" and string.format("%q", k) or k) .. "]"
        end

        local valStr
        if type(v) == "table" then
            valStr = ns.Utils.Serialize(v, indent + 1)
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

-- -------------------------------------------------------------------------
-- UI Helpers
-- -------------------------------------------------------------------------
function ns.Utils.ShowExportWindow(exportString)
    -- Show in a copy-paste dialog
    ---@diagnostic disable-next-line: undefined-global
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
end
