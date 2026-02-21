local _, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

---@class UF : AceModule, AceAddon
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
local AL = ns.AttachmentLogic
local issecretvalue = _G.issecretvalue or function(...)
    local _ = { ... }
    return false
end

-- 12.0.1 Filter Constants
local FILTERS = {
    CC = "CROWD_CONTROL",
    DEFENSIVE = "BIG_DEFENSIVE",
    DISPELLABLE = "RAID_PLAYER_DISPELLABLE",
    RAID_COMBAT = "RAID_IN_COMBAT",
    IMPORTANT = "IMPORTANT",
    EXTERNAL_DEFENSIVE = "EXTERNAL_DEFENSIVE",
    CANCELABLE = "CANCELABLE",
}

local function GetSmartFilterQueries(type, db)
    if not db then return { type } end

    local queries = {}

    if type == "HARMFUL" then
        if db.showAllDebuffs then return { "HARMFUL" } end
        if db.playerDebuffs ~= false then table.insert(queries, "HARMFUL|PLAYER") end
        if db.importantDebuffs ~= false then table.insert(queries, "HARMFUL|" .. FILTERS.IMPORTANT) end
        if db.cc ~= false then table.insert(queries, "HARMFUL|" .. FILTERS.CC) end
        if db.dispellable ~= false then table.insert(queries, "HARMFUL|" .. FILTERS.DISPELLABLE) end
        if db.majorDefensivesDebuffs ~= false then table.insert(queries, "HARMFUL|" .. FILTERS.DEFENSIVE) end
    elseif type == "HELPFUL" then
        if db.showAllBuffs then return { "HELPFUL" } end
        if db.playerBuffs ~= false then table.insert(queries, "HELPFUL|PLAYER") end
        if db.raidInCombat ~= false then table.insert(queries, "HELPFUL|" .. FILTERS.RAID_COMBAT .. "|PLAYER") end
        if db.importantBuffs ~= false then table.insert(queries, "HELPFUL|" .. FILTERS.IMPORTANT) end
        if db.majorDefensivesBuffs ~= false then table.insert(queries, "HELPFUL|" .. FILTERS.DEFENSIVE) end
        if db.externalDefensives ~= false then table.insert(queries, "HELPFUL|" .. FILTERS.EXTERNAL_DEFENSIVE) end
    end

    if #queries == 0 then return {} end
    return queries
end

-- Helper to fetch DB for an element (Base or Custom)
local function GetElementDB(frame, key)
    if key:match("^RoithiAuras") then
        -- Standard Unit Frame DB
        if not frame or not frame.unit then return {} end
        if string.match(frame.unit, "^boss[2-5]$") and RoithiUI.db.profile.UnitFrames["boss1"] then
            -- Logic to inherit from Boss1
            local db = RoithiUI.db.profile.UnitFrames[frame.unit] or {}
            local driverDB = RoithiUI.db.profile.UnitFrames["boss1"]
            local keys = {
                "aurasEnabled", "auraSize", "auraSpacing", "maxAuras", "Whitelist",
                "Blacklist", "ShowOnlyPlayer", "auraAnchor", "auraX", "auraY",
                "auraGrowDirection", "showBuffs", "showDebuffs", "auraDetached",
                "auraScreenPoint", "auraScreenX", "auraScreenY", "smartFilterShowAll",
                "smartFilterCC", "smartFilterDefensives", "smartFilterDispellable",
                "smartFilterRaidBuffs", "smartFilterImportant", "smartFilterExternalDefensives"
            }
            return setmetatable({}, {
                __index = function(_, k)
                    for _, inheritedKey in ipairs(keys) do
                        if k == inheritedKey then return driverDB[k] end
                    end
                    return db[k]
                end
            })
        end
        return RoithiUI.db.profile.UnitFrames[frame.unit] or {}
    else
        -- Custom Aura DB
        local id = key:match("^CustomAura_Buffs_(.+)")
        if not id then id = key:match("^CustomAura_Debuffs_(.+)") end
        if not id then id = key:match("^CustomAura_(.+)") end
        return RoithiUI.db.profile.CustomAuraFrames and RoithiUI.db.profile.CustomAuraFrames[id]
    end
end

