// The worlds page: every save in the Minecraft folder as a card, with a
// little map drawn from its palette and the facts level.dat gave up. The
// concept keeps its instances in a grid like this one.
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

// A little scene from the world: a blocky ridge line, a sun going down, a
// pond and a few trees, laid out from the save's data version so two worlds
// never draw the same picture. It is the world the Play page shows, at
// postcard size.
let FAR_BLOCKS: i64[16] = [3, 4, 3, 5, 4, 3, 6, 4, 3, 5, 4, 6, 3, 4, 5, 3];
let NEAR_BLOCKS: i64[16] = [2, 3, 4, 2, 5, 3, 2, 4, 5, 3, 2, 4, 3, 5, 2, 3];

fn draw_thumb(p: const kit::Pen&, box: ui::Rect, seed: i64) {
    let w = box.w;
    let h = box.h;
    let v = seed % 4;
    let bottom = box.y + h;
    let far_base = box.y + h * 0.60;
    let step: f32 = 11.0;

    // Sky, with the sun low over the ridge.
    kit::veil_v(p, box, kit::mix(theme::BG, theme::ACCENT, 0.05),
                kit::mix(theme::BG, theme::ACCENT, 0.24));
    let sun = kit::r(box.x + w * 0.70, box.y + h * 0.24, 15.0, 15.0);
    ui::fill_circle(p.ctx, kit::r(sun.x - 9.0, sun.y - 9.0, 33.0, 33.0), kit::with_alpha(theme::ACCENT, 30));
    ui::fill_circle(p.ctx, sun, kit::mix(theme::ACCENT, theme::INK, 0.35));

    // The far ridge: columns of eight-pixel blocks, ends at a common base.
    let far = kit::mix(theme::BG, theme::LEAF, 0.16);
    let cols = (w / step) as i64 + 1;
    var i = 0;
    while i < cols {
        let bh: f32 = FAR_BLOCKS[(i + v * 3) % FAR_BLOCKS.len] * 8.0;
        ui::fill_rect(p.ctx, kit::r(box.x + i * step, far_base - bh, step + 0.5, bh + 1.0),
                      0.0, if i % 2 == 0 { far } else { kit::mix(far, theme::BG, 0.10) });
        i++;
    }
    ui::fill_rect(p.ctx, kit::r(box.x, far_base, w, bottom - far_base), 0.0,
                  kit::mix(theme::BG, theme::LEAF, 0.21));

    // The near ridge, in taller blocks.
    let near = kit::mix(theme::BG, theme::LEAF, 0.30);
    i = 0;
    while i < cols {
        let bh: f32 = NEAR_BLOCKS[(i + v * 5) % NEAR_BLOCKS.len] * 9.0;
        ui::fill_rect(p.ctx, kit::r(box.x + i * step, bottom - bh, step + 0.5, bh),
                      0.0, if i % 2 == 0 { near } else { kit::mix(near, theme::BG, 0.08) });
        i++;
    }

    // A pond, on the worlds whose seed says so.
    if seed % 2 == 0 {
        ui::fill_rect(p.ctx, kit::r(box.x + w * 0.10, bottom - 16.0, w * 0.28, 10.0), 4.0,
                      kit::mix(theme::BAND_ACCENT, theme::ACCENT, 0.15));
    }

    // A few trees on the near ridge, in three sizes.
    let trunk = kit::mix(theme::BAND_STONE, theme::INK, 0.16);
    let leaf = kit::mix(theme::LEAF, theme::BG, 0.12);
    var k = 0;
    while k < 3 {
        let tx = box.x + w * (0.20 + k * 0.26 + v * 0.02);
        let hh: f32 = NEAR_BLOCKS[(((tx - box.x) / step) as i64 + v * 5) % NEAR_BLOCKS.len] * 9.0;
        let gy: f32 = bottom - hh + 2.0;
        let s = 0.8 + k * 0.16;
        ui::fill_rect(p.ctx, kit::r(tx, gy - 15.0 * s, 3.0 * s, 15.0 * s), 1.0, trunk);
        ui::fill_rect(p.ctx, kit::r(tx - 8.0 * s, gy - 23.0 * s, 19.0 * s, 8.0 * s), 1.0, leaf);
        ui::fill_rect(p.ctx, kit::r(tx - 5.0 * s, gy - 30.0 * s, 13.0 * s, 8.0 * s), 1.0, leaf);
        ui::fill_rect(p.ctx, kit::r(tx - 2.0 * s, gy - 36.0 * s, 7.0 * s, 7.0 * s), 1.0, leaf);
        k++;
    }

    kit::veil_v(p, kit::r(box.x, box.y + h * 0.78, w, h * 0.22), theme::NONE, kit::with_alpha(theme::BG, 60));
}

