// The launcher's colour schemes. A new one is one more entry in PALETTES;
// theme::use_palette copies the chosen one into the roles the views name.
//
// Every scheme keeps the same relationships: a near-black ground, panels a
// step above it, one saturated accent for action and selection, leaf green
// for "ready" and rust for "failed". Only the hues move.
import std;
import ui;
namespace palette;

struct Palette {
    palette_name: const u8[:],
    note: const u8[:],
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
    glass: ui::Color,            // a panel that sits over the hero image
    accent_soft: ui::Color,      // a selection wash, accent at low alpha
    shadow: ui::Color,           // what floats above the ground casts
    skyline: ui::Color,
    band_accent: ui::Color,
    band_leaf: ui::Color,
    band_stone: ui::Color,
}

// The look the launcher opens with: a blue-black ground and the cyan of the
// two launcher concepts it borrows its shape from.
let NIGHT = Palette {
    palette_name: "Night",
    note: "Blue-black and cyan",
    bg: ui::Color { 9, 11, 15, 255 },
    surface: ui::Color { 17, 20, 27, 255 },
    surface_hover: ui::Color { 26, 31, 40, 255 },
    line: ui::Color { 34, 40, 50, 255 },
    ink: ui::Color { 238, 243, 250, 255 },
    muted: ui::Color { 150, 161, 176, 255 },
    faint: ui::Color { 92, 103, 118, 255 },
    accent: ui::Color { 44, 156, 255, 255 },
    accent_hover: ui::Color { 86, 178, 255, 255 },
    on_accent: ui::Color { 5, 18, 33, 255 },
    leaf: ui::Color { 92, 208, 140, 255 },
    rust: ui::Color { 240, 122, 106, 255 },
    panel: ui::Color { 12, 15, 20, 255 },
    chip: ui::Color { 22, 48, 72, 255 },
    glow: ui::Color { 44, 156, 255, 40 },
    glass: ui::Color { 13, 17, 23, 232 },
    accent_soft: ui::Color { 44, 156, 255, 38 },
    shadow: ui::Color { 0, 0, 0, 120 },
    skyline: ui::Color { 19, 24, 32, 255 },
    band_accent: ui::Color { 18, 51, 78, 255 },
    band_leaf: ui::Color { 18, 56, 42, 255 },
    band_stone: ui::Color { 26, 31, 39, 255 },
};

// Colours sampled from the Gigacat launcher concept (see
// THIRD_PARTY_NOTICES.md): a violet-black ground and a muted purple.
let AMETHYST = Palette {
    palette_name: "Amethyst",
    note: "Violet-black and purple",
    bg: ui::Color { 11, 10, 15, 255 },
    surface: ui::Color { 23, 21, 30, 255 },
    surface_hover: ui::Color { 34, 30, 45, 255 },
    line: ui::Color { 44, 39, 56, 255 },
    ink: ui::Color { 241, 238, 248, 255 },
    muted: ui::Color { 158, 151, 174, 255 },
    faint: ui::Color { 102, 96, 118, 255 },
    accent: ui::Color { 129, 98, 220, 255 },
    accent_hover: ui::Color { 152, 124, 238, 255 },
    on_accent: ui::Color { 248, 244, 255, 255 },
    leaf: ui::Color { 126, 204, 138, 255 },
    rust: ui::Color { 228, 120, 120, 255 },
    panel: ui::Color { 16, 15, 21, 255 },
    chip: ui::Color { 54, 42, 76, 255 },
    glow: ui::Color { 129, 98, 220, 42 },
    glass: ui::Color { 17, 15, 23, 232 },
    accent_soft: ui::Color { 129, 98, 220, 40 },
    shadow: ui::Color { 0, 0, 0, 120 },
    skyline: ui::Color { 25, 22, 33, 255 },
    band_accent: ui::Color { 58, 42, 88, 255 },
    band_leaf: ui::Color { 30, 54, 44, 255 },
    band_stone: ui::Color { 36, 34, 44, 255 },
};

// zoo's first palette: a warm near-black, one sand accent, leaf for "ready".
let SAND = Palette {
    palette_name: "Sand",
    note: "Warm black and sand",
    bg: ui::Color { 16, 15, 13, 255 },
    surface: ui::Color { 30, 28, 25, 255 },
    surface_hover: ui::Color { 44, 40, 35, 255 },
    line: ui::Color { 48, 44, 39, 255 },
    ink: ui::Color { 241, 234, 222, 255 },
    muted: ui::Color { 158, 149, 135, 255 },
    faint: ui::Color { 104, 97, 88, 255 },
    accent: ui::Color { 230, 172, 78, 255 },
    accent_hover: ui::Color { 243, 190, 106, 255 },
    on_accent: ui::Color { 33, 22, 8, 255 },
    leaf: ui::Color { 140, 192, 132, 255 },
    rust: ui::Color { 224, 122, 95, 255 },
    panel: ui::Color { 21, 20, 18, 255 },
    chip: ui::Color { 58, 47, 30, 255 },
    glow: ui::Color { 230, 172, 78, 36 },
    glass: ui::Color { 22, 20, 17, 232 },
    accent_soft: ui::Color { 230, 172, 78, 36 },
    shadow: ui::Color { 0, 0, 0, 120 },
    skyline: ui::Color { 31, 28, 24, 255 },
    band_accent: ui::Color { 62, 48, 28, 255 },
    band_leaf: ui::Color { 34, 48, 34, 255 },
    band_stone: ui::Color { 40, 38, 35, 255 },
};

// Night first: it is the look the shell was drawn for, and a fresh install
// should show it. The palettes a player has chosen before are found by name.
let PALETTES: Palette[3] = [NIGHT, AMETHYST, SAND];
