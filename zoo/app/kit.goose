// A few hand-drawn controls on Nuklear's canvas. Nuklear's stock widgets
// bring their own boxes and paddings; drawing these directly gives the
// launcher the flat, typographic look it wants and keeps every control a
// rectangle plus one click test, which is easy to reason about.
//
// The shapes follow the two launcher concepts named in THIRD_PARTY_NOTICES:
// the rounded dark dock of the Zenith client and the hairline panels of
// HQLauncher. Everything is still drawn from rectangles, circles and moves.
import std;
import ui;
import zoo.app.theme;
namespace kit;

struct Pen { ctx: ui::Context, fonts: theme::Fonts }

fn r(x: f32, y: f32, w: f32, h: f32) -> ui::Rect { ui::Rect { x: x, y: y, w: w, h: h } }

fn width(font: ui::Font, s: const u8[:]) -> f32 { ui::text_width(font, s) }

fn height(font: ui::Font) -> f32 { ui::info(font).height }

fn with_alpha(c: ui::Color, a: u8) -> ui::Color { ui::Color { c.r, c.g, c.b, a } }

fn mix(a: ui::Color, b: ui::Color, t: f32) -> ui::Color {
    let u = clamp(t, 0.0, 1.0);
    ui::Color {
        (a.r * (1.0 - u) + b.r * u) as! u8,
        (a.g * (1.0 - u) + b.g * u) as! u8,
        (a.b * (1.0 - u) + b.b * u) as! u8,
        (a.a * (1.0 - u) + b.a * u) as! u8,
    }
}

// Text with its top-left at x, y; returns the width it took.
fn text(p: const Pen&, x: f32, y: f32, s: const u8[:], font: ui::Font, color: ui::Color) -> f32 {
    let w = width(font, s);
    ui::draw_text(p.ctx, r(x, y, w + 2.0, height(font) + 4.0), s, font, theme::NONE, color);
    w
}

// Text with a one-pixel dark copy under it, for words set straight on the
// hero picture.
fn text_shadow(p: const Pen&, x: f32, y: f32, s: const u8[:], font: ui::Font,
               color: ui::Color, shadow: ui::Color) {
    text(p, x + 1.0, y + 1.0, s, font, shadow);
    text(p, x, y, s, font, color);
}

// Right-aligned against x_right.
fn text_right(p: const Pen&, x_right: f32, y: f32, s: const u8[:], font: ui::Font, color: ui::Color) -> f32 {
    let w = width(font, s);
    text(p, x_right - w, y, s, font, color);
    w
}

// Centred on cx.
fn text_mid(p: const Pen&, cx: f32, y: f32, s: const u8[:], font: ui::Font, color: ui::Color) -> f32 {
    let w = width(font, s);
    text(p, cx - w / 2.0, y, s, font, color);
    w
}

fn hovered(p: const Pen&, box: ui::Rect) -> bool { ui::input_is_mouse_hovering_rect(p.ctx, box) }

fn clicked(p: const Pen&, box: ui::Rect) -> bool {
    ui::input_is_mouse_click_in_rect(p.ctx, ui::BUTTON_LEFT, box) && ui::input_is_mouse_released(p.ctx, ui::BUTTON_LEFT)
}

fn line(p: const Pen&, x0: f32, x1: f32, y: f32, color: ui::Color) {
    ui::stroke_line(p.ctx, x0, y, x1, y, 1.0, color);
}

fn rect_line(p: const Pen&, box: ui::Rect, color: ui::Color) { ui::stroke_rect(p.ctx, box, 0.0, 1.0, color); }

// A panel of the launcher's own: one rounded rectangle, no border unless the
// caller asks for one on top.
fn panel(p: const Pen&, box: ui::Rect, radius: f32, color: ui::Color) {
    ui::fill_rect(p.ctx, box, radius, color);
}

fn outline(p: const Pen&, box: ui::Rect, radius: f32, color: ui::Color) {
    ui::stroke_rect(p.ctx, box, radius, 1.0, color);
}

// Three offset rectangles standing in for a blur: the dock and the floating
// cards of the concept sit on one of these.
fn shadow(p: const Pen&, box: ui::Rect, radius: f32) {
    ui::fill_rect(p.ctx, r(box.x - 6.0, box.y + 8.0, box.w + 12.0, box.h + 8.0), radius + 6.0, with_alpha(theme::SHADOW, 26));
    ui::fill_rect(p.ctx, r(box.x - 3.0, box.y + 4.0, box.w + 6.0, box.h + 6.0), radius + 3.0, with_alpha(theme::SHADOW, 52));
    ui::fill_rect(p.ctx, r(box.x - 1.0, box.y + 2.0, box.w + 2.0, box.h + 2.0), radius + 1.0, with_alpha(theme::SHADOW, 82));
}

