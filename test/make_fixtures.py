"""Builds the test fixtures: a stand-in client jar and Mojang-shaped metadata.

The jar holds a few made-up assets and a class file, no Mojang content, so
the fixtures can live in the repository. Run from the repository root.
"""
import hashlib, json, os, zipfile, random

random.seed(26)
root = "test/data"
vdir = f"{root}/versions/26.3"
os.makedirs(vdir, exist_ok=True)

jar_path = f"{vdir}/26.3.jar"
with zipfile.ZipFile(jar_path, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("META-INF/MANIFEST.MF", "Manifest-Version: 1.0\n")
    z.writestr("net/minecraft/Main.class", bytes(random.getrandbits(8) for _ in range(4000)))
    z.writestr("assets/minecraft/textures/block/", b"")
    z.writestr("assets/minecraft/textures/block/stone.png", bytes(random.getrandbits(8) for _ in range(900)))
    z.writestr("assets/minecraft/models/block/stone.json", json.dumps({"parent": "block/cube_all", "textures": {"all": "block/stone"}}))
    z.writestr("assets/minecraft/blockstates/stone.json", json.dumps({"variants": {"": {"model": "block/stone"}}}))
    z.writestr("assets/minecraft/lang/en_us.json", json.dumps({"block.minecraft.stone": "Stone"}))
    z.writestr("assets/minecraft/sounds.json", "{}")
    z.writestr("data/minecraft/recipe/stone.json", "{}")
jar = open(jar_path, "rb").read()
jar_sha1 = hashlib.sha1(jar).hexdigest()

def version(url):
    return {
        "id": "26.3",
        "type": "release",
        "mainClass": "net.minecraft.client.main.Main",
        "javaVersion": {"component": "java-runtime-epsilon", "majorVersion": 25},
        "assetIndex": {"id": "29", "sha1": "0" * 40, "size": 1, "totalSize": 1, "url": "http://127.0.0.1:8765/29.json"},
        "downloads": {"client": {"sha1": jar_sha1, "size": len(jar), "url": url}},
        "libraries": [{"name": "com.example:lib:1.0"}],
    }

json.dump(version("https://piston-data.mojang.com/v1/objects/x/client.jar"), open(f"{vdir}/26.3.json", "w"), indent=2)
json.dump(version("http://127.0.0.1:8765/versions/26.3/26.3.jar"), open(f"{vdir}/26.3-local.json", "w"), indent=2)
meta_sha1 = hashlib.sha1(open(f"{vdir}/26.3.json", "rb").read()).hexdigest()

manifest = {
    "latest": {"release": "26.3", "snapshot": "26w45a"},
    "versions": [
        {"id": "26.3", "type": "release", "url": "https://piston-meta.mojang.com/v1/packages/x/26.3.json",
         "time": "2026-10-20T10:00:00+00:00", "releaseTime": "2026-10-20T10:00:00+00:00", "sha1": meta_sha1, "complianceLevel": 1},
        {"id": "26w45a", "type": "snapshot", "url": "https://piston-meta.mojang.com/v1/packages/y/26w45a.json",
         "time": "2026-11-04T10:00:00+00:00", "releaseTime": "2026-11-04T10:00:00+00:00", "sha1": "1" * 40, "complianceLevel": 1},
        {"id": "1.21.10", "type": "release", "url": "https://piston-meta.mojang.com/v1/packages/z/1.21.10.json",
         "time": "2025-10-07T10:00:00+00:00", "releaseTime": "2025-10-07T10:00:00+00:00", "sha1": "2" * 40, "complianceLevel": 1},
    ],
}
json.dump(manifest, open(f"{root}/version_manifest_v2.json", "w"))
print("fixtures written, jar sha1", jar_sha1)
