# RoithiUI

**RoithiUI** is a modular, high-performance User Interface replacement for World of Warcraft: Midnight (Patch 12.0) Beta. It is designed to provide a clean, modern aesthetic similar to ElvUI but built on a lightweight, module-first architecture that heavily leverages the native WoW Edit Mode.

## Features

- **Modular Core**: Features are split into independent modules (UnitFrames, Castbars, etc.) for better performance and maintainability.
- **Edit Mode Integration**: All UI elements are fully integrated with Blizzard's Edit Mode ("HUD Edit Mode"). You can move, scale, and configure frames directly using the native tools.
- **SharedMedia Support**: Includes custom textures and fonts, and supports global SharedMedia libraries.
- **Modern Aesthetic**: Pixel-perfect borders, smooth status bars, and clean typography.

## Modules

### 1. UnitFrames
A complete replacement for Player, Target, and Focus frames.
- **Health & Power**: Custom status bars with class colors.
- **Heal Prediction**: Supports the new 12.0 Heal Prediction APIs for accurate incoming heal visuals.
- **Buffs/Debuffs**: Integrated aura handling.

### 2. Castbars
A robust castbar module supporting all major units.
- **Supported Units**: Player, Target, Focus, Pet, Target of Target, Focus Target.
- **Empowered Spells**: Native support for Evoker/modern empowered cast stages.
- **Channeling**: Supports ticks and precise channel timing.
- **Configuration**: Fully configurable via Edit Mode (Settings dialog attached to the frame).

## Installation

1. Download the `RoithiUI` folder.
2. Place it in your `World of Warcraft/_beta_/Interface/AddOns/` directory.
3. Launch the game.

## Configuration

RoithiUI uses a "Zero-Config" philosophy where possible, relying on logical defaults. However, customization is easy:

1. **Enter Edit Mode**: Right-click your unit frame or open the Game Menu -> Edit Mode.
2. **Select a Frame**: Click on any RoithiUI frame (e.g., "Roithi Player Frame", "Midnight Player Bar") to select it.
3. **Adjust Settings**: A settings dialog will appear (courtesy of `LibEditMode`) allowing you to adjust Width, Height, Position, Colors, and more.
4. **Global Toggle**: A generic "Midnight Castbars" menu usually appears in Edit Mode to toggle individual bar visibility.

## Slash Commands

- `/rl` - Reload UI (if using standard Dev tools)
- `/mcb` - Shortcut to open Edit Mode (Castbar specific alias)

## Libraries Used

- **LibStub** & **CallbackHandler-1.0**
- **LibSharedMedia-3.0**
- **LibEditMode**: Powering the in-game configuration UI.

---
*Created for the WoW Agentic Coding Initiative.*
