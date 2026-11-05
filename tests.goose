// Test runner: `goose tests.goose`. Fixtures live in test/data; the HTTP
// cases expect `python3 -m http.server 8765` serving test/data, and skip
// themselves when nothing answers.
import std;
import os;
import zoo.hash.sha1;
import zoo.archive.zip;
import zoo.net.http;
import zoo.mojang.meta;
import zoo.prepare;
import zoo.collection;
import zoo.platform;
import zoo.specimen;
import zoo.archive.compress;
import zoo.world.nbt;
import zoo.world.region;
import zoo.world.chunk;
import zoo.image.png;
import zoo.world.saves;
import zoo.client.blockmodel;
import zoo.client.atlas;
import zoo.client.mesh;

var failures = 0;

fn check(what: const u8[:], ok: bool) {
    if !ok { failures++; print("FAIL ", what); } else { print("ok   ", what); }
}

fn test_sha1() {
    check("sha1 empty", sha1::hex("") == "da39a3ee5e6b4b0d3255bfef95601890afd80709");
    check("sha1 abc", sha1::hex("abc") == "a9993e364706816aba3e25717850c26c9cd0d89d");
    var long: u8[>..] = [];
    for i in 1000000 { long.push('a'); }
    check("sha1 million a", sha1::hex(long) == "34aa973cd4c4daa4f61eeb2bdbad27316534016f");
    var s = sha1::start();
    each_chunk(long, 777) { part, i => sha1::update(s, part); };
    check("sha1 streamed", sha1::finish(s) == "34aa973cd4c4daa4f61eeb2bdbad27316534016f");
}

fn test_zip() {
    var jar: u8[>..] = [];
    check("zip fixture readable", read_file("test/data/sample.zip", jar));
    var list: zip::Entry[>..] = [];
    check("zip directory", zip::entries(jar, list) && list.len == 5);
    let expect: const u8[:][5] = ["015dac26fc7caaa295c90eb733ae82f731a3da33", "",
        "929f91a57c1b1376dea2402973dcb8d4a13c53b1", "ab514b9a49fba12b7f30c6780f4398fe0100a38d",
        "b45a9aa6832f537b97bcc6531de11b3913e490bc"];
    for e, i in list {
        if zip::is_dir(e) { continue; }
        var body: u8[>..] = [];
        check(str("zip entry ", e.name), zip::extract(jar, e, body) && sha1::hex(body) == expect[i]);
    }
    var junk: zip::Entry[>..] = [];
    check("zip rejects non-zip", !zip::entries("not a zip at all, sorry", junk));
}

fn test_meta() {
    var text: u8[>..] = [];
    check("manifest fixture", read_file("test/data/version_manifest_v2.json", text));
    var vs: mojang::VersionRef[>..] = [];
    let m = mojang::read_manifest(text, vs);
    check("manifest parses", m.ok && m.latest_release == "26.3" && vs.len == 3);
    check("manifest entry", vs[0].id == "26.3" && vs[0].kind == "release" && vs[0].sha1.len == 40);
    var vt: u8[>..] = [];
    check("version fixture", read_file("test/data/versions/26.3/26.3.json", vt));
    let v = mojang::read_version(vt);
    check("version parses", v.ok && v.id == "26.3" && v.java_major == 25 && v.client_sha1.len == 40);
    let bad = mojang::read_version("{\"id\": 3");
    check("version rejects broken json", !bad.ok && bad.error.len > 0);
}

fn test_prepare() {
    let home = "test/out/home";
    var job = collection::Job { version: [], meta_url: [], meta_sha1: [], local_jar: [], local_meta: [] };
    job.version.append("26.3");
    job.local_jar.append("test/data/versions/26.3/26.3.jar");
    job.local_meta.append("test/data/versions/26.3/26.3.json");
    var last = 0;
    let ok = collection::obtain(home, job) { stage, text => last = stage; print("     [", stage, "] ", text); };
    check("prepare from local jar", ok && last == collection::STAGE_DONE);
    check("prepared texture", file_exists("test/out/home/resources/26.3/assets/minecraft/textures/block/stone.png"));
    check("skipped class file", !file_exists("test/out/home/resources/26.3/net/minecraft/Main.class"));
    var again = 0;
    collection::obtain(home, job) { stage, text => again = again + 1; };
    check("second run skips work", again == 2);
}

