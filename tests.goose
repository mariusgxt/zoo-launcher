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
    check("level.dat readable", read_file("test/data/world/level.dat", raw));
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
    check("region readable", read_file("test/data/world/region/r.0.0.mca", file));
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
    check("negative chunk file", region::read_file_of("test/data/world/region", -1, -1, neg));
    var raw2: u8[>..] = [];
    check("negative chunk reads", region::chunk(neg, -1, -1, raw2) && raw2.len > 0);
}

fn test_chunk() {
    var file: u8[>..] = [];
    read_file("test/data/world/region/r.0.0.mca", file);
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
    test_download();
    if failures == 0 { print("all passed"); } else { print(failures, " failed"); }
    if failures > 0 { exit(1); }
}
