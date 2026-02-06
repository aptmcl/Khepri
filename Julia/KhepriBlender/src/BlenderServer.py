bl_info = {
    "name": "Khepri",
    "author": "António Leitão",
    "version": (1, 1),
    "blender": (5, 0, 0),
    "location": "Scripting > Khepri",
    "description": "Khepri connection to Blender",
    "warning": "",
    "wiki_url": "",
    "category": "Tools",
}

# To easily test this, on a command prompt do:
# "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" --python BlenderServer.py
# To test this while still allowing redefinitions do:
# "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe"
# and then, in Blender's Python console:
# import os
# __file__=os.path.join(os.getcwd(), "src")
# exec(open("BlenderServer.py").read())

# This loads the shared part of the Khepri server
# PS: Don't even try to load that as a module. You will get separate namespaces.
import os
exec(open(os.path.join(os.path.dirname(__file__), "KhepriServer.py")).read())

# Now comes the Blender-specific server
from bpy import ops, data as D, context as C
import bpy
import bmesh
from math import pi
from mathutils import Vector, Matrix, Quaternion
import addon_utils
# We will use BlenderKit to download materials.
# After activating a BlenderKit account (from addon BlenderKit)
#blenderkit = addon_utils.enable("blenderkit")
#dynamicsky = addon_utils.enable("lighting_dynamic_sky")
#sunposition = addon_utils.enable("sun_position")

# level = 0
# def trace(func):
#     name = func.__name__
#     def wrapper(*args, **kwargs):
#         global level
#         print('>'*(2**level), name, '(', args, ';', kwargs, ')')
#         level += 1
#         try:
#             result = func(*args, **kwargs)
#             print('<'*(2**(level-1)), result)
#             return result
#         finally:
#             level -= 1
#     return wrapper

def download_blenderkit_material(asset_ref):
    from blenderkit import paths, append_link, utils, version_checker, rerequests
    import requests
    def create_asset_data(rdata, asset_type):
        asset_data = {}
        for r in rdata['results']:
            if r['assetType'] == asset_type and len(r['files']) > 0:
                furl = None
                tname = None
                allthumbs = []
                durl, tname = None, None
                for f in r['files']:
                    if f['fileType'] == 'thumbnail':
                        tname = paths.extract_filename_from_url(f['fileThumbnailLarge'])
                        small_tname = paths.extract_filename_from_url(f['fileThumbnail'])
                        allthumbs.append(tname)  # TODO just first thumb is used now.
                    tdict = {}
                    for i, t in enumerate(allthumbs):
                        tdict['thumbnail_%i'] = t
                    if f['fileType'] == 'blend':
                        durl = f['downloadUrl'].split('?')[0]
                        # fname = paths.extract_filename_from_url(f['filePath'])
                if durl and tname:
                    tooltip = blenderkit.search.generate_tooltip(r)
                    r['author']['id'] = str(r['author']['id'])
                    asset_data = {'thumbnail': tname,
                                  'thumbnail_small': small_tname,
                                  # 'thumbnails':allthumbs,
                                  'download_url': durl,
                                  'id': r['id'],
                                  'asset_base_id': r['assetBaseId'],
                                  'assetBaseId': r['assetBaseId'],
                                  'name': r['name'],
                                  'asset_type': r['assetType'],
                                  'tooltip': tooltip,
                                  'tags': r['tags'],
                                  'can_download': r.get('canDownload', True),
                                  'verification_status': r['verificationStatus'],
                                  'author_id': r['author']['id'],
                                  # 'author': r['author']['firstName'] + ' ' + r['author']['lastName']
                                  # 'description': r['description'],
                                  }
                    asset_data['downloaded'] = 0
                    # parse extra params needed for blender here
                    params = utils.params_to_dict(r['parameters'])
                    if asset_type == 'model':
                        if params.get('boundBoxMinX') != None:
                            bbox = {
                                'bbox_min': (
                                    float(params['boundBoxMinX']),
                                    float(params['boundBoxMinY']),
                                    float(params['boundBoxMinZ'])),
                                'bbox_max': (
                                    float(params['boundBoxMaxX']),
                                    float(params['boundBoxMaxY']),
                                    float(params['boundBoxMaxZ']))
                                }
                        else:
                            bbox = {
                                'bbox_min': (-.5, -.5, 0),
                                'bbox_max': (.5, .5, 1)
                            }
                        asset_data.update(bbox)
                    if asset_type == 'material':
                        asset_data['texture_size_meters'] = params.get('textureSizeMeters', 1.0)
                    asset_data.update(tdict)
            r.update(asset_data)
    # main
    asset_base_id_str, asset_type_str = asset_ref.split()
    asset_type = asset_type_str.split(':')[1]
    scene_id = blenderkit.download.get_scene_id()
    reqstr = '?query=%s+%s+order:_score' % (asset_base_id_str, asset_type_str)
    reqstr += '&addon_version=%s' % version_checker.get_addon_version()
    reqstr += '&scene_uuid=%s'% scene_id
    url = paths.get_api_url() + 'search/' + reqstr
    api_key = user_preferences = C.preferences.addons['blenderkit'].preferences.api_key
    headers = utils.get_headers(api_key)
    r = rerequests.get(url, headers=headers)
    rdata = r.json()
    create_asset_data(rdata, asset_type)
    # BlenderKit might return publicity in the front
    asset_data = rdata['results'][-1]
    has_url = blenderkit.download.get_download_url(asset_data, scene_id, api_key)
    #file_names = paths.get_download_filepaths(asset_data)
    files_func = getattr(paths, 'get_download_filepaths', False) or paths.get_download_filenames
    file_names = files_func(asset_data)
    file_name = file_names[0]
    if not os.path.exists(file_name):
        with open(file_name, "wb") as f:
            print("Downloading %s" % file_name)
            res_file_info, resolution = paths.get_res_file(asset_data, 'blend')
            response = requests.get(res_file_info['url'], stream=True)
            #response = requests.get(asset_data['url'], stream=True)
            total_length = response.headers.get('Content-Length')
            if total_length is None:  # no content length header
                f.write(response.content)
            else:
                dl = 0
                for data in response.iter_content(chunk_size=4096*10):
                    dl += len(data)
                    f.write(data)
    return append_blend_material(file_names[-1])

def append_blend_material(file_name):
    materials = D.materials[:]
    with D.libraries.load(file_name, link=False, relative=True) as (data_from, data_to):
        matname = data_from.materials[0]
        data_to.materials = [matname]
    mat = D.materials.get(matname)
    mat.use_fake_user = True
    return mat

