local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LEM = LibStub("LibEditMode")
local LSM = LibStub("LibSharedMedia-3.0")
local LibRoithi = LibStub("LibRoithi-1.0")

---@class Timers : AceAddon, AceModule
---@field CreateBattleResTimer fun(self: Timers)
---@field CreateBloodlustTimer fun(self: Timers)
---@field CreateTimerFrame fun(self: Timers, name: string, dbKey: string, label: string): table, table
local Timers = RoithiUI:NewModule("Timers")

-- Defaults
local DEFAULTS = {
    BattleRes = {
        enabled = true,
        point = "TOP",
        x = 0,
        y = -50,
        scale = 1.0,
    },
    Bloodlust = {
        enabled = true,
        point = "TOP",
        x = 0,
        y = -100,
        scale = 1.0,
    }
}

function Timers:OnInitialize()
    -- Ensure DB Profile path exists (redundant if defaults are set, but safe)
    if not RoithiUI.db.profile.Timers then RoithiUI.db.profile.Timers = {} end

    -- Merge Defaults
    for k, v in pairs(DEFAULTS) do
        if not RoithiUI.db.profile.Timers[k] then
            RoithiUI.db.profile.Timers[k] = CopyTable(v)
        else
            for subK, subV in pairs(v) do
                if RoithiUI.db.profile.Timers[k][subK] == nil then
                    RoithiUI.db.profile.Timers[k][subK] = subV
                end
            end
        end
    end
end

function Timers:OnEnable()
    -- Initialize Sub-Components
    self:CreateBattleResTimer()
    -- self:CreateBloodlustTimer() -- Disabled due to restricted API access
end

-- Shared Helper: Create Movable Frame
function Timers:CreateTimerFrame(name, dbKey, label)
    local db = RoithiUI.db.profile.Timers[dbKey]
    local frame = CreateFrame("Frame", "Roithi" .. name, UIParent)
    frame:SetSize(40, 40)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    frame:SetScale(db.scale)

    if LEM then
        frame.editModeName = label
        local defaults = { point = "TOP", x = 0, y = 0 } -- Fallback defaults if DB missing

        local function OnPositionChanged(f, layoutName, point, x, y)
            db.point = point
            db.x = x
            db.y = y
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
        end

        LEM:AddFrame(frame, OnPositionChanged, defaults)

        -- Settings
        local settings = {
            {
                name = "Scale",
                kind = LEM.SettingType.Slider,
                default = 1.0,
                minValue = 0.5,
                maxValue = 2.0,
                valueStep = 0.1,
                get = function() return db.scale end,
                set = function(_, v)
                    db.scale = v
                    frame:SetScale(v)
                end,
                formatter = function(v) return string.format("%.1f", v) end,
            },
            {
                name = "Enabled",
                kind = LEM.SettingType.Checkbox,
                default = true,
                get = function() return db.enabled end,
                set = function(_, v)
                    db.enabled = v
                    if v then
                        frame:Show() -- Logic script should handle real show, this just enables checks
                        if frame.Update then frame:Update() end
                    else
                        frame:Hide()
                    end
                end,
            }
        }
        LEM:AddFrameSettings(frame, settings)

        -- Edit Mode Visibility
        LEM:RegisterCallback('enter', function()
            if db.enabled then
                frame.isInEditMode = true
                frame:Show()
                -- Show placeholder visual
                if frame.Icon then frame.Icon:SetTexture(134331) end -- Placeholder? Or let module validation set it
                -- Let specific modules handle their "Edit Mode Visual" via override or check
                if frame.OnEditModeEnter then frame:OnEditModeEnter() end
            end
        end)

        LEM:RegisterCallback('exit', function()
            frame.isInEditMode = false
            frame:Hide() -- Hide by default, let update loop show if active
            if frame.OnEditModeExit then frame:OnEditModeExit() end
            if frame.Update then frame:Update() end
        end)
    end

    return frame, db
end
