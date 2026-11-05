// Mods, shaders and resource packs: the three list pages of HQLauncher,
// sharing one toolbar, one hairline table and one switch per row. The zoo
// client does not load content yet, so the page says what a switch really
// does instead of pretending otherwise.
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
    if over { ui::fill_rect(p.ctx, box, 10.0, theme::SURFACE); }
    // Where a loader shows a mod's icon, zoo shows what the entry is.
    let tile = kit::r(box.x + 18.0, box.y + 13.0, 38.0, 38.0);
    ui::fill_rect(p.ctx, tile, 10.0, if item.on { theme::ACCENT_SOFT } else { theme::PANEL });
    kit::glyph(p, tile.x + 19.0, tile.y + 19.0, kit::GLYPH_CONTENT,
               if item.on { theme::ACCENT } else { theme::FAINT });

    var name: u8[>..] = [];
    kit::fit(name, item.name, p.fonts.medium, box.w - 420.0);
    kit::text(p, box.x + 70.0, box.y + 22.0, name, p.fonts.medium,
              if item.on { theme::INK } else { theme::MUTED });
    let what = if item.folder { "folder" } else { "file" };
    kit::text(p, box.x + 430.0, box.y + 24.0, what, p.fonts.small, theme::MUTED);

    kit::text_right(p, box.x + box.w - 82.0, box.y + 24.0,
                    if item.on { "ON" } else { "OFF" }, p.fonts.tiny,
                    if item.on { theme::LEAF } else { theme::FAINT });
    kit::toggle(p, box.x + box.w - 62.0, box.y + (box.h - 22.0) / 2.0, item.on)
}

fn draw(p: const kit::Pen&, s: state::State&, items: content::Item[>..]&, w: f32, h: f32) {
    let x = state::content_x();
    let right = state::content_right(w);
    let bottom = state::body_bottom(h);
    let kind = KINDS[s.shelf];

    state::page_heading(p, x, 30.0, "Content",
                        "Mods, shaders and resource packs read from your own Minecraft folder.");

    // The toolbar: the three lists as tabs, and what the folder holds.
    let bar = kit::r(x, 112.0, right - x, 52.0);
    ui::fill_rect(p.ctx, bar, 12.0, theme::PANEL);
    ui::stroke_rect(p.ctx, bar, 12.0, 1.0, theme::LINE);
    var tx = bar.x + 6.0;
    for k, i in KINDS {
        let label = content::title_of(k);
        let tab = kit::r(tx, bar.y + 7.0, kit::width(p.fonts.small, label) + 30.0, 38.0);
        let on = i == s.shelf;
        let over = kit::hovered(p, tab);
        if on { ui::fill_rect(p.ctx, tab, 8.0, theme::ACCENT_SOFT); }
        else if over { ui::fill_rect(p.ctx, tab, 8.0, theme::SURFACE); }
        if on { ui::fill_rect(p.ctx, kit::r(tab.x + 10.0, tab.y + tab.h - 3.0, tab.w - 20.0, 2.0), 1.0, theme::ACCENT); }
        kit::text(p, tab.x + 15.0, tab.y + 10.0, label, p.fonts.small,
                  if on { theme::INK } else { theme::MUTED });
        if kit::clicked(p, tab) { s.shelf = i; s.scroll = 0.0; }
        tx += tab.w + 4.0;
    }
    kit::text_right(p, bar.x + bar.w - 18.0, bar.y + 20.0,
                    str(items.len, " in ", content::folder_of(kind)), p.fonts.small, theme::FAINT);

    // The table.
    let panel = kit::r(x, 180.0, right - x, bottom - 180.0);
    ui::fill_rect(p.ctx, panel, 16.0, theme::PANEL);
    ui::stroke_rect(p.ctx, panel, 16.0, 1.0, theme::LINE);

    let head_y = panel.y + 22.0;
    kit::text(p, panel.x + 70.0, head_y, "NAME", p.fonts.tiny, theme::FAINT);
    kit::text(p, panel.x + 430.0, head_y, "KIND", p.fonts.tiny, theme::FAINT);
    kit::text_right(p, panel.x + panel.w - 24.0, head_y, "ON", p.fonts.tiny, theme::FAINT);
    kit::line(p, panel.x + 24.0, panel.x + panel.w - 24.0, head_y + 26.0, theme::LINE);

    let top = head_y + 34.0;
    let list_bottom = panel.y + panel.h - 46.0;
    let row_h: f32 = 64.0;

    if items.len == 0 {
        let cx = panel.x + panel.w / 2.0;
        let tile = kit::r(cx - 26.0, top + 54.0, 52.0, 52.0);
        ui::fill_rect(p.ctx, tile, 14.0, theme::SURFACE);
        kit::glyph(p, cx, tile.y + 26.0, kit::GLYPH_CONTENT, theme::FAINT);
        kit::text_mid(p, cx, top + 124.0, str("Nothing in ", content::folder_of(kind), " yet"), p.fonts.medium, theme::MUTED);
        var where: u8[>..] = [];
        kit::fit(where, str("zoo looks in ", s.game_dir, "/", content::folder_of(kind)), p.fonts.small, panel.w - 80.0);
        kit::text_mid(p, cx, top + 148.0, where, p.fonts.small, theme::FAINT);
        return;
    }

    let box = kit::r(panel.x + 12.0, top, panel.w - 24.0, list_bottom - top);
    if kit::hovered(p, box) { s.scroll -= ui::input_mouse(p.ctx).scroll_delta.y * 44.0; }
    s.scroll = clamp(s.scroll, 0.0, max(0.0, items.len * row_h - (list_bottom - top)));

    ui::push_scissor(p.ctx, box);
    var i = 0;
    while i < items.len {
        let y = top + i * row_h - s.scroll;
        if y + row_h > top && y < list_bottom {
            let rb = kit::r(panel.x + 12.0, y, panel.w - 24.0, row_h);
            if draw_row(p, rb, items[i]) { content::set_enabled(items[i], !items[i].on); }
            kit::line(p, panel.x + 70.0, panel.x + panel.w - 24.0, y + row_h - 1.0, theme::LINE);
        }
        i++;
    }
    ui::push_scissor(p.ctx, kit::r(0.0, 0.0, w, h));
    kit::scrollbar(p, kit::r(panel.x + panel.w - 12.0, top, 3.0, list_bottom - top),
                   items.len * row_h, list_bottom - top, s.scroll);
}