# download_blenderkit_material("asset_base_id:1bdb5334-851e-414d-b766-f9fe05477860 asset_type:material")
# download_blenderkit_material("asset_base_id:31dccf38-74f4-4516-9d17-b80a45711ca7 asset_type:material")

Point3d = Vector
Vector3d = Vector

def quaternion_from_vx_vy(vx, vy):
    return Vector((1,0,0)).rotation_difference(vx) @ Vector((0,1,0)).rotation_difference(vy)

shape_counter = 0
def new_id()->Id:
    global shape_counter
    shape_counter += 1
    return shape_counter, str(shape_counter)

materials = []
def add_material(mat):
    materials.append(mat)
    return len(materials) - 1

def get_material(name:str)->MatId:
    return add_material(D.materials[name])

def get_blenderkit_material(ref:str)->MatId:
    return add_material(download_blenderkit_material(ref))

def get_blend_material(file_path:str)->MatId:
    return add_material(append_blend_material(file_path))

def new_node_material(name, type):
    mat = D.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    links.clear()
    return mat, nodes.new(type=type)

def new_clay_material(name:str, color:RGBA)->MatId:
    mat, diffuse_shader = new_node_material(name, "ShaderNodeBsdfDiffuse")
    diffuse_shader.inputs[0].default_value = color
    return add_node_output_material(mat, diffuse_shader)

def add_node_output_material(mat, node):
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    node_out = nodes.new(type='ShaderNodeOutputMaterial')
    links.new(node.outputs[0], node_out.inputs[0])
    return add_material(mat)

def new_glass_material(name:str, color:RGBA, roughness:float, ior:float)->MatId:
    mat, node = new_node_material(name, 'ShaderNodeBsdfGlass')
    node.distribution = 'GGX'
    node.inputs['Color'].default_value = color
    node.inputs['Roughness'].default_value = roughness
    node.inputs['IOR'].default_value = ior
    return add_node_material(mat, node)

def new_mirror_material(name:str, color:RGBA)->MatId:
    mat, node = new_node_material(name, 'ShaderNodeBsdfGlossy')
    node.distribution = 'Sharp'
    node.inputs['Color'].default_value = color
    return add_node_material(mat, node)

def new_metal_material(name:str, color:RGBA, roughness:float, ior:float)->MatId:
    mat, node = new_node_material(name, 'ShaderNodeBsdfGlossy')
    node.distribution = 'GGX'
    node.inputs['Color'].default_value = color
    node.inputs['Roughness'].default_value = roughness
    return add_node_material(mat, node)

# For Principled BSDF in Blender 4.0+/5.0, the inputs are:
# 'Base Color', 'Metallic', 'Roughness', 'IOR', 'Alpha', 'Normal', 'Weight'
# 'Subsurface Weight', 'Subsurface Radius', 'Subsurface Scale', 'Subsurface Anisotropy'
# 'IOR Level' (formerly 'Specular'), 'Specular Tint'
# 'Anisotropic', 'Anisotropic Rotation', 'Tangent'
# 'Transmission Weight' (formerly 'Transmission'), no more 'Transmission Roughness'
# 'Coat Weight' (formerly 'Clearcoat'), 'Coat Roughness' (formerly 'Clearcoat Roughness')
# 'Coat IOR', 'Coat Tint', 'Coat Normal'
# 'Sheen Weight' (formerly 'Sheen'), 'Sheen Roughness', 'Sheen Tint'
# 'Emission Color' (formerly 'Emission'), 'Emission Strength'

def new_material(name:str, base_color:RGBA, metallic:float, specular:float, roughness:float,
                 clearcoat:float, clearcoat_roughness:float, ior:float,
                 transmission:float, transmission_roughness:float,
                 emission:RGBA, emission_strength:float)->MatId:
    mat, node = new_node_material(name, 'ShaderNodeBsdfPrincipled')
    node.inputs['Base Color'].default_value = base_color
    node.inputs['Metallic'].default_value = metallic
    # 'Specular' was renamed to 'IOR Level' in Blender 4.0
    node.inputs['IOR Level'].default_value = specular
    node.inputs['Roughness'].default_value = roughness
    # 'Clearcoat' was renamed to 'Coat Weight' in Blender 4.0
    node.inputs['Coat Weight'].default_value = clearcoat
    # 'Clearcoat Roughness' was renamed to 'Coat Roughness' in Blender 4.0
    node.inputs['Coat Roughness'].default_value = clearcoat_roughness
    node.inputs['IOR'].default_value = ior
    # 'Transmission' was renamed to 'Transmission Weight' in Blender 4.0
    node.inputs['Transmission Weight'].default_value = transmission
    # Note: 'Transmission Roughness' was removed in Blender 4.0 - parameter kept for API compat
    # 'Emission' was renamed to 'Emission Color' in Blender 4.0
    node.inputs['Emission Color'].default_value = emission
    node.inputs['Emission Strength'].default_value = emission_strength
    return add_node_material(mat, node)


def set_hdri_background(hdri_path:str)->None:
    world = C.scene.world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    nodes.clear()
    env_texture = nodes.new(type='ShaderNodeTexEnvironment')
    env_texture.image = D.images.load(hdri_path)
    env_texture.location = (-300,0)
    background = nodes.new(type='ShaderNodeBackground')
    world_output = nodes.new(type='ShaderNodeOutputWorld')
    world.node_tree.links.new(env_texture.outputs[0], background.inputs[0])
    world.node_tree.links.new(background.outputs[0], world_output.inputs[0])
    C.scene.render.film_transparent = True

def set_hdri_background_with_rotation(hdri_path:str, rotation:float)->None:
    world = C.scene.world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    nodes.clear()
    tex_coord = nodes.new(type='ShaderNodeTexCoord')
    mapping = nodes.new(type='ShaderNodeMapping')
    mapping.inputs['Rotation'].default_value[2] = rotation
    env_texture = nodes.new(type='ShaderNodeTexEnvironment')
    env_texture.image = D.images.load(hdri_path)
    background = nodes.new(type='ShaderNodeBackground')
    world_output = nodes.new(type='ShaderNodeOutputWorld')
    world.node_tree.links.new(tex_coord.outputs['Generated'], mapping.inputs[0])
    world.node_tree.links.new(mapping.outputs[0], env_texture.inputs[0])
    world.node_tree.links.new(env_texture.outputs[0], background.inputs[0])
    world.node_tree.links.new(background.outputs[0], world_output.inputs[0])
    C.scene.render.film_transparent = True

