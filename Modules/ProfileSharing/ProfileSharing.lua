-- Modules/ProfileSharing/ProfileSharing.lua
-- Optimized Profile Export/Import with Delta Pruning, Float Precision Cleanup, and LibDeflate Max Compression

local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ProfileSharing = RoithiUI:NewModule("ProfileSharing")

local Serializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")

local function RoundNumber(val)
    if type(val) ~= "number" then return val end
    if val == math.floor(val) then return val end
    local nearestInt = math.floor(val + 0.5)
    if math.abs(val - nearestInt) < 0.0001 then
        return nearestInt
    end
    return math.floor(val * 1000 + 0.5) / 1000
end

local function PruneTable(tbl, defaultTbl)
    if type(tbl) ~= "table" then
        return RoundNumber(tbl)
    end

    local clean = {}
    local hasEntries = false

    for k, v in pairs(tbl) do
        local keyStr = tostring(k)
        if k ~= "tempImportString" and k ~= "migratedTypography" and k ~= "IndicatorTestMode" and not keyStr:match("^temp") then
            local defVal = defaultTbl and defaultTbl[k]
            if type(v) == "table" then
                local isArray = (#v > 0)
                if isArray then
                    local cleanArray = {}
                    for i, elem in ipairs(v) do
                        cleanArray[i] = PruneTable(elem, nil)
                    end
                    clean[k] = cleanArray
                    hasEntries = true
                else
                    local sub = PruneTable(v, type(defVal) == "table" and defVal or nil)
                    if sub and next(sub) ~= nil then
                        clean[k] = sub
                        hasEntries = true
                    end
                end
            else
                local roundedV = RoundNumber(v)
                local roundedDef = (type(defVal) == "number") and RoundNumber(defVal) or defVal
                if defVal == nil or roundedV ~= roundedDef then
                    clean[k] = roundedV
                    hasEntries = true
                end
            end
        end
    end

    if hasEntries then
        return clean
    end
    return nil
end

local function CopyValues(dest, src)
    if type(dest) ~= "table" or type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" then
            local isArray = (#v > 0)
            if isArray then
                dest[k] = {}
                for i, elem in ipairs(v) do
                    if type(elem) == "table" then
                        dest[k][i] = {}
                        CopyValues(dest[k][i], elem)
                    else
                        dest[k][i] = elem
                    end
                end
            else
                if type(dest[k]) ~= "table" then
                    dest[k] = {}
                end
                CopyValues(dest[k], v)
            end
        else
            dest[k] = v
        end
    end
end

function ProfileSharing:OnInitialize()
    -- Initialize module settings if needed
end

function ProfileSharing:ExportProfile()
    local profileData = RoithiUI.db and RoithiUI.db.profile
    if not profileData then return "" end

    local defaults = (ns.Defaults and ns.Defaults.profile) or {}
    local prunedData = PruneTable(profileData, defaults) or {}

    local exportPayload = {
        addon = "RoithiUI",
        version = 1,
        profile = prunedData,
    }

    local serialized = Serializer:Serialize(exportPayload)
    local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
    local encoded = LibDeflate:EncodeForPrint(compressed)

    return encoded
end

function ProfileSharing:ImportProfile(importString)
    if not importString or importString == "" then return false, "Empty import string" end

    local decoded = LibDeflate:DecodeForPrint(importString)
    if not decoded then return false, "Failed to decode import string" end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return false, "Failed to decompress import string" end

    local success, rawData = Serializer:Deserialize(decompressed)
    if not success then return false, "Failed to deserialize profile data" end

    if type(rawData) ~= "table" then
        return false, "Imported data is not a valid table"
    end

    -- Support both envelope format { addon = "RoithiUI", profile = ... } and legacy raw profile table
    local profilePayload = rawData
    if rawData.addon == "RoithiUI" and type(rawData.profile) == "table" then
        profilePayload = rawData.profile
    end

    -- Validation
    if rawData.addon ~= "RoithiUI" and not profilePayload.General and not profilePayload.UnitFrames and not profilePayload.Actionbars and not profilePayload.Minimap then
        return false, "Imported data does not appear to be a valid RoithiUI profile"
    end

    if not RoithiUI.db or not RoithiUI.db.profile then
        return false, "RoithiUI database not available"
    end

    -- 1. Wipe current profile so pruned/omitted keys cleanly fall back to defaults
    for k in pairs(RoithiUI.db.profile) do
        RoithiUI.db.profile[k] = nil
    end

    -- 2. Populate defaults first so any pruned settings retain their expected defaults
    local defaults = (ns.Defaults and ns.Defaults.profile) or {}
    CopyValues(RoithiUI.db.profile, defaults)

    -- 3. Deep-copy imported delta settings on top of defaults
    CopyValues(RoithiUI.db.profile, profilePayload)

    -- 4. Live refresh all modules
    if RoithiUI.RefreshProfile then
        RoithiUI:RefreshProfile()
    end

    return true
end

ns.ProfileSharing = ProfileSharing
