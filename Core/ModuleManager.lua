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
    local profile = RoithiUI.db.profile
    if not profile or not profile.EnabledModules then return end

    for name, module in RoithiUI:IterateModules() do
        local isEnabled = profile.EnabledModules[name]
        if isEnabled == false then
            module:Disable()
        end
    end
end
