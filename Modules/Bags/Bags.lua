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
    self.itemSlots = {}
    self.categoryButtons = {}
    self.newItems = {}
    self.knownItemIDs = {}
    self.newSlots = {}
    self.knownSlots = {}
    self.searchText = ""
    self:RegisterPopups()
end

function BagsMod:OnEnable()
    if self.db.enabled == false then return end

    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagUpdate")
    self:RegisterEvent("BAG_UPDATE", "OnBagUpdate")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnBagUpdate")
    self:RegisterEvent("PLAYER_MONEY", "UpdateMoneyDisplay")
    self:RegisterEvent("MERCHANT_SHOW", "OnMerchantShow")
    self:RegisterEvent("MERCHANT_CLOSED", "OnMerchantClosed")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")

    self:SetupBagBar()
    self:HookBlizzardBagFunctions()
    self:ScanInventoryOnce()
    self:PrewarmItemSlots()
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
        if f and f.SetParent and f:GetParent() ~= hidden then
            f:SetParent(hidden)
        end
    end
    local cb = _G.ContainerFrameCombinedBags
    if cb and cb.SetParent and cb:GetParent() ~= hidden then
        cb:SetParent(hidden)
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
                return true
            end
            if line.leftText then
                if pattern and string.find(line.leftText, pattern) then
                    return true
                end
                local lowerText = string.lower(line.leftText)
                if string.find(lowerText, "tradeable") or string.find(lowerText, "handeln") or string.find(lowerText, "trade time") then
                    return true
                end
            end
        end
        return false
    end

    -- Classic / Forever fallback using hidden scanning tooltip
    if _G.CreateFrame and bag and slot then
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
                            if tt.Hide then tt:Hide() end
                            return true
                        end
                        local lowerText = string.lower(lineText)
                        if string.find(lowerText, "tradeable") or string.find(lowerText, "handeln") or string.find(lowerText, "trade time") then
                            if tt.Hide then tt:Hide() end
                            return true
                        end
                    end
                end
            end
            if tt.Hide then tt:Hide() end
        end
    end

    return false
end

function BagsMod:IsSlotNew(bag, slot, itemData)
    if not bag or not slot then return false end
    local slotKey = GetSlotKey(bag, slot)

    -- If active trade timer is present, it is always considered new (persists even across relogs)
    if self:HasActiveTradeTimer(bag, slot) then
        return true
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

function BagsMod:SetSlotNew(bag, slot, isNew)
    if not bag or not slot then return end
    local slotKey = GetSlotKey(bag, slot)
    self.newSlots = self.newSlots or {}
    if isNew then
        self.newSlots[slotKey] = true
    else
        self.newSlots[slotKey] = nil
    end
end

function BagsMod:ClearNewSlot(bag, slot)
    if not bag or not slot then return end
    local slotKey = GetSlotKey(bag, slot)
    if self.newSlots then
        self.newSlots[slotKey] = nil
    end
    if _G.C_NewItems and _G.C_NewItems.RemoveNewItem then
        pcall(_G.C_NewItems.RemoveNewItem, bag, slot)
    end
end

function BagsMod:ScanInventoryOnce()
    self.knownSlots = self.knownSlots or {}
    self.newSlots = self.newSlots or {}
    self.knownItemIDs = self.knownItemIDs or {}
    for _, bag in ipairs(self:GetScannableBags()) do
        local numSlots = self:GetNumBagSlots(bag)
        for slot = 1, numSlots do
            local slotKey = GetSlotKey(bag, slot)
            local itemInfo = self:GetItemInfoAt(bag, slot)
            if itemInfo and itemInfo.itemID then
                self.knownItemIDs[itemInfo.itemID] = true
                self.knownSlots[slotKey] = itemInfo.itemID
                -- If item has an active trade timer, keep it marked new even on relog
                if self:HasActiveTradeTimer(bag, slot) then
                    self.newSlots[slotKey] = true
                    itemInfo.isNew = true
                end
            else
                self.knownSlots[slotKey] = nil
                self.newSlots[slotKey] = nil
            end
        end
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
            if _G.C_Container and _G.C_Container.GetContainerItemQuestInfo then
                local qInfo = _G.C_Container.GetContainerItemQuestInfo(bag, slot)
                if qInfo and (qInfo.isQuestItem or qInfo.questID) then
                    isQuest = true
                end
            end

            return {
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
                isCraftingReagent = isCraftingReagent,
                isNew = self:IsSlotNew(bag, slot),
            }
        end
    end
    return nil
