// The frame every page sits in: the ground behind it and the sidebar down
// the left. The sidebar follows the Zenith client's rail of named pages and
// the near-black panels of HQLauncher (both credited in
// THIRD_PARTY_NOTICES.md), with zoo's own mark, facts and footer.
import std;
import ui;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace chrome;

// The ground: a near-black field with one soft wash of the accent at the top,
// which is where the hero image of the Play page meets it.
fn draw_ground(p: const kit::Pen&, w: f32, h: f32) {
    ui::fill_rect(p.ctx, kit::r(0.0, 0.0, w, h), 0.0, theme::BG);
    kit::veil_v(p, kit::r(0.0, 0.0, w, min(360.0, h * 0.45)),
                kit::with_alpha(theme::ACCENT, 12), theme::NONE);
}

let RAIL_PAGES: i64[6] = [state::PAGE_PLAY, state::PAGE_VERSIONS, state::PAGE_CONTENT,
                          state::PAGE_WORLDS, state::PAGE_SETTINGS, state::PAGE_SPECIMEN];
let RAIL_LABELS: const u8[:][6] = ["Play", "Versions", "Content", "Worlds", "Setup", "Label"];

// The card under the mark: the version zoo would prepare, or the one it
// has nothing for. It is the sidebar's stand-in for the concept's account.
fn draw_chosen(p: const kit::Pen&, s: const state::State&) -> f32, f32 {
    let x = 20.0;
    let y = 104.0;
    let w = state::SIDEBAR_W - 40.0;
    let box = kit::r(x, y, w, 66.0);
    ui::fill_rect(p.ctx, box, 12.0, theme::SURFACE);
    ui::stroke_rect(p.ctx, box, 12.0, 1.0, theme::LINE);

    let tile = kit::r(x + 12.0, y + 15.0, 36.0, 36.0);
    ui::fill_rect(p.ctx, tile, 10.0, theme::BAND_STONE);
    kit::glyph(p, tile.x + 18.0, tile.y + 18.0, kit::GLYPH_CONTENT,
               if s.busy { theme::ACCENT } else { theme::MUTED });

    let has = state::chosen(s);
    var id: u8[>..] = [];
    if has { kit::fit(id, s.rows[s.selected].id, p.fonts.medium, w - 70.0); }
    else { id.append("No version"); }
    kit::text(p, x + 58.0, y + 14.0, id, p.fonts.medium, if has { theme::INK } else { theme::MUTED });

    var word: const u8[:] = "NO VERSION CHOSEN";
    var color = theme::FAINT;
    if has { word, color = state::readiness(s.rows[s.selected], s); }
    kit::text(p, x + 58.0, y + 36.0, word, p.fonts.tiny, color);
    kit::chevron(p, x + w - 24.0, y + 30.0, theme::FAINT);
    return x, y;
}

fn draw_sidebar(p: const kit::Pen&, s: state::State&, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    let w = state::SIDEBAR_W;
    ui::fill_rect(p.ctx, kit::r(0.0, 0.0, w, h), 0.0, theme::PANEL);
    ui::stroke_line(p.ctx, w - 0.5, 0.0, w - 0.5, h, 1.0, theme::LINE);

    // The mark and the name, at the top of the rail.
    let tile = kit::r(24.0, 24.0, 38.0, 38.0);
    ui::fill_rect(p.ctx, tile, 12.0, theme::SURFACE);
    ui::stroke_rect(p.ctx, tile, 12.0, 1.0, theme::LINE);
    kit::mark(p, tile);
    kit::text(p, 74.0, 22.0, "zoo", p.fonts.title, theme::INK);
    kit::text(p, 76.0, 60.0, "MINECRAFT: JAVA EDITION", p.fonts.tiny, theme::FAINT);

    // What is chosen, and what state it is in.
    let chosen_x, chosen_y = draw_chosen(p, s);
    let chosen = kit::r(chosen_x, chosen_y, state::SIDEBAR_W - 40.0, 66.0);
    if kit::clicked(p, chosen) { s.page = state::PAGE_VERSIONS; }

    // The pages, top to bottom.
    let item_h: f32 = 44.0;
    var y: f32 = 192.0;
    for page, i in RAIL_PAGES {
        let box = kit::r(16.0, y, w - 32.0, item_h);
        if kit::nav_item(p, box, RAIL_LABELS[i], kit::glyph_for(page), s.page == page) { s.page = page; }
        y += item_h + 4.0;
    }

    // The foot: the machine zoo found, the clock, and the way out.
    kit::line(p, 20.0, w - 20.0, h - 118.0, theme::LINE);
    ui::fill_circle(p.ctx, kit::r(24.0, h - 94.0, 6.0, 6.0), if s.game_found { theme::LEAF } else { theme::RUST });
    kit::text(p, 38.0, h - 99.0, if s.game_found { "Minecraft found" } else { "Minecraft not found" },
              p.fonts.small, theme::MUTED);
    kit::text_right(p, w - 24.0, h - 99.0, state::clock_text(s.minutes), p.fonts.tiny, theme::FAINT);

    let quit = kit::r(16.0, h - 68.0, w - 32.0, 40.0);
    if kit::nav_item(p, quit, "Quit", kit::GLYPH_QUIT, false) { want = state::WANT_QUIT; }
    want
}
