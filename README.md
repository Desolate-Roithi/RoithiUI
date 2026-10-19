# RoithiUI

A modular UI replacement for **World of Warcraft: Midnight (12.1.5)**. Built on native **Edit Mode**, RoithiUI provides a lightweight, module-first interface with ElvUI-inspired aesthetics and strict anchor logic.

**Latest Version:** v2.0.4-Beta  
**Last Updated:** 2026-10-19  
**Compatibility:** WoW 12.1.5 (Midnight) & WoW Forever (16001)

## 🆕 Recent Updates (v2.0.4-Beta)

### 1. Bags & Vendor Auto-Repair Automation
* **Automated Equipment Repair**: Added automatic equipment repair when interacting with repair-capable merchants (`MERCHANT_SHOW`).
* **Personal vs. Guild Bank Funding**: Configurable funding source allowing players to draw repair funds from Personal Gold (`PLAYER`) or the Guild Bank (`GUILD`).
* **High-Cost Protection Guard**: Configurable warning threshold slider (1,000g – 50,000g, default 2,000g) with granular manual numeric input (`step = 1`, `bigStep = 500`). Repairs exceeding this threshold are safely skipped and reported in chat with the exact repair amount.
* **Guild Allowance Fallback Notification**: Added contextual chat notification when guild bank funds or daily withdrawal limits are exhausted and personal gold is charged as a fallback.

### 2. Modernized Chat & Bags Options Panels
* **Multi-Tab AceConfig Re-Architecture**: Converted Chat and Bags settings into clean, intuitive tabbed layouts (`childGroups = "tab"`), replacing deep vertical scrolling with dedicated category tabs.
* **Exposed Engine Controls**: Added missing UI controls for `showItemLevel` and `showFontShadow` within Bags settings.
* **Edit Mode & Coordinate Synchronization**: Harmonized coordinate fallbacks between Edit Mode integration, options controls, and default configurations.

### 3. Unified Typography Engine Integration
* **Centralized Font Application**: Routed all font rendering across Actionbars, Bags, Chat, EncounterBar, Minimap, and UnitFrames through `ns.Utils.ApplyTypography`.
* **Strict Shadow Decoupling**: Decoupled drop shadow rendering from font outlines, preventing unwanted shadows when outline is set to none unless shadow is explicitly checked.
* **Engine Flag Normalization**: Prevented C-engine font rasterization warnings by strictly normalizing outline flags to empty strings when none are selected.

### 4. Full Localization & Alphabetical Parity
* **Complete String Parity**: Maintained 100% key parity across all 992 localized entries between `Locales/enUS.lua` and `Locales/deDE.lua`.
* **Alphabetical Consistency**: Re-ordered all keys across 14 sections into strict alphabetical order for streamlined maintenance.

### 5. Castbar Lifecycle & Profile Switching Hardening
* **Eliminated Duplicate Castbars**: Enforced strict idempotency in `ns.InitializeBars()` and `ns.InitializeCastbarConfig()`, reusing existing statusbar frames and LibEditMode registrations rather than creating duplicate frames during profile transitions (`/rui dev`, sandbox test isolation, profile switching).
* **Native Module Lifecycle**: Implemented dedicated `Castbar:RefreshProfile()` and `Castbar:OnDisable()` handlers and registered `Castbar` in `MODULE_REFRESH_ORDER`, preventing fallback `OnEnable()` re-execution and event listener leakage.

## 📦 Previous Updates (v2.0.3-Beta)

### 1. Objective Tracker & UIWidget Zero-Touch Architecture
* **Native Widget Preservation**: Enforced 100% native Blizzard styling for all scenario widgets (Awakening the Machine, Delves, Visions). Pure container centering without modifying child widget frames, scales, or fonts, preventing global `UIWidgetManager` pool taint and secret arithmetic errors.
* **Full Multi-Criteria Visibility**: Restored native sequential criteria rendering and eliminated premature height clamping, ensuring all objective lines in Awakening the Machine / Delves display untruncated.
* **WorldMap & Pin Taint Isolation**: Replaced destructive `SetScript` on `block.HeaderButton` with non-destructive `HookScript`, preventing secure call stack contamination and eliminating `ADDON_ACTION_BLOCKED: SetPropagateMouseClicks` during `TOGGLEWORLDMAP`.

