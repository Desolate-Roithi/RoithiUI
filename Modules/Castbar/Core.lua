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

-- ... (skipping to PLAYER_LOGIN migration safely) ...



-- ----------------------------------------------------------------------------
-- 2. Taint-Safe Blizzard Frame Hiding
-- ----------------------------------------------------------------------------
function ns.UpdateBlizzardVisibility()
    if not MidnightCastbarsDB then return end

    -- Target
    if TargetFrameSpellBar then
        if MidnightCastbarsDB.target and MidnightCastbarsDB.target.enabled then
            TargetFrameSpellBar:UnregisterAllEvents()
            TargetFrameSpellBar:Hide()
            TargetFrameSpellBar:SetAlpha(0)
        else
            TargetFrameSpellBar:SetAlpha(1)
            TargetFrameSpellBar:RegisterEvent("PLAYER_TARGET_CHANGED")
            TargetFrameSpellBar:RegisterEvent("CVAR_UPDATE")
            TargetFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_START", "target")
            TargetFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "target")
            TargetFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target")
            TargetFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target")
            TargetFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "target")
            TargetFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "target")
            TargetFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "target")
            TargetFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
            -- Force update if we just enabled it back
            if UnitExists("target") then TargetFrameSpellBar:Show() end
        end
    end

    -- Focus
    if FocusFrameSpellBar then
        if MidnightCastbarsDB.focus and MidnightCastbarsDB.focus.enabled then
            FocusFrameSpellBar:UnregisterAllEvents()
            FocusFrameSpellBar:Hide()
            FocusFrameSpellBar:SetAlpha(0)
        else
            FocusFrameSpellBar:SetAlpha(1)
            FocusFrameSpellBar:RegisterEvent("PLAYER_FOCUS_CHANGED")
            FocusFrameSpellBar:RegisterEvent("CVAR_UPDATE")
            FocusFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus")
            FocusFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "focus")
            FocusFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "focus")
            FocusFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "focus")
            FocusFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "focus")
            FocusFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "focus")
            FocusFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "focus")
            FocusFrameSpellBar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "focus")
            if UnitExists("focus") then FocusFrameSpellBar:Show() end
        end
    end

    -- Player
    if PlayerCastingBarFrame then
        if MidnightCastbarsDB.player and MidnightCastbarsDB.player.enabled then
            PlayerCastingBarFrame:UnregisterAllEvents()
            PlayerCastingBarFrame:Hide()
            PlayerCastingBarFrame:SetAlpha(0)
        else
            PlayerCastingBarFrame:SetAlpha(1)
            PlayerCastingBarFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            PlayerCastingBarFrame:RegisterEvent("CVAR_UPDATE")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
            PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
        end
    end
end

-- ----------------------------------------------------------------------------
-- 3. Main Event Handler
-- ----------------------------------------------------------------------------
local Castbar = RoithiUI:NewModule("Castbar")
local MidnightCastbarsDB -- Local reference to RoithiUIDB.Castbar

function Castbar:OnInitialize()
    -- Initialize DB reference
    if not RoithiUIDB.Castbar then RoithiUIDB.Castbar = {} end
    MidnightCastbarsDB = RoithiUIDB.Castbar

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
    MidnightCastbarsDB = RoithiUIDB.Castbar -- Ensure defined

    ns.UpdateBlizzardVisibility()
    ns.InitializeBars()   -- Defined in Castbar.lua
    ns.InitializeConfig() -- Defined in Config.lua

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
