// The singleplayer worlds of an official launcher folder. A save is a folder
// under saves/ with a level.dat and a region/ folder; its display name lives
// inside level.dat, which is why the name is read rather than taken from the
// folder it sits in.
import std;
import os;
import zoo.archive.compress;
import zoo.world.nbt;
import zoo.world.region;
namespace saves;

struct Save {
    folder: u8[..80],
    name: u8[..80],
    dir: u8[..400],
    region_dir: u8[..400],
    version: i64,
}

fn blank() -> Save { Save { folder: [], name: [], dir: [], region_dir: [], version: 0 } }

// Reads LevelName and DataVersion out of a save's level.dat. A world whose
// level.dat cannot be read still counts as a save: the folder name carries it.
fn describe(s: Save&) -> bool {
    var file: u8[>..] = [];
    guard read_file(str(s.dir, "/level.dat"), file) else { return false; }
    var plain: u8[>..] = [];
    guard compress::any(file, plain) else { return false; }
    var tags: nbt::Node[>..] = [];
    guard nbt::read(plain, tags) else { return false; }
    let name = nbt::text_of(plain, tags, nbt::member(plain, tags, 0, "Data", "LevelName"));
    if name.len > 0 && name.len <= 80 {
        s.name.resize(0);
        s.name.append(name);
    }
    s.version = nbt::int_of(tags, nbt::member(plain, tags, 0, "Data", "DataVersion"), 0);
    true
}

fn scan(game_dir: const u8[:], out: Save[>..]&) -> i64 {
    var names: u8[>..] = [];
    let dir = str(game_dir, "/saves");
    guard list_dir(dir, names) else { return 0; }
    var n = 0;
    each_split(names, '\n') { folder =>
        if folder.len > 0 && folder.len <= 80 {
            let path = str(dir, "/", folder);
            let region_dir = str(path, "/region");
            if path.len <= 400 && region_dir.len <= 400 && file_exists(str(path, "/level.dat")) {
                var s = blank();
                s.folder.append(folder);
                s.name.append(folder);
                s.dir.append(path);
                s.region_dir.append(region_dir);
                describe(s);
                out.push(s);
                n++;
            }
        }
    };
    n
}

// The region files a save holds, as the chunk coordinate each one starts at.
// Walking the folder beats guessing a world's extent, which has no bound.
struct Tile { rx: i64, rz: i64 }

fn tiles(s: const Save&, out: Tile[>..]&) -> i64 {
    var names: u8[>..] = [];
    guard list_dir(s.region_dir, names) else { return 0; }
    var n = 0;
    each_split(names, '\n') { name =>
        let rx, rz, ok = parse_tile(name);
        if ok {
            out.push(Tile { rx: rx, rz: rz });
            n++;
        }
    };
    n
}

// r.-1.3.mca -> -1, 3. Written out by hand because the coordinates are signed
// and sit between literal dots, which a split alone would not check.
fn parse_tile(name: const u8[:]) -> i64, i64, bool {
    guard starts_with(name, "r.") && ends_with(name, ".mca") else { return 0, 0, false; }
    let body = name[2..name.len - 4];
    var dot = -1;
    for i in body.len { if body[i] == '.' { dot = i; break; } }
    guard dot > 0 && dot < body.len - 1 else { return 0, 0, false; }
    let rx, ok_x = parse_int(body[..dot]);
    let rz, ok_z = parse_int(body[dot + 1..]);
    return rx, rz, ok_x && ok_z;
}

fn find(all: const Save[:], name: const u8[:]) -> i64 {
    for s, i in all {
        if s.folder == name || s.name == name { return i; }
    }
    -1
}
