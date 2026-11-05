// What the launcher window draws each frame. It reads the state, draws on
// the canvas through kit, and returns what the user asked for; the main
// loop decides what happens, so the view has no side effects of its own.
import std;
import os;
import ui;
import zoo.specimen;
import zoo.collection;
import zoo.app.palette;
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
let WANT_THEME = 3;      // State.theme_pick holds which

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
    theme_pick: i64,
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

// Block heights of the skyline behind the title, in 16 px steps. Fixed
// rather than random so every frame and every screenshot draws the same.
let SKYLINE: i64[24] = [3, 5, 4, 8, 6, 6, 11, 9, 4, 7, 13, 10, 6, 5, 9, 12, 8, 4, 6, 10, 7, 5, 3, 4];
let BLOCK: f32 = 16.0;

fn draw_stage(p: const kit::Pen&, w: f32, bottom: f32) {
    kit::glow(p, kit::r(w * 0.3, 0.0, w * 0.7, bottom), theme::GLOW);
    let x0 = w * 0.5;
    let cols = ((w - MARGIN - x0) / BLOCK) as i64;
    var i = 0;
    while i < cols {
        let blocks = SKYLINE[i % SKYLINE.len];
        let bh = blocks as f32 * BLOCK;
        ui::fill_rect(p.ctx, kit::r(x0 + (i as f32) * BLOCK, bottom - bh, BLOCK, bh), 0.0, theme::SKYLINE);
        i++;
    }
}

// One card of the panel: a coloured band with the step number, then what
// the step is about and the single thing the player can do there.
struct Card {
    n: const u8[:],
    title: const u8[:],
    detail: const u8[:],
    detail_color: ui::Color,
    band: ui::Color,
    action: const u8[:],
    enabled: bool,
}

fn draw_card(p: const kit::Pen&, box: ui::Rect, c: const Card&) -> bool {
    ui::fill_rect(p.ctx, box, 12.0, theme::SURFACE);
    let band = kit::r(box.x, box.y, box.w, 92.0);
    ui::fill_rect(p.ctx, band, 12.0, c.band);
    kit::text(p, box.x + 18.0, box.y + 8.0, c.n, p.fonts.title, theme::INK);
    kit::text(p, box.x + 18.0, box.y + 108.0, c.title, p.fonts.medium, theme::INK);
    var d: u8[>..] = [];
    kit::fit(d, c.detail, p.fonts.small, box.w - 36.0);
    kit::text(p, box.x + 18.0, box.y + 134.0, d, p.fonts.small, c.detail_color);
    var hit = false;
    if c.action.len > 0 {
        hit = kit::button(p, kit::r(box.x + 18.0, box.y + box.h - 40.0, box.w - 36.0, 26.0), c.action, kit::LINK, c.enabled);
    }
    hit
}

