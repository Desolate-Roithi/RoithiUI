local _, ns = ...
local RoithiUI = _G.RoithiUI

local ModuleManager = {}
ns.ModuleManager = ModuleManager
RoithiUI.ModuleManager = ModuleManager

-- Compile defaults from all modules before AceDB is initialized
function ModuleManager:CompileDefaults(defaultsTable)
    if not defaultsTable.profile then
        defaultsTable.profile = {}
    end
    if not defaultsTable.profile.EnabledModules then
        defaultsTable.profile.EnabledModules = {}
    end

    for name, module in RoithiUI:IterateModules() do
        -- Register default settings if defined on the module
        if module.defaultSettings then
            local key = module.dbKey or name
            defaultsTable.profile[key] = CopyTable(module.defaultSettings)
        end
        -- Default to Enabled = true for modules
        if defaultsTable.profile.EnabledModules[name] == nil then
            defaultsTable.profile.EnabledModules[name] = true
        end
    end
end

-- Initialize and Enable/Disable modules based on their enablement state in DB
function ModuleManager:EnableModules()
    local profile = RoithiUI.db and RoithiUI.db.profile
    if not profile or not profile.EnabledModules then return end

    for name, module in RoithiUI:IterateModules() do
        local isEnabled = profile.EnabledModules[name]
        if isEnabled == false then
            module:Disable()
        else
            if not module:IsEnabled() then
                module:Enable()
            end
        end
    end
end

-- Check whether a module is enabled in the current profile
function ModuleManager:IsModuleEnabled(name)
    local profile = RoithiUI.db and RoithiUI.db.profile
    if not profile or not profile.EnabledModules then return true end
    return profile.EnabledModules[name] ~= false
end

-- Programmatically toggle a module with immediate lifecycle trigger
function ModuleManager:SetModuleEnabled(name, enabled)
    local profile = RoithiUI.db and RoithiUI.db.profile
    if not profile then return end
    profile.EnabledModules = profile.EnabledModules or {}
    profile.EnabledModules[name] = (enabled == true)

    local module = RoithiUI:GetModule(name, true)
    if module then
        if enabled then
            if not module:IsEnabled() then
                module:Enable()
            end
        else
            if module:IsEnabled() then
                module:Disable()
            end
        end
    end
end

