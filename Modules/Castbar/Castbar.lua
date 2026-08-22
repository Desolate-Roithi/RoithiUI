local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LSM = LibStub("LibSharedMedia-3.0")

-- ----------------------------------------------------------------------------
-- 1. Bar Creation
-- ----------------------------------------------------------------------------
function ns.CreateCastBar(unit)
    local bar = CreateFrame("StatusBar", "MidnightCastBar_" .. unit, UIParent)
    local profile = RoithiUI.db and RoithiUI.db.profile
    local general = profile and profile.General
    local texture = LSM:Fetch("statusbar", (general and general.barTexture) or "Solid") or
        "Interface\\TargetingFrame\\UI-StatusBar"
    bar:SetStatusBarTexture(texture)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar); bg:SetColorTexture(0, 0, 0, 0.5)
    bar.Background = bg

    local icon = bar:CreateTexture(nil, "OVERLAY"); icon:SetPoint("RIGHT", bar, "LEFT", 0, 0);
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Square crop/zoom
    bar.Icon = icon

    local font = LSM:Fetch("font", (general and general.font) or "Friz Quadrata TT") or [[Fonts\FRIZQT__.TTF]]

    -- 1. Create sub-widgets first to allow relative anchoring
    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(font, 12, "OUTLINE")
    timeText:SetPoint("RIGHT", -4, 0)
    bar.TimeFS = timeText

    local text = bar:CreateFontString(nil, "OVERLAY");
    text:SetFont(font, 12, "OUTLINE")
    text:SetPoint("LEFT", 4, 0);                      -- Align Left with padding
    text:SetPoint("RIGHT", bar.TimeFS, "LEFT", -4, 0) -- Now valid as TimeFS exists
    bar.Text = text

    -- Spark (Standard Texture)
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    bar.Spark = spark

    bar.StageTicks = {}

    -- Latency Bar (Safe Zone)
    local latency = bar:CreateTexture(nil, "ARTWORK")
    latency:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    latency:SetVertexColor(1, 0, 0, 0.5) -- Red semi-transparent
    latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    local h = bar:GetHeight()
    if h and h > 0 then latency:SetHeight(h) end
    latency:Hide()
    bar.Latency = latency

    bar.unit = unit; bar:Hide()
    bar:SetClampedToScreen(true)
    return bar
end

function ns.UpdateCastBarMedia(bar)
    if not bar then return end
    local profile = RoithiUI.db and RoithiUI.db.profile
    local general = profile and profile.General
    local texture = LSM:Fetch("statusbar", (general and general.barTexture) or "Solid") or
        "Interface\\TargetingFrame\\UI-StatusBar"
    bar:SetStatusBarTexture(texture) -- Keep this line as it's essential for setting the texture
    local font = LSM:Fetch("font", (general and general.font) or "Friz Quadrata TT") or [[Fonts\FRIZQT__.TTF]]
    -- We assume standard size 12 here, or we could fetch from DB if we added size option
    if bar.Text then
        bar.Text:SetFont(font, 12, "OUTLINE")
    end
    -- Update Font for Time string
    if bar.TimeFS then bar.TimeFS:SetFont(font, 12, "OUTLINE") end
end

function ns.RefreshAllCastbars()
    if not ns.bars then return end
    local cbDB = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Castbar
    for unit, bar in pairs(ns.bars) do
        ns.UpdateCastBarMedia(bar)
        local db = cbDB and cbDB[unit]
        if db then
            if not db.enabled then
                bar:Hide()
            end
            if ns.SetCastbarAttachment then
                ns.SetCastbarAttachment(unit, not db.detached)
            end
        end
    end
end

function ns.InitializeBars()
    for unit, _ in pairs(ns.DEFAULTS) do
        local bar = ns.CreateCastBar(unit)
        ns.bars[unit] = bar
        if ns.RegisterCastbarLEM then
            ns.RegisterCastbarLEM(bar, unit)
        end
    end
end

-- ----------------------------------------------------------------------------
-- 1.5. Safety Wrappers (12.0.1+ Helper mocks)
-- ----------------------------------------------------------------------------
local function FormatDuration(val)
    if not val then return "" end
    -- Secret Safety: If issecretvalue(val), we can't do math, but string.format works natively.
    if (issecretvalue and issecretvalue(val)) or (canaccessvalue and not canaccessvalue(val)) then
        local success, str = pcall(string.format, "%.1f", val)
        if success then return str end
        return ""
    end

    if type(val) == "number" then
        if val >= 60 then
            return string.format("%d:%02d", math.floor(val / 60), val % 60)
        end
        return string.format("%.1f", val)
    end
    -- Fallback
    return val
