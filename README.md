# RoithiUI

A modular UI replacement for **World of Warcraft: Midnight (12.1.5)**. Built on native **Edit Mode**, RoithiUI provides a lightweight, module-first interface with ElvUI-inspired aesthetics and strict anchor logic.

**Latest Version:** v1.7.5  
**Last Updated:** 2026-10-14  
**Compatibility:** WoW 12.1.5 (Midnight) & WoW Forever (16001)

## 🆕 Recent Updates (v1.7.5)

* **Death Knight Rune Synchronization**: Resolved frame-rate jitter and slot displacement by maintaining consistent rune sort ordering across every render frame.
* **Rune Timer Sizing & Customization**: Increased default rune countdown timer font size to 14pt with new customizable font size controls in UnitFrames settings and Edit Mode.
* **Client Keybinding Probe Fix**: Added root `Bindings.xml` manifest to cleanly resolve engine-level `Couldn't open RoithiUI-Dev/Bindings.xml` Lua warnings.

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
