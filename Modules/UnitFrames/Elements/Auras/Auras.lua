local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI

---@class UF : AceModule, AceAddon
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]

local RADLog = function(fmt, ...) if ns.Auras and ns.Auras.RADLog then ns.Auras.RADLog(fmt, ...) end end
local IsSupportedUnit = function(unit) return ns.Auras and ns.Auras.IsSupportedUnit and ns.Auras.IsSupportedUnit(unit) end
local GetUnitDB = function(unit) return ns.Auras and ns.Auras.GetUnitDB and ns.Auras.GetUnitDB(unit) end
local MakeContainerKey = function(unit, suf) return ns.Auras and ns.Auras.MakeContainerKey and ns.Auras.MakeContainerKey(unit, suf) end
local GetOrCreateAuraContainer = function(unit, suf, parent) return ns.Auras and ns.Auras.GetOrCreateAuraContainer and ns.Auras.GetOrCreateAuraContainer(unit, suf, parent) end
local ConfigureAuraContainer = function(c, unit, suf) return ns.Auras and ns.Auras.ConfigureAuraContainer and ns.Auras.ConfigureAuraContainer(c, unit, suf) end
local GetSmartFilterQueries = function(fType, db, unit) return ns.Auras and ns.Auras.GetSmartFilterQueries and ns.Auras.GetSmartFilterQueries(fType, db, unit) end
local FlushContainerFrames = function(c) return ns.Auras and ns.Auras.FlushContainerFrames and ns.Auras.FlushContainerFrames(c) end

-------------------------------------------------------------------------------
-- UF Element Hooks for 12.1.0 Player & Target Auras (1:1 from Auras_12_1.lua)
-------------------------------------------------------------------------------
function UF:CreateAuras(frame)
    if not frame then return end
    local unit = frame.unit

    -- Filter: Handle Player, Target, Focus, Pet, and Boss unitframes in 12.1.0 new aura system
    if not IsSupportedUnit(unit) then
        if UF.CreateLegacyAuras then
            UF:CreateLegacyAuras(frame)
        end
        return
    end

    RADLog("UF:CreateAuras called for 12.1.0 unit: %s", tostring(unit))

    frame.UpdateAuraLayout = function()
        UF:UpdateAuras(frame)
    end

    frame.UpdateAuras = function()
        UF:UpdateAuras(frame)
    end

    -- Initial Container setup
    UF:UpdateAuras(frame)

    -- Register Event Hooks
    frame:HookScript("OnShow", function()
        UF:UpdateAuras(frame)
    end)

    if unit == "target" then
        frame:RegisterEvent("PLAYER_TARGET_CHANGED", frame.UpdateAuras, true)
    elseif unit == "focus" then
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED", frame.UpdateAuras, true)
    end
end

