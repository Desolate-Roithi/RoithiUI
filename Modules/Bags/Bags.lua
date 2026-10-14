local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local BagsMod = RoithiUI:GetModule("Bags")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LibRoithi = LibStub("LibRoithi-1.0")

local QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor
    [1] = { r = 0.3, g = 0.3, b = 0.3 },    -- Common
    [2] = { r = 0.12, g = 1.0, b = 0.0 },   -- Uncommon
    [3] = { r = 0.0, g = 0.44, b = 0.87 },  -- Rare
    [4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic
    [5] = { r = 1.0, g = 0.5, b = 0.0 },    -- Legendary
    [6] = { r = 0.9, g = 0.8, b = 0.5 },    -- Artifact
    [7] = { r = 0.0, g = 0.8, b = 1.0 },    -- Heirloom
}

local function FormatNumberWithDots(amount)
    local formatted = tostring(amount or 0)
    local k
    repeat
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
    until k == 0
    return formatted
end
BagsMod.FormatNumberWithDots = FormatNumberWithDots


function BagsMod:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Bags or self.defaultSettings
    if not self.db.bagBar then
        self.db.bagBar = CopyTable(self.defaultSettings.bagBar)
    end
    if not self.db.bagWindow then
        self.db.bagWindow = CopyTable(self.defaultSettings.bagWindow)
    end
    if not self.db.customCategoryAssignments then
        self.db.customCategoryAssignments = {}
    end
    if self.db.activeCategory == "WEAPONS" then
        self.db.activeCategory = "GEAR"
    end
    if self.db.itemCountFont == nil then
        self.db.itemCountFont = (self.defaultSettings and self.defaultSettings.itemCountFont) or "Roithi Thick"
    end
    if self.db.itemCountFontOutline == nil then
        self.db.itemCountFontOutline = (self.defaultSettings and self.defaultSettings.itemCountFontOutline) or "OUTLINE"
    end
    if self.db.itemLevelFont == nil then
        self.db.itemLevelFont = (self.defaultSettings and self.defaultSettings.itemLevelFont) or "Roithi Thick"
    end
    if self.db.itemLevelFontOutline == nil then
        self.db.itemLevelFontOutline = (self.defaultSettings and self.defaultSettings.itemLevelFontOutline) or "OUTLINE"
    end
    if self.db.questIndicatorSize == nil then
        self.db.questIndicatorSize = (self.defaultSettings and self.defaultSettings.questIndicatorSize) or 16
    end
    if self.db.questIndicatorAnchor == nil then
        self.db.questIndicatorAnchor = (self.defaultSettings and self.defaultSettings.questIndicatorAnchor) or "BOTTOMLEFT"
    end
    if self.db.questIndicatorX == nil then
        self.db.questIndicatorX = (self.defaultSettings and self.defaultSettings.questIndicatorX) or 1
    end
    if self.db.questIndicatorY == nil then
        self.db.questIndicatorY = (self.defaultSettings and self.defaultSettings.questIndicatorY) or 1
    end
    if self.db.showJunkIndicator == nil then
        self.db.showJunkIndicator = (self.defaultSettings and self.defaultSettings.showJunkIndicator ~= false) or true
    end
    if self.db.junkIndicatorSize == nil then
        self.db.junkIndicatorSize = (self.defaultSettings and self.defaultSettings.junkIndicatorSize) or 14
    end
    if self.db.junkIndicatorAnchor == nil then
        self.db.junkIndicatorAnchor = (self.defaultSettings and self.defaultSettings.junkIndicatorAnchor) or "BOTTOMLEFT"
    end
    if self.db.junkIndicatorX == nil then
        self.db.junkIndicatorX = (self.defaultSettings and self.defaultSettings.junkIndicatorX) or 1
    end
    if self.db.junkIndicatorY == nil then
        self.db.junkIndicatorY = (self.defaultSettings and self.defaultSettings.junkIndicatorY) or 1
    end
    self.itemSlots = {}
    self.categoryButtons = {}
    self.newItems = {}
    self.knownItemIDs = {}
    self.newSlots = {}
    self.hoveredNewSlots = {}
    self.dismissedNewHighlights = {}
    self.knownSlots = {}
    self.knownSlotCounts = {}
    self.initialInventoryScanned = false
    self.searchText = ""
    self:RegisterPopups()

    -- Sanitize any legacy numeric itemID assignments to "JUNK" to prevent auto-junking duplicate items
    if self.db and self.db.customCategoryAssignments then
        for k, v in pairs(self.db.customCategoryAssignments) do
            if type(k) == "number" and v == "JUNK" then
                self.db.customCategoryAssignments[k] = nil
            end
        end
    end
end

function BagsMod:OnEnable()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Bags or self.defaultSettings
    if not self.db.bagBar then
        self.db.bagBar = CopyTable(self.defaultSettings.bagBar)
    end
    if not self.db.bagWindow then
        self.db.bagWindow = CopyTable(self.defaultSettings.bagWindow)
    end
    if self.db.activeCategory == "WEAPONS" then
        self.db.activeCategory = "GEAR"
    end
    if self.db.enabled == false then return end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagUpdate")
    self:RegisterEvent("BAG_UPDATE", "OnBagUpdate")
    self:RegisterEvent("BAG_CONTAINER_UPDATE", "OnBagUpdate")
    self:RegisterEvent("ITEM_LOCK_CHANGED", "OnBagUpdate")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN", "OnBagCooldownUpdate")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnBagUpdate")
    self:RegisterEvent("PLAYER_MONEY", "UpdateMoneyDisplay")
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "UpdateMoneyDisplay")
    self:RegisterEvent("MERCHANT_SHOW", "OnMerchantShow")
    self:RegisterEvent("MERCHANT_CLOSED", "OnMerchantClosed")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")

    self:HookTooltipShortcuts()
    self:SetupBagBar()
    self:HookBlizzardBagFunctions()
    self:ScanInventoryOnce(true)
    self:PrewarmItemSlots()
end

function BagsMod:OnEnteringWorld(event, isInitialLogin, isReloadingUi)
    self:KillBlizzardBags()
    local isInitial = (isInitialLogin == true) or (isReloadingUi == true) or (not self.initialInventoryScanned)
    if isInitial then
        self:ScanInventoryOnce(true)
    else
        local now = _G.GetTime and _G.GetTime() or 0
        self.teleportGraceUntil = now + 4.0
    end
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.pendingCombatRelogBagUpdate = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
    end
end

function BagsMod:PrewarmItemSlots()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    self:CreateMainBagFrame()
    for i = 1, 160 do
        local slot = self:AcquireItemSlot(i)
        if slot then
            local parent = slot.slotParent or slot
            parent:Hide()
        end
    end
end

function BagsMod:OnRegenEnabled()
    if self.pendingCombatRelogBagUpdate then
        self.pendingCombatRelogBagUpdate = nil
        self:PrewarmItemSlots()
        if self.UpdateBagBarLayout then
            self:UpdateBagBarLayout()
        end
    end
    if self.mainFrame and self.mainFrame:IsShown() then
        self:UpdateInventory()
    end
end

function BagsMod:RestoreBlizzardBags()
    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f and f.SetParent then
            f:SetParent(UIParent)
        end
    end
    local cb = _G.ContainerFrameCombinedBags
    if cb and cb.SetParent then
        cb:SetParent(UIParent)
    end
end

function BagsMod:OnDisable()
    if self.mainFrame and self.mainFrame.Hide then
        self.mainFrame:Hide()
    end
    self:RestoreBlizzardBags()
    if self.RestoreBlizzardBagBar then
        self:RestoreBlizzardBagBar()
    end
end

local blizzBagHidden
local function GetBlizzBagHidden()
    if not blizzBagHidden then
        blizzBagHidden = CreateFrame("Frame", "RoithiUI_BlizzBagHidden", UIParent)
        blizzBagHidden:Hide()
    end
    return blizzBagHidden
end

function BagsMod:KillBlizzardBags()
    if self.db and self.db.enabled == false then return end
    local hidden = GetBlizzBagHidden()
    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f then
            if f.SetParent and f:GetParent() ~= hidden then
                f:SetParent(hidden)
            end
            if f.Hide and f:IsShown() then
                f:Hide()
            end
            if f.UnregisterAllEvents then
                f:UnregisterAllEvents()
            end
        end
    end
    local cb = _G.ContainerFrameCombinedBags
    if cb then
        if cb.SetParent and cb:GetParent() ~= hidden then
            cb:SetParent(hidden)
        end
        if cb.Hide and cb:IsShown() then
            cb:Hide()
        end
        if cb.UnregisterAllEvents then
            cb:UnregisterAllEvents()
        end
    end
    if _G.BagUpdaterFrame and _G.BagUpdaterFrame.SetScript then
        _G.BagUpdaterFrame:SetScript("OnUpdate", nil)
    end
end

function BagsMod:HookBlizzardBagFunctions()
    self:KillBlizzardBags()

    local lastToggleTime = 0
    local function SmartToggleBags()
        if self.db and self.db.enabled == false then return end
        local now = _G.GetTime and _G.GetTime() or 0
        if math.abs(now - lastToggleTime) < 0.05 then return end
        lastToggleTime = now

        self:ToggleBags()
        self:KillBlizzardBags()
    end

    local function SmartOpenBags()
        if self.db and self.db.enabled == false then return end
        self:OpenBags()
        self:KillBlizzardBags()
    end

    local function SmartCloseBags()
        if self.db and self.db.enabled == false then return end
        self:CloseBags()
    end

    if _G.ToggleAllBags then hooksecurefunc("ToggleAllBags", SmartToggleBags) end
    if _G.ToggleBackpack then hooksecurefunc("ToggleBackpack", SmartToggleBags) end
    if _G.ToggleBag then hooksecurefunc("ToggleBag", SmartToggleBags) end
    if _G.OpenAllBags then hooksecurefunc("OpenAllBags", SmartOpenBags) end
    if _G.CloseAllBags then hooksecurefunc("CloseAllBags", SmartCloseBags) end
end

function BagsMod:OpenCategory(catID)
    self:CreateMainBagFrame()
    if self.mainFrame then
        if catID then
            self.db.activeCategory = catID
        end
        self:UpdateCategoryButtonStyles()
        self:KillBlizzardBags()
        self.mainFrame:Show()
        self:UpdateInventory()
    end
end

function BagsMod:OpenBags(defaultCat)
    self:CreateMainBagFrame()
    if self.mainFrame and self.mainFrame.Show then
        if defaultCat then
            self.db.activeCategory = defaultCat
        end
        self:UpdateCategoryButtonStyles()
        self:KillBlizzardBags()
        self.mainFrame:Show()
        self:UpdateInventory()
    end
end

function BagsMod:CloseBags()
    if self.mainFrame and self.mainFrame.Hide then
        self.mainFrame:Hide()
    end
    self:KillBlizzardBags()
end

local lastToggleBagsTime = 0
function BagsMod:ToggleBags(defaultCat)
    local now = _G.GetTime and _G.GetTime() or 0
    if math.abs(now - lastToggleBagsTime) < 0.2 then return end
    lastToggleBagsTime = now

    if self.mainFrame and self.mainFrame:IsShown() then
        self:CloseBags()
    else
        self:OpenBags(defaultCat)
    end
end

function BagsMod:GetScannableBags()
    local bags = {}
    local maxBag = 4
    if _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS then
        maxBag = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS
    elseif _G.NUM_BAG_SLOTS then
        maxBag = _G.NUM_BAG_SLOTS
    end

    for b = 0, maxBag do
        table.insert(bags, b)
    end

    local reagentBagID = (_G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag) or 5
    local hasReagent = false
    for _, b in ipairs(bags) do
        if b == reagentBagID then hasReagent = true break end
    end
    if not hasReagent and self:GetNumBagSlots(reagentBagID) > 0 then
        table.insert(bags, reagentBagID)
    end

    -- Classic Keyring support
    local keyringID = (_G.KEYRING_CONTAINER or -2)
    if self:GetNumBagSlots(keyringID) > 0 then
        table.insert(bags, keyringID)
    end

    return bags
end

local function GetSlotKey(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot)
end

function BagsMod:GetSlotKey(bag, slot)
    return GetSlotKey(bag, slot)
end

function BagsMod:HasActiveTradeTimer(bag, slot, customTooltipData)
    if not bag or not slot then return false end
    local slotKey = GetSlotKey(bag, slot)
    local now = (_G.GetTime and _G.GetTime()) or 0

    if not customTooltipData and self.tradeTimerCache and self.tradeTimerCache[slotKey] then
        local entry = self.tradeTimerCache[slotKey]
        if (now - entry.time) < 30 then
            return entry.hasTimer
        end
    end

    local hasTimer = false
    local tooltipData = customTooltipData or (_G.C_TooltipInfo and _G.C_TooltipInfo.GetBagItem and _G.C_TooltipInfo.GetBagItem(bag, slot))
    if tooltipData and tooltipData.lines then
        if not customTooltipData and _G.TooltipUtil and _G.TooltipUtil.SurfaceArgs then
            pcall(_G.TooltipUtil.SurfaceArgs, tooltipData)
        end

        local tradeTimeType = (_G.Enum and _G.Enum.TooltipDataLineType and _G.Enum.TooltipDataLineType.TradeTimeRemaining) or 36
        local rawPattern = _G.BIND_TRADE_TIME_REMAINING
        local pattern = rawPattern and rawPattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", ".*")

        for _, line in ipairs(tooltipData.lines) do
            if line.type == tradeTimeType then
                hasTimer = true
                break
            end
            if line.leftText then
                if pattern and string.find(line.leftText, pattern) then
                    hasTimer = true
                    break
                end
                local lowerText = string.lower(line.leftText)
                if string.find(lowerText, "eligible to loot") or string.find(lowerText, "berechtigt") or string.find(lowerText, "trade time remaining") then
                    hasTimer = true
                    break
                end
            end
        end
    elseif _G.CreateFrame and bag and slot then
        -- Classic / Forever fallback using hidden scanning tooltip
        if not self.tradeScanTooltip then
            self.tradeScanTooltip = _G.CreateFrame("GameTooltip", "RoithiBagTradeScanTooltip", nil, "GameTooltipTemplate")
        end
        local tt = self.tradeScanTooltip
        if tt then
            if tt.SetOwner then
                tt:SetOwner(_G.WorldFrame or _G.UIParent, "ANCHOR_NONE")
            end
            if tt.ClearLines then
                tt:ClearLines()
            end
            local ok = tt.SetBagItem and pcall(tt.SetBagItem, tt, bag, slot)
            if ok and tt.NumLines then
                local numLines = tt:NumLines() or 0
                local rawPattern = _G.BIND_TRADE_TIME_REMAINING
                local pattern = rawPattern and rawPattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", ".*")
                for i = 1, numLines do
                    local leftTextObj = _G["RoithiBagTradeScanTooltipTextLeft" .. i]
                    local lineText = leftTextObj and leftTextObj:GetText()
                    if lineText then
                        if pattern and string.find(lineText, pattern) then
                            hasTimer = true
                            break
                        end
                        local lowerText = string.lower(lineText)
                        if string.find(lowerText, "eligible to loot") or string.find(lowerText, "berechtigt") or string.find(lowerText, "trade time remaining") then
                            hasTimer = true
                            break
                        end
                    end
                end
            end
            if tt.Hide then tt:Hide() end
        end
    end

    if not customTooltipData then
        self.tradeTimerCache = self.tradeTimerCache or {}
        self.tradeTimerCache[slotKey] = { hasTimer = hasTimer, time = now }
    end

    return hasTimer
end

function BagsMod:IsSlotNew(bag, slot, itemData)
    if not bag or not slot then return false end
    local slotKey = GetSlotKey(bag, slot)

    local data = itemData
    if not data and _G.C_Container and _G.C_Container.GetContainerItemInfo then
        local cInfo = _G.C_Container.GetContainerItemInfo(bag, slot)
        if cInfo then
            local itemGUID = cInfo.itemGUID
            if not itemGUID and _G.C_Item and _G.C_Item.GetItemGUID and _G.ItemLocation and _G.ItemLocation.CreateFromBagAndSlot then
                local itemLoc = _G.ItemLocation:CreateFromBagAndSlot(bag, slot)
                if itemLoc and _G.C_Item.DoesItemExist and _G.C_Item.DoesItemExist(itemLoc) then
                    itemGUID = _G.C_Item.GetItemGUID(itemLoc)
                end
            end
            data = {
                bag = bag,
                slot = slot,
                itemID = cInfo.itemID,
                quality = cInfo.quality,
                link = cInfo.hyperlink,
                itemGUID = itemGUID,
            }
        end
    end
    if data and self.IsItemJunk and self:IsItemJunk(data) then
        return false
    end

    -- If active trade timer is present, it is always considered new (persists even across relogs)
    if self:HasActiveTradeTimer(bag, slot) then
        return true
    end

    local now = _G.GetTime and _G.GetTime() or 0
    if self.hoveredNewSlots and self.hoveredNewSlots[slotKey] then
        if now < self.hoveredNewSlots[slotKey] then
            return true
        else
            self.hoveredNewSlots[slotKey] = nil
            self:ClearNewSlot(bag, slot)
            return false
        end
    end

    -- If slot was explicitly marked new during session
    if self.newSlots and self.newSlots[slotKey] == true then
        return true
    end

    -- If Blizzard native reports new
    if _G.C_NewItems and _G.C_NewItems.IsNewItem and _G.C_NewItems.IsNewItem(bag, slot) then
        return true
    end

    return false
end

