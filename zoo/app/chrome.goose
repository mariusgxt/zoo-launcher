// The frame every page sits in: the ground behind it, the rail of icons down
// the left, and the bar across the top. It follows the Gigacat launcher
// concept (see THIRD_PARTY_NOTICES.md), with zoo's own pages on the rail.
import std;
import ui;
import zoo.specimen;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace chrome;

// Block heights of the skyline, in 16 px steps. Fixed rather than random so
// every frame, and every screenshot taken for the README, draws the same.
let SKYLINE: i64[40] = [3, 5, 4, 8, 6, 6, 11, 9, 4, 7, 13, 10, 6, 5, 9, 12, 8, 4, 6, 10,
                        7, 5, 3, 4, 9, 11, 6, 8, 5, 12, 7, 4, 10, 6, 9, 3, 7, 11, 5, 8];
let BLOCK: f32 = 16.0;

// The ground: a dark field, a lit corner where the design has its glow, and
// a blocky skyline along the bottom that stands in for the screenshot the
// concept blurs behind its pages.
fn draw_ground(p: const kit::Pen&, w: f32, h: f32) {
    ui::fill_rect(p.ctx, kit::r(0.0, 0.0, w, h), 0.0, theme::BG);
    kit::glow(p, kit::r(w * 0.25, 0.0, w * 0.75, h * 0.8), theme::GLOW);
    let base = h * 0.78;
    let cols = (w / BLOCK) as i64 + 1;
    var i = 0;
    while i < cols {
        let bh = SKYLINE[i % SKYLINE.len] * BLOCK;
        ui::fill_rect(p.ctx, kit::r(i * BLOCK, base - bh, BLOCK, h - base + bh), 0.0, theme::SKYLINE);
        i++;
    }
}

// Which pages the rail offers, top to bottom. Quit sits apart at the foot,
// as the concept's exit icon does.
let RAIL_PAGES: i64[6] = [state::PAGE_PLAY, state::PAGE_VERSIONS, state::PAGE_CONTENT,
                          state::PAGE_WORLDS, state::PAGE_SETTINGS, state::PAGE_SPECIMEN];
let RAIL_LABELS: const u8[:][6] = ["PLAY", "VERSIONS", "CONTENT", "WORLDS", "SETUP", "LABEL"];

fn draw_rail(p: const kit::Pen&, s: state::State&, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    let x = state::EDGE;
    let top = state::TOP_H;
    let rail = kit::r(x, top, state::RAIL_W, h - top - state::EDGE);
    ui::fill_rect(p.ctx, rail, 26.0, theme::SURFACE);

    let item_h: f32 = 62.0;
    var y = top + 16.0;
    for page, i in RAIL_PAGES {
        let box = kit::r(x + 6.0, y, state::RAIL_W - 12.0, item_h);
        let active = s.page == page;
        if kit::rail_item(p, box, RAIL_LABELS[i], kit::glyph_for(page), active) { s.page = page; }
        y += item_h + 2.0;
    }
    // Leaving, at the foot of the rail and set off by a line.
    let quit = kit::r(x + 6.0, h - state::EDGE - 16.0 - item_h, state::RAIL_W - 12.0, item_h);
    kit::line(p, x + 14.0, x + state::RAIL_W - 14.0, quit.y - 10.0);
    if kit::rail_item(p, quit, "QUIT", kit::GLYPH_QUIT, false) { want = state::WANT_QUIT; }
    want
}

// The top bar: the mark, the clock, a badge counting what is prepared, and
// the bar that the concept gives to its server population.
fn draw_top(p: const kit::Pen&, s: const state::State&, w: f32) {
    let tile = kit::r(state::EDGE, state::EDGE, state::RAIL_W - 6.0, state::RAIL_W - 6.0);
    ui::fill_rect(p.ctx, tile, 18.0, theme::SURFACE);
    ui::stroke_rect(p.ctx, tile, 18.0, 1.5, theme::LINE);
    kit::mark(p, tile);

    let x = state::content_x();
    kit::text(p, x, state::EDGE + 18.0, state::clock_text(s.minutes), p.fonts.medium, theme::INK);

    let total = s.rows.len;
    let ready = state::prepared_count(s);
    kit::badge(p, x + 128.0, state::EDGE + 30.0, 27.0, str(ready), str("/", total));

    let bar_x = x + 186.0;
    let bar_w = min(430.0, w - bar_x - 330.0);
    kit::progress(p, kit::r(bar_x, state::EDGE + 26.0, bar_w, 8.0), ready, max(total, 1));
    kit::text_right(p, bar_x + bar_w, state::EDGE + 40.0, "versions prepared", p.fonts.tiny, theme::FAINT);

    // The right end carries what the concept puts there: a state and who is
    // playing. zoo has no accounts, so it names the machine instead.
    let avatar = kit::r(w - state::EDGE - 38.0, state::EDGE + 14.0, 38.0, 38.0);
    ui::fill_rect(p.ctx, avatar, 12.0, theme::CHIP);
    kit::text(p, avatar.x + 11.0, avatar.y + 10.0, "Z", p.fonts.medium, theme::ACCENT);
    let name_w = kit::text_right(p, avatar.x - 14.0, state::EDGE + 24.0, state::upper(s.locality), p.fonts.mono, theme::INK);
    let state_word = if s.game_found { "found" } else { "not found" };
    let state_color = if s.game_found { theme::LEAF } else { theme::RUST };
    let sw = kit::text_right(p, avatar.x - 14.0 - name_w - 18.0, state::EDGE + 24.0, state_word, p.fonts.mono, state_color);
    kit::text_right(p, avatar.x - 14.0 - name_w - 18.0 - sw - 8.0, state::EDGE + 24.0, "Minecraft:", p.fonts.mono, theme::MUTED);
}

// The line of small print along the bottom of every page.
fn draw_foot(p: const kit::Pen&, s: const state::State&, w: f32, h: f32) {
    let t = specimen::current();
    kit::text(p, state::content_x(), h - 26.0,
              str("LAUNCHER ", t.version, "  ·  ", state::upper(t.scientific)), p.fonts.tiny, theme::FAINT);
    kit::text_right(p, w - state::EDGE, h - 26.0, "NOT AN OFFICIAL MINECRAFT PRODUCT", p.fonts.tiny, theme::FAINT);
}
