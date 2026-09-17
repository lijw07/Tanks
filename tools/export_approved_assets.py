import bpy, json, hashlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REVIEW=ROOT/'art-review/tank-cartoon-v3'
OUT=ROOT/'assets/models'
manifest=[]

def export_tree(source_root,destination,asset_id):
    source_objects=[obj for obj in [source_root]+list(source_root.children_recursive) if not obj.name.startswith(('Muzzle flash','Muzzle radial ray'))]
    temp=bpy.data.scenes.new('EXPORT_ONLY');bpy.context.window.scene=temp
    clones={}
    for obj in source_objects:
        copy=obj.copy();copy.animation_data_clear();copy.name=obj.name
        temp.collection.objects.link(copy);clones[obj]=copy
    for obj,copy in clones.items():copy.parent=clones.get(obj.parent)
    root=clones[source_root];root.location=(0,0,0);root.rotation_mode='XYZ';root.rotation_euler=(0,0,0);root.scale=(1,1,1)
    root.name=asset_id
    for copy in clones.values():
        if copy.type=='EMPTY':
            name=copy.name.split(' | ')[-1].split('.')[0]
            if name in ['Hull','TurretPivot','Suspension'] or name.startswith(('BarrelRecoil','Muzzle')):copy.name=name
    bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=root
    destination.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_apply=True,export_yup=True,export_extras=True)
    manifest.append({'id':asset_id,'path':str(destination.relative_to(ROOT)),'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'bytes':destination.stat().st_size})
    for copy in list(clones.values()):bpy.data.objects.remove(copy,do_unlink=True)
    bpy.data.scenes.remove(temp)

bpy.ops.wm.open_mainfile(filepath=str(REVIEW/'Pocket_Armor_Cartoon_Review.blend'))
anim=json.loads((REVIEW/'animation_manifest.json').read_text())
for record in anim['tanks']:
    sc=bpy.data.scenes[record['scene']];bpy.context.window.scene=sc;sc.frame_set(1)
    col=bpy.data.collections[record['collection']]
    root=next(o for o in col.objects if o.get('asset_id')==record['tank'])
    export_tree(root,OUT/'tanks'/f'{record["tank"]}.glb',record['tank'])
    bpy.context.window.scene=sc;sc.frame_set(292)
    for prefix,suffix in [('WRECK | charred hull','hull'),('WRECK | detached turret','turret')]:
        root=next(o for o in col.objects if o.name.startswith(prefix))
        export_tree(root,OUT/'wrecks'/f'{record["tank"]}_{suffix}.glb',record['tank']+'_'+suffix)

bpy.ops.wm.open_mainfile(filepath=str(REVIEW/'Cartoon_Asset_Source.blend'))
for record in json.loads((REVIEW/'source_manifest.json').read_text())['assets']:
    if record['kind']=='tank':continue
    col=bpy.data.collections[record['id']]
    root=next(o for o in col.objects if not o.parent)
    export_tree(root,OUT/'arena'/f'{record["id"]}.glb',record['id'])
receipt={'name':'Pocket Armor approved cartoon kit','version':'3','authorization':'User approved the cartoon revision and requested Godot integration.','provenance':'Original geometry created locally in Blender for this project; no downloaded provider assets or extracted Nintendo assets.','license_note':'User-commissioned original project assets; no third-party asset license applies.','source_files':{n:hashlib.sha256((REVIEW/n).read_bytes()).hexdigest() for n in ['Pocket_Armor_Cartoon_Review.blend','Cartoon_Asset_Source.blend']},'assets':manifest,'axis':'GLB Y up, tank forward +Z','scale':'1 unit = 1 meter','notes':'Static articulated meshes exported from the approved animation rig. Godot scripts drive the same tread travel and wheel axes interactively. Local game-dev packaging CLI unavailable; this is a project import manifest, not a canonical game-dev package.'}
(ROOT/'assets/approved_asset_manifest.json').write_text(json.dumps(receipt,indent=2))
print('APPROVED_ASSET_EXPORT_COMPLETE',len(manifest),flush=True)
