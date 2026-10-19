local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Globals for luacheck
local IsEncounterInProgress = _G.IsEncounterInProgress
local issecretvalue = _G.issecretvalue

local EB = RoithiUI:NewModule("EncounterBar", "AceEvent-3.0", "AceConsole-3.0")
EB.dbKey = "EncounterResource"
EB.defaultSettings = ns.EncounterBarDefaults or (ns.Defaults and ns.Defaults.profile and ns.Defaults.profile.EncounterResource)

-- Blizzard source constant: ALTERNATE_POWER_INDEX = 10
-- Do NOT use Enum.PowerType.Alternate — it does not exist in 12.0.1.
local ALTERNATE_POWER_INDEX = 10

-- ─────────────────────────────────────────────────────────────────────────────
local WHITELISTED_TITLES = {
    ["Abyss Diver"] = true,
    ["Oxygen"] = true,
}

local WHITELISTED_IDS = {
    [4604] = true, -- Abyss Angling Oxygen Bar (Active)
}

local WIDGET_BLACKLIST = {
    [7372] = true, -- Hidden Encounter Timer / Abyss Background Widget
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Blizzard PlayerPowerBarAlt toggle helper
-- Suppresses the native bar while our custom one is active.
-- ─────────────────────────────────────────────────────────────────────────────
local showHooked = false

local function ToggleBlizzard(enableCustom)
    if not PlayerPowerBarAlt then return end

    if enableCustom then
        PlayerPowerBarAlt:UnregisterEvent("UNIT_POWER_BAR_SHOW")
        PlayerPowerBarAlt:UnregisterEvent("UNIT_POWER_BAR_HIDE")
        PlayerPowerBarAlt:UnregisterEvent("PLAYER_ENTERING_WORLD")
        PlayerPowerBarAlt:Hide()

        -- Prevent re-showing via hook without mutating Blizzard frame table
        if not showHooked then
            showHooked = true
            hooksecurefunc(PlayerPowerBarAlt, "Show", function(self)
                local db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.EncounterResource
                if db and db.enabled then
                    self:Hide()
                end
            end)
        end
    else
        -- Restore Blizzard bar events natively without tainting execution context
        PlayerPowerBarAlt:RegisterEvent("UNIT_POWER_BAR_SHOW")
        PlayerPowerBarAlt:RegisterEvent("UNIT_POWER_BAR_HIDE")
        PlayerPowerBarAlt:RegisterEvent("PLAYER_ENTERING_WORLD")

        if UIWidgetPowerBarContainerFrame then
            UIWidgetPowerBarContainerFrame:Show()
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Toggle Function (External Access)
-- ─────────────────────────────────────────────────────────────────────────────
function EB:Toggle(enabled)
    if not RoithiUI.db.profile.EncounterResource then
        RoithiUI.db.profile.EncounterResource = CopyTable(self.defaultSettings)
    end

    local db = RoithiUI.db.profile.EncounterResource
    db.enabled = enabled

    local encounterBar = _G.RoithiEncounterResource

    if enabled then
        ToggleBlizzard(true)
        if encounterBar then
            encounterBar:RegisterEvent("PLAYER_ENTERING_WORLD")
            encounterBar:RegisterEvent("ZONE_CHANGED_NEW_AREA")
            encounterBar:RegisterEvent("ZONE_CHANGED")
            encounterBar:RegisterEvent("PLAYER_DEAD")
            encounterBar:RegisterEvent("PLAYER_ALIVE")
            encounterBar:RegisterEvent("UPDATE_ALL_UI_WIDGETS")
            encounterBar:RegisterEvent("UPDATE_UI_WIDGET")
            encounterBar:RegisterUnitEvent("UNIT_POWER_BAR_SHOW", "player")
            encounterBar:RegisterUnitEvent("UNIT_POWER_BAR_HIDE", "player")
            encounterBar:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            encounterBar:RegisterUnitEvent("UNIT_MAXPOWER", "player")
            if encounterBar.Update then encounterBar:Update() end
        end
    else
        ToggleBlizzard(false)
        if encounterBar then
            encounterBar:UnregisterAllEvents()
            encounterBar:Hide()
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UIWidget power bar path
-- Handles 12.0.5+ world encounter bars (e.g. Oxygen for Abyss Angling).
-- These are NOT delivered via PlayerPowerBarAlt / UnitPowerBarID.
-- ─────────────────────────────────────────────────────────────────────────────

-- Drive widget scan when entering world or full refresh requested.
-- The UIWidget path will be re-driven when individual widgets update via UPDATE_UI_WIDGET.

local function UpdateFromWidget(s, widgetInfo)
    if not widgetInfo then return end

    -- Prevent blacklisted widgets from showing
    if WIDGET_BLACKLIST[widgetInfo.widgetID] then return end

    -- Prioritization: If we are already tracking the active Oxygen bar (4604),
    -- don't let static background widgets (like 7372) overwrite it.
    if s.hasWidgetID == 4604 and widgetInfo.widgetID ~= 4604 then
        return
    end

    local db = RoithiUI.db.profile.EncounterResource
    local widgetDebug = db and db.widgetDebug
    if widgetDebug then
        print("|cff00ccff[EB Debug]|r [UpdateFromWidget] ID: " ..
            tostring(widgetInfo.widgetID) .. " Type: " .. tostring(widgetInfo.widgetType))
    end

    local info
    if widgetInfo.widgetType == Enum.UIWidgetVisualizationType.UnitPowerBar or widgetInfo.widgetType == 23 then
        info = C_UIWidgetManager.GetUnitPowerBarWidgetVisualizationInfo(widgetInfo.widgetID)
    elseif widgetInfo.widgetType == Enum.UIWidgetVisualizationType.StatusBar or widgetInfo.widgetType == 2 then
        info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetInfo.widgetID)
    elseif widgetInfo.widgetType == 24 then -- FillUpFrames (Oxygen/Vigor)
        info = C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(widgetInfo.widgetID)
    end

    -- Fallback for whitelisted IDs if type-specific call failed
    if not info and WHITELISTED_IDS[widgetInfo.widgetID] then
        info = C_UIWidgetManager.GetUnitPowerBarWidgetVisualizationInfo(widgetInfo.widgetID)
            or C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetInfo.widgetID)
            or C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(widgetInfo.widgetID)
    end

    -- 1. Identify Whitelist Status
    local nameText = info and (info.barLabel or info.text) or ""
    local isWhitelisted = WHITELISTED_IDS[widgetInfo.widgetID] or
    (db and db.whitelist and db.whitelist[widgetInfo.widgetID])
    local isTitleWhitelisted = WHITELISTED_TITLES[nameText]

    if widgetDebug then
        if not info then
            print("|cff00ccff[EB Debug]|r [UpdateFromWidget] FAILED to get info for ID: " ..
            tostring(widgetInfo.widgetID))
        else
            print(string.format(
                "|cff00ccff[EB Debug]|r [UpdateFromWidget] ID: %d shownState: %d Title: '%s' Whitelisted: %s",
                widgetInfo.widgetID, info.shownState or -1, nameText, tostring(isWhitelisted or isTitleWhitelisted)))
        end
    end


    -- 2. Calculate values (min, max, val)
    local min, max, val = 0, 0, 0
    if info then
        if widgetInfo.widgetType == 24 and info.numTotalFrames then
            local unitMax = (info.fillMax and info.fillMax > 0) and info.fillMax or 1
            max = info.numTotalFrames or 1
            val = (info.numFullFrames or 0) + (info.fillValue or 0) / unitMax

            -- Raw value mode detection (e.g. Oxygen timer)
            if (info.numFullFrames or 0) > (info.numTotalFrames or 0) then
                max = (info.numTotalFrames or 1) * unitMax
            end
        else
            min = info.barMin or info.fillMin or 0
            max = info.barMax or info.fillMax or 0
            val = info.barValue or info.fillValue or 0
        end
    end

    -- Simplified Log Mode (only for bars)
    if db and db.widgetLogMode and not WIDGET_BLACKLIST[widgetInfo.widgetID] then
        if info and (widgetInfo.widgetType == 2 or widgetInfo.widgetType == 24 or widgetInfo.widgetType == 23) then
            print(string.format("|cff00ccff[EB Log]|r ID: %d | Set: %d | Title: '%s' | Val: %s / %s (Min: %s)",
                widgetInfo.widgetID, widgetInfo.widgetSetID or -1, nameText or "None", tostring(val), tostring(max),
                tostring(min)))
        end
    end

    -- 3. Handle Visibility
    local isHidden = not info or (info.shownState == Enum.WidgetShownState.Hidden)
    if isHidden then
        -- Whitelisted widgets (like Oxygen ID 4604) sometimes report Hidden (0) while active.
        -- However, Blizzard fires UNIT_POWER_BAR_HIDE when the event is truly over.
        -- We check if we recently got a hide signal to avoid re-showing a stale widget.
        local timeSinceHide = GetTime() - (s.lastHideTime or 0)
        local isRecentHide = timeSinceHide < 2.0 -- 2 second grace period for stale widget events

        local shouldBypassHide = (isWhitelisted or isTitleWhitelisted) and info and max > 0 and not isRecentHide
        if not shouldBypassHide then
            if not UnitPowerBarID("player") then
                s.hasWidgetID = nil
                s:Hide()
            end
            return
        end
    end

    -- 4. Opt-in logic for Widgets outside of Boss Encounters
    if not IsEncounterInProgress() and not s.isInEditMode then
        if not isWhitelisted and not isTitleWhitelisted then
            s.hasWidgetID = nil
            s:Hide()
            return
        end
    end

    if db and db.widgetDebug then
        print(string.format("|cff00ccff[EB Debug]|r [UpdateFromWidget] ID: %d Max: %s Val: %s",
            widgetInfo.widgetID, tostring(max), tostring(val)))
    end

    if widgetInfo.widgetID == 4604 then
        nameText = "Oxygen"
        -- Workaround: Capture the first seen value as the Max so it starts at 100%
        if not s.oxygenMax or s.oxygenMax == 0 then
            s.oxygenMax = val
        end
        if s.oxygenMax and s.oxygenMax > 0 then
            max = s.oxygenMax
        end
    end

    s:SetMinMaxValues(min or 0, max or 100)
    s:SetValue(val or 0)

    -- Set standard color (Light Blue) for all widgets to ensure readability
    s:SetStatusBarColor(0, 0.6, 1)
    s.hasWidgetColor = true

    local pct = (max and max > 0) and (val / max * 100) or 0
    s.Text:SetText(string.format("%s: %.0f%%", nameText, pct))

    s.hasWidgetID = widgetInfo.widgetID -- Track current source
    s.hasWidgetType = widgetInfo.widgetType
    s:Show()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Core Update — PlayerPowerBarAlt path