let PRIMARY = 0;
let QUIET = 1;
let LINK = 2;

// A pill button; `enabled` false draws it dimmed and never reports a click.
fn button(p: const Pen&, box: ui::Rect, label: const u8[:], kind: i64, enabled: bool) -> bool {
    let over = enabled && hovered(p, box);
    let round = if kind == LINK { 0.0 } else { 11.0 };
    var fg = theme::INK;
    if kind == PRIMARY {
        let bg = if !enabled { theme::SURFACE } else if over { theme::ACCENT_HOVER } else { theme::ACCENT };
        if enabled {
            ui::fill_rect(p.ctx, r(box.x, box.y + 3.0, box.w, box.h), round, with_alpha(theme::ACCENT, 60));
        }
        ui::fill_rect(p.ctx, box, round, bg);
        fg = if enabled { theme::ON_ACCENT } else { theme::FAINT };
    } else if kind == QUIET {
        ui::fill_rect(p.ctx, box, round, if over { theme::SURFACE_HOVER } else { theme::SURFACE });
        ui::stroke_rect(p.ctx, box, round, 1.0, theme::LINE);
        fg = if enabled { theme::INK } else { theme::FAINT };
    } else {
        fg = if !enabled { theme::FAINT } else if over { theme::ACCENT_HOVER } else { theme::ACCENT };
    }
    let font = p.fonts.medium;
    let w = width(font, label);
    let x = if kind == LINK { box.x + box.w - w } else { box.x + (box.w - w) / 2.0 };
    text(p, x, box.y + (box.h - height(font)) / 2.0 - 1.0, label, font, fg);
    enabled && clicked(p, box)
}

// The small down arrow of a picker.
fn chevron(p: const Pen&, x: f32, y: f32, color: ui::Color) {
    ui::fill_triangle(p.ctx, x, y, x + 9.0, y, x + 4.5, y + 5.0, color);
}

fn chevron_right(p: const Pen&, x: f32, y: f32, color: ui::Color) {
    ui::fill_triangle(p.ctx, x, y, x, y + 9.0, x + 5.0, y + 4.5, color);
}