-- Factory: Create or Get Aura Element
local function GetOrCreateAuraElement(frame, key)
    -- 'frame' can be a UnitFrame or a standalone container
    if frame[key] then return frame[key] end

    local parent = frame
    if frame == RoithiUI then parent = UIParent end   -- Global standalone

    local element = CreateFrame("Frame", key, parent) -- Named frame for AL/LEM
    -- Initial dummy size, updated by layout
    element:SetSize(20, 20)
    frame[key] = element
    element.owner = frame -- Reference back for DB lookups

    -- Drag Support (Satellites/Detached) for ALL aura frames
    element:RegisterForDrag("LeftButton")
    element:SetScript("OnDragStart", function(self)
        if self:IsMovable() then self:StartMoving() end
    end)
    element:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save Screen Position if Movable (Detached)
        if self:IsMovable() then
            local p, _, _, x, y = self:GetPoint()
            local db = GetElementDB(self.owner, key)
            if db then
                if key == "RoithiAuras" then
                    db.auraScreenPoint = p
                    db.auraScreenX = x
                    db.auraScreenY = y
                elseif key == "RoithiAuras_Debuffs" then
                    db.debuffScreenPoint = p
                    db.debuffScreenX = x
                    db.debuffScreenY = y
                else
                    db.screenPoint = p
                    db.screenX = x
                    db.screenY = y
                end
            end
            -- Re-calc layout
            local alType = (key == "RoithiAuras") and "Auras" or key
            local unit = self.unit or (self.owner and self.owner.unit)
            if unit then
                AL:ApplyLayout(unit, alType)
            end
        end
    end)

    element.icons = {}

    -- Icon Factory
    local function CreateIcon(i)
        local icon = CreateFrame("Frame", nil, element)
        icon:SetSize(20, 20)
        LibRoithi.mixins:CreateBackdrop(icon)

        icon.icon = icon:CreateTexture(nil, "ARTWORK")
        icon.icon:SetAllPoints()
        icon.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

        icon.count = icon:CreateFontString(nil, "OVERLAY")
        local fontName = RoithiUI.db.profile.General.unitFrameFont or "Friz Quadrata TT"
        LibRoithi.mixins:SetFont(icon.count, fontName, 10, "OUTLINE")
        icon.count:SetPoint("BOTTOMRIGHT", 2, -2)

        icon.overlay = icon:CreateTexture(nil, "OVERLAY")
        icon.overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        icon.overlay:SetAllPoints()
        icon.overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        icon.overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        icon.overlay:Hide()

        local cd = CreateFrame("Cooldown", "$parentCooldown", icon, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetReverse(true)
        icon.cd = cd

        -- Pandemic Glow Frame
        local glowFrame = CreateFrame("Frame", nil, icon)
        glowFrame:SetAllPoints()
        glowFrame:Hide()
        local glow = glowFrame:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\CheckButtonGlow")
        glow:SetAllPoints()
        glow:SetBlendMode("ADD")
        icon.GlowFrame = glowFrame

        -- Tooltip Scripts
        icon:SetScript("OnEnter", function(self)
            if not self.auraInstanceID then return end
            -- Resolve unit dynamically in case element or frame changes targets
            local currentUnit = (element and element.unit) or (element.owner and element.owner.unit) or
                (frame and frame.unit)
            if not currentUnit then return end

            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
            if self.isDebuff then
                GameTooltip:SetUnitDebuffByAuraInstanceID(currentUnit, self.auraInstanceID, self.filter or "HARMFUL")
            else
                GameTooltip:SetUnitBuffByAuraInstanceID(currentUnit, self.auraInstanceID, self.filter or "HELPFUL")
            end
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

        element.icons[i] = icon
        return icon
    end

    local function logAuraErr(msg, ...)
        local args = { ... }
        if RoithiUI.db.profile.General.debugMode then
            RoithiUI:Log(string.format(msg, unpack(args)))
        end
    end

    -- Update Function for this specific element
    element.Update = function()
        -- Use element's unit if standalone, otherwise frame's unit
        local unit = element.unit or (frame and frame.unit)
        if not unit then return end

        local db = GetElementDB(element.owner, key)
        if not db then
            element:Hide(); return
        end

        -- Enabled Check
        -- Base Auras use 'aurasEnabled', Custom use 'enabled'
        local enabled
        if key:match("^RoithiAuras") then
            enabled = db.aurasEnabled ~= false
        else
            enabled = db.enabled == true
        end

        logAuraErr("Auras Debug: %s Update on %s | Enabled: %s", key, unit, tostring(enabled))

        if not enabled then
            element:Hide()
            return
        end
        element:Show()

        -- Layout (Positioning via AL)
        local alType = (key == "RoithiAuras") and "Auras" or key
        AL:ApplyLayout(unit, alType)

        -- Mouse Interact (Drag)
        if frame.isInEditMode then
            element:EnableMouse(true)
        else
            element:EnableMouse(false)
        end

        local isSplitDebuff = key == "RoithiAuras_Debuffs"
        local isSplitBuff = key == "RoithiAuras" and db.separateAuras

        -- Props
        local size = db.auraSize or 20
        local growDir = db.auraGrowDirection or "RIGHT"
        local spacing = db.auraSpacing or 4
        local maxIcons = db.maxAuras or 8

        if not db.auraGrowDirection and db.growDirection then growDir = db.growDirection end

        -- Overrides if split
        if isSplitDebuff then
            size = db.debuffSize or db.auraSize or 20
            growDir = db.debuffGrowDirection or db.auraGrowDirection or "RIGHT"
            spacing = db.debuffSpacing or db.auraSpacing or 4
            maxIcons = db.debuffMaxAuras or db.maxAuras or 8
        elseif isSplitBuff then
            size = db.buffSize or db.auraSize or 20
            growDir = db.buffGrowDirection or db.auraGrowDirection or "RIGHT"
            spacing = db.buffSpacing or db.auraSpacing or 4
            maxIcons = db.buffMaxAuras or db.maxAuras or 8
        end

        if growDir == "CENTER_HORIZONTAL" then growDir = "RIGHT" end
        if growDir == "CENTER_VERTICAL" then growDir = "DOWN" end

        element:SetHeight(size)

        local anchor1, relPoint, xSpace, ySpace = "LEFT", "RIGHT", spacing, 0
        if growDir == "LEFT" then
            anchor1, relPoint, xSpace, ySpace = "RIGHT", "LEFT", -spacing, 0
        elseif growDir == "UP" then
            anchor1, relPoint, xSpace, ySpace = "BOTTOM", "TOP", 0, spacing
        elseif growDir == "DOWN" then
            anchor1, relPoint, xSpace, ySpace = "TOP", "BOTTOM", 0, -spacing
        end

        local icons = element.icons
        local iconIndex = 1
        local seenAuras = {} -- Table to track unique auras by auraInstanceID to prevent duplicates

        local showDebuffs = db.showDebuffs ~= false
        local showBuffs = db.showBuffs ~= false

        if isSplitDebuff then
            showBuffs = false
        elseif isSplitBuff then
            showDebuffs = false
        end

        -- White/Blacklist logic (Base only? Or Custom too?)
        -- Custom frames likely want strict filtering, maybe whitelist only?
        -- For now, reusing Base logic structure.
        local isWhiteListActive = (db.Whitelist and next(db.Whitelist))

        RoithiUI.TimelessAuraCache = RoithiUI.TimelessAuraCache or {}
        local inCombat = InCombatLockdown and InCombatLockdown()

        -- 1. Debuffs
        local debuffStartIndex = iconIndex
        if showDebuffs then
            local debuffQueries = GetSmartFilterQueries("HARMFUL", db)
            local sortRule = Enum.UnitAuraSortRule.Expiration or 3
            local instanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HARMFUL", 40, sortRule)

            if instanceIDs then
                for _, auraInstanceID in ipairs(instanceIDs) do
                    local limitReached = db.separateAuras and ((iconIndex - debuffStartIndex) >= maxIcons) or
                        (iconIndex > maxIcons)
                    if limitReached then break end

                    local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
                    if aura and not seenAuras[auraInstanceID] then
                        local passesFilter = false
                        for _, q in ipairs(debuffQueries) do
                            if not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, q) then
                                passesFilter = true
                                break
                            end
                        end

                        if passesFilter then
                            local isSecretId = issecretvalue(aura.spellId)
                            local _ = issecretvalue(aura.sourceUnit) -- Removed unused isSecretSrc
                            local skip = false

                            if not skip and db.hideTimeless then
                                local durationObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
                                if durationObj then
                                    local isZero = durationObj:IsZero()
                                    local isZeroSecret = issecretvalue and issecretvalue(isZero)

                                    if not inCombat and not isZeroSecret then
                                        if isZero then
                                            local cacheKey = not issecretvalue(aura.spellId) and aura.spellId or
                                                (not issecretvalue(aura.icon) and aura.icon)
                                            if cacheKey then
                                                RoithiUI.TimelessAuraCache[cacheKey] = true
                                            end
                                            skip = true
                                        end
                                    else
                                        local cacheKey = not issecretvalue(aura.spellId) and aura.spellId or
                                            (not issecretvalue(aura.icon) and aura.icon)
                                        if cacheKey and RoithiUI.TimelessAuraCache[cacheKey] then
                                            skip = true
                                        end
                                    end
                                end
                            end

                            if not skip and db.Blacklist then
                                if not isSecretId and db.Blacklist[aura.spellId] then skip = true end
                            end
                            if not skip and isWhiteListActive then
                                if not isSecretId and not db.Whitelist[aura.spellId] then skip = true end
                            end

                            if not skip then
                                seenAuras[aura.auraInstanceID] = true
                                local icon = icons[iconIndex] or CreateIcon(iconIndex)
                                icon:SetSize(size, size)
                                icon:ClearAllPoints()
                                -- Dynamic Grow
                                if iconIndex == 1 then
                                    icon:SetPoint(anchor1, element, anchor1, 0, 0)
                                else
                                    icon:SetPoint(anchor1, icons[iconIndex - 1], relPoint, xSpace, ySpace)
                                end

                                icon.icon:SetTexture(aura.icon)
                                local count = aura.applications or 0
                                local text = ""
                                if not issecretvalue(count) then
                                    text = (count > 1) and tostring(count) or ""
                                end
                                icon.count:SetText(text)

                                icon.auraInstanceID = auraInstanceID
                                icon.isDebuff = true
                                icon.filter = "HARMFUL"

                                -- Color
                                if _G.DebuffTypeColor and aura.dispelName then
                                    local color = _G.DebuffTypeColor[aura.dispelName] or _G.DebuffTypeColor["none"]
                                    if icon.SetBackdropBorderColor then
                                        icon:SetBackdropBorderColor(color.r, color.g, color
                                            .b)
                                    end
                                    icon.overlay:SetVertexColor(color.r, color.g, color.b)
                                end
                                icon.overlay:Show()

                                local durationObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
                                if durationObj then
                                    local isZero = durationObj:IsZero()
                                    local shouldShow = false
                                    if issecretvalue and issecretvalue(isZero) then
                                        shouldShow = true
                                    elseif not isZero then
                                        shouldShow = true
                                    end

                                    if shouldShow then
                                        if icon.cd.SetCooldownFromDurationObject then
                                            icon.cd:SetCooldownFromDurationObject(durationObj)
                                        end
                                        icon.cd:Show()
                                    else
                                        icon.cd:Hide()
                                    end
                                else
                                    icon.cd:Hide()
                                end
                                if C_UnitAuras.IsAuraInRefreshWindow then
                                    local inWindow = C_UnitAuras.IsAuraInRefreshWindow(unit, aura.auraInstanceID)
                                    if issecretvalue(inWindow) and icon.GlowFrame.SetShownFromSecret then
                                        icon.GlowFrame:SetShownFromSecret(inWindow)
                                    elseif inWindow and inWindow ~= false then
                                        icon.GlowFrame:Show()
                                    else
                                        icon.GlowFrame:Hide()
                                    end
                                else
                                    icon.GlowFrame:Hide()
                                end

                                logAuraErr("Auras Debug: Created Debuff Icon %d for spellId: %s",
                                    iconIndex,
                                    tostring(aura.spellId))

                                icon:Show()
                                iconIndex = iconIndex + 1
                            end
                        end
                    end
                end
            end
        end

        -- 2. Buffs
        local isFirstBuffRendered = false
        local buffStartIndex = iconIndex
        if showBuffs then
            local buffQueries = GetSmartFilterQueries("HELPFUL", db)
            local sortRule = Enum.UnitAuraSortRule.Expiration or 3
            local instanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HELPFUL", 40, sortRule)

            if instanceIDs then
                for _, auraInstanceID in ipairs(instanceIDs) do
                    local limitReached = db.separateAuras and ((iconIndex - buffStartIndex) >= maxIcons) or
                        (iconIndex > maxIcons)
                    if limitReached then break end

                    local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
                    if aura and not seenAuras[auraInstanceID] then
                        local passesFilter = false
                        for _, q in ipairs(buffQueries) do
                            if not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, q) then
                                passesFilter = true
                                break
                            end
                        end

                        if passesFilter then
                            local isSecretId = issecretvalue(aura.spellId)
                            local _ = issecretvalue(aura.sourceUnit)
                            local skip = false

                            if not skip and db.hideTimeless then
                                local durationObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
                                if durationObj then
                                    local isZero = durationObj:IsZero()
                                    local isZeroSecret = issecretvalue and issecretvalue(isZero)

                                    if not inCombat and not isZeroSecret then
                                        if isZero then
                                            local cacheKey = not issecretvalue(aura.spellId) and aura.spellId or
                                                (not issecretvalue(aura.icon) and aura.icon)
                                            if cacheKey then
                                                RoithiUI.TimelessAuraCache[cacheKey] = true
                                            end
                                            skip = true
                                        end
                                    else
                                        local cacheKey = not issecretvalue(aura.spellId) and aura.spellId or
                                            (not issecretvalue(aura.icon) and aura.icon)
                                        if cacheKey and RoithiUI.TimelessAuraCache[cacheKey] then
                                            skip = true
                                        end
                                    end
                                end
                            end

                            if not skip and db.Blacklist then
                                if not isSecretId and db.Blacklist[aura.spellId] then skip = true end
                            end
                            if not skip and isWhiteListActive then
                                if not isSecretId and not db.Whitelist[aura.spellId] then skip = true end
                            end

                            if not skip then
                                seenAuras[aura.auraInstanceID] = true
                                local icon = icons[iconIndex] or CreateIcon(iconIndex)
                                icon:SetSize(size, size)
                                icon:ClearAllPoints()
                                if iconIndex == 1 then
                                    icon:SetPoint(anchor1, element, anchor1, 0, 0)
                                    isFirstBuffRendered = true
                                elseif db.separateAuras and not isFirstBuffRendered then
                                    isFirstBuffRendered = true
                                    if growDir == "LEFT" or growDir == "RIGHT" then
                                        icon:SetPoint(anchor1, element, anchor1, 0, -(size + 4))
                                    else
                                        icon:SetPoint(anchor1, element, anchor1, -(size + 4), 0)
                                    end
                                else
                                    icon:SetPoint(anchor1, icons[iconIndex - 1], relPoint, xSpace, ySpace)
                                    isFirstBuffRendered = true
                                end

                                icon.icon:SetTexture(aura.icon)
                                local count = aura.applications or 0
                                local text = ""
                                if not issecretvalue(count) then
                                    text = (count > 1) and tostring(count) or ""
                                end
                                icon.count:SetText(text)

                                icon.auraInstanceID = auraInstanceID
                                icon.isDebuff = false
                                icon.filter = "HELPFUL"

                                if icon.SetBackdropBorderColor then icon:SetBackdropBorderColor(0, 0, 0) end
                                icon.overlay:Hide()

                                local durationObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
                                if durationObj then
                                    local isZero = durationObj:IsZero()
                                    local shouldShow = false
                                    if issecretvalue and issecretvalue(isZero) then
                                        shouldShow = true
                                    elseif not isZero then
                                        shouldShow = true
                                    end

                                    if shouldShow then
                                        if icon.cd.SetCooldownFromDurationObject then
                                            icon.cd:SetCooldownFromDurationObject(durationObj)
                                        end
                                        icon.cd:Show()
                                    else
                                        icon.cd:Hide()
                                    end
                                else
                                    icon.cd:Hide()
                                end

                                if C_UnitAuras.IsAuraInRefreshWindow then
                                    local inWindow = C_UnitAuras.IsAuraInRefreshWindow(unit, aura.auraInstanceID)
                                    if issecretvalue(inWindow) and icon.GlowFrame.SetShownFromSecret then
                                        icon.GlowFrame:SetShownFromSecret(inWindow)
                                    elseif inWindow and inWindow ~= false then
                                        icon.GlowFrame:Show()
                                    else
                                        icon.GlowFrame:Hide()
                                    end
                                else
                                    icon.GlowFrame:Hide()
                                end

                                if RoithiUI.db.profile.General.debugMode then
                                    RoithiUI:Log(string.format("Auras Debug: Created Buff Icon %d for spellId: %s",
                                        iconIndex,
                                        tostring(aura.spellId)))
                                end

                                icon:Show()
                                iconIndex = iconIndex + 1
                            end
                        end
                    end
                end
            end
        end

        -- Edit Mode Mock
        if frame.forceShowEditMode or frame.forceShowTest then
            local _ = nil
        end

        -- Hide unused
        for i = iconIndex, #icons do icons[i]:Hide() end

        -- Dynamic Element Sizing for Edit Mode Dragging
        local totalIcons = iconIndex - 1
        local renderIcons = totalIcons

        local rows = 1
        if frame.isInEditMode then
            renderIcons = maxIcons
            if not isSplitDebuff and not isSplitBuff and db.separateAuras and
                db.showBuffs ~= false and db.showDebuffs ~= false then
                rows = 2
            end
        end

        if renderIcons > 0 then
            local primarySize = renderIcons * size +
                (renderIcons - 1) * math.abs((growDir == "LEFT" or growDir == "RIGHT") and xSpace or ySpace)
            local secondarySize = rows * size + (rows - 1) * 4 -- since offset is (size + 4) -> 2*size + 4

            if growDir == "LEFT" or growDir == "RIGHT" then
                element:SetSize(primarySize, secondarySize)
            else
                element:SetSize(secondarySize, primarySize)
            end
        else
            element:SetSize(1, 1)
        end

        if frame.isInEditMode then
            if not element.editModeTexture then
                element.editModeTexture = element:CreateTexture(nil, "OVERLAY")
                element.editModeTexture:SetAllPoints()
                element.editModeTexture:SetColorTexture(0, 0.8, 1, 0.3)

                -- Create Top, Bottom, Left, Right borders
                element.editModeTop = element:CreateTexture(nil, "OVERLAY")
                element.editModeTop:SetPoint("TOPLEFT", element, "TOPLEFT", 0, 0)
                element.editModeTop:SetPoint("TOPRIGHT", element, "TOPRIGHT", 0, 0)
                element.editModeTop:SetHeight(1)
                element.editModeTop:SetColorTexture(0, 0.8, 1, 1)

                element.editModeBottom = element:CreateTexture(nil, "OVERLAY")
                element.editModeBottom:SetPoint("BOTTOMLEFT", element, "BOTTOMLEFT", 0, 0)
                element.editModeBottom:SetPoint("BOTTOMRIGHT", element, "BOTTOMRIGHT", 0, 0)
                element.editModeBottom:SetHeight(1)
                element.editModeBottom:SetColorTexture(0, 0.8, 1, 1)

                element.editModeLeft = element:CreateTexture(nil, "OVERLAY")
                element.editModeLeft:SetPoint("TOPLEFT", element, "TOPLEFT", 0, 0)
                element.editModeLeft:SetPoint("BOTTOMLEFT", element, "BOTTOMLEFT", 0, 0)
                element.editModeLeft:SetWidth(1)
                element.editModeLeft:SetColorTexture(0, 0.8, 1, 1)

                element.editModeRight = element:CreateTexture(nil, "OVERLAY")
                element.editModeRight:SetPoint("TOPRIGHT", element, "TOPRIGHT", 0, 0)
                element.editModeRight:SetPoint("BOTTOMRIGHT", element, "BOTTOMRIGHT", 0, 0)
                element.editModeRight:SetWidth(1)
                element.editModeRight:SetColorTexture(0, 0.8, 1, 1)

                element.editModeText = element:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                element.editModeText:SetPoint("CENTER", element, "CENTER", 0, 0)
            end

            local isCustom = key:match("^CustomAura")
            local textStr = ""
            local idLabel = key:match("^CustomAura_(.+)")
            local _ = idLabel
            local _ = isCustom

            if isSplitBuff then
                textStr = textStr .. "\n(Buffs)"
            elseif isSplitDebuff then
                textStr = textStr .. "\n(Debuffs)"
            end
            if element.editModeText then element.editModeText:SetText(textStr) end
            element.editModeTexture:Show()
            element.editModeTop:Show()
            element.editModeBottom:Show()
            element.editModeLeft:Show()
            element.editModeRight:Show()
            if element.editModeText then element.editModeText:Show() end
        else
            if element.editModeTexture then
                element.editModeTexture:Hide()
                element.editModeTop:Hide()
                element.editModeBottom:Hide()
                element.editModeLeft:Hide()
                element.editModeRight:Hide()
                if element.editModeText then element.editModeText:Hide() end
            end
        end
    end

    return element
