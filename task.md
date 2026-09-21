# Task: WoW Retail & WoW Forever Dual Compatibility + Ping System Restoration

## Completed Items
1. **WoW Forever Development Link**:
   - Created directory junction `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\RoithiUI-Dev` pointing to `D:\Development Addons\RoithiUI`.
2. **Packaging & Multiversion TOC**:
   - Updated `RoithiUI.toc` and `RoithiUI-Dev.toc` with `## Interface: 120100, 120007, 16001` and `## AllowLoadGameType: standard, camelot`.
3. **Environment Detection**:
   - Updated `Core/Utils.lua` with `ns.InterfaceVersion`, `ns.IsForever` (16001 / game rule), and `ns.IsRetail`.
4. **Unit Frame Pinging Restoration (Platynator Architecture & Player HP Support)**:
   - Updated `Modules/UnitFrames/Core.lua`:
     - Created child frame inheriting Blizzard's native `PingableUnitFrameTemplate` with `SetAttribute("unit", unit)` and `SetAllPoints(self)` (matching Platynator's architecture).
     - Because `PingableUnitFrameTemplate` is instantiated natively via FrameXML, Blizzard's ping manager hit-tests and queries the untainted frame directly without AddOn Lua execution taints or `securecopy()` secret string crashes.
     - For `unit == "player"`, configured `isPlayerResource = true` and `GetAllowRadialWheel = false` so that pinging the player frame pings the player's health/resource status ("Health: X%" / "Need healing") rather than pinging oneself as a unit in the world.
     - Provided Classic/Forever fallback with secret value safeguards on `GetTargetInfo`.
   - Updated `Tests/Test_UnitFrames_Ping.lua` verifying both native template instantiation, player resource pinging, and Classic fallback modes.
5. **Class Power & Interrupt Cooldowns**:
   - Updated `Modules/UnitFrames/Elements/ClassPower.lua`: `GetSpecialization` nil-safety, combo point target sync on `PLAYER_TARGET_CHANGED`.
   - Updated `Modules/Castbar/Castbar.lua`: Added Classic kick spell IDs (1766, 6552, 2139, 8042, 57994, 15487).
6. **TagManager Specialization & Classic API Nil Safety**:
   - Updated `Modules/UnitFrames/Elements/Tags.lua`:
     - Added nil-safe lookup for `GetSpecialization` in `TM:GetSegments` and `TM.Methods["power.class*"]`.
     - Guarded `UnitStagger` and `UnitGetTotalAbsorbs` against nil in Classic environments.
7. **Automated Verification**:
   - Updated `Tests/Test_Forever_Compatibility.lua` verifying TagManager and ClassPower nil safety in Classic/Forever.
   - All 23 test suites in `Tests/TestRunner.lua` pass 100%.
   - Luacheck verified 0 warnings, 0 errors.
8. **Git Staging Protocol**:
   - Documented mandatory `git add .` usage in `.agent/AGENTS.md` and `.agent/rules/wow-development.md` to rely on `.gitignore` and prevent partial staging.