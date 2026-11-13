local addonName, AT = ...
if AT.skipLoad then return end
local RoithiUI = AT.RoithiUI or _G.RoithiUI
local MinimapMod = RoithiUI:GetModule("Minimap")
local aceLocale = _G.LibStub and _G.LibStub("AceLocale-3.0", true)
local L = aceLocale and aceLocale.GetLocale and aceLocale:GetLocale("RoithiUI", true)

local function SafeCall(fn, ...)
    local utils = (AT and AT.Utils) or (_G.RoithiUI and _G.RoithiUI.Utils)
    if utils and utils.SafeCall then
        return utils.SafeCall(fn, ...)
    end
    return true, fn(...)
end

local isStylingBuffs = false
local buffBtnState = setmetatable({}, { __mode = "k" })

local cvarRestoreWindowStart = 0
local cvarRestoreCount = 0
local cvarLoopPaused = false
local pendingCvarRestore = false
local cvarWarningPrinted = false

local function GetBuffBtnState(frame)
    local st = buffBtnState[frame]
    if not st then
        st = {}
        buffBtnState[frame] = st
    end
    return st
end

local function RunCoalescedCvarRestore()
    pendingCvarRestore = false
    if MinimapMod and MinimapMod.EnsureBuffDurationsCVar then
        MinimapMod:EnsureBuffDurationsCVar(false)
    end
end

function MinimapMod:ResetBuffDurationLoopGuard()
    cvarLoopPaused = false
    cvarRestoreCount = 0
    cvarRestoreWindowStart = 0
    cvarWarningPrinted = false
end

function MinimapMod:EnsureBuffDurationsCVar(fromCVarEvent)
    local db = self.db
    if (self.IsEnabled and not self:IsEnabled()) or (db and db.enabled == false) then
        return false
    end
    if db and db.buffFrameForceDurations == false then
        return false
    end
    if not (_G.GetCVar and _G.SetCVar) then
        return false
    end

    local ok, curVal = SafeCall(_G.GetCVar, "buffDurations")
    if not ok or curVal ~= "0" then
        return true
    end
    if cvarLoopPaused then
        return false
    end

    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedBuffDurationsRestore = true
        return false
    end

    if fromCVarEvent and _G.C_Timer and _G.C_Timer.After then
        if not pendingCvarRestore then
            pendingCvarRestore = true
            _G.C_Timer.After(0, RunCoalescedCvarRestore)
        end
        return true
    end

    local now = _G.GetTime and _G.GetTime() or 0
    if now > 0 then
        if (now - cvarRestoreWindowStart) > 5 then
            cvarRestoreWindowStart = now
            cvarRestoreCount = 0
        end
        cvarRestoreCount = cvarRestoreCount + 1
        if cvarRestoreCount > 3 then
            cvarLoopPaused = true
            if not cvarWarningPrinted and RoithiUI and RoithiUI.Print then
                cvarWarningPrinted = true
                L = L or (aceLocale and aceLocale.GetLocale and aceLocale:GetLocale("RoithiUI", true))
                local msg = (L and L["External addon repeatedly disabled Blizzard's buffDurations CVar; paused auto-restore to prevent a loop."])
                    or "External addon repeatedly disabled Blizzard's buffDurations CVar; paused auto-restore to prevent a loop."
                RoithiUI:Print(msg)
            end
            return false
        end
    end

    self.queuedBuffDurationsRestore = nil
    SafeCall(_G.SetCVar, "buffDurations", "1")
    return true
end

