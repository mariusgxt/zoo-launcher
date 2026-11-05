// One frame of the launcher window: the ground, the rail, the top bar, and
// whichever page the rail points at. The pages read the state and say what
// they want done; the main loop does it, so a frame has no side effects of
// its own beyond what the state carries.
import std;
import ui;
import zoo.minecraft.content;
import zoo.world.saves;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
import zoo.app.chrome;
import zoo.app.pages.play;
import zoo.app.pages.versions;
import zoo.app.pages.shelf;
import zoo.app.pages.worlds;
import zoo.app.pages.settings;
import zoo.app.pages.label;
namespace view;

fn draw(ctx: ui::Context, fonts: const theme::Fonts&, s: state::State&,
        items: content::Item[>..]&, found: const saves::Save[:], w: f32, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    if ui::begin(ctx, "zoo", ui::rect(0.0, 0.0, w, h), ui::WINDOW_NO_SCROLLBAR) {
        let p = kit::Pen { ctx: ctx, fonts: fonts };
        chrome::draw_ground(p, w, h);
        if s.page == state::PAGE_PLAY { want = play::draw(p, s, w, h); }
        else if s.page == state::PAGE_VERSIONS { versions::draw(p, s, w, h); }
        else if s.page == state::PAGE_CONTENT { shelf::draw(p, s, items, w, h); }
        else if s.page == state::PAGE_WORLDS { worlds::draw(p, s, found, w, h); }
        else if s.page == state::PAGE_SETTINGS { want = settings::draw(p, s, w, h); }
        else { want = label::draw(p, s, w, h); }
        chrome::draw_top(p, s, w);
        let rail_want = chrome::draw_rail(p, s, h);
        if rail_want != state::WANT_NOTHING { want = rail_want; }
        chrome::draw_foot(p, s, w, h);
    }
    ui::end(ctx);
    want
}