-- ─────────────────────────────────────────────────────────────────────────────
local function Update(s)
    local db = RoithiUI.db.profile.EncounterResource
    if not db or not db.enabled then
        s:Hide()
        return
    end

    -- 1. Check Widgets first (if we are tracking one)
    if s.hasWidgetID then
        local info
        if s.hasWidgetType == Enum.UIWidgetVisualizationType.UnitPowerBar then
            info = C_UIWidgetManager.GetUnitPowerBarWidgetVisualizationInfo(s.hasWidgetID)
        elseif s.hasWidgetType == Enum.UIWidgetVisualizationType.StatusBar then
            info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(s.hasWidgetID)
        elseif s.hasWidgetType == 24 then
            info = C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(s.hasWidgetID)
        end

        if not info or (info.shownState == Enum.WidgetShownState.Hidden) then
            s.hasWidgetID = nil
            s.hasWidgetType = nil
            -- Fall through to check PlayerPowerBarAlt
        else
            local min, max, val
            if s.hasWidgetType == 24 and info.numTotalFrames then
                local unitMax = (info.fillMax and info.fillMax > 0) and info.fillMax or 1
                if (info.numFullFrames or 0) > (info.numTotalFrames or 0) then
                    val = (info.numFullFrames or 0) + (info.fillValue or 0) / unitMax
                    max = (info.numTotalFrames or 1) * unitMax
                    min = 0

                    local aura = C_UnitAuras.GetPlayerAuraBySpellID(1225598)
                    if aura and aura.duration and aura.duration > 0 then
                        max = aura.duration
                    end
                else
                    min = 0
                    max = info.numTotalFrames or 1
                    val = (info.numFullFrames or 0) + (info.fillValue or 0) / unitMax
                end
            else
                min = info.barMin or info.fillMin or 0
                max = info.barMax or info.fillMax or 100
                val = info.barValue or info.fillValue or 0
            end
            local pct = (max > 0) and (val / max * 100) or 0
            s:SetMinMaxValues(min, max)
            s:SetValue(val)

            -- Keep the text updated with percentage if it was set by widget
            if s.Text:GetText() and s.Text:GetText():find(":") then
                local prefix = s.Text:GetText():match("^(.-):")
                s.Text:SetText(string.format("%s: %.0f%%", prefix, pct))
            end
            return
        end
    end

    -- 2. Check Alternate Power
    local barID = UnitPowerBarID("player")

    if not barID or barID == 0 then
        s:Hide()
        return
    end

    local info = GetUnitPowerBarInfo("player")
    local nameText = info and (info.name or info.barLabel) or ""

    -- Unified Blacklist Check Removed (Now using Opt-in/Boss bypass)

    -- STRICT REQUIREMENT: Hide if no name exists (background mechanics)
    if (not nameText or nameText == "") and not s.isInEditMode then
        s:Hide()
        return
    end

    if not info or (not info.showBar and not s.isInEditMode) then
        s:Hide()
        return
    end

    if not info and s.isInEditMode then
        s:SetMinMaxValues(0, 100)
        s:SetValue(75)
        s:Show()
        s.Text:SetText("Encounter Bar")
        s:SetStatusBarColor(1, 0, 1)
        return
    end

    local ok1, current = pcall(UnitPower, "player", ALTERNATE_POWER_INDEX)
    if not ok1 then current = 0 end
    local ok2, max = pcall(UnitPowerMax, "player", ALTERNATE_POWER_INDEX)
    if not ok2 then max = 0 end

    local currentIsSecret = issecretvalue and issecretvalue(current)
    local maxIsSecret = issecretvalue and issecretvalue(max)
    local isSecret = currentIsSecret or maxIsSecret

    local hasPower = false
    if maxIsSecret then
        hasPower = true
    elseif type(max) == "number" and max > 0 then
        hasPower = true
    end

    if hasPower then
        s:SetMinMaxValues(0, max)
        s:SetValue(current)
        s:Show()

        local barName = nil
        if _G.GetUnitPowerBarStrings then
            local n1 = _G.GetUnitPowerBarStrings("player")
            local n2 = _G.GetUnitPowerBarStrings(barID)
            barName = n1 or n2
        end

        isSecret = isSecret or (issecretvalue and issecretvalue(current))
        local currentStr

        if isSecret and _G.UnitPowerPercent then
            local curve = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 0
            local success, pct = pcall(function()
                return _G.UnitPowerPercent("player", ALTERNATE_POWER_INDEX, false, curve)
            end)

            if success and pct then
                currentStr = string.format("%.0f%%", pct)
            else
                currentStr = "..."
            end
        else
            currentStr = LibRoithi.mixins:SafeFormat("%d / %d", current, max)
        end

        if barName and barName ~= "" then
            s.Text:SetText(barName .. ": " .. (currentStr or ""))
        else
            s.Text:SetText(currentStr or "")
        end
    else
        s:Hide()
    end

    -- Color: use bar-defined color, fall back to Deep Sky Blue
    -- Standard Color: Light Blue for all bars to ensure white text is readable
    s:SetStatusBarColor(0, 0.6, 1)

    -- Final Safety: If we have no data and no text, don't show an empty bar
    local currentText = s.Text:GetText()
    if (not currentText or currentText == "") then
        s:Hide()
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Smart OnEvent dispatcher
-- ─────────────────────────────────────────────────────────────────────────────
local function OnEvent(s, event, arg1, arg2)
    local db = RoithiUI.db.profile.EncounterResource
    local widgetDebug = db and db.widgetDebug
    if widgetDebug then
        print("|cff00ccff[EB Debug]|r [OnEvent] Fired: " .. tostring(event) .. " arg1: " .. tostring(arg1))
    end

    -- UNIT_POWER_BAR_HIDE → immediate hide
    if event == "UNIT_POWER_BAR_HIDE" then
        if arg1 == nil or arg1 == "player" then
            s.hasWidgetID = nil
            s.hasWidgetColor = false
            s.lastHideTime = GetTime()
            s.oxygenMax = nil
            s:Hide()
        end
        return
    end

    -- UNIT_POWER_UPDATE → only relevant for ALTERNATE power type
    if event == "UNIT_POWER_UPDATE" then
        if arg2 ~= "ALTERNATE" then return end
        Update(s)
        return
    end

    -- UNIT_MAXPOWER → only relevant for ALTERNATE power type
    if event == "UNIT_MAXPOWER" then
        if arg2 ~= "ALTERNATE" then return end
        Update(s)
        return
    end

    -- UPDATE_UI_WIDGET → UIWidget power bar path (oxygen bar, etc.)
    -- arg1 is the widgetInfo table: { widgetSetID, widgetID, widgetType, unit }
    if event == "UPDATE_UI_WIDGET" then
        if widgetDebug then
            print(string.format("|cff00ccff[EB Debug]|r [OnEvent] UPDATE_UI_WIDGET fired | ID: %s | SetID: %s",
                tostring(arg1 and arg1.widgetID), tostring(arg1 and arg1.widgetSetID)))
        end
        UpdateFromWidget(s, arg1)
        return
    end

    if event == "UPDATE_ALL_UI_WIDGETS" or event == "PLAYER_ENTERING_WORLD" or event:find("ZONE_CHANGED") or event:find("PLAYER_") then
        s.hasWidgetID = nil
        s.hasWidgetColor = false
        s.oxygenMax = nil
        Update(s)
        -- Individual widget updates will fire UPDATE_UI_WIDGET separately
        return
    end

    -- UNIT_POWER_BAR_SHOW, fallthrough → full update
    Update(s)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CreateEncounterResource
