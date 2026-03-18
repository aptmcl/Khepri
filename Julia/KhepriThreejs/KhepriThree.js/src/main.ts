import * as THREE from "three";
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GUI, Controller } from 'three/addons/libs/lil-gui.module.min.js';
//import { Sky } from 'three/addons/objects/Sky.js';
//import { OutlineEffect } from 'three/addons/effects/OutlineEffect.js';
import { MTLLoader } from 'three/addons/loaders/MTLLoader.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { HDRLoader } from 'three/addons/loaders/HDRLoader.js';
import { GLTFLoader, GLTF } from 'three/addons/loaders/GLTFLoader.js';
import { fileOpen, FileWithHandle } from "browser-fs-access";

//import { appIcons, CONTENT_GRID_ID } from "./globals";

function error(...args: any[]): never {
  console.error(...args);
  throw new Error(args.map(a => a.toString()).join(" "));
}

// RPC
const enum TypeCode { Bool, UInt8, Int32, Int64, Float32, Float64, String, RGB, RGBA, Dict, ArrInt32 }
const enum TypeSize { Int64=8, Int32=4, Int16=2, Int8=1, UInt64=8, UInt32=4, UInt16=2, UInt8=1, Float64=8, Float32=4, Float16=2 }

/*
For dynamic function definition, we need to be able to get types by name
*/
const typeNameMap: { [x: string]: Type<any>; } = {};

/*
function getTypeFromName(name: string): Type<any> {
  const t = typeNameMap[name];
  return t ? t : error("Unknown type name: " + name);
}
*/

class Type<T> {
  public constructor(
    public name: string,
    public size: (v: T) => number,
    public read: (io: IODataView) => T,
    public write: (io: IODataView, v: T) => void
  ) {
    typeNameMap[name] = this;
  }
}

// Types
class PrimitiveType<T> extends Type<T> {
  public constructor(
    name: string,
    size: (v: T) => number,
    read: (io: IODataView) => T = (_io: IODataView) => { error("No reader defined for " + name); },
    write: (io: IODataView, v: T) => void = (_io: IODataView, _v: T) => { error("No writer defined for " + name); }
  ) {
    super(name, size, read, write);
  }
}

type TypeOrTypeArray = Type<any> | TypeOrTypeArray[];


function ofSize<T>(value: number): (v: T) => number { return (_v: T) => value; }
function computeStringSize(str: string) {
  // UTF-8 is based on 8-bit code units. Each character is encoded as 1 to 4 bytes. The first 128 Unicode code points are encoded as 1 byte in UTF-8.
  // Thus the only way to know the size of a string is to encode it.
  const encoder = new TextEncoder();
  const bytes = encoder.encode(str);
  let size = bytes.length;
  // compute variable-length integer
  let len = size;
  while (true) {
    let byte = len & 0x7f;
    len >>>= 7;
    if (len !== 0) { byte |= 0x80; }
    size++;
    if (len === 0) { break; }
  }
  return size;
}
function computeDictSize(_dict: { [key: string]: any; }) {
  let size = 0;
  for (const key in _dict) {
    size += computeStringSize(key);
    size += computeAnySize(_dict[key]);
  }
  return size;
}
function computeAnySize(v: any) {
  return TypeSize.UInt8 + // Type code
          ((v === null || v === undefined) ? 0 :
          (typeof v === "boolean") ? TypeSize.UInt8 :
          (typeof v === "number") ? (Number.isInteger(v) ? TypeSize.Int64 : TypeSize.Float64) :
          (typeof v === "string") ? computeStringSize(v) :
          Array.isArray(v) ? v.reduce((a, b) => a + computeAnySize(b), 0) :
          typeof v === "object" ? computeDictSize(v) :
          error("Unknown type"));
}

const None = new PrimitiveType("None", ofSize(TypeSize.UInt8), (_io) => { error("Can't read none"); }, (io, _v) => io.writeUInt8(0));
const Bool = new PrimitiveType("Bool", ofSize(TypeSize.UInt8), (io) => io.readUInt8() != 0, (io, v) => io.writeUInt8(v ? 1 : 0));
//const Int64 = new PrimitiveType("Int64", ofSize(TypeSize.Int64), (io) => io.readInt64(), (io, v) => io.writeInt64(v));
const Int32 = new PrimitiveType("Int32", ofSize(TypeSize.Int32), (io) => io.readInt32(), (io, v) => io.writeInt32(v));
//const Float64 = new PrimitiveType("Float64", ofSize(TypeSize.Float64), (io) => io.readFloat64(), (io, v) => io.writeFloat64(v));
const Float32 = new PrimitiveType("Float32", ofSize(TypeSize.Float32), (io) => io.readFloat32(), (io, v) => io.writeFloat32(v));
const Matrix4x4 = new PrimitiveType("Matrix4x4", ofSize(16 * TypeSize.Float32),
  (io) => new THREE.Matrix4(  //...(io.readArrayFloat32(16) cannot be converted to a tuple of 16 floats
    io.readFloat32(), io.readFloat32(), io.readFloat32(), io.readFloat32(),
    io.readFloat32(), io.readFloat32(), io.readFloat32(), io.readFloat32(),
    io.readFloat32(), io.readFloat32(), io.readFloat32(), io.readFloat32(),
    io.readFloat32(), io.readFloat32(), io.readFloat32(), io.readFloat32()),
  (io, v) => io.writeArrayFloat32(16, new Float32Array(v.elements)));
// Threejs aligns objects along the Y axis but we prefer the Z axis. The conversion is done on the frontend.
const Matrix4x4Y = Matrix4x4;
const ArrayFloat32 = new PrimitiveType<Float32Array>("ArrayFloat32",
                                                     v => TypeSize.Int32 + v.length * TypeSize.Float32,
                                                     (io) => io.readArrayFloat32(io.readInt32()),
                                                     (io, v) => io.writeArrayFloat32(v.length, v));
const ArrayInt32 = new PrimitiveType<Int32Array>("ArrayInt32",
                                                 v => TypeSize.Int32 + v.length * TypeSize.Int32,
                                                 (io) => io.readArrayInt32(io.readInt32()),
                                                 (io, v) => io.writeArrayInt32(v.length, v));
//const ArrayUInt32 = new PrimitiveType("ArrayUInt32", Infinity, (io) => io.readArrayUInt32(io.readInt32()), (io, v) => io.writeArrayUInt32(v.length, v));
const Str = new PrimitiveType("Str", computeStringSize, (io) => io.readString(), (io, v) => io.writeString(v));
const Dict = new PrimitiveType("Dict", computeDictSize, (io) => io.readDict(), (io, v) => io.writeDict(v));
//const Any = new PrimitiveType("Any", computeAnySize, (io) => io.readAny(), (io, v) => io.writeAny(v));


function valueSize<T>(type: TypeOrTypeArray, v: T | T[]): number {
  if (Array.isArray(type)) {
    const val = v as T[];
    if (type.length === 1) { // [Type] means array of Type
      const subtype = type[0];
      const header = TypeSize.Int32; // length prefix
      return header + val.reduce((size:number, sv:T) => size + valueSize(subtype, sv), 0);
    } else {                 // [Type, Type, ...] means tuple of Type, Type, ...
      return val.reduce((size:number, sv:T, i:number) => size + valueSize(type[i], sv), 0);
    }
  } else {                   // Type
    return type.size(v as T);
  }
}

class CompositeType extends Type<any[]> {
  public constructor(name: string, public subtypes: TypeOrTypeArray[], public combiner: (args: any[]) => any) {
    super(name,
      v => valueSize(subtypes, v),
      (io) => combiner(subtypes.map(st => io.readType(st))),
      (io, v) => subtypes.forEach((st, i) => io.writeType(st, v[i])));
  }
}
//const Float3 = new CompositeType("FLoat3", [Float32, Float32, Float32], args => args);

// Three types
const Vector3d = new CompositeType("Vector3d", [Float32, Float32, Float32], args => new THREE.Vector3(...args));
const Point3d = new CompositeType("Point3d", [Float32, Float32, Float32], args => new THREE.Vector3(...args));
const Point2d = new CompositeType("Point2d", [Float32, Float32], args => new THREE.Vector2(...args));
const RGB = new CompositeType("FLoat3", [Float32, Float32, Float32], args => new THREE.Color(...args));

