# Pocket Armor — Godot UI asset kit

A dark-mode native Godot UI kit for the toy-tank game. Open **this folder's `project.godot`** in Godot 4.7 and run it. This is an isolated art-review project. The kit has not been integrated into the main Tanks game.

## Included

- Start menu: Play, Settings, How to play.
- Tank selection: all eight tank badges, selected state, descriptions, gameplay-derived stats, Back, Roll out.
- Battle HUD: player/tank label, armor, target progress, firing readiness, pause, fire, mine, movement control.
- Pause: Resume, Settings, Restart, Back to start.
- Victory and defeat: separate art/layouts, result values, retry, return to start.
- Settings: music, sound effects, volume, reduced-motion state.
- 70 editable SVG assets: 30 icons, 31 surfaces, 8 tank badges, 1 brand mark.
- Shared native Godot Theme, color/spacing tokens, asset manifest, and layout validation.

There is no screen-switcher bar in the game view. Play leads to tank selection, Roll out opens the HUD, and Pause opens the menu. Inspect other screens directly in Godot or launch the review with `-- --screen=Win` (also `Loss`, `Settings`, `Pause`, `Tanks`, `HUD`, or `Start`). Menus scroll vertically when needed; the HUD stays in the viewport.

## Files

| File | Purpose |
| --- | --- |
| `scenes/start_menu.tscn` | Start screen |
| `scenes/tank_selection.tscn` | Responsive garage |
| `scenes/battle_hud.tscn` | In-game overlay |
| `scenes/pause_menu.tscn` | Pause overlay |
| `scenes/win_screen.tscn` | Victory overlay |
| `scenes/loss_screen.tscn` | Defeat overlay |
| `scenes/settings_menu.tscn` | Settings overlay |
| `scenes/ui_review.tscn` | Standalone review harness |
| `themes/pocket_armor.tres` | Native scalable styling and button states |
| `icons/`, `surfaces/`, `badges/` | Editable SVG assets |
| `tokens.json` | Palette, spacing, type, and target sizes |
| `manifest.json` | Asset inventory and nine-slice margins |
| `validation.json` | Actual size/flow check results |
| `previews/` | Godot-rendered review screenshots; generated and ignored by Git |

## Resizing

The review uses actual viewport dimensions so layouts can reflow. It does not shrink a desktop menu onto a phone. Menu buttons have a 56 px minimum height, reducing to 48 px in short landscape windows. The tank grid changes between eight, four, and two columns. Longer screens use ScrollContainer. Shared StyleBoxFlat surfaces preserve border and corner sizes; labels remain live Godot text.

SVG sources scale without loss. Godot rasterizes their imports, so this review sets SVG import scale to 4 for the displayed icon and badge sizes. Reimport at a suitable scale if a future game uses much larger portraits. Panels and buttons use native style boxes instead of stretching raster corners.

Menus, tank selection, and HUD expose `safe_area_insets` (left, top, right, bottom) for the hosting platform to supply. A future browser export must pass safe-area/canvas size changes into the game; that platform bridge is not part of this asset kit. Actual iOS/Android/Safari export testing remains a later integration step.

## Connecting to gameplay after visual approval

Keep the kit's `scenes`, `scripts`, `themes`, `icons`, `surfaces`, `badges`, `brand-mark.svg`, and `reference` folders together. Scene and runtime asset references are relative so the kit can live under a game asset directory. The isolated `project.godot`, review harness, validation script, and preview images do not need to ship.

Reusable menus emit `action_requested(action: String)`. The game controller should respond to Play, Resume, Restart, Settings, and Main Menu, and own actual pausing and scene transitions. Menu controls run while the tree is paused. The review demonstrates the transitions without pausing a live game.

Tank selection emits `tank_selected(tank_id: String)` and stores `selected_index`. Connect this to a gameplay tank definition; the displayed values come from the current playable tank scenes in `tank_stats.json`. This is a measured snapshot, not a new balance design. The badges are UI symbols inspired by the existing tank colors, not replacement 3D models.

HUD emits `action_requested` for pause/fire/mine and `movement_changed(Vector2)` for the thumb control. Feed live data with `set_health`, `set_fire_ready`, and `set_targets`. Optional `set_ammo` and `set_round` helpers remain for future modes, but the current preview uses unlimited shells and cooldowns. Use `set_results(tanks_tagged, hull_hp, max_hp)` for win/loss values. Direction, aiming, combat, audio, persistent settings, and actual wins/losses remain the game's responsibility. The backdrop is a copied existing arena render, not a playable world.

## Validate / regenerate

Run `scripts/validate_ui.gd` with Godot's `--script` option from this review project. It checks seven screens across 1280×800, 820×1180, 390×844, 844×390, and 320×568; it also checks the start → tank selection → HUD → pause → settings flow and all eight selections. A graphical run captures native rendered PNGs. A headless run checks layouts and signals only.

The `.tscn`, `.gd`, and `.tres` files are the editable sources. `build_assets.py` regenerates the SVGs and basic token/inventory files; the native scenes are maintained directly.

Responsive integration reference: [Godot multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html). Touch target reference: [W3C target sizes](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html). The 48–56 px button heights are this kit's design choice.

## Accurate tank statistics

Run `tools/sync_ui_stats.gd` from the main Tanks project using Godot's `--script` option before validating or shipping an updated kit. It instantiates all eight actual tank scenes as player-controlled tanks, reads their movement speeds and hit points, applies a hit, fires a volley, and measures the fire interval and shell count. It saves the results and source hashes in `tank_stats.json`; it does not change gameplay balance. The UI imports that JSON resource and displays the same values for every tank selection.

Every current player tank has **3 HP** and shells deal **1 HP**. Speeds vary by tank. Orange Mortar fires every **0.98 s**; the other tanks fire every **0.70 s**. Ivory Duelist fires **two shells per trigger**. The existing player/enemy health distinction is preserved. The earlier 1–10 ratings and claims of extra armor/firepower have been removed.