### 2. Minimap & AddonBar Taint Hardening
* **Weak-Keyed Button Isolation**: Replaced frame property mutations on minimap buttons with module-scoped weak-keyed lookup tables (`hookedButtons = setmetatable({}, { __mode = "k" })`).
* **Pure HookScript Event Handlers**: Replaced fallback `Minimap:SetScript` invocations with pure `Minimap:HookScript` to protect Blizzard's native frame scripts.

### 3. Test Suite & Static Automation Hardening
* **Empty Method & Dead Stub Audit**: Integrated `.agent/tools/empty_method_audit.py` into Pillar 1 to prevent empty functions or stubs from entering production.
* **Blizzard Frame Taint Audit**: Enhanced `.agent/tools/taint_safety_audit.py` to statically prohibit `SetScript` and direct table mutations on Blizzard frames.
* **Multi-Line Criteria Tests**: Expanded headless regression tests to validate multi-line scenario criteria rendering.

## 📦 Previous Updates (v2.0.2-Beta)

### Core & Release Fixes
* **Bindings.xml Manifest Resolution**: Removed redundant `Bindings.xml` reference from `RoithiUI.toc`, eliminating Blizzard C-engine `Unrecognized XML: Binding` warnings in the release build while preserving automatic keybinding registration.

### 1. UnitFrames
* **Midnight 12.1.0 Zero-Touch Secrecy**: Full combat-safe handling across all status tags (`issecretvalue` / `canaccessvalue`) with direct pass-through display to prevent secret string comparison crashes.
* **SegmentPool Lifecycle**: Direct acquire-and-anchor pool management for zero-allocation performance and restored visible unit frame tags.
* **Death Knight Rune Synchronization**: Resolved frame-rate jitter and slot displacement by maintaining consistent rune sort ordering across every render frame.
* **Rune Timer Sizing & Customization**: Increased default rune countdown timer font size to 14pt with new customizable font size controls in UnitFrames settings and Edit Mode.
* **PvP Indicator Alignment**: Cleanly aligned countdown timer text inward to the left of the PvP crest icon for player and right-aligned frames, eliminating clipping.
* **Aura Container Integration**: Full WoW 12.1 `AuraContainer` support with centralized growth direction and layout mathematics.

### 2. Castbars
* **Pure durationObj Pipeline**: Castbars and timers exclusively utilize native `durationObj` (`UnitCastingDuration`, `UnitChannelDuration`), eliminating secrecy violations, out-of-combat math hacks, and frame-rate drift.
* **Empowered Spell Stages**: Corrected Boss castbar event registration in 12.1.0 to eliminate unknown empower event errors.
* **Screen Clamping & Persistence**: Clamped castbars to screen boundaries to preserve positions across reloads and zone transitions.

### 3. CooldownManager (CDM)
* **Unified 2D Grid Support**: Upgraded Custom Bars to full multi-row grids with customizable icons per row, multi-row wrapping, and directional growth origins.
* **Scale-Corrected Edit Mode**: Corrected LibEditMode selection handle sizing to account for frame scaling.
* **Zero-Taint CooldownViewer**: Clean CooldownViewer integration eliminating taint vectors.
* **Centralized Anchoring**: Global settings inheritance and centralized anchor positioning.

### 4. Actionbars
* **Centralized Grid Mathematics**: Button coordinates and bar dimensions now consume `ns.Utils.GetGridDimensions` and `ns.Utils.GetGridItemOffset`.
* **Clickthrough & Safety**: Added clickthrough options, override actionbar safety, and micro button recursion protection.

