-- Modules/CooldownManager/CustomBars.lua
-- Standalone Custom Bar Engine for CooldownManager (created from scratch)

local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local CDM = RoithiUI:GetModule("CooldownManager")
local LEM = LibStub("LibEditMode-Roithi", true)
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

CDM.customBarFrames = CDM.customBarFrames or {}

local function SafeIsGreaterThan(val, threshold)
    if val == nil then return false end
    if _G.issecretvalue and _G.issecretvalue(val) then return false end
    if _G.canaccessvalue and not _G.canaccessvalue(val) then return false end
    if _G.C_Secrets and _G.C_Secrets.IsSecret and _G.C_Secrets.IsSecret(val) then return false end
    local ok, res = pcall(function() return val > threshold end)
    return ok and res == true
end

local function SafeIsGreaterThanZero(val)
    return SafeIsGreaterThan(val, 0)
end

local function SafeEquals(val, expected)
    if val == nil then return false end
    if _G.issecretvalue and _G.issecretvalue(val) then return false end
    if _G.canaccessvalue and not _G.canaccessvalue(val) then return false end
    if _G.C_Secrets and _G.C_Secrets.IsSecret and _G.C_Secrets.IsSecret(val) then return false end
    local ok, res = pcall(function() return val == expected end)
    return ok and res == true
end

local function SafeDurationIsZero(durObj)
    if not durObj then return true end
    if _G.issecretvalue and _G.issecretvalue(durObj) then return false end
    if _G.canaccessvalue and not _G.canaccessvalue(durObj) then return false end
    if _G.C_Secrets and _G.C_Secrets.IsSecret and _G.C_Secrets.IsSecret(durObj) then return false end
    if durObj.IsZero then
        local ok, isZero = pcall(durObj.IsZero, durObj)
        if ok and isZero ~= nil then
            if _G.issecretvalue and _G.issecretvalue(isZero) then return false end
            if _G.canaccessvalue and not _G.canaccessvalue(isZero) then return false end
            if _G.C_Secrets and _G.C_Secrets.IsSecret and _G.C_Secrets.IsSecret(isZero) then return false end
            local cmpOk, res = pcall(function() return isZero == true end)
            if cmpOk and res ~= nil then
                return res == true
            end
            return false
        end
    end
    if durObj.GetRemainingDuration then
        local ok, rem = pcall(durObj.GetRemainingDuration, durObj)
        if ok and rem ~= nil then
            if _G.issecretvalue and _G.issecretvalue(rem) then return false end
            if _G.canaccessvalue and not _G.canaccessvalue(rem) then return false end
            if _G.C_Secrets and _G.C_Secrets.IsSecret and _G.C_Secrets.IsSecret(rem) then return false end
            return not SafeIsGreaterThanZero(rem)
        end
    end
    return false
end

local function SafeDurationIsActive(durObj)
    if not durObj then return false end
    if _G.issecretvalue and _G.issecretvalue(durObj) then return false end
    if _G.canaccessvalue and not _G.canaccessvalue(durObj) then return false end
    if _G.C_Secrets and _G.C_Secrets.IsSecret and _G.C_Secrets.IsSecret(durObj) then return false end
    if durObj.IsZero then
        local ok, isZero = pcall(durObj.IsZero, durObj)
        if ok and isZero ~= nil then
            if _G.issecretvalue and _G.issecretvalue(isZero) then return false end
            if _G.canaccessvalue and not _G.canaccessvalue(isZero) then return false end
            if _G.C_Secrets and _G.C_Secrets.IsSecret and _G.C_Secrets.IsSecret(isZero) then return false end
            local cmpOk, res = pcall(function() return isZero == false end)
            if cmpOk and res == true then
                return true
            end
            if isZero == true then
                return false
            end
        end
    end
    if durObj.GetRemainingDuration then
        local ok, rem = pcall(durObj.GetRemainingDuration, durObj)
        if ok and rem ~= nil then
            if _G.issecretvalue and _G.issecretvalue(rem) then return false end
            if _G.canaccessvalue and not _G.canaccessvalue(rem) then return false end
            if _G.C_Secrets and _G.C_Secrets.IsSecret and _G.C_Secrets.IsSecret(rem) then return false end
            return SafeIsGreaterThan(rem, 0.1)
        end
    end
    return false
