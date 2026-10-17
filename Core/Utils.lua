local _, ns = ...
if ns.skipLoad then return end

-- -------------------------------------------------------------------------
-- Environment & Client Flavor Detection
-- -------------------------------------------------------------------------
local GetBuildInfo = _G.GetBuildInfo
local cGameRules = _G.C_GameRules
local WOW_PROJECT_ID = _G.WOW_PROJECT_ID
local WOW_PROJECT_MAINLINE = _G.WOW_PROJECT_MAINLINE

local interfaceVersion = GetBuildInfo and select(4, GetBuildInfo())
ns.InterfaceVersion = tonumber(interfaceVersion) or 0
ns.IsForever = (ns.InterfaceVersion == 16001) or (cGameRules and cGameRules.IsForever and cGameRules.IsForever() or false)
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

function ns.Utils.NormalizeFontFlags(outline)
    if not outline or outline == "NONE" or outline == "None" or outline == "none" or outline == "" then
        return ""
    end
    return outline
end

function ns.Utils.ResolveFontPath(fontName, defaultFallback)
    if fontName and (fontName:find("\\") or fontName:find("/")) then
        return fontName
    end
    local lsm = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if lsm and fontName then
        local fetched = lsm:Fetch("font", fontName)
        if fetched then return fetched end
    end
    if lsm and defaultFallback then
        local fetched = lsm:Fetch("font", defaultFallback)
        if fetched then return fetched end
    end
    if lsm then
        local exp = lsm:Fetch("font", "Expressway") or lsm:Fetch("font", "Roithi Thick")
        if exp then return exp end
    end
    return "Fonts\\FRIZQT__.TTF"
end

function ns.Utils.ApplyTypography(fontString, fontName, fontSize, fontOutline, fontShadow, fallbackFont)
    if not fontString or not fontString.SetFont then return end

    local fontPath = ns.Utils.ResolveFontPath(fontName, fallbackFont or "Expressway")
    local flags = ns.Utils.NormalizeFontFlags(fontOutline)
    fontString:SetFont(fontPath, fontSize or 12, flags)

    if fontString.SetShadowOffset then
        if fontShadow == true then
            fontString:SetShadowOffset(1, -1)
            if fontString.SetShadowColor then fontString:SetShadowColor(0, 0, 0, 1) end
        else
            fontString:SetShadowOffset(0, 0)
        end
    end

    if fontString.GetText and fontString.SetText then
        local txt = fontString:GetText()
        if txt and txt ~= "" then fontString:SetText(txt) end
    end
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
-- Screen Clamping & Coordinate Sanitization Helpers
-- -------------------------------------------------------------------------
function ns.Utils.SanitizeAndCenterPoint(point, x, y, width, height, padding, extraLeft)
    point = point or "CENTER"
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    width = tonumber(width) or 200
    height = tonumber(height) or 20
    padding = tonumber(padding) or 10
    extraLeft = tonumber(extraLeft) or 0

    local sw = UIParent and UIParent:GetWidth() or 1920
    local sh = UIParent and UIParent:GetHeight() or 1080
    if not sw or sw <= 0 then sw = 1920 end
    if not sh or sh <= 0 then sh = 1080 end

    local centerX, centerY = x, y
    if point == "BOTTOM" then
        centerY = y - (sh / 2) + (height / 2)
    elseif point == "TOP" then
        centerY = y + (sh / 2) - (height / 2)
    elseif point == "LEFT" then
        centerX = x - (sw / 2) + (width / 2)
    elseif point == "RIGHT" then
        centerX = x + (sw / 2) - (width / 2)
    elseif point == "TOPLEFT" then
        centerX = x - (sw / 2) + (width / 2)
        centerY = y + (sh / 2) - (height / 2)
    elseif point == "BOTTOMLEFT" then
        centerX = x - (sw / 2) + (width / 2)
        centerY = y - (sh / 2) + (height / 2)
    elseif point == "TOPRIGHT" then
        centerX = x + (sw / 2) - (width / 2)
        centerY = y + (sh / 2) - (height / 2)
    elseif point == "BOTTOMRIGHT" then
        centerX = x + (sw / 2) - (width / 2)
        centerY = y - (sh / 2) + (height / 2)
    end

    local maxX = (sw / 2) - (width / 2) - padding
    local minX = -((sw / 2) - (width / 2) - padding - extraLeft)
    if minX > maxX then minX = maxX end
    centerX = math.max(minX, math.min(maxX, centerX))

    local maxY = (sh / 2) - (height / 2) - padding
    local minY = -maxY
    if minY > maxY then minY, maxY = maxY, minY end
    centerY = math.max(minY, math.min(maxY, centerY))

    return "CENTER", math.floor(centerX * 100 + 0.5) / 100, math.floor(centerY * 100 + 0.5) / 100
