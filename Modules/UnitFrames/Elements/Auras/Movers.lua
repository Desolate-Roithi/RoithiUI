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
local SAMPLE_TIMERS = { "12m", "8", "10", "15", "45",
                         "18m", "5", "12", "24", "6" }
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

                if LEM and LEM.RefreshFrameSettings then
                    LEM:RefreshFrameSettings()
                end
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

    local isCustom = containerSuffix:find("^Custom_")
    local customID = isCustom and containerSuffix:sub(8)
    local customDB = isCustom and RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CustomAuraFrames and RoithiUI.db.profile.CustomAuraFrames[customID]

    local isEnabled = isCustom and (customDB and customDB.enabled ~= false)
                   or (db and db.aurasEnabled ~= false
                       and (containerSuffix ~= "Buffs" or db.showBuffs ~= false)
                       and (containerSuffix ~= "Debuffs" or db.showDebuffs ~= false))

    if not isEditMode or not isEnabled then
        mover:Hide()
        return
    end

    mover:SetFrameStrata("DIALOG")
    mover:SetFrameLevel(200)

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
        isCustom = containerSuffix:find("^Custom_")
        local savedPt = isCustom and (db.screenPoint or db.auraScreenPoint)
                     or (containerSuffix == "Buffs"   and db.buffScreenPoint)
                     or (containerSuffix == "Debuffs" and db.debuffScreenPoint)
                     or db.auraScreenPoint or "TOPLEFT"
        local px = isCustom and (db.screenX or db.auraScreenX)
                or (containerSuffix == "Buffs"   and db.buffScreenX)
                or (containerSuffix == "Debuffs" and db.debuffScreenX)
                or db.auraScreenX or 0
        local py = isCustom and (db.screenY or db.auraScreenY)
                or (containerSuffix == "Buffs"   and db.buffScreenY)
                or (containerSuffix == "Debuffs" and db.debuffScreenY)
                or db.auraScreenY or 0

        mover:SetPoint(savedPt, UIParent, savedPt, px, py)
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
        sg.samples[i] = btn
        btn:SetSize(size, size)
        btn:EnableMouse(false)
        btn:Show()

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

        local GetTargetAnchorFromGrowDir = ns.Auras and ns.Auras.GetTargetAnchorFromGrowDir
        local targetAnchor = GetTargetAnchorFromGrowDir and GetTargetAnchorFromGrowDir(growDir, isCenterHoriz, isCenterVert) or "TOPLEFT"

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

    local LEM = LibStub("LibEditMode-Roithi", true)
    if LEM and LEM.frameSelections then
        local selection = LEM.frameSelections[mover]
        if selection and not selection:IsShown() then
            selection:Show()
        end
    end
end

-------------------------------------------------------------------------------
-- Sub-Module Function Exports
-------------------------------------------------------------------------------
ns.Auras = ns.Auras or {}
ns.Auras.GetOrCreateAuraMover = GetOrCreateAuraMover
ns.Auras.UpdateAuraMover = UpdateAuraMover

local function RefreshAuraSettings(unit)
    local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if ufMod then
        if unit and unit:find("^boss%d+$") then
            for i = 1, 5 do
                local bUnit = "boss" .. i
                if ufMod.units and ufMod.units[bUnit] then
                    ufMod:UpdateAuras(ufMod.units[bUnit])
                end
            end
        elseif unit and ufMod.units and ufMod.units[unit] then
            ufMod:UpdateAuras(ufMod.units[unit])
        elseif ufMod.UpdateAllAuras then
            ufMod:UpdateAllAuras()
        end
    end
end

