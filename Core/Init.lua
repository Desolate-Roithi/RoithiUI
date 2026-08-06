local addonName, ns = ...

-- [1] CONFLICT DETECTION (Top Level)
local isDev = string.match(addonName, "%-Dev$")
local prodName = "RoithiUI"
local otherName = isDev and prodName or "RoithiUI-Dev"

if C_AddOns.IsAddOnLoaded(otherName) then
    ns.skipLoad = true
    return
end

if isDev then
    local state = C_AddOns.GetAddOnEnableState((UnitName("player") or "player"), prodName)
    if state and state > 0 then
        ns.skipLoad = true
        C_Timer.After(5, function()
            print("|cffff0000[" .. addonName .. "]|r |cff00ccffAborted:|r Production version (" .. prodName .. ") is also enabled. Please disable one.")
        end)
        return
    end
end

-- Initialize AceAddon
-- We mixin AceConsole-3.0 here in anticipation of Commands.lua using it via the main object
_G.RoithiUI = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local RoithiUI = _G.RoithiUI


-- Debug Flag
RoithiUI.debug = false

function RoithiUI:Log(...)
    if not self.db or not self.db.profile.General.debugMode then return end
    local prefix = "|cff00ccffRoithiUI:|r"
    print(prefix, ...)
end

-- Module Handling is now natively provided by AceAddon:
-- RoithiUI:NewModule(name, prototype, mixins)
-- RoithiUI:GetModule(name)
-- We don't need to manually define self.modules or NewModule unless we want custom behavior.
-- Existing modules use `RoithiUI:NewModule("UnitFrames")` which works with AceAddon.