/*
function typeSize(t: TypeOrTypeArray): number {
  if (Array.isArray(t)) {
    return t.reduce((a, b) => a + typeSize(b), 0);
  }
  return t.size;
}*/
class IODataView {
    constructor(protected dataView: DataView, protected offset = 0) {
  }
  checkExhausted() {
    if (this.offset != this.dataView.byteLength) {
      console.error("IODataView is not exhausted! offset:", this.offset, " length:", this.dataView.byteLength);
    }
  }
  readType(type: TypeOrTypeArray): any {
    //console.log("Reading type", type);
    if (Array.isArray(type)) { // [Type]
      const subtype = type[0];
      return Array.from({ length: this.readInt32() }, (_v, _i) => this.readType(subtype));
    } else { // Type
      return type.read(this);
    }
  }
  writeType(type: TypeOrTypeArray, v: any | any[]) {
    if (Array.isArray(type)) { // [Type]
      const subtype = type[0];
      this.writeInt32(v.length);
      v.forEach((e: any) => this.writeType(subtype, e));
    } else { // Type
      type.write(this, v)
    }
  }
  readTypedObject(type: { [x: string]: any; }) {
    const obj: { [key: string]: any; } = {};
    for (const key in type) {
      const val = this.readType(type[key]);
      obj[key] = val;
    }
    return obj;
  }
  readDict() {
    const keys = this.readInt32();
    const obj: { [key: string]: any } = {};
    for (let i = 0; i < keys; i++) {
      const key = this.readString();
      const val = this.readAny();
      obj[key] = val;
    }
    return obj;
  }
  writeDict(dict: { [key: string]: any; }) {
    this.writeInt32(Object.keys(dict).length);
    for (const key in dict) {
      this.writeString(key);
      this.writeAny(dict[key]);
    }
  }
  readAny() {
    const code = this.readUInt8() as TypeCode;
    switch (code) {
      case TypeCode.Bool:
        return Bool.read(this);
      case TypeCode.UInt8:
        return this.readUInt8();
      case TypeCode.Int32:
        return this.readInt32();
      case TypeCode.Int64:
        return this.readInt64();
      case TypeCode.Float32:
        return this.readFloat32();
      case TypeCode.Float64:
        return this.readFloat64();
      case TypeCode.String:
        return this.readString();
      case TypeCode.RGB:
      case TypeCode.RGBA:
        return RGB.read(this);
      case TypeCode.Dict:
        return this.readDict();
      case TypeCode.ArrInt32:
        return this.readArrayInt32(this.readInt32())
      default:
        console.error("Unknown object code", code)
    }
  }
  writeAny(v: any) {
    const t = typeof v;
    switch (t) {
    case "boolean":
      this.writeUInt8(TypeCode.Bool);
      Bool.write(this, v);
      break;
    case "number":
      if (Number.isInteger(v)) {
        this.writeUInt8(TypeCode.Int64);
        this.writeInt64(v);
      } else { // Must be float
        this.writeUInt8(TypeCode.Float64);
        this.writeFloat64(v);
      }
      break;
    case "string":
      this.writeUInt8(TypeCode.String);
      this.writeString(v);
      break;
    default:
      console.error("Unknown object type", t)
    }
  }
  readInt64() {
    const size = TypeSize.Int64;
    this.offset += size;
    //Convert BigInt to Number because BigInts cannot be used in many cases
    return Number(this.dataView.getBigInt64(this.offset - size, true));
  }
  writeInt64(v: any) {
    const size = TypeSize.Int64;
    this.offset += size;
    //Convert Number to BigInt because BigInts cannot be used in many cases
    return this.dataView.setBigInt64(this.offset - size, BigInt(v), true);
  }
  readInt32() {
    const size = TypeSize.Int32;
    this.offset += size;
    return this.dataView.getInt32(this.offset - size, true);
  }
  writeInt32(v: any) {
    const size = TypeSize.Int32;
    this.offset += size;
    return this.dataView.setInt32(this.offset - size, v, true);
  }
  readInt16() {
    const size = TypeSize.Int16;
    this.offset += size;
    return this.dataView.getInt16(this.offset - size, true);
  }
  readInt8() {
    const size = TypeSize.Int8;
    this.offset += size;
    return this.dataView.getUint8(this.offset - size);
  }
  readUInt64() {
    const size = TypeSize.UInt64;
    this.offset += size;
    //Convert BigInt to Number because BigInts cannot be used in many cases
    return Number(this.dataView.getBigUint64(this.offset - size, true));
  }
  readUInt32() {
    const size = TypeSize.UInt32;
    this.offset += size;
    return this.dataView.getUint32(this.offset - size, true);
  }
  readUInt16() {
    const size = TypeSize.UInt16;
    this.offset += size;
    return this.dataView.getUint16(this.offset - size, true);
  }
  readUInt8() {
    const size = TypeSize.UInt8;
    this.offset += size;
    return this.dataView.getUint8(this.offset - size);
  }
  writeUInt8(v: number) {
    const size = TypeSize.UInt8;
    this.offset += size;
    return this.dataView.setUint8(this.offset - size, v);
  }
  writeUInt32(v: number) {
    const size = TypeSize.UInt32;
    this.offset += size;
    return this.dataView.setUint32(this.offset - size, v, true);
  }
  readFloat64() {
    const size = TypeSize.Float64;
    this.offset += size;
    return this.dataView.getFloat64(this.offset - size, true);
  }
  writeFloat64(v: any) {
    const size = TypeSize.Float64;
    this.offset += size;
    return this.dataView.setFloat64(this.offset - size, v, true);
  }
  readFloat32() {
    const size = TypeSize.Float32;
    this.offset += size;
    return this.dataView.getFloat32(this.offset - size, true);
  }
  writeFloat32(v: any) {
    const size = TypeSize.Float32;
    this.offset += size;
    return this.dataView.setFloat32(this.offset - size, v, true);
  }/*
  readFloat16() {
      const size = TypeSize.Float16;
      this.offset += size;
      return this.dataView.getFloat16(this.offset - size, true);
  }*/
  readArrayUInt8(n: number) {
    const arr = new Uint8Array(n);
    for (let i = 0; i < n; i++) {
      arr[i] = this.readUInt8();
    }
    return arr;
  }
  readArrayUInt32(n: number) {
    const arr = new Uint32Array(n);
    for (let i = 0; i < n; i++) {
      arr[i] = this.readUInt32();
    }
    return arr;
  }
  writeArrayUInt32(n: number, v: Uint32Array) {
    this.writeInt32(n);
    for (let i = 0; i < n; i++) {
      this.writeInt32(v[i]);
    }
  }

  readArrayInt32(n: number) {
    const arr = new Int32Array(n);
    for (let i = 0; i < n; i++) {
      arr[i] = this.readInt32();
    }
    return arr;
  }
  writeArrayInt32(n: number, v: Int32Array) {
    this.writeInt32(n);
    for (let i = 0; i < n; i++) {
      this.writeInt32(v[i]);
    }
  }
  readArrayFloat32(n: number) {
    const arr = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      arr[i] = this.readFloat32();
    }
    return arr;
  }
  writeArrayFloat32(n: number, v: Float32Array) {
    this.writeInt32(n);
    for (let i = 0; i < n; i++) {
      this.writeFloat32(v[i]);
    }
  }
  readArrayAny(n: number) {
    const arr = new Array(n);
    for (let i = 0; i < n; i++) {
      arr[i] = this.readAny();
    }
    return arr;
  }
  writeArrayAny(n: number, v: any[]) {
    this.writeInt32(n);
    for (let i = 0; i < n; i++) {
      this.writeAny(v[i]);
    }
  }
  readString() {
    let size = 0;
    let shift = 0;
    const decoder = new TextDecoder();
    while (true) {
      let b = this.readUInt8();
      size = size | ((b & 0x7f) << shift);
      if ((b & 0x80) == 0) {
        this.offset += size;
        return decoder.decode(new DataView(this.dataView.buffer, this.offset - size, size));
      } else {
        shift += 7;
      }
    }
  }
  writeString(str: string) {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(str);
    const size = bytes.length;
    // Encode the length as a variable-length integer
    let len = size;
    while (true) {
      let byte = len & 0x7f;
      len >>>= 7;
      if (len !== 0) { byte |= 0x80; }
      this.writeUInt8(byte)
      if (len === 0) { break; }
    }
    for (let i = 0; i < bytes.length; i++) {
      this.writeUInt8(bytes[i]);
    }
  }
}

/*
Utilities
*/

function withTransform(m: THREE.Matrix4, obj: { position: any; quaternion: any; scale: any; }) {
  m.decompose(obj.position, obj.quaternion, obj.scale);
  return obj;
}

// Communication with the server

let connection: WebSocket;
/*
// Send a synchronous HTTP request
function sendHTTPRequest(request: string, ...args: any[]) {
  const params = args.map((arg, i) => `p${i}=${encodeURIComponent(arg)}`).join("&");
  fetch(request + (params ? "?" + params : ""))
    .then(response => response.json())
    .then(data => console.log(data))
    .catch(err => console.error(err));
}
*/
// Send an asynchronous WebSocket request
let requestStillWaitingResponse = false;

function sendWebSocketRequest(connection: WebSocket, request: number, ...args: any[]) {
  if (requestStillWaitingResponse) {
    console.error("Previous request is still waiting for a response");
    return false;
  } else {
    requestStillWaitingResponse = true;
    let size = TypeSize.Int32; //computeStringSize(request);
    size += TypeSize.Int32; // Number of args
    args.forEach(arg => { size += computeAnySize(arg); });
    const buf = new ArrayBuffer(size);
    const out = new IODataView(new DataView(buf));
    //out.writeString(request);
    out.writeInt32(request);
    out.writeArrayAny(args.length, args);
    connection.send(buf);
    return true;
  }
}

function sendRequest(request: number, ...args: any[]) {
//  if (false) {
//    sendHTTPRequest(request, ...args);
//    return true;
//  } else {
    return sendWebSocketRequest(connection, request, ...args);
//  }
}

function sendValue<T>(type:Type<T>, value: T) {
  const buf = new ArrayBuffer(type.size(value));
  const out = new IODataView(new DataView(buf));
  out.writeType(type, value);
  connection.send(buf);
}

/*
There are two kinds of arriving messages: 
 - one for RPC from the server, 
 - another for responses to requests from the client.
The distinction is going to be made by the first integer in the message:
  - If the integer is positive, it's an RPC call.
  - If the integer is negative, it's a response to a request.

Statistically speaking, the maximum request size is 332 bytes
This could be a hint to user a growable ArrayBuffer.
*/
function handleMessage(msg: MessageEvent) {
  if (msg.data instanceof ArrayBuffer) {
    // Binary frame
    const io = new IODataView(new DataView(msg.data));
    // Requested operation
    const funcIdx = io.readInt32();
    if (funcIdx < 0) { // Normal response to a client's request
      requestStillWaitingResponse = false;
      if (funcIdx == -2) { // Error response to a client's request
        console.error("There was an error with the request!");
      }
    } else { // RPC call from the server
      const func = getOperation(funcIdx);
      func(io)
    }
  } else {
    // text frame
    console.log("Text", msg.data);
  }
}

//Operations
const operations: Function[] = [];

const operationsMap: { [x: string]: number; } = {};

function registerOperation(name: string, op: Function) {
  if (operationsMap[name] !== undefined) {
    error(`Function named '${name}' is already registered.`);
  } else {
    operationsMap[name] = operations.push(op) - 1; // operations[name] provides the function index
    return op;
  }
}
function getOperation(idx: number) {
  return operations[idx];
}

function typedFunction<T>(name: string, argTypes: TypeOrTypeArray[], retType: Type<T>, func: Function): Function {
  const tf = (io: IODataView) => {
    const args = argTypes.map(t => io.readType(t));
    //console.log("Calling", name, "with args", args);
    io.checkExhausted();
    sendValue(retType, func(...args)); // pass connection for callbacks
  }
  return registerOperation(name, tf);
}

function typedAsyncFunction<T>(name: string, argTypes: TypeOrTypeArray[], retType: Type<T>, func: Function): Function {
  const tf = (io: IODataView) => {
    const args = argTypes.map(t => io.readType(t));
    io.checkExhausted();
    const continuation = (res: any) => sendValue(retType, res);
    func(...args, continuation);
  }
  return registerOperation(name, tf);
}

// The first two fundamental operations allow retrieval of functions by name and definitions of callbacks

