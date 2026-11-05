// What the launcher window knows between frames, and the few helpers every
// page needs. It lives apart from the views so that a page can read the
// state without the dispatcher having to import the page and the page the
// dispatcher back.
import std;
import ui;
import zoo.collection;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.catalogue;
namespace state;

// The pages, in the order the rail lists them.
let PAGE_PLAY = 0;
let PAGE_VERSIONS = 1;
let PAGE_CONTENT = 2;
let PAGE_WORLDS = 3;
let PAGE_SETTINGS = 4;
let PAGE_SPECIMEN = 5;
let PAGE_COUNT = 6;

// What a frame asks the main loop to do. The views never act themselves.
let WANT_NOTHING = 0;
let WANT_OBTAIN = 1;
let WANT_REFRESH = 2;
let WANT_THEME = 3;      // theme_pick holds which
let WANT_QUIT = 4;

// The three lists of the content page, after the Mods / Shaders / Resource
// packs tabs of the design.
let SHELF_MODS = 0;
let SHELF_SHADERS = 1;
let SHELF_PACKS = 2;

struct Filters { releases: bool, snapshots: bool, installed_only: bool }

struct State {
    rows: catalogue::Row[>..]&,
    selected: i64,
    filters: Filters,
    page: i64,
    scroll: f32,
    shelf: i64,
    busy: bool,
    stage: i64,
    status: u8[..200],
    list_note: u8[..200],
    home: const u8[:],
    game_dir: const u8[:],
    game_found: bool,
    locality: const u8[:],
    theme_pick: i64,
    minutes: i64,         // local wall clock, refreshed by the main loop
}

// The window is laid out from these; everything else hangs off them.
let EDGE: f32 = 20.0;         // window border to the rail
let RAIL_W: f32 = 66.0;
let TOP_H: f32 = 92.0;        // logo, clock, badge and bar live above this
let GAP: f32 = 24.0;          // rail to content

fn content_x() -> f32 { EDGE + RAIL_W + GAP }

fn content_w(w: f32) -> f32 { w - content_x() - EDGE }

fn upper(s: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    out.append(s);
    to_upper(out);
    out
}

fn visible(r: const catalogue::Row&, f: const Filters&) -> bool {
    if f.installed_only && r.local_jar.len == 0 { return false; }
    if r.kind == "release" { return f.releases; }
    if r.kind == "snapshot" { return f.snapshots; }
    if r.kind == "installed" { return true; }
    false      // old_beta and old_alpha stay out until the zoo client reads them
}

fn chosen(s: const State&) -> bool { s.selected >= 0 && s.selected < s.rows.len }

fn readiness(r: const catalogue::Row&, s: const State&) -> const u8[:], ui::Color {
    if s.busy { return "PREPARING", theme::ACCENT; }
    if r.ready { return "READY", theme::LEAF; }
    if s.stage == collection::STAGE_FAILED { return "FAILED", theme::RUST; }
    return "NOT PREPARED", theme::MUTED;
}

fn prepared_count(s: const State&) -> i64 {
    var n = 0;
    for r in s.rows { if r.ready { n++; } }
    n
}

// "4:34 PM", as the design's clock reads.
fn clock_text(minutes: i64) -> u8[>..] {
    let h24 = (minutes / 60) % 24;
    let m = minutes % 60;
    let h = if h24 % 12 == 0 { 12 } else { h24 % 12 };
    var out: u8[>..] = [];
    format(out, h, ":", if m < 10 { "0" } else { "" }, m, if h24 < 12 { " AM" } else { " PM" });
    out
}

// The heading every page but Play carries: a large name and a sentence.
fn page_heading(p: const kit::Pen&, x: f32, y: f32, title: const u8[:], lead_one: const u8[:], lead_two: const u8[:]) {
    let tw = kit::text(p, x, y, title, p.fonts.heading, theme::INK);
    kit::text(p, x + tw + 28.0, y + 12.0, lead_one, p.fonts.small, theme::MUTED);
    kit::text(p, x + tw + 28.0, y + 30.0, lead_two, p.fonts.small, theme::MUTED);
}
