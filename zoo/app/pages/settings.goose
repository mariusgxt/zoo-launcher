// Setup: the colour scheme, the folders and the state of the collection, in
// one panel with labelled sections and hairline rows, the way HQLauncher's
// settings page is built. The swatches are the same concept's accent row.
import std;
import ui;
import zoo.specimen;
import zoo.app.palette;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace settings;

fn section(p: const kit::Pen&, x: f32, y: f32, title: const u8[:], note: const u8[:]) {
    kit::text(p, x, y, title, p.fonts.heading, theme::INK);
    kit::text(p, x, y + 26.0, note, p.fonts.small, theme::MUTED);
}

// One row of the folder and state lists: a name, a line, and its value.
fn row(p: const kit::Pen&, x: f32, right: f32, y: f32, name: const u8[:], value: const u8[:],
       color: ui::Color) {
    kit::text(p, x, y, name, p.fonts.body, theme::MUTED);
    var v: u8[>..] = [];
    kit::fit(v, value, p.fonts.mono, (right - x) * 0.62);
    kit::text_right(p, right, y + 1.0, v, p.fonts.mono, color);
    kit::line(p, x, right, y + 36.0, theme::LINE);
}

fn draw(p: const kit::Pen&, s: state::State&, w: f32, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    let x = state::content_x();
    let right = state::content_right(w);
    let bottom = state::body_bottom(h);

    state::page_heading(p, x, 30.0, "Setup",
                        "How the launcher looks, and where it keeps the files it prepares.");

    // The label of this build, which otherwise only the Label page carries:
    // a build stamp against the heading, where the page has room.
    let t = specimen::current();
    kit::text_right(p, right, 32.0, str("BUILD ", t.version, "  ·  ", t.accession), p.fonts.tiny, theme::FAINT);
    kit::text_right(p, right, 48.0, t.scientific, p.fonts.small, theme::MUTED);

    let panel = kit::r(x, 120.0, right - x, bottom - 120.0);
    ui::fill_rect(p.ctx, panel, 16.0, theme::PANEL);
    ui::stroke_rect(p.ctx, panel, 16.0, 1.0, theme::LINE);
    let left = panel.x + 28.0;
    let inner_right = panel.x + panel.w - 28.0;

    // Appearance: one card per colour scheme, with a small preview of it.
    section(p, left, panel.y + 26.0, "Appearance", "The colour scheme is remembered between starts.");
    let gap: f32 = 16.0;
    let theme_w = (panel.w - 56.0 - 2.0 * gap) / 3.0;
    var tx = left;
    for t, i in palette::PALETTES {
        let card = kit::r(tx, panel.y + 78.0, theme_w, 104.0);
        let on = i == theme::CURRENT;
        let over = kit::hovered(p, card);
        ui::fill_rect(p.ctx, card, 12.0, if over && !on { theme::SURFACE_HOVER } else { theme::SURFACE });
        ui::stroke_rect(p.ctx, card, 12.0, if on { 1.5 } else { 1.0 }, if on { theme::ACCENT } else { theme::LINE });

        let preview = kit::r(card.x + 14.0, card.y + 14.0, 62.0, 64.0);
        ui::fill_rect(p.ctx, preview, 8.0, t.bg);
        ui::fill_rect(p.ctx, kit::r(preview.x + 10.0, preview.y + 10.0, 42.0, 18.0), 5.0, t.surface);
        ui::fill_rect(p.ctx, kit::r(preview.x + 10.0, preview.y + 34.0, 28.0, 7.0), 3.5, t.accent);
        ui::fill_rect(p.ctx, kit::r(preview.x + 10.0, preview.y + 46.0, 18.0, 7.0), 3.5, t.leaf);

        kit::text(p, card.x + 90.0, card.y + 20.0, t.palette_name, p.fonts.medium, theme::INK);
        kit::text(p, card.x + 90.0, card.y + 42.0, t.note, p.fonts.small, theme::MUTED);
        kit::check(p, card.x + card.w - 24.0, card.y + 24.0, on);
        if kit::clicked(p, card) && !on { s.theme_pick = i; want = state::WANT_THEME; }
        tx += theme_w + gap;
    }

    kit::line(p, left, inner_right, panel.y + 208.0, theme::LINE);

    // Folders, which is what someone opens this page to check.
    section(p, left, panel.y + 230.0, "Folders", "Everything zoo prepares stays on this machine.");
    let fy = panel.y + 288.0;
    row(p, left, inner_right, fy, "Collection", s.home, theme::INK);
    row(p, left, inner_right, fy + 48.0, "Minecraft", s.game_dir,
        if s.game_found { theme::LEAF } else { theme::RUST });
    row(p, left, inner_right, fy + 96.0, "This machine", s.locality, theme::INK);

    kit::line(p, left, inner_right, panel.y + 452.0, theme::LINE);

    // What the launcher knows, so the page doubles as the report `--check`
    // prints on the command line.
    section(p, left, panel.y + 476.0, "State", "What the catalogue and the last step came to.");
    let sy = panel.y + 534.0;
    row(p, left, inner_right, sy, "Versions",
        str(s.rows.len, " listed, ", state::prepared_count(s), " prepared"), theme::INK);
    let note = if s.status.len > 0 { str(s.status) } else { str(s.list_note) };
    row(p, left, inner_right, sy + 48.0, "Last step", note, theme::MUTED);
    return want;
}
