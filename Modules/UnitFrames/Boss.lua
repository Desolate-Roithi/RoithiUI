local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
local LEM = LibStub("LibEditMode-Roithi", true)

-- Constants

-- Note: Height/Width is generic from CreateStandardLayout -> Defaults

function UF:InitializeBossFrames()
    -- 1. Create Boss 1 (The Driver)
    local unit1 = "boss1"
    -- We allow standard layout to create it, but we need to intercept for special handling?
    -- No, create standard layout does everything we want EXCEPT the linking.
    -- Actually, simpler to create them manually here using the primitives to ensure exact order/linking.

    -- BOSS 1: The Anchor
    -- We pass skipEditMode=false (default) so it registers, BUT we want custom EditMode handler
    -- to show the ghosts. So we might need to skip default and do custom.
    self:CreateStandardLayout(unit1, "Boss 1", true) -- Skip default EM to add custom

    local driver = self.units[unit1]
    if not driver then return end

    -- Load Driver Position (Prioritize DB)
    local db = RoithiUI.db.profile.UnitFrames[unit1]
    if db and db.point then
        driver:ClearAllPoints()
        driver:SetPoint(db.point, UIParent, db.point, db.x or 0, db.y or 0)
    else
        driver:ClearAllPoints()
        driver:SetPoint("RIGHT", UIParent, "RIGHT", -250, 0)
    end

    driver:SetMovable(true)
    driver:SetClampedToScreen(true)

    -- Edit Mode for Driver (Controls All)
    if LEM then
        driver.editModeName = "Boss Frames" -- Label as plural for the user

        -- Create Overlays for ALL 5 frames
        local overlays = {}
        for i = 1, 5 do
            local f = self.units["boss" .. i]
            if f then
                local ov = f:CreateTexture(nil, "OVERLAY")
                ov:SetAllPoints()
                ov:SetColorTexture(0, 0.8, 1, 0.3)
                ov:Hide()
                overlays[i] = ov
            end
        end
        -- Backwards compatibility if something looks for .EditModeOverlay on Driver
        driver.EditModeOverlay = overlays[1]

        -- Logic for Position Saving
        local defaults = { point = "RIGHT", x = -250, y = 0 }
        local function OnPosChanged(f, layoutName, point, x, y)
            if not RoithiUI.db.profile.UnitFrames[unit1] then
                RoithiUI.db.profile.UnitFrames[unit1] = {}
            end
            local dDb = RoithiUI.db.profile.UnitFrames[unit1]
            dDb.point = point
            dDb.x = x
            dDb.y = y

            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
        end

        -- Register Frame
        LEM:AddFrame(driver, OnPosChanged, defaults, "Boss Frames")

        -- Register Settings via Config/LEMConfig/UnitFrames.lua
        -- Register Settings via Config/LEMConfig/BossFrames.lua
        if ns.ApplyLEMBossConfiguration then
            ns.ApplyLEMBossConfiguration(driver, "boss1")
        end

        -- Helper for WYSIWYG
        local function MockUnitValues(f, i)
            if f.Health then
                f.Health:SetMinMaxValues(0, 100)
                f.Health:SetValue(100 - (i * 10))
                f.Health:SetStatusBarColor(0.9, 0.1, 0.1) -- Enemy Red
            end
            if f.Power then
                f.Power:SetMinMaxValues(0, 100)
                f.Power:SetValue(50)
                f.Power:SetStatusBarColor(0.1, 0.1, 0.9) -- Mana Blue
            end
            if f.Name then
                f.Name:SetText("Boss " .. i)
            end
        end

        LEM:RegisterCallback('enter', function()
            driver.isInEditMode = true

            -- Show Overlays & Ghosts
            for i = 1, 5 do
                if overlays[i] then overlays[i]:Show() end

                local f = self.units["boss" .. i]
                -- Strict Check: Only show if enabled
                if f and UF:IsUnitEnabled("boss" .. i) and not InCombatLockdown() then
                    if not f:IsShown() then
                        f.forceShowEditMode = true
                        UnregisterUnitWatch(f) -- Disable oUF secure driver
                        f:Show()

                        -- Inject Mock Data (WYSIWYG)
                        MockUnitValues(f, i)
                    end
                elseif f and not InCombatLockdown() then
                    -- Disabled: Force Hide
                    f:Hide()
                    UnregisterUnitWatch(f)
                end

                -- Refresh Layouts
                if f and f.UpdatePowerLayout then f.UpdatePowerLayout() end
                if f and f.UpdateAuras then f.UpdateAuras() end
            end
        end)

        LEM:RegisterCallback('exit', function()
            driver.isInEditMode = false

            -- Hide Overlays & Ghosts
            for i = 1, 5 do
                if overlays[i] then overlays[i]:Hide() end

                local f = self.units["boss" .. i]
                if not InCombatLockdown() then
                    if f and f.forceShowEditMode then
                        f.forceShowEditMode = nil
                        f:Hide()

                        if UF:IsUnitEnabled("boss" .. i) then
                            RegisterUnitWatch(f) -- Re-enable oUF secure driver
                        else
                            UnregisterUnitWatch(f)
                        end
                    elseif f then
                        -- Fallback for frames that weren't forced shown but might be in bad state
                        if UF:IsUnitEnabled("boss" .. i) then
                            RegisterUnitWatch(f)
                        else
                            UnregisterUnitWatch(f)
                            f:Hide()
                        end
                    end
                end

                -- Refresh Layouts
                if f and f.UpdatePowerLayout then f.UpdatePowerLayout() end
                if f and f.UpdateAuras then f.UpdateAuras() end
            end
        end)
    end

    -- 2. Create Passengers (Boss 2-5)
    for i = 2, 5 do
        local unit = "boss" .. i
        self:CreateStandardLayout(unit, "Boss " .. i, true) -- Skip EditMode
    end

    self:UpdateBossAnchors()