### 5. Bags
* **Smart Retention Timer Transfer**: Moving newly acquired items across bag slots seamlessly transfers their ticking retention countdown and glow dismissal state without re-triggering highlight overlays.
* **Drag-and-Drop UX**: Added drop-in-same-slot handling and smooth drag-and-drop state preservation.
* **Font Offsets & Filtering**: Added customizable item level and stack count font offsets/sizes, a unified gear filter, and comprehensive category filtering.

### 6. Minimap & Addon Bar
* **Folio & Landing Button Separation**: Decoupled Omnium Folio and Expansion Landing buttons with independent Edit Mode placement, configurable drag movers, and coordinate click interactions.
* **Minimap Customization**: Rectangular and square minimap styling with interactive coordinate overlays.
* **Addon Compartment Bar**: Movable, expandable Addon Compartment bar with smooth button layout.
* **Tightened Attachment**: Reduced objective tracker attachment gaps for compact layouts.

### 7. Chat
* **C-Engine Layout Persistence**: Synchronized custom position, coordinates, and dimensions directly with Blizzard C-engine chat persistence (`SetChatWindowSavedDimensions`, `SetChatWindowSavedPosition`) and Edit Mode anchor info.
* **Tab Docking Architecture Fix**: Decoupled static docked tabs (`dock`) from dynamic tabs (`scrollChild`) to permanently prevent region dependency engine crashes.
* **Dynamic Font Propagation**: Full dynamic font size and tab font size propagation without requiring UI reloads.
* **Censored Message & Notice Formatting**: Clean notice formatting and censored message handling.

### 8. Objectives Tracker
* **Restyled Layout & Collapsible Quests**: Modern visual skinning with auto-collapse in combat/dungeons, hover-to-expand quest objectives, and individual quest pinning to maximize screen real estate.
* **Readable Contrast**: Permanent bright white styling prevents Blizzard's unhover pass from dimming objective text.
* **Zero-Taint Architecture**: Complete modularization into `Quests.lua`, `Scenario.lua`, and `Skinning.lua` without Blizzard frame table mutations.

### 9. EncounterBar
* **Zero-Taint Architecture**: Complete zero-touch isolation for scenario tracking and world power bar widgets.
* **Minigame Blacklisting**: Automatic UI suppression in specific minigames and scenarios (e.g., *Prop Hunt*, *Decor Duel*).
* **Ghost Bar Elimination**: Widget whitelist filtering and Unit Power Bar verification to eliminate phantom bars during encounters.

### 10. Menu (Micro Menu)
* **2D Grid Integration**: Unified container sizing and button placement via centralized grid math.
* **Portrait Inset & Recursion Guard**: Static portrait inset rendering and micro button recursion protection.
* **Backdrop Styling**: Seamless backdrop styling and custom positioning.

### 11. Totems
* **Combat-Safe Totem Tracking**: Totem bar tracking with secret aura safety and clickthrough options.
* **Totem Destruction**: Direct Blizzard totem destruction integration.
* **Category Configuration**: Configurable totem category ordering and button styling.

### 12. SwingTimer
* **Dual Swing Tracking**: Main-hand and off-hand swing timers with smooth animations.
* **Clickthrough Toggle**: Added clickthrough support for uninterrupted clicking.
* **Weapon Speed Detection**: Robust combat tracking and weapon speed change detection.

### 13. ProfileSharing
* **Profile Management Suite**: Seamless export, import, and sharing of UI layouts with real-time options engine sync.
* **Delta-Pruning & Float Snapping**: Zero-allocation delta-pruning and float snapping to prevent profile drift.

### 14. Core & Architecture
* **Unified 2D Grid Engine**: Centralized coordinate, dimension, and flow layout math in `Core/Utils.lua` consumed across all modules.
* **Midnight 12.1.0 Compliance**: Strict adherence to zero-touch combat secret rules and zero Blizzard frame table mutations.
* **100% Localization Parity**: Complete synchronization across 936 translation keys between German (`deDE`) and English (`enUS`).

