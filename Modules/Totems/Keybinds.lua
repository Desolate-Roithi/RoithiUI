local addonName, ns = ...
if ns.skipLoad then return end
if not ns.IsForever and not ns.isTestEnvironment then return end
local RoithiUI = _G.RoithiUI
local Totems = RoithiUI:GetModule("Totems", true)
if not Totems then return end
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

-- Blizzard Keybinding Header & Names
_G.BINDING_HEADER_ROITHI_TOTEMS = L["RoithiUI Totem Bar"]
_G.BINDING_NAME_ROITHI_TOTEM_CYCLE_TYPE = L["Cycle Category"]
_G.BINDING_NAME_ROITHI_TOTEM_CYCLE_SPELL = L["Cycle Spell in Category"]

_G["BINDING_NAME_CLICK RoithiTotemButton_current:LeftButton"] = L["Cast Current Category Totem"]
_G["BINDING_NAME_CLICK RoithiTotemButton_earth:LeftButton"] = L["Cast Earth Totem"]
_G["BINDING_NAME_CLICK RoithiTotemButton_fire:LeftButton"] = L["Cast Fire Totem"]
_G["BINDING_NAME_CLICK RoithiTotemButton_water:LeftButton"] = L["Cast Water Totem"]
_G["BINDING_NAME_CLICK RoithiTotemButton_air:LeftButton"] = L["Cast Air Totem"]
_G["BINDING_NAME_CLICK RoithiTotemButton_shield:LeftButton"] = L["Cast Elemental Shield"]
_G["BINDING_NAME_CLICK RoithiTotemButton_weapon:LeftButton"] = L["Cast Weapon Imbue"]

_G["BINDING_NAME_CLICK RoithiTotemRecallButton:LeftButton"] = L["Unsummon All Totems"]
_G["BINDING_NAME_CLICK RoithiTotemButton_earth:RightButton"] = L["Unsummon Earth Totem"]
_G["BINDING_NAME_CLICK RoithiTotemButton_fire:RightButton"] = L["Unsummon Fire Totem"]
_G["BINDING_NAME_CLICK RoithiTotemButton_water:RightButton"] = L["Unsummon Water Totem"]
_G["BINDING_NAME_CLICK RoithiTotemButton_air:RightButton"] = L["Unsummon Air Totem"]

-- Aliases for direct names
_G.BINDING_NAME_ROITHI_TOTEM_CAST_CURRENT = L["Cast Current Category Totem"]
_G.BINDING_NAME_ROITHI_TOTEM_CAST_EARTH = L["Cast Earth Totem"]
_G.BINDING_NAME_ROITHI_TOTEM_CAST_FIRE = L["Cast Fire Totem"]
_G.BINDING_NAME_ROITHI_TOTEM_CAST_WATER = L["Cast Water Totem"]
_G.BINDING_NAME_ROITHI_TOTEM_CAST_AIR = L["Cast Air Totem"]
_G.BINDING_NAME_ROITHI_TOTEM_CAST_SHIELD = L["Cast Elemental Shield"]
_G.BINDING_NAME_ROITHI_TOTEM_CAST_WEAPON = L["Cast Weapon Imbue"]
_G.BINDING_NAME_ROITHI_TOTEM_RECALL_ALL = L["Unsummon All Totems"]
_G.BINDING_NAME_ROITHI_TOTEM_DESTROY_EARTH = L["Unsummon Earth Totem"]
_G.BINDING_NAME_ROITHI_TOTEM_DESTROY_FIRE = L["Unsummon Fire Totem"]
_G.BINDING_NAME_ROITHI_TOTEM_DESTROY_WATER = L["Unsummon Water Totem"]
_G.BINDING_NAME_ROITHI_TOTEM_DESTROY_AIR = L["Unsummon Air Totem"]

function Totems:SetupSecureKeybindButtons()
    if self.currentButton then return end

    -- Button that casts whatever category is currently selected
    local currentBtn = CreateFrame("Button", "RoithiTotemButton_current", UIParent, "SecureActionButtonTemplate")
    if currentBtn.RegisterForClicks then
        currentBtn:RegisterForClicks("AnyUp", "AnyDown")
    end
    self.currentButton = currentBtn

    -- Dedicated secure destroy buttons for each totem slot (slots 1 to 4)
    self.destroyButtons = {}
    for slot = 1, 4 do
        local dBtn = CreateFrame("Button", "RoithiTotemDestroy_" .. slot, UIParent, "SecureActionButtonTemplate")
        if dBtn.RegisterForClicks then
            dBtn:RegisterForClicks("AnyUp", "AnyDown")
        end
        dBtn:SetAttribute("type", "destroytotem")
        dBtn:SetAttribute("totem-slot", slot)
        self.destroyButtons[slot] = dBtn
    end

    -- Button that unsummons all totems
    local recallBtn = CreateFrame("Button", "RoithiTotemRecallButton", UIParent, "SecureActionButtonTemplate")
    if recallBtn.RegisterForClicks then
        recallBtn:RegisterForClicks("AnyUp", "AnyDown")
    end
    recallBtn:SetAttribute("type", "macro")
    recallBtn:SetAttribute("macrotext", "/cast Totemic Recall\n/click RoithiTotemDestroy_1\n/click RoithiTotemDestroy_2\n/click RoithiTotemDestroy_3\n/click RoithiTotemDestroy_4")
    self.recallButton = recallBtn

    self:UpdateCurrentActionButton()
