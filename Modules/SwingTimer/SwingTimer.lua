local addonName, ns = ...
if ns.skipLoad then return end
if not ns.IsForever and not ns.isTestEnvironment then return end
local RoithiUI = _G.RoithiUI
local SwingTimer = RoithiUI:NewModule("SwingTimer", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local LEM = LibStub and LibStub("LibEditMode-Roithi", true)

SwingTimer.displayName = L["Swing Timer"]
SwingTimer.description = L["Weapon swing timer for player and target in Forever."]
SwingTimer.order = 96
SwingTimer.dbKey = "SwingTimer"
SwingTimer.defaultSettings = ns.SwingTimerDefaults or (ns.Defaults and ns.Defaults.profile and ns.Defaults.profile.SwingTimer)

-- Abilities that reset the swing timer in Classic / Forever
local SWING_RESET_SPELLS = {
    -- Slam
    [1464] = true, [8847] = true, [11604] = true, [11605] = true, [25241] = true, [25242] = true, [47475] = true,
    -- Heroic Strike
    [78] = true, [284] = true, [285] = true, [1608] = true, [11564] = true, [11565] = true, [11566] = true, [11567] = true, [25286] = true,
    -- Cleave
    [845] = true, [7369] = true, [11608] = true, [11609] = true, [20569] = true, [25231] = true,
    -- Raptor Strike
    [2973] = true, [14260] = true, [14261] = true, [14262] = true, [14263] = true, [14264] = true, [14265] = true, [14266] = true,
    -- Maul
    [6807] = true, [6808] = true, [6809] = true, [6810] = true, [9880] = true, [9881] = true, [26996] = true,
}

local issecretvalue = _G.issecretvalue
local canaccessvalue = _G.canaccessvalue
local function UnitCanAttack(a, b)
    local fn = _G.UnitCanAttack
    return fn and fn(a, b)
end
local function UnitAffectingCombat(u)
    local fn = _G.UnitAffectingCombat
    return fn and fn(u)
end
local function UnitIsUnit(a, b)
    local fn = _G.UnitIsUnit
    return fn and fn(a, b)
end
local function UnitExists(u)
    local fn = _G.UnitExists
    return fn and fn(u)
end
local function UnitIsDeadOrGhost(u)
    local fn = _G.UnitIsDeadOrGhost or _G.UnitIsDead
    return fn and fn(u)
end
local function IsSecret(v)
    if ns.Utils and ns.Utils.IsSecret then
        return ns.Utils.IsSecret(v)
    end
    if v == nil then return false end
    local fn = _G.issecretvalue or issecretvalue
    if type(fn) == "function" and fn(v) then return true end
    local ca = _G.canaccessvalue or canaccessvalue
    if type(ca) == "function" and not ca(v) then return true end
    return type(v) == "userdata"
end

local function IsSpellInResetList(spellId)
    if not spellId or IsSecret(spellId) then return false end
    return SWING_RESET_SPELLS[spellId] == true
end

function SwingTimer:GetSafeAttackSpeed(unit)
    local main, off
    if UnitAttackSpeed then
        main, off = UnitAttackSpeed(unit)
        if IsSecret(main) then main = nil end
        if IsSecret(off) then off = nil end
    end
    if unit == "player" then
        if main and type(main) == "number" and main > 0 then
            self.cachedPlayerMainSpeed = main
        else
            main = self.cachedPlayerMainSpeed or 2.0
        end
        if off and type(off) == "number" and off > 0 then
            self.cachedPlayerOffSpeed = off
        else
            off = self.cachedPlayerOffSpeed
        end
        return main, off
    else
        if main and type(main) == "number" and main > 0 then
            self.cachedTargetSpeed = main
        else
            main = self.cachedTargetSpeed or 2.0
        end
        return main, off
    end
end

function SwingTimer:GetSafeRangedSpeed(unit)
    local speed
    if UnitRangedDamage then
        speed = select(1, UnitRangedDamage(unit or "player"))
        if IsSecret(speed) then speed = nil end
    end
    if speed and type(speed) == "number" and speed > 0 then
        self.cachedPlayerRangedSpeed = speed
    else
        speed = self.cachedPlayerRangedSpeed or 2.5
    end
    return speed
end

local SHOW_SWING_TIMER_CVAR = "showSwingTimer"

function SwingTimer:EnsureBlizzardTimerEnabled()
    if not _G.C_CVar or not _G.C_CVar.GetCVar or not _G.C_CVar.SetCVar then return false end
    if _G.C_CVar.GetCVar(SHOW_SWING_TIMER_CVAR) == "1" then return true end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    pcall(_G.C_CVar.SetCVar, SHOW_SWING_TIMER_CVAR, "1")
    return _G.C_CVar.GetCVar(SHOW_SWING_TIMER_CVAR) == "1"
end

function SwingTimer:SyncNativeProgress(hand, frame, value)
    if self.isInEditMode or not self.playerFrame then return end
    local pCfg = self.db and self.db.player or self.defaultSettings.player
    if pCfg.enabled == false then return end

    local bar
    if hand == "main" then
        bar = self.playerFrame.mainBar
    elseif hand == "off" and pCfg.showOffhand ~= false then
        bar = self.playerFrame.offBar
    elseif hand == "ranged" then
        bar = self.playerFrame.rangedBar
    end

    if not bar then return end

    local statusBar = frame.GetStatusBar and frame:GetStatusBar()
    local minVal, maxVal = 0, 2.0
    if statusBar and statusBar.GetMinMaxValues then
        minVal, maxVal = statusBar:GetMinMaxValues()
    end

    bar:SetMinMaxValues(minVal or 0, maxVal or 2.0)
    bar:SetValue(value or 0)

    local showTimer = true
    if pCfg.showTimer ~= nil then
        showTimer = (pCfg.showTimer == true)
    elseif pCfg.showText ~= nil then
        showTimer = (pCfg.showText ~= false)
    end
    if showTimer then
        local label = frame.GetTimeLabel and frame:GetTimeLabel()
        local txt = label and label:GetText()
        if IsSecret(txt) then
            pcall(bar.timeText.SetText, bar.timeText, "")
        elseif txt and type(txt) == "string" and txt ~= "" then
            pcall(bar.timeText.SetText, bar.timeText, txt)
        else
            if not IsSecret(maxVal) and not IsSecret(value) and type(maxVal) == "number" and type(value) == "number" then
                local dur = maxVal or 2.0
                local val = value or 0
                pcall(bar.timeText.SetText, bar.timeText, string.format("%.1fs", math.max(0, dur - val)))
            else
                pcall(bar.timeText.SetText, bar.timeText, "")
            end
        end
    end

    if bar.spark then
        if not IsSecret(maxVal) and not IsSecret(value) and type(maxVal) == "number" and maxVal > 0 then
            local w = bar:GetWidth() or 200
            local val = (type(value) == "number") and value or 0
            local prog = math.min(1, math.max(0, val / maxVal))
            bar.spark:ClearAllPoints()
            bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
            bar.spark:Show()
        else
            bar.spark:Hide()
        end
    end

    bar:Show()
    self.playerFrame:Show()
end

function SwingTimer:SyncNativeReset(hand, frame)
    if self.isInEditMode or not self.playerFrame then return end
    self:SyncNativeProgress(hand, frame, 0)
end

function SwingTimer:SyncNativeClear(hand, _)
    if not self.playerFrame then return end
    local bar
    if hand == "main" then
        bar = self.playerFrame.mainBar
    elseif hand == "off" then
        bar = self.playerFrame.offBar
    elseif hand == "ranged" then
        bar = self.playerFrame.rangedBar
    end
    if bar then bar:Hide() end

    local mb = self.playerFrame.mainBar
    local ob = self.playerFrame.offBar
    local rb = self.playerFrame.rangedBar
    local anyShown = (mb and mb:IsShown()) or (ob and ob:IsShown()) or (rb and rb:IsShown())
    if not anyShown then
        self.playerFrame:Hide()
    end
end

local selectionHooked = setmetatable({}, { __mode = "k" })
local settingAlpha = setmetatable({}, { __mode = "k" })
local nativeAlphaHooked = setmetatable({}, { __mode = "k" })
local nativeOnShowHooked = setmetatable({}, { __mode = "k" })
local nativeOpacityHooked = setmetatable({}, { __mode = "k" })
local nativeStatusBarHooked = setmetatable({}, { __mode = "k" })
local nativeResetHooked = setmetatable({}, { __mode = "k" })
local nativeClearHooked = setmetatable({}, { __mode = "k" })

local function SetClickthrough(frame, clickthrough)
    if not frame then return end
    local enableMouse = not clickthrough
    if frame.EnableMouse then frame:EnableMouse(enableMouse) end
    if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(enableMouse) end
    if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(enableMouse) end
end

local function IsModuleActive(mod)
    if not mod then return true end
    if mod.enabledState ~= nil and not mod.enabledState then return false end
    if mod.IsEnabled and not mod:IsEnabled() then return false end
    if mod.db and mod.db.enabled == false then return false end
    return true
end

local function ShouldSuppressNativeSwingFrames(mod)
    if not IsModuleActive(mod) then return false end
    if mod and mod.db and mod.db.player and mod.db.player.enabled == false then
        return false
    end
    return true
end

local function SafeUnitBool(val)
    if val == nil or IsSecret(val) then return false end
    return val == true or val == 1
end

local function SuppressNativeSelection(targetFrame)
    if not targetFrame then return end
    if targetFrame.Selection then
        if ShouldSuppressNativeSwingFrames(SwingTimer) then
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                targetFrame.Selection:Hide()
            elseif targetFrame.Selection.SetAlpha then
                targetFrame.Selection:SetAlpha(0)
            end
        end
        if not selectionHooked[targetFrame] and hooksecurefunc then
            hooksecurefunc(targetFrame.Selection, "Show", function(sel)
                if ShouldSuppressNativeSwingFrames(SwingTimer) then
                    if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                        sel:Hide()
                    elseif sel.SetAlpha then
                        sel:SetAlpha(0)
                    end
                end
            end)
            selectionHooked[targetFrame] = true
        end
    end
end

local NATIVE_SWING_FRAME_NAMES = {
    "SwingTimerMainHandFrame",
    "SwingTimerOffHandFrame",
    "SwingTimerRangedFrame",
}

function SwingTimer:UpdateNativeSwingFramesVisibility()
    local suppress = ShouldSuppressNativeSwingFrames(self)
    local inLockdown = _G.InCombatLockdown and _G.InCombatLockdown()
    for _, frameName in ipairs(NATIVE_SWING_FRAME_NAMES) do
        local f = _G[frameName]
        if f then
            if suppress then
                SuppressNativeSelection(f)
                if not inLockdown then
                    SetClickthrough(f, true)
                end
                local curAlpha = f.GetAlpha and f:GetAlpha()
                if f.SetAlpha and (curAlpha == nil or IsSecret(curAlpha) or curAlpha ~= 0) and not settingAlpha[f] then
                    settingAlpha[f] = true
                    f:SetAlpha(0)
                    settingAlpha[f] = nil
                end
            else
                if not inLockdown then
                    SetClickthrough(f, false)
                end
                local curAlpha = f.GetAlpha and f:GetAlpha()
                if f.SetAlpha and (curAlpha == nil or (not IsSecret(curAlpha) and curAlpha == 0)) and not settingAlpha[f] then
                    settingAlpha[f] = true
                    f:SetAlpha(1)
                    settingAlpha[f] = nil
                end
            end
        end
    end
end

function SwingTimer:BindNativeSwingFrames()
    self.nativeFramesBound = self.nativeFramesBound or setmetatable({}, { __mode = "k" })
    local anyBound = false

    if _G.C_AddOns and _G.C_AddOns.LoadAddOn and not _G.SwingTimerMainHandFrame then
        pcall(_G.C_AddOns.LoadAddOn, "Blizzard_SwingTimer")
    end

    self:EnsureBlizzardTimerEnabled()

    local targets = {
        main = _G.SwingTimerMainHandFrame,
        off = _G.SwingTimerOffHandFrame,
        ranged = _G.SwingTimerRangedFrame,
    }

    for hand, frame in pairs(targets) do
        if frame and not self.nativeFramesBound[frame] then
            self.nativeFramesBound[frame] = true
            anyBound = true

            SuppressNativeSelection(frame)

            if frame.SetAlpha and not nativeAlphaHooked[frame] and hooksecurefunc then
                nativeAlphaHooked[frame] = true
                hooksecurefunc(frame, "SetAlpha", function(f, alpha)
                    if ShouldSuppressNativeSwingFrames(self) and (IsSecret(alpha) or alpha ~= 0) and not settingAlpha[f] then
                        settingAlpha[f] = true
                        f:SetAlpha(0)
                        settingAlpha[f] = nil
                    end
                end)
            end

            if not nativeOnShowHooked[frame] and frame.HookScript then
                nativeOnShowHooked[frame] = true
                frame:HookScript("OnShow", function(f)
                    local curAlpha = f.GetAlpha and f:GetAlpha()
                    if ShouldSuppressNativeSwingFrames(self) and f.SetAlpha and (IsSecret(curAlpha) or curAlpha ~= 0) and not settingAlpha[f] then
                        settingAlpha[f] = true
                        f:SetAlpha(0)
                        settingAlpha[f] = nil
                    end
                end)
            end

            if frame.UpdateSystemSettingOpacity and not nativeOpacityHooked[frame] and hooksecurefunc then
                nativeOpacityHooked[frame] = true
                hooksecurefunc(frame, "UpdateSystemSettingOpacity", function()
                    if ShouldSuppressNativeSwingFrames(self) and frame.SetAlpha and not settingAlpha[frame] then
                        settingAlpha[frame] = true
                        frame:SetAlpha(0)
                        settingAlpha[frame] = nil
                    end
                end)
            end

            local statusBar = frame.GetStatusBar and frame:GetStatusBar()
            if statusBar and not nativeStatusBarHooked[statusBar] and hooksecurefunc then
                nativeStatusBarHooked[statusBar] = true
                hooksecurefunc(statusBar, "SetValue", function(_, value)
                    self:SyncNativeProgress(hand, frame, value)
                end)
            end

            if frame.ResetSwingTimer and not nativeResetHooked[frame] and hooksecurefunc then
                nativeResetHooked[frame] = true
                hooksecurefunc(frame, "ResetSwingTimer", function()
                    self:SyncNativeReset(hand, frame)
                end)
            end

            if frame.ClearSwingTimer and not nativeClearHooked[frame] and hooksecurefunc then
                nativeClearHooked[frame] = true
                hooksecurefunc(frame, "ClearSwingTimer", function()
                    self:SyncNativeClear(hand, frame)
                end)
            end
        elseif frame then
            SuppressNativeSelection(frame)
        end
    end

    self:UpdateNativeSwingFramesVisibility()

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.topLevelParentEventRegistered then
        self.topLevelParentEventRegistered = true
        _G.EventRegistry:RegisterCallback("UI.TopLevelParentShown", function()
            if ShouldSuppressNativeSwingFrames(self) then
                self:UpdateNativeSwingFramesVisibility()
            end
        end, self)
    end

    if _G.UIParent and _G.UIParent.HookScript and not self.uiParentHooked then
        self.uiParentHooked = true
        _G.UIParent:HookScript("OnShow", function()
            if ShouldSuppressNativeSwingFrames(self) then
                self:UpdateNativeSwingFramesVisibility()
            end
        end)
    end

    if anyBound or _G.SwingTimerMainHandFrame then
        self.hasNativeFrames = true
    end
    return anyBound
end

function SwingTimer:SetupEventFrame()
    if self.eventFrame then return end
    local f = CreateFrame("Frame")
    self.eventFrame = f
    f:SetScript("OnEvent", function(_, event, ...)
        if not IsModuleActive(self) then return end
        if event == "ADDON_LOADED" then
            local loadedAddon = ...
            if loadedAddon == "Blizzard_SwingTimer" then
                self:BindNativeSwingFrames()
            end
        elseif event == "CVAR_UPDATE" then
            local cvarName = ...
            if cvarName == SHOW_SWING_TIMER_CVAR then
                self:EnsureBlizzardTimerEnabled()
                self:UpdateNativeSwingFramesVisibility()
            end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
            self:BindNativeSwingFrames()
            self:UpdateNativeSwingFramesVisibility()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            self:OnCombatLog(event, ...)
        elseif event == "UNIT_COMBAT" then
            self:OnUnitCombat(...)
        elseif event == "PLAYER_SWING" then
            self:OnPlayerSwing(...)
        elseif event == "PLAYER_SWING_RANGE_UPDATE" then
            self:OnPlayerSwingRangeUpdate(...)
        elseif event == "UNIT_ATTACK_SPEED" then
            self:OnAttackSpeedChanged(event, ...)
        elseif event == "UNIT_SPELLCAST_START" then
            self:OnSpellcastStart(event, ...)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            self:OnSpellcastSucceeded(event, ...)
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            self:OnSpellcastFinished(event, ...)
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            self:OnSpellcastStart(event, ...)
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            self:OnSpellcastFinished(event, ...)
        elseif event == "START_AUTOREPEAT_SPELL" then
            self:OnStartAutorepeat()
        elseif event == "STOP_AUTOREPEAT_SPELL" then
            self:OnStopAutorepeat()
        elseif event == "PLAYER_TARGET_CHANGED" then
            self:OnTargetChanged()
        elseif event == "UNIT_FLAGS" or event == "UNIT_HEALTH" then
            local unit = ...
            if unit == "target" then
                if not UnitExists("target") or UnitIsDeadOrGhost("target") then
                    self.targetSwings.main.active = false
                    if self.targetFrame and not self.isInEditMode then
                        if self.targetFrame.mainBar then
                            self.targetFrame.mainBar.lastTenth = nil
                            self.targetFrame.mainBar:Hide()
                        end
                        self.targetFrame:Hide()
                    end
                end
            end
        elseif event == "PLAYER_ENTER_COMBAT" or event == "PLAYER_REGEN_DISABLED" then
            self:OnEnterCombat()
        elseif event == "PLAYER_LEAVE_COMBAT" or event == "PLAYER_REGEN_ENABLED" then
            self:OnLeaveCombat()
            self:EnsureBlizzardTimerEnabled()
            self:UpdateNativeSwingFramesVisibility()
            if self.queuedEnable then
                self.queuedEnable = false
                self:OnEnable()
            end
        end
    end)
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("CVAR_UPDATE")
end

function SwingTimer:OnInitialize()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.SwingTimer or self.defaultSettings
    if not self.db.player then self.db.player = self.defaultSettings.player end
    if not self.db.target then self.db.target = self.defaultSettings.target end

    self.playerSwings = {
        main = { startTime = 0, duration = 0, active = false },
        off = { startTime = 0, duration = 0, active = false },
        ranged = { startTime = 0, duration = 0, active = false },
    }
    self.targetSwings = {
        main = { startTime = 0, duration = 0, active = false },
    }

    self.cachedPlayerMainSpeed = 2.0
    self.cachedPlayerOffSpeed = 2.0
    self.cachedPlayerRangedSpeed = 2.5
    self.cachedTargetSpeed = 2.0

    self:SetupEventFrame()
end

function SwingTimer:RegisterEvent(event, _)
    if self.eventFrame then
        pcall(self.eventFrame.RegisterEvent, self.eventFrame, event)
    end
end

function SwingTimer:UnregisterAllEvents()
    self:OnDisable()
end

function SwingTimer:OnEnable()
    if not ns.IsForever and not ns.isTestEnvironment then return end
    if self.db.enabled == false then return end

    self:SetupEventFrame()

    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedEnable = true
        return
    end

    self:CreateFrames()
    self:UpdateLayout()
    self:BindNativeSwingFrames()

    local f = self.eventFrame
    if f then
        f:RegisterEvent("UNIT_ATTACK_SPEED")
        f:RegisterEvent("UNIT_SPELLCAST_START")
        f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        f:RegisterEvent("UNIT_SPELLCAST_FAILED")
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        f:RegisterEvent("START_AUTOREPEAT_SPELL")
        f:RegisterEvent("STOP_AUTOREPEAT_SPELL")
        f:RegisterEvent("PLAYER_TARGET_CHANGED")
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:RegisterEvent("PLAYER_ENTER_COMBAT")
        f:RegisterEvent("PLAYER_LEAVE_COMBAT")
        if f.RegisterEvent then
            pcall(f.RegisterEvent, f, "PLAYER_SWING")
            pcall(f.RegisterEvent, f, "PLAYER_SWING_RANGE_UPDATE")
        end
        if f.RegisterUnitEvent then
            f:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
            f:RegisterUnitEvent("UNIT_FLAGS", "target")
            f:RegisterUnitEvent("UNIT_HEALTH", "target")
        else
            f:RegisterEvent("UNIT_COMBAT")
            f:RegisterEvent("UNIT_FLAGS")
            f:RegisterEvent("UNIT_HEALTH")
        end
    end

    self:SetupEditMode()
end

function SwingTimer:OnDisable()
    local f = self.eventFrame
    if f then
        f:UnregisterEvent("UNIT_ATTACK_SPEED")
        f:UnregisterEvent("UNIT_SPELLCAST_START")
        f:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        f:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        f:UnregisterEvent("UNIT_SPELLCAST_FAILED")
        f:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        f:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        f:UnregisterEvent("START_AUTOREPEAT_SPELL")
        f:UnregisterEvent("STOP_AUTOREPEAT_SPELL")
        f:UnregisterEvent("PLAYER_TARGET_CHANGED")
        f:UnregisterEvent("PLAYER_REGEN_DISABLED")
        f:UnregisterEvent("PLAYER_ENTER_COMBAT")
        f:UnregisterEvent("PLAYER_LEAVE_COMBAT")
        f:UnregisterEvent("UNIT_COMBAT")
        f:UnregisterEvent("UNIT_FLAGS")
        f:UnregisterEvent("UNIT_HEALTH")
        if f.UnregisterEvent then
            pcall(f.UnregisterEvent, f, "PLAYER_SWING")
            pcall(f.UnregisterEvent, f, "PLAYER_SWING_RANGE_UPDATE")
        end
    end
    if self.playerFrame then self.playerFrame:Hide() end
    if self.targetFrame then self.targetFrame:Hide() end
    self:UpdateNativeSwingFramesVisibility()
end

-- ----------------------------------------------------------------------------
-- Frame Creation & Styling
-- ----------------------------------------------------------------------------

local function CreateBarWidget(parent, name)
    local bar = CreateFrame("StatusBar", name, parent, "BackdropTemplate")
    local texture = (LSM and LSM:Fetch("statusbar", "Solid")) or "Interface\\TargetingFrame\\UI-StatusBar"
    bar:SetStatusBarTexture(texture)

    if bar.SetBackdrop then
        bar:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        bar:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
        bar:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
    end

    local fontName = (SwingTimer.db and SwingTimer.db.font)
        or (RoithiUI and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.font)
        or "Roithi Thick"
    local utils = ns.Utils or (_G.RoithiUI and _G.RoithiUI.Utils)

    local labelText = bar:CreateFontString(nil, "OVERLAY")
    labelText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    if utils and utils.ApplyTypography then
        utils.ApplyTypography(labelText, fontName, 9, "OUTLINE", false, "Roithi Thick")
    end
    labelText:SetJustifyH("LEFT")
    bar.labelText = labelText

    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    if utils and utils.ApplyTypography then
        utils.ApplyTypography(timeText, fontName, 9, "OUTLINE", false, "Roithi Thick")
    end
    timeText:SetJustifyH("RIGHT")
    bar.timeText = timeText

    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(12, 24)
    spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
    bar.spark = spark

    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()
    SetClickthrough(bar, true)

    return bar
end

function SwingTimer:CreateFrames()
    if self.playerFrame and self.targetFrame then return end

    -- Player Container Frame
    local pFrame = CreateFrame("Frame", "RoithiSwingTimer_Player", UIParent)
    pFrame:SetSize(200, 26)
    pFrame:SetClampedToScreen(true)
    pFrame:SetMovable(true)
    pFrame:SetFrameStrata("HIGH")
    pFrame:SetFrameLevel(50)
    SetClickthrough(pFrame, true)

    pFrame.mainBar = CreateBarWidget(pFrame, "RoithiSwingTimer_Player_Main")
    pFrame.offBar = CreateBarWidget(pFrame, "RoithiSwingTimer_Player_Off")
    pFrame.rangedBar = CreateBarWidget(pFrame, "RoithiSwingTimer_Player_Ranged")

    pFrame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdatePlayer(elapsed)
    end)
    self.playerFrame = pFrame

    -- Target Container Frame
    local tFrame = CreateFrame("Frame", "RoithiSwingTimer_Target", UIParent)
    tFrame:SetSize(200, 14)
    tFrame:SetClampedToScreen(true)
    tFrame:SetMovable(true)
    tFrame:SetFrameStrata("HIGH")
    tFrame:SetFrameLevel(50)
    SetClickthrough(tFrame, true)

    tFrame.mainBar = CreateBarWidget(tFrame, "RoithiSwingTimer_Target_Main")

    tFrame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdateTarget(elapsed)
    end)
    self.targetFrame = tFrame
