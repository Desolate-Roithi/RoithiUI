local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local CDM = RoithiUI:GetModule("CooldownManager")
local LSM = LibStub("LibSharedMedia-3.0", true)

local itemBackdrops = setmetatable({}, { __mode = "k" })
local itemStackOverlays = setmetatable({}, { __mode = "k" })

local function GetActiveFont(fontName)
    if LSM then
        if fontName then
            local fetched = LSM:Fetch("font", fontName)
            if fetched then return fetched end
        end
        local thick = LSM:Fetch("font", "Roithi Thick")
        if thick then return thick end
    end
    if fontName and (fontName:find("\\") or fontName:find("/")) then
        return fontName
    end
    return "Fonts\\FRIZQT__.TTF"
end

function CDM:StyleItemFrame(viewerKey, itemFrame)
    if not itemFrame then return end

    -- Locate the primary icon texture
    local icon = itemFrame.Icon
    if icon and icon.Icon then
        icon = icon.Icon
    end

    -- 1. Strip ALL masks attached directly to the icon texture via WoW API
    if icon and icon.GetNumMaskTextures and icon.RemoveMaskTexture then
        local numMasks = icon:GetNumMaskTextures() or 0
        for i = numMasks, 1, -1 do
            local mask = icon:GetMaskTexture(i)
            if mask then
                pcall(icon.RemoveMaskTexture, icon, mask)
                if mask.Hide then mask:Hide() end
                if mask.SetAlpha then mask:SetAlpha(0) end
            end
        end
    end

    -- 2. Strip explicit mask properties
    if itemFrame.IconMask and icon and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture, icon, itemFrame.IconMask)
        if itemFrame.IconMask.Hide then itemFrame.IconMask:Hide() end
        if itemFrame.IconMask.SetAlpha then itemFrame.IconMask:SetAlpha(0) end
    end
    if itemFrame.Icon and itemFrame.Icon.IconMask and icon and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture, icon, itemFrame.Icon.IconMask)
        if itemFrame.Icon.IconMask.Hide then itemFrame.Icon.IconMask:Hide() end
        if itemFrame.Icon.IconMask.SetAlpha then itemFrame.Icon.IconMask:SetAlpha(0) end
    end

    -- 3. Thoroughly inspect and strip MaskTexture / rounded overlays across itemFrame and icon container
    local function StripMaskAndOverlayRegions(frameObj)
        if not frameObj or not frameObj.GetRegions then return end
        local regions = { frameObj:GetRegions() }
        if #regions == 1 and type(regions[1]) == "table" and not regions[1].IsObjectType then
            regions = regions[1]
        end
        for _, region in ipairs(regions) do
            if region ~= icon and region ~= itemFrame.Icon then
                local objType = region.GetObjectType and region:GetObjectType()
                local isMask = (objType == "MaskTexture") or (region.IsObjectType and region:IsObjectType("MaskTexture"))
                local atlas = region.GetAtlas and region:GetAtlas()
                local isMaskTex = false
                local tex = region.GetTexture and region:GetTexture()
                local isSecret = (issecretvalue and issecretvalue(tex)) or (canaccessvalue and not canaccessvalue(tex))
                if tex and not isSecret then
                    local ok, isMatch = pcall(function() return tex == 6707800 end)
                    if ok and isMatch then
                        isMaskTex = true
                    end
                end

                if isMask or atlas == "UI-HUD-CoolDownManager-Mask" or isMaskTex then
                    if icon and icon.RemoveMaskTexture then
                        pcall(icon.RemoveMaskTexture, icon, region)
                    end
                    if region.Hide then region:Hide() end
                    if region.SetAlpha then region:SetAlpha(0) end
                elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                    if region.Hide then region:Hide() end
                    if region.SetAlpha then region:SetAlpha(0) end
                end
            end
        end
    end

    StripMaskAndOverlayRegions(itemFrame)
    if itemFrame.Icon and itemFrame.Icon ~= icon then
        StripMaskAndOverlayRegions(itemFrame.Icon)
    end

    -- 4. Apply square crop to eliminate default Blizzard icon borders
    if icon and icon.SetTexCoord then
        if self.db.cropIcons ~= false then
            local zoom = self.db.iconZoom or 0.07
            local zoomMax = tonumber(string.format("%.4f", 1 - zoom)) or (1 - zoom)
            icon:SetTexCoord(zoom, zoomMax, zoom, zoomMax)
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
    end

    -- 5. Ensure icon fills the frame
    if icon and icon.ClearAllPoints and icon.SetAllPoints then
        icon:ClearAllPoints()
        icon:SetAllPoints(itemFrame.Icon and itemFrame.Icon ~= icon and itemFrame.Icon or itemFrame)
    end

    -- 1px Roithi Backdrop
    local bg = itemBackdrops[itemFrame] or itemFrame.roithiBackdrop
    if not bg then
        bg = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
        if bg.SetAllPoints then bg:SetAllPoints(itemFrame) end
        if bg.SetFrameLevel and itemFrame.GetFrameLevel then
            bg:SetFrameLevel(itemFrame:GetFrameLevel() + 2)
        end
        if bg.SetBackdrop then
            bg:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = self.db.borderSize or 1,
            })
        end
        itemBackdrops[itemFrame] = bg
        itemFrame.roithiBackdrop = bg
    else
        if bg.SetFrameLevel and itemFrame.GetFrameLevel then
            bg:SetFrameLevel(itemFrame:GetFrameLevel() + 2)
        end
    end

    local c = self.db.borderColor or { r = 0, g = 0, b = 0, a = 1.0 }
    if bg.SetBackdropColor then bg:SetBackdropColor(0, 0, 0, 0) end
    if bg.SetBackdropBorderColor then
        bg:SetBackdropBorderColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1.0)
    end
    if bg.Show then bg:Show() end

    local vConf = self.db.viewers and self.db.viewers[viewerKey]
    if not vConf and viewerKey and viewerKey:find("^CustomBar") then
        local cIdx = tonumber(viewerKey:match("^CustomBar(%d+)"))
        if cIdx and self.db.customBars then
            vConf = self.db.customBars[cIdx]
        end
    end

    local isOverridden = (vConf and vConf.overrideGlobal == true)

    -- Cooldown frame countdown font, position, and square swipe
    local cd = itemFrame.Cooldown or (itemFrame.GetCooldownFrame and itemFrame:GetCooldownFrame())
    if cd then
        if cd.GetNumMaskTextures and cd.RemoveMaskTexture then
            local cdMaskCount = cd:GetNumMaskTextures() or 0
            for i = cdMaskCount, 1, -1 do
                local mask = cd:GetMaskTexture(i)
                if mask then
                    pcall(cd.RemoveMaskTexture, cd, mask)
                    if mask.Hide then mask:Hide() end
                    if mask.SetAlpha then mask:SetAlpha(0) end
                end
            end
        end
        if cd.SetSwipeTexture then
            pcall(cd.SetSwipeTexture, cd, "Interface\\Buttons\\WHITE8x8", 0, 0, 0, 0.64)
        end
        if cd.SetDrawEdge then
            pcall(cd.SetDrawEdge, cd, false)
        end
        if cd.SetDrawBling then
            pcall(cd.SetDrawBling, cd, false)
        end

        local fontName = (isOverridden and vConf.font) or self.db.font
        local fontPath = GetActiveFont(fontName)
        if cd.SetCountdownFont then
            pcall(cd.SetCountdownFont, cd, fontPath)
        end
        local showTimer = (vConf and vConf.showTimer ~= nil) and vConf.showTimer or true
        if cd.SetHideCountdownNumbers then
            pcall(cd.SetHideCountdownNumbers, cd, not showTimer)
        end
        local cdFS = cd.GetCountdownFontString and cd:GetCountdownFontString()
        if cdFS then
            local cdSize = (isOverridden and vConf.cooldownFontSize) or self.db.cooldownFontSize or 14
            local cdOutline = (isOverridden and vConf.cooldownFontOutline) or self.db.cooldownFontOutline or "OUTLINE"
            if cdSize == 0 or not showTimer then
                if cdFS.SetFontHeight then cdFS:SetFontHeight(0) end
                if cdFS.Hide then cdFS:Hide() end
            else
                if cdFS.Show then cdFS:Show() end
                if cdFS.SetFont then
                    cdFS:SetFont(fontPath, cdSize, cdOutline)
                end
                if cdFS.SetDrawLayer then
                    cdFS:SetDrawLayer("OVERLAY", 7)
                end
                if cdFS.SetShadowOffset then
                    if cdOutline ~= "NONE" and cdOutline ~= "" then
                        cdFS:SetShadowOffset(0, 0)
                    else
                        cdFS:SetShadowOffset(1, -1)
                    end
                end
            end
            local cdAnchor = (isOverridden and (vConf.cooldownAnchor or vConf.timerAnchor)) or self.db.cooldownAnchor or "CENTER"
            local defaultCdX, defaultCdY, defaultCdJustifyH = (ns.Utils and ns.Utils.GetDefaultAnchorOffsets) and ns.Utils.GetDefaultAnchorOffsets(cdAnchor, 2) or (cdAnchor:find("RIGHT") and -2 or (cdAnchor:find("LEFT") and 2 or 0)), (cdAnchor:find("TOP") and -2 or (cdAnchor:find("BOTTOM") and 2 or 0)), "CENTER"
            local cdX = isOverridden and (vConf.cooldownOffsetX or vConf.timerOffsetX) or self.db.cooldownOffsetX or defaultCdX
            local cdY = isOverridden and (vConf.cooldownOffsetY or vConf.timerOffsetY) or self.db.cooldownOffsetY or defaultCdY
            if cdFS.SetJustifyH then
                cdFS:SetJustifyH(defaultCdJustifyH)
            end
            if cdFS.ClearAllPoints and cdFS.SetPoint then
                cdFS:ClearAllPoints()
                cdFS:SetPoint(cdAnchor, cd, cdAnchor, cdX, cdY)
            end
        end
    end

    -- Elevate stack / charge count frame levels to render above buttons & borders
    if itemFrame.ChargeCount and itemFrame.ChargeCount.SetFrameStrata and itemFrame.GetFrameStrata then
        itemFrame.ChargeCount:SetFrameStrata(itemFrame:GetFrameStrata())
        if itemFrame.ChargeCount.SetFrameLevel and itemFrame.GetFrameLevel then
            itemFrame.ChargeCount:SetFrameLevel((itemFrame:GetFrameLevel() or 10) + 25)
        end
    end
    if itemFrame.Applications and itemFrame.Applications.SetFrameStrata and itemFrame.GetFrameStrata then
        itemFrame.Applications:SetFrameStrata(itemFrame:GetFrameStrata())
        if itemFrame.Applications.SetFrameLevel and itemFrame.GetFrameLevel then
            itemFrame.Applications:SetFrameLevel((itemFrame:GetFrameLevel() or 10) + 25)
        end
    end

    -- Stack / Charge count fontstring styling
    local stackFS = nil
    if itemFrame.GetChargeCountFontString then
        stackFS = itemFrame:GetChargeCountFontString()
    elseif itemFrame.GetApplicationsFontString then
        stackFS = itemFrame:GetApplicationsFontString()
    elseif itemFrame.ChargeCount and itemFrame.ChargeCount.Current then
        stackFS = itemFrame.ChargeCount.Current
    elseif itemFrame.Applications and itemFrame.Applications.Applications then
        stackFS = itemFrame.Applications.Applications
    elseif itemFrame.Applications and itemFrame.Applications.IsObjectType and itemFrame.Applications:IsObjectType("FontString") then
        stackFS = itemFrame.Applications
    elseif itemFrame.Icon and itemFrame.Icon.Applications then
        stackFS = itemFrame.Icon.Applications
    elseif itemFrame.Count then
        stackFS = itemFrame.Count
    end

    if stackFS then
        local stackParent = stackFS.GetParent and stackFS:GetParent()
        if stackParent and stackParent ~= itemFrame and stackParent.SetFrameStrata and itemFrame.GetFrameStrata then
            stackParent:SetFrameStrata(itemFrame:GetFrameStrata())
            if stackParent.SetFrameLevel and itemFrame.GetFrameLevel then
                stackParent:SetFrameLevel((itemFrame:GetFrameLevel() or 10) + 25)
            end
        elseif stackParent and stackParent == itemFrame then
            local stackOverlay = itemStackOverlays[itemFrame] or itemFrame.roithiStackOverlay
            if not stackOverlay and CreateFrame then
                stackOverlay = CreateFrame("Frame", nil, itemFrame)
                stackOverlay:SetAllPoints(itemFrame)
                if stackOverlay.SetFrameStrata and itemFrame.GetFrameStrata then
                    stackOverlay:SetFrameStrata(itemFrame:GetFrameStrata())
                end
                if itemFrame.GetFrameLevel then
                    stackOverlay:SetFrameLevel((itemFrame:GetFrameLevel() or 10) + 25)
                end
                if stackOverlay.EnableMouse then stackOverlay:EnableMouse(false) end
                itemStackOverlays[itemFrame] = stackOverlay
            end
            if stackOverlay and stackFS.SetParent then
                pcall(stackFS.SetParent, stackFS, stackOverlay)
            end
        end

        if stackFS.SetDrawLayer then
            stackFS:SetDrawLayer("OVERLAY", 7)
        end

        local fontName = (isOverridden and vConf.font) or self.db.font
        local fontPath = GetActiveFont(fontName)
        local fontSize = (isOverridden and vConf.stackFontSize) or self.db.stackFontSize or 11
        local fontOutline = (isOverridden and vConf.stackFontOutline) or self.db.stackFontOutline or "OUTLINE"
        if stackFS.SetFont then
            stackFS:SetFont(fontPath, fontSize, fontOutline)
        end
        if stackFS.SetShadowOffset then
            if fontOutline ~= "NONE" and fontOutline ~= "" then
                stackFS:SetShadowOffset(0, 0)
            else
                stackFS:SetShadowOffset(1, -1)
            end
        end
        if stackFS.SetSize then
            stackFS:SetSize(0, 0)
        end
        if stackFS.ClearAllPoints and stackFS.SetPoint then
            local anchor = (isOverridden and vConf.stackAnchor) or self.db.stackAnchor or "BOTTOMRIGHT"
            local defaultOx, defaultOy, defaultStackJustifyH = (ns.Utils and ns.Utils.GetDefaultAnchorOffsets) and ns.Utils.GetDefaultAnchorOffsets(anchor, 2) or (anchor:find("RIGHT") and -2 or (anchor:find("LEFT") and 2 or 0)), (anchor:find("TOP") and -2 or (anchor:find("BOTTOM") and 2 or 0)), "CENTER"
            local ox = isOverridden and vConf.stackOffsetX or self.db.stackOffsetX or defaultOx
            local oy = isOverridden and vConf.stackOffsetY or self.db.stackOffsetY or defaultOy
            if stackFS.SetJustifyH then
                stackFS:SetJustifyH(defaultStackJustifyH)
            end
            stackFS:ClearAllPoints()
            stackFS:SetPoint(anchor, itemFrame, anchor, ox, oy)
        end

        local showStacks = (vConf and vConf.showStacks ~= nil) and vConf.showStacks or true
        if not showStacks then
            if stackFS.Hide then stackFS:Hide() end
            if stackFS.SetAlpha then stackFS:SetAlpha(0) end
        else
            if stackFS.Show then stackFS:Show() end
            if stackFS.SetAlpha then stackFS:SetAlpha(1) end
        end
    end

    if viewerKey == "BuffBar" then
        -- Hide itemFrame global backdrop so icon and bar have clean individual 1px borders
        if bg and bg.Hide then bg:Hide() end

        local bar = itemFrame.Bar or (itemFrame.GetBarFrame and itemFrame:GetBarFrame())
        local iconFrame = itemFrame.Icon or (itemFrame.GetIconFrame and itemFrame:GetIconFrame())
        local barWidth = (vConf and vConf.barWidth) or 220
        local barHeight = (vConf and vConf.barHeight) or 24
        local showIcon = not vConf or vConf.showIcon ~= false
        local iconMatchBarHeight = not vConf or vConf.iconMatchBarHeight ~= false

        local iconW = barHeight
        local iconH = barHeight
        if not iconMatchBarHeight then
            local customSz = (vConf and (vConf.iconSize or vConf.iconWidth)) or barHeight
            iconW = customSz
            iconH = (vConf and (vConf.iconHeight or customSz)) or customSz
        end

        if iconFrame then
            -- Also strip ornate overlay and mask from iconFrame child regions
            if iconFrame.GetRegions then
                local ifRegions = { iconFrame:GetRegions() }
                if #ifRegions == 1 and type(ifRegions[1]) == "table" and not ifRegions[1].IsObjectType then
                    ifRegions = ifRegions[1]
                end
                for _, region in ipairs(ifRegions) do
                    if region.IsObjectType and region:IsObjectType("Texture") then
                        local atlas = region.GetAtlas and region:GetAtlas()
                        if atlas and atlas:find("IconOverlay") then
                            region:SetAlpha(0)
                            if region.Hide then region:Hide() end
                        end
                    elseif region.IsObjectType and region:IsObjectType("MaskTexture") then
                        if self.db.cropIcons then
                            if icon and icon.RemoveMaskTexture then
                                pcall(icon.RemoveMaskTexture, icon, region)
                            end
                            region:SetAlpha(0)
                        end
                    end
                end
            end

            if not showIcon then
                if iconFrame.Hide then iconFrame:Hide() end
                local oldIconBg = itemBackdrops[iconFrame] or iconFrame.roithiBackdrop
                if oldIconBg and oldIconBg.Hide then
                    oldIconBg:Hide()
                end
            else
                if iconFrame.Show then iconFrame:Show() end
                if iconFrame.SetSize then iconFrame:SetSize(iconW, iconH) end
                if iconFrame.ClearAllPoints and iconFrame.SetPoint then
                    iconFrame:ClearAllPoints()
                    iconFrame:SetPoint("LEFT", itemFrame, "LEFT", 0, 0)
                end

                -- Dedicated 1px border for BuffBar icon
                local iconBg = itemBackdrops[iconFrame] or iconFrame.roithiBackdrop
                if not iconBg then
                    iconBg = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
                    if iconBg.SetAllPoints then iconBg:SetAllPoints(iconFrame) end
                    if iconBg.SetFrameLevel and iconFrame.GetFrameLevel then
                        iconBg:SetFrameLevel(math.max(0, iconFrame:GetFrameLevel() - 1))
                    end
                    if iconBg.SetBackdrop then
                        iconBg:SetBackdrop({
                            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                            edgeFile = "Interface\\Buttons\\WHITE8x8",
                            edgeSize = self.db.borderSize or 1,
                        })
                    end
                    itemBackdrops[iconFrame] = iconBg
                end
                if iconBg.SetBackdropColor then iconBg:SetBackdropColor(0, 0, 0, 0) end
                if iconBg.SetBackdropBorderColor then
                    iconBg:SetBackdropBorderColor(c.r or 0.2, c.g or 0.2, c.b or 0.2, c.a or 1.0)
                end
                if iconBg.Show then iconBg:Show() end
                iconFrame.roithiBackdrop = iconBg
            end
        end

        if bar then
            if bar.SetHeight then bar:SetHeight(barHeight) end
            local iconSpacing = (vConf and vConf.iconSpacing) or 2
            if bar.ClearAllPoints and bar.SetPoint then
                bar:ClearAllPoints()
                if showIcon and iconFrame then
                    bar:SetPoint("LEFT", iconFrame, "RIGHT", iconSpacing, 0)
                    bar:SetPoint("RIGHT", itemFrame, "RIGHT", 0, 0)
                else
                    bar:SetPoint("LEFT", itemFrame, "LEFT", 0, 0)
                    bar:SetPoint("RIGHT", itemFrame, "RIGHT", 0, 0)
                end
            end

            -- Square corners vs rounded native atlas
            local square = (vConf and vConf.squareCorners ~= false)
            if square then
                local flatTex = "Interface\\Buttons\\WHITE8x8"
                if bar.SetStatusBarTexture then
                    bar:SetStatusBarTexture(flatTex)
                end
                if bar.BarBG then
                    -- Reset BarBG anchors to exactly match bar height (removes Blizzard's +9px overhang)
                    if bar.BarBG.ClearAllPoints and bar.BarBG.SetAllPoints then
                        bar.BarBG:ClearAllPoints()
                        bar.BarBG:SetAllPoints(bar)
                    end
                    if bar.BarBG.SetTexture then bar.BarBG:SetTexture(flatTex) end
                    local bgC = (vConf and vConf.barBgColor) or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
                    if bar.BarBG.SetVertexColor then
                        bar.BarBG:SetVertexColor(bgC.r, bgC.g, bgC.b, bgC.a or 0.8)
                    end
                end
                if bar.Pip and bar.Pip.SetAlpha then
                    bar.Pip:SetAlpha(0)
                end
            else
                if bar.SetStatusBarTexture then
                    bar:SetStatusBarTexture("UI-HUD-CoolDownManager-Bar")
                end
                if bar.BarBG and bar.BarBG.SetAtlas then
                    bar.BarBG:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
                end
                if bar.Pip and bar.Pip.SetAlpha then
                    bar.Pip:SetAlpha(1)
                end
            end

            -- Dedicated 1px border for statusbar
            local barBorder = itemBackdrops[bar] or bar.roithiBackdrop
            if not barBorder then
                barBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
                if barBorder.SetAllPoints then barBorder:SetAllPoints(bar) end
                if barBorder.SetFrameLevel and bar.GetFrameLevel then
                    barBorder:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
                end
                if barBorder.SetBackdrop then
                    barBorder:SetBackdrop({
                        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = self.db.borderSize or 1,
                    })
                end
                itemBackdrops[bar] = barBorder
            end
            bar.roithiBackdrop = barBorder
            if barBorder.SetBackdropColor then barBorder:SetBackdropColor(0, 0, 0, 0) end
            if barBorder.SetBackdropBorderColor then
                barBorder:SetBackdropBorderColor(c.r or 0.2, c.g or 0.2, c.b or 0.2, c.a or 1.0)
            end
            if barBorder.Show then barBorder:Show() end

            -- Foreground Bar Color
            if vConf and vConf.barColor then
                local bc = vConf.barColor
                local barTex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
                if barTex and barTex.SetVertexColor then
                    barTex:SetVertexColor(bc.r, bc.g, bc.b, bc.a or 1)
                end
            end

            -- Ability Name fontstring with font, size, and custom positioning
            local nameFS = bar.Name or (itemFrame.GetNameFontString and itemFrame:GetNameFontString())
            if nameFS then
                if vConf and vConf.showName == false then
                    if nameFS.Hide then nameFS:Hide() end
                else
                    if nameFS.Show then nameFS:Show() end
                    local fontName = (isOverridden and vConf.font) or self.db.font
                    local fontPath = GetActiveFont(fontName)
                    local nSize = (isOverridden and vConf.nameFontSize) or 11
                    local nOutline = (isOverridden and vConf.nameFontOutline) or "OUTLINE"
                    if nameFS.SetFont then
                        nameFS:SetFont(fontPath, nSize, nOutline)
                    end
                    if nameFS.SetDrawLayer then
                        nameFS:SetDrawLayer("OVERLAY", 7)
                    end
                    if nameFS.SetShadowOffset then
                        if nOutline ~= "NONE" and nOutline ~= "" then
                            nameFS:SetShadowOffset(0, 0)
                        else
                            nameFS:SetShadowOffset(1, -1)
                        end
                    end
                    if nameFS.ClearAllPoints and nameFS.SetPoint then
                        nameFS:ClearAllPoints()
                        local nX = (vConf and vConf.nameOffsetX) or 5
                        local nY = (vConf and vConf.nameOffsetY) or 0
                        local nPos = (vConf and vConf.namePosition) or "LEFT"
                        nameFS:SetPoint(nPos, bar, nPos, nX, nY)
                        if nameFS.SetJustifyH then nameFS:SetJustifyH(nPos) end
                    end
                end
            end

            -- Duration Timer fontstring with font, size, and custom positioning
            local durFS = bar.Duration or (itemFrame.GetDurationFontString and itemFrame:GetDurationFontString())
            if durFS then
                if vConf and vConf.showTimer == false then
                    if durFS.Hide then durFS:Hide() end
                else
                    if durFS.Show then durFS:Show() end
                    local fontName = (isOverridden and vConf.font) or self.db.font
                    local fontPath = GetActiveFont(fontName)
                    local tSize = (isOverridden and vConf.timerFontSize) or self.db.cooldownFontSize or 11
                    local tOutline = (isOverridden and vConf.timerFontOutline) or self.db.cooldownFontOutline or "OUTLINE"
                    if durFS.SetFont then
                        durFS:SetFont(fontPath, tSize, tOutline)
                    end
                    if durFS.SetDrawLayer then
                        durFS:SetDrawLayer("OVERLAY", 7)
                    end
                    if durFS.SetShadowOffset then
                        if tOutline ~= "NONE" and tOutline ~= "" then
                            durFS:SetShadowOffset(0, 0)
                        else
                            durFS:SetShadowOffset(1, -1)
                        end
                    end
                    if durFS.ClearAllPoints and durFS.SetPoint then
                        durFS:ClearAllPoints()
                        local tX = (vConf and vConf.timerOffsetX) or -8
                        local tY = (vConf and vConf.timerOffsetY) or 0
                        local tPos = (vConf and vConf.timerPosition) or "RIGHT"
                        durFS:SetPoint(tPos, bar, tPos, tX, tY)
                        if durFS.SetJustifyH then durFS:SetJustifyH(tPos) end
                    end
                end
            end
        end

        local iconSpacing = (vConf and vConf.iconSpacing) or 2
        local totalW = (showIcon and (iconW + iconSpacing) or 0) + barWidth
        local totalH = math.max(barHeight, (showIcon and iconH or barHeight))
        if itemFrame.SetSize then
            itemFrame:SetSize(totalW, totalH)
        end
    else
        -- Viewer-specific sizing (essential/utility/buff icon)
        if vConf and vConf.iconSize and itemFrame.SetSize then
            local sz = vConf.iconSize
            if sz > 0 then
                itemFrame:SetSize(sz, sz)
            end
        end
    end
end

function CDM:RestoreItemFrame(itemFrame)
    if not itemFrame then return end

    local bg = itemBackdrops[itemFrame] or itemFrame.roithiBackdrop
    if bg and bg.Hide then
        bg:Hide()
    end

    local icon = itemFrame.Icon
    if icon and icon.Icon then icon = icon.Icon end
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0, 1, 0, 1)
    end

    local function RestoreRegions(frameObj)
        if not frameObj or not frameObj.GetRegions then return end
        local regions = { frameObj:GetRegions() }
        if #regions == 1 and type(regions[1]) == "table" and not regions[1].IsObjectType then
            regions = regions[1]
        end
        for _, region in ipairs(regions) do
            local objType = region.GetObjectType and region:GetObjectType()
            local isMask = (objType == "MaskTexture") or (region.IsObjectType and region:IsObjectType("MaskTexture"))
            local atlas = region.GetAtlas and region:GetAtlas()

            if isMask or atlas == "UI-HUD-CoolDownManager-Mask" then
                if icon and icon.AddMaskTexture then
                    pcall(icon.AddMaskTexture, icon, region)
                end
                if region.Show then region:Show() end
                if region.SetAlpha then region:SetAlpha(1) end
            elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                if region.Show then region:Show() end
                if region.SetAlpha then region:SetAlpha(1) end
            end
        end
    end

    RestoreRegions(itemFrame)
    if itemFrame.Icon and itemFrame.Icon ~= icon then
        RestoreRegions(itemFrame.Icon)
    end
end
