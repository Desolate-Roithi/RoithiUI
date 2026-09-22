-- Libs/LibRoithi/LibEditModeExtension.lua
-- Bridges missing methods in LibEditMode widgets and provides self-healing.

local lib = LibStub("LibEditMode-Roithi", true)
if not lib then return end

-- 1. Bridge for Expander Refresh Nil Value
local expanderPool = lib.internal:GetPool(lib.SettingType.Expander)
if expanderPool then
    local oldAcquire = expanderPool.Acquire
    expanderPool.Acquire = function(self, parent)
        local frame, isNew = oldAcquire(self, parent)

        -- Add missing Refresh method if it's missing (it usually is in v14)
        if not frame.Refresh then
            frame.Refresh = function(s)
                local data = s.setting
                if not data then return end

                local layout = lib:GetActiveLayoutName()

                if type(data.disabled) == "function" then
                    s:SetEnabled(not data.disabled(layout))
                else
                    s:SetEnabled(not data.disabled)
                end

                if type(data.hidden) == "function" then
                    s:SetShown(not data.hidden(layout))
                else
                    s:SetShown(not data.hidden)
                end
            end
        end

        -- Add missing SetEnabled for visual feedback
        if not frame.SetEnabled then
            frame.SetEnabled = function(s, enabled)
                s.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
                s:EnableMouse(enabled)
            end
        end

        return frame, isNew
    end
end

-- 1b. Bridge for Slider Refresh Value Update
local sliderPool = lib.internal:GetPool(lib.SettingType.Slider)
if sliderPool then
    local oldAcquire = sliderPool.Acquire
    sliderPool.Acquire = function(self, parent)
        local frame, isNew = oldAcquire(self, parent)

        if not frame.isRefreshBridged then
            frame.isRefreshBridged = true
            local oldRefresh = frame.Refresh
            frame.Refresh = function(s)
                if oldRefresh then oldRefresh(s) end
                local data = s.setting
                if data and data.get then
                    local val = data.get(lib:GetActiveLayoutName())
                    if val ~= nil and s.Slider and s.Slider.SetValue then
                        s.initInProgress = true
                        s.Slider:SetValue(val)
                        s.initInProgress = false
                    end
                end
            end
        end

        return frame, isNew
    end
end

-- 2. Stale Closure Protection (Self-Healing)
-- If lib.internal is wiped but lib object persists, we restore basic hooks.
if not lib.internal.IsHealed then
    local oldAddFrame = lib.AddFrame
    lib.AddFrame = function(self, frame, callback, default, name)
        -- Validation check: if internal.dialog is missing, the lib was likely wiped/reloaded dirty
        if not lib.internal.dialog then
            -- Trigger restoration of pools/dialog/widgets if they are missing
            if _G.RoithiUI and _G.RoithiUI.Log then
                _G.RoithiUI:Log("LibEditMode Corruption Detected! Healing...")
            else
                print("|cffff0000[LibRoithi]|r LibEditMode Corruption Detected! Healing...")
            end
        end

        -- Wrap the callback to respect SetMovable(false)
        -- If frame is locked (SetMovable(false)), we should NOT process the drag end.
        local safeCallback = function(f, layoutName, point, x, y)
            local movableVal = true
            local ok, res = pcall(function() return f:IsMovable() end)
            if ok then
                local isSec = (issecretvalue and issecretvalue(res))
                           or (C_Secrets and C_Secrets.IsSecret and C_Secrets.IsSecret(res))
                           or (type(res) == "userdata")
                if not isSec then
                    movableVal = (res == true)
                end
            end

            if not movableVal then
                if _G.RoithiUI and _G.RoithiUI.Log and _G.RoithiUI.db and _G.RoithiUI.db.profile.General.debugMode then
                    _G.RoithiUI:Log("LEM Extension: Ignored Drag on Locked Frame: " .. (f:GetName() or "Anonymous"))
                end
                return
            end
            if callback then callback(f, layoutName, point, x, y) end
        end

        return oldAddFrame(self, frame, safeCallback, default, name)
    end
    lib.internal.IsHealed = true
end

-- 3. Persistent LEM Dialog Position Saving & Restoring
local function SetupPersistentDialogPosition(dialog)
    if not dialog or dialog.isPositionHooked then return end
    dialog.isPositionHooked = true

    dialog:HookScript("OnDragStop", function(self)
        local point, _, relativePoint, x, y = self:GetPoint()
        if _G.RoithiUI and _G.RoithiUI.db and _G.RoithiUI.db.profile then
            _G.RoithiUI.db.profile.LEMDialogPosition = {
                point = point or "CENTER",
                relativePoint = relativePoint or point or "CENTER",
                x = math.floor((x or 0) + 0.5),
                y = math.floor((y or 0) + 0.5),
            }
        end
    end)

    local oldReset = dialog.Reset
    dialog.Reset = function(self)
        if oldReset then oldReset(self) end
        local pos = _G.RoithiUI and _G.RoithiUI.db and _G.RoithiUI.db.profile and _G.RoithiUI.db.profile.LEMDialogPosition
        if pos and pos.point and pos.x and pos.y then
            self:ClearAllPoints()
            self:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
        end
    end

    local pos = _G.RoithiUI and _G.RoithiUI.db and _G.RoithiUI.db.profile and _G.RoithiUI.db.profile.LEMDialogPosition
    if pos and pos.point and pos.x and pos.y then
        dialog:ClearAllPoints()
        dialog:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    end
end

if lib.internal and lib.internal.dialog then
    SetupPersistentDialogPosition(lib.internal.dialog)
end

if lib.internal and lib.internal.CreateDialog then
    local oldCreateDialog = lib.internal.CreateDialog
    lib.internal.CreateDialog = function(self)
        local dialog = oldCreateDialog(self)
        SetupPersistentDialogPosition(dialog)
        return dialog
    end
end