local function StyleAuraButton(button, force)
    if not button then return end

    local st = GetBuffBtnState(button)
    local db = MinimapMod.db
    if db and db.buffFrameEnableSkinning == false then return end

    local font = (db and db.buffFrameFont) or "Friz Quadrata TT"
    local outline = (db and db.buffFrameFontOutline) or "OUTLINE"
    local showShadow = db and db.buffFrameShowShadow == true
    local utils = (AT and AT.Utils) or (_G.RoithiUI and _G.RoithiUI.Utils)
    local duration = button.Duration or button.duration

    if st.styled and not force then
        -- Only Duration needs drift recovery; Blizzard_BuffFrame only calls SetFontObject on Duration, never Count.
        if duration and duration.GetFont and utils and utils.ApplyTypography and utils.ResolveFontPath and utils.NormalizeFontFlags then
            local targetPath = utils.ResolveFontPath(font, "Friz Quadrata TT")
            local targetFlags = utils.NormalizeFontFlags(outline)
            local size = (db and db.buffFrameDurationSize) or 10
            local okFont, curPath, curSize, curFlags = SafeCall(duration.GetFont, duration)
            local invalidOrSecret = type(curPath) ~= "string"
                or (utils.IsSecret and utils.IsSecret(curPath))
                or type(curSize) ~= "number"
                or (utils.IsSecret and utils.IsSecret(curSize))
                or type(targetPath) ~= "string"
                or (curFlags ~= nil and (type(curFlags) ~= "string" or (utils.IsSecret and utils.IsSecret(curFlags))))
            if okFont and (invalidOrSecret or curPath:lower():gsub("/", "\\") ~= targetPath:lower():gsub("/", "\\") or (curFlags or "") ~= targetFlags or math.abs((tonumber(curSize) or 0) - size) > 0.5) then
                utils.ApplyTypography(duration, font, size, outline, showShadow, "Friz Quadrata TT", true)
            end
        end
        return
    end

    local showBorder = db and db.buffFrameShowBorder == true

    local icon = button.Icon or button.icon
    if icon and icon.SetTexCoord then
        if db and db.buffFrameZoomIcons == false then
            icon:SetTexCoord(0, 1, 0, 1)
        else
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end

    if not st.backdrop then
        local bg = CreateFrame("Frame", nil, button, "BackdropTemplate")
        bg:SetAllPoints(button)
        bg:SetFrameLevel(button:GetFrameLevel() > 0 and (button:GetFrameLevel() - 1) or 0)
        st.backdrop = bg
    end

    if st.backdrop then
        if showBorder then
            local edgeSize = (db and db.buffFrameBorderSize) or 1
            local col = (db and db.buffFrameBorderColor) or { r = 0, g = 0, b = 0, a = 1 }
            st.backdrop:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = edgeSize,
            })
            st.backdrop:SetBackdropBorderColor(col.r or 0, col.g or 0, col.b or 0, col.a or 1)
            st.backdrop:Show()
        else
            st.backdrop:Hide()
        end
    end

    local count = button.Count or button.count

    if duration and utils and utils.ApplyTypography then
        local size = (db and db.buffFrameDurationSize) or 10
        utils.ApplyTypography(duration, font, size, outline, showShadow, "Friz Quadrata TT", true)
    end

    if count and utils and utils.ApplyTypography then
        local size = (db and db.buffFrameCountSize) or 10
        utils.ApplyTypography(count, font, size, outline, showShadow, "Friz Quadrata TT", true)
    end

    st.styled = true
end

function MinimapMod:RefreshBuffFrameStyling()
    if _G.BuffFrame and _G.BuffFrame.auraFrames then
        for _, auraFrame in ipairs(_G.BuffFrame.auraFrames) do
            StyleAuraButton(auraFrame, true)
        end
    end
    if _G.DebuffFrame and _G.DebuffFrame.auraFrames then
        for _, auraFrame in ipairs(_G.DebuffFrame.auraFrames) do
            StyleAuraButton(auraFrame, true)
        end
    end
end

local function IsBuffEditModeActive(mod)
    local em = _G.EditModeManagerFrame
    return (mod and mod.isBuffEditModeActive)
        or (em and (em.editModeActive or em.layoutApplyInProgress or (em.IsShown and em:IsShown())))
end

local function ScheduleBuffDisplacement(mod, force)
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, function()
            if mod and mod.UpdateBuffFrameDisplacement then
                mod:UpdateBuffFrameDisplacement(force)
            end
        end)
    elseif mod and mod.UpdateBuffFrameDisplacement then
        mod:UpdateBuffFrameDisplacement(force)
    end
end

