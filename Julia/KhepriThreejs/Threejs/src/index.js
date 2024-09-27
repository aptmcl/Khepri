import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GUI } from 'three/addons/libs/lil-gui.module.min.js';
import { Sky } from 'three/addons/objects/Sky.js';
import { OutlineEffect } from 'three/addons/effects/OutlineEffect.js';

// Types
class PrimitiveType {
    constructor(name, size, read, write=(io, v) => console.error("No writer defined for ", name, this)) {
        this.name = name;
        this.size = size;
        this.read = read;
        this.write = write;
    }
}

const None = new PrimitiveType("None", 1, (io) => console.log("Can't read none"), (io, v) => io.writeUInt8(0));
const Bool = new PrimitiveType("Bool", 1, (io) => io.readUInt8()!=0, (io, v) => io.writeUInt8(v ? 1 : 0));
const Int64 = new PrimitiveType("Int64", 8, (io) => io.readInt64(), (io, v) => io.writeInt64(v));
const Int32 = new PrimitiveType("Int32", 4, (io) => io.readInt32(), (io, v) => io.writeInt32(v));
const Float64 = new PrimitiveType("Float64", 8, (io) => io.readFloat64(), (io, v) => io.writeFloat64(v));
const Float32 = new PrimitiveType("Float32", 4, (io) => io.readFloat32(), (io, v) => io.writeFloat32(v));
const Matrix4x4 = new PrimitiveType("Matrix4x4", 16*4, (io) => new THREE.Matrix4(...io.readArrayFloat32(16)), (io, v) => io.writeArrayFloat32(16, v));
// Threejs aligns objects along the Y axis but we prefer the Z axis. The conversion is done on the frontend.
const Matrix4x4Y = Matrix4x4;
const ArrayFloat32 = new PrimitiveType("ArrayFloat32", Infinity, (io) => io.readArrayFloat32(io.readInt32()), (io, v) => io.writeArrayFloat32(v.length, v));
const ArrayInt32 = new PrimitiveType("ArrayInt32", Infinity, (io) => io.readArrayInt32(io.readInt32()), (io, v) => io.writeArrayInt32(v.length, v));
const ArrayUInt32 = new PrimitiveType("ArrayUInt32", Infinity, (io) => io.readArrayUInt32(io.readInt32()), (io, v) => io.writeArrayUInt32(v.length, v));
const Str = new PrimitiveType("Str", Infinity, (io) => io.readString(), (io, v) => io.writeString(v));
const Id = new PrimitiveType("Id", 4, (io) => getMesh(io.readInt32()), (io, v) => io.writeInt32(addMesh(v)));
const MatId = new PrimitiveType("MatId", 4, (io) => getMaterial(io.readInt32()), (io, v) => io.writeInt32(addMaterial(v)));
const GUIId = new PrimitiveType("GUIId", 4, (io) => getGUI(io.readInt32()), (io, v) => io.writeInt32(addGUI(v)));
const Dict = new PrimitiveType("Dict", Infinity, (io) => io.readDict());
const Any = new PrimitiveType("Any", Infinity, (io) => io.readAny());

class CompositeType {
    constructor(name, subtypes, combiner) {
        this.name = name;
        this.subtypes = subtypes;
        this.read = (io) => combiner(subtypes.map(st=>io.readType(st)));
        this.write = (io, v) => console.error("Finish this!");
    }
}
const Float3 = new CompositeType("FLoat3", [Float32, Float32, Float32], args => args);
const Vector3d = new CompositeType("Vector3d", [Float32, Float32, Float32], args => new THREE.Vector3(...args));
const Point3d = new CompositeType("Point3d", [Float32, Float32, Float32], args => new THREE.Vector3(...args));
const Point2d = new CompositeType("Point2d", [Float32, Float32], args => new THREE.Vector2(...args));
const RGB = new CompositeType("FLoat3", [Float32, Float32, Float32], args => new THREE.Color(...args));

/*
It is also useful to pass arbitrary objects, as these are sometimes used as keyword args.
*/

const UntypedObject = new PrimitiveType("UntypedObject", Infinity, (io) => io.readUntypedObject())