end

function UF:CreateAuras(frame)
    -- Define hooks first to ensure they are available for event registration
    frame.UpdateAuraLayout = function()
        -- Update Base
        if frame.RoithiAuras then frame.RoithiAuras.Update() end
        -- Update Custom
        if frame.CustomAuras then
            for _, el in pairs(frame.CustomAuras) do el.Update() end
        end
        UF:UpdateAuras(frame)
    end

    frame.UpdateAuras = function()
        UF:UpdateAuras(frame)
    end

    -- 1. Create Base Auras
    GetOrCreateAuraElement(frame, "RoithiAuras")

    -- 2. Register Events (Shared)
    frame:HookScript("OnEvent", function(s, event, arg1)
        if event == "UNIT_AURA" then
            if arg1 == s.unit then frame.UpdateAuras() end
        elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            frame.UpdateAuras()
        end
    end)
    frame:RegisterEvent("UNIT_AURA", frame.UpdateAuras)
    frame:RegisterEvent("PLAYER_TARGET_CHANGED", frame.UpdateAuras, true)
    frame:RegisterEvent("PLAYER_FOCUS_CHANGED", frame.UpdateAuras, true)

    frame:HookScript("OnShow", frame.UpdateAuras)
end

function UF:UpdateAuras(frame)
    if type(frame) == "string" then frame = self.units[frame] end
    if not frame or not frame.unit then
        return
    end

    -- 1. Update Base
    local baseDB = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[frame.unit]

    local el = GetOrCreateAuraElement(frame, "RoithiAuras")
    frame.RoithiAuras = el
    el.Update()

    if baseDB and baseDB.separateAuras then
        local elDebuffs = GetOrCreateAuraElement(frame, "RoithiAuras_Debuffs")
        frame.RoithiAuras_Debuffs = elDebuffs
        elDebuffs.Update()
    else
        if frame.RoithiAuras_Debuffs then frame.RoithiAuras_Debuffs:Hide() end
    end

    -- 2. Sync Custom Auras (DEPRECATED - Moved to standalones)
    -- We keep a minimal loop here to hide any old children if they exist
    if frame.CustomAuras then
        for _, element in pairs(frame.CustomAuras) do element:Hide() end
    end