typedFunction("getOperationNamed", [Str, Str], Int32, (name: string, canonical: string) => {
  let idx = operationsMap[name];
  if (idx !== undefined) {
    return idx;
  } else {
    console.error(`Requested non-existent function named '${name}' with signature ${canonical}.`);
    return -1;
  }
});

/*
typedFunction("addCallbackFunction", [Str, Str, [Str], Str], Int32,
  (name: string, request: string, argTypeNames: string[], retTypeName: string) => {
    const argTypes = argTypeNames.map(getTypeFromName);
    const retType = getTypeFromName(retTypeName);
    typedFunction(name, argTypes, retType, (...args: any[]) => {
      sendValue(Str, request);
      argTypes.forEach((type, i) => {
        sendValue(type, args[i]);
      });
    });
    return operationsMap[name];
  });

function callCallback(name: string, ...args: any[]) {
  const idx = operationsMap[name];
  */

////////////////////////////////////////////////////////////////////////////
/*
We need to store objects (e.g., materials, shapes, etc) internally.
*/

//THREE.Object3D.DEFAULT_UP.set(0, 0, 1);

const renderer = new THREE.WebGLRenderer({ antialias: true }); //{ alpha: true, antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);

const camera = new THREE.PerspectiveCamera(75, window.innerWidth/window.innerHeight, 0.1, 2000);
camera.position.set(5, 5, 5);

const controls = new OrbitControls(camera, renderer.domElement);//, outlineEffect: OutlineEffect;

const scene = new THREE.Scene();
//scene.background = new THREE.Color( 0xffffff );
//scene.background = null;//new THREE.Color( 0xaaaaaa );


let defaultMaterial: THREE.Material;
//let defaultLineMaterial: THREE.Material;
//let wireframeMaterial: THREE.Material;
let selectedMaterial: THREE.Material;
//let wireframeActive: boolean;

let update = true;

//renderer.setClearColor(0x333333, 1);'

/* Should we switch to the WebGPURenderer??
renderer = new THREE.WebGPURenderer( { antialias: true } );
renderer.setPixelRatio( window.devicePixelRatio );
renderer.setSize( window.innerWidth, window.innerHeight );
renderer.setAnimationLoop( animate );
*/
//renderer.shadowMap.enabled = true;
//renderer.shadowMap.type = THREE.PCFSoftShadowMap;

////////////////////////////////

const namedLayers: Map<string, THREE.Group> = new Map();

function createLayer(name: string) {
  const layer = new THREE.Group();
  // Layers ensure Z-up
  layer.rotation.x = -Math.PI*.5;
  scene.add(layer);
  namedLayers.set(name, layer);
  return layer;
}

const defaultLayer: THREE.Group = createLayer("Default")

const layers: THREE.Group[] = [];

function addLayer(obj: THREE.Group) {
  return layers.push(obj) - 1;
}
function getLayer(idx: number) {
  return idx == -1 ? defaultLayer : layers[idx];
}
const LayerId = new PrimitiveType("LayerId", ofSize(4), (io) => getLayer(io.readInt32()), (io, v) => io.writeInt32(addLayer(v)));

typedFunction("createLayer", [Str], LayerId, (name: string) => {
  return createLayer(name);
});

let currentLayer: THREE.Group = defaultLayer

typedFunction("setCurrentLayer", [LayerId], None, (layer: THREE.Group) => {
  currentLayer = layer;
});

typedFunction("getCurrentLayer", [], Int32, () => {
  return layers.indexOf(currentLayer);
});

//////////////////////////////////////////
const objects: Map<number, THREE.Object3D> = new Map();
let nextObject3DId = 0;

function addObject3D(obj: THREE.Object3D) {
  obj.castShadow = true;
  obj.receiveShadow = true;
  if (obj instanceof THREE.Mesh) {
    obj.geometry.computeVertexNormals();
  }
  //wireframeCheck(obj);
  currentLayer.add(obj);
  const object3DId = nextObject3DId++;
  objects.set(object3DId, obj);
  // Store the ID on the object for reverse lookup
  obj.userData.Object3DId = object3DId;
  return object3DId;
}

function getObject3D(idx: number) {
  const obj = objects.get(idx);
  return obj ? obj : error(`Requested non-existent Object3D with id '${idx}'.`);
}

function delObject3D(idx: number) {
  const obj = objects.get(idx);
  if (obj) {
    obj.removeFromParent();
    if (obj instanceof THREE.Mesh) {
      obj.geometry.dispose();
    }
    objects.delete(idx);
    delete obj.userData.Object3DId;
    return idx;
  } else {
    error(`Requested non-existent Object3D with id '${idx}'.`);
  }
}

function delAllObject3Ds() {
  const count = objects.size;
  objects.forEach((obj, _id) => {
    obj.removeFromParent();
    if (obj instanceof THREE.Mesh) {
      obj.geometry.dispose();
    }
    delete obj.userData.Object3DId;
  });
  objects.clear();
  nextObject3DId = 0; // Reset the ID counter
  return count;
}

// We use the trick of knowing that Ids are Int32 so we just get the index
typedFunction("delete", [Int32], None, (i: number) => delObject3D(i));

typedFunction("deleteAll", [], None, () => {
  delAllObject3Ds();
  delAllSprites();
});

const Id = new PrimitiveType("Id", ofSize(4), (io) => getObject3D(io.readInt32()), (io, v) => io.writeInt32(addObject3D(v)));

////////////////////////////////
const materials: THREE.Material[] = [];
function addMaterial(obj: THREE.Material) {
  return materials.push(obj) - 1;
}
function getMaterial(idx: number) {
  return idx == -1 ? defaultMaterial : materials[idx];
}

/*
function delMaterial(idx: number) {
  delete materials[idx];
}
function delAllMaterials() {
  materials.length = 0;
}
*/

const MatId = new PrimitiveType("MatId", ofSize(4), (io) => getMaterial(io.readInt32()), (io, v) => io.writeInt32(addMaterial(v)));

////////////////////////////////

//let spriteMaterial: THREE.SpriteMaterial;
const sprites: Annotation[] = [];

// Sprites for annotations
class Annotation extends THREE.Sprite {
  constructor(_title: string, content: string, material: THREE.SpriteMaterial) {
    const div = document.createElement("div");
    div.classList.add(`annotation`);
    const p = document.createElement("p");
    div.appendChild(p);
    /*    var strong = document.createElement("strong");
        p.appendChild(strong);
        strong.innerText = "◤ " + title;
        p = document.createElement("p");*/
    p.innerText = content;
    document.body.appendChild(div);
    super(material);
    this.userData.KhepriDOM = div;
    sprites.push(this);
  }
  removeFromParent() {
    sprites.splice(sprites.findIndex(e => e === this), 1);
    document.body.removeChild(this.userData.KhepriDOM);
    super.removeFromParent();
    return this;
  }
}
/*
function newAnnotation(pos: THREE.Vector3, title: string, content: string) {
  const ann = new Annotation(title, content, spriteMaterial);
  ann.position.copy(pos);
  ann.scale.set(2, 2, 1);
  return ann;
}
*/

// function addSprite(pos: THREE.Vector3, _title: string, content: string) {
//   const div = document.createElement("div");
//   div.classList.add(`annotation`);
//   const p = document.createElement("p");
//   div.appendChild(p);
//   /*    var strong = document.createElement("strong");
//       p.appendChild(strong);
//       strong.innerText = "◤ " + title;
//       p = document.createElement("p");*/
//   p.innerText = content;
//   div.appendChild(p);
//   //if (!spriteMaterial) {
//     const texture = new THREE.CanvasTexture(div.querySelector("#number") as HTMLCanvasElement);
//     texture.needsUpdate = true;
//     spriteMaterial = new THREE.SpriteMaterial({
//       map: texture,
//       alphaTest: 0.5,
//       transparent: true,
//       depthTest: false,
//       depthWrite: false
//     })
//   //}
//   const sprite = new THREE.Sprite(spriteMaterial);
//   // We need to swap Y and Z for Three.js
//   sprite.position.copy(pos);
//   //sprite.scale.set(2, 2, 1);
//   sprite.userData.KhepriDOM = div;
//   currentLayer.add(sprite);
//   document.body.appendChild(div);
//   return sprites.push(sprite) - 1;
// }


