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


# --- a tiny world: one level.dat and two region files -----------------------
# No Mojang data is involved; the chunks are written here from scratch in the
# 1.18+ shape (sections with a block_states palette) so the world reader has
# something with a known answer to parse.
import gzip, struct, zlib


def nbt_tag(kind, name, payload):
    n = name.encode()
    return bytes([kind]) + struct.pack(">H", len(n)) + n + payload


def nbt_str(s):
    b = s.encode()
    return struct.pack(">H", len(b)) + b


def nbt_compound(members):
    return b"".join(nbt_tag(k, n, p) for n, (k, p) in members.items()) + b"\x00"


def nbt_list(kind, items):
    return bytes([kind]) + struct.pack(">i", len(items)) + b"".join(items)


def packed_longs(indices, bits):
    per = 64 // bits
    out = []
    for i in range(0, len(indices), per):
        word = 0
        for j, v in enumerate(indices[i:i + per]):
            word |= v << (j * bits)
        out.append(word)
    return nbt_list_longs(out)


def nbt_list_longs(values):
    return struct.pack(">i", len(values)) + b"".join(struct.pack(">q", v - (1 << 64) if v >= (1 << 63) else v) for v in values)


def section(y, lower_half_stone=True):
    # Blocks y 0..7 of the section are stone, 8..15 air: index = y*256 + z*16 + x.
    idx = [1 if (i // 256) < 8 and lower_half_stone else 0 for i in range(4096)]
    block_states = nbt_compound({
        "palette": (9, nbt_list(10, [
            nbt_compound({"Name": (8, nbt_str("minecraft:air"))}),
            nbt_compound({"Name": (8, nbt_str("minecraft:stone"))}),
        ])),
        "data": (12, packed_longs(idx, 4)),
    })
    return nbt_compound({"Y": (1, struct.pack("b", y)), "block_states": (10, block_states)})


def chunk_nbt(cx, cz):
    root = nbt_compound({
        "DataVersion": (3, struct.pack(">i", 3953)),
        "xPos": (3, struct.pack(">i", cx)),
        "zPos": (3, struct.pack(">i", cz)),
        "yPos": (3, struct.pack(">i", -4)),
        "Status": (8, nbt_str("minecraft:full")),
        "sections": (9, nbt_list(10, [section(0), section(1, lower_half_stone=False)])),
    })
    return nbt_tag(10, "", root)


def region(chunks):
    header = bytearray(8192)
    body = b""
    sector = 2
    for (cx, cz), nbt in chunks.items():
        payload = zlib.compress(nbt, 6)
        frame = struct.pack(">i", len(payload) + 1) + b"\x02" + payload
        frame += b"\x00" * (-len(frame) % 4096)
        count = len(frame) // 4096
        i = 4 * ((cx % 32) + (cz % 32) * 32)
        header[i:i + 3] = sector.to_bytes(3, "big")
        header[i + 3] = count
        header[4096 + i:4096 + i + 4] = (1762300000).to_bytes(4, "big")
        body += frame
        sector += count
    return bytes(header) + body


world = f"{root}/saves/testworld"
os.makedirs(f"{world}/region", exist_ok=True)

level = nbt_tag(10, "", nbt_compound({"Data": (10, nbt_compound({
    "LevelName": (8, nbt_str("zoo test")),
    "DataVersion": (3, struct.pack(">i", 3953)),
    "SpawnX": (3, struct.pack(">i", 8)),
    "SpawnY": (3, struct.pack(">i", 72)),
    "SpawnZ": (3, struct.pack(">i", -40)),
    "BorderSize": (6, struct.pack(">d", 59999968.0)),
    "hardcore": (1, struct.pack("b", 0)),
    "RandomSeed": (4, struct.pack(">q", -8723617261238761234)),
}))}))
open(f"{world}/level.dat", "wb").write(gzip.compress(level))

open(f"{world}/region/r.0.0.mca", "wb").write(region({(0, 0): chunk_nbt(0, 0), (1, 0): chunk_nbt(1, 0)}))
open(f"{world}/region/r.-1.-1.mca", "wb").write(region({(-1, -1): chunk_nbt(-1, -1)}))
print("world fixture written")


# --- PNGs for the texture decoder ------------------------------------------
# Written by hand rather than with Pillow: the fixtures must stay reproducible
# and the repository free of another build dependency.
def png(width, height, colour, pixels, palette=None, trns=None, filters=None):
    def chunk(kind, body):
        c = kind + body
        return struct.pack(">I", len(body)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    stride = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[colour] * width
    rows = b""
    for y in range(height):
        row = bytes(pixels[y * stride:(y + 1) * stride])
        f = (filters or [0] * height)[y]
        if f == 0:
            rows += b"\x00" + row
        elif f == 1:                       # Sub
            step = stride // width
            out = bytearray(row)
            for i in range(stride - 1, step - 1, -1):
                out[i] = (out[i] - out[i - step]) & 0xFF
            rows += b"\x01" + bytes(out)
        elif f == 2:                       # Up
            prev = bytes(pixels[(y - 1) * stride:y * stride]) if y else b"\x00" * stride
            rows += b"\x02" + bytes((row[i] - prev[i]) & 0xFF for i in range(stride))
        else:
            raise SystemExit("filter not written")
    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, colour, 0, 0, 0))
    if palette:
        out += chunk(b"PLTE", bytes(palette))
    if trns:
        out += chunk(b"tRNS", bytes(trns))
    out += chunk(b"IDAT", zlib.compress(rows, 9))
    out += chunk(b"IEND", b"")
    return out


pdir = f"{root}/png"
os.makedirs(pdir, exist_ok=True)

# 4x2 truecolour, second row filtered with Up so unfiltering is exercised.
rgb = []
for y in range(2):
    for x in range(4):
        rgb += [x * 60 + y, 128 - x * 10, 20 + y * 100]
open(f"{pdir}/rgb.png", "wb").write(png(4, 2, 2, rgb, filters=[0, 2]))

rgba = []
for y in range(2):
    for x in range(2):
        rgba += [x * 100, y * 100, 50, 255 - x * 60]
open(f"{pdir}/rgba.png", "wb").write(png(2, 2, 6, rgba, filters=[0, 1]))

open(f"{pdir}/grey.png", "wb").write(png(3, 1, 0, [0, 127, 255]))
open(f"{pdir}/indexed.png", "wb").write(
    png(3, 1, 3, [0, 1, 2], palette=[255, 0, 0, 0, 255, 0, 0, 0, 255], trns=[0, 128]))
print("png fixtures written")
