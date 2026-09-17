import bpy, math, random, json, os, hashlib
from pathlib import Path
from mathutils import Vector, Quaternion

OUT = Path(__file__).resolve().parent
(OUT / 'exports').mkdir(exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
(OUT / 'textures').mkdir(exist_ok=True)
random.seed(42)
bpy.ops.wm.read_factory_settings(use_empty=True)
LIB = {}
META = []
CURRENT = None
PARENT = None

def material(name, color, metal=0, rough=.4):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m

rubber = material('Graphite rubber', (.055,.072,.083), 0,.65)
linkmat = material('Tread ridges', (.115,.143,.15),.25,.5)
steel = material('Satin gunmetal', (.19,.24,.27),.65,.28)
dark = material('Recesses', (.015,.024,.03),.15,.5)
cream = material('Warm ivory insignia', (.95,.91,.75),.05,.32)
yellow = material('Safety ochre', (1,.61,.06),.15,.4)
red = material('Terracotta', (.66,.22,.11),0,.7)
rededge = material('Terracotta end grain', (.82,.34,.18),0,.65)
sand = material('Sand tile', (.69,.54,.34),0,.86)
floor_mats = [material('Maple floor %02d'%i, (.56+i*.009,.39+i*.008,.22+i*.006),0,.68) for i in range(6)]
brass = material('Warm brass', (.68,.44,.13),.7,.28)
textmat = material('Printed warm white', (.82,.85,.82),0,.9)
ink = material('Printed charcoal', (.09,.15,.17),0,.9)
backdrop = material('Midnight blue backdrop', (.034,.059,.073),0,.9)
pedestalmat = material('Display slate', (.071,.113,.13),.1,.55)
pitmat = material('Pit interior', (.045,.027,.019),0,1)

wood = material('Beech with packed grain', (.73,.48,.25),0,.52)
size = 256
img = bpy.data.images.new('Beech grain', width=size,height=size)
pixels=[]
for y in range(size):
    for x in range(size):
        u=x/size; v=y/size
        g=math.sin(u*210+2*math.sin(v*7)+math.sin(u*17+v*5))
        g2=math.sin(u*750+math.sin(v*10)*3)
        k=1+.038*g+.014*g2+random.uniform(-.012,.012)
        pixels.extend((.77*k,.56*k,.32*k,1))
img.pixels=pixels
img.filepath_raw=str(OUT/'textures/beech_grain.png'); img.file_format='PNG'; img.save(); img.pack()
nt=wood.node_tree
tx=nt.nodes.new('ShaderNodeTexImage'); tx.image=img
nt.links.new(tx.outputs['Color'],nt.nodes.get('Principled BSDF').inputs['Base Color'])

def bind(obj, name, mat=None, parent=None):
    obj.name=name
    for c in list(obj.users_collection): c.objects.unlink(obj)
    CURRENT.objects.link(obj)
    if mat: obj.data.materials.append(mat)
    obj.parent=parent if parent else PARENT
    return obj

def empty(name, loc=(0,0,0), parent=None):
    o=bpy.data.objects.new(name,None); CURRENT.objects.link(o); o.location=loc
    o.parent=parent if parent else PARENT
    o.empty_display_size=.18
    return o

def cube(name, loc, dim, mat, bevel=.04, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=bind(bpy.context.object,name,mat,parent)
    o.dimensions=dim
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Soft toy edges','BEVEL'); m.width=bevel; m.segments=2
        m=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o

def cyl(name,loc,radius,depth,mat,vertices=16,axis='Z',parent=None,bevel=.025):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=bind(bpy.context.object,name,mat,parent)
    if axis=='X': o.rotation_euler[1]=math.pi/2
    if axis=='Y': o.rotation_euler[0]=math.pi/2
    if bevel:
        m=o.modifiers.new('Rounded rim','BEVEL'); m.width=bevel; m.segments=2
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o

def sphere(name,loc,scale,mat,parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=loc)
    o=bind(bpy.context.object,name,mat,parent); o.scale=scale
    for p in o.data.polygons: p.use_smooth=True
    return o

def text(name,body,loc,size,mat,align='CENTER'):
    cv=bpy.data.curves.new(name,'FONT'); cv.body=body; cv.size=size; cv.align_x=align
    cv.extrude=0; cv.space_character=1.15
    o=bpy.data.objects.new(name,cv); CURRENT.objects.link(o); o.location=loc
    cv.materials.append(mat)
    return o

def asset(name,kind,footprint,description):
    global CURRENT,PARENT
    CURRENT=bpy.data.collections.new(name); LIB[name]=CURRENT
    PARENT=None
    root=empty(name); PARENT=root
    root['asset_id']=name; root['kind']=kind; root['snap_grid_m']=1.0
    root['description']=description
    META.append(dict(id=name,kind=kind,footprint_m=footprint,description=description))
    return root

variants=[
 ('01_azure_scout','AZURE / SCOUT',(.055,.43,.78),1.12,1.50,'round',1.00),
 ('02_mint_cruiser','MINT / CRUISER',(.18,.63,.43),1.40,1.75,'hex',1.00),
 ('03_vermilion_heavy','RED / BULLDOG',(.8,.085,.06),1.78,2.03,'box',.95),
 ('04_saffron_sprinter','GOLD / SPRINTER',(1,.60,.035),1.02,1.28,'round',.78),
 ('05_violet_marksman','VIOLET / NEEDLE',(.43,.20,.67),1.22,1.84,'hex',1.70),
 ('06_ivory_duelist','IVORY / DUELIST',(.83,.83,.72),1.48,1.66,'twin',1.05),
 ('07_tangerine_siege','ORANGE / MORTAR',(.95,.28,.045),1.70,2.12,'siege',.69),
 ('08_charcoal_command','SLATE / COMMAND',(.18,.25,.3),1.56,1.88,'diamond',1.2),
]

for idx,(name,label,color,w,l,shape,barrel) in enumerate(variants):
    paint=material(label+' enamel',color,.28,.31)
    lighter=material(label+' edge panels',tuple(min(1,c*1.18+.04) for c in color),.2,.35)
    root=asset('tank_'+name,'tank',[w,l],label+'; articulated turret, recoil barrel and muzzle marker')
    body=empty('Hull')
    PARENT=body
    trackw=.26 if w<1.4 else .32
    for side in (-1,1):
        xx=side*(w/2-trackw/2)
        cube('Track belt', (xx,0,.26),(trackw,l,.46),rubber,.17)
        for yy in [-l*.34,-l*.11,l*.11,l*.34]:
            cyl('Road wheel',(xx+side*trackw*.48,yy,.26),.17,.035,steel,12,'X')
            cyl('Wheel hub',(xx+side*trackw*.56,yy,.26),.065,.045,brass,12,'X',bevel=.008)
        n=10 if l<1.7 else 13
        for k in range(n):
            yy=-l*.41+k*l*.82/(n-1)
            cube('Tread top link',(xx,yy,.483),(trackw+.015,.075,.037),linkmat,.01)
            cube('Tread sole link',(xx,yy,.042),(trackw+.015,.075,.035),linkmat,.008)
        for yy in [-l*.475,l*.475]:
            for zz in [.17,.28,.38]: cube('Tread end link',(xx,yy,zz),(trackw+.012,.045,.05),linkmat,.012)
    cube('Lower hull',(0,0,.40),(w*.73,l*.86,.35),paint,.13)
    cube('Upper deck',(0,-.015,.65),(w*.72,l*.74,.27),paint,.10)
    for side in [-1,1]:
        cube('Track guard',(side*w*.4,0,.57),(trackw*.9,l*.91,.11),lighter,.04)
        cube('Front lamp surround',(side*w*.28,-l*.39,.67),(.16,.08,.13),steel,.03)
        cube('Front lamp',(side*w*.28,-l*.436,.68),(.11,.02,.075),cream,.01)
        cyl('Exhaust',(side*w*.24,l*.34,.68),.055,.19,steel,12)
    for k in range(5): cube('Rear engine grille',((k-2)*.105,l*.28,.8),(.052,.28,.025),dark,.006)
    cube('Hull stripe',(0,-l*.28,.798),(.095,l*.22,.012),cream,.005)
    for side in [-1,1]:
        for yy in [-l*.22,l*.22]: cyl('Deck rivet',(side*w*.30,yy,.8),.024,.02,brass,8,bevel=.004)
    PARENT=root
    turret=empty('TurretPivot',(0,-.045,.82))
    turret['animation_axis']='local Z; exported Godot Y'
    PARENT=turret
    cyl('Turret bearing',(0,0,0),w*.28,.13,steel,24)
    if shape=='round':
        cyl('Round turret',(0,0,.20),w*.34,.39,paint,32,bevel=.06)
    elif shape in ['hex','diamond']:
        o=cyl('Faceted turret',(0,0,.21),w*.37,.41,paint,6 if shape=='hex' else 4,bevel=.05)
        o.scale.y=1.16
        o.rotation_euler[2]=math.pi/6 if shape=='hex' else math.pi/4
    elif shape=='siege':
        cube('Siege mantlet',(0,.07,.18),(w*.64,l*.35,.38),paint,.1)
    else:
        cube('Armored turret',(0,0,.21),(w*.63,l*.39,.42),paint,.09)
        for side in [-1,1]: cube('Turret cheek',(side*w*.29,-.04,.23),(.16,l*.30,.28),lighter,.035)
    cyl('Commander hatch',(0,.08,.455),w*.13,.065,lighter,16)
    cube('Hatch handle',(0,.09,.502),(.15,.055,.034),steel,.016)
    cube('Turret identity stripe',(w*.19,.06,.438),(.06,.28,.014),cream,.003)
    if shape in ['box','diamond','siege']:
        cyl('Antenna base',(-w*.20,.18,.44),.038,.08,steel,12)
        cyl('Whip antenna',(-w*.20,.18,.69),.010,.47,dark,8,bevel=0)
        sphere('Antenna tip',(-w*.20,.18,.934),(.023,.023,.023),cream)
    for bx in ([-.17,.17] if shape=='twin' else [0]):
        gun=empty('BarrelRecoil'+('_L' if bx<0 else '_R' if bx>0 else ''),(bx,-.22,.23))
        PARENT=gun
        r=.105 if shape!='siege' else .22
        cyl('Barrel collar',(0,-.12,0),r*1.35,.25,paint,16,'Y')
        cyl('Cannon tube',(0,-barrel*.5,0),r,barrel,steel if shape=='siege' else paint,16,'Y')
        cyl('Muzzle rim',(0,-barrel,0),r*1.19,.13,steel,16,'Y')
        cyl('Bore shadow',(0,-barrel-.071,0),r*.76,.008,dark,16,'Y',bevel=0)
        empty('Muzzle',(0,-barrel-.08,0))
        PARENT=turret
    turret.rotation_euler.z=math.radians([-12,14,-15,18,-8,12,-12,12][idx])
    PARENT=root
    root['turret_color']=list(color)

def block(name,dim,mat=wood):
    asset(name,'arena module',list(dim[:2]),'Bottom-center pivot; 1 m snap grid')
    cube('Block',(0,0,dim[2]/2),dim,mat,.055)

block('wall_beech_1m',(1,1,1.1))
block('wall_beech_2m',(2,1,1.1))
block('wall_beech_4m',(4,1,1.1))
block('wall_low_2m',(2,1,.5))
block('pillar_beech',(1,1,1.6))
asset('wall_corner_L','arena module',[2,2],'Two arms on 1 m grid; bottom-center pivot')
cube('Corner long arm',(-.5,0,.55),(1,2,1.1),wood,.055)
cube('Corner short arm',(.5,-.5,.55),(1,1,1.1),wood,.055)
asset('wall_junction_T','arena module',[3,2],'Three-way junction')
cube('Junction crossbar',(0,-.5,.55),(3,1,1.1),wood,.055)
cube('Junction stem',(0,.5,.55),(1,1,1.1),wood,.055)
asset('wall_round_pillar','arena module',[1,1],'Rounded bank-shot obstacle')
cyl('Round beech pillar',(0,0,.55),.5,1.1,wood,24,bevel=.05)
asset('wall_diagonal','arena module',[2,2],'45 degree solid prism; bottom-center pivot')
verts=[(-1,-1,0),(1,-1,0),(-1,1,0),(-1,-1,1.1),(1,-1,1.1),(-1,1,1.1)]
mesh=bpy.data.meshes.new('Wedge'); mesh.from_pydata(verts,[],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]); mesh.update()
o=bpy.data.objects.new('Diagonal wedge',mesh); CURRENT.objects.link(o); o.parent=PARENT; mesh.materials.append(wood)
m=o.modifiers.new('Soft edges','BEVEL'); m.width=.05;m.segments=2;o.modifiers.new('Normals','WEIGHTED_NORMAL')
block('wall_terracotta_1m',(1,1,1.1),red)
asset('wall_terracotta_2m','arena module',[2,1],'Two-course destructible-looking brick wall; intact geometry')
for row in range(2):
    for x in range(2): cube('Clay brick',(-.5+x,0,.27+row*.55),(.975,.98,.525),red if (x+row)%2 else rededge,.04)
asset('wall_steel_2m','arena module',[2,1],'Metal bank-shot barrier')
cube('Steel barrier',(0,0,.55),(2,1,1.1),steel,.08)
for side in [-1,1]:
    cube('Safety edge',(side*.84,0,1.115),(.13,.82,.026),yellow,.01)
    for y in [-.34,.34]: cyl('Cap bolt',(side*.75,y,1.12),.045,.03,brass,12)
asset('floor_maple_2m','floor',[2,2],'2 m floor tile, surface at Z=0; tile below pivot')
for j in range(4): cube('Maple plank',(0,-.75+j*.5,-.075),(2,.496,.15),floor_mats[j],.007)
asset('floor_sand_2m','floor',[2,2],'2 m textured sand inset, surface at Z=0')
cube('Sand tile',(0,0,-.075),(2,2,.15),sand,.02)
for i in range(24):
    x=random.uniform(-.88,.88);y=random.uniform(-.88,.88)
    sphere('Small sand pebble',(x,y,.006),(.018,.029,.009),wood)
asset('pit_2m','arena module',[2,2],'Recessed pit; replace floor tile; visual only, collision deferred')
cube('Dark pit floor',(0,0,-.32),(2,2,.1),pitmat,.015)
for s in [-1,1]:
    cube('Pit edge',(s*.94,0,-.12),(.12,2,.26),wood,.016)
    cube('Pit edge',(0,s*.94,-.12),(1.8,.12,.26),wood,.016)
asset('border_2m','arena module',[2,.35],'Arena perimeter rail')
cube('Perimeter rail',(0,0,.28),(2,.35,.56),wood,.055)
cube('Rail inlay',(0,0,.565),(1.83,.09,.02),cream,.01)
asset('border_corner','arena module',[.7,.7],'Corner post for rail system')
cube('Corner post',(0,0,.35),(.7,.7,.7),wood,.065)
cyl('Brass screw',(0,0,.71),.072,.024,brass,16)
cube('Screw slot',(0,0,.726),(.09,.016,.003),dark,.001)
asset('crate_1m','prop',[1,1],'Wooden supply crate')
cube('Crate body',(0,0,.48),(.92,.92,.96),wood,.045)
for s in [-1,1]:
    cube('Top strap',(s*.32,0,.98),(.12,.99,.06),rededge,.012)
    cube('Face strap',(s*.32,-.48,.5),(.12,.06,.95),rededge,.012)
cube('Crate label',(0,-.518,.55),(.3,.02,.27),cream,.015)
asset('barrels_pair','prop',[1,.6],'Two banded toy fuel drums')
for x in [-.26,.26]:
    cyl('Drum',(x,0,.35),.23,.7,red,20)
    for z in [.13,.56]: cyl('Drum band',(x,0,z),.243,.06,steel,20,bevel=.012)
    cyl('Drum cap',(x+.075,0,.71),.04,.024,brass,12)
asset('barricade_2m','prop',[2,.65],'Low striped barricade')
for x in [-.7,.7]: cube('Barrier foot',(x,0,.14),(.24,.65,.28),steel,.04)
cube('Barrier beam',(0,0,.50),(2,.26,.47),yellow,.04)
for x in [-.72,-.24,.24,.72]:
    o=cube('Dark stripe',(x,-.138,.5),(.19,.018,.4),dark,.005);o.rotation_euler.y=-.25
asset('rubble_cluster','prop',[1.5,1],'Broken terracotta rubble')
for i,(x,y,s) in enumerate([(-.5,-.2,.35),(0,.15,.48),(.43,-.13,.32),(.5,.3,.25),(-.3,.3,.22)]):
    o=cube('Clay fragment',(x,y,s*.32),(s,s*.72,s*.6),red if i%2 else rededge,.03);o.rotation_euler.z=i*.72
asset('mine_disc','gameplay prop',[.5,.5],'Separate cap and body; no scripted functionality')
cyl('Mine base',(0,0,.075),.25,.15,steel,24)
cyl('Mine cap',(0,0,.17),.15,.07,yellow,16)
cyl('Mine center',(0,0,.216),.06,.023,red,12)
asset('shell_standard','gameplay prop',[.16,.42],'Shell forward -Y; centered at origin')
cyl('Shell casing',(0,0,.09),.08,.3,brass,12,'Y',bevel=.015)
sphere('Shell tip',(0,-.17,.09),(.08,.12,.08),cream)
asset('shell_rocket','gameplay prop',[.3,.7],'Rocket forward -Y; centered at origin')
cyl('Rocket body',(0,0,.14),.115,.46,steel,12,'Y')
sphere('Rocket nose',(0,-.26,.14),(.115,.17,.115),red)
for s in [-1,1]: cube('Rocket fin',(s*.12,.19,.14),(.14,.17,.045),red,.015)
asset('spawn_marker_2m','gameplay prop',[2,2],'Visual ground marker overlay')
for s in [-1,1]:
    for t in [-1,1]:
        cube('Corner mark',(s*.78,t*.61,.012),(.06,.40,.024),cream,.007)
        cube('Corner mark',(s*.61,t*.78,.012),(.40,.06,.024),cream,.007)

def instance(name,loc=(0,0,0),angle=0):
    o=bpy.data.objects.new(name+'_instance',None); CURRENT.objects.link(o)
    o.instance_type='COLLECTION';o.instance_collection=LIB[name];o.location=loc;o.rotation_euler.z=math.radians(angle)
    return o

def new_scene(name):
    global CURRENT,PARENT
    sc=bpy.data.scenes.new(name); bpy.context.window.scene=sc
    CURRENT=bpy.data.collections.new(name+' | stage');sc.collection.children.link(CURRENT);PARENT=None
    sc.render.engine='CYCLES';sc.cycles.samples=32;sc.cycles.use_denoising=True
    sc.render.resolution_x=1800;sc.render.resolution_y=1350;sc.render.resolution_percentage=100
    sc.world=bpy.data.worlds.new(name+' world');sc.world.use_nodes=True
    sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.45,.52,1)
    sc.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    sc.view_settings.view_transform='AgX'
    sc.render.image_settings.file_format='PNG'
    return sc

