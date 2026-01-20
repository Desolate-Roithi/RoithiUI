local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local Timers = RoithiUI:GetModule("Timers")
local LibRoithi = LibStub("LibRoithi-1.0")

-- Spell IDs
local BUFFS = {
    [2825] = true,   -- Bloodlust
    [32182] = true,  -- Heroism
    [80353] = true,  -- Time Warp
    [264667] = true, -- Primal Rage
    [390386] = true, -- Fury of the Aspects
    [102364] = true, -- Ancient Hysteria (Hunter)
}

local DEBUFFS = {
    [57724] = true,  -- Sated
    [57723] = true,  -- Exhaustion
    [80354] = true,  -- Temporal Displacement
    [264689] = true, -- Fatigued
}

-- Icons (Static mapping for Sated if not found dynamically)
local SATED_ICON = 136071 -- Spell_Nature_Sleep / Sated icon generic

function Timers:CreateBloodlustTimer()
    local frame, db = self:CreateTimerFrame("Bloodlust", "Bloodlust", "Bloodlust")

    -- Visuals
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    frame.Icon = icon

    local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cd:SetAllPoints()
    frame.Cooldown = cd

    -- Big text for active buff
    local durationText = frame:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(durationText, "Friz Quadrata TT", 16, "OUTLINE")
    durationText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.DurationText = durationText -- For number countdown

    LibRoithi.mixins:CreateBackdrop(frame)

    -- Helper: Find Aura
    local function FindAura(list, filter)
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
            if not aura then break end
            if list[aura.spellId] then
                return aura
            end
        end
        return nil
    end

    local function Update(self)
        if self.isInEditMode then
            self:Show()
            self.Icon:SetTexture(C_Spell.GetSpellTexture(2825))
            self.Cooldown:SetCooldown(GetTime(), 40)
            self:SetBackdropBorderColor(0, 1, 0, 1) -- Green for active logic sim
            return
        end

        if not db.enabled then
            self:Hide(); return
        end

        -- Priority 1: Active Buff (Happy State!)
        local buff = FindAura(BUFFS, "HELPFUL")
        if buff then
            self:Show()
            self.Icon:SetTexture(buff.icon)
            self.Cooldown:SetCooldown(buff.expirationTime - buff.duration, buff.duration)
            self.DurationText:SetText("") -- Cooldown frame handles swipe, maybe we want big numbers?
            -- Cooldown frame handles numbers if omnicc or game setting on.
            -- Let's highlight green
            LibRoithi.mixins:CreateBackdrop(self) -- Re-apply if needed or just set color
            self:SetBackdropBorderColor(0, 1, 0, 1)
            return
        end

        -- Priority 2: Sated Debuff (Sad State)
        local debuff = FindAura(DEBUFFS, "HARMFUL")
        if debuff then
            self:Show()
            self.Icon:SetTexture(debuff.icon)
            self.Cooldown:SetCooldown(debuff.expirationTime - debuff.duration, debuff.duration)
            -- Highlight Red
            self:SetBackdropBorderColor(1, 0, 0, 1)
            return
        end

        -- Priority 3: Nothing
        self:Hide()
    end

    frame.Update = Update
    frame:SetScript("OnEvent", Update)
    frame:RegisterUnitEvent("UNIT_AURA", "player")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    frame.OnEditModeEnter = function() Update(frame) end
    frame.OnEditModeExit = function() Update(frame) end

    Update(frame)
end
