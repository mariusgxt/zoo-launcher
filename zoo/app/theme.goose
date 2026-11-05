// Zoo's look. Colours and fonts live here together so the view code only
// ever names a role (muted, accent, title), never a value.
import std;
import os;
import ui;
import zoo.app.palette;
namespace theme;

// The roles are variables, filled from a palette.Palette, so a theme switch
// reaches every view without passing the palette through each call.
var BG = palette::AMETHYST.bg;
var SURFACE = palette::AMETHYST.surface;
var SURFACE_HOVER = palette::AMETHYST.surface_hover;
var LINE = palette::AMETHYST.line;
var INK = palette::AMETHYST.ink;
var MUTED = palette::AMETHYST.muted;
var FAINT = palette::AMETHYST.faint;
var ACCENT = palette::AMETHYST.accent;
var ACCENT_HOVER = palette::AMETHYST.accent_hover;
var ON_ACCENT = palette::AMETHYST.on_accent;
var LEAF = palette::AMETHYST.leaf;
var RUST = palette::AMETHYST.rust;
var PANEL = palette::AMETHYST.panel;
var CHIP = palette::AMETHYST.chip;
var GLOW = palette::AMETHYST.glow;
var SKYLINE = palette::AMETHYST.skyline;
var BAND_ACCENT = palette::AMETHYST.band_accent;
var BAND_LEAF = palette::AMETHYST.band_leaf;
var BAND_STONE = palette::AMETHYST.band_stone;
var CURRENT: i64 = 0;
let NONE = ui::Color { 0, 0, 0, 0 };

let INTER: const u8[:] = embed_file("../../assets/fonts/Inter-Regular.otf");
let INTER_MEDIUM: const u8[:] = embed_file("../../assets/fonts/Inter-Medium.otf");
let INTER_ITALIC: const u8[:] = embed_file("../../assets/fonts/Inter-Italic.otf");
let DISPLAY: const u8[:] = embed_file("../../assets/fonts/InterDisplay-SemiBold.otf");
let MONO: const u8[:] = embed_file("../../assets/fonts/JetBrainsMono-Regular.ttf");

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
        body: ui::add_font_from_memory(a, INTER, 15.0),
        medium: ui::add_font_from_memory(a, INTER_MEDIUM, 15.0),
        small: ui::add_font_from_memory(a, INTER, 13.0),
        italic: ui::add_font_from_memory(a, INTER_ITALIC, 16.0),
        mono: ui::add_font_from_memory(a, MONO, 13.0),
        tiny: ui::add_font_from_memory(a, MONO, 10.0),
        heading: ui::add_font_from_memory(a, DISPLAY, 42.0),
        title: ui::add_font_from_memory(a, DISPLAY, 60.0),
        hero: ui::add_font_from_memory(a, DISPLAY, 104.0),
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

// Takes a palette by its index in palette::PALETTES; out of range keeps Sand.
fn use_palette(ctx: ui::Context, theme_index: i64) {
    let theme_i = if theme_index >= 0 && theme_index < palette::PALETTES.len { theme_index } else { 0 };
    let t = palette::PALETTES[theme_i];
    BG = t.bg; SURFACE = t.surface; SURFACE_HOVER = t.surface_hover; LINE = t.line;
    INK = t.ink; MUTED = t.muted; FAINT = t.faint;
    ACCENT = t.accent; ACCENT_HOVER = t.accent_hover; ON_ACCENT = t.on_accent;
    LEAF = t.leaf; RUST = t.rust;
    PANEL = t.panel; CHIP = t.chip; GLOW = t.glow; SKYLINE = t.skyline;
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
