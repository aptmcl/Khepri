# KhepriThreejs Technical Documentation

KhepriThreejs is a Khepri backend that renders 3D geometry in a web browser
using Three.js. Julia runs a combined HTTP + WebSocket server; browser clients
connect, receive binary-encoded draw commands, and can send interaction events
back to Julia.

This document covers two use cases:

1. **Interactive mode** — a single Julia REPL drives a single browser window.
2. **Multi-client mode** — multiple browser clients connect to a single Julia
   server, each sending requests that trigger geometry creation.

## Architecture Overview

```
┌─────────────────────┐         WebSocket (binary)        ┌──────────────────┐
│   Julia / KhepriBase│◄────────────────────────────────►│  Browser / Three.js│
│                     │         HTTP (static files)       │                  │
│  WebSocket Server   │────────────────────────────────►│  Vite-built app   │
│  (127.0.0.1:12346)  │                                   │  (index.html)     │
└─────────────────────┘                                   └──────────────────┘
```

The system has two parts:

- **Julia side** (`src/`): A `WebSocketBackend` that implements KhepriBase's
  `b_*` geometry operations by encoding them as binary messages and sending them
  over a WebSocket connection.
- **Browser side** (`KhepriThree.js/`): A TypeScript application built with
  Vite that receives those messages, decodes them, and executes the
  corresponding Three.js calls.

### Server Startup

The server is a `LazyParameter` — it starts automatically on the first
operation that requires it. It binds to `127.0.0.1:12346` by default and
handles both HTTP requests (serving the frontend) and WebSocket upgrades
(establishing backend connections).

```julia
# These GlobalParameters control the server address:
default_khepri_websocket_server_host  # default: ip"127.0.0.1"
default_khepri_websocket_server_port  # default: 12346
```

The same HTTP server serves the built frontend files from
`KhepriThree.js/dist/` and resource files (materials, models, environments)
from KhepriBase's resource folders.

### Connection Lifecycle

When a browser loads `http://127.0.0.1:12346`, the server delivers
`index.html` and the compiled JavaScript. The browser JavaScript then opens a
WebSocket connection to `ws://127.0.0.1:12346/threejs`. The server:

1. Detects the WebSocket upgrade request.
2. Looks up `"threejs"` in the backend init map (registered during
   `KhepriThreejs.__init__()`).
3. Calls the init function, which creates a new `THR` backend instance bound to
   that specific WebSocket connection.
4. Calls `main(backend)`, which invokes the user-supplied `main_callback`.
5. The connection stays open for the lifetime of the browser tab.

### Binary Protocol

All communication uses binary WebSocket frames. The protocol is symmetric:

**Server → Client (draw commands):**
```
┌──────────────┬────────────────────────┐
│ Int32: opIdx │ encoded arguments ...  │
└──────────────┴────────────────────────┘
```
`opIdx ≥ 0` identifies the operation by its index in the client's operation
table. The client decodes the arguments according to the operation's type
signature, executes it, and sends back the return value.

**Client → Server (interaction requests):**
```
┌──────────────┬──────────────┬──────────────────┐
│ Int32: reqIdx│ Int32: nArgs │ encoded args ... │
└──────────────┴──────────────┴──────────────────┘
```
`reqIdx` is the index of a handler registered via `register_handler` on the
Julia side. The server decodes the arguments, calls the handler, and responds
with `Int32(-1)` (success) or `Int32(-2)` (error).

**Type encoding** uses KhepriBase's `encode`/`decode` system with namespace
`Val(:THR)`, which delegates primitive types to `Val(:TS)`. Custom encodings
handle `Point3d`, `Vector3d`, `Point2d`, `Matrix4x4`, `Frame3d`, and array
types. Variable-length integers encode string lengths.

### Remote API

The `threejs_api` definition in `src/Threejs.jl` uses `@remote_api :THR` to
declare all available operations. Each entry specifies the operation name, Julia
argument types, return type, and inline TypeScript signature. For example:

