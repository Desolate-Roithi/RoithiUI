local _, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

-- WoW APIs
local _G = _G
local type, tonumber, tostring, ipairs, string = type, tonumber, tostring, ipairs, string
local UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax = UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax
local UnitName, UnitClass, UnitRace, UnitLevel = UnitName, UnitClass, UnitRace, UnitLevel
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitGetTotalHealAbsorbs = _G.UnitGetTotalHealAbsorbs
local UnitIsConnected, UnitIsGhost, UnitIsDead = UnitIsConnected, UnitIsGhost, UnitIsDead
local UnitClassification, UnitCreatureFamily, UnitCreatureType = UnitClassification, UnitCreatureFamily, UnitCreatureType
local CreateFramePool, CreateFontStringPool = CreateFramePool, CreateFontStringPool
local strsplit = _G.strsplit or strsplit
local GetSpecialization = _G.GetSpecialization

-- 12.0.1 Secret APIs (Localized if present)
local C_UnitHealth = _G.C_UnitHealth
---@diagnostic disable-next-line: undefined-field
local C_UnitPower = _G.C_UnitPower
local CurveConstants = _G.CurveConstants
local UnitHealthPercent = _G.UnitHealthPercent
local UnitPowerPercent = _G.UnitPowerPercent
local SetShownFromSecret = _G.SetShownFromSecret


---@diagnostic disable-next-line: undefined-field
local UnitHealthDeficit = _G.UnitHealthDeficit

-- Missing Globals for Linter
---@diagnostic disable-next-line: undefined-field
local AbbreviateLargeNumbers = _G.AbbreviateLargeNumbers

-- Hoisted Class Abbreviation Map (Zero GC)
local CLASS_MAP = {
    ["DH"] = "DEMONHUNTER",
    ["DK"] = "DEATHKNIGHT",
    ["PALA"] = "PALADIN",
    ["WAR"] = "WARRIOR",
    ["WL"] = "WARLOCK",
    ["SH"] = "SHAMAN",
    ["DR"] = "DRUID",
    ["H"] = "HUNTER",
    ["M"] = "MAGE",
    ["PR"] = "PRIEST",
    ["ROG"] = "ROGUE",
    ["EVO"] = "EVOKER",
    ["MONK"] = "MONK"
}
---@diagnostic disable-next-line: undefined-field
local UnitHealthMissing = _G.UnitHealthMissing

---@class UF : AceAddon, AceModule
local UF = RoithiUI:GetModule("UnitFrames")

---@class TagManager
local TM = {}
UF.TagManager = TM



-- Helper: IsSecret predicate (centralized in Core/Utils.lua)
local IsSecret = ns.Utils.IsSecret

-- Helper: Shorten Number (12.0.1 Style K/M/B)
local function AbbreviateNumber(value)
    if value == nil then return "" end

    if IsSecret(value) then
        local abbrev = _G.AbbreviateLargeNumbers or AbbreviateLargeNumbers
        if abbrev then
            local success, result = ns.Utils.SafeCall(abbrev, value)
            if success and result ~= nil then return result end
        end
        return value
    end

    local abbrev = _G.AbbreviateLargeNumbers or AbbreviateLargeNumbers
    if abbrev then
        local success, result = ns.Utils.SafeCall(abbrev, value)
        if success and result ~= nil then
            return result
        end
    end

    if type(value) == "number" then
        local ok, str = ns.Utils.SafeCall(tostring, value)
        if ok and str then return str end
    end
    return value
end

local function WrapRoundedString(val)
    local strUtil = _G.C_StringUtil
    return strUtil.WrapString(strUtil.RoundToNearestString(val), "", "%")
end

-- Helper: Format Percentage with max 1 decimal place (e.g. 87.5% or 100%)
local function FormatPercent(value)
    if value == nil then return "" end
    if IsSecret(value) then
        local ok, formatted = ns.Utils.SafeCall(string.format, "%.1f%%", value)
        if ok and formatted ~= nil then return formatted end
        local strUtil = _G.C_StringUtil
        if strUtil and strUtil.RoundToNearestString and strUtil.WrapString then
            local ok2, roundedStr = ns.Utils.SafeCall(WrapRoundedString, value)
            if ok2 and roundedStr ~= nil then return roundedStr end
        end
        return value
    end

    if type(value) == "string" then
        local num = tonumber(value:match("^([%d%.]+)"))
        if num then
            value = num
        else
            return value
        end
    end

    if type(value) == "number" then
        local rounded = math.floor(value * 10 + 0.5) / 10
        if rounded % 1 == 0 then
            return string.format("%.0f%%", rounded)
        else
            return string.format("%.1f%%", rounded)
        end
    end

    return tostring(value)
end

