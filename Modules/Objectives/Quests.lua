local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:GetModule("Objectives")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local objState = ns.Objectives or {}
ns.Objectives = objState

local skinnedBlocks = objState.skinnedBlocks
local titleFSCache = objState.titleFSCache
local blockBaseTitles = objState.blockBaseTitles or setmetatable({}, { __mode = "k" })
objState.blockBaseTitles = blockBaseTitles
local blockQuestIDs = objState.blockQuestIDs or setmetatable({}, { __mode = "k" })
objState.blockQuestIDs = blockQuestIDs
local barBackdrops = objState.barBackdrops or setmetatable({}, { __mode = "k" })
objState.barBackdrops = barBackdrops

local questZoneCache = {}
local questTitleCache = {}

local function IsSecret(val)
    if ns.Utils and ns.Utils.IsSecret then
        return ns.Utils.IsSecret(val)
    end
    if val == nil then return false end
    local fn = _G.issecretvalue
    if type(fn) == "function" and fn(val) then return true end
    local ca = _G.canaccessvalue
    if type(ca) == "function" and not ca(val) then return true end
    return type(val) == "userdata"
end
objState.IsSecret = IsSecret

local function WipeTable(tbl)
    if _G.wipe then
        _G.wipe(tbl)
    else
        for k in pairs(tbl) do
            tbl[k] = nil
        end
    end
    return tbl
end

local function SafeTrim(str)
    if not str or IsSecret(str) or type(str) ~= "string" then return "" end
    return (str:match("^%s*(.-)%s*$") or str)
end

local function UpdateQuestLogData()
    WipeTable(questZoneCache)
    WipeTable(questTitleCache)
    local numEntries = (_G.C_QuestLog and _G.C_QuestLog.GetNumQuestLogEntries and _G.C_QuestLog.GetNumQuestLogEntries())
        or (_G.GetNumQuestLogEntries and _G.GetNumQuestLogEntries())
        or 0

    local currentHeader = ""
    for i = 1, numEntries do
        if _G.C_QuestLog and _G.C_QuestLog.GetInfo then
            local info = _G.C_QuestLog.GetInfo(i)
            if info then
                if info.isHeader then
                    currentHeader = info.title or ""
                elseif info.questID and info.questID > 0 then
                    questZoneCache[info.questID] = currentHeader
                    if info.title and info.title ~= "" then
                        questTitleCache[info.questID] = info.title
                    end
                end
            end
        elseif _G.GetQuestLogTitle then
            local title, _, _, isHeader, _, _, _, questID = _G.GetQuestLogTitle(i)
            if isHeader then
                currentHeader = title or ""
            elseif questID and questID > 0 then
                questZoneCache[questID] = currentHeader
                if title and title ~= "" then
                    questTitleCache[questID] = title
                end
            end
        end
    end
end

local function GetQuestZone(questID)
    if not questID then return "" end
    if _G.C_QuestLog and _G.C_QuestLog.GetHeaderIndexForQuest then
        local headerIndex = _G.C_QuestLog.GetHeaderIndexForQuest(questID)
        if headerIndex then
            local info = _G.C_QuestLog.GetInfo and _G.C_QuestLog.GetInfo(headerIndex)
            if info and info.title and info.title ~= "" then
                return info.title
            end
        end
    end
    if questZoneCache[questID] and questZoneCache[questID] ~= "" then
        return questZoneCache[questID]
    end
    return ""
end

local cachedSubzoneNames = {}
local cachedZoneNames = {}
local cachedZoneKeySub = nil
local cachedZoneKeyReal = nil
local cachedZoneKeyZone = nil
local cachedZoneKeyMapID = nil
local cachedParentMapID = nil

local function GetCurrentZoneHierarchy()
    local subZone = (_G.GetSubZoneText and _G.GetSubZoneText()) or ""
    local realZone = (_G.GetRealZoneText and _G.GetRealZoneText()) or ""
    local zone = (_G.GetZoneText and _G.GetZoneText()) or ""
    local currentMapID = _G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")

    if subZone == cachedZoneKeySub and realZone == cachedZoneKeyReal and zone == cachedZoneKeyZone and currentMapID == cachedZoneKeyMapID then
        return cachedSubzoneNames, cachedZoneNames, currentMapID, cachedParentMapID
    end

    cachedZoneKeySub = subZone
    cachedZoneKeyReal = realZone
    cachedZoneKeyZone = zone
    cachedZoneKeyMapID = currentMapID
    cachedParentMapID = nil
    WipeTable(cachedSubzoneNames)
    WipeTable(cachedZoneNames)

    if subZone ~= "" then
        cachedSubzoneNames[string.lower(SafeTrim(subZone))] = true
    end
    if realZone ~= "" then
        cachedZoneNames[string.lower(SafeTrim(realZone))] = true
    end
    if zone ~= "" then
        cachedZoneNames[string.lower(SafeTrim(zone))] = true
    end

    if currentMapID and _G.C_Map and _G.C_Map.GetMapInfo then
        local mapInfo = _G.C_Map.GetMapInfo(currentMapID)
        if mapInfo then
            if mapInfo.name and mapInfo.name ~= "" then
                cachedSubzoneNames[string.lower(SafeTrim(mapInfo.name))] = true
            end
            if mapInfo.parentMapID and mapInfo.parentMapID > 0 then
                cachedParentMapID = mapInfo.parentMapID
                local parentInfo = _G.C_Map.GetMapInfo(cachedParentMapID)
                if parentInfo and parentInfo.name and parentInfo.name ~= "" then
                    cachedZoneNames[string.lower(SafeTrim(parentInfo.name))] = true
                end
            end
        end
    end

    return cachedSubzoneNames, cachedZoneNames, currentMapID, cachedParentMapID