```
typedFunction("sphere", [Point3d, Float32, MatId], Id,
  (c: THREE.Vector3, r: number, mat: THREE.Material) => { ... })
```

On the Julia side, calling `@remote(b, sphere(c, r, mat))` encodes the
operation index and arguments into a binary frame, sends it, and decodes the
returned `Id` (an `Int32` object reference).

---

## Use Case 1: Interactive Mode (Single Client)

In interactive mode, a user works in the Julia REPL and sends geometry commands
that appear in a single browser window.

### Setup

```julia
using KhepriThreejs
```

Loading the package registers the `"threejs"` backend initializer and the HTTP
routes. The server starts lazily — it is created the first time a shape
function triggers a backend connection.

### Workflow

```julia
# The first shape command triggers server startup and waits for a browser
# connection. Open http://127.0.0.1:12346 in a browser.
delete_all_shapes()

# Create geometry — each call encodes a binary command and sends it
# over the WebSocket to the browser, which renders it immediately.
sphere(xyz(0, 0, 0), 5)
box(xyz(10, 0, 0), 3, 3, 3)
cylinder(xyz(-5, 0, 0), 2, 2, 8)

# Materials use Three.js material constructors via @remote calls.
red = material(base_color=rgba(1, 0, 0, 1))
sphere(xyz(0, 10, 0), 3, material=red)

# Set camera
set_view(xyz(30, 30, 20), xyz(0, 0, 0), 50, 24)

# Use batch processing for many objects (suspends rendering during creation)
with(batch_processing, true) do
  for i in 1:500
    sphere(xyz(rand()*50, rand()*50, rand()*10), 0.5)
  end
end
```

### How It Works Internally

```
REPL                          Julia                         Browser
─────                         ─────                         ───────
sphere(xyz(0,0,0), 5)
  │
  ├─► b_sphere(b::THR, c, r, mat)
  │     │
  │     ├─► @remote(b, sphere(c, r, mat))
  │     │     │
  │     │     ├─► encode operation index + args
  │     │     ├─► WebSocket.send(binary frame)
  │     │     │                                    ──► decode operation index
  │     │     │                                    ──► decode args (Point3d, Float32, MatId)
  │     │     │                                    ──► new THREE.Mesh(SphereGeometry(r), mat)
  │     │     │                                    ──► scene.add(mesh)
  │     │     │                                    ──► encode return Id
  │     │     ◄─── WebSocket response ◄────────────────
  │     │     │
  │     │     └─► decode Id (Int32)
  │     └─► return THRRef wrapping the Id
  └─► Shape proxy stored in Julia
```

Each `@remote` call is synchronous from Julia's perspective: it blocks until
the browser executes the operation and returns the result. The latency is
typically sub-millisecond on localhost.

### Interactive GUI

The browser can send events back to Julia through registered handlers. This
enables interactive parameter exploration:

```julia
gui = gui_create("Controls")
folder = gui_add_folder(gui, "Parameters", false)

gui_add_slider(folder, "Radius", 0.1, 10.0, 0.1, 3.0, params -> begin
  # Called when the user moves the slider in the browser.
  # The callback runs in a Julia task with this backend as current_backend.
  r = params["p0"]
  delete_all_shapes()
  sphere(xyz(0, 0, 0), r)
end)

gui_add_button(folder, "Reset", () -> begin
  delete_all_shapes()
  sphere(xyz(0, 0, 0), 3.0)
end)
```

**Handler flow:**
1. Julia calls `register_handler(b, name, handler)`, which stores the handler
   function and returns its index.
2. The index is sent to the browser as part of the GUI creation command.
3. When the user interacts with the GUI widget, the browser sends a request
   with that handler index and the current value.
4. Julia's `process_requests` loop (running in a spawned task) decodes the
   request and calls the handler.
5. The handler executes with `current_backends` set to `(b,)`, so shape
   commands go to the correct client.