class IODataView {
    static dataSize = { Int64:8, Int32:4, Int16:2, Int8:1, UInt64:8, UInt32:4, UInt16:2, UInt8:1, Float64:8, Float32:4, Float16:2 }
    constructor(dataView) {
        this.dataView = dataView; 
        this.offset = 0;
    }
    checkExhausted() {
        if (this.offset != this.dataView.byteLength) {
            console.error("IODataView is not exhausted! offset:", this.offset, " length:", this.dataView.byteLength);
        }
    }
    readType(type) {
        //console.log("Reading type", type);
        return Array.isArray(type) ?
            Array.from({length:this.readInt32()}, (_, i) => this.readType(type[0])) :
            type.read(this);
    }
    writeType(type, v) {
        if (Array.isArray(type)) {
            this.writeInt32(v.length);
            v.forEach(e => this.writeType(type[0], e));
        } else {
            type.write(this, v)
        }
    }
    readTypedObject(type) {
        const obj = {};
        for (const key in type) {
            val = this.readType(type[key]);
            obj[key] = val;
        }
        return obj;
    }
    readDict() {
        const keys = this.readInt32();
        const obj = {};
        for (let i = 0; i < keys; i++) {
            const key = this.readString();
            const val = this.readAny();
            obj[key] = val;
        }
        return obj;
    }
    readAny() {
        const code = this.readUInt8();
        switch (code) {
        case 0:
            return Bool.read(this);
        case 1:
            return this.readUInt8();
        case 2:
            return this.readInt32();
        case 3:
            return this.readInt64();
        case 4:
            return this.readFloat32();
        case 5:
            return this.readFloat64();
        case 6:
            return this.readString();
        case 7:
        case 8:
            return RGB.read(this);
        case 9:
            return this.readDict();
        default:
            console.error("Unknown object code", code)
        }
    }
    readInt64() {
        const size = IODataView.dataSize.Int64;
        this.offset += size;
        //Convert BigInt to Number because BigInts cannot be used in many cases
        return Number(this.dataView.getBigInt64(this.offset - size, true));
    }
    readInt32() {
        const size = IODataView.dataSize.Int32;
        this.offset += size;
        return this.dataView.getInt32(this.offset - size, true);
    }
    writeInt32(v) {
        const size = IODataView.dataSize.Int32;
        this.offset += size;
        return this.dataView.setInt32(this.offset - size, v, true);
    }
    readInt16() {
        const size = IODataView.dataSize.Int16;
        this.offset += size;
        return this.dataView.getInt16(this.offset - size, true);
    }
    readInt8() {
        const size = IODataView.dataSize.Int8;
        this.offset += size;
        return this.dataView.getUint8(this.offset - size, true);
    }
    readUInt64() {
        const size = IODataView.dataSize.UInt64;
        this.offset += size;
        //Convert BigInt to Number because BigInts cannot be used in many cases
        return Number(this.dataView.getBigUint64(this.offset - size, true));
    }
    readUInt32() {
        const size = IODataView.dataSize.UInt32;
        this.offset += size;
        return this.dataView.getUint32(this.offset - size, true);
    }
    readUInt16() {
        const size = IODataView.dataSize.UInt16;
        this.offset += size;
        return this.dataView.getUint16(this.offset - size, true);
    }
    readUInt8() {
        const size = IODataView.dataSize.UInt8;
        this.offset += size;
        return this.dataView.getUint8(this.offset - size, true);
    }
    writeUInt8(v) {
        const size = IODataView.dataSize.UInt8;
        this.offset += size;
        return this.dataView.setUint8(this.offset - size, v, true);
    }
    readFloat64() {
        const size = IODataView.dataSize.Float64;
        this.offset += size;
        return this.dataView.getFloat64(this.offset - size, true);
    }
    readFloat32() {
        const size = IODataView.dataSize.Float32;
        this.offset += size;
        return this.dataView.getFloat32(this.offset - size, true);
    }
    readFloat16() {
        const size = IODataView.dataSize.Float16;
        this.offset += size;
        return this.dataView.getFloat16(this.offset - size, true);
    }
    readArrayUInt8(n) {
        const arr = new Uint8Array(n);
        for (let i = 0; i < n; i++) {
            arr[i] = this.readUInt8();
        }
        return arr;
    }
    readArrayUInt32(n) {
        const arr = new Uint32Array(n);
        for (let i = 0; i < n; i++) {
            arr[i] = this.readUInt32();
        }
        return arr;
    }
    readArrayInt32(n) {
        const arr = new Int32Array(n);
        for (let i = 0; i < n; i++) {
            arr[i] = this.readInt32();
        }
        return arr;
    }
    readArrayFloat32(n) {
        const arr = new Float32Array(n);
        for (let i = 0; i < n; i++) {
            arr[i] = this.readFloat32();
        }
        return arr;
    }
    writeArrayFloat32(n, v) {
        for (let i = 0; i < n; i++) {
            this.writeFloat32(v[i]);
        }
    }
    writeArrayFloat32(n, v) {
        this.writeInt32(n);
        this.writeArrayFloat32(n, v);
    }
    readString() {
        let size = 0;
        let shift = 0;
        const decoder = new TextDecoder();
        while(true) {
            let b = this.readUInt8();
            size = size | ((b & 0x7f) << shift);
            if ((b & 0x80) == 0) {
                this.offset += size;
                return decoder.decode(new DataView(this.dataView.buffer, this.offset-size, size));
            } else {
              shift += 7;
            }
        }
    }
}

