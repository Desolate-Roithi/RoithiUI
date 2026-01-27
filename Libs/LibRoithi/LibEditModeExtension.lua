local lib = LibStub('LibEditMode')
if not lib then return end

-- [[ Polyfill for Missing Internal API ]]
-- If LibEditMode is missing its internals (e.g. standalone version vs embedded), we recreate the pool logic here.
if not lib.internal then lib.internal = {} end

if not lib.internal.CreatePool then
    local pools = {}
    local Acquire = CreateUnsecuredObjectPool().Acquire

    local function acquire(self, parent)
        local obj, new = Acquire(self)
        if parent then
            obj:SetParent(parent)
        end
        return obj, new
    end

    function lib.internal:CreatePool(kind, creationFunc, resetterFunc)
        local pool = CreateUnsecuredObjectPool(creationFunc, resetterFunc)
        -- We inject our acquire wrapper to ensure parenting
        pool.Acquire = acquire
        pools[kind] = pool
    end

    function lib.internal:GetPool(kind)
        return pools[kind]
    end
end
-- [[ End Polyfill ]]

-- Add New Setting Types
lib.SettingType.CollapsibleHeader = 11
lib.SettingType.ColorRow = 12
lib.SettingType.Button = 13

-- 1. Collapsible Header Widget
local headerMixin = {}
function headerMixin:Setup(data)
    self.setting = data

    -- Dynamic Width Logic
    local parent = self:GetParent()
    if parent and parent:GetWidth() > 0 then
        self.fixedWidth = parent:GetWidth()
        self:SetWidth(self.fixedWidth)
    end

    self.Text:SetText(data.name)

    local isExpanded = data.get(lib:GetActiveLayoutName())
    if isExpanded then
        self.Symbol:SetText("\226\150\178") -- ▲
    else
        self.Symbol:SetText("\226\150\188") -- ▼
    end

    -- Mathematical Centering for the group (Text + Gap + Symbol)
    local textWidth = self.Text:GetStringWidth()
    local symbolWidth = self.Symbol:GetStringWidth()
    local gap = 5
    local totalWidth = textWidth + gap + symbolWidth

    self.Text:ClearAllPoints()
    self.Text:SetPoint("LEFT", self, "CENTER", -totalWidth / 2, 0)

    self.Symbol:ClearAllPoints()
    self.Symbol:SetPoint("LEFT", self.Text, "RIGHT", gap, 0)
end

function headerMixin:OnHeaderClick()
    local isExpanded = not self.setting.get(lib:GetActiveLayoutName())
    self.setting.set(lib:GetActiveLayoutName(), isExpanded, true)

    if isExpanded then
        self.Symbol:SetText("\226\150\178") -- ▲
    else
        self.Symbol:SetText("\226\150\188") -- ▼
    end
end

lib.internal:CreatePool(lib.SettingType.CollapsibleHeader, function()
    local button = CreateFrame('Button', nil, UIParent)
    button.fixedWidth = 350
    button.fixedHeight = 45
    button:SetSize(350, 45)
    Mixin(button, headerMixin)

    -- Standard Font for the label text
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    button.Text = text

    -- Arial Narrow specifically for the triangle symbols (better support in WoW client)
    local symbol = button:CreateFontString(nil, "OVERLAY")
    symbol:SetFont("Fonts\\ARIALN.TTF", 14, "")
    symbol:SetTextColor(1, 0.82, 0) -- Blizzard Yellow
    button.Symbol = symbol

    button:SetScript("OnClick", function(self) self:OnHeaderClick() end)

    -- Hover effect
    button:SetScript("OnEnter", function(self)
        self.Text:SetTextColor(1, 1, 1)
        self.Symbol:SetShadowOffset(1, -1)
    end)
    button:SetScript("OnLeave", function(self)
        self.Text:SetTextColor(1, 1, 1)
        self.Symbol:SetShadowOffset(0, 0)
    end)

    return button
end, function(_, button)
    button:Hide()
    button.layoutIndex = nil
end)


-- 2. Color Row Widget
local colorRowMixin = {}