function RoithiUI:OnInitialize()
    -- Global Initialized Flag (Last resort if somehow both start initializing)
    if _G.RoithiUI_Initialized then return end
    _G.RoithiUI_Initialized = true

    -- Initialize AceDB
    self.db = LibStub("AceDB-3.0"):New("RoithiUIDB", ns.Defaults, true)

    -- Create a hidden parent for Blizzard frames
    if not self.HiddenFrame then
        self.HiddenFrame = CreateFrame("Frame")
        self.HiddenFrame:Hide()
    end

    -- Register Profile Callbacks
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshProfile")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshProfile")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshProfile")

    -- DB Migration Logic: Legacy Manual -> AceDB Profile
    if _G.RoithiUIDB and not _G.RoithiUIDB.profiles then
        local rawDB = _G.RoithiUIDB
        if rawDB.EnabledModules and not rawDB.profiles then
            for k, v in pairs(rawDB) do
                if k ~= "profiles" and k ~= "profileKeys" then
                    self.db.profile[k] = v
                    rawDB[k] = nil
                end
            end
            self:Print("Migrated legacy settings to 'Default' profile.")
        end
    end

    -- MidnightCastbars Migration (Keep this just in case)
    if _G.MidnightCastbarsDB then
        self.db.profile.Castbar = CopyTable(_G.MidnightCastbarsDB)
        _G.MidnightCastbarsDB = nil
        print("|cff00ccffRoithiUI:|r Migrated MidnightCastbarsDB settings to RoithiUIDB.")
    end

    -- Register Options Table (with DualSpec support if available)
    -- We can register basic profiles too
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RoithiUI_Profiles",
        LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
    -- Add to Blizzard Options
    -- LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RoithiUI_Profiles", "Profiles", "RoithiUI") -- Requires main options registered first

    -- AceAddon calls OnInitialize on modules automatically.

    -- Protect LibEditMode selection labels against WoW 12.0.7 / 12.1.0 secret IsTruncated taint errors
    local LEM = LibStub("LibEditMode-Roithi", true)
    if LEM and LEM.AddFrame and not LEM.roithiFontSecured then
        LEM.roithiFontSecured = true
        local origAddFrame = LEM.AddFrame
        LEM.AddFrame = function(selfObj, frameObj, callbackObj, defaultObj, nameObj)
            origAddFrame(selfObj, frameObj, callbackObj, defaultObj, nameObj)
            local selection = selfObj.frameSelections and selfObj.frameSelections[frameObj]
            if selection then
                local labels = { selection.Label, selection.HorizontalLabel, selection.VerticalLabel }
                for _, lbl in ipairs(labels) do
                    if lbl and lbl.ApplyFontObjects then
                        lbl.ApplyFontObjects = function(fontString)
                            if not fontString.fontObjectsToTry then return end
                            for _, fontObj in ipairs(fontString.fontObjectsToTry) do
                                fontString:SetFontObject(fontObj)
                                local ok, isTrunc = pcall(function() return fontString:IsTruncated() end)
                                local isSec = (issecretvalue and issecretvalue(isTrunc))
                                           or (C_Secrets and C_Secrets.IsSecret and C_Secrets.IsSecret(isTrunc))
                                           or (type(isTrunc) == "userdata")

                                if not ok or isSec then
                                    break
                                else
                                    if not isTrunc then
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                -- 2. Protect against GameTooltip:SetOwner UntrustedLayoutScriptExecution taint lock in 12.1.0
                selection.CheckShowInstructionalTooltip = function(sel)
                    if not sel:IsSelected() then
                        local ok = pcall(function()
                            local tooltip = _G.GetAppropriateTooltip and _G.GetAppropriateTooltip() or _G.GameTooltip
                            tooltip:SetOwner(sel, "ANCHOR_CURSOR")
                            if sel.system and sel.system.GetSystemName then
                                tooltip:SetText(sel.system:GetSystemName())
                            end
                            tooltip:Show()
                        end)
                        if not ok then
                            pcall(function() _G.GameTooltip:Hide() end)
                        end
                    else
                        pcall(function()
                            local tooltip = _G.GetAppropriateTooltip and _G.GetAppropriateTooltip() or _G.GameTooltip
                            tooltip:Hide()
                        end)
                    end
                end

                selection.HideInstructionalTooltip = function(sel)
                    pcall(function()
                        local tooltip = _G.GetAppropriateTooltip and _G.GetAppropriateTooltip() or _G.GameTooltip
                        tooltip:Hide()
                    end)
                end
            end

            -- 3. Protect frameObj:GetPoint against 12.1.0 Secret userdata returns
            if frameObj and frameObj.GetPoint and not frameObj.roithiGetPointSecured then
                frameObj.roithiGetPointSecured = true
                local origGetPoint = frameObj.GetPoint
                frameObj.GetPoint = function(s, idx)
                    local p, relTo, relP, x, y = origGetPoint(s, idx or 1)
                    local isSec = (issecretvalue and (issecretvalue(p) or issecretvalue(x) or issecretvalue(y)))
                               or (C_Secrets and C_Secrets.IsSecret and (C_Secrets.IsSecret(p) or C_Secrets.IsSecret(x) or C_Secrets.IsSecret(y)))
                               or (type(p) == "userdata" or type(x) == "userdata" or type(y) == "userdata")

                    if isSec then
                        local dbP = s.roithiSavedPoint or (defaultObj and defaultObj.point) or "CENTER"
                        local dbRelP = s.roithiSavedRelPoint or dbP
                        local dbX = s.roithiSavedX or (defaultObj and defaultObj.x) or 0
                        local dbY = s.roithiSavedY or (defaultObj and defaultObj.y) or 0
                        return dbP, _G.UIParent, dbRelP, dbX, dbY
                    end

                    return p, relTo, relP, x, y
                end
            end

            -- 4. Protect frameObj geometry methods against 12.1.0 Secret userdata returns
            if frameObj and not frameObj.roithiBoundsSecured then
                frameObj.roithiBoundsSecured = true

                local methods = { "GetLeft", "GetTop", "GetRight", "GetBottom", "GetCenter", "GetRect" }
                for _, method in ipairs(methods) do
                    if type(frameObj[method]) == "function" then
                        local origMethod = frameObj[method]
                        frameObj[method] = function(s, ...)
                            local results = { origMethod(s, ...) }
                            local isSec = false
                            for _, v in ipairs(results) do
                                if (issecretvalue and issecretvalue(v))
                                or (C_Secrets and C_Secrets.IsSecret and C_Secrets.IsSecret(v))
                                or (type(v) == "userdata") then
                                    isSec = true
                                    break
                                end
                            end

                            if isSec then
                                local sw, sh = _G.UIParent:GetSize()
                                local rawFw = (type(s.GetWidth) == "function" and s:GetWidth())
                                local rawFh = (type(s.GetHeight) == "function" and s:GetHeight())

                                local isFwSec = (issecretvalue and issecretvalue(rawFw))
                                             or (C_Secrets and C_Secrets.IsSecret and C_Secrets.IsSecret(rawFw))
                                             or (type(rawFw) == "userdata") or not rawFw

                                local isFhSec = (issecretvalue and issecretvalue(rawFh))
                                             or (C_Secrets and C_Secrets.IsSecret and C_Secrets.IsSecret(rawFh))
                                             or (type(rawFh) == "userdata") or not rawFh

                                local fw = not isFwSec and rawFw or (s.roithiCalcWidth or 100)
                                local fh = not isFhSec and rawFh or (s.roithiCalcHeight or 30)

                                local x = s.roithiSavedX or 0
                                local y = s.roithiSavedY or 0

                                local left = (sw / 2) + x - (fw / 2)
                                local right = left + fw
                                local bottom = (sh / 2) + y - (fh / 2)
                                local top = bottom + fh

                                if method == "GetLeft" then return left end
                                if method == "GetTop" then return top end
                                if method == "GetRight" then return right end
                                if method == "GetBottom" then return bottom end
                                if method == "GetCenter" then return (left + right) / 2, (top + bottom) / 2 end
                                if method == "GetRect" then return left, bottom, fw, fh end
                            end

                            return unpack(results)
                        end
                    end
                end
            end
        end
    end

    -- Register Options
    if self.Config and self.Config.RegisterOptions then
        self.Config:RegisterOptions()
    end
end

function RoithiUI:RefreshProfile()
    if ns and ns.RefreshAllCastbars then ns.RefreshAllCastbars() end
    
    local UF = self:GetModule("UnitFrames")
    if UF and UF.units then
        for unit, _ in pairs(UF.units) do
            if UF.ToggleFrame then
                UF:ToggleFrame(unit, UF:IsUnitEnabled(unit))
            end
            if UF:IsUnitEnabled(unit) and UF.UpdateFrameFromSettings then
                UF:UpdateFrameFromSettings(unit)
            end
        end
    end
    
    -- Also close AceConfigDialog if it's open or refresh registry to match new DB
    LibStub("AceConfigRegistry-3.0"):NotifyChange("RoithiUI_Profiles")
    
    if self.Config and self.Config.OptionsRefresh then
        self.Config:OptionsRefresh()
    end
end

function RoithiUI:OnEnable()
    -- AceAddon calls OnEnable on modules automatically.

    -- Additional startup logic if needed
    -- For example checking module enablement from DB manually before Ace enables them?
    -- AceAddon enables all modules by default.
    -- If we want to support the "Enable/Disable" toggles from RoithiUIDB.EnabledModules,
    -- we might need to iterate modules here and Disable them if the DB says so.

    for name, module in self:IterateModules() do
        local isEnabled = self.db.profile.EnabledModules and self.db.profile.EnabledModules[name]
        -- Handle explicit disable
        if isEnabled == false then
            module:Disable()
        end
    end
end