// A filter chip: an outlined pill that fills with the accent when chosen.
fn chip(p: const Pen&, x: f32, y: f32, label: const u8[:], on: bool) -> f32, bool {
    let font = p.fonts.small;
    let w = width(font, label) + 26.0;
    let box = r(x, y, w, 30.0);
    let over = hovered(p, box);
    ui::fill_rect(p.ctx, box, 9.0, if on { theme::ACCENT_SOFT } else if over { theme::SURFACE } else { theme::PANEL });
    ui::stroke_rect(p.ctx, box, 9.0, 1.0, if on { theme::ACCENT } else { theme::LINE });
    text(p, x + 13.0, y + 7.0, label, font, if on { theme::INK } else { theme::MUTED });
    return w, clicked(p, box)
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

// The play triangle, drawn rather than taken from a font so it sits on the
// pixel grid at any size.
fn play_glyph(p: const Pen&, x: f32, y: f32, size: f32, color: ui::Color) {
    ui::fill_triangle(p.ctx, x, y, x, y + size, x + size * 0.86, y + size / 2.0, color);
}

// The main action: the play glyph in front of the label, on the accent.
fn play_button(p: const Pen&, box: ui::Rect, label: const u8[:], enabled: bool) -> bool {
    let over = enabled && hovered(p, box);
    let bg = if !enabled { theme::SURFACE } else if over { theme::ACCENT_HOVER } else { theme::ACCENT };
    let fg = if enabled { theme::ON_ACCENT } else { theme::FAINT };
    if enabled { ui::fill_rect(p.ctx, r(box.x, box.y + 4.0, box.w, box.h), 13.0, with_alpha(theme::ACCENT, 64)); }
    ui::fill_rect(p.ctx, box, 13.0, bg);
    let font = p.fonts.medium;
    let w = width(font, label) + 24.0;
    let x = box.x + (box.w - w) / 2.0;
    play_glyph(p, x, box.y + box.h / 2.0 - 6.0, 12.0, fg);
    text(p, x + 24.0, box.y + (box.h - height(font)) / 2.0 - 1.0, label, font, fg);
    enabled && clicked(p, box)
}

// The main action of the Play page: one glyph and a label on the accent,
// inside the floating dock.
fn action_button(p: const Pen&, box: ui::Rect, label: const u8[:], kind: i64, enabled: bool) -> bool {
    let over = enabled && hovered(p, box);
    let bg = if !enabled { theme::SURFACE } else if over { theme::ACCENT_HOVER } else { theme::ACCENT };
    let fg = if enabled { theme::ON_ACCENT } else { theme::FAINT };
    if enabled { ui::fill_rect(p.ctx, r(box.x, box.y + 4.0, box.w, box.h), 14.0, with_alpha(theme::ACCENT, 64)); }
    ui::fill_rect(p.ctx, box, 14.0, bg);
    let font = p.fonts.medium;
    let tw = width(font, label);
    let x = box.x + (box.w - (tw + 26.0)) / 2.0;
    glyph(p, x + 10.0, box.y + box.h / 2.0, kind, fg);
    text(p, x + 26.0, box.y + (box.h - height(font)) / 2.0 - 1.0, label, font, fg);
    enabled && clicked(p, box)
}

// A gradient across one rectangle: Nuklear blends the four corners, which is
// all the depth these panels need.
fn veil_v(p: const Pen&, box: ui::Rect, top: ui::Color, bottom: ui::Color) {
    ui::fill_rect_multi_color(p.ctx, box, top, top, bottom, bottom);
}

fn veil_h(p: const Pen&, box: ui::Rect, left: ui::Color, right: ui::Color) {
    ui::fill_rect_multi_color(p.ctx, box, left, right, right, left);
}

// The icons of the launcher, drawn in a 20 x 20 box around cx, cy: a font
// would need a glyph set zoo does not ship, and these stay sharp at the one
// size they are used in.
let GLYPH_PLAY = 0;
let GLYPH_VERSIONS = 1;
let GLYPH_CONTENT = 2;
let GLYPH_WORLDS = 3;
let GLYPH_SETUP = 4;
let GLYPH_LABEL = 5;
let GLYPH_QUIT = 6;
let GLYPH_REFRESH = 7;
let GLYPH_DOWN = 8;

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
            let y = cy - s + 1.0 + i * 7.0;
            ui::fill_rect(p.ctx, r(cx - s, y, 4.0, 4.0), 1.0, color);
            ui::fill_rect(p.ctx, r(cx - s + 7.0, y + 1.0, s + 7.0, 2.0), 1.0, color);
            i++;
        }
    } else if kind == GLYPH_CONTENT {
        // A cube, seen from a corner: the top face and two sides.
        let dim = with_alpha(color, 175);
        ui::fill_triangle(p.ctx, cx, cy - s, cx + s, cy - s / 2.0, cx, cy, color);
        ui::fill_triangle(p.ctx, cx, cy - s, cx - s, cy - s / 2.0, cx, cy, dim);
        ui::fill_triangle(p.ctx, cx - s, cy - s / 2.0, cx, cy, cx, cy + s, color);
        ui::fill_triangle(p.ctx, cx - s, cy - s / 2.0, cx - s, cy + s / 2.0, cx, cy + s, dim);
    } else if kind == GLYPH_WORLDS {
        // A globe: the circle, its equator and its meridian.
        ui::stroke_circle(p.ctx, r(cx - s + 1.0, cy - s + 1.0, 2.0 * s - 2.0, 2.0 * s - 2.0), 1.6, color);
        ui::stroke_line(p.ctx, cx - s + 1.0, cy, cx + s - 1.0, cy, 1.4, color);
        ui::stroke_line(p.ctx, cx, cy - s + 1.0, cx, cy + s - 1.0, 1.4, color);
    } else if kind == GLYPH_SETUP {
        // A gear: the ring, its hub and four teeth.
        ui::stroke_circle(p.ctx, r(cx - 6.0, cy - 6.0, 12.0, 12.0), 1.6, color);
        ui::fill_circle(p.ctx, r(cx - 2.2, cy - 2.2, 4.4, 4.4), color);
        ui::fill_rect(p.ctx, r(cx - 1.5, cy - 10.0, 3.0, 4.0), 1.0, color);
        ui::fill_rect(p.ctx, r(cx - 1.5, cy + 6.0, 3.0, 4.0), 1.0, color);
        ui::fill_rect(p.ctx, r(cx - 10.0, cy - 1.5, 4.0, 3.0), 1.0, color);
        ui::fill_rect(p.ctx, r(cx + 6.0, cy - 1.5, 4.0, 3.0), 1.0, color);
    } else if kind == GLYPH_LABEL {
        // A museum tag: an outlined rectangle with a corner cut and a hole.
        ui::stroke_polyline(p.ctx, [float2 { cx - s, cy - s + 2.0 }, float2 { cx + s - 5.0, cy - s + 2.0 },
                                   float2 { cx + s, cy - 2.0 }, float2 { cx + s, cy + s - 2.0 },
                                   float2 { cx - s, cy + s - 2.0 }, float2 { cx - s, cy - s + 2.0 }],
                            1.5, color);
        ui::fill_circle(p.ctx, r(cx + s - 7.0, cy - s + 4.0, 2.4, 2.4), color);
    } else if kind == GLYPH_REFRESH {
        // A circular arrow. The arc leaves a gap on the upper right where the
        // arrowhead goes; the head's points are precomputed for radius 8.
        ui::stroke_arc(p.ctx, cx, cy, 8.0, 0.6, 5.6, 1.8, color);
        ui::fill_triangle(p.ctx, cx + 9.4, cy - 7.7, cx + 3.0, cy - 2.4, cx + 8.7, cy - 1.9, color);
    } else if kind == GLYPH_DOWN {
        // Into the collection: an arrow down onto a tray.
        ui::stroke_line(p.ctx, cx, cy - s + 1.0, cx, cy + 3.0, 1.8, color);
        ui::fill_triangle(p.ctx, cx - 4.5, cy, cx + 4.5, cy, cx, cy + 6.0, color);
        ui::stroke_polyline(p.ctx, [float2 { cx - 7.0, cy + 5.0 }, float2 { cx - 7.0, cy + s },
                                   float2 { cx + 7.0, cy + s }, float2 { cx + 7.0, cy + 5.0 }], 1.8, color);
    } else {
        // Leaving: an arrow pointing out to the left, through a door frame.
        ui::stroke_line(p.ctx, cx - s, cy, cx + 3.0, cy, 1.6, color);
        ui::fill_triangle(p.ctx, cx - s - 2.0, cy, cx - s + 5.0, cy - 5.0, cx - s + 5.0, cy + 5.0, color);
        ui::stroke_polyline(p.ctx, [float2 { cx + 5.0, cy - s + 1.0 }, float2 { cx + s, cy - s + 1.0 },
                                   float2 { cx + s, cy + s - 1.0 }, float2 { cx + 5.0, cy + s - 1.0 }], 1.6, color);
    }
}

