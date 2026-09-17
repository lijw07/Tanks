import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent / 'tank-kit-v1/Pocket_Armor_Review.blend'
bpy.ops.wm.read_factory_settings(use_empty=True)
ids = [a['id'] for a in json.loads((SOURCE.parent / 'manifest.json').read_text())['assets']]
with bpy.data.libraries.load(str(SOURCE), link=False) as (src, dst):
    dst.collections = [n for n in src.collections if n in ids]
LIB = {c.name: c for c in dst.collections}
assert len(LIB) == len(ids)
SC = None
COL = None
MAPS = []

def mat(name, color, metal=0, rough=.6):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m

wood = bpy.data.materials['Beech with packed grain']
cream = bpy.data.materials['Warm ivory insignia']
steel = bpy.data.materials['Satin gunmetal']
back = mat('Concept backdrop', (.024,.044,.054))
ink = mat('Lettering charcoal', (.035,.065,.076))
blue = mat('Team blue', (.035,.38,.69))
orange = mat('Team coral', (.84,.19,.09))
water = mat('Canal turquoise resin', (.025,.32,.39), .25,.24)
concrete = mat('Freight yard concrete', (.28,.33,.32))
sand = mat('Quarry sand', (.64,.46,.25))
pit = mat('Crater dark earth', (.075,.046,.03))
moss = mat('Fort courtyard sage', (.26,.38,.26))
rust = mat('Container rust', (.56,.16,.08))
teal = mat('Container teal', (.055,.29,.32))

def link(o):
    for c in list(o.users_collection): c.objects.unlink(o)
    COL.objects.link(o)
    return o

