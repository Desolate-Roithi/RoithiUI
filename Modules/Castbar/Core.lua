local addonName, ns = ...
local RoithiUI = _G.RoithiUI

-- ----------------------------------------------------------------------------
-- 1. Shared Data & Constants
-- ----------------------------------------------------------------------------
ns.bars = {}
ns.anchors = {}
ns.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- Default Settings
-- Updated to match v4 Standard Colors
local DEFAULT_COLORS = {
    cast = { 1, 0.95, 0, 1 },        -- FFF200
    channel = { 0, 0.98, 1, 1 },     -- 00F9FF
    interrupted = { 1, 0, 0, 1 },    -- FF0000
    shield = { 0.5, 0.5, 0.5, 1 },   -- 808080
    empower1 = { 0.8, 0.5, 0.1, 1 }, -- CC801A
    empower2 = { 0.9, 0.9, 0.2, 1 }, -- E6E633
    empower3 = { 0.2, 0.7, 0.2, 1 }, -- 33B333
    empower4 = { 0.3, 0.65, 1, 1 },  -- 4DA6FF
}

ns.DEFAULTS = {
    player = {
        enabled = true,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = -150,
        width = 250,
        height = 25,
        fontSize = 12,
        showIcon = true,
        iconScale = 1.0,
        colors = CopyTable(DEFAULT_COLORS)
    },
    target = {
        enabled = true,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 200,
        width = 300,
        height = 30,
        fontSize = 12,
        showIcon = true,
        iconScale = 1.0,
        colors = CopyTable(DEFAULT_COLORS)
    },
    focus = {
        enabled = true,
        point = "CENTER",
        relPoint = "CENTER",
        x = -200,
        y = 100,
        width = 200,
        height = 20,
        fontSize = 12,
        showIcon = true,
        iconScale = 1.0,
        colors = CopyTable(DEFAULT_COLORS)
    },
    pet = {
        enabled = true,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = -180,
        width = 150,
        height = 15,
        fontSize = 10,
        showIcon = true,
        iconScale = 1.0,
        colors = CopyTable(DEFAULT_COLORS)
    },
    targettarget = {
        enabled = true,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 230,
        width = 150,
        height = 15,
        fontSize = 10,
        showIcon = true,
        iconScale = 1.0,
        colors = CopyTable(DEFAULT_COLORS)
    },
    focustarget = {
        enabled = true,
        point = "CENTER",
        relPoint = "CENTER",
        x = -200,
        y = 125,
        width = 150,
        height = 15,
        fontSize = 10,
        showIcon = true,
        iconScale = 1.0,
        colors = CopyTable(DEFAULT_COLORS)
    },
}

-- Add Boss Defaults Programmatically
for i = 1, 5 do
    ns.DEFAULTS["boss" .. i] = {
        enabled = true,
        point = "TOP",
        relPoint = "BOTTOM",
        x = 0,
        y = -10,
        width = 180,
        height = 20,
        fontSize = 10,
        showIcon = true,
        iconScale = 1.0,
        colors = CopyTable(DEFAULT_COLORS)
    }
end

-- ... (skipping to PLAYER_LOGIN migration safely) ...



-- ----------------------------------------------------------------------------
-- 2. Taint-Safe Blizzard Frame Hiding
-- ----------------------------------------------------------------------------
function ns.UpdateBlizzardVisibility()
    local db = RoithiUI.db.profile.Castbar
    if not db then return end

    -- Helper to hide/show
    local function ToggleBlizzBar(frame, shouldHide)
        if not frame then return end

        if shouldHide then
            -- Hide visually but keep events running to avoid Taint/Restoration issues
            -- (UnregisterAllEvents is too destructive and hard to reverse correctly)
            frame:SetAlpha(0)
            if frame.EnableMouse then frame:EnableMouse(false) end
            frame:Hide()

            -- Hook OnShow to force hide?
            -- No, SetAlpha(0) allows standard code to run without visible artifacts.
            -- But standard code might SetAlpha(1).
            -- Let's try explicit Unregister if Safe, but user reported failure.
            -- We'll try SetParent(Hidden) approach if possible, but SetAlpha is safest for 12.0.1

            -- Actually, if we just Unregister "OnEvent", that stops it?
            -- Let's try Unregister for key events only, and Re-Register them.
            -- Events: UNIT_SPELLCAST_START, STOP, CHANNEL_START, STOP, DELAYED, INTERRUPTED
            -- But there are many.

            -- COMPROMISE: We will just Hide it and Hook Show.
            if not frame.RoithiHooked then
                hooksecurefunc(frame, "Show", function(self)
                    if self.shouldBeHiddenRoithi then
                        self:Hide()
                    end
                end)
                frame.RoithiHooked = true
            end
            frame.shouldBeHiddenRoithi = true
            frame:Hide()
        else
            frame.shouldBeHiddenRoithi = false
            -- If it was hidden, let it be shown by game engine when needed.
            frame:SetAlpha(1)
            if frame.EnableMouse then frame:EnableMouse(true) end

            -- FIX: Restoration if currently casting
            -- We assume frame unit based on frame name or similar?
            -- frame.unit usually exists on CastBars
            local u = frame.unit or (frame.GetUnit and frame:GetUnit()) or "player"
            -- PlayerCastingBarFrame doesn't have .unit usually? It watches 'player'.
            if frame == PlayerCastingBarFrame or frame == PlayerFrame.Spellbar then u = "player" end

            if u and (UnitCastingInfo(u) or UnitChannelInfo(u)) then
                frame:Show()
            end
        end
    end

    -- Target
    -- Check both legacy global and new key
    local targetBar = TargetFrame.spellbar or TargetFrameSpellBar
    if targetBar then
        ToggleBlizzBar(targetBar, db.target and db.target.enabled)
    end

    -- Focus
    local focusBar = FocusFrame.spellbar or FocusFrameSpellBar
    if focusBar then
        ToggleBlizzBar(focusBar, db.focus and db.focus.enabled)
    end

    -- Player
    local playerBar = PlayerFrame.Spellbar or PlayerCastingBarFrame
    if playerBar then
        ToggleBlizzBar(playerBar, db.player and db.player.enabled)
    end
