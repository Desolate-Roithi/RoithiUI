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

local BLIZZARD_BAR_FRAMES = {
    bar1 = { "MainActionBar", "MainMenuBar" },
    bar2 = { "MultiBarBottomLeft" },
    bar3 = { "MultiBarBottomRight" },
    bar4 = { "MultiBarRight" },
    bar5 = { "MultiBarLeft" },
    pet = { "PetActionBar", "PetActionBarFrame" },
    stance = { "StanceBar", "StanceBarFrame", "ShapeshiftBarFrame" },
}

local function ButtonHasAction(btn)
    if not btn then return false end
    if btn.HasAction then
        return btn:HasAction() == true
    end
    local action = btn.action or (btn.GetPagedID and btn:GetPagedID()) or (btn.CalculateAction and btn:CalculateAction())
    if action then
        if _G.C_ActionBar and _G.C_ActionBar.HasAction then
            return _G.C_ActionBar.HasAction(action)
        elseif _G.HasAction then
            return _G.HasAction(action)
        end
    end
    local name = btn.GetName and btn:GetName() or ""
    if btn.GetPetActionInfo or name:find("PetAction") then
        local id = btn.GetID and btn:GetID()
        if id and _G.GetPetActionInfo then
            local _, _, texture = _G.GetPetActionInfo(id)
            return texture ~= nil
        end
    end
    if name:find("Stance") or name:find("Shapeshift") then
        local id = btn.GetID and btn:GetID()
        if id and _G.GetShapeshiftFormInfo then
            local texture = _G.GetShapeshiftFormInfo(id)
            return texture ~= nil
        end
    end
    return false
end

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

function AB:IsBarMouseOver(barKey)
    local container = self.bars[barKey]
    if not container then return false end
    if container.IsMouseOver and container:IsMouseOver() then return true end
    local buttons = self:GetBarButtons(barKey)
    for _, btn in ipairs(buttons) do
        if btn.IsMouseOver and btn:IsMouseOver() then return true end
    end
    return false
end

function AB:UpdateBarMouseover(barKey)
    local container = self.bars[barKey]
    if not container then return end
    local db = self.db[barKey] or {}
    if db.enabled == false then
        if container.Hide then container:Hide() end
        return
    end

    local alpha = (db.mouseover and not self:IsBarMouseOver(barKey)) and (db.mouseoverAlpha or 0.0) or (db.alpha or 1.0)
    if container.SetAlpha then
        container:SetAlpha(alpha)
    end
end

function AB:OnBarEnter(barKey)
    local db = self.db[barKey] or {}
    if db.mouseover then
        local container = self.bars[barKey]
        if container and container.SetAlpha then
            container:SetAlpha(db.alpha or 1.0)
        end
    end
end

function AB:OnBarLeave(barKey)
    local db = self.db[barKey] or {}
    if db.mouseover and _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.05, function()
            if not self:IsBarMouseOver(barKey) then
                local container = self.bars[barKey]
                if container and container.SetAlpha then
                    container:SetAlpha(db.mouseoverAlpha or 0.0)
                end
            end
        end)
    end
end

function AB:UpdateEmptyButtons(barKey)
    local db = self.db[barKey] or {}
    if db.enabled == false then return end

    local buttons = self:GetBarButtons(barKey)
    local hideEmpty = db.hideEmpty == true and not self.showingGrid

    for _, btn in ipairs(buttons) do
        if hideEmpty then
            local hasAct = ButtonHasAction(btn)
            if hasAct then
                if btn.SetAlpha then btn:SetAlpha(1) end
                if btn.roithiBackdrop and btn.roithiBackdrop.Show then btn.roithiBackdrop:Show() end
            else
                if btn.SetAlpha then btn:SetAlpha(0) end
                if btn.roithiBackdrop and btn.roithiBackdrop.Hide then btn.roithiBackdrop:Hide() end
            end
        else
            if btn.SetAlpha then btn:SetAlpha(1) end
            if btn.roithiBackdrop and btn.roithiBackdrop.Show then btn.roithiBackdrop:Show() end
        end
    end
end

function AB:UpdateAllEmptyButtons()
    for barKey in pairs(BAR_CONFIGS) do
        self:UpdateEmptyButtons(barKey)
    end
end

local hiddenParent
local function GetHiddenParent()
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame", "RoithiUI_HiddenActionBars", UIParent)
        hiddenParent:Hide()
    end
    return hiddenParent
end

function AB:SetupBars()
    for barKey, cfg in pairs(BAR_CONFIGS) do
        if not self.bars[barKey] then
            local f = CreateFrame("Frame", cfg.name, UIParent)
            if f.SetClampedToScreen then f:SetClampedToScreen(true) end
            if f.SetMovable then f:SetMovable(true) end
            if f.EnableMouse then f:EnableMouse(true) end
            f.barKey = barKey
            if f.SetScript then
                f:SetScript("OnEnter", function() self:OnBarEnter(barKey) end)
                f:SetScript("OnLeave", function() self:OnBarLeave(barKey) end)
            end
            self.bars[barKey] = f

            local db = self.db[barKey] or {}
            local pt = db.point or "BOTTOM"
            if f.ClearAllPoints then f:ClearAllPoints() end
            if f.SetPoint then f:SetPoint(pt, UIParent, pt, db.x or 0, db.y or 0) end
        end

        local db = self.db[barKey] or {}
        if db.enabled ~= false and self.bars[barKey].Show then
            self.bars[barKey]:Show()
        end
    end

    -- Hide Blizzard Art Frames in Classic/Forever
    if _G.MainMenuBarArtFrame and _G.MainMenuBarArtFrame.Hide then
        _G.MainMenuBarArtFrame:Hide()
    end