function ns.GetSettingsForAuras(unit, containerSuffix)
    local LEM = LibStub("LibEditMode-Roithi", true)
    if not LEM then return {} end

    local isBuffs = (containerSuffix == "Buffs")
    local isDebuffs = (containerSuffix == "Debuffs")

    return {
        {
            kind = LEM.SettingType.Checkbox,
            name = "Enable Auras",
            get = function()
                local db = GetUnitDB(unit)
                return db and db.aurasEnabled ~= false
            end,
            set = function(_, v)
                local db = GetUnitDB(unit)
                if db then db.aurasEnabled = v end
                RefreshAuraSettings(unit)
            end,
        },
        {
            kind = LEM.SettingType.Checkbox,
            name = "Detach Auras",
            get = function()
                local db = GetUnitDB(unit)
                if isBuffs then return db and db.buffDetached == true end
                if isDebuffs then return db and db.debuffDetached == true end
                return db and db.auraDetached == true
            end,
            set = function(_, v)
                local db = GetUnitDB(unit)
                if db then
                    if isBuffs then
                        db.buffDetached = v
                        if v and (db.buffScreenX == nil or db.buffScreenY == nil) then
                            local key = ns.Auras and ns.Auras.MakeContainerKey and (ns.Auras.MakeContainerKey(unit, "Buffs") .. "_Mover")
                            local mover = key and UF and UF.AuraMovers and UF.AuraMovers[key]
                            if mover and mover:GetLeft() and UIParent:GetHeight() then
                                db.buffScreenPoint = "TOPLEFT"
                                db.buffScreenX = math.floor(mover:GetLeft() + 0.5)
                                db.buffScreenY = math.floor(mover:GetTop() - UIParent:GetHeight() + 0.5)
                            else
                                db.buffScreenPoint = "CENTER"
                                db.buffScreenX = 0
                                db.buffScreenY = 0
                            end
                        end
                    elseif isDebuffs then
                        db.debuffDetached = v
                        if v and (db.debuffScreenX == nil or db.debuffScreenY == nil) then
                            local key = ns.Auras and ns.Auras.MakeContainerKey and (ns.Auras.MakeContainerKey(unit, "Debuffs") .. "_Mover")
                            local mover = key and UF and UF.AuraMovers and UF.AuraMovers[key]
                            if mover and mover:GetLeft() and UIParent:GetHeight() then
                                db.debuffScreenPoint = "TOPLEFT"
                                db.debuffScreenX = math.floor(mover:GetLeft() + 0.5)
                                db.debuffScreenY = math.floor(mover:GetTop() - UIParent:GetHeight() + 0.5)
                            else
                                db.debuffScreenPoint = "CENTER"
                                db.debuffScreenX = 0
                                db.debuffScreenY = 0
                            end
                        end
                    else
                        db.auraDetached = v
                        if v and (db.auraScreenX == nil or db.auraScreenY == nil) then
                            local key = ns.Auras and ns.Auras.MakeContainerKey and (ns.Auras.MakeContainerKey(unit, "Combined") .. "_Mover")
                            local mover = key and UF and UF.AuraMovers and UF.AuraMovers[key]
                            if mover and mover:GetLeft() and UIParent:GetHeight() then
                                db.auraScreenPoint = "TOPLEFT"
                                db.auraScreenX = math.floor(mover:GetLeft() + 0.5)
                                db.auraScreenY = math.floor(mover:GetTop() - UIParent:GetHeight() + 0.5)
                            else
                                db.auraScreenPoint = "CENTER"
                                db.auraScreenX = 0
                                db.auraScreenY = 0
                            end
                        end
                    end
                end
                RefreshAuraSettings(unit)
                if LEM and LEM.RefreshFrameSettings then
                    LEM:RefreshFrameSettings()
                end
            end,
        },
        {
            kind = LEM.SettingType.Slider,
            name = "Aura Size",
            get = function()
                local db = GetUnitDB(unit)
                if isBuffs then return (db and db.buffSize) or 20 end
                if isDebuffs then return (db and db.debuffSize) or 20 end
                return (db and db.auraSize) or 20
            end,
            set = function(_, v)
                local db = GetUnitDB(unit)
                if db then
                    if isBuffs then db.buffSize = v
                    elseif isDebuffs then db.debuffSize = v
                    else db.auraSize = v end
                end
                RefreshAuraSettings(unit)
            end,
            minValue = 10,
            maxValue = 60,
            valueStep = 1,
        },
        {
            kind = LEM.SettingType.Slider,
            name = "Icons Per Row",
            get = function()
                local db = GetUnitDB(unit)
                if isBuffs then return (db and db.buffsPerRow) or 8 end
                if isDebuffs then return (db and db.debuffsPerRow) or 8 end
                return (db and db.aurasPerRow) or 8
            end,
            set = function(_, v)
                local db = GetUnitDB(unit)
                if db then
                    if isBuffs then db.buffsPerRow = v
                    elseif isDebuffs then db.debuffsPerRow = v
                    else db.aurasPerRow = v end
                end
                RefreshAuraSettings(unit)
            end,
            minValue = 1,
            maxValue = 20,
            valueStep = 1,
        },
        {
            kind = LEM.SettingType.Slider,
            name = "Max Auras",
            get = function()
                local db = GetUnitDB(unit)
                if isBuffs then return (db and db.maxBuffs) or 16 end
                if isDebuffs then return (db and db.maxDebuffs) or 16 end
                return (db and db.maxAuras) or 16
            end,
            set = function(_, v)
                local db = GetUnitDB(unit)
                if db then
                    if isBuffs then db.maxBuffs = v
                    elseif isDebuffs then db.maxDebuffs = v
                    else db.maxAuras = v end
                end
                RefreshAuraSettings(unit)
            end,
            minValue = 1,
            maxValue = 40,
            valueStep = 1,
        },
        {
            kind = LEM.SettingType.Dropdown,
            name = "Anchor Point",
            values = {
                { text = "Top Left",     value = "TOPLEFT" },
                { text = "Left",         value = "LEFT" },
                { text = "Bottom Left",  value = "BOTTOMLEFT" },
                { text = "Top",          value = "TOP" },
                { text = "Center",       value = "CENTER" },
                { text = "Bottom",       value = "BOTTOM" },
                { text = "Top Right",    value = "TOPRIGHT" },
                { text = "Right",        value = "RIGHT" },
                { text = "Bottom Right", value = "BOTTOMRIGHT" },
            },
            get = function()
                local db = GetUnitDB(unit)
                if not db then return "BOTTOM" end
                if isBuffs then return db.buffAnchor or db.auraAnchor or "BOTTOM" end
                if isDebuffs then return db.debuffAnchor or db.auraAnchor or "BOTTOM" end
                return db.auraAnchor or "BOTTOM"
            end,
            set = function(_, v)
                local db = GetUnitDB(unit)
                if db then
                    if isBuffs then db.buffAnchor = v
                    elseif isDebuffs then db.debuffAnchor = v
                    else db.auraAnchor = v end
                end
                RefreshAuraSettings(unit)
            end,
        },
        {
            kind = LEM.SettingType.Dropdown,
            name = "Grow Direction",
            values = {
                { text = "Right then Down",      value = "RIGHT_DOWN" },
                { text = "Right then Up",        value = "RIGHT_UP" },
                { text = "Left then Down",       value = "LEFT_DOWN" },
                { text = "Left then Up",         value = "LEFT_UP" },
                { text = "Down then Right",      value = "DOWN_RIGHT" },
                { text = "Down then Left",       value = "DOWN_LEFT" },
                { text = "Up then Right",        value = "UP_RIGHT" },
                { text = "Up then Left",         value = "UP_LEFT" },
                { text = "Centered Horizontal",  value = "CENTER_HORIZONTAL" },
                { text = "Centered Vertical",    value = "CENTER_VERTICAL" },
            },
            get = function()
                local db = GetUnitDB(unit)
                if not db then return "RIGHT_DOWN" end
                local dir
                if isBuffs then dir = db.buffGrowDirection or db.auraGrowDirection
                elseif isDebuffs then dir = db.debuffGrowDirection or db.auraGrowDirection
                else dir = db.auraGrowDirection end
                if dir == "RIGHT" then return "RIGHT_DOWN" end
                if dir == "LEFT" then return "LEFT_DOWN" end
                return dir or "RIGHT_DOWN"
            end,
            set = function(_, v)
                local db = GetUnitDB(unit)
                if db then
                    if isBuffs then db.buffGrowDirection = v
                    elseif isDebuffs then db.debuffGrowDirection = v
                    else db.auraGrowDirection = v end
                end
                RefreshAuraSettings(unit)
            end,
        },
        {
            kind = LEM.SettingType.Slider,
            name = "X Position",
            get = function()
                local db = GetUnitDB(unit)
                if not db then return 0 end
                local isDetached = isBuffs and (db.buffDetached == true)
                                or isDebuffs and (db.debuffDetached == true)
                                or (db.auraDetached == true)
                if isDetached then
                    local val = isBuffs and db.buffScreenX
                             or isDebuffs and db.debuffScreenX
                             or db.auraScreenX
                    return tonumber(val) or 0
                else
                    local val = isBuffs and db.buffX
                             or isDebuffs and db.debuffX
                             or db.auraX
                    return tonumber(val) or 0
                end
            end,
            set = function(_, v)
                local db = GetUnitDB(unit)
                if db then
                    local isDetached = isBuffs and (db.buffDetached == true)
                                    or isDebuffs and (db.debuffDetached == true)
                                    or (db.auraDetached == true)
                    if isDetached then
                        if isBuffs then db.buffScreenX = v
                        elseif isDebuffs then db.debuffScreenX = v
                        else db.auraScreenX = v end
                    else
                        if isBuffs then db.buffX = v
                        elseif isDebuffs then db.debuffX = v
                        else db.auraX = v end
                    end
                end
                RefreshAuraSettings(unit)
            end,
            minValue = -2000,
            maxValue = 2000,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
        },
        {
            kind = LEM.SettingType.Slider,
            name = "Y Position",
            get = function()
                local db = GetUnitDB(unit)
                if not db then return 0 end
                local isDetached = isBuffs and (db.buffDetached == true)
                                or isDebuffs and (db.debuffDetached == true)
                                or (db.auraDetached == true)
                if isDetached then
                    local val = isBuffs and db.buffScreenY
                             or isDebuffs and db.debuffScreenY
                             or db.auraScreenY
                    return tonumber(val) or 0
                else
                    local val = isBuffs and db.buffY
                             or isDebuffs and db.debuffY
                             or db.auraY
                    return tonumber(val) or 4
                end
            end,
            set = function(_, v)
                local db = GetUnitDB(unit)
                if db then
                    local isDetached = isBuffs and (db.buffDetached == true)
                                    or isDebuffs and (db.debuffDetached == true)
                                    or (db.auraDetached == true)
                    if isDetached then
                        if isBuffs then db.buffScreenY = v
                        elseif isDebuffs then db.debuffScreenY = v
                        else db.auraScreenY = v end
                    else
                        if isBuffs then db.buffY = v
                        elseif isDebuffs then db.debuffY = v
                        else db.auraY = v end
                    end
                end
                RefreshAuraSettings(unit)
            end,
            minValue = -2000,
            maxValue = 2000,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
        },
    }
