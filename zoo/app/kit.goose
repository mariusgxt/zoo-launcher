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

// A filled label pill for facts about the chosen version. `clickable`
// adds the chevron and hover; the caller tests the click on the same box.
fn pill(p: const Pen&, x: f32, y: f32, label: const u8[:], color: ui::Color, clickable: bool) -> f32 {
    let font = p.fonts.small;
    let extra = if clickable { 20.0 } else { 0.0 };
    let w = width(font, label) + 26.0 + extra;
    let box = r(x, y, w, 28.0);
    let over = clickable && hovered(p, box);
    ui::fill_rect(p.ctx, box, 14.0, if over { theme::SURFACE_HOVER } else { theme::CHIP });
    text(p, x + 13.0, y + 6.0, label, font, color);
    if clickable { chevron(p, x + w - 22.0, y + 12.0); }
    w
}

// The play triangle, drawn rather than taken from a font so it sits on the
// pixel grid at any size.
fn play_glyph(p: const Pen&, x: f32, y: f32, size: f32, color: ui::Color) {
    ui::fill_triangle(p.ctx, x, y, x, y + size, x + size * 0.86, y + size / 2.0, color);
}

// A circular arrow. The arc leaves a gap on the upper right where the
// arrowhead goes; the head's points are precomputed for radius 8 to keep
// trigonometry out of the frame loop.
fn refresh_glyph(p: const Pen&, cx: f32, cy: f32, color: ui::Color) {
    ui::stroke_arc(p.ctx, cx, cy, 8.0, 0.6, 5.6, 2.0, color);
    ui::fill_triangle(p.ctx, cx + 9.4, cy - 7.7, cx + 3.0, cy - 2.4, cx + 8.7, cy - 1.9, color);
}

// A square button that carries only the refresh glyph.
fn refresh_button(p: const Pen&, box: ui::Rect, enabled: bool) -> bool {
    let over = enabled && hovered(p, box);
    ui::fill_rect(p.ctx, box, 12.0, if over { theme::SURFACE_HOVER } else { theme::SURFACE });
    refresh_glyph(p, box.x + box.w / 2.0, box.y + box.h / 2.0, if enabled { theme::INK } else { theme::FAINT });
    enabled && clicked(p, box)
}

// The main action: the play glyph in front of the label.
fn play_button(p: const Pen&, box: ui::Rect, label: const u8[:], enabled: bool) -> bool {
    let over = enabled && hovered(p, box);
    let bg = if !enabled { theme::SURFACE } else if over { theme::ACCENT_HOVER } else { theme::ACCENT };
    let fg = if enabled { theme::ON_ACCENT } else { theme::FAINT };
    ui::fill_rect(p.ctx, box, 12.0, bg);
    let font = p.fonts.medium;
    let w = width(font, label) + 22.0;
    let x = box.x + (box.w - w) / 2.0;
    play_glyph(p, x, box.y + box.h / 2.0 - 6.0, 12.0, fg);
    text(p, x + 22.0, box.y + (box.h - height(font)) / 2.0 - 1.0, label, font, fg);
    enabled && clicked(p, box)
}

// A soft light that fades to nothing at its left and bottom edges. Nuklear
// only blends colours across a plain rectangle, so the fade is one quad.
fn glow(p: const Pen&, box: ui::Rect, color: ui::Color) {
    ui::fill_rect_multi_color(p.ctx, box, theme::NONE, color, theme::NONE, theme::NONE);
}

// The icons of the rail. Each is drawn from rectangles and triangles in a
// 22 x 22 box: a font would need a glyph set zoo does not ship, and these
// stay sharp at the one size they are used in.
let GLYPH_PLAY = 0;
let GLYPH_VERSIONS = 1;
let GLYPH_CONTENT = 2;
let GLYPH_WORLDS = 3;
let GLYPH_SETUP = 4;
let GLYPH_LABEL = 5;
let GLYPH_QUIT = 6;

fn glyph_for(page: i64) -> i64 {
    match page {
        0 => GLYPH_PLAY,
        1 => GLYPH_VERSIONS,
        2 => GLYPH_CONTENT,
        3 => GLYPH_WORLDS,
        4 => GLYPH_SETUP,
        _ => GLYPH_LABEL,
    }
}

