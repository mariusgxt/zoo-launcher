// The page zoo opens on. The shape is the Gigacat concept's: a wordmark
// over the ground, facts about the chosen version as pills, and a row of
// cards along the foot. The action bar that holds the version picker and
// the main button together is from the Zenith launcher concept; both are
// credited in THIRD_PARTY_NOTICES.md.
import std;
import ui;
import zoo.specimen;
import zoo.collection;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace play;

// One card of the strip: a coloured band where the concept has a picture,
// then what the step is about and the one thing to do there.
struct Card {
    band: ui::Color,
    tag: const u8[:],
    num: const u8[:],          // large on the band, where the concept has art
    title: const u8[:],
    detail: const u8[:],
    detail_color: ui::Color,
    action: const u8[:],
    foot: const u8[:],         // shown when there is nothing to click
    enabled: bool,
}

fn draw_card(p: const kit::Pen&, box: ui::Rect, c: const Card&) -> bool {
    ui::fill_rect(p.ctx, box, 14.0, theme::SURFACE);
    let band_h = box.h * 0.46;
    ui::fill_rect(p.ctx, kit::r(box.x, box.y, box.w, band_h), 14.0, c.band);
    // The tag sits on the band, as the concept's news cards carry theirs.
    let tw = kit::width(p.fonts.tiny, c.tag) + 20.0;
    ui::fill_rect(p.ctx, kit::r(box.x + 12.0, box.y + 12.0, tw, 20.0), 10.0, theme::BG);
    kit::text(p, box.x + 22.0, box.y + 16.0, c.tag, p.fonts.tiny, theme::INK);
    // The band carried nothing but the tag and read as a blank stripe.
    kit::text_right(p, box.x + box.w - 18.0, box.y + band_h - 54.0, c.num, p.fonts.heading, theme::BG);

    kit::text(p, box.x + 16.0, box.y + band_h + 12.0, c.title, p.fonts.medium, theme::INK);
    var d: u8[>..] = [];
    kit::fit(d, c.detail, p.fonts.small, box.w - 32.0);
    kit::text(p, box.x + 16.0, box.y + band_h + 36.0, d, p.fonts.small, c.detail_color);
    var hit = false;
    if c.action.len > 0 {
        hit = kit::button(p, kit::r(box.x + 16.0, box.y + box.h - 32.0, box.w - 32.0, 22.0),
                          c.action, kit::LINK, c.enabled);
    } else if c.foot.len > 0 {
        kit::text_right(p, box.x + box.w - 16.0, box.y + box.h - 30.0, c.foot, p.fonts.tiny, theme::FAINT);
    }
    hit
}

// The bar that carries the version picker, the main action and the two
// icon buttons, floating over the ground on its own panel.
fn draw_action_bar(p: const kit::Pen&, s: state::State&, box: ui::Rect) -> i64 {
    var want = state::WANT_NOTHING;
    ui::fill_rect(p.ctx, box, 18.0, theme::PANEL);
    ui::stroke_rect(p.ctx, box, 18.0, 1.0, theme::LINE);

    let has = state::chosen(s);
    let pick = kit::r(box.x + 10.0, box.y + 10.0, 250.0, box.h - 20.0);
    let over = kit::hovered(p, pick);
    if over { ui::fill_rect(p.ctx, pick, 12.0, theme::SURFACE_HOVER); }
    kit::text(p, pick.x + 16.0, pick.y + 10.0, "VERSION", p.fonts.tiny, theme::FAINT);
    let id = if has { str(s.rows[s.selected].id) } else { str("none chosen") };
    kit::text(p, pick.x + 16.0, pick.y + 24.0, id, p.fonts.medium, theme::INK);
    kit::chevron(p, pick.x + pick.w - 24.0, pick.y + pick.h / 2.0 - 2.0);
    if kit::clicked(p, pick) { s.page = state::PAGE_VERSIONS; }

    let label = if !has { "PREPARE" } else if s.busy { "PREPARING" }
                else if s.rows[s.selected].ready { "PREPARE AGAIN" } else { "PREPARE" };
    let act = kit::r(pick.x + pick.w + 12.0, box.y + 10.0, 230.0, box.h - 20.0);
    if kit::play_button(p, act, label, has && !s.busy) { want = state::WANT_OBTAIN; }

    let icon = box.h - 20.0;
    if kit::refresh_button(p, kit::r(act.x + act.w + 12.0, box.y + 10.0, icon, icon), !s.busy) {
        want = state::WANT_REFRESH;
    }
    let setup = kit::r(act.x + act.w + 12.0 + icon + 8.0, box.y + 10.0, icon, icon);
    if kit::icon_button(p, setup, kit::GLYPH_SETUP) { s.page = state::PAGE_SETTINGS; }
    want
}

// The panel beside the action bar: two numbers and where they are kept.
fn draw_side(p: const kit::Pen&, s: const state::State&, box: ui::Rect) {
    ui::fill_rect(p.ctx, box, 18.0, theme::PANEL);
    ui::stroke_rect(p.ctx, box, 18.0, 1.0, theme::LINE);
    let ready = state::prepared_count(s);
    kit::text(p, box.x + 20.0, box.y + 14.0, "PREPARED", p.fonts.tiny, theme::FAINT);
    let nw = kit::text(p, box.x + 20.0, box.y + 30.0, str(ready), p.fonts.heading, theme::INK);
    kit::text(p, box.x + 26.0 + nw, box.y + 48.0, str("of ", s.rows.len, " listed"), p.fonts.small, theme::MUTED);
    var home: u8[>..] = [];
    kit::fit(home, s.home, p.fonts.tiny, box.w - 40.0);
    kit::text_right(p, box.x + box.w - 20.0, box.y + box.h - 26.0, home, p.fonts.tiny, theme::FAINT);
}

