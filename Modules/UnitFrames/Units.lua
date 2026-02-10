local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
---@diagnostic disable-next-line: undefined-field
local oUF = ns.oUF or _G.oUF

local LEM = LibStub("LibEditMode-Roithi", true)

function UF:CreateUnitFrame(unit, name, skipEditMode)
    local frameName = "Roithi" .. (name or unit:gsub("^%l", string.upper))
    local frame = oUF:Spawn(unit, frameName)
    if not self.units then self.units = {} end
    self.units[unit] = frame

    -- Edit Mode Registration
    if LEM and not skipEditMode then
        frame.editModeName = name or unit

        -- Register for Layout Persistence
        local defaults = { point = "CENTER", x = 0, y = 0 }
        local function OnPosChanged(f, layoutName, point, x, y)
            if not f.unit then return end
            -- Save to DB
            local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[f.unit]
            if db then
                db.point = point
                db.x = x
                db.y = y
            end
        end -- Close OnPosChanged





        -- Selection Overlay
        local overlay = frame:CreateTexture(nil, "OVERLAY")
        overlay:SetAllPoints()
        overlay:SetColorTexture(0, 0.8, 1, 0.3)
        overlay:Hide()
        frame.EditModeOverlay = overlay

        LEM:RegisterCallback('enter', function()
            frame.isInEditMode = true
            overlay:Show()

            -- FIX: ALWAYS Unregister UnitWatch in Edit Mode to allow manual Show/Hide
            UnregisterUnitWatch(frame)

            if UF:IsUnitEnabled(unit) then
                if not frame:IsShown() then
                    frame.forceShowEditMode = true
                    frame:Show()
                end
            else
                -- Strict: If disabled, ensure it is HIDDEN and Unregistered
                frame:Hide()
                UnregisterUnitWatch(frame)
                return -- Stop processing
            end

            -- Trigger layout updates on sub-elements
            if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
            if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
        end)

        LEM:RegisterCallback('exit', function()
            frame.isInEditMode = false
            overlay:Hide()
            if frame.forceShowEditMode then
                frame.forceShowEditMode = nil
                frame:Hide()
                -- FIX: Flicker - Restore UnitWatch
                if UF:IsUnitEnabled(unit) then
                    RegisterUnitWatch(frame)
                end
            elseif UF:IsUnitEnabled(unit) then
                -- Even if not forced, ensure we restore Watch if enabled
                RegisterUnitWatch(frame)
            else
                -- Ensure disabled
                UnregisterUnitWatch(frame)
                frame:Hide()
            end

            -- Refresh
            if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
            if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
        end)
    end

    return frame
end

function UF:UpdateFrameFromSettings(unit)
    local frame = self.units[unit]
    if not frame then return end
    local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames[unit]

    -- Special Handling for Boss Frames (Inheritance)
    -- Boss 2-5 inherit visual settings from Boss 1
    if string.match(unit, "^boss[2-5]$") then
        local driverDB = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames["boss1"]
        if driverDB then
            -- We construct a composite DB for this update
            -- Use specific unit DB for position (if any), but Driver DB for dimensions
            local specificDB = db or {}
            db = setmetatable({}, {
                __index = function(_, k)
                    if k == "width" or k == "height" then
                        return (driverDB and driverDB[k]) or 180 -- Fallback
                    end
                    return specificDB[k]
                end
            })
        end
    end

    -- Defaults
    local defW, defH = 200, 50
    if string.match(unit, "boss") then
        defW, defH = 180, 40
    elseif unit == "targettarget" or unit == "focustarget" or unit == "pet" then
        defW, defH = 120, 30
    end

    -- Fix: Use separate local variables for final values, handling nil DB gracefully
    local width = (db and db.width and db.width > 0) and db.width or defW
    local height = (db and db.height and db.height > 0) and db.height or defH



    frame:SetWidth(width)
    frame:SetHeight(height)

    -- Update position (SKIP for boss 2-5, managed by Boss.lua)
    if not string.match(unit, "^boss[2-5]$") then
        local point = (db and db.point) or "CENTER"
        local x = (db and db.x) or 0
        local y = (db and db.y) or 0

        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, point, x, y)
    end

    -- Update Elements Live
    if self.UpdateHealthBarSettings then self:UpdateHealthBarSettings(frame) end
    if self.UpdatePowerBarSettings then self:UpdatePowerBarSettings(frame) end
    if self.UpdateClassPowerSettings then self:UpdateClassPowerSettings(frame) end
    if self.UpdateTags then self:UpdateTags(frame) end
    if self.UpdateIndicators then self:UpdateIndicators(frame) end
    if self.UpdateAuras then self:UpdateAuras(frame) end
    if self.UpdateAdditionalPowerSettings then self:UpdateAdditionalPowerSettings(frame) end
end

function UF:IsUnitEnabled(unit)
    if not RoithiUI.db.profile.UnitFrames then return true end
    if not RoithiUI.db.profile.UnitFrames[unit] then return true end
    return RoithiUI.db.profile.UnitFrames[unit].enabled ~= false
end

function UF:ShouldCreate(unit)
    -- Lazy Creation: Only create if enabled in DB
    return self:IsUnitEnabled(unit)
end