fn test_download() {
    var probe: u8[>..] = [];
    let r = http::get("http://127.0.0.1:8765/sample.zip", probe);
    if r.status < 0 { print("skip download tests (no server on 8765)"); return; }
    check("http body", http::ok(r) && sha1::hex(probe) == sha1::hex(probe) && probe.len > 1000);
    var missing: u8[>..] = [];
    let r404 = http::get("http://127.0.0.1:8765/nope", missing);
    check("http 404 is an error", !http::ok(r404) && r404.error.len > 0);
    var job = collection::Job { version: [], meta_url: [], meta_sha1: [], local_jar: [], local_meta: [] };
    job.version.append("26.3");
    job.meta_url.append("http://127.0.0.1:8765/versions/26.3/26.3-local.json");
    let ok = collection::obtain("test/out/dl", job) { stage, text => print("     [", stage, "] ", text); };
    check("download and prepare", ok && file_exists("test/out/dl/versions/26.3/client.jar"));
}

fn test_nbt() {
    var raw: u8[>..] = [];
    check("level.dat readable", read_file("test/data/saves/testworld/level.dat", raw));
    var plain: u8[>..] = [];
    check("level.dat is gzip", compress::gzip(raw, plain));
    var tags: nbt::Node[>..] = [];
    check("level.dat parses", nbt::read(plain, tags));
    let data = nbt::member(plain, tags, 0, "Data");
    check("Data compound", data > 0 && tags[data].kind == nbt::COMPOUND);
    check("LevelName", nbt::text_of(plain, tags, nbt::member(plain, tags, 0, "Data", "LevelName")) == "zoo test");
    check("SpawnY", nbt::int_of(tags, nbt::member(plain, tags, 0, "Data", "SpawnY"), 0) == 72);
    check("negative int", nbt::int_of(tags, nbt::member(plain, tags, 0, "Data", "SpawnZ"), 0) == -40);
    check("long", nbt::int_of(tags, nbt::member(plain, tags, 0, "Data", "RandomSeed"), 0) == -8723617261238761234);
    check("missing member", nbt::member(plain, tags, 0, "Data", "Nope") == -1);
    let border = nbt::member(plain, tags, 0, "Data", "BorderSize");
    check("double", border > 0 && tags[border].dec == 59999968.0);
    check("truncated input refused", !nbt::read(plain[..plain.len / 2], tags));
}

fn test_region() {
    var file: u8[>..] = [];
    check("region readable", read_file("test/data/saves/testworld/region/r.0.0.mca", file));
    check("chunk 0,0 present", region::exists(file, 0, 0));
    check("chunk 5,5 absent", !region::exists(file, 5, 5));
    var raw: u8[>..] = [];
    check("chunk 0,0 inflates", region::chunk(file, 0, 0, raw));
    var tags: nbt::Node[>..] = [];
    check("chunk 0,0 parses", nbt::read(raw, tags));
    check("chunk x", nbt::int_of(tags, nbt::member(raw, tags, 0, "xPos"), 99) == 0);
    check("chunk status", nbt::text_of(raw, tags, nbt::member(raw, tags, 0, "Status")) == "minecraft:full");
    let sections = nbt::member(raw, tags, 0, "sections");
    check("two sections", sections > 0 && tags[sections].count == 2);
    let rx, rz = region::region_of(-1, -1);
    check("negative region", rx == -1 && rz == -1);
    var neg: u8[>..] = [];
    check("negative chunk file", region::read_file_of("test/data/saves/testworld/region", -1, -1, neg));
    var raw2: u8[>..] = [];
    check("negative chunk reads", region::chunk(neg, -1, -1, raw2) && raw2.len > 0);
}

