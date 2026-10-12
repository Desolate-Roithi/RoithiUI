local addonName, ns = ...
if ns.skipLoad then return end
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
    interruptOnCD = { 0.9, 0.5, 0.1, 1 }, -- E6801A (Amber-Orange)
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
        colorOnInterruptCD = false,
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
        detached = true,
        colorOnInterruptCD = false,
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
        colorOnInterruptCD = false,
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
        colorOnInterruptCD = false,
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
        colorOnInterruptCD = false,
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
        colorOnInterruptCD = false,
        detached = false,
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
local BLIZZ_CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

function ns.UpdateBlizzardVisibility()
    if InCombatLockdown and InCombatLockdown() then
        if not ns.pendingBlizzVisibilityUpdate then
            ns.pendingBlizzVisibilityUpdate = true
            local regenFrame = CreateFrame("Frame")
            regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            regenFrame:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                ns.pendingBlizzVisibilityUpdate = false
                ns.UpdateBlizzardVisibility()
            end)
        end
        return
    end

    local db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Castbar
    if not db then return end

    -- Helper to hide/show
    local function ToggleBlizzBar(frame, unit, shouldHide)
        if not frame then return end

        if shouldHide then
            frame.shouldBeHiddenRoithi = true
            if frame.UnregisterAllEvents then
                frame:UnregisterAllEvents()
            end
            frame:SetAlpha(0)
            if frame.EnableMouse then frame:EnableMouse(false) end
            frame:Hide()
        else
            frame.shouldBeHiddenRoithi = false
            frame:SetAlpha(1)
            if frame.EnableMouse then frame:EnableMouse(true) end
            if unit and frame.RegisterUnitEvent and not (frame.IsEventRegistered and frame:IsEventRegistered("UNIT_SPELLCAST_START")) then
                for _, event in ipairs(BLIZZ_CAST_EVENTS) do
                    pcall(frame.RegisterUnitEvent, frame, event, unit)
                end
                if frame.RegisterEvent then
                    pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
                    if unit == "pet" then
                        pcall(frame.RegisterEvent, frame, "UNIT_PET")
                    end
                end
            end
            frame:Show()
        end
    end

    -- Target
    local targetBar = (TargetFrame and TargetFrame.spellbar) or _G.TargetFrameSpellBar
    if targetBar then
        ToggleBlizzBar(targetBar, "target", db.target and db.target.enabled)
    end

    -- Focus
    local focusBar = (FocusFrame and FocusFrame.spellbar) or _G.FocusFrameSpellBar
    if focusBar then
        ToggleBlizzBar(focusBar, "focus", db.focus and db.focus.enabled)
    end

    -- Player
    local playerBar = (PlayerFrame and PlayerFrame.Spellbar) or _G.PlayerCastingBarFrame
    if playerBar then
        ToggleBlizzBar(playerBar, "player", db.player and db.player.enabled)
    end
    if _G.PlayerCastingBarFrame and _G.PlayerCastingBarFrame ~= playerBar then
        ToggleBlizzBar(_G.PlayerCastingBarFrame, "player", db.player and db.player.enabled)
    end

    -- Pet / Vehicle
    if _G.PetCastingBarFrame then
        ToggleBlizzBar(_G.PetCastingBarFrame, "pet", db.pet and db.pet.enabled)
    end
    if PetFrame and PetFrame.Spellbar and PetFrame.Spellbar ~= _G.PetCastingBarFrame then
        ToggleBlizzBar(PetFrame.Spellbar, "pet", db.pet and db.pet.enabled)
    end
end

-- ----------------------------------------------------------------------------
-- 3. Main Event Handler
-- ----------------------------------------------------------------------------
---@class Castbar : AceAddon, AceModule
local Castbar = RoithiUI:NewModule("Castbar")
Castbar.bars = ns.bars   -- Expose for AttachmentLogic
Castbar.defaultSettings = ns.CastbarDefaults or (ns.Defaults and ns.Defaults.profile and ns.Defaults.profile.Castbar)
Castbar.dbKey = "Castbar"
local castbarsDB

