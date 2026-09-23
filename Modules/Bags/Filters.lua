local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local BagsMod = RoithiUI:NewModule("Bags", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

BagsMod.displayName = L["Bags"]
BagsMod.description = L["Modern unified bag display with category filter buttons and expandable bag bar."]
BagsMod.order = 80
BagsMod.dbKey = "Bags"

-- Category IDs
local CATEGORY_ALL = "ALL"
local CATEGORY_NEW = "NEW"
local CATEGORY_FAVORITES = "FAVORITES"
local CATEGORY_GEAR = "GEAR"
local CATEGORY_WEAPONS = "WEAPONS"
local CATEGORY_CONSUMABLES = "CONSUMABLES"
local CATEGORY_REAGENTS = "REAGENTS"
local CATEGORY_QUEST = "QUEST"
local CATEGORY_JUNK = "JUNK"
local CATEGORY_MISC = "MISC"
local CATEGORY_KEYRING = "KEYRING"

BagsMod.CATEGORIES = {
    { id = CATEGORY_ALL, name = L["All"], order = 1 },
    { id = CATEGORY_NEW, name = L["New"], order = 2 },
    { id = CATEGORY_FAVORITES, name = L["Favorites"], order = 3 },
    { id = CATEGORY_GEAR, name = L["Gear"], order = 4 },
    { id = CATEGORY_WEAPONS, name = L["Weapons"], order = 5 },
    { id = CATEGORY_CONSUMABLES, name = L["Consumables"], order = 6 },
    { id = CATEGORY_REAGENTS, name = L["Reagents"], order = 7 },
    { id = CATEGORY_QUEST, name = L["Quest"], order = 8 },
    { id = CATEGORY_JUNK, name = L["Junk"], order = 9 },
    { id = CATEGORY_MISC, name = L["Misc"], order = 10 },
}

if _G.WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC or _G.KeyRingButton then
    table.insert(BagsMod.CATEGORIES, { id = CATEGORY_KEYRING, name = L["Keyring"] or "Keyring", order = 11 })
end

BagsMod.defaultSettings = {
    enabled = true,
    slotSize = 36,
    spacing = 4,
    columns = 10,
    showItemLevel = true,
    qualityBorders = true,
    showEmptySlots = true,
    autoSellJunk = false,
    favorites = {},
    customFilters = {},
    activeCategory = CATEGORY_ALL,
    categoryOrder = {
        CATEGORY_ALL,
        CATEGORY_NEW,
        CATEGORY_FAVORITES,
        CATEGORY_GEAR,
        CATEGORY_WEAPONS,
        CATEGORY_CONSUMABLES,
        CATEGORY_REAGENTS,
        CATEGORY_QUEST,
        CATEGORY_JUNK,
        CATEGORY_MISC,
    },
    enabledCategories = {
        [CATEGORY_ALL] = true,
        [CATEGORY_NEW] = true,
        [CATEGORY_FAVORITES] = true,
        [CATEGORY_GEAR] = true,
        [CATEGORY_WEAPONS] = true,
        [CATEGORY_CONSUMABLES] = true,
        [CATEGORY_REAGENTS] = true,
        [CATEGORY_QUEST] = true,
        [CATEGORY_JUNK] = true,
        [CATEGORY_MISC] = true,
        [CATEGORY_KEYRING] = true,
    },
    bagBar = {
        enabled = true,
        expanded = false,
        buttonSize = 30,
        spacing = 4,
        point = "BOTTOMRIGHT",
        x = -10,
        y = 40,
    },
    bagWindow = {
        point = "BOTTOMRIGHT",
        x = -10,
        y = 80,
    },
}

function BagsMod:GetOrderedCategories()
    local order = (self.db and self.db.categoryOrder) or self.defaultSettings.categoryOrder
    local enabled = (self.db and self.db.enabledCategories) or self.defaultSettings.enabledCategories
    local catMap = {}
    for _, cat in ipairs(self.CATEGORIES) do
        catMap[cat.id] = cat
    end

    local result = {}
    if order then
        for _, catId in ipairs(order) do
            if (not enabled or enabled[catId] ~= false) and catMap[catId] then
                table.insert(result, catMap[catId])
            end
        end
    end

    if #result == 0 then
        for _, cat in ipairs(self.CATEGORIES) do
            table.insert(result, cat)
        end
    end

    -- Append saved custom search filters
    local customFilters = self.db and self.db.customFilters
    if customFilters and type(customFilters) == "table" then
        for _, custom in ipairs(customFilters) do
            if custom.id and custom.name then
                table.insert(result, {
                    id = custom.id,
                    name = custom.name,
                    query = custom.query or custom.name,
                    isCustom = true,
                })
            end
        end
    end

    return result
end

function BagsMod:ClassifyItem(itemData)
    if not itemData or not itemData.itemID then return CATEGORY_MISC end

    local favs = self.db and self.db.favorites
    if favs and favs[itemData.itemID] then
        return CATEGORY_FAVORITES
    end

    if itemData.quality == 0 then
        return CATEGORY_JUNK
    end
    if itemData.isQuest or (itemData.classID == 12) then
        return CATEGORY_QUEST
    end
    if itemData.classID == 2 then
        return CATEGORY_WEAPONS
    end
    if itemData.classID == 4 then
        return CATEGORY_GEAR
    end
    if itemData.classID == 0 then
        return CATEGORY_CONSUMABLES
    end
    if itemData.classID == 7 or itemData.isCraftingReagent or itemData.bag == 5 then
        return CATEGORY_REAGENTS
    end
    if itemData.bag == -2 or itemData.classID == 13 then
        return CATEGORY_KEYRING
    end

    return CATEGORY_MISC
end

function BagsMod:ItemMatchesCategory(itemData, activeCategory)
    if not itemData or not itemData.itemID then return false end

    if activeCategory == CATEGORY_ALL then
        return true
    end
    if activeCategory == CATEGORY_NEW then
        return itemData.isNew == true
    end
    if activeCategory == CATEGORY_FAVORITES then
        local favs = self.db.favorites or {}
        return favs[itemData.itemID] == true
    end
    if activeCategory == CATEGORY_GEAR then
        return itemData.classID == 4
    end
    if activeCategory == CATEGORY_WEAPONS then
        return itemData.classID == 2
    end
    if activeCategory == CATEGORY_CONSUMABLES then
        return itemData.classID == 0
    end
    if activeCategory == CATEGORY_REAGENTS then
        return itemData.classID == 7 or itemData.isCraftingReagent == true or itemData.bag == 5
    end
    if activeCategory == CATEGORY_QUEST then
        return itemData.isQuest == true or itemData.classID == 12
    end
    if activeCategory == CATEGORY_JUNK then
        return itemData.quality == 0
    end
    if activeCategory == CATEGORY_KEYRING then
        return itemData.bag == -2 or itemData.classID == 13
    end
    if activeCategory == CATEGORY_MISC then
        return itemData.quality ~= 0
            and not itemData.isQuest
            and itemData.classID ~= 12
            and itemData.classID ~= 2
            and itemData.classID ~= 4
            and itemData.classID ~= 0
            and itemData.classID ~= 7
            and not itemData.isCraftingReagent
            and itemData.bag ~= 5
            and itemData.bag ~= -2
    end

    -- Check custom saved filters
    local customFilters = self.db and self.db.customFilters
    if customFilters and type(customFilters) == "table" then
        for _, custom in ipairs(customFilters) do
            if custom.id == activeCategory then
                return self:MatchesSearchQuery(itemData, custom.query or custom.name)
            end
        end
    end

    return false
end

local function GetSafeTooltipText(itemData)
    if not itemData or not itemData.bag or not itemData.slot then return "" end
    local text = ""
    if _G.C_TooltipInfo and _G.C_TooltipInfo.GetBagItem then
        local data = _G.C_TooltipInfo.GetBagItem(itemData.bag, itemData.slot)
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                if line.leftText then
                    text = text .. " " .. line.leftText
                end
                if line.rightText then
                    text = text .. " " .. line.rightText
                end
            end
        end
    end
    return text:lower()
end

local QUALITY_NAME_MAP = {
    poor = 0, junk = 0, grey = 0, gray = 0,
    common = 1, white = 1,
    uncommon = 2, green = 2,
    rare = 3, blue = 3,
    epic = 4, purple = 4,
    legendary = 5, orange = 5,
    artifact = 6,
    heirloom = 7,
}

local EXPANSION_NAME_MAP = {
    classic = 0, vanilla = 0,
    tbc = 1, crusade = 1,
    wotlk = 2, wrath = 2, lichking = 2,
    cata = 3, cataclysm = 3,
    mop = 4, pandaria = 4,
    wod = 5, draenor = 5,
    legion = 6,
    bfa = 7, azeroth = 7,
    sl = 8, shadowlands = 8,
    df = 9, dragonflight = 9,
    tww = 10, warwithin = 10,
    midnight = 11,
}

--- Checks whether an item matches an advanced search query.
--- Supports partial matching and tokenized key:value tags:
---   name:<str>, type:<str>, bind:<bop|boe|bou|account>, reagent:<yes|no>,
---   exp:<name|id>, quality:<name|num>, ilvl:<[><=]num|range>, junk, gear, weapon, armor, new, fav,
---   boss:<str>, dropped-by:<str>, zone:<str>, dropped-in:<str>
--- Multiple tokens are combined with AND logic.
function BagsMod:MatchesSearchQuery(itemData, query)
    if not itemData or not itemData.itemID then return false end
    if not query or query == "" then return true end

    local cachedTooltip = nil
    local function GetTooltip()
        if not cachedTooltip then
            cachedTooltip = GetSafeTooltipText(itemData)
        end
        return cachedTooltip
    end

    local nameLower = (itemData.name or ""):lower()
    local typeLower = (itemData.itemType or ""):lower()
    local subTypeLower = (itemData.itemSubType or ""):lower()
    local equipLower = (itemData.equipLoc or ""):lower()

    for token in string.gmatch(query:lower(), "%S+") do
        local matched = false

        -- 1. name:<val> or n:<val>
        if token:find("^name:") or token:find("^n:") then
            local val = token:gsub("^name:", ""):gsub("^n:", "")
            matched = (nameLower:find(val, 1, true) ~= nil)

        -- 2. type:<val> or t:<val>
        elseif token:find("^type:") or token:find("^t:") then
            local val = token:gsub("^type:", ""):gsub("^t:", "")
            if val == "gear" then
                matched = (itemData.classID == 4 or itemData.classID == 2)
            elseif val == "weapon" or val == "weapons" then
                matched = (itemData.classID == 2)
            elseif val == "armor" then
                matched = (itemData.classID == 4)
            elseif val == "consumable" or val == "consumables" then
                matched = (itemData.classID == 0)
            elseif val == "reagent" or val == "reagents" then
                matched = (itemData.classID == 7 or itemData.isCraftingReagent == true)
            else
                matched = (typeLower:find(val, 1, true) ~= nil)
                    or (subTypeLower:find(val, 1, true) ~= nil)
                    or (equipLower:find(val, 1, true) ~= nil)
            end

        -- 3. bind:<val> or b:<val>
        elseif token:find("^bind:") or token:find("^b:") then
            local val = token:gsub("^bind:", ""):gsub("^b:", "")
            local tt = GetTooltip()
            if val == "bop" or val == "soulbound" then
                matched = (itemData.bindType == 1) or tt:find("soulbound", 1, true) or tt:find("binds when picked up", 1, true)
            elseif val == "boe" then
                matched = (itemData.bindType == 2) or tt:find("binds when equipped", 1, true)
            elseif val == "bou" then
                matched = (itemData.bindType == 3) or tt:find("binds when used", 1, true)
            elseif val == "account" or val == "boa" then
                matched = (itemData.bindType == 4) or tt:find("account", 1, true) or tt:find("warbound", 1, true)
            end

        -- 4. reagent:<yes|no> or r:<val>
        elseif token:find("^reagent:") or token:find("^r:") then
            local val = token:gsub("^reagent:", ""):gsub("^r:", "")
            local isReagent = (itemData.classID == 7 or itemData.isCraftingReagent == true or itemData.bag == 5)
            matched = (val == "no" or val == "false" or val == "0") and (not isReagent) or isReagent

        -- 5. exp:<val> or expansion:<val>
        elseif token:find("^exp:") or token:find("^expansion:") then
            local val = token:gsub("^expansion:", ""):gsub("^exp:", "")
            local targetID = EXPANSION_NAME_MAP[val] or tonumber(val)
            if targetID and itemData.expID ~= nil then
                matched = (itemData.expID == targetID)
            else
                local tt = GetTooltip()
                matched = (tt:find(val, 1, true) ~= nil)
            end

        -- 6. quality:<val> or q:<val>
        elseif token:find("^quality:") or token:find("^q:") then
            local val = token:gsub("^quality:", ""):gsub("^q:", "")
            local targetQ = QUALITY_NAME_MAP[val] or tonumber(val)
            if targetQ ~= nil then
                matched = (itemData.quality == targetQ)
            end

        -- 7. ilvl:<expr> or lvl:<expr>
        elseif token:find("^ilvl:") or token:find("^lvl:") then
            local expr = token:gsub("^ilvl:", ""):gsub("^lvl:", "")
            local curLvl = itemData.itemLevel or 0
            if expr:find("^>") then
                local num = tonumber(expr:sub(2)) or 0
                matched = (curLvl > num)
            elseif expr:find("^<") then
                local num = tonumber(expr:sub(2)) or 0
                matched = (curLvl < num)
            elseif expr:find("%-") then
                local minL, maxL = expr:match("(%d+)%-(%d+)")
                minL = tonumber(minL) or 0
                maxL = tonumber(maxL) or 9999
                matched = (curLvl >= minL and curLvl <= maxL)
            else
                local num = tonumber(expr) or 0
                matched = (curLvl == num)
            end

        -- 8. boss:<val> or dropped-by:<val>
        elseif token:find("^boss:") or token:find("^dropped%-by:") then
            local val = token:gsub("^dropped%-by:", ""):gsub("^boss:", ""):gsub("^%.", "")
            local tt = GetTooltip()
            matched = (tt:find(val, 1, true) ~= nil)

        -- 9. zone:<val> or dropped-in:<val>
        elseif token:find("^zone:") or token:find("^dropped%-in:") then
            local val = token:gsub("^dropped%-in:", ""):gsub("^zone:", "")
            local tt = GetTooltip()
            matched = (tt:find(val, 1, true) ~= nil)

        -- 10. Shorthand standalone flags
        elseif token == "junk" or token == "j" then
            matched = (itemData.quality == 0)
        elseif token == "new" then
            matched = (itemData.isNew == true)
        elseif token == "fav" or token == "favorite" or token == "favorites" then
            local favs = self.db.favorites or {}
            matched = (favs[itemData.itemID] == true)
        elseif token == "gear" then
            matched = (itemData.classID == 4 or itemData.classID == 2)
        elseif token == "weapon" or token == "weapons" then
            matched = (itemData.classID == 2)
        elseif token == "armor" then
            matched = (itemData.classID == 4)
        elseif token == "reagents" or token == "reagent" then
            matched = (itemData.classID == 7 or itemData.isCraftingReagent == true or itemData.bag == 5)

        -- 11. Generic partial string match
        else
            matched = (nameLower:find(token, 1, true) ~= nil)
                or (typeLower:find(token, 1, true) ~= nil)
                or (subTypeLower:find(token, 1, true) ~= nil)
                or (equipLower:find(token, 1, true) ~= nil)
        end

        if not matched then
            return false
        end
    end

    return true
end

function BagsMod:ItemMatchesFilter(itemData, activeCategory, searchText)
    if not itemData or not itemData.itemID then return false end

    if not self:ItemMatchesCategory(itemData, activeCategory) then
        return false
    end

    if searchText and searchText ~= "" then
        return self:MatchesSearchQuery(itemData, searchText)
    end

    return true
end
