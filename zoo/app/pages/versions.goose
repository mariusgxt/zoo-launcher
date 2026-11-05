// The version list. The rows are the ones zoo had before, which say in one
// line what a version is and whether it is ready; they now sit on the same
// panel the other list pages use, with the filters as sub-tabs beside them.
import std;
import ui;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace versions;

fn draw(p: const kit::Pen&, s: state::State&, w: f32, h: f32) {
    let x = state::content_x();
    let panel = kit::r(x, state::TOP_H + 12.0, w - x - state::EDGE, h - state::TOP_H - 12.0 - state::EDGE - 34.0);
    ui::fill_rect(p.ctx, panel, 20.0, theme::PANEL);
    ui::stroke_rect(p.ctx, panel, 20.0, 1.0, theme::LINE);
    state::page_heading(p, panel.x + 24.0, panel.y + 24.0, "Versions",
                        "Every version Mojang lists, and the ones already on",
                        "this computer. Pick one and zoo prepares it.");

    var fx = panel.x + 24.0;
    let fy = panel.y + 96.0;
    let cw1, t1 = kit::chip(p, fx, fy, "Releases", s.filters.releases);
    if t1 { s.filters.releases = !s.filters.releases; }
    fx += cw1 + 8.0;
    let cw2, t2 = kit::chip(p, fx, fy, "Snapshots", s.filters.snapshots);
    if t2 { s.filters.snapshots = !s.filters.snapshots; }
    fx += cw2 + 8.0;
    let cw3, t3 = kit::chip(p, fx, fy, "On this computer", s.filters.installed_only);
    if t3 { s.filters.installed_only = !s.filters.installed_only; }
    kit::text_right(p, panel.x + panel.w - 24.0, fy + 7.0, s.list_note, p.fonts.small, theme::MUTED);

    let top = fy + 46.0;
    let bottom = panel.y + panel.h - 20.0;
    let row_h: f32 = 48.0;
    let left = panel.x + 24.0;
    let right = panel.x + panel.w - 24.0;
    kit::line(p, left, right, top - 10.0);

    var shown = 0;
    for r in s.rows { if state::visible(r, s.filters) { shown++; } }
    let list_box = kit::r(left, top, right - left, bottom - top);
    if kit::hovered(p, list_box) { s.scroll -= ui::input_mouse(p.ctx).scroll_delta.y * 40.0; }
    s.scroll = clamp(s.scroll, 0.0, max(0.0, shown * row_h - (bottom - top)));

    ui::push_scissor(p.ctx, list_box);
    var y = top - s.scroll;
    for r, i in s.rows {
        if !state::visible(r, s.filters) { continue; }
        if y + row_h > top && y < bottom {
            let box = kit::r(left, y + 1.0, right - left, row_h - 1.0);
            let picked = i == s.selected;
            if picked || kit::hovered(p, box) {
                ui::fill_rect(p.ctx, box, 8.0, if picked { theme::SURFACE_HOVER } else { theme::SURFACE });
            }
            if picked { ui::fill_rect(p.ctx, kit::r(left, y + 14.0, 3.0, 20.0), 1.5, theme::ACCENT); }
            kit::text(p, left + 18.0, y + 14.0, r.id, p.fonts.medium, theme::INK);
            kit::text(p, left + 220.0, y + 17.0, state::upper(r.kind), p.fonts.mono, theme::FAINT);
            kit::text(p, left + 340.0, y + 15.0, r.released[..min(r.released.len, 10)], p.fonts.small, theme::MUTED);
            if r.ready { kit::text_right(p, right - 18.0, y + 17.0, "READY", p.fonts.mono, theme::LEAF); }
            else if r.local_jar.len > 0 { kit::text_right(p, right - 18.0, y + 17.0, "ON THIS COMPUTER", p.fonts.mono, theme::ACCENT); }
            if kit::clicked(p, box) && y >= top && y + row_h <= bottom + row_h / 2.0 {
                s.selected = i;
                s.page = state::PAGE_PLAY;
            }
        }
        y += row_h;
    }
    ui::push_scissor(p.ctx, kit::r(0.0, 0.0, w, h));
    if shown == 0 { kit::text(p, left + 18.0, top + 16.0, "Nothing matches these filters.", p.fonts.body, theme::MUTED); }
}
