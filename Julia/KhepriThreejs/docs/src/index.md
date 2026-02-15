```@meta
CurrentModule = KhepriThreejs
```

# KhepriThreejs

Documentation for [KhepriThreejs](https://github.com/aptmcl/KhepriThreejs.jl).

```@index
```

```@autodocs
Modules = [KhepriThreejs]
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
