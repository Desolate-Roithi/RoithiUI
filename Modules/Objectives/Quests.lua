local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:GetModule("Objectives")
local objState = ns.Objectives or {}
ns.Objectives = objState

local skinnedBlocks = objState.skinnedBlocks
local titleFSCache = objState.titleFSCache

local questZoneCache = {}
local questTitleCache = {}

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
    if not str then return "" end
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

local function GetCurrentZoneHierarchy()
    local subzoneNames = {}
    local zoneNames = {}
    local subZone = _G.GetSubZoneText and _G.GetSubZoneText()
    if subZone and subZone ~= "" then
        subzoneNames[string.lower(SafeTrim(subZone))] = true
    end

    local realZone = _G.GetRealZoneText and _G.GetRealZoneText()
    if realZone and realZone ~= "" then
        zoneNames[string.lower(SafeTrim(realZone))] = true
    end
    local zone = _G.GetZoneText and _G.GetZoneText()
    if zone and zone ~= "" then
        zoneNames[string.lower(SafeTrim(zone))] = true
    end

    local currentMapID = _G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")
    local parentMapID = nil
    if currentMapID and _G.C_Map and _G.C_Map.GetMapInfo then
        local mapInfo = _G.C_Map.GetMapInfo(currentMapID)
        if mapInfo then
            if mapInfo.name and mapInfo.name ~= "" then
                subzoneNames[string.lower(SafeTrim(mapInfo.name))] = true
            end
            if mapInfo.parentMapID and mapInfo.parentMapID > 0 then
                parentMapID = mapInfo.parentMapID
                local parentInfo = _G.C_Map.GetMapInfo(parentMapID)
                if parentInfo and parentInfo.name and parentInfo.name ~= "" then
                    zoneNames[string.lower(SafeTrim(parentInfo.name))] = true
                end
            end
        end
    end

    return subzoneNames, zoneNames, currentMapID, parentMapID
end

local function GetQuestMapID(questID)
    if not questID then return nil end
    if _G.C_TaskQuest and _G.C_TaskQuest.GetQuestZoneID then
        local qMap = _G.C_TaskQuest.GetQuestZoneID(questID)
        if qMap and qMap > 0 then return qMap end
    end
    if _G.C_QuestLog and _G.C_QuestLog.GetMapForQuestPOIs then
        local pMap = _G.C_QuestLog.GetMapForQuestPOIs(questID)
        if pMap and pMap > 0 then return pMap end
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

local function SortInfosByCurrentZone(infos)
    if not infos or #infos <= 1 then return infos end

    UpdateQuestLogData()
    local subzoneNames, zoneNames, currentMapID, parentMapID = GetCurrentZoneHierarchy()

    local meta = {}
    for index, item in ipairs(infos) do
        local qObj = item.quest
        local qID = (type(qObj) == "table" and (qObj.questID or qObj.id))
            or (type(item) == "table" and (item.questID or item.id))
        local zName = GetQuestZone(qID)
        local tier = GetQuestSortTier(qID, zName, qObj, subzoneNames, zoneNames, currentMapID, parentMapID)
        local title = GetQuestSortTitle(qID, qObj)
        local level = GetQuestLevel(qID)
        meta[item] = {
            tier = tier,
            level = level,
            zone = zName or "",
            title = title or "",
            index = item.index or index,
        }
    end

    table.sort(infos, function(a, b)
        local mA = meta[a]
        local mB = meta[b]
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

        if mA.tier >= 5 and mA.zone ~= mB.zone then
            if mA.zone == "" then return false end
            if mB.zone == "" then return true end
            local lowerZoneA = string.lower(mA.zone)
            local lowerZoneB = string.lower(mB.zone)
            if lowerZoneA ~= lowerZoneB then
                return lowerZoneA < lowerZoneB
            end
        end

        if mA.title ~= mB.title and mA.title ~= "" and mB.title ~= "" then
            local lowerTitleA = string.lower(mA.title)
            local lowerTitleB = string.lower(mB.title)
            if lowerTitleA ~= lowerTitleB then
                return lowerTitleA < lowerTitleB
            end
        end

        return mA.index < mB.index
    end)

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

