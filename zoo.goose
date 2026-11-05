// zoo: the launcher. Build with `goose build zoo.goose` (the worker thread
// needs a real C compiler, so the in-process run is not enough here).
//   zoo-launcher               opens the window
//   zoo-launcher --version     prints the specimen label
//   zoo-launcher --check       prints the folders it uses and whether they work
//   zoo-launcher --frames N    draws N frames and saves zoo.png (for CI)
//   zoo-launcher --select ID [--prepare]   picks a version, and prepares it
//   zoo-launcher --page versions|about     opens on another page
import std;
import os;
import gfx;
import ui;
import zoo.platform;
import zoo.specimen;
import zoo.diagnose;
import zoo.fatal;
import zoo.collection;
import zoo.minecraft.installs;
import zoo.app.worker;
import zoo.app.catalogue;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.view;

struct Options { frames: i64, version: bool, check: bool, select: u8[..48], prepare: bool, page: i64 }

fn read_options() -> Options {
    var o = Options { frames: -1, version: false, check: false, select: [], prepare: false, page: view::PAGE_PLAY };
    let argv = args();
    var i = 1;
    while i < argv.len {
        if argv[i] == "--version" { o.version = true; }
        else if argv[i] == "--check" { o.check = true; }
        else if argv[i] == "--prepare" { o.prepare = true; }
        else if argv[i] == "--page" && i + 1 < argv.len {
            if argv[i + 1] == "versions" { o.page = view::PAGE_VERSIONS; }
            else if argv[i + 1] == "about" { o.page = view::PAGE_ABOUT; }
            i++;
        }
        else if argv[i] == "--select" && i + 1 < argv.len {
            o.select.append(argv[i + 1][..min(argv[i + 1].len, 48)]);
            i++;
        }
        else if argv[i] == "--frames" && i + 1 < argv.len {
            let n, ok = parse_int(argv[i + 1]);
            if ok { o.frames = n; }
            i++;
        }
        i++;
    }
    o
}

fn ask(kind: i64, home: const u8[:], job: collection::Job) {
    var a = worker::Ask { kind: kind, home: [], job: job };
    a.home.append(home[..min(home.len, 400)]);
    qput(a);
}

fn empty_job() -> collection::Job {
    collection::Job { version: [], meta_url: [], meta_sha1: [], local_jar: [], local_meta: [] }
}

fn rescan(rows: catalogue::Row[>..]&, home: const u8[:]) {
    var found: installs::Found[>..] = [];
    installs::scan(platform::minecraft_dir(), found);
    catalogue::add_installed(rows, found);
    catalogue::refresh_ready(rows, home);
}

fn first_visible(rows: const catalogue::Row[:], f: const view::Filters&) -> i64 {
    for r, i in rows { if view::visible(r, f) { return i; } }
    -1
}

fn main() {
    let opts = read_options();
    let locality = platform::name();
    if opts.version {
        var label: u8[>..] = [];
        specimen::format_label(label, specimen::current(), locality);
        write_stdout(label);
        return;
    }
    if opts.check {
        var text: u8[>..] = [];
        diagnose::report(text);
        write_stdout(text);
        return;
    }
    let home = platform::data_dir();
    // A data folder that cannot be made is shown in the window rather than
    // aborted on: someone who started the launcher by double-clicking it
    // sees no console, so an abort here looks like nothing happening.
    let home_ok = platform::make_dirs(home);

    guard gfx::open(specimen::short_label(specimen::current()), 1280, 800, gfx::WINDOW_RESIZABLE) else {
        fatal::stop(str("The window could not be opened.\n", gfx::error()));
    }
    let fonts, baked = theme::load_fonts();
    guard baked else { fatal::stop(str("The fonts could not be prepared.\n", ui::error())); }
    let ctx = ui::create_context(fonts.body);
    guard ctx.id != 0 else { fatal::stop(str("The interface could not be set up.\n", ui::error())); }
    theme::use_palette(ctx, theme::load_choice(home));

    let thread = thread_spawn(worker::run);
    let game_dir = platform::minecraft_dir();
    var rows: catalogue::Row[>..] = [];
    rescan(rows, home);
    ask(worker::ASK_MANIFEST, home, empty_job());

    var s = view::State {
        rows: rows, selected: -1,
        filters: view::Filters { releases: true, snapshots: false, installed_only: false },
        page: opts.page, scroll: 0.0,
        busy: false, stage: 0, status: [], list_note: [], home: home,
        game_dir: game_dir, game_found: is_dir(game_dir), locality: locality,
        theme_pick: 0,
    };
    s.list_note.append("asking Mojang for the version list...");
    if !home_ok {
        s.stage = collection::STAGE_FAILED;
        format(s.status, "cannot make ", home, " - check that the folder is writable");
    }
    var drawn = 0;
    var listing = true;

    while gfx::frame() {
        // Drain whatever the worker finished since the last frame.
        loop {
            let l, got = qpoll<worker::Listed>();
            if !got { break; }
            catalogue::add_listed(rows, l.v);
        }
        if listing {
            let d, done = qpoll<worker::ListDone>();
            if done {
                listing = false;
                catalogue::sort_rows(rows);
                catalogue::refresh_ready(rows, home);
                s.selected = first_visible(rows, s.filters);
                if opts.select.len > 0 { s.selected = catalogue::index_of(rows, opts.select); }
                if opts.prepare && s.selected >= 0 && !s.busy {
                    s.busy = true;
                    ask(worker::ASK_OBTAIN, home, catalogue::job_for(rows[s.selected]));
                }
                s.list_note.resize(0);
                if d.ok && !d.from_cache { format(s.list_note, rows.len, " versions, latest release ", d.latest); }
                else if d.ok { format(s.list_note, "offline, showing the saved list (", d.error[..min(d.error.len, 120)], ")"); }
                else { format(s.list_note, "no version list: ", d.error[..min(d.error.len, 160)]); }
            }
        }
        loop {
            let st, got = qpoll<worker::Step>();
            if !got { break; }
            s.stage = st.stage;
            s.status = st.text;
            if st.stage == collection::STAGE_DONE || st.stage == collection::STAGE_FAILED {
                s.busy = false;
                catalogue::refresh_ready(rows, home);
            }
        }

        ui::input_from_gfx(ctx);
        let size = gfx::screen_size();
        let want = view::draw(ctx, fonts, s, size.x, size.y);
        if want == view::WANT_OBTAIN && s.selected >= 0 {
            s.busy = true;
            s.stage = collection::STAGE_LOOKUP;
            s.status.resize(0);
            s.status.append("starting");
            ask(worker::ASK_OBTAIN, home, catalogue::job_for(rows[s.selected]));
        } else if want == view::WANT_THEME {
            theme::use_palette(ctx, s.theme_pick);
            theme::save_choice(home);
        } else if want == view::WANT_REFRESH {
            rescan(rows, home);
            s.game_found = is_dir(game_dir);
            listing = true;
            ask(worker::ASK_MANIFEST, home, empty_job());
        }

        gfx::begin_screen(float4 { theme::BG.r / 255.0, theme::BG.g / 255.0, theme::BG.b / 255.0, 1.0 });
        gfx::end_pass();
        ui::render(ctx);
        drawn++;
        if drawn == opts.frames { break; }
    }
    if opts.frames > 0 { gfx::screenshot("zoo.png"); }
    ask(worker::ASK_QUIT, home, empty_job());
    thread_wait(thread);
    ui::destroy(ctx);
    ui::destroy(fonts.atlas);
    gfx::close();
}