def cube(name, loc, dims, material, bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = link(bpy.context.object); o.name = name; o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel:
        mod=o.modifiers.new('Soft edges','BEVEL'); mod.width=bevel; mod.segments=2
        o.modifiers.new('Corner normals','WEIGHTED_NORMAL')
    return o

def inst(name, x, y, a=0, z=0):
    o=bpy.data.objects.new(name,None); COL.objects.link(o)
    o.instance_type='COLLECTION'; o.instance_collection=LIB[name]
    o.location=(x,y,z); o.rotation_euler.z=math.radians(a)
    return o

def label(body, loc, size, material=cream):
    d=bpy.data.curves.new(body,'FONT'); d.body=body; d.size=size; d.align_x='CENTER'
    d.space_character=1.15; d.materials.append(material)
    o=bpy.data.objects.new(body,d); COL.objects.link(o); o.location=loc
    return o

def camera(name, loc, target, scale):
    d=bpy.data.cameras.new(name); o=bpy.data.objects.new(name,d); COL.objects.link(o)
    o.location=loc; o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    d.type='ORTHO'; d.ortho_scale=scale
    return o

def light(name, loc, power, size, color):
    d=bpy.data.lights.new(name,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; d.color=color
    o=bpy.data.objects.new(name,d); COL.objects.link(o); o.location=loc
    o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()

def start(num, name, subtitle, floor='maple'):
    global SC,COL
    SC=bpy.data.scenes.new(f'{num:02d} | {name.upper()}'); bpy.context.window.scene=SC
    COL=bpy.data.collections.new(f'{name} | editable layout'); SC.collection.children.link(COL)
    SC.render.engine='CYCLES'; SC.cycles.samples=24; SC.cycles.use_denoising=True
    SC.render.resolution_x=1600; SC.render.resolution_y=1250; SC.render.resolution_percentage=100
    SC.render.image_settings.file_format='PNG'; SC.view_settings.view_transform='AgX'
    SC.world=bpy.data.worlds.new(name+' studio'); SC.world.use_nodes=True
    SC.world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.45,.52,1)
    SC.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    SC.unit_settings.system='METRIC'
    cube('Studio ground',(0,0,-1.05),(200,200,.2),back)
    cube('Solid beech board',(0,0,-.65),(25,19,.65),wood,.16)
    if floor=='maple':
        for x in range(-11,12,2):
            for y in range(-8,9,2): inst('floor_maple_2m',x,y)
    else:
        fm={'concrete':concrete,'sand':sand,'moss':moss}[floor]
        cube('Inset play surface',(0,0,-.10),(24,18,.2),fm)
        for x in range(-10,12,2): cube('Floor joint',(x,0,.001),(.018,18,.003),ink,0)
        for y in range(-7,9,2): cube('Floor joint',(0,y,.001),(24,.018,.003),ink,0)
    for x in range(-11,12,2):
        for y in [-9.2,9.2]: inst('border_2m',x,y)
    for y in range(-8,9,2):
        for x in [-12.2,12.2]: inst('border_2m',x,y,90)
    for x in [-12.2,12.2]:
        for y in [-9.2,9.2]: inst('border_corner',x,y)
    cube('Map title plaque',(0,-10.15,-.42),(18,1.25,.18),ink,.07)
    label(f'{num:02d}  /  {name.upper()}',(0,-10.22,-.31),.47)
    label(subtitle.upper(),(0,-11.05,-.88),.24)
    hero=camera('01 Presentation camera',(25,-34,43),(0,-.6,0),36.8)
    top=camera('02 Overhead layout camera',(0,0,40),(0,0,0),27)
    SC.camera=hero
    light('Warm key',(-8,-10,18),2600,10,(1,.85,.68))
    light('Cool fill',(10,3,12),1900,9,(.69,.83,1))
    light('Back rim',(-2,10,14),2000,8,(1,.93,.81))
    slug=f'{num:02d}_'+name.lower().replace(' ','_')
    SC['design_intent']=subtitle; SC['review_only']=True
    SC['board_dimensions_m']='24 x 18'; SC['gameplay_status']='Visual concept; no collisions or playable logic'
    MAPS.append(dict(number=num,name=name,description=subtitle,scene=SC.name,slug=slug,hero=hero,top=top))

def spawn(x,y,team,a=0):
    cube('Team starting zone',(x,y,.012),(2.7,2.7,.022),blue if team==0 else orange,.12)
    inst('spawn_marker_2m',x,y,z=.024)
    inst('tank_01_azure_scout' if team==0 else 'tank_03_vermilion_heavy',x,y,a,z=.045)

def wall(x,y,length=4,a=0,kind='beech'):
    return inst(f'wall_{kind}_{length}m',x,y,a)

def prop(name,x,y,a=0): return inst(name,x,y,a)

start(1,'Crossfire Court','Three lanes / offset cover / quick flanks')
for x in [-5,5]:
    for y in [-4,4]: wall(x,y,4,90)
for x,y in [(-7,0),(7,0)]: wall(x,y,2)
for x,y in [(-1,-2.5),(1,2.5)]: wall(x,y,2)
for x,y in [(-2,5.5),(2,-5.5)]: prop('wall_round_pillar',x,y)
for x,y in [(-9,6.8),(9,-6.8)]: prop('crate_1m',x,y,10)
spawn(-9,-5,0,-30);spawn(9,5,1,150)
prop('tank_02_mint_cruiser',-1,6.7,-110);prop('tank_05_violet_marksman',2,-6.6,60)

start(2,'Courtyard Keep','Four gates / contested center / outer rotation','moss')
cube('Courtyard stone inset',(0,0,.006),(8,8,.016),concrete)
for y in [-4.5,4.5]:
    for x in [-3.5,3.5]: wall(x,y,4)
for x in [-5,5]:
    for y in [-3,3]: wall(x,y,2,90)
for x in [-5,5]:
    for y in [-4.5,4.5]: prop('pillar_beech',x,y)
for x,y,a in [(-8,1,0),(8,-1,0),(0,7,0),(0,-7,0)]: wall(x,y,2,a,'terracotta')
cube('Central objective plinth',(0,0,.08),(2.4,2.4,.16),wood,.12)
inst('spawn_marker_2m',0,0,z=.18)
label('HOLD',(0,-.2,.175),.38,ink)
spawn(-9,-6,0,-40);spawn(9,6,1,140)
prop('tank_06_ivory_duelist',0,2.6,70);prop('tank_04_saffron_sprinter',8,-5,15)
for x,y in [(-7,6),(7,-6)]: prop('barrels_pair',x,y)

start(3,'Canal Crossings','Three bridges / exposed crossings / split banks')
cube('Recessed turquoise canal',(0,0,.017),(4.6,18,.025),water,.02)
for x in [-2.4,2.4]: cube('Canal coping',(x,0,.10),(.20,18,.2),wood)
for y in [-6,0,6]:
    cube('Flush bridge deck',(0,y,.20),(5.2,3,.38),wood,.07)
    for k in range(-6,7): cube('Bridge plank joint',(k*.38,y,.396),(.018,2.85,.008),ink,0)
    for yy in [y-1.44,y+1.44]: cube('Bridge rim',(0,yy,.43),(5.25,.12,.15),steel)
    for x in [-3.05,3.05]:
        o=cube('Bridge approach',(x,y,.09),(1.2,2.8,.18),wood)
        o.rotation_euler.y=math.radians(8 if x>0 else -8)
for x in [-6,6]:
    for y in [-3,3]: wall(x,y,2,90,'terracotta')
for x,y in [(-9,1.2),(9,-1.2),(-8,-7.4),(8,7.4)]: prop('crate_1m',x,y,12)
spawn(-9,-5,0,-90);spawn(9,5,1,90)
prop('tank_02_mint_cruiser',-6,6,90);prop('tank_07_tangerine_siege',6,-6,-90)

start(4,'Switchback Works','Alternating routes / blind corners / ambush pockets')
for x,side in [(-6,1),(0,-1),(6,1)]:
    for y in [side*5,side*1]: wall(x,y,4,90)
    wall(x,-side*5,2,90)
    prop('wall_round_pillar',x+1.8,-side*1.8)
for x,y in [(-9,6.7),(3,6.7),(-3,-6.7),(9,-6.7)]: prop('crate_1m',x,y)
spawn(-9,-5,0,180);spawn(9,5,1,0)
prop('tank_04_saffron_sprinter',-3,2,180);prop('tank_05_violet_marksman',3,-2,0)
for x,y in [(-3,-3.3),(3,3.3)]: prop('barrels_pair',x,y,90)

start(5,'Freight Exchange','Staggered cargo / bank shots / wide service lanes','concrete')
def container(x,y,a,material):
    root=bpy.data.objects.new('Cargo container',None);COL.objects.link(root)
    objects=[cube('Cargo shell',(0,0,.68),(4,1.6,1.36),material,.08)]
    for xx in [-1.85,1.85]: objects.append(cube('Cargo end frame',(xx,0,.70),(.10,1.67,1.4),steel,.012))
    for xx in [-1.5,-1,-.5,0,.5,1,1.5]:
        for yy in [-.805,.805]: objects.append(cube('Corrugated side',(xx,yy,.68),(.06,.06,1.2),material,.01))
    for o in objects: o.parent=root
    root.location=(x,y,0);root.rotation_euler.z=math.radians(a)
for x,y,a,m in [(-6,4,0,teal),(3,4,0,rust),(-3,-3,0,rust),(6,-3,0,teal),(-7,-1,90,teal),(7,2,90,rust)]: container(x,y,a,m)
for y in [-6.4,6.4]:
    for x in range(-10,11,3): cube('Service lane dash',(x,y,.015),(1.2,.08,.018),cream,.005)
for x,y,a in [(0,0,0),(-1,7,0),(1,-7,0)]: wall(x,y,2,a,'steel')
for x,y in [(-10,2),(10,-1),(-4,7),(4,-7)]: prop('barrels_pair',x,y,90)
spawn(-9,-5.4,0,-45);spawn(9,5.4,1,135)
prop('tank_08_charcoal_command',-2,1,-90);prop('tank_07_tangerine_siege',4,-.5,70)

start(6,'Crater Circuit','Central hazard / ring route / broken cover','sand')
bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=3.5,depth=.08,location=(0,0,.016))
o=link(bpy.context.object);o.name='Dark recessed crater illusion';o.data.materials.append(pit)
for i in range(12):
    a=i*math.tau/12
    o=cube('Crater retaining edge',(3.6*math.cos(a),3.6*math.sin(a),.14),(1.96,.24,.28),wood)
    o.rotation_euler.z=a+math.pi/2
