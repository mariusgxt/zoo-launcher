// What the launcher window draws each frame. It reads the state, draws on
// the canvas through kit, and returns what the user asked for; the main
// loop decides what happens, so the view has no side effects of its own.
import std;
import os;
import ui;
import zoo.specimen;
import zoo.collection;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.catalogue;
namespace view;

let PAGE_PLAY = 0;
let PAGE_VERSIONS = 1;
let PAGE_ABOUT = 2;

let WANT_NOTHING = 0;
let WANT_OBTAIN = 1;
let WANT_REFRESH = 2;

struct Filters { releases: bool, snapshots: bool, installed_only: bool }

struct State {
    rows: catalogue::Row[>..]&,
    selected: i64,
    filters: Filters,
    page: i64,
    scroll: f32,
    busy: bool,
    stage: i64,
    status: u8[..200],
    list_note: u8[..200],
    home: const u8[:],
    game_dir: const u8[:],
    game_found: bool,
    locality: const u8[:],
}

let MARGIN: f32 = 64.0;

fn visible(r: const catalogue::Row&, f: const Filters&) -> bool {
    if f.installed_only && r.local_jar.len == 0 { return false; }
    if r.kind == "release" { return f.releases; }
    if r.kind == "snapshot" { return f.snapshots; }
    if r.kind == "installed" { return true; }
    false      // old_beta and old_alpha stay out until the zoo client reads them
}

fn upper(s: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    out.append(s);
    to_upper(out);
    out
}

fn draw_nav(p: const kit::Pen&, s: State&, w: f32) {
    // The mark: a sand dot with the name beside it.
    ui::fill_circle(p.ctx, kit::r(MARGIN, 28.0, 14.0, 14.0), theme::ACCENT);
    kit::text(p, MARGIN + 24.0, 25.0, "zoo", p.fonts.medium, theme::INK);
    let labels: const u8[:][3] = ["Play", "Versions", "About"];
    var total: f32 = 0.0;
    for l in labels { total += kit::width(p.fonts.body, l) + 28.0 + 4.0; }
    var x = w - MARGIN - total;
    for l, i in labels {
        let tw, hit = kit::tab(p, x, 19.0, l, s.page == i);
        if hit { s.page = i; }
        x += tw + 4.0;
    }
}

fn readiness(r: const catalogue::Row&, s: const State&) -> const u8[:], ui::Color {
    if s.busy { return "PREPARING", theme::ACCENT; }
    if r.ready { return "READY", theme::LEAF; }
    if s.stage == collection::STAGE_FAILED { return "FAILED", theme::RUST; }
    return "NOT PREPARED", theme::MUTED;
}

fn row_item(p: const kit::Pen&, y: f32, w: f32, n: const u8[:], title: const u8[:], detail: const u8[:],
            detail_color: ui::Color, action: const u8[:], enabled: bool) -> bool {
    kit::text(p, MARGIN, y + 23.0, n, p.fonts.mono, theme::FAINT);
    kit::text(p, MARGIN + 56.0, y + 13.0, title, p.fonts.medium, theme::INK);
    var d: u8[>..] = [];
    kit::fit(d, detail, p.fonts.small, w - 2.0 * MARGIN - 260.0);
    kit::text(p, MARGIN + 56.0, y + 36.0, d, p.fonts.small, detail_color);
    var hit = false;
    if action.len > 0 {
        hit = kit::button(p, kit::r(w - MARGIN - 180.0, y + 18.0, 164.0, 30.0), action, kit::LINK, enabled);
    }
    kit::line(p, MARGIN, w - MARGIN, y + 66.0);
    hit
}