////////////////////////////////////////////////////////////////////////////
/*
We need to store objects (e.g., materials, shapes, etc) internally.
*/

let scene, camera, grid, light, renderer, controls, outlineEffect;
let defaultMaterial, defaultLineMaterial, wireframeMaterial, selectedMaterial, wireframeActive;
let update = true;
let updateFunction;

/*
Utilities
*/

function withTransform(m, obj) {
    m.decompose(obj.position, obj.quaternion, obj.scale);
    return obj;
}

/*
Using a array does not seem like the best option, particularly, 
because when we delete shapes we leave undefined 'holes' in the array, 
which cause errors, e.g., in raycasting.
Another option is to use a dictionary and a reverse property on each shape
to know its id.
*/
const meshes = [];
function addMesh(obj) {
    obj.castShadow = true;
    obj.receiveShadow = true;
    obj.geometry.computeVertexNormals();
    wireframeCheck(obj);
    scene.add(obj);
    return meshes.push(obj) - 1;
}
function getMesh(idx) {
    return meshes[idx];
}
function delMesh(idx) {
    if (meshes[idx]) {
        meshes[idx].removeFromParent();
        meshes[idx].geometry.dispose();
        delete meshes[idx];
        return idx;
    } else {
        console.error(`Requested non-existent mesh with id '${idx}'.`);
    }
}
function delAllMeshes() {
    let length = meshes.length;
    meshes.forEach(m => { m.removeFromParent(); m.geometry.dispose(); });
    meshes.length = 0;
    return length;
}

let spriteMaterial;
const sprites = [];

// Sprites for annotations
class Annotation extends THREE.Sprite {
    constructor(title, content, material) {
        const div = document.createElement("div");
        div.classList.add(`annotation`);
        const p = document.createElement("p");
        div.appendChild(p);
    /*    var strong = document.createElement("strong");
        p.appendChild(strong);
        strong.innerText = "◤ " + title;
        p = document.createElement("p");*/
        p.innerText = content;
        //div.appendChild(p);
        document.body.appendChild(div);
        super(material);
        this.userData.KhepriDOM = div;
        sprites.push(this);
    }
    removeFromParent() {
        sprites.splice(sprites.findIndex(e => e === this), 1);
        document.body.removeChild(this.userData.KhepriDOM);
        super.removeFromParent();
    }
}

function newAnnotation(pos, title, content) {
    const ann = new Annotation(title, content, spriteMaterial);
    ann.position.copy(pos);
    ann.scale.set(2, 2, 1);
    return ann;
}


function addSprite(pos, title, content) {
    const div = document.createElement("div");
    div.classList.add(`annotation`);
    const p = document.createElement("p");
    div.appendChild(p);
/*    var strong = document.createElement("strong");
    p.appendChild(strong);
    strong.innerText = "◤ " + title;
    p = document.createElement("p");*/
    p.innerText = content;
    div.appendChild(p);
    document.body.appendChild(div);
    const sprite = new THREE.Sprite(spriteMaterial);
    sprite.position.copy(pos);
    sprite.scale.set(2, 2, 1);
    sprite.userData.KhepriDOM = div;
    scene.add(sprite);
    return sprites.push(sprite) - 1;
}
function delSprite(idx) {
    document.body.removeChild(sprites[idx].userData.KhepriDOM);
    sprites[idx].removeFromParent();
    sprites[idx].geometry.dispose();
    delete sprites[idx];
    return idx;
}
function delAllSprites() {
    const length = sprites.length;
    const body = document.body;
    sprites.forEach(s => { body.removeChild(s.userData.KhepriDOM); });
    sprites.length = 0;
    return length;
}



function wireframeCheck(obj) {
    if (wireframeActive) {
        if (obj.userData.KhepriWireframe) {
            obj.userData.KhepriWireframe.visible = true;
        } else {
            const wireframe = new THREE.LineSegments(new THREE.WireframeGeometry(obj.geometry), wireframeMaterial);
            obj.userData.KhepriWireframe = wireframe;
            obj.add(wireframe);
        }
    } else {
        if (obj.userData.KhepriWireframe) {
            obj.userData.KhepriWireframe.visible = false;
        }
    }
}

function setWireframeActive(v) {
    wireframeActive = v;
    meshes.forEach(wireframeCheck);
}

