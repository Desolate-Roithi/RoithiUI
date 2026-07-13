local _, AT = ...
AT = AT or {}

if not _G.EditModeManagerFrame then return end

-- Store original references on AT for restoration in Postload
AT.originalHookSecureFunc = _G.hooksecurefunc
AT.originalManagerHookScript = _G.EditModeManagerFrame.HookScript

if _G.EditModeSystemSettingsDialog then
    AT.originalDialogHookScript = _G.EditModeSystemSettingsDialog.HookScript
end

-- Helper to check if a table or string is one of our target frames
local function IsTargetFrame(tableOrName)
    return tableOrName == _G.EditModeManagerFrame
        or tableOrName == "EditModeManagerFrame"
        or tableOrName == _G.EditModeSystemSettingsDialog
        or tableOrName == "EditModeSystemSettingsDialog"
end

-- 1. Override hooksecurefunc globally (temporarily during LibEditMode load)
_G.hooksecurefunc = function(tableOrName, functionName, hookFunc)
    if IsTargetFrame(tableOrName) then
        local safeHookFunc = function(...)
            local args = { ... }
            C_Timer.After(0, function()
                hookFunc(unpack(args))
            end)
        end
        return AT.originalHookSecureFunc(tableOrName, functionName, safeHookFunc)
    end
    return AT.originalHookSecureFunc(tableOrName, functionName, hookFunc)
end

-- 2. Intercept HookScript on EditModeManagerFrame to capture show/hide handlers
_G.EditModeManagerFrame.HookScript = function(self, script, handler)
    if script == "OnShow" then
        AT.onShowHandler = handler
        return
    end
    if script == "OnHide" then
        AT.onHideHandler = handler
        return
    end
    if AT.originalManagerHookScript then
        return AT.originalManagerHookScript(self, script, handler)
    end
end

-- 3. Intercept HookScript on EditModeSystemSettingsDialog to capture hide handler
if _G.EditModeSystemSettingsDialog then
    _G.EditModeSystemSettingsDialog.HookScript = function(self, script, handler)
        if script == "OnHide" then
            AT.onDialogHideHandler = handler
            return
        end
        if AT.originalDialogHookScript then
            return AT.originalDialogHookScript(self, script, handler)
        end
    end
end