local function CallHealthPercent(unit)
    local curve = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or (CurveConstants and CurveConstants.ScaleTo100)
    local fnHealthPercent = _G.UnitHealthPercent or UnitHealthPercent
    local pct = fnHealthPercent(unit, false, curve)
    return FormatPercent(pct)
end

local function CallHealthPercentText(unit)
    return C_UnitHealth and C_UnitHealth.GetHealthPercentText and C_UnitHealth.GetHealthPercentText(unit)
end

local function CallPowerPercent(unit)
    local curve = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or (CurveConstants and CurveConstants.ScaleTo100)
    local fnPowerPercent = _G.UnitPowerPercent or UnitPowerPercent
    local pType = _G.UnitPowerType(unit)
    local pct = fnPowerPercent(unit, pType, false, curve)
    return FormatPercent(pct)
end

local function CallPowerPercentText(unit)
    return C_UnitPower and C_UnitPower.GetPowerPercentText and C_UnitPower.GetPowerPercentText(unit)
end

local function CallManaPercent(unit)
    local curve = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or (CurveConstants and CurveConstants.ScaleTo100)
    local fnPowerPercent = _G.UnitPowerPercent or UnitPowerPercent
    local pct = fnPowerPercent(unit, 0, false, curve)
    return FormatPercent(pct)
end

local function CallPowerClassPercent(unit, pType)
    local curve = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or (CurveConstants and CurveConstants.ScaleTo100)
    local fnPowerPercent = _G.UnitPowerPercent or UnitPowerPercent
    local pct = fnPowerPercent(unit, pType, false, curve)
    return FormatPercent(pct)
end

