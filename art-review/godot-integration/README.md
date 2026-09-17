# Godot cartoon asset integration

Open the project in Godot 4.7 and press F5. The main scene is `res://scenes/main.tscn`.

## Saved asset scenes

Every one of the 49 imported GLBs is wrapped in its own saved `.tscn`:

- `scenes/tanks/`: 8 articulated tanks, with a CharacterBody3D root.
- `scenes/arena/`: 17 floors, pits, walls, and perimeter modules.
- `scenes/props/`: 8 props, mine, shells, and spawn marker.
- `scenes/wrecks/`: 16 separate hull/turret wrecks.

Drag these `.tscn` files into maps. GLBs under `assets/models/` remain their mesh dependencies. `assets/scene_manifest.json` lists the individual scenes and their collision counts; `assets/approved_asset_manifest.json` records source hashes and provenance. Assets use meters, Y up, tank forward +Z. Floors sit at Y=0; floor thickness extends below the pivot.

Static assets use their actual mesh triangles, preserving L-wall openings, wedges, and space between separate parts. Tanks use compound convex movement shapes around the hull and track bodies. Turrets and barrels have separate mesh-derived hit areas that follow aim and recoil. Moving tread details are cosmetic and stay within the track envelopes. The pit includes a separately named tank-only movement blocker across its opening; shell rays ignore that layer.

Physics layers: 1 scenery, 2 tank bodies, 3 pit movement blockers, 4 turret/barrel hitboxes. The detached turret's collision is disabled while it is thrown. Reusable shell/mine scenes include collision; the gameplay controllers disable it on their visual instances and use swept ray hits / timed radial mine checks instead.

## Test arena

WASD/arrows move; mouse aims; left click fires; Space drops a mine; R resets. Pick any tank in the selector. Start battle activates basic enemy movement and fire. Tanks and Pieces show galleries of the saved scenes. Show collision overlays the fitted shapes.

Runtime animation uses the approved Blender articulation: wheels rotate about their X axles, 14 tread links per side circulate around the correct path using distance traveled, differential tread speeds follow turns, and barrels recoil. Muzzle flashes, impacts, dust, explosions, smoke, and tossed wreck parts are implemented in Godot. These are interactive runtime animations, not exported copies of the Blender demo timeline.

This is an asset-integration sandbox, not the finished game. The six reviewed map concepts, outline rendering, destructible map walls, audio, progression, and finished enemy behavior are not included here.

## Validation and rebuild

`tests/integration.gd` exercises scene loading, 286 mesh/collider comparisons, openings, pit layers, tank movement against walls, wheel axes, track travel, firing, recoil, death, ricochets, mines, and reset. Run:

```sh
godot --headless --path . -- --integration-qa
godot --path . -- --integration-qa
```

The rendered run also captures the arena, tank gallery, collision overlay, pieces, close-up, explosion, and wreck under `previews/`. It records results in `validation.json` and exits with a nonzero status on failed checks. Test mode isolates synthetic movement and firing from normal mouse input.

`tools/export_approved_assets.py` re-exports the approved cartoon Blender sources. `tools/build_scenes.gd` builds the individual Godot scenes, test arena, and input settings. These overwrite generated assets/scenes; preserve manual edits before rebuilding:

```sh
blender --background --python tools/export_approved_assets.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/build_scenes.gd
```
