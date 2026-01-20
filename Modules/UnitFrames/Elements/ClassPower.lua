local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

local UF = RoithiUI:GetModule("UnitFrames")

-- Configuration for Class Power
local ClassPowerConfig = {
    ["ROGUE"] = { mode = "POWER", type = Enum.PowerType.ComboPoints },
    ["DRUID"] = { mode = "POWER", type = Enum.PowerType.ComboPoints, requireForm = true }, -- Cat form logic needed usually
    ["MONK"] = { mode = "POWER", type = Enum.PowerType.Chi },
    ["PALADIN"] = { mode = "POWER", type = Enum.PowerType.HolyPower },
    ["WARLOCK"] = { mode = "POWER", type = Enum.PowerType.SoulShards },
    ["MAGE"] = { mode = "POWER", type = Enum.PowerType.ArcaneCharges, spec = 1 }, -- Arcane
    ["EVOKER"] = { mode = "POWER", type = Enum.PowerType.Essence },
    ["DEATHKNIGHT"] = { mode = "RUNES" },
    ["SHAMAN"] = {
        mode = "AURA",
        spec = 2,         -- Enhancement
        spellID = 344179, -- Maelstrom Weapon (Verify ID) -> 344179 is common, checking UnitAura usually by name is discouraged, prefer ID.
        -- Notes: Maelstrom Weapon ID varies.
        maxDisplay = 5,
        overcapColor = { r = 1, g = 0, b = 0 }, -- Red border at 5+
        filter = "HELPFUL"
    },
    ["DEMONHUNTER"] = {
        -- Soul Fragments
        [2] = { mode = "AURA", spellID = 203981, maxDisplay = 5, filter = "HELPFUL" }, -- Vengeance (Soul Fragments)
        [3] = { mode = "AURA", spellID = 204255, maxDisplay = 5, filter = "HELPFUL" }, -- Devourer (Soul Fragments)
    }
}

-- Maelstrom ID check:
-- 11.0 usually consolidates. Let's use name check fallback if ID fails or just stick to ID if confident.
-- For Maelstrom, spell ID 344179 is 10.0 version.
-- For Vengeance Soul Fragments: 203981.