def append_material(obj, mat_idx):
    if mat_idx >= 0:
        obj.data.materials.append(materials[mat_idx])

# def add_uvs(mesh):
#     mesh.use_auto_texspace = True
#     uvl = mesh.uv_layers.new(name='KhepriUVs')
#     mesh.uv_layers.active = uvl
#     for polygon in mesh.polygons:
#         for vert, loop in zip(polygon.vertices, polygon.loop_indices):
#             uvl.data[loop].uv = Vector(, 0))
#     uvl.active = True
#     uvl.active_render = True
#     return mesh

def add_bm_uvs(mesh, bm):
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        normal = face.normal
        dx=abs(normal[0])
        dy=abs(normal[1])
        dz=abs(normal[2])
        if (dz > dx):
            u = Vector([1,0,0])
            if (dz>dy):
                v = Vector([0,1,0])
            else:
                v = Vector([0,0,1])
        else:
            v = Vector([0,0,1])
            if dx>dy:
                u = Vector([0,1,0])
            else:
                u = Vector([1,0,0])
        for loop in face.loops:
            loop_uv = loop[uv_layer]
            loop_uv.uv = [ u.dot(loop.vert.co),
                           v.dot(loop.vert.co)]

# def set_uvs_for_face(bm, fi, uv_layer):
#     face = bm.faces[fi]
#     normal = face.normal
#     dx=abs(normal[0])
#     dy=abs(normal[1])
#     dz=abs(normal[2])
#     if (dz > dx):
#         u = Vector([1,0,0])
#         if (dz>dy):
#             v = Vector([0,1,0])
#         else:
#             v = Vector([0,0,1])
#     else:
#         v = Vector([0,0,1])
#         if dx>dy:
#             u = Vector([0,1,0])
#         else:
#             u = Vector([1,0,0])
#     for i in range(len(face.loops)):
#         l = face.loops[i]
#         l[uv_layer].uv = [ u.dot(l.vert.co),
#                            v.dot(l.vert.co)]

# def set_uvs(bm, name=None):
#     uv_layer = bm.loops.layers.uv['KhepriUVs']
#     for fi in range(len(bm.faces)):
#         set_uvs_for_face(bm, fi, uv_layer)
#     bm.to_mesh(mesh)
# We should be using Ints for layers!
# HACK!!! Missing color!!!!!
current_collection = C.collection
def find_or_create_collection(name:str, active:bool, color:RGBA)->str:
    if name not in D.collections:
        collection = D.collections.new(name)
        collection.hide_viewport = not active
        C.scene.collection.children.link(collection)
    return name

def get_current_collection()->str:
    return current_collection.name

def set_current_collection(name:str)->None:
    global current_collection
    current_collection = D.collections[name]

#def all_shapes_in_collection(name:str)->List[Id]:
def delete_all_shapes_in_collection(name:str)->None:
    D.batch_remove(D.collections[name].objects)
    #D.orphans_purge(do_linked_ids=False)

def delete_all_shapes()->None:
    for collection in D.collections:
        D.batch_remove(collection.objects)
    global shape_counter
    shape_counter = 0
    #D.orphans_purge(do_linked_ids=False)

def delete_shape(name:Id)->None:
    D.objects.remove(D.objects[str(name)], do_unlink=True)

def select_shape(name:Id)->None:
    D.objects[str(name)].select_set(True)

def deselect_shape(name:Id)->None:
    D.objects[str(name)].select_set(False)

def select_shapes(names:List[Id])->None:
    for name in names:
        D.objects[str(name)].select_set(True)

def deselect_shapes(names:List[Id])->None:
    for name in names:
        D.objects[str(name)].select_set(False)

def deselect_all_shapes()->None:
    for collection in D.collections:
        for obj in collection.objects:
            obj.select_set(False)

def selected_shapes(prompt:str)->List[Id]:
    return [int(obj.name) for obj in D.objects if obj.select_get()]


def new_bmesh(verts:List[Point3d], edges:List[Tuple[int,int]], faces:List[List[int]], smooth:bool, mat_idx:int)->None:
    bm = bmesh.new()
    mverts = bm.verts
    for vert in verts:
        mverts.new(vert)
    mverts.ensure_lookup_table()
    medges = bm.edges
    for edge in edges:
        medges.new((mverts[edge[0]], mverts[edge[1]]))
    if faces == []:
        bmesh.ops.triangle_fill(bm, edges=bm.edges, use_beauty=True)
    mfaces = bm.faces
    for face in faces:
        mfaces.new([mverts[i] for i in face])
    if smooth:
        for f in mfaces:
            f.smooth = True
    if mat_idx >= 0:
        for f in mfaces:
            f.material_index = mat_idx
            #f.select = True
    bm.normal_update()
    return bm

def add_to_bmesh(bm, verts:List[Point3d], edges:List[Tuple[int,int]], faces:List[List[int]], smooth:bool, mat_idx:int)->None:
    #print(verts, edges, faces)
    mverts = bm.verts
    medges = bm.edges
    mfaces = bm.faces
    new_verts = [mverts.new(vert) for vert in verts]
    mverts.ensure_lookup_table()
    if faces == []:
        new_edges = [medges.new((new_verts[edge[0]], new_verts[edge[1]])) for edge in edges]
        bmesh.ops.triangle_fill(bm, edges=new_edges, use_beauty=True)
    else:
        new_faces = [mfaces.new([new_verts[i] for i in face]) for face in faces]
        if smooth:
            for f in new_faces:
                f.smooth = True
        if mat_idx >= 0:
            for f in new_faces:
                f.material_index = mat_idx
    bm.normal_update()
    return bm

def mesh_from_bmesh(name, bm):
    mesh_data = D.meshes.new(name)
    add_bm_uvs(mesh_data, bm)
    bm.to_mesh(mesh_data)
    bm.free()
    #add_uvs(mesh_data)
    return D.objects.new(name, mesh_data)

def automap(tob, target_slot=0, tex_size=1):
    actob = C.active_object
    C.view_layer.objects.active = tob
    if tob.data.use_auto_texspace:
        tob.data.use_auto_texspace = False
    tob.data.texspace_size = (1, 1, 1)
    uvl = tob.data.uv_layers.new(name='automap')
    scale = tob.scale.copy()
    if target_slot is not None:
        tob.active_material_index = target_slot
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.material_slot_select()
    scale = (scale.x + scale.y + scale.z) / 3.0
    bpy.ops.uv.cube_project(
        cube_size=scale * 2.0 / (tex_size),
        correct_aspect=False)  # it's * 2.0 because blender can't tell size of a unit cube :)
    bpy.ops.object.editmode_toggle()
    tob.data.uv_layers.active = uvl #tob.data.uv_layers['automap']
    uvl.active_render = True
    C.view_layer.objects.active = actob