end

function ns.Utils.ClampFrameToScreen(frame, padding)
    if not frame or not frame.GetPoint then return end
    padding = padding or 10

    local sw = UIParent and UIParent:GetWidth() or 1920
    local sh = UIParent and UIParent:GetHeight() or 1080
    if not sw or sw <= 0 then sw = 1920 end
    if not sh or sh <= 0 then sh = 1080 end

    local left = frame.GetLeft and frame:GetLeft()
    local right = frame.GetRight and frame:GetRight()
    local top = frame.GetTop and frame:GetTop()
    local bottom = frame.GetBottom and frame:GetBottom()

    if not left or not right or not top or not bottom then return end
    if (_G.issecretvalue and (_G.issecretvalue(left) or _G.issecretvalue(right) or _G.issecretvalue(top) or _G.issecretvalue(bottom))) then return end

    local shiftX = 0
    local shiftY = 0

    if left < padding then
        shiftX = padding - left
    elseif right > (sw - padding) then
        shiftX = (sw - padding) - right
    end

    if bottom < padding then
        shiftY = padding - bottom
    elseif top > (sh - padding) then
        shiftY = (sh - padding) - top
    end

    if shiftX ~= 0 or shiftY ~= 0 then
        local p, relTo, relP, curX, curY = frame:GetPoint(1)
        p = p or "CENTER"
        curX = (curX or 0) + shiftX
        curY = (curY or 0) + shiftY
        frame:ClearAllPoints()
        frame:SetPoint(p, relTo or UIParent, relP or p, curX, curY)
    end
end

-- -------------------------------------------------------------------------
-- String & Media Helpers
-- -------------------------------------------------------------------------
function ns.Utils.FormatHotkey(text)
    if not text or text == "" then return "" end
    if (_G.RANGE_INDICATOR and text == _G.RANGE_INDICATOR)
        or text == "·"
        or text == "•"
        or text == "●"
        or text:find("\194\183", 1, true)
        or text:find("\226\128\162", 1, true)
        or text:find("\149", 1, true)
        or text:find("[\194\183\226\128\162]")
    then
        return ""
    end
    local formatted = text
    formatted = formatted:gsub("SHIFT%-", "S")
    formatted = formatted:gsub("Shift%-", "S")
    formatted = formatted:gsub("s%-", "S")
    formatted = formatted:gsub("CTRL%-", "C")
    formatted = formatted:gsub("Ctrl%-", "C")
    formatted = formatted:gsub("c%-", "C")
    formatted = formatted:gsub("ALT%-", "A")
    formatted = formatted:gsub("Alt%-", "A")
    formatted = formatted:gsub("a%-", "A")
    formatted = formatted:gsub("STRG%-", "C")
    formatted = formatted:gsub("Strg%-", "C")
    formatted = formatted:gsub("SPACE", "Sp")
    formatted = formatted:gsub("Mouse Wheel Up", "WU")
    formatted = formatted:gsub("Mouse Wheel Down", "WD")
    return formatted
end

function ns.Utils.GetLSMKeys(mediaType)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM then return {} end
    local list = LSM:List(mediaType)
    local out = {}
    for _, name in ipairs(list) do
        out[name] = name
    end
    return out
end

-- -------------------------------------------------------------------------
-- Centralized Anchor Point System
-- -------------------------------------------------------------------------
local ANCHOR_POINTS = {
    "TOPLEFT",
    "TOP",
    "TOPRIGHT",
    "LEFT",
    "CENTER",
    "RIGHT",
    "BOTTOMLEFT",
    "BOTTOM",
    "BOTTOMRIGHT",
}
ns.Utils.ANCHOR_POINTS = ANCHOR_POINTS