end

function SwingTimer:SetupEditMode()
    if not LEM or not LEM.AddFrame then return end

    if self.playerFrame and not self.playerFrame.editModeRegistered then
        self.playerFrame.editModeName = L["Player Swing Timer"] or "Player Swing Timer"
        self.playerFrame:SetMovable(true)
        local pCfg = self.db.player or self.defaultSettings.player
        local defPlayer = ns.Defaults.profile.SwingTimer.player
        local defaultPlayerPos = { point = defPlayer.point, x = defPlayer.x, y = defPlayer.y }
        LEM:AddFrame(self.playerFrame, function(f, _, newPoint, newX, newY)
            pCfg.point = newPoint
            pCfg.x = math.floor(newX * 100 + 0.5) / 100
            pCfg.y = math.floor(newY * 100 + 0.5) / 100
            if f and f.ClearAllPoints and f.SetPoint then
                f:ClearAllPoints()
                f:SetPoint(newPoint, UIParent, newPoint, pCfg.x, pCfg.y)
            end
            self:UpdateLayout()
            if self.isInEditMode then self:ShowSampleBars(true) end
            if LEM and LEM.RefreshFrameSettings then
                LEM:RefreshFrameSettings(f)
            end
        end, defaultPlayerPos, L["Player Swing Timer"] or "Player Swing Timer")

        if LEM.frameSelections and LEM.frameSelections[self.playerFrame] then
            local sel = LEM.frameSelections[self.playerFrame]
            if sel.SetFrameStrata then sel:SetFrameStrata(self.playerFrame:GetFrameStrata() or "HIGH") end
            if sel.SetFrameLevel then sel:SetFrameLevel(self.playerFrame:GetFrameLevel() + 50) end
            if sel.EnableMouse then sel:EnableMouse(true) end
            if sel.RegisterForDrag then sel:RegisterForDrag("LeftButton") end
        end

        if LEM.AddFrameSettings and self.GetPlayerLEMFrameSettings then
            LEM:AddFrameSettings(self.playerFrame, self:GetPlayerLEMFrameSettings())
        end

        if LEM.AddFrameSettingsButtons then
            LEM:AddFrameSettingsButtons(self.playerFrame, {
                {
                    text = L["Open Full Settings"] or "Open Full Settings",
                    click = function()
                        if RoithiUI and RoithiUI.OpenSettings then
                            RoithiUI:OpenSettings("swingtimer")
                        elseif LibStub("AceConfigDialog-3.0") then
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "combat", "swingtimer")
                            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                        end
                    end,
                },
            })
        end
        self.playerFrame.editModeRegistered = true
    end

    if self.targetFrame and not self.targetFrame.editModeRegistered then
        self.targetFrame.editModeName = L["Target Swing Timer"] or "Target Swing Timer"
        self.targetFrame:SetMovable(true)
        local tCfg = self.db.target or self.defaultSettings.target
        local defTarget = ns.Defaults.profile.SwingTimer.target
        local defaultTargetPos = { point = defTarget.point, x = defTarget.x, y = defTarget.y }
        LEM:AddFrame(self.targetFrame, function(f, _, newPoint, newX, newY)
            tCfg.point = newPoint
            tCfg.x = math.floor(newX * 100 + 0.5) / 100
            tCfg.y = math.floor(newY * 100 + 0.5) / 100
            if f and f.ClearAllPoints and f.SetPoint then
                f:ClearAllPoints()
                f:SetPoint(newPoint, UIParent, newPoint, tCfg.x, tCfg.y)
            end
            self:UpdateLayout()
            if self.isInEditMode then self:ShowSampleBars(true) end
            if LEM and LEM.RefreshFrameSettings then
                LEM:RefreshFrameSettings(f)
            end
        end, defaultTargetPos, L["Target Swing Timer"] or "Target Swing Timer")

        if LEM.frameSelections and LEM.frameSelections[self.targetFrame] then
            local sel = LEM.frameSelections[self.targetFrame]
            if sel.SetFrameStrata then sel:SetFrameStrata(self.targetFrame:GetFrameStrata() or "HIGH") end
            if sel.SetFrameLevel then sel:SetFrameLevel(self.targetFrame:GetFrameLevel() + 50) end
            if sel.EnableMouse then sel:EnableMouse(true) end
            if sel.RegisterForDrag then sel:RegisterForDrag("LeftButton") end
        end

        if LEM.AddFrameSettings and self.GetTargetLEMFrameSettings then
            LEM:AddFrameSettings(self.targetFrame, self:GetTargetLEMFrameSettings())
        end

        if LEM.AddFrameSettingsButtons then
            LEM:AddFrameSettingsButtons(self.targetFrame, {
                {
                    text = L["Open Full Settings"] or "Open Full Settings",
                    click = function()
                        if RoithiUI and RoithiUI.OpenSettings then
                            RoithiUI:OpenSettings("swingtimer")
                        elseif LibStub("AceConfigDialog-3.0") then
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "combat", "swingtimer")
                            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                        end
                    end,
                },
            })
        end
        self.targetFrame.editModeRegistered = true
    end

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.eventRegistryRegistered then
        _G.EventRegistry:RegisterCallback("EditMode.Enter", function()
            self:UpdateNativeSwingFramesVisibility()
        end, self)
        _G.EventRegistry:RegisterCallback("EditMode.Exit", function()
            self:UpdateNativeSwingFramesVisibility()
        end, self)
        self.eventRegistryRegistered = true
    end

    if LEM.RegisterCallback and not self.lemCallbackRegistered then
        LEM:RegisterCallback("enter", function()
            self.isInEditMode = true
            SetClickthrough(self.playerFrame, false)
            SetClickthrough(self.targetFrame, false)
            if self.playerFrame then
                self.playerFrame:EnableMouse(true)
                self.playerFrame:SetMovable(true)
            end
            if self.targetFrame then
                self.targetFrame:EnableMouse(true)
                self.targetFrame:SetMovable(true)
            end
            for _, f in ipairs({ self.playerFrame, self.targetFrame }) do
                if f and LEM.frameSelections and LEM.frameSelections[f] then
                    local sel = LEM.frameSelections[f]
                    if sel.SetFrameStrata then sel:SetFrameStrata(f:GetFrameStrata() or "HIGH") end
                    if sel.SetFrameLevel then sel:SetFrameLevel(f:GetFrameLevel() + 50) end
                    if sel.EnableMouse then sel:EnableMouse(true) end
                    if sel.RegisterForDrag then sel:RegisterForDrag("LeftButton") end
                    if sel.Show then sel:Show() end
                end
            end
            self:UpdateNativeSwingFramesVisibility()
            self:ShowSampleBars(true)
        end)
        LEM:RegisterCallback("exit", function()
            self.isInEditMode = false
            if self.playerFrame then self.playerFrame:SetMovable(false) end
            if self.targetFrame then self.targetFrame:SetMovable(false) end
            SetClickthrough(self.playerFrame, true)
            SetClickthrough(self.targetFrame, true)
            self:UpdateNativeSwingFramesVisibility()
            self:ShowSampleBars(false)
        end)
        self.lemCallbackRegistered = true
    end
