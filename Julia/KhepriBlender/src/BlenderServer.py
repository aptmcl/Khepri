bl_info = {
    "name": "Khepri",
    "author": "António Leitão",
    "version": (1, 0),
    "blender": (2, 80, 0),
    "location": "Scripting > Khepri",
    "description": "Khepri connection to Blender",
    "warning": "",
    "wiki_url": "",
    "category": "Tools",
}

# To easily test this, on a command prompt do:
# "C:\Program Files\Blender Foundation\Blender 2.91\blender.exe" --python BlenderServer.py
# To test this while still allowing redefinitions do:
# "C:\Program Files\Blender Foundation\Blender 2.91\blender.exe"
# and then, in Blender's Python console:
# __file__=os.getcwd()+"/src"
# exec(open("BlenderServer.py").read())

# This loads the shared part of the Khepri server
# PS: Don't even try to load that as a module. You will get separate namespaces.
import os
exec(open(os.path.join(os.path.dirname(__file__), "KhepriServer.py")).read())

# Now comes the Blender-specific server
from bpy import ops, data as D, context as C
import bpy
import bmesh
from mathutils import Vector, Matrix
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
    materials = bpy.data.materials[:]
    with bpy.data.libraries.load(file_name, link=False, relative=True) as (data_from, data_to):
        matname = data_from.materials[0]
        data_to.materials = [matname]
    mat = bpy.data.materials.get(matname)
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

# For Principled BSDF, the inputs are as follows:
# 0, 'Base Color'
# 1, 'Subsurface'
# 2, 'Subsurface Radius'
# 3, 'Subsurface Color'
# 4, 'Metallic'
# 5, 'Specular'
# 6, 'Specular Tint'
# 7, 'Roughness'
# 8, 'Anisotropic'
# 9, 'Anisotropic Rotation'
# 10, 'Sheen'
# 11, 'Sheen Tint'
# 12, 'Clearcoat'
# 13, 'Clearcoat Roughness'
# 14, 'IOR'
# 15, 'Transmission'
# 16, 'Transmission Roughness'
# 17, 'Emission'
# 18, 'Alpha'
# 19, 'Normal'
# 20, 'Clearcoat Normal'
# 21, 'Tangent'

def new_material(name:str, base_color:RGBA, metallic:float, specular:float, roughness:float,
                 clearcoat:float, clearcoat_roughness:float, ior:float,
                 transmission:float, transmission_roughness:float,
                 emission:RGBA, emission_strength:float)->MatId:
    mat, node = new_node_material(name, 'ShaderNodeBsdfPrincipled')
    node.inputs['Base Color'].default_value = base_color
    #node.inputs['Subsurface'].default_value =
    #node.inputs['Subsurface Radius'].default_value =
    #node.inputs['Subsurface Color'].default_value =
    node.inputs['Metallic'].default_value = metallic
    node.inputs['Specular'].default_value = specular
    #node.inputs['Specular Tint'].default_value =
    node.inputs['Roughness'].default_value = roughness
    #node.inputs['Anisotropic'].default_value =
    #node.inputs['Anisotropic Rotation'].default_value =
    #node.inputs['Sheen'].default_value =
    #node.inputs['Sheen Tint'].default_value =
    node.inputs['Clearcoat'].default_value = clearcoat
    node.inputs['Clearcoat Roughness'].default_value = clearcoat_roughness
    node.inputs['IOR'].default_value = ior
    node.inputs['Transmission'].default_value = transmission
    node.inputs['Transmission Roughness'].default_value = transmission_roughness
    node.inputs['Emission'].default_value = emission
    #node.inputs['Alpha'].default_value =
    #node.inputs['Normal'].default_value =
    #node.inputs['Clearcoat Normal'].default_value =
    #node.inputs['Tangent'].default_value =
    return add_node_material(mat, node)


def set_hdri_background(hdri_path:str)->None:
    world = C.scene.world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    nodes.clear()
    env_texture = nodes.new(type='ShaderNodeTexEnvironment')
    env_texture.image = bpy.data.images.load(hdri_path)
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
    env_texture.image = bpy.data.images.load(hdri_path)
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
    medges = bm.edges
    mfaces = bm.faces
    for vert in verts:
        mverts.new(vert)
    mverts.ensure_lookup_table()
    for edge in edges:
        medges.new((mverts[edge[0]], mverts[edge[1]]))
    if faces == []:
        bmesh.ops.triangle_fill(bm, edges=bm.edges, use_beauty=True)
    else:
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
    kind = "POLY"
    curve = D.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    obj = D.objects.new(name, curve)
    current_collection.objects.link(obj)
    line = curve.splines.new(kind)
    line.use_cyclic_u = closed
    line.points.add(len(ps) - 1)
    for (i, p) in enumerate(ps):
        line.points[i].co = (p[0], p[1], p[2], 1.0)
    append_material(obj, mat)
    return id