def line(ps:List[Point3d], closed:bool, mat:MatId)->Id:
    id, name = new_id()
    curve = D.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    obj = D.objects.new(name, curve)
    current_collection.objects.link(obj)
    line = curve.splines.new("POLY")
    line.use_cyclic_u = closed
    line.points.add(len(ps) - 1)
    for (i, p) in enumerate(ps):
        line.points[i].co = (p[0], p[1], p[2], 1.0)
    append_material(obj, mat)
    return id

def bezier(order:int, ps:List[Point3d], closed:bool, tgs:List[Point3d], mat:MatId)->Id:
    id, name = new_id()
    curve = D.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    obj = D.objects.new(name, curve)
    current_collection.objects.link(obj)
    spline = curve.splines.new("BEZIER")
    spline.use_cyclic_u = closed
    spline.use_endpoint_u = not closed
    n = len(ps) - (1 if closed else 0)
    spline.bezier_points.add(n - 1)
    for i in range(0, n):
        p = ps[i]
        #pt = (p[0], p[1], p[2], 1.0)
        spline.bezier_points[i].co = p
        #spline.bezier_points[i].handle_left = p
        #spline.bezier_points[i].handle_right = p
        spline.bezier_points[i].handle_right_type = 'AUTO'
        spline.bezier_points[i].handle_left_type = 'AUTO'
    for (tg, i) in zip(tgs, [0, n-1]):
        bp = spline.bezier_points[i]
        x, y, z = ps[i]
        tx, ty, tz = tg
        bp.handle_left_type = 'FREE'
        bp.handle_right_type = 'FREE'
        bp.handle_left = (x - tx, y - ty, z - tz)
        bp.handle_right = (x + tx, y + ty, z + tz)
    spline.order_u = max(3, order)
    spline.resolution_u = 4*len(ps)
    append_material(obj, mat)
    return id

def nurbs(order:int, ps:List[Point3d], closed:bool, mat:MatId)->Id:
    #print(order, ps, closed)
    id, name = new_id()
    curve = D.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    obj = D.objects.new(name, curve)
    current_collection.objects.link(obj)
    spline = curve.splines.new("NURBS")
    spline.use_cyclic_u = closed
    spline.use_endpoint_u = not closed
    n = len(ps) - (1 if closed else 0)
    spline.points.add(n - 1)
    for i in range(0, n):
        p = ps[i]
        spline.points[i].co = (p[0], p[1], p[2], 1.0)
    spline.order_u = max(4, order)
    spline.resolution_u = 4
    append_material(obj, mat)
    return id

def objmesh(verts:List[Point3d], edges:List[Tuple[int,int]], faces:List[List[int]], smooth:bool, mat:MatId)->Id:
    id, name = new_id()
    obj = mesh_from_bmesh(name, new_bmesh(verts, edges, faces, smooth, -1 if mat < 0 else 0))
    current_collection.objects.link(obj)
    append_material(obj, mat)
    return id

def trig(p1:Point3d, p2:Point3d, p3:Point3d, mat:MatId)->Id:
    return objmesh([p1, p2, p3], [], [[0, 1, 2]], False, mat)

def quad(p1:Point3d, p2:Point3d, p3:Point3d, p4:Point3d, mat:MatId)->Id:
    return objmesh([p1, p2, p3, p4], [], [[0, 1, 2, 3]], False, mat)

def quad_strip_faces(s, n):
    return [[p0, p1, p2, p3]
            for (p0, p1, p2, p3)
            in zip(range(s,s+n),
                   range(s+1,s+n+1),
                   range(s+n+1, s+2*n),
                   range(s+n, s+2*n-1))]

def quad_strip_closed_faces(s, n):
    faces = quad_strip_faces(s, n)
    faces.append([s+n-1, s, s+n, s+2*n-1])
    return faces

def quad_strip(ps:List[Point3d], qs:List[Point3d], smooth:bool, mat:MatId)->Id:
    ps.extend(qs)
    return objmesh(ps, [], quad_strip_faces(0, len(qs)), smooth, mat)

def quad_strip_closed(ps:List[Point3d], qs:List[Point3d], smooth:bool, mat:MatId)->Id:
    ps.extend(qs)
    return objmesh(ps, [], quad_strip_closed_faces(0, len(qs)), smooth, mat)

def quad_surface(ps:List[Point3d], nu:int, nv:int, closed_u:bool, closed_v:bool, smooth:bool, mat:MatId)->Id:
    faces = []
    if closed_u:
        for i in range(0, nv-1):
            faces.extend(quad_strip_closed_faces(i*nu, nu))
        if closed_v:
            faces.extend([[p, p+1, q+1, q] for (p, q) in zip(range((nv-1)*nu,nv*nu-1), range(0, nu-1))])
            faces.append([nv*nu-1, (nv-1)*nu, 0, nu-1])
    else:
        for i in range(0, nv-1):
            faces.extend(quad_strip_faces(i*nu, nu))
        if closed_v:
            faces.extend([[p, p+1, q+1, q] for (p, q) in zip(range((nv-1)*nu,nv*nu), range(0, nu-1))])
    return objmesh(ps, [], faces, smooth, mat)

def ngon(ps:List[Point3d], pivot:Point3d, smooth:bool, mat:MatId)->Id:
    ps.append(ps[0])
    ps.append(pivot)
    n = len(ps) - 1
    return objmesh(
        ps,
        [],
        [[i0, i1, n]
         for (i0,i1) in zip(range(0, n-1), range(1, n))],
        smooth,
        mat)

def polygon(ps:List[Point3d], mat:MatId)->Id:
    return objmesh(ps, [], [list(range(0, len(ps)))], False, mat)

def polygon_with_holes(pss:List[List[Point3d]], mat:MatId)->Id:
    verts = [p for ps in pss for p in ps]
    edges = []
    for ps in pss:
        i = len(edges)
        edges.extend([(i+j,i+j+1) for j in range(0, len(ps)-1)])
        edges.append((i+len(ps)-1, i))
    id, name = new_id()
    obj = mesh_from_bmesh(name, new_bmesh(verts, edges, [], False, -1 if mat < 0 else 0))
    append_material(obj, mat)
    current_collection.objects.link(obj)
    return id

