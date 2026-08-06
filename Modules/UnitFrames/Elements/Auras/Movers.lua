local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")

---@class UF : AceModule, AceAddon
local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]

local RADLog = function(fmt, ...) if ns.Auras and ns.Auras.RADLog then ns.Auras.RADLog(fmt, ...) end end
local GetUnitDB = function(unit) return ns.Auras and ns.Auras.GetUnitDB and ns.Auras.GetUnitDB(unit) end
local FormatAuraButton = function(btn, key, isDebuff, size, db) if ns.Auras and ns.Auras.FormatAuraButton then ns.Auras.FormatAuraButton(btn, key, isDebuff, size, db) end end
local ConfigureAuraContainer = function(c, unit, suf) return ns.Auras and ns.Auras.ConfigureAuraContainer and ns.Auras.ConfigureAuraContainer(c, unit, suf) end

-------------------------------------------------------------------------------
-- AuraMover System
-- A dedicated UIParent-level mover frame per container, registered with
-- LibEditMode-Roithi. It mirrors the visual position & size of the real
-- AuraContainer and hosts the sample dummy icons. The real AuraContainer is
-- never registered with LEM and never drag-able itself.
-------------------------------------------------------------------------------
local SAMPLE_ICONS  = { 136075, 136042, 136025, 136056, 136012,
                         135940, 135813, 136193, 135987, 136071 }
local SAMPLE_TIMERS = { "12m", "8s", "10s", "15s", "45s",
                         "18m", "5s", "12s", "24s", "6s" }
local SAMPLE_COUNTS = { nil, "3", nil, "2", nil, "5", nil, nil, "2", nil }

