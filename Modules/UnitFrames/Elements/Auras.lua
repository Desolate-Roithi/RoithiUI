local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

---@class UF : AceModule, AceAddon
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]

function UF:CreateAuras(frame)
    local element = CreateFrame("Frame", nil, frame)
    element:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
    element:SetSize(frame:GetWidth(), 20)
    frame.RoithiAuras = element

    element.icons = {}

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

        -- Pandemic Glow Frame (Secret Safe)
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
            if not self.index or not self.filter then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
            -- Use the unit from the frame at the time of tooltip display
            GameTooltip:SetUnitAura(frame.unit, self.index, self.filter)
            GameTooltip:Show()
        end)

        icon:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        element.icons[i] = icon
        return icon
    end

    frame.UpdateAuras = function()
        local unit = frame.unit
        if not unit then return end

        -- Get DB
        -- Get DB
        local db
        if RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit] then
            db = RoithiUI.db.profile.UnitFrames[unit]
        else
            db = {}
        end

        -- Special Handling for Boss Frames (Inheritance)
        if string.match(unit, "^boss[2-5]$") then
            local driverDB = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames["boss1"]
            if driverDB then
                local specificDB = db
                db = setmetatable({}, {
                    __index = function(_, k)
                        -- Inherit Visual/Logic Aura Settings
                        if k == "aurasEnabled" or k == "auraSize" or k == "maxAuras" or k == "Whitelist" or k == "Blacklist" or k == "ShowOnlyPlayer" or k == "auraAnchor" or k == "auraX" or k == "auraY" or k == "auraGrowDirection" or k == "showBuffs" or k == "showDebuffs" then
                            return driverDB[k]
                        end
                        return specificDB[k]
                    end
                })
            end
        end
        local enabled = db.aurasEnabled ~= false
        local size = db.auraSize or 20
        local maxIcons = db.maxAuras or 8
        -- Anchor & Position
        local anchor = db.auraAnchor or "BOTTOMLEFT"
        local offX = db.auraX or 0
        local offY = db.auraY or 4
        local growDir = db.auraGrowDirection or "RIGHT"

        local showDebuffs = db.showDebuffs ~= false
        local showBuffs = db.showBuffs ~= false

        if not enabled then
            element:Hide()
            return
        end
        element:Show()

        -- Apply Layout
        element:ClearAllPoints()
        -- Map "TOP" -> TOPLEFT, "BOTTOM" -> BOTTOMLEFT etc logic?
        -- User dropdown has TOP, BOTTOM, LEFT, RIGHT.
        -- Let's assume standard anchoring logic:
        -- If user picks "TOP", we anchor element's BOTTOM to frame's TOP? Or element's TOP to frame's TOP?
        -- Usually:
        -- TOP: Element BOTTOM -> Frame TOP
        -- BOTTOM: Element TOP -> Frame BOTTOM
        -- LEFT: Element RIGHT -> Frame LEFT
        -- RIGHT: Element LEFT -> Frame RIGHT

        local p, rP = "BOTTOMLEFT", "TOPLEFT" -- Defaults

        if anchor == "TOP" then
            p, rP = "BOTTOM", "TOP"
        elseif anchor == "BOTTOM" then
            p, rP = "TOP", "BOTTOM"
        elseif anchor == "LEFT" then
            p, rP = "RIGHT", "LEFT"
        elseif anchor == "RIGHT" then
            p, rP = "LEFT", "RIGHT"
        end

        element:SetPoint(p, frame, rP, offX, offY)
        element:SetHeight(size)

        -- Grow Params
        local anchor1, anchor2, relPoint, xSpace = "LEFT", "LEFT", "RIGHT", 4
        if growDir == "LEFT" then
            anchor1, anchor2, relPoint, xSpace = "RIGHT", "RIGHT", "LEFT", -4
        end

        local icons = element.icons
        local iconIndex = 1

        local isWhiteListActive = (db.Whitelist and next(db.Whitelist))

        -- 1. Debuffs
        if showDebuffs then
            local debuffFilter = "HARMFUL"
            if db.ShowOnlyPlayer then debuffFilter = debuffFilter .. "|PLAYER" end

            for i = 1, 40 do
                if iconIndex > maxIcons then break end
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, debuffFilter)
                if not aura then break end

                -- Defensive Filter Checks (12.0.1 Safety)
                local isSecretId = issecretvalue(aura.spellId)
                local isSecretSrc = issecretvalue(aura.sourceUnit)
                local skip = false

                -- A. Show Only Player check is handled by API filter now

                -- B. Blacklist
                if not skip and db.Blacklist then
                    if isSecretId then
                        skip = true
                    elseif db.Blacklist[aura.spellId] then
                        skip = true
                    end
                end

                -- C. Whitelist (Strict)
                if not skip and isWhiteListActive then
                    if isSecretId then
                        skip = true
                    elseif not db.Whitelist[aura.spellId] then
                        skip = true
                    end
                end

                if not skip then
                    local icon = icons[iconIndex] or CreateIcon(iconIndex)
                    icon:SetSize(size, size) -- Apply Size
                    icon:ClearAllPoints()
                    -- Dynamic Grow
                    if iconIndex == 1 then
                        icon:SetPoint(anchor1, element, anchor1, 0, 0)
                    else
                        icon:SetPoint(anchor1, icons[iconIndex - 1], relPoint, xSpace, 0)
                    end

                    icon.icon:SetTexture(aura.icon)
                    local count = aura.applications
                    local text = ""
                    if count then
                        local success, result = pcall(function() return count > 1 end)
                        if success and result then
                            text = tostring(count)
                        end
                    end
                    icon.count:SetText(text)

                    -- Store data for Tooltip
                    icon.index = i
                    icon.filter = debuffFilter

                    -- Debuff Type Color
                    local color = nil
                    ---@diagnostic disable-next-line: undefined-field
                    if _G.DebuffTypeColor then
                        ---@diagnostic disable-next-line: undefined-field
                        color = _G.DebuffTypeColor[aura.dispelName] or _G.DebuffTypeColor["none"]
                    else
                        color = { r = 1, g = 0, b = 0 } -- Fallback
                    end

                    if icon.SetBackdropBorderColor then
                        icon:SetBackdropBorderColor(color.r, color.g, color.b)
                    end
                    icon.overlay:SetVertexColor(color.r, color.g, color.b)
                    icon.overlay:Show()

                    -- Pandemic Glow (12.0.1+ Safe)
                    -- If ShowOnlyPlayer is true, it IS player. If false, check source safely.
                    local isPlayerAura = db.ShowOnlyPlayer or (not isSecretSrc and aura.sourceUnit == "player")

                    if isPlayerAura and C_UnitAuras.IsAuraInRefreshWindow then
                        local isPandemic = C_UnitAuras.IsAuraInRefreshWindow(unit, aura.auraInstanceID)
                        if icon.GlowFrame.SetShownFromSecret then
                            icon.GlowFrame:SetShownFromSecret(isPandemic)
                        else
                            icon.GlowFrame:Hide()
                        end
                    else
                        icon.GlowFrame:Hide()
                    end

                    icon:Show()
                    iconIndex = iconIndex + 1
                end
            end
        end

        -- 2. Buffs
        if showBuffs then
            local buffFilter = "HELPFUL"
            if db.ShowOnlyPlayer then buffFilter = buffFilter .. "|PLAYER" end

            for i = 1, 40 do
                if iconIndex > maxIcons then break end
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, buffFilter)
                if not aura then break end

                -- Defensive Filter Checks (12.0.1 Safety)
                local isSecretId = issecretvalue(aura.spellId)
                local isSecretSrc = issecretvalue(aura.sourceUnit)
                local skip = false

                -- A. Show Only Player handled by API filter

                -- B. Blacklist
                if not skip and db.Blacklist then
                    if isSecretId then
                        skip = true
                    elseif db.Blacklist[aura.spellId] then
                        skip = true
                    end
                end

                -- C. Whitelist (Strict)
                if not skip and isWhiteListActive then
                    if isSecretId then
                        skip = true
                    elseif not db.Whitelist[aura.spellId] then
                        skip = true
                    end
                end

                if not skip then
                    local icon = icons[iconIndex] or CreateIcon(iconIndex)
                    icon:SetSize(size, size) -- Apply Size
                    icon:ClearAllPoints()
                    -- Dynamic Grow
                    if iconIndex == 1 then
                        icon:SetPoint(anchor1, element, anchor1, 0, 0)
                    else
                        icon:SetPoint(anchor1, icons[iconIndex - 1], relPoint, xSpace, 0)
                    end

                    icon.icon:SetTexture(aura.icon)
                    local count = aura.applications
                    local text = ""
                    if count then
                        local success, result = pcall(function() return count > 1 end)
                        if success and result then
                            text = tostring(count)
                        end
                    end
                    icon.count:SetText(text)

                    icon.index = i
                    icon.filter = buffFilter

                    if icon.SetBackdropBorderColor then
                        icon:SetBackdropBorderColor(0, 0, 0)
                    end
                    icon.overlay:Hide()

                    -- Pandemic Glow (12.0.1+ Safe)
                    local isPlayerAura = db.ShowOnlyPlayer or (not isSecretSrc and aura.sourceUnit == "player")

                    if isPlayerAura and C_UnitAuras.IsAuraInRefreshWindow then
                        local isPandemic = C_UnitAuras.IsAuraInRefreshWindow(unit, aura.auraInstanceID)
                        if icon.GlowFrame.SetShownFromSecret then
                            icon.GlowFrame:SetShownFromSecret(isPandemic)
                        else
                            icon.GlowFrame:Hide()
                        end
                    else
                        icon.GlowFrame:Hide()
                    end

                    icon:Show()
                    iconIndex = iconIndex + 1
                end
            end
        end

        -- Mock Data for Edit Mode (WYSIWYG)
        if frame.forceShowEditMode or frame.forceShowTest then
            for i = 1, 3 do
                local icon = icons[iconIndex] or CreateIcon(iconIndex)
                icon:SetSize(size, size)
                icon:ClearAllPoints()
                -- Dynamic Grow
                if iconIndex == 1 then
                    icon:SetPoint(anchor1, element, anchor1, 0, 0)
                else
                    icon:SetPoint(anchor1, icons[iconIndex - 1], relPoint, xSpace, 0)
                end

                -- Mock Textures (1: Green Buff, 2: Red Debuff, 3: Purple Curse etc)
                local tex = "Interface\\Icons\\Spell_Nature_Regeneration"
                if i == 2 then tex = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" end
                if i == 3 then tex = "Interface\\Icons\\Spell_Holy_WordFortitude" end

                icon.icon:SetTexture(tex)
                icon.count:SetText("")

                if i == 2 then
                    if icon.SetBackdropBorderColor then icon:SetBackdropBorderColor(1, 0, 0) end
                    icon.overlay:SetVertexColor(1, 0, 0)
                    icon.overlay:Show()
                else
                    if icon.SetBackdropBorderColor then icon:SetBackdropBorderColor(0, 0, 0) end
                    icon.overlay:Hide()
                end

                icon.GlowFrame:Hide()
                icon:Show()
                iconIndex = iconIndex + 1
            end
        end

        -- Hide unused
        for i = iconIndex, #icons do
            icons[i]:Hide()
        end
    end

    frame:HookScript("OnEvent", function(self, event, arg1)
        if event == "UNIT_AURA" then
            if arg1 == self.unit then
                frame.UpdateAuras()
            end
        elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            frame.UpdateAuras()
        end
    end)
    frame:RegisterEvent("UNIT_AURA", frame.UpdateAuras)
    frame:RegisterEvent("PLAYER_TARGET_CHANGED", frame.UpdateAuras, true)
    frame:RegisterEvent("PLAYER_FOCUS_CHANGED", frame.UpdateAuras, true)

    frame:HookScript("OnShow", frame.UpdateAuras)
    frame.UpdateAuras()
end

function UF:UpdateAuras(frame)
    if frame.UpdateAuras then
        frame.UpdateAuras()
    end
end