fn draw_play(p: const kit::Pen&, s: State&, w: f32, h: f32) -> i64 {
    var want = WANT_NOTHING;
    let tag = specimen::current();
    let has = s.selected >= 0 && s.selected < s.rows.len;
    let panel_h: f32 = 250.0;
    let panel_y = max(452.0, h - 80.0 - panel_h);
    draw_stage(p, w, panel_y - 28.0);

    // The name, with the sand dot of the mark where Gigacat puts its plus.
    let zw = kit::text(p, MARGIN - 4.0, 84.0, "zoo", p.fonts.hero, theme::INK);
    ui::fill_circle(p.ctx, kit::r(MARGIN + zw + 6.0, 124.0, 22.0, 22.0), theme::ACCENT);

    // Facts about the chosen version as pills; the first one opens Versions.
    var x = MARGIN;
    let vlabel = if has { str("Minecraft ", s.rows[s.selected].id) } else { str("Choose a version") };
    let vw = kit::pill(p, x, 206.0, vlabel, theme::INK, true);
    if kit::clicked(p, kit::r(x, 206.0, vw, 28.0)) { s.page = PAGE_VERSIONS; }
    x += vw + 8.0;
    if has {
        let row = s.rows[s.selected];
        let word, color = readiness(row, s);
        x += kit::pill(p, x, 206.0, word, color, false) + 8.0;
        x += kit::pill(p, x, 206.0, upper(row.kind), theme::MUTED, false) + 8.0;
    }
    kit::pill(p, x, 206.0, tag.scientific, theme::MUTED, false);

    kit::text(p, MARGIN, 254.0, "Minecraft: Java Edition, rewritten in Goose. This launcher prepares the", p.fonts.body, theme::MUTED);
    kit::text(p, MARGIN, 276.0, "resources the zoo client reads from your own copy of the game.", p.fonts.body, theme::MUTED);

    // The main action and, beside it, looking for the game again.
    let label = if !has { "Prepare" } else if s.busy { "Preparing..." }
                else if s.rows[s.selected].ready { "Prepare again" } else { "Prepare" };
    let bw: f32 = 200.0;
    if kit::play_button(p, kit::r(MARGIN, 318.0, bw, 48.0), label, has && !s.busy) { want = WANT_OBTAIN; }
    if kit::refresh_button(p, kit::r(MARGIN + bw + 10.0, 318.0, 48.0, 48.0), !s.busy) { want = WANT_REFRESH; }
    if s.busy || s.stage == collection::STAGE_DONE {
        let part = if s.stage >= collection::STAGE_DONE { 5.0 } else { s.stage as f32 };
        kit::progress(p, kit::r(MARGIN, 380.0, bw + 58.0, 3.0), part, 5.0);
    }
    kit::line(p, MARGIN, w * 0.45, panel_y - 28.0);

    // The panel: what preparing needs, one card per step.
    let panel = kit::r(MARGIN, panel_y, w - 2.0 * MARGIN, panel_h);
    ui::fill_rect(p.ctx, panel, 16.0, theme::PANEL);
    ui::stroke_rect(p.ctx, panel, 16.0, 1.0, theme::LINE);
    let gap: f32 = 14.0;
    let cw = (panel.w - 2.0 * gap - 2.0 * 16.0) / 3.0;
    let ch = panel_h - 32.0;
    let cy = panel_y + 16.0;

    let ready = has && s.rows[s.selected].ready;
    let res_text = if !has { str("Choose a version first.") }
                   else if ready { str("Prepared for Minecraft ", s.rows[s.selected].id) }
                   else { str("Not prepared yet for Minecraft ", s.rows[s.selected].id) };
    let c1 = Card { n: "01", title: "Resources", detail: res_text,
                    detail_color: if ready { theme::LEAF } else { theme::MUTED }, band: theme::BAND_ACCENT,
                    action: if ready { "Prepare again" } else { "Prepare" }, enabled: has && !s.busy };
    if draw_card(p, kit::r(MARGIN + 16.0, cy, cw, ch), c1) { want = WANT_OBTAIN; }

    let mc_text = if s.game_found { str("Found at ", s.game_dir) }
                  else { str("Not found at ", s.game_dir, ". zoo downloads the game from Mojang instead.") };
    let c2 = Card { n: "02", title: "Minecraft folder", detail: mc_text, detail_color: theme::MUTED,
                    band: theme::BAND_LEAF, action: "Look again", enabled: !s.busy };
    if draw_card(p, kit::r(MARGIN + 16.0 + cw + gap, cy, cw, ch), c2) { want = WANT_REFRESH; }

    let status_color = if s.stage == collection::STAGE_FAILED { theme::RUST }
                       else if s.stage == collection::STAGE_DONE { theme::LEAF } else { theme::MUTED };
    let status_text = if s.status.len > 0 { str(s.status) } else { str("Kept in ", s.home) };
    let c3 = Card { n: "03", title: "Collection", detail: status_text, detail_color: status_color,
                    band: theme::BAND_STONE, action: "", enabled: false };
    draw_card(p, kit::r(MARGIN + 16.0 + 2.0 * (cw + gap), cy, cw, ch), c3);
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

fn draw_about(p: const kit::Pen&, s: State&, w: f32) -> i64 {
    var want = WANT_NOTHING;
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
    kit::text(p, MARGIN, y + 20.0, "THEME", p.fonts.mono, theme::FAINT);
    var cx = MARGIN + 200.0;
    for t, i in palette::PALETTES {
        let cw, hit = kit::chip(p, cx, y + 12.0, t.palette_name, i == theme::CURRENT);
        if hit && i != theme::CURRENT { s.theme_pick = i; want = WANT_THEME; }
        cx += cw + 8.0;
    }
    y += 52.0;
    kit::line(p, MARGIN, w - MARGIN, y);
    kit::text(p, MARGIN, y + 24.0, "Not an official Minecraft product. Not approved by or associated with Mojang or Microsoft.", p.fonts.small, theme::FAINT);
    want
}

fn draw(ctx: ui::Context, fonts: const theme::Fonts&, s: State&, w: f32, h: f32) -> i64 {
    var want = WANT_NOTHING;
    if ui::begin(ctx, "zoo", ui::rect(0.0, 0.0, w, h), ui::WINDOW_NO_SCROLLBAR) {
        let p = kit::Pen { ctx: ctx, fonts: fonts };
        draw_nav(p, s, w);
        if s.page == PAGE_PLAY { want = draw_play(p, s, w, h); }
        else if s.page == PAGE_VERSIONS { draw_versions(p, s, w, h); }
        else { want = draw_about(p, s, w); }
        let t = specimen::current();
        kit::text(p, MARGIN, h - 34.0, str("LAUNCHER ", t.version, "  ·  ", upper(t.scientific)), fonts.mono, theme::FAINT);
        kit::text_right(p, w - MARGIN, h - 34.0, upper(s.locality), fonts.mono, theme::FAINT);
    }
    ui::end(ctx);
    want
}
