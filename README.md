# Tanks

A Godot toy-tank project with editable Blender artwork, animation studies, and six tabletop map concepts. **Pocket Armor** is the working name used in the art reviews.

## Current state

The approved cartoon tank kit is integrated into Godot with charcoal outlines visible in the editor and during play. The game starts at a centered cartoon main menu with chunky rounded buttons, dark blue panels, warm yellow accents, and portraits of the actual tank models. The tank picker, pause, settings, and result menus share the same visual theme. **Play → select a tank → Roll out** starts a match on a random one of the six **48 × 36 m arenas**, with one player and seven enemies. **Escape / Pause** freezes the match; Resume, Restart, and Back to start are connected. Actual match outcomes open win/loss screens, and Quit closes the desktop game. The diagnostic arena still supports **4, 6, or 8 tanks**. Each map has eight spawn points, collision, and obstacle-aware enemy routes. Tanks and Pieces galleries and a collision overlay remain available. Every imported asset has its own reusable `.tscn` scene: 8 tanks, 25 modular pieces, and 16 wreck parts.

The maps are Crossfire Court, Courtyard Keep, Canal Crossings, Switchback Works, Freight Exchange, and Crater Circuit.

## Open the project

1. Clone the repository.
2. Open `project.godot` in Godot. Its current feature version is **4.7**.
3. Let Godot rebuild its local import cache.
4. Press **F5** to run `scenes/main_menu.tscn`. Choose **Play**, select a tank, and choose **Roll out!**. The game picks a random arena, avoiding the previous arena for a new round.
5. Use **WASD/arrows** to move, **mouse** to aim, **left click** to fire, **Space** for a mine, and **Tab** for the camera. **Escape** or the pause button opens the pause menu. Restart keeps the same arena and tank. After victory, One more round picks a new arena.
6. Settings offers only master volume and editable key bindings, saved between launches. Select a control and press a key or mouse button to rebind it; Escape cancels, and Reset keys restores the defaults. Touch controls appear automatically on touch devices: use the move pad, touch the arena to aim, and tap Fire or Mine. Actual mobile-browser export testing is still required; the UI has been checked at phone and tablet viewport sizes.
7. For development tools, open `scenes/main.tscn` and press **F6**. Its Tanks/Pieces galleries, collision overlay, map selector, 4/6/8 tank setting, and practice mode remain available there. They are hidden in the normal game flow.

Desktop Quit closes the application. Browser builds show End session, unload the match, and offer a return to the menu; a browser page cannot normally close its own tab.

The art sources were authored in **Blender 5.1.1**. Open the relevant `.blend` file directly to inspect or edit the artwork. Each review folder has its own README with instructions and known limits.

| Location | Contents |
| --- | --- |
| `project.godot` | Godot project configuration |
| `scenes/main_menu.tscn` | Production game entry and menu flow |
| `scripts/game_flow.gd` | Random match loading, pause, results, settings, and quit |
| `assets/ui/` | Dark native menus, HUD, vector icons, and tank display |
| `scenes/main.tscn` | Playable arena and development galleries |
| `scenes/maps/` | Six large, editable map scenes with independent F6 previews |
| `scripts/battlefield.gd` | Spawn layout and navigation through solid scenery |
| `tools/import_outlines.gd` | Import-time outline geometry for GLB assets |
| `scenes/tanks/` | Eight tank scenes with movement collision and articulated hitboxes |
| `scenes/arena/`, `scenes/props/` | Modular asset scenes with mesh surface collision |
| `scenes/wrecks/` | Separate hull and turret wreck scenes |
| `assets/models/` | GLB source models referenced by the saved scenes |
| `assets/scene_manifest.json` | Complete asset-to-scene mapping and collision counts |
| `art-review/godot-integration/` | Import notes, validation report, and generated captures |
| `art-review/tank-kit-v1/` | Original modular tanks, scenery, textures, and staged GLB exports |
| `art-review/tank-animation-v2/` | Movement, aiming, firing, and destruction animation studies |
| `art-review/tank-cartoon-v3/` | Simplified cartoon tank source and animation revision |
| `art-review/map-concepts-v1/` | Original six map studies |
| `art-review/map-concepts-v2-outline/` | Map revision with charcoal outlines and clearer lighting |

`art-review/.gdignore` deliberately prevents Godot from importing the review workspace. Preserve it. Production GLBs live under `assets/models/`; their committed `.import` settings attach `tools/import_outlines.gd`. This adds small inverted hulls with a shared unlit charcoal material. Outlines follow the original parts, do not cast shadows, and are excluded from collision generation. Floor tiles and spawn markings are deliberately not outlined. Unlike the Blender Freestyle treatment, these outlines work in the Godot editor and at runtime.

See [the map scene guide](scenes/maps/README.md) for scene editing, hazards, rebuilding, and checks.

## What belongs in Git

Commit project configuration, code, scenes, editable Blender sources, runtime/source assets, GLB exports, textures, authoring scripts, manifests, and validation reports. Commit Godot's `*.import` sidecars and `*.uid` files too: these preserve import settings and resource identity. `export_presets.cfg` can be tracked for this Godot version; private export credentials must remain local.

The ignore rules exclude Godot caches, game builds, generated review images/videos and embedded HTML galleries, render logs, Blender numbered backups, Python caches, local environment files, and signing credentials. Ignored files remain on disk. Review screenshots and videos referenced by the individual READMEs are generated outputs and will not be present in a fresh clone.

Text files use LF line endings. Binary assets use normal Git with binary attributes; Git LFS is not required by this repository. If the source-asset collection grows substantially, agree on LFS tracking before committing those new large assets.

## Rebuild review outputs

Run authoring scripts through Blender's background mode. For example, from the repository root:

```sh
blender --background --python art-review/map-concepts-v1/build_maps.py
blender --background --python art-review/map-concepts-v2-outline/refine_style.py
```

On macOS, Blender's executable may be `/Applications/Blender.app/Contents/MacOS/Blender`. The map gallery scripts additionally use Python with Pillow installed. Rendering writes into each review folder; preserve manual `.blend` edits before rebuilding, since authoring scripts may overwrite their generated scene files. Some older video scripts contain local paths; check their configuration before running them on another machine.

## Commit and push

Review the changes and use your Git client to commit them, or run:

```sh
git status
git add .
git diff --cached --stat
git commit -m "Prepare Godot project for version control"
```

If no remote is configured, create an empty remote repository and add its URL:

```sh
git remote add origin YOUR_REPOSITORY_URL
git push -u origin main
```

The cleanup stops tracking generated files in new commits. Files from the original initial commit remain in Git history; ignore rules do not remove earlier committed data.

No open-source license has been selected for this project.

See Godot's [version-control guide](https://docs.godotengine.org/en/latest/tutorials/best_practices/version_control_systems.html) and [resource UID guidance](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/) for the upstream conventions behind these rules.
