# Builds the release archives into dist/:
#   TURBOGRASS-<version>.zip             for OpenMW's own shaders
#   TURBOGRASS-<version>-Wareya-PBR.zip  for Wareya's PBR shaders for OpenMW 0.51
# Each holds one root folder with README.md, LICENSE, AUTHORS.md and shaders/, like Wareya's releases.
# The PBR shader is generated from shaders/compatibility/groundcover.vert, which stays the only source.
#
# Usage: python3 package.py

import pathlib
import re
import shutil
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent
SHADER = "shaders/compatibility/groundcover.vert"
DOCS = ["README.md", "LICENSE", "AUTHORS.md"]

# Wareya's PBR groundcover.frag needs per-pixel lighting, so its groundcover.vert has to force it too
VANILLA_LIGHTING = "#define PER_PIXEL_LIGHTING @normalMap\n"
PBR_LIGHTING = ("//#define PER_PIXEL_LIGHTING @normalMap\n"
                "// PBR requires per-pixel lighting to work.\n"
                "#define PER_PIXEL_LIGHTING 1\n")


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
    vanilla = (ROOT / SHADER).read_text()
    version = re.search(r"// TURBOGRASS (\S+),", vanilla).group(1)
    if vanilla.count(VANILLA_LIGHTING) != 1:
        raise SystemExit("PER_PIXEL_LIGHTING define not found exactly once in " + SHADER)
    dist = ROOT / "dist"
    if dist.exists():
        shutil.rmtree(dist)
    dist.mkdir()
    build("TURBOGRASS-" + version, vanilla, dist)
    build("TURBOGRASS-" + version + "-Wareya-PBR", vanilla.replace(VANILLA_LIGHTING, PBR_LIGHTING), dist)


if __name__ == "__main__":
    main()
