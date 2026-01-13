local MAJOR, MINOR = "LibRoithi-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local LSM = LibStub("LibSharedMedia-3.0")

-- Mixins
lib.mixins = {}

--- Applies a pixel perfect 1px backdrop to the frame
-- @param frame The frame to apply the backdrop to
-- @param template Optional BackdropTemplate to use (defaults to BackdropTemplate)
function lib.mixins:CreateBackdrop(frame, template)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })

    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

--- Creates a 1px border around the frame
-- @param frame The frame to apply the border to
function lib.mixins:CreatePixelBorder(frame)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end

    frame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

--- Sets the font for a font string or frame with text
-- @param obj The FontString or Frame to set the font on
-- @param fontName The name of the font registered in LSM
-- @param size The size of the font
-- @param flags Optional flags (OUTLINE, MONOCHROME, etc.)
function lib.mixins:SetFont(obj, fontName, size, flags)
    local fontPath = LSM:Fetch("font", fontName or "Friz Quadrata TT")

    if obj.SetFont then
        obj:SetFont(fontPath, size or 12, flags or "OUTLINE")
    elseif obj.GetFontString then
        local fs = obj:GetFontString()
        if fs then
            fs:SetFont(fontPath, size or 12, flags or "OUTLINE")
        end
    end
end

-- Global Access for convenience if needed, but LibStub is preferred
_G.LibRoithi = lib
