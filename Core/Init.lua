local addonName, ns = ...

-- Global Addon Object
_G.RoithiUI = {}
local RoithiUI = _G.RoithiUI

-- Mixin LibRoithi helpers if desired, or access via LibStub("LibRoithi-1.0")
local LibRoithi = LibStub("LibRoithi-1.0")

-- Simple Module System
RoithiUI.modules = {}

function RoithiUI:NewModule(name)
    local module = {}
    self.modules[name] = module
    return module
end

function RoithiUI:GetModule(name)
    return self.modules[name]
end

-- Event Handling
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")

loader:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        RoithiUI:OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        RoithiUI:OnEnable()
    end
end)

function RoithiUI:OnInitialize()
    -- Initialize DB
    if not _G.RoithiUIDB then
        _G.RoithiUIDB = {
            EnabledModules = {
                PlayerFrame = true,
                TargetFrame = true,
                FocusFrame = true,
                Castbars = true,
            }
        }
    end

    -- DB Migration Logic
    if _G.MidnightCastbarsDB then
        _G.RoithiUIDB.Castbar = CopyTable(_G.MidnightCastbarsDB)
        _G.MidnightCastbarsDB = nil
        print("|cff00ccffRoithiUI:|r Migrated MidnightCastbarsDB settings to RoithiUIDB.")
    end

    -- Initialize Modules
    for name, module in pairs(self.modules) do
        if module.OnInitialize then
            module:OnInitialize()
        end
    end

    -- Register Options
    if self.Config and self.Config.RegisterOptions then
        self.Config:RegisterOptions()
    end
end

function RoithiUI:OnEnable()
    -- Allow modules to initialize
    for name, module in pairs(self.modules) do
        -- Check if module is enabled in DB (default to true if nil, but keys are populated in OnInitialize)
        local isEnabled = RoithiUIDB.EnabledModules[name]
        -- Handle "Castbars" vs "Castbar" naming if there's a mismatch, but we'll try to align keys.
        -- If specific module implementation has OnEnable, call it.
        if isEnabled ~= false and module.OnEnable then
            module:OnEnable()
        end
    end
end