local function GetOrCreateAuraMover(container, unit, containerSuffix)
    local moverKey = container.containerKey .. "_Mover"
    local mover = UF.AuraMovers[moverKey]

    if mover then return mover end

    RADLog("Creating AuraMover [%s]", moverKey)

    mover = CreateFrame("Frame", moverKey, UIParent)
    mover:SetFrameStrata("DIALOG")
    mover:SetFrameLevel(200)
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:EnableMouse(false)   -- default click-through; toggled per mode
    mover:Hide()

    mover.unit            = unit
    mover.containerSuffix = containerSuffix
    mover.containerRef    = container

    -- Title label
    local title = mover:CreateFontString(nil, "OVERLAY")
    title:SetPoint("BOTTOM", mover, "TOP", 0, 2)
    mover.Title = title

    -- Background tint
    local bg = mover:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(mover)
    bg:SetColorTexture(0, 0.5, 0.9, 0.25)
    mover.Bg = bg

    -- Sample icon pool
    local sampleGroup = CreateFrame("Frame", nil, mover)
    sampleGroup:SetAllPoints(mover)
    sampleGroup:SetFrameLevel(mover:GetFrameLevel() + 1)
    sampleGroup:EnableMouse(false)
    sampleGroup.samples = {}
    mover.SampleGroup = sampleGroup

    -- Register with LibEditMode-Roithi
    local LEM = LibStub("LibEditMode-Roithi", true)
    if LEM then
        local db = GetUnitDB(unit)
        local isCustom = containerSuffix:find("^Custom_")
        local customID = isCustom and containerSuffix:sub(8)
        local customDB = isCustom and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CustomAuraFrames and RoithiUI.db.profile.CustomAuraFrames[customID]

        local defaults = {
            point = isCustom and (customDB and (customDB.screenPoint or customDB.auraScreenPoint))
                 or (containerSuffix == "Buffs"    and db.buffScreenPoint)
                 or (containerSuffix == "Debuffs"  and db.debuffScreenPoint)
                 or db.auraScreenPoint or "CENTER",
            x = isCustom and (customDB and (customDB.screenX or customDB.auraScreenX))
             or (containerSuffix == "Buffs"   and db.buffScreenX)
             or (containerSuffix == "Debuffs" and db.debuffScreenX)
             or db.auraScreenX or 0,
            y = isCustom and (customDB and (customDB.screenY or customDB.auraScreenY))
             or (containerSuffix == "Buffs"   and db.buffScreenY)
             or (containerSuffix == "Debuffs" and db.debuffScreenY)
             or db.auraScreenY or 0,
        }

        if isCustom then
            mover.editModeName = "Roithi Custom " .. customID
        else
            mover.editModeName = "Roithi "
                .. unit:sub(1,1):upper() .. unit:sub(2)
                .. " " .. containerSuffix:sub(1,1):upper() .. containerSuffix:sub(2)
        end

        pcall(function()
            LEM:AddFrame(mover, function(movedFrame, _, point, x, y)
                local u   = movedFrame.unit
                local suf = movedFrame.containerSuffix
                local uDB = GetUnitDB(u)

                local isCustomFrame = suf:find("^Custom_")

                -- Guard: if not detached and not custom frame, snap mover back to attached position
                if not movedFrame.isDetachedMover and not isCustomFrame then
                    local cRef = movedFrame.containerRef
                    if cRef then
                        ConfigureAuraContainer(cRef, u, suf)
                    end
                    return
                end

                -- Determine layout anchor for detached movers based on grow direction
                local cIDFrame = isCustomFrame and suf:sub(8)
                local frameDB = isCustomFrame and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CustomAuraFrames and RoithiUI.db.profile.CustomAuraFrames[cIDFrame] or uDB
                local gDir = isCustomFrame and (frameDB and frameDB.auraGrowDirection)
                          or (suf == "Buffs" and uDB.buffGrowDirection)
                          or (suf == "Debuffs" and uDB.debuffGrowDirection)
                          or uDB.auraGrowDirection or "RIGHT_DOWN"

                local isCenterH = (gDir:find("CENTER_HORIZONTAL") or gDir == "CENTER_HORIZ")
                local isCenterV = (gDir:find("CENTER_VERTICAL") or gDir == "CENTER_VERT")

                local targetAnchor = "TOPLEFT"
                if gDir == "RIGHT_UP" or gDir == "UP" or gDir == "UP_RIGHT" or gDir == "BOTTOM_TO_TOP" then
                    targetAnchor = "BOTTOMLEFT"
                elseif gDir == "LEFT_DOWN" or gDir == "DOWN_LEFT" or gDir == "LEFT" then
                    targetAnchor = "TOPRIGHT"
                elseif gDir == "LEFT_UP" or gDir == "UP_LEFT" then
                    targetAnchor = "BOTTOMRIGHT"
                elseif gDir == "CENTER_HORIZONTAL_UP" then
                    targetAnchor = "BOTTOM"
                elseif gDir == "CENTER_HORIZONTAL_DOWN" or isCenterH then
                    targetAnchor = "TOP"
                elseif gDir == "CENTER_VERTICAL_LEFT" then
                    targetAnchor = "RIGHT"
                elseif gDir == "CENTER_VERTICAL_RIGHT" or isCenterV then
                    targetAnchor = "LEFT"
                end

                local ptStr = targetAnchor
                local cleanX = tonumber(tostring(x or 0)) or 0
                local cleanY = tonumber(tostring(y or 0)) or 0

                if movedFrame.GetLeft and UIParent.GetLeft then
                    local uW, uH = UIParent:GetWidth(), UIParent:GetHeight()
                    if uW and uH and uW > 0 and uH > 0 then
                        if targetAnchor == "TOPLEFT" then
                            cleanX = movedFrame:GetLeft()
                            cleanY = movedFrame:GetTop() - uH
                        elseif targetAnchor == "BOTTOMLEFT" then
                            cleanX = movedFrame:GetLeft()
                            cleanY = movedFrame:GetBottom()
                        elseif targetAnchor == "TOPRIGHT" then
                            cleanX = movedFrame:GetRight() - uW
                            cleanY = movedFrame:GetTop() - uH
                        elseif targetAnchor == "BOTTOMRIGHT" then
                            cleanX = movedFrame:GetRight() - uW
                            cleanY = movedFrame:GetBottom()
                        elseif targetAnchor == "TOP" then
                            cleanX = movedFrame:GetLeft() + movedFrame:GetWidth()/2 - uW/2
                            cleanY = movedFrame:GetTop() - uH
                        elseif targetAnchor == "BOTTOM" then
                            cleanX = movedFrame:GetLeft() + movedFrame:GetWidth()/2 - uW/2
                            cleanY = movedFrame:GetBottom()
                        elseif targetAnchor == "LEFT" then
                            cleanX = movedFrame:GetLeft()
                            cleanY = movedFrame:GetBottom() + movedFrame:GetHeight()/2 - uH/2
                        elseif targetAnchor == "RIGHT" then
                            cleanX = movedFrame:GetRight() - uW
                            cleanY = movedFrame:GetBottom() + movedFrame:GetHeight()/2 - uH/2
                        end
                    end
                end

                cleanX = math.floor(cleanX * 10 + 0.5) / 10
                cleanY = math.floor(cleanY * 10 + 0.5) / 10

                -- Save position to DB
                if isCustomFrame then
                    local cID = suf:sub(8)
                    local cDB = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CustomAuraFrames and RoithiUI.db.profile.CustomAuraFrames[cID]
                    if cDB then
                        cDB.screenPoint     = ptStr
                        cDB.screenX         = cleanX
                        cDB.screenY         = cleanY
                        cDB.auraScreenPoint = ptStr
                        cDB.auraScreenX     = cleanX
                        cDB.auraScreenY     = cleanY
                        cDB.x               = cleanX
                        cDB.y               = cleanY
                        cDB.anchor          = ptStr
                    end
                elseif suf == "Buffs" then
                    uDB.buffScreenPoint  = ptStr
                    uDB.buffScreenX      = cleanX
                    uDB.buffScreenY      = cleanY
                elseif suf == "Debuffs" then
                    uDB.debuffScreenPoint = ptStr
                    uDB.debuffScreenX     = cleanX
                    uDB.debuffScreenY     = cleanY
                else
                    uDB.auraScreenPoint = ptStr
                    uDB.auraScreenX     = cleanX
                    uDB.auraScreenY     = cleanY
                end

                -- Re-anchor real container to new position
                local cRef = movedFrame.containerRef
                if cRef then
                    if suf:find("^Custom_") then
                        local cID = suf:sub(8)
                        UF:UpdateCustomAura(cID)
                    else
                        ConfigureAuraContainer(cRef, u, suf)
                    end
                end
                local AL = ns.AttachmentLogic
                if AL and AL.ApplyLayout then AL:ApplyLayout(u, suf) end
            end, defaults, mover.editModeName)

            if isCustom and ns.GetSettingsForCustomAura then
                LEM:AddFrameSettings(mover, ns.GetSettingsForCustomAura(customID))
                LEM:AddFrameSettingsButtons(mover, {
                    {
                        text = "Open Full Settings",
                        click = function()
                            if LibStub("AceConfigDialog-3.0", true) then
                                LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "custom", customID)
                                LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                            end
                        end
                    }
                })
            elseif ns.GetSettingsForAuras then
                LEM:AddFrameSettings(mover, ns.GetSettingsForAuras(unit, containerSuffix))
                LEM:AddFrameSettingsButtons(mover, {
                    {
                        text = "Open Full Settings",
                        click = function()
                            if LibStub("AceConfigDialog-3.0", true) then
                                LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "units", unit)
                                LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                            end
                        end
                    }
                })
            end
        end)
    end

    UF.AuraMovers[moverKey] = mover
    container.AuraMover = mover
    return mover