end

function ns.GetSettingsForCustomAura(customID)
    local LEM = LibStub("LibEditMode-Roithi", true)
    if not LEM then return {} end

    local function GetCDB()
        if RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CustomAuraFrames then
            return RoithiUI.db.profile.CustomAuraFrames[customID]
        end
    end

    return {
        {
            kind = LEM.SettingType.Slider,
            name = "Aura Size",
            get = function()
                local db = GetCDB()
                return (db and db.auraSize) or 30
            end,
            set = function(_, v)
                local db = GetCDB()
                if db then db.auraSize = v end
                local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                if ufMod and ufMod.UpdateCustomAura then ufMod:UpdateCustomAura(customID) end
            end,
            minValue = 10,
            maxValue = 100,
            valueStep = 1,
        },
        {
            kind = LEM.SettingType.Slider,
            name = "Icons Per Row",
            get = function()
                local db = GetCDB()
                return (db and db.aurasPerRow) or 8
            end,
            set = function(_, v)
                local db = GetCDB()
                if db then db.aurasPerRow = v end
                local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                if ufMod and ufMod.UpdateCustomAura then ufMod:UpdateCustomAura(customID) end
            end,
            minValue = 1,
            maxValue = 20,
            valueStep = 1,
        },
        {
            kind = LEM.SettingType.Slider,
            name = "Max Auras",
            get = function()
                local db = GetCDB()
                return (db and db.maxAuras) or 16
            end,
            set = function(_, v)
                local db = GetCDB()
                if db then db.maxAuras = v end
                local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                if ufMod and ufMod.UpdateCustomAura then ufMod:UpdateCustomAura(customID) end
            end,
            minValue = 1,
            maxValue = 40,
            valueStep = 1,
        },
        {
            kind = LEM.SettingType.Dropdown,
            name = "Grow Direction",
            values = {
                { text = "Right then Down",      value = "RIGHT_DOWN" },
                { text = "Right then Up",        value = "RIGHT_UP" },
                { text = "Left then Down",       value = "LEFT_DOWN" },
                { text = "Left then Up",         value = "LEFT_UP" },
                { text = "Down then Right",      value = "DOWN_RIGHT" },
                { text = "Down then Left",       value = "DOWN_LEFT" },
                { text = "Up then Right",        value = "UP_RIGHT" },
                { text = "Up then Left",         value = "UP_LEFT" },
                { text = "Centered Horizontal",  value = "CENTER_HORIZONTAL" },
                { text = "Centered Vertical",    value = "CENTER_VERTICAL" },
            },
            get = function()
                local db = GetCDB()
                return (db and db.auraGrowDirection) or "RIGHT_DOWN"
            end,
            set = function(_, v)
                local db = GetCDB()
                if db then db.auraGrowDirection = v end
                local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                if ufMod and ufMod.UpdateCustomAura then ufMod:UpdateCustomAura(customID) end
            end,
        },
        {
            kind = LEM.SettingType.Checkbox,
            name = "Hide Icon",
            get = function()
                local db = GetCDB()
                return db and db.hideIcon == true
            end,
            set = function(_, v)
                local db = GetCDB()
                if db then db.hideIcon = v end
                local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                if ufMod and ufMod.UpdateCustomAura then ufMod:UpdateCustomAura(customID) end
            end,
        },
        {
            kind = LEM.SettingType.Checkbox,
            name = "Hide Timer",
            get = function()
                local db = GetCDB()
                return db and db.hideTimer == true
            end,
            set = function(_, v)
                local db = GetCDB()
                if db then db.hideTimer = v end
                local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                if ufMod and ufMod.UpdateCustomAura then ufMod:UpdateCustomAura(customID) end
            end,
        },
        {
            kind = LEM.SettingType.Checkbox,
            name = "Hide Stack Count",
            get = function()
                local db = GetCDB()
                return db and db.hideCount == true
            end,
            set = function(_, v)
                local db = GetCDB()
                if db then db.hideCount = v end
                local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                if ufMod and ufMod.UpdateCustomAura then ufMod:UpdateCustomAura(customID) end
            end,
        },
        {
            kind = LEM.SettingType.Slider,
            name = "X Position",
            get = function()
                local db = GetCDB()
                return (db and (db.screenX or db.auraScreenX or db.x)) or 0
            end,
            set = function(_, v)
                local db = GetCDB()
                if db then
                    db.screenX = v
                    db.auraScreenX = v
                    db.x = v
                end
                local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                if ufMod and ufMod.UpdateCustomAura then ufMod:UpdateCustomAura(customID) end
            end,
            minValue = -2000,
            maxValue = 2000,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
        },
        {
            kind = LEM.SettingType.Slider,
            name = "Y Position",
            get = function()
                local db = GetCDB()
                return (db and (db.screenY or db.auraScreenY or db.y)) or 0
            end,
            set = function(_, v)
                local db = GetCDB()
                if db then
                    db.screenY = v
                    db.auraScreenY = v
                    db.y = v
                end
                local ufMod = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                if ufMod and ufMod.UpdateCustomAura then ufMod:UpdateCustomAura(customID) end
            end,
            minValue = -2000,
            maxValue = 2000,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
        },
    }
end

