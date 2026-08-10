local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI", true)

--- Profile Sharing Options (Combined Import / Export) — injected into Profiles tab only
local profileSharingGroup = {
    type = "group",
    name = L["Profile Sharing"],
    desc = L["Export or Import your RoithiUI profile settings as a compressed string."],
    inline = true,
    order = 999,
    args = {
        exportString = {
            type = "input",
            name = L["Your Export String"],
            desc = L["Copy this string to share your profile with others."],
            order = 1,
            multiline = 4,
            get = function()
                local PS = RoithiUI:GetModule("ProfileSharing")
                return PS and PS:ExportProfile() or ""
            end,
            set = function() end,
        },
        importString = {
            type = "input",
            name = L["Paste Import String"],
            desc = L["Paste a RoithiUI profile string here and click Import."],
            order = 2,
            multiline = 4,
            get = function() return RoithiUI.db.profile.tempImportString or "" end,
            set = function(_, v) RoithiUI.db.profile.tempImportString = v end,
        },
        importButton = {
            type = "execute",
            name = L["Import Profile"],
            desc = L["Applying an imported profile will overwrite your current settings and reload the UI."],
            order = 3,
            confirm = true,
            confirmText = L["Applying an imported profile will overwrite your current settings and reload the UI."],
            func = function()
                local str = RoithiUI.db.profile.tempImportString
                if str and str:match("%S") then
                    local PS = RoithiUI:GetModule("ProfileSharing")
                    if PS and PS.ImportProfile then
                        local success, err = PS:ImportProfile(str)
                        if success then
                            RoithiUI.db.profile.tempImportString = nil
                            ReloadUI()
                        else
                            print("|cffff0000[RoithiUI]|r Import failed: " .. tostring(err))
                        end
                    end
                end
            end,
        },
    }
}

ns.GetProfileSharingOptions = function()
    return profileSharingGroup
end
