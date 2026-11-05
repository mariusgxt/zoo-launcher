// What zoo does when it cannot start at all. A plain abort prints to a console
// that a double-clicked exe does not have, so the window never appears and
// nothing says why. Every fatal start error goes three ways instead: a message
// box where the system has one, stderr for a terminal, and a log file next to
// the data folder that can be sent on afterwards.
import std;
import os;
import zoo.platform;
import zoo.specimen;
import zoo.diagnose;
namespace fatal;

extern fn zoo_message_box(title: const u8[:], text: const u8[:]) -> i32;

fn log_path() -> u8[>..] { str(platform::data_dir(), "/start.log") }

// The message, the specimen label and what diagnose could see, which is what
// anyone looking at the log afterwards needs in one place.
fn write_log(why: const u8[:]) -> bool {
    var text: u8[>..] = [];
    format(text, "zoo could not start\n\n", why, "\n\n");
    diagnose::report(text);
    let path = log_path();
    platform::make_dirs(platform::parent(path));
    write_file(path, text)
}

// Reports why zoo is stopping and ends the program. Never returns.
fn stop(why: const u8[:]) {
    let logged = write_log(why);
    var text: u8[>..] = [];
    format(text, why, "\n\n");
    if logged { format(text, "The details are in ", log_path(), "\n"); }
    write_stderr(text);
    var title: u8[>..] = [];
    format(title, specimen::short_label(specimen::current()), " cannot start");
    zoo_message_box(title, text);
    exit(1);
}
