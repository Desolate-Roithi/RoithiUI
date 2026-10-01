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

SwingTimer.defaultSettings = {
    enabled = true,
    player = {
        enabled = true,
        width = 200,
        height = 12,
        showOffhand = true,
        showText = true,
        point = "CENTER",
        x = 0,
        y = -140,
        colorMain = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 },
        colorOff = { r = 0.35, g = 0.75, b = 1.0, a = 1.0 },
        colorRanged = { r = 0.2, g = 0.85, b = 0.35, a = 1.0 },
    },
    target = {
        enabled = true,
        width = 200,
        height = 12,
        showText = true,
        point = "CENTER",
        x = 0,
        y = -160,
        color = { r = 0.85, g = 0.25, b = 0.25, a = 1.0 },
    },
}

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
local function IsSecret(v)
    return (type(issecretvalue) == "function" and issecretvalue(v))
        or (type(canaccessvalue) == "function" and not canaccessvalue(v))
        or (type(v) == "userdata")
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

    if pCfg.showText ~= false then
        local label = frame.GetTimeLabel and frame:GetTimeLabel()
        local txt = label and label:GetText()
        if txt and txt ~= "" then
            bar.timeText:SetText(txt)
        else
            local dur = maxVal or 2.0
            local val = value or 0
            bar.timeText:SetText(string.format("%.1fs", math.max(0, dur - val)))
        end
    end

    if bar.spark and maxVal and maxVal > 0 then
        local w = bar:GetWidth() or 200
        local prog = math.min(1, math.max(0, (value or 0) / maxVal))
        bar.spark:ClearAllPoints()
        bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
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

function SwingTimer:BindNativeSwingFrames()
    self.nativeFramesBound = self.nativeFramesBound or {}
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

            if frame.SetAlpha then frame:SetAlpha(0) end
            if frame.UpdateSystemSettingOpacity and hooksecurefunc then
                hooksecurefunc(frame, "UpdateSystemSettingOpacity", function()
                    frame:SetAlpha(0)
                end)
            end

            local statusBar = frame.GetStatusBar and frame:GetStatusBar()
            if statusBar and hooksecurefunc then
                hooksecurefunc(statusBar, "SetValue", function(_, value)
                    self:SyncNativeProgress(hand, frame, value)
                end)
            end

            if frame.ResetSwingTimer and hooksecurefunc then
                hooksecurefunc(frame, "ResetSwingTimer", function()
                    self:SyncNativeReset(hand, frame)
                end)
            end

            if frame.ClearSwingTimer and hooksecurefunc then
                hooksecurefunc(frame, "ClearSwingTimer", function()
                    self:SyncNativeClear(hand, frame)
                end)
            end
        end
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
        if not self:IsEnabled() or (self.db and self.db.enabled == false) then return end
        if event == "ADDON_LOADED" then
            local loadedAddon = ...
            if loadedAddon == "Blizzard_SwingTimer" then
                self:BindNativeSwingFrames()
            end
        elseif event == "CVAR_UPDATE" then
            local cvarName = ...
            if cvarName == SHOW_SWING_TIMER_CVAR then
                self:EnsureBlizzardTimerEnabled()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            self:BindNativeSwingFrames()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            self:OnCombatLog(event, ...)
        elseif event == "UNIT_COMBAT" then
            self:OnUnitCombat(...)
        elseif event == "UNIT_ATTACK_SPEED" then
            self:OnAttackSpeedChanged(event, ...)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            self:OnSpellcastSucceeded(event, ...)
        elseif event == "START_AUTOREPEAT_SPELL" then
            self:OnStartAutorepeat()
        elseif event == "STOP_AUTOREPEAT_SPELL" then
            self:OnStopAutorepeat()
        elseif event == "PLAYER_TARGET_CHANGED" then
            self:OnTargetChanged()
        elseif event == "PLAYER_ENTER_COMBAT" or event == "PLAYER_REGEN_DISABLED" then
            self:OnEnterCombat()
        elseif event == "PLAYER_LEAVE_COMBAT" or event == "PLAYER_REGEN_ENABLED" then
            self:OnLeaveCombat()
            if self.queuedEnable then
                self.queuedEnable = false
                self:OnEnable()
            end
        end
    end)
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
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
        f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        f:RegisterEvent("START_AUTOREPEAT_SPELL")
        f:RegisterEvent("STOP_AUTOREPEAT_SPELL")
        f:RegisterEvent("PLAYER_TARGET_CHANGED")
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:RegisterEvent("PLAYER_ENTER_COMBAT")
        f:RegisterEvent("PLAYER_LEAVE_COMBAT")
        if f.RegisterUnitEvent then
            f:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
        else
            f:RegisterEvent("UNIT_COMBAT")
        end
    end

    self:SetupEditMode()