end

local function ConfigureBarText(bar, cfg)
    if not bar or not cfg then return end

    local showLabel = true
    if cfg.showLabel ~= nil then
        showLabel = (cfg.showLabel == true)
    elseif cfg.showText ~= nil then
        showLabel = (cfg.showText ~= false)
    end

    local showTimer = true
    if cfg.showTimer ~= nil then
        showTimer = (cfg.showTimer == true)
    elseif cfg.showText ~= nil then
        showTimer = (cfg.showText ~= false)
    end

    if bar.labelText then
        bar.labelText:SetShown(showLabel)
        bar.labelText:ClearAllPoints()
        local lAnchor = cfg.labelAnchor or "LEFT"
        local lx = cfg.labelX or 4
        local ly = cfg.labelY or 0
        bar.labelText:SetPoint(lAnchor, bar, lAnchor, lx, ly)
        bar.labelText:SetJustifyH(lAnchor)
    end

    if bar.timeText then
        bar.timeText:SetShown(showTimer)
        bar.timeText:ClearAllPoints()
        local tAnchor = cfg.timerAnchor or "RIGHT"
        local tx = cfg.timerX or -4
        local ty = cfg.timerY or 0
        bar.timeText:SetPoint(tAnchor, bar, tAnchor, tx, ty)
        bar.timeText:SetJustifyH(tAnchor)
    end
