# KhepriThreejs

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://aptmcl.github.io/KhepriThreejs.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://aptmcl.github.io/KhepriThreejs.jl/dev/)
[![Build Status](https://github.com/aptmcl/KhepriThreejs.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/aptmcl/KhepriThreejs.jl/actions/
workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/aptmcl/KhepriThreejs.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/aptmcl/KhepriThreejs.jl)

A Julia package for 3D visualization using Three.js through WebSocket communication.

## Overview

KhepriThreejs provides a bridge between Julia and Three.js for real-time 3D visualization. It allows you to create, manipulate, and display 3D objects in a web browser using Julia code.

## Security Notice

⚠️ **Important**: This package binds to `127.0.0.1` (localhost) by default for security. This ensures the visualization server is only accessible from your local machine. Do not change this binding unless you understand the security implications.

## Installation

```julia
using Pkg
Pkg.add("KhepriThreejs")
```

## Building the JavaScript Components

Before using KhepriThreejs, you need to build the JavaScript components:

1. Navigate to the Threejs directory:
   ```bash
   cd Threejs
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Build the JavaScript bundle:
   ```bash
   npm run build
   ```

This will create the necessary JavaScript files in the `Threejs/dist/` directory.

## Quick Start

```julia
using KhepriThreejs

# Create a simple sphere
sphere(xyz(0, 0, 0), 1)

# Create a box
box(xyz(2, 0, 0), 1, 1, 1)

# Set the view
set_view(xyz(5, 5, 5), xyz(0, 0, 0), 50, 24)
```

## Usage

After starting the visualization, open your browser to:
```
http://127.0.0.1:8900
```

### Basic Example

```julia
using KhepriThreejs

# Create some basic shapes
sphere(xyz(0, 0, 0), 1)
box(xyz(2, 0, 0), 1, 1, 1)
cylinder(xyz(-2, 0, 0), 0.5, 0.5, 2)

# Add a grid for reference
dark_grid_helper()

# Set camera view
set_view(xyz(5, 5, 5), xyz(0, 0, 0), 50, 24)
```

### Interactive GUI Example

```julia
using KhepriThreejs

# Create GUI controls
gui = gui_create("Controls", 1)

# Add a slider for object size
gui_add_slider(gui, "Size", 0.1, 5.0, 0.1, 1.0, (params) -> begin
    # This callback will be called when the slider changes
    println("Size changed to: ", params["p0"])
end)

# Add a button
gui_add_button(gui, "Reset", () -> begin
    delete_all_refs()
    sphere(xyz(0, 0, 0), 1)
end)
```

## Features

- **Real-time 3D visualization** using Three.js
- **WebSocket communication** for fast data transfer
- **Interactive controls** with mouse and keyboard
- **Material support** including physical, standard, and basic materials
- **GUI controls** for interactive parameter adjustment
- **Grid helpers** for better spatial orientation
- **Memory-efficient object management**

## Performance Tips

1. **Use batch processing** when creating many objects:
   ```julia
   start_batch_processing()
   for i in 1:1000
       sphere(xyz(rand(), rand(), rand()), 0.1)
   end
   stop_batch_processing()
   ```

2. **Reuse materials** instead of creating new ones for each object

3. **Delete unused objects** to free memory

## Troubleshooting

### Common Issues

1. **"Connection refused"**: Make sure no other application is using port 8900
2. **Browser not loading**: Check that the server is running and accessible at `127.0.0.1:8900`
3. **JavaScript errors**: Make sure you've built the JavaScript components with `npm run build`
4. **Performance issues**: Use batch processing for large numbers of objects

### Debug Mode

Enable debug logging:

```julia
using Logging
global_logger(ConsoleLogger(stderr, Logging.Debug))
```

## Development

### Running Tests

```julia
using Pkg
Pkg.test("KhepriThreejs")
```

### Building for Development

For development with automatic rebuilding:

```bash
cd Threejs
npm run build -- --watch
```

## Architecture

KhepriThreejs uses a client-server architecture:

- **Julia Server**: Handles 3D object creation and manipulation
- **JavaScript Client**: Renders the 3D scene using Three.js
- **WebSocket Communication**: Binary protocol for efficient data transfer

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This package is licensed under the MIT License. See the LICENSE file for details.

## Dependencies

- **KhepriBase**: Core Khepri functionality
- **HTTP**: WebSocket server implementation
- **Sockets**: Network communication
- **Three.js**: 3D rendering engine (JavaScript)
