# 12.1.0 Native Aura Container Architecture Documentation

## Overview
The `Auras` module in `RoithiUI` manages buff and debuff display for unit frames (Player, Target, Focus, Pet, Boss) and user-defined Custom Aura satellite frames using World of Warcraft Patch 12.1.0 native `AuraContainer` and `AuraGroup` C-Engine APIs.

To ensure high maintainability, zero-touch combat taint safety, and clean separation of concerns, the module is divided into 7 focused files under `Modules/UnitFrames/Elements/Auras/`.

---

## File Breakdown

### 1. `Init.lua`
- **Purpose**: Initializes the `ns.Auras` sub-namespace.
- **Key Features**:
  - `ns.Auras.RADLog(fmt, ...)`: Debug logging system for Roithi Aura Debugger.
  - `/rad` slash command handler (`SlashCmdList["ROITHIAURADEBUG"]`).
  - Table registries: `UF.AuraContainers`, `UF.AuraMovers`, `UF.CustomAuraContainers`.

### 2. `Helpers.lua`
- **Purpose**: Pure mathematical, coordinate conversion, and DB query helper functions.
- **Functions**:
  - `ns.Auras.ConvertAnchorPosition(oldPoint, oldX, oldY, newPoint, mW, mH)`: Converts relative coordinates when changing growth directions so frames remain stationary on screen.
  - `ns.Auras.MakeContainerKey(unit, containerSuffix)`: Generates consistent lookup keys (e.g. `RoithiAuraContainer_player_Buffs`).
  - `ns.Auras.IsSupportedUnit(unit)`: Validates supported units (`player`, `target`, `focus`, `pet`, `boss1-5`, etc.).
  - `ns.Auras.GetUnitDB(unit)`: Retrieves UnitFrame DB table with fallback for boss frames.
  - `ns.Auras.GetSmartFilterQueries(filterType, db, unit)`: Builds 12.1.0 `AuraGroup` filter query strings (`HELPFUL|PLAYER`, `HARMFUL|IMPORTANT`, etc.).
  - `ns.Auras.BuildCandidateFilters(db, filterType)`: Merges global default blacklists (`RoithiUI.db.profile.Auras.Blacklist`), unit-specific blacklists/whitelists, and `maxDuration` for timeless aura hiding.

### 3. `Formatting.lua`
- **Purpose**: Applies visual styling, fonts, zoom, cooldown swipes, text overlay frame levels, duration timer formatting, and border indicators to individual aura buttons.
- **Functions**:
  - `ns.Auras.FormatAuraButton(auraButton, containerKey, isDebuff, buttonSize, db)`: Configures texture zoom (`SetTexCoord`), cooldown swipe (`CooldownFrameTemplate`), text overlay frame (`textFrame:SetFrameLevel(GetFrameLevel() + 25)`), duration timer text (`SetDurationText`), stack count text (`SetApplicationCount`), 2px top debuff border indicator, cancel aura click binding (`RightButtonUp`), and pandemic glow texture.

### 4. `Movers.lua`
- **Purpose**: Manages LibEditMode-Roithi integration and visual mover frames.
- **Functions**:
  - `ns.Auras.GetOrCreateAuraMover(container, unit, containerSuffix, isCustom, customID)`: Creates UIParent-level mover frames, registers them with `LibEditMode-Roithi`, sets up right-click popups and options shortcuts.
  - `ns.Auras.UpdateAuraMover(...)`: Positions and sizes movers during Edit Mode, renders dummy sample icons (10 sample icons, timers, counts), handles detached vs attached snapping, and calculates centered horizontal/vertical alignment coordinates.
  - `ns.GetSettingsForCustomAura(customID)`: Registers Edit Mode popup settings for custom aura frames (Aura Size, Icons Per Row, Max Auras, Grow Direction, X/Y Position) utilizing dynamic growth direction corner anchoring.
  - `ns.GetSettingsForAuras(unit, containerSuffix)`: Registers Edit Mode popup settings for unit frame aura containers (Aura Size, Max Auras, Anchor Point, Grow Direction, X/Y Position).

### 5. `Containers.lua`
- **Purpose**: Manages 12.1.0 native `AuraContainer` C-Engine frames and dynamic line layout.
- **Functions**:
  - `ns.Auras.GetOrCreateAuraContainer(unit, containerSuffix, parentFrame)`: Creates or updates `AuraContainer` frames with `CustomAuraContainerTemplate`.
  - `ns.Auras.ConfigureAuraContainer(container, unit, containerSuffix)`: Applies FlowLayout C-Engine settings (`SetFlowLayoutAxis`, `SetFlowLayoutAnchorPoint`, `SetFlowLayoutGrowthDirection`, `SetFlowLayoutMaximumLineSize`), configures active `AuraGroup` filter strings, candidate filters, sorting, combined container debuff count secure hooks, and container bounds sizing.
  - `ns.Auras.FlushContainerFrames(cFrame)`: Flushes inactive containers, disables event listening, and hides mover frames cleanly.

