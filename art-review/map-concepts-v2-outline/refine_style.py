import bpy, json, sys, hashlib
from pathlib import Path

OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'map-concepts-v1/Pocket_Armor_Map_Concepts.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
manifest=json.loads((SOURCE.parent/'manifest.json').read_text())
outline=bpy.data.collections.new('OUTLINE | tanks and raised scenery')
for collection in list(bpy.data.collections):
    if collection.name.startswith(('tank_', 'wall_', 'pillar_', 'crate_', 'barrels_', 'barricade_', 'rubble_', 'border_')):
        for obj in collection.all_objects:
            if obj.type=='MESH' and obj.name not in outline.objects:
                outline.objects.link(obj)
for scene in bpy.data.scenes:
    for obj in list(scene.objects):
        if obj.type=='MESH' and obj.name.startswith(('Cargo ', 'Corrugated ', 'Bridge ', 'Canal coping', 'Crater retaining', 'Solid beech board')):
            if obj.name not in outline.objects: outline.objects.link(obj)
outline.use_fake_user=True
for material in bpy.data.materials:
    if material.use_nodes:
        bsdf=material.node_tree.nodes.get('Principled BSDF')
        if bsdf:
            bsdf.inputs['Specular IOR Level'].default_value=.28
            if material.name!='Canal turquoise resin':
                bsdf.inputs['Roughness'].default_value=max(.48,bsdf.inputs['Roughness'].default_value)
for scene in bpy.data.scenes:
    scene.render.use_freestyle=True
    scene.render.line_thickness=1.0
    scene.cycles.samples=40
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.22
    scene.view_settings.look='AgX - Medium High Contrast'
    scene['style_revision']='Fine charcoal silhouettes; softer specular response; reduced fill lighting'
    for obj in scene.objects:
        if obj.type=='LIGHT':
            if obj.name.startswith('Warm key'): obj.data.energy*=.92;obj.data.size=8
            elif obj.name.startswith('Cool fill'): obj.data.energy*=.65;obj.data.size=7
            elif obj.name.startswith('Back rim'): obj.data.energy*=.60;obj.data.size=6
    fs=scene.view_layers[0].freestyle_settings
    lines=fs.linesets[0] if len(fs.linesets) else fs.linesets.new('Readable silhouettes')
    lines.name='Charcoal object outlines'
    lines.select_by_collection=True;lines.collection=outline
    lines.collection_negation='INCLUSIVE'
    lines.select_by_edge_types=True
    for name in ['silhouette','border','crease','ridge_valley','suggestive_contour','material_boundary','contour','external_contour','edge_mark']:
        setattr(lines,'select_'+name,name in ['silhouette','contour','external_contour'])
    style=lines.linestyle
    style.color=(.026,.035,.038);style.alpha=.92;style.thickness=1.4
    scene.camera=next(o for o in scene.objects if o.type=='CAMERA' and o.name.startswith('01 Presentation'))
    scene.render.resolution_x=1600;scene.render.resolution_y=1250
    scene.render.filepath=str(OUT/'previews'/f"{next(m['slug'] for m in manifest['maps'] if m['scene']==scene.name)}.png")
    for node in scene.compositing_node_group.nodes if getattr(scene,'compositing_node_group',None) else []:
        if node.type=='GLARE':node.mute=True
bpy.context.window.scene=bpy.data.scenes[manifest['maps'][0]['scene']]
manifest['style_revision']={'request':'Add outlines and reduce the bloom-like softness','method':'Blender Freestyle charcoal object silhouettes, 1.4 px at final resolution; reduced world/fill/rim; higher roughness and lower specular; Medium High Contrast AgX','bloom':'No glare/bloom effect was present in the original scenes; softness came from lighting/materials','source_map_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest()}
manifest['status']='Outlined review concepts; no Godot integration or gameplay validation'
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pocket_Armor_Map_Concepts_Outlined.blend'))
trial='--trial' in sys.argv
for m in manifest['maps'][:1] if trial else manifest['maps']:
    scene=bpy.data.scenes[m['scene']];bpy.context.window.scene=scene
    print('OUTLINE_RENDER_START',scene.name,flush=True)
    bpy.ops.render.render(write_still=True)
    if not trial:
        scene.camera=next(o for o in scene.objects if o.type=='CAMERA' and o.name.startswith('02 Overhead'))
        scene.render.resolution_x=1500;scene.render.resolution_y=1150
        scene.render.filepath=str(OUT/'previews'/f"{m['slug']}_overhead.png")
        bpy.ops.render.render(write_still=True)
    print('OUTLINE_RENDER_DONE',scene.name,flush=True)
print('OUTLINED_MAPS_COMPLETE',flush=True)