end

local function GetSafeLatency()
    -- Try C_Castbar first (12.0.1)
    if C_Castbar and C_Castbar.GetLatencyAspect then
        local success, latency = pcall(C_Castbar.GetLatencyAspect)
        if success and latency then return latency / 1000 end
    end
    -- Fallback: Network World Latency
    local _, _, home, world = GetNetStats()
    return (world or home) / 1000
end

-- ----------------------------------------------------------------------------
-- 1.6. Player Class Interrupt Tracking
-- ----------------------------------------------------------------------------
local INTERRUPT_SPELLS = {
    -- Warrior
    [6552] = true, -- Pummel
    -- Death Knight
    [47528] = true, -- Mind Freeze
    -- Demon Hunter
    [183752] = true, -- Disrupt
    -- Druid
    [106839] = true, -- Skull Bash
    [78675] = true, -- Solar Beam
    -- Evoker
    [351338] = true, -- Quell
    -- Hunter
    [147362] = true, -- Counter Shot
    [187707] = true, -- Muzzle
    -- Mage
    [2139] = true, -- Counterspell
    -- Monk
    [116705] = true, -- Spear Hand Strike
    -- Paladin
    [96231] = true, -- Rebuke
    [31935] = true, -- Avenger's Shield
    -- Priest
    [15487] = true, -- Silence
    -- Rogue
    [1766] = true, -- Kick
    -- Shaman
    [57994] = true, -- Wind Shear
    -- Warlock
    [19647] = true, -- Spell Lock (Pet)
    [119910] = true, -- Spell Lock (Command Demon)
    [119898] = true, -- Command Demon
    [132409] = true, -- Spell Lock (Grimoire)
    [171138] = true, -- Shadow Lock
    [89766] = true, -- Axe Toss (Felguard)
}

local cachedInterruptSpellID = nil

local function UpdatePlayerInterruptSpell()
    cachedInterruptSpellID = nil
    for spellID in pairs(INTERRUPT_SPELLS) do
        if (_G.C_SpellBook and _G.C_SpellBook.IsSpellKnownOrInSpellBook and (_G.C_SpellBook.IsSpellKnownOrInSpellBook(spellID) or (_G.Enum and _G.Enum.SpellBookSpellBank and _G.C_SpellBook.IsSpellKnownOrInSpellBook(spellID, _G.Enum.SpellBookSpellBank.Pet))))
            or (_G.IsSpellKnownOrOverridesKnown and _G.IsSpellKnownOrOverridesKnown(spellID))
            or (_G.IsPlayerSpell and _G.IsPlayerSpell(spellID)) then
            cachedInterruptSpellID = spellID
            return spellID
        end
    end
    if _G.IsSpellKnownOrOverridesKnown and _G.IsSpellKnownOrOverridesKnown(119898) then
        cachedInterruptSpellID = 119898
        return 119898
    end
    return nil
end

ns.UpdatePlayerInterruptSpell = UpdatePlayerInterruptSpell

local function GetPlayerInterruptCooldownState()
    local spellID = cachedInterruptSpellID or UpdatePlayerInterruptSpell()
    if not spellID then return false, nil end

    -- 1. Try C_Spell.GetSpellCooldownDuration(spellID, true) first (12.0.1+ Native API)
    if C_Spell and C_Spell.GetSpellCooldownDuration then
        local success, durObj = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
        if success and durObj and durObj.IsZero then
            local isZeroSuccess, isZero = pcall(durObj.IsZero, durObj)
            if isZeroSuccess and isZero ~= nil then
                local isZeroSecret = (issecretvalue and issecretvalue(isZero)) or (canaccessvalue and not canaccessvalue(isZero))
                if isZeroSecret then
                    -- isZero is a SECRET boolean (true = 0 CD / Ready, false = on CD)
                    return nil, isZero
                else
                    return not isZero, nil
                end
            end
        end
    end

    -- 2. Fallback to C_Spell.GetSpellCooldown
    local startTime, duration, isEnabled
    if C_Spell and C_Spell.GetSpellCooldown then
        local success, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if success and info then
            startTime = info.startTime
            duration = info.duration
            isEnabled = info.isEnabled
        end
    elseif _G.GetSpellCooldown then
        local success, sT, dur, en = pcall(_G.GetSpellCooldown, spellID)
        if success then
            startTime = sT
            duration = dur
            isEnabled = en
        end
    end

    if isEnabled == 0 or isEnabled == false then
        return false, nil
    end

    local isDurationSecret = (issecretvalue and issecretvalue(duration)) or (canaccessvalue and not canaccessvalue(duration))
    local isStartSecret = (issecretvalue and issecretvalue(startTime)) or (canaccessvalue and not canaccessvalue(startTime))
    if isDurationSecret or isStartSecret then
        return false, nil
    end

    if not duration or duration <= 1.5 or not startTime or startTime <= 0 then
        return false, nil
    end

    local curTime = _G.GetTime and _G.GetTime() or 0
    if curTime > 0 and startTime > 0 then
        local rem = (startTime + duration) - curTime
        return rem > 0.1, nil
    end

    return true, nil
