local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode")

-- WoW APIs
local _G = _G
local pcall, type, tonumber, tostring, ipairs, string = pcall, type, tonumber, tostring, ipairs, string
local UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax = UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax
local UnitName, UnitClass, UnitRace, UnitLevel = UnitName, UnitClass, UnitRace, UnitLevel
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitIsConnected, UnitIsGhost, UnitIsDead = UnitIsConnected, UnitIsGhost, UnitIsDead
local UnitClassification, UnitCreatureFamily, UnitCreatureType = UnitClassification, UnitCreatureFamily, UnitCreatureType
local CreateFramePool, CreateFontStringPool = CreateFramePool, CreateFontStringPool

-- 12.0.1 Secret APIs (Localized if present)
local issecretvalue = _G.issecretvalue
local C_Secrets = _G.C_Secrets
local C_UnitHealth = _G.C_UnitHealth
---@diagnostic disable-next-line: undefined-field
local C_UnitPower = _G.C_UnitPower
local CurveConstants = _G.CurveConstants
local UnitHealthPercent = _G.UnitHealthPercent
local UnitPowerPercent = _G.UnitPowerPercent

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
                local pct = UnitPowerPercent(unit, false, curve)
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

    -- Absorb
    ["absorb"] = function(unit)
        local absorb = UnitGetTotalAbsorbs(unit) or 0
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

    -- Tokenization (Conditionals removed as requested)
    local result = {}
    local lastPos = 1

    -- Pattern: Capture @tag optionally followed by :modifier
    -- Using a greedy match for the tag part which may include :modifier, extracting it manually
    for startPos, token, endPos in formatString:gmatch("()@([%w_%.%:]+)()") do
        -- Add preceding static text
        if startPos > lastPos then
            table.insert(result, { text = formatString:sub(lastPos, startPos - 1), isTag = false })
        end

        -- Split token into tagName and modifier
        local tagName, modifier = strsplit(":", token)

        local method = TM.Methods[tagName]
        if method then
            local success, val = pcall(method, unit)
            if success then
                -- Apply modifiers
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
            -- If not a valid tag method, treat as literal text (or ignore?)
            -- Usually we might want to print the raw token if invalid tag,
            -- but for now let's just ignore or insert empty?
            -- Let's insert the raw text for debugging or fallback
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
-- ----------------------------------------------------------------------------
-- 3. Core System (Create & Update)
-- ----------------------------------------------------------------------------
function UF:CreateTags(frame)
    if not frame.Tags then frame.Tags = {} end
    -- We need a container for custom tags if they are anchored to the frame freely
    -- Actually, each tag is its own FontString.
    -- We store them in frame.Tags list.
end

function UF:UpdateTags(frame)
    local unit = frame.unit
    local db = RoithiUI.db.profile.UnitFrames[unit]

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

    for _, tagConfig in ipairs(db.tags) do
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
            tagFrame:SetSize(200, 20)
            tagFrame:ClearAllPoints()
            tagFrame:SetPoint(point, relativeTo, point, tagConfig.x or 0, tagConfig.y or 0)

            tagFrame.formatString = tagConfig.formatString
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
        LibRoithi.mixins:SetFont(fs, "Friz Quadrata TT", tagFrame.fontSize or 12, "OUTLINE")

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
        if unit == frame.unit then
            UpdateTags()
            -- Context Switch Events
        elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            UpdateTags()
        elseif event == "UNIT_TARGET" then
            UpdateTags()
        end
    end

    -- Key events for stats
    if frame.unit then
        frame:RegisterEvent("UNIT_HEALTH", OnTagEvent)
        frame:RegisterEvent("UNIT_MAXHEALTH", OnTagEvent)
        frame:RegisterEvent("UNIT_POWER_UPDATE", OnTagEvent)
        frame:RegisterEvent("UNIT_MAXPOWER", OnTagEvent)
        frame:RegisterEvent("UNIT_NAME_UPDATE", OnTagEvent)
        frame:RegisterEvent("UNIT_LEVEL", OnTagEvent)
        frame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", OnTagEvent)
    end

    -- Context events for target switching (Must be declared unitless)
    if frame.unit == "target" then
        frame:RegisterEvent("PLAYER_TARGET_CHANGED", OnTagEvent, true)
    elseif frame.unit == "focus" then
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED", OnTagEvent, true)
    elseif frame.unit == "targettarget" or frame.unit == "focustarget" or frame.unit == "pettarget" then
        frame:RegisterEvent("UNIT_TARGET", OnTagEvent)
    end

    -- Also update on Show to ensure fresh data
    frame:HookScript("OnShow", UpdateTags)
    frame.RoithiTagsHooked = true
end
