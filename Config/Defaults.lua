local addonName, ns = ...

ns.Defaults = {
    -- Global Module Toggles
    EnabledModules = {
        PlayerFrame = true,
        TargetFrame = true,
        FocusFrame = true,
        PetFrame = true,
        TargetTargetFrame = true,
        -- Granular Castbars
        PlayerCastbar = true,
        TargetCastbar = true,
        FocusCastbar = true,
        PetCastbar = true,
        TargetTargetCastbar = true,
        FocusTargetCastbar = true,
        -- Encounter
        EncounterBar = true,
    },

    -- UnitFrame Specific Defaults
    UnitFrames = {
        player = {
            enabled = true,
            width = 230,
            height = 50,
            point = "CENTER",
            x = -250,
            y = -100,
            -- Power
            powerEnabled = true,
            powerHeight = 12,
            powerDetached = false,
            powerWidth = 230, -- Only used if detached or inferred
            -- Class Power
            classPowerEnabled = true,
            classPowerHeight = 10,
            classPowerDetached = false,
            classPowerWidth = 230,
            -- Additional Power
            additionalPowerEnabled = true,
            additionalPowerHeight = 10,
            additionalPowerDetached = false,
            additionalPowerWidth = 230,
            -- Tags
            tags = {
                {
                    id = 1,
                    enabled = true,
                    point = "CENTER",
                    x = 0,
                    y = 0,
                    anchorTo = "Health",
                    fontSize = 12,
                    formatString = "@health.current:short / @health.percent - @health.missing"
                },
                -- Power Tag
                {
                    id = 2,
                    enabled = true,
                    point = "CENTER",
                    x = 0,
                    y = 0,
                    anchorTo = "Power",
                    fontSize = 12,
                    formatString = "@power.percent"
                }
            },
            -- Auras
            aurasEnabled = true,
            maxAuras = 8,
            -- Indicators
            indicators = {
                resurrect = { enabled = true, size = 24, point = "CENTER", x = 0, y = 0 },
                phase = { enabled = true, size = 22, point = "CENTER", x = 0, y = 0 },
                combat = { enabled = true, size = 20, point = "CENTER", relativePoint = "BOTTOMLEFT", x = 0, y = 0 },
                resting = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOPLEFT", x = 0, y = 0 },
                leader = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 8 },
                raidicon = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOP", x = 0, y = 5 },
                role = { enabled = true, size = 16, point = "TOPLEFT", x = 14, y = 8 },
                readycheck = { enabled = true, size = 20, point = "CENTER", x = 0, y = 0 },
                pvp = { enabled = true, size = 24, point = "CENTER", relativePoint = "TOPRIGHT", x = -10, y = 10 },
                quest = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOPLEFT", x = 10, y = 10 },
                tankassist = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 16 }, -- Above leader
            }
        },
        target = {
            enabled = true,
            width = 230,
            height = 50,
            point = "CENTER",
            x = 250,
            y = -100,
            powerEnabled = true,
            powerHeight = 12,
            tags = {
                {
                    id = 1,
                    enabled = true,
                    point = "LEFT",
                    x = 5,
                    y = 0,
                    anchorTo = "Health",
                    fontSize = 12,
                    formatString = "@name"
                },
                {
                    id = 2,
                    enabled = true,
                    point = "RIGHT",
                    x = -5,
                    y = 0,
                    anchorTo = "Health",
                    fontSize = 12,
                    formatString = "@health.percent"
                }
            },
            aurasEnabled = true,
            maxAuras = 8,
            indicators = {
                resurrect = { enabled = true, size = 24, point = "CENTER", x = 0, y = 0 },
                phase = { enabled = true, size = 22, point = "CENTER", x = 0, y = 0 },
                combat = { enabled = true, size = 20, point = "CENTER", relativePoint = "BOTTOMLEFT", x = 0, y = 0 },
                leader = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 8 },
                raidicon = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOP", x = 0, y = 5 },
                role = { enabled = true, size = 16, point = "TOPLEFT", x = 14, y = 8 },
                readycheck = { enabled = true, size = 20, point = "CENTER", x = 0, y = 0 },
                pvp = { enabled = true, size = 24, point = "CENTER", relativePoint = "TOPRIGHT", x = -10, y = 10 },
                quest = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOPLEFT", x = 10, y = 10 },
                tankassist = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 16 },
            }
        },
        focus = {
            enabled = true,
            width = 200,
            height = 30,
            point = "CENTER",
            x = 350,
            y = 0,
            powerEnabled = true,
            powerHeight = 8,
            aurasEnabled = true,
            maxAuras = 8,
            indicators = {
                resurrect = { enabled = true, size = 24, point = "CENTER", x = 0, y = 0 },
                phase = { enabled = true, size = 22, point = "CENTER", x = 0, y = 0 },
                combat = { enabled = true, size = 20, point = "CENTER", relativePoint = "BOTTOMLEFT", x = 0, y = 0 },
                leader = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 8 },
                raidicon = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOP", x = 0, y = 5 },
                role = { enabled = true, size = 16, point = "TOPLEFT", x = 14, y = 8 },
                readycheck = { enabled = true, size = 20, point = "CENTER", x = 0, y = 0 },
                pvp = { enabled = true, size = 24, point = "CENTER", relativePoint = "TOPRIGHT", x = -10, y = 10 },
                quest = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOPLEFT", x = 10, y = 10 },
                tankassist = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 16 },
            }
        },
        targettarget = {
            enabled = true,
            width = 120,
            height = 30,
            point = "CENTER",
            x = 0,
            y = -200,
            powerEnabled = false,
            aurasEnabled = true,
            maxAuras = 8,
            indicators = {
                resurrect = { enabled = true, size = 24, point = "CENTER", x = 0, y = 0 },
                phase = { enabled = true, size = 22, point = "CENTER", x = 0, y = 0 },
                combat = { enabled = true, size = 20, point = "CENTER", relativePoint = "BOTTOMLEFT", x = 0, y = 0 },
                leader = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 8 },
                raidicon = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOP", x = 0, y = 5 },
                role = { enabled = true, size = 16, point = "TOPLEFT", x = 14, y = 8 },
                readycheck = { enabled = true, size = 20, point = "CENTER", x = 0, y = 0 },
                pvp = { enabled = true, size = 24, point = "CENTER", relativePoint = "TOPRIGHT", x = -10, y = 10 },
                quest = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOPLEFT", x = 10, y = 10 },
                tankassist = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 16 },
            }
        },
        pet = {
            enabled = true,
            width = 120,
            height = 30,
            point = "CENTER",
            x = -350,
            y = 0,
            powerEnabled = false,
            aurasEnabled = true,
            maxAuras = 8,
            indicators = {
                resurrect = { enabled = true, size = 24, point = "CENTER", x = 0, y = 0 },
                phase = { enabled = true, size = 22, point = "CENTER", x = 0, y = 0 },
                combat = { enabled = true, size = 20, point = "CENTER", relativePoint = "BOTTOMLEFT", x = 0, y = 0 },
                leader = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 8 },
                raidicon = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOP", x = 0, y = 5 },
                role = { enabled = true, size = 16, point = "TOPLEFT", x = 14, y = 8 },
                readycheck = { enabled = true, size = 20, point = "CENTER", x = 0, y = 0 },
                pvp = { enabled = true, size = 24, point = "CENTER", relativePoint = "TOPRIGHT", x = -10, y = 10 },
                quest = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOPLEFT", x = 10, y = 10 },
                tankassist = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 16 },
            }
        },
        focustarget = {
            enabled = true,
            width = 120,
            height = 30,
            point = "CENTER",
            x = -350,
            y = -50,
            powerEnabled = false,
            aurasEnabled = true,
            maxAuras = 8,
            indicators = {
                resurrect = { enabled = true, size = 24, point = "CENTER", x = 0, y = 0 },
                phase = { enabled = true, size = 22, point = "CENTER", x = 0, y = 0 },
                combat = { enabled = true, size = 20, point = "CENTER", relativePoint = "BOTTOMLEFT", x = 0, y = 0 },
                leader = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 8 },
                raidicon = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOP", x = 0, y = 5 },
                role = { enabled = true, size = 16, point = "TOPLEFT", x = 14, y = 8 },
                readycheck = { enabled = true, size = 20, point = "CENTER", x = 0, y = 0 },
                pvp = { enabled = true, size = 24, point = "CENTER", relativePoint = "TOPRIGHT", x = -10, y = 10 },
                quest = { enabled = true, size = 20, point = "CENTER", relativePoint = "TOPLEFT", x = 10, y = 10 },
                tankassist = { enabled = true, size = 16, point = "TOPLEFT", x = 0, y = 16 },
            }
        }
    },

    -- Castbar Defaults
    Castbar = {
        player = {
            enabled = true,
            width = 230,
            height = 20,
            point = "CENTER",
            x = 0,
            y = -200,
            icon = true,
            time = true,
            colors = {
                cast = { 1, 0.7, 0, 1 },
                channel = { 0, 1, 0, 1 },
                success = { 0, 1, 0, 1 },
                failed = { 1, 0, 0, 1 },
                interrupted = { 1, 0, 0, 1 },
                shield = { 0.7, 0.7, 0.7, 1 } -- Uninterruptible
            }
        },
        target = {
            enabled = true,
            width = 230,
            height = 20,
            point = "TOP",
            relativeTo = "TargetFrame", -- Conceptually
            x = 0,
            y = 30,
            colors = {
                cast = { 1, 0.7, 0, 1 },
                interruptible = { 1, 0, 0, 1 }, -- Usually enemy casts are red?
            }
        },
        targettarget = {
            enabled = true,
            width = 120,
            height = 15,
            point = "TOP",
            relativeTo = "TargetTargetFrame",
            x = 0,
            y = 20,
            colors = { cast = { 1, 0.7, 0, 1 } }
        },
        focus = {
            enabled = true,
            width = 200,
            height = 20,
            point = "TOP",
            relativeTo = "FocusFrame",
            x = 0,
            y = 30,
            colors = { cast = { 1, 0.7, 0, 1 }, interruptible = { 1, 0, 0, 1 } }
        },
        focustarget = {
            enabled = true,
            width = 120,
            height = 15,
            point = "TOP",
            relativeTo = "FocusTargetFrame",
            x = 0,
            y = 20,
            colors = { cast = { 1, 0.7, 0, 1 } }
        },
        pet = {
            enabled = true,
            width = 120,
            height = 15,
            point = "TOP",
            relativeTo = "PetFrame",
            x = 0,
            y = 20,
            colors = { cast = { 1, 0.7, 0, 1 } }
        }
    }
}