end

local function GetQuestMapID(questID)
    if not questID then return nil end
    if _G.GetQuestUiMapID then
        local uMap = _G.GetQuestUiMapID(questID)
        if uMap and uMap > 0 then return uMap end
    end
    if _G.C_TaskQuest and _G.C_TaskQuest.GetQuestZoneID then
        local qMap = _G.C_TaskQuest.GetQuestZoneID(questID)
        if qMap and qMap > 0 then return qMap end
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetQuestTagInfo then
        local tag = _G.C_QuestLog.GetQuestTagInfo(questID)
        if tag and tag.mapID and tag.mapID > 0 then return tag.mapID end
    end
    return nil
end

local function IsQuestEntryComplete(questID, questObj)
    if questObj and questObj.IsComplete and type(questObj.IsComplete) == "function" then
        local comp = questObj:IsComplete()
        if comp ~= nil then return (comp == true or comp == 1) end
    end
    if ObjectivesMod and ObjectivesMod.IsQuestComplete then
        return ObjectivesMod:IsQuestComplete(questID)
    end
    return false
end

local function GetQuestSortTitle(questID, questObj)
    if questObj and questObj.title and questObj.title ~= "" then
        return questObj.title
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetTitleForQuestID then
        local t = _G.C_QuestLog.GetTitleForQuestID(questID)
        if t and t ~= "" then return t end
    end
    if questTitleCache[questID] and questTitleCache[questID] ~= "" then
        return questTitleCache[questID]
    end
    return ""
end

local function GetQuestSortTier(questID, questZone, questObj, subzoneNames, zoneNames, currentMapID, parentMapID)
    local isComplete = IsQuestEntryComplete(questID, questObj)
    local qMap = GetQuestMapID(questID)
    local cleanZone = questZone and string.lower(SafeTrim(questZone)) or ""

    local inSubzone = (currentMapID and qMap == currentMapID) or (cleanZone ~= "" and subzoneNames and subzoneNames[cleanZone])
    if inSubzone then
        return isComplete and 2 or 1
    end

    local inZone = (parentMapID and qMap == parentMapID) or (cleanZone ~= "" and zoneNames and zoneNames[cleanZone])
    if inZone then
        return isComplete and 4 or 3
    end

    return isComplete and 6 or 5
end

local function GetQuestLevel(questID)
    if not questID then return 0 end
    if _G.C_QuestLog and _G.C_QuestLog.GetQuestDifficultyLevel then
        local lvl = _G.C_QuestLog.GetQuestDifficultyLevel(questID)
        if lvl and lvl > 0 then return lvl end
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetQuestLevel then
        local lvl = _G.C_QuestLog.GetQuestLevel(questID)
        if lvl and lvl > 0 then return lvl end
    end
    return 0
end

local sortMetaPool = {}
local sortMetaByItem = setmetatable({}, { __mode = "k" })

local function CompareQuestInfosByZone(a, b)
    local mA = sortMetaByItem[a]
    local mB = sortMetaByItem[b]
    if not mA or not mB then
        return (a.index or 0) < (b.index or 0)
    end

    if mA.tier ~= mB.tier then
        return mA.tier < mB.tier
    end

    if mA.level ~= mB.level then
        if mA.level == 0 then return false end
        if mB.level == 0 then return true end
        return mA.level < mB.level
    end

    if mA.tier >= 5 and mA.zoneLower ~= mB.zoneLower then
        if mA.zoneLower == "" then return false end
        if mB.zoneLower == "" then return true end
        return mA.zoneLower < mB.zoneLower
    end

    if mA.titleLower ~= mB.titleLower and mA.titleLower ~= "" and mB.titleLower ~= "" then
        return mA.titleLower < mB.titleLower
    end

    if mA.index ~= mB.index then
        return mA.index < mB.index
    end

    local qidA = a.questID or (a.quest and a.quest.questID) or 0
    local qidB = b.questID or (b.quest and b.quest.questID) or 0
    return qidA < qidB
end

local function SortInfosByCurrentZone(infos)
    if not infos or #infos <= 1 then return infos end

    if not next(questZoneCache) then
        UpdateQuestLogData()
    end
    local subzoneNames, zoneNames, currentMapID, parentMapID = GetCurrentZoneHierarchy()

    WipeTable(sortMetaByItem)
    for index, item in ipairs(infos) do
        local qObj = item.quest
        local qID = (type(qObj) == "table" and (qObj.questID or qObj.id))
            or (type(item) == "table" and (item.questID or item.id))
        local zName = GetQuestZone(qID) or ""
        local tier = GetQuestSortTier(qID, zName, qObj, subzoneNames, zoneNames, currentMapID, parentMapID)
        local title = GetQuestSortTitle(qID, qObj) or ""
        local level = GetQuestLevel(qID)
        local m = sortMetaPool[index]
        if not m then
            m = {}
            sortMetaPool[index] = m
        end
        m.tier = tier
        m.level = level
        m.zone = zName
        m.zoneLower = (tier >= 5 and zName ~= "") and string.lower(zName) or ""
        m.title = title
        m.titleLower = (title ~= "") and string.lower(title) or ""
        m.index = item.index or index
        sortMetaByItem[item] = m
    end

    table.sort(infos, CompareQuestInfosByZone)
    WipeTable(sortMetaByItem)

    return infos
