import bpy,math,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'tank-kit-v1/Pocket_Armor_Review.blend'))
COL=None
P=None

def mat(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=0;p.inputs['Roughness'].default_value=.95
    return m
dark=mat('Cartoon / ink tracks',(.055,.073,.12))
wheelmat=mat('Cartoon / wheel facets',(.14,.19,.26))
trackmat=mat('Cartoon / tread tabs',(.11,.15,.21))
white=mat('Cartoon / cream stripe',(1,.90,.58))
muzzleblack=mat('Cartoon / muzzle opening',(.025,.035,.065))

def empty(name,parent=None,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None);COL.objects.link(o);o.parent=parent;o.location=loc;return o
def bind(o,name,m,parent=None):
    for c in list(o.users_collection):c.objects.unlink(o)
    COL.objects.link(o);o.name=name;o.parent=parent if parent else P;o.data.materials.append(m)
    for face in o.data.polygons:face.use_smooth=False
    return o
def box(name,loc,dim,m,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bind(bpy.context.object,name,m,parent);o.scale=dim
    return o
def cyl(name,loc,r,d,m,n=6,axis='Z',parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d,location=loc)
    o=bind(bpy.context.object,name,m,parent)
    if axis=='X':o.rotation_euler.y=math.pi/2
    if axis=='Y':o.rotation_euler.x=math.pi/2
    return o
def tapered(name,z,w,l,h,m,n=8):
    if n==8:
        cut=.22;outline=[(-w/2+cut,-l/2),(w/2-cut,-l/2),(w/2,-l/2+cut),(w/2,l/2-cut),(w/2-cut,l/2),(-w/2+cut,l/2),(-w/2,l/2-cut),(-w/2,-l/2+cut)]
    else:outline=[(math.cos(math.tau*i/n)*w/2,math.sin(math.tau*i/n)*l/2) for i in range(n)]
    verts=[(x,y,z) for x,y in outline]+[(x*.82,y*.82,z+h) for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);COL.objects.link(o);o.parent=P;me.materials.append(m);return o
def belt(x,l,w):
    a=l*.5-.22;r=.22
    outline=[(-a,.26+r),(a,.26+r),(a+r*.707,.26+r*.707),(a+r,.26),(a+r*.707,.26-r*.707),(a,.26-r),(-a,.26-r),(-a-r*.707,.26-r*.707),(-a-r,.26),(-a-r*.707,.26+r*.707)]
    n=len(outline);verts=[(x+side*w/2,y,z) for side in [-1,1] for y,z in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new('Low-poly track housing');me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new('Track belt',me);COL.objects.link(o);o.parent=P;me.materials.append(dark)

variants=[('01_azure_scout',(.025,.48,.94),1.12,1.5,8,1.0),('02_mint_cruiser',(.06,.78,.36),1.4,1.75,6,1.0),('03_vermilion_heavy',(.94,.095,.08),1.78,2.03,4,.95),('04_saffron_sprinter',(1,.65,.035),1.02,1.28,8,.78),('05_violet_marksman',(.56,.17,.87),1.22,1.84,6,1.7),('06_ivory_duelist',(.92,.87,.64),1.48,1.66,4,1.05),('07_tangerine_siege',(1,.31,.035),1.70,2.12,8,.69),('08_charcoal_command',(.16,.29,.48),1.56,1.88,4,1.2)]
counts=[]
for ix,(id,color,w,l,n,barrel) in enumerate(variants):
    COL=bpy.data.collections['tank_'+id]
    for o in list(COL.objects):bpy.data.objects.remove(o,do_unlink=True)
    paint=mat('Cartoon / '+id,color)
    P=None;root=empty('tank_'+id);root['asset_id']='tank_'+id;root['kind']='tank';root['snap_grid_m']=1.0
    P=root;hull=empty('Hull',root);P=hull
    tw=.30 if w<1.4 else .36
    for side in [-1,1]:
        x=side*(w/2-tw/2);belt(x,l,tw)
        for y in [-l*.29,0,l*.29]:
            cyl('Road wheel',(x+side*tw*.51,y,.26),.17,.035,wheelmat,6,'X')
        for j in range(6):box('Tread top link',(x,-l*.34+j*l*.68/5,.49),(tw,.075,.028),trackmat)
    tapered('Lower hull',.27,w*.82,l*.83,.36,paint)
    tapered('Upper deck',.55,w*.78,l*.66,.25,paint)
    for side in [-1,1]:box('Track guard',(side*w*.39,0,.56),(tw*.7,l*.84,.09),paint)
    box('Hull stripe',(0,-l*.30,.803),(.16,l*.15,.014),white)
    P=root;turret=empty('TurretPivot',root,(0,-.045,.81));P=turret
    if n==4:
        o=tapered('Armored turret',0,w*.74,l*.46,.48,paint,8)
    else:o=tapered('Faceted turret',0,w*.81,w*.83,.48,paint,n)
    cyl('Commander hatch',(0,.05,.50),w*.13,.07,paint,6)
    box('Turret stripe',(w*.21,.04,.493),(.12,.28,.012),white)
    for bx in ([-.18,.18] if ix==5 else [0]):
        gun=empty('BarrelRecoil',turret,(bx,-.22,.24));P=gun
        radius=.12 if ix!=6 else .24
        cyl('Cannon tube',(0,-barrel/2,0),radius,barrel,paint,6,'Y')
        cyl('Muzzle rim',(0,-barrel+.015,0),radius*1.16,.11,paint,6,'Y')
        cyl('Bore shadow',(0,-barrel-.046,0),radius*.73,.008,muzzleblack,6,'Y')
        empty('Muzzle',gun,(0,-barrel-.08,0))
    turret.rotation_euler.z=math.radians([-12,14,-15,18,-8,12,-12,12][ix])
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in COL.objects if o.type=='MESH')
    counts.append({'tank':id,'static_triangles':tris,'objects':len(COL.objects)})

# Flatten every surface in the arena kit so the tanks and environment share one style.
for m in bpy.data.materials:
    if not m.use_nodes:continue
    p=m.node_tree.nodes.get('Principled BSDF')
    if not p:continue
    p.inputs['Metallic'].default_value=0;p.inputs['Roughness'].default_value=.95
    for link in list(m.node_tree.links):
        if link.to_socket==p.inputs['Base Color']:m.node_tree.links.remove(link)
    if m.name=='Beech with packed grain':p.inputs['Base Color'].default_value=(.72,.42,.16,1)
    if m.name.startswith('Maple floor'):p.inputs['Base Color'].default_value=(.66,.48,.27,1)
for o in list(bpy.data.objects):
    if o.type!='MESH':continue
    if o.name.startswith(('Deck rivet','Cap bolt','Small sand pebble','Brass screw','Screw slot')):
        bpy.data.objects.remove(o,do_unlink=True);continue
    for mod in list(o.modifiers):
        if mod.type=='BEVEL':mod.segments=1;mod.width=min(mod.width,.025)
        elif mod.type=='WEIGHTED_NORMAL':o.modifiers.remove(mod)
    for face in o.data.polygons:face.use_smooth=False
for sc in bpy.data.scenes:
    sc.view_settings.view_transform='Standard';sc.view_settings.look='Medium High Contrast' if 'Medium High Contrast' in sc.view_settings.bl_rna.properties['look'].enum_items.keys() else 'None'
    sc.render.engine='CYCLES';sc.cycles.samples=12
    sc.render.resolution_percentage=75
    for o in sc.objects:
        if o.type=='LIGHT':o.data.color=(1,1,1)
bpy.context.window.scene=bpy.data.scenes['02 | TANK LINEUP']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Cartoon_Asset_Source.blend'))
(OUT/'geometry_counts.json').write_text(json.dumps(counts,indent=2))
for name,outname in [('02 | TANK LINEUP','cartoon_lineup'),('01 | ASSEMBLED ARENA','cartoon_arena'),('03 | MODULAR ARENA KIT','cartoon_modules')]:
    sc=bpy.data.scenes[name];bpy.context.window.scene=sc;sc.render.filepath=str(OUT/'previews'/f'{outname}.png');bpy.ops.render.render(write_still=True)
print('CARTOON_SOURCE_COMPLETE',flush=True)