def camera(sc,loc,target,scale):
    data=bpy.data.cameras.new('Camera');o=bpy.data.objects.new('Camera',data);CURRENT.objects.link(o)
    o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO';data.ortho_scale=scale;data.lens=40;sc.camera=o
    return o

def area(name,loc,power,size,color=(1,1,1)):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    o=bpy.data.objects.new(name,data);CURRENT.objects.link(o);o.location=loc
    o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()

def lighting():
    area('Large warm softbox',(-8,-10,18),2400,10,(1,.85,.66))
    area('Cool fill',(10,3,12),1800,9,(.69,.83,1))
    area('Back rim',(-2,10,14),1800,8,(1,.93,.81))

arena=new_scene('01 | ASSEMBLED ARENA')
cube('Studio ground',(0,0,-.89),(200,200,.2),backdrop,.01)
cube('Beech game board',(0,0,-.57),(24.8,18.8,.35),wood,.14)
for side in [-1,1]:
    cube('Board side fascia',(side*12.2,0,-.20),(.4,18.8,.42),wood,.035)
    cube('Board end fascia',(0,side*9.2,-.20),(24,.4,.42),wood,.035)
pitcoords={(3,2),(4,2),(8,6),(9,6)}
for ix in range(12):
    for iy in range(9):
        instance('pit_2m' if (ix,iy) in pitcoords else 'floor_maple_2m',(-11+ix*2,-8+iy*2,0))
