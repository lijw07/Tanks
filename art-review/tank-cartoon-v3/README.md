# Pocket Armor — cartoon revision 3

This revision addresses the tread rotation bug and replaces the detailed models with simple, faceted toy tanks. Previous review files remain intact. Everything is still excluded from Godot by `art-review/.gdignore`.

## Review the animation

Open **Pocket_Armor_Cartoon_Review.blend**. Press **Space** over the viewport to play/pause, or scrub the timeline. The top scene selector provides eight individual tank demos and an all-tank comparison. The sequence remains 14 seconds at 24 fps:

- Frames 1–72: drive.
- Frames 73–108: pivot turn.
- Frames 109–151: aim.
- Frames 156 and 192: fire; the duelist fires its second barrel four frames later.
- Frame 240: explode.
- Frames 278–325: smoking wreck.
- Frames 326–336: reset.

`previews/cartoon_animation_demo.mp4` is a rendered version. **Cartoon_Asset_Source.blend** contains the restyled tank lineup, assembled arena, and modular-kit presentation.

## What changed

- Rebuilt all eight tank models with simple tapered hulls, six/eight-sided turrets and barrels, three wheels per side, flat colors, and broad markings.
- Removed engine grilles, rivets, headlights, antennas, small fittings, metallic shading, and wood grain.
- Static tank meshes contain 540–608 triangles; the animated tanks use 28 tread links and remain below 1,500 triangles each, excluding effects and the display stage.
- Simplified the arena materials and changed smoke, dust, and explosion meshes to flat-shaded low-poly shapes.
- Corrected wheel rotation with quaternions around the chassis X axle. The former Euler Z rotation changed the axle direction and made the wheels wobble.
- Corrected differential track travel during turning using the actual track-center offset. Both the rotating chassis and tread motion now agree at the ground contact point.
- Sampled wheel rotation every frame so a multi-revolution wheel movement cannot interpolate through the wrong short rotation.

## Verification and limits

`validation.json` records checks for all eight tanks: wheel axis stability across every movement frame, longitudinal tread/ground contact slip during driving and turning, movement/aiming, firing, death, wreck, reset, and polygon budgets. The Godot project configuration hash is unchanged.

This is a choreographed Blender art preview, not a game controller or Godot implementation. The effects are editable mesh animations. No sound is included. The revised art still needs user approval.
