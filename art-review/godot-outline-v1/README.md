# Godot outline verification

The Godot renderer was checked with 46 outlined model assets and 521 imported outline meshes. Two floor tiles and the spawn marker are intentionally excluded. All eight tank variants, modular pieces, the arena, and changed turret/tread poses were rendered with the Mobile renderer on Metal.

`tools/import_outlines.gd` adds inverted hull geometry as a child of each eligible mesh during import. `assets/materials/charcoal_outline.tres` provides the shared unlit charcoal material. These outlines are visible in the editor and at runtime, cast no shadows, and are excluded from collision generation in `tools/build_scenes.gd`. Source GLBs are unchanged.

The shared game scene also uses AgX tone mapping, reduced ambient/sun lighting, and 4× MSAA for clearer edges. The map collection now uses the same treatment. Generated captures are in `previews/` and remain ignored by Git.

Implementation references: Godot [mesh outline generation](https://docs.godotengine.org/en/stable/classes/class_mesh.html#class-mesh-method-create-outline) and [scene post-import scripts](https://docs.godotengine.org/en/stable/classes/class_editorscenepostimport.html).