end

ns.GetPlayerInterruptCooldownState = GetPlayerInterruptCooldownState

-- ----------------------------------------------------------------------------
-- 2. Update Logic
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- 2. Update Logic (Matching castbar_example.lua)
-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- 2. Update Logic (Pure Combat-Safe durationObj Engine)
-- ----------------------------------------------------------------------------
local function OnCastbarUpdate(self, elapsed)
    if self.isInEditMode or self.isInterrupted then return end
    if not self.casting and not self.channeling then return end
    if not self.durationObj then return end

    if self.SetTimerDuration then
        local dir = self.channeling and (_G.Enum and _G.Enum.StatusBarTimerDirection and _G.Enum.StatusBarTimerDirection.RemainingTime or 1) or (_G.Enum and _G.Enum.StatusBarTimerDirection and _G.Enum.StatusBarTimerDirection.ElapsedTime or 0)
        local interp = _G.Enum and _G.Enum.StatusBarInterpolation and _G.Enum.StatusBarInterpolation.Immediate or 0
        self:SetTimerDuration(self.durationObj, interp, dir)
    else
        local total = self.durationObj:GetTotalDuration()
        local rem = self.durationObj:GetRemainingDuration()
        local isSecret = (issecretvalue and issecretvalue(total)) or (canaccessvalue and not canaccessvalue(total))
        if not isSecret and total and total > 0 then
            self.maxValue = total
            self.value = self.channeling and rem or (total - rem)
            self:SetMinMaxValues(0, total)
            self:SetValue(self.value)
        end
    end

    if self.TimeFS then
        local rem = self.durationObj:GetRemainingDuration()
        self.TimeFS:SetText(FormatDuration(rem))
    end
end