end

local function IsQuestInCurrentZone(questID, questZone)
    local subzoneNames, zoneNames, currentMapID, parentMapID = GetCurrentZoneHierarchy()
    local tier = GetQuestSortTier(questID, questZone, nil, subzoneNames, zoneNames, currentMapID, parentMapID)
    return tier <= 4
end

ObjectivesMod.GetQuestSortTier = GetQuestSortTier
ObjectivesMod.GetQuestZone = GetQuestZone
ObjectivesMod.IsQuestInCurrentZone = IsQuestInCurrentZone
ObjectivesMod.SortInfosByCurrentZone = SortInfosByCurrentZone
ObjectivesMod.UpdateQuestLogData = UpdateQuestLogData
objState.SortInfosByCurrentZone = SortInfosByCurrentZone

local function GetBlockHeaderHeight(b)
    if not b or not b.HeaderText then return 16 end
    if b.HeaderText.GetStringHeight then
        local sh = b.HeaderText:GetStringHeight()
        if sh and sh > 0 then return sh end
    end
    if b.HeaderText.GetHeight then
        local h = b.HeaderText:GetHeight()
        if h and h > 0 then return h end
    end
    return 16
end

local seenLinesScratch = {}
local function ForEachBlockLine(selfOrBlock, blockOrFunc, maybeFunc)
    local block = (type(selfOrBlock) == "table" and type(blockOrFunc) == "table" and blockOrFunc) or selfOrBlock
    local func = maybeFunc or (type(blockOrFunc) == "function" and blockOrFunc)
    if not block or not func then return end
    for k in pairs(seenLinesScratch) do seenLinesScratch[k] = nil end
    if block.usedLines then
        for _, line in pairs(block.usedLines) do
            if line and not seenLinesScratch[line] then
                seenLinesScratch[line] = true
                func(line)
            end
        end
    end
    if block.lines then
        for _, line in pairs(block.lines) do
            if line and not seenLinesScratch[line] then
                seenLinesScratch[line] = true
                func(line)
            end
        end
    end
end
objState.ForEachBlockLine = ForEachBlockLine
ObjectivesMod.ForEachBlockLine = ForEachBlockLine

local function GetBlockTitleFS(selfOrBlock, block)
    local b = (type(selfOrBlock) == "table" and type(block) == "table" and block) or selfOrBlock
    if not b or type(b) ~= "table" then return nil end
    if titleFSCache[b] then return titleFSCache[b] end
    local fs = b.HeaderText or b.Title or b.Text or b.label
    if not fs and b.GetRegions then
        for _, r in ipairs({ b:GetRegions() }) do
            if r and ((r.GetObjectType and r:GetObjectType() == "FontString") or (r.IsObjectType and r:IsObjectType("FontString"))) then
                fs = r
                break
            end
        end
    end
    if fs then
        titleFSCache[b] = fs
    end
    return fs
end
ObjectivesMod.GetBlockTitleFS = GetBlockTitleFS

function ObjectivesMod:GetBlockQuestID(block)
    if not block then return nil end
    if type(block) == "number" then return block end
    if type(block) ~= "table" then return tonumber(block) end
    local qid = block.id or block.questID or (block.quest and (block.quest.questID or block.quest.id))
    if not qid and block.GetQuestID then
        qid = block:GetQuestID()
    end
    return tonumber(qid)
end

function ObjectivesMod:IsQuestPinned(block)
    local qid = self:GetBlockQuestID(block)
    if not qid or not self.db or not self.db.pinnedQuests then return false end
    return self.db.pinnedQuests[qid] == true
end

function ObjectivesMod:TogglePinQuest(block)
    local qid = self:GetBlockQuestID(block)
    if not qid or not self.db then return false end
    if not self.db.pinnedQuests then
        self.db.pinnedQuests = {}
    end
    local newState = not self.db.pinnedQuests[qid]
    if newState then
        self.db.pinnedQuests[qid] = true
    else
        self.db.pinnedQuests[qid] = nil
    end

    if type(block) == "table" then
        if self.ApplyQuestLevelToTitle then
            self:ApplyQuestLevelToTitle(block)
        end
        local isHovered = (block.IsMouseOver and block:IsMouseOver()) or (block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver())
        if self.UpdateBlockHoverObjectives then
            self:UpdateBlockHoverObjectives(block, isHovered or false)
        end
    else
        for b in pairs(skinnedBlocks) do
            if type(b) == "table" and self:GetBlockQuestID(b) == qid then
                if self.ApplyQuestLevelToTitle then
                    self:ApplyQuestLevelToTitle(b)
                end
                local h = (b.IsMouseOver and b:IsMouseOver()) or (b.HeaderButton and b.HeaderButton.IsMouseOver and b.HeaderButton:IsMouseOver())
                if self.UpdateBlockHoverObjectives then
                    self:UpdateBlockHoverObjectives(b, h or false)
                end
            end
        end
    end
end