end

function SwingTimer:OnDisable()
    local f = self.eventFrame
    if f then
        f:UnregisterEvent("UNIT_ATTACK_SPEED")
        f:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        f:UnregisterEvent("START_AUTOREPEAT_SPELL")
        f:UnregisterEvent("STOP_AUTOREPEAT_SPELL")
        f:UnregisterEvent("PLAYER_TARGET_CHANGED")
        f:UnregisterEvent("PLAYER_REGEN_DISABLED")
        f:UnregisterEvent("PLAYER_ENTER_COMBAT")
        f:UnregisterEvent("PLAYER_LEAVE_COMBAT")
        f:UnregisterEvent("UNIT_COMBAT")
    end
    if self.playerFrame then self.playerFrame:Hide() end
    if self.targetFrame then self.targetFrame:Hide() end
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

    local fontPath = (LSM and LSM:Fetch("font", "Friz Quadrata TT")) or "Fonts\\FRIZQT__.TTF"

    local labelText = bar:CreateFontString(nil, "OVERLAY")
    labelText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    labelText:SetFont(fontPath, 9, "OUTLINE")
    labelText:SetJustifyH("LEFT")
    bar.labelText = labelText

    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timeText:SetFont(fontPath, 9, "OUTLINE")
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

    return bar
end

