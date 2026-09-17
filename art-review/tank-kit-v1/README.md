# Pocket Armor — Blender review kit

Original toy-tank models and a modular tabletop arena inspired by **Tanks! in Wii Play**.

**Review only. Nothing has been imported into Godot.** The parent `art-review/.gdignore` excludes this entire folder from Godot's importer. Keep that file in place until visual approval and a separate integration step.

## Open and review

Open `Pocket_Armor_Review.blend` in Blender. Choose among these scenes from the scene selector:

1. **01 | ASSEMBLED ARENA** — wooden tabletop arena populated with all eight tanks.
2. **02 | TANK LINEUP** — individual tank silhouettes, colors, and sizes.
3. **03 | MODULAR ARENA KIT** — the complete collection of 25 reusable modules.
4. **04 | TOP DOWN LAYOUT** — overhead view for judging readability and arena arrangement.

Rendered PNGs are in `previews/`. Every placed tank and module is a collection instance of its reusable source. This allows pieces to be rearranged without duplicating their source geometry. Use Blender's collection instance workflow to place additional pieces; edit the source collection to change all instances.

## Tanks

| Tank | Hull width | Design |
|---|---:|---|
| Azure Scout | 1.12 m | Light chassis, rounded turret |
| Mint Cruiser | 1.40 m | Medium chassis, hexagonal turret |
| Vermilion Bulldog | 1.78 m | Wide heavy chassis, armored rectangular turret |
| Saffron Sprinter | 1.02 m | Small, short chassis and compact cannon |
| Violet Needle | 1.22 m | Narrow chassis and long marksman barrel |
| Ivory Duelist | 1.48 m | Two barrels with separate recoil parents |
| Tangerine Mortar | 1.70 m | Large siege chassis, wide short barrel |
| Slate Command | 1.56 m | Faceted turret and antenna |

Each tank includes `Hull`, `TurretPivot`, one or two `BarrelRecoil` parents, and `Muzzle` markers. Treads, wheels, guards, hatch, lamps, and body panels remain editable meshes. The pivot hierarchy is prepared for animation; this review includes static models, not authored animation clips or gameplay.

## Modular arena pieces

- Beech walls: 1 m, 2 m, 4 m, low wall, tall pillar, L corner, T junction, round pillar, and diagonal wedge.
- Terracotta walls: single block and two-course 2 m wall.
- Steel barrier with yellow edge markings.
- Maple and sand floor tiles, a recessed pit, perimeter rail, and corner post.
- Crate, paired drums, striped barricade, and rubble cluster.
- Mine, standard shell, rocket, and spawn marker.

## Scale and future engine handoff

- One Blender unit equals one meter. Most placement uses a **1 m grid**; floor tiles are **2 × 2 m**.
- Tank asset roots sit on the ground under the hull center. Solid modules use bottom-center roots. Floor tiles have their walkable surface at Z = 0; a pit replaces a floor tile and extends below that plane.
- Blender uses Z up and tank forward −Y. The GLB exports convert to Y up and tank forward +Z. Account for this forward axis when implementing movement later.
- `exports/` contains one self-contained GLB per asset, with embedded PBR materials and the wood texture. These are staged exports only, not imported Godot resources.
- Material colors can be edited independently. The 256 × 256 beech texture is packed in the Blender source and embedded into relevant GLBs.
- Collisions, navigation, damage states, effects, animation clips, and Godot scenes/scripts are intentionally deferred until the user approves the visual direction.

## Provenance and verification

All meshes and the wood grain texture were generated locally in Blender for this request. No Nintendo models, extracted textures, downloaded asset packs, or paid generation services were used. The game reference is visual inspiration only. No third-party asset license is attached; no legal determination is made about protection of generated work or the referenced game's branding.

`manifest.json` records the original request, constraints, asset dimensions, source triangle counts, and export hashes. `validation.json` records independent inspection of the GLB bytes and hierarchy. This is a review bundle, not a verified canonical package from the optional `game-dev` utility, which was unavailable in this environment. Blender export and static file checks do not constitute a Godot import or gameplay validation.

`build_tank_kit.py` is the reproducible authoring source. Re-running it overwrites the generated files in this review folder, so preserve any manual Blender edits before rebuilding.
