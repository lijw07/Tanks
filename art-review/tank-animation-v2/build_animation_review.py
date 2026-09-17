import bpy, math, random, json, hashlib
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
SOURCE=OUT.parent/'tank-kit-v1/Pocket_Armor_Review.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
random.seed(27)
FPS=24
END=336
COL=None
SC=None
original_scenes=list(bpy.data.scenes)
sources=sorted([c for c in bpy.data.collections if c.name.startswith('tank_')],key=lambda c:c.name)
spec=json.loads((SOURCE.parent/'manifest.json').read_text())
records=[]

def mat(name,col,rough=.6,emission=0,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if emission:p.inputs['Emission Color'].default_value=(*col,1);p.inputs['Emission Strength'].default_value=emission
    return m

hot=mat('FX | hot yellow core',(1,.68,.13),.5,5)
orange=mat('FX | orange flame',(1,.18,.018),.5,2.5)
smoke=mat('FX | charcoal smoke',(.13,.16,.17),1)
light_smoke=mat('FX | dissipating smoke',(.28,.30,.30),1)
dustmat=mat('FX | warm dust',(.48,.35,.21),1)
char=mat('WRECK | scorched steel',(.055,.068,.074),.91,.0,.12)
ember=mat('FX | ember',(1,.28,.035),.4,3)
white=bpy.data.materials['Printed warm white']
steel=bpy.data.materials['Satin gunmetal']
wood=bpy.data.materials['Beech with packed grain']
slate=bpy.data.materials['Display slate']
rubber=bpy.data.materials['Graphite rubber']
treadmat=bpy.data.materials['Tread ridges']
brass=bpy.data.materials['Warm brass']

def link(o,name,parent=None):
    o.name=name
    for c in list(o.users_collection):c.objects.unlink(o)
    COL.objects.link(o);o.parent=parent
    return o

def empty(name,parent=None):
    o=bpy.data.objects.new(name,None);COL.objects.link(o);o.parent=parent;o.empty_display_size=.08
    return o

def cube(name,loc,dim,m,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=link(bpy.context.object,name,parent);o.dimensions=dim
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(m)
    return o

def ball(name,loc,scale,m,parent=None):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc)
    o=link(bpy.context.object,name,parent);o.scale=scale;o.data.materials.append(m)
    for p in o.data.polygons:p.use_smooth=True
    return o

def torus(name,loc,m):
    bpy.ops.mesh.primitive_torus_add(major_radius=1,minor_radius=.035,major_segments=40,minor_segments=6,location=loc)
    o=link(bpy.context.object,name);o.data.materials.append(m);return o

def label(name,body,loc,size=.2):
    c=bpy.data.curves.new(name,'FONT');c.body=body;c.size=size;c.align_x='CENTER';c.materials.append(white)
    o=bpy.data.objects.new(name,c);COL.objects.link(o);o.location=loc;return o

def key(o,prop,frame,val):
    setattr(o,prop,val);o.keyframe_insert(data_path=prop,frame=frame,group=prop)

def pulse(o,frame,duration,scale,peak=2):
    key(o,'scale',1,(.0001,)*3)
    key(o,'scale',frame-1,(.0001,)*3)
    key(o,'scale',frame+peak,scale)
    key(o,'scale',frame+duration,(.0001,)*3)
    key(o,'scale',END,(.0001,)*3)

def puff(name,loc,start,life,size,m,drift):
    o=ball(name,loc,(1,1,1),m)
    key(o,'location',start,loc);key(o,'location',start+life,Vector(loc)+Vector(drift))
    pulse(o,start,life,(size,)*3,max(3,int(life*.42)))
    return o

def scene(name,scale=10,loc=(8,-11,13),target=(0,-.4,0),res=(960,720)):
    global COL,SC
    SC=bpy.data.scenes.new(name);bpy.context.window.scene=SC
    COL=bpy.data.collections.new(name+' | display');SC.collection.children.link(COL)
    SC.frame_start=1;SC.frame_end=END;SC.render.fps=FPS
    SC.render.engine='CYCLES';SC.cycles.samples=12;SC.cycles.use_denoising=True
    SC.render.resolution_x=res[0];SC.render.resolution_y=res[1];SC.render.resolution_percentage=100
    SC.world=bpy.data.worlds.new(name+' | world');SC.world.use_nodes=True
    SC.world.node_tree.nodes['Background'].inputs[0].default_value=(.35,.42,.48,1)
    SC.world.node_tree.nodes['Background'].inputs[1].default_value=.5
    SC.view_settings.view_transform='AgX';SC.unit_settings.system='METRIC'
    ca=bpy.data.cameras.new('Review camera');cam=bpy.data.objects.new('Review camera',ca);COL.objects.link(cam)
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();ca.type='ORTHO';ca.ortho_scale=scale;SC.camera=cam
    for name,loc,power,size,color in [('Key',(-4,-6,11),1300,8,(1,.87,.72)),('Fill',(7,2,8),950,7,(.7,.85,1))]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color
        o=bpy.data.objects.new(name,d);COL.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    cube('Studio',(0,0,-.5),(100,100,.2),bpy.data.materials['Midnight blue backdrop'])
    for fr,txt in [(1,'DRIVE'),(73,'PIVOT TURN'),(109,'AIM'),(156,'FIRE 1'),(192,'FIRE 2'),(240,'DEATH / EXPLOSION'),(278,'WRECK / SMOKE'),(326,'RESPAWN')]:SC.timeline_markers.new(txt,frame=fr)
    SC.sync_mode='FRAME_DROP'
    return SC

def trackpath(s,a,r=.22):
    straight=2*a;total=4*a+2*math.pi*r;s%=total
    if s<straight:return (a-s,.26+r,math.pi)
    s-=straight
    if s<math.pi*r:
        t=s/r;return(-a-r*math.sin(t),.26+r*math.cos(t),math.pi+t)
    s-=math.pi*r
    if s<straight:return(-a+s,.26-r,0)
    t=(s-straight)/r;return(a+r*math.sin(t),.26-r*math.cos(t),t)

def motion(f):
    if f<=72:
        t=max(0,(f-1)/71);return (Vector((0,1.1-1.7*t,0)),0)
    if f<=108:return(Vector((0,-.6,0)),math.radians(35)*(f-72)/36)
    return(Vector((0,-.6,0)),math.radians(35))

for ix,source in enumerate(sources):
    sc=scene(f'{ix+2:02d} | '+source.name.split('_',2)[2].replace('_',' ').upper())
    stage=COL
    demo=bpy.data.collections.new('ANIMATED | '+source.name);sc.collection.children.link(demo);COL=demo
    meshes_before=len(bpy.data.objects)
    copies={}
    # Bake bevels into new meshes, preserving the approved static source file.
    for old in source.objects:
        o=old.copy();o.animation_data_clear();COL.objects.link(o);o.name=f'{ix+1:02d} | '+old.name
        if old.type=='MESH':
            o.data=old.data.copy()
        copies[old]=o
    for old,o in copies.items():o.parent=copies.get(old.parent)
    root=next(o for old,o in copies.items() if old.parent is None)
    hull=next(o for old,o in copies.items() if old.name.startswith('Hull'))
    turret=next(o for old,o in copies.items() if old.name.startswith('TurretPivot'))
    suspension=empty('Suspension',root);hull.parent=suspension;turret.parent=suspension
    guns=[o for old,o in copies.items() if old.name.startswith('BarrelRecoil')]
    muzzles=[o for old,o in copies.items() if old.name.startswith('Muzzle') and old.type=='EMPTY']
    dims=next(a['footprint_m'] for a in spec['assets'] if a['id']==source.name);w,l=dims
    wheels=[]
    for old,o in copies.items():
        if old.name.startswith(('Track belt','Road wheel','Wheel hub')):
            o.parent=root
            if old.name.startswith(('Road wheel','Wheel hub')):wheels.append(o)
        if old.name.startswith(('Tread top link','Tread sole link','Tread end link')):bpy.data.objects.remove(o,do_unlink=True)
    # Continuous racetrack paths; links move around both ends rather than sliding on top.
    trackw=.26 if w<1.4 else .32;a=l*.5-.22;perimeter=4*a+2*math.pi*.22
    linkcount=max(22,round(perimeter/.14));links=[]
    for side in [-1,1]:
        for j in range(linkcount):
            o=cube(f'Tread {side:+d} / {j:02d}',(0,0,0),(trackw+.012,.09,.04),treadmat,root)
            for f in list(range(1,112,2))+[112,239,240,326,330,336]:
                drive=min(max(f-1,0),71)*1.7/71
                turn=min(max(f-72,0),36)*math.radians(35)*w*.5/36
                travel=drive+side*turn
                if f>=326:travel=0
                y,z,rx=trackpath(j*perimeter/linkcount+travel,a)
                key(o,'location',f,(side*(w/2-trackw/2),y,z))
                # Unwrap tangent changes to prevent reversal at a 2*pi boundary.
                if j==0 and side==-1:pass
                if f==1:previous=rx
                while rx-previous>math.pi:rx-=2*math.pi
                while rx-previous<-math.pi:rx+=2*math.pi
                key(o,'rotation_euler',f,(rx,0,0));previous=rx
            links.append(o)
    for o in wheels:
        base=o.rotation_euler.copy();side=-1 if o.location.x<0 else 1
        for f in [1,72,108,239,326,330,336]:
            d=min(max(f-1,0),71)*1.7/71+side*min(max(f-72,0),36)*math.radians(35)*w*.5/36
            if f>=326:d=0
            # Cylinder local Z is its axle, transformed onto world X by the initial rotation.
            o.rotation_mode='XYZ';key(o,'rotation_euler',f,(base.x,base.y,base.z-d/.17))
    for f in [1,72,108,239,240,326,330,336]:
        pos,yaw=motion(f)
        if f>=326:pos,yaw=motion(1)
        key(root,'location',f,pos);key(root,'rotation_euler',f,(0,0,yaw))
    for f,scale in [(1,1),(240,1),(241,.0001),(325,.0001),(331,1),(336,1)]:key(root,'scale',f,(scale,)*3)
    for f in range(1,111,3):
        strength=1 if f<72 else .4
        key(suspension,'location',f,(0,0,.013*math.sin(f*.67)*strength))
        key(suspension,'rotation_euler',f,(.012*math.sin(f*.54)*strength,.009*math.cos(f*.5)*strength,0))
    for f in [112,151,180,188,221,239,326,336]:
        key(suspension,'location',f,(0,0,0));key(suspension,'rotation_euler',f,(0,0,0))
    for f,z in [(1,0),(72,0),(108,-35),(126,-57),(142,-35),(239,-35),(326,0),(336,0)]:key(turret,'rotation_euler',f,(0,0,math.radians(z)))
    # Two salvos; the duelist fires its two guns in a quick stagger.
    for gi,gun in enumerate(guns):
        base=gun.location.copy()
        for f in [1,152,188,222,239,326,336]:key(gun,'location',f,base)
        for shot in [156+gi*4,192+gi*4]:
            key(gun,'location',shot-1,base);key(gun,'location',shot+1,base+Vector((0,.18 if ix!=6 else .25,0)));key(gun,'location',shot+9,base)
            key(suspension,'rotation_euler',shot-1,(0,0,0));key(suspension,'rotation_euler',shot+2,(-.04,0,0));key(suspension,'rotation_euler',shot+10,(0,0,0))
        muzzle=next(m for m in muzzles if m.parent==gun)
        for shot in [156+gi*4,192+gi*4]:
            flash=ball('Muzzle flash | hot core',(0,-.12,0),(1,1,1),hot,muzzle);pulse(flash,shot,5,(.17,.40,.17),1)
            flare=ball('Muzzle flash | orange lobe',(0,-.31,0),(1,1,1),orange,muzzle);pulse(flare,shot,6,(.22,.34,.20),2)
            for q in range(4):
                ray=cube('Muzzle radial ray',(0,0,0),(.04,.32,.04),hot,muzzle)
                angle=q*math.pi/2;ray.location=(.14*math.cos(angle),-.15,.14*math.sin(angle));ray.rotation_euler=(angle*.1,0,angle)
                pulse(ray,shot,4,(1,1,1),1)
            sc.frame_set(shot-1);bpy.context.view_layer.update();p=muzzle.matrix_world.translation.copy()
            projectile=ball('Traveling shell',p,(1,1,1),brass)
            end=Vector((p.x,-3.0,p.z));impact=shot+8
            key(projectile,'location',shot,p);key(projectile,'location',impact,end)
            pulse(projectile,shot,9,(.075,.18,.075),1)
            trail=ball('Shell streak',p,(1,1,1),hot)
            key(trail,'location',shot,p+Vector((0,.14,0)));key(trail,'location',impact,end+Vector((0,.14,0)))
            pulse(trail,shot,9,(.026,.30,.026),1)
            for k in range(5):
                puff('Muzzle smoke',p,shot+2+k*2,17,.10+k*.018,light_smoke,(random.uniform(-.18,.18),-.15,.4))
            pulse(ball('Impact flash',end,(1,)*3,hot),impact,6,(.31,.18,.31),1)
            for k in range(7):
                direction=Vector((random.uniform(-.8,.8),random.uniform(.15,.7),random.uniform(.1,.9)))
                sp=ball('Impact spark',end,(1,)*3,ember)
                key(sp,'location',impact,end);key(sp,'location',impact+14,end+direction)
                pulse(sp,impact,14,(.025,.025,.10),1)
            for k in range(4):puff('Impact smoke',end,impact+k*2,22,.18,light_smoke,(random.uniform(-.4,.4),.1,.5))
    for f in range(7,105,7):
        pos,yaw=motion(f)
        for side in [-1,1]:
            p=pos+Vector((side*w*.42,l*.40,.14))
            puff('Track dust',p,f,20,.13,dustmat,(side*.18,.25,.19))
    # Destruction uses animation-only mesh effects: deterministic when scrubbing, no simulation bake.
    death=Vector((0,-.6,.5));yaw=math.radians(35)
    ring=torus('Explosion shock ring',(0,-.6,.06),dustmat);pulse(ring,240,22,(2.0,2.0,.7),12)
    for k in range(11):
        off=Vector((random.uniform(-.55,.55),random.uniform(-.55,.55),random.uniform(-.25,.45)))
        o=ball('Explosion fireball',death+off,(1,)*3,hot if k<4 else orange)
        peak=random.uniform(.35,.65);pulse(o,240+k%3,19+random.randrange(5),(peak,)*3,4+k%3)
        key(o,'location',240,death+off);key(o,'location',264,death+off*1.9+Vector((0,0,.55)))
    for k in range(20):
        p=death+Vector((random.uniform(-.5,.5),random.uniform(-.5,.5),random.uniform(0,.4)))
        puff('Death smoke',p,245+k*2,55,random.uniform(.30,.56),smoke if k<10 else light_smoke,(random.uniform(-.5,.5),.35,1.5+random.random()))
    for k in range(16):
        angle=random.uniform(0,math.tau);speed=random.uniform(.9,2.0);end=death+Vector((math.cos(angle)*speed,math.sin(angle)*speed,-.42))
        o=cube('Flying armor debris',death,(random.uniform(.08,.19),.13,.09),steel if k%2 else char)
        key(o,'location',240,death);key(o,'location',250,death+Vector((math.cos(angle)*speed*.5,math.sin(angle)*speed*.5,random.uniform(.7,1.4))));key(o,'location',267,end);key(o,'location',275,end+Vector((.08,0,-.02)))
        key(o,'rotation_euler',240,(0,0,0));key(o,'rotation_euler',270,(random.random()*8,random.random()*8,random.random()*8))
        key(o,'scale',1,(.0001,)*3);key(o,'scale',240,(.0001,)*3);key(o,'scale',242,(1,)*3);key(o,'scale',320,(1,)*3);key(o,'scale',326,(.0001,)*3)
    # Editable wreck made from the same silhouette, with a thrown turret assembly.
    sc.frame_set(239);bpy.context.view_layer.update()
    wreck=empty('WRECK | charred hull');wreck.location=(0,-.6,0);wreck.rotation_euler.z=yaw
    thrown=empty('WRECK | detached turret');thrown.location=(0,-.6,.82)
    bpy.context.view_layer.update()
    turret_descendants=set(turret.children_recursive)
    for old,orig in copies.items():
        if old.type!='MESH' or old.name.startswith(('Tread','Muzzle','Bore','Cannon')):continue
        # Avoid tiny details in the wreck while preserving its hull, wheels and turret identity.
        if not old.name.startswith(('Lower hull','Upper deck','Track belt','Track guard','Road wheel','Round turret','Faceted turret','Armored turret','Siege mantlet','Turret cheek','Commander hatch','Barrel collar')):continue
        o=orig.copy();o.data=orig.data.copy();o.animation_data_clear();COL.objects.link(o);o.name='Charred | '+old.name
        o.data.materials.clear();o.data.materials.append(char)
        is_turret=orig==turret or orig in turret_descendants
        world=orig.matrix_world.copy();o.parent=thrown if is_turret else wreck
        o.matrix_parent_inverse.identity();o.matrix_basis=o.parent.matrix_world.inverted()@world
    for group in [wreck,thrown]:
        for f,s in [(1,.0001),(240,.0001),(242,1),(320,1),(326,.0001),(336,.0001)]:key(group,'scale',f,(s,)*3)
    for f,loc,rot in [(240,(0,-.6,.82),(0,0,0)),(252,(.4,.1,2.0),(.8,.4,1.0)),(267,(.9,.5,.34),(1.9,.2,1.6)),(275,(1.0,.55,.31),(1.7,.2,1.7)),(320,(1.0,.55,.31),(1.7,.2,1.7))]:
        key(thrown,'location',f,loc);key(thrown,'rotation_euler',f,rot)
    for k in range(6):puff('Wreck ember',(-.35+k*.14,-.6,.55),257+k*4,36,.055,ember,(.15,0,.55))
    scorch=ball('Scorch mark',(0,-.6,.011),(1,)*3,char)
    for f,s in [(1,.0001),(240,.0001),(249,1),(320,1),(326,.0001),(336,.0001)]:key(scorch,'scale',f,(s*w*.73,s*l*.64,max(.0001,s*.008)))
    # Target and review base are included in the reusable demo collection.
    cube('Review slab',(0,-.35,-.17),(5.3,7.1,.30),slate)
    for j in range(8):cube('Maple test lane',(0,-2.75+j*.7,-.025),(4.9,.692,.045),bpy.data.materials['Maple floor 02'])
    cube('Impact target',(0,-3.27,.68),(2.15,.3,1.36),steel)
    for x in [-.85,.85]:cube('Target yellow rail',(x,-3.438,.68),(.11,.014,1.18),bpy.data.materials['Safety ochre'])
    label('Name',source.name.split('_',2)[2].replace('_',' ').upper(),(0,2.65,.018),.27)
    # All animation is authored as reusable object actions. Linear keys keep track cycles stable.
    animated=0;curves=0
    for o in demo.objects:
        if not o.animation_data or not o.animation_data.action:continue
        act=o.animation_data.action;act.name=source.name+' / '+o.name;animated+=1
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        curves+=1
                        for pt in fc.keyframe_points:pt.interpolation='LINEAR'
    COL=stage
    label('Instructions','SPACE: PLAY / PAUSE   |   DRAG TIMELINE TO SCRUB',(0,-4.4,0),.18)
    for start,end,title in [(1,72,'01  /  DRIVE'),(73,108,'02  /  PIVOT TURN'),(109,151,'03  /  AIM'),(152,225,'04  /  FIRE + IMPACT'),(226,239,'05  /  HOLD'),(240,277,'06  /  EXPLOSION'),(278,325,'07  /  SMOKING WRECK'),(326,336,'08  /  RESET')]:
        o=label('Animated phase',title,(0,3.75,0),.30)
        for fr,s in [(1,.0001),(max(1,start-1),.0001),(start,1),(end,1),(min(336,end+1),.0001),(336,.0001)]:key(o,'scale',fr,(s,)*3)
    sc.frame_set(1)
    records.append(dict(tank=source.name,scene=sc.name,collection=demo.name,animated_objects=animated,curves=curves,tread_links=len(links),barrels=len(guns),frame_range=[1,END],fps=FPS))
    print('ANIMATED',source.name,animated,flush=True)

gallery=scene('01 | ALL TANKS - ANIMATION TEST',scale=27,loc=(0,-19,34),target=(0,-.5,0),res=(1440,1000))
for i,r in enumerate(records):
    o=bpy.data.objects.new('Demo | '+r['tank'],None);COL.objects.link(o);o.instance_type='COLLECTION';o.instance_collection=bpy.data.collections[r['collection']];o.location=((i%4-1.5)*6.0,4.25-(i//4)*8.5,0)
label('Gallery title','POCKET ARMOR  /  MOTION + EFFECTS',(0,9,0),.5)
label('Gallery guide','1-72 DRIVE   /   73-108 TURN   /   156 + 192 FIRE   /   240 DEATH   /   326 RESET',(0,-9.5,0),.21)
for old in original_scenes:bpy.data.scenes.remove(old)
bpy.context.window.scene=bpy.data.scenes[records[0]['scene']]
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.region_3d.view_camera_zoom=10
            area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL'
        if area.type=='DOPESHEET_EDITOR':
            area.spaces.active.dopesheet.show_only_selected=False
for sc in bpy.data.scenes:sc.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pocket_Armor_Animation_Review.blend'))
report={'status':'BLENDER REVIEW ONLY - waiting for visual approval','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'frames':END,'fps':FPS,'duration_seconds':END/FPS,'tanks':records,'features':['Continuous tread circulation','Axle wheel rotation','Travel and differential pivot turn','Suspension motion','Independent turret aiming','Barrel recoil','Muzzle flash and smoke','Traveling shells and streaks','Target impacts and sparks','Track dust','Death flash and fireball','Shock ring','Flying armor debris','Detached turret','Charred hull wreck','Rising smoke and embers','Respawn loop'],'limits':['Choreographed animation previews, not playable combat','Blender mesh effects; Godot particle implementation deferred','No sound effects','No Godot files changed']}
(OUT/'animation_manifest.json').write_text(json.dumps(report,indent=2))
hero=bpy.context.scene
for frame,name in [(48,'01_moving'),(157,'02_firing'),(247,'03_explosion'),(292,'04_wreck')]:
    hero.frame_set(frame);hero.render.image_settings.file_format='PNG';hero.render.filepath=str(OUT/'previews'/f'{name}.png');bpy.ops.render.render(write_still=True)
bpy.context.window.scene=gallery;gallery.frame_set(157);gallery.render.filepath=str(OUT/'previews/05_all_tanks.png');bpy.ops.render.render(write_still=True)
print('ANIMATION_BUILD_COMPLETE',flush=True)
