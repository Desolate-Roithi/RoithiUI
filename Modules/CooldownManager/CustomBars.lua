-- Modules/CooldownManager/CustomBars.lua
-- Standalone Custom Bar Engine for CooldownManager (created from scratch)

local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local CDM = RoithiUI:GetModule("CooldownManager")
local LEM = LibStub("LibEditMode-Roithi", true)
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

CDM.customBarFrames = CDM.customBarFrames or {}

function CDM:GetCustomBars()
    if not self.db then
        self.db = RoithiUI and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CooldownManager or self.defaultSettings
    end
    if not self.db then return {} end
    if not self.db.customBars then
        self.db.customBars = {}
    end
    return self.db.customBars
end

function CDM:CreateCustomBar(name)
    local list = self:GetCustomBars()
    local index = #list + 1
    local barId = "custom_" .. tostring(index)

    local barConfig = {
        id = barId,
        name = name or (string.format(L["Custom Bar %d"] or "Custom Bar %d", index)),
        iconSize = 40,
        spacing = 0,
        orientation = "HORIZONTAL",
        growthDirection = "LEFT_TO_RIGHT",
        adaptable = true,
        maxIcons = 8,
        point = "CENTER",
        x = 0,
        y = -100 - (index * 48),
        enabled = true,
        overrideGlobal = false,
        cropIcons = true,
        showTimer = true,
        cooldownFontSize = 14,
        timerAnchor = "CENTER",
        timerOffsetX = 0,
        timerOffsetY = 0,
        showStacks = true,
        stackFontSize = 11,
        stackAnchor = "BOTTOMRIGHT",
        stackOffsetX = -2,
        stackOffsetY = 2,
        spells = {},
    }

    table.insert(list, barConfig)
    self:InitializeCustomBar(index)
    return index
end

function CDM:DeleteCustomBar(index)
    local list = self:GetCustomBars()
    if not list[index] then return end

    local frame = self.customBarFrames[index]
    if frame then
        if frame.Hide then frame:Hide() end
        self.customBarFrames[index] = nil
    end

    table.remove(list, index)
    self:InitializeAllCustomBars()
end

function CDM:GetCursorSpellInfo()
    local cursorType, arg1, arg2, arg3 = _G.GetCursorInfo()
    if not cursorType then return nil end

    if cursorType == "spell" then
        -- In WoW (retail/midnight), return 4 (arg3) is the actual spellID; arg1 is spellbook slot, arg2 is bookType.
        local spellID = arg3
        if not spellID and type(arg1) == "number" then
            if _G.C_SpellBook and _G.C_SpellBook.GetSpellBookItemInfo then
                local bookType = arg2 or (_G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Player)
                local info = _G.C_SpellBook.GetSpellBookItemInfo(arg1, bookType)
                if info and info.spellID then
                    spellID = info.spellID
                end
            end
            if not spellID and _G.GetSpellBookItemInfo then
                local slotID = select(2, _G.GetSpellBookItemInfo(arg1, arg2 or "spell"))
                if slotID then spellID = slotID end
            end
        end
        return spellID or arg1
    elseif cursorType == "petaction" then
        return arg1
    elseif cursorType == "item" then
        return arg1
    elseif cursorType == "macro" then
        if _G.GetMacroSpell then
            local macroSpellID = _G.GetMacroSpell(arg1)
            if macroSpellID then return macroSpellID end
        end
        return nil
    end
    return nil
end