end

function BagsMod:OnBagUpdate()
    if self.UpdateBagButtonsVisual then
        self:UpdateBagButtonsVisual()
    end
    if self.mainFrame and self.mainFrame:IsShown() then
        self:UpdateInventory()
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

    local pt = cfg.point or "BOTTOMRIGHT"
    local cols = self.db.columns or 10
    local slotSize = self.db.slotSize or 36
    local spacing = self.db.spacing or 4
    local initialW = math.max(380, cols * slotSize + (cols - 1) * spacing + 16)
    frame:SetSize(initialW, 420)
    frame:ClearAllPoints()
    frame:SetPoint(pt, UIParent, pt, cfg.x or -10, cfg.y or 80)

    if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
    frame:SetScript("OnDragStart", function(s) s:StartMoving() end)
    frame:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local sPoint, _, _, sX, sY = s:GetPoint(1)
        self.db.bagWindow = self.db.bagWindow or {}
        self.db.bagWindow.point = sPoint
        self.db.bagWindow.x = sX
        self.db.bagWindow.y = sY
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
    self:CreateFooterBar()
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

    -- Save Filter Button (+)
    local saveFilterBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    saveFilterBtn:SetSize(20, 20)
    saveFilterBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
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
    plusText:SetPoint("CENTER", saveFilterBtn, "CENTER", 0, 1)
    plusText:SetText("+")
    plusText:SetTextColor(0.2, 0.8, 1.0, 1)

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
    infoBtn:SetPoint("RIGHT", saveFilterBtn, "LEFT", -4, 0)
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
    infoText:SetPoint("CENTER", infoBtn, "CENTER", 0, 1)
    infoText:SetText("?")
    infoText:SetTextColor(1, 0.82, 0.0, 1)

    local function ShowSearchGuide(owner)
        if not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(owner, "ANCHOR_TOPLEFT")
        _G.GameTooltip:SetText(L["Bag Search Syntax Guide"] or "Bag Search Syntax Guide", 1, 0.82, 0)
        _G.GameTooltip:AddLine(L["Combine any tokens with spaces (AND logic):"] or "Combine any tokens with spaces (AND logic):", 1, 1, 1)
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine("• |cffffd100name:text|r or |cffffd100text|r - " .. (L["Item name match"] or "Item name match"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100type:gear||weapon||armor||consumable||reagent|r", 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100bind:bop||boe||bou||account|r - " .. (L["Bind status"] or "Bind status"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100reagent:yes||no|r or |cffffd100reagents|r", 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100exp:tww||df||sl||bfa||classic|r - " .. (L["Expansion"] or "Expansion"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100quality:epic||rare||uncommon||poor|r or |cffffd100q:4|r", 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100ilvl:>600|r, |cffffd100ilvl:<550|r, |cffffd100ilvl:600-630|r", 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100boss:name|r, |cffffd100zone:name|r - " .. (L["Drop source"] or "Drop source"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine("• |cffffd100junk|r, |cffffd100new|r, |cffffd100fav|r - " .. (L["Shorthand flags"] or "Shorthand flags"), 0.9, 0.9, 0.9)
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine("|cff00ff00" .. (L["Example:"] or "Example:") .. "|r |cfffffffftype:gear quality:epic ilvl:>600|r", 0.8, 0.8, 0.8)
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
    search:SetHeight(20)
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
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(search, "Friz Quadrata TT", 11, "")
    else
        search:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    end
    if search.SetTextInsets then search:SetTextInsets(6, 6, 0, 0) end
    if search.SetTextColor then search:SetTextColor(0.9, 0.9, 0.9, 1) end

    local placeholder = search:CreateFontString(nil, "OVERLAY")
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(placeholder, "Friz Quadrata TT", 10, "")
    else
        placeholder:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    end
    placeholder:SetPoint("LEFT", search, "LEFT", 6, 0)
    placeholder:SetText(L["Search items (e.g. type:gear, bind:boe, new)..."] or "Search items...")
    placeholder:SetTextColor(0.5, 0.5, 0.5, 0.8)

    search:SetScript("OnTextChanged", function(s)
        local txt = s:GetText() or ""
        self.searchText = txt
        if txt == "" then
            placeholder:Show()
        else
            placeholder:Hide()
        end
        self:UpdateInventory()
    end)
    search:SetScript("OnEscapePressed", function(s)
        s:SetText("")
        s:ClearFocus()
    end)
    search:SetScript("OnEnter", function(s)
        ShowSearchGuide(s)
    end)
    search:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    self.searchBox = search
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

function BagsMod:OpenItemCategoryMenu(owner, itemID)
    if not itemID then return end
    local currentCat = (self.db.customCategoryAssignments and self.db.customCategoryAssignments[itemID])
    local categories = {
        { id = "GEAR", name = L["Gear"] or "Gear" },
        { id = "WEAPONS", name = L["Weapons"] or "Weapons" },
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
                local label = cat.name
                if currentCat == cat.id then
                    label = "|cff00ff00✓ " .. label .. "|r"
                end
                rootDescription:CreateButton(label, function()
                    self:AssignItemCategory(itemID, cat.id)
                end)
            end
            if currentCat then
                rootDescription:CreateDivider()
                rootDescription:CreateButton("|cffff8800" .. (L["Reset to Default Category"] or "Reset to Default Category") .. "|r", function()
                    self:ResetItemCategory(itemID)
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
        if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
            LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 10, "OUTLINE")
        else
            text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        end
        text:SetPoint("CENTER", btn, "CENTER", 0, 0)
        text:SetText(cat.name)
        text:SetTextColor(0.8, 0.8, 0.8, 1)

        btn.catId = cat.id
        btn.isCustom = cat.isCustom
        btn.label = text

        if btn.RegisterForClicks then btn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        btn:SetScript("OnClick", function(b, button)
            local infoType, itemID
            if _G.GetCursorInfo then
                infoType, itemID = _G.GetCursorInfo()
            end
            if infoType == "item" and itemID then
                if cat.id ~= "ALL" and cat.id ~= "NEW" and cat.id ~= "FAVORITES" then
                    self:AssignItemCategory(itemID, cat.id)
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
            local infoType, itemID
            if _G.GetCursorInfo then
                infoType, itemID = _G.GetCursorInfo()
            end
            if infoType == "item" and itemID then
                if cat.id ~= "ALL" and cat.id ~= "NEW" and cat.id ~= "FAVORITES" then
                    self:AssignItemCategory(itemID, cat.id)
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

function BagsMod:UpdateCategoryButtonsLayout()
    if not self.catContainer or not self.categoryButtons or #self.categoryButtons == 0 then return end

    local totalW = self.catContainer:GetWidth()
    if not totalW or totalW < 100 then
        local cols = self.db.columns or 10
        local slotSize = self.db.slotSize or 36
        local spacing = self.db.spacing or 4
        totalW = math.max(380, cols * slotSize + (cols - 1) * spacing)
    end

    local numButtons = #self.categoryButtons
    local buttonsPerRow = 5
    local btnSpacing = 3
    local btnH = 20
    local btnW = math.floor((totalW - (buttonsPerRow - 1) * btnSpacing) / buttonsPerRow)

    for i, btn in ipairs(self.categoryButtons) do
        local col = (i - 1) % buttonsPerRow
        local row = math.floor((i - 1) / buttonsPerRow)
        local x = col * (btnW + btnSpacing)
        local y = -row * (btnH + btnSpacing)

        btn:ClearAllPoints()
        btn:SetSize(btnW, btnH)
        btn:SetPoint("TOPLEFT", self.catContainer, "TOPLEFT", x, y)
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

    -- Money Display
    local moneyText = footer:CreateFontString(nil, "OVERLAY")
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(moneyText, "Friz Quadrata TT", 10, "OUTLINE")
    else
        moneyText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end
    moneyText:SetPoint("LEFT", footer, "LEFT", 2, 0)
    self.moneyText = moneyText
    self:UpdateMoneyDisplay()

    -- Free Space Count
    local freeText = footer:CreateFontString(nil, "OVERLAY")
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(freeText, "Friz Quadrata TT", 10, "OUTLINE")
    else
        freeText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end
    freeText:SetPoint("RIGHT", footer, "RIGHT", -2, 0)
    self.freeText = freeText

    -- Clean / Sort Bags button
    local sortBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    sortBtn:SetSize(40, 18)
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
    local sortText = sortBtn:CreateFontString(nil, "OVERLAY")
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(sortText, "Friz Quadrata TT", 9, "OUTLINE")
    else
        sortText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    end
    sortText:SetPoint("CENTER", sortBtn, "CENTER", 0, 0)
    sortText:SetText(L["Sort"])
    sortBtn:SetScript("OnClick", function()
        if _G.C_Container and _G.C_Container.SortBags then
            _G.C_Container.SortBags()
        elseif _G.SortBags then
            _G.SortBags()
        end
    end)
    self.sortButton = sortBtn

    -- Sell Junk Button (Visible at Vendor)
    local junkBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    junkBtn:SetSize(65, 18)
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
    local junkText = junkBtn:CreateFontString(nil, "OVERLAY")
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(junkText, "Friz Quadrata TT", 9, "OUTLINE")
    else
        junkText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    end
    junkText:SetPoint("CENTER", junkBtn, "CENTER", 0, 0)
    junkText:SetText(L["Sell Junk"])
    junkBtn:SetScript("OnClick", function()
        self:SellAllJunk()
    end)
    junkBtn:Hide()
    self.junkButton = junkBtn
end

function BagsMod:UpdateMoneyDisplay()
    if not self.moneyText then return end
    local copper = _G.GetMoney and _G.GetMoney() or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    self.moneyText:SetText(string.format("|cffffd700%d|rg |cffc7c7cf%d|rs |cffeda55f%d|rc", gold, silver, cop))
end

function BagsMod:OnMerchantShow()
    if self.junkButton then self.junkButton:Show() end
    if self.db.autoSellJunk then
        self:SellAllJunk()
    end
end

function BagsMod:OnMerchantClosed()
    if self.junkButton then self.junkButton:Hide() end
end

function BagsMod:SellAllJunk()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    if _G.C_MerchantFrame and _G.C_MerchantFrame.SellAllJunkItems then
        _G.C_MerchantFrame.SellAllJunkItems()
        return
    end
    for _, bag in ipairs(self:GetScannableBags()) do
        local numSlots = self:GetNumBagSlots(bag)
        for slot = 1, numSlots do
            local itemInfo = self:GetItemInfoAt(bag, slot)
            if itemInfo and itemInfo.quality == 0 then
                if _G.C_Container and _G.C_Container.UseContainerItem then
                    pcall(_G.C_Container.UseContainerItem, bag, slot)
                elseif _G.UseContainerItem then
                    pcall(_G.UseContainerItem, bag, slot)
                end
            end
        end
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

    slotParent:SetFrameLevel(self.mainFrame:GetFrameLevel() + 5)
    slot:SetFrameLevel(slotParent:GetFrameLevel() + 1)

    if not slot.SetBackdrop and _G.BackdropTemplateMixin then
        Mixin(slot, _G.BackdropTemplateMixin)
    end
    if slot.SetBackdrop then
        slot:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        slot:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        slot:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
    end

    -- Icon texture
    local icon = slot.icon or slot.Icon or (slot.GetName and _G[slot:GetName() .. "IconTexture"])
    if not icon then
        icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(slot)
        slot.icon = icon
    end
    if slot.IconMask and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture, icon, slot.IconMask)
    end
    if slot.CircleMask and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture, icon, slot.CircleMask)
    end
    if icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- Count text
    local count = slot.Count or slot.count
    if not count then
        count = slot:CreateFontString(nil, "OVERLAY")
        count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
        slot.count = count
    end
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(count, "Friz Quadrata TT", 10, "OUTLINE")
    else
        count:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end

    -- Item level text
    local ilvl = slot.ilvl
    if not ilvl then
        ilvl = slot:CreateFontString(nil, "OVERLAY")
        ilvl:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
        ilvl:SetTextColor(1, 0.82, 0, 1)
        slot.ilvl = ilvl
    end
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(ilvl, "Friz Quadrata TT", 9, "OUTLINE")
    else
        ilvl:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    end

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
        newOverlay:SetBlendMode("ADD")
        newOverlay:SetAlpha(0.65)
        newOverlay:Hide()
        slot.newOverlay = newOverlay
    end

    -- Click & Drag handling
    if slot.RegisterForClicks then slot:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    if slot.RegisterForDrag then slot:RegisterForDrag("LeftButton") end

    local function HandlePickup(s)
        if s.bag and s.slot then
            if _G.C_Container and _G.C_Container.PickupContainerItem then
                _G.C_Container.PickupContainerItem(s.bag, s.slot)
            elseif _G.PickupContainerItem then
                _G.PickupContainerItem(s.bag, s.slot)
            end
        end
    end

    if slot.HookScript then
        slot:HookScript("PreClick", function(s, button)
            if button == "RightButton" then
                if _G.IsShiftKeyDown and _G.IsShiftKeyDown() and s.itemData and s.itemData.itemID then
                    self:OpenItemCategoryMenu(s, s.itemData.itemID)
                elseif _G.IsAltKeyDown and _G.IsAltKeyDown() and s.itemData and s.itemData.itemID then
                    self.db.favorites = self.db.favorites or {}
                    self.db.favorites[s.itemData.itemID] = not self.db.favorites[s.itemData.itemID]
                    self:UpdateInventory()
                end
            end
        end)
    end

    if not slot:GetScript("OnClick") then
        slot:SetScript("OnClick", function(s, button)
            if button == "LeftButton" then
                HandlePickup(s)
            elseif button == "RightButton" then
                if _G.IsShiftKeyDown and _G.IsShiftKeyDown() and s.itemData and s.itemData.itemID then
                    self:OpenItemCategoryMenu(s, s.itemData.itemID)
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
        slot:SetScript("OnDragStart", function(s) HandlePickup(s) end)
    end
    if not slot:GetScript("OnReceiveDrag") then
        slot:SetScript("OnReceiveDrag", function(s) HandlePickup(s) end)
    end


    slot:SetScript("OnEnter", function(s)
        -- Slot new status management:
        -- If the item has an active trade timer, keep it marked new until timer expires.
        -- If it has NO trade timer, remove it from new on hover.
        if s.bag and s.slot then
            local hasTradeTimer = self:HasActiveTradeTimer(s.bag, s.slot)
            if not hasTradeTimer then
                self:ClearNewSlot(s.bag, s.slot)
                if s.itemData then
                    s.itemData.isNew = false
                end
                if s.newOverlay then
                    s.newOverlay:Hide()
                end
                s.needsTabRefreshOnLeave = true
            end
        end

        if s.bag and s.slot and _G.GameTooltip then
            _G.GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            local hasItem = false
            if _G.C_Container and _G.C_Container.GetContainerItemInfo then
                _G.GameTooltip:SetBagItem(s.bag, s.slot)
                hasItem = (s.itemData and s.itemData.itemID ~= nil)
            elseif s.itemData and s.itemData.link then
                _G.GameTooltip:SetHyperlink(s.itemData.link)
                hasItem = true
            end

            if hasItem and s.itemData and s.itemData.itemID then
                local favs = self.db.favorites or {}
                local isFav = favs[s.itemData.itemID] == true
                _G.GameTooltip:AddLine(" ")
                if isFav then
                    _G.GameTooltip:AddLine("|cffffd100★ Favorited|r |cffaaaaaa(Alt + Right Click to remove)|r", 1, 1, 1)
                else
                    _G.GameTooltip:AddLine("|cff888888<Alt + Right Click to Favorite>|r", 0.7, 0.7, 0.7)
                end
                _G.GameTooltip:AddLine("|cff00ccff<Shift + Right Click to Reassign Category>|r", 0.4, 0.8, 1.0)
                _G.GameTooltip:AddLine("|cff00ff00<Drag item onto Category tab to Reassign>|r", 0.4, 0.9, 0.4)
            end
            _G.GameTooltip:Show()
        end
    end)
    slot:SetScript("OnLeave", function(s)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
        if s and s.needsTabRefreshOnLeave then
            s.needsTabRefreshOnLeave = nil
            if self.db and self.db.activeCategory == "NEW" and self.mainFrame and self.mainFrame:IsShown() then
                self:UpdateInventory()
            end
        end
    end)

    self.itemSlots[index] = slot
    return slot
end

function BagsMod:UpdateInventory()
    if not self.mainFrame or not self.mainFrame:IsShown() then return end

    local allItems = {}
    local totalSlots = 0
    local freeSlots = 0

    local displaySlots = {}
    local activeCat = self.db.activeCategory or "ALL"

    local reagentBagID = (_G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag) or 5
    local keyringID = (_G.KEYRING_CONTAINER or -2)

    local normalDisplaySlots = {}
    local reagentDisplaySlots = {}

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
            local itemInfo = self:GetItemInfoAt(bag, slot)
            if itemInfo and itemInfo.itemID then
                local isTradeableBoP = self:HasActiveTradeTimer(bag, slot)
                if isTradeableBoP then
                    self.newSlots[slotKey] = true
                    itemInfo.isNew = true
                elseif _G.C_NewItems and _G.C_NewItems.IsNewItem then
                    if _G.C_NewItems.IsNewItem(bag, slot) then
                        self.newSlots[slotKey] = true
                        itemInfo.isNew = true
                    elseif self.newSlots[slotKey] then
                        itemInfo.isNew = true
                    end
                elseif not self.knownItemIDs[itemInfo.itemID] then
                    self.newSlots[slotKey] = true
                    itemInfo.isNew = true
                elseif self.newSlots[slotKey] then
                    itemInfo.isNew = true
                end
                self.knownSlots[slotKey] = itemInfo.itemID
                self.knownItemIDs[itemInfo.itemID] = true
                table.insert(allItems, itemInfo)
            else
                self.knownSlots[slotKey] = nil
                self.newSlots[slotKey] = nil
                if (activeCat == "ALL" and (isNormalBag or isReagentBag))
                    or (activeCat == "REAGENTS" and isReagentBag)
                    or (activeCat == "KEYRING" and isKeyringBag)
                    or (activeCat ~= "ALL" and activeCat ~= "REAGENTS" and activeCat ~= "KEYRING" and isNormalBag) then
                    freeSlots = freeSlots + 1
                end
            end

            if activeCat == "ALL" then
                if isNormalBag then
                    table.insert(normalDisplaySlots, {
                        bag = bag,
                        slot = slot,
                        itemData = itemInfo,
                    })
                elseif isReagentBag then
                    table.insert(reagentDisplaySlots, {
                        bag = bag,
                        slot = slot,
                        itemData = itemInfo,
                    })
                end
            elseif activeCat == "REAGENTS" then
                if (itemInfo and itemInfo.itemID and self:ItemMatchesCategory(itemInfo, activeCat)) or (isReagentBag and not itemInfo) then
                    table.insert(displaySlots, {
                        bag = bag,
                        slot = slot,
                        itemData = itemInfo,
                    })
                end
            elseif activeCat == "KEYRING" then
                if isKeyringBag then
                    table.insert(displaySlots, {
                        bag = bag,
                        slot = slot,
                        itemData = itemInfo,
                    })
                end
            else
                if itemInfo and itemInfo.itemID and self:ItemMatchesCategory(itemInfo, activeCat) then
                    table.insert(displaySlots, {
                        bag = bag,
                        slot = slot,
                        itemData = itemInfo,
                    })
                end
            end
        end
    end

    local numNormal = 0
    local numReagent = 0
    if activeCat == "ALL" then
        for _, entry in ipairs(normalDisplaySlots) do
            table.insert(displaySlots, entry)
        end
        numNormal = #normalDisplaySlots
        for _, entry in ipairs(reagentDisplaySlots) do
            table.insert(displaySlots, entry)
        end
        numReagent = #reagentDisplaySlots
    end

    if self.freeText then
        self.freeText:SetText(string.format("%d / %d %s", freeSlots, totalSlots, L["Free"]))
    end

    local cols = self.db.columns or 10
    local slotSize = self.db.slotSize or 36
    local spacing = self.db.spacing or 4

    local numDisplay = #displaySlots
    local normalRows = (activeCat == "ALL") and math.max(1, math.ceil(numNormal / cols)) or math.max(1, math.ceil(numDisplay / cols))
    local normalGridH = normalRows * slotSize + (normalRows - 1) * spacing

    local reagentGap = (activeCat == "ALL" and numReagent > 0) and 10 or 0
    local reagentRows = (activeCat == "ALL" and numReagent > 0) and math.ceil(numReagent / cols) or 0
    local reagentGridH = (reagentRows > 0) and (reagentRows * slotSize + (reagentRows - 1) * spacing) or 0

    local gridW = cols * slotSize + (cols - 1) * spacing
    local frameW = math.max(380, gridW + 16)
    local catH = (self.catContainer and self.catContainer:GetHeight()) or 46
    local headerH = 28 + catH + 12
    local footerH = 24 + 8
    local gridH = normalGridH + reagentGap + reagentGridH
    local frameH = headerH + gridH + footerH + 16

    if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
        self.mainFrame:SetSize(frameW, frameH)
        self:UpdateCategoryButtonsLayout()
    end

    local isSearching = (self.searchText and self.searchText ~= "")

    for i = 1, numDisplay do
        local entry = displaySlots[i]
        local slotFrame = self:AcquireItemSlot(i)
        if slotFrame then
            local parent = slotFrame.slotParent or slotFrame
            parent:SetSize(slotSize, slotSize)
            parent:ClearAllPoints()

            local x, y
            if activeCat == "ALL" and i > numNormal then
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

            parent:SetFrameLevel(self.mainFrame:GetFrameLevel() + 5)
            slotFrame:SetFrameLevel(parent:GetFrameLevel() + 1)
            parent:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", x, y)
            parent:Show()
            slotFrame:Show()

            slotFrame:SetID(entry.slot or 0)
            if slotFrame.slotParent then
                slotFrame.slotParent:SetID(entry.bag or 0)
            end

            slotFrame.bag = entry.bag
            slotFrame.slot = entry.slot
            slotFrame.itemData = entry.itemData

            local itemData = entry.itemData
            if itemData then
                local isMatch = true
                if isSearching then
                    isMatch = self:MatchesSearchQuery(itemData, self.searchText)
                end

                local tex = itemData.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
                if slotFrame.SetItemButtonTexture then
                    slotFrame:SetItemButtonTexture(tex)
                end
                slotFrame.icon:SetTexture(tex)
                slotFrame.icon:Show()

                if isSearching and not isMatch then
                    -- Dim non-matching items
                    slotFrame:SetAlpha(0.2)
                    if slotFrame.icon.SetDesaturated then slotFrame.icon:SetDesaturated(true) end
                    slotFrame:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.5)
                else
                    -- Highlight matching items
                    slotFrame:SetAlpha(1.0)
                    if slotFrame.icon.SetDesaturated then slotFrame.icon:SetDesaturated(false) end
                    if isSearching then
                        slotFrame:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                    else
                        local qc = QUALITY_COLORS[itemData.quality or 1] or QUALITY_COLORS[1]
                        if self.db.qualityBorders ~= false then
                            slotFrame:SetBackdropBorderColor(qc.r, qc.g, qc.b, 1.0)
                        else
                            slotFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
                        end
                    end
                end

                -- Count
                if itemData.count and itemData.count > 1 then
                    slotFrame.count:SetText(itemData.count)
                    slotFrame.count:Show()
                else
                    slotFrame.count:Hide()
                end

                -- Item Level
                if self.db.showItemLevel and itemData.itemLevel and itemData.itemLevel > 1 and (itemData.classID == 2 or itemData.classID == 4) then
                    slotFrame.ilvl:SetText(itemData.itemLevel)
                    slotFrame.ilvl:Show()
                else
                    slotFrame.ilvl:Hide()
                end

                -- Favorites indicator
                local favs = self.db.favorites or {}
                if favs[itemData.itemID] then
                    slotFrame.fav:Show()
                else
                    slotFrame.fav:Hide()
                end

                -- New item highlight
                if itemData.isNew then
                    slotFrame.newOverlay:Show()
                else
                    slotFrame.newOverlay:Hide()
                end

                slotFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
            else
                -- Empty slot
                slotFrame.icon:Hide()
                if slotFrame.icon.SetTexture then slotFrame.icon:SetTexture(nil) end
                if slotFrame.SetItemButtonTexture then slotFrame:SetItemButtonTexture(nil) end
                slotFrame.count:Hide()
                slotFrame.ilvl:Hide()
                slotFrame.fav:Hide()
                slotFrame.newOverlay:Hide()
                if isSearching then
                    slotFrame:SetAlpha(0.2)
                else
                    slotFrame:SetAlpha(1.0)
                end
                slotFrame:SetBackdropColor(0.03, 0.03, 0.03, 0.4)
                slotFrame:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.5)
            end
        end
    end

    for i = numDisplay + 1, #self.itemSlots do
        local s = self.itemSlots[i]
        if s then
            s:Hide()
            if s.slotParent then s.slotParent:Hide() end
        end
    end
end