def nurbs(order:int, ps:List[Point3d], closed:bool, mat:MatId)->Id:
    #print(order, ps, closed)
    id, name = new_id()
    kind = "NURBS"
    curve = D.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    obj = D.objects.new(name, curve)
    current_collection.objects.link(obj)
    spline = curve.splines.new(kind)
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
            faces.extend([[p, p+1, q+1, q] for (p, q) in zip(range((nv-1)*nu,nv*nu), range(0, nu))])
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
    bmesh.ops.create_circle(bm, cap_ends=True, radius=r, segments=32,
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

def sphere(center:Point3d, radius:float, mat:MatId)->Id:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=radius, )
    for f in bm.faces:
        f.smooth = True
    if mat >= 0:
        for f in bm.faces:
            f.material_index = 0
            #f.select = True
    id, name = new_id()
    obj = mesh_from_bmesh(name, bm)
    obj.location=center
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
    if br > 0:
        bmesh.ops.create_circle(bm, cap_ends=True, radius=br, segments=32,
                                matrix=Matrix.Translation(Vector((0, 0, -depth/2))),
                                calc_uvs=True)
        mat_idx += 0 if bmat < 0 else 1
    bmesh.ops.create_cone(bm, cap_ends=False, segments=32,
                          radius1=br, radius2=tr, depth=depth,
                          calc_uvs=True)
    for f in bm.faces:
        f.smooth = True
    if smat >= 0:
        for f in  bm.faces:
            f.material_index = mat_idx
        mat_idx += 1
    if tr > 0:
        bmesh.ops.create_circle(bm, cap_ends=True, radius=tr, segments=32,
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

def box(p:Point3d, vx:Vector3d, vy:Vector3d, dx:float, dy:float, dz:float, mat:MatId)->Id:
    id, name = new_id()
    rot = quaternion_from_vx_vy(vx, vy)
    print(rot)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1, matrix=Matrix.Diagonal(Vector((dx, dy, dz, 1.0))),
                          # AML Scale here? May influence UVs
                          #matrix=Matrix.Translation(Vector((0, 0, -depth/2))),
                          #calc_uvs=True
                          )
    obj = mesh_from_bmesh(name, bm)
    obj.rotation_euler = rot.to_euler()
    print(rot.to_euler())
    print(p)
    obj.location = p
    current_collection.objects.link(obj)
    append_material(obj, mat)
    return id

