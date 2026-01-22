local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
local LEM = LibStub("LibEditMode", true)

-- Constants
local BOSS_SPACING = 30
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

        LEM:RegisterCallback('enter', function()
            driver.isInEditMode = true

            -- Show Overlays & Ghosts
            for i = 1, 5 do
                if overlays[i] then overlays[i]:Show() end

                local f = self.units["boss" .. i]
                if f and not f:IsShown() then
                    f.forceShowEditMode = true
                    f:Show()
                end
            end
        end)

        LEM:RegisterCallback('exit', function()
            driver.isInEditMode = false

            -- Hide Overlays & Ghosts
            for i = 1, 5 do
                if overlays[i] then overlays[i]:Hide() end

                local f = self.units["boss" .. i]
                if f and f.forceShowEditMode then
                    f.forceShowEditMode = nil
                    f:Hide()
                end
            end
        end)
    end

    -- 2. Create Passengers (Boss 2-5)
    for i = 2, 5 do
        local unit = "boss" .. i
        self:CreateStandardLayout(unit, "Boss " .. i, true) -- Skip EditMode

        local passenger = self.units[unit]
        if passenger then
            passenger:ClearAllPoints()
            -- Bottom-to-Top: Boss 2 Bottom -> Boss 1 Top
            local prev = self.units["boss" .. (i - 1)]
            passenger:SetPoint("BOTTOM", prev, "TOP", 0, BOSS_SPACING)

            passenger:SetMovable(false) -- Passengers locked to Driver
            -- Actually hooking script works better if EnableMouse is true.
        end
    end

    -- 3. Unified Drag Logic
    -- Function to Save Driver Position
    local function SaveDriverPosition()
        local point, _, _, x, y = driver:GetPoint()
        if not RoithiUI.db.profile.UnitFrames[unit1] then
            RoithiUI.db.profile.UnitFrames[unit1] = {}
        end
        local dDb = RoithiUI.db.profile.UnitFrames[unit1]
        dDb.point = point
        dDb.x = x
        dDb.y = y
    end

    -- Attach to ALL frames (including Driver)
    -- Attach Proxy Drag to ALL frames
    for i = 1, 5 do
        local f = self.units["boss" .. i]
        if f then
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")

            -- Use SetScript to ensure we own the drag behavior
            f:SetScript("OnDragStart", function()
                if driver.isInEditMode then
                    driver:StartMoving()
                end
            end)

            f:SetScript("OnDragStop", function()
                if driver.isInEditMode then
                    driver:StopMovingOrSizing()
                    SaveDriverPosition()
                end
            end)
        end
    end
end

function UF:ToggleBossTestMode()
    self.BossTestMode = not self.BossTestMode

    if self.BossTestMode then
        print("|cff00ccffRoithiUI:|r Boss Frames Test Mode: |cff00ff00ON|r")
        for i = 1, 5 do
            local frame = self.units["boss" .. i]
            if frame then
                UnregisterUnitWatch(frame)
                frame.forceShowTest = true
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
        print("|cff00ccffRoithiUI:|r Boss Frames Test Mode: |cffff0000OFF|r")
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