6. Julia responds with success/error; the browser unlocks for the next request.

**Important constraint:** The browser enforces one pending request at a time
(`requestStillWaitingResponse` flag). If a handler takes too long, subsequent
GUI interactions are dropped. Handlers should return quickly.

---

## Use Case 2: Multi-Client Mode (Multiple Browsers)

In multi-client mode, multiple browser clients connect to the same Julia
server. Each client runs independently in its own Julia task with isolated
state. The typical pattern is: each browser sends interaction requests, and the
Julia server responds by creating geometry in that specific client's scene.

### Setup

```julia
using KhepriThreejs

# Define what happens when each client connects.
# main_callback is a GlobalParameter — set it BEFORE any client connects.
main_callback(b -> begin
  # This runs once per client, in a dedicated Julia task.
  # 'b' is the THR backend bound to this specific browser tab.
  # current_backend() is already set to b.

  # Build an initial scene for this client
  delete_all_shapes()
  dark_grid_helper()
  set_view(xyz(30, 30, 20), xyz(0, 0, 0), 50, 24)

  # Create GUI controls — interactions from THIS client call handlers
  # that run in THIS client's task, sending geometry to THIS client.
  gui = gui_create("Design")

  gui_add_slider(gui, "Height", 1.0, 20.0, 0.5, 5.0, params -> begin
    h = params["p0"]
    delete_all_shapes()
    box(xyz(0, 0, 0), 5, 5, h)
  end)

  gui_add_button(gui, "Add Sphere", () -> begin
    sphere(xyz(rand()*20, rand()*20, rand()*10), 1.0)
  end)

  # Start processing GUI interaction requests from this client.
  # This call blocks (runs the request loop), keeping the task alive.
  start_processing_requests(b)
end)
```

Then open `http://127.0.0.1:12346` in multiple browser tabs or on multiple
machines (if the host is changed from localhost). Each tab gets its own
independent scene and GUI.

### How It Works Internally

```
Browser A connects                        Browser B connects
       │                                         │
       ▼                                         ▼
  WebSocket upgrade to /threejs             WebSocket upgrade to /threejs
       │                                         │
       ▼                                         ▼
  init_func(ws_a) → THR("Threejs", ws_a)   init_func(ws_b) → THR("Threejs", ws_b)
       │                                         │
       ▼                                         ▼
  Task A spawned                            Task B spawned
  ┌─────────────────────────┐               ┌─────────────────────────┐
  │ task_local_storage:     │               │ task_local_storage:     │
  │   current_backends=(a,) │               │   current_backends=(b,) │
  │   current_cs=world_cs   │               │   current_cs=world_cs   │
  │                         │               │                         │
  │ main_callback()(a)      │               │ main_callback()(b)      │
  │   → builds scene for A  │               │   → builds scene for B  │
  │   → registers handlers  │               │   → registers handlers  │
  │                         │               │                         │
  │ process_requests(a)     │               │ process_requests(b)     │
  │   → loops forever:      │               │   → loops forever:      │
  │     receive request     │               │     receive request     │
  │     call handler        │               │     call handler        │
  │     handler creates     │               │     handler creates     │
  │     shapes on A only    │               │     shapes on B only    │
  └─────────────────────────┘               └─────────────────────────┘
```

### Task Isolation

Each client connection runs in a separate Julia task (`Threads.@spawn`). The
task inherits a copy of the parent's task-local storage, then overrides
`current_backends` to point only to its own backend. This means:

- **Refs are per-client:** Each `THR` instance has its own `refs::References`,
  so object IDs from one client don't collide with another.
- **Handlers are per-client:** Each backend's `handlers::Vector{Function}`
  stores only callbacks registered for that connection.
- **Parameters are per-task:** `current_cs`, `current_layer`, and
  user-defined `Parameter` values are isolated via `task_local_storage()`.
- **No locking needed:** Clients run concurrently without shared mutable state.

