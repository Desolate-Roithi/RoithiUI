-- Core/FontEngine.lua
-- Centralized Font & Typography Engine for RoithiUI

local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LSM = LibStub("LibSharedMedia-3.0", true)

local FontEngine = {}
RoithiUI.FontEngine = FontEngine

local DEFAULT_FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

local function ResolveLSMFont(fontName)
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
    return DEFAULT_FALLBACK_FONT
end

function RoithiUI:GetModuleDB(moduleKey)
    if not self.db or not self.db.profile then return nil end
    return self.db.profile[moduleKey]
end

function RoithiUI:GetFontInfo(moduleKey, textKey, defaultSize, defaultOutline)
    local modDB = moduleKey and self:GetModuleDB(moduleKey)
    local globalGeneral = self.db and self.db.profile and self.db.profile.General

    -- 1. Text-specific override
    local textFont = nil
    local textSize = nil
    local textOutline = nil
    if modDB and modDB.fonts and textKey and modDB.fonts[textKey] then
        local tConf = modDB.fonts[textKey]
        textFont = tConf.font
        textSize = tConf.size
        textOutline = tConf.outline
    end

    -- 2. Module-level fallback
    local modFont = modDB and modDB.font
    local modSize = modDB and modDB.fontSize
    local modOutline = modDB and modDB.fontOutline

    -- 3. Global fallback
    local globalFont = (globalGeneral and globalGeneral.font) or (self.db and self.db.profile and self.db.profile.font) or "Roithi Thick"
    local globalOutline = (globalGeneral and globalGeneral.fontOutline) or "OUTLINE"

    local finalFontName = textFont or modFont or globalFont
    local finalSize = textSize or modSize or defaultSize or 12
    local finalOutline = textOutline or modOutline or globalOutline or defaultOutline or "OUTLINE"
    local fontPath = ResolveLSMFont(finalFontName)

    return fontPath, finalSize, finalOutline, finalFontName
end

function RoithiUI:ApplyFont(fontString, moduleKey, textKey, defaultSize, defaultOutline)
    if not fontString or not fontString.SetFont then return end
    local fontPath, size, outline = self:GetFontInfo(moduleKey, textKey, defaultSize, defaultOutline)
    fontString:SetFont(fontPath, size, outline)
    if fontString.SetShadowOffset then
        if outline ~= "NONE" and outline ~= "" then
            fontString:SetShadowOffset(0, 0)
        else
            fontString:SetShadowOffset(1, -1)
        end
    end
end

function RoithiUI:TriggerFontUpdate()
    if self.SendMessage then
        self:SendMessage("ROITHIUI_FONT_CHANGED")
    end
    if self.modules then
        for name, module in self:IterateModules() do
            if module.UpdateFonts then
                pcall(module.UpdateFonts, module)
            elseif module.StyleAll then
                pcall(module.StyleAll, module)
            elseif module.StyleAllBars then
                pcall(module.StyleAllBars, module)
            end
        end
    end
end
