## Status
- **Phase**: Implementation
- **Branch**: `additional-features`

## Completed Items
1. **Forever Compatibility & ClassPower Crash Fix**:
   - Resolved `ClassPower.lua:238: attempt to call a nil value` in Forever:
     - Made `GetSpecialization` call nil-safe: `local getSpec = GetSpecialization or _G.GetSpecialization; local spec = getSpec and getSpec() or 1`.
     - In Forever, guarded classes without secondary class power (e.g. Paladins) to immediately hide and return cleanly.
     - Added safe `Enum.PowerType` fallbacks for Classic environments where modern enum tables are incomplete.
     - Supported target combo points via `GetComboPoints("player", "target")` and `PLAYER_TARGET_CHANGED` for Rogues and Druids in Classic/Forever.
   - Guarded `Tags.lua` for `GetSpecialization`, `UnitStagger`, and `UnitGetTotalAbsorbs`.
   - Guarded `Bars.lua` for `UnitGetTotalAbsorbs`.
   - Added environment detection in `Core/Utils.lua` (`ns.InterfaceVersion`, `ns.IsForever`, `ns.IsRetail`).
   - Updated `RoithiUI.toc` and `RoithiUI-Dev.toc` with 16001 and camelot game type.
   - Verified via `Tests/Test_Forever_Compatibility.lua` and luacheck (0 warnings / 0 errors).
- **Goal**:
  1. Add module toggle to completely disable/enable each module (UnitFrames, Castbar, EncounterBar, Minimap, AddonBar, Actionbars), compatible with both Retail (12.x) and WoW Forever (Classic 16001).
  2. Overhaul Addon Hiding Bar:
     - Detachable and attachable.
     - Detached: Snaps to nearest screen edge with automatic edge detection by default. Edit mode dropdown option: `Auto`, `Top`, `Left`, `Right`, `Bottom` (snapping constrained to selected edge/corner).
     - Attached: Positioned adjacent to the minimap (as seen in screenshot, with X buttons shown left of minimap), adjustable sizes, extends/collapses via small button symbol at the bottom.
  3. Overhaul Minimap:
     - Design matching reference screenshot: sleek square/modern style, coordinates, zone text.
     - Option for panel bar below or data displayed directly on map (FPS, latency/time, date, friends: guild, in wow, in same version of wow, all bnet, etc.).
  4. Actionbars Module:
     - Integration and configuration for actionbars matching sleek UI design.