end

-- ----------------------------------------------------------------------------
-- 3. Main Event Handler
-- ----------------------------------------------------------------------------
---@class Castbar : AceAddon, AceModule
local Castbar = RoithiUI:NewModule("Castbar")
local MidnightCastbarsDB -- Local reference to RoithiUIDB.Castbar

function Castbar:OnInitialize()
    -- Initialize DB reference
    -- RoithiUI.db should handle defaults via AceDB.
    -- But we might need to verify if "Castbar" key exists if usage was unstructured before.
    if not RoithiUI.db.profile.Castbar then RoithiUI.db.profile.Castbar = {} end
    MidnightCastbarsDB = RoithiUI.db.profile.Castbar

    -- Apply Defaults
    for unit, defaultCfg in pairs(ns.DEFAULTS) do
        if not MidnightCastbarsDB[unit] then
            MidnightCastbarsDB[unit] = defaultCfg
        else
            -- Merge new defaults if missing
            for k, v in pairs(defaultCfg) do
                if MidnightCastbarsDB[unit][k] == nil then
                    MidnightCastbarsDB[unit][k] = v
                end
            end
            if not MidnightCastbarsDB[unit].colors then
                MidnightCastbarsDB[unit].colors = defaultCfg.colors
            else
                for cKey, cVal in pairs(defaultCfg.colors) do
                    if not MidnightCastbarsDB[unit].colors[cKey] then
                        MidnightCastbarsDB[unit].colors[cKey] = cVal
                    end
                end
            end
            if MidnightCastbarsDB[unit].enabled == nil then MidnightCastbarsDB[unit].enabled = true end
            if not MidnightCastbarsDB[unit].fontSize then MidnightCastbarsDB[unit].fontSize = 12 end
            MidnightCastbarsDB[unit].scale = nil -- Remove legacy scale
        end
    end

    -- Force Color Reset for v4
    if not MidnightCastbarsDB.colors_v4 then
        for unit, _ in pairs(ns.DEFAULTS) do
            if MidnightCastbarsDB[unit] then
                if not MidnightCastbarsDB[unit].colors then MidnightCastbarsDB[unit].colors = {} end
                for k, v in pairs(DEFAULT_COLORS) do
                    MidnightCastbarsDB[unit].colors[k] = { v[1], v[2], v[3], v[4] }
                end
            end
        end
        MidnightCastbarsDB.colors_v4 = true
    end
end

