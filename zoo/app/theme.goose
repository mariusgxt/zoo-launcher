// Zoo's look. Colours and fonts live here together so the view code only
// ever names a role (muted, accent, title), never a value.
import std;
import os;
import ui;
import zoo.app.palette;
namespace theme;

// The roles are variables, filled from a palette.Palette, so a theme switch
// reaches every view without passing the palette through each call.
var BG = palette::NIGHT.bg;
var SURFACE = palette::NIGHT.surface;
var SURFACE_HOVER = palette::NIGHT.surface_hover;
var LINE = palette::NIGHT.line;
var INK = palette::NIGHT.ink;
var MUTED = palette::NIGHT.muted;
var FAINT = palette::NIGHT.faint;
var ACCENT = palette::NIGHT.accent;
var ACCENT_HOVER = palette::NIGHT.accent_hover;
var ON_ACCENT = palette::NIGHT.on_accent;
var LEAF = palette::NIGHT.leaf;
var RUST = palette::NIGHT.rust;
var PANEL = palette::NIGHT.panel;
var CHIP = palette::NIGHT.chip;
var GLOW = palette::NIGHT.glow;
var GLASS = palette::NIGHT.glass;
var ACCENT_SOFT = palette::NIGHT.accent_soft;
var SHADOW = palette::NIGHT.shadow;
var SKYLINE = palette::NIGHT.skyline;
var BAND_ACCENT = palette::NIGHT.band_accent;
var BAND_LEAF = palette::NIGHT.band_leaf;
var BAND_STONE = palette::NIGHT.band_stone;
var CURRENT: i64 = 0;
let NONE = ui::Color { 0, 0, 0, 0 };
let WHITE = ui::Color { 255, 255, 255, 255 };

let INTER: const u8[:] = embed_file("../../assets/fonts/Inter-Regular.otf");
let INTER_MEDIUM: const u8[:] = embed_file("../../assets/fonts/Inter-Medium.otf");
let INTER_ITALIC: const u8[:] = embed_file("../../assets/fonts/Inter-Italic.otf");
let DISPLAY: const u8[:] = embed_file("../../assets/fonts/InterDisplay-SemiBold.otf");
let DISPLAY_BOLD: const u8[:] = embed_file("../../assets/fonts/InterDisplay-Bold.otf");
let MONO: const u8[:] = embed_file("../../assets/fonts/JetBrainsMono-Regular.ttf");

// The Play page's backdrop: zoo's own client drawing its demo world. It is
// zoo's picture of itself, so no Minecraft art is shipped or copied.
let BACKDROP: const u8[:] = embed_file("../../docs/media/client.png");

struct Fonts {
    atlas: ui::FontAtlas,
    body: ui::Font,
    medium: ui::Font,
    small: ui::Font,
    italic: ui::Font,
    mono: ui::Font,
    tiny: ui::Font,
    heading: ui::Font,
    title: ui::Font,
    hero: ui::Font,
}

// One atlas for every size, baked once; the context draws its own widgets
// with `body` and the canvas picks the others per call.
fn load_fonts() -> Fonts, bool {
    let a = ui::create_font_atlas();
    var f = Fonts {
        atlas: a,
        body: ui::add_font_from_memory(a, INTER, 14.0),
        medium: ui::add_font_from_memory(a, INTER_MEDIUM, 14.0),
        small: ui::add_font_from_memory(a, INTER, 12.0),
        italic: ui::add_font_from_memory(a, INTER_ITALIC, 15.0),
        mono: ui::add_font_from_memory(a, MONO, 12.0),
        tiny: ui::add_font_from_memory(a, MONO, 10.0),
        heading: ui::add_font_from_memory(a, DISPLAY, 20.0),
        title: ui::add_font_from_memory(a, DISPLAY, 34.0),
        hero: ui::add_font_from_memory(a, DISPLAY_BOLD, 64.0),
    };
    let ok = ui::bake(a);
    return f, ok;
}

fn apply(ctx: ui::Context) {
    var s = ui::style(ctx);
    s.window.fixed_background = ui::style_item_color(BG);
    s.window.background = BG;
    s.window.padding = float2 { 0.0, 0.0 };
    s.window.border = 0.0;
    s.text.color = INK;
    ui::set_style(ctx, s);
}

// Takes a palette by its index in palette::PALETTES; out of range keeps Night.
fn use_palette(ctx: ui::Context, theme_index: i64) {
    let theme_i = if theme_index >= 0 && theme_index < palette::PALETTES.len { theme_index } else { 0 };
    let t = palette::PALETTES[theme_i];
    BG = t.bg; SURFACE = t.surface; SURFACE_HOVER = t.surface_hover; LINE = t.line;
    INK = t.ink; MUTED = t.muted; FAINT = t.faint;
    ACCENT = t.accent; ACCENT_HOVER = t.accent_hover; ON_ACCENT = t.on_accent;
    LEAF = t.leaf; RUST = t.rust;
    PANEL = t.panel; CHIP = t.chip; GLOW = t.glow; GLASS = t.glass;
    ACCENT_SOFT = t.accent_soft; SHADOW = t.shadow; SKYLINE = t.skyline;
    BAND_ACCENT = t.band_accent; BAND_LEAF = t.band_leaf; BAND_STONE = t.band_stone;
    CURRENT = theme_i;
    apply(ctx);
}

// The choice is one line of text in the collection folder, the palette's
// name rather than its index, so reordering PALETTES keeps old choices.
fn choice_path(home: const u8[:]) -> u8[>..] { str(home, "/theme") }

fn load_choice(home: const u8[:]) -> i64 {
    var saved: u8[>..] = [];
    if !read_file(choice_path(home), saved) { return 0; }
    for t, i in palette::PALETTES { if starts_with(saved, t.palette_name) { return i; } }
    0
}

fn save_choice(home: const u8[:]) {
    write_file(choice_path(home), str(palette::PALETTES[CURRENT].palette_name, "\n"));
}