//function addSprite1(pos: THREE.Vector3, _title: string, content: string) {
//  // 1. Canvas setup (Same as before to prevent warnings)
//  const canvas = document.createElement('canvas');
//  canvas.width = 512; 
//  canvas.height = 256;
//  
//  //const context = canvas.getContext('2d');
//  //if (context) {
//  //  context.clearRect(0, 0, canvas.width, canvas.height);
//  //  context.font = "Bold 40px Arial";
//  //  context.fillStyle = "rgba(255, 255, 255, 1)";
//  //  context.textAlign = "center";
//  //  context.textBaseline = "middle";
//  //  context.fillText(content, canvas.width / 2, canvas.height / 2);
//  //}
//
//  const ctx = canvas.getContext('2d');
//  if (!ctx) return;
//
//  // Standard clear
//  ctx.clearRect(0, 0, canvas.width, canvas.height);
//  const fontSize = 60;
//  const fontFace = "Arial Bold";
//  ctx.font = `${fontSize}px ${fontFace}`;
//  
//  // Measure text width to size the background box dynamically
//  const textMetrics = ctx.measureText(content);
//  const textWidth = textMetrics.width;
//
//  // Style configurations
//  const paddingX = 40;
//  const paddingY = 20;
//  const cornerRadius = 30;
//  const bgColor = "rgba(0, 0, 0, 0.85)"; // Slightly transparent black
//  const textColor = "rgba(255, 255, 255, 1)"; // White
//
//  // Calculate dimensions of the background box
//  const boxWidth = textWidth + (paddingX * 2);
//  const boxHeight = fontSize + (paddingY * 2);
//
//  // Calculate starting X/Y to center the box precisely on the canvas
//  const startX = (canvas.width - boxWidth) / 2;
//  // Adjusting Y slightly for better visual centering relative to text baseline
//  const startY = (canvas.height - boxHeight) / 2; 
//
//  // --- 3. DRAW ROUNDED RECTANGLE BACKGROUND ---
//  ctx.fillStyle = bgColor;
//  ctx.beginPath();
//  // Start at top-left corner after the curve
//  ctx.moveTo(startX + cornerRadius, startY);
//  // Top line
//  ctx.lineTo(startX + boxWidth - cornerRadius, startY);
//  // Top-right curve
//  ctx.quadraticCurveTo(startX + boxWidth, startY, startX + boxWidth, startY + cornerRadius);
//  // Right line
//  ctx.lineTo(startX + boxWidth, startY + boxHeight - cornerRadius);
//  // Bottom-right curve
//  ctx.quadraticCurveTo(startX + boxWidth, startY + boxHeight, startX + boxWidth - cornerRadius, startY + boxHeight);
//  // Bottom line
//  ctx.lineTo(startX + cornerRadius, startY + boxHeight);
//  // Bottom-left curve
//  ctx.quadraticCurveTo(startX, startY + boxHeight, startX, startY + boxHeight - cornerRadius);
//  // Left line
//  ctx.lineTo(startX, startY + cornerRadius);
//  // Top-left curve
//  ctx.quadraticCurveTo(startX, startY, startX + cornerRadius, startY);
//  ctx.closePath();
//  ctx.fill();
//
//  // --- 4. DRAW TEXT ON TOP ---
//  ctx.fillStyle = textColor;
//  ctx.textAlign = "center";
//  // "middle" baseline makes centering easier
//  ctx.textBaseline = "middle"; 
//  // Draw at absolute center of canvas
//  ctx.fillText(content, canvas.width / 2, canvas.height / 2);
//
//  const texture = new THREE.CanvasTexture(canvas);
//  texture.needsUpdate = true; 
//
//  // 2. Material with sizeAttenuation DISABLED
//  spriteMaterial = new THREE.SpriteMaterial({ 
//    map: texture,
//    transparent: true,
//    depthWrite: false,
//    depthTest: true,
//    sizeAttenuation: false, // <--- THE KEY CHANGE
//  // Z-FIGHTING FIX: Polygon offset
//    polygonOffset: true,
//    polygonOffsetFactor: -1.0, 
//    polygonOffsetUnits: -4.0
//  });
//
//  const sprite = new THREE.Sprite(spriteMaterial);
//  //pos.x += 0.1; // Slightly above the point
//  sprite.position.copy(pos);
//  sprite.center.set(0.5, 0.0);
//  
//  // 3. SCALING LOGIC CHANGES
//  // When sizeAttenuation is false, 1.0 = 100% of the screen height.
//  // Therefore, we must use very small numbers.
//  // 0.1 = The sprite will take up 10% of the screen height.
//  // We adjust X based on the aspect ratio of our canvas (2:1)
//  const scaleFactor = 0.1; // Adjust this to make text bigger/smaller
//  sprite.scale.set(scaleFactor * 2, scaleFactor, 1); 
//
//const dotCanvas = document.createElement('canvas');
//  dotCanvas.width = 64;
//  dotCanvas.height = 64;
//  const dotCtx = dotCanvas.getContext('2d');
//  
//  if (dotCtx) {
//    // Draw Circle
//    dotCtx.beginPath();
//    dotCtx.arc(32, 32, 24, 0, 2 * Math.PI);
//    dotCtx.fillStyle = "#000000"; 
//    dotCtx.fill();
//    
//    // Draw White Border
//    dotCtx.lineWidth = 4; // Thicker line for visibility when scaled down
//    dotCtx.strokeStyle = "#FFFFFF";
//    dotCtx.stroke();
//  }
//
//  const dotTexture = new THREE.CanvasTexture(dotCanvas);
//  const dotMaterial = new THREE.SpriteMaterial({ 
//    map: dotTexture,
//    sizeAttenuation: false, // Constant screen size
//    depthTest: false,       // <--- CRITICAL: Always visible through walls
//    depthWrite: false
//  });
//
//  const dotSprite = new THREE.Sprite(dotMaterial);
//  dotSprite.position.copy(pos);
//  dotSprite.scale.set(0.02, 0.02, 1); // Small fixed size (2% of screen height)
//  dotSprite.renderOrder = 999; // Ensure it draws ON TOP of the text label
//  
//  currentLayer.add(dotSprite);
//
//
//  // --- PART B: THE LABEL (Rounded Rect) ---
//  const labelCanvas = document.createElement('canvas');
//  labelCanvas.width = 1024; 
//  labelCanvas.height = 256; // Wide aspect ratio
//  
//  const ctx = labelCanvas.getContext('2d');
//  if (!ctx) return;
//
//  const fontSize = 60;
//  ctx.font = `Bold ${fontSize}px Arial`;
//  
//  const textMetrics = ctx.measureText(content);
//  const textWidth = textMetrics.width;
//  const padding = 20;
//  
//  // Box Dimensions
//  const boxWidth = textWidth + (padding * 2);
//  const boxHeight = fontSize + (padding * 2);
//  const radius = 30;
//
//  // Draw Position: Bottom-Left of the canvas
//  // We add a small 'margin' (20px) so the text box doesn't overlap the dot perfectly
//  const x = 2; 
//  const y = labelCanvas.height - boxHeight - 1; // 10px from bottom edge
//
//  // Draw Rounded Rectangle
//  ctx.fillStyle = "rgba(0, 0, 0, 0.85)";
//  ctx.beginPath();
//  ctx.moveTo(x + radius, y);
//  ctx.lineTo(x + boxWidth - radius, y);
//  ctx.quadraticCurveTo(x + boxWidth, y, x + boxWidth, y + radius);
//  ctx.lineTo(x + boxWidth, y + boxHeight - radius);
//  ctx.quadraticCurveTo(x + boxWidth, y + boxHeight, x + boxWidth - radius, y + boxHeight);
//  ctx.lineTo(x + radius, y + boxHeight);
//  ctx.quadraticCurveTo(x, y + boxHeight, x, y + boxHeight - radius);
//  ctx.lineTo(x, y + radius);
//  ctx.quadraticCurveTo(x, y, x + radius, y);
//  ctx.closePath();
//  ctx.fill();
//
//  // Draw Text
//  ctx.fillStyle = "white";
//  ctx.textAlign = "left";
//  ctx.textBaseline = "top";
//  // Align text inside the box
//  ctx.fillText(content, x + padding, y + padding);
//
//  const labelTexture = new THREE.CanvasTexture(labelCanvas);
//  labelTexture.minFilter = THREE.LinearFilter;
//  labelTexture.needsUpdate = true;
//
//  const labelMaterial = new THREE.SpriteMaterial({ 
//    map: labelTexture,
//    transparent: true,
//    sizeAttenuation: false, // Fixed screen size
//    depthTest: true,        // Text hides behind walls (optional, change to false if needed)
//    depthWrite: false
//  });
//
//  const labelSprite = new THREE.Sprite(labelMaterial);
//  labelSprite.position.copy(pos);
//  
//  // --- CRITICAL ALIGNMENT ---
//  // (0,0) sets the Sprite's anchor to the Bottom-Left corner of the texture
//  labelSprite.center.set(0.0, 0.0);
//
//  // Scale: 0.25 relates to the canvas aspect ratio logic
//  // Adjust 0.08 up or down to change overall text size
//  const labelScale = 0.08; 
//  // Maintain 4:1 aspect ratio of the 1024x256 canvas
//  labelSprite.scale.set(labelScale * 4, labelScale, 1);
// 1. Setup High-Res Canvas



//  const canvas = document.createElement('canvas');
//  // Wide canvas to accommodate long text
//  canvas.width = 1024; 
//  canvas.height = 512; 
//  const ctx = canvas.getContext('2d');
//  if (!ctx) return;
//
//  // 2. Configuration
//  const dotRadius = 24;
//  const dotBorder = 6;
//  const fontSize = 50;
//  const padding = 20; // Padding inside the text box
//  const boxRadius = 20; // Corner radius of the box
//  
//  // 3. Define the "Pivot Point" on the Canvas
//  // This is where the 3D position will map to.
//  // We place it near the bottom-left, but with enough room for the dot radius.
//  const pivotX = 40; 
//  const pivotY = canvas.height - 40; 
//
//  // 4. Draw the Dot (Centered on pivot)
//  ctx.beginPath();
//  ctx.arc(pivotX, pivotY, dotRadius, 0, 2 * Math.PI);
//  ctx.fillStyle = "black";
//  ctx.fill();
//  ctx.lineWidth = dotBorder;
//  ctx.strokeStyle = "white";
//  ctx.stroke();
//
//  // 5. Draw the Label (Extending from pivot)
//  // We want the bottom-left of the box to start at the pivot
//  ctx.font = `Bold ${fontSize}px Arial`;
//  const textMetrics = ctx.measureText(content);
//  const textWidth = textMetrics.width;
//  
//  const boxWidth = textWidth + (padding * 2);
//  const boxHeight = fontSize + (padding * 2);
//  
//  // Position the box:
//  // X: Starts slightly to the right of the dot (pivotX + spacing)
//  // Y: Starts 'above' the pivot (remember canvas Y is inverted, so "up" is subtraction)
//  const boxX = pivotX + dotRadius + 10; // 10px gap
//  const boxY = pivotY - boxHeight + (dotRadius / 2); // Align bottom of box roughly with dot center
//
//  // Draw Rounded Rectangle
//  ctx.fillStyle = "rgba(0, 0, 0, 0.85)";
//  ctx.beginPath();
//  ctx.moveTo(boxX + boxRadius, boxY);
//  ctx.lineTo(boxX + boxWidth - boxRadius, boxY);
//  ctx.quadraticCurveTo(boxX + boxWidth, boxY, boxX + boxWidth, boxY + boxRadius);
//  ctx.lineTo(boxX + boxWidth, boxY + boxHeight - boxRadius);
//  ctx.quadraticCurveTo(boxX + boxWidth, boxY + boxHeight, boxX + boxWidth - boxRadius, boxY + boxHeight);
//  ctx.lineTo(boxX + boxRadius, boxY + boxHeight);
//  ctx.quadraticCurveTo(boxX, boxY + boxHeight, boxX, boxY + boxHeight - boxRadius);
//  ctx.lineTo(boxX, boxY + boxRadius);
//  ctx.quadraticCurveTo(boxX, boxY, boxX + boxRadius, boxY);
//  ctx.closePath();
//  ctx.fill();
//
//  // Draw Text
//  ctx.fillStyle = "white";
//  ctx.textAlign = "left";
//  ctx.textBaseline = "middle";
//  ctx.fillText(content, boxX + padding, boxY + (boxHeight / 2));
//
//  // 6. Create Texture
//  const texture = new THREE.CanvasTexture(canvas);
//  texture.minFilter = THREE.LinearFilter; // Smooth scaling
//  texture.needsUpdate = true;
//
//  // 7. Material
//  const spriteMaterial = new THREE.SpriteMaterial({ 
//    map: texture,
//    transparent: true,
//    sizeAttenuation: false, // Keep constant size on screen
//    depthTest: true, //false,       // Always visible (draws on top of everything)
//    depthWrite: false
//  });
//
//  const sprite = new THREE.Sprite(spriteMaterial);
//  sprite.position.copy(pos);
//
//  // 8. THE CRITICAL ANCHOR CALCULATION
//  // We must map our Canvas Pivot (pixel coordinates) to UV coordinates (0.0 to 1.0)
//  
//  // X: Simple ratio (Pivot X / Total Width)
//  const anchorX = pivotX / canvas.width;
//  
//  // Y: Inverted ratio (Canvas 0 is top, UV 0 is bottom)
//  const anchorY = 1.0 - (pivotY / canvas.height);
//
//  sprite.center.set(anchorX, anchorY);
//
//  // 9. Scale
//  // Adjust scale to control overall size on screen
//  const scale = 0.15; 
//  // Maintain aspect ratio based on canvas dimensions
//  sprite.scale.set(scale * (canvas.width / canvas.height), scale, 1);
//    currentLayer.add(sprite);
//  //return sprites.push(sprite) - 1;
//  return 1;
//}

