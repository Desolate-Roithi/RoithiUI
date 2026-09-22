local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local AB = RoithiUI:GetModule("Actionbars")
local LibRoithi = LibStub("LibRoithi-1.0")

local BAR_CONFIGS = {
    bar1 = { name = "RoithiActionBar1", prefix = "ActionButton", count = 12 },
    bar2 = { name = "RoithiActionBar2", prefix = "MultiBarBottomLeftButton", count = 12 },
    bar3 = { name = "RoithiActionBar3", prefix = "MultiBarBottomRightButton", count = 12 },
    bar4 = { name = "RoithiActionBar4", prefix = "MultiBarRightButton", count = 12 },
    bar5 = { name = "RoithiActionBar5", prefix = "MultiBarLeftButton", count = 12 },
    pet = { name = "RoithiActionPetBar", prefix = "PetActionButton", count = 10 },
    stance = { name = "RoithiActionStanceBar", prefix = "StanceButton", count = 10, altPrefix = "ShapeshiftButton" },
}
AB.BAR_CONFIGS = BAR_CONFIGS

function AB:GetBarButtons(barKey)
    local cfg = BAR_CONFIGS[barKey]
    if not cfg then return {} end

    local buttons = {}
    for i = 1, cfg.count do
        local btn = _G[cfg.prefix .. i]
        if not btn and cfg.altPrefix then
            btn = _G[cfg.altPrefix .. i]
        end
        if btn then
            table.insert(buttons, btn)
        end
    end
    return buttons
end

function AB:SetupBars()
    for barKey, cfg in pairs(BAR_CONFIGS) do
        if not self.bars[barKey] then
            local f = CreateFrame("Frame", cfg.name, UIParent)
            f:SetClampedToScreen(true)
            f:SetMovable(true)
            f.barKey = barKey
            self.bars[barKey] = f

            local db = self.db[barKey] or {}
            local pt = db.point or "BOTTOM"
            f:ClearAllPoints()
            f:SetPoint(pt, UIParent, pt, db.x or 0, db.y or 0)
        end
        self.bars[barKey]:Show()
    end

    -- Hide Blizzard Art Frames in Classic/Forever
    if _G.MainMenuBarArtFrame then
        _G.MainMenuBarArtFrame:Hide()
    end
end

function AB:StyleButton(button)
    if not button then return end

    -- 1. Icon TexCoords (Zoomed to create modern square look)
    local icon = button.icon or _G[button:GetName() and (button:GetName() .. "Icon") or ""]
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    -- 2. Hide Blizzard Borders
    local border = button.Border or _G[button:GetName() and (button:GetName() .. "Border") or ""]
    if border and border.SetAlpha then
        border:SetAlpha(0)
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal and normal.SetAlpha then
        normal:SetAlpha(0)
    end

    -- 3. 1px Custom Backdrop
    if not button.roithiBackdrop then
        local bg = CreateFrame("Frame", nil, button, "BackdropTemplate")
        if bg.SetAllPoints then
            bg:SetAllPoints(button)
        end
        if bg.SetFrameLevel and button.GetFrameLevel then
            bg:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
        end
        if bg.SetBackdrop then
            bg:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            bg:SetBackdropColor(0.05, 0.05, 0.05, 0.7)
            local bc = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
            bg:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        end
        button.roithiBackdrop = bg
    else
        button.roithiBackdrop:Show()
        local bc = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
        if button.roithiBackdrop.SetBackdropBorderColor then
            button.roithiBackdrop:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        end
    end

    -- 4. Keybind Hotkey Styling
    local hotkey = button.HotKey or _G[button:GetName() and (button:GetName() .. "HotKey") or ""]
    if hotkey then
        if hotkey.SetShown then
            hotkey:SetShown(self.db.showHotkeys ~= false)
        end
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(hotkey, self.db.font or "Friz Quadrata TT", self.db.fontSize or 11, "OUTLINE")
        end
    end

    -- 5. Macro Text Styling
    local name = button.Name or _G[button:GetName() and (button:GetName() .. "Name") or ""]
    if name then
        if name.SetShown then
            name:SetShown(self.db.showMacroText ~= false)
        end
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(name, self.db.font or "Friz Quadrata TT", math.max(8, (self.db.fontSize or 11) - 2), "OUTLINE")
        end
    end
end

function AB:UnstyleButton(button)
    if not button then return end

    local icon = button.icon or _G[button:GetName() and (button:GetName() .. "Icon") or ""]
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0, 1, 0, 1)
    end

    local border = button.Border or _G[button:GetName() and (button:GetName() .. "Border") or ""]
    if border and border.SetAlpha then
        border:SetAlpha(1)
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal and normal.SetAlpha then
        normal:SetAlpha(1)
    end

    if button.roithiBackdrop then
        button.roithiBackdrop:Hide()
    end
end

function AB:StyleAllBars()
    for barKey in pairs(BAR_CONFIGS) do
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            self:StyleButton(btn)
        end
    end
end

function AB:UnstyleAllBars()
    for barKey in pairs(BAR_CONFIGS) do
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            self:UnstyleButton(btn)
        end
    end
end

function AB:LayoutBar(barKey)
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedLayout = true
        return
    end

    local container = self.bars[barKey]
    if not container then return end

    local db = self.db[barKey]
    if not db or db.enabled == false then
        container:Hide()
        return
    end
    container:Show()

    local buttons = self:GetBarButtons(barKey)
    if #buttons == 0 then return end

    local btnSize = db.buttonSize or 36
    local spacing = db.spacing or 4
    local perRow = db.buttonsPerRow or #buttons
    if perRow < 1 then perRow = 1 end

    local numCols = math.min(#buttons, perRow)
    local numRows = math.ceil(#buttons / perRow)

    local totalW = (numCols * btnSize) + math.max(0, (numCols - 1) * spacing)
    local totalH = (numRows * btnSize) + math.max(0, (numRows - 1) * spacing)
    container:SetSize(totalW, totalH)

    for i, btn in ipairs(buttons) do
        btn:ClearAllPoints()
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local x = col * (btnSize + spacing)
        local y = -row * (btnSize + spacing)

        btn:SetSize(btnSize, btnSize)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
    end
end

function AB:LayoutAllBars()
    for barKey in pairs(BAR_CONFIGS) do
        self:LayoutBar(barKey)
    end
end

function AB:RestoreBlizzardBars()
    for _, container in pairs(self.bars) do
        container:Hide()
    end

    if _G.MainMenuBarArtFrame then
        _G.MainMenuBarArtFrame:Show()
    end
end