-- ----------------------------------------------------------------------------
-- 1. Tag Methods (Data Providers)
-- ----------------------------------------------------------------------------
TM.Methods = {
    ["name"] = function(unit) return UnitName(unit) or "Unknown" end,
    ["class"] = function(unit) return UnitClass(unit) or "" end,
    ["race"] = function(unit) return UnitRace(unit) or "" end,
    ["level"] = function(unit) return UnitLevel(unit) or "" end,

    -- Health
    ["health.current"] = function(unit) return UnitHealth(unit) end,
    ["health.maximum"] = function(unit) return UnitHealthMax(unit) end,
    ["health.missing"] = function(unit)
        local cur, max = UnitHealth(unit), UnitHealthMax(unit)
        local isActuallySecret = IsSecret(cur) or IsSecret(max)

        if isActuallySecret then
            local fn = _G.UnitHealthDeficit or UnitHealthDeficit
            if fn then
                local ok, def = ns.Utils.SafeCall(fn, unit)
                if ok and def then
                    local abbrev = _G.AbbreviateLargeNumbers or AbbreviateLargeNumbers
                    if abbrev then
                        local ok2, res = ns.Utils.SafeCall(abbrev, def)
                        if ok2 and res ~= nil then return res end
                    end
                    return def
                end
            end
            local fnMissing = _G.UnitHealthMissing or UnitHealthMissing
            if fnMissing then
                local okM, mVal = ns.Utils.SafeCall(fnMissing, unit)
                if okM and mVal then return mVal end
            end
            return ""
        end

        local missing = (max or 0) - (cur or 0)
        if missing > 0 then return missing end
        return ""
    end,
    ["health.percent"] = function(unit)
        local cur, max = UnitHealth(unit), UnitHealthMax(unit)
        local isActuallySecret = IsSecret(cur) or IsSecret(max)

        if isActuallySecret then
            -- Secondary Fallback: UnitHealthPercent with curve
            local fnHealthPercent = _G.UnitHealthPercent or UnitHealthPercent
            if fnHealthPercent then
                local success, result = ns.Utils.SafeCall(CallHealthPercent, unit)
                if success and result then return result end
            end

            -- Fallback to official text API
            local success2, result2 = ns.Utils.SafeCall(CallHealthPercentText, unit)
            if success2 and result2 then return FormatPercent(result2) end

            return ""
        end

        if not max or max == 0 then return "0%" end
        return FormatPercent((cur / max) * 100)
    end,

    -- Power
    ["power.current"] = function(unit) return UnitPower(unit) end,
    ["power.maximum"] = function(unit) return UnitPowerMax(unit) end,
    ["power.percent"] = function(unit)
        local cur, max = UnitPower(unit), UnitPowerMax(unit)
        local isActuallySecret = IsSecret(cur) or IsSecret(max)

        if isActuallySecret then
            -- Secondary Fallback: UnitPowerPercent with curve
            local fnPowerPercent = _G.UnitPowerPercent or UnitPowerPercent
            if fnPowerPercent and _G.UnitPowerType then
                local success, result = ns.Utils.SafeCall(CallPowerPercent, unit)
                if success and result then return result end
            end

            local success2, result2 = ns.Utils.SafeCall(CallPowerPercentText, unit)
            if success2 and result2 then return FormatPercent(result2) end

            return ""
        end

        if not max or max == 0 then return "0%" end
        return FormatPercent((cur / max) * 100)
    end,

    ["power.missing"] = function(unit)
        local cur, max = UnitPower(unit), UnitPowerMax(unit)
        local isActuallySecret = IsSecret(cur) or IsSecret(max)

        if isActuallySecret then
            -- Note: No native UnitPowerMissing exists for secrets usually,
            -- but we can return the value to be abbreviated if it's a number-like secret.
            -- However, usually Power isn't "missing" in the same way health is.
            -- For simplicity, if secret, returns empty as we can't do math.
            return ""
        end

        local missing = max - cur
        if missing > 0 then return missing end
        return ""
    end,

    -- Class Power / Advanced Power (New for 12.0.1)
    -- Renamed from classpower.* to power.class.*
    ["power.class"] = function(unit)
        if unit ~= "player" then return "" end
        local _, class = UnitClass("player")
        local getSpec = GetSpecialization or _G.GetSpecialization
        local spec = getSpec and getSpec() or 1
        local classConfig = UF.ClassPowerConfig and UF.ClassPowerConfig[class]
        local config = nil

        if classConfig then
            if classConfig[spec] then
                config = classConfig[spec]
            elseif classConfig.mode then
                config = classConfig
            end
        end
        if not config then return "" end
        if config.spec and config.spec ~= spec then return "" end

        if config.mode == "AURA" then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(config.spellID)
            if not aura and config.backupID then aura = C_UnitAuras.GetPlayerAuraBySpellID(config.backupID) end

            if config.requireAura and not aura then return "" end

            local apps = aura and aura.applications or 0
            if IsSecret(apps) then return "" end
            return apps
        elseif config.mode == "POWER" then
            return UnitPower("player", config.type)
        end
        return ""
    end,

    ["power.class.max"] = function(unit)
        if unit ~= "player" then return "" end
        local _, class = UnitClass("player")
        local getSpec = GetSpecialization or _G.GetSpecialization
        local spec = getSpec and getSpec() or 1
        local classConfig = UF.ClassPowerConfig and UF.ClassPowerConfig[class]
        local config = nil

        if classConfig then
            if classConfig[spec] then
                config = classConfig[spec]
            elseif classConfig.mode then
                config = classConfig
            end
        end
        if not config then return "" end
        if config.spec and config.spec ~= spec then return "" end

        local max = config.maxDisplay or 5
        if config.mode == "AURA" then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(config.spellID)
            if not aura and config.backupID then aura = C_UnitAuras.GetPlayerAuraBySpellID(config.backupID) end

            if config.requireAura and not aura then return "" end

            if aura and aura.maxStack then
                if IsSecret(aura.maxStack) then return aura.maxStack end
                if aura.maxStack > 0 then
                    max = aura.maxStack
                    if class == "SHAMAN" then max = 5 end
                end
            end
            return max
        elseif config.mode == "POWER" then
            local pMax = UnitPowerMax("player", config.type)
            if IsSecret(pMax) then return pMax end
            if pMax and pMax > 0 then max = pMax end
            return max
        end
        return ""
    end,

    ["power.class.percent"] = function(unit)
        if unit ~= "player" then return "" end
        local _, class = UnitClass("player")
        local getSpec = GetSpecialization or _G.GetSpecialization
        local spec = getSpec and getSpec() or 1
        local classConfig = UF.ClassPowerConfig and UF.ClassPowerConfig[class]
        local config = nil

        if classConfig then
            if classConfig[spec] then
                config = classConfig[spec]
            elseif classConfig.mode then
                config = classConfig
            end
        end
        if not config or (config.spec and config.spec ~= spec) then return "" end

        local cur, max = 0, config.maxDisplay or 5

        if config.mode == "AURA" then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(config.spellID)
            if not aura and config.backupID then aura = C_UnitAuras.GetPlayerAuraBySpellID(config.backupID) end

            if config.requireAura and not aura then return "" end

            local apps = aura and aura.applications or 0
            if IsSecret(apps) then
                cur = 0
            else
                cur = apps
            end
            if aura and aura.maxStack and not IsSecret(aura.maxStack) and aura.maxStack > 0 then
                max = aura.maxStack
                if class == "SHAMAN" then max = 5 end
            end
        elseif config.mode == "POWER" then
            cur = UnitPower("player", config.type)
            local pMax = UnitPowerMax("player", config.type)
            if IsSecret(pMax) then
                max = pMax
            elseif pMax and pMax > 0 then
                max = pMax
            end
        end

        if IsSecret(cur) or IsSecret(max) then
            local fnPowerPercent = _G.UnitPowerPercent or UnitPowerPercent
            if fnPowerPercent then
                local success, result = ns.Utils.SafeCall(CallPowerClassPercent, unit, config.type)
                if success and result then return result end
            end
            return ""
        end

        if max == 0 then return "0%" end
        return FormatPercent((cur / max) * 100)
    end,

    -- Additional Power (Mana when in form)
    ["power.add.current"] = function(unit)
        if UnitPowerType(unit) == 0 then return "" end -- Primary is already Mana

        local cur = UnitPower(unit, 0)
        local max = UnitPowerMax(unit, 0)
        -- Secret Safety
        if IsSecret(cur) or IsSecret(max) then return cur end
        if not max or max == 0 then return "" end

        return cur
    end,

    ["power.add.maximum"] = function(unit)
        if UnitPowerType(unit) == 0 then return "" end

        local max = UnitPowerMax(unit, 0)
        -- Secret Safety
        if IsSecret(max) then return max end
        if not max or max == 0 then return "" end

        return max
    end,

    ["power.add.percent"] = function(unit)
        if UnitPowerType(unit) == 0 then return "" end

        local cur = UnitPower(unit, 0)
        local max = UnitPowerMax(unit, 0)

        -- Handle Secrets via Helper API
        if IsSecret(cur) or IsSecret(max) then
            local fnPowerPercent = _G.UnitPowerPercent or UnitPowerPercent
            if fnPowerPercent then
                local success, result = ns.Utils.SafeCall(CallManaPercent, unit)
                if success and result then return result end
            end
            return ""
        end

        if not max or max == 0 then return "" end
        return FormatPercent((cur / max) * 100)
    end,

    ["power.add.missing"] = function(unit)
        if UnitPowerType(unit) == 0 then return "" end

        local cur = UnitPower(unit, 0)
        local max = UnitPowerMax(unit, 0)

        if IsSecret(cur) or IsSecret(max) then return "" end
        if not max or max == 0 then return "" end

        local missing = max - cur
        if missing > 0 then return missing end
        return ""
    end,

    -- Monk Stagger
    ["power.stagger"] = function(unit)
        local stagger = UnitStagger and UnitStagger(unit)
        if not stagger then return "" end
        if IsSecret(stagger) then return stagger end
        if stagger == 0 then return "" end
        return stagger
    end,

    ["power.stagger.percent"] = function(unit)
        local stagger = UnitStagger and UnitStagger(unit)
        if not stagger then return "" end
        if IsSecret(stagger) then return "" end
        if stagger == 0 then return "" end

        local healthMax = UnitHealthMax(unit)
        if not healthMax then return "" end
        if IsSecret(healthMax) then return "" end
        if healthMax == 0 then return "" end

        return FormatPercent((stagger / healthMax) * 100)
    end,

    -- Absorb
    ["absorb"] = function(unit)
        local absorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0
        if IsSecret(absorb) then return absorb end
        if type(absorb) == "number" and absorb > 0 then return absorb end
        return ""
    end,

    ["healabsorb"] = function(unit)
        local healAbsorb = 0
        if UnitGetTotalHealAbsorbs then healAbsorb = UnitGetTotalHealAbsorbs(unit) or 0 end
        if IsSecret(healAbsorb) then return healAbsorb end
        if type(healAbsorb) == "number" and healAbsorb > 0 then return healAbsorb end
        return ""
    end,

    -- Status & Classification
    ["status"] = function(unit)
        local conn = UnitIsConnected(unit)
        if not IsSecret(conn) and conn == false then return "Offline" end
        local ghost = UnitIsGhost(unit)
        if not IsSecret(ghost) and (ghost == true or ghost == 1) then return "Ghost" end
        local dead = UnitIsDead(unit)
        if not IsSecret(dead) and (dead == true or dead == 1) then return "Dead" end
        return ""
    end,

    ["classification"] = function(unit)
        local c = UnitClassification(unit)
        if IsSecret(c) or not c then return "" end
        if c == "worldboss" or c == "boss" then return "Boss" end
        if c == "elite" then return "Elite" end
        if c == "rareelite" then return "Rare-Elite" end
        if c == "rare" then return "Rare" end
        return ""
    end,

    ["creature"] = function(unit)
        local fam = UnitCreatureFamily(unit)
        if fam and not IsSecret(fam) then return fam end
        local ct = UnitCreatureType(unit)
        if ct and not IsSecret(ct) then return ct end
        return ""
    end,

    ["difficulty"] = function(unit)
        if not UnitExists(unit) then return "" end
        local level = UnitLevel(unit)
        if IsSecret(level) or not level then return "" end
        if level == -1 then return "Boss" end
        return level
    end,
}