function ns.UpdateCast(bar, unitOverride)
    local unit = unitOverride or (bar and bar.unit)
    if not bar or not unit then return end

    local db = RoithiUI.db.profile.Castbar[bar.unit]
    if not db or not db.enabled then
        bar:Hide(); bar:SetScript("OnUpdate", nil)
        return
    end

    if bar.isInEditMode then return end

    local name, text, texture, notInterruptible, castID
    local durationObj
    local isChannel = false
    local state = "cast"

    -- Check Channel / Empowered
    local chName, chText, chTexture, _, _, _, chNotInt, _, isEmpowered, numEmpowerStages = UnitChannelInfo(unit)
    if chName then
        name = chName
        text = chText
        texture = chTexture
        notInterruptible = chNotInt
        isChannel = true
        state = (isEmpowered or (numEmpowerStages and numEmpowerStages > 0)) and "empowered" or "channel"
        if isEmpowered or (numEmpowerStages and numEmpowerStages > 0) then
            durationObj = UnitEmpoweredChannelDuration and UnitEmpoweredChannelDuration(unit, true)
        else
            durationObj = UnitChannelDuration and UnitChannelDuration(unit)
        end
    else
        local cName, cText, cTexture, _, _, _, cID, cNotInt = UnitCastingInfo(unit)
        if cName then
            name = cName
            text = cText
            texture = cTexture
            castID = cID
            notInterruptible = cNotInt
            isChannel = false
            state = "cast"
            durationObj = UnitCastingDuration and UnitCastingDuration(unit)
        end
    end

    if not name or not durationObj then
        if bar.isEmpower and ns.StopEmpower then ns.StopEmpower(bar) end
        if not bar.isInterrupted and not bar.isInEditMode then
            bar.casting = false
            bar.channeling = false
            bar.durationObj = nil
            bar.castID = nil
            bar:Hide()
            bar:SetScript("OnUpdate", nil)
        end
        return
    end

    local totalSec = durationObj:GetTotalDuration()
    local remSec = durationObj:GetRemainingDuration()
    local isTotalSecret = (issecretvalue and issecretvalue(totalSec)) or (canaccessvalue and not canaccessvalue(totalSec))

    local curVal = 0
    if not isTotalSecret then
        if not totalSec or totalSec <= 0 then totalSec = 1 end
        curVal = isChannel and remSec or (totalSec - remSec)
        if curVal < 0 then curVal = 0 end
        if curVal > totalSec then curVal = totalSec end
    end

    bar.isInterrupted = false
    bar.casting = not isChannel
    bar.channeling = isChannel
    bar.value = curVal
    bar.maxValue = totalSec
    bar.durationObj = durationObj
    bar.castID = castID

    -- Visual Setup
    local colors = db.colors
    local shieldC = (colors and colors.shield) or { 0.5, 0.5, 0.5, 1 }
    local kickCDC = (colors and colors.interruptOnCD) or { 0.9, 0.5, 0.1, 1 }
    local normC = (colors and (colors[state] or colors.cast)) or { 1, 0.95, 0, 1 }

    local isKickOnCD, isKickZeroSecret
    if bar.unit ~= "player" and db.colorOnInterruptCD then
        isKickOnCD, isKickZeroSecret = GetPlayerInterruptCooldownState()
    end

    local isNotIntSecret = (issecretvalue and issecretvalue(notInterruptible)) or (canaccessvalue and not canaccessvalue(notInterruptible))
    local hasKickZeroSecret = (issecretvalue and issecretvalue(isKickZeroSecret)) or (canaccessvalue and not canaccessvalue(isKickZeroSecret))

    if db.showIcon then
        bar.Icon:Show(); bar.Icon:SetTexture(texture)
    else
        bar.Icon:Hide()
    end

    local isSecretText = (issecretvalue and issecretvalue(text)) or (canaccessvalue and not canaccessvalue(text))
    if not isSecretText and text and string.len(text) > 22 then
        text = string.sub(text, 1, 22) .. "..."
    end
    if bar.Text then bar.Text:SetText(text) end

    -- Color Evaluation Pipeline (Pure Combat-Safe with C_CurveUtil)
    if (isNotIntSecret or hasKickZeroSecret) and C_CurveUtil and (C_CurveUtil.EvaluateColorValueFromBoolean or C_CurveUtil.EvaluateColorFromBoolean) then
        local rBase, gBase, bBase, aBase
        if hasKickZeroSecret then
            -- isKickZeroSecret: true = 0 CD (Ready) -> normC, false = active CD -> kickCDC
            if C_CurveUtil.EvaluateColorValueFromBoolean then
                rBase = C_CurveUtil.EvaluateColorValueFromBoolean(isKickZeroSecret, normC[1], kickCDC[1])
                gBase = C_CurveUtil.EvaluateColorValueFromBoolean(isKickZeroSecret, normC[2], kickCDC[2])
                bBase = C_CurveUtil.EvaluateColorValueFromBoolean(isKickZeroSecret, normC[3], kickCDC[3])
                aBase = C_CurveUtil.EvaluateColorValueFromBoolean(isKickZeroSecret, normC[4] or 1, kickCDC[4] or 1)
            else
                local baseObj = C_CurveUtil.EvaluateColorFromBoolean(isKickZeroSecret, _G.CreateColor(normC[1], normC[2], normC[3], normC[4] or 1), _G.CreateColor(kickCDC[1], kickCDC[2], kickCDC[3], kickCDC[4] or 1))
                rBase, gBase, bBase, aBase = baseObj:GetRGBA()
            end
        else
            local baseC = (isKickOnCD == true) and kickCDC or normC
            rBase, gBase, bBase, aBase = baseC[1], baseC[2], baseC[3], baseC[4] or 1
        end

        local rFinal, gFinal, bFinal, aFinal
        if isNotIntSecret then
            -- notInterruptible: true = shielded -> shieldC, false = kickable -> base color
            if C_CurveUtil.EvaluateColorValueFromBoolean then
                rFinal = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, shieldC[1], rBase)
                gFinal = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, shieldC[2], gBase)
                bFinal = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, shieldC[3], bBase)
                aFinal = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, shieldC[4] or 1, aBase)
            else
                local finalObj = C_CurveUtil.EvaluateColorFromBoolean(notInterruptible, _G.CreateColor(shieldC[1], shieldC[2], shieldC[3], shieldC[4] or 1), _G.CreateColor(rBase, gBase, bBase, aBase))
                rFinal, gFinal, bFinal, aFinal = finalObj:GetRGBA()
            end
        elseif notInterruptible == true then
            rFinal, gFinal, bFinal, aFinal = shieldC[1], shieldC[2], shieldC[3], shieldC[4] or 1
        else
            rFinal, gFinal, bFinal, aFinal = rBase, gBase, bBase, aBase
        end

        if state == "channel" then
            bar:SetReverseFill(true)
            bar:SetStatusBarColor(0, 0, 0, 1)
            if bar.Background then
                if bar.Background.SetColorTexture then
                    bar.Background:SetColorTexture(rFinal, gFinal, bFinal, aFinal)
                elseif bar.Background.SetVertexColor then
                    bar.Background:SetVertexColor(rFinal, gFinal, bFinal, aFinal)
                end
            end
        else
            bar:SetReverseFill(false)
            bar:SetStatusBarColor(rFinal, gFinal, bFinal, aFinal)
            if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
        end
    else
        local isShield = (not isNotIntSecret and notInterruptible == true)
        local baseC = (isKickOnCD == true) and kickCDC or normC
        local c = isShield and shieldC or baseC

        if state == "channel" then
            bar:SetReverseFill(true)
            bar:SetStatusBarColor(0, 0, 0, 1)
            if bar.Background then bar.Background:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
        else
            bar:SetReverseFill(false)
            bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
            if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
        end
    end

    -- Latency Ping Bar
    if bar.Latency then
        if not isTotalSecret and totalSec and totalSec > 0 then
            local latencySec = GetSafeLatency()
            if latencySec > 0 then
                local width = bar:GetWidth() * (latencySec / totalSec)
                if width > bar:GetWidth() then width = bar:GetWidth() end
                bar.Latency:SetWidth(width)
                bar.Latency:SetHeight(bar:GetHeight())
                bar.Latency:ClearAllPoints()
                if isChannel then
                    bar.Latency:SetPoint("LEFT", bar, "LEFT", 0, 0)
                else
                    bar.Latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
                end
                bar.Latency:Show()
            else
                bar.Latency:Hide()
            end
        else
            bar.Latency:Hide()
        end
    end

    if bar.SetTimerDuration then
        local dir = isChannel and (_G.Enum and _G.Enum.StatusBarTimerDirection and _G.Enum.StatusBarTimerDirection.RemainingTime or 1) or (_G.Enum and _G.Enum.StatusBarTimerDirection and _G.Enum.StatusBarTimerDirection.ElapsedTime or 0)
        local interp = _G.Enum and _G.Enum.StatusBarInterpolation and _G.Enum.StatusBarInterpolation.Immediate or 0
        bar:SetTimerDuration(durationObj, interp, dir)
    elseif not isTotalSecret then
        bar:SetMinMaxValues(0, totalSec)
        bar:SetValue(curVal)
    end

    if bar.TimeFS then
        bar.TimeFS:SetText(FormatDuration(remSec))
    end

    bar:SetScript("OnUpdate", OnCastbarUpdate)
    bar:Show()
end

function ns.HandleInterrupt(bar)
    if bar.isEmpower then ns.StopEmpower(bar) end

    -- 1. Visual Updates FIRST (Ensure Text/Color always apply)
    bar.Text:SetText("INTERRUPTED"); bar.Spark:Hide()

    local c = RoithiUI.db.profile.Castbar[bar.unit].colors.interrupted
    if bar.Background and c then
        bar.Background:SetColorTexture(c[1], c[2], c[3], c[4])
        -- Fix V3: Visual Mask (Foreground == Background) to hide filling
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    end


    -- 2. Freeze progress
    bar.isInterrupted = true; bar:SetScript("OnUpdate", nil)
    local frozenVal = bar:GetValue()
    bar:SetValue(frozenVal) -- Explicitly freeze visual state

    -- 4. Vanish after 1 second
    C_Timer.After(1.0, function()
        -- Only hide if we are STILL interrupted (didn't start a new cast)
        -- Using local closure safety
        if bar.isInterrupted then
            bar.isInterrupted = false
            bar:Hide()
        end
    end)
end
