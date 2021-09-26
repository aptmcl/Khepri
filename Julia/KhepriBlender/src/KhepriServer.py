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
# "C:\Program Files\Blender Foundation\Blender 2.91\blender.exe" --python KhepriServer.py
# To test this while still allowing redefinitions do:
# "C:\Program Files\Blender Foundation\Blender 2.91\blender.exe"
# and then, in Blender's Python console
# exec(open("KhepriServer.py").read())


import sys
def warn(msg):
    print(msg, file=sys.stderr)
    sys.stderr.flush()

from bpy import ops, data as D, context as C
import bpy
import bmesh
import math
import time
import os.path
#from math import *
from mathutils import Vector, Matrix
from typing import List, Tuple, NewType
Size = NewType('Size', int)
import addon_utils
# We will use BlenderKit to download materials.
# After activating a BlenderKit account (from addon BlenderKit)
blenderkit = addon_utils.enable("blenderkit")
#dynamicsky = addon_utils.enable("lighting_dynamic_sky")
sunposition = addon_utils.enable("sun_position")

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
    asset_data = rdata['results'][0]
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
    material = append_link.append_material(file_names[-1])
    return material

# download_blenderkit_material("asset_base_id:1bdb5334-851e-414d-b766-f9fe05477860 asset_type:material")
# download_blenderkit_material("asset_base_id:31dccf38-74f4-4516-9d17-b80a45711ca7 asset_type:material")


Point3d = Vector
Vector3d = Vector
Id = Size
MatId = Size
RGBA = Tuple[float,float,float,float]

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

def new_material(name:str, diffuse_color:RGBA, specularity:float, roughness:float)->MatId:
    mat = D.materials.new(name=name)
    mat.diffuse_color=diffuse_color
    #mat.specular_color=specular_color
    mat.specular_intensity = specularity
    mat.roughness = roughness
    return add_material(mat)

def assign_material(obj, mat_idx):
    if mat_idx >= 0:
        mesh = obj.data
        material = materials[mat_idx]
        mesh.materials.append(material)
# HACK: These two are formally equivalent. Normalize!
def maybe_add_material(obj, mat):
    if mat >= 0:
        obj.data.materials.append(materials[mat])

def add_uvs(mesh):
    mesh.use_auto_texspace = True
    uvl = mesh.uv_layers.new(name='KhepriUVs')
    mesh.uv_layers.active = uvl
    for polygon in mesh.polygons:
        for vert, loop in zip(polygon.vertices, polygon.loop_indices):
            uvl.data[loop].uv = Vector((0, 0))
    uvl.active = True
    uvl.active_render = True
    return mesh

# We should be using Ints for layers!
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
    for obj in D.collections[name].objects:
        D.objects.remove(obj, do_unlink=True)

def delete_all_shapes()->None:
    #for scene in D.scenes:
    #    for obj in scene.objects:
    #        scene.objects.remove(obj, do_unlink=True)
    # only worry about data in the startup scene
    for collection in D.collections:
        for obj in collection.objects:
            D.objects.remove(obj, do_unlink=True)
    # for bpy_data_iter in (
    #     D.objects,
    #     D.meshes,
    #     #D.cameras,
    #     ):
    #     for id_data in bpy_data_iter:
    #         bpy_data_iter.remove(id_data, do_unlink=True)

def delete_shape(name:Id)->None:
    D.objects.remove(D.objects[str(name)], do_unlink=True)

def select_shape(name:Id)->None:
    D.objects[str(name)].select_set(True)

def deselect_shape(name:Id)->None:
    D.objects[str(name)].select_set(False)

def deselect_all_shapes()->None:
    for collection in D.collections:
        for obj in collection.objects:
            obj.select_set(False)