end

function SwingTimer:ShowSampleBars(show)
    if not self.playerFrame or not self.targetFrame then return end

    if show then
        local pCfg = self.db.player or self.defaultSettings.player
        if pCfg.enabled ~= false then
            self.playerFrame:Show()
            self.playerFrame.mainBar:Show()
            self.playerFrame.mainBar:SetValue(0.6)
            self.playerFrame.mainBar.timeText:SetText("1.2s")
            self.playerFrame.mainBar.labelText:SetText(L["Main Hand"] or "Main Hand")

            if pCfg.showOffhand ~= false then
                self.playerFrame.offBar:Show()
                self.playerFrame.offBar:SetValue(0.3)
                self.playerFrame.offBar.timeText:SetText("0.6s")
                self.playerFrame.offBar.labelText:SetText(L["Off Hand"] or "Off Hand")
            else
                self.playerFrame.offBar:Hide()
            end
            ConfigureBarText(self.playerFrame.mainBar, pCfg)
            ConfigureBarText(self.playerFrame.offBar, pCfg)
        end

        local tCfg = self.db.target or self.defaultSettings.target
        if tCfg.enabled ~= false then
            self.targetFrame:Show()
            self.targetFrame.mainBar:Show()
            self.targetFrame.mainBar:SetValue(0.5)
            self.targetFrame.mainBar.timeText:SetText("1.0s")
            self.targetFrame.mainBar.labelText:SetText(L["Target"] or "Target")
            ConfigureBarText(self.targetFrame.mainBar, tCfg)
        end
    else
        self.playerFrame.mainBar:Hide()
        self.playerFrame.offBar:Hide()
        self.playerFrame.rangedBar:Hide()
        self.playerFrame:Hide()

        self.targetFrame.mainBar:Hide()
        self.targetFrame:Hide()
    end
