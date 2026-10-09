local addonName, ns = ...
if ns.skipLoad then return end

ns.Defaults = {
    profile = {
        Auras = {
            Blacklist = { ["264689"] = true, ["36032"] = true, ["390435"] = true, ["57723"] = true, ["57724"] = true, ["80354"] = true, ["95809"] = true },
            ShowOnlyPlayer = false,
            UseLibCustomGlow = true,
            Whitelist = {},
            hideCount = false,
            hideIcon = false,
            hideTimer = false,
        },
        CustomAuraFrames = {},
        EnabledModules = {
            Castbar = true,
            EncounterBar = true,
            FocusCastbar = true,
            FocusFrame = true,
            FocusTargetCastbar = true,
            Minimap = true,
            PetCastbar = true,
            PetFrame = true,
            PlayerCastbar = true,
            PlayerFrame = true,
            TargetCastbar = true,
            TargetFrame = true,
            TargetTargetCastbar = true,
            TargetTargetFrame = true,
            UnitFrames = true,
        },
        General = { Theme = "Class", castbarBar = "Solid", castbarFont = "Friz Quadrata TT", debugMode = false, unitFrameBar = "Solid", unitFrameFont = "Friz Quadrata TT" },
        IndicatorTestMode = false,
        LEMDialogPosition = false,
        Range = { insideAlpha = 1, outsideAlpha = 0.4 },
        SmartFilters = { showAll = false, showBossDebuffs = true, showCrowdControl = true, showDispellable = true, showImportant = true, showMajorDefensives = true, showRaidBuffs = true },
        Theme = "ClassColors",
        barTexture = "Solid",
        font = "Friz Quadrata TT",
        tempIndicatorSelect = "quest",
    },
}

-- Preload modular defaults if available (ensures headless tests & startup have full profile)
if loadfile then
    local moduleDefaults = {
        "UnitFrames",
        "Castbar",
        "Actionbars",
        "Bags",
        "Chat",
        "CooldownManager",
        "EncounterBar",
        "Menu",
        "Minimap",
        "Objectives",
        "SwingTimer",
        "Totems",
    }
    for _, modName in ipairs(moduleDefaults) do
        local chunk = loadfile("Modules/" .. modName .. "/Defaults.lua")
        if chunk then chunk(addonName, ns) end
    end
end