-- ─────────────────────────────────────────────────────────────────────────────
function EB:OnInitialize()
    -- Check if module is disabled
    local profile = RoithiUI.db and RoithiUI.db.profile
    if profile and profile.EnabledModules and profile.EnabledModules.EncounterBar == false then
        self:Disable()
        return
    end

    self.db = profile and profile.EncounterResource or self.defaultSettings
    local db = self.db

    -- Slash Command
    self:RegisterChatCommand("reb", "ChatCommand")
    self:RegisterChatCommand("encounterbar", "ChatCommand")

    -- Guard against double-creation
    if _G.RoithiEncounterResource then return end

    -- Create the standalone bar (parented to UIParent)
    local encounterBar = CreateFrame("StatusBar", "RoithiEncounterResource", UIParent)
    encounterBar:SetSize(db.width, db.height)
    encounterBar:SetStatusBarTexture(
        LSM:Fetch("statusbar", db.texture) or "Interface\\TargetingFrame\\UI-StatusBar"
    )
    encounterBar:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    LibRoithi.mixins:CreateBackdrop(encounterBar)

    local bg = encounterBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1)
    encounterBar.bg = bg

    local fontName = (db and db.font)
        or (RoithiUI and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.font)
        or "Roithi Thick"
    local fontOutline = (db and db.fontOutline)
        or (RoithiUI and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.fontOutline)
        or "OUTLINE"
    local text = encounterBar:CreateFontString(nil, "OVERLAY")
    if ns.Utils and ns.Utils.ApplyTypography then
        ns.Utils.ApplyTypography(text, fontName, db.fontSize or 12, fontOutline, false, "Roithi Thick")
    elseif LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(text, fontName, db.fontSize or 12, fontOutline)
    end
    text:SetPoint("CENTER", encounterBar, "CENTER", 0, 0)
    encounterBar.Text = text

    encounterBar:Hide()

    -- Wire Update and OnEvent
    encounterBar.Update = function(barSelf) Update(barSelf) end
    encounterBar:SetScript("OnEvent", OnEvent)

    -- Register with LibEditMode
    if ns.InitEncounterBarLEM then
        ns.InitEncounterBarLEM()
    end