fn draw_play(p: const kit::Pen&, s: State&, w: f32, h: f32) -> i64 {
    var want = WANT_NOTHING;
    let tag = specimen::current();
    let has = s.selected >= 0 && s.selected < s.rows.len;

    // Eyebrow, title and the specimen line.
    var x = MARGIN;
    if has {
        let row = s.rows[s.selected];
        let word, color = readiness(row, s);
        x += kit::text(p, x, 118.0, str("MINECRAFT ", upper(row.id)), p.fonts.mono, theme::MUTED);
        x += kit::text(p, x + 10.0, 118.0, "·", p.fonts.mono, theme::FAINT) + 20.0;
        kit::text(p, x, 118.0, word, p.fonts.mono, color);
    } else {
        kit::text(p, x, 118.0, "NO VERSION CHOSEN", p.fonts.mono, theme::MUTED);
    }
    kit::text(p, MARGIN - 2.0, 104.0, "zoo", p.fonts.hero, theme::INK);
    kit::text(p, MARGIN, 226.0, str(tag.scientific, " ", tag.authority), p.fonts.italic, theme::INK);
    kit::text(p, MARGIN, 256.0, "Minecraft: Java Edition, rewritten in Goose. This launcher prepares the", p.fonts.body, theme::MUTED);
    kit::text(p, MARGIN, 278.0, "resources the zoo client reads from your own copy of the game.", p.fonts.body, theme::MUTED);

    // The version pill and the main action.
    let bw = 150.0;
    let bx = w - MARGIN - bw;
    let label = if !has { "Prepare" } else if s.busy { "Preparing..." }
                else if s.rows[s.selected].ready { "Prepare again" } else { "Prepare" };
    if kit::button(p, kit::r(bx, 316.0, bw, 42.0), label, kit::PRIMARY, has && !s.busy) { want = WANT_OBTAIN; }
    let pill = if has { str(s.rows[s.selected].id, "    ") } else { str("Choose a version    ") };
    let pw = kit::width(p.fonts.medium, pill) + 36.0;
    let px = bx - pw - 10.0;
    if kit::button(p, kit::r(px, 316.0, pw, 42.0), pill, kit::QUIET, true) { s.page = PAGE_VERSIONS; }
    kit::chevron(p, px + pw - 28.0, 335.0);
    if s.busy || s.stage == collection::STAGE_DONE {
        let part = if s.stage >= collection::STAGE_DONE { 5.0 } else { s.stage as f32 };
        kit::progress(p, kit::r(bx - pw - 10.0, 368.0, pw + 10.0 + bw, 3.0), part, 5.0);
    }

    // The numbered checklist.
    var y: f32 = 392.0;
    kit::line(p, MARGIN, w - MARGIN, y);
    let ready = has && s.rows[s.selected].ready;
    let res_text = if !has { str("Choose a version first.") }
                   else if ready { str("Prepared for Minecraft ", s.rows[s.selected].id) }
                   else { str("Not prepared yet for Minecraft ", s.rows[s.selected].id) };
    if row_item(p, y, w, "01", "Resources", res_text, if ready { theme::LEAF } else { theme::MUTED },
                if ready { "Prepare again" } else { "Prepare" }, has && !s.busy) { want = WANT_OBTAIN; }
    y += 66.0;
    let mc_text = if s.game_found { str("Found at ", s.game_dir) }
                  else { str("Not found at ", s.game_dir, ". zoo downloads the game from Mojang instead.") };
    if row_item(p, y, w, "02", "Minecraft folder", mc_text, theme::MUTED, "Look again", !s.busy) { want = WANT_REFRESH; }
    y += 66.0;
    let status_color = if s.stage == collection::STAGE_FAILED { theme::RUST }
                       else if s.stage == collection::STAGE_DONE { theme::LEAF } else { theme::MUTED };
    let status_text = if s.status.len > 0 { str(s.status) } else { str("Your collection is kept in ", s.home) };
    row_item(p, y, w, "03", "Collection", status_text, status_color, "", false);
    want
}

