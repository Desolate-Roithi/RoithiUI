local addonName, AT = ...
local RoithiUI = AT.RoithiUI or _G.RoithiUI
local MinimapMod = RoithiUI:GetModule("Minimap")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LibRoithi = LibStub("LibRoithi-1.0")

local configuratorFrame = nil
local draggedTileIndex = nil

local dragProxy = CreateFrame("Frame", "RoithiAddonDragProxy", UIParent)
dragProxy:SetSize(36, 36)
dragProxy:SetFrameStrata("TOOLTIP")
local dpIcon = dragProxy:CreateTexture(nil, "ARTWORK")
dpIcon:SetAllPoints()
dpIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
dragProxy.icon = dpIcon
dragProxy:Hide()

local function FindButtonIcon(button)
    if not button then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    if button.icon and button.icon.GetTexture and button.icon:GetTexture() then
        return button.icon:GetTexture()
    end
    if button.Icon and button.Icon.GetTexture and button.Icon:GetTexture() then
        return button.Icon:GetTexture()
    end
    if button.GetRegions then
        for _, obj in ipairs({ button:GetRegions() }) do
            if obj:IsObjectType("Texture") then
                local tex = obj:GetTexture()
                if tex then
                    local texStr = type(tex) == "string" and tex:lower() or ""
                    if not texStr:find("border") and not texStr:find("background") and not texStr:find("glow") and not texStr:find("shadow") then
                        return tex
                    end
                end
            end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetOrderedButtonList()
    local scanned = MinimapMod.scannedButtons or {}
    local order = MinimapMod.db and MinimapMod.db.addonBarButtonOrder or {}
    local list = {}

    for name, btn in pairs(scanned) do
        table.insert(list, { name = name, button = btn })
    end

    table.sort(list, function(a, b)
        if order and #order > 0 then
            local idxA, idxB
            for i, n in ipairs(order) do
                if n == a.name then idxA = i end
                if n == b.name then idxB = i end
            end
            if idxA and idxB then return idxA < idxB end
            if idxA then return true end
            if idxB then return false end
        end
        return a.name < b.name
    end)

    return list
end

local function SaveOrder(list)
    local order = {}
    for _, item in ipairs(list) do
        table.insert(order, item.name)
    end
    MinimapMod.db = MinimapMod.db or {}
    MinimapMod.db.addonBarButtonOrder = order
    if MinimapMod.UpdateAddonBarLayout then
        MinimapMod:UpdateAddonBarLayout()
    end
end

function MinimapMod:RefreshAllArrangers()
    if self.arrangerWidget and self.arrangerWidget.Refresh then
        self.arrangerWidget:Refresh()
    end
    if configuratorFrame and configuratorFrame:IsShown() then
        self:UpdateButtonConfiguratorTiles()
    end
end