function ObjectivesMod:ToggleSuperTrackQuest(block)
    local qid = self:GetBlockQuestID(block)
    if not qid then return end
    if _G.C_SuperTrack and _G.C_SuperTrack.GetSuperTrackedQuestID and _G.C_SuperTrack.SetSuperTrackedQuestID then
        local current = _G.C_SuperTrack.GetSuperTrackedQuestID()
        local targetID = (current == qid) and 0 or qid
        if _G.InCombatLockdown and _G.InCombatLockdown() then
            self.pendingSuperTrackQuestID = targetID
            return
        end
        _G.C_SuperTrack.SetSuperTrackedQuestID(targetID)
        if type(block) == "table" then
            self:ApplyQuestLevelToTitle(block)
        else
            for b in pairs(skinnedBlocks) do
                if type(b) == "table" and self:GetBlockQuestID(b) == qid then
                    self:ApplyQuestLevelToTitle(b)
                end
            end
        end
    end
end

function ObjectivesMod:IsQuestComplete(questID, block)
    local qid = questID or self:GetBlockQuestID(block)
    if not qid then return false end
    if block then
        if block.poiIsComplete then return true end
        if block.quest and block.quest.IsComplete and block.quest:IsComplete() then return true end
    end
    if _G.C_QuestLog then
        if _G.C_QuestLog.IsComplete and _G.C_QuestLog.IsComplete(qid) then
            return true
        end
        if _G.C_QuestLog.ReadyForTurnIn and _G.C_QuestLog.ReadyForTurnIn(qid) then
            return true
        end
        if _G.C_QuestLog.GetLogIndexForQuestID and _G.C_QuestLog.GetInfo then
            local idx = _G.C_QuestLog.GetLogIndexForQuestID(qid)
            if idx then
                local info = _G.C_QuestLog.GetInfo(idx)
                if info and (info.isComplete == true or info.isComplete == 1) then
                    return true
                end
            end
        end
    end
    if _G.GetNumQuestLogEntries and _G.GetQuestLogTitle then
        for i = 1, _G.GetNumQuestLogEntries() do
            local _, _, _, isHeader, _, isComplete, _, id = _G.GetQuestLogTitle(i)
            if not isHeader and id == qid then
                if isComplete == 1 or isComplete == true then
                    return true
                end
            end
        end
    end
    return false
end

local function IsForeverQuest(questID)
    if ns.IsRetail or (_G.WOW_PROJECT_ID and _G.WOW_PROJECT_MAINLINE and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE) then
        return false
    end
    if not questID or type(questID) ~= "number" then return false end
    if _G.GetQuestExpansion then
        local exp = _G.GetQuestExpansion(questID)
        if exp and exp > 0 then
            return true
        end
    end
    return questID > 9550
end

local function GetCleanQuestTitle(block, questID, curText)
    if _G.C_QuestLog and _G.C_QuestLog.GetTitleForQuestID then
        local t = _G.C_QuestLog.GetTitleForQuestID(questID)
        if t and not IsSecret(t) and type(t) == "string" and t ~= "" then
            if block then
                blockBaseTitles[block] = t
                blockQuestIDs[block] = questID
            end
            return t
        end
    end
    if block and blockBaseTitles[block] and blockQuestIDs[block] == questID then
        return blockBaseTitles[block]
    end
    if not curText or IsSecret(curText) or type(curText) ~= "string" then
        return ""
    end
    local clean = curText:gsub("^%s*|c%x%x%x%x%x%x%x%x%[[^%]]+%]%|r%s*", "")
    clean = clean:gsub("^%s*%[[^%]]+%]%s*", "")
    clean = clean:gsub("^%s*|c%x%x%x%x%x%x%x%x\226\136\158%|r%s*", "")
    clean = clean:gsub("^%s*\226\136\158%s*", "")
    clean = clean:gsub("^%s*|c%x%x%x%x%x%x%x%x%*%|r%s*", "")
    clean = clean:gsub("^%s*%*%s*", "")
    clean = clean:gsub("^%s*|T[^|]+|t%s*", "")
    clean = clean:gsub("%s*|T[^|]+|t%s*$", "")
    clean = clean:gsub("^%s*|A[^|]+|a%s*", "")
    clean = clean:gsub("%s*|A[^|]+|a%s*$", "")
    clean = clean:gsub("%s*|c%x%x%x%x%x%x%x%x%[✓%]%|r%s*$", "")
    clean = clean:gsub("%s*%[✓%]%s*$", "")
    if block then
        blockBaseTitles[block] = clean
        blockQuestIDs[block] = questID
    end
    return clean
end

