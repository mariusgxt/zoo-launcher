// The settings page. The concept keeps appearance at the top and the rest
// in labelled blocks; the colour swatches are the HQLauncher concept's way
// of choosing an accent, which suits zoo's themes exactly.
import std;
import ui;
import zoo.app.palette;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace settings;

// One labelled line in a block: a name on the left, a value on the right.
fn draw_line(p: const kit::Pen&, x: f32, y: f32, w: f32, name: const u8[:], value: const u8[:], color: ui::Color) {
    kit::text(p, x, y, name, p.fonts.body, theme::MUTED);
    var v: u8[>..] = [];
    kit::fit(v, value, p.fonts.body, w - 240.0);
    kit::text(p, x + 230.0, y, v, p.fonts.body, color);
}

fn draw_block(p: const kit::Pen&, box: ui::Rect, title: const u8[:]) {
    ui::fill_rect(p.ctx, box, 16.0, theme::SURFACE);
    kit::text(p, box.x + 20.0, box.y + 16.0, state::upper(title), p.fonts.tiny, theme::FAINT);
}

fn draw(p: const kit::Pen&, s: state::State&, w: f32, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    let x = state::content_x();
    let panel = kit::r(x, state::TOP_H + 12.0, w - x - state::EDGE, h - state::TOP_H - 12.0 - state::EDGE - 34.0);
    ui::fill_rect(p.ctx, panel, 20.0, theme::PANEL);
    ui::stroke_rect(p.ctx, panel, 20.0, 1.0, theme::LINE);
    state::page_heading(p, panel.x + 24.0, panel.y + 24.0, "Setup",
                        "How the launcher looks, and where it keeps things.",
                        "Your choice of theme is remembered between starts.");

    let bw = panel.w - 48.0;
    // Appearance, with one swatch per theme.
    let look = kit::r(panel.x + 24.0, panel.y + 102.0, bw, 108.0);
    draw_block(p, look, "Appearance");
    kit::text(p, look.x + 20.0, look.y + 42.0, "Theme", p.fonts.body, theme::MUTED);
    var cx = look.x + 230.0;
    for t, i in palette::PALETTES {
        let box = kit::r(cx, look.y + 38.0, 132.0, 46.0);
        let on = i == theme::CURRENT;
        let over = kit::hovered(p, box);
        ui::fill_rect(p.ctx, box, 14.0, if on { theme::CHIP } else if over { theme::SURFACE_HOVER } else { theme::BG });
        ui::stroke_rect(p.ctx, box, 14.0, 1.0, if on { t.accent } else { theme::LINE });
        ui::fill_circle(p.ctx, kit::r(box.x + 14.0, box.y + 14.0, 18.0, 18.0), t.accent);
        ui::fill_circle(p.ctx, kit::r(box.x + 28.0, box.y + 18.0, 10.0, 10.0), t.leaf);
        kit::text(p, box.x + 50.0, box.y + 15.0, t.palette_name, p.fonts.small,
                  if on { theme::INK } else { theme::MUTED });
        if kit::clicked(p, box) && !on { s.theme_pick = i; want = state::WANT_THEME; }
        cx += 144.0;
    }

    // Folders, which is what someone opens this page to check.
    let folders = kit::r(panel.x + 24.0, look.y + look.h + 16.0, bw, 148.0);
    draw_block(p, folders, "Folders");
    draw_line(p, folders.x + 20.0, folders.y + 44.0, bw, "Collection", s.home, theme::INK);
    draw_line(p, folders.x + 20.0, folders.y + 72.0, bw, "Minecraft", s.game_dir,
              if s.game_found { theme::LEAF } else { theme::RUST });
    draw_line(p, folders.x + 20.0, folders.y + 100.0, bw, "This machine", s.locality, theme::INK);

    // What the launcher is doing, so the page doubles as the report
    // `--check` prints on the command line.
    let work = kit::r(panel.x + 24.0, folders.y + folders.h + 16.0, bw, 120.0);
    draw_block(p, work, "State");
    let versions = str(s.rows.len, " listed, ", state::prepared_count(s), " prepared");
    draw_line(p, work.x + 20.0, work.y + 44.0, bw, "Versions", versions, theme::INK);
    let note = if s.status.len > 0 { str(s.status) } else { str(s.list_note) };
    draw_line(p, work.x + 20.0, work.y + 72.0, bw, "Last step", note, theme::MUTED);
    want
}