function MinimapMod:RenderButtonTiles(container, tilesTable)
    if not container then return 0 end

    local buttonList = GetOrderedButtonList()
    local tileSize = 36
    local spacing = 8
    local cols = 8
    local visibleCount = self.db and self.db.addonBarVisibleCount or 3

    for idx, item in ipairs(buttonList) do
        local tile = tilesTable[idx]
        if not tile then
            tile = CreateFrame("Button", nil, container, "BackdropTemplate")
            tile:SetSize(tileSize, tileSize)
            tile:EnableMouse(true)
            tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            tile:RegisterForDrag("LeftButton")

            tile:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeSize = 1,
            })

            local icon = tile:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(tile)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tile.icon = icon

            local badge = tile:CreateFontString(nil, "OVERLAY")
            LibRoithi.mixins:SetFont(badge, "Friz Quadrata TT", 9, "OUTLINE")
            badge:SetPoint("TOPLEFT", tile, "TOPLEFT", 2, -2)
            tile.badge = badge

            -- Item 3.1: Red "X" cross-out overlay for disabled buttons
            local redX = tile:CreateTexture(nil, "OVERLAY", nil, 7)
            redX:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            redX:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
            redX:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -1, 1)
            tile.redX = redX

            -- Item 3.2: Drag and drop with visual feedback
            tile:SetScript("OnDragStart", function(s)
                draggedTileIndex = s.tileIndex
                local tex = s.icon:GetTexture()
                dpIcon:SetTexture(tex)
                dragProxy:Show()
                dragProxy:SetScript("OnUpdate", function(p)
                    local cx, cy = _G.GetCursorPosition()
                    local uiscale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1.0
                    p:ClearAllPoints()
                    p:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / uiscale, cy / uiscale)
                end)
            end)

            local function HandleDrop(s)
                dragProxy:Hide()
                dragProxy:SetScript("OnUpdate", nil)
                if draggedTileIndex and draggedTileIndex ~= s.tileIndex then
                    local currentList = GetOrderedButtonList()
                    local movedItem = table.remove(currentList, draggedTileIndex)
                    table.insert(currentList, s.tileIndex, movedItem)
                    SaveOrder(currentList)
                    MinimapMod:RefreshAllArrangers()
                end
                draggedTileIndex = nil
            end

            tile:SetScript("OnReceiveDrag", HandleDrop)

            tile:SetScript("OnMouseUp", function(s, mouseBtn)
                if draggedTileIndex then
                    HandleDrop(s)
                    return
                end

                -- Click toggles enabled/disabled
                local name = s.buttonName
                if name then
                    MinimapMod.db = MinimapMod.db or {}
                    MinimapMod.db.addonBarButtons = MinimapMod.db.addonBarButtons or {}
                    local current = MinimapMod.db.addonBarButtons[name] ~= false
                    MinimapMod.db.addonBarButtons[name] = not current
                    if MinimapMod.UpdateAddonBarLayout then
                        MinimapMod:UpdateAddonBarLayout()
                    end
                    MinimapMod:RefreshAllArrangers()
                end
            end)

            tile:SetScript("OnEnter", function(s)
                if _G.GameTooltip then
                    _G.GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    local isEnabled = not MinimapMod.db or not MinimapMod.db.addonBarButtons or MinimapMod.db.addonBarButtons[s.buttonName] ~= false
                    local cleanName = s.buttonName:gsub("MinimapButton", ""):gsub("LibDBIconMinimapButton_", ""):gsub("Button", "")
                    _G.GameTooltip:AddLine(cleanName ~= "" and cleanName or s.buttonName, 1, 1, 1)
                    _G.GameTooltip:AddDoubleLine(L["Position"] or "Position", string.format("#%d", s.tileIndex), 0.8, 0.8, 0.8, 0.4, 0.8, 1)
                    _G.GameTooltip:AddDoubleLine(L["Status"] or "Status", isEnabled and (L["Enabled"] or "Enabled") or (L["Disabled"] or "Disabled"), 0.8, 0.8, 0.8, isEnabled and 0.2 or 1, isEnabled and 1 or 0.2, 0.2)
                    _G.GameTooltip:AddLine(" ")
                    _G.GameTooltip:AddLine(L["Left-Click & Drag: Move Position"] or "Left-Click & Drag: Move Position", 0.7, 0.7, 0.7)
                    _G.GameTooltip:AddLine(L["Click: Toggle Enable/Disable"] or "Click: Toggle Enable/Disable", 0.7, 0.7, 0.7)
                    _G.GameTooltip:Show()
                end
            end)

            tile:SetScript("OnLeave", function()
                if _G.GameTooltip then _G.GameTooltip:Hide() end
            end)

            tilesTable[idx] = tile
        end

        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local posX = col * (tileSize + spacing)
        local posY = -(row * (tileSize + spacing))

        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", container, "TOPLEFT", posX, posY)
        tile.tileIndex = idx
        tile.buttonName = item.name

        local tex = FindButtonIcon(item.button)
        tile.icon:SetTexture(tex)

        local isEnabled = not self.db or not self.db.addonBarButtons or self.db.addonBarButtons[item.name] ~= false
        tile.icon:SetDesaturated(not isEnabled)

        if not isEnabled then
            tile.redX:Show()
            tile:SetBackdropBorderColor(0.6, 0.1, 0.1, 0.8)
            tile:SetBackdropColor(0.12, 0.02, 0.02, 0.85)
            tile.badge:SetTextColor(0.5, 0.5, 0.5, 1)
        else
            tile.redX:Hide()
            if idx <= visibleCount then
                tile:SetBackdropBorderColor(1, 0.82, 0, 1)
                tile:SetBackdropColor(0.2, 0.16, 0.02, 0.8)
                tile.badge:SetTextColor(1, 0.82, 0, 1)
            else
                tile:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                tile:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                tile.badge:SetTextColor(0.8, 0.8, 0.8, 1)
            end
        end

        tile.badge:SetText(tostring(idx))
        tile:Show()
    end

    for i = #buttonList + 1, #tilesTable do
        tilesTable[i]:Hide()
    end

    local totalRows = math.ceil(#buttonList / cols)
    return totalRows * (tileSize + spacing)
end

function MinimapMod:OpenButtonConfigurator()
    if configuratorFrame and configuratorFrame:IsShown() then
        configuratorFrame:Hide()
        return
    end

    if not configuratorFrame then
        local frame = CreateFrame("Frame", "RoithiButtonConfigurator", UIParent, "BackdropTemplate")
        frame:SetSize(440, 360)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetClampedToScreen(true)

        LibRoithi.mixins:CreateBackdrop(frame)
        frame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
        frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        local title = frame:CreateFontString(nil, "OVERLAY")
        LibRoithi.mixins:SetFont(title, "Friz Quadrata TT", 14, "OUTLINE")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
        title:SetText(L["Addon Button Arrangement"] or "Addon Button Arrangement")
        title:SetTextColor(1, 0.82, 0, 1)

        local subtitle = frame:CreateFontString(nil, "OVERLAY")
        LibRoithi.mixins:SetFont(subtitle, "Friz Quadrata TT", 10, "OUTLINE")
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        subtitle:SetPoint("RIGHT", frame, "RIGHT", -30, 0)
        subtitle:SetJustifyH("LEFT")
        subtitle:SetText(L["Drag icons to reorder. First N buttons are shown in Base view. Click to toggle enable/disable."] or "Drag icons to reorder. First N buttons are shown in Base view. Click to toggle enable/disable.")
        subtitle:SetTextColor(0.7, 0.7, 0.7, 1)

        local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        local container = CreateFrame("Frame", nil, frame)
        container:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -58)
        container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
        frame.container = container

        frame.tiles = {}
        configuratorFrame = frame

        if _G.UISpecialFrames then
            table.insert(_G.UISpecialFrames, "RoithiButtonConfigurator")
        end
    end

    self:UpdateButtonConfiguratorTiles()
    configuratorFrame:Show()