end

-- UpdateAuraMover: called at the end of ConfigureAuraContainer to
-- synchronise the mover frame with the real container's computed layout.
local function UpdateAuraMover(
    container, unit, containerSuffix,
    calcWidth, calcHeight, size, spacing, perRow,
    layoutAnchor, growDir, isVerticalLayout,
    isCenterHoriz, isCenterVert, isCombined,
    isEditMode, isDetached, db
)
    local mover = GetOrCreateAuraMover(container, unit, containerSuffix)

    if not isEditMode then
        mover:Hide()
        return
    end

    ---------------------------------------------------------------------------
    -- 1. Size the mover to match the computed sample layout
    ---------------------------------------------------------------------------
    local maxCount = isCombined and (tonumber(db.maxAuras) or 16)
                 or (containerSuffix == "Debuffs" and (tonumber(db.debuffMaxAuras) or tonumber(db.maxAuras) or 16))
                 or (containerSuffix == "Buffs" and (tonumber(db.buffMaxAuras) or tonumber(db.maxAuras) or 16))
                 or (tonumber(db.maxAuras) or 16)

    local effectivePerRow = perRow
    if maxCount and maxCount > 0 and effectivePerRow > maxCount then
        effectivePerRow = maxCount
    end

    local editSampleCount = isCombined and math.min(maxCount, 10) or math.min(maxCount, 5)
    if editSampleCount < 1 then editSampleCount = 1 end

    -- Re-derive the layout dimensions from the sample count and effectivePerRow
    local sCols, sRows
    if isVerticalLayout then
        sCols = math.ceil(editSampleCount / effectivePerRow)
        sRows = math.min(editSampleCount, effectivePerRow)
    else
        sCols = math.min(editSampleCount, effectivePerRow)
        sRows = math.ceil(editSampleCount / effectivePerRow)
    end
    local moverW = math.max(sCols * size + (sCols - 1) * spacing, size)
    local moverH = math.max(sRows * size + (sRows - 1) * spacing, size)
    mover:SetSize(moverW, moverH)

    ---------------------------------------------------------------------------
    -- 2. Position the mover
    -- Detached: use saved DB screen coords (anchor to UIParent directly).
    -- Attached: mirror the real container's anchor using the plain-Lua
    --           roithiSaved* values stored during ConfigureAuraContainer.
    ---------------------------------------------------------------------------
    mover:ClearAllPoints()

    if isDetached then
        local isCustom = containerSuffix:find("^Custom_")
        local savedPt = isCustom and (db.screenPoint or db.auraScreenPoint)
                     or (containerSuffix == "Buffs"   and db.buffScreenPoint)
                     or (containerSuffix == "Debuffs" and db.debuffScreenPoint)
                     or db.auraScreenPoint
        local px = isCustom and (db.screenX or db.auraScreenX)
                or (containerSuffix == "Buffs"   and db.buffScreenX)
                or (containerSuffix == "Debuffs" and db.debuffScreenX)
                or db.auraScreenX or 0
        local py = isCustom and (db.screenY or db.auraScreenY)
                or (containerSuffix == "Buffs"   and db.buffScreenY)
                or (containerSuffix == "Debuffs" and db.debuffScreenY)
                or db.auraScreenY or 0

        local targetAnchor = "TOPLEFT"
        if growDir == "RIGHT_UP" or growDir == "UP" or growDir == "UP_RIGHT" or growDir == "BOTTOM_TO_TOP" then
            targetAnchor = "BOTTOMLEFT"
        elseif growDir == "LEFT_DOWN" or growDir == "DOWN_LEFT" or growDir == "LEFT" then
            targetAnchor = "TOPRIGHT"
        elseif growDir == "LEFT_UP" or growDir == "UP_LEFT" then
            targetAnchor = "BOTTOMRIGHT"
        elseif growDir == "CENTER_HORIZONTAL_UP" then
            targetAnchor = "BOTTOM"
        elseif growDir == "CENTER_HORIZONTAL_DOWN" or isCenterHoriz then
            targetAnchor = "TOP"
        elseif growDir == "CENTER_VERTICAL_LEFT" then
            targetAnchor = "RIGHT"
        elseif growDir == "CENTER_VERTICAL_RIGHT" or isCenterVert then
            targetAnchor = "LEFT"
        end

        local pt = savedPt or targetAnchor
        if not savedPt or savedPt ~= targetAnchor then
            local ConvertAnchorPosition = ns.Auras and ns.Auras.ConvertAnchorPosition
            if ConvertAnchorPosition then
                pt, px, py = ConvertAnchorPosition(savedPt, px, py, targetAnchor, moverW, moverH)
            else
                pt = targetAnchor
            end
            if isCustom then
                db.screenPoint = pt; db.screenX = px; db.screenY = py
                db.auraScreenPoint = pt; db.auraScreenX = px; db.auraScreenY = py
            elseif containerSuffix == "Buffs" then
                db.buffScreenPoint = pt; db.buffScreenX = px; db.buffScreenY = py
            elseif containerSuffix == "Debuffs" then
                db.debuffScreenPoint = pt; db.debuffScreenX = px; db.debuffScreenY = py
            else
                db.auraScreenPoint = pt; db.auraScreenX = px; db.auraScreenY = py
            end
        end

        mover:SetPoint(pt, UIParent, pt, px, py)
    else
        -- Attached: use the container's saved anchor (plain Lua values, never secret)
        local anchorPt  = container.roithiSavedPoint    or "BOTTOMLEFT"
        local anchorRel = container.roithiAnchorFrame    or UIParent
        local relPt     = container.roithiSavedRelPoint  or anchorPt
        local offX      = container.roithiSavedX         or 0
        local offY      = container.roithiSavedY         or 0
        mover:SetPoint(anchorPt, anchorRel, relPt, offX, offY)
    end

    ---------------------------------------------------------------------------
    -- 3. Drag state: set flag & keep mover mouse disabled for LEM selection overlay
    ---------------------------------------------------------------------------
    mover.isDetachedMover = isDetached
    mover:SetMovable(true)
    mover:EnableMouse(false)

    ---------------------------------------------------------------------------
    -- 4. Title label
    ---------------------------------------------------------------------------
    local fontName = (RoithiUI.db and RoithiUI.db.profile
        and RoithiUI.db.profile.General
        and RoithiUI.db.profile.General.unitFrameFont)
        or "Friz Quadrata TT"
    if LibRoithi and LibRoithi.mixins and LibRoithi.mixins.SetFont then
        LibRoithi.mixins:SetFont(mover.Title, fontName, 10, "OUTLINE")
    end
    mover.Title:SetText(unit:upper() .. " " .. containerSuffix:upper())

    ---------------------------------------------------------------------------
    -- 5. Sample dummy icons
    ---------------------------------------------------------------------------
    local sg = mover.SampleGroup
    sg:SetAllPoints(mover)

    for i = 1, editSampleCount do
        local btn = sg.samples[i] or CreateFrame("Frame", nil, sg)
        btn:SetSize(size, size)
        btn:EnableMouse(false)

        local isSampleDebuff = (containerSuffix == "Debuffs") or (isCombined and i > 5)
        FormatAuraButton(btn, container.containerKey, isSampleDebuff, size, db)

        local iconIdx = ((i - 1) % #SAMPLE_ICONS) + 1
        if btn.Icon then btn.Icon:SetTexture(SAMPLE_ICONS[iconIdx]) end
        if btn.TextFrame then btn.TextFrame:Show() end
        if btn.DurationText then
            btn.DurationText:SetText(SAMPLE_TIMERS[i])
            btn.DurationText:Show()
        end
        if btn.CountText then
            if SAMPLE_COUNTS[i] then
                btn.CountText:SetText(SAMPLE_COUNTS[i])
                btn.CountText:Show()
            else
                btn.CountText:Hide()
            end
        end

        -- Layout: position within sampleGroup following real grow direction
        -- Render all 10 sample icons (5 buffs + 5 debuffs) sequentially across the mover box
        local displayIdx = i - 1
        local ci, ri
        if isVerticalLayout then
            ci = math.floor(displayIdx / effectivePerRow)
            ri = displayIdx % effectivePerRow
        else
            ci = displayIdx % effectivePerRow
            ri = math.floor(displayIdx / effectivePerRow)
        end

        local iconCenterX, iconCenterY
        local isCenterHUp = (growDir == "CENTER_HORIZONTAL_UP")
        local isCenterVLeft = (growDir == "CENTER_VERTICAL_LEFT")

        if isCenterHoriz then
            local itemsInRow = math.min(editSampleCount - ri * effectivePerRow, effectivePerRow)
            if itemsInRow < 1 then itemsInRow = 1 end
            local lineSize = itemsInRow * size + (itemsInRow - 1) * spacing
            iconCenterX = -lineSize / 2 + size / 2 + ci * (size + spacing)
            local rowOffset = isCenterHUp and (ri * (size + spacing) + size / 2) or (-ri * (size + spacing) - size / 2)
            iconCenterY = rowOffset
        elseif isCenterVert then
            local itemsInCol = math.min(editSampleCount - ci * effectivePerRow, effectivePerRow)
            if itemsInCol < 1 then itemsInCol = 1 end
            local lineSize = itemsInCol * size + (itemsInCol - 1) * spacing
            local colOffset = isCenterVLeft and (-ci * (size + spacing) - size / 2) or (ci * (size + spacing) + size / 2)
            iconCenterX = colOffset
            iconCenterY = lineSize / 2 - size / 2 - ri * (size + spacing)
        else
            local isLeft = growDir:find("LEFT") and not growDir:find("RIGHT")
            iconCenterX = isLeft and (-ci * (size + spacing) - size / 2) or (ci * (size + spacing) + size / 2)
            local goesUp = growDir == "RIGHT_UP" or growDir == "LEFT_UP"
                        or growDir == "UP_RIGHT" or growDir == "UP_LEFT" or growDir == "UP"
                        or growDir == "BOTTOM_TO_TOP"
            iconCenterY = goesUp and (ri * (size + spacing) + size / 2) or (-ri * (size + spacing) - size / 2)
        end

        local targetAnchor = "TOPLEFT"
        if growDir == "RIGHT_UP" or growDir == "UP" or growDir == "UP_RIGHT" or growDir == "BOTTOM_TO_TOP" then
            targetAnchor = "BOTTOMLEFT"
        elseif growDir == "LEFT_DOWN" or growDir == "DOWN_LEFT" or growDir == "LEFT" then
            targetAnchor = "TOPRIGHT"
        elseif growDir == "LEFT_UP" or growDir == "UP_LEFT" then
            targetAnchor = "BOTTOMRIGHT"
        elseif growDir == "CENTER_HORIZONTAL_UP" then
            targetAnchor = "BOTTOM"
        elseif growDir == "CENTER_HORIZONTAL_DOWN" or isCenterHoriz then
            targetAnchor = "TOP"
        elseif growDir == "CENTER_VERTICAL_LEFT" then
            targetAnchor = "RIGHT"
        elseif growDir == "CENTER_VERTICAL_RIGHT" or isCenterVert then
            targetAnchor = "LEFT"
        end

        btn:ClearAllPoints()
        btn:SetPoint("CENTER", sg, targetAnchor, iconCenterX, iconCenterY)
        btn:Show()
        sg.samples[i] = btn
    end

    -- Hide leftover samples beyond current count
    for i = editSampleCount + 1, #sg.samples do
        if sg.samples[i] then sg.samples[i]:Hide() end
    end

    mover:Show()
end

-------------------------------------------------------------------------------
-- Sub-Module Function Exports
-------------------------------------------------------------------------------
ns.Auras = ns.Auras or {}
ns.Auras.GetOrCreateAuraMover = GetOrCreateAuraMover
ns.Auras.UpdateAuraMover = UpdateAuraMover