### 6. `CustomAuras.lua`
- **Purpose**: Manages user-defined standalone satellite aura containers.
- **Functions**:
  - `UF:UpdateCustomAura(id)`: Configures a custom aura container by ID with candidate filters, layout options, and mover registration.
  - `UF:UpdateAllCustomAuras()`: Iterates all custom aura entries in `RoithiUI.db.profile.CustomAuraFrames` and updates them.

### 7. `Auras.lua`
- **Purpose**: UnitFrames module main entry points and event watchers.
- **Functions**:
  - `UF:CreateAuras(frame)`: Main entry point during UnitFrame initialization.
  - `UF:UpdateAuras(frame)`: Main update function for unit frames.
  - `UF:UpdateAllAuras()`: Updates all active unit frame containers and custom aura containers.
  - `watcherFrame`: Listens for `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, and `PLAYER_ENTERING_WORLD`.
  - `LibEditMode`: Hooks `enter` and `exit` callbacks to toggle sample aura preview mode.

---

## Architectural Decisions & Technical Rationale

### 1. Modular 7-File Architecture vs. Monolithic File
- **Rationale**: The legacy 1,824-line `Auras_12_1.lua` file mixed UI rendering, Edit Mode dragging, C-Engine layout math, custom satellite frames, and event handlers.
- **Solution**: Splitting into 7 single-responsibility modules (`Init`, `Helpers`, `Formatting`, `Movers`, `Containers`, `CustomAuras`, `Auras`) ensures that button styling changes (`Formatting.lua`) never affect mover drag logic (`Movers.lua`) or unitframe lifecycle hooks (`Auras.lua`). Each file remains under 550 lines for rapid navigation and luacheck isolation.

### 2. Dedicated `AuraMover` Proxy System vs. Direct `AuraContainer` Registration
- **Rationale**: The Patch 12.1.0 native `AuraContainer` frame is controlled by Blizzard's internal `FlowLayout` and `ProcessDirtyFlags` C++ loops. Registering `AuraContainer` directly with `LibEditMode-Roithi` or attaching `OnDragStart`/`OnDragStop` scripts caused position resets and layout conflicts.
- **Solution**: Introduced `AuraMover` — a lightweight, `UIParent`-level proxy frame (`DIALOG` strata, level 200) registered with `LibEditMode-Roithi`. `AuraMover` acts as the drag handle, displays 10 sample preview icons with accurate timers/counts in Edit Mode, and saves non-secret screen coordinates (`point, x, y`). The real `AuraContainer` is never registered with Edit Mode and remains 100% untainted.

### 3. Growth-Direction Origin Corner Anchoring (`targetAnchor`)
- **Rationale**: Anchoring containers to their `"CENTER"` caused symmetric container expansion/contraction when active aura counts changed, shifting the position of the first aura icon across the screen.
- **Solution**: Computed dynamic `targetAnchor` origin corners corresponding 1:1 to growth directions:
  - `RIGHT_DOWN` / `DOWN` / `RIGHT` $\rightarrow$ `TOPLEFT`
  - `LEFT_DOWN` / `LEFT` $\rightarrow$ `TOPRIGHT`
  - `RIGHT_UP` / `UP` $\rightarrow$ `BOTTOMLEFT`
  - `LEFT_UP` $\rightarrow$ `BOTTOMRIGHT`
  - `CENTER_HORIZONTAL_DOWN` $\rightarrow$ `TOP`
  - `CENTER_HORIZONTAL_UP` $\rightarrow$ `BOTTOM`
- **Result**: Containers expand and shrink outward from `targetAnchor`, keeping the **first aura icon completely fixed in place at all times**.

### 4. Seamless Coordinate Translation (`ConvertAnchorPosition`)
- **Rationale**: When changing growth directions in settings (e.g. from `RIGHT_DOWN` to `LEFT_DOWN`), the frame's anchor point changes from `TOPLEFT` to `TOPRIGHT`. Re-anchoring without coordinate conversion caused the frame to jump across the screen.
- **Solution**: `ConvertAnchorPosition` translates existing `(savedPt, px, py)` coordinates into the new `targetAnchor` relative to screen dimensions (`UIParent`). The first aura icon retains its exact pixel location on screen after growth direction changes.

### 5. Native `AuraGroup` Candidate Filter Pipeline & Dual-Mode Whitelist Architecture
- **Rationale**: In WoW Midnight (12.0.7 / 12.1.0), iterating auras in Lua during combat to filter by spell ID triggers Secret userdata Secrecy locks.
- **Solution**: Blacklists (`excludeSpellIDs`) and Whitelists (`includeSpellIDs`) are merged into native `candidateFilters` tables passed directly to Blizzard's C-Engine `SetAuraGroupCandidateFilters`. Filtering and merging occur natively inside Blizzard's C++ engine, guaranteeing zero combat taint and zero FPS overhead.
- **Dual-Mode Whitelist Execution**:
  1. **Show Only Whitelisted (`onlyWhitelistBuffs` / `onlyWhitelistDebuffs`)**: Replaces standard filter queries with a single `"HELPFUL"` or `"HARMFUL"` query whose `candidateFilters` restricts display strictly to spell IDs in `db.Whitelist`.
  2. **Include Whitelisted (`additionalWhitelistBuffs` / `additionalWhitelistDebuffs`)**: Retains all active smart filter groups (`Buffs_1`, `Debuffs_1`...) with standard blacklist candidate filters, and registers a dedicated secondary `Buffs_Whitelist` / `Debuffs_Whitelist` `AuraGroup` with `includeSpellIDs = db.Whitelist`. Blizzard's `AuraContainer` merges both groups into a single layout seamlessly.
  3. **Empty Whitelist Handling & C-Engine Protection**: When a whitelist has 0 active spell IDs, `candidateFilters.includeSpellIDs` is `nil` (never populated with dummy spell ID 0 or empty tables, which would cause Blizzard's C-Engine to drop candidate filters and display all buffs). The secondary `Buffs_Whitelist` / `Debuffs_Whitelist` group is strictly registered ONLY when valid whitelisted spell IDs are present, ensuring 0 extra/unwanted auras display when the whitelist is empty.

### 6. Selective Aura Element Hiding (`hideIcon`, `hideTimer`, `hideCount`)
- **Rationale**: Players often want to isolate a single aura component for specific satellite frames or whitelisted spells. For instance, displaying ONLY the remaining duration timer for a spell (e.g., Boneshield) without redundant icons or stack counts.
- **Solution**:
  - `hideIcon`: Hides the main aura icon texture, top debuff indicator line, and cooldown swipe texture.
  - `hideTimer`: Hides remaining duration text and cooldown swipe texture.
  - `hideCount`: Hides application stack count text.
- **Implementation**: Handled in `Formatting.lua` (`FormatAuraButton`), `Movers.lua` (Edit Mode preview & right-click popups), and AceConfig `Options.lua`.

### 7. Flight Path & Vehicle Whitelist Aura Suppression
- **Rationale**: In Patch 12.1.0, Blizzard's C-Engine `AuraContainer` candidate filter evaluator (`AuraContainerUtil.CanApplyIdentityCandidateFilters`) enforces that `UnitCanAssist("player", unitToken)` must evaluate to `true` to allow `candidateFilters.includeSpellIDs` on helpful buffs. When on a flight path (e.g. Vault of Ula'thek taxi) or in certain vehicle states, `UnitCanAssist("player", "player")` evaluates to `false`. Blizzard's C-Engine drops the candidate whitelist check, causing `"HELPFUL"` AuraGroups to default to displaying **ALL buffs** on the player.
- **Solution**:
  - `IsPlayerInaccessible(unit)`: Detects when `UnitOnTaxi("player")`, `UnitInVehicle("player")`, `UnitHasVehicleUI("player")`, or `not UnitCanAssist("player", "player")` is active.
  - Suppresses/hides "Show Only Whitelisted" aura containers and bypasses registering secondary `Buffs_Whitelist` / `Debuffs_Whitelist` / `CustomBuffs_Whitelist` / `CustomDebuffs_Whitelist` AuraGroups while in an inaccessible state.
  - Event listeners on `watcherFrame` (`UNIT_ENTERED_VEHICLE`, `UNIT_EXITED_VEHICLE`, `PLAYER_CONTROL_LOST`, `PLAYER_CONTROL_GAINED`, `VEHICLE_UPDATE`, etc.) automatically restore whitelist tracking upon landing or dismounting.

---

## 12.1.0 Combat Secrecy & Safety Compliance
- In combat context (`InCombatLockdown() == true`), returned Secret userdata must not be unwrapped, inspected, or compared using Lua operators (`<`, `>`, `==`).
- Secret values are passed directly to native Blizzard methods (`texture:SetTexture()`, `fontstring:SetText()`, `cooldown:SetCooldown()`).
- All helper function calls across files are dynamically referenced via `ns.Auras` to avoid nil upvalue dereferencing during module load.


