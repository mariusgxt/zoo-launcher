// Takes what the zoo client needs out of a client jar: textures, models,
// block states, atlases and the English names. Zoo ships none of Mojang's
// files; they come from the player's own copy, as with Horizon.
import std;
import os;
import zoo.archive.zip;
import zoo.platform;
namespace prepare;

let KEEP: const u8[:][6] = ["textures/", "models/", "blockstates/", "atlases/", "lang/en_us.json", "font/"];
let PREFIX = "assets/minecraft/";

struct Report { files: i64, bytes: i64, ok: bool, error: u8[..200] }

fn wanted(name: const u8[:]) -> bool {
    guard starts_with(name, PREFIX) else { return false; }
    let rest = name[PREFIX.len..];
    for k in KEEP { if starts_with(rest, k) { return true; } }
    false
}

// The stamp names the jar's SHA-1, so a changed jar prepares again and an
// unchanged one is skipped on the next start.
fn stamp_path(dest: const u8[:]) -> u8[>..] { str(dest, "/prepared.txt") }

fn is_prepared(dest: const u8[:], jar_sha1: const u8[:]) -> bool {
    var s: u8[>..] = [];
    read_file(stamp_path(dest), s) && starts_with(s, jar_sha1)
}

fn from_jar(jar: const u8[:], jar_sha1: const u8[:], dest: const u8[:]) -> Report {
    var rep = Report { files: 0, bytes: 0, ok: false, error: [] };
    var list: zip::Entry[>..] = [];
    guard zip::entries(jar, list) else { rep.error.append("not a zip file"); return rep; }
    var made: u8[>..] = [];       // the last directory made, to skip repeats
    for e in list {
        if zip::is_dir(e) || !wanted(e.name) { continue; }
        let path = str(dest, "/", e.name);
        let dir = platform::parent(path);
        if dir != made {
            if !platform::make_dirs(dir) { rep.error.append(str("cannot make ", dir)[..min(dir.len + 12, 200)]); return rep; }
            made.resize(0);
            made.append(dir);
        }
        var body: u8[>..] = [];
        if !zip::extract(jar, e, body) { format(rep.error, "broken entry ", e.name[..min(e.name.len, 150)]); return rep; }
        if !write_file(path, body) { format(rep.error, "cannot write ", e.name[..min(e.name.len, 150)]); return rep; }
        rep.files++;
        rep.bytes += body.len;
    }
    if rep.files == 0 { rep.error.append("the jar has no assets/minecraft files"); return rep; }
    write_file(stamp_path(dest), str(jar_sha1, "\n", rep.files, " files\n"));
    rep.ok = true;
    rep
}
