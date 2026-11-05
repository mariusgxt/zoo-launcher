// Brings one Minecraft version into zoo's collection: finds or downloads
// its client jar, checks it, and prepares the client's resources from it.
// Progress goes to a block the caller passes, so the same code runs in the
// GUI's worker thread and in the tests.
import std;
import os;
import zoo.platform;
import zoo.net.http;
import zoo.hash.sha1;
import zoo.mojang.meta;
import zoo.minecraft.installs;
import zoo.prepare;
namespace collection;

let STAGE_LOOKUP = 1;
let STAGE_DOWNLOAD = 2;
let STAGE_VERIFY = 3;
let STAGE_PREPARE = 4;
let STAGE_DONE = 5;
let STAGE_FAILED = 6;

struct Job { version: u8[..48], meta_url: u8[..200], meta_sha1: u8[..40], local_jar: u8[..400], local_meta: u8[..400] }

fn version_dir(home: const u8[:], id: const u8[:]) -> u8[>..] { str(home, "/versions/", id) }
fn resource_dir(home: const u8[:], id: const u8[:]) -> u8[>..] { str(home, "/resources/", id) }

// F(stage, text) is told each step. Returns true when the resources are ready.
fn obtain<F>(home: const u8[:], job: const Job&) -> bool {
    let id = job.version;
    let res = resource_dir(home, id);
    let vdir = version_dir(home, id);
    guard platform::make_dirs(vdir) else { F(STAGE_FAILED, str("cannot make ", vdir)); return false; }

    // The version file first: it carries the jar's SHA-1, local or not.
    F(STAGE_LOOKUP, str("reading the version file of ", id));
    var meta_text: u8[>..] = [];
    if job.local_meta.len > 0 {
        guard read_file(job.local_meta, meta_text) else { F(STAGE_FAILED, str("cannot read ", job.local_meta)); return false; }
    } else {
        let r = http::get(job.meta_url, meta_text);
        guard http::ok(r) else { F(STAGE_FAILED, str("version file: ", r.error)); return false; }
        if job.meta_sha1.len > 0 && sha1::hex(meta_text) != job.meta_sha1 {
            F(STAGE_FAILED, "the version file does not match its checksum");
            return false;
        }
        write_file(str(vdir, "/version.json"), meta_text);
    }
    let v = mojang::read_version(meta_text);
    guard v.ok else { F(STAGE_FAILED, str("version file: ", v.error)); return false; }

    if prepare::is_prepared(res, v.client_sha1) { F(STAGE_DONE, str(id, " is ready")); return true; }

    var jar: u8[>..] = [];
    let cached = str(vdir, "/client.jar");
    if job.local_jar.len > 0 {
        F(STAGE_LOOKUP, str("using the jar from ", job.local_jar));
        guard read_file(job.local_jar, jar) else { F(STAGE_FAILED, str("cannot read ", job.local_jar)); return false; }
    } else if read_file(cached, jar) && sha1::hex(jar) == v.client_sha1 {
        F(STAGE_LOOKUP, "using the jar downloaded before");
    } else {
        jar.resize(0);
        F(STAGE_DOWNLOAD, str("downloading the client jar (", v.client_size / 1048576, " MB)"));
        let r = http::get(v.client_url, jar);
        guard http::ok(r) else { F(STAGE_FAILED, str("client jar: ", r.error)); return false; }
    }

    F(STAGE_VERIFY, "checking the jar");
    let got = sha1::hex(jar);
    guard got == v.client_sha1 else { F(STAGE_FAILED, str("the jar's SHA-1 is ", got, ", expected ", v.client_sha1)); return false; }
    if job.local_jar.len == 0 { write_file_atomic(cached, jar); }

    F(STAGE_PREPARE, "taking textures, models and block states out of the jar");
    let rep = prepare::from_jar(jar, v.client_sha1, res);
    guard rep.ok else { F(STAGE_FAILED, str("preparing: ", rep.error)); return false; }
    F(STAGE_DONE, str(id, " is ready: ", rep.files, " files, ", rep.bytes / 1024, " KB"));
    true
}
