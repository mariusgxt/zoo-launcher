// Mods, shaders and resource packs: the concept's three list pages, which
// share a layout and differ only in the folder they read. The sub-tabs on
// the left and the two columns of rows with a switch are the Gigacat
// concept's; the plain table rules come from the HQLauncher concept.
import std;
import ui;
import zoo.minecraft.content;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace shelf;

let KINDS: i64[3] = [content::KIND_MODS, content::KIND_SHADERS, content::KIND_PACKS];

fn draw_row(p: const kit::Pen&, box: ui::Rect, item: content::Item&) -> bool {
    let over = kit::hovered(p, box);
    ui::fill_rect(p.ctx, box, 12.0, if over { theme::SURFACE_HOVER } else { theme::SURFACE });
    // Where the concept shows a mod's icon, zoo shows what the entry is.
    let icon = kit::r(box.x + 10.0, box.y + 10.0, box.h - 20.0, box.h - 20.0);
    ui::fill_rect(p.ctx, icon, 10.0, if item.on { theme::BAND_ACCENT } else { theme::CHIP });
    kit::glyph(p, icon.x + icon.w / 2.0, icon.y + icon.h / 2.0, kit::GLYPH_CONTENT,
               if item.on { theme::INK } else { theme::FAINT });

    var name: u8[>..] = [];
    kit::fit(name, item.name, p.fonts.medium, box.w - 150.0);
    kit::text(p, icon.x + icon.w + 14.0, box.y + 12.0, name, p.fonts.medium,
              if item.on { theme::INK } else { theme::MUTED });
    let what = if item.folder { "folder" } else { "file" };
    let where_it_is = if item.on { str(what, ", switched on") } else { str(what, ", switched off") };
    kit::text(p, icon.x + icon.w + 14.0, box.y + 34.0, where_it_is, p.fonts.small, theme::FAINT);

    kit::toggle(p, box.x + box.w - 60.0, box.y + (box.h - 26.0) / 2.0, item.on)
}

fn draw(p: const kit::Pen&, s: state::State&, items: content::Item[>..]&, w: f32, h: f32) {
    let x = state::content_x();
    let kind = KINDS[s.shelf];

    // The page sits on one panel, as every list page of the concept does.
    let panel = kit::r(x, state::TOP_H + 12.0, w - x - state::EDGE, h - state::TOP_H - 12.0 - state::EDGE - 34.0);
    ui::fill_rect(p.ctx, panel, 20.0, theme::PANEL);
    ui::stroke_rect(p.ctx, panel, 20.0, 1.0, theme::LINE);

    // The sub-tabs down the left of the panel.
    var ty = panel.y + 34.0;
    for k, i in KINDS {
        let tab = kit::r(panel.x + 20.0, ty, 136.0, 34.0);
        let on = i == s.shelf;
        let over = kit::hovered(p, tab);
        if on || over { ui::fill_rect(p.ctx, tab, 12.0, if on { theme::CHIP } else { theme::SURFACE }); }
        let label = content::title_of(k);
        kit::text(p, tab.x + (tab.w - kit::width(p.fonts.small, label)) / 2.0, tab.y + 9.0, label,
                  p.fonts.small, if on { theme::INK } else { theme::MUTED });
        if kit::clicked(p, tab) { s.shelf = i; s.scroll = 0.0; }
        ty += 40.0;
    }

    let list_x = panel.x + 184.0;
    state::page_heading(p, list_x, panel.y + 24.0, content::title_of(kind),
                        content::lead_of(kind), content::lead_two_of(kind));

    let top = panel.y + 96.0;
    let bottom = panel.y + panel.h - 20.0;
    let list_w = panel.x + panel.w - 20.0 - list_x;
    let col_w = (list_w - 16.0) / 2.0;
    let row_h: f32 = 62.0;

    if items.len == 0 {
        kit::text(p, list_x, top + 8.0, str("Nothing in ", content::folder_of(kind), " yet."), p.fonts.body, theme::MUTED);
        kit::text(p, list_x, top + 32.0, str("zoo looks in ", s.game_dir, "/", content::folder_of(kind)), p.fonts.small, theme::FAINT);
        return;
    }

    let rows_per_col = ((bottom - top) / row_h) as i64;
    let box = kit::r(list_x, top, list_w, bottom - top);
    if kit::hovered(p, box) { s.scroll -= ui::input_mouse(p.ctx).scroll_delta.y * 40.0; }
    let pages = max(0.0, (items.len - rows_per_col * 2) as f32 / 2.0 * row_h);
    s.scroll = clamp(s.scroll, 0.0, pages);

    ui::push_scissor(p.ctx, box);
    for item, i in items {
        let col = i % 2;
        let row = i / 2;
        let y = top + row * row_h - s.scroll;
        if y + row_h > top - row_h && y < bottom {
            let rb = kit::r(list_x + col * (col_w + 16.0), y, col_w, row_h - 10.0);
            if draw_row(p, rb, item) { content::set_enabled(item, !item.on); }
        }
    }
    ui::push_scissor(p.ctx, kit::r(0.0, 0.0, w, h));
}