local function RegisterAuraFrameHooks(mod, targetFrame, withStyling)
    if not targetFrame then return end
    local frameSt = GetBuffBtnState(targetFrame)

    if targetFrame.UpdateAuraButtons and not frameSt.updateAuraButtonsHooked then
        frameSt.updateAuraButtonsHooked = true
        hooksecurefunc(targetFrame, "UpdateAuraButtons", function(frame)
            if (mod.IsEnabled and not mod:IsEnabled()) or (mod.db and mod.db.enabled == false) then return end
            if withStyling and frame and frame.auraFrames then
                for _, auraFrame in ipairs(frame.auraFrames) do
                    StyleAuraButton(auraFrame)
                end
            end
            if IsBuffEditModeActive(mod) then return end
            if mod.UpdateBuffFrameDisplacement then
                mod:UpdateBuffFrameDisplacement()
            end
        end)
    end

    if targetFrame.UpdateGridLayout and not frameSt.updateGridLayoutHooked then
        frameSt.updateGridLayoutHooked = true
        hooksecurefunc(targetFrame, "UpdateGridLayout", function()
            if (mod.IsEnabled and not mod:IsEnabled()) or (mod.db and mod.db.enabled == false) then return end
            if IsBuffEditModeActive(mod) then return end
            if mod.UpdateBuffFrameDisplacement then
                mod:UpdateBuffFrameDisplacement()
            end
        end)
    end
end

function MinimapMod:HookBuffFrameStyling()
    if isStylingBuffs then return end
    isStylingBuffs = true

    -- Ensure buffDurations CVar is active so Blizzard does not suppress aura duration text
    self:EnsureBuffDurationsCVar(false)

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.buffEditModeRegistered then
        _G.EventRegistry:RegisterCallback("EditMode.Enter", function()
            self.isBuffEditModeActive = true
        end, self)
        _G.EventRegistry:RegisterCallback("EditMode.Exit", function()
            self.isBuffEditModeActive = false
            ScheduleBuffDisplacement(self, true)
        end, self)
        self.buffEditModeRegistered = true
    end

    RegisterAuraFrameHooks(self, _G.BuffFrame, true)
    RegisterAuraFrameHooks(self, _G.DebuffFrame, true)

    if _G.BuffFrame and _G.BuffFrame.CollapseAndExpandButton then
        local btn = _G.BuffFrame.CollapseAndExpandButton
        local btnSt = GetBuffBtnState(btn)
        if not btnSt.hooked and btn.HookScript then
            btn:HookScript("OnClick", function()
                if (MinimapMod.IsEnabled and not MinimapMod:IsEnabled()) or (MinimapMod.db and MinimapMod.db.enabled == false) then return end
                if MinimapMod.UpdateBuffFrameDisplacement then
                    MinimapMod:UpdateBuffFrameDisplacement(true)
                end
            end)
            btnSt.hooked = true
        end
    end

    self:RefreshBuffFrameStyling()
    if self.UpdateBuffFrameDisplacement then
        self:UpdateBuffFrameDisplacement(true)
    end
end

local lastNumRows = nil
local lastFinalX = nil
local lastCollapseWidth = nil
local lastDebuffRelX = nil
local lastDebuffRelY = nil
local lastAnchorTarget = nil

local function SafeIsShown(frame)
    if not frame or not frame.IsShown then return false, false end
    local ok, shown = SafeCall(frame.IsShown, frame)
    if not ok then return false, false end
    local isSecret = (AT and AT.Utils and AT.Utils.IsSecret and AT.Utils.IsSecret(shown))
        or (issecretvalue and issecretvalue(shown))
    if isSecret then
        return false, true
    end
    return shown == true, false
end

local function IsNonSecretNumber(val)
    if type(val) ~= "number" then return false end
    local isSecret = (AT and AT.Utils and AT.Utils.IsSecret and AT.Utils.IsSecret(val))
        or (issecretvalue and issecretvalue(val))
    return not isSecret
end

local function SafeGetEffectiveScale(frame)
    if not frame or not frame.GetEffectiveScale then return 1 end
    local ok, s = SafeCall(frame.GetEffectiveScale, frame)
    if ok and IsNonSecretNumber(s) and s > 0 then
        return s
    end
    return 1
end

local function SafeGetCoord(region, methodName)
    if not region or not region[methodName] then return nil end
    local ok, val = SafeCall(region[methodName], region)
    if ok and IsNonSecretNumber(val) then
        return val
    end
    return nil
end

