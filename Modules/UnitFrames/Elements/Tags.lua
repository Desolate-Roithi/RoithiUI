local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode")
local LSM = LibStub("LibSharedMedia-3.0")

-- WoW APIs
local _G = _G
local pcall, type, tonumber, tostring, ipairs, string = pcall, type, tonumber, tostring, ipairs, string
local UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax = UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax
local UnitName, UnitClass, UnitRace, UnitLevel = UnitName, UnitClass, UnitRace, UnitLevel
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitIsConnected, UnitIsGhost, UnitIsDead = UnitIsConnected, UnitIsGhost, UnitIsDead
local UnitClassification, UnitCreatureFamily, UnitCreatureType = UnitClassification, UnitCreatureFamily, UnitCreatureType
local CreateFramePool, CreateFontStringPool = CreateFramePool, CreateFontStringPool
local strsplit = strsplit

-- 12.0.1 Secret APIs (Localized if present)
local issecretvalue = _G.issecretvalue
local C_Secrets = _G.C_Secrets
local C_UnitHealth = _G.C_UnitHealth
---@diagnostic disable-next-line: undefined-field
local C_UnitPower = _G.C_UnitPower
local CurveConstants = _G.CurveConstants
local UnitHealthPercent = _G.UnitHealthPercent
local UnitPowerPercent = _G.UnitPowerPercent


---@diagnostic disable-next-line: undefined-field
local UnitHealthDeficit = _G.UnitHealthDeficit

-- Missing Globals for Linter
---@diagnostic disable-next-line: undefined-field
local AbbreviateLargeNumbers = _G.AbbreviateLargeNumbers
---@diagnostic disable-next-line: undefined-field
local UnitHealthMissing = _G.UnitHealthMissing

---@class UF : AceAddon, AceModule
local UF = RoithiUI:GetModule("UnitFrames")

---@class TagManager
local TM = {}
UF.TagManager = TM