end


local function SetIconVisualState(icon, isOnCD)
    if not icon then return end
    local isCD = (isOnCD == true)
    if icon.SetDesaturated then
        pcall(icon.SetDesaturated, icon, isCD)
    end
    if icon.SetVertexColor then
        local v = isCD and 0.55 or 1.0
        pcall(icon.SetVertexColor, icon, v, v, v)
    end
end

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
        buttonsPerRow = 8,
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
        return { itemID = arg1, isItem = true }
    elseif cursorType == "macro" then
        if _G.GetMacroSpell then
            local macroSpellID = _G.GetMacroSpell(arg1)
            if macroSpellID then return macroSpellID end
        end
        if _G.GetMacroItem then
            local macroItemID = _G.GetMacroItem(arg1)
            if macroItemID then return { itemID = macroItemID, isItem = true } end
        end
        return nil
    end
    return nil
end

function CDM:ResolveSpellInfo(spellIdentifier)
    if not spellIdentifier then return nil end

    if type(spellIdentifier) == "table" and spellIdentifier.isItem then
        local itemID = tonumber(spellIdentifier.itemID)
        if itemID then
            local itemInfo = { (_G.C_Item and _G.C_Item.GetItemInfo and _G.C_Item.GetItemInfo(itemID)) or (_G.GetItemInfo and _G.GetItemInfo(itemID)) }
            local iName = itemInfo[1]
            local iIcon = itemInfo[10]
            if not iName then
                iName = "Item " .. tostring(itemID)
                iIcon = iIcon or (_G.C_Item and _G.C_Item.GetItemIconByID and _G.C_Item.GetItemIconByID(itemID)) or 134400
            end
            return {
                itemID = itemID,
                isItem = true,
                name = iName,
                icon = iIcon or (_G.C_Item and _G.C_Item.GetItemIconByID and _G.C_Item.GetItemIconByID(itemID)) or 134400,
            }
        end
        return nil
    end

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