function CDM:ResolveSpellInfo(spellIdentifier)
    if not spellIdentifier then return nil end
    local spellID = tonumber(spellIdentifier)
    local name, icon
    if spellID then
        if _G.C_Spell and _G.C_Spell.GetSpellInfo then
            local info = _G.C_Spell.GetSpellInfo(spellID)
            if info then
                name = info.name
                icon = info.iconID or (_G.C_Spell.GetSpellTexture and _G.C_Spell.GetSpellTexture(spellID))
            end
        elseif _G.GetSpellInfo then
            name = _G.GetSpellInfo(spellID)
            icon = select(3, _G.GetSpellInfo(spellID))
        end
    else
        local str = tostring(spellIdentifier):match("^%s*(.-)%s*$")
        if str and str ~= "" then
            if _G.C_Spell and _G.C_Spell.GetSpellInfo then
                local info = _G.C_Spell.GetSpellInfo(str)
                if info then
                    spellID = info.spellID
                    name = info.name
                    icon = info.iconID or (_G.C_Spell.GetSpellTexture and _G.C_Spell.GetSpellTexture(spellID))
                end
            elseif _G.GetSpellInfo then
                local sName = _G.GetSpellInfo(str)
                local sIcon = select(3, _G.GetSpellInfo(str))
                local sID = select(7, _G.GetSpellInfo(str))
                if sID then
                    spellID = sID
                    name = sName
                    icon = sIcon
                end
            end
        end
    end
    if spellID and not name then
        name = "Spell " .. tostring(spellID)
        icon = 134400
    end

    if spellID and name then
        return {
            spellID = spellID,
            name = name,
            icon = icon or (_G.C_Spell and _G.C_Spell.GetSpellTexture and _G.C_Spell.GetSpellTexture(spellID)) or 134400,
        }
    end
    return nil
end

function CDM:AssignSpellToCustomBar(barIndex, slotIndex, spellIdentifier)
    local list = self:GetCustomBars()
    local cfg = list[barIndex]
    if not cfg then return false end
    cfg.spells = cfg.spells or {}

    local spellData = self:ResolveSpellInfo(spellIdentifier)
    if not spellData then return false end

    if not slotIndex or slotIndex > #cfg.spells + 1 then
        slotIndex = #cfg.spells + 1
    end

    cfg.spells[slotIndex] = spellData
    self:InitializeCustomBar(barIndex)
    if self.RefreshSettingsPanelSpells then
        self:RefreshSettingsPanelSpells()
    end
    return true
end

function CDM:RemoveSpellFromCustomBar(barIndex, slotIndex)
    local list = self:GetCustomBars()
    local cfg = list[barIndex]
    if not cfg or not cfg.spells then return end
    table.remove(cfg.spells, slotIndex)
    self:InitializeCustomBar(barIndex)
    if self.RefreshSettingsPanelSpells then
        self:RefreshSettingsPanelSpells()
    end
end

function CDM:MoveSpellInCustomBar(barIndex, slotIndex, direction)
    local list = self:GetCustomBars()
    local cfg = list[barIndex]
    if not cfg or not cfg.spells then return end
    local targetIndex = slotIndex + direction
    if targetIndex < 1 or targetIndex > (cfg.maxIcons or 8) then return end
    local temp = cfg.spells[slotIndex]
    cfg.spells[slotIndex] = cfg.spells[targetIndex]
    cfg.spells[targetIndex] = temp
    self:InitializeCustomBar(barIndex)
end