local function HasFrameAnchorDrifted(frame, expectedPoint, expectedRelTo, expectedRelPoint, expectedX, expectedY)
    if not frame or not frame.GetPoint then return true end
    local ok, pt, relTo, relPoint, xOfs, yOfs = SafeCall(frame.GetPoint, frame, 1)
    if not ok or not pt then return true end
    if (AT and AT.Utils and AT.Utils.IsSecret and (AT.Utils.IsSecret(pt) or AT.Utils.IsSecret(relPoint) or AT.Utils.IsSecret(xOfs) or AT.Utils.IsSecret(yOfs)))
        or (issecretvalue and (issecretvalue(pt) or issecretvalue(relPoint) or issecretvalue(xOfs) or issecretvalue(yOfs))) then
        return true
    end
    if pt ~= expectedPoint or relTo ~= expectedRelTo or relPoint ~= expectedRelPoint then
        return true
    end
    if not IsNonSecretNumber(xOfs) or not IsNonSecretNumber(yOfs) then
        return true
    end
    if math.abs(xOfs - expectedX) > 0.1 or math.abs(yOfs - expectedY) > 0.1 then
        return true
    end
    return false
end

local function GetNumVisibleBuffRows()
    local buffFrame = _G.BuffFrame
    if not buffFrame then return 0 end
    local isShown, isSecret = SafeIsShown(buffFrame)
    if isSecret then return lastNumRows or 1 end
    if not isShown then return 0 end
    if buffFrame.isExpanded == false then return 1 end

    local count = 0
    if buffFrame.auraFrames then
        for _, btn in ipairs(buffFrame.auraFrames) do
            local bShown, bSecret = SafeIsShown(btn)
            if bSecret then
                return lastNumRows or 1
            elseif bShown then
                count = count + 1
            end
        end
    end
    if buffFrame.ConsolidatedBuffs then
        local cShown, cSecret = SafeIsShown(buffFrame.ConsolidatedBuffs)
        if cSecret then
            return lastNumRows or 1
        elseif cShown then
            count = count + 1
        end
    end
    if count == 0 then return 0 end

    local stride = 10
    if buffFrame.AuraContainer and buffFrame.AuraContainer.iconStride and buffFrame.AuraContainer.iconStride > 0 then
        stride = buffFrame.AuraContainer.iconStride
    end
    return math.ceil(count / stride)
end

local function ComputeDebuffRelativeOffset(buffFrame, debuffFrame, numRows, collapseWidth)
    local buffEffScale = SafeGetEffectiveScale(buffFrame)
    local debuffEffScale = SafeGetEffectiveScale(debuffFrame)
    local debuffRelX = -((collapseWidth * buffEffScale) / debuffEffScale)
    if numRows == 0 then
        return debuffRelX, 0
    end

    local addIconsToTop = buffFrame and buffFrame.AuraContainer and buffFrame.AuraContainer.addIconsToTop
    local buffTopCoord = SafeGetCoord(buffFrame, "GetTop")
    if buffTopCoord and not addIconsToTop then
        local buffTopScreen = buffTopCoord * buffEffScale
        local lowestBottomScreen = nil

        local function TrackRegionBottom(region)
            local shown, secret = SafeIsShown(region)
            if secret or not shown then return end
            local bottomCoord = SafeGetCoord(region, "GetBottom")
            if bottomCoord then
                local screenB = bottomCoord * SafeGetEffectiveScale(region)
                if not lowestBottomScreen or screenB < lowestBottomScreen then
                    lowestBottomScreen = screenB
                end
            end
        end

        if buffFrame.auraFrames then
            for _, btn in ipairs(buffFrame.auraFrames) do
                TrackRegionBottom(btn)
                local dur = btn and (btn.Duration or btn.duration)
                if dur then
                    TrackRegionBottom(dur)
                end
            end
        end
        if buffFrame.ConsolidatedBuffs then
            TrackRegionBottom(buffFrame.ConsolidatedBuffs)
        end

        if lowestBottomScreen and lowestBottomScreen < buffTopScreen then
            local gapScreen = 5 * buffEffScale
            local debuffRelY = (lowestBottomScreen - gapScreen - buffTopScreen) / debuffEffScale
            return debuffRelX, debuffRelY
        end
    end

    -- Fallback when frame geometry is unavailable (pre-layout / headless stubs)
    local rowHeight = 45
    if buffFrame and buffFrame.auraFrames and buffFrame.auraFrames[1] then
        local h = SafeGetCoord(buffFrame.auraFrames[1], "GetHeight")
        local pad = (buffFrame.AuraContainer and buffFrame.AuraContainer.iconPadding) or 5
        local scale = (buffFrame.AuraContainer and buffFrame.AuraContainer.iconScale) or 1
        if h and h > 0 then
            rowHeight = (h + pad) * scale
        end
    end

    local rawY = -(numRows * rowHeight + 5)
    local debuffRelY = (rawY * buffEffScale) / debuffEffScale
    return debuffRelX, debuffRelY