// One item of the sidebar: an icon and its name, the active one on a pill
// with an accent bar, as the two concepts light the page you are on.
fn nav_item(p: const Pen&, box: ui::Rect, label: const u8[:], kind: i64, active: bool) -> bool {
    let over = hovered(p, box);
    if active {
        ui::fill_rect(p.ctx, box, 10.0, theme::ACCENT_SOFT);
        ui::fill_rect(p.ctx, r(box.x - 8.0, box.y + 13.0, 3.0, box.h - 26.0), 1.5, theme::ACCENT);
    } else if over {
        ui::fill_rect(p.ctx, box, 10.0, theme::SURFACE);
    }
    let color = if active { theme::ACCENT } else if over { theme::INK } else { theme::MUTED };
    glyph(p, box.x + 24.0, box.y + box.h / 2.0, kind, color);
    text(p, box.x + 48.0, box.y + (box.h - height(p.fonts.medium)) / 2.0 - 1.0, label,
         p.fonts.medium, if active { theme::INK } else { color });
    clicked(p, box)
}

// zoo's mark: the specimen dot in a rounded tile, where the concept has its
// cat. Drawn, not an image file, so the tile scales with the window.
fn mark(p: const Pen&, tile: ui::Rect) {
    let cx = tile.x + tile.w / 2.0;
    let cy = tile.y + tile.h / 2.0;
    let rad = min(tile.w, tile.h) * 0.28;
    ui::fill_circle(p.ctx, r(cx - rad, cy - rad, 2.0 * rad, 2.0 * rad), theme::ACCENT);
    ui::fill_circle(p.ctx, r(cx - rad + 3.0, cy - rad + 2.0, rad * 0.95, rad * 0.95), theme::BG);
    ui::fill_circle(p.ctx, r(cx - 2.0, cy - 2.0, rad * 0.7, rad * 0.7), theme::ACCENT);
}