function UF:CreateClassPower(frame)
    if frame.unit ~= "player" then return end

    local name = frame:GetName() and (frame:GetName() .. "_ClassPower") or nil
    local element = CreateFrame("Frame", name, frame)
    element:SetPoint("BOTTOMLEFT", frame.Power, "TOPLEFT", 0, 4)
    element:SetSize(frame:GetWidth(), 12)
    element:SetSize(frame:GetWidth(), 12)
    frame.ClassPower = element

    element.Text = element:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    element.Text:SetPoint("CENTER")
    element.Text:SetText("CLASS POWER")
    element.Text:Hide()

    element.points = {}

    -- Create 10 Points (Max needed usually)
    for i = 1, 10 do
        local point = CreateFrame("Frame", nil, element)
        point:SetSize((frame:GetWidth() - 9 * 2) / 10, 10) -- fluid width

        LibRoithi.mixins:CreateBackdrop(point)

        point.tex = point:CreateTexture(nil, "ARTWORK")
        point.tex:SetAllPoints()
        point.tex:SetColorTexture(1, 1, 1) -- White by default, colored by update

        -- Rune / Cooldown support
        point.cooldown = CreateFrame("Cooldown", nil, point, "CooldownFrameTemplate")
        point.cooldown:SetAllPoints()
        point.cooldown:Hide()

        element.points[i] = point
    end

    local function UpdateLayout(numPoints)
        if numPoints == 0 then return end
        local width = frame:GetWidth()
        local spacing = 2
        local pWidth = (width - (numPoints - 1) * spacing) / numPoints

        for i = 1, numPoints do
            local point = element.points[i]
            point:SetWidth(pWidth)
            point:ClearAllPoints()
            if i == 1 then
                point:SetPoint("LEFT", element, "LEFT", 0, 0)
            else
                point:SetPoint("LEFT", element.points[i - 1], "RIGHT", spacing, 0)
            end
        end
    end

    local function Update()
        local _, class = UnitClass("player")
        local config = ClassPowerConfig[class]

        if not config then
            element:Hide()
            return
        end

        if element.isInEditMode then
            UpdateLayout(5)
            for i = 1, 5 do
                local p = element.points[i]
                p:Show()
                p.tex:SetColorTexture(1, 1, 0)
                p.tex:SetVertexColor(1, 1, 0) -- Ensure vertex color is set too
                p:SetAlpha(1)
            end
            element.Text:Show()
            element:Show()
            return
        end
        element.Text:Hide()

        -- Spec Check
        local spec = GetSpecialization()
        if config[spec] then config = config[spec] end -- Sub-table for specs (DH)
        if config.spec and config.spec ~= spec then
            element:Hide()
            return
        end

        local cur, max = 0, 0
        local color = { r = 1, g = 1, b = 0 } -- Default Yellow

        if config.mode == "POWER" then
            -- Power Check
            -- Power Check
            -- Replaced old requireForm logic with Max Power check
            -- If the player has a max power > 0 for this type, show the bar.

            -- Druid Cat Form Check
            if class == "DRUID" and config.requireForm then
                local index = GetShapeshiftForm()
                local isCat = false
                if index and index > 0 then
                    local _, _, _, spellID = GetShapeshiftFormInfo(index)
                    if spellID == 768 then isCat = true end
                end

                if not isCat then
                    element:Hide()
                    return
                end
            end

            if UnitPowerMax("player", config.type, true) <= 0 then
                element:Hide()
                return
            end

            cur = UnitPower("player", config.type, true)
            max = UnitPowerMax("player", config.type, true)

            -- Some powers are returned in 1/10ths e.g. Stagger? No, Secondary resources are usually integer.
            -- Using 'true' in UnitPower returns unmodified.
            -- For some like SoulShards it's 1 per shard.
            -- Validating if 'true' handles fractional for special bars.
            -- Class Resources usually whole numbers.

            -- Color?
            local powerInfo = PowerBarColor[config.type] or { r = 1, g = 1, b = 1 }
            -- PowerBarColor index might be string token or number ID?
            -- Global PowerBarColor is [Token] e.g. "COMBO_POINTS"
            -- We need to map Enum to Token? Or just use class color?
            -- Let's use generic Class Color or white for now.
            color = { r = 1, g = 0.9, b = 0 }
        elseif config.mode == "RUNES" then
            -- Runes are always 6
            max = 6
            cur = 6                             -- We calculate per rune
            color = { r = 0.4, g = 0.6, b = 1 } -- Rune Blue
        elseif config.mode == "AURA" then
            -- Check Aura
            local found = false
            -- We need to scan by ID. `C_UnitAuras` is filtered by name usually, or iterate.
            -- Iterate is safest.
            for i = 1, 40 do
                local aura = C_UnitAuras.GetAuraDataByIndex("player", i, config.filter)
                if not aura then break end
                if aura.spellId == config.spellID then
                    cur = aura.applications
                    if cur == 0 then cur = 1 end -- Stacks 0 means 1? Usually yes for some buffs, but Maelstrom implies stacks.
                    found = true
                    break
                end
            end
            if not found then cur = 0 end

            max = config.maxDisplay or 5    -- Soft cap
            -- Color
            color = { r = 0, g = 1, b = 1 } -- Cyan/Blueish default
        end

        -- Prepare Layout
        local displayMax = max
        if config.maxDisplay then displayMax = config.maxDisplay end
        -- For Runes, displayMax is 6.

        UpdateLayout(displayMax)

        -- Render
        for i = 1, 10 do
            local point = element.points[i]
            if i > displayMax then
                point:Hide()
            else
                point:Show()
                -- Logic per mode
                if config.mode == "RUNES" then
                    local start, duration, runeReady = GetRuneCooldown(i)
                    if runeReady then
                        point.tex:SetVertexColor(color.r, color.g, color.b)
                        point:SetAlpha(1)
                    else
                        point.tex:SetVertexColor(color.r * 0.5, color.g * 0.5, color.b * 0.5)
                        point.cooldown:SetCooldown(start, duration)
                        point.cooldown:Show()
                    end
                elseif config.mode == "AURA" then
                    -- Enhancement: Fill up to min(cur, 5)
                    local filled = (i <= cur)
                    if filled then
                        point:SetAlpha(1)
                        point.tex:SetVertexColor(color.r, color.g, color.b)
                    else
                        point:SetAlpha(0.2)
                        point.tex:SetVertexColor(color.r, color.g, color.b)
                    end

                    -- Overcap Border Color
                    if config.overcapColor and cur >= displayMax then
                        if point.SetBackdropBorderColor then
                            point:SetBackdropBorderColor(config.overcapColor.r, config.overcapColor.g,
                                config.overcapColor.b)
                        end
                    else
                        if point.SetBackdropBorderColor then
                            point:SetBackdropBorderColor(0, 0, 0)
                        end
                    end
                else
                    -- Standard Power
                    if i <= cur then
                        point:SetAlpha(1)
                        point.tex:SetVertexColor(color.r, color.g, color.b)
                    else
                        point:SetAlpha(0.2)
                        point.tex:SetVertexColor(color.r, color.g, color.b)
                    end
                end
            end
        end
        element:Show()
    end

    -- Event Handling
    local events = { "PLAYER_ENTERING_WORLD", "UNIT_POWER_UPDATE", "UNIT_DISPLAYPOWER", "SPELLS_CHANGED" }
    if class == "DRUID" then
        table.insert(events, "UPDATE_SHAPESHIFT_FORM")
    end
    if class == "DEATHKNIGHT" then
        table.insert(events, "RUNE_POWER_UPDATE")
    elseif class == "SHAMAN" or class == "DEMONHUNTER" then
        table.insert(events, "UNIT_AURA")
    end

    frame:HookScript("OnEvent", function(self, event, unit)
        if (unit and unit ~= "player") then return end
        Update()
    end)

    for _, e in ipairs(events) do
        frame:RegisterEvent(e)
        if e == "UNIT_AURA" or e == "UNIT_POWER_UPDATE" then
            frame:RegisterUnitEvent(e, "player")
        end
    end

    frame.UpdateClassPowerLayout = function()
        -- Get DB
        local db
        if RoithiUIDB and RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[frame.unit] then
            db = RoithiUIDB.UnitFrames[frame.unit]
        else
            return -- No config found, probably not initialized yet
        end

        local detached = db.classPowerDetached
        local height = db.classPowerHeight or 12
        local width = db.width or
            frame:GetWidth() -- Use frame width if not specified, though db.width usually exists for UF

        if frame.isInEditMode then
            element.isInEditMode = true
        end

        element:SetHeight(height)
        -- element:SetWidth(width) -- Width is dynamic in UpdateLayout usually? No, element width calls UpdateLayout math.
        -- We should update width here too if detached?
        -- UpdateLayout uses frame:GetWidth().
        -- If we want Independent Width for Detached Bar, we need a setting for it.
        -- For now, inherit width.

        if detached then
            element:SetParent(UIParent)
            local point = db.classPowerPoint or "CENTER"
            local x = db.classPowerX or 0
            local y = db.classPowerY or -50
            element:ClearAllPoints()
            element:SetPoint(point, UIParent, point, x, y)

            local width = db and db.classPowerWidth or frame:GetWidth()
            element:SetWidth(width)
        else
            element:SetParent(frame)
            element:ClearAllPoints()
            -- Anchor to Power Bar if exists and visible?
            -- Or Frame?
            -- Default anchoring:
            local powerHeight = (frame.Power and frame.Power:IsShown()) and frame.Power:GetHeight() or 0
            -- If power is detached, frame.Power is visible but elsewhere.
            -- If we want to stack on frame, we might need to check if Power is detached.

            -- Keep simple: Always anchor to Power for now as per original logic,
            -- creating a stack. If Power moves, this moves.
            -- Stack: Frame(Health) -> Power(Below) -> ClassPower(Below)
            element:SetPoint("TOPLEFT", frame.Power, "BOTTOMLEFT", 0, -4)
            element:SetPoint("TOPRIGHT", frame.Power, "BOTTOMRIGHT", 0, -4)
        end

        -- Trigger content update to refresh point sizes
        Update()
    end

    -- Edit Mode Registration
    local LEM = LibStub("LibEditMode", true)
    if LEM then
        -- Name for Selection Overlay
        element.editModeName = "Class Power"

        local defaults = { point = "CENTER", x = 0, y = -100 }
        local function OnPosChanged(f, layoutName, point, x, y)
            local db = RoithiUIDB and RoithiUIDB.UnitFrames and RoithiUIDB.UnitFrames[frame.unit]

            -- If not detached, ignore movement
            if not db or not db.classPowerDetached then
                frame.UpdateClassPowerLayout()
                return
            end

            if db then
                db.classPowerPoint = point
                db.classPowerX = x
                db.classPowerY = y
            end
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
        end

        -- Use unique name for LEM
        LEM:AddFrame(element, OnPosChanged, defaults)
        element:SetMovable(true)

        LEM:RegisterCallback('enter', function()
            -- We always want to allow interaction if enabled?
            -- Or only if detached?
            -- EditMode usually allows moving everything if selected.
            -- If we ONLY allow moving when detached, we should communicate that.
            -- But standard behavior is: You can select it. If you drag it, it becomes "detached" (if logic supported it).
            -- Here, we rely on the checkbox. So if not detached, OnPosChanged snaps back.

            -- We force show so user can see what they are configuring
            element.isInEditMode = true
            Update()
        end)

        LEM:RegisterCallback('exit', function()
            element.isInEditMode = false
            Update()
        end)
    end

    frame:HookScript("OnShow", Update)

    -- Dynamic Layout Updates
    element:HookScript("OnShow",
        function() if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end end)
    element:HookScript("OnHide",
        function() if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end end)

    frame.UpdateClassPowerLayout() -- Initial Layout Update
end