def mesh(verts:List[Point3d], edges:List[Tuple[int,int]], faces:List[List[int]], mat:MatId)->Id:
    # id, name = new_id()
    # msh = D.meshes.new(name)
    # msh.from_pydata(verts, edges, faces)
    # obj = D.objects.new(name, msh)
    # assign_material(obj, mat)
    # current_collection.objects.link(obj)
    # return id
    error("Don't use this. Use objmesh!")

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
    bm.to_mesh(mesh_data)
    bm.free()
    add_uvs(mesh_data)
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
    assign_material(obj, mat)
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
    #spline.order_u = order
    spline.use_cyclic_u = closed
    n = len(ps) - (1 if closed else 0)
    spline.points.add(n - 1)
    for i in range(0, n):
        p = ps[i]
        spline.points[i].co = (p[0], p[1], p[2], 1.0)
    assign_material(obj, mat)
    return id

def objmesh(verts:List[Point3d], edges:List[Tuple[int,int]], faces:List[List[int]], smooth:bool, mat:MatId)->Id:
    id, name = new_id()
    obj = mesh_from_bmesh(name, new_bmesh(verts, edges, faces, smooth, -1 if mat < 0 else 0))
    current_collection.objects.link(obj)
    assign_material(obj, mat)
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
    maybe_add_material(obj, mat)
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
    maybe_add_material(obj, mat)
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
    maybe_add_material(obj, bmat)
    maybe_add_material(obj, tmat)
    maybe_add_material(obj, smat)
    current_collection.objects.link(obj)
    return id

# def sphere(center:Point3d, radius:float)->Id:
#     bpy.ops.mesh.primitive_uv_sphere_add(location=center, radius=radius)
#     bpy.ops.object.shade_smooth()
#     return C.object.name

def sphere(center:Point3d, radius:float, mat:MatId)->Id:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, diameter=radius, )
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
    assign_material(obj, mat)
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
                          diameter1=br, diameter2=tr, depth=depth,
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
    maybe_add_material(obj, bmat)
    maybe_add_material(obj, tmat)
    maybe_add_material(obj, smat)
    current_collection.objects.link(obj)
    return id

def box(p:Point3d, vx:Vector3d, vy:Vector3d, dx:float, dy:float, dz:float, mat:MatId)->Id:
    id, name = new_id()
    rot = quaternion_from_vx_vy(vx, vy)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1, matrix=Matrix.Diagonal(Vector((dx, dy, dz, 1.0))),
                          # AML Scale here? May influence UVs
                          #matrix=Matrix.Translation(Vector((0, 0, -depth/2))),
                          #calc_uvs=True
                          )
    obj = mesh_from_bmesh(name, bm)
    obj.rotation_euler = rot.to_euler()
    obj.location = p
    current_collection.objects.link(obj)
    assign_material(obj, mat)
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
def area_light(p:Point3d, v:Vector3d, size:float, color:RGBA, strength:float)->Id:
    id, name = new_id()
    rot = Vector((0, 0, 1)).rotation_difference(v)  # Rotation from Z axis
    bpy.ops.object.light_add(name=name, type='AREA', location=location, rotation=rotation)
    light = C.object.data
    light.size = size
    light.use_nodes = True
    light.node_tree.nodes["Emission"].inputs["Color"].default_value = color
    light.energy = strength
    return id

def sun_light(p:Point3d, v:Vector3d)->Id:
    id, name = new_id()
    rot = Vector((0, 0, 1)).rotation_difference(v)  # Rotation from Z axis
    bpy.ops.object.light_add(name=name, type='SUN', location=p, rotation=rot)
    return id

def light(p:Point3d, type:str)->Id:
    id, name = new_id()
    light_data = D.lights.new(name, type=type)
    light = D.objects.new(name, light_data)
    light.location = p
    current_collection.objects.link(light)

def khepri_sun():
    name = 'KhepriSun'
    name = 'Sun'
    if D.objects.find(name) == -1:
        bpy.ops.object.light_add(type='SUN')
    return D.objects[name]

def set_sun(latitude:float, longitude:float, elevation:float,
            year:int, month:int, day:int, time:float,
            UTC_zone:float, use_daylight_savings:bool)->None:
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
    #sun_props.sun_object = khepri_sun()
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