function BagsMod:ShouldShowNewHighlight(bag, slot, itemData)
    if not itemData or not itemData.isNew then return false end
    local b = bag or itemData.bag
    local s = slot or itemData.slot
    if not b or not s then return false end
    local slotKey = GetSlotKey(b, s)
    if self.dismissedNewHighlights and self.dismissedNewHighlights[slotKey] then
        return false
    end
    if self.hoveredNewSlots and self.hoveredNewSlots[slotKey] then
        return false
    end
    return true
end

function BagsMod:SetSlotNew(bag, slot, isNew)
    if not bag or not slot then return end
    local slotKey = GetSlotKey(bag, slot)
    self.newSlots = self.newSlots or {}
    if isNew then
        self.newSlots[slotKey] = true
        if self.dismissedNewHighlights then
            self.dismissedNewHighlights[slotKey] = nil
        end
    else
        self.newSlots[slotKey] = nil
        if self.dismissedNewHighlights then
            self.dismissedNewHighlights[slotKey] = nil
        end
    end
end

function BagsMod:ClearNewSlot(bag, slot)
    if not bag or not slot then return end
    local slotKey = GetSlotKey(bag, slot)
    if self.newSlots then
        self.newSlots[slotKey] = nil
    end
    if self.hoveredNewSlots then
        self.hoveredNewSlots[slotKey] = nil
    end
    if self.dismissedNewHighlights then
        self.dismissedNewHighlights[slotKey] = nil
    end
    if _G.C_NewItems and _G.C_NewItems.RemoveNewItem then
        pcall(_G.C_NewItems.RemoveNewItem, bag, slot)
    end
end

function BagsMod:EvaluateQuestItemState(itemID, questID, isActive)
    local isQuest = (isActive == true or questID ~= nil)
    local showQuestBang = false
    local showQuestBorder = false

    if isActive then
        local isAlreadyOnQuest = questID and _G.C_QuestLog and _G.C_QuestLog.IsOnQuest and _G.C_QuestLog.IsOnQuest(questID)
        local isQuestDone = questID and _G.C_QuestLog and _G.C_QuestLog.IsQuestFlaggedCompleted and _G.C_QuestLog.IsQuestFlaggedCompleted(questID)
        if isAlreadyOnQuest or isQuestDone then
            showQuestBang = false
            showQuestBorder = (isAlreadyOnQuest == true)
        else
            showQuestBang = true
        end
    elseif isQuest then
        showQuestBorder = true
    end

    return {
        isQuest = isQuest,
        showQuestBang = showQuestBang,
        showQuestBorder = showQuestBorder,
    }
end

local function HasBagShortcuts(tooltip)
    if not tooltip or not tooltip.NumLines then return false end
    local num = tooltip:NumLines()
    for i = num, math.max(1, num - 5), -1 do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line and line.GetText then
            local txt = line:GetText()
            if txt and (txt:find("Favorited") or txt:find("Favorite>") or txt:find("Reassign")) then
                return true
            end
        end
    end
    return false
end

local function AppendBagShortcuts(tooltip, itemID)
    if not itemID or not tooltip or not tooltip.AddLine then return end
    if HasBagShortcuts(tooltip) then return end
    local favs = (BagsMod and BagsMod.db and BagsMod.db.favorites) or {}
    local isFav = (favs[itemID] == true)
    tooltip:AddLine(" ")
    if isFav then
        tooltip:AddLine("|cffffd100★ Favorited|r |cffaaaaaa(Alt + Right Click to remove)|r", 1, 1, 1)
    else
        tooltip:AddLine("|cff888888<Alt + Right Click to Favorite>|r", 0.7, 0.7, 0.7)
    end
    tooltip:AddLine("|cff00ccff<Shift + Right Click to Reassign Category>|r", 0.4, 0.8, 1.0)
    tooltip:AddLine("|cff00ff00<Drag item onto Category tab to Reassign>|r", 0.4, 0.9, 0.4)
    tooltip:Show()
end

function BagsMod:HookTooltipShortcuts()
    if self.tooltipShortcutsHooked then return end
    if _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall and _G.Enum and _G.Enum.TooltipDataType then
        _G.TooltipDataProcessor.AddTooltipPostCall(_G.Enum.TooltipDataType.Item, function(tooltip, _)
            local owner = tooltip:GetOwner()
            if owner and (owner.isRoithiBagSlot or tooltip.roithiBagSlot == owner) then
                local itemID = (owner.itemData and owner.itemData.itemID)
                    or (_G.C_Container and _G.C_Container.GetContainerItemID and _G.C_Container.GetContainerItemID(owner.bag, owner.slot))
                    or (_G.GetContainerItemID and _G.GetContainerItemID(owner.bag, owner.slot))
                if itemID and not HasBagShortcuts(tooltip) then
                    AppendBagShortcuts(tooltip, itemID)
                end
            end
        end)
    elseif _G.GameTooltip and _G.GameTooltip.HookScript then
        _G.GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            local owner = tooltip:GetOwner()
            if owner and (owner.isRoithiBagSlot or tooltip.roithiBagSlot == owner) then
                local itemID = (owner.itemData and owner.itemData.itemID)
                    or (_G.C_Container and _G.C_Container.GetContainerItemID and _G.C_Container.GetContainerItemID(owner.bag, owner.slot))
                    or (_G.GetContainerItemID and _G.GetContainerItemID(owner.bag, owner.slot))
                if itemID and not HasBagShortcuts(tooltip) then
                    AppendBagShortcuts(tooltip, itemID)
                end
            end
        end)
    end
    self.tooltipShortcutsHooked = true
end

function BagsMod:ScanInventoryOnce(isInitial)
    self.knownSlots = self.knownSlots or {}
    self.knownSlotCounts = self.knownSlotCounts or {}
    self.newSlots = self.newSlots or {}
    self.knownItemIDs = self.knownItemIDs or {}
    local anySlotScanned = false
    local initialScan = (isInitial == true) or (not self.initialInventoryScanned)

    if initialScan then
        self.newSlots = {}
        self.hoveredNewSlots = {}
        self.dismissedNewHighlights = {}
        self.tradeTimerCache = {}
        self.knownSlotCounts = {}
        if _G.C_NewItems and _G.C_NewItems.ClearAll then
            pcall(_G.C_NewItems.ClearAll)
        end
    end

    for _, bag in ipairs(self:GetScannableBags()) do
        local numSlots = self:GetNumBagSlots(bag)
        for slot = 1, numSlots do
            local slotKey = GetSlotKey(bag, slot)
            local itemInfo = self:GetItemInfoAt(bag, slot)
            if itemInfo and itemInfo.itemID then
                anySlotScanned = true
                self.knownItemIDs[itemInfo.itemID] = true
                self.knownSlots[slotKey] = itemInfo.itemID
                self.knownSlotCounts[slotKey] = itemInfo.count or 1
                -- If item has an active trade timer, keep it marked new even on relog / login
                if self:HasActiveTradeTimer(bag, slot) then
                    self.newSlots[slotKey] = true
                    itemInfo.isNew = true
                else
                    if initialScan then
                        self.newSlots[slotKey] = nil
                        itemInfo.isNew = false
                        if _G.C_NewItems and _G.C_NewItems.RemoveNewItem then
                            pcall(_G.C_NewItems.RemoveNewItem, bag, slot)
                        end
                    end
                end
            else
                self.knownSlots[slotKey] = nil
                self.knownSlotCounts[slotKey] = nil
                self.newSlots[slotKey] = nil
                if self.hoveredNewSlots then self.hoveredNewSlots[slotKey] = nil end
                if self.dismissedNewHighlights then self.dismissedNewHighlights[slotKey] = nil end
            end
        end
    end
    if anySlotScanned then
        self.initialInventoryScanned = true
    end
end

function BagsMod:GetNumBagSlots(bag)
    if _G.C_Container and _G.C_Container.GetContainerNumSlots then
        return _G.C_Container.GetContainerNumSlots(bag) or 0
    elseif _G.GetContainerNumSlots then
        return _G.GetContainerNumSlots(bag) or 0
    end
    return 0
end

function BagsMod:GetItemInfoAt(bag, slot)
    if _G.C_Container and _G.C_Container.GetContainerItemInfo then
        local info = _G.C_Container.GetContainerItemInfo(bag, slot)
        if info then
            local itemID = info.itemID
            local quality = info.quality or 1
            local count = info.stackCount or 1
            local link = info.hyperlink or info.hyperLink or (_G.C_Container.GetContainerItemLink and _G.C_Container.GetContainerItemLink(bag, slot))
            local texture = info.iconFileID or info.icon

            local itemGUID = info.itemGUID
            if not itemGUID and _G.C_Item and _G.C_Item.GetItemGUID and _G.ItemLocation and _G.ItemLocation.CreateFromBagAndSlot then
                local itemLoc = _G.ItemLocation:CreateFromBagAndSlot(bag, slot)
                if itemLoc and _G.C_Item.DoesItemExist and _G.C_Item.DoesItemExist(itemLoc) then
                    itemGUID = _G.C_Item.GetItemGUID(itemLoc)
                end
            end

            local name, itemType, itemSubType, equipLoc, classID, subclassID, bindType, expID, isCraftingReagent, itemLevel
            if itemID and _G.C_Item and _G.C_Item.GetItemInfoInstant then
                local _, iType, iSubType, eqLoc, _, cID, scID = _G.C_Item.GetItemInfoInstant(itemID)
                itemType = iType
                itemSubType = iSubType
                equipLoc = eqLoc
                classID = cID
                subclassID = scID
            end
            if link and _G.GetItemInfo then
                local iName, _, iQuality, iLvl, _, iType, iSubType, _, eqLoc, _, _, cID, scID, bType, expacID, _, isCraft = _G.GetItemInfo(link)
                name = iName
                itemType = itemType or iType
                itemSubType = itemSubType or iSubType
                equipLoc = equipLoc or eqLoc
                quality = iQuality or quality
                itemLevel = iLvl
                classID = classID or cID
                subclassID = subclassID or scID
                bindType = bType
                expID = expacID
                isCraftingReagent = isCraft
            end
            if not itemLevel and link and _G.C_Item and _G.C_Item.GetDetailedItemLevelInfo then
                itemLevel = _G.C_Item.GetDetailedItemLevelInfo(link)
            end

            local isQuest = false
            local showQuestBang = false
            local showQuestBorder = false
            if _G.C_Container and _G.C_Container.GetContainerItemQuestInfo then
                local qInfo = _G.C_Container.GetContainerItemQuestInfo(bag, slot)
                if qInfo then
                    local qState = self:EvaluateQuestItemState(itemID, qInfo.questID, qInfo.isActive)
                    isQuest = qState.isQuest or (qInfo.isQuestItem == true) or (qInfo.questID ~= nil)
                    showQuestBang = qState.showQuestBang
                    showQuestBorder = qState.showQuestBorder or (qInfo.isQuestItem == true)
                end
            elseif _G.GetContainerItemQuestInfo then
                local isQuestItem, qID, act = _G.GetContainerItemQuestInfo(bag, slot)
                if isQuestItem or qID or act then
                    local qState = self:EvaluateQuestItemState(itemID, qID, act)
                    isQuest = qState.isQuest or (isQuestItem == true) or (qID ~= nil)
                    showQuestBang = qState.showQuestBang
                    showQuestBorder = qState.showQuestBorder or (isQuestItem == true)
                end
            end
            if classID == 12 then
                isQuest = true
                showQuestBorder = true
            end

            local itemInfo = {
                bag = bag,
                slot = slot,
                itemID = itemID,
                name = name or (link and link:match("%[(.-)%]")) or ("Item " .. tostring(itemID)),
                quality = quality,
                count = count,
                link = link,
                texture = texture,
                classID = classID,
                subclassID = subclassID,
                itemType = itemType,
                itemSubType = itemSubType,
                equipLoc = equipLoc,
                itemLevel = itemLevel,
                bindType = bindType,
                expID = expID,
                isQuest = isQuest,
                showQuestBang = showQuestBang,
                showQuestBorder = showQuestBorder,
                isCraftingReagent = isCraftingReagent,
                itemGUID = itemGUID,
            }
            itemInfo.isNew = self:IsSlotNew(bag, slot, itemInfo)
            return itemInfo
        end
    end
    return nil
end

function BagsMod:OnBagUpdate()
    if not self.mainFrame or not self.mainFrame:IsShown() then
        if self.UpdateBagButtonsVisual then
            self:UpdateBagButtonsVisual()
        end
        return
    end

    if self.pendingBagUpdate then return end
    self.pendingBagUpdate = true

    local function PerformUpdate()
        self.pendingBagUpdate = nil
        if self.UpdateBagButtonsVisual then
            self:UpdateBagButtonsVisual()
        end
        if self.mainFrame and self.mainFrame:IsShown() then
            self:UpdateInventory()
        end
    end

    if _G.RunNextFrame then
        _G.RunNextFrame(PerformUpdate)
    elseif _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.05, PerformUpdate)
    else
        PerformUpdate()
    end
end

function BagsMod:CreateMainBagFrame()
    if self.mainFrame then return end

    local cfg = self.db.bagWindow or self.defaultSettings.bagWindow

    local frame = CreateFrame("Frame", "RoithiBagFrame", UIParent, "BackdropTemplate")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(50)

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
    end

    local defBW = ns.Defaults.profile.Bags.bagWindow
    local pt = cfg.point or defBW.point
    local cols = self.db.columns or 10
    local slotSize = self.db.slotSize or 36
    local spacing = self.db.spacing or 4
    local calculatedW = math.max(380, cols * slotSize + (cols - 1) * spacing + 16)
    local initialW = (cfg.width and cfg.width > 0) and cfg.width or calculatedW
    local initialH = (cfg.height and cfg.height > 0) and cfg.height or 420
    frame:SetSize(initialW, initialH)
    frame:ClearAllPoints()
    frame:SetPoint(pt, UIParent, pt, cfg.x or defBW.x, cfg.y or defBW.y)

    if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
    frame:SetScript("OnDragStart", function(s) s:StartMoving() end)
    frame:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local sPoint, _, _, sX, sY = s:GetPoint(1)
        self.db.bagWindow = self.db.bagWindow or {}
        self.db.bagWindow.point = sPoint
        self.db.bagWindow.x = sX
        self.db.bagWindow.y = sY
        self.db.bagWindow.width = s:GetWidth()
        self.db.bagWindow.height = s:GetHeight()
    end)

    self.mainFrame = frame

    if _G.UISpecialFrames then
        local found = false
        for _, name in ipairs(_G.UISpecialFrames) do
            if name == "RoithiBagFrame" then found = true break end
        end
        if not found then
            table.insert(_G.UISpecialFrames, "RoithiBagFrame")
        end
    end

    self:CreateHeaderBar()
    self:CreateCategoryButtons()
    if self.UpdateCategoryButtonsLayout then
        self:UpdateCategoryButtonsLayout(initialW - 12)
    end
    self:CreateFooterBar()
    self:UpdateTypography()
end

function BagsMod:ApplyFont(fontString, defaultSize, customSizeKey, defaultOutline, customFontKey, customOutlineKey)
    if not fontString then return end
    local fontFace = (self.db and customFontKey and self.db[customFontKey]) or (self.db and self.db.font) or "Friz Quadrata TT"
    local outline = (self.db and customOutlineKey and self.db[customOutlineKey]) or (self.db and self.db.fontOutline) or defaultOutline or "OUTLINE"
    local size = (self.db and customSizeKey and self.db[customSizeKey]) or defaultSize or 12
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(fontString, fontFace, size, outline)
    else
        fontString:SetFont("Fonts\\FRIZQT__.TTF", size, outline)
    end
    if fontString.SetShadowOffset then
        if outline == "OUTLINE" or outline == "THICKOUTLINE" then
            fontString:SetShadowOffset(0, 0)
        else
            fontString:SetShadowOffset(1, -1)
            if fontString.SetShadowColor then
                fontString:SetShadowColor(0, 0, 0, 1)
            end
        end
    end
    if fontString.IsObjectType and fontString:IsObjectType("FontString") and fontString.SetDrawLayer then
        fontString:SetDrawLayer("OVERLAY", 7)
    end
end

function BagsMod:UpdateFooterLayout()
    if not self.footerBar or not self.freeText or not self.sortButton then return end
    local freeAnchor = (self.db and self.db.freeSlotsAnchor) or "RIGHT"
    self.freeText:ClearAllPoints()
    self.sortButton:ClearAllPoints()

    if freeAnchor == "LEFT" then
        local leftAnchor = (self.lastCurrencyButton and self.lastCurrencyButton:IsShown() and self.lastCurrencyButton) or self.moneyButton or self.moneyText
        if leftAnchor then
            self.freeText:SetPoint("LEFT", leftAnchor, "RIGHT", 12, 0)
        else
            self.freeText:SetPoint("LEFT", self.footerBar, "LEFT", 120, 0)
        end
        if self.freeText.SetJustifyH then self.freeText:SetJustifyH("LEFT") end
        self.sortButton:SetPoint("RIGHT", self.footerBar, "RIGHT", -2, 0)
    elseif freeAnchor == "CENTER" then
        self.freeText:SetPoint("CENTER", self.footerBar, "CENTER", 0, 0)
        if self.freeText.SetJustifyH then self.freeText:SetJustifyH("CENTER") end
        self.sortButton:SetPoint("RIGHT", self.footerBar, "RIGHT", -2, 0)
    else
        self.freeText:SetPoint("RIGHT", self.footerBar, "RIGHT", -2, 0)
        if self.freeText.SetJustifyH then self.freeText:SetJustifyH("RIGHT") end
        self.sortButton:SetPoint("RIGHT", self.freeText, "LEFT", -8, 0)
    end
end