function CDM:IsCustomBarItemAccessible(entry)
    if not entry then return false end

    -- Item branch
    if entry.isItem or (entry.itemID and not entry.spellID) then
        local itemID = tonumber(entry.itemID)
        if not itemID then return false end

        -- Check if it is equippable gear or trinket
        local equipSlot = nil
        if _G.C_Item and _G.C_Item.GetItemInventoryTypeByID then
            local ok, slot = pcall(_G.C_Item.GetItemInventoryTypeByID, itemID)
            if ok and slot then equipSlot = slot end
        end
        if not equipSlot and _G.GetItemInfoInstant then
            local ok, _, _, slot = pcall(_G.GetItemInfoInstant, itemID)
            if ok and slot then equipSlot = slot end
        end

        local isEquippable = false
        if equipSlot and equipSlot ~= "" and equipSlot ~= "INVTYPE_NON_EQUIP_IGNORE" and equipSlot ~= 0 then
            isEquippable = true
        end

        if isEquippable then
            -- Trinkets and equipment: MUST be currently equipped!
            if _G.C_Item and _G.C_Item.IsEquippedItem then
                local ok, isEq = pcall(_G.C_Item.IsEquippedItem, itemID)
                return ok and isEq == true
            elseif _G.IsEquippedItem then
                local ok, isEq = pcall(_G.IsEquippedItem, itemID)
                return ok and isEq == true
            end
            return false
        else
            -- Potions and consumables: MUST be in bags (item count > 0)
            local count = 0
            if _G.C_Item and _G.C_Item.GetItemCount then
                local ok, c = pcall(_G.C_Item.GetItemCount, itemID)
                if ok and type(c) == "number" then count = c end
            elseif _G.GetItemCount then
                local ok, c = pcall(_G.GetItemCount, itemID)
                if ok and type(c) == "number" then count = c end
            end
            return count > 0
        end
    end

    -- Spell branch
    local spellID = tonumber(entry.spellID)
    if spellID then
        if _G.IsSpellKnownOrOverridesKnown then
            local ok, known = pcall(_G.IsSpellKnownOrOverridesKnown, spellID)
            if ok and known == true then return true end
        end
        if _G.C_Spell and _G.C_Spell.IsSpellKnown then
            local ok, known = pcall(_G.C_Spell.IsSpellKnown, spellID)
            if ok and known == true then return true end
        end
        if _G.IsPlayerSpell then
            local ok, known = pcall(_G.IsPlayerSpell, spellID)
            if ok and known == true then return true end
        end
        if _G.IsSpellKnown then
            local ok, known = pcall(_G.IsSpellKnown, spellID)
            if ok and known == true then return true end
        end
        return false
    end

    return false
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

    local origIdx = (iconBtn and iconBtn.originalSlotIndex) or (frame and frame.activeOrigIndices and frame.activeOrigIndices[slotIndex]) or slotIndex
    local spellInfo = cfg.spells and cfg.spells[origIdx]
    if not spellInfo or (not spellInfo.spellID and not spellInfo.itemID) then
        iconBtn.spellID = nil
        iconBtn.itemID = nil
        iconBtn.Icon:SetTexture(nil)
        iconBtn.Icon:SetColorTexture(0.12, 0.12, 0.12, 0.5)
        SetIconVisualState(iconBtn.Icon, false)
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

    if spellInfo.isItem or (spellInfo.itemID and not spellInfo.spellID) then
        local itemID = spellInfo.itemID
        iconBtn.itemID = itemID
        iconBtn.spellID = nil

        local tex = spellInfo.icon or (_G.C_Item and _G.C_Item.GetItemIconByID and _G.C_Item.GetItemIconByID(itemID)) or 134400
        if tex then
            iconBtn.Icon:SetTexture(tex)
        end

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
            local isOnCD = false
            if cd.SetCooldown then
                local start, dur, enable = 0, 0, 0
                if _G.C_Container and _G.C_Container.GetItemCooldown then
                    start, dur, enable = _G.C_Container.GetItemCooldown(itemID)
                elseif _G.C_Item and _G.C_Item.GetItemCooldown then
                    start, dur, enable = _G.C_Item.GetItemCooldown(itemID)
                elseif _G.GetItemCooldown then
                    start, dur, enable = _G.GetItemCooldown(itemID)
                end
                local isEnabled = (enable == true or SafeEquals(enable, 1))
                if isEnabled and SafeIsGreaterThanZero(dur) then
                    pcall(cd.SetCooldown, cd, start, dur)
                    if SafeIsGreaterThan(dur, 1.5) then
                        local now = (_G.GetTime and _G.GetTime()) or 0
                        local finish = (start or 0) + dur
                        if SafeIsGreaterThan(finish - now, 0.1) then
                            isOnCD = true
                        end
                    end
                elseif cd.Clear then
                    cd:Clear()
                elseif cd.SetCooldown then
                    pcall(cd.SetCooldown, cd, 0, 0)
                end
            end
            SetIconVisualState(iconBtn.Icon, isOnCD)
        end

        local showStacks = (cfg.showStacks ~= false)
        if iconBtn.ChargeCount and iconBtn.ChargeCount.Current then
            local chargeFS = iconBtn.ChargeCount.Current
            if not showStacks then
                chargeFS:SetText("")
                chargeFS:Hide()
            else
                local itemCount = 0
                if _G.C_Item and _G.C_Item.GetItemCount then
                    itemCount = _G.C_Item.GetItemCount(itemID) or 0
                elseif _G.GetItemCount then
                    itemCount = _G.GetItemCount(itemID) or 0
                end
                if itemCount and SafeIsGreaterThan(itemCount, 1) then
                    chargeFS:SetText(tostring(itemCount))
                    chargeFS:Show()
                    if chargeFS.SetTextColor then
                        chargeFS:SetTextColor(1, 1, 1, 1)
                    end
                else
                    chargeFS:SetText("")
                end
            end
        end

        iconBtn:Show()
        return
    end

    local spellID = spellInfo.spellID
    iconBtn.spellID = spellID
    iconBtn.itemID = nil

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

        local cdApplied = false
        local isOnCD = false
        local durObj = nil

        local cdInfo = _G.C_Spell and _G.C_Spell.GetSpellCooldown and _G.C_Spell.GetSpellCooldown(spellID)
        if cdInfo and cdInfo.isActive ~= nil then
            local okActive, isActive = pcall(function() return cdInfo.isActive == true end)
            local okGCD, isOnGCD = pcall(function() return cdInfo.isOnGCD == true end)
            if okActive and isActive then
                if not (okGCD and isOnGCD) then
                    isOnCD = true
                end
            end
        end

        if cd.SetCooldownFromDurationObject and _G.C_Spell and _G.C_Spell.GetSpellCooldownDuration then
            durObj = _G.C_Spell.GetSpellCooldownDuration(spellID, true)
            if durObj then
                local ok = pcall(cd.SetCooldownFromDurationObject, cd, durObj)
                if ok then
                    cdApplied = true
                    if not isOnCD and (cdInfo == nil or cdInfo.isActive == nil) and SafeDurationIsActive(durObj) then
                        isOnCD = true
                    end
                end
            end
        end

        if not cdApplied and cd.SetCooldown then
            if cdInfo and cdInfo.startTime and cdInfo.duration and cdInfo.isEnabled then
                local isEnabled = cdInfo.isEnabled == true or SafeEquals(cdInfo.isEnabled, 1)
                if isEnabled then
                    pcall(cd.SetCooldown, cd, cdInfo.startTime, cdInfo.duration, cdInfo.modRate or 1)
                    cdApplied = true
                    if not isOnCD and SafeIsGreaterThan(cdInfo.duration, 1.5) then
                        local now = (_G.GetTime and _G.GetTime()) or 0
                        local finish = cdInfo.startTime + cdInfo.duration
                        if SafeIsGreaterThan(finish - now, 0.1) then
                            isOnCD = true
                        end
                    end
                end
            elseif _G.GetSpellCooldown then
                local start, dur, enable, modRate = _G.GetSpellCooldown(spellID)
                local isEnabled = enable == true or SafeEquals(enable, 1)
                if start and dur and isEnabled then
                    pcall(cd.SetCooldown, cd, start, dur, modRate or 1)
                    cdApplied = true
                    if not isOnCD and SafeIsGreaterThan(dur, 1.5) then
                        local now = (_G.GetTime and _G.GetTime()) or 0
                        local finish = start + dur
                        if SafeIsGreaterThan(finish - now, 0.1) then
                            isOnCD = true
                        end
                    end
                end
            end
        end

        if not cdApplied or (durObj and SafeDurationIsZero(durObj)) or (cdInfo and cdInfo.isActive == false) then
            if cd.Clear then
                cd:Clear()
            elseif cd.SetCooldown then
                pcall(cd.SetCooldown, cd, 0, 0)
            end
        end

        local chargeInfo = _G.C_Spell and _G.C_Spell.GetSpellCharges and _G.C_Spell.GetSpellCharges(spellID)
        if chargeInfo and SafeIsGreaterThanZero(chargeInfo.currentCharges) then
            isOnCD = false
        end

        SetIconVisualState(iconBtn.Icon, isOnCD)
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
            local isMultiCharge = false
            local ok, multi = pcall(function()
                return chargeInfo and chargeInfo.maxCharges and chargeInfo.maxCharges > 1
            end)
            if ok and multi then
                isMultiCharge = true
            end

            if isMultiCharge and chargeInfo and chargeInfo.currentCharges then
                chargeFS:SetText(chargeInfo.currentCharges)
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
        local frame = self.customBarFrames[barIdx]
        local count = (frame and frame.activeSpells and #frame.activeSpells) or (cfg.spells and #cfg.spells or 0)
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
    if growthDir == "DOWN" then growthDir = "TOP_TO_BOTTOM"
    elseif growthDir == "UP" then growthDir = "BOTTOM_TO_TOP"
    elseif growthDir == "LEFT" then growthDir = "RIGHT_TO_LEFT"
    elseif growthDir == "RIGHT" then growthDir = "LEFT_TO_RIGHT"
    elseif growthDir == "CENTER" then growthDir = "CENTER_HORIZONTAL"
    end
    growthDir = growthDir or (isVertical and "TOP_TO_BOTTOM" or "LEFT_TO_RIGHT")
    local isAdaptable = (cfg.adaptable ~= false)
    cfg.spells = cfg.spells or {}

    local isEditMode = _G.EditModeManagerFrame and _G.EditModeManagerFrame.IsShown and _G.EditModeManagerFrame:IsShown()
    local isCdmSettings = not isEditMode and (self.customSettingsPanel and self.customSettingsPanel.IsShown and self.customSettingsPanel:IsShown())

    local activeSpells = {}
    local activeOrigIndices = {}
    if isCdmSettings or isEditMode then
        for origIdx, entry in ipairs(cfg.spells) do
            table.insert(activeSpells, entry)
            table.insert(activeOrigIndices, origIdx)
        end
    else
        for origIdx, entry in ipairs(cfg.spells) do
            if self:IsCustomBarItemAccessible(entry) then
                table.insert(activeSpells, entry)
                table.insert(activeOrigIndices, origIdx)
            end
        end
    end
    frame.activeSpells = activeSpells
    frame.activeOrigIndices = activeOrigIndices

    local numSpells = #activeSpells

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

    local perLine = cfg.buttonsPerRow or 8
    local totalW, totalH
    if ns.Utils and ns.Utils.GetGridDimensions then
        local _, _, gridW, gridH = ns.Utils.GetGridDimensions(numVisible, perLine, iconSize, iconSize, spacing, spacing, isVertical)
        totalW, totalH = gridW, gridH
    else
        totalW = isVertical and iconSize or (numVisible * iconSize + math.max(0, numVisible - 1) * spacing)
        totalH = isVertical and (numVisible * iconSize + math.max(0, numVisible - 1) * spacing) or iconSize
    end
    frame:SetSize(math.max(totalW, 20), math.max(totalH, 20))

    local is1D = (numVisible <= perLine and not isVertical) or (numVisible <= perLine and isVertical)
    local targetPoint = (ns.Utils and ns.Utils.GetGrowthAnchor) and ns.Utils.GetGrowthAnchor(growthDir, is1D) or "CENTER"

    if cfg.point ~= targetPoint then
        if ns.Utils and ns.Utils.MigratePointCoordinates then
            cfg.x, cfg.y = ns.Utils.MigratePointCoordinates(cfg.point or "CENTER", targetPoint, cfg.x or 0, cfg.y or 0, totalW, totalH)
        end
        cfg.point = targetPoint
    end

    frame:ClearAllPoints()
    frame:SetPoint(targetPoint, UIParent, "CENTER", cfg.x or 0, cfg.y or 0)
    frame.editModeName = cfg.name or ("Custom Bar " .. index)

    -- Register with LibEditMode if available
    if LEM and LEM.AddFrame and not frame.lemRegistered then
        local defaults = { point = targetPoint, x = cfg.x or 0, y = cfg.y or 0 }
        LEM:AddFrame(frame, function(f, unusedMode, pt, x, y)
            local currentGrowth = cfg.growthDirection
            if currentGrowth == "DOWN" then currentGrowth = "TOP_TO_BOTTOM"
            elseif currentGrowth == "UP" then currentGrowth = "BOTTOM_TO_TOP"
            elseif currentGrowth == "LEFT" then currentGrowth = "RIGHT_TO_LEFT"
            elseif currentGrowth == "RIGHT" then currentGrowth = "LEFT_TO_RIGHT"
            elseif currentGrowth == "CENTER" then currentGrowth = "CENTER_HORIZONTAL"
            end
            local isVert = (cfg.orientation == "VERTICAL")
            currentGrowth = currentGrowth or (isVert and "TOP_TO_BOTTOM" or "LEFT_TO_RIGHT")

            local anchorPt = (ns.Utils and ns.Utils.GetGrowthAnchor) and ns.Utils.GetGrowthAnchor(currentGrowth) or "CENTER"

            local w = f:GetWidth() or 40
            local h = f:GetHeight() or 40

            local fCenterX, fCenterY
            if f.GetCenter and UIParent and UIParent.GetCenter then
                local uCenterX, uCenterY = UIParent:GetCenter()
                local fcX, fcY = f:GetCenter()
                if uCenterX and fcX then
                    fCenterX = fcX - uCenterX
                    fCenterY = fcY - uCenterY
                end
            end

            if not fCenterX then
                if ns.Utils and ns.Utils.PointToCenter then
                    fCenterX, fCenterY = ns.Utils.PointToCenter(pt, x or 0, y or 0, w, h)
                else
                    fCenterX, fCenterY = x or 0, y or 0
                end
            end

            local finalX, finalY
            if ns.Utils and ns.Utils.CenterToPoint then
                finalX, finalY = ns.Utils.CenterToPoint(anchorPt, fCenterX, fCenterY, w, h)
            else
                finalX, finalY = fCenterX, fCenterY
            end

            f:ClearAllPoints()
            f:SetPoint(anchorPt, UIParent, "CENTER", finalX, finalY)
            cfg.point = anchorPt
            cfg.x = finalX
            cfg.y = finalY
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
                    name = L["Icons Per Row"] or "Icons Per Row",
                    kind = LEM.SettingType.Slider,
                    default = 8,
                    minValue = 1,
                    maxValue = 24,
                    valueStep = 1,
                    get = function() return cfg.buttonsPerRow or 8 end,
                    set = function(_, val)
                        cfg.buttonsPerRow = val
                        CDM:InitializeCustomBar(index)
                    end,
                    formatter = function(v) return string.format("%.0f", v) end,
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
                        if CDM then CDM.selectedOptionsBar = frame.barKey end
                        if RoithiUI and RoithiUI.OpenSettings then
                            RoithiUI:OpenSettings("cooldownmanager")
                        elseif LibStub and LibStub("AceConfigDialog-3.0", true) then
                            local ACD = LibStub("AceConfigDialog-3.0", true)
                            pcall(function() ACD:Open("RoithiUI") end)
                            pcall(function() ACD:SelectGroup("RoithiUI", "combat", "cooldownmanager") end)
                        end
                    end,
                },
                {
                    text = L["Create / Edit Bars"] or "Create / Edit Bars",
                    click = function()
                        CDM:OpenBlizzardSettings(true)
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
            if iconBtn.Cooldown.SetScript then
                iconBtn.Cooldown:SetScript("OnCooldownDone", function()
                    SetIconVisualState(iconBtn.Icon, false)
                end)
            end

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
                    local targetSlot = selfBtn.originalSlotIndex or selfBtn.slotIndex
                    CDM:AssignSpellToCustomBar(index, targetSlot, spellID)
                    _G.ClearCursor()
                end
            end)

            iconBtn:SetScript("OnClick", function(selfBtn, button)
                local spellID = CDM:GetCursorSpellInfo()
                if spellID then
                    local targetSlot = selfBtn.originalSlotIndex or selfBtn.slotIndex
                    CDM:AssignSpellToCustomBar(index, targetSlot, spellID)
                    _G.ClearCursor()
                elseif button == "RightButton" and _G.IsShiftKeyDown() then
                    local targetSlot = selfBtn.originalSlotIndex or selfBtn.slotIndex
                    CDM:RemoveSpellFromCustomBar(index, targetSlot)
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
        iconBtn.originalSlotIndex = (frame.activeOrigIndices and frame.activeOrigIndices[i]) or i
        iconBtn:SetSize(iconSize, iconSize)
        iconBtn:ClearAllPoints()
        local itemOx, itemOy, iconAnchor
        local barPerLine = cfg.buttonsPerRow or 8
        if ns.Utils and ns.Utils.GetGridItemOffset then
            itemOx, itemOy, iconAnchor = ns.Utils.GetGridItemOffset(growthDir, i, numVisible, barPerLine, iconSize, iconSize, spacing, spacing, isVertical)
        elseif ns.Utils and ns.Utils.GetLinearItemOffset then
            itemOx, itemOy, iconAnchor = ns.Utils.GetLinearItemOffset(growthDir, i, numVisible, iconSize, spacing)
        else
            local offset = (i - 1) * (iconSize + spacing)
            itemOx, itemOy, iconAnchor = offset, 0, "LEFT"
        end
        iconBtn:SetPoint(iconAnchor, frame, iconAnchor, itemOx, itemOy)

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

-- Event listener for live custom cooldown updates and accessibility changes
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or
       event == "PLAYER_EQUIPMENT_CHANGED" or
       event == "BAG_UPDATE_DELAYED" or
       event == "SPELLS_CHANGED" or
       event == "TRAIT_CONFIG_UPDATED" or
       event == "PLAYER_SPECIALIZATION_CHANGED" then
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
