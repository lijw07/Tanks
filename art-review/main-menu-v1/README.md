# Integrated main menu

Run the main Tanks project with F5. Its entry scene is now `scenes/main_menu.tscn`.

The UI lives under `assets/ui/` and operates the actual game. This folder only contains generated captures and validation reports. There is no separate review navigation bar.

Checks cover Play → tank selection → random arena, real HUD values, pause/resume, paused firing timers, settings return, restart, actual victory/defeat, returning to the main menu, and Quit. Rendered responsive checks cover desktop, phone, tablet, and short landscape sizes.