fn glyph(p: const Pen&, cx: f32, cy: f32, kind: i64, color: ui::Color) {
    let s: f32 = 9.0;       // half the icon's box
    if kind == GLYPH_PLAY {
        ui::fill_triangle(p.ctx, cx - s + 3.0, cy - s, cx - s + 3.0, cy + s, cx + s, cy, color);
    } else if kind == GLYPH_VERSIONS {
        var i = 0;
        while i < 3 {
            let y = cy - s + 2.0 + i * 7.0;
            ui::fill_rect(p.ctx, r(cx - s, y, 4.0, 4.0), 1.0, color);
            ui::fill_rect(p.ctx, r(cx - s + 7.0, y + 1.0, s + 7.0, 2.0), 1.0, color);
            i++;
        }
    } else if kind == GLYPH_CONTENT {
        // A cube, seen from a corner: the top face and two sides.
        ui::fill_triangle(p.ctx, cx, cy - s, cx + s, cy - s / 2.0, cx, cy, color);
        ui::fill_triangle(p.ctx, cx, cy - s, cx - s, cy - s / 2.0, cx, cy, color);
        ui::fill_triangle(p.ctx, cx - s, cy - s / 2.0, cx, cy, cx, cy + s, color);
        ui::fill_triangle(p.ctx, cx - s, cy - s / 2.0, cx - s, cy + s / 2.0, cx, cy + s, color);
    } else if kind == GLYPH_WORLDS {
        // A folded map: three panels, the middle one dropped.
        ui::fill_triangle(p.ctx, cx - s, cy - s + 2.0, cx - s / 3.0, cy - s + 5.0, cx - s / 3.0, cy + s, color);
        ui::fill_triangle(p.ctx, cx - s, cy - s + 2.0, cx - s, cy + s - 3.0, cx - s / 3.0, cy + s, color);
        ui::fill_rect(p.ctx, r(cx - s / 3.0 + 1.0, cy - s + 5.0, s / 1.5, 2.0 * s - 5.0), 1.0, color);
        ui::fill_triangle(p.ctx, cx + s / 3.0 + 2.0, cy - s + 5.0, cx + s, cy - s + 2.0, cx + s, cy + s - 3.0, color);
    } else if kind == GLYPH_SETUP {
        ui::stroke_circle(p.ctx, r(cx - s + 2.0, cy - s + 2.0, 2.0 * s - 4.0, 2.0 * s - 4.0), 2.0, color);
        ui::fill_circle(p.ctx, r(cx - 2.5, cy - 2.5, 5.0, 5.0), color);
        var i = 0;
        while i < 4 {
            let dx = if i == 0 { -s } else if i == 1 { s - 3.0 } else { -1.5 };
            let dy = if i == 2 { -s } else if i == 3 { s - 3.0 } else { -1.5 };
            ui::fill_rect(p.ctx, r(cx + dx, cy + dy, 3.0, 3.0), 1.0, color);
            i++;
        }
    } else if kind == GLYPH_LABEL {
        // A museum tag: a rectangle with a corner cut and a hole for string.
        ui::fill_rect(p.ctx, r(cx - s, cy - s / 1.6, 2.0 * s - 4.0, 1.3 * s), 2.0, color);
        ui::fill_triangle(p.ctx, cx + s - 4.0, cy - s / 1.6, cx + s, cy, cx + s - 4.0, cy + s / 1.6, color);
    } else {
        // Leaving: a door's arrow, pointing out to the left.
        ui::fill_rect(p.ctx, r(cx - s + 2.0, cy - 1.5, 2.0 * s - 5.0, 3.0), 1.0, color);
        ui::fill_triangle(p.ctx, cx - s - 1.0, cy, cx - s + 5.0, cy - 5.0, cx - s + 5.0, cy + 5.0, color);
    }
}

// One item of the rail: the icon with its name under it, and the active one
// lit the way the concept lights the page you are on.
fn rail_item(p: const Pen&, box: ui::Rect, label: const u8[:], kind: i64, active: bool) -> bool {
    let over = hovered(p, box);
    if active {
        ui::fill_rect(p.ctx, box, 16.0, theme::CHIP);
        ui::fill_rect(p.ctx, r(box.x - 6.0, box.y + 14.0, 3.0, box.h - 28.0), 1.5, theme::ACCENT);
    } else if over {
        ui::fill_rect(p.ctx, box, 16.0, theme::SURFACE_HOVER);
    }
    let color = if active { theme::ACCENT } else if over { theme::INK } else { theme::FAINT };
    glyph(p, box.x + box.w / 2.0, box.y + 20.0, kind, color);
    let lw = width(p.fonts.tiny, label);
    text(p, box.x + (box.w - lw) / 2.0, box.y + 38.0, label, p.fonts.tiny,
         if active { theme::INK } else { theme::FAINT });
    clicked(p, box)
}

