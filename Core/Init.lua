local addonName, ns = ...

-- Initialize AceAddon
-- We mixin AceConsole-3.0 here in anticipation of Commands.lua using it via the main object
_G.RoithiUI = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local RoithiUI = _G.RoithiUI

-- Mixin LibRoithi helpers if desired, or access via LibStub("LibRoithi-1.0")
local LibRoithi = LibStub("LibRoithi-1.0")

-- Debug Flag
RoithiUI.debug = false

function RoithiUI:Log(...)
    if not self.db or not self.db.profile.General.debugMode then return end
    local prefix = "|cff00ccffRoithiUI:|r"
    print(prefix, ...)
end

-- Module Handling is now natively provided by AceAddon:
-- RoithiUI:NewModule(name, prototype, mixins)
-- RoithiUI:GetModule(name)
-- We don't need to manually define self.modules or NewModule unless we want custom behavior.
-- Existing modules use `RoithiUI:NewModule("UnitFrames")` which works with AceAddon.

function RoithiUI:OnInitialize()
    local isDev = string.match(addonName, "%-Dev$")
    if isDev then
        local prodName = string.gsub(addonName, "%-Dev$", "")
        local state = C_AddOns.GetAddOnEnableState((UnitName("player") or "player"), prodName)
        if state and state > 0 then
            C_Timer.After(5, function()
                print("|cffff0000["..addonName.."]|r |cff00ccffAborted:|r Production version ("..prodName..") is also loaded. Database untouched.")
            end)
            return -- Abort initialization completely
        end
    end

    -- Initialize AceDB
    self.db = LibStub("AceDB-3.0"):New("RoithiUIDB", ns.Defaults, true)

    -- Register Profile Callbacks
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshProfile")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshProfile")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshProfile")

    -- DB Migration Logic: Legacy Manual -> AceDB Profile
    if _G.RoithiUIDB and not _G.RoithiUIDB.profiles then
        local rawDB = _G.RoithiUIDB
        if rawDB.EnabledModules and not rawDB.profiles then
            for k, v in pairs(rawDB) do
                if k ~= "profiles" and k ~= "profileKeys" then
                    self.db.profile[k] = v
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

function RoithiUI:RefreshProfile()
    if ns and ns.RefreshAllCastbars then ns.RefreshAllCastbars() end
    
    local UF = self:GetModule("UnitFrames")
    if UF and UF.units then
        for unit, _ in pairs(UF.units) do
            if UF.ToggleFrame then
                UF:ToggleFrame(unit, UF:IsUnitEnabled(unit))
            end
            if UF:IsUnitEnabled(unit) and UF.UpdateFrameFromSettings then
                UF:UpdateFrameFromSettings(unit)
            end
        end
    end
    
    -- Also close AceConfigDialog if it's open or refresh registry to match new DB
    LibStub("AceConfigRegistry-3.0"):NotifyChange("RoithiUI_Profiles")
    
    if self.Config and self.Config.OptionsRefresh then
        self.Config:OptionsRefresh()
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