end

function SwingTimer:UpdateLayout()
    if not self.playerFrame or not self.targetFrame then return end

    local pCfg = self.db.player or self.defaultSettings.player
    local tCfg = self.db.target or self.defaultSettings.target

    -- Player Frame Sizing & Anchors
    local pWidth = pCfg.width or 200
    local pHeight = pCfg.height or 12
    local hasOffhand = pCfg.showOffhand ~= false

    self.playerFrame:ClearAllPoints()
    self.playerFrame:SetPoint(pCfg.point or "CENTER", UIParent, pCfg.point or "CENTER", pCfg.x or 0, pCfg.y or -140)
    self.playerFrame:SetSize(pWidth, hasOffhand and (pHeight * 2 + 2) or pHeight)

    local isOffTop = (pCfg.barOrder == "OFF_TOP")
    local mb = self.playerFrame.mainBar
    local ob = self.playerFrame.offBar
    local rb = self.playerFrame.rangedBar

    if isOffTop then
        ob:ClearAllPoints()
        ob:SetPoint("TOPLEFT", self.playerFrame, "TOPLEFT", 0, 0)
        ob:SetSize(pWidth, pHeight)

        mb:ClearAllPoints()
        mb:SetPoint("TOPLEFT", ob, "BOTTOMLEFT", 0, -2)
        mb:SetSize(pWidth, pHeight)
    else
        mb:ClearAllPoints()
        mb:SetPoint("TOPLEFT", self.playerFrame, "TOPLEFT", 0, 0)
        mb:SetSize(pWidth, pHeight)

        ob:ClearAllPoints()
        ob:SetPoint("TOPLEFT", mb, "BOTTOMLEFT", 0, -2)
        ob:SetSize(pWidth, pHeight)
    end

    local mc = pCfg.colorMain or { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
    mb:SetStatusBarColor(mc.r, mc.g, mc.b, mc.a or 1.0)
    mb.labelText:SetText(L["Main Hand"] or "Main Hand")

    local oc = pCfg.colorOff or { r = 0.35, g = 0.75, b = 1.0, a = 1.0 }
    ob:SetStatusBarColor(oc.r, oc.g, oc.b, oc.a or 1.0)
    ob.labelText:SetText(L["Off Hand"] or "Off Hand")

    rb:ClearAllPoints()
    rb:SetPoint("TOPLEFT", self.playerFrame, "TOPLEFT", 0, 0)
    rb:SetSize(pWidth, pHeight)
    local rc = pCfg.colorRanged or { r = 0.2, g = 0.85, b = 0.35, a = 1.0 }
    rb:SetStatusBarColor(rc.r, rc.g, rc.b, rc.a or 1.0)
    rb.labelText:SetText(L["Ranged"] or "Ranged")

    ConfigureBarText(mb, pCfg)
    ConfigureBarText(ob, pCfg)
    ConfigureBarText(rb, pCfg)

    -- Target Frame Sizing & Anchors
    local tWidth = tCfg.width or 200
    local tHeight = tCfg.height or 12

    self.targetFrame:ClearAllPoints()
    self.targetFrame:SetPoint(tCfg.point or "CENTER", UIParent, tCfg.point or "CENTER", tCfg.x or 0, tCfg.y or -160)
    self.targetFrame:SetSize(tWidth, tHeight)

    local tb = self.targetFrame.mainBar
    tb:ClearAllPoints()
    tb:SetPoint("TOPLEFT", self.targetFrame, "TOPLEFT", 0, 0)
    tb:SetSize(tWidth, tHeight)
    local tc = tCfg.color or { r = 0.85, g = 0.25, b = 0.25, a = 1.0 }
    tb:SetStatusBarColor(tc.r, tc.g, tc.b, tc.a or 1.0)
    tb.labelText:SetText(L["Target"] or "Target")
    ConfigureBarText(tb, tCfg)

    self:UpdateNativeSwingFramesVisibility()
end

-- ----------------------------------------------------------------------------
-- Swing Lifecycle
-- ----------------------------------------------------------------------------

function SwingTimer:StartSwing(unit, swingType, duration)
    if IsSecret(duration) or type(duration) ~= "number" then
        if unit == "player" then
            if swingType == "off" then
                duration = self.cachedPlayerOffSpeed or 2.0
            elseif swingType == "ranged" then
                duration = self.cachedPlayerRangedSpeed or 2.5
            else
                duration = self.cachedPlayerMainSpeed or 2.0
            end
        else
            duration = self.cachedTargetSpeed or 2.0
        end
    end
    if not duration or duration <= 0 then return end
    local now = GetTime()

    if unit == "player" then
        if self.db.player and self.db.player.enabled == false then return end
        local record = self.playerSwings[swingType]
        if not record then return end

        record.startTime = now
        record.duration = duration
        record.active = true

        if not self.isInEditMode and self.playerFrame then
            self.playerFrame:Show()
            if swingType == "main" and self.playerFrame.mainBar then
                self.playerFrame.mainBar.lastTenth = nil
                self.playerFrame.mainBar:SetMinMaxValues(0, duration)
                self.playerFrame.mainBar:SetValue(0)
                self.playerFrame.mainBar:Show()
            elseif swingType == "off" and self.playerFrame.offBar and (self.db.player.showOffhand ~= false) then
                self.playerFrame.offBar.lastTenth = nil
                self.playerFrame.offBar:SetMinMaxValues(0, duration)
                self.playerFrame.offBar:SetValue(0)
                self.playerFrame.offBar:Show()
            elseif swingType == "ranged" and self.playerFrame.rangedBar then
                self.playerFrame.rangedBar.lastTenth = nil
                self.playerFrame.rangedBar:SetMinMaxValues(0, duration)
                self.playerFrame.rangedBar:SetValue(0)
                self.playerFrame.rangedBar:Show()
            end
        end
    elseif unit == "target" then
        if not UnitExists("target") or UnitIsDeadOrGhost("target") then return end
        if _G.UnitCanAttack and not UnitCanAttack("player", "target") then return end

        local inCombat = UnitAffectingCombat and UnitAffectingCombat("target")
        local isTargetingPlayer = false
        if UnitIsUnit then
            local ok, isUnit = pcall(UnitIsUnit, "targettarget", "player")
            if ok and not IsSecret(isUnit) and isUnit == true then
                isTargetingPlayer = true
            end
        end

        if _G.UnitAffectingCombat and not inCombat and not isTargetingPlayer then
            return
        end
        if self.db.target and self.db.target.enabled == false then return end

        if duration > 150 then
            duration = self.cachedTargetSpeed or 2.0
        end
        if duration > 10.0 then
            duration = 10.0
        elseif duration < 0.2 then
            duration = 0.2
        end

        local record = self.targetSwings.main
        record.startTime = now
        record.duration = duration
        record.active = true

        if not self.isInEditMode and self.targetFrame and self.targetFrame.mainBar then
            self.targetFrame:Show()
            self.targetFrame.mainBar.lastTenth = nil
            self.targetFrame.mainBar:SetMinMaxValues(0, duration)
            self.targetFrame.mainBar:SetValue(0)
            self.targetFrame.mainBar:Show()
        end
    end
end

function SwingTimer:ApplyParryHaste(unit)
    local now = GetTime()
    local record = (unit == "player") and self.playerSwings.main or self.targetSwings.main
    if not record or not record.active then return end

    if record.lastParryTime and (now - record.lastParryTime < 0.05) then
        return
    end
    record.lastParryTime = now

    if IsSecret(record.duration) or type(record.duration) ~= "number" or record.duration <= 0 then
        record.duration = (unit == "player") and (self.cachedPlayerMainSpeed or 2.0) or (self.cachedTargetSpeed or 2.0)
    end

    local elapsed = now - record.startTime
    local remaining = record.duration - elapsed
    if remaining <= 0 then return end

    local speed = record.duration
    local minRemaining = speed * 0.20

    -- In Classic mechanics, parry haste never alters swings already at or below 20%
    if remaining <= minRemaining then
        return
    end

    -- Canonical Classic 60%/20% Parry Haste Rule:
    -- If remaining > 60%, it reduces by 40% of weapon speed.
    -- If remaining is between 20% and 60%, it drops directly to 20% of weapon speed.
    local newRemaining
    if remaining <= speed * 0.60 then
        newRemaining = minRemaining
    else
        newRemaining = remaining - (speed * 0.40)
    end

    local diff = remaining - newRemaining
    if diff > 0 then
        record.startTime = record.startTime - diff
    end
end

function SwingTimer:ResetPlayerSwing()
    local mainSpeed = self:GetSafeAttackSpeed("player")
    self:StartSwing("player", "main", mainSpeed)
end

-- ----------------------------------------------------------------------------
-- Update Ticks
-- ----------------------------------------------------------------------------

function SwingTimer:OnUpdatePlayer(_)
    if self.isInEditMode or self.hasNativeFrames then return end
    local now = GetTime()
    local anyActive = false

    -- Main Hand
    local mh = self.playerSwings.main
    if mh.active then
        if IsSecret(mh.duration) or type(mh.duration) ~= "number" or mh.duration <= 0 then
            mh.duration = self.cachedPlayerMainSpeed or 2.0
        end
        local elapsed = now - mh.startTime
        if elapsed < mh.duration then
            anyActive = true
            local remain = mh.duration - elapsed
            local bar = self.playerFrame.mainBar
            bar:SetValue(elapsed)
            local tenth = math.floor(remain * 10)
            if tenth ~= bar.lastTenth then
                bar.lastTenth = tenth
                bar.timeText:SetText(string.format("%.1fs", math.max(0, remain)))
            end
            if bar.spark then
                local w = bar:GetWidth() or 200
                local prog = (mh.duration > 0) and math.min(1, math.max(0, elapsed / mh.duration)) or 0
                bar.spark:ClearAllPoints()
                bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
            end
        else
            mh.active = false
            self.playerFrame.mainBar.lastTenth = nil
            self.playerFrame.mainBar:Hide()
        end
    end

    -- Off Hand
    local oh = self.playerSwings.off
    if oh.active and (self.db.player.showOffhand ~= false) then
        if IsSecret(oh.duration) or type(oh.duration) ~= "number" or oh.duration <= 0 then
            oh.duration = self.cachedPlayerOffSpeed or 2.0
        end
        local elapsed = now - oh.startTime
        if elapsed < oh.duration then
            anyActive = true
            local remain = oh.duration - elapsed
            local bar = self.playerFrame.offBar
            bar:SetValue(elapsed)
            local tenth = math.floor(remain * 10)
            if tenth ~= bar.lastTenth then
                bar.lastTenth = tenth
                bar.timeText:SetText(string.format("%.1fs", math.max(0, remain)))
            end
            if bar.spark then
                local w = bar:GetWidth() or 200
                local prog = (oh.duration > 0) and math.min(1, math.max(0, elapsed / oh.duration)) or 0
                bar.spark:ClearAllPoints()
                bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
            end
        else
            oh.active = false
            self.playerFrame.offBar.lastTenth = nil
            self.playerFrame.offBar:Hide()
        end
    end

    -- Ranged
    local rg = self.playerSwings.ranged
    if rg.active then
        if IsSecret(rg.duration) or type(rg.duration) ~= "number" or rg.duration <= 0 then
            rg.duration = self.cachedPlayerRangedSpeed or 2.5
        end
        local elapsed = now - rg.startTime
        if elapsed < rg.duration then
            anyActive = true
            local remain = rg.duration - elapsed
            local bar = self.playerFrame.rangedBar
            bar:SetValue(elapsed)
            local tenth = math.floor(remain * 10)
            if tenth ~= bar.lastTenth then
                bar.lastTenth = tenth
                bar.timeText:SetText(string.format("%.1fs", math.max(0, remain)))
            end
            if bar.spark then
                local w = bar:GetWidth() or 200
                local prog = (rg.duration > 0) and math.min(1, math.max(0, elapsed / rg.duration)) or 0
                bar.spark:ClearAllPoints()
                bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
            end
        else
            rg.active = false
            self.playerFrame.rangedBar.lastTenth = nil
            self.playerFrame.rangedBar:Hide()
        end
    end

    if not anyActive then
        self.playerFrame:Hide()
    end
end

function SwingTimer:OnUpdateTarget(_)
    if self.isInEditMode then return end
    local tm = self.targetSwings.main

    local isTargetValid = UnitExists("target") and not UnitIsDeadOrGhost("target")
        and (not _G.UnitCanAttack or UnitCanAttack("player", "target"))
        and (not _G.UnitAffectingCombat or UnitAffectingCombat("target"))

    if not isTargetValid then
        if tm.active or (self.targetFrame and self.targetFrame:IsShown()) then
            tm.active = false
            if self.targetFrame and self.targetFrame.mainBar then
                self.targetFrame.mainBar.lastTenth = nil
                self.targetFrame.mainBar:Hide()
            end
            if self.targetFrame then
                self.targetFrame:Hide()
            end
        end
        return
    end

    local now = GetTime()
    if tm.active then
        if IsSecret(tm.duration) or type(tm.duration) ~= "number" or tm.duration <= 0 then
            tm.duration = self.cachedTargetSpeed or 2.0
        end
        local elapsed
        if tm.isCasting then
            elapsed = (tm.castPauseStart or now) - tm.startTime
        else
            elapsed = now - tm.startTime
        end
        if elapsed < tm.duration then
            local remain = tm.duration - elapsed
            local bar = self.targetFrame.mainBar
            bar:SetValue(elapsed)
            local tenth = math.floor(remain * 10)
            if tenth ~= bar.lastTenth then
                bar.lastTenth = tenth
                bar.timeText:SetText(string.format("%.1fs", math.max(0, remain)))
            end
            if bar.spark then
                local w = bar:GetWidth() or 200
                local prog = (tm.duration > 0) and math.min(1, math.max(0, elapsed / tm.duration)) or 0
                bar.spark:ClearAllPoints()
                bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
            end
        else
            tm.active = false
            self.targetFrame.mainBar.lastTenth = nil
            self.targetFrame.mainBar:Hide()
            self.targetFrame:Hide()
        end
    else
        self.targetFrame:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- Event Handlers
-- ----------------------------------------------------------------------------

function SwingTimer:OnCombatLog(event, ...)
    local info
    if _G.C_CombatLog and _G.C_CombatLog.GetCurrentEventInfo then
        info = { _G.C_CombatLog.GetCurrentEventInfo() }
    elseif _G.CombatLogGetCurrentEventInfo then
        info = { _G.CombatLogGetCurrentEventInfo() }
    elseif ... then
        info = { ... }
    end
    if not info or #info < 2 then return end

    local subevent = info[2]
    local sourceGUID = info[4]
    local destGUID = info[8]

    local playerGUID = UnitGUID and UnitGUID("player")
    local targetGUID = UnitGUID and UnitGUID("target")

    -- Player Actions
    if sourceGUID == playerGUID then
        if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
            local isOffHand = false
            if subevent == "SWING_DAMAGE" then
                isOffHand = info[21] or false
            elseif subevent == "SWING_MISSED" then
                isOffHand = info[13] or false
            end

            local mainSpeed, offSpeed = self:GetSafeAttackSpeed("player")

            if isOffHand and offSpeed and offSpeed > 0 then
                self:StartSwing("player", "off", offSpeed)
            else
                self:StartSwing("player", "main", mainSpeed or 2.0)
            end
        elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" then
            local spellId = info[12]
            if IsSpellInResetList(spellId) then
                local mainSpeed = self:GetSafeAttackSpeed("player")
                self:StartSwing("player", "main", mainSpeed)
            end
        elseif subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED" then
            local speed = self:GetSafeRangedSpeed("player")
            self:StartSwing("player", "ranged", speed)
        end
    end

    -- Target Actions
    if targetGUID and sourceGUID == targetGUID then
        if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
            local targetSpeed = self:GetSafeAttackSpeed("target")
            self:StartSwing("target", "main", targetSpeed)
        end
    end

    -- Parry Haste Detection (White Swings & Yellow Special Attacks)
    if subevent == "SWING_MISSED" or subevent == "SPELL_MISSED" or subevent == "SPELL_EXTRA_ATTACKS_MISSED" then
        local missType = (subevent == "SWING_MISSED") and info[12] or info[15]
        if missType == "PARRY" then
            if destGUID == playerGUID then
                self:ApplyParryHaste("player")
            elseif targetGUID and destGUID == targetGUID then
                self:ApplyParryHaste("target")
            end
        end
    end

    -- Target Death Detection
    if subevent == "UNIT_DIED" and targetGUID and destGUID == targetGUID then
        self.targetSwings.main.active = false
        if self.targetFrame and not self.isInEditMode then
            if self.targetFrame.mainBar then
                self.targetFrame.mainBar.lastTenth = nil
                self.targetFrame.mainBar:Hide()
            end
            self.targetFrame:Hide()
        end
    end
end

function SwingTimer:OnAttackSpeedChanged(_, unit)
    if unit == "player" then
        local mainSpeed, offSpeed = self:GetSafeAttackSpeed("player")
        if self.playerSwings.main.active and mainSpeed and mainSpeed > 0 then
            local oldDur = self.playerSwings.main.duration
            if oldDur and oldDur > 0 then
                local ratio = mainSpeed / oldDur
                local now = GetTime()
                local elapsed = (now - self.playerSwings.main.startTime) * ratio
                self.playerSwings.main.startTime = now - elapsed
                self.playerSwings.main.duration = mainSpeed
                if self.playerFrame and self.playerFrame.mainBar then
                    self.playerFrame.mainBar:SetMinMaxValues(0, mainSpeed)
                end
            end
        end
        if self.playerSwings.off.active and offSpeed and offSpeed > 0 then
            local oldDur = self.playerSwings.off.duration
            if oldDur and oldDur > 0 then
                local ratio = offSpeed / oldDur
                local now = GetTime()
                local elapsed = (now - self.playerSwings.off.startTime) * ratio
                self.playerSwings.off.startTime = now - elapsed
                self.playerSwings.off.duration = offSpeed
                if self.playerFrame and self.playerFrame.offBar then
                    self.playerFrame.offBar:SetMinMaxValues(0, offSpeed)
                end
            end
        end
    elseif unit == "target" then
        local targetSpeed = self:GetSafeAttackSpeed("target")
        if self.targetSwings.main.active and targetSpeed and targetSpeed > 0 then
            local oldDur = self.targetSwings.main.duration
            if oldDur and oldDur > 0 then
                local ratio = targetSpeed / oldDur
                local now = GetTime()
                local elapsed = (now - self.targetSwings.main.startTime) * ratio
                self.targetSwings.main.startTime = now - elapsed
                self.targetSwings.main.duration = targetSpeed
                if self.targetFrame and self.targetFrame.mainBar then
                    self.targetFrame.mainBar:SetMinMaxValues(0, targetSpeed)
                end
            end
        end
    end
end

function SwingTimer:OnSpellcastSucceeded(_, unit, _, spellId)
    if unit == "player" and IsSpellInResetList(spellId) then
        self:ResetPlayerSwing()
    end
    if unit == "target" then
        self:OnSpellcastFinished("UNIT_SPELLCAST_SUCCEEDED", unit)
        if IsSpellInResetList(spellId) then
            local targetSpeed = self:GetSafeAttackSpeed("target")
            self:StartSwing("target", "main", targetSpeed)
        end
    end
end

function SwingTimer:OnPlayerSwing(swingDuration, swingType)
    if self.isInEditMode or not self.playerFrame then return end
    if not IsSecret(swingDuration) and (type(swingDuration) ~= "number" or swingDuration <= 0) then return end
    if IsSecret(swingType) then swingType = 0 end

    -- Enum.PlayerSwingType: 0 = MainHand, 1 = OffHand, 2 = Ranged
    if swingType == 0 then
        self:StartSwing("player", "main", swingDuration)
    elseif swingType == 1 then
        self:StartSwing("player", "off", swingDuration)
    elseif swingType == 2 then
        self:StartSwing("player", "ranged", swingDuration)
    end
end

function SwingTimer:OnPlayerSwingRangeUpdate(swingType, isInRange, checksRange)
    if not self.playerFrame then return end
    if IsSecret(swingType) then swingType = 0 end
    local isOutOfRange = false
    if not IsSecret(checksRange) and not IsSecret(isInRange) then
        isOutOfRange = (checksRange == true and isInRange == false)
    end
    local bar
    if swingType == 0 then
        bar = self.playerFrame.mainBar
    elseif swingType == 1 then
        bar = self.playerFrame.offBar
    elseif swingType == 2 then
        bar = self.playerFrame.rangedBar
    end
    if bar and bar.timeText then
        if isOutOfRange then
            bar.timeText:SetTextColor(1.0, 0.2, 0.2, 1.0)
        else
            bar.timeText:SetTextColor(1.0, 1.0, 1.0, 1.0)
        end
    end
end

function SwingTimer:OnSpellcastStart(_, unit)
    if unit == "target" and self.targetSwings and self.targetSwings.main and self.targetSwings.main.active then
        self.targetSwings.main.isCasting = true
        self.targetSwings.main.castPauseStart = GetTime()
    end
end

function SwingTimer:OnSpellcastFinished(_, unit)
    if unit == "target" and self.targetSwings and self.targetSwings.main and self.targetSwings.main.isCasting then
        self.targetSwings.main.isCasting = false
        if self.targetSwings.main.castPauseStart then
            local pauseDuration = GetTime() - self.targetSwings.main.castPauseStart
            self.targetSwings.main.startTime = self.targetSwings.main.startTime + pauseDuration
            self.targetSwings.main.castPauseStart = nil
        end
    end
end

function SwingTimer:OnStartAutorepeat()
    local speed = self:GetSafeRangedSpeed("player")
    self:StartSwing("player", "ranged", speed)
end

function SwingTimer:OnStopAutorepeat()
    self.playerSwings.ranged.active = false
    if self.playerFrame and self.playerFrame.rangedBar then
        self.playerFrame.rangedBar:Hide()
    end
end

function SwingTimer:OnTargetChanged()
    self.targetSwings.main.active = false
    if self.targetFrame and not self.isInEditMode then
        if self.targetFrame.mainBar then
            self.targetFrame.mainBar.lastTenth = nil
            self.targetFrame.mainBar:Hide()
        end
        self.targetFrame:Hide()
    end
    if UnitExists("target") and not SafeUnitBool(UnitIsDeadOrGhost("target")) and (not _G.UnitCanAttack or SafeUnitBool(UnitCanAttack("player", "target"))) and (UnitAffectingCombat and SafeUnitBool(UnitAffectingCombat("target"))) then
        local targetSpeed = self:GetSafeAttackSpeed("target")
        self:StartSwing("target", "main", targetSpeed)
    end
end

function SwingTimer:OnUnitCombat(unit, action)
    if unit == "player" then
        if self.inCombat or (UnitAffectingCombat and SafeUnitBool(UnitAffectingCombat("player"))) then
            local mainSpeed = self:GetSafeAttackSpeed("player")
            self:StartSwing("player", "main", mainSpeed)
        end
        if UnitExists("target") and not SafeUnitBool(UnitIsDeadOrGhost("target")) and SafeUnitBool(UnitCanAttack("player", "target")) then
            local isTargetAttackingPlayer = false
            if ns.Utils and ns.Utils.SafeUnitIsUnit then
                local isMatch = ns.Utils.SafeUnitIsUnit("targettarget", "player")
                if isMatch then
                    isTargetAttackingPlayer = true
                end
            elseif UnitIsUnit then
                local ok, isUnit = pcall(UnitIsUnit, "targettarget", "player")
                if ok and not IsSecret(isUnit) and isUnit == true then
                    isTargetAttackingPlayer = true
                end
            end

            if isTargetAttackingPlayer then
                local targetSpeed = self:GetSafeAttackSpeed("target")
                self:StartSwing("target", "main", targetSpeed)
            end
        end
        if action == "PARRY" then
            self:ApplyParryHaste("player")
        end
    elseif unit == "target" then
        if SafeUnitBool(UnitIsDeadOrGhost("target")) or not SafeUnitBool(UnitCanAttack("player", "target")) then
            self.targetSwings.main.active = false
            if self.targetFrame and not self.isInEditMode then
                if self.targetFrame.mainBar then
                    self.targetFrame.mainBar.lastTenth = nil
                    self.targetFrame.mainBar:Hide()
                end
                self.targetFrame:Hide()
            end
            return
        end
        if action == "PARRY" then
            self:ApplyParryHaste("target")
        elseif not self.targetSwings.main.active and UnitExists("target") and SafeUnitBool(UnitCanAttack("player", "target")) and UnitAffectingCombat and SafeUnitBool(UnitAffectingCombat("target")) then
            local targetSpeed = self:GetSafeAttackSpeed("target")
            self:StartSwing("target", "main", targetSpeed)
        end
    end
end

function SwingTimer:OnEnterCombat()
    self.inCombat = true
    local mainSpeed = self:GetSafeAttackSpeed("player")
    self:StartSwing("player", "main", mainSpeed)
end

function SwingTimer:OnLeaveCombat()
    self.inCombat = false
    if not self.isInEditMode then
        self.playerSwings.main.active = false
        self.playerSwings.off.active = false
        self.playerSwings.ranged.active = false
        self.targetSwings.main.active = false
        if self.playerFrame then self.playerFrame:Hide() end
        if self.targetFrame then self.targetFrame:Hide() end
    end
end

function SwingTimer:RefreshProfile()
    self.db = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.SwingTimer or self.defaultSettings
    self:UpdateLayout()
    if LEM and LEM.RefreshFrameSettings then
        if self.playerFrame then LEM:RefreshFrameSettings(self.playerFrame) end
        if self.targetFrame then LEM:RefreshFrameSettings(self.targetFrame) end
    end
end
SwingTimer.RefreshSettings = SwingTimer.RefreshProfile

function SwingTimer:UpdateFonts()
    local fontName = (self.db and self.db.font)
        or (RoithiUI and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.font)
        or "Roithi Thick"
    local fontOutline = (self.db and self.db.fontOutline)
        or (RoithiUI and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General and RoithiUI.db.profile.General.fontOutline)
        or "OUTLINE"
    local utils = ns.Utils or (_G.RoithiUI and _G.RoithiUI.Utils)
    if not utils or not utils.ApplyTypography then return end

    local bars = {}
    if self.playerFrame then
        if self.playerFrame.mainBar then table.insert(bars, self.playerFrame.mainBar) end
        if self.playerFrame.offBar then table.insert(bars, self.playerFrame.offBar) end
        if self.playerFrame.rangedBar then table.insert(bars, self.playerFrame.rangedBar) end
    end
    if self.targetFrame and self.targetFrame.mainBar then
        table.insert(bars, self.targetFrame.mainBar)
    end

    for _, bar in ipairs(bars) do
        if bar.labelText then
            utils.ApplyTypography(bar.labelText, fontName, 9, fontOutline, false, "Roithi Thick")
        end
        if bar.timeText then
            utils.ApplyTypography(bar.timeText, fontName, 9, fontOutline, false, "Roithi Thick")
        end
    end
end