# def add_torus(major_rad, minor_rad, major_seg, minor_seg):
#     from math import cos, sin, pi
#     from mathutils import Vector, Matrix
#
#     pi_2 = pi * 2.0
#
#     verts = []
#     faces = []
#     i1 = 0
#     tot_verts = major_seg * minor_seg
#     for major_index in range(major_seg):
#         matrix = Matrix.Rotation((major_index / major_seg) * pi_2, 3, 'Z')
#
#         for minor_index in range(minor_seg):
#             angle = pi_2 * minor_index / minor_seg
#
#             vec = matrix @ Vector((
#                 major_rad + (cos(angle) * minor_rad),
#                 0.0,
#                 sin(angle) * minor_rad,
#             ))
#
#             verts.extend(vec[:])
#
#             if minor_index + 1 == minor_seg:
#                 i2 = (major_index) * minor_seg
#                 i3 = i1 + minor_seg
#                 i4 = i2 + minor_seg
#             else:
#                 i2 = i1 + 1
#                 i3 = i1 + minor_seg
#                 i4 = i3 + 1
#
#             if i2 >= tot_verts:
#                 i2 = i2 - tot_verts
#             if i3 >= tot_verts:
#                 i3 = i3 - tot_verts
#             if i4 >= tot_verts:
#                 i4 = i4 - tot_verts
#
#             faces.extend([i1, i3, i4, i2])
#
#             i1 += 1
#
#     return verts, faces
#
#
# def add_uvs(mesh, minor_seg, major_seg):
#     from math import fmod
#
#     mesh.uv_layers.new()
#     uv_data = mesh.uv_layers.active.data
#     polygons = mesh.polygons
#     u_step = 1.0 / major_seg
#     v_step = 1.0 / minor_seg
#
#     # Round UV's, needed when segments aren't divisible by 4.
#     u_init = 0.5 + fmod(0.5, u_step)
#     v_init = 0.5 + fmod(0.5, v_step)
#
#     # Calculate wrapping value under 1.0 to prevent
#     # float precision errors wrapping at the wrong step.
#     u_wrap = 1.0 - (u_step / 2.0)
#     v_wrap = 1.0 - (v_step / 2.0)
#
#     vertex_index = 0
#
#     u_prev = u_init
#     u_next = u_prev + u_step
#     for _major_index in range(major_seg):
#         v_prev = v_init
#         v_next = v_prev + v_step
#         for _minor_index in range(minor_seg):
#             loops = polygons[vertex_index].loop_indices
#             uv_data[loops[0]].uv = u_prev, v_prev
#             uv_data[loops[1]].uv = u_next, v_prev
#             uv_data[loops[3]].uv = u_prev, v_next
#             uv_data[loops[2]].uv = u_next, v_next
#
#             if v_next > v_wrap:
#                 v_prev = v_next - 1.0
#             else:
#                 v_prev = v_next
#             v_next = v_prev + v_step
#
#             vertex_index += 1
#
#         if u_next > u_wrap:
#             u_prev = u_next - 1.0
#         else:
#             u_prev = u_next
#         u_next = u_prev + u_step
#
#
# class AddTorus(Operator, object_utils.AddObjectHelper):
#     """Construct a torus mesh"""
#     bl_idname = "mesh.primitive_torus_add"
#     bl_label = "Add Torus"
#     bl_options = {'REGISTER', 'UNDO', 'PRESET'}
#
#     def mode_update_callback(self, _context):
#         if self.mode == 'EXT_INT':
#             self.abso_major_rad = self.major_radius + self.minor_radius
#             self.abso_minor_rad = self.major_radius - self.minor_radius
#
#     major_segments: IntProperty(
#         name="Major Segments",
#         description="Number of segments for the main ring of the torus",
#         min=3, max=256,
#         default=48,
#     )
#     minor_segments: IntProperty(
#         name="Minor Segments",
#         description="Number of segments for the minor ring of the torus",
#         min=3, max=256,
#         default=12,
#     )
#     mode: EnumProperty(
#         name="Dimensions Mode",
#         items=(
#             ('MAJOR_MINOR', "Major/Minor",
#              "Use the major/minor radii for torus dimensions"),
#             ('EXT_INT', "Exterior/Interior",
#              "Use the exterior/interior radii for torus dimensions"),
#         ),
#         update=mode_update_callback,
#     )
#     major_radius: FloatProperty(
#         name="Major Radius",
#         description=("Radius from the origin to the "
#                      "center of the cross sections"),
#         soft_min=0.0, soft_max=100.0,
#         min=0.0, max=10_000.0,
#         default=1.0,
#         subtype='DISTANCE',
#         unit='LENGTH',
#     )
#     minor_radius: FloatProperty(
#         name="Minor Radius",
#         description="Radius of the torus' cross section",
#         soft_min=0.0, soft_max=100.0,
#         min=0.0, max=10_000.0,
#         default=0.25,
#         subtype='DISTANCE',
#         unit='LENGTH',
#     )
#     abso_major_rad: FloatProperty(
#         name="Exterior Radius",
#         description="Total Exterior Radius of the torus",
#         soft_min=0.0, soft_max=100.0,
#         min=0.0, max=10_000.0,
#         default=1.25,
#         subtype='DISTANCE',
#         unit='LENGTH',
#     )
#     abso_minor_rad: FloatProperty(
#         name="Interior Radius",
#         description="Total Interior Radius of the torus",
#         soft_min=0.0, soft_max=100.0,
#         min=0.0, max=10_000.0,
#         default=0.75,
#         subtype='DISTANCE',
#         unit='LENGTH',
#     )
#     generate_uvs: BoolProperty(
#         name="Generate UVs",
#         description="Generate a default UV map",
#         default=True,
#     )
#
#     def draw(self, _context):
#         layout = self.layout
#
#         layout.use_property_split = True
#         layout.use_property_decorate = False
#
#         layout.separator()
#
#         layout.prop(self, "major_segments")
#         layout.prop(self, "minor_segments")
#
#         layout.separator()
#
#         layout.prop(self, "mode")
#         if self.mode == 'MAJOR_MINOR':
#             layout.prop(self, "major_radius")
#             layout.prop(self, "minor_radius")
#         else:
#             layout.prop(self, "abso_major_rad")
#             layout.prop(self, "abso_minor_rad")
#
#         layout.separator()
#
#         layout.prop(self, "generate_uvs")
#         layout.prop(self, "align")
#         layout.prop(self, "location")
#         layout.prop(self, "rotation")
#
#     def invoke(self, context, _event):
#         object_utils.object_add_grid_scale_apply_operator(self, context)
#         return self.execute(context)
#
#     def execute(self, context):
#
#         if self.mode == 'EXT_INT':
#             extra_helper = (self.abso_major_rad - self.abso_minor_rad) * 0.5
#             self.major_radius = self.abso_minor_rad + extra_helper
#             self.minor_radius = extra_helper
#
#         verts_loc, faces = add_torus(
#             self.major_radius,
#             self.minor_radius,
#             self.major_segments,
#             self.minor_segments,
#         )
#
#         mesh = D.meshes.new(data_("Torus"))
#
#         mesh.vertices.add(len(verts_loc) // 3)
#
#         nbr_loops = len(faces)
#         nbr_polys = nbr_loops // 4
#         mesh.loops.add(nbr_loops)
#         mesh.polygons.add(nbr_polys)
#
#         mesh.vertices.foreach_set("co", verts_loc)
#         mesh.polygons.foreach_set("loop_start", range(0, nbr_loops, 4))
#         mesh.polygons.foreach_set("loop_total", (4,) * nbr_polys)
#         mesh.loops.foreach_set("vertex_index", faces)
#
#         if self.generate_uvs:
#             add_uvs(mesh, self.minor_segments, self.major_segments)
#
#         mesh.update()

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