-- Helper: Shorten Number (12.0.1 Style K/M)
local function AbbreviateNumber(value)
    -- CRITICAL: Check for Secret values using the GLOBAL function
    -- Secrets have type() == "number" or "string" but forbid math/comparison.
    if issecretvalue and issecretvalue(value) then
        if AbbreviateLargeNumbers then
            return AbbreviateLargeNumbers(value)
        end
        return value
    end

    local n = tonumber(value)
    if not n then return value end

    -- Fallback for non-secret values
    local success, result = pcall(function()
        if n >= 1000000000 then
            return string.format("%.1fB", n / 1000000000)
        elseif n >= 1000000 then
            return string.format("%.1fM", n / 1000000)
        elseif n >= 1000 then
            return string.format("%.1fk", n / 1000)
        end
        return tostring(n)
    end)
    return success and result or value
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
        local isRestricted = C_Secrets and C_Secrets.ShouldUnitHealthMaxBeSecret(unit)
        local cur, max = UnitHealth(unit), UnitHealthMax(unit)
        local isActuallySecret = issecretvalue and (issecretvalue(cur) or issecretvalue(max))

        if isRestricted or isActuallySecret then
            if UnitHealthDeficit then
                return UnitHealthDeficit(unit)
            elseif UnitHealthMissing then
                return UnitHealthMissing(unit)
            end
            return ""
        end

        local missing = max - cur
        if missing > 0 then return missing end
        return ""
    end,
    ["health.percent"] = function(unit)
        local isRestricted = C_Secrets and C_Secrets.ShouldUnitHealthMaxBeSecret(unit)
        local cur, max = UnitHealth(unit), UnitHealthMax(unit)
        local isActuallySecret = issecretvalue and (issecretvalue(cur) or issecretvalue(max))

        if isRestricted or isActuallySecret then
            -- 12.0.1 Native Approach: Use UnitHealthPercent with Scaling Curve
            -- This returns a secret value already scaled to 0-100 for formatting.
            local curve = (CurveConstants and CurveConstants.ScaleTo100) or 0
            local success, result = pcall(function()
                local pct = UnitHealthPercent(unit, false, curve)
                -- format automatically handles secret scaling
                return string.format("%.2f%%", pct)
            end)

            if success and result then return result end

            -- Fallback to official text API
            local success2, result2 = pcall(function() return C_UnitHealth.GetHealthPercentText(unit) end)
            if success2 and result2 and result2 ~= "" then return result2 end

            return ""
        end

        if max == 0 then return "0.00%" end
        return string.format("%.2f%%", (cur / max) * 100)
    end,

    -- Power
    ["power.current"] = function(unit) return UnitPower(unit) end,
    ["power.maximum"] = function(unit) return UnitPowerMax(unit) end,
    ["power.percent"] = function(unit)
        local isRestricted = C_Secrets and C_Secrets.ShouldUnitPowerBeSecret(unit)
        local cur, max = UnitPower(unit), UnitPowerMax(unit)
        local isActuallySecret = issecretvalue and (issecretvalue(cur) or issecretvalue(max))

        if isRestricted or isActuallySecret then
            -- 12.0.1 Power Approach
            local curve = (CurveConstants and CurveConstants.ScaleTo100) or 0
            local success, result = pcall(function()
                local pType = UnitPowerType(unit)
                local pct = UnitPowerPercent(unit, pType, false, curve)
                return string.format("%.2f%%", pct)
            end)

            if success and result then return result end

            local success2, result2 = pcall(function() return C_UnitPower.GetPowerPercentText(unit) end)
            if success2 and result2 then return result2 end

            return ""
        end

        if max == 0 then return "0.00%" end
        return string.format("%.2f%%", (cur / max) * 100)
    end,

    ["power.missing"] = function(unit)
        local isRestricted = C_Secrets and C_Secrets.ShouldUnitPowerBeSecret(unit)
        local cur, max = UnitPower(unit), UnitPowerMax(unit)
        local isActuallySecret = issecretvalue and (issecretvalue(cur) or issecretvalue(max))

        if isRestricted or isActuallySecret then
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
        local spec = GetSpecialization()
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

            return aura and aura.applications or 0
        elseif config.mode == "POWER" then
            return UnitPower("player", config.type)
        end
        return ""
    end,

    ["power.class.max"] = function(unit)
        if unit ~= "player" then return "" end
        local _, class = UnitClass("player")
        local spec = GetSpecialization()
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

            if aura and aura.maxStack and aura.maxStack > 0 then
                max = aura.maxStack
                if class == "SHAMAN" then max = 5 end
            end
            return max
        elseif config.mode == "POWER" then
            local pMax = UnitPowerMax("player", config.type)
            if pMax and pMax > 0 then max = pMax end
            return max
        end
        return ""
    end,

    ["power.class.percent"] = function(unit)
        if unit ~= "player" then return "" end
        local _, class = UnitClass("player")
        local spec = GetSpecialization()
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

            cur = aura and aura.applications or 0
            if aura and aura.maxStack and aura.maxStack > 0 then
                max = aura.maxStack
                if class == "SHAMAN" then max = 5 end
            end
        elseif config.mode == "POWER" then
            cur = UnitPower("player", config.type)
            local pMax = UnitPowerMax("player", config.type)
            if pMax and pMax > 0 then max = pMax end
        end

        if max == 0 then return "0%" end
        return string.format("%.0f%%", (cur / max) * 100)
    end,

    -- Additional Power (Mana when in form)
    ["power.add.current"] = function(unit)
        local pType = UnitPowerType(unit)
        if pType == 0 then return "" end -- Primary is already Mana

        local max = UnitPowerMax(unit, 0)
        -- Secret Safety
        if issecretvalue and issecretvalue(max) then return UnitPower(unit, 0) end
        if not max or max == 0 then return "" end

        return UnitPower(unit, 0)
    end,

    ["power.add.maximum"] = function(unit)
        local pType = UnitPowerType(unit)
        if pType == 0 then return "" end

        local max = UnitPowerMax(unit, 0)
        -- Secret Safety: Secrets behave like numbers/strings but no comparison
        -- We assume if it exists it's valid to show
        if issecretvalue and issecretvalue(max) then return max end
        if not max or max == 0 then return "" end

        return max
    end,

    ["power.add.percent"] = function(unit)
        local pType = UnitPowerType(unit)
        if pType == 0 then return "" end

        local cur = UnitPower(unit, 0)
        local max = UnitPowerMax(unit, 0)

        -- Handle Secrets via Helper API
        if issecretvalue and (issecretvalue(cur) or issecretvalue(max)) then
            local curve = (CurveConstants and CurveConstants.ScaleTo100) or 0
            local success, result = pcall(function()
                -- Explicitly request percent for MANA (0)
                local pct = UnitPowerPercent(unit, 0, false, curve)
                if pct then return string.format("%.0f%%", pct) end
            end)
            if success and result then return result end
            return ""
        end

        if not max or max == 0 then return "" end
        return string.format("%.0f%%", (cur / max) * 100)
    end,

    ["power.add.missing"] = function(unit)
        local pType = UnitPowerType(unit)
        if pType == 0 then return "" end

        local cur = UnitPower(unit, 0)
        local max = UnitPowerMax(unit, 0)

        if issecretvalue and (issecretvalue(cur) or issecretvalue(max)) then return "" end
        if not max or max == 0 then return "" end

        local missing = max - cur
        if missing > 0 then return missing end
        return ""
    end,

    -- Monk Stagger
    ["power.stagger"] = function(unit)
        local stagger = UnitStagger(unit)
        if not stagger or stagger == 0 then return "" end
        if issecretvalue and issecretvalue(stagger) then return stagger end
        return stagger
    end,

    ["power.stagger.percent"] = function(unit)
        local stagger = UnitStagger(unit)
        if not stagger or stagger == 0 then return "" end

        local healthMax = UnitHealthMax(unit)
        if not healthMax or healthMax == 0 then return "" end

        if issecretvalue and (issecretvalue(stagger) or issecretvalue(healthMax)) then return "" end

        return string.format("%.0f%%", (stagger / healthMax) * 100)
    end,

    -- Absorb
    ["absorb"] = function(unit)
        local absorb = UnitGetTotalAbsorbs(unit) or 0
        if issecretvalue and issecretvalue(absorb) then return absorb end
        if absorb <= 0 then return "" end
        return absorb
    end,

    -- Status & Classification
    ["status"] = function(unit)
        if not UnitIsConnected(unit) then return "Offline" end
        if UnitIsGhost(unit) then return "Ghost" end
        if UnitIsDead(unit) then return "Dead" end
        return ""
    end,

    ["classification"] = function(unit)
        local c = UnitClassification(unit)
        if c == "worldboss" or c == "boss" then return "Boss" end
        if c == "elite" then return "Elite" end
        if c == "rareelite" then return "Rare-Elite" end
        if c == "rare" then return "Rare" end
        return ""
    end,

    ["creature"] = function(unit)
        return UnitCreatureFamily(unit) or UnitCreatureType(unit) or ""
    end,

    ["difficulty"] = function(unit)
        if not UnitExists(unit) then return "" end
        local level = UnitLevel(unit)
        if level == -1 then return "Boss" end
        return level
    end,
}

