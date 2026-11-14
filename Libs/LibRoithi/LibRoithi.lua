local MAJOR, MINOR = "LibRoithi-1.0", 2
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

--- Safely formats text, handling Secret values in 12.0.1+
-- @param formatString The string format pattern (e.g. "%d / %d")
-- @param ... The values to format
-- @return The formatted string, or a placeholder if values are Secret
function lib.mixins:SafeFormat(formatString, ...)
    local numArgs = select("#", ...)
    for i = 1, numArgs do
        local val = select(i, ...)
        -- 12.0.1: Secret values can be userdata OR numbers that fail arithmetic
        local isSecret = (issecretvalue and issecretvalue(val))
        if isSecret then
            return "..."
        end
    end
    return string.format(formatString, ...)
end

--- Returns a default or named statusbar texture
-- @param name Optional name registered in LSM (defaults to "Solid")
function lib:GetStatusBarTexture(name)
    local tex = LSM and LSM:Fetch("statusbar", name or "Solid")
    return tex or "Interface\\TargetingFrame\\UI-StatusBar"
end

-- Global Access for convenience if needed, but LibStub is preferred
_G.LibRoithi = lib