-- Helper for Restoration
function UF:RestoreBlizzardFrame(unit)
    local blizzFrame
    if unit == "player" then
        blizzFrame = PlayerFrame
    elseif unit == "target" then
        blizzFrame = TargetFrame
    elseif unit == "focus" then
        blizzFrame = FocusFrame
    elseif unit == "pet" then
        blizzFrame = PetFrame
        -- Expand as needed
    end

    if blizzFrame then
        -- oUF disables by parenting to HiddenParent or checking DisableBlizzard
        -- We try to restore typical state
        -- NOTE: This might fight oUF if we don't re-parent?
        -- oUF usually SetParents to a hidden frame. We set back to UIParent.
        if blizzFrame:GetParent() ~= UIParent then
            blizzFrame:SetParent(UIParent)
        end
        blizzFrame:SetAlpha(1)
        if not blizzFrame:IsShown() and UnitExists(unit) then
            blizzFrame:Show()
        end
        -- Some frames need re-registering events if oUF unregistered them?
        -- oUF generally doesn't Unregister events on Blizzard frames, just Hides them.
    end
end

function UF:ToggleFrame(unit, enabled)
    local frame = self.units[unit]

    if enabled then
        -- 1. Enable / Create Path
        -- Lazy Create if missing
        if not frame then
            -- Need to know friendly name?
            -- CreateStandardLayout requires name.
            -- We can infer or map it.
            local names = {
                player = "Player",
                target = "Target",
                focus = "Focus",
                pet = "Pet",
                targettarget = "Target of Target",
                focustarget = "Focus Target",
            }
            if string.match(unit, "boss") then
                -- Delegate to Boss Module logic to ensure Driver/Passengers are linked correctly
                if self.InitializeBossFrames then self:InitializeBossFrames() end
                frame = self.units[unit]
            else
                self:CreateStandardLayout(unit, names[unit] or unit)
                frame = self.units[unit]
            end
        end

        if not frame then return end -- Creation failed?

        if frame.Enable then frame:Enable() end
        RegisterUnitWatch(frame) -- Drive visibility

        -- Let oUF decide show/hide based on UnitExists, but force update
        if UnitExists(unit) then frame:Show() end

        -- Disable Blizzard Frame (Ensure it stays hidden)
        if self.DisableBlizzard then
            local oUF = _G.oUF
            if oUF and oUF.DisableBlizzard then
                oUF:DisableBlizzard(unit)
            end
        end
    else
        -- 2. Disable Path
        if not frame then return end -- If never created, nothing to disable

        UnregisterUnitWatch(frame)
        frame:Hide()
        if frame.Disable then frame:Disable() end

        -- FIX: Auto-Detach Castbar if it should remain enabled
        -- "when hiding the frame the castbar should detatch and stay enabled"
        if ns.SetCastbarAttachment and RoithiUI.db.profile.Castbar then
            local cbDB = RoithiUI.db.profile.Castbar[unit]
            if cbDB and cbDB.enabled then
                -- Check if currently attached
                if not cbDB.detached then
                    cbDB.detached = true
                    ns.SetCastbarAttachment(unit, false)
                    RoithiUI:Log("Auto-Detached " .. unit .. " Castbar to keep it visible.")
                end
            end
        end

        -- FIX: Restore Blizzard Frame if we disable ours
        self:RestoreBlizzardFrame(unit)
    end
end

function UF:CreateStandardLayout(unit, name, skipEditMode)
    if not self:ShouldCreate(unit) then return end

    local frame = self:CreateUnitFrame(unit, name, skipEditMode)

    -- Default Positions (Can be overridden by DB later)
    -- Apply Settings (Dimensions, Position, etc. from DB)
    if self.UpdateFrameFromSettings then
        self:UpdateFrameFromSettings(unit)
    end

    -- Create ALL elements for every frame to ensure consistent structure
    -- self:CreateHealthBar(frame) -- REMOVED: Core.lua (Shared Style) creates SafeHealth which acts as frame.Health
    self:CreatePowerBar(frame)
    self:CreateHealPrediction(frame)
    self:CreateIndicators(frame)
    self:CreateAuras(frame)
    self:CreateRange(frame)

    self:CreateClassPower(frame)
    self:CreateAdditionalPower(frame)
    self:CreateEncounterResource(frame)
    local TM = self.TagManager
    if TM then
        self:UpdateTags(frame) -- Build tags from DB
        self:EnableTags(frame) -- Hook events
    end

    self:ToggleFrame(unit, self:IsUnitEnabled(unit))
end

function UF:InitializeUnits()
    self:CreateStandardLayout("player", "Player")
    self:CreateStandardLayout("target", "Target")
    self:CreateStandardLayout("focus", "Focus")
    self:CreateStandardLayout("pet", "Pet")
    self:CreateStandardLayout("targettarget", "Target of Target")
    self:CreateStandardLayout("focustarget", "Focus Target")
    self:InitializeBossFrames()
end

-- Hook OnEnable to run initialization
-- We do this here so Elements.lua and Core.lua are already loaded
local baseEnable = UF.OnEnable
function UF:OnEnable()
    if baseEnable then baseEnable(self) end
    self:InitializeUnits()
    if ns.InitializeUnitFrameConfig then ns.InitializeUnitFrameConfig() end
end
