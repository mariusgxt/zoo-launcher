// Zoo's colours: a dusk savanna, warm dark ground with a sand accent and a
// leaf green for "ready". Kept in one table so a later light theme is one
// more function, not a hunt through the view code.
import std;
import ui;
namespace theme;

let INK = ui::Color { 236, 226, 208, 255 };
let MUTED = ui::Color { 160, 148, 128, 255 };
let SAND = ui::Color { 226, 168, 74, 255 };
let LEAF = ui::Color { 128, 186, 112, 255 };
let RUST = ui::Color { 214, 104, 82, 255 };
let GROUND = ui::Color { 30, 27, 23, 255 };
let PANEL = ui::Color { 40, 36, 31, 255 };

fn apply(ctx: ui::Context) {
    var t = ui::default_color_table();
    t[ui::COLOR_TEXT] = INK;
    t[ui::COLOR_WINDOW] = GROUND;
    t[ui::COLOR_HEADER] = PANEL;
    t[ui::COLOR_BORDER] = ui::Color { 70, 62, 52, 255 };
    t[ui::COLOR_BUTTON] = ui::Color { 92, 70, 40, 255 };
    t[ui::COLOR_BUTTON_HOVER] = ui::Color { 124, 92, 48, 255 };
    t[ui::COLOR_BUTTON_ACTIVE] = SAND;
    t[ui::COLOR_TOGGLE] = ui::Color { 60, 54, 46, 255 };
    t[ui::COLOR_TOGGLE_HOVER] = ui::Color { 80, 72, 60, 255 };
    t[ui::COLOR_TOGGLE_CURSOR] = SAND;
    t[ui::COLOR_SELECT] = GROUND;
    t[ui::COLOR_SELECT_ACTIVE] = ui::Color { 104, 80, 46, 255 };
    t[ui::COLOR_SLIDER] = ui::Color { 60, 54, 46, 255 };
    t[ui::COLOR_SLIDER_CURSOR] = SAND;
    t[ui::COLOR_SLIDER_CURSOR_HOVER] = SAND;
    t[ui::COLOR_SLIDER_CURSOR_ACTIVE] = SAND;
    t[ui::COLOR_SCROLLBAR] = PANEL;
    t[ui::COLOR_SCROLLBAR_CURSOR] = ui::Color { 92, 82, 68, 255 };
    t[ui::COLOR_SCROLLBAR_CURSOR_HOVER] = ui::Color { 120, 106, 88, 255 };
    t[ui::COLOR_SCROLLBAR_CURSOR_ACTIVE] = SAND;
    ui::style_from_table(ctx, t);
}