end

function Totems:UpdateCurrentActionButton()
    if not self.currentButton or InCombatLockdown() then return end

    local catKey = self.db.selectedCategory or "earth"
    local spellId = self.db.selectedSpells and self.db.selectedSpells[catKey]
    local spellName = nil

    if spellId then
        if C_Spell and C_Spell.GetSpellInfo then
            local spellInfo = C_Spell.GetSpellInfo(spellId)
            if spellInfo then spellName = spellInfo.name end
        elseif GetSpellInfo then
            spellName = GetSpellInfo(spellId)
        end
    end

    if spellName or spellId then
        self.currentButton:SetAttribute("type", "spell")
        self.currentButton:SetAttribute("spell", spellName or spellId)
    else
        self.currentButton:SetAttribute("type", nil)
        self.currentButton:SetAttribute("spell", nil)
    end
end

function Totems:GetVisibleCategories()
    local visible = {}
    for _, catKey in ipairs(self.categories) do
        local optKey = "show" .. catKey:gsub("^%l", string.upper)
        local enabledByOpt = (self.db[optKey] ~= false)
        local hasKnownSpells = self.availableSpells and self.availableSpells[catKey] and (#self.availableSpells[catKey] > 0)
        if enabledByOpt and hasKnownSpells then
            table.insert(visible, catKey)
        end
    end
    if #visible == 0 then
        for _, catKey in ipairs(self.categories) do
            local optKey = "show" .. catKey:gsub("^%l", string.upper)
            if self.db[optKey] ~= false then
                table.insert(visible, catKey)
            end
        end
    end
    return visible
end

function Totems:CycleCategory(direction)
    self.isKeyboardHighlight = true
    local dir = direction or 1
    local visible = self:GetVisibleCategories()
    if #visible == 0 then return end

    local curCat = self.db.selectedCategory or visible[1]
    local curIdx = 1

    for i, key in ipairs(visible) do
        if key == curCat then
            curIdx = i
            break
        end
    end

    local nextIdx = curIdx + dir
    if nextIdx > #visible then
        nextIdx = 1
    elseif nextIdx < 1 then
        nextIdx = #visible
    end

    self.db.selectedCategory = visible[nextIdx]
    self:UpdateCurrentActionButton()
    if self.UpdateAllSlotBorders then
        self:UpdateAllSlotBorders()
    end
    self:OnTick()
end

function Totems:CycleSpell(direction)
    self.isKeyboardHighlight = true
    local dir = direction or 1
    local catKey = self.db.selectedCategory or "earth"
    local spells = self.availableSpells[catKey]
    if not spells or #spells == 0 then
        spells = self.spellsDatabase[catKey] or {}
    end

    if #spells == 0 then return end

    local curSpellId = self.db.selectedSpells[catKey]
    local curIdx = 1
    for i, s in ipairs(spells) do
        if s.id == curSpellId then
            curIdx = i
            break
        end
    end

    local nextIdx = curIdx + dir
    if nextIdx > #spells then
        nextIdx = 1
    elseif nextIdx < 1 then
        nextIdx = #spells
    end

    self:SelectSpell(catKey, spells[nextIdx].id)
    self:UpdateCurrentActionButton()
end

function Totems:CastSlot(catKey)
    local btn = self.buttons[catKey]
    if btn and btn.Click then
        btn:Click()
    end
end

function Totems:DestroyTotemSlot(blizzSlot)
    if DestroyTotem then
        DestroyTotem(blizzSlot)
    end
end

function Totems:UnsummonAll()
    if self.recallButton and self.recallButton.Click then
        self.recallButton:Click()
    else
        for slot = 1, 4 do
            self:DestroyTotemSlot(slot)
        end
    end
end

local function FormatHotkey(text)
    if not text or text == "" then return "" end
    if text == _G.RANGE_INDICATOR or text == "·" or text == "•" or text:find("[\194\183\226\128\162]") then
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

function Totems:UpdateHotkeys()
    if not self.buttons then return end
    for _, catKey in ipairs(self.categories) do
        local btn = self.buttons[catKey]
        if btn and btn.hotkeyText then
            local bindingAction = "CLICK " .. btn:GetName() .. ":LeftButton"
            local key = GetBindingKey and GetBindingKey(bindingAction)
            if key and (not self.db or self.db.showKeybind ~= false) then
                btn.hotkeyText:SetText(FormatHotkey(key))
            else
                btn.hotkeyText:SetText("")
            end
        end
    end
end