fn draw_card(p: const kit::Pen&, box: ui::Rect, save: const saves::Save&) {
    ui::fill_rect(p.ctx, box, 14.0, theme::SURFACE);
    ui::stroke_rect(p.ctx, box, 14.0, 1.0, theme::LINE);

    let thumb = kit::r(box.x + 10.0, box.y + 10.0, box.w - 20.0, 128.0);
    let seed = save.version + save.folder.len * 17 + save.name.len * 7;
    draw_thumb(p, thumb, seed);

    var name: u8[>..] = [];
    kit::fit(name, save.name, p.fonts.medium, box.w - 36.0);
    kit::text(p, box.x + 18.0, box.y + 152.0, name, p.fonts.medium, theme::INK);
    var folder: u8[>..] = [];
    kit::fit(folder, str("folder ", save.folder), p.fonts.small, box.w - 36.0);
    kit::text(p, box.x + 18.0, box.y + 174.0, folder, p.fonts.small, theme::FAINT);

    let regions = region_count(save);
    kit::text(p, box.x + 18.0, box.y + box.h - 28.0,
              str(regions, " region files  ·  data ", save.version), p.fonts.tiny, theme::MUTED);
}

fn draw(p: const kit::Pen&, s: state::State&, found: const saves::Save[:], w: f32, h: f32) {
    let x = state::content_x();
    let right = state::content_right(w);
    let bottom = state::body_bottom(h);
    state::page_heading(p, x, 30.0, "Worlds",
                        "The singleplayer worlds in your Minecraft folder. The client opens them.");
    kit::text_right(p, right, 36.0, str(found.len, " worlds"), p.fonts.small, theme::MUTED);

    if found.len == 0 {
        let panel = kit::r(x, 120.0, right - x, bottom - 120.0);
        ui::fill_rect(p.ctx, panel, 16.0, theme::PANEL);
        ui::stroke_rect(p.ctx, panel, 16.0, 1.0, theme::LINE);
        let cx = panel.x + panel.w / 2.0;
        let tile = kit::r(cx - 28.0, panel.y + panel.h * 0.36, 56.0, 56.0);
        ui::fill_rect(p.ctx, tile, 14.0, theme::SURFACE);
        kit::glyph(p, cx, tile.y + 28.0, kit::GLYPH_WORLDS, theme::FAINT);
        kit::text_mid(p, cx, tile.y + 76.0, "No worlds found", p.fonts.medium, theme::MUTED);
        var where: u8[>..] = [];
        kit::fit(where, str("zoo looks in ", s.game_dir, "/saves"), p.fonts.small, panel.w - 80.0);
        kit::text_mid(p, cx, tile.y + 100.0, where, p.fonts.small, theme::FAINT);
        return;
    }

    let gap: f32 = 18.0;
    let cols = 3;
    let cw = (right - x - (cols - 1) * gap) / cols;
    let ch: f32 = 222.0;
    let top = 120.0;
    let box = kit::r(x, top, right - x, bottom - top);
    if kit::hovered(p, box) { s.scroll -= ui::input_mouse(p.ctx).scroll_delta.y * 44.0; }
    let rows = (found.len + cols - 1) / cols;
    s.scroll = clamp(s.scroll, 0.0, max(0.0, rows * (ch + gap) - box.h));

    ui::push_scissor(p.ctx, box);
    for save, i in found {
        let cx = x + (i % cols) * (cw + gap);
        let cy = top + (i / cols) * (ch + gap) - s.scroll;
        if cy + ch > top - ch && cy < bottom + ch { draw_card(p, kit::r(cx, cy, cw, ch), save); }
    }
    ui::push_scissor(p.ctx, kit::r(0.0, 0.0, w, h));
    kit::scrollbar(p, kit::r(right - 8.0, top, 3.0, bottom - top),
                   rows * (ch + gap) - gap, bottom - top, s.scroll);
}