let selected = [];
function select(obj) {
    if (obj.userData.KhepriSelected) {
        obj.userData.KhepriSelected.visible = true;
    } else {
        const isSelected = new THREE.Mesh(obj.geometry, selectedMaterial);
        obj.userData.KhepriSelected = isSelected;
        obj.add(isSelected);
    }
    selected.push(obj);
}
function deselect(obj) {
    if (obj.userData.KhepriSelected) {
        obj.userData.KhepriSelected.visible = false;
    }
    selected = selected.filter((e) => e !== obj);
}
function deselectAll() {
    selected.forEach((e, _) => e.userData.KhepriSelected.visible = false);
    selected = [];
}
function getSelected() {
    return selected;
}


//There is a problem with quads and trigs that forces the used of double sided materials.
const materials = [];
function addMaterial(obj) {
    return materials.push(obj) - 1;
}
function getMaterial(idx) {
    return idx == -1 ? defaultMaterial : materials[idx];
}
function delMaterial(idx) {
    delete materials[idx];
}
function delAllMaterials() {
    materials.length = 0;
}

//The GUI panel can have children
const guis = [];
function addGUI(obj) {
    return guis.push(obj) - 1;
}
// We use the trick of knowing that Ids are Int32 so we just get the index
function getGUI(idx) {
    return guis[idx];
}
function delGUI(idx) {
    guis[idx].destroy()
    delete guis[idx];
}

//Operations
const operations = [];

function getOperation(idx) {
    return operations[idx];
}

function typedFunction(name, argTypes, retType, f) {
    f.argType = new CompositeType("ArgTypes", argTypes, args => args);
    f.retType = retType;
    operations[name] = operations.push(f) - 1; // operations[name] provides the function index
    return f;
}

typedFunction("getOperationNamed", [Str], Int32, (name) => { 
    let idx = operations[name];
    if (idx) {
        return idx;
    } else {
        console.error(`Requested non-existent function named '${name}'.`);
        return -1;
    }
});


// We use the trick of knowing that Ids are Int32 so we just get the index
typedFunction("delete", [Int32], None, (i) => delMesh(i));

typedFunction("deleteAll", [], None, () => { 
    delAllMeshes();
    delAllSprites();
});


typedFunction("addAnnotation", [Point3d, Str], Int32, (p, txt) => addSprite(p, "", txt));
typedFunction("deleteAnnotation", [Int32], None, (i) => delSprite(i));


//typedFunction("addAnnotation", [Point3d, Str], Id, (p, txt) => newAnnotation(p, "", txt));
//typedFunction("deleteAnnotation", [Int32], None, (i) => delSprite(i));

///////////////////////////////////////////
// This is going to be useful to implement callbacks from the GUI
function send(request) {
    fetch(request)
    .then(response => response.json())
	.then(data => console.log(data))
	.catch(err => console.error(err));
}

typedFunction("guiCreate", [Str, Int32], GUIId, (title, kind) => {    
    const gui = new GUI({ title: title });
    if (kind == 1) {
        const params = {
            grid: true,
            wireFrame: wireframeActive,
            outline: false,
            shading: 'glossy',
        };
    //  gui.add(params, '???', [ 2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 40, 50 ] ).name( 'Tessellation Level' ).onChange( render );
        gui.add(params, 'grid').name('Grid?').onChange(() => grid.visible = params.grid);
        gui.add(params, 'wireFrame').name('Wireframe?').onChange(setWireframeActive);
        gui.add(params, 'outline').name('Outline').onChange(() => outlineEffect.enabled = params.outline);
    //  gui.add(params, 'body' ).name( 'display body' ).onChange( render );
    //  gui.add(params, 'bottom' ).name( 'display bottom' ).onChange( render );
    //  gui.add(params, 'fitLid' ).name( 'snug lid' ).onChange( render );
    //  gui.add(params, 'nonblinn' ).name( 'original scale' ).onChange( render );
    //  gui.add(params, 'newShading', [ 'wireframe', 'flat', 'smooth', 'glossy', 'textured', 'reflective' ] ).name( 'Shading' ).onChange( render );
        outlineEffect.enabled = params.outline;
    }
    return gui;
});

typedFunction("guiAddFolder", [GUIId, Str], GUIId, (gui, title) =>
    gui.addFolder(title));

typedFunction("guiAddButton", [GUIId, Str, Str], None, (gui, name, request) => {
    const param = { field: () => send(request) };
    gui.add(param, 'field').name(name);
});

onChangeMakeRequest(prev, request) = 
    (value) => {
        // HACK Stop accepting changes when update is false!!!!!
        if (value != prev) {
            prev = value;
            send(request + "?p0=" + value)
        }
    } 