end

function MinimapMod:UpdateButtonConfiguratorTiles()
    if not configuratorFrame or not configuratorFrame.container then return end
    self:RenderButtonTiles(configuratorFrame.container, configuratorFrame.tiles)
end

-- Register AceGUI widget for embedded settings usage (Items 3, 3.1, 3.2, 5)
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if AceGUI then
    local Type, Version = "RoithiButtonArranger", 1
    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(420, 150)

        local desc = frame:CreateFontString(nil, "OVERLAY")
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(desc, "Friz Quadrata TT", 10, "OUTLINE")
        end
        desc:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        desc:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        desc:SetJustifyH("LEFT")
        desc:SetText(L["Drag icons to reorder. First N buttons are shown in Base view. Click icon to toggle enable/disable (red X indicates disabled)."] or "Drag icons to reorder. First N buttons are shown in Base view. Click icon to toggle enable/disable (red X indicates disabled).")
        desc:SetTextColor(0.75, 0.75, 0.75, 1)

        local container = CreateFrame("Frame", nil, frame)
        container:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -8)
        container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

        local widget = {
            frame = frame,
            type = Type,
            container = container,
            tiles = {},
            OnAcquire = function(self)
                self:Refresh()
            end,
            OnRelease = function(self)
                for _, t in ipairs(self.tiles) do t:Hide() end
            end,
            SetLabel = function() end,
            SetDisabled = function() end,
            SetValue = function() end,
            SetText = function() end,
            GetText = function() return "" end,
            SetNumLines = function() end,
            Refresh = function(self)
                local h = MinimapMod:RenderButtonTiles(self.container, self.tiles)
                self.frame:SetHeight(math.max(120, h + 30))
            end,
        }
        MinimapMod.arrangerWidget = widget
        return AceGUI:RegisterAsWidget(widget)
    end
    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