# Lights
def area_light(p:Point3d, v:Vector3d, size:float, color:RGBA, energy:float)->Id:
    id, name = new_id()
    rot = Vector((0, 0, 1)).rotation_difference(v)  # Rotation from Z axis
    light_data = D.lights.new(name, 'AREA')
    light_data.energy = energy
    light_data.size = size
    light_data.use_nodes = True
    light_data.node_tree.nodes["Emission"].inputs["Color"].default_value = color
    light = D.objects.new(name, light_data)
    light.location=location
    light.rotation=rotation
    return id

def sun_light(p:Point3d, v:Vector3d)->Id:
    id, name = new_id()
    rot = Vector((0, 0, 1)).rotation_difference(v)  # Rotation from Z axis
    bpy.ops.object.light_add(name=name, type='SUN', location=p, rotation=rot)
    return id

def light(p:Point3d, type:str)->Id:
    id, name = new_id()
    light_data = D.lights.new(name, type)
    light = D.objects.new(name, light_data)
    light.location = p
    current_collection.objects.link(light)

def light_probe(p:Point3d, type:str)->Id:
    id, name = new_id()
    light_data = D.lights.new(name, type)
    light = D.objects.new(name, light_data)
    light.location = p
    current_collection.objects.link(light)


# HACK! This should not be used as we now resort to Nishita!!!!
def khepri_sun():
    raise RuntimeError("Don't use this!!! Use Nishita!!!")
    name = 'KhepriSun'
    name = 'Sun'
    if D.objects.find(name) == -1:
        C.view_layer.active_layer_collection = C.view_layer.layer_collection
        light_data = bpy.data.lights.new(name="Sun", type='SUN')
        light_data.energy = 30
        light_object = bpy.data.objects.new(name="Sun", object_data=light_data)
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


#bpy.context.scene.view_settings.view_transform = 'False Color'
#bpy.context.scene.world.light_settings.use_ambient_occlusion = True


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

def current_space():
    area = next(area for area in C.screen.areas if area.type == 'VIEW_3D')
    space = next(space for space in area.spaces if space.type == 'VIEW_3D')
    return space

def set_view(camera:Point3d, target:Point3d, lens:float)->None:
    direction = target - camera
    rot_quat = direction.to_track_quat('-Z', 'Y')
    space = current_space()
    view = space.region_3d
    view.view_location = target
    view.view_rotation = rot_quat
    view.view_distance = direction.length
    space.lens = lens

# import bpy
# from mathutils import Vector
#
# cam = bpy.data.objects['Camera']
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
#                 override = {'area': area, 'region': region, 'edit_object': bpy.context.edit_object}
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



set_backend_port(11003)

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
