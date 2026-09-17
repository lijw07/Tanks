# Pocket Armor — animation and effects review

Open **Pocket_Armor_Animation_Review.blend** in Blender. This is a separate animated review file; the approved static kit remains in `../tank-kit-v1/`.

## Watch and test

- The file opens on the Azure Scout close-up. Place your pointer over the 3D view and press **Space** to play or pause.
- Drag the timeline playhead to inspect any moment. Timeline markers label the major events.
- Use the top scene selector for **01 | ALL TANKS - ANIMATION TEST**, or one of the eight individual tank scenes.
- Playback is 24 fps over frames 1–336, a 14-second loop. Blender's frame-dropping playback mode preserves timing if the preview cannot draw every frame.
- The rendered video in `previews/` provides smooth playback without depending on live viewport performance.
- To see the editable parts and animation controls, toggle overlays with **Shift–Alt–Z**. Expand the tank's `ANIMATED` collection in the Outliner to select its hull, turret, barrel, tread links, or effect objects.

| Frames | Event |
|---|---|
| 1–72 | Forward travel, circulating treads, rotating wheels, suspension motion, track dust |
| 73–108 | Differential pivot turn |
| 109–151 | Independent turret aim |
| 156 and 192 | Two firing events: recoil, muzzle flash/smoke, shell streak, impact sparks/smoke |
| 160 and 196 | Ivory Duelist's second barrel fires |
| 240–277 | Death explosion, shock ring, flying armor, detached turret |
| 278–325 | Charred wreck, rising smoke, residual embers |
| 326–336 | Wreck clears and tank resets |

## Included

All eight tanks have authored movement, aiming, firing, destruction, and reset animation. Treads follow a continuous path around their wheels rather than sliding across the top. Firing effects follow each barrel's muzzle marker. Death leaves a separate scorched hull and thrown turret.

Animations and effects use editable Blender objects and keyframes. No physics simulation cache, external plugin, or background Python handler is required to play or scrub the saved file. Effects use mesh animation so they remain visible in material preview as well as in renders.

This is a **choreographed art test**, not playable combat. Sound effects and an interactive controller are not included. Godot animation clips, particles, collision, damage, and gameplay integration remain pending approval. The parent `art-review/.gdignore` continues to exclude the entire review area from Godot.

`animation_manifest.json` describes the authored content. `validation.json` records checks of the saved animation data. `build_animation_review.py` is the reproducible authoring source; re-running it overwrites generated files in this v2 folder.