## 🚀 Key Features

* **Edit Mode Native:** Move, scale, and snap all frames directly via Blizzard’s HUD Edit Mode.
* **Smart Anchoring:** Elements (Power, Class Power, Castbars) follow a strict hierarchy to ensure perfect alignment. Use "Detach" in settings to break the chain.
* **Modern API Support:** Full integration with 12.0.1 Heal Prediction, Secret Health/Power APIs, and Empowered Cast stages.
* **Zero-Overhead Debugging:** Detailed logging available for troubleshooting, with zero performance impact when disabled.

## 📦 Modules

### 1. UnitFrames
* Supports Player, Target, Focus, Pet, TargetTarget, FocusTarget, and Boss frames.
* Dynamic class colors and custom status bar textures via SharedMedia.
* Refactored aura management with WoW 12.1 `AuraContainer` support, whitelist/blacklist filtering, and custom mover anchors.
* Combat-safe health prediction, class power, additional power, and dynamic status tags.

### 2. Castbars
* Comprehensive support for Player, Target, Focus, Pet, and Boss castbars.
* Native Empowered Spell stages and channeling ticks using pure combat-safe `durationObj` pipelines.
* Smart anchoring hierarchy to unit frames with optional manual placement and Edit Mode integration.

### 3. CooldownManager (CDM)
* Custom 1D and 2D bars with configurable icons per row, multi-row wrapping, and directional growth origins.
* Zero-taint CooldownViewer architecture and global settings inheritance.
* Scale-corrected Edit Mode selection handles.

### 4. Actionbars
* Full 1D/2D grid engine integration with customizable columns, rows, and padding.
* Clickthrough options, override actionbar safety, and micro button layout management.

### 5. Bags
* Clean ElvUI-inspired all-in-one inventory and bank displays.
* Category filtering (Gear, Weapons, Consumables, Reagents, Quest, Junk, Favorites, New).
* Smart retention timers for newly looted items with seamless state transfer on slot moves.

### 6. Minimap & Addon Bar
* Rectangular and square minimap skinning with customizable coordinate overlays.
* Independent Omnium Folio and Expansion Landing buttons with dedicated Edit Mode anchors.
* Movable, expandable Addon Compartment bar.

### 7. Chat
* C-engine synchronized dimensions, positions, and user-placed persistence across reloads.
* Re-architected tab docking separating static and dynamic tab parentage to eliminate region dependency errors.
* Full dynamic font and tab font size propagation.

### 8. Objectives Tracker
* Modular architecture isolating quests, scenarios, and skins without Blizzard frame table mutations.
* Comprehensive typography hierarchy and permanent bright contrast unhover styling.

### 9. Totems & SwingTimer
* Combat-safe totem bar tracking with clickthrough options and Blizzard totem destroy integration.
* Main-hand and off-hand swing timers with smooth animations.

### 10. ProfileSharing & EncounterBar
* Complete profile management suite supporting seamless export, import, and sharing of UI layouts.
* Modular localized translations (`enUS`/`deDE` with 100% key parity).
* Scenario minigame suppression and world power bar tracking.

## 💻 Commands & Configuration

| Command | Description |
| :--- | :--- |
| `/rui` | Open free-flowing configuration window (or use Addon Compartment). |
| `/rui help` | Display list of available slash commands in chat. |
| `/rui <group>` | Open config directly to a module tab (e.g. `auras`, `actionbars`, `minimap`). |
| `/rui testsuite` | Open interactive In-Game Test Suite window (Pillar 2). |
| `/rui bliz` | Open native Blizzard Settings AddOn category. |
| `/rl` | Quick reload the UI. |
| **Edit Mode** | Enter via Game Menu to move and configure all frames. |

## 🛠️ Dependencies
* **LibSharedMedia-3.0**: Custom textures and fonts.
* **LibEditMode**: Powers the deep Edit Mode integration.
* **LibStub**: Core library management.