def circle(c:Point3d, v:Vector3d, r:float, mat:MatId)->Id:
    rot = Vector((0, 0, 1)).rotation_difference(v)  # Rotation from Z axis.
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, radius=r, segments=64,
                                calc_uvs=True)
    id, name = new_id()
    obj = mesh_from_bmesh(name, bm)
    obj.rotation_euler = rot.to_euler()
    obj.location = c
    append_material(obj, mat)
    current_collection.objects.link(obj)
    return id

def cuboid(verts:List[Point3d], mat:MatId)->Id:
    return objmesh(verts, [], [(0,1,2,3), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)], False, mat)

def pyramid_frustum(bs:List[Point3d], ts:List[Point3d], smooth:bool, bmat:MatId, tmat:MatId, smat:MatId)->Id:
    n = len(bs)
    mat_idx = 0
    bm = new_bmesh(bs, [], [list(range(n-1,-1,-1))], False, -1 if bmat < 0 else mat_idx)
    mat_idx += 0 if tmat < 0 else 1
    add_to_bmesh(bm, ts, [], [list(range(0, n))], False, -1 if tmat < 0 else mat_idx)
    mat_idx += 0 if smat < 0 else 1
    add_to_bmesh(bm, bs + ts, [], quad_strip_closed_faces(0, n), smooth, -1 if smat < 0 else mat_idx)
    id, name = new_id()
    obj = mesh_from_bmesh(name, bm)
    append_material(obj, bmat)
    append_material(obj, tmat)
    append_material(obj, smat)
    current_collection.objects.link(obj)
    return id

# def sphere(center:Point3d, radius:float)->Id:
#     bpy.ops.mesh.primitive_uv_sphere_add(location=center, radius=radius)
#     bpy.ops.object.shade_smooth()
#     return C.object.name
def oldsphere(center:Point3d, radius:float, mat:MatId)->Id:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=128, v_segments=64, radius=radius, )
    for f in bm.faces:
       f.smooth = True
    if mat >= 0:
        for f in bm.faces:
            f.material_index = 0
            #f.select = True
    id, name = new_id()
    obj = mesh_from_bmesh(name, bm)
    obj.location=center
    obj.scale=(radius, radius, radius)
    current_collection.objects.link(obj)
    append_material(obj, mat)
    return id

sphere_bmesh = False
def sphere(center:Point3d, radius:float, mat:MatId)->Id:
    global sphere_bmesh
    if sphere_bmesh:
        bm = sphere_bmesh
    else:
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=1, )
        for f in bm.faces:
           f.smooth = True
        sphere_bmesh = bm

    #for f in bm.faces:
    #   f.smooth = True
    #if mat >= 0:
    #    for f in bm.faces:
    #        f.material_index = 0
            #f.select = True
    id, name = new_id()
    mesh_data = D.meshes.new(name)
    #add_bm_uvs(mesh_data, bm)
    bm.to_mesh(mesh_data)
    #bm.free() We are caching it!
    #add_uvs(mesh_data)
    obj = D.objects.new(name, mesh_data)
    obj.location=center
    obj.scale=(radius, radius, radius)
    current_collection.objects.link(obj)
    append_material(obj, mat)
    return id

def cone_frustum(b:Point3d, br:float, t:Point3d, tr:float, bmat:MatId, tmat:MatId, smat:MatId)->Id:
    vec = t - b
    depth = vec.length
    rot = Vector((0, 0, 1)).rotation_difference(vec)  # Rotation from Z axis.
    trans = rot @ Vector((0, 0, depth / 2))  # Such that origin is at center of the base of the cylinder.
    bm = bmesh.new()
    mat_idx = 0
    bmesh.ops.create_cone(bm, cap_ends=False, segments=64,
                          radius1=br, radius2=tr, depth=depth,
                          calc_uvs=True)
    for f in bm.faces:
        f.smooth = True
    if smat >= 0:
        for f in  bm.faces:
            f.material_index = mat_idx
        bm.normal_update()
        mat_idx += 1
    if br > 0:
        bmesh.ops.create_circle(bm, cap_ends=True, radius=br, segments=64,
                                matrix=Matrix.Translation(Vector((0, 0, -depth/2))),
                                calc_uvs=True)
        mat_idx += 0 if bmat < 0 else 1
    if tr > 0:
        bmesh.ops.create_circle(bm, cap_ends=True, radius=tr, segments=64,
                                matrix=Matrix.Translation(Vector((0, 0, depth/2))),
                                calc_uvs=True)
        mat_idx += 0 if tmat < 0 else 1
    id, name = new_id()
    obj = mesh_from_bmesh(name, bm)
    obj.rotation_euler = rot.to_euler()
    obj.location = b + trans
    append_material(obj, bmat)
    append_material(obj, tmat)
    append_material(obj, smat)
    current_collection.objects.link(obj)
    return id

def rotation_from_axes(vx, vy):
    vz = vx.cross(vy)
    rot_matrix = Matrix((vx, vy, vz)).transposed()
    return rot_matrix

box_bmesh = False
def box(p:Point3d, vx:Vector3d, vy:Vector3d, dx:float, dy:float, dz:float, mat:MatId)->Id:
    global box_bmesh
    if box_bmesh:
        bm = box_bmesh
    else:
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        box_bmesh = bm
    vz = vx.cross(vy)
    rot_matrix = Matrix((vx, vy, vz)).transposed()
    id, name = new_id()
    mesh_data = D.meshes.new(name)
    bm.to_mesh(mesh_data)
    obj = D.objects.new(name, mesh_data)
    obj.scale = (dx, dy, dz)
    obj.rotation_euler = rot_matrix.to_euler()
    obj.location = p + vx*dx/2 + vy*dy/2 + vz*dz/2
    current_collection.objects.link(obj)
    append_material(obj, mat)
    return id

def text(txt:str, p:Point3d, vx:Vector3d, vy:Vector3d, size:float)->Id:
    id, name = new_id()
    rot = quaternion_from_vx_vy(vx, vy)
    text_data = D.curves.new(name=name, type='FONT')
    text_data.body = txt
    #text_data.align_x = align_x
    #text_data.align_y = align_y
    text_data.size = size
    text_data.font = D.fonts["Bfont"]
    #text_data.space_line = space_line
    #text_data.extrude = extrude
    obj = D.objects.new(name, text_data)
    obj.location = p
    obj.rotation_euler = rot.to_euler()
    current_collection.objects.link(obj)
    return id

# Boolean operations

