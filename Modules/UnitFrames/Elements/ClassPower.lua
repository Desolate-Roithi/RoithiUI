---@diagnostic disable: undefined-global
local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

---@class UF
local UF = RoithiUI:GetModule("UnitFrames")

-- Configuration for Class Power
local ClassPowerConfig = {
    ["ROGUE"] = { mode = "POWER", type = Enum.PowerType.ComboPoints },
    ["DRUID"] = { mode = "POWER", type = Enum.PowerType.ComboPoints, requireForm = true },
    ["MONK"] = {
        [1] = { mode = "STAGGER", style = "BAR" },          -- Brewmaster Stagger
        [3] = { mode = "POWER", type = Enum.PowerType.Chi } -- Windwalker Only
    },
    ["PALADIN"] = { mode = "POWER", type = Enum.PowerType.HolyPower },
    ["WARLOCK"] = { mode = "POWER", type = Enum.PowerType.SoulShards },
    ["MAGE"] = { mode = "POWER", type = Enum.PowerType.ArcaneCharges, spec = 1 },
    ["EVOKER"] = { mode = "POWER", type = Enum.PowerType.Essence },
    ["DEATHKNIGHT"] = {
        mode = "RUNES",
        color = { r = 0.2, g = 0.6, b = 1.0 } -- Blueish Rune Color
    },
    ["SHAMAN"] = {
        mode = "AURA",
        spec = 2,
        spellID = 344179, -- Maelstrom Weapon
        maxDisplay = 5,
        overcapColor = { r = 1, g = 0, b = 0 },
        filter = "HELPFUL"
    },
    ["DEMONHUNTER"] = {
        -- Devourer: Void / Soul Fragments (0-50). Render as a single BAR.
        [3] = {
            mode = "AURA",
            style = "BAR",
            spellID = 1225789,
            backupID = 1227702,
            maxDisplay = 50,                          -- Default Max (Dynamic update if possible)
            filter = "HELPFUL",
            color = { r = 0.45, g = 0.05, b = 0.85 }, -- Deep Void Purple
            requireAura = true,                       -- Only show if this Aura is actually present (Devourer Spec Specific)
            markers = { 30 }                          -- Indicator at 30 Souls
        },
    }
}
UF.ClassPowerConfig = ClassPowerConfig