-- ----------------------------------------------------------------------------
-- 2. Parsing & Formatting
-- ----------------------------------------------------------------------------

function TM:GetSegments(formatString, unit)
    if not formatString then return {} end

    -- 1. Conditional Logic [type](format) for Power Type
    if formatString:find("%[") then
        local pType, pToken = UnitPowerType(unit or "player")
        if pToken then
            for cond, content in formatString:gmatch("%[([^%]]+)%]%(([^%)]+)%)") do
                if cond:upper() == pToken then
                    return TM:GetSegments(content, unit)
                end
            end
            local stripped = formatString:gsub("%[([^%]]+)%]%(([^%)]+)%)%s?", "")
            formatString = stripped
        end
    end

    -- 2. Conditional Logic {class:spec}(format)
    -- Supports {DH:3}(...) or {MAGE}(...)
    if formatString:find("%{") then
        local _, class = UnitClass(unit or "player")
        local spec = GetSpecialization()

        -- Class Abbreviation Map
        local classMap = {
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

        -- Iterate all {cond}(content) blocks
        for cond, content in formatString:gmatch("%{([^%}]+)%}%(([^%)]+)%)") do
            local reqClass, reqSpec = strsplit(":", cond)
            reqClass = reqClass and reqClass:upper()

            -- Resolve Abbr
            if classMap[reqClass] then reqClass = classMap[reqClass] end

            local classMatch = (reqClass == class)
            local specMatch = true

            if reqSpec then
                if tonumber(reqSpec) ~= spec then specMatch = false end
            end

            if classMatch and specMatch then
                return TM:GetSegments(content, unit)
            end
        end

        -- If conditional blocks existed but none matched context, strip them
        local stripped = formatString:gsub("%{([^%}]+)%}%(([^%)]+)%)%s?", "")
        formatString = stripped
    end

    -- Tokenization
    local result = {}
    local lastPos = 1

    for startPos, token, endPos in formatString:gmatch("()@([%w_%.%:]+)()") do
        if startPos > lastPos then
            table.insert(result, { text = formatString:sub(lastPos, startPos - 1), isTag = false })
        end

        local tagName, modifier = strsplit(":", token)

        -- Legacy support (if config wasn't updated)
        if tagName == "classpower.current" then tagName = "power.class" end
        if tagName == "classpower.maximum" then tagName = "power.class.max" end
        if tagName == "classpower.percent" then tagName = "power.class.percent" end

        local method = TM.Methods[tagName]
        if method then
            local success, val = pcall(method, unit)
            if success then
                if modifier and modifier:lower() == "short" then
                    val = AbbreviateNumber(val)
                end

                if type(val) == "table" then
                    for _, subVal in ipairs(val) do
                        table.insert(result, { text = subVal, isTag = true })
                    end
                else
                    table.insert(result, { text = val, isTag = true })
                end
            else
                print("|cffff0000[RoithiUI Tag Error]|r", tagName, val)
                table.insert(result, { text = "<Err>", isTag = true })
            end
        else
            table.insert(result, { text = "@" .. token, isTag = false })
        end
        lastPos = endPos
    end

    -- Add remaining static text
    if lastPos <= #formatString then
        table.insert(result, { text = formatString:sub(lastPos), isTag = false })
    end

    return result
end

-- ----------------------------------------------------------------------------
-- 3. Core System (Create & Update)
-- ----------------------------------------------------------------------------
function UF:CreateTags(frame)
    if not frame.Tags then frame.Tags = {} end
end

function UF:UpdateTags(frame)
    local unit = frame.unit

    -- Boss Inheritance: Boss 2-5 use Boss 1 settings
    local dbUnit = unit
    if unit and unit:match("^boss[2-5]$") then
        dbUnit = "boss1"
    end

    local db = RoithiUI.db.profile.UnitFrames[dbUnit]

    if not frame.TagsPool then
        frame.TagsPool = CreateFramePool("Frame", frame, nil, function(_, f)
            f:Hide()
            f:ClearAllPoints()
            if f.SegmentPool then
                f.SegmentPool:ReleaseAll()
            end
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
                tagFrame.SegmentPool = CreateFontStringPool(tagFrame, "OVERLAY")
            end
            tagFrame.SegmentPool:ReleaseAll()

            -- Anchor to frame or specific element
            local point = tagConfig.point or "CENTER"
            local relativeTo = frame
            if tagConfig.anchorTo == "Health" and frame.Health then
                relativeTo = frame.Health
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

    local segments = TM:GetSegments(tagFrame.formatString, tagFrame.unit or "player")
    tagFrame.SegmentPool:ReleaseAll()

    local count = #segments
    if count == 0 then return end

    local fontStrings = {}
    for i, segment in ipairs(segments) do
        local fs = tagFrame.SegmentPool:Acquire()
        local fontName = tagFrame.font or RoithiUI.db.profile.General.unitFrameFont or "Friz Quadrata TT"
        LibRoithi.mixins:SetFont(fs, fontName, tagFrame.fontSize or 12, "OUTLINE")

        -- Special: If the return is a table/mixed, it might be an error from GetSegments
        fs:SetText(segment.text)

        fs:ClearAllPoints()
        fs:Show()
        fontStrings[i] = fs
    end

    -- 12.0.1: Robust anchoring without math (no GetStringWidth needed)
    local point = tagFrame.point or "CENTER"

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

function UF:UpdateCustomTags(frame)
    if frame.TagsPool then
        for tagFrame in frame.TagsPool:EnumerateActive() do
            self:UpdateTagFrame(tagFrame)
        end
    end
end

function UF:EnableTags(frame)
    if frame.RoithiTagsHooked then return end

    local function UpdateTags() self:UpdateCustomTags(frame) end

    -- Unified Event Handler for oUF
    local function OnTagEvent(_, event, unit)
        -- Standard Unit Events
        -- Use UnitIsUnit to handle dynamic units (e.g., targettarget == player)
        if unit and frame.unit and (unit == frame.unit or UnitIsUnit(unit, frame.unit)) then
            UpdateTags()
            -- Context Switch Events
        elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            UpdateTags()
        elseif event == "UNIT_TARGET" then
            UpdateTags()
        end
    end

    -- Create a dedicated listener frame to ensure events are caught properly
    local listener = CreateFrame("Frame", nil, frame)
    listener:SetScript("OnEvent", OnTagEvent)

    -- Key events for stats
    if frame.unit then
        listener:RegisterEvent("UNIT_HEALTH")
        listener:RegisterEvent("UNIT_MAXHEALTH")
        listener:RegisterEvent("UNIT_POWER_UPDATE")
        listener:RegisterEvent("UNIT_POWER_UPDATE")
        listener:RegisterEvent("UNIT_MAXPOWER")
        listener:RegisterEvent("UNIT_DISPLAYPOWER") -- For Additional Power toggling
        listener:RegisterEvent("UNIT_NAME_UPDATE")
        listener:RegisterEvent("UNIT_LEVEL")
        listener:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
        listener:RegisterEvent("UNIT_AURA") -- Added for ClassPower Aura tags
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
