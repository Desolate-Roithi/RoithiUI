local addonName, ns = ...

-- Initialize AceAddon
-- We mixin AceConsole-3.0 here in anticipation of Commands.lua using it via the main object
_G.RoithiUI = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local RoithiUI = _G.RoithiUI

-- Mixin LibRoithi helpers if desired, or access via LibStub("LibRoithi-1.0")
local LibRoithi = LibStub("LibRoithi-1.0")

-- Debug Flag
RoithiUI.debug = false

-- Module Handling is now natively provided by AceAddon:
-- RoithiUI:NewModule(name, prototype, mixins)
-- RoithiUI:GetModule(name)
-- We don't need to manually define self.modules or NewModule unless we want custom behavior.
-- Existing modules use `RoithiUI:NewModule("UnitFrames")` which works with AceAddon.

function RoithiUI:OnInitialize()
    -- Initialize AceDB
    -- "RoithiUIDB" is the SavedVariables table name in .toc (should be verified)
    -- ns.Defaults is the default table
    -- true (defaultProfile) -> "Default"
    self.db = LibStub("AceDB-3.0"):New("RoithiUIDB", ns.Defaults, true)

    -- DB Migration Logic: Legacy Manual -> AceDB Profile
    -- Check if we have legacy root keys that match defaults structure, and no profiles
    if _G.RoithiUIDB and not _G.RoithiUIDB.profiles then
        -- This is likely a legacy DB. Move known keys to current profile.
        -- We can't move everything blindly because AceDB manages the table now.
        -- But since we just initialized New(), AceDB might have already restructured if it was empty-ish,
        -- or if it was existing, it might treat it as a profile if structured oddly?
        -- Actually AceDB puts profiles in .profiles. If keys exist at root, they are ignored or overwritten unless upgraded.
        -- Best effort: Manually move keys if they exist in the raw global but not in profile?
        -- AceDB handles this if we use "namespaces" but for raw profile data it's tricky.

        -- Creating a simple migration check:
        -- Access raw DB not via self.db to avoid AceDB magic for a second
        local rawDB = _G.RoithiUIDB

        -- If we detect a specific key like "EnabledModules" at root
        if rawDB.EnabledModules and not rawDB.profiles then
            -- Copy to current profile
            for k, v in pairs(rawDB) do
                if k ~= "profiles" and k ~= "profileKeys" then
                    self.db.profile[k] = v
                    -- clear from root? safe to leave garbage or clean it up.
                    rawDB[k] = nil
                end
            end
            self:Print("Migrated legacy settings to 'Default' profile.")
        end
    end

    -- MidnightCastbars Migration (Keep this just in case)
    if _G.MidnightCastbarsDB then
        self.db.profile.Castbar = CopyTable(_G.MidnightCastbarsDB)
        _G.MidnightCastbarsDB = nil
        print("|cff00ccffRoithiUI:|r Migrated MidnightCastbarsDB settings to RoithiUIDB.")
    end

    -- Register Options Table (with DualSpec support if available)
    -- We can register basic profiles too
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RoithiUI_Profiles",
        LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
    -- Add to Blizzard Options
    -- LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RoithiUI_Profiles", "Profiles", "RoithiUI") -- Requires main options registered first

    -- AceAddon calls OnInitialize on modules automatically.

    -- Register Options
    if self.Config and self.Config.RegisterOptions then
        self.Config:RegisterOptions()
    end
end

function RoithiUI:OnEnable()
    -- AceAddon calls OnEnable on modules automatically.

    -- Additional startup logic if needed
    -- For example checking module enablement from DB manually before Ace enables them?
    -- AceAddon enables all modules by default.
    -- If we want to support the "Enable/Disable" toggles from RoithiUIDB.EnabledModules,
    -- we might need to iterate modules here and Disable them if the DB says so.

    for name, module in self:IterateModules() do
        local isEnabled = self.db.profile.EnabledModules and self.db.profile.EnabledModules[name]
        -- Handle explicit disable
        if isEnabled == false then
            module:Disable()
        end
    end
end