function BagsMod:UpdateTypography()
    if self.searchBox then
        self:ApplyFont(self.searchBox, 12, "searchFontSize", "")
    end
    if self.searchPlaceholder then
        self:ApplyFont(self.searchPlaceholder, 12, "searchFontSize", "")
    end
    if self.categoryButtons then
        for _, btn in ipairs(self.categoryButtons) do
            if btn.label then
                self:ApplyFont(btn.label, 12, "categoryFontSize", "OUTLINE")
            end
        end
    end
    if self.moneyText then
        self:ApplyFont(self.moneyText, 12, "goldFontSize", "OUTLINE")
    end
    if self.currencyButtons then
        for _, btn in pairs(self.currencyButtons) do
            if btn.text then
                self:ApplyFont(btn.text, 12, "goldFontSize", "OUTLINE")
            end
        end
    end
    if self.freeText then
        self:ApplyFont(self.freeText, 12, "freeSlotsFontSize", "OUTLINE")
    end
    self:UpdateFooterLayout()

    local slots = self.itemSlots or self.slotPool
    if slots then
        local countAnchor = (self.db and self.db.itemCountAnchor) or "BOTTOMRIGHT"
        local countX = (self.db and self.db.itemCountX) or -2
        local countY = (self.db and self.db.itemCountY) or 2
        local ilvlAnchor = (self.db and self.db.itemLevelAnchor) or "TOPLEFT"
        local ilvlX = (self.db and self.db.itemLevelX) or 2
        local ilvlY = (self.db and self.db.itemLevelY) or -2
        local questAnchor = (self.db and self.db.questIndicatorAnchor) or "BOTTOMLEFT"
        local questX = (self.db and self.db.questIndicatorX) or 1
        local questY = (self.db and self.db.questIndicatorY) or 1
        local questSize = (self.db and self.db.questIndicatorSize) or 16
        local junkAnchor = (self.db and self.db.junkIndicatorAnchor) or "BOTTOMLEFT"
        local junkX = (self.db and self.db.junkIndicatorX) or 1
        local junkY = (self.db and self.db.junkIndicatorY) or 1
        local junkSize = (self.db and self.db.junkIndicatorSize) or 14

        for _, slotFrame in pairs(slots) do
            local count = slotFrame.Count or slotFrame.count
            if count then
                self:ApplyFont(count, 12, "itemCountFontSize", "OUTLINE", "itemCountFont", "itemCountFontOutline")
                if count.ClearAllPoints then count:ClearAllPoints() end
                count:SetPoint(countAnchor, slotFrame, countAnchor, countX, countY)
            end
            if slotFrame.ilvl then
                self:ApplyFont(slotFrame.ilvl, 12, "itemLevelFontSize", "OUTLINE", "itemLevelFont", "itemLevelFontOutline")
                if slotFrame.ilvl.ClearAllPoints then slotFrame.ilvl:ClearAllPoints() end
                slotFrame.ilvl:SetPoint(ilvlAnchor, slotFrame, ilvlAnchor, ilvlX, ilvlY)
            end
            if slotFrame.questIcon then
                if slotFrame.questIcon.SetSize then slotFrame.questIcon:SetSize(questSize, questSize) end
                if slotFrame.questIcon.ClearAllPoints then slotFrame.questIcon:ClearAllPoints() end
                slotFrame.questIcon:SetPoint(questAnchor, slotFrame, questAnchor, questX, questY)
            end
            if slotFrame.junkIcon then
                if slotFrame.junkIcon.SetSize then slotFrame.junkIcon:SetSize(junkSize, junkSize) end
                if slotFrame.junkIcon.ClearAllPoints then slotFrame.junkIcon:ClearAllPoints() end
                slotFrame.junkIcon:SetPoint(junkAnchor, slotFrame, junkAnchor, junkX, junkY)
            end
        end
    end
    if self.reagentGridSeparator and self.reagentGridSeparator.label then
        self:ApplyFont(self.reagentGridSeparator.label, 12, "categoryFontSize", "OUTLINE")
    end
end