end

function EB:OnEnable()
    local db = RoithiUI.db.profile.EncounterResource
    self:Toggle(db.enabled)
end

function EB:OnDisable()
    self:Toggle(false)
end

function EB:ChatCommand(input)
    local db = RoithiUI.db.profile.EncounterResource
    if input == "debug" then
        db.widgetDebug = not db.widgetDebug
        RoithiUI:Print("EncounterBar Widget Debug: " ..
            (db.widgetDebug and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    elseif input == "widgets" then
        db.widgetLogMode = not db.widgetLogMode
        RoithiUI:Print("EncounterBar Widget Log Mode: " ..
            (db.widgetLogMode and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    else
        RoithiUI:Print("Usage: /reb [debug | widgets]")
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Module Metadata & Options Registry
-- ─────────────────────────────────────────────────────────────────────────────
local localeLib = LibStub("AceLocale-3.0", true)
local L = localeLib and localeLib:GetLocale("RoithiUI", true) or setmetatable({}, { __index = function(_, k) return k end })

EB.dbKey = "EncounterResource"
EB.displayName = L["Encounter Bar (Alt Power)"]
EB.description = L["Enables RoithiUI custom alternative power bar and encounter power widgets."]
EB.order = 30

function EB:RefreshProfile()
    local profile = RoithiUI.db and RoithiUI.db.profile
    self.db = profile and profile.EncounterResource or self.defaultSettings
    local bar = _G.RoithiEncounterResource
    if bar and self.db then
        bar:SetSize(self.db.width or 250, self.db.height or 20)
        bar:ClearAllPoints()
        bar:SetPoint(self.db.point or "TOP", UIParent, self.db.point or "TOP", self.db.x or 0, self.db.y or -100)
        if self.db.texture and LSM then
            bar:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.texture) or "Interface\\TargetingFrame\\UI-StatusBar")
        end
        if bar.Text then
            local fontName = (self.db and self.db.font)
                or (RoithiUI and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.font)
                or "Roithi Thick"
            local fontOutline = (self.db and self.db.fontOutline)
                or (RoithiUI and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.fontOutline)
                or "OUTLINE"
            if ns.Utils and ns.Utils.ApplyTypography then
                ns.Utils.ApplyTypography(bar.Text, fontName, self.db.fontSize or 12, fontOutline, false, "Roithi Thick")
            elseif LibRoithi and LibRoithi.mixins then
                LibRoithi.mixins:SetFont(bar.Text, fontName, self.db.fontSize or 12, fontOutline)
            end
        end
        local LEM = LibStub and LibStub("LibEditMode-Roithi", true)
        if LEM and LEM.RefreshFrameSettings then
            LEM:RefreshFrameSettings(bar)
        end
    end
end
EB.RefreshSettings = EB.RefreshProfile

function EB:UpdateFonts()
    if self.UpdateBarLayout then self:UpdateBarLayout() end
end

