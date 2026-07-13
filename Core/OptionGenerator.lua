local _, ns = ...
local RoithiUI = _G.RoithiUI

local OptionGenerator = {}
ns.OptionGenerator = OptionGenerator
RoithiUI.OptionGenerator = OptionGenerator

function OptionGenerator:GenerateAceConfig(schema, getDB, onChange, extraArgs)
    local args = {}
    for i, item in ipairs(schema) do
        if not item.showIn or item.showIn == "options" or item.showIn == "both" then
            local option = {
                name = item.name,
                order = i,
            }
            if item.type == "range" then
                option.type = "range"
                option.min = item.min
                option.max = item.max
                option.step = item.step
            elseif item.type == "toggle" then
                option.type = "toggle"
            elseif item.type == "select" then
                option.type = "select"
                option.values = item.values
            end

            -- Getter / Setter
            option.get = item.get or function()
                local db = getDB()
                if not db then return item.default end
                if db[item.key] == nil then return item.default end
                return db[item.key]
            end
            option.set = item.set or function(_, val)
                local db = getDB()
                if db then
                    db[item.key] = val
                end
                if onChange then onChange(item.key, val) end
            end

            args[item.key] = option
        end
    end

    if extraArgs then
        for k, v in pairs(extraArgs) do
            args[k] = v
        end
    end

    return args
end

function OptionGenerator:GenerateLEMConfig(schema, getDB, onChange, LEM)
    local settings = {}
    for _, item in ipairs(schema) do
        if item.showIn == "editmode" or item.showIn == "both" then
            local kind
            if item.type == "range" then
                kind = LEM.SettingType.Slider
            elseif item.type == "toggle" then
                kind = LEM.SettingType.Checkbox
            elseif item.type == "select" then
                kind = LEM.SettingType.Dropdown
            end

            if kind then
                local setting = {
                    name = item.name,
                    kind = kind,
                    default = item.default,
                    get = item.get or function()
                        local db = getDB()
                        if not db then return item.default end
                        if db[item.key] == nil then return item.default end
                        return db[item.key]
                    end,
                    set = item.set or function(_, val)
                        local db = getDB()
                        if db then
                            db[item.key] = val
                        end
                        if onChange then onChange(item.key, val) end
                    end,
                }

                if item.type == "range" then
                    setting.minValue = item.min
                    setting.maxValue = item.max
                    setting.valueStep = item.step
                    setting.formatter = item.formatter or function(v) return string.format("%.0f", v) end
                elseif item.type == "select" then
                    setting.options = item.values
                end

                table.insert(settings, setting)
            end
        end
    end
    return settings
end