typedFunction("guiAddCheckbox", [GUIId, Str, Str, Bool], None, (gui, name, request, curr) => {
    const param = { field: curr };
    gui.add(param, 'field').name(name).onChange(onChangeMakeRequest(curr, request));
});

typedFunction("guiAddSlider", [GUIId, Str, Str, Float32, Float32, Float32, Float32], None, (gui, name, request, min, max, step, curr) => {
    const param = { field: curr };
    gui.add(param, 'field', min, max, step).name(name).onChange(onChangeMakeRequest(curr, request));
});

typedFunction("guiAddDropdown", [GUIId, Str, Str, Dict, Int32], None, (gui, name, request, options, curr) => {
    const param = { field: curr };
    gui.add(param, 'field', options).name(name).onChange(onChangeMakeRequest(curr, request));
});


///////////////////////
// Grid Helper

typedFunction("gridHelper", [Int32, Int32, RGB, RGB], None, (size, divisions, colorCenterLine, colorGrid) => {
    if (grid) {
        grid.removeFromParent();
        grid.dispose();
    }
    grid = new THREE.GridHelper(size, divisions, colorCenterLine, colorGrid);
    grid.rotateX(-Math.PI/2);
    //grid.translateY(1);
    //grid.renderOrder = 1;
    scene.add(grid);
});

///////////////////////
// The graphical stuff

typedFunction("points", [[Point3d], MatId], Id, (vs, mat) => {
    return new THREE.Points(new THREE.BufferGeometry().setFromPoints(vs), mat);
});

typedFunction("line", [[Point3d], MatId], Id, (vs, mat) => {
    return new THREE.Line(new THREE.BufferGeometry().setFromPoints(vs), mat);
});

typedFunction("spline", [[Point3d], Bool, MatId], Id, (vs, closed, mat) => {
    const pts = new THREE.CatmullRomCurve3(vs, closed).getPoints(Math.round(8*(vs.length)));
    return new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), mat);
});

//This computes a mesh, not a curve!
typedFunction("arc", [Matrix4x4, Float32, Float32, Float32, MatId], Id, (m, r, start, finish, mat) => {
    const pts = new THREE.ArcCurve(0, 0, r, start, finish, finish < start)
        .getPoints(Math.round(64*((Math.abs(finish-start))/2/Math.PI)));
    return withTransform(m, new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), mat));
});

typedFunction("arcRegion", [Matrix4x4Y, Float32, Float32, Float32, MatId], Id, (m, r, start, amplitude, mat) => {
    const geo = new THREE.CircleGeometry(r, Math.round(64*(amplitude/2/Math.PI)), start, amplitude);
    return withTransform(m, new THREE.Mesh(geo, mat));
});


typedFunction("surfacePolygonWithHoles", [Matrix4x4, [Point2d], [[Point2d]], MatId], Id, (m, ps, qss, mat) => {
    const faces = THREE.ShapeUtils.triangulateShape(ps, qss);
    const vs = new Float32Array((ps.length + qss.reduce((n, qs) => n + qs.length, 0))*3);
    let k = 0;
    ps.forEach(p => {
        vs[k++] = p.x;
        vs[k++] = p.y;
        vs[k++] = 0.0;
    });
    qss.forEach(qs => qs.forEach(q => {
            vs[k++] = q.x;
            vs[k++] = q.y;  
            vs[k++] = 0.0;
        }));
    
    const geo = new THREE.BufferGeometry();
    geo.setIndex([].concat(...faces));
    geo.setAttribute('position', new THREE.BufferAttribute(vs, 3));
    return withTransform(m, new THREE.Mesh(geo, mat));
});

typedFunction("sphere", [Point3d, Float32, MatId], Id, (c, r, mat) => {
    const geo = new THREE.SphereGeometry(r, 64, 64);
    const obj = new THREE.Mesh(geo, mat);
    obj.position.copy(c);
    return obj;
});

typedFunction("box", [Matrix4x4, Float32, Float32, Float32, MatId], Id, (m, dx, dy, dz, mat) =>
    withTransform(m, new THREE.Mesh(new THREE.BoxGeometry(dx, dy, dz), mat)));

typedFunction("torus", [Matrix4x4, Float32, Float32, MatId], Id, (m, re, ri, mat) =>
    withTransform(m, new THREE.Mesh(new THREE.TorusGeometry(re, ri, 64, 32), mat)));

typedFunction("cylinder", [Matrix4x4Y, Float32, Float32, Float32, MatId], Id, (m, rb, rt, h, mat) =>
    withTransform(m, new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, 64), mat)));

