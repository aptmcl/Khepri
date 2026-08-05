#!/usr/bin/env python3
"""Fail when a vendored plugin binary is older than the sources it was built from.

The plugin supply chain vendors built binaries (DLL/.rhp/.gha bundles under
Julia/*/Plugin and inside Plugins/) because users install those directly and
CI cannot build the SDK-bound projects (AutoCAD/Revit/Rhino/Grasshopper
references resolve against locally installed applications). That makes
"source fixed, binary never re-vendored" invisible — it shipped stale
binaries at least three times in 2026-06/07 (Rhino missing the 07-30
batching fix, the AutoCAD deploy bundle refreshed on the wrong side,
Grasshopper's .gha predating the 06-22 P0 fixes).

The check is git topology, NOT file dates: checkout does not preserve
mtimes, and commit dates are not monotonic under rebase/cherry-pick. A
binary B with source set S is fresh iff no commit after the last commit
touching B touches S:

    bin_commit = git rev-list -1 HEAD -- B
    stale      = git rev-list --count {bin_commit}..HEAD -- S    # > 0 => stale

A same-commit source+binary update is fresh by construction. Requires the
full history (actions/checkout with fetch-depth: 0).
"""

import subprocess
import sys

# Binary -> the source pathspecs it is built from. KhepriBase.dll copies are
# stale when the SHARED sources change; the app-plugin binaries are stale when
# their OWN project sources change (KhepriBase is a separate assembly, not
# merged, so base-source changes do not stale the app DLL itself — the base
# DLL beside it catches those). Bundle output dirs that live INSIDE a project
# dir are excluded from that project's source set.
# sign.ps1 (Authenticode post-build signing) and the .sln shape the built
# bytes without living under the project dir, so each source set names them.
KHEPRI_BASE_SRC = [
    "Plugins/KhepriBase/KhepriBase",
    "Plugins/KhepriBase/sign.ps1",
    "Plugins/KhepriBase/KhepriBase.sln",
    ":(exclude)Plugins/KhepriBase/KhepriBase/bin",
]
AUTOCAD_SRC = [
    "Plugins/KhepriAutoCAD/KhepriAutoCAD",
    "Plugins/KhepriAutoCAD/sign.ps1",
    "Plugins/KhepriAutoCAD/KhepriAutoCAD.sln",
    ":(exclude)Plugins/KhepriAutoCAD/KhepriAutoCAD/KhepriAutoCAD.bundle",
    ":(exclude)Plugins/KhepriAutoCAD/KhepriAutoCAD/bin",
]
REVIT_SRC = [
    "Plugins/KhepriRevit/KhepriRevit",
    "Plugins/KhepriRevit/sign.ps1",
    "Plugins/KhepriRevit/KhepriRevit.sln",
    ":(exclude)Plugins/KhepriRevit/KhepriRevit/KhepriRevit.bundle",
    ":(exclude)Plugins/KhepriRevit/KhepriRevit/bin",
]
RHINO_SRC = [
    "Plugins/KhepriRhinoceros/KhepriRhinoceros",
    "Plugins/KhepriRhinoceros/KhepriRhinoceros.sln",
    ":(exclude)Plugins/KhepriRhinoceros/KhepriRhinoceros/bin",
]
GRASSHOPPER_SRC = [
    "Plugins/KhepriGrasshopper/KhepriGrasshopper",
    "Plugins/KhepriGrasshopper/KhepriGrasshopper.sln",
    ":(exclude)Plugins/KhepriGrasshopper/KhepriGrasshopper/bin",
]
# The bundle MANIFESTS are hand-vendored copies of the project-side bundle
# originals; update_plugin() installs them into the host application, so a
# manifest edited only on the Plugins side is exactly the refresh-the-wrong-
# copy incident again, in .xml form.
AUTOCAD_MANIFEST_SRC = ["Plugins/KhepriAutoCAD/KhepriAutoCAD/KhepriAutoCAD.bundle/PackageContents.xml"]
REVIT_MANIFEST_SRC = ["Plugins/KhepriRevit/KhepriRevit/KhepriRevit.bundle/PackageContents.xml"]
REVIT_ADDIN_SRC = ["Plugins/KhepriRevit/KhepriRevit/KhepriRevit.bundle/Contents/KhepriRevit.addin"]

CHECKS = [
    # (vendored binary, source pathspecs)
    ("Julia/KhepriAutoCAD/Plugin/KhepriAutoCAD.bundle/Contents/KhepriAutoCAD.dll", AUTOCAD_SRC),
    ("Julia/KhepriAutoCAD/Plugin/KhepriAutoCAD.bundle/Contents/KhepriBase.dll", KHEPRI_BASE_SRC),
    ("Julia/KhepriAutoCAD/Plugin/KhepriAutoCAD.bundle/PackageContents.xml", AUTOCAD_MANIFEST_SRC),
    ("Plugins/KhepriAutoCAD/KhepriAutoCAD/KhepriAutoCAD.bundle/Contents/KhepriAutoCAD.dll", AUTOCAD_SRC),
    ("Plugins/KhepriAutoCAD/KhepriAutoCAD/KhepriAutoCAD.bundle/Contents/KhepriBase.dll", KHEPRI_BASE_SRC),
    ("Julia/KhepriRevit/Plugin/KhepriRevit.bundle/Contents/KhepriRevit.dll", REVIT_SRC),
    ("Julia/KhepriRevit/Plugin/KhepriRevit.bundle/Contents/KhepriBase.dll", KHEPRI_BASE_SRC),
    ("Julia/KhepriRevit/Plugin/KhepriRevit.bundle/PackageContents.xml", REVIT_MANIFEST_SRC),
    ("Julia/KhepriRevit/Plugin/KhepriRevit.bundle/Contents/KhepriRevit.addin", REVIT_ADDIN_SRC),
    ("Julia/KhepriRhino/Plugin/KhepriRhinoceros.rhp", RHINO_SRC),
    ("Julia/KhepriRhino/Plugin/KhepriBase.dll", KHEPRI_BASE_SRC),
    ("Julia/KhepriGrasshopper/Plugin/KhepriGrasshopper.gha", GRASSHOPPER_SRC),
    ("Plugins/KhepriUnity/Assets/Khepri/Plugins/KhepriBase.dll", KHEPRI_BASE_SRC),
]


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout.strip()


def main():
    failures = []
    for binary, sources in CHECKS:
        bin_commit = git("rev-list", "-1", "HEAD", "--", binary)
        if not bin_commit:
            failures.append(f"{binary}: not tracked by git (never committed?)")
            continue
        stale = int(git("rev-list", "--count", f"{bin_commit}..HEAD", "--", *sources))
        if stale:
            newest = git("log", "-1", "--format=%h %ad %s", "--date=short", "--", *sources)
            print(f"::error file={binary}::stale vendored binary: {stale} source commit(s) "
                  f"after its last update (newest: {newest}). Rebuild the plugin, run the "
                  f"backend's upgrade_plugin(), and commit binary + sources together.")
            failures.append(binary)
        else:
            print(f"ok: {binary} (last vendored in {bin_commit[:10]})")
    if failures:
        print(f"\n{len(failures)} stale vendored binar{'y' if len(failures) == 1 else 'ies'}.")
        sys.exit(1)
    print("\nAll vendored plugin binaries are at least as new as their sources.")


if __name__ == "__main__":
    main()