for x,y,a in [(-7,2,90),(7,-2,90),(-2,-6,0),(2,6,0)]: wall(x,y,2,a,'terracotta')
for x,y,a in [(-7,-3,25),(7,3,-155),(-3,6,0),(3,-6,180)]: prop('wall_diagonal',x,y,a)
for x,y in [(-4.8,-2),(4.8,2),(-1,4.8),(1,-4.8)]: prop('rubble_cluster',x,y,35)
spawn(-9,-5,0,-50);spawn(9,5,1,130)
prop('tank_04_saffron_sprinter',-1,-7.3,-90);prop('tank_02_mint_cruiser',1,7.3,90)

if 'Scene' in bpy.data.scenes: bpy.data.scenes.remove(bpy.data.scenes['Scene'])
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file: im.pack()
bpy.context.window.scene=bpy.data.scenes[MAPS[0]['scene']]
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_perspective='CAMERA'
            a.spaces.active.shading.type='MATERIAL'
            a.spaces.active.overlay.show_overlays=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pocket_Armor_Map_Concepts.blend'))
manifest={'title':'Pocket Armor / six map studies','status':'Review concepts; no Godot integration or gameplay validation','source':str(SOURCE.relative_to(OUT.parent.parent)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'asset_spec':{'board_m':[24,18],'units':'meters','assets':'Appended original tank-kit-v1 collections; new editable map geometry','textures':'Existing packed 256 x 256 beech; new materials are procedural PBR constants','license':'Existing project artwork plus newly authored local geometry; no external assets or paid providers','budget':'Review scenes use collection instancing; no runtime performance budget asserted'},'maps':[{k:v for k,v in m.items() if k not in ['hero','top']} for m in MAPS]}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
for m in MAPS:
    sc=bpy.data.scenes[m['scene']];bpy.context.window.scene=sc
    sc.camera=m['hero'];sc.render.filepath=str(OUT/'previews'/f"{m['slug']}.png")
    print('MAP_RENDER_START',m['name'],flush=True);bpy.ops.render.render(write_still=True)
    sc.camera=m['top'];sc.render.resolution_x=1500;sc.render.resolution_y=1150
    sc.render.filepath=str(OUT/'previews'/f"{m['slug']}_overhead.png")
    bpy.ops.render.render(write_still=True)
    sc.camera=m['hero'];sc.render.resolution_x=1600;sc.render.resolution_y=1250
    print('MAP_RENDER_DONE',m['name'],flush=True)
print('ALL_MAPS_COMPLETE',len(MAPS),flush=True)