-- ----------------------------------------------------------------------------
-- 2. Parsing & Formatting
-- ----------------------------------------------------------------------------

local tokenTemplateCache = {}
local function GetParsedTokens(fmt)
    local tokens = tokenTemplateCache[fmt]
    if tokens then return tokens end
    tokens = {}
    local lastPos = 1
    for startPos, token, endPos in fmt:gmatch("()@([%w_%.%:]+)()") do
        if startPos > lastPos then
            table.insert(tokens, { isTag = false, text = fmt:sub(lastPos, startPos - 1) })
        end
        local tagName, modifier = strsplit(":", token)
        if tagName == "classpower.current" then tagName = "power.class" end
        if tagName == "classpower.maximum" then tagName = "power.class.max" end
        if tagName == "classpower.percent" then tagName = "power.class.percent" end
        table.insert(tokens, { isTag = true, tag = tagName, modifier = modifier, rawToken = "@" .. token })
        lastPos = endPos
    end
    if lastPos <= #fmt then
        table.insert(tokens, { isTag = false, text = fmt:sub(lastPos) })
    end
    tokenTemplateCache[fmt] = tokens
    return tokens
end

local function WipeArray(tbl)
    if _G.wipe then
        _G.wipe(tbl)
    else
        for i = #tbl, 1, -1 do
            tbl[i] = nil
        end
    end
    return tbl
