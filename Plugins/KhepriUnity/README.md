# Khepri-Unity Backend
 Unity visualization backend for the AD tool Khepri

## Command-line connection mode

KhepriUnity defaults to client mode, where Unity connects to the Khepri socket
server:

```text
-khepriMode=client -serverIP=127.0.0.1 -port=12345
```

To run Unity as the server that Khepri connects to:

```text
-khepriMode=server -serverIP=127.0.0.1 -port=11002
```

`-client` and `-server` are accepted as shorthand flags. `-port=` overrides
the mode-specific default port.
