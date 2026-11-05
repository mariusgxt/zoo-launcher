// The version list the window shows: Mojang's manifest merged with what is
// installed locally. One row per version id, so a version both installed
// and listed by Mojang shows once and prefers the local jar.
import std;
import os;
import zoo.mojang.meta;
import zoo.minecraft.installs;
import zoo.collection;
import zoo.prepare;
namespace catalogue;

struct Row {
    id: u8[..48],
    kind: u8[..16],
    released: u8[..32],
    meta_url: u8[..200],
    meta_sha1: u8[..40],
    local_jar: u8[..400],
    local_meta: u8[..400],
    ready: bool,
}

fn index_of(rows: const Row[:], id: const u8[:]) -> i64 {
    for r, i in rows { if r.id == id { return i; } }
    -1
}

fn blank() -> Row {
    Row { id: [], kind: [], released: [], meta_url: [], meta_sha1: [], local_jar: [], local_meta: [], ready: false }
}

fn add_installed(rows: Row[>..]&, found: const installs::Found[:]) {
    for f in found {
        var at = index_of(rows, f.id);
        if at < 0 { var r = blank(); r.id = f.id; r.kind.append("installed"); rows.push(r); at = rows.len - 1; }
        rows[at].local_jar = f.jar;
        rows[at].local_meta = f.meta;
    }
}

fn add_listed(rows: Row[>..]&, v: const mojang::VersionRef&) {
    var at = index_of(rows, v.id);
    if at < 0 { var r = blank(); r.id = v.id; rows.push(r); at = rows.len - 1; }
    rows[at].kind = v.kind;
    rows[at].released = v.released;
    rows[at].meta_url = v.url;
    rows[at].meta_sha1 = v.sha1;
}

// A row is ready when its resources carry a stamp; the stamp's SHA-1 is
// checked again when the version is obtained.
fn refresh_ready(rows: Row[:], home: const u8[:]) {
    for &r in rows { r.ready = file_exists(str(collection::resource_dir(home, r.id), "/prepared.txt")); }
}

fn job_for(r: const Row&) -> collection::Job {
    collection::Job { version: r.id, meta_url: r.meta_url, meta_sha1: r.meta_sha1, local_jar: r.local_jar, local_meta: r.local_meta }
}

// Newest first by Mojang's release time; installed-only rows (no time) last.
fn sort_rows(rows: Row[:]) {
    sort(rows) { a, b => compare(a.released, b.released) > 0 };
}