function ObjectivesMod:ApplyQuestLevelToTitle(block)
    if not block or not self.db then return end

    local questID = self:GetBlockQuestID(block)
    if not questID or type(questID) ~= "number" then return end

    local titleFS = block.HeaderText or GetBlockTitleFS(block)
    if not (titleFS and titleFS.GetText and titleFS.SetText) then return end

    local curText = titleFS:GetText()
    if not curText or IsSecret(curText) or type(curText) ~= "string" or curText == "" then return end

    local lvl = GetQuestLevel(questID)

    local colorCode = nil
    if lvl and lvl > 0 and _G.GetQuestDifficultyColor then
        local diff = _G.GetQuestDifficultyColor(lvl)
        if diff and diff.r then
            colorCode = string.format("|cff%02x%02x%02x", math.floor((diff.r or 1) * 255 + 0.5), math.floor((diff.g or 1) * 255 + 0.5), math.floor((diff.b or 1) * 255 + 0.5))
        end
    end
    if not colorCode and not IsSecret(curText) and type(curText) == "string" then
        colorCode = curText:match("^(|c%x%x%x%x%x%x%x%x)")
    end

    local isNewQuest = IsForeverQuest(questID)
    local isRetail = ns.IsRetail or (_G.WOW_PROJECT_ID and _G.WOW_PROJECT_MAINLINE and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)
    local showInfinity = (not isRetail) and (self.db.showForeverQuestInfinity ~= false) and isNewQuest
    local showLevel = (self.db.showQuestLevel ~= false) and lvl and lvl > 0

    local isSuperTracked = false
    if self.db.showFocusIndicator ~= false and _G.C_SuperTrack and _G.C_SuperTrack.GetSuperTrackedQuestID then
        isSuperTracked = (_G.C_SuperTrack.GetSuperTrackedQuestID() == questID)
    end
    local isPinned = self:IsQuestPinned(questID) or self:IsQuestPinned(block)

    local isComplete = false
    if self.db.showCompletedQuestIndicator ~= false then
        isComplete = self:IsQuestComplete(questID, block)
    end

    local prefix = ""
    if isSuperTracked then
        prefix = prefix .. "|TInterface\\ChatFrame\\ChatFrameExpandArrow:10:10:0:0|t "
    end
    if isPinned then
        prefix = prefix .. "|cffffd200*|r "
    end
    if isComplete then
        prefix = prefix .. "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t "
    end

    if showLevel and lvl and curText:match("^|c%x%x%x%x%x%x%x%x%[" .. tostring(lvl) .. "%]|r") and not showInfinity and prefix == "" and not isComplete and not curText:find("%*") then
        return
    end

    local baseText = GetCleanQuestTitle(block, questID, curText)
    if not baseText or IsSecret(baseText) or type(baseText) ~= "string" or baseText == "" then return end

    local fc = self.db.foreverColor or (self.defaultSettings and self.defaultSettings.foreverColor) or { r = 0.22, g = 0.74, b = 0.97 }
    local infR = math.floor((fc.r or 0.22) * 255 + 0.5)
    local infG = math.floor((fc.g or 0.74) * 255 + 0.5)
    local infB = math.floor((fc.b or 0.97) * 255 + 0.5)
    local infinityStr = string.format("|TInterface\\AddOns\\%s\\Media\\Textures\\Infinity:12:12:0:0:64:64:0:64:0:64:%d:%d:%d|t", addonName or "RoithiUI", infR, infG, infB)

    local newText
    if colorCode then
        if showLevel and showInfinity then
            newText = string.format("%s%s[%d]|r %s %s%s|r", prefix, colorCode, lvl, infinityStr, colorCode, baseText)
        elseif showLevel then
            newText = string.format("%s%s[%d]|r %s%s|r", prefix, colorCode, lvl, colorCode, baseText)
        elseif showInfinity then
            newText = string.format("%s%s %s%s|r", prefix, infinityStr, colorCode, baseText)
        else
            newText = prefix .. colorCode .. baseText .. "|r"
        end
    else
        if showLevel and showInfinity then
            newText = string.format("%s[%d] %s %s", prefix, lvl, infinityStr, baseText)
        elseif showLevel then
            newText = string.format("%s[%d] %s", prefix, lvl, baseText)
        elseif showInfinity then
            newText = string.format("%s%s %s", prefix, infinityStr, baseText)
        else
            newText = prefix .. baseText
        end
    end

    local oldText = titleFS:GetText()
    if not IsSecret(oldText) and oldText ~= newText then
        titleFS:SetText(newText)
    end
end

local function IsLineCompleted(line, block)
    if not line then return false end
    if line.isCompleted == true or line.completed == true or line.state == "Complete" then
        return true
    end
    if line.state and _G.ObjectiveTrackerAnimLineState and line.state == _G.ObjectiveTrackerAnimLineState.Completing then
        return true
    end
    if line.color and _G.OBJECTIVE_TRACKER_COLOR and line.color == _G.OBJECTIVE_TRACKER_COLOR["Complete"] then
        return true
    end
    if line.Icon and line.Icon.GetAtlas and line.Icon:GetAtlas() == "ui-questtracker-tracker-check" then
        return true
    end
    if line.Check and line.Check.IsShown and line.Check:IsShown() then
        return true
    end
    if line.objectiveIndex and block and block.id and _G.C_QuestLog and _G.C_QuestLog.GetQuestObjectives then
        local qid = block.id or block.questID
        local ok, objs = pcall(_G.C_QuestLog.GetQuestObjectives, qid)
        if ok and objs and objs[line.objectiveIndex] then
            return objs[line.objectiveIndex].finished == true
        end
    end
    return false
end

function ObjectivesMod:IsMouseOverBlock(block)
    if not block then return false end
    if block.IsMouseOver and block:IsMouseOver() then return true end
    if block.HeaderButton and block.HeaderButton.IsMouseOver and block.HeaderButton:IsMouseOver() then return true end
    local itemBtn = block.itemButton or block.ItemButton or (block.GetItemButton and block:GetItemButton())
    if itemBtn and itemBtn.IsMouseOver and itemBtn:IsMouseOver() then return true end
    return false
end

function ObjectivesMod:CancelCollapseTimer()
    self.collapseTimerToken = (self.collapseTimerToken or 0) + 1
    self.pendingCollapseBlock = nil
end

