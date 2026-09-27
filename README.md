# RoithiUI

A modular UI replacement for **World of Warcraft: Midnight (12.1)**. Built on native **Edit Mode**, RoithiUI provides a lightweight, module-first interface with ElvUI-inspired aesthetics and strict anchor logic.

**Latest Version:** v1.7.3  
**Last Updated:** 2026-09-27  
**Compatibility:** WoW 12.1.0 (Midnight) & WoW Forever (16001)

## 🆕 Recent Updates (v1.7.3)

* **Castbar Screen Clamping & Boundary Enforcement**: Implemented coordinate sanitization and screen clamping across all castbars and attachment states. Bars can no longer drift or spawn off-screen, taking spell icon offsets and UI scale into account.
* **Anchor & Reload Stability**: Resolved module load order race where castbars initialized before unit frames, eliminating issues where unmoved bars shifted or detached on `/reload`. Attached castbars now maintain hierarchy and re-anchor seamlessly upon unit frame creation.
* **Edit Mode Coordinate Normalization**: Fixed parent re-anchoring in Edit Mode to prevent screen coordinate inflation and double UI scale division when toggling detached state.
* **Combat & Secret Timing Robustness**: Added pushback event listeners (`UNIT_SPELLCAST_DELAYED`, `UNIT_SPELLCAST_CHANNEL_UPDATE`) and hardened secret duration handling against arithmetic operations in combat.

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

### 3. EncounterBar
* Modular tracking for scenario objectives and world bar widgets (e.g. Oxygen bar).
* Keyword blacklisting for automatic UI suppression in specific minigames/scenarios (e.g. *Prop Hunt*, *Decor Duel*).
* Widget whitelist filtering and Unit Power Bar verification to eliminate ghost bars during encounters.
* Fully movable and scalable via native Blizzard Edit Mode.

### 4. ProfileSharing
* Complete profile management suite supporting seamless export, import, and sharing of UI layouts.
* Modular localized translations (`enUS`/`deDE`).
* Real-time synchronization with options engine and Edit Mode configurations.

## 💻 Commands & Configuration

| Command | Description |
| :--- | :--- |
| `/rui` | Open RoithiUI Options (or use Addon Compartment). |
| `/rl` | Quick reload the UI. |
| **Edit Mode** | Enter via Game Menu to move and configure all frames. |

## 🛠️ Dependencies
* **LibSharedMedia-3.0**: Custom textures and fonts.
* **LibEditMode**: Powers the deep Edit Mode integration.
* **LibStub**: Core library management.
