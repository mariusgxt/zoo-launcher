// The launcher's colour schemes. A new one is one more entry in PALETTES;
// theme::use_palette copies the chosen one into the roles the views name.
import std;
import ui;
namespace palette;

struct Palette {
    palette_name: const u8[:],
    bg: ui::Color,
    surface: ui::Color,
    surface_hover: ui::Color,
    line: ui::Color,
    ink: ui::Color,
    muted: ui::Color,
    faint: ui::Color,
    accent: ui::Color,
    accent_hover: ui::Color,
    on_accent: ui::Color,
    leaf: ui::Color,
    rust: ui::Color,
    panel: ui::Color,
    chip: ui::Color,
    glow: ui::Color,
    skyline: ui::Color,
    band_accent: ui::Color,
    band_leaf: ui::Color,
    band_stone: ui::Color,
}

// zoo's own: a near-black warm ground, one sand accent, leaf green for "ready".
let SAND = Palette {
    palette_name: "Sand",
    bg: ui::Color { 18, 17, 15, 255 },
    surface: ui::Color { 31, 29, 26, 255 },
    surface_hover: ui::Color { 42, 39, 35, 255 },
    line: ui::Color { 44, 41, 37, 255 },
    ink: ui::Color { 239, 232, 220, 255 },
    muted: ui::Color { 146, 138, 125, 255 },
    faint: ui::Color { 96, 90, 82, 255 },
    accent: ui::Color { 226, 168, 74, 255 },
    accent_hover: ui::Color { 238, 186, 102, 255 },
    on_accent: ui::Color { 33, 22, 8, 255 },
    leaf: ui::Color { 140, 192, 132, 255 },
    rust: ui::Color { 224, 122, 95, 255 },
    panel: ui::Color { 24, 23, 21, 255 },
    chip: ui::Color { 52, 42, 28, 255 },
    glow: ui::Color { 226, 168, 74, 34 },
    skyline: ui::Color { 34, 31, 27, 255 },
    band_accent: ui::Color { 58, 45, 26, 255 },
    band_leaf: ui::Color { 34, 48, 34, 255 },
    band_stone: ui::Color { 40, 38, 35, 255 },
};

// Colours sampled from the Gigacat launcher concept (see
// THIRD_PARTY_NOTICES.md): a violet-black ground and a muted purple.
let AMETHYST = Palette {
    palette_name: "Amethyst",
    bg: ui::Color { 14, 13, 17, 255 },
    surface: ui::Color { 30, 28, 37, 255 },
    surface_hover: ui::Color { 42, 38, 54, 255 },
    line: ui::Color { 40, 37, 50, 255 },
    ink: ui::Color { 238, 235, 245, 255 },
    muted: ui::Color { 150, 144, 166, 255 },
    faint: ui::Color { 96, 91, 112, 255 },
    accent: ui::Color { 112, 84, 170, 255 },
    accent_hover: ui::Color { 132, 102, 194, 255 },
    on_accent: ui::Color { 246, 242, 255, 255 },
    leaf: ui::Color { 126, 204, 138, 255 },
    rust: ui::Color { 228, 120, 120, 255 },
    panel: ui::Color { 23, 22, 28, 255 },
    chip: ui::Color { 60, 46, 83, 255 },
    glow: ui::Color { 120, 80, 200, 46 },
    skyline: ui::Color { 30, 25, 42, 255 },
    band_accent: ui::Color { 62, 42, 96, 255 },
    band_leaf: ui::Color { 30, 54, 44, 255 },
    band_stone: ui::Color { 38, 36, 46, 255 },
};

// Amethyst first: it is the look the launcher was drawn for, and a fresh
// install should show that one.
let PALETTES: Palette[2] = [AMETHYST, SAND];