function Castbar:OnInitialize()
    -- Initialize DB reference
    -- RoithiUI.db should handle defaults via AceDB.
    -- But we might need to verify if "Castbar" key exists if usage was unstructured before.
    if not RoithiUI.db.profile.Castbar then RoithiUI.db.profile.Castbar = {} end
    castbarsDB = RoithiUI.db.profile.Castbar

    -- Apply Defaults
    for unit, defaultCfg in pairs(ns.DEFAULTS) do
        if not castbarsDB[unit] then
            castbarsDB[unit] = defaultCfg
        else
            -- Merge new defaults if missing
            for k, v in pairs(defaultCfg) do
                if castbarsDB[unit][k] == nil then
                    castbarsDB[unit][k] = v
                end
            end
            if not castbarsDB[unit].colors then
                castbarsDB[unit].colors = defaultCfg.colors
            else
                for cKey, cVal in pairs(defaultCfg.colors) do
                    if not castbarsDB[unit].colors[cKey] then
                        castbarsDB[unit].colors[cKey] = cVal
                    end
                end
            end
            if castbarsDB[unit].enabled == nil then castbarsDB[unit].enabled = true end
            if not castbarsDB[unit].fontSize then castbarsDB[unit].fontSize = 12 end
            castbarsDB[unit].scale = nil -- Remove legacy scale
        end
    end

    -- Force Color Reset for v4
    if not castbarsDB.colors_v4 then
        for unit, _ in pairs(ns.DEFAULTS) do
            if castbarsDB[unit] then
                if not castbarsDB[unit].colors then castbarsDB[unit].colors = {} end
                for k, v in pairs(DEFAULT_COLORS) do
                    castbarsDB[unit].colors[k] = { v[1], v[2], v[3], v[4] }
                end
            end
        end
        castbarsDB.colors_v4 = true
    end
end

local CAST_UNIT_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTED",
}

function ns.RegisterBarUnitEvents(bar)
    if not bar or not bar.unit or not bar.RegisterUnitEvent then return end
    for _, ev in ipairs(CAST_UNIT_EVENTS) do
        bar:RegisterUnitEvent(ev, bar.unit)
    end
    bar:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_SPELLCAST_INTERRUPTED" then
            ns.HandleInterrupt(self)
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            local _, castGUID = ...
            local isSecretID = (issecretvalue and (issecretvalue(self.castID) or issecretvalue(castGUID))) or (canaccessvalue and (not canaccessvalue(self.castID) or not canaccessvalue(castGUID)))
            if not isSecretID and self.castID and castGUID and self.castID ~= castGUID then
                return
            end
            if not self.isInterrupted and not self.isInEditMode then
                self.casting = false
                self.channeling = false
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        else
            ns.UpdateCast(self, self.unit)
        end
    end)
end