function ObjectivesMod:HandleBlockEnter(block)
    if not block then return end
    if self.pendingCollapseBlock and self.pendingCollapseBlock ~= block then
        local prevBlock = self.pendingCollapseBlock
        self:CancelCollapseTimer()
        self:UpdateBlockHoverObjectives(prevBlock, false)
    else
        self:CancelCollapseTimer()
    end
    self:UpdateBlockHoverObjectives(block, true)
end

function ObjectivesMod:HandleBlockLeave(block)
    if not block then return end
    if _G.GameTooltip and _G.GameTooltip:GetOwner() == block then
        _G.GameTooltip:Hide()
    end

    if self:IsMouseOverBlock(block) then
        return
    end

    if self:IsQuestPinned(block) then
        self:UpdateBlockHoverObjectives(block, false)
        return
    end

    local delay = (self.db and self.db.collapseDelay) or 0.25
    if delay <= 0 or not _G.C_Timer or not _G.C_Timer.After then
        self:UpdateBlockHoverObjectives(block, false)
        return
    end

    self:CancelCollapseTimer()
    self.pendingCollapseBlock = block
    local currentToken = self.collapseTimerToken
    _G.C_Timer.After(delay, function()
        if self.collapseTimerToken == currentToken and self.pendingCollapseBlock == block then
            self.pendingCollapseBlock = nil
            if not self:IsMouseOverBlock(block) then
                self:UpdateBlockHoverObjectives(block, false)
            else
                self:UpdateBlockHoverObjectives(block, true)
            end
        end
    end)
end

function ObjectivesMod:UpdateBlockHoverObjectives(block, isHovered)
    if not block then return end

    local isPinned = self:IsQuestPinned(block)
    local isPendingCollapse = (self.pendingCollapseBlock == block)
    local isExpanded = isHovered or isPinned or isPendingCollapse
    local hoverMode = self.db and self.db.hoverObjectiveText
    local hideCompleted = self.db and self.db.hideCompletedObjectives

    local headerHeight = GetBlockHeaderHeight(block)
    local lineSpacing = (block.parentModule and block.parentModule.lineSpacing) or 2
    local fullHeight = headerHeight + 2

    local function SetProgressBarState(bar, show)
        if not bar then return end
        local bg = barBackdrops[bar]
        if show then
            if bar.Show then bar:Show() end
            if bar.SetAlpha then bar:SetAlpha(1) end
            if bg then
                if bg.Show then bg:Show() end
                if bg.SetAlpha then bg:SetAlpha(1) end
            end
        else
            if bar.Hide then bar:Hide() end
            if bar.SetAlpha then bar:SetAlpha(0) end
            if bg then
                if bg.Hide then bg:Hide() end
                if bg.SetAlpha then bg:SetAlpha(0) end
            end
        end
    end

    local isShowingObjectives = not hoverMode or isExpanded

    ForEachBlockLine(block, function(line)
        local isComp = IsLineCompleted(line, block)
        local pb = line.progressBar or line.ProgressBar
        if hideCompleted and isComp then
            if line.Hide then line:Hide() end
            if line.SetAlpha then line:SetAlpha(0) end
            if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(0) end
            if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(0) end
            if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(0) end
            if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(0) end
            SetProgressBarState(pb, false)
            if line.SetHeight then line:SetHeight(0.001) end
        elseif isShowingObjectives then
            if line.Show then line:Show() end
            if line.SetAlpha then line:SetAlpha(1) end
            if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(1) end
            if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(1) end
            if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(1) end
            if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(1) end
            SetProgressBarState(pb, true)
            local textHeight = (line.Text and line.Text.GetStringHeight and line.Text:GetStringHeight()) or 0
            if textHeight < 14 then
                textHeight = (line.Text and line.Text.GetHeight and line.Text:GetHeight()) or 14
            end
            local lh = math.max(16, math.ceil(textHeight) + 3)
            if line.SetHeight then line:SetHeight(lh) end
            fullHeight = fullHeight + lh + lineSpacing
            if pb and pb.GetHeight then
                local pbH = pb:GetHeight()
                if pbH and pbH > 0 then
                    fullHeight = fullHeight + pbH + lineSpacing
                end
            end
        else
            if line.Hide then line:Hide() end
            if line.SetAlpha then line:SetAlpha(0) end
            if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(0) end
            if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(0) end
            if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(0) end
            if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(0) end
            SetProgressBarState(pb, false)
            if line.SetHeight then line:SetHeight(0.001) end
        end
    end)

    SetProgressBarState(block.progressBar or block.ProgressBar, isShowingObjectives)
    if block.usedProgressBars then
        for _, pb in pairs(block.usedProgressBars) do
            SetProgressBarState(pb, isShowingObjectives)
        end
    end

    if block.SetHeight then
        local currentHeight = (block.GetHeight and block:GetHeight()) or 0
        local targetHeight = hoverMode and (isExpanded and fullHeight or headerHeight) or fullHeight
        if math.abs(currentHeight - targetHeight) > 0.5 then
            block:SetHeight(targetHeight)
        end
    end

    if isHovered then
        self:ShowQuestTooltip(block)
    else
        self:HideQuestTooltip(block)
    end
end

