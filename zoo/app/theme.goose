// Zoo's look: a near-black warm ground, one sand accent, leaf green for
// "ready". Colours and fonts live here together so the view code only ever
// names a role (muted, accent, title), never a value.
import std;
import ui;
namespace theme;

let BG = ui::Color { 18, 17, 15, 255 };
let SURFACE = ui::Color { 31, 29, 26, 255 };
let SURFACE_HOVER = ui::Color { 42, 39, 35, 255 };
let LINE = ui::Color { 44, 41, 37, 255 };
let INK = ui::Color { 239, 232, 220, 255 };
let MUTED = ui::Color { 146, 138, 125, 255 };
let FAINT = ui::Color { 96, 90, 82, 255 };
let ACCENT = ui::Color { 226, 168, 74, 255 };
let ACCENT_HOVER = ui::Color { 238, 186, 102, 255 };
let ON_ACCENT = ui::Color { 33, 22, 8, 255 };
let LEAF = ui::Color { 140, 192, 132, 255 };
let RUST = ui::Color { 224, 122, 95, 255 };
// The play page's stage, after the Gigacat launcher concept: a raised panel
// for the cards, a warm glow behind the title and a blocky skyline in it.
let PANEL = ui::Color { 24, 23, 21, 255 };
let CHIP = ui::Color { 52, 42, 28, 255 };
let GLOW = ui::Color { 226, 168, 74, 34 };
let SKYLINE = ui::Color { 34, 31, 27, 255 };
let BAND_SAND = ui::Color { 58, 45, 26, 255 };
let BAND_LEAF = ui::Color { 34, 48, 34, 255 };
let BAND_STONE = ui::Color { 40, 38, 35, 255 };
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