def boolean_op(op:str, id1:Id, id2:Id)->Id:
    obj1 = D.objects[str(id1)]
    obj2 = D.objects[str(id2)]
    bool_modifier = obj1.modifiers.new(name="Boolean", type='BOOLEAN')
    bool_modifier.operation = op
    bool_modifier.object = obj2
    C.view_layer.objects.active = obj1
    bpy.ops.object.modifier_apply(modifier=bool_modifier.name)
    # Note: use_auto_smooth was removed in Blender 4.0+
    # Smooth shading is now handled via mesh attributes or geometry nodes
    D.objects.remove(obj2,do_unlink = True)
    return id1

def union(id1:Id, id2:Id)->Id:
    return boolean_op('UNION', id1, id2)

def intersect(id1:Id, id2:Id)->Id:
    return boolean_op('INTERSECT', id1, id2)

def difference(id1:Id, id2:Id)->Id:
    return boolean_op('DIFFERENCE', id1, id2)

def slice(id:Id, p:Point3d, v:Vector3d)->Id:
    obj = D.objects[str(id)]
    dimensions = obj.dimensions
    plane_size = max(dimensions) * 2
    bpy.ops.mesh.primitive_plane_add(size=plane_size, enter_editmode=False, align='WORLD', location=(0, 0, 0))
    plane = C.active_object
    rot_quat = Vector((0, 0, 1)).rotation_difference(Vector(-v))
    plane.rotation_euler = rot_quat.to_euler()
    plane.location = p
    bool_mod = obj.modifiers.new(name="Slice", type='BOOLEAN')
    bool_mod.operation = 'DIFFERENCE'
    bool_mod.object = plane
    C.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bool_mod.name)
    # Note: use_auto_smooth was removed in Blender 4.0+
    D.objects.remove(plane, do_unlink=True)
    return id

# Lights

def sun_light(p:Point3d, v:Vector3d)->Id:
    id, name = new_id()
    rot = Vector((0, 0, 1)).rotation_difference(v)  # Rotation from Z axis
    bpy.ops.object.light_add(name=name, type='SUN', location=p, rotation=rot)
    return id

def baselight(p:Point3d, type:str, energy:float, color:RGB):
    id, name = new_id()
    light_data = D.lights.new(name, type)
    light_data.energy = energy
    light_data.color = color
    light = D.objects.new(name, light_data)
    light.location = p
    current_collection.objects.link(light)
    return id, light

def pointlight(p:Point3d, energy:float, color:RGB)->Id:
    id, light = baselight(p, 'POINT', energy, color)
    return id

def rotation_euler_from_z_direction(v):
    return Vector(v).to_track_quat('-Z', 'Y').to_euler()

def arealight(p:Point3d, v:Vector3d, size:float, energy:float, color:RGB)->Id:
    id, light = baselight(p, 'AREA', energy, color)
    light.data.size = size
    light.rotation_euler = rotation_euler_from_z_direction(v)
    return id

def spotlight(p:Point3d, v:Vector3d, size:float, blend:float, energy:float, color:RGB)->Id:
    id, light = baselight(p, 'SPOT', energy, color)
    light_data = light.data
    light_data.energy = energy
    light_data.color = color
    light_data.spot_size = size
    light_data.spot_blend = blend
    light.rotation_euler = rotation_euler_from_z_direction(v)
    return id

def ieslight(p:Point3d, v:Vector3d, ies_file_path:str, energy:float)->Id:
    id, light = baselight(p, 'POINT', energy, color)
    light.data.use_nodes = True
    nodes = light.data.node_tree.nodes
    nodes.clear()
    emission = nodes.new(type='ShaderNodeEmission')
    ies_texture = nodes.new(type='ShaderNodeTexIES')
    ies_texture.ies = D.texts.load(ies_file_path)
    light_output = nodes.new(type='ShaderNodeOutputLight')
    light.data.node_tree.links.new(ies_texture.outputs[0], emission.inputs[0])
    light.data.node_tree.links.new(emission.outputs[0], light_output.inputs[0])
    return id

# HACK! This should not be used as we now resort to Nishita!!!!
def khepri_sun():
    raise RuntimeError("Don't use this!!! Use Nishita!!!")
    name = 'KhepriSun'
    name = 'Sun'
    if D.objects.find(name) == -1:
        C.view_layer.active_layer_collection = C.view_layer.layer_collection
        light_data = D.lights.new(name="Sun", type='SUN')
        light_data.energy = 30
        light_object = D.objects.new(name="Sun", object_data=light_data)
        light_object.location = (5, 5, 5)
        C.collection.objects.link(light_object)
        C.view_layer.objects.active = light_object
        #bpy.ops.object.light_add(type='SUN')
    return D.objects[name]

def set_sun(latitude:float, longitude:float, elevation:float,
            year:int, month:int, day:int, time:float,
            UTC_zone:float, use_daylight_savings:bool)->None:
    raise RuntimeError("Don't use this!!! Use Nishita!!!")
    sun_props = C.scene.sun_pos_properties #sunposition.sun_calc.sun
    sun_props.usage_mode = 'NORMAL'
    sun_props.use_daylight_savings = False
    sun_props.use_refraction = True
    sun_props.latitude = latitude
    sun_props.longitude = longitude
    sun_props.month = month
    sun_props.day = day
    sun_props.year = year
    sun_props.use_day_of_year = False
    sun_props.UTC_zone = UTC_zone
    sun_props.time = time
    sun_props.sun_distance = 100
    sun_props.use_daylight_savings = use_daylight_savings
    # Using Sky Texture => It creates its own sun.
    # sun_props.sun_object = khepri_sun()
    sunposition.sun_calc.update_time(C)
    sunposition.sun_calc.move_sun(C)

def find_or_create_node(node_tree, search_type, create_type):
    for node in node_tree.nodes:
        if node.type == search_type:
            return node
    return node_tree.nodes.new(type=create_type)

def find_or_create_world(name):
    for world in D.worlds:
        if world.name == name:
            return world
    return D.worlds.new(name)

def set_sun_sky(sun_elevation:float, sun_rotation:float, turbidity:float, with_sun:bool)->None:
    C.scene.render.engine = 'CYCLES'
    sky = C.scene.world.node_tree.nodes.new("ShaderNodeTexSky")
    bg = C.scene.world.node_tree.nodes["Background"]
    C.scene.world.node_tree.links.new(bg.inputs[0], sky.outputs[0])
    sky.sky_type = "NISHITA"
    sky.turbidity = turbidity
    sky.dust_density = turbidity
    sky.sun_elevation = sun_elevation
    sky.sun_rotation = sun_rotation
    sky.sun_disc = with_sun