end

-- STANDALONE CUSTOM AURAS
RoithiUI.CustomAuras = RoithiUI.CustomAuras or {}

function UF:UpdateAllCustomAuras()
    local customDB = RoithiUI.db.profile.CustomAuraFrames
    if not customDB then return end

    local LEM = LibStub("LibEditMode-Roithi", true)

    for id, conf in pairs(customDB) do
        local key = "CustomAura_" .. id
        local el = RoithiUI.CustomAuras[id]

        if not el then
            el = GetOrCreateAuraElement(RoithiUI, key)
            RoithiUI.CustomAuras[id] = el

            -- LIBEDITMODE REGISTRATION
            if LEM then
                local function OnPosChanged(_f, _, p, x, y)
                    local db = RoithiUI.db.profile.CustomAuraFrames[id]
                    if db then
                        db.screenPoint, db.screenX, db.screenY = p, x, y
                    end
                end

                local defaults = {
                    p = "CENTER",
                    x = 0,
                    y = -50
                }

                LEM:AddFrame(el, OnPosChanged, defaults, "Custom Aura: " .. id)

                -- ADD LEM SETTINGS
                local auraSettings = {
                    {
                        kind = LEM.SettingType.Checkbox,
                        name = "Enabled",
                        get = function() return RoithiUI.db.profile.CustomAuraFrames[id].enabled ~= false end,
                        set = function(v)
                            RoithiUI.db.profile.CustomAuraFrames[id].enabled = v
                            el.Update()
                        end
                    },
                    {
                        kind = LEM.SettingType.Slider,
                        name = "Aura Size",
                        minValue = 10,
                        maxValue = 100,
                        valueStep = 1,
                        get = function() return RoithiUI.db.profile.CustomAuraFrames[id].auraSize or 30 end,
                        set = function(v)
                            RoithiUI.db.profile.CustomAuraFrames[id].auraSize = v
                            el.Update()
                        end
                    },
                    {
                        kind = LEM.SettingType.Slider,
                        name = "Max Auras",
                        minValue = 1,
                        maxValue = 40,
                        valueStep = 1,
                        get = function() return RoithiUI.db.profile.CustomAuraFrames[id].maxAuras or 4 end,
                        set = function(v)
                            RoithiUI.db.profile.CustomAuraFrames[id].maxAuras = v
                            el.Update()
                        end
                    },
                    {
                        kind = LEM.SettingType.Slider,
                        name = "Spacing",
                        minValue = 0,
                        maxValue = 40,
                        valueStep = 1,
                        get = function() return RoithiUI.db.profile.CustomAuraFrames[id].auraSpacing or 4 end,
                        set = function(v)
                            RoithiUI.db.profile.CustomAuraFrames[id].auraSpacing = v
                            el.Update()
                        end
                    },
                    {
                        kind = LEM.SettingType.Slider,
                        name = "X Offset (from Screen Center)",
                        minValue = -2000,
                        maxValue = 2000,
                        valueStep = 1,
                        get = function() return RoithiUI.db.profile.CustomAuraFrames[id].screenX or 0 end,
                        set = function(v)
                            RoithiUI.db.profile.CustomAuraFrames[id].screenX = v
                            el.Update()
                        end
                    },
                    {
                        kind = LEM.SettingType.Slider,
                        name = "Y Offset (from Screen Center)",
                        minValue = -2000,
                        maxValue = 2000,
                        valueStep = 1,
                        get = function() return RoithiUI.db.profile.CustomAuraFrames[id].screenY or -50 end,
                        set = function(v)
                            RoithiUI.db.profile.CustomAuraFrames[id].screenY = v
                            el.Update()
                        end
                    }
                }
                LEM:AddFrameSettings(el, auraSettings)
                LEM:AddFrameSettingsButtons(el, {
                    {
                        text = "Open Full Settings",
                        click = function()
                            local ACD = LibStub("AceConfigDialog-3.0", true)
                            if ACD then
                                ACD:Open("RoithiUI")
                                ACD:SelectGroup("RoithiUI", "auras", "custom", id)
                            end
                        end
                    }
                })
            end

            -- EVENT REGISTRATION
            el:SetScript("OnEvent", function(s, event, unit)
                if event == "UNIT_AURA" and unit == s.unit then
                    s.Update()
                elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
                    s.Update()
                end
            end)
            el:RegisterEvent("PLAYER_TARGET_CHANGED")
            el:RegisterEvent("PLAYER_FOCUS_CHANGED")
        end

        -- Update Internal Unit
        el.unit = conf.unit or "player"
        el:UnregisterEvent("UNIT_AURA")
        el:RegisterUnitEvent("UNIT_AURA", el.unit)

        el.Update()
    end

    -- Cleanup deleted ones
    for id, el in pairs(RoithiUI.CustomAuras) do
        if not customDB[id] then
            el:Hide()
            -- We don't necessarily destroy frames in Lua, but we hide them.
        end
    end
end

-- Initialize on Load
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        UF:UpdateAllCustomAuras()
    end
end)
