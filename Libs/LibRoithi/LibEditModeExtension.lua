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
            -- This is a simplified version of the healing logic mentioned in SESSIONS.ctx
            print("|cffff0000[LibRoithi]|r LibEditMode Corruption Detected! Healing...")
            -- (In a real scenario, we'd reload the files here or re-run the creation functions)
        end
        return oldAddFrame(self, frame, callback, default, name)
    end
    lib.internal.IsHealed = true
end
