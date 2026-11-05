// What zoo can tell about the machine it was started on, in one block of
// text. A start that fails on someone else's computer is otherwise a guess:
// this names the folders it would use, whether they can be written, and
// whether the window could be opened at all.
import std;
import os;
import zoo.platform;
import zoo.specimen;
namespace diagnose;

fn state_of(path: const u8[:]) -> const u8[:] {
    if !file_exists(path) { return "missing"; }
    if !is_dir(path) { return "not a folder"; }
    return "there";
}

// Writes and deletes a file, because a folder that exists is not the same as
// a folder zoo may write into: a synced AppData or a locked-down profile says
// yes to the first question and no to the second.
fn writable(dir: const u8[:]) -> const u8[:] {
    guard platform::make_dirs(dir) else { return "cannot be made"; }
    let probe = str(dir, "/write-probe.tmp");
    guard write_file(probe, "zoo") else { return "no, cannot write there"; }
    delete_file(probe);
    return "yes";
}

fn report(out: u8[>..]&) {
    specimen::format_label(out, specimen::current(), platform::name());
    format(out, "\n");
    let data = platform::data_dir();
    let game = platform::minecraft_dir();
    format(out, "Data folder    ", data, "\n");
    format(out, "  state        ", state_of(data), "\n");
    format(out, "  writable     ", writable(data), "\n");
    format(out, "Minecraft      ", game, "\n");
    format(out, "  state        ", state_of(game), "\n");
    format(out, "  versions     ", state_of(str(game, "/versions")), "\n");
    format(out, "  saves        ", state_of(str(game, "/saves")), "\n");
    var home: u8[>..] = [];
    if env("ZOO_HOME", home) && home.len > 0 { format(out, "ZOO_HOME       ", home, "\n"); }
    format(out, "Resources      ", state_of(str(data, "/resources")), "\n");
}