end

function MinimapMod:UpdateBuffFrameDisplacement(force)
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.queuedBuffDisplacement = true
        return
    end

    local anchorTarget = self.container or _G.Minimap
    if not anchorTarget then return end

    local baseOffset = -8
    local displacement = 0

    -- Only displace if addon bar is attached, shown, and displaceBuffs is enabled
    if self.addonBar and self.db and self.db.addonBarAttached ~= false and self.db.showAddonBar and self.db.displaceBuffs ~= false then
        local w = self.addonBar:GetWidth() or 0
        local h = self.addonBar:GetHeight() or 0
        local isBarExpanded = (w > 25) and (h > 25)
        if isBarExpanded then
            displacement = w
        end
    end

    local finalX = baseOffset - displacement

    local buffFrame = _G.BuffFrame
    local buffDrifted = buffFrame and HasFrameAnchorDrifted(buffFrame, "TOPRIGHT", anchorTarget, "TOPLEFT", finalX, 0)
    if buffFrame and buffFrame.ClearAllPoints and buffFrame.SetPoint and (force or buffDrifted or finalX ~= lastFinalX or anchorTarget ~= lastAnchorTarget) then
        buffFrame:ClearAllPoints()
        buffFrame:SetPoint("TOPRIGHT", anchorTarget, "TOPLEFT", finalX, 0)
    end

    local debuffFrame = _G.DebuffFrame
    if not debuffFrame or not debuffFrame.ClearAllPoints or not debuffFrame.SetPoint then return end

    local numRows = GetNumVisibleBuffRows()
    local collapseWidth = 0
    if buffFrame and buffFrame.CollapseAndExpandButton then
        local cShown, cSecret = SafeIsShown(buffFrame.CollapseAndExpandButton)
        if cShown and not cSecret then
            collapseWidth = (buffFrame.CollapseAndExpandButton:GetWidth() or 15) * (buffFrame.CollapseAndExpandButton:GetScale() or 1)
        end
    end

    local anchorRef = buffFrame or anchorTarget
    local anchorRefPoint = buffFrame and "TOPRIGHT" or "TOPLEFT"
    local debuffRelX, debuffRelY
    if buffFrame then
        debuffRelX, debuffRelY = ComputeDebuffRelativeOffset(buffFrame, debuffFrame, numRows, collapseWidth)
    else
        debuffRelX = finalX - collapseWidth
        debuffRelY = (numRows == 0) and 0 or -(numRows * 45 + 5)
    end

    local debuffDrifted = HasFrameAnchorDrifted(debuffFrame, "TOPRIGHT", anchorRef, anchorRefPoint, debuffRelX, debuffRelY)

    if not force and not debuffDrifted and not buffDrifted
        and numRows == lastNumRows and finalX == lastFinalX and collapseWidth == lastCollapseWidth
        and anchorTarget == lastAnchorTarget
        and lastDebuffRelX and math.abs(lastDebuffRelX - debuffRelX) <= 0.1
        and lastDebuffRelY and math.abs(lastDebuffRelY - debuffRelY) <= 0.1 then
        return
    end

    lastNumRows = numRows
    lastFinalX = finalX
    lastCollapseWidth = collapseWidth
    lastDebuffRelX = debuffRelX
    lastDebuffRelY = debuffRelY
    lastAnchorTarget = anchorTarget

    debuffFrame:ClearAllPoints()
    debuffFrame:SetPoint("TOPRIGHT", anchorRef, anchorRefPoint, debuffRelX, debuffRelY)
end
