# Pocket Armor production UI

The game entry point is `scenes/main_menu.tscn`, controlled by `scripts/game_flow.gd`. These UI scenes are integrated into real gameplay, outside the excluded art-review directory.

- Home centers Play, Settings, and Quit beneath a chunky rounded title. A faceted dark blue backdrop and actual tank portraits match the game models. The reusable theme supplies outlined, rounded controls to tank selection, pause, settings, HUD, and results.
- Play opens the eight-tank selection scene with portraits rendered from the actual game models and a gently rotating 3D selected-tank preview. Its statistics come from `ToyTank.player_stats()`; health, damage, and firing interval share the constants used by gameplay.
- Roll out selects a random scene from `MapCatalog`. A new round avoids the immediately previous map. Restart keeps the map and selected tank.
- The battlefield HUD uses just a bullet icon and mine icon for weapon readiness, plus pause and touch movement. The icons empty when used and fill upward with gold from the actual cooldown timers. There is no health panel, tank counter, ammo amount, weapon label, separate progress bar, or reload timer text.
- Pause uses `SceneTree.paused`; the delayed Duelist shot and wreck cleanup timers honor it.
- Actual player death and enemy defeats select the result scenes and supply real results.
- The application pauses when it loses focus during battle.
- Desktop Quit closes the application. The Web branch ends the session without attempting to close the host tab. That branch needs an actual browser-export test before release.

The root viewport uses its actual dimensions for UI reflow; containers, scrolling, and fixed-size touch targets handle narrow and short windows. Phone/tablet layouts are verified by native renders, not physical device testing. To preview one reusable menu in the editor, open its `.tscn` file.

`tests/game_flow.gd` checks connected menu/game transitions and saves rendered captures to `art-review/main-menu-v1/previews/`. `tests/quit_button.gd` verifies the Quit button exits. `tests/maps.gd` checks all six map scenes and gameplay paths.

Pass `-- --capture-dir=res://art-review/cartoon-menu-v2/` to the game-flow test for current review captures. Short phones omit the large hero preview to retain all eight tank choices, live stats, and the Roll out action onscreen. Landscape phones use a single row of eight tank choices.

`tools/render_ui_portraits.gd` regenerates the eight transparent model portraits; `tank_portrait.gd` renders the selected tank live. Home uses static portraits to avoid rendering an entire arena behind menu controls. The rounded Fredoka font comes from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/fredoka), with its redistribution license in `fonts/OFL.txt`.

Settings contains Volume and Key bindings only. Rebinding supports movement, fire, mine, camera, and pause; conflicts are rejected, Escape cancels capture, and Reset keys restores defaults. Volume and bindings persist in user settings. Touch controls enable automatically on touch devices. Menu hover turns the pointed-at button yellow and transfers its focus outline; leaving clears it, with keyboard navigation still available.

`tests/menu_hover_settings.gd` validates real pointer hover, key capture/cancellation/conflicts, config persistence, volume, gameplay rebinding, camera/pause, reset, and compact settings layouts. Its test run restores the prior user settings file.

The aim reticle is drawn in screen coordinates from the same pointer events used for aiming, avoiding the old tank-height/floor-height offset. It hides over UI, while paused, and while spectating, and restores the menu cursor. `tests/hud_feedback.gd` checks meter timing and pause/resume, clickable controls, viewport bounds, crosshair/aim alignment in both camera views, and spectator compatibility. Captures live in `art-review/hud-icons-v2/previews/`.
