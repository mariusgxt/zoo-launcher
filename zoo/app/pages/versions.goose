// The version list: every version Mojang lists and every one already on this
// computer, on one hairline table (the HQLauncher table rule) with the chosen
// version and its action in a panel beside it.
import std;
import ui;
import zoo.collection;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace versions;

fn draw(p: const kit::Pen&, s: state::State&, w: f32, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    let x = state::content_x();
    let right = state::content_right(w);
    let bottom = state::body_bottom(h);

    state::page_heading(p, x, 30.0, "Versions",
                        "Every version Mojang lists, and the ones already on this computer.");

    // The filters, and the refresh button, against the heading.
    var fw: f32 = 0.0;
    fw += kit::width(p.fonts.small, "Releases") + 26.0 + 8.0;
    fw += kit::width(p.fonts.small, "Snapshots") + 26.0 + 8.0;
    fw += kit::width(p.fonts.small, "On this computer") + 26.0 + 8.0;
    var fx: f32 = right - fw - 50.0;
    let fy: f32 = 38.0;
    let cw1, t1 = kit::chip(p, fx, fy, "Releases", s.filters.releases);
    if t1 { s.filters.releases = !s.filters.releases; s.scroll = 0.0; }
    fx += cw1 + 8.0;
    let cw2, t2 = kit::chip(p, fx, fy, "Snapshots", s.filters.snapshots);
    if t2 { s.filters.snapshots = !s.filters.snapshots; s.scroll = 0.0; }
    fx += cw2 + 8.0;
    let cw3, t3 = kit::chip(p, fx, fy, "On this computer", s.filters.installed_only);
    if t3 { s.filters.installed_only = !s.filters.installed_only; s.scroll = 0.0; }
    if kit::icon_button(p, kit::r(right - 40.0, fy + 1.0, 30.0, 30.0), kit::GLYPH_REFRESH) {
        want = state::WANT_REFRESH;
    }

    // The panel: the table on the left, the chosen version on the right.
    let panel = kit::r(x, 120.0, right - x, bottom - 120.0);
    ui::fill_rect(p.ctx, panel, 16.0, theme::PANEL);
    ui::stroke_rect(p.ctx, panel, 16.0, 1.0, theme::LINE);

    let detail_w = 300.0;
    let list_x = panel.x + 24.0;
    let list_right = panel.x + panel.w - detail_w - 48.0;
    let top = panel.y + 54.0;
    let list_bottom = panel.y + panel.h - 40.0;
    let row_h: f32 = 54.0;

    // Column names, small and quiet, over their columns.
    let head_y = panel.y + 22.0;
    kit::text(p, list_x + 18.0, head_y, "VERSION", p.fonts.tiny, theme::FAINT);
    kit::text(p, list_x + 230.0, head_y, "TYPE", p.fonts.tiny, theme::FAINT);
    kit::text(p, list_x + 330.0, head_y, "RELEASED", p.fonts.tiny, theme::FAINT);
    kit::text_right(p, list_right - 18.0, head_y, "STATE", p.fonts.tiny, theme::FAINT);
    kit::line(p, list_x, list_right, top - 8.0, theme::LINE);

    var shown = 0;
    for r in s.rows { if state::visible(r, s.filters) { shown++; } }
    let list_box = kit::r(list_x, top, list_right - list_x, list_bottom - top);
    if kit::hovered(p, list_box) { s.scroll -= ui::input_mouse(p.ctx).scroll_delta.y * 44.0; }
    s.scroll = clamp(s.scroll, 0.0, max(0.0, shown * row_h - (list_bottom - top)));

    ui::push_scissor(p.ctx, list_box);
    var y = top - s.scroll;
    for r, i in s.rows {
        if !state::visible(r, s.filters) { continue; }
        if y + row_h > top && y < list_bottom {
            let box = kit::r(list_x, y, list_right - list_x, row_h);
            let picked = i == s.selected;
            let over = kit::hovered(p, box);
            if picked { ui::fill_rect(p.ctx, box, 10.0, theme::ACCENT_SOFT); }
            else if over { ui::fill_rect(p.ctx, box, 10.0, theme::SURFACE); }
            if picked { ui::fill_rect(p.ctx, kit::r(box.x + 5.0, y + 15.0, 3.0, 24.0), 1.5, theme::ACCENT); }
            kit::text(p, list_x + 18.0, y + 15.0, r.id, p.fonts.medium,
                      if picked { theme::INK } else { theme::INK });
            kit::text(p, list_x + 230.0, y + 18.0, state::upper(r.kind), p.fonts.tiny, theme::FAINT);
            kit::text(p, list_x + 330.0, y + 16.0, r.released[..min(r.released.len, 10)], p.fonts.small, theme::MUTED);

            var state_word: const u8[:] = "NOT PREPARED";
            var state_color = theme::FAINT;
            if r.ready { state_word = "PREPARED"; state_color = theme::LEAF; }
            else if r.local_jar.len > 0 { state_word = "ON DISK"; state_color = theme::ACCENT; }
            let sw = kit::width(p.fonts.tiny, state_word);
            ui::fill_circle(p.ctx, kit::r(list_right - 24.0 - sw - 12.0, y + 24.0, 6.0, 6.0), state_color);
            kit::text(p, list_right - 24.0 - sw, y + 20.0, state_word, p.fonts.tiny, state_color);

            if kit::clicked(p, box) { s.selected = i; }
            kit::line(p, list_x + 18.0, list_right - 18.0, y + row_h - 1.0, theme::LINE);
        }
        y += row_h;
    }
    ui::push_scissor(p.ctx, kit::r(0.0, 0.0, w, h));
    kit::scrollbar(p, kit::r(list_right - 8.0, top, 3.0, list_bottom - top),
                   shown * row_h, list_bottom - top, s.scroll);
    if shown == 0 {
        kit::text(p, list_x + 18.0, top + 18.0, "Nothing matches these filters.", p.fonts.body, theme::MUTED);
    }
    kit::text_right(p, list_right, panel.y + panel.h - 24.0, s.list_note, p.fonts.tiny, theme::FAINT);

    // The chosen version, and the one action it offers.
    let detail = kit::r(panel.x + panel.w - detail_w - 24.0, panel.y + 54.0, detail_w,
                        panel.h - 74.0);
    ui::fill_rect(p.ctx, detail, 14.0, theme::SURFACE);
    ui::stroke_rect(p.ctx, detail, 14.0, 1.0, theme::LINE);
    kit::text(p, detail.x + 20.0, detail.y + 18.0, "CHOSEN VERSION", p.fonts.tiny, theme::FAINT);

    if state::chosen(s) {
        let row = s.rows[s.selected];
        var id: u8[>..] = [];
        kit::fit(id, row.id, p.fonts.heading, detail.w - 40.0);
        kit::text(p, detail.x + 20.0, detail.y + 40.0, id, p.fonts.heading, theme::INK);
        var state_word: const u8[:] = "NOT PREPARED YET";
        var state_color = theme::MUTED;
        if row.ready { state_word = "PREPARED"; state_color = theme::LEAF; }
        else if s.stage == collection::STAGE_FAILED { state_word = "LAST TRY FAILED"; state_color = theme::RUST; }
        if s.busy { state_word = "PREPARING"; state_color = theme::ACCENT; }
        ui::fill_circle(p.ctx, kit::r(detail.x + 20.0, detail.y + 82.0, 6.0, 6.0), state_color);
        kit::text(p, detail.x + 32.0, detail.y + 78.0, state_word, p.fonts.tiny, state_color);

        var ry = detail.y + 112.0;
        kit::text(p, detail.x + 20.0, ry, "TYPE", p.fonts.tiny, theme::FAINT);
        kit::text(p, detail.x + 20.0, ry + 15.0, state::upper(row.kind), p.fonts.small, theme::INK);
        ry += 46.0;
        kit::text(p, detail.x + 20.0, ry, "RELEASED", p.fonts.tiny, theme::FAINT);
        kit::text(p, detail.x + 20.0, ry + 15.0, row.released[..min(row.released.len, 10)],
                  p.fonts.small, theme::INK);
        ry += 46.0;
        kit::text(p, detail.x + 20.0, ry, "ON THIS COMPUTER", p.fonts.tiny, theme::FAINT);
        kit::text(p, detail.x + 20.0, ry + 15.0, if row.local_jar.len > 0 { "yes" } else { "no" },
                  p.fonts.small, theme::INK);

        // What preparation actually takes, so the panel says why the button
        // is worth pressing.
        kit::line(p, detail.x + 20.0, detail.x + detail.w - 20.0, ry + 48.0, theme::LINE);
        kit::text(p, detail.x + 20.0, ry + 64.0, "WHAT PREPARATION TAKES", p.fonts.tiny, theme::FAINT);
        let takes: const u8[:][3] = ["Textures and atlases", "Block models and block states",
                                     "Fonts and English names"];
        var ty = ry + 88.0;
        for take in takes {
            ui::fill_circle(p.ctx, kit::r(detail.x + 22.0, ty + 5.0, 5.0, 5.0), theme::ACCENT);
            kit::text(p, detail.x + 36.0, ty, take, p.fonts.small, theme::MUTED);
            ty += 24.0;
        }

        let act = kit::r(detail.x + 16.0, detail.y + detail.h - 64.0, detail.w - 32.0, 48.0);
        var label: const u8[:] = "PREPARE";
        if row.ready { label = "PREPARE AGAIN"; }
        if s.busy { label = "PREPARING"; }
        if kit::action_button(p, act, label, kit::GLYPH_DOWN, !s.busy) { want = state::WANT_OBTAIN; }
        kit::text(p, detail.x + 20.0, detail.y + detail.h - 90.0,
                  "Textures, models and names come from your own copy.", p.fonts.tiny, theme::FAINT);
    } else {
        kit::text(p, detail.x + 20.0, detail.y + 44.0, "No version chosen.", p.fonts.body, theme::MUTED);
    }
    return want;
}
