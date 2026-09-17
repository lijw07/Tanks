# Minimal cinematic main menu

Native Godot main-menu redesign using the existing Crossfire Court arena and tank models. The camera drifts slowly behind a dark gradient, with simple text controls and a slim focus marker.

Run the main project to review it. Play still opens the eight-tank selection and launches a random arena. This pass changes the home scene only; the other menus keep their functional existing styles pending feedback on the visual direction.

The graphical game-flow run passed 97 checks with no failures. Captures cover 1280×800 desktop, 390×844 phone, 820×1180 tablet, 844×390 landscape, and 320×568 small phone. These are native window renders, not physical-device or browser-export tests.

The previous home source is preserved in `../main-menu-v1/previous-home/` for comparison. `validation.json` records the current run; `previews/01-main-menu.png` shows the new desktop menu.