fn draw(p: const kit::Pen&, s: state::State&, w: f32, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    let tag = specimen::current();
    let has = state::chosen(s);
    let x = state::content_x();
    let right = w - state::EDGE;

    // The state of the chosen version, in a pill above the name.
    var word: const u8[:] = "NO VERSION CHOSEN";
    var color = theme::MUTED;
    if has { word, color = state::readiness(s.rows[s.selected], s); }
    kit::state_pill(p, x, state::TOP_H + 22.0, word, color);

    // The name, with the specimen dot where the concept sets its plus.
    let zw = kit::text(p, x - 6.0, state::TOP_H + 48.0, "zoo", p.fonts.hero, theme::INK);
    ui::fill_circle(p.ctx, kit::r(x + zw - 2.0, state::TOP_H + 92.0, 24.0, 24.0), theme::ACCENT);

    var px = x;
    let edition = if has { str("Minecraft ", s.rows[s.selected].id) } else { str("No version") };
    px += kit::outline_pill(p, px, state::TOP_H + 172.0, edition, theme::INK) + 10.0;
    if has { px += kit::outline_pill(p, px, state::TOP_H + 172.0, state::upper(s.rows[s.selected].kind), theme::MUTED) + 10.0; }
    kit::outline_pill(p, px, state::TOP_H + 172.0, str(tag.scientific, " ", tag.version), theme::MUTED);

    kit::text(p, x, state::TOP_H + 222.0, "Minecraft: Java Edition, rewritten in Goose. This launcher prepares the", p.fonts.body, theme::MUTED);
    kit::text(p, x, state::TOP_H + 244.0, "resources the zoo client reads from your own copy of the game.", p.fonts.body, theme::MUTED);

    let bar = kit::r(x, state::TOP_H + 290.0, min(680.0, right - x), 76.0);
    want = draw_action_bar(p, s, bar);
    // The concept puts its friends list beside the play button. zoo has no
    // accounts, so the space carries the two counts the page is about.
    let side = kit::r(bar.x + bar.w + 16.0, bar.y, right - bar.x - bar.w - 16.0, bar.h);
    if side.w > 180.0 { draw_side(p, s, side); }
    if s.busy || s.stage == collection::STAGE_DONE {
        let part = if s.stage >= collection::STAGE_DONE { 5.0 } else { s.stage as f32 };
        kit::progress(p, kit::r(bar.x + 10.0, bar.y + bar.h + 10.0, bar.w - 20.0, 4.0), part, 5.0);
    }

    // The strip of cards along the foot.
    let strip_h = min(210.0, h - (bar.y + bar.h) - 76.0);
    let strip_y = h - state::EDGE - 44.0 - strip_h;
    let gap: f32 = 16.0;
    let cw = (right - x - 2.0 * gap) / 3.0;
    let ready = has && s.rows[s.selected].ready;

    let res_text = if !has { str("Choose a version first.") }
                   else if ready { str("Prepared for Minecraft ", s.rows[s.selected].id) }
                   else { str("Not prepared yet for Minecraft ", s.rows[s.selected].id) };
    let c1 = Card { band: theme::BAND_ACCENT, tag: "STEP 01", num: "01", title: "Resources", detail: res_text,
                    detail_color: if ready { theme::LEAF } else { theme::MUTED },
                    action: if ready { "Prepare again" } else { "Prepare" }, foot: "",
                    enabled: has && !s.busy };
    if draw_card(p, kit::r(x, strip_y, cw, strip_h), c1) { want = state::WANT_OBTAIN; }

    let mc_text = if s.game_found { str("Found at ", s.game_dir) }
                  else { str("Not found. zoo downloads the game from Mojang instead.") };
    let c2 = Card { band: theme::BAND_LEAF, tag: "STEP 02", num: "02", title: "Minecraft folder",
                    detail: mc_text, detail_color: theme::MUTED, action: "Look again", foot: "",
                    enabled: !s.busy };
    if draw_card(p, kit::r(x + cw + gap, strip_y, cw, strip_h), c2) { want = state::WANT_REFRESH; }

    let status_color = if s.stage == collection::STAGE_FAILED { theme::RUST }
                       else if s.stage == collection::STAGE_DONE { theme::LEAF } else { theme::MUTED };
    let status_text = if s.status.len > 0 { str(s.status) } else { str("Kept in ", s.home) };
    let stage_word = if s.busy { "working" }
                     else if s.stage == collection::STAGE_FAILED { "stopped" }
                     else if s.stage == collection::STAGE_DONE { "complete" } else { "idle" };
    let c3 = Card { band: theme::BAND_STONE, tag: "STEP 03", num: "03", title: "Collection",
                    detail: status_text, detail_color: status_color, action: "", foot: stage_word,
                    enabled: false };
    draw_card(p, kit::r(x + 2.0 * (cw + gap), strip_y, cw, strip_h), c3);
    want
}
