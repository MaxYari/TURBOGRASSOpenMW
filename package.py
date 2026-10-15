# Builds the release archives into dist/:
#   TURBOGRASS-<version>.zip             for OpenMW's own shaders
#   TURBOGRASS-<version>-Wareya-PBR.zip  for Wareya's PBR shaders for OpenMW 0.51, and for Liam's Kitbashed
#                                        PBR and Complete Water Shaders PBR, which ship Wareya's groundcover.vert
#   TURBOGRASS-<version>-Rafael-PBR.zip  for Rafael's Enhanced PBR Lighting 2.3, OpenMW 0.51 folder
# Each holds one root folder with README.md, LICENSE, AUTHORS.md and shaders/, like Wareya's releases.
# The PBR shaders are generated from shaders/compatibility/groundcover.vert, which stays the only source:
# each variant swaps the parts that must match its pack's groundcover.frag and lighting library.
#
# Usage: python3 package.py [version]
# The version defaults to the one in the shader's "// TURBOGRASS <version>," line; a given one replaces it
# there in the built shaders, as well as naming the archives.

import pathlib
import re
import shutil
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent
SHADER = "shaders/compatibility/groundcover.vert"
DOCS = ["README.md", "LICENSE", "AUTHORS.md"]

STOCK_LIGHTING_DEFINE = "#define PER_PIXEL_LIGHTING @normalMap\n"

STOCK_VARYINGS = """\
// Other shaders respect forcePPL, but legacy groundcover mods were designed to work with vertex lighting.
// They may do not look as intended with per-pixel lighting, so ignore this setting for now.
#define PER_PIXEL_LIGHTING @normalMap

varying float euclideanDepth;
varying float linearDepth;

#if PER_PIXEL_LIGHTING
varying vec3 passViewPos;
#else
centroid varying vec3 passLighting;
centroid varying vec3 shadowDiffuseLighting;
#endif
"""

STOCK_INCLUDES = """\
#include "shadows_vertex.glsl"
#include "compatibility/normals.glsl"
#include "lib/light/lighting.glsl"
#include "lib/view/depth.glsl"

uniform float osg_SimulationTime;
uniform mat4 osg_ViewMatrixInverse;
uniform mat4 osg_ViewMatrix;
uniform float windSpeed;
"""

STOCK_LIGHTING_OUTPUT = """\
#if PER_PIXEL_LIGHTING
    passViewPos = viewPos.xyz;
#else
"""

VARIANTS = [
    ("", []),
    # Wareya's groundcover.frag needs per-pixel lighting, so the vertex shader has to force it too
    ("-Wareya-PBR", [
        (STOCK_LIGHTING_DEFINE,
         "//#define PER_PIXEL_LIGHTING @normalMap\n"
         "// PBR requires per-pixel lighting to work.\n"
         "#define PER_PIXEL_LIGHTING 1\n"),
    ]),
    # Rafael's groundcover.frag also reads passViewPos always and a localHeight varying, and his lighting.glsl
    # already includes normals.glsl and declares the osg_* uniforms
    ("-Rafael-PBR", [
        (STOCK_VARYINGS, """\
#define PER_PIXEL_LIGHTING 1

varying float euclideanDepth;
varying float linearDepth;
varying vec3 passViewPos;

#if !PER_PIXEL_LIGHTING
centroid varying vec3 passLighting;
centroid varying vec3 shadowDiffuseLighting;
#endif
varying float localHeight;
"""),
        (STOCK_INCLUDES, """\
#include "shadows_vertex.glsl"
#include "lib/light/lighting.glsl"
#include "lib/view/depth.glsl"

uniform float windSpeed;
"""),
        (STOCK_LIGHTING_OUTPUT, """\
    localHeight = gl_Vertex.z;
    passViewPos = viewPos.xyz;
#if !PER_PIXEL_LIGHTING
"""),
    ]),
]


def make_variant(source, replacements):
    for old, new in replacements:
        if source.count(old) != 1:
            raise SystemExit("Expected exactly one match in " + SHADER + " for:\n" + old)
        source = source.replace(old, new)
    return source


def build(name, shader_text, dist):
    folder = dist / name
    (folder / SHADER).parent.mkdir(parents=True)
    for doc in DOCS:
        shutil.copy2(ROOT / doc, folder / doc)
    (folder / SHADER).write_text(shader_text)
    archive = dist / (name + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(folder.rglob("*")):
            z.write(f, f.relative_to(dist).as_posix())
    shutil.rmtree(folder)
    print(archive)


def main():
    source = (ROOT / SHADER).read_text()
    line = re.search(r"// TURBOGRASS (\S+),", source)
    version = sys.argv[1] if len(sys.argv) > 1 else line.group(1)
    # A given version is the one going on Nexus, so the shipped shaders say it too
    source = source[:line.start(1)] + version + source[line.end(1):]
    variants = [(suffix, make_variant(source, replacements)) for suffix, replacements in VARIANTS]
    dist = ROOT / "dist"
    if dist.exists():
        shutil.rmtree(dist)
    dist.mkdir()
    for suffix, text in variants:
        build("TURBOGRASS-" + version + suffix, text, dist)


if __name__ == "__main__":
    main()
