local _, ns = ...
local oUF = ns.oUF

-- Custom Health Prediction Element
-- Logic:
-- 1. MyHeal + OtherHeal = IncidentHeal (Grow from current HP)
-- 2. Absorb = Overlay from Left (Cap at 110% of MaxHP)
-- 3. HealAbsorb = Overlay from Right (Reverse direction)

local function Update(self, event, unit)
    if self.unit ~= unit then return end

    local element = self.HealthPrediction
    if not element then return end

    -- 1. Get Values (Standard oUF path)
    -- We assume oUF core handles the 'UNIT_HEAL_PREDICTION' events and updating values?
    -- Actually oUF's standard element 'HealthPrediction' does the math and Sets the values on the bars.
    -- We just need to hook PostUpdate or handle the layout/clamping.
    -- BUT, standard oUF might not clamp to 110% specifically or handle reverse fill cleanly regarding textures.

    -- Let's rely on oUF's value gathering and just override the display logic in PostUpdate.
    -- oUF populates: element.myBar:SetValue(myIncomingHeal), etc.

    -- We need to ensure the bars are set up in Core.lua, OR we do it here.
    -- User wants *logic* here.
end

-- We will stick to defining the Visual Style in Core.lua (spawning) and just provide
-- a PostUpdate hook here if logic requires it.
-- Actually, for "Cap at 110%", standard oUF bars max out at healthMax usually?
-- No, usually they are set to maxHealth.
-- If we want the BAR to represent 110%, we set the MinMaxValues to 0, maxHealth * 1.1.

local function PostUpdate(self, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb,
                          hasOverHealAbsorb)
    local element = self
    local frame = self.__owner
    local health = frame and frame.SafeHealth
    local maxHealth = UnitHealthMax(unit)

    -- Sanitize/Defaults
    myIncomingHeal = myIncomingHeal or 0
    otherIncomingHeal = otherIncomingHeal or 0
    absorb = absorb or 0
    healAbsorb = healAbsorb or 0
    maxHealth = maxHealth or 0



    -- Protect against 0 max health
    if maxHealth == 0 then maxHealth = 1 end

    -- 1. Setup Ranges (110% Cap for Absorbs)
    -- We want the absorb bar to be able to cover 110% of the frame visually?
    -- No, usually "Cap at 110%" means we don't show more than 110% total HP.
    -- If the frame represents 100% HP, then 110% would go OFF frame.
    -- RoithiUI request: "cap at 110% of health".
    -- This essentially means the Absorb bar shouldn't extend past 110% total effective HP?
    -- Or does it mean the UNIT FRAME width represents 100% HP, but we allow overlay up to 100%?
    -- "Positive absorbs should start from the left side of the frame and cap at 110% of health."
    -- "Start from the left side" imply they are NOT appended to current HP, but overlay from 0?
    -- If they overlay from left (0), and I have 50% HP and 60% Absorb.
    -- Do I see 50% Health Bar + 60% Absorb Bar (overlapping)?
    -- OR 50% Health, then Absorb starts at 50%?
    -- "Start from the left side" strongly implies Overlay from 0.

    -- Let's assume OVERLAY from 0.

    -- 1. MyHeal / OtherHeal (Standard Growth from Current HP)
    -- oUF usually anchors them to Health texture. We need to handle this in layout.

    -- 2. Absorb (Overlay from Left, Cap 110%)
    if element.absorbBar then
        local absorbPct = absorb / maxHealth
        if absorbPct > 1.1 then absorbPct = 1.1 end

        -- If using StatusBar, SetValue(absorb). To enforce cap, we might need to SetMinMax(0, maxHealth)
        -- and SetValue(math.min(absorb, maxHealth * 1.1)).
        -- But wait, if the frame width = maxHealth, then 1.1 is offscreen.
        -- Assuming user accepts 1.1 goes offscreen OR re-scales frame?
        -- Standard UI practice: Bar = MaxHealth. If 110%, it is full + extra?
        -- We will clamp the VALUE to maxHealth * 1.1.

        element.absorbBar:SetMinMaxValues(0, maxHealth)
        element.absorbBar:SetValue(math.min(absorb, maxHealth * 1.1))
    end

    -- 3. HealAbsorb (Reverse from Right)
    if element.healAbsorbBar then
        element.healAbsorbBar:SetMinMaxValues(0, maxHealth)
        element.healAbsorbBar:SetValue(healAbsorb)
    end
end

ns.HealthPrediction = {
    PostUpdate = PostUpdate
}