end

function AB:StyleButton(button)
    if not button then return end

    -- 1. Icon TexCoords (Zoomed to create modern square look)
    local zoom = self.db.iconZoom or 0.07
    local zoomMax = tonumber(string.format("%.4f", 1 - zoom)) or (1 - zoom)
    local icon = button.icon or _G[button.GetName and button:GetName() and (button:GetName() .. "Icon") or ""]
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(zoom, zoomMax, zoom, zoomMax)
    end

    -- 2. Hide Blizzard Borders
    local border = button.Border or _G[button.GetName and button:GetName() and (button:GetName() .. "Border") or ""]
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
        if button.roithiBackdrop.Show then button.roithiBackdrop:Show() end
        local bc = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
        if button.roithiBackdrop.SetBackdropBorderColor then
            button.roithiBackdrop:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        end
    end

    -- 4. Keybind Hotkey Styling
    local hotkey = button.HotKey or _G[button.GetName and button:GetName() and (button:GetName() .. "HotKey") or ""]
    if hotkey then
        if hotkey.SetShown then
            hotkey:SetShown(self.db.showHotkeys ~= false)
        end
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(hotkey, self.db.font or "Friz Quadrata TT", self.db.fontSize or 11, "OUTLINE")
        end
    end

    -- 5. Macro Text Styling
    local name = button.Name or _G[button.GetName and button:GetName() and (button:GetName() .. "Name") or ""]
    if name then
        if name.SetShown then
            name:SetShown(self.db.showMacroText ~= false)
        end
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(name, self.db.font or "Friz Quadrata TT", math.max(8, (self.db.fontSize or 11) - 2), "OUTLINE")
        end
    end

    -- 6. Item / Charge Count Styling
    local count = button.Count or _G[button.GetName and button:GetName() and (button:GetName() .. "Count") or ""]
    if count then
        if count.SetShown then
            count:SetShown(self.db.showCount ~= false)
        end
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(count, self.db.font or "Friz Quadrata TT", math.max(8, (self.db.fontSize or 11) - 1), "OUTLINE")
        end
    end

    -- 7. Hook Mouseover
    if not button.roithiMouseoverHooked and button.HookScript then
        button:HookScript("OnEnter", function()
            if button.barKey then
                self:OnBarEnter(button.barKey)
            end
        end)
        button:HookScript("OnLeave", function()
            if button.barKey then
                self:OnBarLeave(button.barKey)
            end
        end)
        button.roithiMouseoverHooked = true
    end
end