function UF:CreateClassPower(frame)
    if frame.unit ~= "player" then return end

    local name = frame:GetName() and (frame:GetName() .. "_ClassPower") or nil
    local element = CreateFrame("Frame", name, frame)
    -- Initial Anchor (will be updated by layout)
    element:SetPoint("TOPLEFT", frame.Power, "BOTTOMLEFT", 0, -4)
    element:SetSize(frame:GetWidth(), 12)
    frame.ClassPower = element

    element.Text = element:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    element.Text:SetPoint("CENTER")
    element.Text:SetText("CLASS POWER")
    element.Text:Hide()

    element.points = {}

    local fontName = RoithiUI.db.profile.General.unitFrameFont or "Friz Quadrata TT"

    -- Main Points (Bars/Nodes)
    for i = 1, 10 do
        local point = CreateFrame("StatusBar", nil, element)
        point:SetSize((frame:GetWidth() - 9 * 2) / 10, 10)
        point:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        point:GetStatusBarTexture():SetHorizTile(false)
        point:SetMinMaxValues(0, 1)

        LibRoithi.mixins:CreateBackdrop(point)

        -- Background
        point.bg = point:CreateTexture(nil, "BACKGROUND")
        point.bg:SetAllPoints()
        point.bg:SetColorTexture(1, 1, 1)
        point.bg:SetAlpha(0.2)

        -- Cooldowns (Hidden for DK, used for others if needed?)
        point.cooldown = CreateFrame("Cooldown", nil, point, "CooldownFrameTemplate")
        point.cooldown:SetAllPoints()
        point.cooldown:Hide()

        -- Timer Text (For Runes)
        point.Timer = point:CreateFontString(nil, "OVERLAY")
        -- 8pt Font, Outline, 1 digit precision requested
        LibRoithi.mixins:SetFont(point.Timer, fontName, 12, "OUTLINE")
        point.Timer:SetPoint("CENTER", point, "CENTER", 0, 0)
        point.Timer:SetText("")

        -- Overcap Overlay
        point.OvercapBar = CreateFrame("StatusBar", nil, point)
        point.OvercapBar:SetAllPoints()
        point.OvercapBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        point.OvercapBar:SetMinMaxValues(0, 1)
        point.OvercapBar:SetValue(0)
        point.OvercapBar:SetFrameLevel(point:GetFrameLevel() + 1)
        point.OvercapBar:SetStatusBarColor(1, 0, 0, 0.5)

        element.points[i] = point
    end

    -- Threshold Markers (Lines)
    element.markers = {}
    for i = 1, 5 do
        local marker = element:CreateTexture(nil, "OVERLAY")
        marker:SetColorTexture(1, 1, 1, 0.8) -- White transparent line
        marker:SetSize(1, 12)
        marker:Hide()
        element.markers[i] = marker
    end

    -- Enable movement for Edit Mode (Handled by LibEditMode)
    -- element:SetMovable(true)
    -- element:SetClampedToScreen(true)

    local function UpdateLayout(numPoints)
        if numPoints == 0 then return end

        if element.lastMax == numPoints and not element.forceLayout then
            return
        end
        element.lastMax = numPoints
        element.forceLayout = false

        local width = element:GetWidth()
        if width <= 0 then
            local db = RoithiUI.db.profile.UnitFrames[frame.unit]
            width = db and (db.classPowerWidth or db.width) or 200
        end

        local spacing = 2
        local pWidth = (width - (numPoints - 1) * spacing) / numPoints

        for i = 1, numPoints do
            local point = element.points[i]
            point:SetWidth(pWidth)
            point:SetHeight(element:GetHeight()) -- Ensure height updates dynamically
            point:ClearAllPoints()
            if i == 1 then
                point:SetPoint("LEFT", element, "LEFT", 0, 0)
            else
                point:SetPoint("LEFT", element.points[i - 1], "RIGHT", spacing, 0)
            end
        end
    end

    -- Runes OnUpdate Loop (Continuous Value Refill + Timer)
    local function OnUpdateRunes(self, elapsed)
        for i = 1, 6 do
            local point = element.points[i]
            local start, duration, runeReady = GetRuneCooldown(i)
            if runeReady then
                point:SetMinMaxValues(0, 1)
                point:SetValue(1)
                point:SetAlpha(1)
                point.Timer:SetText("")
            elseif start and duration then
                point:SetAlpha(1)

                local current = GetTime() - start
                point:SetMinMaxValues(0, duration)
                point:SetValue(current)

                -- Timer Logic
                local remain = duration - current
                if remain > 0 then
                    point.Timer:SetText(string.format("%.1f", remain))
                else
                    point.Timer:SetText("")
                end
            else
                point:SetMinMaxValues(0, 1)
                point:SetValue(0)
                point.Timer:SetText("")
            end
        end
    end

    local function Update()
        -- Global Enable Check
        local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[frame.unit]
        if db and db.classPowerEnabled == false then
            element:Hide()
            element:SetScript("OnUpdate", nil)
            return
        end

        local _, class = UnitClass("player")
        local spec = GetSpecialization()

        -- Robust Config Logic
        local classConfig = ClassPowerConfig[class]
        local config = nil

        if classConfig then
            if classConfig[spec] then
                config = classConfig[spec]
            elseif classConfig.mode then
                config = classConfig
            end
        end

        if not config then
            element:Hide()
            element:SetScript("OnUpdate", nil)
            return
        end

        if config.spec and config.spec ~= spec then
            element:Hide()
            element:SetScript("OnUpdate", nil)
            return
        end

        -- Require Form Logic (Druid Specific)
        if config.requireForm and class == "DRUID" then
            local pType = UnitPowerType("player")
            if pType ~= Enum.PowerType.Energy then
                element:Hide()
                element:SetScript("OnUpdate", nil)
                return
            end
        end

        local max = config.maxDisplay or 5
        local color = config.color or (config.mode == "AURA" and { r = 0, g = 1, b = 1 } or { r = 1, g = 1, b = 0 })

        local curValue = 0
        local modifier = 1

        if config.mode == "AURA" then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(config.spellID)
            if not aura and config.backupID then
                aura = C_UnitAuras.GetPlayerAuraBySpellID(config.backupID)
            end

            -- RequireAura check
            if config.requireAura and not aura then
                element:Hide()
                element:SetScript("OnUpdate", nil)
                return
            end

            local apps = aura and aura.applications or 0
            if issecretvalue and issecretvalue(apps) then
                curValue = 0
            else
                curValue = apps
            end

            ---@diagnostic disable-next-line: undefined-field
            if aura and config.maxDisplay then
                max = config.maxDisplay
                if class == "SHAMAN" then max = 5 end
            end
        elseif config.mode == "POWER" then
            local pMax = UnitPowerMax("player", config.type)

            -- Strict Visibility: If max power is 0 (e.g. Druid in Bear/Caster), HIDE.
            if not pMax or pMax <= 0 then
                element:Hide()
                element:SetScript("OnUpdate", nil)
                return
            end

            max = pMax

            -- Fragment Logic (Generic)
            local segMax = UnitPowerMax("player", config.type) -- logical max (5)
            modifier = UnitPowerDisplayMod(config.type) or 1

            -- Fallback if DisplayMod is 1 but TrueMax reveals fragments (some resources might behave this way)
            if modifier == 1 then
                local trueMax = UnitPowerMax("player", config.type, true)
                if trueMax and segMax and segMax > 0 and trueMax > segMax then
                    modifier = trueMax / segMax
                end
            end

            -- Explicit Warlock Fix: Soul Shards are always 10 fragments per shard
            if class == "WARLOCK" and config.type == Enum.PowerType.SoulShards then
                modifier = 10
            end

            curValue = UnitPower("player", config.type, true) -- get raw fragment value
        elseif config.mode == "STAGGER" then
            curValue = UnitStagger("player") or 0
            local hpMax = UnitHealthMax("player")
            if hpMax and hpMax > 0 then max = hpMax end

            -- Dynamic Coloring
            local pct = (curValue / max) * 100
            if pct >= 60 then
                color = { r = 1.0, g = 0.42, b = 0.42 } -- Red (Heavy)
            elseif pct >= 30 then
                color = { r = 1.0, g = 0.98, b = 0.72 } -- Yellow (Moderate)
            else
                color = { r = 0.52, g = 1.0, b = 0.52 } -- Green (Light)
            end

            -- Stagger is always a single bar, ensure modifier doesn't break it (POINTS mode check below)
            modifier = 1
        elseif config.mode == "RUNES" then
            max = 6 -- DK Runes always 6
            modifier = 1
        end

        -- Layout Handling for BAR style
        local pointsToRender = max
        if config.style == "BAR" then
            pointsToRender = 1
        end

        UpdateLayout(pointsToRender)

        -- Marker Logic
        if config.markers and config.style == "BAR" then
            local currentWidth = element.points[1]:GetWidth()
            for i, val in ipairs(config.markers) do
                local m = element.markers[i]
                if m and val < max then
                    m:Show()
                    m:ClearAllPoints()
                    local pct = val / max
                    m:SetPoint("CENTER", element.points[1], "LEFT", currentWidth * pct, 0)
                    m:SetHeight(element:GetHeight())
                elseif m then
                    m:Hide()
                end
            end
        else
            for _, m in ipairs(element.markers) do m:Hide() end
        end

        -- Rune Special Handling
        if config.mode == "RUNES" then
            element:SetScript("OnUpdate", OnUpdateRunes)
        else
            element:SetScript("OnUpdate", nil)
        end

        for i = 1, 10 do
            local point = element.points[i]

            if i > pointsToRender then
                point:Hide()
            else
                point:Show()
                point:SetAlpha(1) -- defensive check against greying out
                point:SetStatusBarColor(color.r, color.g, color.b)
                point.bg:SetVertexColor(color.r, color.g, color.b)

                -- Clean up Timer if not in Rune Mode
                if config.mode ~= "RUNES" then
                    point.Timer:SetText("")
                end

                if config.style == "BAR" then
                    -- Single Bar Mode
                    -- If we are using fragments, scaling applies to the whole bar
                    local barMax = max * (modifier or 1)
                    point:SetMinMaxValues(0, barMax)
                    point:SetValue(curValue)
                    point.cooldown:Hide()

                    if curValue >= barMax and config.overcapColor then
                        point.OvercapBar:SetStatusBarColor(config.overcapColor.r, config.overcapColor.g,
                            config.overcapColor.b, 0.5)
                        point.OvercapBar:SetMinMaxValues(0, 1)
                        point.OvercapBar:SetValue(1)
                    else
                        point.OvercapBar:SetValue(0)
                    end
                elseif config.mode == "RUNES" then
                    -- Initial Setup for Runes (Updates handled by OnUpdate)
                    point.cooldown:Hide()
                else
                    -- Standard Points Mode
                    -- Here is where the smooth fragment logic shines
                    -- Point i represents range: [(i-1)*mod, i*mod]
                    -- e.g. Warlock Mod=10. Point 1 is 0-10. Point 2 is 10-20.
                    local mod = modifier or 1
                    point:SetMinMaxValues((i - 1) * mod, i * mod)
                    point:SetValue(curValue)

                    if config.overcapColor then
                        -- WRAPPING LOGIC (New)
                        -- Calculate if this specific point should wrap (turn red)
                        -- Normalize current value to logical units for wrapping calculation
                        local mod = modifier or 1
                        local logicalCur = curValue / mod
                        local overcapCount = math.max(0, logicalCur - max)

                        point.OvercapBar:SetStatusBarColor(config.overcapColor.r, config.overcapColor.g,
                            config.overcapColor.b, 1)
                        point.OvercapBar:SetMinMaxValues(0, 1) -- Boolean state basically

                        if i <= overcapCount then
                            -- This point is overcapped (e.g., Stacks 6, 7, 8... fill points 1, 2, 3...)
                            point.OvercapBar:SetValue(1)
                        else
                            point.OvercapBar:SetValue(0)
                        end
                    else
                        point.OvercapBar:SetValue(0)
                    end
                end
            end
        end
        element:Show()
    end

    frame:HookScript("OnEvent", function(self, event, unit)
        if (unit and unit ~= "player") then return end
        Update()
    end)

    frame:RegisterEvent("PLAYER_REGEN_ENABLED", Update, true)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD", Update, true)
    frame:RegisterEvent("SPELLS_CHANGED", Update, true)
    if class == "DRUID" then frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM", Update, true) end
    if class == "DEATHKNIGHT" then frame:RegisterEvent("RUNE_POWER_UPDATE", Update, true) end
    frame:RegisterEvent("UNIT_POWER_UPDATE", Update)
    frame:RegisterEvent("UNIT_DISPLAYPOWER", Update)
    if class == "SHAMAN" or class == "DEMONHUNTER" then frame:RegisterEvent("UNIT_AURA", Update) end
    if class == "MONK" then
        frame:RegisterEvent("UNIT_HEALTH", Update)
        frame:RegisterEvent("UNIT_MAXHEALTH", Update)
    end

    -- ------------------------------------------------------------------------
    -- Robust Layout Updater (Centralized Attachment)
    -- ------------------------------------------------------------------------
    frame.UpdateClassPowerLayout = function()
        local AL = ns.AttachmentLogic
        if AL then
            AL:ApplyLayout(frame.unit, "ClassPower")
        end

        local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[frame.unit]
        if not db then return end

        local height = db.classPowerHeight or 12
        local enabled = db.classPowerEnabled ~= false

        if not enabled then
            element:Hide()
            return
        end

        element:SetHeight(height)
        Update()
    end

    -- ------------------------------------------------------------------------
    -- Edit Mode Integration
    -- ------------------------------------------------------------------------
    local LEM = LibStub("LibEditMode-Roithi", true)
    if LEM then
        element.editModeName = (frame.editModeName or frame:GetName()) .. " Class Power"

        -- Default position (detached)
        local defaults = { point = "CENTER", x = 0, y = 0 }

        -- Callback: Called when LibEditMode tries to move the frame
        local function OnClassPowerPosChanged(f, layoutName, point, x, y)
            local unit = frame.unit
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]

            -- If not detached, ignore movement and enforce attached layout
            if not db or not db.classPowerDetached then
                if frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
                return
            end

            if db then
                db.classPowerPoint = point
                db.classPowerX = x
                db.classPowerY = y
            end
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)

            local AL = ns.AttachmentLogic
            if AL then AL:GlobalLayoutRefresh(unit) end
        end

        LEM:AddFrame(element, OnClassPowerPosChanged, defaults)

        -- Edit Mode Visibility
        LEM:RegisterCallback('enter', function()
            local unit = frame.unit
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]
            if db and db.classPowerDetached then
                element.isInEditMode = true
                element:SetAlpha(1)
                element:Show()
                -- Force render of dummy points
                for i = 1, 5 do
                    if element.points[i] then
                        element.points[i]:Show()
                        element.points[i]:SetValue(1)
                    end
                end
            else
                element.isInEditMode = false
                -- Force layout update to ensure SetMovable(false) is applied
                if frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
            end
        end)

        LEM:RegisterCallback('exit', function()
            element.isInEditMode = false
            Update()
        end)
    end

    -- Hook for Config: Must trigger LAYOUT update, not just value update
    frame.UpdateClassPowerSettings = frame.UpdateClassPowerLayout
    frame.UpdateClassPowerLayout()
end

function UF:UpdateClassPowerSettings(frame)
    if frame.UpdateClassPowerSettings then
        frame.UpdateClassPowerSettings(frame)
    end
end