end

local function AcquireSegmentNode(outNodePool, idx, text, isTag, tag)
    if outNodePool then
        local node = outNodePool[idx]
        if not node then
            node = {}
            outNodePool[idx] = node
        end
        node.text = text
        node.isTag = isTag
        node.tag = tag
        return node
    end
    return { text = text, isTag = isTag, tag = tag }
end

local function ClearSegmentNodePool(outNodePool, startIdx)
    if not outNodePool then return end
    for i = startIdx, #outNodePool do
        local node = outNodePool[i]
        node.text = nil
        node.tag = nil
    end
end

function TM:GetSegments(formatString, unit, outResult, outNodePool)
    if not formatString then
        ClearSegmentNodePool(outNodePool, 1)
        return outResult and WipeArray(outResult) or {}
    end

    -- 1. Conditional Logic [type](format) for Power Type
    if formatString:find("%[") then
        local _, pToken = UnitPowerType(unit or "player")
        if pToken and not IsSecret(pToken) then
            local currentPower = pToken:upper()
            for cond, content in formatString:gmatch("%[([^%]]+)%]%(([^%)]+)%)") do
                if cond:upper() == currentPower then
                    return TM:GetSegments(content, unit, outResult, outNodePool)
                end
            end
        end
        local stripped = formatString:gsub("%[([^%]]+)%]%(([^%)]+)%)%s?", "")
        formatString = stripped
    end

    -- 2. Conditional Logic {class:spec}(format)
    -- Supports {DH:3}(...) or {MAGE}(...)
    if formatString:find("%{") then
        local _, class = UnitClass(unit or "player")
        local getSpec = GetSpecialization or _G.GetSpecialization
        local spec = getSpec and getSpec()

        if class and not IsSecret(class) then
            -- Iterate all {cond}(content) blocks
            for cond, content in formatString:gmatch("%{([^%}]+)%}%(([^%)]+)%)") do
                local reqClass, reqSpec = strsplit(":", cond)
                reqClass = reqClass and reqClass:upper()

                -- Resolve Abbr
                if CLASS_MAP[reqClass] then reqClass = CLASS_MAP[reqClass] end

                local classMatch = (reqClass == class)
                local specMatch = true

                if reqSpec then
                    if not spec or IsSecret(spec) or tonumber(reqSpec) ~= spec then specMatch = false end
                end

                if classMatch and specMatch then
                    return TM:GetSegments(content, unit, outResult, outNodePool)
                end
            end
        end

        -- If conditional blocks existed but none matched context, strip them
        local stripped = formatString:gsub("%{([^%}]+)%}%(([^%)]+)%)%s?", "")
        formatString = stripped
    end

    -- Tokenization via cached template
    local tokens = GetParsedTokens(formatString)
    local result = outResult and WipeArray(outResult) or {}
    local nodeCount = 0

    for _, token in ipairs(tokens) do
        if not token.isTag then
            nodeCount = nodeCount + 1
            result[nodeCount] = AcquireSegmentNode(outNodePool, nodeCount, token.text, false, nil)
        else
            local tagName = token.tag
            local method = TM.Methods[tagName]
            if method then
                local success, val = ns.Utils.SafeCall(method, unit)
                if success then
                    if token.modifier and token.modifier:lower() == "short" then
                        val = AbbreviateNumber(val)
                    end

                    if type(val) == "table" then
                        for _, subVal in ipairs(val) do
                            nodeCount = nodeCount + 1
                            result[nodeCount] = AcquireSegmentNode(outNodePool, nodeCount, subVal, true, tagName)
                        end
                    else
                        nodeCount = nodeCount + 1
                        result[nodeCount] = AcquireSegmentNode(outNodePool, nodeCount, val, true, tagName)
                    end
                else
                    RoithiUI:Log("|cffff0000[RoithiUI Tag Error]|r", tagName, val)
                    nodeCount = nodeCount + 1
                    result[nodeCount] = AcquireSegmentNode(outNodePool, nodeCount, "<Err>", true, nil)
                end
            else
                nodeCount = nodeCount + 1
                result[nodeCount] = AcquireSegmentNode(outNodePool, nodeCount, token.rawToken, false, nil)
            end
        end
    end

    ClearSegmentNodePool(outNodePool, nodeCount + 1)
    return result