function AB:UnstyleButton(button)
    if not button then return end

    local icon = button.icon or _G[button.GetName and button:GetName() and (button:GetName() .. "Icon") or ""]
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0, 1, 0, 1)
    end

    local border = button.Border or _G[button.GetName and button:GetName() and (button:GetName() .. "Border") or ""]
    if border and border.SetAlpha then
        border:SetAlpha(1)
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal and normal.SetAlpha then
        normal:SetAlpha(1)
    end

    if button.roithiBackdrop and button.roithiBackdrop.Hide then
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
    local buttons = self:GetBarButtons(barKey)
    local blizzFrames = BLIZZARD_BAR_FRAMES[barKey]

    if not db or db.enabled == false then
        if container.Hide then container:Hide() end
        for _, btn in ipairs(buttons) do
            if btn.Hide then btn:Hide() end
            if btn.SetAlpha then btn:SetAlpha(0) end
        end
        if blizzFrames then
            for _, fname in ipairs(blizzFrames) do
                local bf = _G[fname]
                if bf then
                    if bf.Hide then bf:Hide() end
                    if bf.SetAlpha then bf:SetAlpha(0) end
                    if bf.Selection and bf.Selection.Hide then bf.Selection:Hide() end
                end
            end
        end
        local LEM = LibStub("LibEditMode-Roithi", true)
        if LEM and LEM.frameSelections and LEM.frameSelections[container] then
            local sel = LEM.frameSelections[container]
            if sel and sel.Hide then sel:Hide() end
        end
        return
    end

    if container.Show then container:Show() end

    -- Hide Blizzard native frames for this bar to prevent duplicate displays & Edit Mode outlines
    if blizzFrames then
        for _, fname in ipairs(blizzFrames) do
            local bf = _G[fname]
            if bf then
                if not bf.roithiOriginalParent and bf.GetParent then
                    bf.roithiOriginalParent = bf:GetParent()
                end
                if fname ~= "MainActionBar" and fname ~= "MainMenuBar" then
                    local hp = GetHiddenParent()
                    if bf.SetParent and hp then
                        bf:SetParent(hp)
                    end
                end
                if bf.SetAlpha then bf:SetAlpha(0) end
                if bf.Hide then bf:Hide() end
                if bf.Selection and bf.Selection.Hide then bf.Selection:Hide() end
            end
        end
    end

    if #buttons == 0 then return end

    local btnSize = db.buttonSize or 36
    local spacing = db.spacing or 4
    local perRow = db.buttonsPerRow or #buttons
    if perRow < 1 then perRow = 1 end

    local numCols = math.min(#buttons, perRow)
    local numRows = math.ceil(#buttons / perRow)

    local totalW = (numCols * btnSize) + math.max(0, (numCols - 1) * spacing)
    local totalH = (numRows * btnSize) + math.max(0, (numRows - 1) * spacing)
    if container.SetSize then container:SetSize(totalW, totalH) end

    for i, btn in ipairs(buttons) do
        btn.barKey = barKey
        if not btn.originalParent and btn.GetParent then
            btn.originalParent = btn:GetParent()
        end
        if not btn.roithiOriginalPoints and btn.GetNumPoints then
            btn.roithiOriginalPoints = {}
            for p = 1, btn:GetNumPoints() do
                local pt, relTo, relPt, x, y = btn:GetPoint(p)
                table.insert(btn.roithiOriginalPoints, { point = pt, relTo = relTo, relPt = relPt, x = x, y = y })
            end
            if btn.GetSize then
                local w, h = btn:GetSize()
                btn.roithiOriginalWidth = w
                btn.roithiOriginalHeight = h
            end
        end
        if btn.SetParent then
            btn:SetParent(container)
        end
        if btn.SetAlpha then btn:SetAlpha(1) end
        if btn.Show then btn:Show() end
        if btn.ClearAllPoints then btn:ClearAllPoints() end
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local x = col * (btnSize + spacing)
        local y = -row * (btnSize + spacing)

        if btn.SetSize then btn:SetSize(btnSize, btnSize) end
        if btn.SetPoint then btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y) end
    end

    self:UpdateBarMouseover(barKey)
    self:UpdateEmptyButtons(barKey)
end

function AB:LayoutAllBars()
    for barKey in pairs(BAR_CONFIGS) do
        self:LayoutBar(barKey)
    end
end

function AB:RestoreBlizzardBars()
    for barKey, container in pairs(self.bars) do
        if container.Hide then container:Hide() end
        local buttons = self:GetBarButtons(barKey)
        for _, btn in ipairs(buttons) do
            if btn.originalParent and btn.SetParent then
                btn:SetParent(btn.originalParent)
            end
            if btn.roithiOriginalPoints and #btn.roithiOriginalPoints > 0 then
                if btn.ClearAllPoints then btn:ClearAllPoints() end
                for _, pt in ipairs(btn.roithiOriginalPoints) do
                    if btn.SetPoint then
                        btn:SetPoint(pt.point, pt.relTo, pt.relPt, pt.x, pt.y)
                    end
                end
            end
            if btn.roithiOriginalWidth and btn.roithiOriginalHeight and btn.SetSize then
                btn:SetSize(btn.roithiOriginalWidth, btn.roithiOriginalHeight)
            end
            if btn.SetAlpha then btn:SetAlpha(1) end
            if btn.Show then btn:Show() end
        end

        local blizzFrames = BLIZZARD_BAR_FRAMES[barKey]
        if blizzFrames then
            for _, fname in ipairs(blizzFrames) do
                local bf = _G[fname]
                if bf then
                    if bf.roithiOriginalParent and bf.SetParent then
                        bf:SetParent(bf.roithiOriginalParent)
                    elseif fname ~= "MainActionBar" and fname ~= "MainMenuBar" and bf.SetParent then
                        bf:SetParent(UIParent)
                    end
                    if bf.SetAlpha then bf:SetAlpha(1) end
                    if bf.Show then bf:Show() end
                    if bf.Selection and bf.Selection.Show then bf.Selection:Show() end
                    if bf.UpdateGridLayout then
                        pcall(bf.UpdateGridLayout, bf)
                    end
                end
            end
        end
    end

    if _G.EditModeManagerFrame and _G.EditModeManagerFrame.UpdateActionBarLayout then
        for _, blizzFrames in pairs(BLIZZARD_BAR_FRAMES) do
            for _, fname in ipairs(blizzFrames) do
                local bf = _G[fname]
                if bf then
                    pcall(_G.EditModeManagerFrame.UpdateActionBarLayout, _G.EditModeManagerFrame, bf)
                end
            end
        end
    end

    if _G.MultiActionBar_Update then
        pcall(_G.MultiActionBar_Update)
    end
    if _G.UIParent_ManageFramePositions then
        pcall(_G.UIParent_ManageFramePositions)
    end

    if _G.MainMenuBarArtFrame and _G.MainMenuBarArtFrame.Show then
        _G.MainMenuBarArtFrame:Show()
    end
end