function addSprite(pos: THREE.Vector3, _title: string, content: string) {
// 1. Setup Canvas
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  // 2. Settings for the "Architectural" look
  const fontSize = 48;
  const font = "Bold " + fontSize + "px Arial";
  const lineColor = "rgba(0, 0, 0, 1)";
  const lineWidth = 6;
  
  // The "Leader" is the angled line. 
  // rise/run determines the angle (e.g., 45 degrees)
  const leaderRun = 50;  // Horizontal distance from point to elbow
  const leaderRise = 50; // Vertical distance from point to elbow

  // 3. Define the Pivot Point on Canvas
  // (Where the line touches the 3D object)
  const pivotX = 40;
  const pivotY = canvas.height - 40; 

  // 4. Calculate Text Size
  ctx.font = font;
  const metrics = ctx.measureText(content);
  const textWidth = metrics.width;

  // 5. Draw the Lines
  ctx.strokeStyle = lineColor;
  ctx.lineWidth = lineWidth;
  ctx.lineCap = "round"; // Makes corners smooth
  ctx.lineJoin = "round";

  ctx.beginPath();
  // Start at the pivot (The 3D location)
  ctx.moveTo(pivotX, pivotY);
  
  // Draw diagonal to the "Elbow"
  // Note: Canvas Y is inverted, so subtracting 'rise' moves UP
  const elbowX = pivotX + leaderRun;
  const elbowY = pivotY - leaderRise;
  ctx.lineTo(elbowX, elbowY);

  // Draw horizontal line (The Underline)
  // Length matches text width plus a little padding
  const endX = elbowX + textWidth + 10; 
  ctx.lineTo(endX, elbowY);
  
  ctx.stroke();

  // 6. Draw the Text
  // We draw it sitting *on top* of the horizontal line
  ctx.fillStyle = lineColor;
  ctx.textAlign = "left";
  ctx.textBaseline = "bottom"; 
  
  // Optional: Add a drop shadow for readability against bright backgrounds
  //ctx.shadowColor = "rgba(0,0,0,0.8)";
  //ctx.shadowBlur = 6;
  //ctx.shadowOffsetX = 2;
  //ctx.shadowOffsetY = 2;

  // Position text at the Elbow X, and slightly above the Elbow Y
  ctx.fillText(content, elbowX, elbowY - 5);

  // 7. Optional: Draw a small dot at the pivot to mark the exact spot
  ctx.shadowColor = "transparent"; // Reset shadow for the dot
  ctx.fillStyle = lineColor;
  ctx.beginPath();
  ctx.arc(pivotX, pivotY, 6, 0, Math.PI * 2);
  ctx.fill();

  // 8. Create Texture
  const texture = new THREE.CanvasTexture(canvas);
  texture.minFilter = THREE.LinearFilter;
  texture.needsUpdate = true;

  // 9. Material
  const spriteMaterial = new THREE.SpriteMaterial({ 
    map: texture,
    transparent: true,
    sizeAttenuation: false, // Fixed screen size
    depthTest: true, //false,       // Always visible through walls
    depthWrite: false
  });

  const sprite = new THREE.Sprite(spriteMaterial);
  sprite.position.copy(pos);

  // 10. ANCHOR CALCULATION
  // Map pixel pivot to UV coordinates (0 to 1)
  const anchorX = pivotX / canvas.width;
  const anchorY = 1.0 - (pivotY / canvas.height);
  
  sprite.center.set(anchorX, anchorY);

  // 11. Scale
  const scale = 0.2; // Adjust overall size
  sprite.scale.set(scale * (canvas.width / canvas.height), scale, 1);
    currentLayer.add(sprite);
  return sprites.push(sprite) - 1;
}


function disposeSprite(sprite: THREE.Sprite) {
  sprite.removeFromParent();
  if (sprite.material instanceof THREE.SpriteMaterial && sprite.material.map) {
    sprite.material.map.dispose();
  }
  sprite.material.dispose();
  sprite.geometry.dispose();
}
function delSprite(idx: number) {
  const sprite = sprites[idx];
  if (sprite) {
    disposeSprite(sprite);
    (sprites as any[])[idx] = null;
  }
  return idx;
}
function delAllSprites() {
  const length = sprites.length;
  sprites.forEach(s => { if (s) disposeSprite(s); });
  sprites.length = 0;
  return length;
}

//const SpriteId = new PrimitiveType("SpriteId", 4, (io) => getSprite(io.readInt32()), (io, v) => io.writeInt32(addSprite(v)));

/*
function wireframeCheck(obj: THREE.Object3D) {
  if (wireframeActive) {
    if (obj.userData.KhepriWireframe) {
      obj.userData.KhepriWireframe.visible = true;
    } else {
      if (obj instanceof THREE.Mesh) {
        const wireframe = new THREE.LineSegments(new THREE.WireframeGeometry(obj.geometry), wireframeMaterial);
        obj.userData.KhepriWireframe = wireframe;
        obj.add(wireframe);
      } else {
        obj.children.forEach(wireframeCheck);
      }
    }
  } else {
    if (obj.userData.KhepriWireframe) {
      obj.userData.KhepriWireframe.visible = false;
    }
  }
}

function setWireframeActive(v: boolean) {
  wireframeActive = v;
  objects.forEach(wireframeCheck);
}
*/
let selected: THREE.Mesh[] = [];
function select(obj: THREE.Mesh) {
  if (obj.userData.KhepriSelected) {
    obj.userData.KhepriSelected.visible = true;
  } else {
    const isSelected = new THREE.Mesh(obj.geometry, selectedMaterial);
    obj.userData.KhepriSelected = isSelected;
    obj.add(isSelected);
  }
  selected.push(obj);
}
/*
function deselect(obj: THREE.Mesh) {
  if (obj.userData.KhepriSelected) {
    obj.userData.KhepriSelected.visible = false;
  }
  selected = selected.filter((e) => e !== obj);
}*/
function deselectAll() {
  selected.forEach(e => e.userData.KhepriSelected.visible = false);
  selected = [];
}
/*
function getSelected() {
  return selected;
}*/

////////////////////////////////

//The GUI panel can have children
const guis: GUI[] = [];
function addGUI(obj: GUI) {
  return guis.push(obj) - 1;
}
// We use the trick of knowing that Ids are Int32 so we just get the index
function getGUI(idx: number) {
  return guis[idx];
}
/*
function delGUI(idx: number) {
  guis[idx].destroy()
  delete guis[idx];
}*/

const GUIId = new PrimitiveType("GUIId", ofSize(TypeSize.Int32), (io) => getGUI(io.readInt32()), (io, v) => io.writeInt32(addGUI(v)));

//Using messages placed in the WebSocket

typedFunction("guiCreate", [Str, Int32], GUIId, (title: string, kind: number) => {
  const gui = new GUI({ title: title });
  kind
/*  if (kind == 1) {
    const params = {
      grid: true,
      wireFrame: wireframeActive,
      outline: false,
      shading: 'glossy',
    };*/
    //  gui.add(params, '???', [ 2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 40, 50 ] ).name( 'Tessellation Level' ).onChange( render );
    /*
    gui.add(params, 'grid').name('Grid?').onChange(() => grid.visible = params.grid);
    gui.add(params, 'wireFrame').name('Wireframe?').onChange(setWireframeActive);
    gui.add(params, 'outline').name('Outline').onChange(() => outlineEffect.enabled = params.outline);
    */
    //  gui.add(params, 'body' ).name( 'display body' ).onChange( render );
    //  gui.add(params, 'bottom' ).name( 'display bottom' ).onChange( render );
    //  gui.add(params, 'fitLid' ).name( 'snug lid' ).onChange( render );
    //  gui.add(params, 'nonblinn' ).name( 'original scale' ).onChange( render );
    //  gui.add(params, 'newShading', [ 'wireframe', 'flat', 'smooth', 'glossy', 'textured', 'reflective' ] ).name( 'Shading' ).onChange( render );
    //outlineEffect.enabled = params.outline;
  //}
  return gui;
});

typedFunction("guiAddFolder", [GUIId, Str, Bool], GUIId, (gui: GUI, title: string, closed: boolean) => {
  const folder = gui.addFolder(title);
  if (closed) folder.close();
  return folder;
});

typedFunction("guiRemove", [GUIId], None, (gui: GUI) => {
  gui.destroy();
});

typedFunction("guiVisible", [GUIId, Bool], None, (gui: GUI, visible: boolean) => {
  if (visible) {
    gui.show();
  } else {
    gui.hide();
  }
});

//type request = string;
//const Request = Str;
type request = number;
const Request = Int32


typedFunction("guiAddButton", [GUIId, Str, Request], GUIId,
  (gui: GUI, name: string, request: request) => {
    const param = { field: () => sendRequest(request) };
    return gui.add(param, 'field').name(name);
});

function onChangeMakeRequest(request: request, prev: any) {
  return function<t, T extends Controller<{ field: t; }, "field">>(this: T, value: t) {
    if (value != prev) {
      if (sendRequest(request, value)) {
        prev = value;        
      } else {
        this.setValue(prev);
      }
    }
  };
}

