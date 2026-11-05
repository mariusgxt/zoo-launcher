// The specimen label, where the concept has its account page. The profile
// card, the row of figures and the strip of saved skins all map onto what
// zoo actually has: the release it is, what it collected, and the themes it
// can wear.
import std;
import ui;
import zoo.specimen;
import zoo.app.palette;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace label;

// One figure of the row: a value with its name under it.
fn draw_figure(p: const kit::Pen&, x: f32, y: f32, value: const u8[:], name: const u8[:]) {
    kit::text(p, x, y, value, p.fonts.medium, theme::INK);
    kit::text(p, x, y + 20.0, state::upper(name), p.fonts.tiny, theme::FAINT);
}

fn draw(p: const kit::Pen&, s: state::State&, w: f32, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    let t = specimen::current();
    let x = state::content_x();
    let right = state::content_right(w);
    let bottom = state::body_bottom(h);
    let cw = right - x;

    state::page_heading(p, x, 30.0, "Label",
                        "The specimen this build is catalogued under, and the tag a museum would write.");

    // The card: the mark, the name of the release and its authority.
    let card = kit::r(x, 120.0, cw * 0.62, 224.0);
    ui::fill_rect(p.ctx, card, 16.0, theme::SURFACE);
    ui::stroke_rect(p.ctx, card, 16.0, 1.0, theme::LINE);

    let tile = kit::r(card.x + 24.0, card.y + 24.0, 84.0, 84.0);
    ui::fill_rect(p.ctx, tile, 20.0, theme::ACCENT_SOFT);
    kit::mark(p, tile);

    kit::text(p, tile.x + 104.0, card.y + 26.0, t.scientific, p.fonts.heading, theme::INK);
    kit::text(p, tile.x + 104.0, card.y + 54.0, str(t.common, "  ·  ", t.authority),
              p.fonts.small, theme::MUTED);
    let acc_w = kit::width(p.fonts.tiny, t.accession) + 24.0;
    ui::fill_rect(p.ctx, kit::r(tile.x + 104.0, card.y + 78.0, acc_w, 24.0), 12.0, theme::CHIP);
    kit::text(p, tile.x + 116.0, card.y + 83.0, t.accession, p.fonts.tiny, theme::INK);

    let fy = card.y + 150.0;
    draw_figure(p, card.x + 24.0, fy, t.version, "Version");
    draw_figure(p, card.x + 148.0, fy, t.collected, "Collected");
    draw_figure(p, card.x + 300.0, fy, s.locality, "Locality");
    draw_figure(p, card.x + 430.0, fy, t.preparator, "Preparator");

    // Where the concept keeps saved skins, zoo keeps the themes it wears.
    let skins = kit::r(card.x + card.w + 20.0, 120.0, cw - card.w - 20.0, 224.0);
    ui::fill_rect(p.ctx, skins, 16.0, theme::SURFACE);
    ui::stroke_rect(p.ctx, skins, 16.0, 1.0, theme::LINE);
    kit::text(p, skins.x + 22.0, skins.y + 20.0, "THEMES", p.fonts.tiny, theme::FAINT);
    kit::text(p, skins.x + 22.0, skins.y + 40.0, "What the launcher wears.", p.fonts.small, theme::MUTED);
    let sw = (skins.w - 44.0 - 20.0) / 3.0;
    var cx = skins.x + 22.0;
    for pal, i in palette::PALETTES {
        let box = kit::r(cx, skins.y + 72.0, sw, 130.0);
        let on = i == theme::CURRENT;
        let over = kit::hovered(p, box);
        ui::fill_rect(p.ctx, box, 12.0, if over { pal.surface_hover } else { pal.panel });
        ui::stroke_rect(p.ctx, box, 12.0, if on { 1.5 } else { 1.0 }, if on { pal.accent } else { theme::LINE });
        ui::fill_rect(p.ctx, kit::r(box.x + 12.0, box.y + 16.0, box.w - 24.0, 38.0), 8.0, pal.accent);
        ui::fill_rect(p.ctx, kit::r(box.x + 12.0, box.y + 62.0, box.w - 24.0, 8.0), 4.0, pal.leaf);
        ui::fill_rect(p.ctx, kit::r(box.x + 12.0, box.y + 76.0, (box.w - 24.0) * 0.6, 8.0), 4.0, pal.muted);
        kit::text(p, box.x + 12.0, box.y + 96.0, pal.palette_name, p.fonts.small,
                  if on { theme::INK } else { theme::MUTED });
        if kit::clicked(p, box) && !on { s.theme_pick = i; want = state::WANT_THEME; }
        cx += sw + 10.0;
    }

    // The label itself, written out the way a museum tag reads.
    let tag = kit::r(x, 364.0, cw, bottom - 364.0);
    ui::fill_rect(p.ctx, tag, 16.0, theme::PANEL);
    ui::stroke_rect(p.ctx, tag, 16.0, 1.0, theme::LINE);
    kit::text(p, tag.x + 28.0, tag.y + 24.0, "SPECIMEN LABEL", p.fonts.tiny, theme::FAINT);
    kit::text(p, tag.x + 28.0, tag.y + 44.0, "The tag a museum would write for this build.",
              p.fonts.small, theme::MUTED);

    let col2 = tag.x + tag.w / 2.0;
    var ry = tag.y + 96.0;
    kit::text(p, tag.x + 28.0, ry, "SCIENTIFIC NAME", p.fonts.tiny, theme::FAINT);
    kit::text(p, tag.x + 240.0, ry - 4.0, t.scientific, p.fonts.small, theme::INK);
    kit::text(p, col2 + 28.0, ry, "ACCESSION", p.fonts.tiny, theme::FAINT);
    kit::text(p, col2 + 200.0, ry - 4.0, t.accession, p.fonts.small, theme::INK);
    ry += 52.0;
    kit::text(p, tag.x + 28.0, ry, "COMMON NAME", p.fonts.tiny, theme::FAINT);
    kit::text(p, tag.x + 240.0, ry - 4.0, t.common, p.fonts.small, theme::INK);
    kit::text(p, col2 + 28.0, ry, "COLLECTED", p.fonts.tiny, theme::FAINT);
    kit::text(p, col2 + 200.0, ry - 4.0, t.collected, p.fonts.small, theme::INK);
    ry += 52.0;
    kit::text(p, tag.x + 28.0, ry, "AUTHORITY", p.fonts.tiny, theme::FAINT);
    kit::text(p, tag.x + 240.0, ry - 4.0, t.authority, p.fonts.small, theme::INK);
    kit::text(p, col2 + 28.0, ry, "PREPARATOR", p.fonts.tiny, theme::FAINT);
    kit::text(p, col2 + 200.0, ry - 4.0, t.preparator, p.fonts.small, theme::INK);

    kit::line(p, tag.x + 28.0, tag.x + tag.w - 28.0, ry + 34.0, theme::LINE);
    kit::text(p, tag.x + 28.0, ry + 50.0,
              "Every release is named after a specimen: the scientific name is the build, the",
              p.fonts.small, theme::MUTED);
    kit::text(p, tag.x + 28.0, ry + 68.0,
              "accession number is its place in the collection. zoo ships no Minecraft content.",
              p.fonts.small, theme::MUTED);
    return want;
}
