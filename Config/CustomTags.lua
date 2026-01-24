local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local Config = RoithiUI.Config or {}
RoithiUI.Config = Config

local function RefreshConfig()
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR then ACR:NotifyChange("RoithiUI") end
end

local function SanitizeInput(text)
    if not text then return "" end
    -- Remove non-printable characters/control codes to prevent breakage
    -- Keep color codes (|c) but maybe ensure they are safe?
    -- For now just ensure no newlines or crazy invisible chars
    return text:gsub("[\n\r]", ""):trim()
end
function RoithiUI.Config.GetCustomTagsOptions()
    local options = {
        type = "group",
        name = "Custom Tags",
        args = {
            intro = {
                type = "description",
                name = "Configure custom text tags for unit frames. You can add as many tags as you like.\n\n" ..
                    "|cffffd100Available Tags:|r\n" ..
                    "  |cff00ff00@name|r - Unit Name\n" ..
                    "  |cff00ff00@level|r - Unit Level\n" ..
                    "  |cff00ff00@class|r - Unit Class\n" ..
                    "  |cff00ff00@race|r - Unit Race\n" ..
                    "  |cff00ff00@status|r - Dead, Ghost, or Offline\n" ..
                    "  |cff00ff00@creature|r - Creature type/family\n" ..
                    "  |cff00ff00@classification|r - Boss, Elite, etc.\n\n" ..
                    "|cffffd100Health & Power:|r\n" ..
                    "  |cff00ff00@health.current|r - Current health\n" ..
                    "  |cff00ff00@health.maximum|r - Max health\n" ..
                    "  |cff00ff00@health.percent|r - Health percentage (e.g. 85.25%)\n" ..
                    "  |cff00ff00@health.missing|r - Missing health\n" ..
                    "  |cff00ff00@power.current|r - Current power\n" ..
                    "  |cff00ff00@power.percent|r - Power percentage\n" ..
                    "  |cff00ff00@power.missing|r - Missing power\n" ..
                    "  |cff00ff00@absorb|r - Total absorbs\n" ..
                    "  |cff00ff00@power.class|r - Class Power (Resources/Runes)\n" ..
                    "  |cff00ff00@power.class.max|r - Max Class Power\n" ..
                    "  |cff00ff00@power.class.percent|r - Class Power %\n" ..
                    "  |cff00ff00@power.add.current|r - Add. Power (Mana/Alt)\n" ..
                    "  |cff00ff00@power.add.maximum|r - Max Add. Power\n" ..
                    "  |cff00ff00@power.add.percent|r - Add. Power %\n" ..
                    "  |cff00ff00@power.add.missing|r - Missing Add. Power\n" ..
                    "  |cff00ff00@power.stagger|r - Current Stagger\n" ..
                    "  |cff00ff00@power.stagger.percent|r - Stagger % of HP\n\n" ..
                    "|cffffd100Modifiers:|r\n" ..
                    "  Append |cff00ff00:short|r to any numeric tag to abbreviate values (e.g. |cff00ff00@health.current:short|r -> 1.2M)\n\n" ..
                    "|cffffd100Conditions:|r\n" ..
                    "  Use |cff00ff00[type](tags)|r to show tags only for specific power types.\n" ..
                    "  Example: |cff00ff00[mana](@power.percent) @power.current|r\n" ..
                    "  Use |cff00ff00{class:spec}(tags)|r to show tags only for specific spec.\n" ..
                    "  Example: |cff00ff00{DH:3}(@power.class)|r\n" ..
                    "  (Shows % if Mana class, otherwise current value)",
                order = 0,
            },
        },
    }

    local units = {
        { "player",       "Player" },
        { "target",       "Target" },
        { "targettarget", "Target of Target" },
        { "focus",        "Focus" },
        { "focustarget",  "Focus Target" }, -- If supported by core
        { "pet",          "Pet" },
        { "boss1",        "Boss Frames" },
    }

    for i, u in ipairs(units) do
        local unit, label = u[1], u[2]

        local function GetDB()
            if not RoithiUI.db.profile.UnitFrames[unit] then RoithiUI.db.profile.UnitFrames[unit] = {} end
            if not RoithiUI.db.profile.UnitFrames[unit].tags then RoithiUI.db.profile.UnitFrames[unit].tags = {} end
            return RoithiUI.db.profile.UnitFrames[unit].tags
        end

        local unitGroup = {
            type = "group",
            name = label,
            order = i,
            args = {
                addTag = {
                    type = "execute",
                    name = "Add New Tag",
                    desc = "Add a new text tag to this unit frame.",
                    order = 0,
                    func = function()
                        local tags = GetDB()
                        table.insert(tags, {
                            enabled = true,
                            formatString = "@health.current",
                            order = 10,
                            point = "CENTER",
                            anchorTo = "Frame",
                            x = 0,
                            y = 0
                        })
                        ns.RefreshUnitFrame(unit)
                        RefreshConfig()
                    end,
                },
            }
        }

        local tags = GetDB()
        for idx, tagConfig in ipairs(tags) do
            unitGroup.args["tag" .. idx] = {
                type = "group",
                name = "Tag " .. idx .. (tagConfig.formatString and (" - " .. tagConfig.formatString) or ""),
                order = idx + 10,
                inline = false,
                args = {
                    delete = {
                        type = "execute",
                        name = "Delete Tag",
                        desc = "Remove this tag.",
                        order = 0,
                        confirm = true,
                        func = function()
                            table.remove(tags, idx)
                            ns.RefreshUnitFrame(unit)
                            RefreshConfig()
                        end,
                    },
                    enabled = {
                        type = "toggle",
                        name = "Enable",
                        order = 1,
                        get = function() return tagConfig.enabled end,
                        set = function(_, v)
                            tagConfig.enabled = v
                            ns.RefreshUnitFrame(unit)
                        end,
                    },
                    text = {
                        type = "input",
                        name = "Format Text",
                        desc = "E.g. @health.current or @name",
                        width = "double",
                        order = 2,
                        get = function() return tagConfig.formatString end,
                        set = function(_, v)
                            tagConfig.formatString = SanitizeInput(v)
                            ns.RefreshUnitFrame(unit)
                            RefreshConfig() -- Update header name
                        end,
                    },
                    fontSize = {
                        type = "range",
                        name = "Font Size",
                        order = 2.5, -- Between Text and Anchor
                        min = 8,
                        max = 32,
                        step = 1,
                        get = function() return tagConfig.fontSize or 12 end,
                        set = function(_, v)
                            tagConfig.fontSize = v
                            ns.RefreshUnitFrame(unit)
                        end,
                    },
                    order = {
                        type = "range",
                        name = "Draw Order",
                        desc = "Higher numbers draw on top.",
                        order = 2.6,
                        min = 1,
                        max = 100,
                        step = 1,
                        get = function() return tagConfig.order or 10 end,
                        set = function(_, v)
                            tagConfig.order = v
                            ns.RefreshUnitFrame(unit)
                        end,
                    },
                    anchorTo = {
                        type = "select",
                        name = "Anchor To",
                        order = 3,
                        values = {
                            ["Frame"] = "Frame",
                            ["Health"] = "Health Bar",
                            ["Power"] = "Power Bar",
                            ["ClassPower"] = "Class Power",
                            ["AdditionalPower"] = "Add. Power"
                        },
                        get = function() return tagConfig.anchorTo or "Frame" end,
                        set = function(_, v)
                            tagConfig.anchorTo = v
                            ns.RefreshUnitFrame(unit)
                        end,
                    },
                    point = {
                        type = "select",
                        name = "Point",
                        order = 4,
                        values = {
                            ["CENTER"] = "Center",
                            ["TOP"] = "Top",
                            ["BOTTOM"] = "Bottom",
                            ["LEFT"] = "Left",
                            ["RIGHT"] = "Right",
                            ["TOPLEFT"] = "Top Left",
                            ["TOPRIGHT"] = "Top Right",
                            ["BOTTOMLEFT"] = "Bottom Left",
                            ["BOTTOMRIGHT"] = "Bottom Right"
                        },
                        get = function() return tagConfig.point or "CENTER" end,
                        set = function(_, v)
                            tagConfig.point = v
                            ns.RefreshUnitFrame(unit)
                        end,
                    },
                    x = {
                        type = "range",
                        name = "X Offset",
                        order = 5,
                        min = -300,
                        max = 300,
                        step = 1,
                        get = function() return tagConfig.x or 0 end,
                        set = function(_, v)
                            tagConfig.x = v
                            ns.RefreshUnitFrame(unit)
                        end,
                    },
                    y = {
                        type = "range",
                        name = "Y Offset",
                        order = 6,
                        min = -200,
                        max = 200,
                        step = 1,
                        get = function() return tagConfig.y or 0 end,
                        set = function(_, v)
                            tagConfig.y = v
                            ns.RefreshUnitFrame(unit)
                        end,
                    },
                }
            }
        end

        options.args[unit] = unitGroup
    end

    return options
end
