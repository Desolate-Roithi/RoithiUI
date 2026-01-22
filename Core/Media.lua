-- Media.lua
-- Centralizes SharedMedia registration and Theme definitions.

local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LSM = LibStub("LibSharedMedia-3.0")

-- ----------------------------------------------------------------------------
-- Media Registration
-- ----------------------------------------------------------------------------
-- Fonts
LSM:Register("font", "Roithi Font", [[Interface\Addons\RoithiUI\Media\Fonts\MyFont.ttf]]) -- Example path

-- StatusBars
LSM:Register("statusbar", "Roithi Flat", [[Interface\Addons\RoithiUI\Media\StatusBars\Flat.tga]])

-- ----------------------------------------------------------------------------
-- Themes
-- ----------------------------------------------------------------------------
RoithiUI.Themes = {}

function RoithiUI:GetTheme(name)
    return self.Themes[name] or self.Themes["Class"] -- Default
end

-- Theme: Class Colors
RoithiUI.Themes["Class"] = {
    health = { 0.2, 0.2, 0.2 }, -- Fallback
    useClassColors = true,
    power = { 0.2, 0.5, 0.9 },
}

-- Theme: Grayscale
RoithiUI.Themes["Grayscale"] = {
    health = { 0.3, 0.3, 0.3 },
    useClassColors = false,
    power = { 0.5, 0.5, 0.5 },
    tapped = { 0.5, 0.5, 0.5 },
    disconnected = { 0.4, 0.4, 0.4 },
}

-- Helper to apply theme to a frame
function RoithiUI:ApplyTheme(frame, themeName)
    local theme = self:GetTheme(themeName)
    if not frame.SafeHealth then return end

    -- Update Header/Health settings
    frame.SafeHealth.colorClass = theme.useClassColors
    frame.SafeHealth.colorSmooth = theme.useClassColors -- or false if specific logic

    if not theme.useClassColors then
        frame.SafeHealth:SetStatusBarColor(unpack(theme.health))
    end

    -- Force update
    if frame.SafeHealth.ForceUpdate then
        frame.SafeHealth:ForceUpdate()
    end
end