function UF:UpdateAuras(frame)
    if type(frame) == "string" then frame = self.units[frame] end
    if not frame or not frame.unit then return end
    local unit = frame.unit

    -- Delegate non-supported units to Legacy handler
    if not IsSupportedUnit(unit) then
        if UF.UpdateLegacyAuras then
            UF:UpdateLegacyAuras(frame)
        end
        return
    end

    local db = GetUnitDB(unit)
    local enabled = db.aurasEnabled ~= false
    RADLog("UF:UpdateAuras 12.1.0 for unit [%s] | Enabled: %s", unit, tostring(enabled))

    if not enabled then
        local suffixes = { "Buffs", "Debuffs", "Combined" }
        for _, suf in ipairs(suffixes) do
            local key = "RoithiAuraContainer_" .. unit .. "_" .. suf
            local c = UF.AuraContainers[key]
            if c then
                c:Hide()
                if c.AuraMover then c.AuraMover:Hide() end
            end
            local mKey = key .. "_Mover"
            if UF.AuraMovers and UF.AuraMovers[mKey] then
                UF.AuraMovers[mKey]:Hide()
            end
        end
        return
    end

    local separateAuras = db.separateAuras == true
    local showBuffs = db.showBuffs ~= false
    local showDebuffs = db.showDebuffs ~= false

    local isEditMode = false
    local LEM = LibStub("LibEditMode-Roithi", true)
    if LEM and LEM.IsInEditMode and LEM:IsInEditMode() then
        isEditMode = true
    elseif EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        isEditMode = true
    end

    local buffQueries  = GetSmartFilterQueries("HELPFUL",  db, unit)
    local debuffQueries = GetSmartFilterQueries("HARMFUL", db, unit)
    local hasBuffs  = showBuffs  and (isEditMode or #buffQueries  > 0)
    local hasDebuffs = showDebuffs and (isEditMode or #debuffQueries > 0)

    RADLog("[AuraFilter] unit=[%s] separateAuras=%s showBuffs=%s showDebuffs=%s hasBuffs=%s hasDebuffs=%s buffQ=%d debuffQ=%d",
        unit, tostring(separateAuras), tostring(showBuffs), tostring(showDebuffs),
        tostring(hasBuffs), tostring(hasDebuffs), #buffQueries, #debuffQueries)

    if separateAuras then
        -- Hide combined container if previously created
        local combinedKey = MakeContainerKey(unit, "Combined")
        local combined = UF.AuraContainers[combinedKey]
        if combined then
            FlushContainerFrames(combined)
            if combined.AuraMover then combined.AuraMover:Hide() end
        end
        if UF.AuraMovers and UF.AuraMovers[combinedKey .. "_Mover"] then
            UF.AuraMovers[combinedKey .. "_Mover"]:Hide()
        end

        -- Buffs Container
        local buffContainerKey = MakeContainerKey(unit, "Buffs")
        if hasBuffs then
            local buffContainer = GetOrCreateAuraContainer(unit, "Buffs", frame)
            ConfigureAuraContainer(buffContainer, unit, "Buffs")
        else
            local buffContainer = UF.AuraContainers[buffContainerKey]
            if buffContainer then
                RADLog("[AuraFilter] Flushing Buffs container (hasBuffs=false) for unit [%s]", unit)
                FlushContainerFrames(buffContainer)
                if buffContainer.AuraMover then buffContainer.AuraMover:Hide() end
            end
            if UF.AuraMovers and UF.AuraMovers[buffContainerKey .. "_Mover"] then
                UF.AuraMovers[buffContainerKey .. "_Mover"]:Hide()
            end
        end

        -- Debuffs Container
        local debuffContainerKey = MakeContainerKey(unit, "Debuffs")
        if hasDebuffs then
            local debuffContainer = GetOrCreateAuraContainer(unit, "Debuffs", frame)
            ConfigureAuraContainer(debuffContainer, unit, "Debuffs")
        else
            local debuffContainer = UF.AuraContainers[debuffContainerKey]
            if debuffContainer then
                RADLog("[AuraFilter] Flushing Debuffs container (hasDebuffs=false) for unit [%s]", unit)
                FlushContainerFrames(debuffContainer)
                if debuffContainer.AuraMover then debuffContainer.AuraMover:Hide() end
            end
            if UF.AuraMovers and UF.AuraMovers[debuffContainerKey .. "_Mover"] then
                UF.AuraMovers[debuffContainerKey .. "_Mover"]:Hide()
            end
        end
    else
        -- Hide separate containers if previously created
        local buffsKey = MakeContainerKey(unit, "Buffs")
        local buffs = UF.AuraContainers[buffsKey]
        if buffs then
            FlushContainerFrames(buffs)
            if buffs.AuraMover then buffs.AuraMover:Hide() end
        end
        if UF.AuraMovers and UF.AuraMovers[buffsKey .. "_Mover"] then
            UF.AuraMovers[buffsKey .. "_Mover"]:Hide()
        end

        local debuffsKey = MakeContainerKey(unit, "Debuffs")
        local debuffs = UF.AuraContainers[debuffsKey]
        if debuffs then
            FlushContainerFrames(debuffs)
            if debuffs.AuraMover then debuffs.AuraMover:Hide() end
        end
        if UF.AuraMovers and UF.AuraMovers[debuffsKey .. "_Mover"] then
            UF.AuraMovers[debuffsKey .. "_Mover"]:Hide()
        end

        -- Combined Container
        local combinedContainerKey = MakeContainerKey(unit, "Combined")
        if hasBuffs or hasDebuffs then
            local combinedContainer = GetOrCreateAuraContainer(unit, "Combined", frame)
            ConfigureAuraContainer(combinedContainer, unit, "Combined")
        else
            local combinedContainer = UF.AuraContainers[combinedContainerKey]
            if combinedContainer then
                RADLog("[AuraFilter] Flushing Combined container (hasBuffs/Debuffs=false) for unit [%s]", unit)
                FlushContainerFrames(combinedContainer)
                if combinedContainer.AuraMover then combinedContainer.AuraMover:Hide() end
            end
            if UF.AuraMovers and UF.AuraMovers[combinedContainerKey .. "_Mover"] then
                UF.AuraMovers[combinedContainerKey .. "_Mover"]:Hide()
            end
        end
    end
end

function UF:UpdateAllAuras()
    if self.units then
        for _, frame in pairs(self.units) do
            if frame and frame.unit and IsSupportedUnit(frame.unit) then
                self:UpdateAuras(frame)
            end
        end
    end
    if self.UpdateAllCustomAuras then
        self:UpdateAllCustomAuras()
    end
end

function UF:UpdateAllCustomAuras()
    local customDB = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CustomAuraFrames
    if RoithiUI.CustomAuras then
        for id, frame in pairs(RoithiUI.CustomAuras) do
            if not customDB or not customDB[id] or customDB[id].enabled == false then
                frame:Hide()
                if frame.AuraMover then frame.AuraMover:Hide() end
                local mKey = "RoithiAuraContainer_Custom_" .. id .. "_Mover"
                if UF.AuraMovers and UF.AuraMovers[mKey] then
                    UF.AuraMovers[mKey]:Hide()
                end
            end
        end
    end
    if not customDB then return end
    for id in pairs(customDB) do
        self:UpdateCustomAura(id)
    end
end

-------------------------------------------------------------------------------
-- Global Event Listener for Target Changes & World Load
-------------------------------------------------------------------------------
local watcherFrame = CreateFrame("Frame")
watcherFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
watcherFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
watcherFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
watcherFrame:SetScript("OnEvent", function(_, event)
    RADLog("Watcher event triggered: %s", tostring(event))
    local UFModule = RoithiUI:GetModule("UnitFrames", true)
    if UFModule then
        if UFModule.units then
            for _, uFrame in pairs(UFModule.units) do
                if uFrame and uFrame.unit and IsSupportedUnit(uFrame.unit) then
                    UFModule:UpdateAuras(uFrame)
                end
            end
        end
        if UFModule.UpdateAllCustomAuras then
            UFModule:UpdateAllCustomAuras()
        end
    end
end)

-- Register LibEditMode callbacks for Edit Mode sample aura previews across all unitframes & custom auras
local LEM = LibStub("LibEditMode-Roithi", true)
if LEM then
    local function RefreshEditModeAuras()
        local UFModule = RoithiUI:GetModule("UnitFrames", true)
        if UFModule then
            if UFModule.units then
                for _, uFrame in pairs(UFModule.units) do
                    if uFrame and uFrame.unit and IsSupportedUnit(uFrame.unit) then
                        UFModule:UpdateAuras(uFrame)
                    end
                end
            end
            if UFModule.UpdateAllCustomAuras then
                UFModule:UpdateAllCustomAuras()
            end
        end
    end
    LEM:RegisterCallback('enter', RefreshEditModeAuras)
    LEM:RegisterCallback('exit', RefreshEditModeAuras)
end
