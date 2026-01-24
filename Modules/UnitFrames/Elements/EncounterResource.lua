local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LEM = LibStub("LibEditMode")

local UF = RoithiUI:GetModule("UnitFrames")

-- Blizzard Toggle Helper
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

        -- Prevent showing via hook
        if not PlayerPowerBarAlt.RoithiHookedShow then
            hooksecurefunc(PlayerPowerBarAlt, "Show", function(self)
                if RoithiUI.db.profile.EncounterResource and RoithiUI.db.profile.EncounterResource.enabled then
                    self:Hide()
                end
            end)
            PlayerPowerBarAlt.RoithiHookedShow = true
        end
    else
        -- Restore
        if PlayerPowerBarAlt.RoithiOriginalOnUpdate then
            PlayerPowerBarAlt:SetScript("OnUpdate", PlayerPowerBarAlt.RoithiOriginalOnUpdate)
            PlayerPowerBarAlt.RoithiOriginalOnUpdate = nil
        end

        PlayerPowerBarAlt:RegisterEvent("UNIT_POWER_BAR_SHOW")
        if UnitPowerBarID("player") then
            -- FIX: Force initialization so 'barInfo' exists before OnUpdate runs
            local onEvent = PlayerPowerBarAlt:GetScript("OnEvent")
            if onEvent then
                -- Must pass 'player' as unit, otherwise some handlers bail out early
                onEvent(PlayerPowerBarAlt, "UNIT_POWER_BAR_SHOW", "player")
            end

            -- DOUBLE CHECK: Do not show if barInfo is still missing (failed init)
            if PlayerPowerBarAlt.barInfo then
                PlayerPowerBarAlt:Show()
            end
        end
    end
end

-- Toggle Function (External Access)
function UF:ToggleEncounterResource(enabled)
    -- Ensure DB exists if called early
    if not RoithiUI.db.profile.EncounterResource then
        RoithiUI.db.profile.EncounterResource = {
            enabled = true,
            point = "TOP",
            x = 0,
            y = -100,
        }
    end

    local db = RoithiUI.db.profile.EncounterResource
    db.enabled = enabled

    -- Find the bar if it exists
    local frame = self.frames and self.frames["player"]
    local encounterBar = frame and frame.EncounterResource

    if enabled then
        ToggleBlizzard(true)
        if encounterBar then
            -- Re-register events
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

function UF:CreateEncounterResource(frame)
    if frame.unit ~= "player" then return end

    -- Defaults
    if not RoithiUI.db.profile.EncounterResource then
        RoithiUI.db.profile.EncounterResource = {
            enabled = true,
            point = "TOP",
            x = 0,
            y = -100,
        }
    end
    local db = RoithiUI.db.profile.EncounterResource

    -- Enforce defaults for partial DB
    if not db.point then db.point = "TOP" end
    if not db.x then db.x = 0 end
    if not db.y then db.y = -100 end

    if _G.RoithiEncounterResource then return end

    -- Create Independent Frame (Parent UIParent)
    local encounterBar = CreateFrame("StatusBar", "RoithiEncounterResource", UIParent)
    encounterBar:SetSize(250, 20)
    encounterBar:SetStatusBarTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")

    -- Initial Position
    encounterBar:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    LibRoithi.mixins:CreateBackdrop(encounterBar)

    local bg = encounterBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1)
    encounterBar.bg = bg

    local text = encounterBar:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", 12, "OUTLINE")
    text:SetPoint("CENTER", encounterBar, "CENTER", 0, 0)
    encounterBar.Text = text

    -- Initially Hide
    encounterBar:Hide()

    -- Reference
    frame.EncounterResource = encounterBar

    -- Edit Mode Registration
    if LEM then
        local defaults = { point = "TOP", x = 0, y = -100 }

        local function OnPositionChanged(f, layoutName, point, x, y)
            db.point = point
            db.x = x
            db.y = y
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
        end

        LEM:AddFrame(encounterBar, OnPositionChanged, defaults)
        encounterBar.editModeName = "Encounter Resource Bar" -- Human readable name
    end

    -- Update Logic
    local function Update(self)
        if not db.enabled then
            self:Hide()
            return
        end

        local barID = UnitPowerBarID("player")

        if barID then
            ---@diagnostic disable-next-line: param-type-mismatch
            local current = UnitPower("player", Enum.PowerType.Alternate)

            ---@diagnostic disable-next-line: param-type-mismatch, missing-parameter
            local max = UnitPowerMax("player", Enum.PowerType.Alternate)

            ---@diagnostic disable-next-line: param-type-mismatch, missing-parameter
            local info = GetUnitPowerBarInfo(barID)

            -- If info is nil, it might be a hidden bar?
            if not info then
                -- Edit Mode Placeholder
                if self.isInEditMode then
                    self:SetMinMaxValues(0, 100)
                    self:SetValue(100)
                    self:Show()
                    self.Text:SetText("Encounter Bar")
                    self:SetStatusBarColor(1, 0, 1)
                    return
                end
                self:Hide()
                return
            end

            self:SetMinMaxValues(0, max)
            self:SetValue(current)

            self:Show()
            self:Show()
            self.Text:SetText(LibRoithi.mixins:SafeFormat("%d / %d", current, max))

            -- Color
            self:SetStatusBarColor(1, 0, 1) -- Default Pink/Purple
            if info.barColor then
                self:SetStatusBarColor(info.barColor.r, info.barColor.g, info.barColor.b)
            end
        else
            self:Hide()
        end
    end

    encounterBar.Update = Update
    encounterBar:SetScript("OnEvent", Update)

    -- Initial State
    UF:ToggleEncounterResource(db.enabled)
end
