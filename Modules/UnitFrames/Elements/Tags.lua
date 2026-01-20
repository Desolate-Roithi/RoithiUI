local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LEM = LibStub("LibEditMode")

local UF = RoithiUI:GetModule("UnitFrames")

---@class TagManager
local TM = {}
UF.TagManager = TM

-- Helper: Shorten Number (12.0.1 Style K/M)
local function AbbreviateNumber(value)
    if not value or type(value) ~= "number" then return value end
    if value >= 1000000000 then
        return string.format("%.1fB", value / 1000000000)
    elseif value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return value
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
        local h, m = UnitHealth(unit), UnitHealthMax(unit)
        if LibRoithi.mixins:SafeFormat("", h) == "..." then return "..." end
        return m - h
    end,
    ["health.percent"] = function(unit)
        local h, m = UnitHealth(unit), UnitHealthMax(unit)
        if LibRoithi.mixins:SafeFormat("", h) == "..." then return "..." end
        if m == 0 then return 0 end
        return math.floor((h / m) * 100)
    end,

    -- Power
    ["power.current"] = function(unit) return UnitPower(unit) end,
    ["power.maximum"] = function(unit) return UnitPowerMax(unit) end,
    ["power.percent"] = function(unit)
        local p, m = UnitPower(unit), UnitPowerMax(unit)
        if LibRoithi.mixins:SafeFormat("", p) == "..." then return "..." end
        if m == 0 then return 0 end
        return math.floor((p / m) * 100)
    end,

    -- Absorb
    ["absorb.current"] = function(unit) return UnitGetTotalAbsorbs(unit) or 0 end,
    ["absorb.percent"] = function(unit)
        local a, m = UnitGetTotalAbsorbs(unit) or 0, UnitHealthMax(unit)
        if m == 0 then return 0 end
        return math.floor((a / m) * 100)
    end,
}

-- ----------------------------------------------------------------------------
-- 2. Parsing & Formatting
-- ----------------------------------------------------------------------------
-- Helper: Shorten Number (12.0.1 Style K/M)
local function AbbreviateNumber(value)
    if not value or type(value) ~= "number" then return value end
    if value >= 1000000000 then
        return string.format("%.1fB", value / 1000000000)
    elseif value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return value
end

-- ----------------------------------------------------------------------------
-- 2. Parsing & Formatting
-- ----------------------------------------------------------------------------
function TM:FormatTag(formatString, unit)
    if not formatString then return "" end

    -- 1. Conditional Logic [type]...
    local pType, pToken = UnitPowerType(unit)
    pToken = (pToken or ""):lower()

    if formatString:find(";") then
        local segments = { strsplit(";", formatString) }
        local matchFound = false
        local finalStr = ""

        for _, segment in ipairs(segments) do
            segment = strtrim(segment)
            local condition = segment:match("^%[([%w_]+)%](.*)")
            if condition then
                if condition:lower() == pToken then
                    finalStr = segment:match("^%[[%w_]+%](.*)")
                    matchFound = true
                    break
                end
            elseif not matchFound then
                -- If no condition header, this is the 'else' block or default
                finalStr = segment
                -- Don't break yet, keep looking for specific match?
                -- Usually default is last. Let's assume last valid non-condition or first valid condition wins.
            end
        end

        if matchFound then
            formatString = finalStr
        elseif finalStr ~= "" then
            formatString = finalStr
        end
    end

    -- 2. Tag Replacement
    local function replaceTag(fullTag, tagKey, modifier)
        local method = TM.Methods[tagKey]
        if method then
            local val = method(unit)

            -- Secret Check
            if type(val) == "userdata" and C_Secrets and C_Secrets.IsSecret and C_Secrets.IsSecret(val) then
                return "..."
            end

            -- Modifiers
            if modifier == "short" then
                val = AbbreviateNumber(tonumber(val))
            end

            return tostring(val)
        end
        return ""
    end

    -- Pattern: Look for @tagName(:modifier)?
    local result = formatString:gsub("@([%w%.]+)(:?([%w]*))", replaceTag)
    return result
