local addonName, ns = ...
if ns.skipLoad then return end

local OptionsEngine = {}
ns.OptionsEngine = OptionsEngine
OptionsEngine.modules = {}

--- Register a module's option schema
---@param moduleKey string Unique identifier (e.g. "castbars", "auras", "unitframes")
---@param schema table AceConfig schema table containing name, order, options/args
function OptionsEngine:RegisterModuleOptions(moduleKey, schema)
    if not moduleKey or not schema then return end
    self.modules[moduleKey] = schema
end

--- Recursively filter an options tree for AceConfig
local function FilterAceArgs(argsTable)
    local result = {}
    for key, opt in pairs(argsTable) do
        local scope = opt.scope or "both"
        if scope == "ace" or scope == "both" then
            local copy = {}
            for k, v in pairs(opt) do
                if k ~= "scope" then
                    copy[k] = v
                end
            end
            if copy.type == "group" and copy.args then
                copy.args = FilterAceArgs(copy.args)
            end
            result[key] = copy
        end
    end
    return result
end

--- Compile all registered schemas into AceConfig args format
---@return table Compiled AceConfig args tree
function OptionsEngine:CompileAceConfig()
    local args = {}
    for moduleKey, schema in pairs(self.modules) do
        local groupArgs = {}
        local root = schema.options or schema.args or schema
        if type(root) == "table" then
            groupArgs = FilterAceArgs(root)
        end
        args[moduleKey] = {
            type = "group",
            name = schema.name or moduleKey,
            order = schema.order or 10,
            args = groupArgs,
        }
    end
    return args
end

--- Traverse an options table recursively to collect LEM setting objects
local function CollectLEMOptions(argsTable, settings, LEM, frame, parentGroup)
    if not argsTable then return end
    for _, opt in pairs(argsTable) do
        if type(opt) == "table" then
            local scope = opt.scope or "both"
            if scope == "lem" or scope == "both" then
                local settingName = opt.lemName or opt.name or "Setting"
                local getter = opt.lemGet or opt.get
                local setter = opt.lemSet or opt.set

                local isHidden = function()
                    if parentGroup and parentGroup.expanded == false then return true end
                    if opt.hidden then
                        if type(opt.hidden) == "function" then return opt.hidden() end
                        return opt.hidden
                    end
                    return false
                end

                if opt.type == "group" and opt.args then
                    if opt.name then
                        local group = opt
                        local headerKind = opt.lemKind or (LEM.SettingType and LEM.SettingType.CollapsibleHeader) or "expander"
                        table.insert(settings, {
                            kind = headerKind,
                            name = settingName,
                            get = function() return group.expanded ~= false end,
                            set = function(_, v)
                                group.expanded = v
                                if frame then
                                    local freshSettings = {}
                                    CollectLEMOptions(argsTable, freshSettings, LEM, frame)
                                    if LEM.AddFrameSettings then LEM:AddFrameSettings(frame, freshSettings) end
                                    if LEM.RefreshFrameSettings then LEM:RefreshFrameSettings(frame) end
                                end
                            end,
                        })
                    end
                    CollectLEMOptions(opt.args, settings, LEM, frame, opt)
                elseif opt.type == "toggle" then
                    table.insert(settings, {
                        name = settingName,
                        kind = opt.lemKind or (LEM.SettingType and LEM.SettingType.Checkbox) or "checkbox",
                        get = function()
                            if getter then return getter() end
                        end,
                        set = function(_, v)
                            if setter then setter(nil, v) end
                        end,
                        hidden = isHidden,
                    })
                elseif opt.type == "range" then
                    table.insert(settings, {
                        name = settingName,
                        kind = opt.lemKind or (LEM.SettingType and LEM.SettingType.Slider) or "slider",
                        minValue = opt.min or 0,
                        maxValue = opt.max or 100,
                        valueStep = opt.step or 1,
                        get = function()
                            if getter then return getter() end
                        end,
                        set = function(_, v)
                            if setter then setter(nil, v) end
                        end,
                        formatter = opt.formatter or function(v) return string.format("%.1f", v) end,
                        hidden = isHidden,
                    })
                elseif opt.type == "select" and opt.values then
                    local valFunc = opt.values
                    local valuesList = {}
                    local rawValues = (type(valFunc) == "function") and valFunc() or valFunc
                    if rawValues then
                        for k, v in pairs(rawValues) do
                            table.insert(valuesList, { text = tostring(v), value = k })
                        end
                    end
                    table.insert(settings, {
                        name = settingName,
                        kind = opt.lemKind or (LEM.SettingType and LEM.SettingType.Dropdown) or "dropdown",
                        values = valuesList,
                        get = function()
                            if getter then return getter() end
                        end,
                        set = function(_, v)
                            if setter then setter(nil, v) end
                        end,
                        hidden = isHidden,
                    })
                end
            end
        end
    end
end

--- Register LibEditMode extra settings for a frame using a registered module schema
---@param frame table Frame registered in LibEditMode
---@param moduleKey string Module identifier
---@param unitKey? string Optional unit sub-key (e.g. "player", "boss1")
function OptionsEngine:RegisterLEMOptions(frame, moduleKey, unitKey)
    local LEM = LibStub("LibEditMode-Roithi", true) or LibStub("LibEditMode-1.0", true)
    if not LEM or not frame then return end

    if not self.modules[moduleKey] then
        if RoithiUI and RoithiUI.debug then
            print(string.format("|cffff8800[RoithiUI OptionsEngine]|r Module '%s' not registered in OptionsEngine!", tostring(moduleKey)))
        end
        return
    end

    local schema = self.modules[moduleKey]
    local root = schema.options or schema.args or schema
    if not root then return end

    local settings = {}
    local targetTree = root

    if unitKey then
        local searchTree = root.args or root
        if searchTree[unitKey] then
            local unitNode = searchTree[unitKey]
            targetTree = unitNode.args or unitNode
        else
            if RoithiUI and RoithiUI.debug then
                print(string.format("|cffff8800[RoithiUI OptionsEngine]|r Sub-key '%s' not found in module '%s'", tostring(unitKey), tostring(moduleKey)))
            end
        end
    end

    CollectLEMOptions(targetTree, settings, LEM, frame)

    if #settings > 0 then
        if LEM.AddFrameSettings then
            LEM:AddFrameSettings(frame, settings)
        end
        if RoithiUI and RoithiUI.debug then
            print(string.format("|cff00ff00[RoithiUI OptionsEngine]|r Registered %d LEM settings for module '%s' (unit '%s')", #settings, tostring(moduleKey), tostring(unitKey or "all")))
        end
    else
        if RoithiUI and RoithiUI.debug then
            print(string.format("|cffff8800[RoithiUI OptionsEngine]|r 0 LEM settings collected for module '%s' (unit '%s')", tostring(moduleKey), tostring(unitKey or "all")))
        end
    end
end
