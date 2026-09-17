import bpy, json, hashlib
from pathlib import Path

OUT = Path(__file__).resolve().parent
manifest = json.loads((OUT/'manifest.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Pocket_Armor_Map_Concepts.blend'))
rows = []
assert len(bpy.data.scenes) == 6
for item in manifest['maps']:
    scene = bpy.data.scenes[item['scene']]
    objects = list(scene.objects)
    cameras = [o for o in objects if o.type == 'CAMERA']
    instances = [o for o in objects if o.instance_type == 'COLLECTION']
    tanks = [o for o in instances if o.instance_collection.name.startswith('tank_')]
    assert len(cameras) == 2
    assert len(tanks) == 4
    assert scene.camera.name.startswith('01 Presentation camera')
    assert scene['review_only']
    assert all(len(o.instance_collection.objects) for o in instances)
    previews = []
    for suffix in ['', '_overhead']:
        path = OUT/'previews'/f"{item['slug']}{suffix}.png"
        assert path.is_file(), path
        img = bpy.data.images.load(str(path), check_existing=False)
        assert img.size[0] >= 1500 and img.size[1] >= 1150
        previews.append({'file':str(path.relative_to(OUT)), 'dimensions':list(img.size), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        bpy.data.images.remove(img)
    rows.append({'scene':scene.name,'objects':len(objects),'collection_instances':len(instances),'tanks':len(tanks),'cameras':len(cameras),'previews':previews})
source=Path(manifest['source'])
assert hashlib.sha256(source.read_bytes()).hexdigest()==manifest['source_sha256']
assert (OUT.parent/'.gdignore').exists()
external=[im.filepath for im in bpy.data.images if im.source=='FILE' and not im.packed_file and im.filepath]
assert not external,external
result={'passed':True,'scene_count':len(rows),'preview_count':12,'source_unchanged':True,'external_texture_dependencies':external,'godot_import_excluded':True,'scope':'Saved Blender structure and preview files; not gameplay validation','maps':rows}
(OUT/'validation.json').write_text(json.dumps(result,indent=2))
print('MAP_VALIDATION_PASSED',len(rows),flush=True)
