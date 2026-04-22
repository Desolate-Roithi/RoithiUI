local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

local EB = RoithiUI:NewModule("EncounterBar", "AceEvent-3.0")

-- Blizzard source constant: ALTERNATE_POWER_INDEX = 10
-- Do NOT use Enum.PowerType.Alternate — it does not exist in 12.0.1.
local ALTERNATE_POWER_INDEX = 10

-- ─────────────────────────────────────────────────────────────────────────────
-- Blacklists
-- ─────────────────────────────────────────────────────────────────────────────
local BLACKLISTED_KEYWORDS = {
    ["Singularity Anchor"] = true,
    ["Prop Hunt"] = true,
    ["Hide and Seek"] = true,
    ["Decor Duel"] = true,
    ["Dragon Isles"] = true,
    ["Dragonriding"] = true,
    ["Vigor"] = true,
    ["Runestone Charge"] = true,
}

local function IsBarBlacklisted(text)
    if not text or text == "" then return false end
    for keyword in pairs(BLACKLISTED_KEYWORDS) do
        if text:find(keyword) then return true end
    end
    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Blizzard PlayerPowerBarAlt toggle helper
-- Suppresses the native bar while our custom one is active.
-- ─────────────────────────────────────────────────────────────────────────────
local function ToggleBlizzard(enableCustom)
    if not PlayerPowerBarAlt then return end

    if enableCustom then
        PlayerPowerBarAlt:UnregisterEvent("UNIT_POWER_BAR_SHOW")
        PlayerPowerBarAlt:Hide()

        -- Prevent OnUpdate crash by removing the script entirely
        if not PlayerPowerBarAlt.RoithiOriginalOnUpdate then
            PlayerPowerBarAlt.RoithiOriginalOnUpdate = PlayerPowerBarAlt:GetScript("OnUpdate")
        end
        PlayerPowerBarAlt:SetScript("OnUpdate", nil)

        -- Prevent re-showing via hook
        if not PlayerPowerBarAlt.RoithiHookedShow then
            hooksecurefunc(PlayerPowerBarAlt, "Show", function(self)
                if RoithiUI.db.profile.EncounterResource and RoithiUI.db.profile.EncounterResource.enabled then
                    self:Hide()
                end
            end)
            PlayerPowerBarAlt.RoithiHookedShow = true
        end

        -- Suppression removed to fix missing overlays in Hide and Seek mode
    else
        -- Restore Blizzard bar
        if PlayerPowerBarAlt.RoithiOriginalOnUpdate then
            PlayerPowerBarAlt:SetScript("OnUpdate", PlayerPowerBarAlt.RoithiOriginalOnUpdate)
            PlayerPowerBarAlt.RoithiOriginalOnUpdate = nil
        end

        PlayerPowerBarAlt:RegisterEvent("UNIT_POWER_BAR_SHOW")
        if UnitPowerBarID("player") then
            -- FIX: Force initialization so 'barInfo' exists before OnUpdate runs
            local onEvent = PlayerPowerBarAlt:GetScript("OnEvent")
            if onEvent then
                onEvent(PlayerPowerBarAlt, "UNIT_POWER_BAR_SHOW", "player")
            end
            if PlayerPowerBarAlt.barInfo then
                PlayerPowerBarAlt:Show()
            end
        end
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
        RoithiUI.db.profile.EncounterResource = {
            enabled = true,
            width    = 250,
            height   = 20,
            fontSize = 12,
            texture  = "Solid",
            point = "TOP",
            x = 0,
            y = -100,
        }
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
    
    local debugMode = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.debugMode
    if debugMode then
        RoithiUI:Log("RoithiUI DEBUG [UpdateFromWidget] ID: " .. tostring(widgetInfo.widgetID) .. " Type: " .. tostring(widgetInfo.widgetType))
    end

    local info
    if widgetInfo.widgetType == Enum.UIWidgetVisualizationType.UnitPowerBar then
        info = C_UIWidgetManager.GetUnitPowerBarWidgetVisualizationInfo(widgetInfo.widgetID)
    elseif widgetInfo.widgetType == Enum.UIWidgetVisualizationType.StatusBar then
        info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetInfo.widgetID)
    else
        return
    end

    -- Verify this widget belongs to the Unit Power Bar set
    -- This filters out Zone labels (Dragon Isles), Quest info, etc.
    local powerBarSetID = C_UIWidgetManager.GetUnitPowerBarWidgetSetID()
    if widgetInfo.widgetSetID ~= powerBarSetID and not s.isInEditMode then
        -- Special exception for specific scenarios if they don't use the standard set
        -- But for now, strict set matching is the cleanest fix.
        return
    end

    -- Scenario Blacklist (Prop Hunt, etc.)
    if C_Scenario.IsInScenario() then
        local name = C_Scenario.GetInfo()
        if name and (name:find("Prop Hunt") or name:find("Hide and Seek") or name:find("Decor Duel")) then
            s:Hide()
            return
        end
    end

    if not info and debugMode then
        RoithiUI:Log("RoithiUI DEBUG [UpdateFromWidget] VisualizationInfo returned nil for ID " .. tostring(widgetInfo.widgetID))
    end
    if not info or info.shownState == Enum.WidgetShownState.Hidden then
        -- Only hide the custom bar if the legacy PlayerPowerBarAlt path is also inactive
        if not UnitPowerBarID("player") then
            s.hasWidgetID = nil
            s:Hide()
        end
        return
    end

    -- Fix: Hide if the widget has no maximum value (e.g. Zone labels)
    if not info.barMax or info.barMax <= 0 then
        s.hasWidgetID = nil
        if not UnitPowerBarID("player") then
            s:Hide()
        end
        return
    end

    s:SetMinMaxValues(info.barMin, info.barMax)
    s:SetValue(info.barValue)

    if info.barColor then
        s:SetStatusBarColor(info.barColor.r, info.barColor.g, info.barColor.b)
        s.hasWidgetColor = true
    end

    local nameText = info.barLabel or info.text or ""
    if IsBarBlacklisted(nameText) then
        s.hasWidgetID = nil
        s:Hide()
        return
    end

    s.Text:SetText(nameText)
    s.hasWidgetID = widgetInfo.widgetID -- Track current source
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
        local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(s.hasWidgetID)
        local isPower = false
        if not info or info.shownState == Enum.WidgetShownState.Hidden then
            info = C_UIWidgetManager.GetUnitPowerBarWidgetVisualizationInfo(s.hasWidgetID)
            isPower = true
        end

        if not info or info.shownState == Enum.WidgetShownState.Hidden then
            s.hasWidgetID = nil
            s.hasWidgetColor = false
        else
            -- If the widget is still valid, let UpdateFromWidget handle it or just keep showing
            -- We don't want to fall through to Power Bar logic if a widget is active
            return 
        end
    end

    -- 2. Check Alternate Power
    local barID = UnitPowerBarID("player")

    if not barID or barID == 0 then
        s:Hide()
        return
    end

    local info = GetUnitPowerBarInfo(barID) or GetUnitPowerBarInfo("player")
    local nameText = info and (info.name or info.barLabel) or ""

    -- Unified Blacklist Check (Scenario Name & Bar Name)
    local scenarioName = C_Scenario.IsInScenario() and C_Scenario.GetInfo() or ""
    if IsBarBlacklisted(nameText) or IsBarBlacklisted(scenarioName) then
        s:Hide()
        return
    end

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

    local current = UnitPower("player", ALTERNATE_POWER_INDEX) or 0
    local max     = UnitPowerMax("player", ALTERNATE_POWER_INDEX) or 0

    if max > 0 then
        s:SetMinMaxValues(0, max)
        s:SetValue(current)
        s:Show()
        
        local nameText = nil
        if _G.GetUnitPowerBarStrings then
            local n1 = _G.GetUnitPowerBarStrings("player")
            local n2 = _G.GetUnitPowerBarStrings(barID)
            nameText = n1 or n2
        end
        
        local isSecret = (issecretvalue and issecretvalue(current))
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
        
        if nameText and nameText ~= "" then
            s.Text:SetText(nameText .. ": " .. currentStr)
        else
            s.Text:SetText(currentStr)
        end
    else
        s:Hide()
    end

    -- Color: use bar-defined color, fall back to Deep Sky Blue
    if info and info.barColor then
        s:SetStatusBarColor(info.barColor.r, info.barColor.g, info.barColor.b)
    else
        -- If we don't have a widget color OR it's a legacy power bar, use blue
        if not s.hasWidgetColor or (s.hasWidgetID == nil) then
            s:SetStatusBarColor(0, 0.75, 1.0) -- 00BFFF Deep Sky Blue
        end
    end

    -- Final Safety: If we have no data and no text, don't show an empty bar
    if (not nameText or nameText == "") and (not currentStr or currentStr == "") then
        s:Hide()
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Smart OnEvent dispatcher
-- ─────────────────────────────────────────────────────────────────────────────
local function OnEvent(s, event, arg1, arg2)
    local debugMode = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.debugMode
    if debugMode then
        RoithiUI:Log("RoithiUI DEBUG [OnEvent] Fired: " .. tostring(event) .. " arg1: " .. tostring(arg1))
    end
    
    -- UNIT_POWER_BAR_HIDE → immediate hide
    if event == "UNIT_POWER_BAR_HIDE" then
        if arg1 == nil or arg1 == "player" then
            s.hasWidgetID = nil
            s.hasWidgetColor = false
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
        if debugMode then
            RoithiUI:Log(string.format("RoithiUI DEBUG [OnEvent] UPDATE_UI_WIDGET fired | ID: %s | SetID: %s", 
                tostring(arg1 and arg1.widgetID), tostring(arg1 and arg1.widgetSetID)))
        end
        UpdateFromWidget(s, arg1)
        return
    end

    if event == "UPDATE_ALL_UI_WIDGETS" or event == "PLAYER_ENTERING_WORLD" or event:find("ZONE_CHANGED") or event:find("PLAYER_") then
        s.hasWidgetID = nil
        s.hasWidgetColor = false
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
    -- Ensure DB has full defaults
    if not RoithiUI.db.profile.EncounterResource then
        RoithiUI.db.profile.EncounterResource = {
            enabled  = true,
            width    = 250,
            height   = 20,
            fontSize = 12,
            texture  = "Solid",
            point    = "TOP",
            x        = 0,
            y        = -100,
        }
    end
    local db = RoithiUI.db.profile.EncounterResource

    -- Fill any missing keys (for older save data)
    if not db.point    then db.point    = "TOP" end
    if not db.x        then db.x        = 0 end
    if not db.y        then db.y        = -100 end
    if not db.width    then db.width    = 250 end
    if not db.height   then db.height   = 20 end
    if not db.fontSize then db.fontSize = 12 end
    if not db.texture  then db.texture  = "Solid" end

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

    local text = encounterBar:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", db.fontSize, "OUTLINE")
    text:SetPoint("CENTER", encounterBar, "CENTER", 0, 0)
    encounterBar.Text = text

    encounterBar:Hide()

    -- Wire Update and OnEvent
    encounterBar.Update = function(barSelf) Update(barSelf) end
    encounterBar:SetScript("OnEvent", OnEvent)

    -- Register with LibEditMode (LEMConfig/EncounterBar.lua handles callbacks)
    if ns.InitEncounterBarLEM then
        ns.InitEncounterBarLEM()
    end
end

function EB:OnEnable()
    local db = RoithiUI.db.profile.EncounterResource
    self:Toggle(db.enabled)
end