typedFunction("mesh", [ArrayFloat32, MatId], Id, (vs, idxs, mat) => {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(vs, 3));
    return new THREE.Mesh(geo, mat);
});

typedFunction("meshIndexed", [ArrayFloat32, ArrayInt32, MatId], Id, (vs, idxs, mat) => {
    const geo = new THREE.BufferGeometry();
    geo.setIndex(Array.from(idxs)); //geo.setAttribute('index', new THREE.BufferAttribute(idxs, 1));
    geo.setAttribute('position', new THREE.BufferAttribute(vs, 3));
    return new THREE.Mesh(geo, mat);
});

typedFunction("MeshPhysicalMaterial", [Dict], MatId, (params) => 
    new THREE.MeshPhysicalMaterial(params));

typedFunction("MeshStandardMaterial", [Dict], MatId, (params) => 
    new THREE.MeshStandardMaterial(params));

typedFunction("MeshPhongMaterial", [Dict], MatId, (params) => 
    new THREE.MeshPhongMaterial(params));

typedFunction("MeshLambertMaterial", [Dict], MatId, (params) => 
    new THREE.MeshLambertMaterial(params));

typedFunction("LineBasicMaterial", [Dict], MatId, (params) => 
    new THREE.LineBasicMaterial(params));

typedFunction("setView", [Point3d, Point3d, Float32, Float32], None, (position, target, lens, aperture) => {
    const sensorHeight = 24; // Typical 35mm film height in mm
    const fovInDegrees = THREE.MathUtils.radToDeg(2 * Math.atan(sensorHeight/(2*lens)));
    camera.fov = fovInDegrees;
    camera.position.copy(position);
    camera.lookAt(target);
    const d = position.distanceTo(target);
    camera.near = Math.max(0.1, d*0.1);
    camera.far = Math.min(2000, d*20000);
    camera.updateProjectionMatrix();
    controls.target.copy(target);
    controls.update();
});
// See https://github.com/mrdoob/three.js/pull/14526
function zoomCameraToSelection( camera, controls, selection) {
    const box = new THREE.Box3();
    for(const object of selection) box.expandByObject(object);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());
    const maxSize = Math.max(size.x, size.y, size.z);
    const fitHeightDistance = maxSize/(2*Math.atan(Math.PI*camera.fov/360));
    const fitWidthDistance = fitHeightDistance/camera.aspect;
    const distance = Math.max(fitHeightDistance, fitWidthDistance);
    const direction = controls.target.clone()
      .sub( camera.position )
      .normalize()
      .multiplyScalar( distance );
    //controls.maxDistance = distance * 10;
    controls.target.copy(center);
    camera.near = distance / 100;
    camera.far = distance * 100;
    camera.position.copy(controls.target).sub(direction);
    camera.updateProjectionMatrix();
    controls.update();
  }

typedFunction("zoomExtents", [], None, () => {
    zoomCameraToSelection(camera, controls, meshes);
/*    const boundingBox = new THREE.Box3();
    meshes.forEach(object => boundingBox.expandBy(object));
    const center = boundingBox
    return boundingBox;*/
});

typedFunction("setSky", [Point3d, Point3d, Float32, Float32], None, (position, target, lens, aperture) => {
/*    // Add Sky
				sky = new Sky();
				sky.scale.setScalar( 450000 );
				scene.add( sky );

				sun = new THREE.Vector3();

				/// GUI

				const effectController = {
					turbidity: 10,
					rayleigh: 3,
					mieCoefficient: 0.005,
					mieDirectionalG: 0.7,
					elevation: 2,
					azimuth: 180,
					exposure: renderer.toneMappingExposure
				};

				function guiChanged() {

					const uniforms = sky.material.uniforms;
					uniforms[ 'turbidity' ].value = effectController.turbidity;
					uniforms[ 'rayleigh' ].value = effectController.rayleigh;
					uniforms[ 'mieCoefficient' ].value = effectController.mieCoefficient;
					uniforms[ 'mieDirectionalG' ].value = effectController.mieDirectionalG;

					const phi = THREE.MathUtils.degToRad( 90 - effectController.elevation );
					const theta = THREE.MathUtils.degToRad( effectController.azimuth );

					sun.setFromSphericalCoords( 1, phi, theta );

					uniforms[ 'sunPosition' ].value.copy( sun );

					renderer.toneMappingExposure = effectController.exposure;
					renderer.render( scene, camera );

				}
*/
});

typedFunction("stopUpdate", [], None, () => {
    update = false;
});
typedFunction("startUpdate", [], None, () => { 
    update = true;
});