end

function UF:UpdateBossAnchors()
    local db = RoithiUI.db.profile.UnitFrames and RoithiUI.db.profile.UnitFrames["boss1"]
    local spacing = db and db.spacing or 30

    for i = 2, 5 do
        local unit = "boss" .. i
        local frame = self.units[unit]
        local prev = self.units["boss" .. (i - 1)]

        if frame and prev then
            frame:ClearAllPoints()
            -- Bottom-to-Top stack
            frame:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
            frame:SetMovable(false)
        end
    end
end

function UF:ToggleBossTestMode()
    self.BossTestMode = not self.BossTestMode

    if self.BossTestMode then
        RoithiUI:Log("Boss Frames Test Mode: |cff00ff00ON|r")
        for i = 1, 5 do
            local frame = self.units["boss" .. i]
            if frame then
                UnregisterUnitWatch(frame)
                frame.forceShowTest = true
                frame:SetParent(UIParent)
                frame:SetAlpha(1)
                frame:Show()

                -- Fake Data
                if frame.Health then
                    frame.Health:SetMinMaxValues(0, 100)
                    frame.Health:SetValue(100 - (i * 10)) -- Different values
                    frame.Health:SetStatusBarColor(0.8, 0.2, 0.2)
                end

                if frame.Power then
                    frame.Power:SetMinMaxValues(0, 100)
                    frame.Power:SetValue(50)
                    frame.Power:SetStatusBarColor(0.2, 0.2, 0.8)
                end
            end
        end
    else
        RoithiUI:Log("Boss Frames Test Mode: |cffff0000OFF|r")
        for i = 1, 5 do
            local frame = self.units["boss" .. i]
            if frame then
                frame.forceShowTest = nil
                frame:Hide() -- Hide by default, let oUF show if unit exists
                RegisterUnitWatch(frame)
            end
        end
    end
end
