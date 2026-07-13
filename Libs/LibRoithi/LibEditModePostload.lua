local _, AT = ...
AT = AT or {}

-- Restore hooksecurefunc
if AT.originalHookSecureFunc then
    _G.hooksecurefunc = AT.originalHookSecureFunc
    AT.originalHookSecureFunc = nil
end

-- Restore EditModeManagerFrame HookScript
if AT.originalManagerHookScript and _G.EditModeManagerFrame then
    _G.EditModeManagerFrame.HookScript = AT.originalManagerHookScript
    AT.originalManagerHookScript = nil
end

-- Restore EditModeSystemSettingsDialog HookScript
if AT.originalDialogHookScript and _G.EditModeSystemSettingsDialog then
    _G.EditModeSystemSettingsDialog.HookScript = AT.originalDialogHookScript
    AT.originalDialogHookScript = nil
end

-- Create the OnUpdate watcher to safely trigger captured handlers asynchronously without secure stack taint
local watcher = CreateFrame("Frame")
AT.watcher = watcher

local isEditing = false
local dialogShown = false
watcher:SetScript("OnUpdate", function(self)
    if _G.EditModeManagerFrame then
        local isShown = not not _G.EditModeManagerFrame:IsShown()
        if isShown ~= isEditing then
            isEditing = isShown
            if isEditing then
                if AT.onShowHandler then
                    pcall(AT.onShowHandler)
                end
            else
                if AT.onHideHandler then
                    pcall(AT.onHideHandler)
                end
            end
        end
    end
    if _G.EditModeSystemSettingsDialog then
        local isDialogShown = not not _G.EditModeSystemSettingsDialog:IsShown()
        if isDialogShown ~= dialogShown then
            dialogShown = isDialogShown
            if not dialogShown then
                if AT.onDialogHideHandler then
                    pcall(AT.onDialogHideHandler)
                end
            end
        end
    end
end)
