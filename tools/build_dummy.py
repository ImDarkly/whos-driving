"""Rebuild original dummy assets with installed Blender; no external packages.
Run: blender --background --python tools/build_dummy.py
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'player'
PREVIEW = ROOT / 'docs' / 'player-previews'
SOURCE = ROOT / 'art' / 'player'
SOURCE.mkdir(parents=True, exist_ok=True)
(ROOT/'art'/'.gdignore').touch()
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .78
    return m

body = material('Body_Repaint', (1, .60, .012))
dark = material('Joints_Charcoal', (.025, .032, .038))
white = material('Details_Ivory', (.96, .95, .85))
# Mark yellow is deliberately independent of the repaintable shell.
mark = material('Mark_SafetyYellow', (1, .76, .012))
parts = []
bindings = {}

def bind(obj, bone):
    parts.append(obj)
    bindings[obj.name] = bone
    return obj

def box(name, center, size, mat, bevel=.02, bone=None, segments=1):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    if bevel:
        mod = o.modifiers.new('Faceted corners', 'BEVEL')
        mod.width = bevel
        mod.segments = segments
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if bone:
        bind(o, bone)
    return o

def joint(name, center, radius, depth, axis, bone):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=depth, location=center)
    o = bpy.context.object
    o.name = name
    if axis == 'X':
        o.rotation_euler[1] = math.pi / 2
    o.data.materials.append(dark)
    bind(o, bone)

box('Torso', (0, 0, .507), (.274, .185, .245), body, .04, 'Root', 1)
box('Pelvis', (0, 0, .363), (.235, .16, .082), dark, .025, 'Root')
joint('Neck', (0, 0, .65), .047, .04, 'Z', 'Root')
box('Head', (0, -.005, .802), (.335, .27, .28), body, .065, 'Head', 2)
for s, x in [('L', -.068), ('R', .068)]:
    box('Eye.' + s, (x, -.143, .813), (.077, .018, .079), white, .013, 'Head')
    box('Pupil.' + s, (x + .012, -.155, .813), (.029, .012, .048), dark, .006, 'Head')

# Thin inset-style quadrant badges on both temples, built in the YZ plane.
for sign in [-1, 1]:
    verts = []
    faces = []
    for q in range(4):
        start = len(verts)
        verts.append((sign * .169, .005, .812))
        for k in range(5):
            a = (q * 90 + k * 22.5) * math.pi / 180
            verts.append((sign * .169, .005 + .068 * math.cos(a), .812 + .068 * math.sin(a)))
        for k in range(4):
            faces.append((start, start+k+1, start+k+2) if sign > 0 else (start, start+k+2, start+k+1))
    mesh = bpy.data.meshes.new('BadgeGeometry')
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(dark)
    mesh.materials.append(mark)
    o = bpy.data.objects.new('CrashMark.' + str(sign), mesh)
    bpy.context.collection.objects.link(o)
    for p in mesh.polygons:
        p.material_index = (p.index // 4) % 2
    bind(o, 'Head')

bones = [('Root', (0, 0, .35), (0, 0, .63), None),
         ('Head', (0, 0, .65), (0, 0, .92), 'Root')]
for suffix, sign in [('L', -1), ('R', 1)]:
    x = sign * .197
    shoulder, elbow, wrist = (x, 0, .592), (sign*.239, 0, .453), (sign*.27, 0, .327)
    hip, knee, ankle = (sign*.071, 0, .35), (sign*.083, 0, .203), (sign*.083, 0, .063)
    for name, a, b, parent in [
        ('UpperArm', shoulder, elbow, 'Root'), ('LowerArm', elbow, wrist, 'UpperArm.'+suffix),
        ('Hand', wrist, (sign*.28, 0, .25), 'LowerArm.'+suffix),
        ('Thigh', hip, knee, 'Root'), ('Shin', knee, ankle, 'Thigh.'+suffix),
        ('Foot', ankle, (sign*.083, -.13, .045), 'Shin.'+suffix)]:
        bones.append((name+'.'+suffix, a, b, parent))
    for name, a, b, width, depth in [
        ('UpperArm', shoulder, elbow, .093, .108), ('LowerArm', elbow, wrist, .088, .094),
        ('Thigh', hip, knee, .103, .125), ('Shin', knee, ankle, .091, .103)]:
        a, b = Vector(a), Vector(b)
        obj = box(name+'.'+suffix, (a+b)/2, (width, depth, (a-b).length-.024), body, .017, name+'.'+suffix)
        obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    box('Hand.'+suffix, (sign*.278, -.007, .291), (.102, .105, .10), body, .026, 'Hand.'+suffix)
    box('Thumb.'+suffix, (sign*.233, -.042, .31), (.044, .061, .057), body, .012, 'Hand.'+suffix)
    box('Foot.'+suffix, (sign*.083, -.051, .039), (.122, .208, .078), body, .018, 'Foot.'+suffix)
    box('Sole.'+suffix, (sign*.083, -.051, .009), (.124, .21, .018), dark, .004, 'Foot.'+suffix)
    for name, pos, radius, depth in [('Shoulder', shoulder, .052, .065), ('Elbow', elbow, .047, .088), ('Hip', hip, .053, .095), ('Knee', knee, .046, .094)]:
        parent = {'Shoulder':'UpperArm', 'Elbow':'LowerArm', 'Hip':'Thigh', 'Knee':'Shin'}[name]+'.'+suffix
        joint(name+'.'+suffix, pos, radius, depth, 'X', parent)

arm = bpy.data.armatures.new('DummySkeleton')
rig = bpy.data.objects.new('CrashDummy', arm)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name, head, tail, parent in bones:
    b = arm.edit_bones.new(name)
    b.head, b.tail = head, tail
    if parent:
        b.parent = arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
    group = o.vertex_groups.new(name=bindings[o.name])
    group.add(list(range(len(o.data.vertices))), 1, 'REPLACE')
    mod = o.modifiers.new('Rigid bone weights', 'ARMATURE')
    mod.object = rig
    o.parent = rig
    o.name = 'Mesh_' + o.name
rig.show_in_front = True
rig.rotation_euler.z = math.pi

def pose(name):
    for p in rig.pose.bones:
        p.rotation_mode = 'XYZ'
        p.rotation_euler = (0, 0, 0)
    # Convert desired world-axis rotations to each rest bone's local axes.
    from mathutils import Matrix
    def rotate(bone, axis, angle):
        p = rig.pose.bones[bone]
        rest = p.bone.matrix_local.to_3x3()
        p.rotation_euler = (rest.inverted() @ Matrix.Rotation(math.radians(angle), 3, axis) @ rest).to_euler()
    if name != 'Stand':
        for s in ['L', 'R']:
            rotate('Thigh.'+s, 'X', -90)
            rotate('Shin.'+s, 'X', 90)
            rotate('UpperArm.'+s, 'X', -12 if name != 'Steer' else -52)
            rotate('LowerArm.'+s, 'X', -72 if name != 'Steer' else -30)
    if name == 'LookSide':
        rotate('Head', 'Z', 70)
    bpy.context.view_layer.update()

# Static named pose clips, rather than invented gameplay animations.
for name in ['Stand', 'Sit', 'Steer', 'LookSide']:
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.new(name)
    pose(name)
    for frame in [1, 2]:
        for p in rig.pose.bones:
            p.keyframe_insert(data_path='rotation_euler', frame=frame, group=p.name)
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, rig.animation_data.action)
    track.mute = True
rig.animation_data.action = None
pose('Stand')
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for o in parts:
    o.select_set(True)
triangles = sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in parts)
assert triangles <= 1500, triangles
bpy.ops.export_scene.gltf(filepath=str(OUT/'crash_dummy.glb'), export_format='GLB',
    use_selection=True, export_animations=True, export_animation_mode='NLA_TRACKS',
    export_force_sampling=True, export_skins=True, export_yup=True)

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.render.resolution_x = 1100
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.world.color = (.32, .32, .32)
scene.view_settings.view_transform = 'AgX'
floor = material('StudioFloor', (.24, .27, .29))
ground = box('Studio Ground', (0,0,-.035), (200,200,.05), floor, 0)
def light(name, position, energy, size):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.shape, data.size = energy, 'DISK', size
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector((0,0,.5))-obj.location).to_track_quat('-Z','Y').to_euler()
light('Key', (1,-3,4), 350, 4)
light('Fill', (-3,-1,2), 220, 3)
light('Rim', (0,2,3), 400, 2)
data = bpy.data.cameras.new('PreviewCamera')
camera = bpy.data.objects.new('PreviewCamera',data)
scene.collection.objects.link(camera)
scene.camera = camera
def render(filename, position, target, scale):
    camera.location = (position[0], -position[1], position[2])
    target = Vector((target[0], -target[1], target[2]))
    camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = scale
    scene.render.filepath = str(PREVIEW/filename)
    bpy.ops.render.render(write_still=True)

pose('Stand')
colors = {'Yellow':(1,.60,.012), 'Red':(.85,.055,.025), 'Blue':(.025,.39,.8), 'Green':(.21,.65,.025)}
for name,color in colors.items():
    m = material('Body_'+name, color)
    m.use_fake_user = True
    (OUT/('body_'+name.lower()+'.tres')).write_text('[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nresource_name = "Body_'+name+'"\nalbedo_color = Color('+', '.join(str(v) for v in (*color,1))+')\nroughness = 0.78\n')
render('standing.png', (1.5,-3,1.4), (0,0,.47), 1.65)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_location = (0,0,.47)
            area.spaces.active.region_3d.view_distance = 1.7
            area.spaces.active.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'crash_dummy.blend'))
pose('Sit')
render('seated.png', (1.6,-3,1.3), (0,-.05,.47), 1.65)
pose('Steer')
render('steering.png', (1.6,-3,1.3), (0,-.05,.47), 1.65)
pose('LookSide')
render('look-side.png', (1.6,-3,1.3), (0,-.05,.47), 1.65)

# A separate inspection scene keeps the car out of the distributable character.
pose('Sit')
clones = []
for i,(name,color) in enumerate(colors.items()):
    material_copy = body.copy()
    material_copy.name = 'Body_'+name
    material_copy.diffuse_color = (*color,1)
    material_copy.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1)
    # Independent rigs and materials for a four-passenger cabin fit study.
    clone = rig.copy()
    clone.data = rig.data.copy()
    scene.collection.objects.link(clone)
    clone.name = 'Passenger_'+name
    clones.append(clone)
    for p in rig.pose.bones:
        clone.pose.bones[p.name].rotation_mode = 'XYZ'
        clone.pose.bones[p.name].rotation_euler = p.rotation_euler.copy()
    clone.location = ((-.48 if i%2==0 else .48), (.15 if i<2 else -.62), 0)
    for o in parts:
        copy = o.copy()
        copy.data = o.data.copy()
        scene.collection.objects.link(copy)
        copy.parent = clone
        copy.modifiers.get('Rigid bone weights').object = clone
        for slot in copy.material_slots:
            if slot.material == body:
                slot.material = material_copy
for o in parts:
    o.hide_render = True
rig.hide_render=True
for i,clone in enumerate(clones):
    clone.location = ((i-1.5)*.65,0,0)
render('four-colors.png', (1,-5,2), (0,-.05,.45), 3.0)
for i,clone in enumerate(clones):
    clone.scale = (1.2, 1.2, 1.2)
    clone.location = ((-.48 if i%2==0 else .48), (.15 if i<2 else -.62), -.24 if i<2 else -.227)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/retro_car/retro_car.glb'))
car_objects = list(bpy.context.selected_objects)
ground.location.z = -.68
render('cabin-exterior.png', (4,-6,3), (0,0,.35), 4.8)
# Roof-hidden inspection only: distribution model and game roof stay untouched.
# An interior camera provides the actual intact-cabin view.
camera.data.type='PERSP'
camera.data.lens=14
for i,clone in enumerate(clones):
    camera.location = Vector((clone.location.x, clone.location.y, .8))
    camera.rotation_euler=(Vector((.48 if i%2==0 else -.48, -.3 if i<2 else .10,.76))-camera.location).to_track_quat('-Z','Y').to_euler()
    for j,c in enumerate(clones):
        for child in c.children:
            child.hide_render = i==j
    scene.render.filepath=str(PREVIEW/('cabin-seat-%d.png'%(i+1)))
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'build/dummy-cabin-study.blend'))
(PREVIEW/'metrics.json').write_text(json.dumps({'triangles':triangles,'mesh_objects':len(parts),'bones':len(bones),'height_m':.942,'head_width_m':.335,'poses':['Stand','Sit','Steer','LookSide']},indent=2)+'\n')
print('DUMMY COMPLETE', triangles, 'triangles')
