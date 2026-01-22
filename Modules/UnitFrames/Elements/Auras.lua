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
        LibRoithi.mixins:SetFont(icon.count, "Friz Quadrata TT", 10, "OUTLINE")
        icon.count:SetPoint("BOTTOMRIGHT", 2, -2)

        icon.overlay = icon:CreateTexture(nil, "OVERLAY")
        icon.overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        icon.overlay:SetAllPoints()
        icon.overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        icon.overlay:Hide()

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
        local enabled = db.aurasEnabled ~= false
        local size = db.auraSize or 20
        local maxIcons = db.maxAuras or 8
        local showDebuffs = true
        local showBuffs = true

        if not enabled then
            element:Hide()
            return
        end
        element:Show()

        if unit == "player" then
            showBuffs = false
        end

        -- Resize container height approx
        element:SetHeight(size)

        local icons = element.icons
        local iconIndex = 1

        -- 1. Debuffs
        if showDebuffs then
            for i = 1, 40 do
                if iconIndex > maxIcons then break end
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
                if not aura then break end

                local icon = icons[iconIndex] or CreateIcon(iconIndex)
                icon:SetSize(size, size) -- Apply Size
                icon:ClearAllPoints()
                if iconIndex == 1 then
                    icon:SetPoint("LEFT", element, "LEFT", 0, 0)
                else
                    icon:SetPoint("LEFT", icons[iconIndex - 1], "RIGHT", 4, 0)
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
                icon.filter = "HARMFUL"

                -- Debuff Type Color
                local color = nil
                ---@diagnostic disable-next-line: undefined-field
                if _G.DebuffTypeColor then
                    ---@diagnostic disable-next-line: undefined-field
                    color = _G.DebuffTypeColor[aura.dispelName] or _G.DebuffTypeColor["none"]
                else
                    color = { r = 1, g = 0, b = 0 } -- Fallback
                end

                -- Highlight Code (simplified) inlined or keep separate?
                -- The original code has highlight color logic here.
                -- Let's keep it.

                if icon.SetBackdropBorderColor then
                    icon:SetBackdropBorderColor(color.r, color.g, color.b)
                end
                icon.overlay:SetVertexColor(color.r, color.g, color.b)
                icon.overlay:Show()

                icon:Show()
                iconIndex = iconIndex + 1
            end
        end

        -- 2. Buffs
        if showBuffs then
            for i = 1, 40 do
                if iconIndex > maxIcons then break end
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
                if not aura then break end

                local icon = icons[iconIndex] or CreateIcon(iconIndex)
                icon:SetSize(size, size) -- Apply Size
                icon:ClearAllPoints()
                if iconIndex == 1 then
                    icon:SetPoint("LEFT", element, "LEFT", 0, 0)
                else
                    icon:SetPoint("LEFT", icons[iconIndex - 1], "RIGHT", 4, 0)
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
                icon.filter = "HELPFUL"

                if icon.SetBackdropBorderColor then
                    icon:SetBackdropBorderColor(0, 0, 0)
                end
                icon.overlay:Hide()

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