for x in range(-11,12,2):
    for y in [-9.2,9.2]: instance('border_2m',(x,y,0))
for y in range(-8,9,2):
    for x in [-12.2,12.2]: instance('border_2m',(x,y,0),90)
for x in [-12.2,12.2]:
    for y in [-9.2,9.2]: instance('border_corner',(x,y,0))
walls=[('wall_beech_4m',(-7,-1,0),90),('wall_beech_4m',(-7,4,0),0),
('wall_beech_2m',(-3,3,0),90),('wall_corner_L',(0,-.5,0),90),
('wall_beech_4m',(4,1,0),90),('wall_beech_2m',(7,-4,0),0),
('wall_beech_2m',(7,-6,0),90),('wall_diagonal',(-1,6,0),180),
('wall_steel_2m',(0,-5,0),0),('wall_terracotta_2m',(8,5.5,0),0),
('wall_terracotta_1m',(6.5,5.5,0),0),('wall_round_pillar',(-10,-6,0),0),
('wall_round_pillar',(10,1,0),0),('wall_beech_2m',(-3,-7,0),0)]
for n,p,a in walls: instance(n,p,a)
placements=[(-8.5,-5,35),(-9,6,-130),(7,7.4,160),(2.1,-7,-25),(9,-1.8,60),(-3,.3,-40),(1,3.8,-100),(9,-6.8,30)]
for variant,(x,y,a) in zip(variants,placements): instance('tank_'+variant[0],(x,y,.015),a)
for n,p,a in [('crate_1m',(-10,3,0),8),('crate_1m',(-10.2,1.9,0),-5),('barrels_pair',(10,7,0),90),('rubble_cluster',(9,3.2,0),45),('mine_disc',(-2,-3,0),0),('mine_disc',(5,-5.5,0),0),('barricade_2m',(3,7.5,0),0),('shell_standard',(-5,-3,.2),-60),('shell_standard',(-4,-2.4,.2),-60)]: instance(n,p,a)
camera(arena,(25,-34,40),(0,0,0),34.5);lighting()
arena.render.filepath=str(OUT/'previews/01_arena.png')

