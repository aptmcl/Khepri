# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Security Considerations

### Network Binding

KhepriThreejs binds to `127.0.0.1` (localhost) by default for security reasons. This ensures that:

1. The visualization server is only accessible from your local machine
2. External network connections cannot access the server
3. No authentication is required since it's local-only

### Important Security Notes

⚠️ **Do not change the binding to `0.0.0.0`** unless you:
- Understand the security implications
- Have implemented proper authentication
- Are running in a controlled environment
- Have firewall rules in place

### WebSocket Communication

The package uses WebSocket communication for real-time 3D visualization:

- **Protocol**: Binary WebSocket protocol for efficiency
- **Authentication**: None (local-only access)
- **Input Validation**: Basic validation implemented
- **Error Handling**: Comprehensive error handling to prevent crashes

### Input Validation

The following input validation is implemented:

- Message size validation
- Operation index validation
- Type checking for function arguments
- Error response handling

### Memory Management

Recent improvements include:

- Proper cleanup of 3D objects and resources
- Map-based storage to avoid memory leaks
- Automatic disposal of geometries and materials
- Prevention of undefined array holes

## Reporting Security Issues

If you discover a security vulnerability, please:

1. **Do not** create a public issue
2. Email the maintainer directly
3. Provide detailed information about the vulnerability
4. Include steps to reproduce the issue

## Security Best Practices

When using KhepriThreejs:

1. **Keep the package updated** to the latest version
2. **Use localhost binding** (default behavior)
3. **Don't expose the port** to external networks
4. **Monitor for unusual activity** if running in production
5. **Use batch processing** for large numbers of objects to prevent memory issues

## Known Issues

- No authentication mechanism (by design for local-only access)
- Limited input sanitization for GUI parameters
- WebSocket connection errors may not be handled gracefully in all cases

## Future Security Improvements

Planned security enhancements:

1. Optional authentication for remote access
2. Enhanced input validation
3. Rate limiting for WebSocket messages
4. Secure WebSocket (WSS) support
5. Audit logging for security events
