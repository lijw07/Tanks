import bpy,json,math,hashlib
from mathutils import Vector
from pathlib import Path
out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/'Pocket_Armor_Cartoon_Review.blend'))
manifest=json.loads((out/'animation_manifest.json').read_text())
checks=[]
for entry in manifest['tanks']:
    sc=bpy.data.scenes[entry['scene']];bpy.context.window.scene=sc
    col=bpy.data.collections[entry['collection']]
    root=next(o for o in col.objects if o.get('asset_id')==entry['tank'])
    wheels=[o for o in col.objects if 'Road wheel' in o.name and not o.name.startswith('Charred')]
    treads=[o for o in col.objects if o.name.startswith('Tread ')]
    axis_error=0;contact_error=0;tangent_error=0;ground_samples=0
    for frame in range(1,109):
        sc.frame_set(frame);bpy.context.view_layer.update()
        for wheel in wheels:
            axis=wheel.rotation_quaternion@Vector((0,0,1))
            axis_error=max(axis_error,(axis-Vector((1,0,0))).length)
        if frame<108:
            active=[(o,o.matrix_world.translation.copy()) for o in treads if abs(o.location.z-.04)<.0001 and abs(o.location.y)<.35]
            yaw=root.rotation_euler.z
            sc.frame_set(frame+1);bpy.context.view_layer.update()
            forward=Vector((math.sin((yaw+root.rotation_euler.z)/2),-math.cos((yaw+root.rotation_euler.z)/2),0))
            for o,p in active:
                if abs(o.location.z-.04)>.0001:continue
                residual=abs((o.matrix_world.translation-p).dot(forward))
                contact_error=max(contact_error,residual);ground_samples+=1
    assert len(wheels)==6,(entry['tank'],len(wheels))
    assert len(treads)==28
    assert axis_error<1e-5,(entry['tank'],'axle wobble',axis_error)
    assert ground_samples>30
    assert contact_error<.0002,(entry['tank'],'contact slide',contact_error)
    sc.frame_set(1);start=root.location.copy()
    sc.frame_set(72);assert abs((root.location-start).length-1.7)<1e-5
    sc.frame_set(108);assert abs(root.rotation_euler.z-math.radians(35))<1e-5
    sc.frame_set(157);assert max(o.scale.x for o in col.objects if o.name.startswith('Muzzle flash'))>.05
    sc.frame_set(242);assert root.scale.x<.001
    sc.frame_set(292);assert next(o for o in col.objects if o.name.startswith('WRECK | charred hull')).scale.x>.99
    sc.frame_set(336);assert root.scale.x>.99
    tris=sum(sum(len(poly.vertices)-2 for poly in o.data.polygons) for o in root.children_recursive if o.type=='MESH')
    assert tris<1500,(entry['tank'],tris)
    checks.append({'tank':entry['tank'],'wheel_axis_max_error':axis_error,'bottom_contact_longitudinal_slip_max_m_per_frame':contact_error,'ground_contact_samples':ground_samples,'animated_tank_triangles':tris,'status':'PASS'})
assert (out.parent/'.gdignore').exists()
assert hashlib.sha256((out.parent.parent/'project.godot').read_bytes()).hexdigest()=='429111d58104e4f22a598012ade780f563b8f03692e5c4cc235a141ea261944e'
(out/'validation.json').write_text(json.dumps({'status':'PASS','tanks':checks,'godot_unchanged':True,'review_only':True},indent=2))
print('TREAD_PHYSICS_AND_ANIMATION_PASS',len(checks),flush=True)
