// Versions already on this machine, found in an official launcher folder.
// Using them first means the common case needs no download at all, as
// Horizon's launcher does with other launchers' folders.
import std;
import os;
namespace installs;

struct Found { id: u8[..48], jar: u8[..400], meta: u8[..400] }

fn scan(game_dir: const u8[:], out: Found[>..]&) -> i64 {
    var names: u8[>..] = [];
    let versions = str(game_dir, "/versions");
    guard list_dir(versions, names) else { return 0; }
    var n = 0;
    each_split(names, '\n') { id =>
        if id.len > 0 && id.len <= 48 {
            let jar = str(versions, "/", id, "/", id, ".jar");
            let meta = str(versions, "/", id, "/", id, ".json");
            if jar.len <= 400 && meta.len <= 400 && file_exists(jar) && file_exists(meta) {
                var f = Found { id: [], jar: [], meta: [] };
                f.id.append(id);
                f.jar.append(jar);
                f.meta.append(meta);
                out.push(f);
                n++;
            }
        }
    };
    n
}

fn find(found: const Found[:], id: const u8[:]) -> i64 {
    for f, i in found { if f.id == id { return i; } }
    -1
}
