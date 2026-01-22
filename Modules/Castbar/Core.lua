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
            frame:UnregisterAllEvents()
            frame:Hide()
            frame:SetAlpha(0)
            -- Hook Show to keep hidden?
            -- Better to just ensure events are gone.
        else
            frame:SetAlpha(1)
            -- Re-register events if we know them, or reload UI hint?
            -- Blizzard code usually registers these on load or via Mixins.
            -- Modern frames use Mixins. We might need to call OnLoad or re-register specific events.
            -- For now, we restore Alpha and let the user reload if needed,
            -- OR we try to re-hook events.
            -- Re-registering all events manually is brittle.
            -- A reload is safer for "Show" but we can try basic ones.
            if frame.unit then
                frame:RegisterUnitEvent("UNIT_SPELLCAST_START", frame.unit)
                frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", frame.unit)
                frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", frame.unit)
                frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", frame.unit)
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