local function onColorChanged(swatch)
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local a = ColorPickerFrame:GetColorAlpha()
    local color = CreateColor(r, g, b, a)

    swatch.colorData.set(lib:GetActiveLayoutName(), color, false)
    swatch:SetColorRGB(r, g, b)

    -- update colorInfo for next run
    swatch.colorInfo.r = r
    swatch.colorInfo.g = g
    swatch.colorInfo.b = b
    swatch.colorInfo.opacity = a
end

local function onColorCancel(swatch)
    swatch.colorData.set(lib:GetActiveLayoutName(), swatch.oldValue, false)
    local r, g, b, a = swatch.oldValue:GetRGBA()
    swatch:SetColorRGB(r, g, b)

    swatch.colorInfo.r = r
    swatch.colorInfo.g = g
    swatch.colorInfo.b = b
    swatch.colorInfo.opacity = a
end

local function onSwatchClick(swatch)
    local info = swatch.colorInfo
    swatch.oldValue = CreateColor(info.r, info.g, info.b, info.opacity)
    ColorPickerFrame:SetupColorPickerAndShow(info)
end

function colorRowMixin:Setup(data)
    self.setting = data
    self.Label:SetText(data.name)

    -- Dynamic Width Logic
    local parent = self:GetParent()
    if parent and parent:GetWidth() > 0 then
        self.fixedWidth = parent:GetWidth()
        self:SetWidth(self.fixedWidth)
    end

    -- Reset swatches visibility
    for _, swatch in ipairs(self.Swatches) do
        swatch:Hide()
    end

    for i, colorData in ipairs(data.colors) do
        local swatch = self.Swatches[i]
        if not swatch then
            -- Create more swatches if needed
            swatch = CreateFrame('Button', nil, self, 'ColorSwatchTemplate')
            swatch:SetSize(32, 32)
            if i == 1 then
                swatch:SetPoint('LEFT', self.Label, 'RIGHT', 5, 0)
            else
                swatch:SetPoint('LEFT', self.Swatches[i - 1], 'RIGHT', 2, 0)
            end
            swatch:SetScript('OnClick', onSwatchClick)
            self.Swatches[i] = swatch
        end

        swatch:Show()
        swatch.colorData = colorData

        local color = colorData.get(lib:GetActiveLayoutName())
        local r, g, b, a = color:GetRGBA()
        swatch:SetColorRGB(r, g, b)

        swatch.colorInfo = {
            swatchFunc = GenerateClosure(onColorChanged, swatch),
            opacityFunc = GenerateClosure(onColorChanged, swatch),
            cancelFunc = GenerateClosure(onColorCancel, swatch),
            r = r,
            g = g,
            b = b,
            opacity = a,
            hasOpacity = true
        }
    end
end

lib.internal:CreatePool(lib.SettingType.ColorRow, function()
    local frame = CreateFrame('Frame', nil, UIParent, 'ResizeLayoutFrame')
    frame.fixedWidth = 350
    frame.fixedHeight = 56
    frame:Hide()
    Mixin(frame, colorRowMixin)

    local Label = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightMedium')
    Label:SetPoint('LEFT')
    Label:SetSize(100, 32)
    Label:SetJustifyH('LEFT')
    frame.Label = Label

    frame.Swatches = {}
    return frame
end, function(_, frame)
    frame:Hide()
    frame.layoutIndex = nil
end)


-- 3. Button Widget
local buttonMixin = {}
function buttonMixin:Setup(data)
    self.setting = data
    self:SetText(data.name)

    -- Dynamic Width Logic
    local parent = self:GetParent()
    if parent and parent:GetWidth() > 0 then
        self.fixedWidth = parent:GetWidth()
        self:SetWidth(self.fixedWidth)
    end

    self:SetScript("OnClick", function()
        if data.func then data.func() end
    end)
end

lib.internal:CreatePool(lib.SettingType.Button, function()
    local button = CreateFrame('Button', nil, UIParent, "UIPanelButtonTemplate")
    button.fixedWidth = 350
    button.fixedHeight = 30
    button:SetSize(350, 30)
    Mixin(button, buttonMixin)
    return button
end, function(_, button)
    button:Hide()
    button.layoutIndex = nil
end)
