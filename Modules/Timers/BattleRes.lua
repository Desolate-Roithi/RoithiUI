local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local Timers = RoithiUI:GetModule("Timers")
local LibRoithi = LibStub("LibRoithi-1.0")

-- Rebirth Spell ID (Shared Tracking)
-- Battle Res Spell IDs (Druid, DK, Warlock, Paladin)
local BRES_SPELLS = { 20484, 61999, 20707, 391054 }

function Timers:CreateBattleResTimer()
    local frame, db = self:CreateTimerFrame("BattleRes", "BattleRes", "Battle Res")

    -- Visuals
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(C_Spell.GetSpellTexture(BRES_SPELLS[1]) or 136080) -- Fallback
    frame.Icon = icon

    local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cd:SetAllPoints()
    frame.Cooldown = cd

    local text = frame:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 20, "OUTLINE")
    text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    frame.Text = text -- Charge Count

    LibRoithi.mixins:CreateBackdrop(frame)

    -- Update Logic
    local function Update(self)
        if self.isInEditMode then
            self.Text:SetText("3")
            self.Cooldown:SetCooldown(GetTime(), 0)
            self:Show()
            return
        end

        if not db.enabled then
            self:Hide(); return
        end

        -- Only show in Groups generally? Or always?
        -- API returns nil charges if solo/not applicable?
        -- GetSpellCharges(20484) works for Druids always.
        -- For non-Druids, does it return the group charge?
        -- Yes, GetSpellCharges(20484) is a known hack for tracking shared charges.

        local chargeInfo
        for _, id in ipairs(BRES_SPELLS) do
            local info = C_Spell.GetSpellCharges(id)
            if info then
                chargeInfo = info
                break
            end
        end
        if not chargeInfo then
            self:Hide()
            return
        end

        local currentCharges = chargeInfo.currentCharges
        local maxCharges = chargeInfo.maxCharges
        local cooldownStart = chargeInfo.cooldownStartTime
        local cooldownDuration = chargeInfo.cooldownDuration
        local chargeModRate = chargeInfo.chargeModRate

        self:Show()
        self.Text:SetText(currentCharges)

        -- If we have charges < max, show CD for next charge
        if currentCharges < maxCharges then
            self.Cooldown:SetCooldown(cooldownStart, cooldownDuration, chargeModRate)
        else
            self.Cooldown:Clear()
        end
    end

    frame.Update = Update
    frame:SetScript("OnEvent", Update)

    -- Events
    -- SPELL_UPDATE_CHARGES covers replenishment
    frame:RegisterEvent("SPELL_UPDATE_CHARGES")
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    -- Group update might enable/disable the system
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Hooks for Edit Mode
    frame.OnEditModeEnter = function() Update(frame) end
    frame.OnEditModeExit = function() Update(frame) end

    Update(frame)
end