local ANCHOR_NAMES = {
    TOPLEFT = "Top Left",
    TOP = "Top",
    TOPRIGHT = "Top Right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}
ns.Utils.ANCHOR_NAMES = ANCHOR_NAMES

function ns.Utils.GetAnchorList()
    local list = {}
    for i, a in ipairs(ANCHOR_POINTS) do
        list[i] = a
    end
    return list
end

function ns.Utils.GetNextAnchor(current)
    local cur = current or "CENTER"
    local idx = 1
    for i, a in ipairs(ANCHOR_POINTS) do
        if a == cur then
            idx = i
            break
        end
    end
    return ANCHOR_POINTS[(idx % #ANCHOR_POINTS) + 1]
end

function ns.Utils.GetAnchorJustifyH(anchor)
    if not anchor then return "CENTER" end
    if anchor:find("LEFT") then
        return "LEFT"
    elseif anchor:find("RIGHT") then
        return "RIGHT"
    end
    return "CENTER"
end

function ns.Utils.GetDefaultAnchorOffsets(anchor, padding)
    local pad = padding or 2
    if not anchor then return 0, 0, "CENTER" end
    local ox = anchor:find("RIGHT") and -pad or (anchor:find("LEFT") and pad or 0)
    local oy = anchor:find("TOP") and -pad or (anchor:find("BOTTOM") and pad or 0)
    local justifyH = ns.Utils.GetAnchorJustifyH(anchor)
    return ox, oy, justifyH
end

function ns.Utils.GetAnchorDropdownValues()
    local L = LibStub and LibStub("AceLocale-3.0", true) and LibStub("AceLocale-3.0"):GetLocale("RoithiUI", true)
    local values = {}
    for _, pt in ipairs(ANCHOR_POINTS) do
        local rawText = ANCHOR_NAMES[pt] or pt
        values[pt] = (L and L[rawText]) or rawText
    end
    return values
end

function ns.Utils.GetAnchorLEMValues()
    local L = LibStub and LibStub("AceLocale-3.0", true) and LibStub("AceLocale-3.0"):GetLocale("RoithiUI", true)
    local values = {}
    for _, pt in ipairs(ANCHOR_POINTS) do
        local rawText = ANCHOR_NAMES[pt] or pt
        table.insert(values, {
            text = (L and L[rawText]) or rawText,
            value = pt,
        })
    end
    return values
end

-------------------------------------------------------------------------
-- Growth Direction & Coordinate Math Helpers
-------------------------------------------------------------------------
function ns.Utils.GetGrowthAnchor(growthDir, is1D)
    if not growthDir then return "CENTER" end
    if growthDir == "RIGHT_TO_LEFT" or growthDir == "LEFT" then
        return "RIGHT"
    elseif growthDir == "LEFT_TO_RIGHT" or growthDir == "RIGHT" then
        return "LEFT"
    elseif growthDir == "TOP_TO_BOTTOM" or growthDir == "DOWN" then
        return "TOP"
    elseif growthDir == "BOTTOM_TO_TOP" or growthDir == "UP" then
        return "BOTTOM"
    elseif growthDir == "CENTER_HORIZONTAL_UP" then
        return "BOTTOM"
    elseif growthDir == "CENTER_HORIZONTAL_DOWN" then
        return "TOP"
    elseif growthDir == "CENTER_HORIZONTAL" or growthDir == "CENTER_HORIZ" then
        return (is1D ~= false) and "CENTER" or "TOP"
    elseif growthDir == "CENTER_VERTICAL_LEFT" then
        return "RIGHT"
    elseif growthDir == "CENTER_VERTICAL_RIGHT" then
        return "LEFT"
    elseif growthDir == "CENTER_VERTICAL" or growthDir == "CENTER_VERT" then
        return (is1D ~= false) and "CENTER" or "LEFT"
    elseif growthDir == "LEFT_DOWN" or growthDir == "DOWN_LEFT" then
        return "TOPRIGHT"
    elseif growthDir == "RIGHT_UP" or growthDir == "UP_RIGHT" then
        return "BOTTOMLEFT"
    elseif growthDir == "LEFT_UP" or growthDir == "UP_LEFT" then
        return "BOTTOMRIGHT"
    elseif growthDir == "RIGHT_DOWN" or growthDir == "DOWN_RIGHT" then
        return "TOPLEFT"
    end
    return "CENTER"
end

function ns.Utils.PointToCenter(point, x, y, width, height)
    point = point or "CENTER"
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    local w = tonumber(width) or 0
    local h = tonumber(height) or 0
    local cx, cy = x, y

    if point:find("LEFT") then
        cx = x + (w / 2)
    elseif point:find("RIGHT") then
        cx = x - (w / 2)
    end

    if point:find("BOTTOM") then
        cy = y + (h / 2)
    elseif point:find("TOP") then
        cy = y - (h / 2)
    end

    return cx, cy
end

function ns.Utils.CenterToPoint(targetPoint, cx, cy, width, height)
    targetPoint = targetPoint or "CENTER"
    cx = tonumber(cx) or 0
    cy = tonumber(cy) or 0
    local w = tonumber(width) or 0
    local h = tonumber(height) or 0
    local px, py = cx, cy

    if targetPoint:find("LEFT") then
        px = cx - (w / 2)
    elseif targetPoint:find("RIGHT") then
        px = cx + (w / 2)
    end

    if targetPoint:find("BOTTOM") then
        py = cy - (h / 2)
    elseif targetPoint:find("TOP") then
        py = cy + (h / 2)
    end

    return px, py
end

function ns.Utils.MigratePointCoordinates(curPoint, targetPoint, curX, curY, width, height)
    if curPoint == targetPoint then
        return curX or 0, curY or 0
    end
    local cx, cy = ns.Utils.PointToCenter(curPoint, curX, curY, width, height)
    return ns.Utils.CenterToPoint(targetPoint, cx, cy, width, height)
end

function ns.Utils.GetGridDimensions(totalCount, perLine, itemWidth, itemHeight, spacingX, spacingY, isVertical)
    local count = math.max(1, tonumber(totalCount) or 1)
    local limit = tonumber(perLine)
    if not limit or limit < 1 then limit = count end
    local w = tonumber(itemWidth) or 40
    local h = tonumber(itemHeight) or w
    local sx = tonumber(spacingX) or 0
    local sy = tonumber(spacingY) or sx

    local primaryCount = math.min(count, limit)
    local secondaryCount = math.ceil(count / limit)

    local cols = isVertical and secondaryCount or primaryCount
    local rows = isVertical and primaryCount or secondaryCount
    if cols < 1 then cols = 1 end
    if rows < 1 then rows = 1 end

    local totalW = (cols * w) + math.max(0, cols - 1) * sx
    local totalH = (rows * h) + math.max(0, rows - 1) * sy
    return cols, rows, totalW, totalH, limit
end

function ns.Utils.GetGridItemOffset(growthDir, index, totalCount, perLine, itemWidth, itemHeight, spacingX, spacingY, isVertical, centerIncompleteLines)
    local cols, rows, _, _, effectivePerLine = ns.Utils.GetGridDimensions(totalCount, perLine, itemWidth, itemHeight, spacingX, spacingY, isVertical)
    local idx = math.max(1, tonumber(index) or 1)
    local w = tonumber(itemWidth) or 40
    local h = tonumber(itemHeight) or w
    local sx = tonumber(spacingX) or 0
    local sy = tonumber(spacingY) or sx
    local pitchX = w + sx
    local pitchY = h + sy

    local primaryIdx = (idx - 1) % effectivePerLine
    local secondaryIdx = math.floor((idx - 1) / effectivePerLine)
    local col = isVertical and secondaryIdx or primaryIdx
    local row = isVertical and primaryIdx or secondaryIdx

    local gDir = growthDir or "LEFT_TO_RIGHT"
    local is1D = (rows == 1 and not isVertical) or (cols == 1 and isVertical)

    -- Symmetrical horizontal centering
    if gDir == "CENTER_HORIZONTAL" or gDir == "CENTER" then
        if is1D then
            local totalSpan = (totalCount - 1) * pitchX
            local ox = -totalSpan / 2 + (idx - 1) * pitchX
            return ox, 0, "CENTER"
        else
            local itemsInRow = math.min(totalCount - row * effectivePerLine, effectivePerLine)
            if itemsInRow < 1 then itemsInRow = 1 end
            local rowW = (itemsInRow * w) + math.max(0, itemsInRow - 1) * sx
            local ox = -rowW / 2 + w / 2 + primaryIdx * pitchX
            local oy = -row * pitchY - h / 2
            return ox, oy, "TOP"
        end
    elseif gDir == "CENTER_HORIZONTAL_UP" then
        local itemsInRow = math.min(totalCount - row * effectivePerLine, effectivePerLine)
        if itemsInRow < 1 then itemsInRow = 1 end
        local rowW = (itemsInRow * w) + math.max(0, itemsInRow - 1) * sx
        local ox = -rowW / 2 + w / 2 + primaryIdx * pitchX
        local oy = row * pitchY + h / 2
        return ox, oy, "BOTTOM"
    elseif gDir == "CENTER_VERTICAL" then
        if is1D then
            local totalSpan = (totalCount - 1) * pitchY
            local oy = totalSpan / 2 - (idx - 1) * pitchY
            return 0, oy, "CENTER"
        else
            local itemsInCol = math.min(totalCount - col * effectivePerLine, effectivePerLine)
            if itemsInCol < 1 then itemsInCol = 1 end
            local colH = (itemsInCol * h) + math.max(0, itemsInCol - 1) * sy
            local ox = col * pitchX + w / 2
            local oy = colH / 2 - h / 2 - primaryIdx * pitchY
            return ox, oy, "LEFT"
        end
    elseif gDir == "CENTER_VERTICAL_LEFT" then
        local itemsInCol = math.min(totalCount - col * effectivePerLine, effectivePerLine)
        if itemsInCol < 1 then itemsInCol = 1 end
        local colH = (itemsInCol * h) + math.max(0, itemsInCol - 1) * sy
        local ox = -col * pitchX - w / 2
        local oy = colH / 2 - h / 2 - primaryIdx * pitchY
        return ox, oy, "RIGHT"
    end

    local gAnchor = ns.Utils.GetGrowthAnchor(gDir, is1D)

    if gAnchor == "RIGHT" or gAnchor == "TOPRIGHT" then
        local ox = -col * pitchX
        local oy = -row * pitchY
        return ox, oy, is1D and "RIGHT" or "TOPRIGHT"
    elseif gAnchor == "BOTTOMRIGHT" then
        local ox = -col * pitchX
        local oy = row * pitchY
        return ox, oy, "BOTTOMRIGHT"
    elseif gAnchor == "BOTTOMLEFT" or gAnchor == "BOTTOM" then
        local ox = col * pitchX
        local oy = row * pitchY
        return ox, oy, (is1D or gAnchor == "BOTTOM") and "BOTTOM" or "BOTTOMLEFT"
    elseif gAnchor == "TOP" then
        local ox = col * pitchX
        local oy = -row * pitchY
        return ox, oy, "TOP"
    else -- LEFT / TOPLEFT
        local ox = col * pitchX
        local oy = -row * pitchY
        return ox, oy, is1D and "LEFT" or "TOPLEFT"
    end
end

-- Backward compatibility wrapper for pure 1D calls
function ns.Utils.GetLinearItemOffset(growthDir, index, totalCount, itemSize, spacing)
    local isVertical = (growthDir == "TOP_TO_BOTTOM" or growthDir == "BOTTOM_TO_TOP" or growthDir == "CENTER_VERTICAL" or growthDir == "CENTER_VERTICAL_LEFT" or growthDir == "CENTER_VERTICAL_RIGHT")
    local ox, oy, anchor = ns.Utils.GetGridItemOffset(growthDir, index, totalCount, totalCount, itemSize, itemSize, spacing, spacing, isVertical)
    return ox, oy, anchor
end

function ns.Utils.GetFrameScreenCoordinates(frame, parent, anchorPoint)
    parent = parent or _G.UIParent
    anchorPoint = anchorPoint or "CENTER"
    if not frame or not frame.GetLeft or not parent or not parent.GetWidth then
        return 0, 0
    end
    local fL, fR, fB, fT = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    if not fL or not fR or not fB or not fT then return 0, 0 end
    local pW, pH = parent:GetWidth() or 0, parent:GetHeight() or 0
    local fW, fH = fR - fL, fT - fB

    local x, y
    if anchorPoint == "TOPLEFT" then
        x = fL
        y = fT - pH
    elseif anchorPoint == "BOTTOMLEFT" then
        x = fL
        y = fB
    elseif anchorPoint == "TOPRIGHT" then
        x = fR - pW
        y = fT - pH
    elseif anchorPoint == "BOTTOMRIGHT" then
        x = fR - pW
        y = fB
    elseif anchorPoint == "TOP" then
        x = fL + (fW / 2) - (pW / 2)
        y = fT - pH
    elseif anchorPoint == "BOTTOM" then
        x = fL + (fW / 2) - (pW / 2)
        y = fB
    elseif anchorPoint == "LEFT" then
        x = fL
        y = fB + (fH / 2) - (pH / 2)
    elseif anchorPoint == "RIGHT" then
        x = fR - pW
        y = fB + (fH / 2) - (pH / 2)
    else -- CENTER
        x = fL + (fW / 2) - (pW / 2)
        y = fB + (fH / 2) - (pH / 2)
    end

    return x, y
end

function ns.Utils.GetAuraFlowLayoutParameters(growthDir)
    local gDir = growthDir or "RIGHT_DOWN"
    local isCenterHoriz = (gDir:find("CENTER_HORIZONTAL") or gDir == "CENTER_HORIZ")
    local isCenterVert = (gDir:find("CENTER_VERTICAL") or gDir == "CENTER_VERT")
    local isVerticalLayout = (gDir == "DOWN_RIGHT" or gDir == "DOWN_LEFT" or gDir == "UP_RIGHT" or gDir == "UP_LEFT"
        or isCenterVert or gDir == "DOWN" or gDir == "UP")

    local layoutAnchor = "TOPLEFT"
    if gDir == "RIGHT_DOWN" or gDir == "DOWN" or gDir == "DOWN_RIGHT" or gDir == "TOP_TO_BOTTOM" or gDir == "RIGHT" then
        layoutAnchor = "TOPLEFT"
    elseif gDir == "RIGHT_UP" or gDir == "UP" or gDir == "UP_RIGHT" or gDir == "BOTTOM_TO_TOP" then
        layoutAnchor = "BOTTOMLEFT"
    elseif gDir == "LEFT_DOWN" or gDir == "DOWN_LEFT" or gDir == "LEFT" then
        layoutAnchor = "TOPRIGHT"
    elseif gDir == "LEFT_UP" or gDir == "UP_LEFT" then
        layoutAnchor = "BOTTOMRIGHT"
    elseif gDir == "CENTER_HORIZONTAL_UP" then
        layoutAnchor = "BOTTOMLEFT"
    elseif gDir == "CENTER_HORIZONTAL_DOWN" or isCenterHoriz then
        layoutAnchor = "TOPLEFT"
    elseif gDir == "CENTER_VERTICAL_LEFT" then
        layoutAnchor = "TOPRIGHT"
    elseif gDir == "CENTER_VERTICAL_RIGHT" or isCenterVert then
        layoutAnchor = "TOPLEFT"
    end

    local axisVal = isVerticalLayout and 1 or 0
    local horizDir = (gDir:find("LEFT") and not gDir:find("RIGHT")
        and not (gDir == "CENTER_HORIZONTAL_DOWN" or gDir == "CENTER_HORIZONTAL_UP" or gDir == "CENTER_VERTICAL_RIGHT")) and -1 or 1
    local vertDir = (gDir == "RIGHT_UP" or gDir == "LEFT_UP" or gDir == "UP_RIGHT" or gDir == "UP_LEFT"
        or gDir == "CENTER_HORIZONTAL_UP" or gDir == "BOTTOM_TO_TOP" or layoutAnchor:find("BOTTOM")) and 1 or -1

    return layoutAnchor, axisVal, horizDir, vertDir
end

local RoithiUI = _G.RoithiUI
if RoithiUI then
    RoithiUI.Utils = ns.Utils
end