class InfiniteGridHelper extends THREE.Mesh {
    constructor (size1, size2, color, distance, axes = 'xzy') {
        color = color || new THREE.Color( 'white' );
        size1 = size1 || 10;
        size2 = size2 || 100;
        distance = distance || 8000;

        const planeAxes = axes.substr( 0, 2 );
        const geometry = new THREE.PlaneGeometry( 2, 2, 1, 1 );
        const material = new THREE.ShaderMaterial( {
            side: THREE.DoubleSide,
            uniforms: {
                uSize1: {
                    value: size1
                },
                uSize2: {
                    value: size2
                },
                uColor: {
                    value: color
                },
                uDistance: {
                    value: distance
                }
            },
            transparent: true,
            vertexShader: `
                varying vec3 worldPosition;
                uniform float uDistance;

                void main() {
                    vec3 pos = position.${axes} * uDistance;
                    pos.${planeAxes} += cameraPosition.${planeAxes};
                    worldPosition = pos;
                    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
                }`,
            fragmentShader: `
                varying vec3 worldPosition;
                uniform float uSize1;
                uniform float uSize2;
                uniform vec3 uColor;
                uniform float uDistance;
        
                float getGrid(float size) {
                    vec2 r = worldPosition.${planeAxes} / size;
                    vec2 grid = abs(fract(r - 0.5) - 0.5) / fwidth(r);
                    float line = min(grid.x, grid.y);
                    return 1.0 - min(line, 1.0);
                }

                void main() {
                    float d = 1.0 - min(distance(cameraPosition.${planeAxes}, worldPosition.${planeAxes}) / uDistance, 1.0);
                    float g1 = getGrid(uSize1);
                    float g2 = getGrid(uSize2);
                    gl_FragColor = vec4(uColor.rgb, mix(g2, g1, g1) * pow(d, 3.0));
                    gl_FragColor.a = mix(0.5 * gl_FragColor.a, gl_FragColor.a, g2);

                    if ( gl_FragColor.a <= 0.0 ) discard;
                }`,
            extensions: {
                derivatives: true
            }
        } );
        super(geometry, material);
        this.frustumCulled = false;
    }
}

//init();
//animate();

class Viewer {
  constructor(domElement) {
    this.domElement = domElement;
    THREE.Object3D.DEFAULT_UP = new THREE.Vector3(0, 0, 1);

    //Materials
    //defaultMaterial = new THREE.MeshPhongMaterial({ color:0xaaaaaa, side:THREE.DoubleSide});
    defaultMaterial = new THREE.MeshLambertMaterial({side:THREE.DoubleSide, polygonOffset: true,
        polygonOffsetFactor: 1, // positive value pushes polygon further away
        polygonOffsetUnits: 1});
    defaultLineMaterial = new THREE.LineBasicMaterial({color:0x000000, depthWrite:true}) //For lines
    wireframeMaterial = new THREE.MeshBasicMaterial({color:0xaaaaaa, opacity:0.5, wireframe:true, transparent:true});
    wireframeActive = false;
    selectedMaterial = new THREE.MeshBasicMaterial({color:0xfff200, opacity:0.3, transparent:true});
    spriteMaterial = new THREE.SpriteMaterial({
        map: new THREE.CanvasTexture(document.querySelector("#number")),
        alphaTest: 0.5,
        transparent: true,
        depthTest: false,
        depthWrite: false
    });

    scene = new THREE.Scene();
    //scene.background = new THREE.Color( 0xffffff );
    scene.background = null;//new THREE.Color( 0xaaaaaa );
    this.scene = scene;

    camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 2000);
    camera.position.set(5, 5, 5);
    this.camera = camera;

    renderer = new THREE.WebGLRenderer({antialias:true, preserveDrawingBuffer: true});
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(window.innerWidth, window.innerHeight);
    //renderer.setClearColor(0x333333, 1);'
    this.renderer = renderer;

    document.body.appendChild(renderer.domElement);
    outlineEffect = new OutlineEffect(renderer, {
        defaultThickness: 0.001,
        defaultColor: [0, 0, 0],
        defaultAlpha: 0.5,
        defaultKeepAlive: true 
    });

    controls = new OrbitControls(camera, renderer.domElement);
    this.controls = controls;
    
    const light = new THREE.HemisphereLight( 0xffffff, 0x888888, 3 )
    light.position.set( 0, 0, 10 );

    //const ambientLight = new THREE.AmbientLight( 0x7c7c7c, 3.0 );
    //scene.add(ambientLight);

