import bpy,json,hashlib,math
from pathlib import Path
out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/'Pocket_Armor_Animation_Review.blend'))
manifest=json.loads((out/'animation_manifest.json').read_text())
results=[]
for record in manifest['tanks']:
    sc=bpy.data.scenes[record['scene']];bpy.context.window.scene=sc
    col=bpy.data.collections[record['collection']]
    root=next(o for o in col.objects if o.get('asset_id')==record['tank'])
    tread=next(o for o in col.objects if o.name.startswith('Tread -1 / 00'))
    wheel=next(o for o in col.objects if 'Road wheel' in o.name)
    gun=next(o for o in col.objects if 'BarrelRecoil' in o.name)
    turret=next(o for o in col.objects if 'TurretPivot' in o.name)
    wreck=next(o for o in col.objects if o.name.startswith('WRECK | charred hull'))
    flash=next(o for o in col.objects if o.name.startswith('Muzzle flash | hot core'))
    sc.frame_set(1);p1=root.location.copy();t1=tread.location.copy();r1=wheel.rotation_euler.copy()
    sc.frame_set(24);assert (tread.location-t1).length>.02;assert sum(abs(a-b) for a,b in zip(wheel.rotation_euler,r1))>.1
    sc.frame_set(72);assert (root.location-p1).length>1.6
    sc.frame_set(108);assert abs(root.rotation_euler.z-math.radians(35))<.01
    sc.frame_set(142);assert abs(turret.rotation_euler.z+math.radians(35))<.01
    sc.frame_set(152);base=gun.location.copy()
    sc.frame_set(158);assert (gun.location-base).length>.09;assert max(flash.scale)>.05
    assert root.scale.x>.99
    sc.frame_set(242);assert root.scale.x<.001;assert wreck.scale.x>.99
    sc.frame_set(292);assert root.scale.x<.001;assert wreck.scale.x>.99
    sc.frame_set(336);assert root.scale.x>.99;assert wreck.scale.x<.001;assert (root.location-p1).length<.001
    results.append({'tank':record['tank'],'result':'PASS','checks':['Travel','Tread circulation','Wheel rotation','Pivot turn','Turret aiming','Recoil','Muzzle flash','Death replacement','Persistent wreck','Respawn reset']})
assert (out.parent/'.gdignore').exists()
project=out.parent.parent/'project.godot'
assert hashlib.sha256(project.read_bytes()).hexdigest()=='429111d58104e4f22a598012ade780f563b8f03692e5c4cc235a141ea261944e'
report={'status':'PASS','tested_from_saved_blend':True,'tanks':results,'godot_project_unchanged':True,'excluded_from_godot_import':True,'limitations':['Visual effects are authored Blender mesh animation','Godot import and gameplay not tested because approval is pending']}
(out/'validation.json').write_text(json.dumps(report,indent=2))
print('ANIMATION_VALIDATION_PASS',len(results),flush=True)
