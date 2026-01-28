local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")


local Direction = RoithiUI:NewModule("Direction", "AceEvent-3.0")

local VISIBILITY = {
    ALWAYS = 1,
    IN_COMBAT = 2,
    OUT_OF_COMBAT = 3,
    NEVER = 4
}



function Direction:OnInitialize()
    self.db = RoithiUI.db.profile.Direction
    self.db.visibility = self.db.visibility or VISIBILITY.ALWAYS
    self:CreateIndicators()
end

function Direction:OnEnable()
    if self.db.enabled then
        self:RegisterEvent("PLAYER_REGEN_DISABLED", "UpdateVisibility")
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateVisibility")
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateVisibility")
        self:UpdateVisibility()
    else
        self:UnregisterAllEvents()
        self.Left:Hide()
        self.Right:Hide()
    end
end

function Direction:OnDisable()
    self:UnregisterAllEvents()
    self.Left:Hide()
    self.Right:Hide()
end

function Direction:UpdateVisibility()
    if not self.db.enabled then
        self.Left:Hide()
        self.Right:Hide()
        return
    end

    if self.Left.isInEditMode or self.Right.isInEditMode then
        self.Left:Show()
        self.Right:Show()
        return
    end

    local inCombat = UnitAffectingCombat("player")
    local mode = self.db.visibility
    local shouldShow = false

    if mode == VISIBILITY.ALWAYS then
        shouldShow = true
    elseif mode == VISIBILITY.IN_COMBAT then
        shouldShow = inCombat
    elseif mode == VISIBILITY.OUT_OF_COMBAT then
        shouldShow = not inCombat
    elseif mode == VISIBILITY.NEVER then
        shouldShow = false
    end

    if shouldShow then
        self.Left:Show()
        self.Right:Show()
    else
        self.Left:Hide()
        self.Right:Hide()
    end
end

function Direction:Toggle(enabled)
    self.db.enabled = enabled
    if enabled then
        self:OnEnable()
    else
        self:OnDisable()
    end
end

function Direction:CreateIndicators()
    local size = 96

    -- Left Indicator
    local left = CreateFrame("Frame", "RoithiDirectionLeft", UIParent)
    left:SetSize(size, size)
    left.Texture = left:CreateTexture(nil, "ARTWORK")
    left.Texture:SetAllPoints()
    left.Texture:SetTexture("Interface\\Icons\\misc_arrowleft") -- Left Arrow (Misc Icon)
    left.Texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)            -- Squared / Zoomed 30%

    left.Text = left:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    LibRoithi.mixins:SetFont(left.Text, "Roithi Thick", 24, "OUTLINE") -- Larger Font
    left.Text:SetPoint("TOP", left, "BOTTOM", 0, -2)
    left.Text:SetText("Links")

    left:SetPoint(self.db.left.point, UIParent, self.db.left.point, self.db.left.x, self.db.left.y)
    self.Left = left

    -- Right Indicator
    local right = CreateFrame("Frame", "RoithiDirectionRight", UIParent)
    right:SetSize(size, size)
    right.Texture = right:CreateTexture(nil, "ARTWORK")
    right.Texture:SetAllPoints()
    right.Texture:SetTexture("Interface\\Icons\\misc_arrowright") -- Right Arrow (Misc Icon)
    right.Texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)             -- Squared / Zoomed 30%

    right.Text = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    LibRoithi.mixins:SetFont(right.Text, "Roithi Thick", 24, "OUTLINE") -- Larger Font
    right.Text:SetPoint("TOP", right, "BOTTOM", 0, -2)
    right.Text:SetText("Rechts")

    right:SetPoint(self.db.right.point, UIParent, self.db.right.point, self.db.right.x, self.db.right.y)
    self.Right = right

    -- Edit Mode
    local LEM = LibStub("LibEditMode", true)
    if LEM then
        local settings = {
            {
                kind = LEM.SettingType.Dropdown,
                name = "Visibility",
                get = function() return self.db.visibility end,
                set = function(_, val)
                    self.db.visibility = val
                    self:UpdateVisibility()
                end,
                values = {
                    { text = "Always",        value = 1 },
                    { text = "In Combat",     value = 2 },
                    { text = "Out of Combat", value = 3 },
                    { text = "Never",         value = 4 },
                }
            }
        }

        -- Left
        LEM:AddFrame(left, function(f, layoutName, point, x, y)
            self.db.left.point = point
            self.db.left.x = x
            self.db.left.y = y
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
        end, { point = "CENTER", x = -500, y = 50 })
        LEM:AddFrameSettings(left, settings)

        -- Right
        LEM:AddFrame(right, function(f, layoutName, point, x, y)
            self.db.right.point = point
            self.db.right.x = x
            self.db.right.y = y
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
        end, { point = "CENTER", x = 500, y = 50 })
        LEM:AddFrameSettings(right, settings)

        -- Edit Mode Visibility
        LEM:RegisterCallback('enter', function()
            left.isInEditMode = true
            right.isInEditMode = true
            self:UpdateVisibility()
        end)

        LEM:RegisterCallback('exit', function()
            left.isInEditMode = false
            right.isInEditMode = false
            self:UpdateVisibility()
        end)
    end
end