end

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
    local db = RoithiUIDB.UnitFrames[unit]

    -- Clear existing tags if strict rebuild is needed, or reuse?
    -- For complexity, let's reuse/pool.
    if not frame.TagsPool then
        frame.TagsPool = CreateFramePool("Frame", frame, nil, function(pool, f)
            -- Custom OnRelease if needed
            f:Hide()
            f:ClearAllPoints()
        end)
    end

    frame.TagsPool:ReleaseAll()

    if not db or not db.tags then return end

    for i, tagConfig in ipairs(db.tags) do
        -- Acquire a Frame to hold the font string? Or just FontString?
        -- Anchoring requires a region. FontString is a region.
        -- But CreateFramePool creates Frames.
        -- Let's use an ObjectPool for FontStrings if we want lighter weight,
        -- but if we want valid Anchors for EditMode/Other things, Frame is safer?
        -- Actually, a simple FontString is enough for display.
        -- But wait, user said "Additional tags can be anchored to any frame or subframe".

        -- Let's use a Frame wrapper so we can anchor it easily and maybe attach scripts if needed later.
        local tagFrame = frame.TagsPool:Acquire()

        if not tagFrame.Text then
            tagFrame.Text = tagFrame:CreateFontString(nil, "OVERLAY")
            LibRoithi.mixins:SetFont(tagFrame.Text, "Friz Quadrata TT", 12, "OUTLINE")
            tagFrame.Text:SetAllPoints()
        end

        local text = tagFrame.Text

        -- Apply Config
        local point = tagConfig.point or "CENTER"
        local relativeTo = frame -- Default to main frame
        -- Parse anchor target (e.g. "Health", "Power")
        if tagConfig.anchorTo == "Health" and frame.Health then relativeTo = frame.Health end
        if tagConfig.anchorTo == "Power" and frame.Power then relativeTo = frame.Power end
        if tagConfig.anchorTo == "ClassPower" and frame.ClassPower then relativeTo = frame.ClassPower end
        if tagConfig.anchorTo == "AdditionalPower" and frame.AdditionalPower then relativeTo = frame.AdditionalPower end

        tagFrame:SetParent(relativeTo)
        tagFrame:SetSize(200, 20) -- Dummy size for centering
        tagFrame:ClearAllPoints()
        tagFrame:SetPoint(point, relativeTo, point, tagConfig.x or 0, tagConfig.y or 0)

        -- Store the format string on the frame for the OnUpdate/Event script
        tagFrame.formatString = tagConfig.formatString
        tagFrame.unit = unit

        tagFrame:Show()

        -- Initial Update
        text:SetText(TM:FormatTag(tagConfig.formatString, unit))
    end
end

-- ----------------------------------------------------------------------------
-- 4. Event Handling
-- ----------------------------------------------------------------------------
local function OnEvent(self, event, unit)
    if not self.visibleTags then return end
    -- We need a way to iterate active tags on the unit frame and update them.
    -- Ideally, the UnitFrame itself triggers an UpdateTags event?
    -- Or we hook the standard "UNIT_HEALTH", "UNIT_POWER_UPDATE" etc to generic update.
end

-- Hook into UF's central event handler or add specific tag updating logic?
-- Ideally, we add a function `frame:UpdateCustomTags()` and call it on relevant events.
function UF:UpdateCustomTags(frame)
    -- Iterate active objects in pool
    if frame.TagsPool then
        for tagFrame in frame.TagsPool:EnumerateActive() do
            if tagFrame.Text and tagFrame.formatString then
                tagFrame.Text:SetText(TM:FormatTag(tagFrame.formatString, frame.unit))
            end
        end
    end
end

-- Auto-register events for frames that have tags?
-- For now, let's call UpdateCustomTags from the main `UpdateIndicators` or similar hook in `Units.lua` or `Elements.lua`.