typedFunction("guiAddCheckbox", [GUIId, Str, Request, Bool], GUIId,
  (gui: GUI, name: string, request: request, curr: boolean) => {
    const param = { field: curr };
    return gui.add(param, 'field').name(name).onChange(onChangeMakeRequest(request, curr));
  });

typedFunction("guiAddSlider", [GUIId, Str, Request, Float32, Float32, Float32, Float32], GUIId,
  (gui: GUI, name: string, request: request, min: number, max: number, step: number, curr: number) => {
    const param = { field: curr };
    return gui.add(param, 'field', min, max, step).name(name).onChange(onChangeMakeRequest(request, curr));
  });

typedFunction("guiAddDropdown", [GUIId, Str, Request, Dict, Int32], GUIId,
  (gui: GUI, name: string, request: request, options: any, curr: number) => {
    const param = { field: curr };
    return gui.add(param, 'field', options).name(name).onChange(onChangeMakeRequest(request, curr));
  });

// To read/write files, the action needs to be started from a user action

typedFunction("guiAddLoadFileButton", [GUIId, Str, Request], GUIId,
  (gui: GUI, name: string, request: request) => {
    const param = { field: () => loadFileAndSendRequest(request) };
    return gui.add(param, 'field').name(name);
});

///////////////////////
// Grid Helper

let grid: THREE.GridHelper;

typedFunction("gridHelper", [Int32, Int32, RGB, RGB], None,
  (size: number, divisions: number, colorCenterLine: THREE.Color, colorGrid: THREE.Color) => {
    if (grid) {
      grid.removeFromParent();
      grid.dispose();
    }
    // HACK: Erase existing grid?
    grid = new THREE.GridHelper(size, divisions, colorCenterLine, colorGrid);
    //grid.rotateX(-Math.PI / 2);
    //grid.translateY(1);
    //grid.renderOrder = 1;
    currentLayer.add(grid);
  });

///////////////////////
// The graphical stuff

typedFunction("addAnnotation", [Point3d, Str], Int32, (p: THREE.Vector3, txt: string) => addSprite(p, "", txt));
typedFunction("deleteAnnotation", [Int32], None, (i: number) => delSprite(i));


//typedFunction("addAnnotation", [Point3d, Str], Id, (p, txt) => newAnnotation(p, "", txt));
//typedFunction("deleteAnnotation", [Int32], None, (i) => delSprite(i));



typedFunction("points", [[Point3d], MatId], Id, (vs: THREE.Vector3[], mat: THREE.Material) => {
  return new THREE.Points(new THREE.BufferGeometry().setFromPoints(vs), mat);
});

typedFunction("line", [[Point3d], MatId], Id, (vs: THREE.Vector3[], mat: THREE.Material) => {
  return new THREE.Line(new THREE.BufferGeometry().setFromPoints(vs), mat);
});

typedFunction("spline", [[Point3d], Bool, MatId], Id, (vs: THREE.Vector3[], closed: boolean, mat: THREE.Material) => {
  const pts = new THREE.CatmullRomCurve3(vs, closed).getPoints(Math.round(8 * (vs.length)));
  return new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), mat);
});

typedFunction("arc", [Matrix4x4, Float32, Float32, Float32, MatId], Id,
  (m: THREE.Matrix4, r: number, start: number, finish: number, mat: THREE.Material) => {
    const pts = new THREE.ArcCurve(0, 0, r, start, finish, finish < start)
      .getPoints(Math.round(64 * ((Math.abs(finish - start)) / 2 / Math.PI)));
    return withTransform(m, new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), mat));
  });

typedFunction("arcRegion", [Matrix4x4Y, Float32, Float32, Float32, MatId], Id,
  (m: THREE.Matrix4, r: number, start: number, amplitude: number, mat: THREE.Material) => {
    const geo = new THREE.CircleGeometry(r, Math.round(64 * (amplitude / 2 / Math.PI)), start, amplitude);
    return withTransform(m, new THREE.Mesh(geo, mat));
  });


typedFunction("surfacePolygonWithHoles", [Matrix4x4, [Point2d], [[Point2d]], MatId], Id,
  (m: THREE.Matrix4, ps: THREE.Vector2[], qss: THREE.Vector2[][], mat: THREE.Material) => {
    const faces = THREE.ShapeUtils.triangulateShape(ps, qss);
    const vs = new Float32Array((ps.length + qss.reduce((n, qs) => n + qs.length, 0)) * 3);
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
    geo.setIndex(([] as number[]).concat(...faces));
    geo.setAttribute('position', new THREE.BufferAttribute(vs, 3));
    return withTransform(m, new THREE.Mesh(geo, mat));
  });

typedFunction("sphere", [Point3d, Float32, MatId], Id,
  (c: THREE.Vector3, r: number, mat: THREE.Material) => {
    const geo = new THREE.SphereGeometry(r, 64, 64);
    const obj = new THREE.Mesh(geo, mat);
    obj.position.copy(c);
    return obj;
  });

typedFunction("box", [Matrix4x4, Float32, Float32, Float32, MatId], Id,
  (m: THREE.Matrix4, dx: number, dy: number, dz: number, mat: THREE.Material) =>
    withTransform(m, new THREE.Mesh(new THREE.BoxGeometry(dx, dy, dz), mat)));

typedFunction("torus", [Matrix4x4, Float32, Float32, MatId], Id,
  (m: THREE.Matrix4, re: number, ri: number, mat: THREE.Material) =>
    withTransform(m, new THREE.Mesh(new THREE.TorusGeometry(re, ri, 64, 32), mat)));

typedFunction("cylinder", [Matrix4x4Y, Float32, Float32, Float32, Bool, MatId], Id,
  (m: THREE.Matrix4, rb: number, rt: number, h: number, open: boolean, mat: THREE.Material) =>
    withTransform(m, new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, 64, 1, open), mat)));

typedFunction("mesh", [ArrayFloat32, MatId], Id,
  (vs: Float32Array, mat: THREE.Material) => {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(vs, 3));
    return new THREE.Mesh(geo, mat);
  });

typedFunction("meshIndexed", [ArrayFloat32, ArrayInt32, MatId], Id,
  (vs: Float32Array, idxs: Int32Array, mat: THREE.Material) => {
    const geo = new THREE.BufferGeometry();
    //geo.setIndex(Array.from(idxs)); //geo.setAttribute('index', new THREE.BufferAttribute(idxs, 1));
    geo.setIndex(new THREE.BufferAttribute(new Uint32Array(idxs.buffer, idxs.byteOffset, idxs.length), 1)); //geo.setAttribute('index', new THREE.BufferAttribute(idxs, 1));
    geo.setAttribute('position', new THREE.BufferAttribute(vs, 3));
    return new THREE.Mesh(geo, mat);
  }); 

typedFunction("quadStrip", [[Point3d], [Point3d], Bool, MatId], Id,
  (ps: THREE.Vector3[], qs: THREE.Vector3[], smooth: boolean, mat: THREE.Material) => {
    const geo = smooth ? quadStripSmoothGeometry(ps, qs) : quadStripFlatGeometry(ps, qs);
    return new THREE.Mesh(geo, mat);
  });

function quadStripSmoothGeometry(ps: THREE.Vector3[], qs: THREE.Vector3[]): THREE.BufferGeometry {
   const vertices: number[] = [];
   const indices: number[] = [];
   const numQuads = ps.length - 1;
   for (let i = 0; i < ps.length; i++) {
       vertices.push(ps[i].x, ps[i].y, ps[i].z);
       vertices.push(qs[i].x, qs[i].y, qs[i].z);
   }
   for (let i = 0; i < numQuads; i++) {
       const topLeft = 2 * i;
       const topRight = 2 * i + 2;
       const bottomLeft = 2 * i + 1;
       const bottomRight = 2 * i + 3;
       indices.push(topLeft, topRight, bottomLeft);
       indices.push(topRight, bottomRight, bottomLeft);
   }
   const geometry = new THREE.BufferGeometry();
   geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
   geometry.setIndex(indices);
   return geometry;
}