fn test_chunk() {
    var file: u8[>..] = [];
    read_file("test/data/saves/testworld/region/r.0.0.mca", file);
    var raw: u8[>..] = [];
    region::chunk(file, 0, 0, raw);
    var tags: nbt::Node[>..] = [];
    nbt::read(raw, tags);
    var layers: chunk::Layer[>..] = [];
    var blocks: u16[>..] = [];
    let info = chunk::read(raw, tags, layers, blocks);
    check("chunk decoded", info.ok && info.layers == 2);
    check("chunk position", info.cx == 0 && info.cz == 0);
    check("blocks unpacked", blocks.len == 2 * 4096);
    check("palette of two", chunk::palette_size(tags, layers[0].palette) == 2);
    check("palette names", chunk::palette_name(raw, tags, layers[0].palette, 1) == "minecraft:stone");
    check("air index", chunk::index_of(raw, tags, layers[0].palette, "minecraft:air") == 0);
    check("unknown name", chunk::index_of(raw, tags, layers[0].palette, "minecraft:water") == -1);
    // The fixture fills y 0..7 of the lower section with stone and leaves the
    // rest air, so the seam is what proves the bit unpacking.
    check("stone below", chunk::block_at(blocks, layers[0], 3, 7, 11) == 1);
    check("air above", chunk::block_at(blocks, layers[0], 3, 8, 11) == 0);
    check("upper section empty", chunk::block_at(blocks, layers[1], 0, 0, 0) == 0);
    check("out of range", chunk::block_at(blocks, layers[0], 16, 0, 0) == -1);
    check("bits for palette", chunk::bits_for(2) == 4 && chunk::bits_for(17) == 5 && chunk::bits_for(300) == 9);
    check("layer by height", chunk::layer_of(layers, 5) == 0 && chunk::layer_of(layers, 20) == 1 && chunk::layer_of(layers, 200) == -1);
}

fn png_of(path: const u8[:], out: u8[>..]&) -> png::Image {
    var file: u8[>..] = [];
    if !read_file(path, file) { return png::Image { width: 0, height: 0, ok: false, error: [] }; }
    png::decode(file, out)
}

fn test_png() {
    var rgb: u8[>..] = [];
    let a = png_of("test/data/png/rgb.png", rgb);
    check("rgb decodes", a.ok && a.width == 4 && a.height == 2 && rgb.len == 4 * 2 * 4);
    check("rgb first pixel", rgb[0] == 0 && rgb[1] == 128 && rgb[2] == 20 && rgb[3] == 255);
    // Row one is stored with the Up filter, so these bytes only come out right
    // if unfiltering ran.
    check("rgb second row", rgb[16] == 1 && rgb[17] == 128 && rgb[18] == 120);
    check("rgb last pixel", rgb[28] == 181 && rgb[29] == 98 && rgb[30] == 120);

    var rgba: u8[>..] = [];
    let b = png_of("test/data/png/rgba.png", rgba);
    check("rgba decodes", b.ok && rgba.len == 2 * 2 * 4);
    check("rgba alpha kept", rgba[3] == 255 && rgba[7] == 195);

    var grey: u8[>..] = [];
    let c = png_of("test/data/png/grey.png", grey);
    check("grey decodes", c.ok && grey.len == 12);
    check("grey spreads to rgb", grey[4] == 127 && grey[5] == 127 && grey[6] == 127 && grey[7] == 255);

    var idx: u8[>..] = [];
    let e = png_of("test/data/png/indexed.png", idx);
    check("indexed decodes", e.ok && idx.len == 12);
    check("palette applied", idx[0] == 255 && idx[1] == 0 && idx[2] == 0);
    check("tRNS applied", idx[3] == 0 && idx[7] == 128 && idx[11] == 255);

    var junk: u8[>..] = [];
    let f = png::decode("not a png at all", junk);
    check("junk refused", !f.ok && f.error.len > 0 && junk.len == 0);
    var file: u8[>..] = [];
    read_file("test/data/png/rgb.png", file);
    var half: u8[>..] = [];
    check("truncated png refused", !png::decode(file[..file.len / 2], half).ok);
    check("paeth picks the nearest", png::paeth(10, 20, 15) == 15 && png::paeth(2, 3, 100) == 2);
}

