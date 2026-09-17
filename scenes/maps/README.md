# Large map collection

Six separate Godot scenes expand the approved tabletop concepts into **48 × 36 m** battlefields. Each has **eight spawn markers** and supports the game's **4, 6, or 8 total tank** selections. The current controller is one player plus AI; these maps do not implement online or local multiplayer.

| Scene | Layout |
| --- | --- |
| `01_crossfire_court.tscn` | Broad lanes, staggered walls, open outer flanks |
| `02_courtyard_keep.tscn` | Four gates and an enclosed central courtyard |
| `03_canal_crossings.tscn` | Three 5 m wide bridges across an 8 m canal |
| `04_switchback_works.tscn` | Offset long partitions with wide routes around their ends |
| `05_freight_exchange.tscn` | Cargo containers and connected service lanes |
| `06_crater_circuit.tscn` | A 12 m central crater and a wide surrounding route |

Press **F5** for the map selector and combat. Choose a map, tank type, and total tank count. Practice mode keeps targets stationary; Start battle activates AI. **Tab** or **Follow tank** changes between an overview and close play. Reset clears the current round and uses the selected map's spawn points.

Open any individual `.tscn` and press **F6** for its standalone static preview. `Geometry` contains editable map pieces; `Spawns` contains the starting transforms; `Preview` contains display tanks, a camera, and lighting. The main game removes `Preview` when it instantiates a map, then supplies its own tanks and shared lighting.

The canal and crater block tank movement on physics layer 3, while allowing shells to pass above them. Bridge decks are flush with the play surface to match the existing horizontal tank controller. The central courtyard emblem is visual, not a capture-point game mode. Cargo shells use box collision; reusable kit pieces retain their mesh-derived collision. Added outline meshes are visual only.

Navigation is built from the map's actual physics shapes on a 2 m grid with clearance for the large tanks. This is basic route-following AI; it does not add squad tactics or coordinated traffic avoidance.

## Rebuild and verify

From the repository root, with Godot on the command path:

```sh
godot --headless --path . --script tools/build_maps.gd
godot --path . --script tests/maps.gd
```

The builder overwrites the six map scene files. Preserve manual scene edits before rebuilding. The map check verifies spawn clearance, connected routes, hazard blockers, 4/6/8 tank populations, follow-camera zoom, mine bounds, AI movement, and four-tank victory handling. It also writes actual game renders into `art-review/large-maps-v1/previews/` and a report into `art-review/large-maps-v1/validation.json`. Add `--headless` to skip captures.

Source artwork and the original smaller Blender concepts are preserved. Godot imports regenerate outlines from `tools/import_outlines.gd`; existing `.glb.import` files must stay committed. When adding a new model, assign that script in its Import settings before using it in a map.