### Practical Example: Collaborative Viewer

```julia
using KhepriThreejs

# Shared model data (read-only from client tasks)
const building_floors = 5
const floor_height = 3.0

main_callback(b -> begin
  delete_all_shapes()
  set_view(xyz(40, 40, 30), xyz(0, 0, 0), 50, 24)

  # Each client sees the same base building
  for i in 0:building_floors-1
    with(current_cs, translated_cs(current_cs(), 0, 0, i * floor_height)) do
      box(xyz(0, 0, 0), 20, 15, floor_height - 0.3)
    end
  end

  gui = gui_create("Explore")

  # Each client can independently toggle floor visibility, add annotations, etc.
  gui_add_slider(gui, "Camera Height", 1.0, 30.0, 1.0, 15.0, params -> begin
    h = params["p0"]
    set_view(xyz(40, 40, h), xyz(0, 0, h/2), 50, 24)
  end)

  start_processing_requests(b)
end)
```

### Differences from Interactive Mode

| Aspect | Interactive Mode | Multi-Client Mode |
|--------|-----------------|-------------------|
| Client count | One browser tab | Many simultaneous tabs/machines |
| Who drives geometry | Julia REPL | Browser interactions via `main_callback` |
| `main_callback` | Not used (default no-op) | Required — entry point per client |
| `start_processing_requests` | Not needed (REPL is the driver) | Required — runs the event loop |
| Backend lifetime | Until REPL exits or tab closes | Until tab closes (task exits) |
| State isolation | Single global state | Per-task via `task_local_storage()` |

### Hybrid Mode

Both modes can coexist. If `main_callback` is set and a user also types
commands in the REPL, the REPL commands go to whichever backend is set as
`current_backend()` in the REPL's task (typically the first client that
connected, via `add_global_backend`). Meanwhile, each client's own task
continues processing its GUI requests independently.

---

## Materials

Materials are created via `@remote` calls to Three.js material constructors.
KhepriThreejs provides helper functions for common material types:

| Helper | Three.js class | Use case |
|--------|---------------|----------|
| `threejs_material(b, color)` | `MeshLambertMaterial` | Basic diffuse surfaces |
| `threejs_metal_material(b, roughness, color)` | `MeshPhysicalMaterial` | Metals |
| `threejs_glass_material(b, opacity, color)` | `MeshPhysicalMaterial` | Transparent glass |
| `threejs_plaster_material(b)` | `MeshPhysicalMaterial` | Architectural plaster |
| `threejs_line_material(b, color)` | `LineBasicMaterial` | Lines and curves |
| `threejs_glTF_material(b, path)` | Loaded from glTF file | PBR materials from files |

Default material mappings (glass, metal, wood, concrete, plaster, grass) are
set during `__init__()`. Users should use Khepri's `material` system
for portable code:

```julia
mat = material(base_color=rgba(0.8, 0.2, 0.1, 1.0))
sphere(xyz(0, 0, 0), 5, material=mat)
```

### glTF Materials

PBR materials can be loaded from glTF files stored in the resources folder:

```julia
my_floor = material("MyFloor", THR => glTF_material("laminate_floor_02"))
box(xyz(0, 0, 0), 10, 10, 0.1, material=my_floor)
```

The material files are served by the HTTP handler from
`resources/materials/<name>/<name>_4k.gltf`.

---

## Limitations

- **No CSG/Boolean operations:** `has_boolean_ops(::Type{THR})` returns
  `HasBooleanOps{false}()`. Boolean operations fall back to KhepriBase's
  mesh-based emulation, which produces triangulated approximations.
- **Single pending request:** The browser can only have one outstanding request
  to Julia at a time. GUI handlers must return quickly.
- **Line width:** WebGL ignores `linewidth` on most platforms due to OpenGL
  Core Profile limitations — lines are always 1 pixel wide.
- **Layer deletion:** Per-layer shape deletion is not supported; use
  `delete_all_shapes()` instead.