function BagsMod:CreateHeaderBar()
    local header = CreateFrame("Frame", nil, self.mainFrame)
    header:SetHeight(28)
    header:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", self.mainFrame, "TOPRIGHT", -6, -6)
    self.headerBar = header

    -- Close Button (Native Blizzard vector atlas / texture, no tofu box)
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints(closeBtn)
    if closeTex.SetAtlas then
        closeTex:SetAtlas("common-icon-redx")
    else
        closeTex:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    end
    closeBtn:SetScript("OnEnter", function()
        closeTex:SetVertexColor(1, 0.4, 0.4, 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeTex:SetVertexColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnClick", function() self:CloseBags() end)

    -- Bag Settings Button (gear icon between + and x)
    local settingsBtn = CreateFrame("Button", nil, header)
    settingsBtn:SetSize(18, 18)
    settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    local gearTex = settingsBtn:CreateTexture(nil, "ARTWORK")
    gearTex:SetAllPoints(settingsBtn)
    local gearAtlasOk = false
    if gearTex.SetAtlas and _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo("GM-icon-settings") then
        gearAtlasOk = pcall(function() gearTex:SetAtlas("GM-icon-settings") end)
    end
    if not gearAtlasOk then
        gearTex:SetTexture("Interface\\WorldMap\\Gear_64Grey")
    end
    gearTex:SetVertexColor(0.7, 0.7, 0.7, 1)
    settingsBtn.icon = gearTex
    settingsBtn:SetScript("OnEnter", function()
        gearTex:SetVertexColor(0, 0.85, 1, 1)
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(settingsBtn, "ANCHOR_TOP")
            _G.GameTooltip:SetText(L["Bag Settings"] or "Bag Settings", 1, 1, 1)
            _G.GameTooltip:AddLine(L["Click to open RoithiUI Bag Settings."] or "Click to open RoithiUI Bag Settings.", 0.8, 0.8, 0.8, true)
            _G.GameTooltip:Show()
        end
    end)
    settingsBtn:SetScript("OnLeave", function()
        gearTex:SetVertexColor(0.7, 0.7, 0.7, 1)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    settingsBtn:SetScript("OnClick", function()
        if RoithiUI and RoithiUI.OpenSettings then
            RoithiUI:OpenSettings("bags")
        elseif LibStub and LibStub("AceConfigDialog-3.0", true) then
            local ACD = LibStub("AceConfigDialog-3.0", true)
            pcall(function() ACD:Open("RoithiUI") end)
            pcall(function() ACD:SelectGroup("RoithiUI", "general", "bags") end)
        end
    end)
    self.settingsBtn = settingsBtn

    -- Save Filter Button (+)
    local saveFilterBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    saveFilterBtn:SetSize(20, 20)
    saveFilterBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -6, 0)
    if saveFilterBtn.SetBackdrop then
        saveFilterBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        saveFilterBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
        saveFilterBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    end
    local plusText = saveFilterBtn:CreateFontString(nil, "OVERLAY")
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(plusText, "Friz Quadrata TT", 12, "OUTLINE")
    else
        plusText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    end
    plusText:SetJustifyH("CENTER")
    plusText:SetJustifyV("MIDDLE")
    plusText:SetPoint("CENTER", saveFilterBtn, "CENTER", 1, 0)
    plusText:SetText("+")
    plusText:SetTextColor(0.2, 0.8, 1.0, 1)
    saveFilterBtn.text = plusText
    self.saveFilterBtn = saveFilterBtn

    saveFilterBtn:SetScript("OnEnter", function(s)
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(s, "ANCHOR_TOP")
            _G.GameTooltip:SetText(L["Save Search as Category"], 1, 1, 1)
            _G.GameTooltip:AddLine(L["Save the current search query as a custom filter tab."], 0.8, 0.8, 0.8, true)
            _G.GameTooltip:Show()
        end
    end)
    saveFilterBtn:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    saveFilterBtn:SetScript("OnClick", function()
        self:SaveCurrentSearchFilter()
    end)

    -- Search Info / Guide Button (?)
    local infoBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    infoBtn:SetSize(20, 20)
    infoBtn:SetPoint("RIGHT", saveFilterBtn, "LEFT", -6, 0)
    if infoBtn.SetBackdrop then
        infoBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        infoBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
        infoBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
    end
    local infoText = infoBtn:CreateFontString(nil, "OVERLAY")
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(infoText, "Friz Quadrata TT", 11, "OUTLINE")
    else
        infoText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    end
    infoText:SetJustifyH("CENTER")
    infoText:SetJustifyV("MIDDLE")
    infoText:SetPoint("CENTER", infoBtn, "CENTER", 1, 0)
    infoText:SetText("?")
    infoText:SetTextColor(1, 0.82, 0.0, 1)
    infoBtn.text = infoText
    self.infoBtn = infoBtn

    local function ShowSearchGuide(owner)
        if not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(owner, "ANCHOR_TOPLEFT")
        _G.GameTooltip:SetText(L["Bag Search Syntax Guide"] or "Bag Search Syntax Guide", 1, 0.82, 0)
        _G.GameTooltip:AddLine(L["Combine tokens with spaces/and/&& (AND) or ,/or/|| (OR):"] or "Combine tokens with spaces/and/&& (AND) or ,/or/|| (OR):", 1, 1, 1)
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine("• |cffffd100name:text|r or |cffffd100text|r - " .. (L["Item name match"] or "Item name match"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100type:gear||weapon||armor||consumable||reagent|r", 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100bind:bop||boe||bou||account|r - " .. (L["Bind status"] or "Bind status"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100reagent:yes||no|r or |cffffd100reagents|r", 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100exp:tww||df||sl||bfa||classic|r - " .. (L["Expansion"] or "Expansion"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100quality:epic||rare||uncommon||poor|r or |cffffd100q:4|r", 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100ilvl:>600|r, |cffffd100ilvl:<550|r, |cffffd100ilvl:600-630|r", 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100boss:name|r, |cffffd100zone:name|r - " .. (L["Drop source"] or "Drop source"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100slot:finger|r, |cffffd100s:ring|r, |cffffd100s:13|r - " .. (L["Slot match"] or "Slot match"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100junk|r, |cffffd100new|r, |cffffd100fav|r - " .. (L["Shorthand flags"] or "Shorthand flags"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine("|cff00ff00" .. (L["Boolean OR:"] or "Boolean OR:") .. "|r |cffffffffring or trinket|r, |cffffffffcloth || leather|r, |cffffffffs:finger, s:trinket|r", 0.8, 0.8, 0.8)
        _G.GameTooltip:AddLine("|cff00ff00" .. (L["Boolean AND:"] or "Boolean AND:") .. "|r |cffffffffepic and gem|r, |cfffffffftype:gear quality:epic ilvl:>600|r", 0.8, 0.8, 0.8)
        _G.GameTooltip:AddLine("|cff00ff00" .. (L["Save:"] or "Save:") .. "|r |cffaaaaaa" .. (L["Click [+] to save as a custom category tab"] or "Click [+] to save as a custom category tab") .. "|r", 0.8, 0.8, 0.8)
        _G.GameTooltip:Show()
    end

    infoBtn:SetScript("OnEnter", function(s)
        infoBtn:SetBackdropBorderColor(1, 0.82, 0.0, 1.0)
        ShowSearchGuide(s)
    end)
    infoBtn:SetScript("OnLeave", function()
        infoBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)

    -- Search Box
    local search = CreateFrame("EditBox", "RoithiBagSearchBox", header, "BackdropTemplate")
    search:SetHeight(22)
    search:SetPoint("LEFT", header, "LEFT", 0, 0)
    search:SetPoint("RIGHT", infoBtn, "LEFT", -6, 0)
    if search.SetAutoFocus then search:SetAutoFocus(false) end
    if search.SetBackdrop then
        search:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        search:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        search:SetBackdropBorderColor(0.25, 0.25, 0.25, 1.0)
    end
    self:ApplyFont(search, 12, "searchFontSize", "")
    if search.SetTextInsets then search:SetTextInsets(6, 20, 0, 0) end
    if search.SetTextColor then search:SetTextColor(0.9, 0.9, 0.9, 1) end

    local placeholder = search:CreateFontString(nil, "OVERLAY")
    self:ApplyFont(placeholder, 12, "searchFontSize", "")
    placeholder:SetPoint("LEFT", search, "LEFT", 6, 0)
    placeholder:SetPoint("RIGHT", search, "RIGHT", -20, 0)
    placeholder:SetJustifyH("LEFT")
    if placeholder.SetWordWrap then placeholder:SetWordWrap(false) end
    placeholder:SetText(L["Search items (e.g. ring or trinket, type:gear)..."] or "Search items (e.g. ring or trinket, type:gear)...")
    placeholder:SetTextColor(0.5, 0.5, 0.5, 0.8)
    self.searchPlaceholder = placeholder

    -- Clear search field button (inside search field on the right)
    local clearBtn = CreateFrame("Button", "RoithiBagSearchClearButton", search)
    clearBtn:SetSize(14, 14)
    clearBtn:SetPoint("RIGHT", search, "RIGHT", -4, 0)
    local clearTex = clearBtn:CreateTexture(nil, "ARTWORK")
    clearTex:SetAllPoints(clearBtn)
    local clearAtlasOk = false
    if clearTex.SetAtlas and _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo("common-search-clear") then
        clearAtlasOk = pcall(function() clearTex:SetAtlas("common-search-clear") end)
    end
    if not clearAtlasOk then
        clearTex:SetTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    end
    clearTex:SetAlpha(0.6)
    clearBtn.icon = clearTex
    clearBtn:SetScript("OnEnter", function()
        clearTex:SetAlpha(1.0)
    end)
    clearBtn:SetScript("OnLeave", function()
        clearTex:SetAlpha(0.6)
    end)
    clearBtn:SetScript("OnClick", function()
        search:SetText("")
        if search.ClearFocus then search:ClearFocus() end
    end)
    clearBtn:Hide()
    self.searchClearButton = clearBtn

    search:SetScript("OnTextChanged", function(s)
        local txt = s:GetText() or ""
        self.searchText = txt
        if txt == "" then
            placeholder:Show()
            if self.searchClearButton then self.searchClearButton:Hide() end
        else
            placeholder:Hide()
            if self.searchClearButton then self.searchClearButton:Show() end
        end
        self:UpdateInventory()
    end)
    search:SetScript("OnEscapePressed", function(s)
        s:SetText("")
        s:ClearFocus()
    end)
    self.searchBox = search
end

function BagsMod:ClearSearch()
    if self.searchBox then
        self.searchBox:SetText("")
        if self.searchBox.ClearFocus then
            self.searchBox:ClearFocus()
        end
    else
        self.searchText = ""
        self:UpdateInventory()
    end
end

function BagsMod:RegisterPopups()
    if not _G.StaticPopupDialogs then return end

    _G.StaticPopupDialogs["ROITHI_RENAME_BAG_FILTER"] = {
        text = L["Rename Search Filter:"] or "Rename Search Filter:",
        button1 = _G.ACCEPT or "Accept",
        button2 = _G.CANCEL or "Cancel",
        hasEditBox = 1,
        maxLetters = 32,
        OnShow = function(selfDialog, data)
            local editBox = selfDialog.editBox or _G[selfDialog:GetName() .. "EditBox"]
            if editBox then
                editBox:SetText(data and data.name or "")
                editBox:HighlightText()
                editBox:SetFocus()
            end
        end,
        OnAccept = function(selfDialog, data)
            local editBox = selfDialog.editBox or _G[selfDialog:GetName() .. "EditBox"]
            local newName = editBox and editBox:GetText()
            if newName and newName ~= "" and data and data.id then
                self:RenameCustomFilter(data.id, newName)
            end
        end,
        EditBoxOnEnterPressed = function(selfEditBox, data)
            local parent = selfEditBox:GetParent()
            local newName = selfEditBox:GetText()
            if newName and newName ~= "" and data and data.id then
                self:RenameCustomFilter(data.id, newName)
            end
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(selfEditBox)
            selfEditBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    _G.StaticPopupDialogs["ROITHI_DELETE_BAG_FILTER"] = {
        text = L["Delete search filter '%s'?"] or "Delete search filter '%s'?",
        button1 = _G.YES or "Yes",
        button2 = _G.NO or "No",
        OnAccept = function(_, data)
            if data and data.id then
                self:DeleteCustomFilter(data.id)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    _G.StaticPopupDialogs["ROITHI_CONFIRM_SELL_CUSTOM_JUNK"] = {
        text = "%s",
        button1 = _G.YES or "Yes",
        button2 = _G.NO or "No",
        OnAccept = function(_, data)
            if data and data.onConfirm then
                data.onConfirm()
            end
        end,
        OnCancel = function(_, data)
            if data and data.onCancel then
                data.onCancel()
            end
        end,
        timeout = 0,
        whileDead = false,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function BagsMod:RenameCustomFilter(filterID, newName)
    if not self.db or not self.db.customFilters or not newName or newName == "" then return end
    for _, custom in ipairs(self.db.customFilters) do
        if custom.id == filterID then
            custom.name = newName
            break
        end
    end
    self:RebuildCategoryButtons()
    self:UpdateInventory()
    print("|cff00ff00[RoithiUI]|r " .. string.format(L["Renamed filter to '%s'"] or "Renamed filter to '%s'", newName))
end

function BagsMod:PromptRenameCustomFilter(filterID, currentName)
    if _G.StaticPopup_Show then
        _G.StaticPopup_Show("ROITHI_RENAME_BAG_FILTER", nil, nil, { id = filterID, name = currentName })
    end
end

function BagsMod:PromptDeleteCustomFilter(filterID, filterName)
    if _G.StaticPopup_Show then
        _G.StaticPopup_Show("ROITHI_DELETE_BAG_FILTER", filterName, nil, { id = filterID, name = filterName })
    else
        self:DeleteCustomFilter(filterID)
    end
end

function BagsMod:OpenCategoryContextMenu(owner, cat)
    if _G.MenuUtil and _G.MenuUtil.CreateContextMenu then
        _G.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            rootDescription:CreateTitle(cat.name)
            rootDescription:CreateButton(L["Rename"] or "Rename", function()
                self:PromptRenameCustomFilter(cat.id, cat.name)
            end)
            rootDescription:CreateButton("|cffff4444" .. (L["Delete"] or "Delete") .. "|r", function()
                self:PromptDeleteCustomFilter(cat.id, cat.name)
            end)
        end)
    else
        self:PromptDeleteCustomFilter(cat.id, cat.name)
    end
end

function BagsMod:OpenItemCategoryMenu(owner, itemDataOrID)
    if not itemDataOrID then return end
    local itemData = type(itemDataOrID) == "table" and itemDataOrID or { itemID = itemDataOrID }
    local currentCat = self:GetItemAssignedCategory(itemData)
    if currentCat == "WEAPONS" then currentCat = "GEAR" end
    local categories = {
        { id = "GEAR", name = L["Gear"] or "Gear" },
        { id = "CONSUMABLES", name = L["Consumables"] or "Consumables" },
        { id = "REAGENTS", name = L["Reagents"] or "Reagents" },
        { id = "QUEST", name = L["Quest"] or "Quest" },
        { id = "JUNK", name = L["Junk"] or "Junk" },
        { id = "MISC", name = L["Misc"] or "Misc" },
    }

    if _G.MenuUtil and _G.MenuUtil.CreateContextMenu then
        _G.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            rootDescription:CreateTitle(L["Assign Category"] or "Assign Category")
            for _, cat in ipairs(categories) do
                if rootDescription.CreateRadio then
                    rootDescription:CreateRadio(cat.name, function()
                        return currentCat == cat.id
                    end, function()
                        if currentCat == cat.id then
                            self:ResetItemCategory(itemData)
                        else
                            self:AssignItemCategory(itemData, cat.id)
                        end
                    end)
                else
                    local label = cat.name
                    if currentCat == cat.id then
                        label = "|cff00ff00* " .. label .. "|r"
                    end
                    rootDescription:CreateButton(label, function()
                        if currentCat == cat.id then
                            self:ResetItemCategory(itemData)
                        else
                            self:AssignItemCategory(itemData, cat.id)
                        end
                    end)
                end
            end
            if currentCat then
                rootDescription:CreateDivider()
                local resetText = (currentCat == "JUNK") and (L["Remove from Junk"] or "Remove from Junk") or (L["Reset to Default Category"] or "Reset to Default Category")
                rootDescription:CreateButton("|cffff8800" .. resetText .. "|r", function()
                    self:ResetItemCategory(itemData)
                end)
            end
        end)
    end
end

function BagsMod:SaveCurrentSearchFilter()
    local q = self.searchText or ""
    if q == "" then
        print("|cffff8800[RoithiUI]|r " .. (L["Please type a search query first to save it as a filter."] or "Please type a search query first to save it as a filter."))
        return
    end

    self.db.customFilters = self.db.customFilters or {}
    local timeSuffix = tostring(_G.GetTime and _G.GetTime() or (#self.db.customFilters + 1)):gsub("%.", "")
    local id = "CUSTOM_" .. timeSuffix
    table.insert(self.db.customFilters, {
        id = id,
        name = q,
        query = q,
    })
    self.db.activeCategory = id
    self:RebuildCategoryButtons()
    self:UpdateInventory()
    print("|cff00ff00[RoithiUI]|r " .. string.format(L["Saved search filter '%s'"] or "Saved search filter '%s'", q))
end

function BagsMod:DeleteCustomFilter(filterID)
    if not self.db or not self.db.customFilters then return end
    for idx, custom in ipairs(self.db.customFilters) do
        if custom.id == filterID then
            table.remove(self.db.customFilters, idx)
            break
        end
    end
    if self.db.activeCategory == filterID then
        self.db.activeCategory = "ALL"
    end
    self:RebuildCategoryButtons()
    self:UpdateInventory()
end

function BagsMod:RebuildCategoryButtons()
    if self.catContainer then
        self.catContainer:Hide()
        self.catContainer = nil
    end
    self.categoryButtons = {}
    self:CreateCategoryButtons()
end

function BagsMod:CreateCategoryButtons()
    if self.catContainer then return end

    local catContainer = CreateFrame("Frame", "RoithiBagCategoryContainer", self.mainFrame)
    catContainer:SetHeight(46)
    catContainer:SetPoint("TOPLEFT", self.headerBar, "BOTTOMLEFT", 0, -4)
    catContainer:SetPoint("TOPRIGHT", self.headerBar, "BOTTOMRIGHT", 0, -4)
    catContainer:SetFrameLevel(self.mainFrame:GetFrameLevel() + 5)
    catContainer:Show()
    self.catContainer = catContainer

    self.categoryButtons = {}
    local ordered = self:GetOrderedCategories()

    for _, cat in ipairs(ordered) do
        local btn = CreateFrame("Button", nil, catContainer, "BackdropTemplate")
        btn:SetFrameLevel(catContainer:GetFrameLevel() + 2)
        if btn.SetBackdrop then
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
        end

        local text = btn:CreateFontString(nil, "OVERLAY")
        self:ApplyFont(text, 12, "categoryFontSize", "OUTLINE")
        text:SetPoint("LEFT", btn, "LEFT", 2, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
        text:SetJustifyH("CENTER")
        if text.SetWordWrap then text:SetWordWrap(false) end
        text:SetText(cat.name)
        text:SetTextColor(0.8, 0.8, 0.8, 1)

        btn.catId = cat.id
        btn.isCustom = cat.isCustom
        btn.label = text

        if btn.RegisterForClicks then btn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        btn:SetScript("OnClick", function(b, button)
            local infoType, itemID, itemLink
            if _G.GetCursorInfo then
                infoType, itemID, itemLink = _G.GetCursorInfo()
            end
            if infoType == "item" and itemID then
                if cat.id ~= "ALL" and cat.id ~= "NEW" and cat.id ~= "FAVORITES" then
                    local targetKey = (cat.id == "JUNK" and (itemLink or itemID)) or itemID
                    self:AssignItemCategory(targetKey, cat.id)
                    if _G.ClearCursor then _G.ClearCursor() end
                    return
                end
            end

            if cat.isCustom then
                if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then
                    self:PromptRenameCustomFilter(cat.id, cat.name)
                    return
                end
                if button == "RightButton" then
                    self:OpenCategoryContextMenu(b, cat)
                    return
                end
            end
            self.db.activeCategory = cat.id
            self:UpdateCategoryButtonStyles()
            self:UpdateInventory()
        end)

        btn:SetScript("OnReceiveDrag", function()
            local infoType, itemID, itemLink
            if _G.GetCursorInfo then
                infoType, itemID, itemLink = _G.GetCursorInfo()
            end
            if infoType == "item" and itemID then
                if cat.id ~= "ALL" and cat.id ~= "NEW" and cat.id ~= "FAVORITES" then
                    local targetKey = (cat.id == "JUNK" and (itemLink or itemID)) or itemID
                    self:AssignItemCategory(targetKey, cat.id)
                    if _G.ClearCursor then _G.ClearCursor() end
                end
            end
        end)

        btn:SetScript("OnEnter", function()
            if self.db.activeCategory ~= cat.id then
                btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1.0)
            end
            if cat.isCustom and _G.GameTooltip then
                _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                _G.GameTooltip:SetText(cat.name, 1, 1, 1)
                _G.GameTooltip:AddLine((L["Query: "] or "Query: ") .. (cat.query or cat.name), 0.8, 0.8, 0.8)
                _G.GameTooltip:AddLine(" ")
                _G.GameTooltip:AddLine("|cff00ff00<Shift-Click to Rename Filter>|r", 0.2, 0.9, 0.2)
                _G.GameTooltip:AddLine("|cffff4444<Right-Click for Options / Delete>|r", 0.9, 0.4, 0.4)
                _G.GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            if self.db.activeCategory ~= cat.id then
                btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1.0)
            end
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)

        table.insert(self.categoryButtons, btn)
    end

    self:UpdateCategoryButtonsLayout()
end

function BagsMod:UpdateCategoryButtonsLayout(overrideW)
    if not self.catContainer or not self.categoryButtons or #self.categoryButtons == 0 then return end

    local totalW = overrideW or self.catContainer:GetWidth()
    if not totalW or totalW < 100 then
        local cols = self.db.columns or 10
        local slotSize = self.db.slotSize or 36
        local spacing = self.db.spacing or 4
        totalW = math.max(380, cols * slotSize + (cols - 1) * spacing)
    end

    local numButtons = #self.categoryButtons
    local btnSpacing = 3
    local minBtnW = 86
    local buttonsPerRow = math.max(2, math.floor((totalW + btnSpacing) / (minBtnW + btnSpacing)))
    local btnH = 22
    local btnW = math.floor((totalW - (buttonsPerRow - 1) * btnSpacing) / buttonsPerRow)

    for i, btn in ipairs(self.categoryButtons) do
        local col = (i - 1) % buttonsPerRow
        local row = math.floor((i - 1) / buttonsPerRow)
        local x = col * (btnW + btnSpacing)
        local y = -row * (btnH + btnSpacing)

        btn:ClearAllPoints()
        btn:SetSize(btnW, btnH)
        btn:SetPoint("TOPLEFT", self.catContainer, "TOPLEFT", x, y)
        if btn.label then
            btn.label:ClearAllPoints()
            btn.label:SetPoint("LEFT", btn, "LEFT", 2, 0)
            btn.label:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
            btn.label:SetJustifyH("CENTER")
            if btn.label.SetWordWrap then btn.label:SetWordWrap(false) end
        end
        btn:Show()
    end

    local totalRows = math.ceil(numButtons / buttonsPerRow)
    local totalCatH = totalRows * btnH + math.max(0, totalRows - 1) * btnSpacing
    self.catContainer:SetHeight(totalCatH)

    self:UpdateCategoryButtonStyles()
end

function BagsMod:UpdateCategoryButtonStyles()
    local active = self.db.activeCategory or "ALL"
    for _, btn in ipairs(self.categoryButtons) do
        if btn.catId == active then
            btn:SetBackdropColor(0.15, 0.35, 0.6, 0.9)
            btn:SetBackdropBorderColor(0.3, 0.6, 1.0, 1.0)
            if btn.label then btn.label:SetTextColor(1, 1, 1, 1) end
        else
            btn:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
            btn:SetBackdropBorderColor(0.22, 0.22, 0.22, 1.0)
            if btn.label then btn.label:SetTextColor(0.75, 0.75, 0.75, 1) end
        end
    end
end

function BagsMod:CreateFooterBar()
    local footer = CreateFrame("Frame", nil, self.mainFrame)
    footer:SetHeight(24)
    footer:SetPoint("BOTTOMLEFT", self.mainFrame, "BOTTOMLEFT", 6, 6)
    footer:SetPoint("BOTTOMRIGHT", self.mainFrame, "BOTTOMRIGHT", -6, 6)
    self.footerBar = footer

    -- Money Display (Interactive Widget with Wealth & Currency Breakdown)
    local moneyBtn = CreateFrame("Button", nil, footer)
    moneyBtn:SetHeight(20)
    moneyBtn:SetPoint("LEFT", footer, "LEFT", 2, 0)

    local moneyText = moneyBtn:CreateFontString(nil, "OVERLAY")
    self:ApplyFont(moneyText, 12, "goldFontSize", "OUTLINE")
    moneyText:SetPoint("LEFT", moneyBtn, "LEFT", 0, 0)
    self.moneyText = moneyText
    self.moneyButton = moneyBtn
    self.currencyButtons = {}
    self:UpdateMoneyDisplay()

    moneyBtn:SetScript("OnEnter", function(b)
        if not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(b, "ANCHOR_TOPLEFT")
        _G.GameTooltip:ClearLines()
        _G.GameTooltip:AddLine(L["Currency & Wealth"] or "Currency & Wealth", 1, 1, 1)
        _G.GameTooltip:AddLine(" ")

        local copper = _G.GetMoney and _G.GetMoney() or 0
        local gold = math.floor(copper / 10000)
        local silver = math.floor((copper % 10000) / 100)
        local cop = copper % 100
        local formattedGold = FormatNumberWithDots(gold)
        local charMoneyStr = string.format("|cffffd700%s|rg |cffc7c7cf%d|rs |cffeda55f%d|rc", formattedGold, silver, cop)
        _G.GameTooltip:AddDoubleLine(L["Character Gold"] or "Character Gold", charMoneyStr, 1, 0.82, 0, 1, 1, 1)

        if _G.C_Bank and _G.C_Bank.FetchDepositedMoney and _G.Enum and _G.Enum.BankType and _G.Enum.BankType.Account then
            local warbandCopper = _G.C_Bank.FetchDepositedMoney(_G.Enum.BankType.Account) or 0
            if warbandCopper > 0 then
                local wGold = math.floor(warbandCopper / 10000)
                local wSilver = math.floor((warbandCopper % 10000) / 100)
                local wCop = warbandCopper % 100
                local wFormattedGold = FormatNumberWithDots(wGold)
                local warbandMoneyStr = string.format("|cffffd700%s|rg |cffc7c7cf%d|rs |cffeda55f%d|rc", wFormattedGold, wSilver, wCop)
                _G.GameTooltip:AddDoubleLine(L["Warband Gold"] or "Warband Gold", warbandMoneyStr, 0, 0.8, 1, 1, 1, 1)
            end
        end

        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine(L["Click to toggle Currency tab."] or "Click to toggle Currency tab.", 0.2, 0.8, 1, true)
        _G.GameTooltip:Show()
    end)
    moneyBtn:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    moneyBtn:SetScript("OnClick", function()
        if _G.ToggleCharacter then
            _G.ToggleCharacter("TokenFrame")
        end
    end)

    -- Free Space Count
    local freeText = footer:CreateFontString(nil, "OVERLAY")
    self:ApplyFont(freeText, 12, "freeSlotsFontSize", "OUTLINE")
    freeText:SetPoint("RIGHT", footer, "RIGHT", -2, 0)
    self.freeText = freeText

    -- Clean / Sort Bags button
    local sortBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    sortBtn:SetSize(48, 20)
    sortBtn:SetPoint("RIGHT", freeText, "LEFT", -8, 0)
    if sortBtn.SetBackdrop then
        sortBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        sortBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        sortBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1.0)
    end
    local sortHl = sortBtn:CreateTexture(nil, "HIGHLIGHT")
    sortHl:SetAllPoints(sortBtn)
    sortHl:SetColorTexture(1, 1, 1, 0.15)
    sortBtn:SetHighlightTexture(sortHl)

    local sortText = sortBtn:CreateFontString(nil, "OVERLAY")
    self:ApplyFont(sortText, 11, nil, "OUTLINE")
    sortText:SetPoint("LEFT", sortBtn, "LEFT", 2, 0)
    sortText:SetPoint("RIGHT", sortBtn, "RIGHT", -2, 0)
    sortText:SetJustifyH("CENTER")
    sortText:SetText(L["Sort"])
    sortBtn:SetScript("OnClick", function()
        local now = _G.GetTime and _G.GetTime() or 0
        self.isSortingBagsUntil = now + 2.5
        if _G.C_Container and _G.C_Container.SortBags then
            _G.C_Container.SortBags()
        elseif _G.SortBags then
            _G.SortBags()
        end
    end)
    sortBtn:SetScript("OnEnter", function(b)
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        end
        if b.SetBackdropColor then
            b:SetBackdropColor(0.2, 0.2, 0.2, 0.95)
        end
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(b, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine(L["Cleanup Bags"] or "Cleanup Bags", 1, 1, 1)
            _G.GameTooltip:AddLine(L["Sort and organize items in your bags."] or "Sort and organize items in your bags.", 0.7, 0.7, 0.7, true)
            _G.GameTooltip:Show()
        end
    end)
    sortBtn:SetScript("OnLeave", function(b)
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(0.25, 0.25, 0.25, 1.0)
        end
        if b.SetBackdropColor then
            b:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        end
        if _G.GameTooltip then
            _G.GameTooltip:Hide()
        end
    end)
    self.sortButton = sortBtn

    -- Sell Junk Button (Visible at Vendor)
    local junkBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    junkBtn:SetSize(74, 20)
    junkBtn:SetPoint("RIGHT", sortBtn, "LEFT", -6, 0)
    if junkBtn.SetBackdrop then
        junkBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        junkBtn:SetBackdropColor(0.4, 0.1, 0.1, 0.8)
        junkBtn:SetBackdropBorderColor(0.8, 0.2, 0.2, 1.0)
    end
    local junkHl = junkBtn:CreateTexture(nil, "HIGHLIGHT")
    junkHl:SetAllPoints(junkBtn)
    junkHl:SetColorTexture(1, 1, 1, 0.15)
    junkBtn:SetHighlightTexture(junkHl)

    local junkText = junkBtn:CreateFontString(nil, "OVERLAY")
    self:ApplyFont(junkText, 11, nil, "OUTLINE")
    junkText:SetPoint("LEFT", junkBtn, "LEFT", 2, 0)
    junkText:SetPoint("RIGHT", junkBtn, "RIGHT", -2, 0)
    junkText:SetJustifyH("CENTER")
    junkText:SetText(L["Sell Junk"])
    junkBtn:SetScript("OnClick", function()
        self:SellAllJunk()
    end)
    junkBtn:SetScript("OnEnter", function(b)
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(1.0, 0.4, 0.4, 1.0)
        end
        if b.SetBackdropColor then
            b:SetBackdropColor(0.5, 0.15, 0.15, 0.95)
        end
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(b, "ANCHOR_TOP")
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine(L["Sell Junk"] or "Sell Junk", 1, 1, 1)
            _G.GameTooltip:AddLine(L["Automatically sell all poor quality (grey) items."] or "Automatically sell all poor quality (grey) items.", 0.7, 0.7, 0.7, true)
            _G.GameTooltip:Show()
        end
    end)
    junkBtn:SetScript("OnLeave", function(b)
        if b.SetBackdropBorderColor then
            b:SetBackdropBorderColor(0.8, 0.2, 0.2, 1.0)
        end
        if b.SetBackdropColor then
            b:SetBackdropColor(0.4, 0.1, 0.1, 0.8)
        end
        if _G.GameTooltip then
            _G.GameTooltip:Hide()
        end
    end)
    junkBtn:Hide()
    self.junkButton = junkBtn
end


function BagsMod:GetOrCreateCurrencyButton(index)
    self.currencyButtons = self.currencyButtons or {}
    if self.currencyButtons[index] then
        return self.currencyButtons[index]
    end

    local footer = self.footerBar
    if not footer then return nil end

    local btn = CreateFrame("Button", nil, footer)
    btn:SetHeight(20)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", btn, "LEFT", 0, 0)
    if icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.icon = icon

    local text = btn:CreateFontString(nil, "OVERLAY")
    self:ApplyFont(text, 12, "goldFontSize", "OUTLINE")
    text:SetPoint("LEFT", icon, "RIGHT", 3, 0)
    btn.text = text

    btn:SetScript("OnEnter", function(b)
        if not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(b, "ANCHOR_TOP")
        local showed = false
        if _G.GameTooltip.SetBackpackToken and b.tokenIndex then
            _G.GameTooltip:SetBackpackToken(b.tokenIndex)
            showed = true
        elseif _G.C_CurrencyInfo and _G.C_CurrencyInfo.GetCurrencyInfo and b.currencyID then
            local info = _G.C_CurrencyInfo.GetCurrencyInfo(b.currencyID)
            if info and info.name then
                _G.GameTooltip:SetText(info.name, 1, 1, 1)
                if info.description and info.description ~= "" then
                    _G.GameTooltip:AddLine(info.description, 0.8, 0.8, 0.8, true)
                end
                showed = true
            end
        end
        if not showed and b.currencyName then
            _G.GameTooltip:SetText(b.currencyName, 1, 1, 1)
            showed = true
        end
        if showed then
            if _G.TOKEN_REMOVE_FROM_BACKPACK_INSTRUCTION and _G.GameTooltip_AddInstructionLine then
                if _G.GameTooltip_AddBlankLineToTooltip then
                    _G.GameTooltip_AddBlankLineToTooltip(_G.GameTooltip)
                end
                _G.GameTooltip_AddInstructionLine(_G.GameTooltip, _G.TOKEN_REMOVE_FROM_BACKPACK_INSTRUCTION)
            end
            _G.GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)

    btn:SetScript("OnClick", function(b)
        if _G.IsModifiedClick and _G.IsModifiedClick("TOKENWATCHTOGGLE") and b.currencyID and _G.C_CurrencyInfo and _G.C_CurrencyInfo.SetCurrencyBackpackByID then
            _G.C_CurrencyInfo.SetCurrencyBackpackByID(b.currencyID, false)
            if self.UpdateMoneyDisplay then
                self:UpdateMoneyDisplay()
            end
            return
        end
        if _G.IsModifiedClick and _G.IsModifiedClick("CHATLINK") and b.currencyID and _G.C_CurrencyInfo and _G.C_CurrencyInfo.GetCurrencyLink and _G.HandleModifiedItemClick then
            local link = _G.C_CurrencyInfo.GetCurrencyLink(b.currencyID, b.quantity or 0)
            if link and _G.HandleModifiedItemClick(link) then
                return
            end
        end
        if _G.ToggleCharacter then
            _G.ToggleCharacter("TokenFrame")
        end
    end)

    self.currencyButtons[index] = btn
    return btn
end

function BagsMod:UpdateBackpackCurrencies()
    if not self.footerBar then return end

    local prevAnchor = self.moneyButton
    local maxTokens = 5
    local lastBtn = nil

    for i = 1, maxTokens do
        local cInfo = nil
        if _G.C_CurrencyInfo and _G.C_CurrencyInfo.GetBackpackCurrencyInfo then
            cInfo = _G.C_CurrencyInfo.GetBackpackCurrencyInfo(i)
        end

        if cInfo and cInfo.name then
            local btn = self:GetOrCreateCurrencyButton(i)
            if btn then
                btn.tokenIndex = i
                btn.currencyID = cInfo.currencyTypesID
                btn.currencyName = cInfo.name
                btn.quantity = cInfo.quantity

                if btn.icon and btn.icon.SetTexture then
                    btn.icon:SetTexture(cInfo.iconFileID)
                end

                local countStr = FormatNumberWithDots(cInfo.quantity or 0)
                if btn.text and btn.text.SetText then
                    self:ApplyFont(btn.text, 12, "goldFontSize", "OUTLINE")
                    btn.text:SetText(countStr)
                end

                local textW = (btn.text and btn.text.GetStringWidth and btn.text:GetStringWidth()) or 24
                if btn.SetWidth then
                    btn:SetWidth(14 + 3 + textW)
                end

                if btn.ClearAllPoints and btn.SetPoint then
                    btn:ClearAllPoints()
                    if prevAnchor == self.moneyButton then
                        btn:SetPoint("LEFT", prevAnchor, "RIGHT", 8, 0)
                    else
                        btn:SetPoint("LEFT", prevAnchor, "RIGHT", 6, 0)
                    end
                end
                if btn.Show then
                    btn:Show()
                end
                prevAnchor = btn
                lastBtn = btn
            end
        else
            if self.currencyButtons and self.currencyButtons[i] and self.currencyButtons[i].Hide then
                self.currencyButtons[i]:Hide()
            end
        end
    end

    self.lastCurrencyButton = lastBtn
end

function BagsMod:UpdateMoneyDisplay()
    if not self.moneyText then return end
    local copper = _G.GetMoney and _G.GetMoney() or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    local formattedGold = FormatNumberWithDots(gold)
    self.moneyText:SetText(string.format("|cffffd700%s|rg |cffc7c7cf%d|rs |cffeda55f%d|rc", formattedGold, silver, cop))
    if self.moneyButton and self.moneyText.GetStringWidth then
        self.moneyButton:SetWidth(math.max(40, self.moneyText:GetStringWidth() + 4))
    end
    self:UpdateBackpackCurrencies()
end

function BagsMod:OnMerchantShow()
    if self.junkButton then self.junkButton:Show() end
    if self.db.autoSellJunk then
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0.1, function()
                if _G.MerchantFrame and _G.MerchantFrame:IsShown() then
                    self:SellAllJunk()
                end
            end)
        else
            self:SellAllJunk()
        end
    end
end

function BagsMod:OnMerchantClosed()
    if self.junkButton then self.junkButton:Hide() end
    if self.sellingJunkTicker then
        self.sellingJunkTicker:Cancel()
        self.sellingJunkTicker = nil
    end
    if _G.StaticPopup_Hide then
        _G.StaticPopup_Hide("ROITHI_CONFIRM_SELL_CUSTOM_JUNK")
    end
end

function BagsMod:PromptSellCustomJunk(customQueue, customItemDisplay, customItemCounts)
    if not customQueue or #customQueue == 0 then return end

    local lines = {}
    local maxDisplay = 5
    for i = 1, math.min(#customItemDisplay, maxDisplay) do
        local display = customItemDisplay[i]
        local count = customItemCounts[display.itemID] or 1
        local line = "• " .. tostring(display.link or display.itemID)
        if count > 1 then
            line = line .. " (x" .. count .. ")"
        end
        table.insert(lines, line)
    end
    if #customItemDisplay > maxDisplay then
        local remaining = #customItemDisplay - maxDisplay
        table.insert(lines, string.format(L["... and %d more custom item(s)"] or "... and %d more custom item(s)", remaining))
    end

    local itemsText = table.concat(lines, "\n")
    local template = L["The following custom items are marked as Junk and will be sold:\n\n%s\n\nDo you want to sell them? (Their Junk status will be reset)"]
        or "The following custom items are marked as Junk and will be sold:\n\n%s\n\nDo you want to sell them? (Their Junk status will be reset)"
    local promptText = string.format(template, itemsText)

    local data = {
        onConfirm = function()
            self:ExecuteSellQueue(customQueue, true)
        end,
    }

    if _G.StaticPopup_Show then
        _G.StaticPopup_Show("ROITHI_CONFIRM_SELL_CUSTOM_JUNK", promptText, nil, data)
    else
        data.onConfirm()
    end
end

function BagsMod:ExecuteSellQueue(queue, isCustom, onFinished)
    if not queue or #queue == 0 then
        if onFinished then onFinished() end
        return
    end

    local totalCopper = 0
    local totalItems = 0
    local resetItemIDs = {}

    for _, item in ipairs(queue) do
        totalItems = totalItems + (item.count or 1)
        totalCopper = totalCopper + ((item.price or 0) * (item.count or 1))
    end

    local queueIndex = 1
    local function ProcessNext()
        if _G.InCombatLockdown and _G.InCombatLockdown() then
            if self.sellingJunkTicker then
                self.sellingJunkTicker:Cancel()
                self.sellingJunkTicker = nil
            end
            return
        end
        if not _G.MerchantFrame or not _G.MerchantFrame:IsShown() then
            if self.sellingJunkTicker then
                self.sellingJunkTicker:Cancel()
                self.sellingJunkTicker = nil
            end
            return
        end

        local item = queue[queueIndex]
        if item then
            local currentID = nil
            if _G.C_Container and _G.C_Container.GetContainerItemID then
                currentID = _G.C_Container.GetContainerItemID(item.bag, item.slot)
            elseif _G.GetContainerItemID then
                currentID = _G.GetContainerItemID(item.bag, item.slot)
            end

            -- Guard: verify slot still holds the expected junk item before selling
            if (not item.itemID or currentID == item.itemID) and currentID ~= nil then
                if _G.C_Container and _G.C_Container.UseContainerItem then
                    pcall(_G.C_Container.UseContainerItem, item.bag, item.slot)
                elseif _G.UseContainerItem then
                    pcall(_G.UseContainerItem, item.bag, item.slot)
                end
                if isCustom then
                    resetItemIDs[item.itemID or 0] = true
                    self:ResetItemCategory(item)
                end
            end
            queueIndex = queueIndex + 1
        end

        if queueIndex > #queue then
            if self.sellingJunkTicker then
                self.sellingJunkTicker:Cancel()
                self.sellingJunkTicker = nil
            end
            if isCustom and next(resetItemIDs) then
                self:UpdateInventory()
            end
            if totalItems > 0 then
                local gold = math.floor(totalCopper / 10000)
                local silver = math.floor((totalCopper % 10000) / 100)
                local cop = totalCopper % 100
                local formattedGold = FormatNumberWithDots(gold)
                local moneyStr = string.format("|cffffd700%s|rg |cffc7c7cf%d|rs |cffeda55f%d|rc", formattedGold, silver, cop)
                local msg
                if isCustom then
                    msg = string.format(L["Sold %d custom junk item%s for %s and reset their Junk status."] or "Sold %d custom junk item%s for %s and reset their Junk status.", totalItems, totalItems == 1 and "" or "s", moneyStr)
                else
                    msg = string.format(L["Sold %d junk item%s for %s."] or "Sold %d junk item%s for %s.", totalItems, totalItems == 1 and "" or "s", moneyStr)
                end
                print("|cff00ccff[RoithiUI]|r " .. msg)
            end
            if onFinished then
                onFinished()
            end
        end
    end

    self.ProcessNextJunk = ProcessNext

    if _G.C_Timer and _G.C_Timer.NewTicker then
        self.sellingJunkTicker = _G.C_Timer.NewTicker(0.15, ProcessNext, #queue)
    else
        while queueIndex <= #queue do
            ProcessNext()
        end
    end
end

function BagsMod:SellAllJunk()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    if self.sellingJunkTicker then
        self.sellingJunkTicker:Cancel()
        self.sellingJunkTicker = nil
    end

    local nativeQueue = {}
    local customQueue = {}
    local customItemCounts = {}
    local customItemDisplay = {}

    for _, bag in ipairs(self:GetScannableBags()) do
        local numSlots = self:GetNumBagSlots(bag)
        for slot = 1, numSlots do
            local itemInfo = self:GetItemInfoAt(bag, slot)
            if itemInfo and itemInfo.itemID then
                local isFav = self.db and self.db.favorites and self.db.favorites[itemInfo.itemID]
                if not isFav then
                    local price = 0
                    local itemLink = itemInfo.link or (_G.C_Container and _G.C_Container.GetContainerItemLink and _G.C_Container.GetContainerItemLink(bag, slot))
                    if itemLink and _G.C_Item and _G.C_Item.GetItemInfo then
                        local _, _, _, _, _, _, _, _, _, _, sellPrice = _G.C_Item.GetItemInfo(itemLink)
                        price = sellPrice or 0
                    elseif itemLink and _G.GetItemInfo then
                        local _, _, _, _, _, _, _, _, _, _, sellPrice = _G.GetItemInfo(itemLink)
                        price = sellPrice or 0
                    elseif itemInfo.itemID and _G.GetItemInfo then
                        local _, _, _, _, _, _, _, _, _, _, sellPrice = _G.GetItemInfo(itemInfo.itemID)
                        price = sellPrice or 0
                    end

                    local canSell = (price > 0)
                    if not canSell and _G.C_Container and _G.C_Container.GetContainerItemInfo then
                        local cInfo = _G.C_Container.GetContainerItemInfo(bag, slot)
                        if cInfo and cInfo.hasNoValue == false then
                            canSell = true
                        end
                    end

                    if canSell then
                        local count = itemInfo.count or 1
                        local customCat = self:GetItemAssignedCategory(itemInfo)
                        if customCat == "JUNK" or (itemInfo.quality ~= 0 and self:IsItemJunk(itemInfo)) then
                            table.insert(customQueue, {
                                bag = bag,
                                slot = slot,
                                itemID = itemInfo.itemID,
                                itemGUID = itemInfo.itemGUID,
                                link = itemLink or itemInfo.link or itemInfo.name or ("item:" .. itemInfo.itemID),
                                count = count,
                                price = price,
                                isCustomJunk = true,
                                name = itemInfo.name or itemLink or ("item:" .. itemInfo.itemID),
                            })
                            local displayKey = itemInfo.itemGUID or itemLink or itemInfo.itemID
                            if not customItemCounts[displayKey] then
                                customItemCounts[displayKey] = 0
                                table.insert(customItemDisplay, {
                                    itemID = itemInfo.itemID,
                                    link = itemLink or itemInfo.name or ("item:" .. itemInfo.itemID),
                                })
                            end
                            customItemCounts[displayKey] = customItemCounts[displayKey] + count
                        elseif itemInfo.quality == 0 and not customCat then
                            table.insert(nativeQueue, {
                                bag = bag,
                                slot = slot,
                                itemID = itemInfo.itemID,
                                itemGUID = itemInfo.itemGUID,
                                count = count,
                                price = price,
                                isCustomJunk = false,
                            })
                        end
                    end
                end
            end
        end
    end

    local function StartCustomJunkPrompt()
        if #customQueue == 0 then return end
        self:PromptSellCustomJunk(customQueue, customItemDisplay, customItemCounts)
    end

    -- Priority 1: Native Blizzard C_MerchantFrame engine API (Dragonflight/TWW/Midnight)
    if _G.C_MerchantFrame and _G.C_MerchantFrame.SellAllJunkItems then
        local numJunk = (_G.C_MerchantFrame.GetNumJunkItems and _G.C_MerchantFrame.GetNumJunkItems()) or #nativeQueue
        if numJunk > 0 then
            _G.C_MerchantFrame.SellAllJunkItems()
            local msg = string.format(L["Sold %d junk item%s."] or "Sold %d junk item%s.", numJunk, numJunk == 1 and "" or "s")
            print("|cff00ccff[RoithiUI]|r " .. msg)
        end
        StartCustomJunkPrompt()
        return
    end

    -- Priority 2: Graceful fallback sell queue (Classic / legacy clients)
    if #nativeQueue == 0 and #customQueue == 0 then return end

    if #nativeQueue > 0 then
        self:ExecuteSellQueue(nativeQueue, false, function()
            StartCustomJunkPrompt()
        end)
    else
        StartCustomJunkPrompt()
    end
end

function BagsMod:OnSlotEnter(s)
    if not s then return end
    if s.bag and s.slot then
        local slotKey = GetSlotKey(s.bag, s.slot)
        local hasTradeTimer = self:HasActiveTradeTimer(s.bag, s.slot)
        local isNew = self:IsSlotNew(s.bag, s.slot, s.itemInfo)

        if isNew then
            self.dismissedNewHighlights = self.dismissedNewHighlights or {}
            self.dismissedNewHighlights[slotKey] = true
            if s.newOverlay then
                s.newOverlay:Hide()
            end

            if not hasTradeTimer then
                self.hoveredNewSlots = self.hoveredNewSlots or {}
                if not self.hoveredNewSlots[slotKey] then
                    local retentionMinutes = (self.db and self.db.newItemRetentionTimer) or 20
                    if retentionMinutes < 1 then retentionMinutes = 1 elseif retentionMinutes > 240 then retentionMinutes = 240 end
                    local now = _G.GetTime and _G.GetTime() or 0
                    self.hoveredNewSlots[slotKey] = now + (retentionMinutes * 60)
                    self.newSlots = self.newSlots or {}
                    self.newSlots[slotKey] = true
                end
                if s.itemData then
                    s.itemData.isNew = true
                end
            end
        else
            if s.newOverlay then
                s.newOverlay:Hide()
            end
        end
    end

    s.isRoithiBagSlot = true
    if s.bag and s.slot and _G.GameTooltip then
        _G.GameTooltip.roithiBagSlot = s
        _G.GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        local hasItem = false
        if _G.C_Container and _G.C_Container.GetContainerItemInfo then
            _G.GameTooltip:SetBagItem(s.bag, s.slot)
            hasItem = (s.itemData and s.itemData.itemID ~= nil)
        elseif s.itemData and s.itemData.link and _G.GameTooltip.SetHyperlink then
            _G.GameTooltip:SetHyperlink(s.itemData.link)
            hasItem = true
        end

        local itemID = (s.itemData and s.itemData.itemID)
            or (_G.C_Container and _G.C_Container.GetContainerItemID and _G.C_Container.GetContainerItemID(s.bag, s.slot))
            or (_G.GetContainerItemID and _G.GetContainerItemID(s.bag, s.slot))

        if hasItem and itemID then
            AppendBagShortcuts(_G.GameTooltip, itemID)
        end
        _G.GameTooltip:Show()
    end

    if _G.C_Container and _G.C_Container.ShowContainerSellCursor and _G.MerchantFrame and _G.MerchantFrame:IsShown() and s.bag and s.slot then
        _G.C_Container.ShowContainerSellCursor(s.bag, s.slot)
    end
end

function BagsMod:AcquireItemSlot(index)
    if self.itemSlots[index] then
        return self.itemSlots[index]
    end

    if _G.InCombatLockdown and _G.InCombatLockdown() then
        return nil
    end

    self:CreateMainBagFrame()

    local slotParent = CreateFrame("Frame", nil, self.mainFrame)
    local size = self.db.slotSize or 36
    slotParent:SetSize(size, size)

    local template = "ContainerFrameItemButtonTemplate"
    local slot = CreateFrame("ItemButton", "RoithiBagSlot" .. index, slotParent, template)
    slot:SetAllPoints(slotParent)
    slot.slotParent = slotParent

    -- Strip Blizzard template emptyBackground atlas and textures so empty slots never show native slot artwork
    slot.emptyBackgroundAtlas = nil
    slot.emptyBackgroundTexture = nil
    slot.GetItemButtonBackgroundTexture = function() return nil, false end
    slot.UpdateQuestItem = function() end

    -- Override SetItemButtonTexture to prevent native ItemButtonTemplate from falling back to emptyBackgroundAtlas
    slot.SetItemButtonTexture = function(s, texture)
        local iconTex = s.icon or s.Icon
        if not iconTex then return end
        if texture and texture ~= "" then
            if iconTex.SetTexture then iconTex:SetTexture(texture) end
            iconTex:Show()
        else
            if iconTex.SetAtlas then iconTex:SetAtlas(nil) end
            if iconTex.SetTexture then iconTex:SetTexture(nil) end
            iconTex:Hide()
        end
    end

    if slot.ExtendedSlot then
        slot.ExtendedSlot:SetAlpha(0)
        if slot.ExtendedSlot.Hide then slot.ExtendedSlot:Hide() end
    end

    slotParent:SetFrameLevel(self.mainFrame:GetFrameLevel() + 5)
    slot:SetFrameLevel(slotParent:GetFrameLevel() + 1)

    if not slot.SetBackdrop and _G.BackdropTemplateMixin then
        Mixin(slot, _G.BackdropTemplateMixin)
    end
    if slot.SetBackdrop then
        slot:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        })
        slot:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    end

    -- Icon texture (fills slot, border overlays on top)
    local icon = slot.icon or slot.Icon or (slot.GetName and _G[slot:GetName() .. "IconTexture"])
    if not icon then
        icon = slot:CreateTexture(nil, "ARTWORK")
    end
    if icon.ClearAllPoints then icon:ClearAllPoints() end
    if icon.SetPoint then
        icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    end
    slot.icon = icon
    slot.Icon = icon
    if slot.IconMask and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture, icon, slot.IconMask)
    end
    if slot.CircleMask and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture, icon, slot.CircleMask)
    end
    if icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- Suppress Blizzard native borders, slots, and quality overlays to eliminate double borders
    if slot.IconBorder then
        slot.IconBorder:SetAlpha(0)
        if slot.IconBorder.Hide then slot.IconBorder:Hide() end
    end
    local norm = slot.GetNormalTexture and slot:GetNormalTexture()
    if norm then
        if norm.SetTexture then norm:SetTexture(nil) end
        if norm.SetAlpha then norm:SetAlpha(0) end
        if norm.Hide then norm:Hide() end
    end
    if slot.NormalTexture then
        if slot.NormalTexture.SetTexture then slot.NormalTexture:SetTexture(nil) end
        if slot.NormalTexture.SetAlpha then slot.NormalTexture:SetAlpha(0) end
        if slot.NormalTexture.Hide then slot.NormalTexture:Hide() end
    end
    for _, region in ipairs({ slot:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") and region ~= icon then
            local tex = region.GetTexture and region:GetTexture()
            local atlas = region.GetAtlas and region:GetAtlas()
            local str = (type(tex) == "string" and tex or "") .. (type(atlas) == "string" and atlas or "")
            local sLower = str:lower()
            if sLower:find("border") or sLower:find("normal") or sLower:find("slot") or sLower:find("glow") or sLower:find("ring") or sLower:find("itemslotbackground") then
                region:SetAlpha(0)
                if region.SetTexture then region:SetTexture(nil) end
                if region.Hide then region:Hide() end
            end
        end
    end

    -- Cooldown swirl and text (hidden by default to avoid GPU swipe evaluations)
    local cooldown = slot.Cooldown or slot.cooldown
    if not cooldown then
        cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        cooldown:SetAllPoints(slot)
        cooldown:SetFrameLevel(slot:GetFrameLevel() + 2)
        if cooldown.SetDrawEdge then cooldown:SetDrawEdge(true) end
        if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
        if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
        slot.Cooldown = cooldown
        slot.cooldown = cooldown
    end
    if cooldown.Hide then cooldown:Hide() end

    -- 1px overlay border to guarantee border renders above the icon
    if not slot.roithiBorder then
        local border = CreateFrame("Frame", nil, slot, "BackdropTemplate")
        border:SetAllPoints(slot)
        border:SetFrameLevel(slot:GetFrameLevel() + 5)
        border:EnableMouse(false)
        border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        border:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
        slot.roithiBorder = border

        if not slot.roithiBorderHooked and hooksecurefunc then
            hooksecurefunc(slot, "SetBackdropBorderColor", function(s, r, g, b, a)
                if s.roithiBorder and s.roithiBorder.SetBackdropBorderColor then
                    s.roithiBorder:SetBackdropBorderColor(r, g, b, a)
                end
            end)
            slot.roithiBorderHooked = true
        end
    end

    -- Count text
    local count = slot.Count or slot.count
    local countAnchor = (self.db and self.db.itemCountAnchor) or "BOTTOMRIGHT"
    local countX = (self.db and self.db.itemCountX) or -2
    local countY = (self.db and self.db.itemCountY) or 2
    if not count then
        count = slot:CreateFontString(nil, "OVERLAY")
        count:SetPoint(countAnchor, slot, countAnchor, countX, countY)
    else
        if count.ClearAllPoints then count:ClearAllPoints() end
        count:SetPoint(countAnchor, slot, countAnchor, countX, countY)
    end
    slot.count = count
    slot.Count = count
    self:ApplyFont(count, 12, "itemCountFontSize", "OUTLINE", "itemCountFont", "itemCountFontOutline")

    -- Item level text
    local ilvl = slot.ilvl
    local ilvlAnchor = (self.db and self.db.itemLevelAnchor) or "TOPLEFT"
    local ilvlX = (self.db and self.db.itemLevelX) or 2
    local ilvlY = (self.db and self.db.itemLevelY) or -2
    if not ilvl then
        ilvl = slot:CreateFontString(nil, "OVERLAY")
        ilvl:SetPoint(ilvlAnchor, slot, ilvlAnchor, ilvlX, ilvlY)
        ilvl:SetTextColor(1, 0.82, 0, 1)
        slot.ilvl = ilvl
    else
        if ilvl.ClearAllPoints then ilvl:ClearAllPoints() end
        ilvl:SetPoint(ilvlAnchor, slot, ilvlAnchor, ilvlX, ilvlY)
    end
    self:ApplyFont(ilvl, 12, "itemLevelFontSize", "OUTLINE", "itemLevelFont", "itemLevelFontOutline")

    -- Favorite star indicator (Texture atlas, zero tofu box)
    local fav = slot.fav
    if not fav then
        fav = slot:CreateTexture(nil, "OVERLAY")
        fav:SetSize(14, 14)
        fav:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -1, -1)
        if fav.SetAtlas then
            fav:SetAtlas("auctionhouse-icon-favorite")
        else
            fav:SetTexture("Interface\\Common\\Reputation-Star")
        end
        slot.fav = fav
    end

    -- New item highlight overlay
    local newOverlay = slot.newOverlay
    if not newOverlay then
        newOverlay = slot:CreateTexture(nil, "OVERLAY")
        newOverlay:SetAllPoints(slot)
        newOverlay:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        newOverlay:SetBlendMode("BLEND")
        newOverlay:SetAlpha(0.4)
        newOverlay:Hide()
        slot.newOverlay = newOverlay
    end

    -- Quest indicator icon (clean exclamation mark)
    local questIcon = slot.questIcon
    local qSize = (self.db and self.db.questIndicatorSize) or 16
    local qAnchor = (self.db and self.db.questIndicatorAnchor) or "BOTTOMLEFT"
    local qX = (self.db and self.db.questIndicatorX) or 1
    local qY = (self.db and self.db.questIndicatorY) or 1
    if not questIcon then
        questIcon = slot:CreateTexture(nil, "OVERLAY", nil, 6)
        questIcon:Hide()
        slot.questIcon = questIcon
    end
    questIcon:SetSize(qSize, qSize)
    if questIcon.ClearAllPoints then questIcon:ClearAllPoints() end
    questIcon:SetPoint(qAnchor, slot, qAnchor, qX, qY)

    -- Cosmetic indicator icon
    local cosmeticIcon = slot.cosmeticIcon
    if not cosmeticIcon then
        cosmeticIcon = slot:CreateTexture(nil, "OVERLAY", nil, 6)
        cosmeticIcon:Hide()
        slot.cosmeticIcon = cosmeticIcon
    end
    cosmeticIcon:SetSize(14, 14)
    if cosmeticIcon.ClearAllPoints then cosmeticIcon:ClearAllPoints() end
    cosmeticIcon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
    if cosmeticIcon.SetAtlas then
        cosmeticIcon:SetAtlas("transmog-icon-ui")
    end

    -- Junk indicator icon (bags-junkcoin)
    local junkIcon = slot.junkIcon
    local jSize = (self.db and self.db.junkIndicatorSize) or 14
    local jAnchor = (self.db and self.db.junkIndicatorAnchor) or "BOTTOMLEFT"
    local jX = (self.db and self.db.junkIndicatorX) or 1
    local jY = (self.db and self.db.junkIndicatorY) or 1
    if not junkIcon then
        junkIcon = slot:CreateTexture(nil, "OVERLAY", nil, 6)
        junkIcon:Hide()
        slot.junkIcon = junkIcon
    end
    junkIcon:SetSize(jSize, jSize)
    if junkIcon.ClearAllPoints then junkIcon:ClearAllPoints() end
    junkIcon:SetPoint(jAnchor, slot, jAnchor, jX, jY)
    if junkIcon.SetAtlas then
        junkIcon:SetAtlas("bags-junkcoin")
    else
        junkIcon:SetTexture("Interface\\Icons\\inv_misc_coin_01")
    end

    -- Stop and disable unused Blizzard animation groups from ContainerFrameItemButtonTemplate
    if slot.newitemglowAnim then
        slot.newitemglowAnim:Stop()
        if slot.newitemglowAnim.SetLooping then slot.newitemglowAnim:SetLooping("NONE") end
    end
    if slot.flashAnim and slot.flashAnim.Stop then slot.flashAnim:Stop() end
    if slot.AugmentBorderAnim and slot.AugmentBorderAnim.Stop then slot.AugmentBorderAnim:Stop() end

    -- Hide and clear unused Blizzard decorative textures to eliminate overdraw
    if slot.NewItemTexture then
        if slot.NewItemTexture.SetTexture then slot.NewItemTexture:SetTexture(nil) end
        slot.NewItemTexture:Hide()
    end
    if slot.BattlepayItemTexture then
        if slot.BattlepayItemTexture.SetTexture then slot.BattlepayItemTexture:SetTexture(nil) end
        slot.BattlepayItemTexture:Hide()
    end
    if slot.BagIndicator then
        if slot.BagIndicator.SetTexture then slot.BagIndicator:SetTexture(nil) end
        slot.BagIndicator:Hide()
    end
    if slot.ExtendedSlot then
        if slot.ExtendedSlot.SetTexture then slot.ExtendedSlot:SetTexture(nil) end
        slot.ExtendedSlot:Hide()
    end
    if slot.UpgradeIcon then
        if slot.UpgradeIcon.SetTexture then slot.UpgradeIcon:SetTexture(nil) end
        slot.UpgradeIcon:Hide()
    end
    if slot.flash then
        if slot.flash.SetTexture then slot.flash:SetTexture(nil) end
        slot.flash:Hide()
    end
    if slot.AugmentBorderAnimTexture then
        if slot.AugmentBorderAnimTexture.SetTexture then slot.AugmentBorderAnimTexture:SetTexture(nil) end
        slot.AugmentBorderAnimTexture:Hide()
    end
    if slot.IconQuestTexture then
        if slot.IconQuestTexture.SetTexture then slot.IconQuestTexture:SetTexture(nil) end
        slot.IconQuestTexture:Hide()
    end
    if slot.JunkIcon and slot.JunkIcon ~= slot.junkIcon then
        if slot.JunkIcon.SetTexture then slot.JunkIcon:SetTexture(nil) end
        slot.JunkIcon:Hide()
    end
    if slot.searchOverlay then slot.searchOverlay:Hide() end
    if slot.ItemContextOverlay then slot.ItemContextOverlay:Hide() end
    if slot.IconOverlay then slot.IconOverlay:Hide() end
    if slot.IconOverlay2 then slot.IconOverlay2:Hide() end
    if slot.SetScript then
        slot:SetScript("OnEvent", nil)
    end

    slot.UpdateNewItem = function(s)
        if not s.itemData then
            if s.NewItemTexture then s.NewItemTexture:Hide() end
            if s.BattlepayItemTexture then s.BattlepayItemTexture:Hide() end
            if s.newitemglowAnim and s.newitemglowAnim.Stop then s.newitemglowAnim:Stop() end
            if s.flashAnim and s.flashAnim.Stop then s.flashAnim:Stop() end
            if s.AugmentBorderAnim and s.AugmentBorderAnim.Stop then s.AugmentBorderAnim:Stop() end
            if s.newOverlay then s.newOverlay:Hide() end
            return
        end
        if s.newOverlay then
            if self:ShouldShowNewHighlight(s.bag, s.slot, s.itemData) then
                s.newOverlay:Show()
            else
                s.newOverlay:Hide()
            end
        end
        if s.NewItemTexture then s.NewItemTexture:Hide() end
        if s.BattlepayItemTexture then s.BattlepayItemTexture:Hide() end
        if s.newitemglowAnim and s.newitemglowAnim.Stop then s.newitemglowAnim:Stop() end
        if s.flashAnim and s.flashAnim.Stop then s.flashAnim:Stop() end
        if s.AugmentBorderAnim and s.AugmentBorderAnim.Stop then s.AugmentBorderAnim:Stop() end
    end

    -- Click & Drag handling
    if slot.RegisterForClicks then slot:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    if slot.RegisterForDrag then slot:RegisterForDrag("LeftButton") end

    local function HandlePickup(s, doPickup)
        if s.bag and s.slot then
            local itemData = s.itemData or self:GetItemInfoAt(s.bag, s.slot)
            if itemData and itemData.itemID then
                local slotKey = GetSlotKey(s.bag, s.slot)
                local now = _G.GetTime and _G.GetTime() or 0
                local wasNew = (self.newSlots and self.newSlots[slotKey] == true)
                    or (self.hoveredNewSlots and self.hoveredNewSlots[slotKey] and now < self.hoveredNewSlots[slotKey])
                    or (_G.C_NewItems and _G.C_NewItems.IsNewItem and _G.C_NewItems.IsNewItem(s.bag, s.slot))
                self.draggedItemInfo = {
                    itemID = itemData.itemID,
                    count = itemData.count or 1,
                    fromBag = s.bag,
                    fromSlot = s.slot,
                    fromSlotKey = slotKey,
                    time = now,
                    isNew = wasNew and true or false,
                }
            end
            self:ClearNewSlot(s.bag, s.slot)
            if s.newOverlay then s.newOverlay:Hide() end
            if doPickup then
                if _G.C_Container and _G.C_Container.PickupContainerItem then
                    _G.C_Container.PickupContainerItem(s.bag, s.slot)
                elseif _G.PickupContainerItem then
                    _G.PickupContainerItem(s.bag, s.slot)
                end
            end
        end
    end

    if slot.HookScript then
        slot:HookScript("PreClick", function(s, button)
            if button == "RightButton" then
                if _G.IsShiftKeyDown and _G.IsShiftKeyDown() and s.itemData and s.itemData.itemID then
                    self:OpenItemCategoryMenu(s, s.itemData)
                elseif _G.IsAltKeyDown and _G.IsAltKeyDown() and s.itemData and s.itemData.itemID then
                    self.db.favorites = self.db.favorites or {}
                    self.db.favorites[s.itemData.itemID] = not self.db.favorites[s.itemData.itemID]
                    self:UpdateInventory()
                end
            end
        end)
        slot:HookScript("OnDragStart", function(s)
            HandlePickup(s, false)
        end)
    end

    if not slot:GetScript("OnClick") then
        slot:SetScript("OnClick", function(s, button)
            if button == "LeftButton" then
                HandlePickup(s, true)
            elseif button == "RightButton" then
                if _G.IsShiftKeyDown and _G.IsShiftKeyDown() and s.itemData and s.itemData.itemID then
                    self:OpenItemCategoryMenu(s, s.itemData)
                elseif _G.IsAltKeyDown and _G.IsAltKeyDown() and s.itemData and s.itemData.itemID then
                    self.db.favorites = self.db.favorites or {}
                    self.db.favorites[s.itemData.itemID] = not self.db.favorites[s.itemData.itemID]
                    self:UpdateInventory()
                else
                    if s.bag and s.slot then
                        if _G.C_Container and _G.C_Container.UseContainerItem then
                            pcall(_G.C_Container.UseContainerItem, s.bag, s.slot)
                        elseif _G.UseContainerItem then
                            pcall(_G.UseContainerItem, s.bag, s.slot)
                        end
                    end
                end
            end
        end)
    end

    if not slot:GetScript("OnDragStart") then
        slot:SetScript("OnDragStart", function(s) HandlePickup(s, true) end)
    end
    if not slot:GetScript("OnReceiveDrag") then
        slot:SetScript("OnReceiveDrag", function(s) HandlePickup(s, true) end)
    end


    -- Neutralize Blizzard's ContainerFrameItemButtonMixin.OnUpdate / UpdateTooltip to prevent
    -- GameTooltip from being re-anchored away from ANCHOR_RIGHT and having lines wiped on next frame.
    slot.UpdateTooltip = function() end
    slot:SetScript("OnUpdate", nil)

    slot:SetScript("OnEnter", function(s)
        self:OnSlotEnter(s)
    end)
    slot:SetScript("OnLeave", function(s)
        if _G.GameTooltip then
            _G.GameTooltip.roithiBagSlot = nil
            _G.GameTooltip:Hide()
        end
        if _G.ResetCursor then
            _G.ResetCursor()
        end
    end)

    self.itemSlots[index] = slot
    return slot
end

function BagsMod:UpdateInventory()
    if not self.mainFrame or not self.mainFrame:IsShown() then return end

    if not self.initialInventoryScanned then
        self:ScanInventoryOnce(true)
    end

    self.cachedAllItems = self.cachedAllItems or {}
    self.cachedDisplaySlots = self.cachedDisplaySlots or {}
    self.cachedNormalSlots = self.cachedNormalSlots or {}
    self.cachedReagentSlots = self.cachedReagentSlots or {}
    self.slotEntryPool = self.slotEntryPool or {}

    local wipeTable = _G.wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
    wipeTable(self.cachedAllItems)
    wipeTable(self.cachedDisplaySlots)
    wipeTable(self.cachedNormalSlots)
    wipeTable(self.cachedReagentSlots)

    local allItems = self.cachedAllItems
    local displaySlots = self.cachedDisplaySlots
    local normalDisplaySlots = self.cachedNormalSlots
    local reagentDisplaySlots = self.cachedReagentSlots
    local entryPool = self.slotEntryPool
    local entryIndex = 0

    local function AllocSlotEntry(b, s, data)
        entryIndex = entryIndex + 1
        local entry = entryPool[entryIndex]
        if not entry then
            entry = {}
            entryPool[entryIndex] = entry
        end
        entry.bag = b
        entry.slot = s
        entry.itemData = data
        return entry
    end

    local totalSlots = 0
    local freeSlots = 0
    local activeCat = self.db.activeCategory or "ALL"

    local reagentBagID = (_G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag) or 5
    local keyringID = (_G.KEYRING_CONTAINER or -2)

    local now = _G.GetTime and _G.GetTime() or 0
    local isSorting = self.isSortingBagsUntil and now < self.isSortingBagsUntil
    local isTeleporting = self.teleportGraceUntil and now < self.teleportGraceUntil

    -- Take snapshots of previous state for cross-slot move and total count detection
    local prevKnownSlots = {}
    local prevKnownCounts = {}
    local prevNewSlots = {}
    local prevItemCounts = {}

    if self.knownSlots then
        for k, v in pairs(self.knownSlots) do
            prevKnownSlots[k] = v
        end
    end
    if self.knownSlotCounts then
        for k, v in pairs(self.knownSlotCounts) do
            prevKnownCounts[k] = v
        end
    end
    if self.newSlots then
        for k, v in pairs(self.newSlots) do
            prevNewSlots[k] = v
        end
    end
    for k, itemID in pairs(prevKnownSlots) do
        local count = prevKnownCounts[k] or 1
        prevItemCounts[itemID] = (prevItemCounts[itemID] or 0) + count
    end

    -- Pre-pass: scan current contents of all scannable bags to detect vacated slots and current item counts
    local currentSlotItems = {}
    local currentItemCounts = {}
    for _, bag in ipairs(self:GetScannableBags()) do
        local numSlots = self:GetNumBagSlots(bag)
        for slot = 1, numSlots do
            local slotKey = GetSlotKey(bag, slot)
            local itemInfo = self:GetItemInfoAt(bag, slot)
            if itemInfo and itemInfo.itemID then
                currentSlotItems[slotKey] = itemInfo
                currentItemCounts[itemInfo.itemID] = (currentItemCounts[itemInfo.itemID] or 0) + (itemInfo.count or 1)
            else
                currentSlotItems[slotKey] = false
            end
        end
    end

    -- Find all slots that previously held itemID but now do not (vacated / moved / swapped)
    local vacatedSlotsByItemID = {}
    for sKey, oldID in pairs(prevKnownSlots) do
        local curr = currentSlotItems[sKey]
        if not curr or curr.itemID ~= oldID then
            if not vacatedSlotsByItemID[oldID] then
                vacatedSlotsByItemID[oldID] = {}
            end
            table.insert(vacatedSlotsByItemID[oldID], {
                slotKey = sKey,
                wasNew = (prevNewSlots[sKey] == true),
                count = prevKnownCounts[sKey] or 1,
            })
        end
    end

    for _, bag in ipairs(self:GetScannableBags()) do
        local isReagentBag = (bag == reagentBagID)
        local isKeyringBag = (bag == keyringID)
        local isNormalBag = (not isReagentBag and not isKeyringBag)

        local numSlots = self:GetNumBagSlots(bag)

        if activeCat == "ALL" then
            if isNormalBag or isReagentBag then
                totalSlots = totalSlots + numSlots
            end
        elseif activeCat == "REAGENTS" then
            if isReagentBag then
                totalSlots = totalSlots + numSlots
            end
        elseif activeCat == "KEYRING" then
            if isKeyringBag then
                totalSlots = totalSlots + numSlots
            end
        else
            if isNormalBag then
                totalSlots = totalSlots + numSlots
            end
        end

        for slot = 1, numSlots do
            local slotKey = GetSlotKey(bag, slot)
            local itemInfo = currentSlotItems[slotKey] or self:GetItemInfoAt(bag, slot)
            if itemInfo and itemInfo.itemID then
                local isTradeableBoP = false
                if (itemInfo.quality or 0) >= 2 and (itemInfo.bindType == 1 or itemInfo.bindType == 4 or not itemInfo.bindType) then
                    isTradeableBoP = self:HasActiveTradeTimer(bag, slot)
                end

                local prevID = prevKnownSlots[slotKey]
                local isNewSlot = false

                -- Check if this slot was just filled by user drag
                local isSlotChanged = (prevID ~= itemInfo.itemID)
                local isFromDrag = false
                local draggedItemWasNew = false
                if isSlotChanged and self.draggedItemInfo and (now - self.draggedItemInfo.time) <= 3.0 and self.draggedItemInfo.itemID == itemInfo.itemID then
                    if self.draggedItemInfo.fromSlotKey ~= slotKey then
                        isFromDrag = true
                        draggedItemWasNew = (self.draggedItemInfo.isNew == true)
                        self.draggedItemInfo = nil
                    end
                end

                -- Check if this item was moved/swapped/split from another slot in inventory
                local isMovedItem = false
                local movedWasNew = false
                if isSlotChanged then
                    local vacatedList = vacatedSlotsByItemID[itemInfo.itemID]
                    if vacatedList and #vacatedList > 0 then
                        local vac = table.remove(vacatedList, 1)
                        isMovedItem = true
                        if vac.wasNew then
                            movedWasNew = true
                        end
                    end
                end

                if isTradeableBoP then
                    isNewSlot = true
                elseif self.newSlots[slotKey] then
                    isNewSlot = true
                elseif self.hoveredNewSlots and self.hoveredNewSlots[slotKey] and now < self.hoveredNewSlots[slotKey] then
                    isNewSlot = true
                elseif isFromDrag then
                    if draggedItemWasNew then
                        isNewSlot = true
                    end
                elseif isMovedItem then
                    -- Moved items inherit new status if and only if they were already new
                    if movedWasNew then
                        isNewSlot = true
                    end
                elseif _G.C_NewItems and _G.C_NewItems.IsNewItem and _G.C_NewItems.IsNewItem(bag, slot) then
                    isNewSlot = true
                elseif self.initialInventoryScanned and not isSorting and not isTeleporting and isSlotChanged then
                    -- Fallback for newly acquired items (boss drop, vendor buy, quest reward):
                    -- Must NOT be an already-known item whose total count in inventory did not increase!
                    local prevTotal = prevItemCounts[itemInfo.itemID] or 0
                    local currentTotal = currentItemCounts[itemInfo.itemID] or (itemInfo.count or 1)
                    if prevTotal == 0 then
                        -- Item was never seen in inventory before -> truly new acquisition
                        isNewSlot = true
                    elseif currentTotal > prevTotal then
                        -- Total count increased (e.g. duplicate boss drop)
                        if (itemInfo.maxStack or 1) == 1 then
                            isNewSlot = true
                        end
                    end
                end

                -- Junk items (poor quality or custom assigned junk) are strictly never marked as new
                if isNewSlot and self.IsItemJunk and self:IsItemJunk(itemInfo) then
                    isNewSlot = false
                end

                if isNewSlot then
                    self.newSlots[slotKey] = true
                    itemInfo.isNew = true
                else
                    self.newSlots[slotKey] = nil
                    itemInfo.isNew = false
                end

                if prevID and prevID ~= itemInfo.itemID then
                    if self.dismissedNewHighlights then
                        self.dismissedNewHighlights[slotKey] = nil
                    end
                    if self.hoveredNewSlots then
                        self.hoveredNewSlots[slotKey] = nil
                    end
                    if self.tradeTimerCache then
                        self.tradeTimerCache[slotKey] = nil
                    end
                end
                self.knownSlots[slotKey] = itemInfo.itemID
                self.knownSlotCounts = self.knownSlotCounts or {}
                self.knownSlotCounts[slotKey] = itemInfo.count or 1
                self.knownItemIDs[itemInfo.itemID] = true
                table.insert(allItems, itemInfo)
            else
                if not isTeleporting then
                    self.knownSlots[slotKey] = nil
                    if self.knownSlotCounts then self.knownSlotCounts[slotKey] = nil end
                end
                self.newSlots[slotKey] = nil
                if self.tradeTimerCache then self.tradeTimerCache[slotKey] = nil end
                if self.hoveredNewSlots then self.hoveredNewSlots[slotKey] = nil end
                if self.dismissedNewHighlights then self.dismissedNewHighlights[slotKey] = nil end
                if _G.C_NewItems and _G.C_NewItems.RemoveNewItem then
                    pcall(_G.C_NewItems.RemoveNewItem, bag, slot)
                end
                if (activeCat == "ALL" and (isNormalBag or isReagentBag))
                    or (activeCat == "REAGENTS" and isReagentBag)
                    or (activeCat == "KEYRING" and isKeyringBag)
                    or (activeCat ~= "ALL" and activeCat ~= "REAGENTS" and activeCat ~= "KEYRING" and isNormalBag) then
                    freeSlots = freeSlots + 1
                end
            end

            if activeCat == "ALL" then
                if isNormalBag then
                    table.insert(normalDisplaySlots, AllocSlotEntry(bag, slot, itemInfo))
                elseif isReagentBag then
                    table.insert(reagentDisplaySlots, AllocSlotEntry(bag, slot, itemInfo))
                end
            elseif activeCat == "REAGENTS" then
                if isNormalBag then
                    if itemInfo and itemInfo.itemID and self:ItemMatchesCategory(itemInfo, activeCat) then
                        table.insert(normalDisplaySlots, AllocSlotEntry(bag, slot, itemInfo))
                        totalSlots = totalSlots + 1
                    end
                elseif isReagentBag then
                    table.insert(reagentDisplaySlots, AllocSlotEntry(bag, slot, itemInfo))
                end
            elseif activeCat == "KEYRING" then
                if isKeyringBag then
                    table.insert(displaySlots, AllocSlotEntry(bag, slot, itemInfo))
                end
            else
                if itemInfo and itemInfo.itemID and self:ItemMatchesCategory(itemInfo, activeCat) then
                    table.insert(displaySlots, AllocSlotEntry(bag, slot, itemInfo))
                end
            end
        end
    end

    local numNormal = 0
    local numReagent = 0
    if activeCat == "ALL" or activeCat == "REAGENTS" then
        for _, entry in ipairs(normalDisplaySlots) do
            table.insert(displaySlots, entry)
        end
        numNormal = #normalDisplaySlots
        for _, entry in ipairs(reagentDisplaySlots) do
            table.insert(displaySlots, entry)
        end
        numReagent = #reagentDisplaySlots
    end
    self.lastNumNormalReagents = (activeCat == "REAGENTS") and numNormal or nil

    if self.freeText then
        local freeStr = string.format("%d / %d %s", freeSlots, totalSlots, L["Free"])
        if self.lastFreeText ~= freeStr then
            self.freeText:SetText(freeStr)
            self.lastFreeText = freeStr
        end
    end
    self:UpdateMoneyDisplay()

    local cols = self.db.columns or 10
    local slotSize = self.db.slotSize or 36
    local spacing = self.db.spacing or 4

    local numDisplay = #displaySlots
    local isSplitCategory = (activeCat == "ALL" or activeCat == "REAGENTS")
    local normalRows = isSplitCategory and (numNormal > 0 and math.max(1, math.ceil(numNormal / cols)) or 0) or math.max(1, math.ceil(numDisplay / cols))
    local normalGridH = (normalRows > 0) and (normalRows * slotSize + (normalRows - 1) * spacing) or 0

    local reagentGap = (isSplitCategory and numReagent > 0 and numNormal > 0) and 20 or 0
    local reagentRows = (isSplitCategory and numReagent > 0) and math.ceil(numReagent / cols) or 0
    local reagentGridH = (reagentRows > 0) and (reagentRows * slotSize + (reagentRows - 1) * spacing) or 0

    local gridW = cols * slotSize + (cols - 1) * spacing
    local frameW = math.max(380, gridW + 16)
    if self.UpdateCategoryButtonsLayout then
        self:UpdateCategoryButtonsLayout(frameW - 12)
    end
    local catH = (self.catContainer and self.catContainer:GetHeight()) or 46
    local headerH = 28 + catH + 12
    local footerH = 24 + 8
    local gridH = normalGridH + reagentGap + reagentGridH
    if gridH < slotSize then gridH = slotSize end
    local frameH = headerH + gridH + footerH + 16

    if isSplitCategory and numReagent > 0 and numNormal > 0 then
        if not self.reagentGridSeparator then
            local sep = CreateFrame("Frame", nil, self.mainFrame)
            sep:SetHeight(16)
            local line = sep:CreateTexture(nil, "ARTWORK")
            line:SetHeight(1)
            line:SetPoint("LEFT", sep, "LEFT", 0, 0)
            line:SetPoint("RIGHT", sep, "RIGHT", 0, 0)
            line:SetColorTexture(0.3, 0.3, 0.35, 0.8)
            sep.line = line

            local label = sep:CreateFontString(nil, "OVERLAY")
            self:ApplyFont(label, 12, "categoryFontSize", "OUTLINE")
            label:SetPoint("LEFT", sep, "LEFT", 4, 0)
            label:SetText(L["Reagents"] or "Reagents")
            label:SetTextColor(0.2, 0.8, 1, 0.9)
            sep.label = label
            self.reagentGridSeparator = sep
        end
        local sepY = -(headerH + normalGridH + 2)
        self.reagentGridSeparator:ClearAllPoints()
        self.reagentGridSeparator:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 8, sepY)
        self.reagentGridSeparator:SetWidth(gridW)
        if not self.reagentGridSeparator:IsShown() then self.reagentGridSeparator:Show() end
    else
        if self.reagentGridSeparator and self.reagentGridSeparator:IsShown() then
            self.reagentGridSeparator:Hide()
        end
    end

    if self.db then
        self.db.bagWindow = self.db.bagWindow or {}
        self.db.bagWindow.width = frameW
        self.db.bagWindow.height = frameH
    end

    self.mainFrame:SetSize(frameW, frameH)

    local isSearching = (self.searchText and self.searchText ~= "")

    for i = 1, numDisplay do
        local entry = displaySlots[i]
        local slotFrame = self:AcquireItemSlot(i)
        if slotFrame then
            local parent = slotFrame.slotParent or slotFrame
            if slotFrame.lastSlotSize ~= slotSize then
                parent:SetSize(slotSize, slotSize)
                slotFrame.lastSlotSize = slotSize
            end

            local x, y
            if isSplitCategory and i > numNormal then
                local relIdx = i - numNormal
                local col = (relIdx - 1) % cols
                local row = math.floor((relIdx - 1) / cols)
                x = 8 + col * (slotSize + spacing)
                y = -(headerH + normalGridH + reagentGap + row * (slotSize + spacing))
            else
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                x = 8 + col * (slotSize + spacing)
                y = -(headerH + row * (slotSize + spacing))
            end

            if slotFrame.lastX ~= x or slotFrame.lastY ~= y then
                parent:ClearAllPoints()
                parent:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", x, y)
                slotFrame.lastX = x
                slotFrame.lastY = y
            end

            if not parent:IsShown() then parent:Show() end
            if not slotFrame:IsShown() then slotFrame:Show() end

            slotFrame:SetID(entry.slot or 0)
            if slotFrame.slotParent then
                slotFrame.slotParent:SetID(entry.bag or 0)
            end

            slotFrame.bag = entry.bag
            slotFrame.slot = entry.slot
            slotFrame.itemData = entry.itemData

            local itemData = entry.itemData
            if itemData then
                if slotFrame.IconBorder and slotFrame.IconBorder:IsShown() then
                    slotFrame.IconBorder:SetAlpha(0)
                    slotFrame.IconBorder:Hide()
                end
                local normTex = slotFrame.GetNormalTexture and slotFrame:GetNormalTexture()
                if type(normTex) == "table" and normTex.IsShown and normTex:IsShown() then
                    if normTex.SetTexture then normTex:SetTexture(nil) end
                    if normTex.SetAlpha then normTex:SetAlpha(0) end
                    if normTex.Hide then normTex:Hide() end
                end
                local isMatch = true
                if isSearching then
                    isMatch = self:MatchesSearchQuery(itemData, self.searchText)
                end

                local tex = itemData.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
                if slotFrame.lastTexture ~= tex then
                    if slotFrame.SetItemButtonTexture then
                        slotFrame:SetItemButtonTexture(tex)
                    end
                    local iconTex = slotFrame.icon or slotFrame.Icon
                    if iconTex then
                        iconTex:SetTexture(tex)
                    end
                    slotFrame.lastTexture = tex
                end
                local iconTex = slotFrame.icon or slotFrame.Icon
                if iconTex and not iconTex:IsShown() then
                    iconTex:Show()
                end

                local targetAlpha = (isSearching and not isMatch) and 0.2 or 1.0
                if slotFrame.lastAlpha ~= targetAlpha then
                    slotFrame:SetAlpha(targetAlpha)
                    slotFrame.lastAlpha = targetAlpha
                end
                if iconTex and iconTex.SetDesaturated then
                    local desat = (isSearching and not isMatch)
                    if slotFrame.lastDesat ~= desat then
                        iconTex:SetDesaturated(desat)
                        slotFrame.lastDesat = desat
                    end
                end

                local br, bg, bb, ba
                if isSearching and not isMatch then
                    br, bg, bb, ba = 0.15, 0.15, 0.15, 0.5
                elseif isSearching then
                    br, bg, bb, ba = 1.0, 0.82, 0.0, 1.0
                elseif itemData.showQuestBang or itemData.showQuestBorder or itemData.isQuest or (itemData.classID == 12) then
                    br, bg, bb, ba = 1.0, 0.85, 0.0, 1.0
                else
                    local qc = QUALITY_COLORS[itemData.quality or 1] or QUALITY_COLORS[1]
                    if self.db.qualityBorders ~= false then
                        br, bg, bb, ba = qc.r, qc.g, qc.b, 1.0
                    else
                        br, bg, bb, ba = 0.2, 0.2, 0.2, 1.0
                    end
                end
                if slotFrame.lastBorderR ~= br or slotFrame.lastBorderG ~= bg or slotFrame.lastBorderB ~= bb or slotFrame.lastBorderA ~= ba then
                    slotFrame:SetBackdropBorderColor(br, bg, bb, ba)
                    slotFrame.lastBorderR, slotFrame.lastBorderG, slotFrame.lastBorderB, slotFrame.lastBorderA = br, bg, bb, ba
                end

                -- Count
                local countText = slotFrame.count or slotFrame.Count
                if countText then
                    if itemData.count and itemData.count > 1 then
                        local countStr = tostring(itemData.count)
                        if slotFrame.lastCountText ~= countStr then
                            countText:SetText(countStr)
                            slotFrame.lastCountText = countStr
                        end
                        if not countText:IsShown() then countText:Show() end
                    else
                        if slotFrame.lastCountText ~= nil then
                            countText:SetText("")
                            slotFrame.lastCountText = nil
                        end
                        if countText:IsShown() then countText:Hide() end
                    end
                end

                -- Item Level
                if slotFrame.ilvl then
                    if self.db.showItemLevel and itemData.itemLevel and itemData.itemLevel > 1 and (itemData.classID == 2 or itemData.classID == 4) then
                        local ilvlStr = tostring(itemData.itemLevel)
                        if slotFrame.lastIlvlText ~= ilvlStr then
                            slotFrame.ilvl:SetText(ilvlStr)
                            slotFrame.lastIlvlText = ilvlStr
                        end
                        if self.db.colorItemLevelByQuality ~= false and itemData.quality and QUALITY_COLORS[itemData.quality] then
                            local qc = QUALITY_COLORS[itemData.quality]
                            slotFrame.ilvl:SetTextColor(qc.r, qc.g, qc.b, 1)
                        else
                            slotFrame.ilvl:SetTextColor(1, 0.82, 0, 1)
                        end
                        if not slotFrame.ilvl:IsShown() then slotFrame.ilvl:Show() end
                    else
                        if slotFrame.lastIlvlText ~= nil then
                            slotFrame.ilvl:SetText("")
                            slotFrame.lastIlvlText = nil
                        end
                        if slotFrame.ilvl:IsShown() then slotFrame.ilvl:Hide() end
                    end
                end

                -- Favorites indicator
                if slotFrame.fav then
                    local favs = self.db.favorites or {}
                    if favs[itemData.itemID] then
                        if not slotFrame.fav:IsShown() then slotFrame.fav:Show() end
                    else
                        if slotFrame.fav:IsShown() then slotFrame.fav:Hide() end
                    end
                end

                -- New item highlight
                if slotFrame.newOverlay then
                    if self:ShouldShowNewHighlight(slotFrame.bag, slotFrame.slot, itemData) then
                        if not slotFrame.newOverlay:IsShown() then slotFrame.newOverlay:Show() end
                    else
                        if slotFrame.newOverlay:IsShown() then slotFrame.newOverlay:Hide() end
                    end
                end

                -- Stop any background animations on active slot
                if slotFrame.NewItemTexture and slotFrame.NewItemTexture:IsShown() then slotFrame.NewItemTexture:Hide() end
                if slotFrame.BattlepayItemTexture and slotFrame.BattlepayItemTexture:IsShown() then slotFrame.BattlepayItemTexture:Hide() end
                if slotFrame.newitemglowAnim and slotFrame.newitemglowAnim.Stop then slotFrame.newitemglowAnim:Stop() end
                if slotFrame.flashAnim and slotFrame.flashAnim.Stop then slotFrame.flashAnim:Stop() end
                if slotFrame.IconQuestTexture and slotFrame.IconQuestTexture:IsShown() then
                    slotFrame.IconQuestTexture:Hide()
                end

                -- Quest indicator (clean exclamation mark without squashed box/border)
                if slotFrame.questIcon then
                    local isQuest = itemData.showQuestBang or itemData.showQuestBorder or itemData.isQuest or (itemData.classID == 12)
                    if isQuest then
                        local questTex = "Interface\\GossipFrame\\AvailableQuestIcon"
                        slotFrame.questIcon:SetTexture(questTex)
                        if slotFrame.questIcon.SetTexCoord then
                            slotFrame.questIcon:SetTexCoord(0, 1, 0, 1)
                        end
                        local qSize = (self.db and self.db.questIndicatorSize) or 16
                        local qAnchor = (self.db and self.db.questIndicatorAnchor) or "BOTTOMLEFT"
                        local qX = (self.db and self.db.questIndicatorX) or 1
                        local qY = (self.db and self.db.questIndicatorY) or 1
                        if slotFrame.questIcon.SetSize then slotFrame.questIcon:SetSize(qSize, qSize) end
                        if slotFrame.questIcon.ClearAllPoints then slotFrame.questIcon:ClearAllPoints() end
                        slotFrame.questIcon:SetPoint(qAnchor, slotFrame, qAnchor, qX, qY)
                        if not slotFrame.questIcon:IsShown() then slotFrame.questIcon:Show() end
                    else
                        if slotFrame.questIcon:IsShown() then slotFrame.questIcon:Hide() end
                    end
                end

                -- Cosmetic indicator (shows on cosmetic items that can be learned)
                if slotFrame.cosmeticIcon then
                    local isCosmetic = false
                    if itemData and (itemData.hyperlink or itemData.itemID) then
                        if _G.C_Item and _G.C_Item.IsCosmeticItem then
                            local ok, cosmetic = pcall(_G.C_Item.IsCosmeticItem, itemData.hyperlink or itemData.itemID)
                            if ok and cosmetic then
                                isCosmetic = true
                            end
                        end
                    end
                    local isLearnable = false
                    if isCosmetic and itemData.itemID then
                        if _G.C_TransmogCollection and _G.C_TransmogCollection.PlayerHasTransmog then
                            local ok, hasTransmog = pcall(_G.C_TransmogCollection.PlayerHasTransmog, itemData.itemID)
                            if ok and not hasTransmog then
                                isLearnable = true
                            end
                        else
                            isLearnable = true
                        end
                    end

                    if isCosmetic and isLearnable then
                        if not slotFrame.cosmeticIcon:IsShown() then slotFrame.cosmeticIcon:Show() end
                    else
                        if slotFrame.cosmeticIcon:IsShown() then slotFrame.cosmeticIcon:Hide() end
                    end
                end

                -- Junk indicator (gold coin for poor quality or custom junk items)
                if slotFrame.junkIcon then
                    local isJunk = (self.db.showJunkIndicator ~= false) and self:IsItemJunk(itemData)
                    if isJunk then
                        local jSize = (self.db and self.db.junkIndicatorSize) or 14
                        local jAnchor = (self.db and self.db.junkIndicatorAnchor) or "BOTTOMLEFT"
                        local jX = (self.db and self.db.junkIndicatorX) or 1
                        local jY = (self.db and self.db.junkIndicatorY) or 1
                        if slotFrame.junkIcon.SetSize then slotFrame.junkIcon:SetSize(jSize, jSize) end
                        if slotFrame.junkIcon.ClearAllPoints then slotFrame.junkIcon:ClearAllPoints() end
                        slotFrame.junkIcon:SetPoint(jAnchor, slotFrame, jAnchor, jX, jY)
                        if not slotFrame.junkIcon:IsShown() then slotFrame.junkIcon:Show() end
                    else
                        if slotFrame.junkIcon:IsShown() then slotFrame.junkIcon:Hide() end
                    end
                end

                self:UpdateSlotCooldown(slotFrame)
                slotFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
            else
                -- Empty slot
                if slotFrame.junkIcon and slotFrame.junkIcon:IsShown() then slotFrame.junkIcon:Hide() end
                if slotFrame.cosmeticIcon and slotFrame.cosmeticIcon:IsShown() then slotFrame.cosmeticIcon:Hide() end
                if slotFrame.questIcon and slotFrame.questIcon:IsShown() then slotFrame.questIcon:Hide() end
                if slotFrame.IconBorder and slotFrame.IconBorder:IsShown() then
                    slotFrame.IconBorder:SetAlpha(0)
                    slotFrame.IconBorder:Hide()
                end
                local normEmpty = slotFrame.GetNormalTexture and slotFrame:GetNormalTexture()
                if type(normEmpty) == "table" and normEmpty.IsShown and normEmpty:IsShown() then
                    if normEmpty.SetTexture then normEmpty:SetTexture(nil) end
                    if normEmpty.SetAlpha then normEmpty:SetAlpha(0) end
                    if normEmpty.Hide then normEmpty:Hide() end
                end
                local iconTex = slotFrame.icon or slotFrame.Icon
                if iconTex then
                    if iconTex.SetDesaturated then iconTex:SetDesaturated(false) end
                    if iconTex.SetVertexColor then iconTex:SetVertexColor(1, 1, 1, 1) end
                    if iconTex.SetAtlas then iconTex:SetAtlas(nil) end
                    if iconTex.SetTexture then iconTex:SetTexture(nil) end
                    if iconTex:IsShown() then iconTex:Hide() end
                end
                if slotFrame.SetItemButtonTexture then slotFrame:SetItemButtonTexture(nil) end
                slotFrame.emptyBackgroundAtlas = nil
                slotFrame.emptyBackgroundTexture = nil
                slotFrame.lastTexture = nil
                slotFrame.lastDesat = nil
                local countText = slotFrame.count or slotFrame.Count
                if countText and countText:IsShown() then countText:Hide() end
                if slotFrame.lastCountText ~= nil then slotFrame.lastCountText = nil end

                if slotFrame.ilvl and slotFrame.ilvl:IsShown() then slotFrame.ilvl:Hide() end
                if slotFrame.lastIlvlText ~= nil then slotFrame.lastIlvlText = nil end

                if slotFrame.fav and slotFrame.fav:IsShown() then slotFrame.fav:Hide() end
                if slotFrame.newOverlay and slotFrame.newOverlay:IsShown() then slotFrame.newOverlay:Hide() end
                if slotFrame.NewItemTexture and slotFrame.NewItemTexture:IsShown() then slotFrame.NewItemTexture:Hide() end
                if slotFrame.BattlepayItemTexture and slotFrame.BattlepayItemTexture:IsShown() then slotFrame.BattlepayItemTexture:Hide() end
                if slotFrame.newitemglowAnim and slotFrame.newitemglowAnim.Stop then slotFrame.newitemglowAnim:Stop() end
                if slotFrame.flashAnim and slotFrame.flashAnim.Stop then slotFrame.flashAnim:Stop() end
                if slotFrame.AugmentBorderAnim and slotFrame.AugmentBorderAnim.Stop then slotFrame.AugmentBorderAnim:Stop() end
                if slotFrame.Cooldown then
                    slotFrame.Cooldown:Hide()
                    if slotFrame.Cooldown.Clear then
                        slotFrame.Cooldown:Clear()
                    elseif slotFrame.Cooldown.SetCooldown then
                        slotFrame.Cooldown:SetCooldown(0, 0)
                    end
                end
                local targetAlpha = isSearching and 0.2 or 1.0
                if slotFrame.lastAlpha ~= targetAlpha then
                    slotFrame:SetAlpha(targetAlpha)
                    slotFrame.lastAlpha = targetAlpha
                end
                slotFrame:SetBackdropColor(0.03, 0.03, 0.03, 0.4)
                if slotFrame.lastBorderR ~= 0.15 or slotFrame.lastBorderG ~= 0.15 or slotFrame.lastBorderB ~= 0.15 or slotFrame.lastBorderA ~= 0.5 then
                    slotFrame:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.5)
                    slotFrame.lastBorderR, slotFrame.lastBorderG, slotFrame.lastBorderB, slotFrame.lastBorderA = 0.15, 0.15, 0.15, 0.5
                end
            end
        end
    end

    for i = numDisplay + 1, #self.itemSlots do
        local s = self.itemSlots[i]
        if s then
            s:Hide()
            if s.slotParent then s.slotParent:Hide() end
            if s.Cooldown then s.Cooldown:Hide() end
            if s.newOverlay then s.newOverlay:Hide() end
            if s.roithiBorder then s.roithiBorder:Hide() end
        end
    end
end

function BagsMod:UpdateSlotCooldown(slotFrame)
    if not slotFrame or not slotFrame.Cooldown then return end
    local start, duration, enable = 0, 0, 0
    if slotFrame.bag and slotFrame.slot then
        if _G.C_Container and _G.C_Container.GetContainerItemCooldown then
            start, duration, enable = _G.C_Container.GetContainerItemCooldown(slotFrame.bag, slotFrame.slot)
        elseif _G.GetContainerItemCooldown then
            start, duration, enable = _G.GetContainerItemCooldown(slotFrame.bag, slotFrame.slot)
        end
    end
    if enable and enable ~= 0 and duration and duration > 0 then
        slotFrame.Cooldown:SetCooldown(start, duration)
        slotFrame.Cooldown:Show()
    else
        slotFrame.Cooldown:Hide()
        if slotFrame.Cooldown.Clear then
            slotFrame.Cooldown:Clear()
        elseif slotFrame.Cooldown.SetCooldown then
            slotFrame.Cooldown:SetCooldown(0, 0)
        end
    end
end

function BagsMod:OnBagCooldownUpdate()
    if not self.mainFrame or not self.mainFrame:IsShown() then return end
    for _, slotFrame in ipairs(self.itemSlots) do
        if slotFrame:IsShown() and slotFrame.bag and slotFrame.slot then
            self:UpdateSlotCooldown(slotFrame)
        end
    end
end

function BagsMod:RefreshProfile()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Bags or self.defaultSettings
    if self.UpdateBagBarLayout then
        self:UpdateBagBarLayout()
    end
    if self.mainFrame and self.mainFrame.ClearAllPoints and self.mainFrame.SetPoint then
        local pos = self.db.mainBagPosition
        if pos and pos.point then
            self.mainFrame:ClearAllPoints()
            self.mainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
        end
    end
    local LEM = LibStub and LibStub("LibEditMode-Roithi", true)
    if LEM and LEM.RefreshFrameSettings and self.bagBar then
        LEM:RefreshFrameSettings(self.bagBar)
    end
end
BagsMod.RefreshSettings = BagsMod.RefreshProfile

function BagsMod:UpdateFonts()
    if self.UpdateTypography then self:UpdateTypography() end
    self:UpdateInventory()
end
