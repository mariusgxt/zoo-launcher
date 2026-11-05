// The specimen label, where the concept has its account page. The profile
// card, the row of figures and the strip of saved skins all map onto what
// zoo actually has: the release it is, what it has collected, and the
// themes it can wear.
import std;
import ui;
import zoo.specimen;
import zoo.app.palette;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace label;

// One figure of the row: a big number with its name under it.
fn draw_figure(p: const kit::Pen&, x: f32, y: f32, value: const u8[:], name: const u8[:]) {
    kit::text(p, x, y, value, p.fonts.medium, theme::INK);
    kit::text(p, x, y + 22.0, state::upper(name), p.fonts.tiny, theme::FAINT);
}

fn draw(p: const kit::Pen&, s: state::State&, w: f32, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    let t = specimen::current();
    let x = state::content_x();
    let panel = kit::r(x, state::TOP_H + 12.0, w - x - state::EDGE, h - state::TOP_H - 12.0 - state::EDGE - 34.0);
    ui::fill_rect(p.ctx, panel, 20.0, theme::PANEL);
    ui::stroke_rect(p.ctx, panel, 20.0, 1.0, theme::LINE);

    // The card: the mark, the name of the release and its authority.
    let card = kit::r(panel.x + 24.0, panel.y + 24.0, panel.w * 0.62 - 36.0, 190.0);
    ui::fill_rect(p.ctx, card, 16.0, theme::SURFACE);
    let tile = kit::r(card.x + 20.0, card.y + 20.0, 76.0, 76.0);
    ui::fill_rect(p.ctx, tile, 18.0, theme::CHIP);
    kit::mark(p, tile);
    kit::text(p, tile.x + tile.w + 20.0, card.y + 24.0, t.scientific, p.fonts.medium, theme::INK);
    kit::text(p, tile.x + tile.w + 20.0, card.y + 46.0, str(t.common, " · ", t.authority), p.fonts.small, theme::MUTED);
    let acc_w = kit::width(p.fonts.tiny, t.accession) + 20.0;
    ui::fill_rect(p.ctx, kit::r(tile.x + tile.w + 20.0, card.y + 70.0, acc_w, 20.0), 10.0, theme::BAND_ACCENT);
    kit::text(p, tile.x + tile.w + 30.0, card.y + 74.0, t.accession, p.fonts.tiny, theme::INK);

    draw_figure(p, card.x + 24.0, card.y + 122.0, t.version, "Version");
    draw_figure(p, card.x + 134.0, card.y + 122.0, t.collected, "Collected");
    draw_figure(p, card.x + 270.0, card.y + 122.0, s.locality, "Locality");
    draw_figure(p, card.x + 380.0, card.y + 122.0, t.preparator, "Preparator");

    // Where the concept keeps saved skins, zoo keeps the themes it wears.
    let skins = kit::r(card.x + card.w + 24.0, panel.y + 24.0, panel.x + panel.w - 24.0 - (card.x + card.w + 24.0), 190.0);
    ui::fill_rect(p.ctx, skins, 16.0, theme::SURFACE);
    kit::text(p, skins.x + 20.0, skins.y + 18.0, "THEMES", p.fonts.tiny, theme::FAINT);
    var cx = skins.x + 20.0;
    for pal, i in palette::PALETTES {
        let box = kit::r(cx, skins.y + 46.0, 104.0, 118.0);
        let on = i == theme::CURRENT;
        ui::fill_rect(p.ctx, box, 14.0, pal.panel);
        ui::stroke_rect(p.ctx, box, 14.0, if on { 2.0 } else { 1.0 }, if on { pal.accent } else { theme::LINE });
        ui::fill_rect(p.ctx, kit::r(box.x + 16.0, box.y + 18.0, box.w - 32.0, 40.0), 10.0, pal.accent);
        ui::fill_rect(p.ctx, kit::r(box.x + 16.0, box.y + 64.0, box.w - 32.0, 10.0), 5.0, pal.leaf);
        ui::fill_rect(p.ctx, kit::r(box.x + 16.0, box.y + 80.0, (box.w - 32.0) * 0.6, 10.0), 5.0, pal.muted);
        kit::text(p, box.x + 16.0, box.y + 96.0, pal.palette_name, p.fonts.small,
                  if on { theme::INK } else { theme::MUTED });
        if kit::clicked(p, box) && !on { s.theme_pick = i; want = state::WANT_THEME; }
        cx += 116.0;
    }

    // The label itself, written out the way a museum tag reads.
    let tag = kit::r(panel.x + 24.0, card.y + card.h + 20.0, panel.w - 48.0,
                     panel.y + panel.h - 20.0 - (card.y + card.h + 20.0));
    ui::fill_rect(p.ctx, tag, 16.0, theme::SURFACE);
    kit::text(p, tag.x + 20.0, tag.y + 18.0, "SPECIMEN LABEL", p.fonts.tiny, theme::FAINT);
    let names: const u8[:][6] = ["Scientific name", "Common name", "Authority", "Accession", "Collected", "Preparator"];
    let values: const u8[:][6] = [t.scientific, t.common, t.authority, t.accession, t.collected, t.preparator];
    var y = tag.y + 46.0;
    for n, i in names {
        if y + 26.0 < tag.y + tag.h - 36.0 {
            kit::text(p, tag.x + 20.0, y, state::upper(n), p.fonts.tiny, theme::FAINT);
            kit::text(p, tag.x + 220.0, y - 2.0, values[i], p.fonts.body, theme::INK);
            y += 28.0;
        }
    }
    kit::text(p, tag.x + 20.0, tag.y + tag.h - 28.0,
              "Not an official Minecraft product. Not approved by or associated with Mojang or Microsoft.",
              p.fonts.small, theme::FAINT);
    want
}