function SwingTimer:CreateFrames()
    if self.playerFrame and self.targetFrame then return end

    -- Player Container Frame
    local pFrame = CreateFrame("Frame", "RoithiSwingTimer_Player", UIParent)
    pFrame:SetClampedToScreen(true)
    pFrame:SetMovable(true)
    pFrame:SetFrameStrata("HIGH")
    pFrame:SetFrameLevel(50)

    pFrame.mainBar = CreateBarWidget(pFrame, "RoithiSwingTimer_Player_Main")
    pFrame.offBar = CreateBarWidget(pFrame, "RoithiSwingTimer_Player_Off")
    pFrame.rangedBar = CreateBarWidget(pFrame, "RoithiSwingTimer_Player_Ranged")

    pFrame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdatePlayer(elapsed)
    end)
    self.playerFrame = pFrame

    -- Target Container Frame
    local tFrame = CreateFrame("Frame", "RoithiSwingTimer_Target", UIParent)
    tFrame:SetClampedToScreen(true)
    tFrame:SetMovable(true)
    tFrame:SetFrameStrata("HIGH")
    tFrame:SetFrameLevel(50)

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
        local pCfg = self.db.player or self.defaultSettings.player
        LEM:AddFrame(self.playerFrame, function(_, _, newPoint, newX, newY)
            pCfg.point = newPoint
            pCfg.x = newX
            pCfg.y = newY
        end, { point = pCfg.point or "CENTER", x = pCfg.x or 0, y = pCfg.y or -140 })
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
        local tCfg = self.db.target or self.defaultSettings.target
        LEM:AddFrame(self.targetFrame, function(_, _, newPoint, newX, newY)
            tCfg.point = newPoint
            tCfg.x = newX
            tCfg.y = newY
        end, { point = tCfg.point or "CENTER", x = tCfg.x or 0, y = tCfg.y or -160 })
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

    if LEM.RegisterCallback and not self.lemCallbackRegistered then
        LEM:RegisterCallback("enter", function()
            self.isInEditMode = true
            self:ShowSampleBars(true)
        end)
        LEM:RegisterCallback("exit", function()
            self.isInEditMode = false
            self:ShowSampleBars(false)
        end)
        self.lemCallbackRegistered = true
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
            end
        end

        local tCfg = self.db.target or self.defaultSettings.target
        if tCfg.enabled ~= false then
            self.targetFrame:Show()
            self.targetFrame.mainBar:Show()
            self.targetFrame.mainBar:SetValue(0.5)
            self.targetFrame.mainBar.timeText:SetText("1.0s")
            self.targetFrame.mainBar.labelText:SetText(L["Target"] or "Target")
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

    -- Player Main Hand Bar
    local mb = self.playerFrame.mainBar
    mb:ClearAllPoints()
    mb:SetPoint("TOPLEFT", self.playerFrame, "TOPLEFT", 0, 0)
    mb:SetSize(pWidth, pHeight)
    local mc = pCfg.colorMain or { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
    mb:SetStatusBarColor(mc.r, mc.g, mc.b, mc.a or 1.0)
    mb.labelText:SetText(L["Main Hand"] or "Main Hand")
    mb.labelText:SetShown(pCfg.showText ~= false)
    mb.timeText:SetShown(pCfg.showText ~= false)

    -- Player Off Hand Bar
    local ob = self.playerFrame.offBar
    ob:ClearAllPoints()
    ob:SetPoint("TOPLEFT", mb, "BOTTOMLEFT", 0, -2)
    ob:SetSize(pWidth, pHeight)
    local oc = pCfg.colorOff or { r = 0.35, g = 0.75, b = 1.0, a = 1.0 }
    ob:SetStatusBarColor(oc.r, oc.g, oc.b, oc.a or 1.0)
    ob.labelText:SetText(L["Off Hand"] or "Off Hand")
    ob.labelText:SetShown(pCfg.showText ~= false)
    ob.timeText:SetShown(pCfg.showText ~= false)

    -- Player Ranged Bar (Overlays Main Bar)
    local rb = self.playerFrame.rangedBar
    rb:ClearAllPoints()
    rb:SetPoint("TOPLEFT", self.playerFrame, "TOPLEFT", 0, 0)
    rb:SetSize(pWidth, pHeight)
    local rc = pCfg.colorRanged or { r = 0.2, g = 0.85, b = 0.35, a = 1.0 }
    rb:SetStatusBarColor(rc.r, rc.g, rc.b, rc.a or 1.0)
    rb.labelText:SetText(L["Ranged"] or "Ranged")
    rb.labelText:SetShown(pCfg.showText ~= false)
    rb.timeText:SetShown(pCfg.showText ~= false)

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
    tb.labelText:SetShown(tCfg.showText ~= false)
    tb.timeText:SetShown(tCfg.showText ~= false)
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
                self.playerFrame.mainBar:SetMinMaxValues(0, duration)
                self.playerFrame.mainBar:SetValue(0)
                self.playerFrame.mainBar:Show()
            elseif swingType == "off" and self.playerFrame.offBar and (self.db.player.showOffhand ~= false) then
                self.playerFrame.offBar:SetMinMaxValues(0, duration)
                self.playerFrame.offBar:SetValue(0)
                self.playerFrame.offBar:Show()
            elseif swingType == "ranged" and self.playerFrame.rangedBar then
                self.playerFrame.rangedBar:SetMinMaxValues(0, duration)
                self.playerFrame.rangedBar:SetValue(0)
                self.playerFrame.rangedBar:Show()
            end
        end
    elseif unit == "target" then
        if self.db.target and self.db.target.enabled == false then return end
        local record = self.targetSwings.main
        record.startTime = now
        record.duration = duration
        record.active = true

        if not self.isInEditMode and self.targetFrame and self.targetFrame.mainBar then
            self.targetFrame:Show()
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

    if IsSecret(record.duration) or type(record.duration) ~= "number" or record.duration <= 0 then
        record.duration = (unit == "player") and (self.cachedPlayerMainSpeed or 2.0) or (self.cachedTargetSpeed or 2.0)
    end

    local elapsed = now - record.startTime
    local remaining = record.duration - elapsed
    if remaining <= 0 then return end

    -- Parry reduces remaining swing time by 40% of weapon speed, capped so at least 20% remains
    local reduction = record.duration * 0.40
    local minRemaining = record.duration * 0.20

    local newRemaining = math.max(minRemaining, remaining - reduction)
    local diff = remaining - newRemaining
    record.startTime = record.startTime - diff
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
            bar.timeText:SetText(string.format("%.1fs", remain))
            if bar.spark then
                local w = bar:GetWidth() or 200
                local prog = (mh.duration > 0) and math.min(1, math.max(0, elapsed / mh.duration)) or 0
                bar.spark:ClearAllPoints()
                bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
            end
        else
            mh.active = false
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
            bar.timeText:SetText(string.format("%.1fs", remain))
            if bar.spark then
                local w = bar:GetWidth() or 200
                local prog = (oh.duration > 0) and math.min(1, math.max(0, elapsed / oh.duration)) or 0
                bar.spark:ClearAllPoints()
                bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
            end
        else
            oh.active = false
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
            bar.timeText:SetText(string.format("%.1fs", remain))
            if bar.spark then
                local w = bar:GetWidth() or 200
                local prog = (rg.duration > 0) and math.min(1, math.max(0, elapsed / rg.duration)) or 0
                bar.spark:ClearAllPoints()
                bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
            end
        else
            rg.active = false
            self.playerFrame.rangedBar:Hide()
        end
    end

    if not anyActive then
        self.playerFrame:Hide()
    end
end

function SwingTimer:OnUpdateTarget(_)
    if self.isInEditMode then return end
    local now = GetTime()
    local tm = self.targetSwings.main

    if tm.active then
        if IsSecret(tm.duration) or type(tm.duration) ~= "number" or tm.duration <= 0 then
            tm.duration = self.cachedTargetSpeed or 2.0
        end
        local elapsed = now - tm.startTime
        if elapsed < tm.duration then
            local remain = tm.duration - elapsed
            local bar = self.targetFrame.mainBar
            bar:SetValue(elapsed)
            bar.timeText:SetText(string.format("%.1fs", remain))
            if bar.spark then
                local w = bar:GetWidth() or 200
                local prog = (tm.duration > 0) and math.min(1, math.max(0, elapsed / tm.duration)) or 0
                bar.spark:ClearAllPoints()
                bar.spark:SetPoint("CENTER", bar, "LEFT", prog * w, 0)
            end
        else
            tm.active = false
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
            if spellId and SWING_RESET_SPELLS[spellId] then
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

    -- Parry Haste Detection
    if subevent == "SWING_MISSED" then
        local missType = info[12]
        if missType == "PARRY" then
            if destGUID == playerGUID then
                self:ApplyParryHaste("player")
            elseif targetGUID and destGUID == targetGUID then
                self:ApplyParryHaste("target")
            end
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
    if unit == "player" and spellId and SWING_RESET_SPELLS[spellId] then
        self:ResetPlayerSwing()
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
        self.targetFrame.mainBar:Hide()
        self.targetFrame:Hide()
    end
end

function SwingTimer:OnUnitCombat(unit)
    if unit == "player" then
        if self.inCombat or (UnitAffectingCombat and UnitAffectingCombat("player")) then
            local mainSpeed = self:GetSafeAttackSpeed("player")
            self:StartSwing("player", "main", mainSpeed)
        end
    elseif unit == "target" then
        if UnitExists and UnitExists("target") then
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