function Castbar:OnEnable()
    castbarsDB = RoithiUI.db.profile.Castbar -- Ensure defined

    ns.UpdateBlizzardVisibility()
    ns.InitializeBars()          -- Defined in Castbar.lua
    if ns.InitializeCastbarConfig then
        ns.InitializeCastbarConfig()
    end
    if ns.RefreshAllCastbars then
        ns.RefreshAllCastbars()
    end

    -- Register Cast Events
    self.eventFrame = CreateFrame("Frame")
    local f = self.eventFrame
    -- Registered via self.eventFrame to avoid GC and allow external access/teardown

    f:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            if ns.bars and ns.bars["target"] and not (InCombatLockdown and InCombatLockdown()) then
                local cbDB = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["target"]
                if cbDB and not cbDB.detached and ns.SetCastbarAttachment then
                    ns.SetCastbarAttachment("target", true)
                end
            end
            ns.UpdateCast(ns.bars["target"])
            ns.UpdateCast(ns.bars["targettarget"])
        elseif event == "PLAYER_FOCUS_CHANGED" then
            if ns.bars and ns.bars["focus"] then
                if not (InCombatLockdown and InCombatLockdown()) then
                    local cbDB = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar["focus"]
                    if cbDB and not cbDB.detached and ns.SetCastbarAttachment then
                        ns.SetCastbarAttachment("focus", true)
                    end
                end
                ns.UpdateCast(ns.bars["focus"], "focus")
            end
            if ns.bars and ns.bars["focustarget"] then
                ns.UpdateCast(ns.bars["focustarget"], "focustarget")
            end
        elseif event == "UNIT_TARGET" then
            local unit = ...
            if unit == "target" then
                ns.UpdateCast(ns.bars["targettarget"])
            elseif unit == "focus" then
                ns.UpdateCast(ns.bars["focustarget"])
            end
        elseif event == "UNIT_PET" then
            ns.UpdateCast(ns.bars["pet"])
            -- Sync attachment on pet change
            local cbDB = RoithiUI.db.profile.Castbar["pet"]
            local isDetached = cbDB and cbDB.detached
            ns.SetCastbarAttachment("pet", not isDetached)
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            if ns.bars then
                for u, bar in pairs(ns.bars) do
                    if u ~= "player" and bar:IsShown() and (bar.casting or bar.channeling) then
                        ns.UpdateCast(bar, u)
                    end
                end
            end
        elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            if ns.UpdatePlayerInterruptSpell then
                ns.UpdatePlayerInterruptSpell()
            end
            if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
                if ns.RefreshAllCastbars then
                    ns.RefreshAllCastbars()
                end
            end
        else
            local unit = ...
            local targetBar = ns.bars[unit]
            
            -- Vehicle Aliasing: Map vehicle/pet casts to player bar if needed
            if unit == "vehicle" then
                targetBar = ns.bars["player"]
            end

            if targetBar then
                if event == "UNIT_SPELLCAST_INTERRUPTED" then
                    ns.HandleInterrupt(targetBar)
                elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
                    local _, castGUID = ...
                    local isSecretID = (issecretvalue and (issecretvalue(targetBar.castID) or issecretvalue(castGUID))) or (canaccessvalue and (not canaccessvalue(targetBar.castID) or not canaccessvalue(castGUID)))
                    if not isSecretID and targetBar.castID and castGUID and targetBar.castID ~= castGUID then
                        return
                    end
                    if not targetBar.isInterrupted and not targetBar.isInEditMode then
                        targetBar.casting = false
                        targetBar.channeling = false
                        targetBar:Hide(); targetBar:SetScript("OnUpdate", nil)
                    end
                else
                    ns.UpdateCast(targetBar, unit)
                end
            end
        end
    end)

    f:RegisterEvent("UNIT_SPELLCAST_START")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    f:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    f:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    f:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    f:RegisterEvent("UNIT_SPELLCAST_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_FOCUS_CHANGED")
    f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    f:RegisterEvent("SPELLS_CHANGED")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- Events are registered above
end

-- Slash Command
if RoithiUI and RoithiUI.RegisterChatCommand then
    RoithiUI:RegisterChatCommand("mcb", function(_)
        if EditModeManagerFrame then
            if not EditModeManagerFrame:IsVisible() then
                ShowUIPanel(EditModeManagerFrame)
            else
                HideUIPanel(EditModeManagerFrame)
            end
        else
            RoithiUI:Log("MidnightCastbars: Edit Mode not available.")
        end
    end)
end

-- ----------------------------------------------------------------------------
-- 4. Attachment Logic
-- ----------------------------------------------------------------------------
function ns.SetCastbarAttachment(unit, attached)
    local bar = ns.bars and ns.bars[unit]
    if not bar then return end

    local db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[unit]
    if not db then return end

    if attached ~= nil then
        db.detached = not attached
    end

    local AL = ns.AttachmentLogic
    if AL then
        AL:ApplyLayout(unit, "Castbar")
    else
        if bar.ClearAllPoints then bar:ClearAllPoints() end
        if bar.SetParent and UIParent then bar:SetParent(UIParent) end
        if bar.SetPoint and UIParent then bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    end
end