function quadStripFlatGeometry(ps: THREE.Vector3[], qs: THREE.Vector3[]): THREE.BufferGeometry {
  const vertices: number[] = [];
  const indices: number[] = [];
  const numQuads = ps.length - 1;
  for (let i = 0; i < numQuads; i++) {
      const v0 = ps[i];     // top left
      const v1 = ps[i + 1]; // top right
      const v2 = qs[i + 1]; // bottom right
      const v3 = qs[i];     // bottom left
      const baseIndex = (i * 4);
      vertices.push(v0.x, v0.y, v0.z);
      vertices.push(v1.x, v1.y, v1.z);
      vertices.push(v2.x, v2.y, v2.z);
      vertices.push(v3.x, v3.y, v3.z);
      indices.push(baseIndex, baseIndex + 1, baseIndex + 2);
      indices.push(baseIndex, baseIndex + 2, baseIndex + 3);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  geometry.setIndex(indices);
  return geometry;
}

typedFunction("surfaceGrid", [[[Point3d]], Bool, Bool, Bool, Bool, MatId], Id, (points: THREE.Vector3[][], uClosed: boolean, vClosed: boolean, uSmooth: boolean, vSmooth: boolean, mat: THREE.Material) => {    
  return new THREE.Mesh((uSmooth && vSmooth) ?
                          createSmoothSurface(points, uClosed, vClosed) :
                          uSmooth ?
                            createUSmoothVFlatSurface(points, uClosed, vClosed) :
                            vSmooth ?
                              createUFlatVSmoothSurface(points, uClosed, vClosed) :
                              createFlatSurface(points, uClosed, vClosed),
                        mat);
})

function createSmoothSurface(points: THREE.Vector3[][], uClosed: boolean, vClosed: boolean): THREE.BufferGeometry {
  const uCount = points.length;
  const vCount = points[0].length;
  const uSegments = uClosed ? uCount : uCount - 1;
  const vSegments = vClosed ? vCount : vCount - 1;
  const vertices: number[] = [];
  const indices: number[] = [];
  const uvs: number[] = [];
  for (let u = 0; u < uCount; u++) {
    for (let v = 0; v < vCount; v++) {
      const point = points[u][v];
      vertices.push(point.x, point.y, point.z);
      uvs.push(u / uSegments, v / vSegments);
    }
  }
  for (let u = 0; u < uSegments; u++) {
    for (let v = 0; v < vSegments; v++) {
      const uNext = (u + 1) % uCount;
      const vNext = (v + 1) % vCount;
      const i00 = u * vCount + v;
      const i10 = uNext * vCount + v;
      const i11 = uNext * vCount + vNext;
      const i01 = u * vCount + vNext;
      indices.push(i00, i10, i11, i00, i11, i01);
    }
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  return geometry;
}

function createFlatSurface(points: THREE.Vector3[][], uClosed: boolean, vClosed: boolean): THREE.BufferGeometry {
  const uCount = points.length;
  const vCount = points[0].length;
  const uSegments = uClosed ? uCount : uCount - 1;
  const vSegments = vClosed ? vCount : vCount - 1;
  const vertices: number[] = [];
  const indices: number[] = [];
  const uvs: number[] = [];
  let vertexIndex = 0;
  for (let u = 0; u < uSegments; u++) {
    for (let v = 0; v < vSegments; v++) {
      const uNext = (u + 1) % uCount;
      const vNext = (v + 1) % vCount;
      const p00 = points[u][v];
      const p10 = points[uNext][v];
      const p11 = points[uNext][vNext];
      const p01 = points[u][vNext];
      vertices.push(p00.x, p00.y, p00.z);
      vertices.push(p10.x, p10.y, p10.z);
      vertices.push(p11.x, p11.y, p11.z);
      vertices.push(p01.x, p01.y, p01.z);
      const u0 = u / uSegments;
      const u1 = (u + 1) / uSegments;
      const v0 = v / vSegments;
      const v1 = (v + 1) / vSegments;
      uvs.push(u0, v0, u1, v0, u1, v1, u0, v1);
      indices.push(vertexIndex, vertexIndex + 1, vertexIndex + 2,
                   vertexIndex, vertexIndex + 2, vertexIndex + 3);
      vertexIndex += 4;
    }
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  return geometry;
}

function createUSmoothVFlatSurface(points: THREE.Vector3[][], uClosed: boolean, vClosed: boolean): THREE.BufferGeometry {
  const uCount = points.length;
  const vCount = points[0].length;
  const vSegments = vClosed ? vCount : vCount - 1;
  const vertices: number[] = [];
  const indices: number[] = [];
  const uvs: number[] = [];
  let vertexIndex = 0;
  for (let v = 0; v < vSegments; v++) {
    const vNext = (v + 1) % vCount;
    for (let u = 0; u < uCount; u++) {
      const pTop = points[u][v];
      vertices.push(pTop.x, pTop.y, pTop.z);
      uvs.push(u / (uCount - 1), v / vSegments);
      const pBottom = points[u][vNext];
      vertices.push(pBottom.x, pBottom.y, pBottom.z);
      uvs.push(u / (uCount - 1), (v + 1) / vSegments);
    }
    const uSegments = uClosed ? uCount : uCount - 1;
    for (let u = 0; u < uSegments; u++) {
      const uNext = (u + 1) % uCount;            
      const topLeft = vertexIndex + 2 * u;
      const topRight = vertexIndex + 2 * uNext;
      const bottomLeft = vertexIndex + 2 * u + 1;
      const bottomRight = vertexIndex + 2 * uNext + 1;
      indices.push(topLeft, topRight, bottomLeft);
      indices.push(topRight, bottomRight, bottomLeft);
    }
    vertexIndex += 2*uCount;
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  return geometry;
}

function createUFlatVSmoothSurface(points: THREE.Vector3[][], uClosed: boolean, vClosed: boolean): THREE.BufferGeometry {
  const uCount = points.length;
  const vCount = points[0].length;
  const uSegments = uClosed ? uCount : uCount - 1;
  const vertices: number[] = [];
  const indices: number[] = [];
  const uvs: number[] = [];
  let vertexIndex = 0;
  for (let u = 0; u < uSegments; u++) {
    const uNext = (u + 1) % uCount;
    for (let v = 0; v < vCount; v++) {
      const pLeft = points[u][v];
      vertices.push(pLeft.x, pLeft.y, pLeft.z);
      uvs.push(u / uSegments, v / (vCount - 1));
      const pRight = points[uNext][v];
      vertices.push(pRight.x, pRight.y, pRight.z);
      uvs.push((u + 1) / uSegments, v / (vCount - 1));
    }
   // Create indices for this strip (smooth along V)
    const vSegments = vClosed ? vCount : vCount - 1;
    for (let v = 0; v < vSegments; v++) {
      const vNext = (v + 1) % vCount;      
      const leftTop = vertexIndex + 2 * v;
      const leftBottom = vertexIndex + 2 * vNext;
      const rightTop = vertexIndex + 2 * v + 1;
      const rightBottom = vertexIndex + 2 * vNext + 1;
      indices.push(leftTop, rightTop, leftBottom);
      indices.push(rightTop, rightBottom, leftBottom);
    }
    vertexIndex += 2*vCount;
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  return geometry;
}

typedFunction("extrudedSurface", [Matrix4x4, [Point2d], Bool, [[Point2d]], [Bool], Vector3d, MatId], Id,
  (m: THREE.Matrix4, ps: THREE.Vector2[], _smooth: boolean, qss: THREE.Vector2[][], _smoothHoles: boolean, v: THREE.Vector3, mat: THREE.Material) => {
    const profile = new THREE.Shape(ps);
    qss.forEach(qs => profile.holes.push(new THREE.Shape(qs)));
    const extrudeSettings = (v.x == 0 && v.y == 0) ? 
      {
        steps: 1,
        depth: v.z,
        bevelEnabled: false
      } :
      { // This is a sweep: it might arbitrarily rotate the profile
        steps: 1,
        extrudePath: new THREE.LineCurve3(new THREE.Vector3(0, 0, 0), v),
        bevelEnabled: false
      };
    return withTransform(m, new THREE.Mesh(new THREE.ExtrudeGeometry(profile, extrudeSettings), mat));
  });

typedFunction("meshObjFmt", [Str, Str, Matrix4x4], Id, (path: string, name: string, m: THREE.Matrix4) => {
  const parent = new THREE.Object3D();
  new MTLLoader().setPath(path).loadAsync(`${name}.mtl`).then(materials => {
    materials.preload();
    new OBJLoader().setPath(path).setMaterials(materials).loadAsync(`${name}.obj`).then(object => {
      object.traverse(child => {
        if (child instanceof THREE.Mesh && child.material) {
          const mats = Array.isArray(child.material) ? child.material : [child.material];
          mats.forEach(mat => mat.side = THREE.DoubleSide);
        }
      });
      parent.add(object);
    }).catch(err => console.error(err));
  }).catch(err => console.error(err));
  return withTransform(m, parent);
});

typedFunction("MeshPhysicalMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
  new THREE.MeshPhysicalMaterial(params));

typedFunction("MeshStandardMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
  new THREE.MeshStandardMaterial(params));

typedFunction("MeshPhongMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
  new THREE.MeshPhongMaterial(params));

typedFunction("MeshLambertMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
  new THREE.MeshLambertMaterial(params));

typedFunction("LineBasicMaterial", [Dict], MatId, (params: { [key: string]: any }) =>
  new THREE.LineBasicMaterial(params));

function extractMaterialFromPolyHavenGLTF(gltf: GLTF) {
  return (gltf.scene.children[0] as THREE.Mesh).material
}

typedAsyncFunction("glTFMaterial", [Str], MatId, (path: string, cont: Function) =>
  new GLTFLoader().load(path, (gltf) => cont(extractMaterialFromPolyHavenGLTF(gltf))));

typedAsyncFunction("setEnvironment", [Str, Bool], None, (path: string, setBackground: boolean, cont: Function) =>
  new HDRLoader().load(path, function (texture) {
    texture.mapping = THREE.EquirectangularReflectionMapping;
    //texture.magFilter = THREE.NearestFilter;
    scene.environment = texture;
    scene.background = setBackground ? texture : null;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    //renderer.toneMappingExposure = 0.85;
    if (setBackground) {
      removeStandardSceneLighting();
    }
    cont()
  }));

typedFunction("setView", [Point3d, Point3d, Float32, Float32], None,
  (position: THREE.Vector3, target: THREE.Vector3, lens: number, _aperture: number) => {
    const sensorHeight = 24; // Typical 35mm film height in mm
    const fovInDegrees = THREE.MathUtils.radToDeg(2 * Math.atan(sensorHeight / (2 * lens)));
    camera.fov = fovInDegrees;
    camera.position.copy(position);
    camera.lookAt(target);
    const d = position.distanceTo(target);
    camera.near = Math.max(0.1, d * 0.1);
    camera.far = Math.min(2000, d * 20000);
    camera.updateProjectionMatrix();
    controls.target.copy(target);
    controls.update();
  });

/*
// See https://github.com/mrdoob/three.js/pull/14526
function zoomCameraToSelection(camera: THREE.PerspectiveCamera, controls: OrbitControls, selection: THREE.Object3D[]) {
const box = new THREE.Box3();
for (const object of selection) box.expandByObject(object);
const size = box.getSize(new THREE.Vector3());
const center = box.getCenter(new THREE.Vector3());
const maxSize = Math.max(size.x, size.y, size.z);
const fitHeightDistance = maxSize / (2 * Math.atan(Math.PI * camera.fov / 360));
const fitWidthDistance = fitHeightDistance / camera.aspect;
const distance = Math.max(fitHeightDistance, fitWidthDistance);
const direction = controls.target.clone()
  .sub(camera.position)
  .normalize()
  .multiplyScalar(distance);
//controls.maxDistance = distance * 10;
controls.target.copy(center);
camera.near = distance / 100;
camera.far = distance * 100;
camera.position.copy(controls.target).sub(direction);
camera.updateProjectionMatrix();
controls.update();
}
*/
//typedFunction("zoomExtents", [], None, () => {
//  zoomCameraToSelection(camera, controls, meshes);
//  /*    const boundingBox = new THREE.Box3();
//      meshes.forEach(object => boundingBox.expandBy(object));
//      const center = boundingBox
//      return boundingBox;*/
//});

//typedFunction("setSky", [Point3d, Point3d, Float32, Float32], None,
//  (position: THREE.Vector3, target: THREE.Vector3, lens: number, aperture: number) => {
//    /*    // Add Sky
//            sky = new Sky();
//            sky.scale.setScalar( 450000 );
//            currentLayer.add( sky );
//    
//            sun = new THREE.Vector3();
//    
//            /// GUI
//    
//            const effectController = {
//              turbidity: 10,
//              rayleigh: 3,
//              mieCoefficient: 0.005,
//              mieDirectionalG: 0.7,
//              elevation: 2,
//              azimuth: 180,
//              exposure: renderer.toneMappingExposure
//            };
//    
//            function guiChanged() {
//    
//              const uniforms = sky.material.uniforms;
//              uniforms[ 'turbidity' ].value = effectController.turbidity;
//              uniforms[ 'rayleigh' ].value = effectController.rayleigh;
//              uniforms[ 'mieCoefficient' ].value = effectController.mieCoefficient;
//              uniforms[ 'mieDirectionalG' ].value = effectController.mieDirectionalG;
//    
//              const phi = THREE.MathUtils.degToRad( 90 - effectController.elevation );
//              const theta = THREE.MathUtils.degToRad( effectController.azimuth );
//    
//              sun.setFromSphericalCoords( 1, phi, theta );
//    
//              uniforms[ 'sunPosition' ].value.copy( sun );
//    
//              renderer.toneMappingExposure = effectController.exposure;
//              renderer.render( scene, camera );
//    
//            }
//    */
//  });
let time = 0; 

typedFunction("stopUpdate", [], None, () => {
  time = +Date.now();
  update = false;
});
typedFunction("startUpdate", [], None, () => {
  let now = +Date.now();
  console.log("Paused for", (now - time), "ms");
  update = true;
});

function loadFileAndSendRequest(request: request) {
  fileOpen({
    description: 'KML files',
    mimeTypes: ['KML: application/vnd.google-earth.kml+xml', 
                'KMZ: application/vnd.google-earth.kmz'],
    extensions: ['.kml', '.kmz'],
    multiple: false,
  }).then((fileHandle: FileWithHandle) =>  {
    fileHandle.text().then((str: string) => {
      sendRequest(request, str)
    })});
}

typedAsyncFunction("showKMLCoordinatesFromFile", [], None, (cont: Function) => {
  fileOpen({
    description: 'KML files',
    mimeTypes: ['KML: application/vnd.google-earth.kml+xml', 
                'KMZ: application/vnd.google-earth.kmz'],
    extensions: ['.kml', '.kmz'],
    multiple: false,
  }).then((fileHandle: FileWithHandle) =>  {
    fileHandle.text().then((str: string) => {
      console.log(str);
      cont();
/*    (await file.text());
    try {
      const parser = new DOMParser();
      const kmlDoc = parser.parseFromString(kmlText, 'text/xml');
      const parseError = kmlDoc.getElementsByTagName('parsererror')[0];
      if (parseError) {
          throw new Error('Invalid KML file: XML parsing error');
    
      const coordinates = this.extractCoordinates(kmlDoc);
      console.log('Parsed coordinates:', coordinates);
      // Handle coordinates here (e.g., pass to mapping library)
      
        } catch (error) {
            console.error('Error parsing KML file:', error);
            alert('Error parsing KML file. Please check the file format.');
        } */
  })})});

/*

    private handleFileSelect(event: Event): void {
        const file = (event.target as HTMLInputElement).files?.[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (e) => this.parseKML(e.target?.result as string);
        reader.readAsText(file);
        
        // Reset input to allow selecting same file again
        this.fileInput.value = '';
    }

    private parseKML(kmlText: string): void {
        try {
            const parser = new DOMParser();
            const kmlDoc = parser.parseFromString(kmlText, 'text/xml');

            // Check for XML parsing errors
            const parseError = kmlDoc.getElementsByTagName('parsererror')[0];
            if (parseError) {
                throw new Error('Invalid KML file: XML parsing error');
            }

            const coordinates = this.extractCoordinates(kmlDoc);
            console.log('Parsed coordinates:', coordinates);
            // Handle coordinates here (e.g., pass to mapping library)
            
        } catch (error) {
            console.error('Error parsing KML file:', error);
            alert('Error parsing KML file. Please check the file format.');
        }
    }

    private extractCoordinates(kmlDoc: Document): number[][] {
        const coords: number[][] = [];
        const coordElements = kmlDoc.getElementsByTagName('coordinates');

        for (let i = 0; i < coordElements.length; i++) {
            const textContent = coordElements[i].textContent?.trim();
            if (!textContent) continue;

            const points = textContent.split(/\s+/);
            for (const point of points) {
                const [lon, lat, alt] = point.split(',').map(Number);
                if (!isNaN(lat) && !isNaN(lon)) {
                    coords.push([lat, lon, alt || 0]);
                }
            }
        }

        return coords;
    }
}

// Usage
new KMLParser('kml-loader-btn');
*/

function establishConnection(handler: (evt: MessageEvent) => void) {
  const url = `${location.protocol == "https:" ? "wss" : "ws"}://${location.host}/threejs`;
  const connection = new WebSocket(url);
  connection.binaryType = "arraybuffer";
  connection.onmessage = handler;
  connection.onclose = function (evt) {
    console.log("onclose:", evt);
  }
  return connection;
}

function render() {
  renderer.render(scene, camera);
  //outlineEffect.render(scene, camera);
  updateScreenPosition();
}

function updateScreenPosition() {
//  sprites.forEach(sprite => {
//    const annotation = sprite.userData.KhepriDOM;
//    //Object position
//    //const position = new THREE.Vector3(25,25,25);
//    //    const meshDistance = camera.position.distanceTo(position);
//    //    const spriteDistance = camera.position.distanceTo(sprite.position);
//    const spriteBehindObject = false; //spriteDistance > meshDistance;
//    //sprite.material.opacity = spriteBehindObject ? 0.25 : 1; 
//    //sprite.material.opacity = 0;
//    const vector = new THREE.Vector3(25, 25, 25);
//    vector.setFromMatrixPosition(sprite.matrixWorld);
//    vector.project(camera);
//    const canvas = renderer.domElement;
//    vector.x = Math.round((1 + vector.x)*(canvas.width/window.devicePixelRatio)/2);
//    vector.y = Math.round((1 - vector.y)*(canvas.height/window.devicePixelRatio)/2);
//    annotation.style.top = `${vector.y}px`;
//    annotation.style.left = `${vector.x}px`;
//    annotation.style.opacity = spriteBehindObject ? 0.25 : 1;
//    //console.log(annotation.style);
//  });
}

//Materials
//defaultMaterial = new THREE.MeshPhongMaterial({ color:0xaaaaaa, side:THREE.DoubleSide});
defaultMaterial = new THREE.MeshLambertMaterial({
  side: THREE.DoubleSide, polygonOffset: true,
  polygonOffsetFactor: 1, // positive value pushes polygon further away
  polygonOffsetUnits: 1
});
//defaultLineMaterial = new THREE.LineBasicMaterial({ color: 0x000000, depthWrite: true }) //For lines
//wireframeMaterial = new THREE.MeshBasicMaterial({ color: 0xaaaaaa, opacity: 0.5, wireframe: true, transparent: true });
//wireframeActive = false;
selectedMaterial = new THREE.MeshBasicMaterial({ color: 0xfff200, opacity: 0.3, transparent: true });

let light:THREE.Light;
let ambientLight:THREE.Light;

function addStandardSceneLighting() {
  light = new THREE.HemisphereLight(0xffffff, 0x888888, 3)
  light.position.set(0, 0, 10);
  defaultLayer.add(light)
  ambientLight = new THREE.AmbientLight( 0x7c7c7c, 3.0 );
  defaultLayer.add(ambientLight);
  //light = new THREE.DirectionalLight( 0xFFFFFF, 3.0 );
  //light.position.set( 0.32, 0.39, 0.7 );
  //defaultLayer.add(light);
}

function removeStandardSceneLighting() {
  defaultLayer.remove(light)
  defaultLayer.remove(ambientLight);
}

  //currentLayer.add(new THREE.AxesHelper(5));
  //currentLayer.add(new InfiniteGridHelper(false, false, false, false, 'xyz'));


/*
outlineEffect = new OutlineEffect(renderer, {
  defaultThickness: 0.001,
  defaultColor: [0, 0, 0],
  defaultAlpha: 0.5,
  defaultKeepAlive: true
});
*/

/*    const light = new THREE.HemisphereLight(0xffffff, 0x888888, 3)
    light.position.set(0, 0, 10);
*/
    //const ambientLight = new THREE.AmbientLight( 0x7c7c7c, 3.0 );
    //currentLayer.add(ambientLight);

    //light = new THREE.DirectionalLight( 0xFFFFFF, 3.0 );
    //light.position.set( 0.32, 0.39, 0.7 );
//    currentLayer.add(light);
    //currentLayer.add(new THREE.AxesHelper(5));
    //currentLayer.add(new InfiniteGridHelper(false, false, false, false, 'xyz'));
/*
    const sky = new Sky();
    sky.scale.setScalar(450000);
    currentLayer.add(sky);
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
    uniforms["turbidity"].value = effectController.turbidity;
    uniforms["rayleigh"].value = effectController.rayleigh;
    uniforms["mieCoefficient"].value = effectController.mieCoefficient;
    uniforms["mieDirectionalG"].value = effectController.mieDirectionalG;
    uniforms["sunPosition"].value.set(400000, 400000, 400000);
    currentLayer.add(sky);
*/

document.body.appendChild(renderer.domElement);
addStandardSceneLighting()
connection = establishConnection(handleMessage);

// Raycaster setup
const raycaster = new THREE.Raycaster();
const mouse = new THREE.Vector2();
function onMouseClick(event: MouseEvent) {
  mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
  mouse.y = - (event.clientY / window.innerHeight) * 2 + 1;
  raycaster.setFromCamera(mouse, camera);
  // We can't use the meshes array because as we delete stuff, the array slots become undefined
  const intersects = raycaster.intersectObjects(scene.children);
  if (intersects.length > 0) {
    //console.log(intersects)
    const obj = intersects[0].object;
    if (!event.shiftKey) {
      deselectAll();
    }
    if (obj != grid) {
      select(obj as THREE.Mesh);
    }
  } else {
    deselectAll();
  }
}
function onWindowResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  //outlineEffect.setSize(window.innerWidth, window.innerHeight);
}
window.addEventListener('click', onMouseClick, false);
window.addEventListener('resize', onWindowResize, false);
renderer.setAnimationLoop(()=>{
  controls.update();
  if (update) {
    render();
  }
});

