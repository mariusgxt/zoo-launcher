// The page zoo opens on: zoo's own client render across the top, the chosen
// version over it and a floating dock that holds the version picker and the
// main action. The dock is the Zenith client's (THIRD_PARTY_NOTICES.md); the
// three cards under it are zoo's own facts, laid out like HQLauncher's home.
import std;
import ui;
import zoo.collection;
import zoo.minecraft.content;
import zoo.world.saves;
import zoo.app.theme;
import zoo.app.kit;
import zoo.app.state;
namespace play;

// The floating dock: the version that would be prepared, the action, and the
// two small buttons that refresh or open the setup.
fn draw_dock(p: const kit::Pen&, s: state::State&, box: ui::Rect) -> i64 {
    var want = state::WANT_NOTHING;
    kit::shadow(p, box, 20.0);
    ui::fill_rect(p.ctx, box, 20.0, theme::GLASS);
    ui::stroke_rect(p.ctx, box, 20.0, 1.0, theme::LINE);

    let has = state::chosen(s);
    // The dock gives up its extra width first: a narrow window keeps the
    // segment, the action and the two small buttons on one line.
    let compact = box.w < 700.0;
    let seg_w: f32 = if compact { 190.0 } else { 260.0 };
    let act_w: f32 = seg_w;
    let icon: f32 = if compact { 46.0 } else { 52.0 };
    let group_w = seg_w + 12.0 + act_w + 10.0 + icon + 10.0 + icon;
    let start = box.x + (box.w - group_w) / 2.0;
    let seg = kit::r(start, box.y + 12.0, seg_w, 52.0);

    // The picker.
    let over = kit::hovered(p, seg);
    ui::fill_rect(p.ctx, seg, 12.0, if over { theme::SURFACE_HOVER } else { theme::NONE });
    kit::text(p, seg.x + 14.0, seg.y + 7.0, "VERSION", p.fonts.tiny, theme::FAINT);
    var id: u8[>..] = [];
    if has { kit::fit(id, s.rows[s.selected].id, p.fonts.medium, seg.w - 60.0); } else { id.append("none chosen"); }
    kit::text(p, seg.x + 14.0, seg.y + 22.0, id, p.fonts.medium, if has { theme::INK } else { theme::MUTED });
    kit::chevron(p, seg.x + seg.w - 24.0, seg.y + 24.0, theme::MUTED);
    if kit::clicked(p, seg) { s.page = state::PAGE_VERSIONS; }

    ui::stroke_line(p.ctx, start + seg_w + 6.0, box.y + 16.0, start + seg_w + 6.0, box.y + box.h - 16.0,
                    1.0, theme::LINE);

    // The main action.
    let label = if !has { "PREPARE" } else if s.busy { "PREPARING" }
                else if s.rows[s.selected].ready { "PREPARE AGAIN" } else { "PREPARE" };
    let act = kit::r(start + seg_w + 12.0, box.y + 12.0, act_w, 52.0);
    if kit::action_button(p, act, label, kit::GLYPH_DOWN, has && !s.busy) { want = state::WANT_OBTAIN; }

    if kit::icon_button(p, kit::r(start + seg_w + 12.0 + act_w + 10.0, box.y + 12.0, icon, icon),
                        kit::GLYPH_REFRESH) {
        want = state::WANT_REFRESH;
    }
    if kit::icon_button(p, kit::r(start + seg_w + 12.0 + act_w + 10.0 + icon + 10.0, box.y + 12.0, icon, icon),
                        kit::GLYPH_SETUP) {
        s.page = state::PAGE_SETTINGS;
    }

    if s.busy {
        let part = if s.stage >= collection::STAGE_DONE { 5.0 } else { s.stage as f32 };
        kit::progress(p, kit::r(box.x + 22.0, box.y + box.h - 7.0, box.w - 44.0, 3.0), part, 5.0);
    }
    want
}

// One card of the row under the hero: a glyph, a number and what to do next.
fn draw_card(p: const kit::Pen&, box: ui::Rect, kind: i64, value: const u8[:],
             label: const u8[:], detail: const u8[:], action: const u8[:]) -> bool {
    let over = kit::hovered(p, box);
    ui::fill_rect(p.ctx, box, 14.0, if over { theme::SURFACE_HOVER } else { theme::SURFACE });
    ui::stroke_rect(p.ctx, box, 14.0, 1.0, if over { theme::ACCENT } else { theme::LINE });

    let tile = kit::r(box.x + 20.0, box.y + 18.0, 34.0, 34.0);
    ui::fill_rect(p.ctx, tile, 10.0, theme::ACCENT_SOFT);
    kit::glyph(p, tile.x + 17.0, tile.y + 17.0, kind, theme::ACCENT);

    kit::chevron_right(p, box.x + box.w - 26.0, box.y + 26.0, if over { theme::ACCENT } else { theme::FAINT });

    kit::text(p, box.x + 20.0, box.y + 64.0, value, p.fonts.title, theme::INK);
    kit::text(p, box.x + 20.0, box.y + 110.0, label, p.fonts.small, theme::MUTED);

    var d: u8[>..] = [];
    kit::fit(d, detail, p.fonts.small, box.w - 40.0);
    kit::text(p, box.x + 20.0, box.y + box.h - 50.0, d, p.fonts.small, theme::FAINT);

    kit::text(p, box.x + 20.0, box.y + box.h - 24.0, action, p.fonts.small,
              if over { theme::ACCENT_HOVER } else { theme::ACCENT });
    kit::clicked(p, box)
}

