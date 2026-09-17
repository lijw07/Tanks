# Pocket Armor — map concept collection

Open **Pocket_Armor_Map_Concepts.blend** and use Blender's scene selector to switch between six editable map concepts. The file opens on Crossfire Court. All boards have a 24 × 18 m play area and use the project's original toy-tank kit.

| Scene | Map idea | Intended combat pattern |
|---|---|---|
| 01 Crossfire Court | Open wooden arena with offset walls | Three lanes, short flanking routes, readable cover |
| 02 Courtyard Keep | Four entrances around a fortified courtyard | Fight for the center or rotate around the outside |
| 03 Canal Crossings | Turquoise canal with three wooden bridges | Commit to exposed crossings and defend either bank |
| 04 Switchback Works | Alternating long walls and corner pockets | Ambushes, route prediction, and close encounters |
| 05 Freight Exchange | Corrugated cargo containers in a service yard | Staggered sightlines, broad side lanes, potential ricochets |
| 06 Crater Circuit | Sandy arena around a dark central hazard | Circular movement, broken cover, and pursuit |

Each scene includes **01 Presentation camera** and **02 Overhead layout camera**. Select a camera in the Outliner and use **Ctrl–Numpad 0** to make it active. **Numpad 0** enters or leaves camera view. Turn viewport overlays on to select and move pieces visually. Existing tank and kit pieces are collection instances; the new scenery is editable mesh geometry.

`previews/` contains one angled render and one overhead render per concept. `index.html` provides a comparison gallery with a view switch. Blue and coral pads indicate proposed starting locations. Other tanks demonstrate scale and sightlines.

These are static design studies. Route descriptions are design intentions, not playtest results. Water and the crater are visual hazard placeholders; bridge approaches are illustrative geometry. Collision, movement, navigation, destructible cover, ricochets, and hazard behavior are not implemented. Tank animations remain in the separate animation review file.

The original tank kit and animation files are preserved. Everything here remains under `art-review/.gdignore`, outside Godot's importer. No Godot project settings or gameplay scenes were changed.

The models and packed wood texture were appended from the existing local kit; additional geometry was authored locally in Blender. No external assets or paid services were used. This is a Blender review bundle, not a canonical package from the unavailable optional game-dev CLI. `manifest.json` records the source hash and scene descriptions; `validation.json` records inspection of the saved file.

`build_maps.py` reproduces the scenes and renders. Re-running it overwrites this concept bundle; preserve manual changes before rebuilding.
