# Changelog

All notable changes to KhepriThreejs will be documented in this file.

## [1.0.1] - 2024-01-XX

### Security
- **CRITICAL**: Changed default binding from `0.0.0.0` to `127.0.0.1` for security
- Added comprehensive security documentation in `SECURITY.md`
- Added input validation for WebSocket messages
- Added error handling for WebSocket connections

### Memory Management
- **FIXED**: Replaced array-based mesh storage with Map to prevent memory leaks
- **FIXED**: Replaced array-based sprite storage with Map for better memory management
- **FIXED**: Proper cleanup of 3D objects and resources
- **FIXED**: Automatic disposal of geometries and materials
- **FIXED**: Prevention of undefined array holes that caused raycasting errors

### Error Handling
- **IMPROVED**: Added comprehensive error handling in WebSocket message processing
- **IMPROVED**: Added validation for message size and operation indices
- **IMPROVED**: Added proper error responses for failed operations
- **FIXED**: Improved error handling in GUI change callbacks
- **FIXED**: Added proper error handling for incomplete type implementations

### Code Quality
- **FIXED**: Removed HACK comments and replaced with proper TODO comments
- **IMPROVED**: Fixed incomplete implementations in PrimitiveType and CompositeType
- **IMPROVED**: Added proper error throwing for unimplemented features
- **CLEANED**: Removed commented-out code and improved code organization

### Configuration
- **IMPROVED**: Fixed webpack configuration to disable watch mode in production
- **ADDED**: Separate development webpack configuration
- **ADDED**: New npm scripts for development builds

### Documentation
- **ADDED**: Comprehensive API documentation
- **ADDED**: Security policy and best practices
- **ADDED**: Performance tips and troubleshooting guide
- **IMPROVED**: Updated README with proper build instructions
- **ADDED**: Development setup instructions

### Testing
- **ADDED**: Comprehensive test suite covering basic functionality
- **ADDED**: Tests for backend operations and material creation
- **ADDED**: Tests for GUI functions and grid helpers
- **ADDED**: Error handling tests

### Performance
- **IMPROVED**: Better memory management for large scenes
- **IMPROVED**: More efficient object storage and retrieval
- **ADDED**: Batch processing recommendations

## [1.0.0] - Initial Release

### Features
- Basic 3D visualization using Three.js
- WebSocket communication between Julia and JavaScript
- Support for basic geometric shapes (sphere, box, cylinder, torus)
- Material system with various material types
- Interactive GUI controls
- Grid helpers for spatial orientation
- Camera controls and view management

### Known Issues
- Memory leaks in object management
- Security vulnerabilities with network binding
- Incomplete error handling
- Limited input validation
- Performance issues with large scenes
