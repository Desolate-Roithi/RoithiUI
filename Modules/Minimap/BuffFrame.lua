local addonName, AT = ...
if AT.skipLoad then return end
local RoithiUI = AT.RoithiUI or _G.RoithiUI
local MinimapMod = RoithiUI:GetModule("Minimap")

local isStylingBuffs = false
local buffBtnState = setmetatable({}, { __mode = "k" })

local function GetBuffBtnState(frame)
    local st = buffBtnState[frame]
    if not st then
        st = {}
        buffBtnState[frame] = st
    end
    return st
end

local function StyleAuraButton(button)
    if not button then return end

    local db = MinimapMod.db
    local showBorder = db and db.buffFrameShowBorder == true

    local icon = button.Icon or button.icon
    if icon and icon.SetTexCoord then
        if db and db.buffFrameZoomIcons == false then
            icon:SetTexCoord(0, 1, 0, 1)
        else
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end

    local st = GetBuffBtnState(button)
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

    if db and db.buffFrameEnableSkinning == false then return end

    local duration = button.Duration or button.duration
    local count = button.Count or button.count
    local font = (db and db.buffFrameFont) or "Friz Quadrata TT"
    local outline = (db and db.buffFrameFontOutline) or "OUTLINE"
    local showShadow = db and db.buffFrameShowShadow == true

    local utils = (AT and AT.Utils) or (_G.RoithiUI and _G.RoithiUI.Utils)
    if duration and utils and utils.ApplyTypography then
        local size = (db and db.buffFrameDurationSize) or 10
        utils.ApplyTypography(duration, font, size, outline, showShadow, "Friz Quadrata TT")
    end

    if count and utils and utils.ApplyTypography then
        local size = (db and db.buffFrameCountSize) or 10
        utils.ApplyTypography(count, font, size, outline, showShadow, "Friz Quadrata TT")
    end

    st.styled = true
end

function MinimapMod:RefreshBuffFrameStyling()
    if _G.BuffFrame and _G.BuffFrame.auraFrames then
        for _, auraFrame in ipairs(_G.BuffFrame.auraFrames) do
            StyleAuraButton(auraFrame)
        end
    end
    if _G.DebuffFrame and _G.DebuffFrame.auraFrames then
        for _, auraFrame in ipairs(_G.DebuffFrame.auraFrames) do
            StyleAuraButton(auraFrame)
        end
    end
end

function MinimapMod:HookBuffFrameStyling()
    if isStylingBuffs then return end
    isStylingBuffs = true

    if _G.EventRegistry and _G.EventRegistry.RegisterCallback and not self.buffEditModeRegistered then
        _G.EventRegistry:RegisterCallback("EditMode.Enter", function()
            self.isBuffEditModeActive = true
        end, self)
        _G.EventRegistry:RegisterCallback("EditMode.Exit", function()
            self.isBuffEditModeActive = false
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(0, function()
                    if self.UpdateBuffFrameDisplacement then
                        self:UpdateBuffFrameDisplacement(true)
                    end
                end)
            elseif self.UpdateBuffFrameDisplacement then
                self:UpdateBuffFrameDisplacement(true)
            end
        end, self)
        self.buffEditModeRegistered = true
    end

    if _G.BuffFrame and _G.BuffFrame.UpdateAuraButtons then
        hooksecurefunc(_G.BuffFrame, "UpdateAuraButtons", function(frame)
            if frame.auraFrames then
                for _, auraFrame in ipairs(frame.auraFrames) do
                    StyleAuraButton(auraFrame)
                end
            end
            local em = _G.EditModeManagerFrame
            if self.isBuffEditModeActive or (em and (em.editModeActive or em.layoutApplyInProgress or (em.IsShown and em:IsShown()))) then
                return
            end
            if MinimapMod.UpdateBuffFrameDisplacement then
                MinimapMod:UpdateBuffFrameDisplacement()
            end
        end)
    end

    if _G.BuffFrame and _G.BuffFrame.UpdateGridLayout then
        hooksecurefunc(_G.BuffFrame, "UpdateGridLayout", function()
            local em = _G.EditModeManagerFrame
            if self.isBuffEditModeActive or (em and (em.editModeActive or em.layoutApplyInProgress or (em.IsShown and em:IsShown()))) then
                return
            end
            if MinimapMod.UpdateBuffFrameDisplacement then
                MinimapMod:UpdateBuffFrameDisplacement()
            end
        end)
    end

    if _G.DebuffFrame and _G.DebuffFrame.UpdateAuraButtons then
        hooksecurefunc(_G.DebuffFrame, "UpdateAuraButtons", function(frame)
            if frame.auraFrames then
                for _, auraFrame in ipairs(frame.auraFrames) do
                    StyleAuraButton(auraFrame)
                end
            end
        end)
    end

    if _G.BuffFrame and _G.BuffFrame.CollapseAndExpandButton then
        local btn = _G.BuffFrame.CollapseAndExpandButton
        local btnSt = GetBuffBtnState(btn)
        if not btnSt.hooked and btn.HookScript then
            btn:HookScript("OnClick", function()
                if MinimapMod.UpdateBuffFrameDisplacement then
                    MinimapMod:UpdateBuffFrameDisplacement(true)
                end
            end)
            btnSt.hooked = true
        end
    end
end

local lastNumRows = nil
local lastFinalX = nil
local lastCollapseWidth = nil

local function SafeIsShown(frame)
    if not frame or not frame.IsShown then return false, false end
    local ok, shown = pcall(frame.IsShown, frame)
    if not ok then return false, false end
    local isSecret = (AT and AT.Utils and AT.Utils.IsSecret and AT.Utils.IsSecret(shown))
        or (issecretvalue and issecretvalue(shown))
    if isSecret then
        return false, true
    end
    return shown == true, false
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
    if buffFrame and buffFrame.ClearAllPoints and buffFrame.SetPoint then
        buffFrame:ClearAllPoints()
        buffFrame:SetPoint("TOPRIGHT", anchorTarget, "TOPLEFT", finalX, 0)
    end

    local debuffFrame = _G.DebuffFrame
    if not debuffFrame or not debuffFrame.ClearAllPoints or not debuffFrame.SetPoint then return end

    local numRows = GetNumVisibleBuffRows()
    local collapseWidth = 0
    if buffFrame and buffFrame.CollapseAndExpandButton and buffFrame.CollapseAndExpandButton:IsShown() then
        collapseWidth = (buffFrame.CollapseAndExpandButton:GetWidth() or 15) * (buffFrame.CollapseAndExpandButton:GetScale() or 1)
    end

    if not force and numRows == lastNumRows and finalX == lastFinalX and collapseWidth == lastCollapseWidth then
        return
    end

    lastNumRows = numRows
    lastFinalX = finalX
    lastCollapseWidth = collapseWidth

    -- Dynamic row height: icon + duration + padding
    local rowHeight = 45
    if buffFrame and buffFrame.auraFrames and buffFrame.auraFrames[1] then
        local h = buffFrame.auraFrames[1]:GetHeight()
        local pad = (buffFrame.AuraContainer and buffFrame.AuraContainer.iconPadding) or 5
        local scale = (buffFrame.AuraContainer and buffFrame.AuraContainer.iconScale) or 1
        if h and h > 0 then
            rowHeight = (h + pad) * scale
        end
    end

    local debuffY = (numRows == 0) and 0 or -(numRows * rowHeight + 5)
    local debuffX = finalX - collapseWidth

    debuffFrame:ClearAllPoints()
    debuffFrame:SetPoint("TOPRIGHT", anchorTarget, "TOPLEFT", debuffX, debuffY)
end