function CDM:UpdateCustomBarSlot(barIndex, slotIndex)
    local list = self:GetCustomBars()
    local cfg = list[barIndex]
    if not cfg then return end
    local frame = self.customBarFrames[barIndex]
    if not frame or not frame.icons then return end
    local iconBtn = frame.icons[slotIndex]
    if not iconBtn then return end

    local spellInfo = cfg.spells and cfg.spells[slotIndex]
    if not spellInfo or not spellInfo.spellID then
        iconBtn.spellID = nil
        iconBtn.Icon:SetTexture(nil)
        iconBtn.Icon:SetColorTexture(0.12, 0.12, 0.12, 0.5)
        if iconBtn.Cooldown and iconBtn.Cooldown.Clear then iconBtn.Cooldown:Clear() end
        if iconBtn.ChargeCount and iconBtn.ChargeCount.Current then
            local isEditMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame.IsShown and _G.EditModeManagerFrame:IsShown()
            local isCdmSettings = not isEditMode and (self.customSettingsPanel and self.customSettingsPanel.IsShown and self.customSettingsPanel:IsShown())
            if isCdmSettings then
                iconBtn.ChargeCount.Current:SetText("+")
                if iconBtn.ChargeCount.Current.SetTextColor then
                    iconBtn.ChargeCount.Current:SetTextColor(0, 0.8, 1, 0.8)
                end
            else
                iconBtn.ChargeCount.Current:SetText("")
            end
        end
        iconBtn:Show()
        return
    end

    local spellID = spellInfo.spellID
    iconBtn.spellID = spellID

    local tex = spellInfo.icon or (_G.C_Spell and _G.C_Spell.GetSpellTexture and _G.C_Spell.GetSpellTexture(spellID))
    if tex then
        iconBtn.Icon:SetTexture(tex)
    end

    -- Update Cooldown
    local cd = iconBtn.Cooldown
    local showTimer = (cfg.showTimer ~= false)
    if cd then
        if cd.SetHideCountdownNumbers then
            pcall(cd.SetHideCountdownNumbers, cd, not showTimer)
        end
        local cdFS = cd.GetCountdownFontString and cd:GetCountdownFontString()
        if cdFS then
            if not showTimer then
                if cdFS.Hide then cdFS:Hide() end
            else
                if cdFS.Show then cdFS:Show() end
            end
        end
        if cd.SetCooldown then
            local cdInfo = _G.C_Spell and _G.C_Spell.GetSpellCooldown and _G.C_Spell.GetSpellCooldown(spellID)
            if cdInfo and cdInfo.startTime and cdInfo.duration and cdInfo.duration > 0 and cdInfo.isEnabled then
                cd:SetCooldown(cdInfo.startTime, cdInfo.duration, cdInfo.modRate or 1)
            elseif _G.GetSpellCooldown then
                local start, dur, enable, modRate = _G.GetSpellCooldown(spellID)
                if start and dur and dur > 0 and enable == 1 then
                    cd:SetCooldown(start, dur, modRate or 1)
                elseif cd.Clear then
                    cd:Clear()
                end
            elseif cd.Clear then
                cd:Clear()
            end
        end
    end

    -- Update Charges
    local chargeInfo = _G.C_Spell and _G.C_Spell.GetSpellCharges and _G.C_Spell.GetSpellCharges(spellID)
    local showStacks = (cfg.showStacks ~= false)
    if iconBtn.ChargeCount and iconBtn.ChargeCount.Current then
        local chargeFS = iconBtn.ChargeCount.Current
        if not showStacks then
            chargeFS:SetText("")
            chargeFS:Hide()
        else
            chargeFS:Show()
            if chargeInfo and chargeInfo.maxCharges and chargeInfo.maxCharges > 1 then
                chargeFS:SetText(tostring(chargeInfo.currentCharges or 0))
                if chargeFS.SetTextColor then
                    chargeFS:SetTextColor(1, 1, 1, 1)
                end
            else
                chargeFS:SetText("")
            end
        end
    end

    iconBtn:Show()
end

function CDM:UpdateAllCustomBarCooldowns()
    local list = self:GetCustomBars()
    for barIdx, cfg in ipairs(list) do
        local count = cfg.spells and #cfg.spells or 0
        for slotIdx = 1, count do
            self:UpdateCustomBarSlot(barIdx, slotIdx)
        end
    end
end

