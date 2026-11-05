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

fn main() {
    var label: u8[>..] = [];
    specimen::format_label(label, specimen::current(), platform::name());
    write_stdout(label);
    test_sha1();
    test_zip();
    test_meta();
    test_prepare();
    test_download();
    if failures == 0 { print("all passed"); } else { print(failures, " failed"); }
    if failures > 0 { exit(1); }
}
