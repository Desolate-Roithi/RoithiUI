local _, ns = ...
if ns.skipLoad then return end

-- -------------------------------------------------------------------------
-- Environment & Client Flavor Detection
-- -------------------------------------------------------------------------
local GetBuildInfo = _G.GetBuildInfo
local WOW_PROJECT_ID = _G.WOW_PROJECT_ID
local WOW_PROJECT_MAINLINE = _G.WOW_PROJECT_MAINLINE

local _, _, _, interfaceVersion = GetBuildInfo()
ns.InterfaceVersion = tonumber(interfaceVersion) or 0
ns.IsForever = (ns.InterfaceVersion == 16001) or (_G.C_GameRules and _G.C_GameRules.IsForever and _G.C_GameRules.IsForever() or false)
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

-- -------------------------------------------------------------------------
-- Screen Clamping & Coordinate Sanitization
-- -------------------------------------------------------------------------
function ns.Utils.SanitizeAndCenterPoint(point, x, y, width, height, padding)
    padding = padding or 10
    width = tonumber(width) or 200
    height = tonumber(height) or 20
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    point = point or "CENTER"

    local screenW, screenH = 1920, 1080
    if UIParent and UIParent.GetSize then
        local w, h = UIParent:GetSize()
        if w and w > 0 and h and h > 0 then
            screenW, screenH = w, h
        end
    end

    local halfW = screenW / 2
    local halfH = screenH / 2

    -- Convert non-CENTER points to screen-centered coordinates
    local cX = x
    local cY = y

    if point == "TOP" then
        cY = y + halfH - (height / 2)
    elseif point == "BOTTOM" then
        cY = y - halfH + (height / 2)
    elseif point == "LEFT" then
        cX = x - halfW + (width / 2)
    elseif point == "RIGHT" then
        cX = x + halfW - (width / 2)
    elseif point == "TOPLEFT" then
        cX = x - halfW + (width / 2)
        cY = y + halfH - (height / 2)
    elseif point == "TOPRIGHT" then
        cX = x + halfW - (width / 2)
        cY = y + halfH - (height / 2)
    elseif point == "BOTTOMLEFT" then
        cX = x - halfW + (width / 2)
        cY = y - halfH + (height / 2)
    elseif point == "BOTTOMRIGHT" then
        cX = x + halfW - (width / 2)
        cY = y - halfH + (height / 2)
    end

    -- Strict clamping within visible screen boundaries
    local maxX = math.max(0, halfW - (width / 2) - padding)
    local maxY = math.max(0, halfH - (height / 2) - padding)

    cX = math.max(-maxX, math.min(maxX, cX))
    cY = math.max(-maxY, math.min(maxY, cY))

    cX = math.floor(cX * 100 + 0.5) / 100
    cY = math.floor(cY * 100 + 0.5) / 100

    return "CENTER", cX, cY
end

function ns.Utils.ClampFrameToScreen(frame, padding)
    if not frame then return end
    padding = padding or 10

    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
        if frame.SetClampRectInsets then
            frame:SetClampRectInsets(-padding, padding, padding, -padding)
        end
    end

    local left = frame.GetLeft and frame:GetLeft()
    local right = frame.GetRight and frame:GetRight()
    local top = frame.GetTop and frame:GetTop()
    local bottom = frame.GetBottom and frame:GetBottom()
    if not left or not right or not top or not bottom then return end

    local screenW, screenH = 1920, 1080
    if UIParent and UIParent.GetSize then
        local w, h = UIParent:GetSize()
        if w and w > 0 and h and h > 0 then
            screenW, screenH = w, h
        end
    end

    local shiftX = 0
    local shiftY = 0

    if left < padding then
        shiftX = padding - left
    elseif right > (screenW - padding) then
        shiftX = (screenW - padding) - right
    end

    if bottom < padding then
        shiftY = padding - bottom
    elseif top > (screenH - padding) then
        shiftY = (screenH - padding) - top
    end

    if shiftX ~= 0 or shiftY ~= 0 then
        local numPoints = frame.GetNumPoints and frame:GetNumPoints() or 1
        if numPoints == 1 and frame.GetPoint and frame.ClearAllPoints and frame.SetPoint then
            local pt, relTo, relPt, curX, curY = frame:GetPoint(1)
            frame:ClearAllPoints()
            frame:SetPoint(pt or "CENTER", relTo or UIParent, relPt or pt or "CENTER", (curX or 0) + shiftX, (curY or 0) + shiftY)
        end
    end
end

