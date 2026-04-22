# RoithiUI

A modular UI replacement for **World of Warcraft: Midnight (12.0)**. Built on native **Edit Mode**, RoithiUI provides a lightweight, module-first interface with ElvUI-inspired aesthetics and strict anchor logic.

**Latest Version:** v1.3.0  
**Last Updated:** 2026-04-22  
**Compatibility:** WoW 12.0.1 (Midnight)

## 🆕 Recent Updates (v1.3.0)

* **Vehicle UI Stabilization**: Resolved persistent race conditions during vehicle entry/exit. Units now correctly display names, health, and power values immediately upon transition.
* **Encounter Bar Module**: A new modular bar for world widgets (Oxygen, Scenario Progress, etc.). Fully integrated with **Edit Mode** for custom positioning and scaling.
* **Scenario Blacklisting**: Intelligent automatic suppression of the UI in specific scenarios like *Prop Hunt*, *Hide and Seek*, and *Decor Duel* to keep the screen clutter-free.
* **Secure Visibility Management**: Refactored Blizzard frame hiding logic to be more resilient against 12.0.1 "Secret" value taint.

## 🚀 Key Features

* **Edit Mode Native:** Move, scale, and snap all frames directly via Blizzard’s HUD Edit Mode.
* **Smart Anchoring:** Elements (Power, Class Power, Castbars) follow a strict hierarchy to ensure perfect alignment. Use "Detach" in settings to break the chain.
* **Modern API Support:** Full integration with 12.0.1 Heal Prediction, Secret Health/Power APIs, and Empowered Cast stages.
* **Zero-Overhead Debugging:** Detailed logging available for troubleshooting, with zero performance impact when disabled.

## 📦 Modules

### 1. UnitFrames
* Supports Player, Target, Focus, Pet, and Boss frames.
* Dynamic class colors and custom status bar textures via SharedMedia.
* Integrated aura handling with whitelist/blacklist support.

### 2. Castbars
* Support for all major units including TargetTarget and FocusTarget.
* Native Empowered Spell stages and channeling ticks.
* Smart anchoring to unit frames with optional manual placement.

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