def set_sky(turbidity:float)->None:
    C.scene.render.engine = 'CYCLES'
    world = find_or_create_world("World")
    world.use_nodes = True
    bg = find_or_create_node(world.node_tree, "BACKGROUND", "")
    sky = find_or_create_node(world.node_tree, "TEX_SKY", "ShaderNodeTexSky")
    #sky.sky_type = "HOSEK_WILKIE"
    sky.sky_type = "NISHITA"
    sky.turbidity = turbidity
    sky.dust_density = turbidity
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
    if D.objects.find(name) is -1:
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

# def set_camera_view(camera:Point3d, target:Point3d, lens:float)->None:
#     direction = camera - target
#     rot_quat = direction.to_track_quat('Z', 'Y')
#     cam = khepri_camera()
#     cam.rotation_euler = rot_quat.to_euler()
#     cam.location = rot_quat @ Vector((0.0, 0.0, direction.length))
#     cam.data.lens = lens
#     C.scene.camera = cam
#
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

def cycles_renderer(samples:int, denoising:bool, motion_blur:bool, transparent:bool)->None:
    C.scene.render.engine = 'CYCLES'
    C.scene.render.use_motion_blur = motion_blur
    C.scene.render.film_transparent = transparent
    C.scene.view_layers[0].cycles.use_denoising = denoising
    C.scene.cycles.samples = samples
    C.scene.cycles.device = "GPU"
    C.preferences.addons["cycles"].preferences.compute_device_type = "CUDA"
    C.preferences.addons["cycles"].preferences.get_devices()
    for d in C.preferences.addons["cycles"].preferences.devices:
        d["use"] = 1
    bpy.ops.render.render(use_viewport = True, write_still=True)

#######################################
# Communication
#Python provides sendall but not recvall
def recvall(sock, count):
    buf = b''
    while count:
        newbuf = sock.recv(count)
        if not newbuf: return None
        buf += newbuf
        count -= len(newbuf)
    return buf

