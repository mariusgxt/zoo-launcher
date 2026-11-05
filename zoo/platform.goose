// Where things live on this machine. Every path goes out with '/', which
// Windows accepts as well, so callers never branch on the separator.
import std;
import os;
namespace platform;

extern fn zoo_platform() -> i32;

let WINDOWS = 0;
let LINUX = 1;
let MACOS = 2;

fn current() -> i32 { zoo_platform() }

fn name() -> const u8[:] {
    match zoo_platform() as i64 { WINDOWS => "windows", MACOS => "macos", _ => "linux" }
}

fn env_or(name: const u8[:], fallback: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    if !env(name, out) || out.len == 0 { out.resize(0); out.append(fallback); }
    for &c in out { if c == '\\' { c = '/'; } }
    out
}

fn home() -> u8[>..] {
    if zoo_platform() as i64 == WINDOWS { env_or("USERPROFILE", "C:/") } else { env_or("HOME", "/tmp") }
}

// The official launcher's game directory; other launchers keep their own,
// which sources can learn later.
fn minecraft_dir() -> u8[>..] {
    let p = zoo_platform() as i64;
    if p == WINDOWS { return str(env_or("APPDATA", "C:/"), "/.minecraft"); }
    if p == MACOS { return str(home(), "/Library/Application Support/minecraft"); }
    return str(home(), "/.minecraft");
}

// ZOO_HOME wins so tests and portable installs can point zoo elsewhere.
fn data_dir() -> u8[>..] {
    var forced: u8[>..] = [];
    if env("ZOO_HOME", forced) && forced.len > 0 { return forced; }
    let p = zoo_platform() as i64;
    if p == WINDOWS { return str(env_or("APPDATA", "C:/"), "/zoo"); }
    if p == MACOS { return str(home(), "/Library/Application Support/zoo"); }
    var xdg: u8[>..] = [];
    if env("XDG_DATA_HOME", xdg) && xdg.len > 0 { return str(xdg, "/zoo"); }
    return str(home(), "/.local/share/zoo");
}

// make_dir only makes the last part, so the parents are made first. It
// also reports false for a folder that is already there, which on a second
// start is the normal case, so the result is whether the folder exists.
fn make_dirs(path: const u8[:]) -> bool {
    for i in 1..path.len {
        if path[i] == '/' && path[i - 1] != ':' && path[i - 1] != '/' { make_dir(path[..i]); }
    }
    make_dir(path);
    return is_dir(path);
}

fn parent(path: const u8[:]) -> const u8[:] {
    let i = rfind(path, "/");
    if i <= 0 { path[..0] } else { path[..i] }
}
