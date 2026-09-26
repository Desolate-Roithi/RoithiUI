local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local CDM = RoithiUI:GetModule("CooldownManager")
local LSM = LibStub("LibSharedMedia-3.0", true)

local function GetActiveFont(fontName)
    if LSM and fontName then
        local fetched = LSM:Fetch("font", fontName)
        if fetched then return fetched end
    end
    return "Fonts\\FRIZQT__.TTF"
end

function CDM:StyleItemFrame(viewerKey, itemFrame)
    if not itemFrame then return end

    -- Hide Blizzard's ornate rounded overlay
    if itemFrame.GetRegions then
        local regions = { itemFrame:GetRegions() }
        if #regions == 1 and type(regions[1]) == "table" and not regions[1].IsObjectType then
            regions = regions[1]
        end
        for _, region in ipairs(regions) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                local atlas = region.GetAtlas and region:GetAtlas()
                if atlas and atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                    region:SetAlpha(0)
                end
            elseif region.IsObjectType and region:IsObjectType("MaskTexture") and self.db.cropIcons then
                region:SetAlpha(0)
            end
        end
    end

    -- Locate the primary icon texture
    local icon = itemFrame.Icon
    if icon and icon.Icon then
        icon = icon.Icon
    end

    if icon and icon.SetTexCoord then
        if self.db.cropIcons then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
    end

    -- 1px Roithi Backdrop
    local bg = itemFrame.roithiBackdrop
    if not bg then
        bg = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
        if bg.SetAllPoints then bg:SetAllPoints(itemFrame) end
        if bg.SetFrameLevel and itemFrame.GetFrameLevel then
            bg:SetFrameLevel(math.max(0, itemFrame:GetFrameLevel() - 1))
        end
        if bg.SetBackdrop then
            bg:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = self.db.borderSize or 1,
            })
        end
        itemFrame.roithiBackdrop = bg
    end

    local c = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
    if bg.SetBackdropColor then bg:SetBackdropColor(0, 0, 0, 0) end
    if bg.SetBackdropBorderColor then
        bg:SetBackdropBorderColor(c.r or 0.2, c.g or 0.2, c.b or 0.2, c.a or 1.0)
    end
    if bg.Show then bg:Show() end

    -- Cooldown frame countdown font
    local cd = itemFrame.Cooldown or (itemFrame.GetCooldownFrame and itemFrame:GetCooldownFrame())
    if cd and cd.SetCountdownFont then
        local fontPath = GetActiveFont(self.db.font)
        pcall(cd.SetCountdownFont, cd, fontPath)
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
        local fontPath = GetActiveFont(self.db.font)
        local fontSize = self.db.stackFontSize or 11
        local fontOutline = self.db.stackFontOutline or "OUTLINE"
        if stackFS.SetFont then
            stackFS:SetFont(fontPath, fontSize, fontOutline)
        end
        if stackFS.SetSize then
            stackFS:SetSize(0, 0)
        end
        if stackFS.ClearAllPoints and stackFS.SetPoint then
            local anchor = self.db.stackAnchor or "BOTTOMRIGHT"
            local ox = self.db.stackOffsetX or -2
            local oy = self.db.stackOffsetY or 2
            if stackFS.SetJustifyH then
                if anchor:find("LEFT") then
                    stackFS:SetJustifyH("LEFT")
                elseif anchor:find("RIGHT") then
                    stackFS:SetJustifyH("RIGHT")
                else
                    stackFS:SetJustifyH("CENTER")
                end
            end
            stackFS:ClearAllPoints()
            stackFS:SetPoint(anchor, itemFrame, anchor, ox, oy)
        end
    end

    -- Viewer-specific sizing (essential/utility/buff icon)
    local vConf = self.db.viewers and self.db.viewers[viewerKey]
    if vConf and vConf.iconSize and itemFrame.SetSize then
        local sz = vConf.iconSize
        if sz > 0 and (viewerKey ~= "BuffBar") then
            itemFrame:SetSize(sz, sz)
        end
    end
end

function CDM:RestoreItemFrame(itemFrame)
    if not itemFrame then return end

    if itemFrame.roithiBackdrop and itemFrame.roithiBackdrop.Hide then
        itemFrame.roithiBackdrop:Hide()
    end

    local icon = itemFrame.Icon
    if icon and icon.Icon then icon = icon.Icon end
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0, 1, 0, 1)
    end

    if itemFrame.GetRegions then
        local regions = { itemFrame:GetRegions() }
        if #regions == 1 and type(regions[1]) == "table" and not regions[1].IsObjectType then
            regions = regions[1]
        end
        for _, region in ipairs(regions) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                local atlas = region.GetAtlas and region:GetAtlas()
                if atlas and atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                    region:SetAlpha(1)
                end
            elseif region.IsObjectType and region:IsObjectType("MaskTexture") then
                region:SetAlpha(1)
            end
        end
    end
end