"""


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

def dump_exception(ex, conn):
    warn('Dumping exception!!!')
    warn("".join(traceback.TracebackException.from_exception(ex).format()))
    w_str("".join(traceback.TracebackException.from_exception(ex).format()), conn)

def r_struct(s, conn):
    return s.unpack(recvall(conn, s.size))[0]

def w_struct(s, e, conn):
    conn.sendall(s.pack(e))

def e_struct(s, e, ex, conn):
    w_struct(s, e, conn)
    dump_exception(ex, conn)

def r_tuple_struct(s, conn):
    return s.unpack(recvall(conn, s.size))

def w_tuple_struct(s, e, conn):
    conn.sendall(s.pack(*e))

def e_tuple_struct(s, e, ex, conn):
    w_tuple_struct(s, e, conn)
    dump_exception(ex, conn)

def r_list_struct(s, conn):
    n = r_int(conn)
    es = []
    for i in range(n):
        es.append(r_struct(s, conn))
    return es

def w_list_struct(s, es, conn):
    w_int(len(es), conn)
    for e in es:
        w_struct(s, e, conn)

def e_list(ex, conn):
    w_int(-1, conn)
    dump_exception(ex, conn)

int_struct = struct.Struct('i')
float_struct = struct.Struct('d')
byte_struct = struct.Struct('1B')

def w_None(e, conn)->None:
    w_struct(byte_struct, 0, conn)

e_None = partial(e_struct, byte_struct, 127)

def r_bool(conn)->bool:
    return r_struct(byte_struct, conn) == 1
def w_bool(b:bool, conn)->None:
    w_struct(byte_struct, 1 if b else 0, conn)

e_bool = partial(e_struct, byte_struct, 127)

r_int = partial(r_struct, int_struct)
w_int = partial(w_struct, int_struct)
e_int = partial(e_struct, int_struct, -12345678)

r_float = partial(r_struct, float_struct)
w_float = partial(w_struct, float_struct)
e_float = partial(w_struct, float_struct, math.nan)

r_Size = partial(r_struct, int_struct)
w_Size = partial(w_struct, int_struct)
e_Size = partial(e_struct, int_struct, -1)

def r_str(conn)->str:
    size = 0
    shift = 0
    byte = 0x80
    while byte & 0x80:
        try:
            byte = ord(conn.recv(1))
        except TypeError:
            raise IOError('Buffer empty')
        size |= (byte & 0x7f) << shift
        shift += 7
    return recvall(conn, size).decode('utf-8')

def w_str(s:str, conn):
    size = len(s)
    array = bytearray()
    while True:
        byte = size & 0x7f
        size >>= 7
        if size:
            array.append(byte | 0x80)
        else:
            array.append(byte)
            break
    conn.send(array)
    conn.sendall(s.encode('utf-8'))

def e_str(ex, conn)->None:
    w_str("This an error!", conn)
    dump_exception(ex, conn)

float3_struct = struct.Struct('3d')
def r_Vector(conn)->Vector:
    s = float3_struct
    return Vector(s.unpack(recvall(conn, s.size)))

def w_Vector(e:Vector, conn)->None:
    s = float3_struct
    conn.sendall(s.pack(e.x, e.y, e.z))

e_Vector = e_float

def r_List(f, conn):
    n = r_int(conn)
    es = []
    for i in range(n):
        es.append(f(conn))
    return es

def w_List(f, es, conn):
    w_int(len(es), conn)
    for e in es:
        f(e, conn)

e_List = e_list

r_List_int = partial(r_List, r_int)
w_List_int = partial(w_List, w_int)
e_List_int = e_List

r_List_float = partial(r_List, r_float)
w_List_float = partial(w_List, w_float)
e_List_float = e_List

r_List_List_int = partial(r_List, r_List_int)
w_List_List_int = partial(w_List, w_List_int)
e_List_List_int = e_List

r_List_Vector = partial(r_List, r_Vector)
w_List_Vector = partial(w_List, w_Vector)
e_List_Vector = e_List

r_List_List_Vector = partial(r_List, r_List_Vector)
w_List_List_Vector = partial(w_List, w_List_Vector)
e_List_List_Vector = e_List

int_int_struct = struct.Struct('2i')
r_Tint_intT = partial(r_tuple_struct, int_int_struct)
w_Tint_intT = partial(w_tuple_struct, int_int_struct)

r_List_Tint_intT = partial(r_List, r_Tint_intT)
w_List_Tint_intT = partial(w_List, w_Tint_intT)
e_List_Tint_intT = e_List

##############################################################
# For automatic generation of serialize/deserialize code
import inspect

def is_tuple_type(t)->bool:
    return hasattr(t, '__origin__') and t.__origin__ is tuple

def tuple_elements_type(t):
    return t.__args__

def is_list_type(t)->bool:
    return hasattr(t, '__origin__') and t.__origin__ is list

def list_element_type(t):
    return t.__args__[0]

def method_name_from_type(t)->str:
    if is_list_type(t):
        return "List_" + method_name_from_type(list_element_type(t))
    elif is_tuple_type(t):
        return "T" + '_'.join([method_name_from_type(pt) for pt in tuple_elements_type(t)]) + 'T'
    elif t is None:
        return "None"
    else:
        return t.__name__

def deserialize_parameter(c:str, t)->str:
    if is_tuple_type(t):
        return '(' + ','.join([deserialize_parameter(c, pt) for pt in tuple_elements_type(t)]) + ',)'
    else:
        return f"r_{method_name_from_type(t)}({c})"

def serialize_return(c:str, t, e:str)->str:
    if is_tuple_type(t):
        return f"__r = {e}; " + '; '.join([serialize_return(c, pt, f"__r[{i}]")
                                           for i, pt in enumerate(tuple_elements_type(t))])
    else:
        return f"w_{method_name_from_type(t)}({e}, {c})"

def serialize_error(c:str, t, e:str)->str:
    if is_tuple_type(t):
        return serialize_error(c, tuple_elements_type(t)[0], e)
    else:
        return f"e_{method_name_from_type(t)}({e}, {c})"

def try_serialize(c:str, t, e:str)->str:
    return f"""
    try:
        {e}
    except Exception as __ex:
        warn('RMI Error!!!!')
        warn("".join(traceback.TracebackException.from_exception(__ex).format()))
        warn('End of RMI Error.  I will attempt to serialize it.')
        {serialize_error(c, t, "__ex")}"""

def generate_rmi(f):
    c = 'c'
    name = f.__name__
    sig = inspect.signature(f)
    rt = sig.return_annotation
    pts = [p.annotation for p in sig.parameters.values()]
    des_pts = ','.join([deserialize_parameter(c, p) for p in pts])
    body = try_serialize(c, rt, serialize_return(c, rt, f"{name}({des_pts})"))
    dict = globals()
    rmi_name = f"rmi_{name}"
    rmi_f = f"def {rmi_name}({c}):{body}"
    warn(rmi_f)
    exec(rmi_f, dict)
    return dict[rmi_name]

##############################################################
# Socket server
import socket

socket_server = None
connection = None
current_action = None
min_wait_time = 0.1
max_wait_time = 0.2
max_repeated = 1000

def read_operation(conn):
    return r_int(conn)

def try_read_operation(conn):
    conn.settimeout(min_wait_time)
    try:
        return read_operation(conn)
    except socket.timeout:
        return -2
    finally:
        conn.settimeout(None)

def execute_read_and_repeat(op, conn):
    count = 0
    while True:
        if op == -1:
            return False
        execute(op, conn)
        count =+ 1
        if count > max_repeated:
            return False
        conn.settimeout(max_wait_time)
        try:
            op = read_operation(conn)
        except socket.timeout:
            break
        finally:
            conn.settimeout(None)
    return True;


operations = []

def provide_operation(name:str)->int:
    warn(f"Requested operation |{name}| -> {globals()[name]}")
    operations.append(generate_rmi(globals()[name]))
    return len(operations) - 1

# The first operation is the operation that makes operations available
operations.append(generate_rmi(provide_operation))


def execute(op, conn):
    operations[op](conn)

def wait_for_connection():
    global current_action
    warn('Waiting for connection...')
    current_action = accept_client

def start_server():
    global socket_server
    socket_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    socket_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    socket_server.bind(('localhost', 11003))
    socket_server.settimeout(max_wait_time)
    socket_server.listen(5)
    wait_for_connection()

counter_accept_attempts = 1
def accept_client():
    global counter_accept_attempts
    global connection
    global current_action
    try:
        #warn(f"Is anybody out there? (attempt {counter_accept_attempts})")
        connection, client_address = socket_server.accept()
        warn('Connection established.')
        current_action = handle_client
    except socket.timeout:
        counter_accept_attempts += 1
        #warn('It does not seem that there is.')
        # keep trying
        pass
    except Exception as ex:
        warn('Something bad happened!')
        traceback.print_exc()
        #warn('Resetting socket server.')


def handle_client():
    conn = connection
    op = try_read_operation(conn)
    if op == -1:
        warn("Connection terminated.")
        wait_for_connection()
    elif op == -2:
        # timeout
        pass
    else:
        execute_read_and_repeat(op, conn)

current_action = start_server

import traceback

def execute_current_action():
    #warn(f"Execute {current_action}")
    try:
        current_action()
    except Exception as ex:
        traceback.print_exc()
        #warn('Resetting socket server.')
        warn('Killing socket server.')
        if connection:
            connection.close()
        wait_for_connection()
        # AML Remove when corrected
        #bpy.app.timers.unregister(execute_current_action)
    finally:
        return max_wait_time # timer

import addon_utils

class Khepri(object):
    def __init__(self):
        pass

if bpy.app.background:
    while True:
        execute_current_action()
else:
    bpy.app.timers.register(execute_current_action)

#bpy.app.timers.register(execute_current_action)

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
."""
