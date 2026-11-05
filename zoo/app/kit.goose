// A few hand-drawn controls on Nuklear's canvas. Nuklear's stock widgets
// bring their own boxes and paddings; drawing these directly gives the
// launcher the flat, typographic look it wants and keeps every control a
// rectangle plus one click test, which is easy to reason about.
import std;
import ui;
import zoo.app.theme;
namespace kit;

struct Pen { ctx: ui::Context, fonts: theme::Fonts }

fn r(x: f32, y: f32, w: f32, h: f32) -> ui::Rect { ui::Rect { x: x, y: y, w: w, h: h } }

fn width(font: ui::Font, s: const u8[:]) -> f32 { ui::text_width(font, s) }

fn height(font: ui::Font) -> f32 { ui::info(font).height }

// Text with its top-left at x, y; returns the width it took.
fn text(p: const Pen&, x: f32, y: f32, s: const u8[:], font: ui::Font, color: ui::Color) -> f32 {
    let w = width(font, s);
    ui::draw_text(p.ctx, r(x, y, w + 2.0, height(font) + 4.0), s, font, theme::NONE, color);
    w
}

// Right-aligned against x_right.
fn text_right(p: const Pen&, x_right: f32, y: f32, s: const u8[:], font: ui::Font, color: ui::Color) -> f32 {
    let w = width(font, s);
    text(p, x_right - w, y, s, font, color);
    w
}

fn hovered(p: const Pen&, box: ui::Rect) -> bool { ui::input_is_mouse_hovering_rect(p.ctx, box) }

fn clicked(p: const Pen&, box: ui::Rect) -> bool {
    ui::input_is_mouse_click_in_rect(p.ctx, ui::BUTTON_LEFT, box) && ui::input_is_mouse_released(p.ctx, ui::BUTTON_LEFT)
}

fn line(p: const Pen&, x0: f32, x1: f32, y: f32) { ui::stroke_line(p.ctx, x0, y, x1, y, 1.0, theme::LINE); }

let PRIMARY = 0;
let QUIET = 1;
let LINK = 2;

// A pill button; `enabled` false draws it dimmed and never reports a click.
fn button(p: const Pen&, box: ui::Rect, label: const u8[:], kind: i64, enabled: bool) -> bool {
    let over = enabled && hovered(p, box);
    let round = if kind == LINK { 0.0 } else { 12.0 };
    var fg = theme::INK;
    if kind == PRIMARY {
        let bg = if !enabled { theme::SURFACE } else if over { theme::ACCENT_HOVER } else { theme::ACCENT };
        ui::fill_rect(p.ctx, box, round, bg);
        fg = if enabled { theme::ON_ACCENT } else { theme::FAINT };
    } else if kind == QUIET {
        ui::fill_rect(p.ctx, box, round, if over { theme::SURFACE_HOVER } else { theme::SURFACE });
        fg = if enabled { theme::INK } else { theme::FAINT };
    } else {
        fg = if !enabled { theme::FAINT } else if over { theme::INK } else { theme::MUTED };
    }
    let font = p.fonts.medium;
    let w = width(font, label);
    let x = if kind == LINK { box.x + box.w - w } else { box.x + (box.w - w) / 2.0 };
    text(p, x, box.y + (box.h - height(font)) / 2.0 - 1.0, label, font, fg);
    enabled && clicked(p, box)
}

// The small down arrow of a picker.
fn chevron(p: const Pen&, x: f32, y: f32) {
    ui::fill_triangle(p.ctx, x, y, x + 9.0, y, x + 4.5, y + 5.0, theme::MUTED);
}

// A tab in the top bar: plain text, with a soft pill behind the active one.
fn tab(p: const Pen&, x: f32, y: f32, label: const u8[:], active: bool) -> f32, bool {
    let font = p.fonts.body;
    let w = width(font, label) + 28.0;
    let box = r(x, y, w, 32.0);
    if active { ui::fill_rect(p.ctx, box, 12.0, theme::SURFACE); }
    let over = hovered(p, box);
    let color = if active || over { theme::INK } else { theme::MUTED };
    text(p, x + 14.0, y + 7.0, label, font, color);
    return w, clicked(p, box);
}

// A small toggle pill for filters.
fn chip(p: const Pen&, x: f32, y: f32, label: const u8[:], on: bool) -> f32, bool {
    let font = p.fonts.small;
    let w = width(font, label) + 24.0;
    let box = r(x, y, w, 28.0);
    let over = hovered(p, box);
    ui::fill_rect(p.ctx, box, 10.0, if on { theme::SURFACE_HOVER } else if over { theme::SURFACE } else { theme::BG });
    ui::stroke_rect(p.ctx, box, 10.0, 1.0, if on { theme::ACCENT } else { theme::LINE });
    text(p, x + 12.0, y + 6.0, label, font, if on { theme::INK } else { theme::MUTED });
    return w, clicked(p, box);
}

// A thin progress line: `part` of `whole`, in the accent colour.
fn progress(p: const Pen&, box: ui::Rect, part: f32, whole: f32) {
    ui::fill_rect(p.ctx, box, box.h / 2.0, theme::SURFACE);
    let f = clamp(part / max(whole, 1.0), 0.0, 1.0);
    if f > 0.0 { ui::fill_rect(p.ctx, r(box.x, box.y, box.w * f, box.h), box.h / 2.0, theme::ACCENT); }
}

// Cuts text to fit a width, ending in "..." when it had to cut.
fn fit(out: u8[>..]&, s: const u8[:], font: ui::Font, max_w: f32) {
    if width(font, s) <= max_w { out.append(s); return; }
    var n = s.len;
    while n > 0 && width(font, s[..n]) + width(font, "...") > max_w { n--; }
    out.append(s[..n]);
    out.append("...");
}