fn test_saves() {
    var all: saves::Save[>..] = [];
    check("saves found", saves::scan("test/data", all) == 2);
    let i = saves::find(all, "testworld");
    check("find by folder", i >= 0);
    check("name from level.dat", all[i].name == "zoo test");
    check("data version read", all[i].version == 3953);
    check("find by name", saves::find(all, "zoo test") == i && saves::find(all, "nope") == -1);
    check("no saves folder", saves::scan("test/data/png", all) == 0);
    var tiles: saves::Tile[>..] = [];
    check("region files listed", saves::tiles(all[i], tiles) == 2);
    var seen_neg = false;
    for t in tiles { if t.rx == -1 && t.rz == -1 { seen_neg = true; } }
    check("negative region tile", seen_neg);
    let rx, rz, ok = saves::parse_tile("r.-3.12.mca");
    check("tile name parsed", ok && rx == -3 && rz == 12);
    let _a, _b, bad = saves::parse_tile("r.5.mca");
    check("tile name refused", !bad);
}

fn test_blockmodel() {
    let res = "test/data/resources";
    let stone = blockmodel::faces_of(res, "minecraft:stone");
    check("stone resolved", stone.ok);
    check("stone all faces", stone.side == "minecraft:block/stone" && stone.top == "minecraft:block/stone" && stone.bottom == "minecraft:block/stone");
    let grass = blockmodel::faces_of(res, "minecraft:grass_block");
    check("grass resolved", grass.ok);
    check("grass top", grass.top == "block/grass_block_top");
    check("grass side", grass.side == "block/grass_block_side");
    check("grass bottom", grass.bottom == "block/dirt");
    let log = blockmodel::faces_of(res, "oak_log");
    check("log side", log.ok && log.side == "block/oak_log");
    check("log end on top and bottom", log.top == "block/oak_log_top" && log.bottom == "block/oak_log_top");
    let fence = blockmodel::faces_of(res, "oak_fence");
    check("multipart first model", fence.ok && fence.side == "block/oak_planks");
    check("unknown block", !blockmodel::faces_of(res, "minecraft:nether_portal").ok);
    check("texture path", blockmodel::texture_path(res, "minecraft:block/stone") == "test/data/resources/textures/block/stone.png");
}

fn test_atlas() {
    let res = "test/data/resources";
    var slots: atlas::Slot[>..] = [];
    var tiles: u8[>..] = [];
    let stone = atlas::add(res, "block/stone", slots, tiles);
    let dirt = atlas::add(res, "block/dirt", slots, tiles);
    check("tiles numbered in order", stone == 0 && dirt == 1);
    check("tile bytes appended", tiles.len == 2 * 16 * 16 * 4);
    check("a name is added once", atlas::add(res, "block/stone", slots, tiles) == 0 && slots.len == 2);
    check("missing texture refused", atlas::add(res, "block/nothing_here", slots, tiles) == -1);
    let missing = atlas::add_missing(slots, tiles);
    check("stand-in tile", missing == 2 && atlas::find(slots, "zoo:missing") == 2);
    atlas::add(res, "block/grass_block_top", slots, tiles);
    var image: u8[>..] = [];
    let g = atlas::flatten(tiles, image);
    check("grid is square enough", g.tiles == 4 && g.cols == 2 && g.rows == 2);
    check("image size", g.width == 32 && g.height == 32 && image.len == 32 * 32 * 4);
    // Row 0 holds the top row of tile 0 and then of tile 1, so the first pixel
    // of each is where the two textures' light top rows meet.
    check("first tile in place", image[0] == 165 && image[1] == 165 && image[2] == 165);
    check("second tile beside it", image[64] == 174 && image[65] == 136 && image[66] == 107);
    let u, v = atlas::corner_of(g, 3);
    check("tile corner", u == 0.5 && v == 0.5);
    let du, dv = atlas::step_of(g);
    check("tile step", du == 0.5 && dv == 0.5);
}