// The newest release on the catalogue, for the Versions card.
fn latest_release(rows: const catalogue::Row[:]) -> u8[>..] {
    var best: u8[>..] = [];
    for r in rows {
        if r.kind != "release" { continue; }
        if best.len == 0 || compare(r.id, best) > 0 {
            best.resize(0);
            best.append(r.id);
        }
    }
    best
}

fn draw(p: const kit::Pen&, s: state::State&, items: content::Item[>..]&,
        found: const saves::Save[:], w: f32, h: f32) -> i64 {
    var want = state::WANT_NOTHING;
    let has = state::chosen(s);
    let x = state::content_x();
    let right = state::content_right(w);
    let cw = right - x;
    let cx = (state::SIDEBAR_W + w) / 2.0;
    let hero_h = clamp(h * 0.645, 400.0, 560.0);

    // The picture: zoo's own render, cover-cropped, darkened to a backdrop.
    let hero = kit::r(state::SIDEBAR_W, 0.0, w - state::SIDEBAR_W, hero_h);
    if s.backdrop.texture != 0 {
        ui::draw_image(p.ctx, hero, kit::cover(s.backdrop, hero), ui::Color { 106, 113, 127, 255 });
        kit::veil_v(p, hero, kit::with_alpha(theme::BG, 100), kit::with_alpha(theme::BG, 40));
        kit::veil_h(p, kit::r(hero.x, 0.0, hero.w * 0.55, hero_h),
                    kit::with_alpha(theme::BG, 70), theme::NONE);
        // The foot of the picture dissolves into the page, so the cards below
        // sit on the same ground as the rest of the launcher.
        kit::veil_v(p, kit::r(hero.x, hero_h * 0.55, hero.w, hero_h * 0.45), theme::NONE, theme::BG);
    }

    // The version over the picture.
    let dock = kit::r(cx - min(740.0, cw) / 2.0, hero_h - 104.0, min(740.0, cw), 76.0);
    let title_y = dock.y - 178.0;

    var word: const u8[:] = "NO VERSION CHOSEN";
    var color = theme::MUTED;
    if has { word, color = state::readiness(s.rows[s.selected], s); }
    let pill_w = kit::width(p.fonts.tiny, word) + 40.0;
    kit::state_pill(p, cx - pill_w / 2.0, title_y - 42.0, word, color);

    if has {
        kit::text_mid(p, cx, title_y, str("Minecraft ", s.rows[s.selected].id), p.fonts.hero, theme::INK);
        var sub: u8[>..] = [];
        format(sub, s.rows[s.selected].kind, "  ·  ", s.rows[s.selected].released[..min(s.rows[s.selected].released.len, 10)],
               "  ·  ", if s.rows[s.selected].ready { "prepared on this computer" } else { "zoo prepares it from your own copy" });
        kit::text_shadow(p, cx - kit::width(p.fonts.small, sub) / 2.0, title_y + 80.0, sub,
                         p.fonts.small, kit::mix(theme::MUTED, theme::INK, 0.55), kit::with_alpha(theme::BG, 170));
    } else {
        kit::text_mid(p, cx, title_y + 12.0, "Choose a version", p.fonts.title, theme::INK);
        kit::text_mid(p, cx, title_y + 58.0, "Pick one from the catalogue and zoo prepares it for the client.",
                      p.fonts.small, theme::MUTED);
    }

    want = draw_dock(p, s, dock);

    // The row of facts under the hero.
    let top = hero_h + 22.0;
    let bottom = state::body_bottom(h) - 12.0;
    let gap: f32 = 18.0;
    let card_w = (cw - 2.0 * gap) / 3.0;
    let card_h = max(180.0, bottom - top);
    let ready = state::prepared_count(s);

    var v1: u8[>..] = [];
    format(v1, ready);
    var d1: u8[>..] = [];
    if s.rows.len > 0 && latest_release(s.rows).len > 0 {
        d1.append(str(s.rows.len, " versions in the catalogue, latest ", latest_release(s.rows)));
    } else if s.list_note.len > 0 {
        d1.append(s.list_note);
    } else {
        d1.append("Every version Mojang lists.");
    }
    if draw_card(p, kit::r(x, top, card_w, card_h), kit::GLYPH_VERSIONS, v1,
                 "versions prepared", d1, if has { "Browse versions" } else { "Choose a version" }) {
        s.page = state::PAGE_VERSIONS;
    }

    var d2: u8[>..] = [];
    if found.len > 0 { d2.append(str(found[0].name, " is the newest.")); }
    else { d2.append("None yet — zoo looks in your Minecraft folder."); }
    if draw_card(p, kit::r(x + card_w + gap, top, card_w, card_h), kit::GLYPH_WORLDS, str(found.len),
                 "singleplayer worlds", d2, "See worlds") {
        s.page = state::PAGE_WORLDS;
    }

    var d3: u8[>..] = [];
    if items.len > 0 { d3.append(str(items[0].name, " and ", items.len - 1, " more.")); }
    else { d3.append("Shaders and resource packs live beside them."); }
    if draw_card(p, kit::r(x + 2.0 * (card_w + gap), top, card_w, card_h), kit::GLYPH_CONTENT, str(items.len),
                 "mods in your folder", d3, "Open content") {
        s.page = state::PAGE_CONTENT;
    }

    return want;
}