// zoo's mark: the specimen dot in a rounded tile, where the concept has its
// cat. Drawn, not an image file, so the tile scales with the window.
fn mark(p: const Pen&, tile: ui::Rect) {
    let cx = tile.x + tile.w / 2.0;
    let cy = tile.y + tile.h / 2.0;
    ui::fill_circle(p.ctx, r(cx - 11.0, cy - 11.0, 22.0, 22.0), theme::ACCENT);
    ui::fill_circle(p.ctx, r(cx - 4.0, cy - 14.0, 8.0, 8.0), theme::SURFACE);
    ui::fill_circle(p.ctx, r(cx + 2.0, cy - 2.0, 5.0, 5.0), theme::BG);
}

// The diamond badge of the top bar: a big number over a small one.
fn badge(p: const Pen&, cx: f32, cy: f32, radius: f32, big: const u8[:], small: const u8[:]) {
    ui::fill_polygon(p.ctx, [float2 { cx, cy - radius }, float2 { cx + radius, cy },
                             float2 { cx, cy + radius }, float2 { cx - radius, cy }], theme::SURFACE);
    let bw = width(p.fonts.medium, big);
    let sw = width(p.fonts.tiny, small);
    text(p, cx - (bw + sw) / 2.0, cy - 9.0, big, p.fonts.medium, theme::INK);
    text(p, cx - (bw + sw) / 2.0 + bw + 1.0, cy - 2.0, small, p.fonts.tiny, theme::FAINT);
}

// An outlined pill, as the concept's facts under the title are drawn.
fn outline_pill(p: const Pen&, x: f32, y: f32, label: const u8[:], color: ui::Color) -> f32 {
    let font = p.fonts.small;
    let w = width(font, label) + 34.0;
    let box = r(x, y, w, 32.0);
    ui::fill_rect(p.ctx, box, 16.0, theme::CHIP);
    ui::stroke_rect(p.ctx, box, 16.0, 1.0, theme::LINE);
    text(p, x + 17.0, y + 8.0, label, font, color);
    w
}

// The toggle of the content lists: a track with a knob, green when on.
fn toggle(p: const Pen&, x: f32, y: f32, on: bool) -> bool {
    let box = r(x, y, 46.0, 26.0);
    let over = hovered(p, box);
    ui::fill_rect(p.ctx, box, 13.0, if on { theme::LEAF } else if over { theme::SURFACE_HOVER } else { theme::SURFACE });
    let knob_x = if on { x + 46.0 - 23.0 } else { x + 3.0 };
    ui::fill_circle(p.ctx, r(knob_x, y + 3.0, 20.0, 20.0), theme::INK);
    clicked(p, box)
}

// A square button carrying one rail glyph, for the action bar.
fn icon_button(p: const Pen&, box: ui::Rect, kind: i64) -> bool {
    let over = hovered(p, box);
    ui::fill_rect(p.ctx, box, 12.0, if over { theme::SURFACE_HOVER } else { theme::SURFACE });
    glyph(p, box.x + box.w / 2.0, box.y + box.h / 2.0, kind, if over { theme::INK } else { theme::MUTED });
    clicked(p, box)
}

// The small state pill above the title: a dot in the state's colour and the
// word beside it, as the Zenith concept marks its season.
fn state_pill(p: const Pen&, x: f32, y: f32, label: const u8[:], color: ui::Color) -> f32 {
    let font = p.fonts.tiny;
    let w = width(font, label) + 38.0;
    ui::fill_rect(p.ctx, r(x, y, w, 24.0), 12.0, theme::CHIP);
    ui::fill_circle(p.ctx, r(x + 13.0, y + 9.0, 7.0, 7.0), color);
    text(p, x + 26.0, y + 7.0, label, font, theme::INK);
    w
}
