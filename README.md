# RoithiUI

**RoithiUI** is a modular, User Interface replacement for **World of Warcraft: Midnight (Patch 12.0)**. It is designed to provide a clean, ElvUI-like lightweight, module-first UI that uses native **WoW Edit Mode**.

## Features

- **Modular Core**: Functionality is split into independent modules (UnitFrames, Castbars, etc.)
- **Edit Mode Integration**: All UI elements are fully integrated with Blizzard's "HUD Edit Mode". You can move, scale, and configure frames directly using native tools.
- **Strict Attachment Logic**: Unit frame elements (Power, Class Power, Additional Power, Castbar) follow a strict hierarchy to ensure they snap together perfectly.
  - *Hierarchy*: UnitFrame -> Power -> ClassPower -> AdditionalPower -> Castbar.
  - *Drag Lock*: Attached elements remain locked to their parent to prevent accidental misalignment. To move them, simply "Detach" them in the settings.
- **SharedMedia Support**: Includes custom textures and fonts, and supports global SharedMedia libraries.

## Modules

### 1. UnitFrames
A complete replacement for Player, Target, Focus, Pet, and Boss frames.
- **Health & Power**: Custom status bars with dynamic class colors.
- **Additional Power**: Native support for Mana on Druids/Shamans/Priests when in specific forms.
- **Heal Prediction**: Supports the new 12.0 Heal Prediction APIs for accurate incoming heal/absorb visuals.
- **Buffs/Debuffs**: Integrated aura handling with whitelist/blacklist support.

### 2. Castbars
A robust castbar module supporting all major units.
- **Supported Units**: Player, Target, Focus, Pet, TargetTarget, FocusTarget.
- **Empowered Spells**: Native support for Evoker and modern empowered cast stages.
- **Channeling**: Supports ticks and precise channel timing.
- **Smart Anchoring**: Automatically anchors to the UnitFrame stack but can be detached and placed anywhere.

## Configuration

Customization is fully supported via **Edit Mode**.

### How to Customize
1.  **Enter Edit Mode**: Open the Game Menu -> Edit Mode (or right-click a unit frame).
2.  **Select a Frame**: Click on any RoithiUI element (e.g., "Roithi Player Frame", "Player Castbar").
3.  **Adjust Settings**: A configuration window will appear, allowing you to:
    -   **Detach/Attach**: Break the dependency chain to move elements freely.
    -   **Size & Scale**: Adjust width and height.
    -   **Colors**: Customize bar colors.

### Debug Mode
If you encounter issues, you can enable **Debug Mode** to see detailed logs in the chat.
-   Go to `RoithiUI Options` (via Addon Compartment or `/rui`).
-   Toggle **Debug Mode** in the General settings.
-    *Note: Logs are zero-overhead when disabled.*

## Slash Commands

- `/rl` - Reload UI
- `/rui` - Open Options Panel

## Libraries

- **LibStub** & **CallbackHandler-1.0**
- **LibSharedMedia-3.0**
- **LibEditMode**: Powering the in-game configuration UI.

---
*Created for the WoW Agentic Coding Initiative.*