local function ForEachBlockLine(selfOrBlock, blockOrFunc, maybeFunc)
    local block = (type(selfOrBlock) == "table" and type(blockOrFunc) == "table" and blockOrFunc) or selfOrBlock
    local func = maybeFunc or (type(blockOrFunc) == "function" and blockOrFunc)
    if not block or not func then return end
    local seen = {}
    if block.usedLines then
        for _, line in pairs(block.usedLines) do
            if line and not seen[line] then
                seen[line] = true
                func(line)
            end
        end
    end
    if block.lines then
        for _, line in pairs(block.lines) do
            if line and not seen[line] then
                seen[line] = true
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
        if t and t ~= "" then
            if block then
                block.roithiBaseTitle = t
                block.roithiQuestID = questID
            end
            return t
        end
    end
    if block and block.roithiBaseTitle and block.roithiQuestID == questID then
        return block.roithiBaseTitle
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
        block.roithiBaseTitle = clean
        block.roithiQuestID = questID
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
    if not curText or curText == "" then return end

    local lvl = GetQuestLevel(questID)

    local colorCode = nil
    if lvl and lvl > 0 and _G.GetQuestDifficultyColor then
        local diff = _G.GetQuestDifficultyColor(lvl)
        if diff and diff.r then
            colorCode = string.format("|cff%02x%02x%02x", math.floor((diff.r or 1) * 255 + 0.5), math.floor((diff.g or 1) * 255 + 0.5), math.floor((diff.b or 1) * 255 + 0.5))
        end
    end
    if not colorCode then
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

    local baseText = GetCleanQuestTitle(block, questID, curText)

    local fc = self.db.foreverColor or (self.defaultSettings and self.defaultSettings.foreverColor) or { r = 0.22, g = 0.74, b = 0.97 }
    local infinityHex = string.format("ff%02x%02x%02x", math.floor((fc.r or 0.22) * 255 + 0.5), math.floor((fc.g or 0.74) * 255 + 0.5), math.floor((fc.b or 0.97) * 255 + 0.5))
    local infinityStr = string.format("|c%s\226\136\158|r", infinityHex)

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

    if titleFS:GetText() ~= newText then
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

function ObjectivesMod:UpdateBlockHoverObjectives(block, isHovered)
    if not block then return end

    local isPinned = self:IsQuestPinned(block)
    local isExpanded = isHovered or isPinned
    local hoverMode = self.db and self.db.hoverObjectiveText
    local hideCompleted = self.db and self.db.hideCompletedObjectives

    local headerHeight = GetBlockHeaderHeight(block)
    local lineSpacing = (block.parentModule and block.parentModule.lineSpacing) or 2
    local fullHeight = headerHeight + 2

    ForEachBlockLine(block, function(line)
        local isComp = IsLineCompleted(line, block)
        if hideCompleted and isComp then
            if line.Hide then line:Hide() end
            if line.SetAlpha then line:SetAlpha(0) end
            if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(0) end
            if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(0) end
            if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(0) end
            if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(0) end
            if line.SetHeight then line:SetHeight(0.001) end
        elseif not hoverMode or isExpanded then
            if line.Show then line:Show() end
            if line.SetAlpha then line:SetAlpha(1) end
            if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(1) end
            if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(1) end
            if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(1) end
            if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(1) end
            local lh = line.roithiOrigHeight
            if not lh or lh <= 1 then
                if line.Text and line.Text.GetStringHeight then
                    lh = line.Text:GetStringHeight()
                end
                if not lh or lh <= 1 then
                    lh = (line.Text and line.Text.GetHeight and line.Text:GetHeight()) or 14
                end
            end
            if not lh or lh < 14 then lh = 14 end
            line.roithiOrigHeight = lh
            if line.SetHeight then line:SetHeight(lh) end
            fullHeight = fullHeight + lh + lineSpacing
        else
            if line.Hide then line:Hide() end
            if line.SetAlpha then line:SetAlpha(0) end
            if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(0) end
            if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(0) end
            if line.Check and line.Check.SetAlpha then line.Check:SetAlpha(0) end
            if line.Icon and line.Icon.SetAlpha then line.Icon:SetAlpha(0) end
            if line.SetHeight then line:SetHeight(0.001) end
        end
    end)

    if block.SetHeight then
        local oldHeight = block.height or GetBlockHeaderHeight(block)
        local targetHeight = hoverMode and (isExpanded and fullHeight or headerHeight) or fullHeight
        if math.abs(oldHeight - targetHeight) > 1 then
            block:SetHeight(targetHeight)
            block.height = targetHeight
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
    if not title or title == "" then
        if _G.C_QuestLog and _G.C_QuestLog.GetTitleForQuestID then
            title = _G.C_QuestLog.GetTitleForQuestID(qid)
        end
    end
    if not title or title == "" then
        title = "Quest"
    end
    local cleanTitle = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

    tooltip:AddLine(cleanTitle, 1, 0.85, 0.35, true)

    local zone = GetQuestZone(qid)
    if zone and zone ~= "" then
        tooltip:AddLine(zone, 0.6, 0.6, 0.6)
    end

    if _G.C_QuestLog and _G.C_QuestLog.GetQuestObjectives then
        local ok, objs = pcall(_G.C_QuestLog.GetQuestObjectives, qid)
        if ok and objs and #objs > 0 then
            tooltip:AddLine(" ")
            for _, obj in ipairs(objs) do
                if obj.text and obj.text ~= "" then
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
    tooltip:AddDoubleLine("|cff9e9e9eAlt+Click:|r |cffffffffTrack|r", "|cff9e9e9eCtrl+Click:|r |cffffffffPin|r", 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)

    tooltip:Show()
end

function ObjectivesMod:HideQuestTooltip(block)
    if not _G.GameTooltip then return end
    if _G.GameTooltip:GetOwner() == block then
        _G.GameTooltip:Hide()
    end
end