#C.scene.view_settings.view_transform = 'False Color'
#C.scene.world.light_settings.use_ambient_occlusion = True


def set_sky(turbidity:float)->None:
    raise RuntimeError("Don't use this!!! Use Nishita!!!")
    C.scene.render.engine = 'CYCLES'
    world = find_or_create_world("World")
    world.use_nodes = True
    bg = find_or_create_node(world.node_tree, "BACKGROUND", "")
    sky = find_or_create_node(world.node_tree, "TEX_SKY", "ShaderNodeTexSky")
    #sky.sky_type = "HOSEK_WILKIE"
    sky.sky_type = "NISHITA"
    sky.turbidity = turbidity
    sky.dust_density = turbidity
    #Sun Direction
    #Sun direction vector.
    #
    #Ground Albedo
    #Amount of light reflected from the planet surface back into the atmosphere.
    #
    #Sun Disc
    #Enable/Disable sun disc lighting.
    #
    #Sun Size
    #Angular diameter of the sun disc (in degrees).
    #
    #Sun Intensity
    #Multiplier for sun disc lighting.
    #
    #Sun Elevation
    #Rotation of the sun from the horizon (in degrees).
    #
    #Sun Rotation
    #Rotation of the sun around the zenith (in degrees).
    #
    #Altitude
    #The distance from sea level to the location of the camera. For example, if the camera is placed on a beach then a value of 0 should be used. However, if the camera is in the cockpit of a flying airplane then a value of 10 km will be more suitable. Note, this is limited to 60 km because the mathematical model only accounts for the first two layers of the earth’s atmosphere (which ends around 60 km).
    #
    #Air
    #Density of air molecules.
    #0 no air
    #1 clear day atmosphere
    #2 highly polluted day
    #
    #Dust
    #Density of dust and water droplets.
    #0 no dust
    #1 clear day atmosphere
    #5 city like atmosphere
    #10 hazy day
    #
    #Ozone
    #Density of ozone molecules; useful to make the sky appear bluer.
    #0 no ozone
    #1 clear day atmosphere
    #2 city like atmosphere
    world.node_tree.links.new(bg.inputs[0], sky.outputs[0])

def current_area():
    return next(area for area in C.screen.areas if area.type == 'VIEW_3D')

def current_space(area = current_area()):
    return next(space for space in area.spaces if space.type == 'VIEW_3D')

def current_region(area = current_area()):
    return next(region for region in area.regions if region.type == 'WINDOW')

def set_view(camera:Point3d, target:Point3d, lens:float)->None:
    direction = target - camera
    rot_quat = direction.to_track_quat('-Z', 'Y')
    space = current_space()
    view = space.region_3d
    view.view_location = target
    view.view_rotation = rot_quat
    view.view_distance = direction.length
    space.lens = lens

def set_view_top()->None:
    area = current_area()
    with C.temp_override(area=area, region=current_region(area)):
       bpy.ops.view3d.view_axis(type='TOP')

def frame_all()->None:
    area = current_area()
    with C.temp_override(area=area, region=current_region(area)):
        bpy.ops.view3d.view_all()

# import bpy
# from mathutils import Vector
#
# cam = D.objects['Camera']
# location = cam.location
# up = cam.matrix_world.to_quaternion() @ Vector((0.0, 1.0, 0.0))
# direction = cam.matrix_world.to_quaternion() @ Vector((0.0, 0.0, -1.0))
#
# print(
#     '-vp ' + str(location.x) + ' ' + str(location.y) + ' ' +  str(location.z) + ' ' +
#     '-vd ' + str(direction.x) + ' ' + str(direction.y) + ' ' + str(direction.z) + ' ' +
#     '-vu ' + str(up.x) + ' ' + str(up.y) + ' ' + str(up.z)
# )

def get_view()->Tuple[Point3d, Point3d, float]:
    space = current_space()
    view = space.region_3d
    return (
        view.view_rotation @ Vector((0.0, 0.0, view.view_distance)) + view.view_location,
        view.view_location,
        space.lens)

def khepri_camera():
    name = 'KhepriCamera'
    name = 'Camera'
    if D.objects.find(name) == -1:
        cam = D.cameras.new(name)
        # Simulate Sony's FE 85mm F1.4 GM
        # cam.sensor_fit = 'HORIZONTAL'
        # cam.sensor_width = 36.0
        # cam.sensor_height = 24.0
        # cam.lens = lens
        # cam.dof.use_dof = True
        # cam.dof.focus_object = focus_target_object
        # cam.dof.aperture_fstop = fstop
        # cam.dof.aperture_blades = 11
        obj = D.objects.new(name, cam)
        C.collection.objects.link(obj)
        return obj
    else:
        return D.objects[name]

def set_camera_view(camera:Point3d, target:Point3d, lens:float)->None:
    direction = target - camera
    direction *= 2
    rot_quat = direction.to_track_quat('-Z', 'Y')
    cam = khepri_camera()
    cam.location = camera
    cam.rotation_euler = rot_quat.to_euler()
    cam.data.lens = lens
    d = direction.length 
    # Architectural work suggests these distances:
    cam.data.clip_start = 0.1
    cam.data.clip_end = 100000
    C.scene.camera = cam

def camera_from_view()->None:
    space = current_space()
    cam = khepri_camera()
    cam.location = space.region_3d.view_location
    cam.rotation_euler = space.region_3d.view_rotation.to_euler()
    cam.data.lens = space.lens

# If needed, a zoom-extents operation can be defined as follows
# for area in C.screen.areas:
#     if area.type == 'VIEW_3D':
#         for region in area.regions:
#             if region.type == 'WINDOW':
#                 override = {'area': area, 'region': region, 'edit_object': C.edit_object}
#                 bpy.ops.view3d.view_all(override)

def set_render_size(width:int, height:int)->None:
    C.scene.render.resolution_x = width
    C.scene.render.resolution_y = height
    C.scene.render.resolution_percentage = 100
    #C.scene.render.resolution_percentage = 50
    #C.scene.render.pixel_aspect_x = 1.0
    #C.scene.render.pixel_aspect_y = 1.0

def set_render_path(filepath:str)->None:
    C.scene.render.image_settings.file_format = 'PNG'
    C.scene.render.filepath = filepath

def default_renderer()->None:
    bpy.ops.render.render(use_viewport = True, write_still=True)