roster=new_scene('02 | TANK LINEUP')
roster.render.resolution_y=1250
cube('Backdrop',(0,0,-.4),(100,100,.2),backdrop,.01)
for i,v in enumerate(variants):
    x=(i%4-1.5)*4.5; y=2.55-(i//4)*5.5
    cube('Tank display plinth',(x,y,-.17),(3.8,4.35,.32),pedestalmat,.13)
    instance('tank_'+v[0],(x,y+.25,0),-20)
    text('Tank label',v[1],(x,y-1.54,.025),.235,textmat)
    text('Tank class',f'{v[3]:.2f} m WIDE  /  '+('LIGHT' if i in [0,3] else 'HEAVY' if i in [2,6] else 'SPECIALIST'),(x,y-1.94,.027),.125,textmat)
text('Title','POCKET ARMOR',(0,6.95,0),.72,textmat)
text('Subtitle','TANK STUDIES   /   8 SILHOUETTES   /   ROTATING TURRETS',(0,6.25,0),.21,textmat)
text('Footer','BLENDER ASSET REVIEW   -   INSPIRED BY WII PLAY TANKS!',(0,-6.4,0),.19,textmat)
camera(roster,(5,-16,28),(0,.5,0),22);lighting()
roster.render.filepath=str(OUT/'previews/02_tank_lineup.png')

kit=new_scene('03 | MODULAR ARENA KIT')
kit.render.resolution_x=2000;kit.render.resolution_y=1550
cube('Backdrop',(0,0,-.55),(100,100,.2),backdrop,.01)
module_names=[n for n in LIB if not n.startswith('tank_')]
for i,n in enumerate(module_names):
    x=(i%5-2)*5.1;y=8-(i//5)*4.6
    cube('Module plinth',(x,y,-.3),(4.65,4.16,.22),pedestalmat,.1)
    instance(n,(x,y+.2,.20 if n=='pit_2m' else 0))
    short=n.replace('wall_','').replace('_',' ').upper()
    text('Module name',short,(x,y-1.28,-.175),.20,textmat)
    info=next(a for a in META if a['id']==n)
    text('Module dimensions',('%.2g x %.2g m'%tuple(info['footprint_m'][:2])),(x,y-1.63,-.174),.15,textmat)
text('Kit title','BUILD THE BATTLEFIELD',(0,11.7,0),.68,textmat)
text('Kit subtitle',f'{len(module_names)} MODULAR PIECES   /   METER SCALE   /   REUSABLE COLLECTIONS',(0,10.9,0),.23,textmat)
camera(kit,(0,-18,40),(0,.3,0),36.5);lighting()
kit.render.filepath=str(OUT/'previews/03_modular_kit.png')

top=new_scene('04 | TOP DOWN LAYOUT')
for obj in arena.collection.all_objects:
    if obj.type not in ['CAMERA','LIGHT']: CURRENT.objects.link(obj)
camera(top,(0,0,38),(0,0,0),28)
lighting();top.render.filepath=str(OUT/'previews/04_top_down.png')

export_scene=bpy.data.scenes.new('Export temporary')
bpy.context.window.scene=export_scene
for name,col in LIB.items():
    export_scene.collection.children.link(col)
    bpy.ops.object.select_all(action='DESELECT')
    for o in col.objects: o.select_set(True)
    bpy.context.view_layer.objects.active=next(o for o in col.objects if o.parent is None)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'exports'/f'{name}.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_yup=True,export_animations=False,export_extras=True)
    deps=bpy.context.evaluated_depsgraph_get()
    tris=0
    for o in col.objects:
        if o.type=='MESH':
            me=o.evaluated_get(deps).to_mesh();me.calc_loop_triangles();tris+=len(me.loop_triangles);o.evaluated_get(deps).to_mesh_clear()
    row=next(a for a in META if a['id']==name)
    row['triangles']=tris
    row['glb']=f'exports/{name}.glb'
    row['sha256']=hashlib.sha256((OUT/row['glb']).read_bytes()).hexdigest()
    export_scene.collection.children.unlink(col)
bpy.context.window.scene=arena
bpy.data.scenes.remove(export_scene)
if 'Scene' in bpy.data.scenes: bpy.data.scenes.remove(bpy.data.scenes['Scene'])
for sc in bpy.data.scenes:
    sc.unit_settings.system='METRIC';sc.unit_settings.scale_length=1
for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type=='VIEW_3D':
            ar.spaces.active.region_3d.view_perspective='CAMERA'
            ar.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Pocket_Armor_Review.blend'))
manifest={'name':'Pocket Armor modular toy tank kit','version':'0.1.0-review','status':'Review build; not imported to Godot','source':'Original geometry authored locally in Blender; Wii Play Tanks! is a visual reference only. No extracted game assets.','units':'meters','blender_up':'Z','blender_forward':'-Y','glb_up':'Y','glb_forward':'+Z (converted from Blender -Y)','snap_grid_m':1,'floor_tile_m':2,'texture_budget':'One packed 256x256 beech image; other surfaces use glTF PBR materials','triangle_policy':{'tank_max':20000,'module_max':10000},'assets':META}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
for sc in [arena,roster,kit,top]:
    bpy.context.window.scene=sc
    print('RENDER_START',sc.name,flush=True)
    bpy.ops.render.render(write_still=True)
    print('RENDER_DONE',sc.name,flush=True)
bpy.context.window.scene=arena
print('TANK_KIT_COMPLETE',len(META),flush=True)
