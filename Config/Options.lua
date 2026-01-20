local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local Config = RoithiUI.Config or {}
RoithiUI.Config = Config

-- ----------------------------------------------------------------------------
-- AceConfig Table Definition
-- ----------------------------------------------------------------------------
local function GetOptions()
    local options = {
        type = "group",
        name = "RoithiUI Settings",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    -- Moved from General.lua or new items ca go here
                    intro = {
                        type = "description",
                        name = "General settings for RoithiUI modules.",
                        order = 1,
                    },
                    -- Add global toggles here later if needed
                },
            },
            unitframes = {
                type = "group",
                name = "Unit Frames",
                order = 2,
                args = {
                    intro = {
                        type = "description",
                        name = "Configure text, auras, and indicators for Unit Frames.",
                        order = 1,
                    },
                    -- Units will be populated dynamically or defined below
                },
            },
            castbars = {
                type = "group",
                name = "Castbars",
                order = 3,
                args = {
                    intro = {
                        type = "description",
                        name = "Castbar settings are currently managed via Edit Mode.",
                        order = 1,
                    },
                },
            },
        },
    }

    -- Populate Unit Frame Options
    local units = {
        { "player",       "Player" },
        { "target",       "Target" },
        { "targettarget", "Target of Target" },
        { "focus",        "Focus" },
        { "focustarget",  "Focus Target" },
        { "pet",          "Pet" },
    }

    for i, u in ipairs(units) do
        local unit, label = u[1], u[2]

        -- Helper to get DB
        local function GetDB()
            if not RoithiUIDB.UnitFrames[unit] then RoithiUIDB.UnitFrames[unit] = {} end
            return RoithiUIDB.UnitFrames[unit]
        end

        options.args.unitframes.args[unit] = {
            type = "group",
            name = label,
            order = 10 + i,
            args = {
                -- Tab: Text
                text = {
                    type = "group",
                    name = "Text",
                    order = 1,
                    inline = true,
                    args = {
                        healthFormat = {
                            type = "select",
                            name = "Health Format",
                            order = 1,
                            values = { smart = "Smart", cur = "Current", percent = "Percent", curmax = "Cur / Max", deficit = "Deficit" },
                            get = function() return GetDB().healthTextFormat or "smart" end,
                            set = function(_, v)
                                GetDB().healthTextFormat = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        powerFormat = {
                            type = "select",
                            name = "Power Format",
                            order = 2,
                            values = { smart = "Smart", cur = "Current", percent = "Percent", curmax = "Cur / Max" },
                            get = function() return GetDB().powerTextFormat or "smart" end,
                            set = function(_, v)
                                GetDB().powerTextFormat = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        fontSize = {
                            type = "range",
                            name = "Font Size",
                            order = 3,
                            min = 8,
                            max = 32,
                            step = 1,
                            get = function() return GetDB().fontSize or 12 end,
                            set = function(_, v)
                                GetDB().fontSize = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        -- Positions (X/Y) moved from EditMode? User said: "Move the others to the settings window"
                        -- Ideally offsets are fine here if fine-tuning is needed outside drag-drop.
                        healthX = {
                            type = "range",
                            name = "Health X",
                            min = -100,
                            max = 100,
                            step = 1,
                            get = function() return GetDB().healthTextX or -4 end,
                            set = function(_, v)
                                GetDB().healthTextX = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        healthY = {
                            type = "range",
                            name = "Health Y",
                            min = -50,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().healthTextY or 0 end,
                            set = function(_, v)
                                GetDB().healthTextY = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        powerX = {
                            type = "range",
                            name = "Power X",
                            min = -100,
                            max = 100,
                            step = 1,
                            get = function() return GetDB().powerTextX or -4 end,
                            set = function(_, v)
                                GetDB().powerTextX = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        powerY = {
                            type = "range",
                            name = "Power Y",
                            min = -50,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().powerTextY or 0 end,
                            set = function(_, v)
                                GetDB().powerTextY = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        nameX = {
                            type = "range",
                            name = "Name X",
                            min = -100,
                            max = 100,
                            step = 1,
                            get = function() return GetDB().nameTextX or 0 end,
                            set = function(_, v)
                                GetDB().nameTextX = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        nameY = {
                            type = "range",
                            name = "Name Y",
                            min = -50,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().nameTextY or 0 end,
                            set = function(_, v)
                                GetDB().nameTextY = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                    },
                },
                -- Tab: Indicators
                indicators = {
                    type = "group",
                    name = "Indicators",
                    order = 2,
                    inline = true,
                    args = {
                        combat = {
                            type = "toggle",
                            name = "Show Combat",
                            get = function() return (GetDB().indicators and GetDB().indicators.combat ~= false) end,
                            set = function(_, v)
                                if not GetDB().indicators then GetDB().indicators = {} end; GetDB().indicators.combat = v; ns
                                    .RefreshUnitFrame(unit)
                            end,
                        },
                        phase = {
                            type = "toggle",
                            name = "Show Phase",
                            get = function() return (GetDB().indicators and GetDB().indicators.phase ~= false) end,
                            set = function(_, v)
                                if not GetDB().indicators then GetDB().indicators = {} end; GetDB().indicators.phase = v; ns
                                    .RefreshUnitFrame(unit)
                            end,
                        },
                        resurrect = {
                            type = "toggle",
                            name = "Show Resurrect",
                            get = function() return (GetDB().indicators and GetDB().indicators.resurrect ~= false) end,
                            set = function(_, v)
                                if not GetDB().indicators then GetDB().indicators = {} end; GetDB().indicators.resurrect =
                                    v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        leader = {
                            type = "toggle",
                            name = "Show Leader",
                            get = function() return (GetDB().indicators and GetDB().indicators.leader ~= false) end,
                            set = function(_, v)
                                if not GetDB().indicators then GetDB().indicators = {} end; GetDB().indicators.leader = v; ns
                                    .RefreshUnitFrame(unit)
                            end,
                        },
                        raidicon = {
                            type = "toggle",
                            name = "Show Raid Icon",
                            get = function() return (GetDB().indicators and GetDB().indicators.raidicon ~= false) end,
                            set = function(_, v)
                                if not GetDB().indicators then GetDB().indicators = {} end; GetDB().indicators.raidicon =
                                    v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        role = {
                            type = "toggle",
                            name = "Show Role",
                            get = function() return (GetDB().indicators and GetDB().indicators.role ~= false) end,
                            set = function(_, v)
                                if not GetDB().indicators then GetDB().indicators = {} end; GetDB().indicators.role = v; ns
                                    .RefreshUnitFrame(unit)
                            end,
                        },
                    },
                },
                -- Tab: Auras (Placeholder for now)
                auras = {
                    type = "group",
                    name = "Auras",
                    order = 3,
                    inline = true,
                    args = {
                        enable = {
                            type = "toggle",
                            name = "Enable",
                            order = 1,
                            get = function() return GetDB().aurasEnabled ~= false end,
                            set = function(_, v)
                                GetDB().aurasEnabled = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        size = {
                            type = "range",
                            name = "Size",
                            order = 2,
                            min = 10,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().auraSize or 20 end,
                            set = function(_, v)
                                GetDB().auraSize = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                        max = {
                            type = "range",
                            name = "Max Auras",
                            order = 3,
                            min = 1,
                            max = 40,
                            step = 1,
                            get = function() return GetDB().maxAuras or 8 end,
                            set = function(_, v)
                                GetDB().maxAuras = v; ns.RefreshUnitFrame(unit)
                            end,
                        },
                    },
                },
            },
        }
    end

    return options
end

function Config:RegisterOptions()
    -- Safety check for AceConfig
    local AC = LibStub("AceConfig-3.0", true)
    local ACD = LibStub("AceConfigDialog-3.0", true)

    if AC and ACD then
        AC:RegisterOptionsTable("RoithiUI", GetOptions)
        self.optionsFrame = ACD:AddToBlizOptions("RoithiUI", "RoithiUI")
    else
        -- If AceConfig is missing, we just don't register this table.
        -- The standalone config (if loaded) or just the lack of options is better than a crash.
        print("RoithiUI: AceConfig-3.0 not found. Detailed options disabled.")
    end
end

-- Refresh Helper (can be moved to Core/UnitFrames if scope issues arise)
function ns.RefreshUnitFrame(unit)
    local UF = RoithiUI:GetModule("UnitFrames")
    if UF and UF.UpdateFrameFromSettings then
        UF:UpdateFrameFromSettings(unit)
    end
end