    //light = new THREE.DirectionalLight( 0xFFFFFF, 3.0 );
    //light.position.set( 0.32, 0.39, 0.7 );
    scene.add(light);
    //scene.add(new THREE.AxesHelper(5));
    //scene.add(new InfiniteGridHelper(false, false, false, false, 'xyz'));
    const sky = new Sky();
	sky.scale.setScalar( 450000 );
	scene.add( sky );
    var effectController = {
		turbidity: 10,
		rayleigh: 2,
		mieCoefficient: 0.005,
		mieDirectionalG: 0.8,
		inclination: 0.49, // elevation / inclination
		azimuth: 0.25, // Facing front,
		sun: ! true
	};
	var uniforms = sky.material.uniforms;
    uniforms["up"].value = THREE.Object3D.DEFAULT_UP;
	uniforms[ "turbidity" ].value = effectController.turbidity;
	uniforms[ "rayleigh" ].value = effectController.rayleigh;
	uniforms[ "mieCoefficient" ].value = effectController.mieCoefficient;
	uniforms[ "mieDirectionalG" ].value = effectController.mieDirectionalG;
    uniforms[ "sunPosition" ].value.set(400000, 400000, 400000);
    scene.add(sky);
    // Raycaster setup
    const raycaster = new THREE.Raycaster();
    const mouse = new THREE.Vector2();

    function onMouseClick(event) {
        mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
        mouse.y = - (event.clientY / window.innerHeight) * 2 + 1;
        raycaster.setFromCamera(mouse, camera);
        // We can't use the meshes array because as we delete stuff, the array slots become undefined
        const intersects = raycaster.intersectObjects(scene.children);
        if (intersects.length > 0) {
            //console.log(intersects)
            const obj = intersects[0].object;
            if (! event.shiftKey) {
                deselectAll();
            }
            if (obj != grid) {
                select(obj);
            }
        } else {
            deselectAll();
            console.log("nope")
        }
    }

    function onWindowResize() {
        camera.aspect = window.innerWidth / window.innerHeight;
        camera.updateProjectionMatrix();
        //renderer.setSize(window.innerWidth, window.innerHeight);
        outlineEffect.setSize( window.innerWidth, window.innerHeight );
    }
    
    function animate() {
        requestAnimationFrame(animate);
        controls.update();
        if (update) {
            render();
        }
    }

    window.addEventListener('click', onMouseClick, false);
    window.addEventListener('resize', onWindowResize, false);
    updateFunction = animate;
    animate();
  }

  connect(url) {
    if (url === undefined) {
        url = `ws://${location.host}`;
    }
    if (location.protocol == "https:") {
        url = url.replace("ws:", "wss:");
    }
    this.connection = new WebSocket(url);
    this.connection.binaryType = "arraybuffer";
    this.connection.onmessage = (msg) => this.handleMessage(msg);
    this.connection.onclose = function(evt) {
        console.log("onclose:", evt);
    }
  }

  handleMessage(msg) {
    if (msg.data instanceof ArrayBuffer) {
        // Binary frame
        const io = new IODataView(new DataView(msg.data));
        // Requested operation
        const funcIdx = io.readInt32();
        const func = getOperation(funcIdx);
        const args = io.readType(func.argType);
        io.checkExhausted();
        //console.log("Args", args);
        const res = func(...args);
        //console.log("Result", res);
        const buf = new ArrayBuffer(func.retType.size);
        const out = new IODataView(new DataView(buf));
        out.writeType(func.retType, res);
        this.connection.send(buf)
      } else {
        // text frame
        console.log("Text", msg.data);
      }
    }
}

function render() {
//    renderer.render(scene, camera);
    outlineEffect.render(scene, camera);
    updateScreenPosition();
}

function updateScreenPosition() {
    sprites.forEach(sprite => {
    const annotation = sprite.userData.KhepriDOM;
    //Object position
    //const position = new THREE.Vector3(25,25,25);
    //    const meshDistance = camera.position.distanceTo(position);
    //    const spriteDistance = camera.position.distanceTo(sprite.position);
        const spriteBehindObject = false; //spriteDistance > meshDistance;
        //sprite.material.opacity = spriteBehindObject ? 0.25 : 1; 
        //sprite.material.opacity = 0;
        const vector = new THREE.Vector3(25, 25, 25);
        vector.copy(sprite.position);
        const canvas = renderer.domElement;
        vector.project(camera);
        vector.x = Math.round((0.5 + vector.x/2)*(canvas.width/window.devicePixelRatio));
        vector.y = Math.round((0.5 - vector.y/2)*(canvas.height/window.devicePixelRatio));
        annotation.style.top = `${vector.y}px`;
        annotation.style.left = `${vector.x}px`;
        annotation.style.opacity = spriteBehindObject ? 0.25 : 1;
        //console.log(annotation.style);
    });
}

export { Viewer };