function ObjectivesMod:ShowQuestTooltip(block)
    if not block or not _G.GameTooltip then return end
    local qid = self:GetBlockQuestID(block)
    if not qid or type(qid) ~= "number" then return end

    local tooltip = _G.GameTooltip
    tooltip:SetOwner(block, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPRIGHT", block, "TOPLEFT", -8, 0)

    local title = (block.HeaderText and block.HeaderText.GetText and block.HeaderText:GetText())
    if not title or IsSecret(title) or type(title) ~= "string" or title == "" then
        if _G.C_QuestLog and _G.C_QuestLog.GetTitleForQuestID then
            local t = _G.C_QuestLog.GetTitleForQuestID(qid)
            if t and not IsSecret(t) and type(t) == "string" and t ~= "" then
                title = t
            end
        end
    end
    local cleanTitle = L["Quest"] or "Quest"
    if title and not IsSecret(title) and type(title) == "string" and title ~= "" then
        cleanTitle = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end

    tooltip:AddLine(cleanTitle, 1, 0.85, 0.35, true)

    local zone = GetQuestZone(qid)
    if zone and not IsSecret(zone) and type(zone) == "string" and zone ~= "" then
        tooltip:AddLine(zone, 0.6, 0.6, 0.6)
    end

    if _G.C_QuestLog and _G.C_QuestLog.GetQuestObjectives then
        local ok, objs = pcall(_G.C_QuestLog.GetQuestObjectives, qid)
        if ok and objs and #objs > 0 then
            tooltip:AddLine(" ")
            for _, obj in ipairs(objs) do
                if obj.text and not IsSecret(obj.text) and type(obj.text) == "string" and obj.text ~= "" then
                    local r, g, b = 0.85, 0.85, 0.85
                    local prefix = " • "
                    if obj.finished then
                        r, g, b = 0.35, 1.0, 0.45
                        prefix = " ✔ "
                    end
                    tooltip:AddLine(prefix .. obj.text, r, g, b, true)
                end
            end
        end
    end

    if _G.IsInGroup and _G.IsInGroup() and tooltip.SetQuestPartyProgress then
        pcall(tooltip.SetQuestPartyProgress, tooltip, qid)
    end

    tooltip:AddLine(" ")
    local trackHint = L["|cff9e9e9eAlt+Click:|r |cffffffffTrack|r"] or "|cff9e9e9eAlt+Click:|r |cffffffffTrack|r"
    local pinHint = L["|cff9e9e9eCtrl+Click:|r |cffffffffPin|r"] or "|cff9e9e9eCtrl+Click:|r |cffffffffPin|r"
    tooltip:AddDoubleLine(trackHint, pinHint, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)

    tooltip:Show()
end

function ObjectivesMod:HideQuestTooltip(block)
    if not _G.GameTooltip then return end
    if _G.GameTooltip:GetOwner() == block then
        _G.GameTooltip:Hide()
    end
end

local sortPrefixBlocks = {}
local sortQuestEntries = {}
local sortQuestEntryPool = {}
local sortEntryCount = 0
local sortActiveSelf = nil
local sortAnchorParent = nil
local sortAnchorFromHeader = -4
local sortAnchorFromBlock = -2
local sortAnchorDefaultOffsetX = 4
local sortAnchorPrev = nil

local function SortQuestEntriesByIndex(a, b)
    return (a.index or 0) < (b.index or 0)
end

local function CollectTrackerSortBlock(block)
    if block and block.used ~= false and (block.IsShown == nil or block:IsShown()) then
        local isPopup = (block.popUpType ~= nil) or (type(block.id) == "string") or (block.template == "AutoQuestPopUpBlockTemplate")
        local mod = sortActiveSelf or ObjectivesMod
        local qID = (not isPopup and mod and mod.GetBlockQuestID) and mod:GetBlockQuestID(block) or nil
        if qID and not IsSecret(qID) and type(qID) == "number" and qID > 0 then
            local watchIdx = 0
            if _G.C_QuestLog and _G.C_QuestLog.GetQuestWatchIndex then
                local idx = _G.C_QuestLog.GetQuestWatchIndex(qID)
                if idx and not IsSecret(idx) and type(idx) == "number" and idx > 0 then watchIdx = idx end
            end
            sortEntryCount = sortEntryCount + 1
            local entry = sortQuestEntryPool[sortEntryCount]
            if not entry then
                entry = {}
                sortQuestEntryPool[sortEntryCount] = entry
            end
            entry.block = block
            entry.questID = qID
            entry.index = watchIdx
            entry.quest = block.quest
            sortQuestEntries[sortEntryCount] = entry
        else
            table.insert(sortPrefixBlocks, block)
        end
    end
end

local function AnchorOneSortedBlock(block)
    if not block or not block.ClearAllPoints or not block.SetPoint then return end
    block:ClearAllPoints()
    if not sortAnchorPrev then
        block:SetPoint("TOP", sortAnchorParent, "TOP", 0, sortAnchorFromHeader)
    else
        block:SetPoint("TOP", sortAnchorPrev, "BOTTOM", 0, sortAnchorFromBlock)
    end
    local p = (block.GetParent and block:GetParent()) or sortAnchorParent
    local modDb = sortActiveSelf and sortActiveSelf.db
    local blockOffsetX = (modDb and modDb.blockOffsetX) or block.offsetX or sortAnchorDefaultOffsetX
    block:SetPoint("LEFT", p, "LEFT", blockOffsetX, 0)
    if not block.fixedWidth then
        block:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    end
    sortAnchorPrev = block
end

function ObjectivesMod:SortTrackerBlocks(tracker)
    if self.IsEnabled and not self:IsEnabled() then return end
    if not self.db or self.db.enabled == false then return end
    if not tracker or not (tracker.IsShown and tracker:IsShown()) then return end
    if tracker ~= _G.QuestObjectiveTracker and tracker ~= _G.CampaignQuestObjectiveTracker then
        return
    end

    local forEachBlock = objState.ForEachTrackerBlock or self.ForEachTrackerBlock
    if not forEachBlock then return end

    for i = #sortPrefixBlocks, 1, -1 do sortPrefixBlocks[i] = nil end
    for i = #sortQuestEntries, 1, -1 do sortQuestEntries[i] = nil end
    sortEntryCount = 0
    sortActiveSelf = self

    forEachBlock(tracker, CollectTrackerSortBlock)

    if #sortQuestEntries <= 1 and #sortPrefixBlocks == 0 then
        sortActiveSelf = nil
        return
    end

    if self.db and self.db.sortQuestsByZone ~= false then
        local sortFunc = self.SortInfosByCurrentZone or (objState and objState.SortInfosByCurrentZone) or SortInfosByCurrentZone
        if sortFunc then
            sortFunc(sortQuestEntries)
        end
    else
        table.sort(sortQuestEntries, SortQuestEntriesByIndex)
    end

    sortAnchorParent = tracker.ContentsFrame or tracker
    sortAnchorFromHeader = tracker.fromHeaderOffsetY or -4
    sortAnchorFromBlock = tracker.fromBlockOffsetY or -2
    sortAnchorDefaultOffsetX = (self.db and self.db.blockOffsetX) or tracker.blockOffsetX or 4
    sortAnchorPrev = nil

    for _, pBlock in ipairs(sortPrefixBlocks) do
        AnchorOneSortedBlock(pBlock)
    end
    for _, entry in ipairs(sortQuestEntries) do
        AnchorOneSortedBlock(entry.block)
    end
    sortActiveSelf = nil
end

function ObjectivesMod:TrimTrackerGap(tracker)
    if not tracker or not tracker.SetHeight then return end
    if not (tracker.IsShown and tracker:IsShown()) then return end

    if tracker.IsCollapsed and tracker:IsCollapsed() then
        local rawCollapsedH = (tracker.Header and tracker.Header:GetHeight()) or tracker.headerHeight or 24
        local collapsedH = (not IsSecret(rawCollapsedH) and type(rawCollapsedH) == "number") and rawCollapsedH or 24
        local curCollapsedH = tracker.GetHeight and tracker:GetHeight()
        if not curCollapsedH or (not IsSecret(curCollapsedH) and type(curCollapsedH) == "number" and math.abs(curCollapsedH - collapsedH) > 0.5) then
            tracker:SetHeight(collapsedH)
        end
        return
    end

    local rawHeaderH = (tracker.Header and tracker.Header:IsShown() and tracker.Header:GetHeight()) or tracker.headerHeight or 20
    local headerH = (not IsSecret(rawHeaderH) and type(rawHeaderH) == "number") and rawHeaderH or 20
    local fromHeader = math.abs(tracker.fromHeaderOffsetY or 4)
    local fromBlock = math.abs(tracker.fromBlockOffsetY or 2)
    -- Compensate for Blizzard's hardcoded container moduleSpacing (10px) to tighten inter-module gaps
    local bottomPad = -6

    local mathHeight = headerH
    local activeBlockCount = 0

    local forEachBlock = objState.ForEachTrackerBlock or self.ForEachTrackerBlock
    if forEachBlock then
        forEachBlock(tracker, function(block)
            if block and block.used ~= false and (block.IsShown == nil or block:IsShown()) then
                local bh = (block.GetHeight and block:GetHeight()) or 0
                if not IsSecret(bh) and type(bh) == "number" and bh > 0 then
                    activeBlockCount = activeBlockCount + 1
                    if activeBlockCount == 1 then
                        mathHeight = mathHeight + fromHeader + bh
                    else
                        mathHeight = mathHeight + fromBlock + bh
                    end
                end
            end
        end)
    end

    if activeBlockCount > 0 then
        mathHeight = math.floor(mathHeight + bottomPad + 0.5)
    end

    local top = tracker.GetTop and tracker:GetTop()
    local lowest = nil
    if forEachBlock and not IsSecret(top) and type(top) == "number" then
        forEachBlock(tracker, function(block)
            if block and block.used ~= false and (block.IsShown == nil or block:IsShown()) and block.GetBottom then
                local b = block:GetBottom()
                if b and not IsSecret(b) and type(b) == "number" and (not lowest or b < lowest) then
                    lowest = b
                end
            end
        end)
    end
    if not lowest and tracker.Header and tracker.Header.IsShown and tracker.Header:IsShown() and tracker.Header.GetBottom then
        local hb = tracker.Header:GetBottom()
        if hb and not IsSecret(hb) and type(hb) == "number" then
            lowest = hb
        end
    end

    local desired = mathHeight
    if not IsSecret(top) and not IsSecret(lowest) and type(top) == "number" and type(lowest) == "number" and top > lowest then
        local geoDesired = math.floor(top - lowest + bottomPad + 0.5)
        if geoDesired > 0 then
            desired = geoDesired
        end
    end

    local rawCurrent = (tracker.GetHeight and tracker:GetHeight()) or 0
    local current = (not IsSecret(rawCurrent) and type(rawCurrent) == "number") and rawCurrent or 0
    if desired > 0 and math.abs(desired - current) > 0.5 then
        tracker:SetHeight(desired)
    end
end