def cycles_renderer(samples:int, denoising:bool, motion_blur:bool, transparent:bool, exposure:float)->None:
    C.scene.render.engine = 'CYCLES'
    C.scene.render.use_motion_blur = motion_blur
    C.scene.render.film_transparent = transparent
    C.scene.view_layers[0].cycles.use_denoising = denoising
    C.scene.cycles.samples = samples
    #C.scene.cycles.film_exposure = exposure # Just a brightness multiplier 0-10
    C.scene.view_settings.exposure = exposure # Better approximation
    C.scene.cycles.device = "GPU"
    C.preferences.addons["cycles"].preferences.compute_device_type = "CUDA"
    C.preferences.addons["cycles"].preferences.get_devices()
    for d in C.preferences.addons["cycles"].preferences.devices:
        d["use"] = 1
    bpy.ops.render.render(use_viewport=True, write_still=True)

def freestylesvg_renderer(thickness:float, crease_angle:float, sphere_radius:float, kr_derivative_epsilon:float)->None:
    freestylesvg = addon_utils.enable("render_freestyle_svg")
    C.scene.render.use_freestyle = True
    C.scene.svg_export.use_svg_export = True
    C.scene.render.line_thickness_mode = 'ABSOLUTE'
    D.linestyles['LineStyle'].use_export_strokes = True
    D.linestyles['LineStyle'].thickness = thickness
    settings = C.view_layer.freestyle_settings
    settings.crease_angle = crease_angle
    settings.use_culling = False
    settings.use_advanced_options = True
    settings.use_material_boundaries = True
    settings.use_ridges_and_valleys = True
    settings.use_smoothness = True
    settings.use_suggestive_contours = True
    settings.sphere_radius = sphere_radius
    settings.kr_derivative_epsilon = kr_derivative_epsilon
    bpy.ops.render.render(use_viewport = True, write_still=True)
    C.scene.render.use_freestyle = False

def clay_renderer(samples:int, denoising:bool, motion_blur:bool, transparent:bool)->None:
    C.scene.render.engine = 'CYCLES'
    C.scene.render.use_motion_blur = motion_blur
    C.scene.render.film_transparent = transparent
    C.scene.view_layers[0].cycles.use_denoising = denoising
    C.scene.view_layers[0].use_pass_ambient_occlusion = True
    C.scene.cycles.samples = samples
    C.scene.cycles.device = "GPU"
    C.preferences.addons["cycles"].preferences.compute_device_type = "CUDA"
    C.preferences.addons["cycles"].preferences.get_devices()
    for d in C.preferences.addons["cycles"].preferences.devices:
        d["use"] = 1
    bpy.ops.render.render(use_viewport = True, write_still=True)

# Last resort

def blender_cmd(expr:str)->None:
    eval(expr)

# Bounding box

def get_global_bbox()->Tuple[Point3d, Point3d]:
    min_coord = [float('inf')] * 3
    max_coord = [float('-inf')] * 3
    for collection in D.collections:
        for obj in collection.objects:
            if obj.type == 'MESH' and obj.bound_box:
                for local_bbox_corner in obj.bound_box:
                    world_bbox_corner = obj.matrix_world @ Point3d(local_bbox_corner)
                    for i in range(3):
                        min_coord[i] = min(min_coord[i], world_bbox_corner[i])
                        max_coord[i] = max(max_coord[i], world_bbox_corner[i])
    return Point3d(min_coord), Point3d(max_coord)

def add_render_background(d:float, w:float, mat:MatId)->Id:
    p0, p1 = get_global_bbox()
    return quad(Point3d((p0[0]-w, p0[1]-w, p0[2]-d)),
                Point3d((p1[0]+w, p0[1]-w, p0[2]-d)),
                Point3d((p1[0]+w, p1[1]+w, p0[2]-d)),
                Point3d((p0[0]-w, p1[1]+w, p0[2]-d)),
                mat)

"""
    com.light_cache_bake()


class _Point3dArray(object):
    def write(self, conn, ps):
        Int.write(conn, len(ps))
        for p in ps:
            Point3d.write(conn, p)
    def read(self, conn):
        n = Int.read(conn)
        if n == -1:
            raise RuntimeError(String.read(conn))
        else:
            pts = []
            for i in range(n):
                pts.append(Point3d.read(conn))
            return pts

Point3dArray = _Point3dArray()

class _Frame3d(object):
    def write(self, conn, ps):
        raise Error("Bum")
    def read(self, conn):
        return u0(cs_from_o_vx_vy_vz(Point3d.read(conn),
                                     Vector3d.read(conn),
                                     Vector3d.read(conn),
                                     Vector3d.read(conn)))

Frame3d = _Frame3d()


fast_mode = False

class _ObjectId(Packer):
    def __init__(self):
        super().__init__('1i')
    def read(self, conn):
        if fast_mode:
            return incr_id_counter()
        else:
            _id = super().read(conn)
            if _id == -1:
                raise RuntimeError(String.read(conn))
            else:
                return _id

ObjectId = _ObjectId()
Entity = _ObjectId()
ElementId = _ObjectId()

class _ObjectIdArray(object):
    def write(self, conn, ids):
        Int.write(conn, len(ids))
        for _id in ids:
            ObjectId.write(conn, _id)
    def read(self, conn):
        n = Int.read(conn)
        if n == -1:
            raise RuntimeError(String.read(conn))
        else:
            ids = []
            for i in range(n):
                ids.append(ObjectId.read(conn))
            return ids

ObjectIdArray = _ObjectIdArray()
"""

import struct
from functools import partial

def r_Vector(conn)->Vector:
    return Vector(r_float3(conn))

def w_Vector(e:Vector, conn)->None:
    w_float3((e.x, e.y, e.z), conn)

e_Vector = e_float3

r_List_Vector = partial(r_List, r_Vector)
w_List_Vector = partial(w_List, w_Vector)
e_List_Vector = e_List

r_List_List_Vector = partial(r_List, r_List_Vector)
w_List_List_Vector = partial(w_List, w_List_Vector)
e_List_List_Vector = e_List

import addon_utils

class Khepri(object):
    def __init__(self):
        pass

# Use this when Blender is the server
#init_client_server("Blender", 11003)

# or this when it is the client
init_client_server("Blender", 0)

if bpy.app.background:
    while True:
        execute_current_action()
else:
    bpy.app.timers.register(execute_current_action)

"""
def register():
    global server
#    server = Khepri()

def unregister():
    global server
    warn('stopping server...')
#    server.stop()
#    del server

if __name__ == "__main__":
    register()
"""