// The small state pill above a title: a dot in the state's colour and the
// word beside it.
fn state_pill(p: const Pen&, x: f32, y: f32, label: const u8[:], color: ui::Color) -> f32 {
    let font = p.fonts.tiny;
    let w = width(font, label) + 40.0;
    ui::fill_rect(p.ctx, r(x, y, w, 26.0), 13.0, with_alpha(theme::SURFACE, 210));
    ui::stroke_rect(p.ctx, r(x, y, w, 26.0), 13.0, 1.0, with_alpha(theme::LINE, 200));
    ui::fill_circle(p.ctx, r(x + 13.0, y + 10.0, 6.0, 6.0), color);
    text(p, x + 26.0, y + 7.0, label, font, theme::INK);
    w
}

// An outlined pill, as the facts under a title are drawn.
fn outline_pill(p: const Pen&, x: f32, y: f32, label: const u8[:], color: ui::Color) -> f32 {
    let font = p.fonts.small;
    let w = width(font, label) + 28.0;
    let box = r(x, y, w, 30.0);
    ui::fill_rect(p.ctx, box, 15.0, with_alpha(theme::SURFACE, 190));
    ui::stroke_rect(p.ctx, box, 15.0, 1.0, theme::LINE);
    text(p, x + 14.0, y + 7.0, label, font, color);
    w
}

// The toggle of the content lists: a track with a knob, accent when on.
fn toggle(p: const Pen&, x: f32, y: f32, on: bool) -> bool {
    let box = r(x, y, 40.0, 22.0);
    let over = hovered(p, box);
    ui::fill_rect(p.ctx, box, 11.0, if on { theme::ACCENT } else if over { theme::SURFACE_HOVER } else { theme::SURFACE });
    if !on { ui::stroke_rect(p.ctx, box, 11.0, 1.0, theme::LINE); }
    let knob_x = if on { x + 40.0 - 19.0 } else { x + 3.0 };
    ui::fill_circle(p.ctx, r(knob_x, y + 3.0, 16.0, 16.0), if on { theme::ON_ACCENT } else { theme::MUTED });
    clicked(p, box)
}

// A square button carrying one glyph, for a toolbar.
fn icon_button(p: const Pen&, box: ui::Rect, kind: i64) -> bool {
    let over = hovered(p, box);
    ui::fill_rect(p.ctx, box, 12.0, if over { theme::SURFACE_HOVER } else { theme::SURFACE });
    ui::stroke_rect(p.ctx, box, 12.0, 1.0, theme::LINE);
    glyph(p, box.x + box.w / 2.0, box.y + box.h / 2.0, kind, if over { theme::INK } else { theme::MUTED });
    clicked(p, box)
}

// A selected-state circle for the theme list.
fn check(p: const Pen&, cx: f32, cy: f32, on: bool) {
    if on {
        ui::fill_circle(p.ctx, r(cx - 8.0, cy - 8.0, 16.0, 16.0), theme::ACCENT);
        ui::fill_circle(p.ctx, r(cx - 3.0, cy - 3.0, 6.0, 6.0), theme::ON_ACCENT);
    } else {
        ui::stroke_circle(p.ctx, r(cx - 8.0, cy - 8.0, 16.0, 16.0), 1.0, theme::LINE);
    }
}

// A thin scroll indicator for a list driven by the wheel: a faint track with
// a thumb that says where in the list the view is.
fn scrollbar(p: const Pen&, track: ui::Rect, content_h: f32, view_h: f32, offset: f32) {
    if content_h <= view_h || track.h <= 0.0 { return; }
    ui::fill_rect(p.ctx, r(track.x, track.y, 3.0, track.h), 1.5, with_alpha(theme::LINE, 120));
    let thumb_h = max(24.0, track.h * (view_h / content_h));
    let room = track.h - thumb_h;
    let t = clamp(offset / (content_h - view_h), 0.0, 1.0);
    ui::fill_rect(p.ctx, r(track.x, track.y + room * t, 3.0, thumb_h), 1.5,
                  with_alpha(theme::INK, 70));
}

// A full-bleed image cover-cropped into a box: the backdrop and the hero
// cards use it so a window resize never stretches the picture.
fn cover(img: ui::Image, box: ui::Rect) -> ui::Image {
    let sw = img.w as f32;
    let sh = img.h as f32;
    if sw <= 0.0 || sh <= 0.0 || box.w <= 0.0 || box.h <= 0.0 { return img; }
    let scale = max(box.w / sw, box.h / sh);
    let rw = box.w / scale;
    let rh = box.h / scale;
    let rx = (sw - rw) * 0.5;
    let ry = (sh - rh) * 0.5;
    ui::subimage_id(img.texture, img.w, img.h, ui::Rect { x: rx, y: ry, w: rw, h: rh })
}
