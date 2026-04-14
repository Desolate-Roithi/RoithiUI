local _, ns = ...
local oUF = ns.oUF
if not oUF then return end

local LCG = LibStub("LibCustomGlow-1.0", true)

-- 12.0.1 Secret API / 11.0.2 Compat
local IsAuraInRefreshWindow = C_UnitAuras and C_UnitAuras.IsAuraInRefreshWindow

-- UpdateGlow: not exposed as a standalone element in this version;
-- pandemic/dispel detection is done via PostUpdateIcon below.
local function UpdateGlow(self, _, unit)
    if self.unit ~= unit then return end

    local element = self.Glows
    if not element then return end

    -- Reset
    if LCG then
        LCG.PixelGlow_Stop(element.Pandemic)
        LCG.AutoCastGlow_Stop(element.Dispel)
    else
        element.Pandemic:Hide()
        element.Dispel:Hide()
    end

    local i = 1
    local filter = (unit == "target" or unit == "nameplate") and "PLAYER|HARMFUL" or "PLAYER|HELPFUL"

    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not aura then break end

        -- Pandemic / Dispel detection for frame-level glow is handled in PostUpdateIcon
        -- (see below). No per-frame-state tracking needed here.

        i = i + 1
    end
end
-- Suppress unused warning: UpdateGlow is exported below in a future pass if needed
ns._UpdateGlow = UpdateGlow

-- HELPER: PostUpdateIcon
local function PostUpdateIcon(element, unit, button, index, position)
    local data = C_UnitAuras.GetAuraDataByIndex(unit, index, element.filter)
    if not data then return end

    -- 1. Create Glow Frame if missing
    if not button.Glow then
        button.Glow = CreateFrame("Frame", nil, button)
        button.Glow:SetAllPoints()
        button.Glow.Texture = button.Glow:CreateTexture(nil, "OVERLAY")
        button.Glow.Texture:SetTexture("Interface\\Buttons\\CheckButtonGlow")
        button.Glow.Texture:SetAllPoints()
        button.Glow.Texture:SetBlendMode("ADD")
        button.Glow:Hide()

        -- Add SetShownFromSecret if missing (Compat)
        if not button.Glow.SetShownFromSecret then
            button.Glow.SetShownFromSecret = function(self, show)
                -- Fallback for non-secret envs (or if boolean is vanilla true/false)
                if show then self:Show() else self:Hide() end
            end
        end
    end

    -- 2. PANDEMIC GLOW (Secret API)
    if IsAuraInRefreshWindow and data.auraInstanceID then
        local isPandemic = C_UnitAuras.IsAuraInRefreshWindow(unit, data.auraInstanceID)
        -- Secret Safe SetShown
        button.Glow:SetShownFromSecret(isPandemic)

        -- If LCG is used, we can't easily pass a Secret to LCG functions (they use standard Lua).
        -- So for 12.0, we MUST use standard texture glow with SetShownFromSecret
        -- unless LCG updates to support secrets.
        -- For now, we only support Texture glow for Pandemic to be 100% safe.
    end

    -- 3. DISPEL / STEAL GLOW (Standard)
    if button.Stealable then button.Stealable:Hide() end -- Default oUF might handle this, we override/enhance

    local showDispel = false
    if data.isStealable or (data.dispelName ~= nil) then
        showDispel = true
    end

    if LCG and element.useLibCustomGlow and showDispel then
        LCG.PixelGlow_Start(button,
            {
                color = { 1, 1, 1, 1 },
                N = 8,
                frequency = 0.25,
                length = 4,
                th = 2,
                xOffset = 0,
                yOffset = 0,
                border = true,
                key =
                "dispel"
            })
    elseif showDispel then
        -- Fallback or Standard Border
        if not button.Overlay then
            button.Overlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
            button.Overlay:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
            button.Overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
            button.Overlay:SetAllPoints()
        end

        local color = DebuffTypeColor[data.dispelName] or DebuffTypeColor.none
        button.Overlay:SetVertexColor(color.r, color.g, color.b)
        button.Overlay:Show()
    else
        if LCG then LCG.PixelGlow_Stop(button, "dispel") end
        if button.Overlay then button.Overlay:Hide() end
    end
end

-- Export
ns.Glows = {
    PostUpdateIcon = PostUpdateIcon
}