end

-- ----------------------------------------------------------------------------
-- 3. Core System (Create & Update)
-- ----------------------------------------------------------------------------
function UF:CreateTags(frame)
    if not frame.Tags then frame.Tags = {} end
    frame.UpdateTags = function() self:UpdateTags(frame) end
end

local function GetEffectiveTagUnit(unit)
    if unit == "player" then
        if (_G.UnitHasVehicleUI and _G.UnitHasVehicleUI("player")) or (_G.UnitInVehicle and _G.UnitInVehicle("player")) then
            if _G.UnitExists("vehicle") then
                return "vehicle"
            end
        end
    end
    return unit
end

function UF:UpdateTags(frame)
    local unit = GetEffectiveTagUnit(frame.unit)

    -- Boss Inheritance: Boss 2-5 use Boss 1 settings
    local dbUnit = unit
    if unit == "vehicle" then
        dbUnit = "player" -- Fallback to player settings for vehicle
    elseif unit and unit:match("^boss[2-5]$") then
        dbUnit = "boss1"
    end

    local db = RoithiUI.db.profile.UnitFrames[dbUnit]

    if not frame.TagsPool then
        local createPool = CreateFramePool or _G.CreateFramePool
        if not createPool then return end
        frame.TagsPool = createPool("Frame", frame, nil, function(_, f)
            f:Hide()
            f:ClearAllPoints()
            if f.SegmentPool then
                f.SegmentPool:ReleaseAll()
            end
            if f.segmentScratch then
                WipeArray(f.segmentScratch)
            end
            ClearSegmentNodePool(f.segmentNodePool, 1)
            f.activeFontStrings = nil
            f.appliedPoint = nil
            f.appliedCount = nil
            f.appliedFontKey = nil
        end)
    end

    frame.TagsPool:ReleaseAll()
    if not db or not db.tags then return end

    -- Sort tags by order (Low -> High)
    local sortedTags = {}
    for _, tagConfig in ipairs(db.tags) do
        table.insert(sortedTags, tagConfig)
    end
    table.sort(sortedTags, function(a, b)
        return (a.order or 10) < (b.order or 10)
    end)

    for i, tagConfig in ipairs(sortedTags) do
        if tagConfig.enabled then
            local tagFrame = frame.TagsPool:Acquire()

            -- Segment Pool for individual FontStrings
            if not tagFrame.SegmentPool then
                local createFSPool = CreateFontStringPool or _G.CreateFontStringPool
                if createFSPool then
                    tagFrame.SegmentPool = createFSPool(tagFrame, "OVERLAY")
                end
            end
            tagFrame.SegmentPool:ReleaseAll()
            tagFrame.activeFontStrings = nil
            tagFrame.appliedPoint = nil
            tagFrame.appliedCount = nil
            tagFrame.appliedFontKey = nil

            -- Anchor to frame or specific element
            local point = tagConfig.point or "CENTER"
            local relativeTo = frame
            local healthBar = frame.Health or frame.SafeHealth
            if tagConfig.anchorTo == "Health" and healthBar then
                relativeTo = healthBar
            elseif tagConfig.anchorTo == "Power" and frame.Power then
                relativeTo = frame.Power
            elseif tagConfig.anchorTo == "ClassPower" and frame.ClassPower then
                relativeTo = frame.ClassPower
            elseif tagConfig.anchorTo == "AdditionalPower" and frame.AdditionalPower then
                relativeTo = frame.AdditionalPower
            end

            tagFrame:SetParent(relativeTo)
            tagFrame:SetFrameLevel(relativeTo:GetFrameLevel() + 20 + i)
            tagFrame:SetSize(200, 20)
            tagFrame:ClearAllPoints()
            tagFrame:SetPoint(point, relativeTo, point, tagConfig.x or 0, tagConfig.y or 0)

            tagFrame.formatString = tagConfig.formatString
            tagFrame.font = tagConfig.font
            tagFrame.fontSize = tagConfig.fontSize or 12
            tagFrame.fontOutline = tagConfig.fontOutline
            tagFrame.point = point -- Save point for alignment logic
            tagFrame.unit = unit
            tagFrame:Show()

            -- Initial Render
            UF:UpdateTagFrame(tagFrame)
        end
    end
