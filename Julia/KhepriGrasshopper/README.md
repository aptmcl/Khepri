# KhepriGrasshopper

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://aptmcl.github.io/Khepri/KhepriGrasshopper/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://aptmcl.github.io/Khepri/KhepriGrasshopper/dev)
[![Build Status](https://github.com/aptmcl/Khepri/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/aptmcl/Khepri/actions/workflows/ci.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/aptmcl/Khepri/branch/main/graph/badge.svg?flag=KhepriGrasshopper)](https://codecov.io/gh/aptmcl/Khepri)

## Plugin installation

Installing the Julia package no longer copies the Grasshopper plugin as a
`Pkg.build` side effect (that build step crashed on any machine without
`APPDATA`). On Windows, run once after installing or updating the package:

```julia
using KhepriGrasshopper
KhepriGrasshopper.update_plugin()
```

This copies `KhepriGrasshopper.gha` into `%APPDATA%\Grasshopper\Libraries`;
restart Rhino/Grasshopper afterwards.
