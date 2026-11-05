// What sits in a Minecraft folder beside the game: mods, shader packs and
// resource packs. zoo neither loads nor installs them yet; it reads the
// folders the official launcher uses, so the launcher can show and switch
// off what is already there.
import std;
import os;
namespace content;

let KIND_MODS = 0;
let KIND_SHADERS = 1;
let KIND_PACKS = 2;

// Switched off is a renamed file, which is how mod loaders have always read
// it, so the change survives zoo being uninstalled.
let OFF = ".disabled";

struct Item {
    name: u8[..120],       // what to show: the file name without its suffixes
    file: u8[..400],       // the full path as it is on disk right now
    kind: i64,
    on: bool,
    folder: bool,          // resource packs may be folders rather than files
}

fn folder_of(kind: i64) -> const u8[:] {
    match kind {
        0 => "mods",
        1 => "shaderpacks",
        _ => "resourcepacks",
    }
}

fn title_of(kind: i64) -> const u8[:] {
    match kind {
        0 => "Mods",
        1 => "Shaders",
        _ => "Resource packs",
    }
}

fn lead_of(kind: i64) -> const u8[:] {
    match kind {
        0 => "Mods found in your Minecraft folder. The zoo client does not",
        1 => "Shader packs found in your Minecraft folder. The zoo client does",
        _ => "Resource packs found in your Minecraft folder. zoo reads the",
    }
}

fn lead_two_of(kind: i64) -> const u8[:] {
    match kind {
        0 => "load them yet; switching one off renames it, as a loader reads it.",
        1 => "not draw with them yet; switching one off renames it.",
        _ => "game's own textures; switching one off renames the pack.",
    }
}

// Strips the suffixes so a row reads as a name, not as a file.
fn display_name(out: u8[>..]&, file: const u8[:]) {
    var n = file.len;
    if ends_with(file[..n], OFF) { n -= OFF.len; }
    if n > 4 && (ends_with(file[..n], ".jar") || ends_with(file[..n], ".zip")) { n -= 4; }
    out.append(file[..min(n, 120)]);
}

fn scan(game_dir: const u8[:], kind: i64, out: Item[>..]&) -> i64 {
    var names: u8[>..] = [];
    let dir = str(game_dir, "/", folder_of(kind));
    guard list_dir(dir, names) else { return 0; }
    var n = 0;
    each_split(names, '\n') { entry =>
        if entry.len > 0 && entry.len <= 120 {
            let path = str(dir, "/", entry);
            if path.len <= 400 {
                var name: u8[>..] = [];
                display_name(name, entry);
                var item = Item { name: [], file: [], kind: kind, on: !ends_with(entry, OFF), folder: is_dir(path) };
                item.name.append(name);
                item.file.append(path);
                out.push(item);
                n++;
            }
        }
    };
    n
}

// Renames the file the other way round. The item is updated only when the
// rename worked, so a read-only folder leaves the switch where it was.
fn set_enabled(item: Item&, on: bool) -> bool {
    if item.on == on { return true; }
    var target: u8[>..] = [];
    if on {
        if !ends_with(item.file, OFF) { return false; }
        target.append(item.file[..item.file.len - OFF.len]);
    } else {
        target.append(item.file);
        target.append(OFF);
    }
    if target.len > 400 { return false; }
    guard rename_file(item.file, target) else { return false; }
    item.file.resize(0);
    item.file.append(target);
    item.on = on;
    true
}