fn draw_versions(p: const kit::Pen&, s: State&, w: f32, h: f32) {
    kit::text(p, MARGIN, 112.0, "Versions", p.fonts.title, theme::INK);
    var x = MARGIN;
    let cw1, t1 = kit::chip(p, x, 196.0, "Releases", s.filters.releases);
    if t1 { s.filters.releases = !s.filters.releases; }
    x += cw1 + 8.0;
    let cw2, t2 = kit::chip(p, x, 196.0, "Snapshots", s.filters.snapshots);
    if t2 { s.filters.snapshots = !s.filters.snapshots; }
    x += cw2 + 8.0;
    let cw3, t3 = kit::chip(p, x, 196.0, "On this computer", s.filters.installed_only);
    if t3 { s.filters.installed_only = !s.filters.installed_only; }
    kit::text_right(p, w - MARGIN, 202.0, s.list_note, p.fonts.small, theme::MUTED);

    let top = 244.0;
    let bottom = h - 60.0;
    let row_h = 48.0;
    kit::line(p, MARGIN, w - MARGIN, top);
    var shown = 0;
    for r in s.rows { if visible(r, s.filters) { shown++; } }
    let list_box = kit::r(MARGIN, top, w - 2.0 * MARGIN, bottom - top);
    if kit::hovered(p, list_box) { s.scroll -= ui::input_mouse(p.ctx).scroll_delta.y * 40.0; }
    s.scroll = clamp(s.scroll, 0.0, max(0.0, shown * row_h - (bottom - top)));

    ui::push_scissor(p.ctx, list_box);
    var y = top - s.scroll;
    for r, i in s.rows {
        if !visible(r, s.filters) { continue; }
        if y + row_h > top && y < bottom {
            let box = kit::r(MARGIN, y + 1.0, w - 2.0 * MARGIN, row_h - 1.0);
            let picked = i == s.selected;
            if picked || kit::hovered(p, box) { ui::fill_rect(p.ctx, box, 8.0, if picked { theme::SURFACE_HOVER } else { theme::SURFACE }); }
            if picked { ui::fill_rect(p.ctx, kit::r(MARGIN, y + 14.0, 3.0, 20.0), 1.5, theme::ACCENT); }
            kit::text(p, MARGIN + 18.0, y + 14.0, r.id, p.fonts.medium, theme::INK);
            kit::text(p, MARGIN + 220.0, y + 17.0, upper(r.kind), p.fonts.mono, theme::FAINT);
            kit::text(p, MARGIN + 340.0, y + 15.0, r.released[..min(r.released.len, 10)], p.fonts.small, theme::MUTED);
            if r.ready { kit::text_right(p, w - MARGIN - 18.0, y + 17.0, "READY", p.fonts.mono, theme::LEAF); }
            else if r.local_jar.len > 0 { kit::text_right(p, w - MARGIN - 18.0, y + 17.0, "ON THIS COMPUTER", p.fonts.mono, theme::ACCENT); }
            if kit::clicked(p, box) && y >= top && y + row_h <= bottom + row_h / 2.0 { s.selected = i; s.page = PAGE_PLAY; }
        }
        y += row_h;
    }
    ui::push_scissor(p.ctx, kit::r(0.0, 0.0, w, h));
    if shown == 0 { kit::text(p, MARGIN + 18.0, top + 16.0, "Nothing matches these filters.", p.fonts.body, theme::MUTED); }
}

fn draw_about(p: const kit::Pen&, s: const State&, w: f32) {
    let t = specimen::current();
    kit::text(p, MARGIN, 112.0, "Specimen", p.fonts.title, theme::INK);
    kit::text(p, MARGIN, 192.0, str(t.scientific, " ", t.authority), p.fonts.italic, theme::INK);
    var y: f32 = 236.0;
    kit::line(p, MARGIN, w - MARGIN, y);
    let names: const u8[:][7] = ["Common name", "Version", "Accession", "Locality", "Collected", "Prep.", "Collection"];
    let values: const u8[:][7] = [t.common, t.version, t.accession, s.locality, t.collected, t.preparator, s.home];
    for n, i in names {
        kit::text(p, MARGIN, y + 14.0, upper(n), p.fonts.mono, theme::FAINT);
        kit::text(p, MARGIN + 200.0, y + 12.0, values[i], p.fonts.body, theme::INK);
        y += 44.0;
        kit::line(p, MARGIN, w - MARGIN, y);
    }
    kit::text(p, MARGIN, y + 24.0, "Not an official Minecraft product. Not approved by or associated with Mojang or Microsoft.", p.fonts.small, theme::FAINT);
}

fn draw(ctx: ui::Context, fonts: const theme::Fonts&, s: State&, w: f32, h: f32) -> i64 {
    var want = WANT_NOTHING;
    if ui::begin(ctx, "zoo", ui::rect(0.0, 0.0, w, h), ui::WINDOW_NO_SCROLLBAR) {
        let p = kit::Pen { ctx: ctx, fonts: fonts };
        // The name, very large and nearly the ground's colour, under the play page.
        if s.page == PAGE_PLAY { kit::text(p, MARGIN - 18.0, h - 300.0, "zoo", fonts.watermark, theme::WATERMARK); }
        draw_nav(p, s, w);
        if s.page == PAGE_PLAY { want = draw_play(p, s, w, h); }
        else if s.page == PAGE_VERSIONS { draw_versions(p, s, w, h); }
        else { draw_about(p, s, w); }
        let t = specimen::current();
        kit::text(p, MARGIN, h - 34.0, str("LAUNCHER ", t.version, "  ·  ", upper(t.scientific)), fonts.mono, theme::FAINT);
        kit::text_right(p, w - MARGIN, h - 34.0, upper(s.locality), fonts.mono, theme::FAINT);
    }
    ui::end(ctx);
    want
}
