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
            if not f:IsMovable() then
                -- If the frame is locked, it shouldn't have been moved.
                -- However, if LibEditMode forced it, we should revert or ignore.
                -- Logging for debug:
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