function CDM:InitializeCustomBar(index)
    local list = self:GetCustomBars()
    local cfg = list[index]
    if not cfg then return end

    local frame = self.customBarFrames[index]
    if not frame then
        frame = CreateFrame("Frame", "RoithiUI_CDM_CustomBar_" .. index, UIParent, "BackdropTemplate")
        frame:SetClampedToScreen(true)
        if frame.RegisterForDrag then
            frame:RegisterForDrag("LeftButton")
        end
        frame:SetScript("OnReceiveDrag", function()
            local spellID = CDM:GetCursorSpellInfo()
            if spellID then
                local nextSlot = (cfg.spells and #cfg.spells or 0) + 1
                CDM:AssignSpellToCustomBar(index, nextSlot, spellID)
                _G.ClearCursor()
            end
        end)
        self.customBarFrames[index] = frame
    end

    local iconSize = cfg.iconSize or 40
    local spacing = cfg.spacing or 0
    if cfg.showTimer == nil then cfg.showTimer = true end
    if cfg.showStacks == nil then cfg.showStacks = true end
    if not cfg.stackAnchor then cfg.stackAnchor = "BOTTOMRIGHT" end
    if not cfg.timerAnchor then cfg.timerAnchor = "CENTER" end
    if not cfg.growthDirection then
        cfg.growthDirection = (cfg.orientation == "VERTICAL") and "TOP_TO_BOTTOM" or "LEFT_TO_RIGHT"
    end
    if cfg.growthDirection == "DOWN" or cfg.growthDirection == "TOP_TO_BOTTOM" then
        cfg.growthDirection = "TOP_TO_BOTTOM"
        cfg.orientation = "VERTICAL"
    elseif cfg.growthDirection == "UP" or cfg.growthDirection == "BOTTOM_TO_TOP" then
        cfg.growthDirection = "BOTTOM_TO_TOP"
        cfg.orientation = "VERTICAL"
    elseif cfg.growthDirection == "CENTER_VERTICAL" then
        cfg.growthDirection = "CENTER_VERTICAL"
        cfg.orientation = "VERTICAL"
    elseif cfg.growthDirection == "LEFT" or cfg.growthDirection == "RIGHT_TO_LEFT" then
        cfg.growthDirection = "RIGHT_TO_LEFT"
        cfg.orientation = "HORIZONTAL"
    elseif cfg.growthDirection == "CENTER" or cfg.growthDirection == "CENTER_HORIZONTAL" then
        cfg.growthDirection = "CENTER_HORIZONTAL"
        cfg.orientation = "HORIZONTAL"
    else
        cfg.growthDirection = "LEFT_TO_RIGHT"
        cfg.orientation = "HORIZONTAL"
    end

    local isVertical = (cfg.orientation == "VERTICAL")
    local growthDir = cfg.growthDirection
    local isAdaptable = (cfg.adaptable ~= false)
    cfg.spells = cfg.spells or {}
    local numSpells = #cfg.spells

    local isEditMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame.IsShown and _G.EditModeManagerFrame:IsShown()
    local isCdmSettings = not isEditMode and (self.customSettingsPanel and self.customSettingsPanel.IsShown and self.customSettingsPanel:IsShown())

    local numVisible
    if isAdaptable then
        if numSpells == 0 then
            numVisible = (isCdmSettings or isEditMode) and 1 or 0
        else
            numVisible = isCdmSettings and (numSpells + 1) or numSpells
        end
    else
        numVisible = cfg.maxIcons or 8
    end

    if numVisible == 0 then
        frame:Hide()
        return
    end

    local totalW = isVertical and iconSize or (numVisible * iconSize + math.max(0, numVisible - 1) * spacing)
    local totalH = isVertical and (numVisible * iconSize + math.max(0, numVisible - 1) * spacing) or iconSize
    frame:SetSize(math.max(totalW, 20), math.max(totalH, 20))

    frame:ClearAllPoints()
    frame:SetPoint(cfg.point or "CENTER", UIParent, cfg.point or "CENTER", cfg.x or 0, cfg.y or 0)
    frame.editModeName = cfg.name or ("Custom Bar " .. index)

    -- Register with LibEditMode if available
    if LEM and LEM.AddFrame and not frame.lemRegistered then
        local defaults = { point = cfg.point or "CENTER", x = cfg.x or 0, y = cfg.y or 0 }
        LEM:AddFrame(frame, function(f, _, pt, x, y)
            f:ClearAllPoints()
            f:SetPoint(pt, UIParent, pt, x, y)
            cfg.point = pt
            cfg.x = x
            cfg.y = y
        end, defaults)

        if LEM.AddFrameSettings and LEM.SettingType then
            local settings = {
                {
                    name = L["Icon Size"] or "Icon Size",
                    kind = LEM.SettingType.Slider,
                    default = 40,
                    minValue = 20,
                    maxValue = 80,
                    valueStep = 2,
                    get = function() return cfg.iconSize or 40 end,
                    set = function(_, val)
                        cfg.iconSize = val
                        CDM:InitializeCustomBar(index)
                    end,
                    formatter = function(v) return string.format("%.0f", v) end,
                },
                {
                    name = L["Icon Spacing / Padding"] or "Icon Spacing / Padding",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = 0,
                    maxValue = 20,
                    valueStep = 1,
                    get = function() return cfg.spacing or 0 end,
                    set = function(_, val)
                        cfg.spacing = val
                        CDM:InitializeCustomBar(index)
                    end,
                    formatter = function(v) return string.format("%.0f", v) end,
                },
                {
                    name = L["Adaptable Bar (Auto-fit)"] or "Adaptable Bar (Auto-fit)",
                    kind = LEM.SettingType.Checkbox,
                    default = true,
                    get = function() return cfg.adaptable ~= false end,
                    set = function(_, val)
                        cfg.adaptable = val
                        CDM:InitializeCustomBar(index)
                    end,
                },
                {
                    name = L["Orientation"] or "Orientation",
                    kind = LEM.SettingType.Dropdown,
                    default = "HORIZONTAL",
                    values = {
                        { text = L["Horizontal"] or "Horizontal", value = "HORIZONTAL" },
                        { text = L["Vertical"] or "Vertical", value = "VERTICAL" },
                    },
                    get = function() return cfg.orientation or "HORIZONTAL" end,
                    set = function(_, val)
                        cfg.orientation = val
                        if val == "HORIZONTAL" then
                            if cfg.growthDirection == "TOP_TO_BOTTOM" or cfg.growthDirection == "BOTTOM_TO_TOP" then
                                cfg.growthDirection = "LEFT_TO_RIGHT"
                            end
                        else
                            if cfg.growthDirection == "LEFT_TO_RIGHT" or cfg.growthDirection == "RIGHT_TO_LEFT" then
                                cfg.growthDirection = "TOP_TO_BOTTOM"
                            end
                        end
                        CDM:InitializeCustomBar(index)
                    end,
                },
                {
                    name = L["Growth Direction / Alignment"] or "Growth Direction / Alignment",
                    kind = LEM.SettingType.Dropdown,
                    default = "LEFT_TO_RIGHT",
                    values = {
                        { text = L["Left to Right (Grow Right)"] or "Left to Right (Grow Right)", value = "LEFT_TO_RIGHT" },
                        { text = L["Right to Left (Grow Left)"] or "Right to Left (Grow Left)", value = "RIGHT_TO_LEFT" },
                        { text = L["Centered Horizontal"] or "Centered Horizontal", value = "CENTER_HORIZONTAL" },
                        { text = L["Top to Bottom (Grow Down)"] or "Top to Bottom (Grow Down)", value = "TOP_TO_BOTTOM" },
                        { text = L["Bottom to Top (Grow Up)"] or "Bottom to Top (Grow Up)", value = "BOTTOM_TO_TOP" },
                        { text = L["Centered Vertical"] or "Centered Vertical", value = "CENTER_VERTICAL" },
                    },
                    get = function()
                        local g = cfg.growthDirection
                        if g == "DOWN" then return "TOP_TO_BOTTOM" end
                        if g == "UP" then return "BOTTOM_TO_TOP" end
                        if g == "LEFT" then return "RIGHT_TO_LEFT" end
                        if g == "RIGHT" then return "LEFT_TO_RIGHT" end
                        if g == "CENTER" then return "CENTER_HORIZONTAL" end
                        return g or (cfg.orientation == "VERTICAL" and "TOP_TO_BOTTOM" or "LEFT_TO_RIGHT")
                    end,
                    set = function(_, val)
                        cfg.growthDirection = val
                        if val == "TOP_TO_BOTTOM" or val == "BOTTOM_TO_TOP" or val == "CENTER_VERTICAL" then
                            cfg.orientation = "VERTICAL"
                        else
                            cfg.orientation = "HORIZONTAL"
                        end
                        CDM:InitializeCustomBar(index)
                    end,
                },
                {
                    name = L["Override Global Settings"] or "Override Global Settings",
                    kind = LEM.SettingType.Checkbox,
                    default = false,
                    get = function() return cfg.overrideGlobal == true end,
                    set = function(_, val)
                        cfg.overrideGlobal = val
                        CDM:InitializeCustomBar(index)
                    end,
                },
                {
                    name = L["Show Countdown Timer"] or "Show Countdown Timer",
                    kind = LEM.SettingType.Checkbox,
                    default = true,
                    get = function() return cfg.showTimer ~= false end,
                    set = function(_, val)
                        cfg.showTimer = val
                        CDM:InitializeCustomBar(index)
                    end,
                },
                {
                    name = L["Timer Font Size"] or "Timer Font Size",
                    kind = LEM.SettingType.Slider,
                    default = 14,
                    minValue = 8,
                    maxValue = 28,
                    valueStep = 1,
                    get = function() return cfg.cooldownFontSize or 14 end,
                    set = function(_, val)
                        cfg.cooldownFontSize = val
                        CDM:InitializeCustomBar(index)
                    end,
                    formatter = function(v) return string.format("%.0f", v) end,
                },
                {
                    name = L["Timer Position"] or "Timer Position",
                    kind = LEM.SettingType.Dropdown,
                    default = "CENTER",
                    values = (ns.Utils and ns.Utils.GetAnchorLEMValues) and ns.Utils.GetAnchorLEMValues() or {},
                    get = function() return cfg.timerAnchor or "CENTER" end,
                    set = function(_, val)
                        cfg.timerAnchor = val
                        CDM:InitializeCustomBar(index)
                    end,
                },
                {
                    name = L["Show Stacks / Charges"] or "Show Stacks / Charges",
                    kind = LEM.SettingType.Checkbox,
                    default = true,
                    get = function() return cfg.showStacks ~= false end,
                    set = function(_, val)
                        cfg.showStacks = val
                        CDM:InitializeCustomBar(index)
                    end,
                },
                {
                    name = L["Stack Font Size"] or "Stack Font Size",
                    kind = LEM.SettingType.Slider,
                    default = 11,
                    minValue = 8,
                    maxValue = 24,
                    valueStep = 1,
                    get = function() return cfg.stackFontSize or 11 end,
                    set = function(_, val)
                        cfg.stackFontSize = val
                        CDM:InitializeCustomBar(index)
                    end,
                    formatter = function(v) return string.format("%.0f", v) end,
                },
                {
                    name = L["Stack Position"] or "Stack Position",
                    kind = LEM.SettingType.Dropdown,
                    default = "BOTTOMRIGHT",
                    values = (ns.Utils and ns.Utils.GetAnchorLEMValues) and ns.Utils.GetAnchorLEMValues() or {},
                    get = function() return cfg.stackAnchor or "BOTTOMRIGHT" end,
                    set = function(_, val)
                        cfg.stackAnchor = val
                        CDM:InitializeCustomBar(index)
                    end,
                },
            }
            LEM:AddFrameSettings(frame, settings)
        end

        if LEM.AddFrameSettingsButtons then
            LEM:AddFrameSettingsButtons(frame, {
                {
                    text = L["RoithiUI Cooldown Settings"] or "RoithiUI Cooldown Settings",
                    click = function()
                        if RoithiUI and RoithiUI.OpenSettings then
                            RoithiUI:OpenSettings("cooldownmanager")
                        elseif LibStub and LibStub("AceConfigDialog-3.0", true) then
                            local ACD = LibStub("AceConfigDialog-3.0", true)
                            ACD:SelectGroup("RoithiUI", "combat", "cooldownmanager")
                            ACD:Open("RoithiUI")
                        end
                    end,
                },
                {
                    text = L["Blizzard Cooldown Manager"] or "Blizzard Cooldown Manager",
                    click = function()
                        CDM:OpenBlizzardSettings(false)
                    end,
                },
            })
        end
        frame.lemRegistered = true
    end

    -- Pool of icon frames inside this bar
    frame.icons = frame.icons or {}
    for i = 1, numVisible do
        local iconBtn = frame.icons[i]
        if not iconBtn then
            iconBtn = CreateFrame("Button", "$parent_Icon" .. i, frame)
            iconBtn.Icon = iconBtn:CreateTexture(nil, "BACKGROUND")
            iconBtn.Icon:SetAllPoints(iconBtn)
            iconBtn.Cooldown = CreateFrame("Cooldown", "$parent_Cooldown", iconBtn, "CooldownFrameTemplate")
            iconBtn.Cooldown:SetAllPoints(iconBtn)

            local chargeFrame = CreateFrame("Frame", nil, iconBtn)
            chargeFrame:SetAllPoints(iconBtn)
            if iconBtn.GetFrameStrata and chargeFrame.SetFrameStrata then
                chargeFrame:SetFrameStrata(iconBtn:GetFrameStrata())
            end
            if iconBtn.GetFrameLevel then
                chargeFrame:SetFrameLevel(iconBtn:GetFrameLevel() + 25)
            end
            if chargeFrame.EnableMouse then chargeFrame:EnableMouse(false) end
            local chargeText = chargeFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            if chargeText.SetDrawLayer then
                chargeText:SetDrawLayer("OVERLAY", 7)
            end
            chargeText:SetPoint("BOTTOMRIGHT", chargeFrame, "BOTTOMRIGHT", -2, 2)
            chargeFrame.Current = chargeText
            iconBtn.ChargeCount = chargeFrame

            if iconBtn.RegisterForDrag then
                iconBtn:RegisterForDrag("LeftButton")
            end
            if iconBtn.RegisterForClicks then
                iconBtn:RegisterForClicks("AnyUp")
            end

            iconBtn:SetScript("OnReceiveDrag", function(selfBtn)
                local spellID = CDM:GetCursorSpellInfo()
                if spellID then
                    CDM:AssignSpellToCustomBar(index, selfBtn.slotIndex, spellID)
                    _G.ClearCursor()
                end
            end)

            iconBtn:SetScript("OnClick", function(selfBtn, button)
                local spellID = CDM:GetCursorSpellInfo()
                if spellID then
                    CDM:AssignSpellToCustomBar(index, selfBtn.slotIndex, spellID)
                    _G.ClearCursor()
                elseif button == "RightButton" and _G.IsShiftKeyDown() then
                    CDM:RemoveSpellFromCustomBar(index, selfBtn.slotIndex)
                end
            end)

            iconBtn:SetScript("OnEnter", function(selfBtn)
                if selfBtn.spellID and _G.GameTooltip then
                    _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    if _G.GameTooltip.SetSpellByID then
                        _G.GameTooltip:SetSpellByID(selfBtn.spellID)
                    end
                    _G.GameTooltip:Show()
                elseif _G.GameTooltip then
                    _G.GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    _G.GameTooltip:SetText(L["(Drop spell here)"] or "(Drop spell here)")
                    _G.GameTooltip:Show()
                end
            end)

            iconBtn:SetScript("OnLeave", function()
                if _G.GameTooltip then _G.GameTooltip:Hide() end
            end)

            frame.icons[i] = iconBtn
        end

        iconBtn.barIndex = index
        iconBtn.slotIndex = i
        iconBtn:SetSize(iconSize, iconSize)
        iconBtn:ClearAllPoints()
        local offset = (i - 1) * (iconSize + spacing)
        if growthDir == "CENTER_HORIZONTAL" or growthDir == "CENTER" then
            local startX = -((numVisible - 1) * (iconSize + spacing)) / 2
            local xOffset = startX + (i - 1) * (iconSize + spacing)
            iconBtn:SetPoint("CENTER", frame, "CENTER", xOffset, 0)
        elseif growthDir == "CENTER_VERTICAL" then
            local startY = ((numVisible - 1) * (iconSize + spacing)) / 2
            local yOffset = startY - (i - 1) * (iconSize + spacing)
            iconBtn:SetPoint("CENTER", frame, "CENTER", 0, yOffset)
        elseif growthDir == "RIGHT_TO_LEFT" then
            iconBtn:SetPoint("RIGHT", frame, "RIGHT", -offset, 0)
        elseif growthDir == "BOTTOM_TO_TOP" then
            iconBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, offset)
        elseif growthDir == "TOP_TO_BOTTOM" then
            iconBtn:SetPoint("TOP", frame, "TOP", 0, -offset)
        else -- LEFT_TO_RIGHT
            iconBtn:SetPoint("LEFT", frame, "LEFT", offset, 0)
        end

        if iconBtn.ChargeCount and iconBtn.ChargeCount.Current then
            local chargeFS = iconBtn.ChargeCount.Current
            local isOverridden = (cfg.overrideGlobal == true)
            local anchor = isOverridden and (cfg.stackAnchor or "BOTTOMRIGHT") or (CDM.db and CDM.db.stackAnchor or "BOTTOMRIGHT")
            chargeFS:ClearAllPoints()
            local defOx, defOy, defJustifyH = (ns.Utils and ns.Utils.GetDefaultAnchorOffsets) and ns.Utils.GetDefaultAnchorOffsets(anchor, 2) or (anchor:find("RIGHT") and -2 or (anchor:find("LEFT") and 2 or 0)), (anchor:find("TOP") and -2 or (anchor:find("BOTTOM") and 2 or 0)), "CENTER"
            local ox = isOverridden and (cfg.stackOffsetX or defOx) or (CDM.db and CDM.db.stackOffsetX or defOx)
            local oy = isOverridden and (cfg.stackOffsetY or defOy) or (CDM.db and CDM.db.stackOffsetY or defOy)
            if chargeFS.SetJustifyH then
                chargeFS:SetJustifyH(defJustifyH)
            end
            chargeFS:SetPoint(anchor, iconBtn, anchor, ox, oy)
        end

        self:UpdateCustomBarSlot(index, i)

        if self.StyleItemFrame then
            self:StyleItemFrame("CustomBar" .. index, iconBtn)
        end
    end

    for i = numVisible + 1, #frame.icons do
        frame.icons[i]:Hide()
    end

    if cfg.enabled ~= false then
        frame:Show()
    else
        frame:Hide()
    end
end

function CDM:InitializeAllCustomBars()
    local list = self:GetCustomBars()
    for i = 1, #list do
        self:InitializeCustomBar(i)
    end
    for i = #list + 1, #self.customBarFrames do
        if self.customBarFrames[i] then
            self.customBarFrames[i]:Hide()
            self.customBarFrames[i] = nil
        end
    end
end

-- Event listener for live custom cooldown updates
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if CDM and CDM.InitializeAllCustomBars then
            CDM:InitializeAllCustomBars()
        end
    end
    if CDM and CDM.UpdateAllCustomBarCooldowns then
        CDM:UpdateAllCustomBarCooldowns()
    end
end)

if LEM and LEM.RegisterCallback and not CDM.roithiCustomBarsLEMHooked then
    LEM:RegisterCallback("enter", function()
        if CDM.InitializeAllCustomBars then CDM:InitializeAllCustomBars() end
    end)
    LEM:RegisterCallback("exit", function()
        if CDM.InitializeAllCustomBars then CDM:InitializeAllCustomBars() end
    end)
    CDM.roithiCustomBarsLEMHooked = true
end
