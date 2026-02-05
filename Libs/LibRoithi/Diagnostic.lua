local lib = LibStub("LibRoithi-1.0")

function lib:Diagnostic()
    print("|cffffff00--- LibEditMode-Roithi Diagnostic Tool ---|r")
    print("  Timestamp: " .. tostring(GetTime()))

    local lem = LibStub("LibEditMode-Roithi", true)
    if not lem then
        print("|cffff0000FAIL: LibEditMode-Roithi library object not found via LibStub!|r")
        return
    end

    print("|cff00ff00LEM Diag: Report|r")
    print("  Version (MINOR): " .. tostring(lem.hookVersion or "unknown"))
    print("  Is Editing (Lib): " .. tostring(lem.isEditing and "YES" or "NO"))
    print("  Is Shown (Blizz): " .. tostring(EditModeManagerFrame and EditModeManagerFrame:IsShown() and "YES" or "NO"))

    print("|cff00ff00Registered Frames:|r")
    for frame, selection in pairs(lem.frameSelections or {}) do
        print("  - " ..
        tostring(frame:GetName() or "unnamed") .. " (Selection: " .. (selection:IsShown() and "SHOWN" or "HIDDEN") .. ")")
    end

    local frameCount = 0
    for _ in pairs(lem.frameSettings or {}) do frameCount = frameCount + 1 end
    print("  Registered Frames (frameSettings): " .. frameCount)

    local selectionCount = 0
    for _ in pairs(lem.frameSelections or {}) do selectionCount = selectionCount + 1 end
    print("  Selection Frames (frameSelections): " .. selectionCount)

    -- check for hidden selections
    if lem.isEditing then
        print("  Status: Currently Editing")
        for frame, selection in pairs(lem.frameSelections or {}) do
            if not selection:IsShown() then
                print("    |cffffa500WARN:|r Selection for " .. tostring(frame:GetName()) .. " is HIDDEN!")
                print("      Frame Shown: " .. tostring(frame:IsShown()))
                print("      Selection Alpha: " .. tostring(selection:GetAlpha()))
                print("      Selection Parent: " .. tostring(selection:GetParent() == frame))
            end
        end
    else
        print("  Status: Not Editing")
    end

    print("  System Settings: " .. (lem.systemSettings and "Present" or "MISSING"))
    print("  Extension: " .. (lem.internal and lem.internal.extension and "Present" or "MISSING"))
end
