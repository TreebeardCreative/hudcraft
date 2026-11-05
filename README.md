# hudcraft

hudcraft is a lightweight, customizable information HUD for World of Warcraft: Forever. It works alongside the player's existing interface and is intended to provide compact information groups and individual HUD displays without replacing the rest of the UI.

## Development status

Version `0.1.1` is the first tracked foundation for the ground-up Forever rebuild. It uses the current Forever addon base and is an early development build, not a public release. The rebuild is catching up with the established behavior of hudcraft `1.0.0`; the planned first complete release of this line is `1.1.0` after that scope is restored and the new improvements are ready.

## Project direction

The intended addon lets players create, name, arrange, and position compact HUD groups, choose the information each group displays, and configure horizontal or vertical layouts, module order, separators, and text alignment. Planned information includes character level and class, experience, gold, bag space, durability, clock, performance, weapon skills, and professions. Groups and settings remain focused on information display and configuration; hudcraft is not a full UI replacement.

The current foundation includes the addon bootstrap, saved-setting defaults, output and settings windows, a group display, and initial Bags, Clock, Experience, Level, and Performance modules. These source files mark the starting implementation; their presence does not mean the full intended feature set is complete.

## TreebeardUI

This build uses TreebeardUI as a separate addon dependency (API 1) for reusable windows, controls, and layout. hudcraft owns its HUD content, setting meanings, saved values, actions, and appearance choices. TreebeardUI is not embedded in this repository.

## Repository layout

```text
HUDCraft.toc                 Forever manifest and addon load order
Bootstrap.lua                Addon namespace and TreebeardUI compatibility check
Main.lua                     Initialization, saved settings, and commands
Core/                        Defaults and output behavior
Groups/                      HUD group construction and layout
Modules/                     Information providers
UI/Settings/                 Settings window
UI/Output/                   Diagnostic output window
```

The game installs the addon in a folder named `HUDCraft`. Development and public-facing branding use lowercase `hudcraft`.

## License

This project is available under the MIT License. See [LICENSE](LICENSE).
