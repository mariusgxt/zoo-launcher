// The launcher's background thread. Downloads and unpacking take seconds,
// and an immediate-mode window has to draw every frame, so slow work runs
// here and talks to the window only through the typed queues.
import std;
import os;
import zoo.net.http;
import zoo.hash.sha1;
import zoo.mojang.meta;
import zoo.collection;
namespace worker;

let ASK_QUIT = 0;
let ASK_MANIFEST = 1;
let ASK_OBTAIN = 2;

struct Ask { kind: i64, home: u8[..400], job: collection::Job }

// One step of an obtain; stage is one of collection's STAGE_* values.
struct Step { stage: i64, version: u8[..48], text: u8[..200] }

// The manifest comes back as one Listed per version, then a ListDone.
struct Listed { v: mojang::VersionRef }
struct ListDone { ok: bool, from_cache: bool, latest: u8[..48], error: u8[..160] }

fn clip(s: const u8[:], n: i64) -> const u8[:] { s[..min(s.len, n)] }

fn manifest_path(home: const u8[:]) -> u8[>..] { str(home, "/version_manifest_v2.json") }

// The manifest is cached so the version list still fills offline.
fn send_manifest(home: const u8[:]) {
    var text: u8[>..] = [];
    // ZOO_MANIFEST_URL points at a mirror, or at a test server.
    var url: u8[>..] = [];
    if !env("ZOO_MANIFEST_URL", url) || url.len == 0 { url.resize(0); url.append(mojang::MANIFEST_URL); }
    let r = http::get(url, text);
    var from_cache = false;
    var why: u8[..160] = [];
    if http::ok(r) {
        write_file_atomic(manifest_path(home), text);
    } else {
        why.append(clip(r.error, 160));
        text.resize(0);
        from_cache = read_file(manifest_path(home), text);
    }
    var done = ListDone { ok: false, from_cache: from_cache, latest: [], error: why };
    if text.len > 0 {
        var vs: mojang::VersionRef[>..] = [];
        let m = mojang::read_manifest(text, vs);
        if m.ok {
            for v in vs { qput(Listed { v: v }); }
            done.ok = true;
            done.latest = m.latest_release;
        } else {
            done.error.resize(0);
            done.error.append(clip(m.error, 160));
        }
    }
    qput(done);
}

thread_fn run() {
    loop {
        let ask = qget<Ask>();
        if ask.kind == ASK_QUIT { break; }
        if ask.kind == ASK_MANIFEST { send_manifest(ask.home); continue; }
        if ask.kind == ASK_OBTAIN {
            let id = ask.job.version;
            collection::obtain(ask.home, ask.job) { stage, text =>
                var s = Step { stage: stage, version: id, text: [] };
                s.text.append(clip(text, 200));
                qput(s);
            };
        }
    }
}
