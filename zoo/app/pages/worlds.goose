// The worlds page, where the concept has its map. zoo cannot draw a world
// map in the launcher yet, so each save is a card with what its level.dat
// says, and the region files behind it counted.
import std;
import os;
import ui;
import zoo.world.saves;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace worlds;

// How many region files a save has, which is the only size zoo can give
// cheaply: reading them to measure a world would take as long as loading it.
fn region_count(s: const saves::Save&) -> i64 {
    var names: u8[>..] = [];
    guard list_dir(s.region_dir, names) else { return 0; }
    var n = 0;
    each_split(names, '\n') { name => if ends_with(name, ".mca") { n++; } };
    n
}

fn draw_card(p: const kit::Pen&, box: ui::Rect, s: const saves::Save&) {
    ui::fill_rect(p.ctx, box, 14.0, theme::SURFACE);
    // A patch of ground standing in for the map the concept draws.
    let band = kit::r(box.x, box.y, box.w, box.h * 0.5);
    ui::fill_rect(p.ctx, band, 14.0, theme::BAND_LEAF);
    var i = 0;
    while i < 7 {
        var j = 0;
        while j < 3 {
            let tile = kit::r(band.x + 14.0 + i * 26.0, band.y + 16.0 + j * 22.0, 22.0, 18.0);
            if tile.x + tile.w < band.x + band.w - 10.0 && (i + j + s.version) % 3 != 0 {
                ui::fill_rect(p.ctx, tile, 3.0, theme::BAND_STONE);
            }
            j++;
        }
        i++;
    }
    var name: u8[>..] = [];
    kit::fit(name, s.name, p.fonts.medium, box.w - 32.0);
    kit::text(p, box.x + 16.0, box.y + box.h * 0.5 + 12.0, name, p.fonts.medium, theme::INK);
    kit::text(p, box.x + 16.0, box.y + box.h * 0.5 + 36.0, str("folder ", s.folder), p.fonts.small, theme::FAINT);
    let regions = region_count(s);
    kit::text(p, box.x + 16.0, box.y + box.h - 28.0,
              str(regions, " region files · data version ", s.version), p.fonts.small, theme::MUTED);
}

fn draw(p: const kit::Pen&, s: state::State&, found: const saves::Save[:], w: f32, h: f32) {
    let x = state::content_x();
    let panel = kit::r(x, state::TOP_H + 12.0, w - x - state::EDGE, h - state::TOP_H - 12.0 - state::EDGE - 34.0);
    ui::fill_rect(p.ctx, panel, 20.0, theme::PANEL);
    ui::stroke_rect(p.ctx, panel, 20.0, 1.0, theme::LINE);
    state::page_heading(p, panel.x + 24.0, panel.y + 24.0, "Worlds",
                        "The singleplayer worlds in your Minecraft folder.",
                        "The zoo client reads these; the launcher only lists them.");

    if found.len == 0 {
        kit::empty_note(p, kit::r(panel.x + 24.0, panel.y + 100.0, panel.w - 48.0, 96.0),
                        "No worlds here yet", str("zoo looks in ", s.game_dir, "/saves"));
        return;
    }

    let gap: f32 = 16.0;
    let cols = 3;
    let cw = (panel.w - 48.0 - (cols - 1) * gap) / cols;
    let ch: f32 = 186.0;
    let top = panel.y + 100.0;
    let box = kit::r(panel.x + 24.0, top, panel.w - 48.0, panel.y + panel.h - 20.0 - top);
    if kit::hovered(p, box) { s.scroll -= ui::input_mouse(p.ctx).scroll_delta.y * 40.0; }
    let rows = (found.len + cols - 1) / cols;
    s.scroll = clamp(s.scroll, 0.0, max(0.0, rows * (ch + gap) - box.h));

    ui::push_scissor(p.ctx, box);
    for save, i in found {
        let cx = box.x + (i % cols) * (cw + gap);
        let cy = top + (i / cols) * (ch + gap) - s.scroll;
        if cy + ch > top - ch && cy < box.y + box.h { draw_card(p, kit::r(cx, cy, cw, ch), save); }
    }
    ui::push_scissor(p.ctx, kit::r(0.0, 0.0, w, h));
}