end

-- ----------------------------------------------------------------------------
-- 4. Event Handling
-- ----------------------------------------------------------------------------

function UF:UpdateTagFrame(tagFrame)
    if not tagFrame.SegmentPool then return end

    local unit = tagFrame.unit or "player"
    if unit == "player" then
        unit = GetEffectiveTagUnit("player")
    end

    tagFrame.segmentScratch = tagFrame.segmentScratch or {}
    tagFrame.segmentNodePool = tagFrame.segmentNodePool or {}
    local segments = TM:GetSegments(tagFrame.formatString, unit, tagFrame.segmentScratch, tagFrame.segmentNodePool)
    local count = #segments
    if count == 0 then
        if tagFrame.SegmentPool.ReleaseAll then
            tagFrame.SegmentPool:ReleaseAll()
        end
        tagFrame.activeFontStrings = nil
        tagFrame.appliedPoint = nil
        tagFrame.appliedCount = nil
        tagFrame.appliedFontKey = nil
        return
    end

    local point = tagFrame.point or "CENTER"
    local fontStrings = tagFrame.activeFontStrings
    local needsReanchor = (not fontStrings) or (#fontStrings ~= count) or (tagFrame.appliedPoint ~= point)
        or (fontStrings[1] and fontStrings[1].GetNumPoints and fontStrings[1]:GetNumPoints() == 0)

    if needsReanchor then
        if tagFrame.SegmentPool.ReleaseAll then
            tagFrame.SegmentPool:ReleaseAll()
        end
        fontStrings = {}
        tagFrame.activeFontStrings = fontStrings
        tagFrame.appliedPoint = point
        tagFrame.appliedCount = count
        for i = 1, count do
            fontStrings[i] = tagFrame.SegmentPool:Acquire()
            fontStrings[i]:ClearAllPoints()
        end

        -- 12.0.1: Robust anchoring without math (no GetStringWidth needed)
        if point:find("LEFT") then
            -- Flush Left: S1 at LEFT, Sn to the right of Sn-1
            fontStrings[1]:SetPoint("LEFT", tagFrame, "LEFT")
            for i = 2, count do
                fontStrings[i]:SetPoint("LEFT", fontStrings[i - 1], "RIGHT")
            end
        elseif point:find("RIGHT") then
            -- Flush Right: Sn at RIGHT, Sn-1 to the left of Sn
            fontStrings[count]:SetPoint("RIGHT", tagFrame, "RIGHT")
            for i = count - 1, 1, -1 do
                fontStrings[i]:SetPoint("RIGHT", fontStrings[i + 1], "LEFT")
            end
        else
            -- CENTER: Clustered around the center
            if count % 2 == 1 then
                -- Odd count: Middle segment at CENTER
                local mid = (count + 1) / 2
                fontStrings[mid]:SetPoint("CENTER", tagFrame, "CENTER")
                -- Build out from middle
                for i = mid - 1, 1, -1 do
                    fontStrings[i]:SetPoint("RIGHT", fontStrings[i + 1], "LEFT")
                end
                for i = mid + 1, count do
                    fontStrings[i]:SetPoint("LEFT", fontStrings[i - 1], "RIGHT")
                end
            else
                -- Even count: Junction of mid/mid+1 at CENTER
                local mid1 = count / 2
                local mid2 = mid1 + 1
                fontStrings[mid1]:SetPoint("RIGHT", tagFrame, "CENTER")
                fontStrings[mid2]:SetPoint("LEFT", tagFrame, "CENTER")
                -- Build out from junction
                for i = mid1 - 1, 1, -1 do
                    fontStrings[i]:SetPoint("RIGHT", fontStrings[i + 1], "LEFT")
                end
                for i = mid2 + 1, count do
                    fontStrings[i]:SetPoint("LEFT", fontStrings[i - 1], "RIGHT")
                end
            end
        end
    end

    local fontName = tagFrame.font or (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.unitFrameFont) or "Roithi Thick"
    local fontOutline = tagFrame.fontOutline or (RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.fontOutline) or "OUTLINE"
    local fontSize = tagFrame.fontSize or 12
    local updateTypo = needsReanchor or (tagFrame.appliedFontName ~= fontName or tagFrame.appliedFontSize ~= fontSize or tagFrame.appliedFontOutline ~= fontOutline)
    if updateTypo then
        tagFrame.appliedFontName = fontName
        tagFrame.appliedFontSize = fontSize
        tagFrame.appliedFontOutline = fontOutline
    end

    local utils = ns.Utils or (_G.RoithiUI and _G.RoithiUI.Utils)
    for i, segment in ipairs(segments) do
        local fs = fontStrings[i]
        local needsFont = updateTypo or (fs and fs.GetFont and not fs:GetFont())
        if needsFont and utils and utils.ApplyTypography then
            utils.ApplyTypography(fs, fontName, fontSize, fontOutline, false, "Roithi Thick")
        end
        if needsFont and fs.SetDrawLayer then fs:SetDrawLayer("OVERLAY", 7) end

        -- Direct pass-through: set text natively without comparison
        fs:SetText(segment.text)

        -- 12.0.1 Secret Zero-Hiding for specific tags
        local isSecret = IsSecret(segment.text)
        if segment.isTag and (segment.tag == "absorb" or segment.tag == "healabsorb") then
            if isSecret then
                if SetShownFromSecret then
                    SetShownFromSecret(fs, segment.text)
                else
                    fs:Show()
                end
            elseif segment.text == 0 or segment.text == "0" or segment.text == "" or segment.text == nil then
                fs:Hide()
            else
                fs:Show()
            end
        else
            fs:Show()
        end
    end
end

function UF:UpdateCustomTags(frame)
    if frame.TagsPool then
        for tagFrame in frame.TagsPool:EnumerateActive() do
            self:UpdateTagFrame(tagFrame)
        end
    end
end

local function IsDirectUnitToken(u)
    if not u or type(u) ~= "string" then return false end
    return u == "player" or u == "target" or u == "focus" or u == "pet" or u:find("^boss%d+$") ~= nil
end

function UF:EnableTags(frame)
    if frame.RoithiTagsHooked then return end

    local function UpdateTags() self:UpdateCustomTags(frame) end
    local function DelayedUpdateTags()
        if frame.UpdateTags then frame.UpdateTags() else UpdateTags() end
    end

    -- Unified Event Handler for oUF
    local function OnTagEvent(_, event, unit)
        -- Standard Unit Events
        -- Use SafeUnitIsUnit to handle dynamic units (e.g., targettarget == player)
        local effectiveUnit = GetEffectiveTagUnit(frame.unit)
        local match = false
        if unit and frame.unit then
            if unit == frame.unit or unit == effectiveUnit then
                match = true
            elseif ns.Utils and ns.Utils.SafeUnitIsUnit then
                local isMatch = ns.Utils.SafeUnitIsUnit(unit, frame.unit)
                match = isMatch
            end
        end

        if match then
            if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
                if _G.C_Timer and _G.C_Timer.After then
                    _G.C_Timer.After(0.1, DelayedUpdateTags)
                else
                    DelayedUpdateTags()
                end
            else
                UpdateTags()
            end
            -- Context Switch Events
        elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(0.1, DelayedUpdateTags)
            else
                DelayedUpdateTags()
            end
        elseif event == "UNIT_TARGET" then
            UpdateTags()
        end
    end

    -- Create a dedicated listener frame to ensure events are caught properly
    local listener = CreateFrame("Frame", nil, frame)
    listener:SetScript("OnEvent", OnTagEvent)

    -- Key events for stats
    if frame.unit then
        local STAT_EVENTS = {
            "UNIT_HEALTH",
            "UNIT_MAXHEALTH",
            "UNIT_POWER_UPDATE",
            "UNIT_MAXPOWER",
            "UNIT_DISPLAYPOWER",
            "UNIT_NAME_UPDATE",
            "UNIT_LEVEL",
            "UNIT_ABSORB_AMOUNT_CHANGED",
            "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
            "UNIT_AURA",
            "UNIT_ENTERED_VEHICLE",
            "UNIT_EXITED_VEHICLE",
        }

        local isDirect = IsDirectUnitToken(frame.unit)
        for _, ev in ipairs(STAT_EVENTS) do
            if isDirect and listener.RegisterUnitEvent then
                if frame.unit == "player" then
                    ns.Utils.SafeCall(listener.RegisterUnitEvent, listener, ev, "player", "vehicle")
                else
                    ns.Utils.SafeCall(listener.RegisterUnitEvent, listener, ev, frame.unit)
                end
            else
                ns.Utils.SafeCall(listener.RegisterEvent, listener, ev)
            end
        end
    end

    -- Context events for target switching (Must be declared unitless)
    if frame.unit == "target" then
        listener:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        listener:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "targettarget" or frame.unit == "focustarget" or frame.unit == "pettarget" then
        listener:RegisterEvent("UNIT_TARGET")
    end

    -- Also update on Show to ensure fresh data
    frame:HookScript("OnShow", UpdateTags)
    frame.RoithiTagsHooked = true
end