function Castbar:OnEnable()
    MidnightCastbarsDB = RoithiUI.db.profile.Castbar -- Ensure defined

    ns.UpdateBlizzardVisibility()
    ns.InitializeBars()          -- Defined in Castbar.lua
    ns.InitializeCastbarConfig() -- Defined in Config/Castbars.lua

    -- Register Cast Events
    local f = CreateFrame("Frame") -- or use module? Module doesn't have event mixins by default in my Init.lua
    -- I'll use a local frame or if RoithiUI had AceEvent-3.0...
    -- My Init.lua was simple. I'll stick to a frame.

    f:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            ns.UpdateCast(ns.bars["target"])
            ns.UpdateCast(ns.bars["targettarget"])
        elseif event == "PLAYER_FOCUS_CHANGED" then
            ns.UpdateCast(ns.bars["focus"])
            ns.UpdateCast(ns.bars["focustarget"])
        elseif event == "UNIT_TARGET" then
            local unit = ...
            if unit == "target" then
                ns.UpdateCast(ns.bars["targettarget"])
            elseif unit == "focus" then
                ns.UpdateCast(ns.bars["focustarget"])
            end
        elseif event == "UNIT_PET" then
            ns.UpdateCast(ns.bars["pet"])
        else
            local unit = ...
            if ns.bars[unit] then
                if event == "UNIT_SPELLCAST_INTERRUPTED" then
                    ns.HandleInterrupt(ns.bars[unit])
                elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
                    if not ns.bars[unit].isInterrupted and not ns.bars[unit].isInEditMode then
                        ns.bars[unit]:Hide(); ns.bars[unit]:SetScript("OnUpdate", nil)
                    end
                else
                    ns.UpdateCast(ns.bars[unit])
                end
            end
        end
    end)

    f:RegisterEvent("UNIT_SPELLCAST_START")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    f:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    f:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
    f:RegisterEvent("UNIT_SPELLCAST_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_FOCUS_CHANGED")
    -- Events are registered above
end

-- Slash Command
SLASH_MIDNIGHTCB1 = "/mcb"
SlashCmdList["MIDNIGHTCB"] = function(msg)
    if EditModeManagerFrame then
        if not EditModeManagerFrame:IsVisible() then
            ShowUIPanel(EditModeManagerFrame)
        else
            HideUIPanel(EditModeManagerFrame)
        end
    else
        print("MidnightCastbars: Edit Mode not available.")
    end
end

-- ----------------------------------------------------------------------------
-- 4. Attachment Logic
-- ----------------------------------------------------------------------------
function ns.SetCastbarAttachment(unit, attached)
    local bar = ns.bars[unit]
    if not bar then return end

    local db = RoithiUI.db.profile.Castbar[unit]

    local UF = RoithiUI:GetModule("UnitFrames")
    local uFrame = UF and UF.units and UF.units[unit]

    -- Special Case for Boss Frames: Snap to specific boss frame
    if string.find(unit, "boss") then
        uFrame = UF and UF.units and UF.units[unit]
    end

    if attached and uFrame then
        -- SMART ATTACHMENT LOGIC
        -- Priority: AdditionalPower > ClassPower > Power > Frame
        -- BUT only if they are NOT DETACHED.
        local anchor = uFrame

        -- Access UnitFrame DB safely to check for detachment
        local ufDB = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]

        -- Default to attached if no DB entry (safe fallback)
        local powerDetached = ufDB and ufDB.powerDetached
        local classPowerDetached = ufDB and ufDB.classPowerDetached
        local additionalPowerDetached = ufDB and ufDB.additionalPowerDetached

        if uFrame.Power and uFrame.Power:IsShown() and not powerDetached then
            anchor = uFrame.Power
        end

        if uFrame.ClassPower and uFrame.ClassPower:IsShown() and not classPowerDetached then
            -- Assumes ClassPower is visually below Power.
            -- If ClassPower is present but Power is detached, does ClassPower move up?
            -- Typically yes, in standard layouts.
            anchor = uFrame.ClassPower
        end

        if uFrame.AdditionalPower and uFrame.AdditionalPower:IsShown() and not additionalPowerDetached then
            -- Assumes AdditionalPower is visually below ClassPower/Power.
            anchor = uFrame.AdditionalPower
        end

        bar:SetParent(uFrame)
        bar:ClearAllPoints()
        -- Offset logic: Use db.x / db.y as offset from the smart anchor
        -- Check if db.x is reasonable offset (usually huge if formerly detached).
        -- If attached, we might want to ignore large saved coordinates or clamp them?
        -- Let's just use 0, -5 hardcoded + db.x/y if user wants fine tuning?
        -- The user asked for X/Y sliders. If attached, they act as offsets.
        local offX = db.x or 0
        local offY = (db.y or 0) - 5

        -- FIX: Visual Centering with Icon
        -- If icon is shown, the bar width is reduced, but centering the BAR makes the ICON overhang left.
        -- We shift RIGHT by half the icon width to center the whole (Icon + Bar) group.
        if db.showIcon then
            local iconSize = (db.height or 20) * (db.iconScale or 1.0)
            offX = offX + (iconSize / 2)
        end

        bar:SetPoint("TOP", anchor, "BOTTOM", offX, offY)
    else
        bar:SetParent(UIParent)
        -- Restore position from DB
        -- If db.x/y were used as offsets while attached, they might be small.
        -- If detaching, we probably want to keep them or restore absolute?
        -- For now, we trust the DB.
        local point = db.point or "CENTER"
        bar:ClearAllPoints()
        bar:SetPoint(point, UIParent, point, db.x or 0, db.y or 0)
    end
end
