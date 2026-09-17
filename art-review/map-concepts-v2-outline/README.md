# Pocket Armor — outlined map concepts

Open **Pocket_Armor_Map_Concepts_Outlined.blend**. Use Blender's scene selector to choose any of the six map concepts. Each scene includes presentation and overhead cameras.

This revision adds fine charcoal outlines around tanks and raised scenery. Floor seams, text, and small flat markings are excluded from the outline selection. Lower ambient/fill/rim lighting, less specular reflection, and a higher-contrast display look reduce the previous washed-out appearance. No bloom/glare effect was enabled in the original scenes.

Outlines use Blender Freestyle and appear in final renders (**F12**); Blender's ordinary material-preview viewport does not display them. Their line style is editable in View Layer Properties → Freestyle Line Set → Charcoal object outlines. Outlines are a Blender presentation treatment and have not been implemented in Godot.

`previews/` contains all six angled renders and all six overhead renders. The gallery and comparison sheet use these updated images. Map layouts, source tank geometry, and the original v1 collection are preserved.

These remain static visual concepts, with no playable movement, collision, hazard behavior, or Godot integration. Everything is inside the existing Godot-excluded review directory.

`refine_style.py` creates this revision from the original saved map collection. `manifest.json` records the source and style changes; `validation.json` records saved-file and render checks. Rebuilding overwrites files in this revision folder.
