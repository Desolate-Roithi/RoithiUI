local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local ProfileSharing = RoithiUI:NewModule("ProfileSharing")

local Serializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")

function ProfileSharing:OnInitialize()
    -- Initialize module settings if needed
end

function ProfileSharing:ExportProfile()
    local profileData = RoithiUI.db.profile
    if not profileData then return "" end

    local serialized = Serializer:Serialize(profileData)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)

    return encoded
end

function ProfileSharing:ImportProfile(importString)
    if not importString or importString == "" then return false, "Empty import string" end

    local decoded = LibDeflate:DecodeForPrint(importString)
    if not decoded then return false, "Failed to decode import string" end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return false, "Failed to decompress import string" end

    local success, data = Serializer:Deserialize(decompressed)
    if not success then return false, "Failed to deserialize profile data" end

    if type(data) ~= "table" then
        return false, "Imported data is not a valid table"
    end

    -- Basic validation: check for expected top-level keys
    if not data.General and not data.UnitFrames then
        return false, "Imported data does not appear to be a valid RoithiUI profile"
    end

    -- Overwrite the current profile
    -- WARNING: This is a destructive operation
    for k, v in pairs(data) do
        RoithiUI.db.profile[k] = v
    end

    return true
end

ns.ProfileSharing = ProfileSharing