fn test_mesh() {
    let res = "test/data/resources";
    var file: u8[>..] = [];
    read_file("test/data/saves/testworld/region/r.0.0.mca", file);
    var raw: u8[>..] = [];
    region::chunk(file, 0, 0, raw);
    var tags: nbt::Node[>..] = [];
    nbt::read(raw, tags);
    var layers: chunk::Layer[>..] = [];
    var blocks: u16[>..] = [];
    chunk::read(raw, tags, layers, blocks);

    var slots: atlas::Slot[>..] = [];
    var tiles: u8[>..] = [];
    var known: mesh::Known[>..] = [];
    var cells: mesh::Cell[>..] = [];
    let vol = mesh::bake(raw, tags, layers, blocks, res, slots, tiles, known, cells);
    check("volume spans both sections", vol.layers == 2 && vol.y0 == 0);
    check("cells filled", cells.len == 2 * 4096);
    check("stone cell solid", mesh::cell_at(cells, vol, 3, 7, 11).solid == 1);
    check("air cell empty", mesh::cell_at(cells, vol, 3, 8, 11).solid == 0);
    check("names cached once", known.len == 2);
    check("air is not solid", mesh::air("minecraft:cave_air") && !mesh::air("minecraft:stone"));

    var image: u8[>..] = [];
    let g = atlas::flatten(tiles, image);
    var pieces: mesh::Piece[>..] = [];
    pieces.push(mesh::Piece { cx: 0, cz: 0, vol: vol });
    var verts: f32[>..] = [];
    let faces = mesh::build(cells, pieces, 0, g, verts);
    // The fixture is a slab eight blocks deep: its lid, its floor and four
    // walls, and nothing from inside it.
    check("only visible faces", faces == 256 + 256 + 4 * 16 * 8);
    check("vertices per face", verts.len == faces * 6 * 6);
    check("mesh sits in the chunk", verts[0] >= 0.0 && verts[0] <= 16.0 && verts[2] >= 0.0 && verts[2] <= 16.0);

    var far_pieces: mesh::Piece[>..] = [];
    far_pieces.push(mesh::Piece { cx: 2, cz: -3, vol: vol });
    var far: f32[>..] = [];
    mesh::build(cells, far_pieces, 0, g, far);
    check("chunk offset applied", far[0] == 32.0 && far[2] == -48.0);

    // With the chunk beside it loaded, the wall between the two is dropped:
    // one side of each chunk loses its 16 by 8 faces.
    var pair: mesh::Cell[>..] = [];
    var both: mesh::Piece[>..] = [];
    var tags_b: nbt::Node[>..] = [];
    var raw_b: u8[>..] = [];
    region::chunk(file, 1, 0, raw_b);
    nbt::read(raw_b, tags_b);
    var layers_b: chunk::Layer[>..] = [];
    var blocks_b: u16[>..] = [];
    chunk::read(raw_b, tags_b, layers_b, blocks_b);
    var known_b: mesh::Known[>..] = [];
    var slots_b: atlas::Slot[>..] = [];
    var tiles_b: u8[>..] = [];
    both.push(mesh::Piece { cx: 0, cz: 0, vol: mesh::bake(raw, tags, layers, blocks, res, slots_b, tiles_b, known_b, pair) });
    both.push(mesh::Piece { cx: 1, cz: 0, vol: mesh::bake(raw_b, tags_b, layers_b, blocks_b, res, slots_b, tiles_b, known_b, pair) });
    var image_b: u8[>..] = [];
    let g_b = atlas::flatten(tiles_b, image_b);
    var seam: f32[>..] = [];
    let seam_faces = mesh::build(pair, both, 0, g_b, seam);
    check("shared wall dropped", seam_faces == faces - 16 * 8);
    check("neighbour cell seen", mesh::cell_world(pair, both, 16, 3, 5).solid == 1);
    check("outside the loaded chunks is air", mesh::cell_world(pair, both, 999, 3, 5).solid == 0);
}

fn main() {
    var label: u8[>..] = [];
    specimen::format_label(label, specimen::current(), platform::name());
    write_stdout(label);
    test_sha1();
    test_zip();
    test_meta();
    test_prepare();
    test_nbt();
    test_region();
    test_chunk();
    test_png();
    test_saves();
    test_blockmodel();
    test_atlas();
    test_mesh();
    test_download();
    if failures == 0 { print("all passed"); } else { print(failures, " failed"); }
    if failures > 0 { exit(1); }
}
