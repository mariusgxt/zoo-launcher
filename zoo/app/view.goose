// What the launcher window draws each frame. It only reads the state and
// returns what the user asked for; the main loop decides what happens, so
// the view stays testable through screenshots and free of side effects.
import std;
import os;
import ui;
import zoo.specimen;
import zoo.collection;
import zoo.app.theme;
import zoo.app.catalogue;
namespace view;

struct Filters { releases: bool, snapshots: bool, installed_only: bool }

struct State {
    rows: catalogue::Row[>..]&,
    selected: i64,
    filters: Filters,
    busy: bool,
    stage: i64,
    status: u8[..200],
    list_note: u8[..200],
    home: const u8[:],
    locality: const u8[:],
}

let WANT_NOTHING = 0;
let WANT_OBTAIN = 1;
let WANT_REFRESH = 2;

fn visible(r: const catalogue::Row&, f: const Filters&) -> bool {
    if f.installed_only && r.local_jar.len == 0 { return false; }
    if r.kind == "release" { return f.releases; }
    if r.kind == "snapshot" { return f.snapshots; }
    if r.kind == "installed" { return true; }
    false      // old_beta and old_alpha stay out until the zoo client reads them
}

fn draw_versions(ctx: ui::Context, s: State&, height: f32) {
    ui::layout_row_dynamic(ctx, 24.0, 3);
    ui::checkbox_label(ctx, "Releases", s.filters.releases);
    ui::checkbox_label(ctx, "Snapshots", s.filters.snapshots);
    ui::checkbox_label(ctx, "Installed", s.filters.installed_only);
    ui::layout_row_dynamic(ctx, height - 60.0, 1);
    if ui::group_begin(ctx, "version list", ui::WINDOW_BORDER) {
        let cols: f32[3] = [0.45, 0.30, 0.25];
        for r, i in s.rows {
            if !visible(r, s.filters) { continue; }
            ui::layout_row(ctx, ui::DYNAMIC, 22.0, cols);
            var on = i == s.selected;
            if ui::selectable_label(ctx, r.id, ui::TEXT_LEFT, on) { s.selected = i; }
            ui::label_colored(ctx, r.kind, ui::TEXT_LEFT, theme::MUTED);
            if r.ready { ui::label_colored(ctx, "ready", ui::TEXT_RIGHT, theme::LEAF); }
            else if r.local_jar.len > 0 { ui::label_colored(ctx, "on disk", ui::TEXT_RIGHT, theme::SAND); }
            else { ui::label(ctx, "", ui::TEXT_RIGHT); }
        }
        ui::group_end(ctx);
    }
    ui::layout_row_dynamic(ctx, 18.0, 1);
    ui::label_colored(ctx, s.list_note, ui::TEXT_LEFT, theme::MUTED);
}

fn field(ctx: ui::Context, name: const u8[:], value: const u8[:]) {
    let cols: f32[2] = [0.32, 0.68];
    ui::layout_row(ctx, ui::DYNAMIC, 22.0, cols);
    ui::label_colored(ctx, name, ui::TEXT_LEFT, theme::MUTED);
    ui::label(ctx, if value.len > 0 { value } else { "-" }, ui::TEXT_LEFT);
}

fn draw_details(ctx: ui::Context, s: State&) -> i64 {
    var want = WANT_NOTHING;
    if s.selected < 0 || s.selected >= s.rows.len {
        ui::layout_row_dynamic(ctx, 24.0, 1);
        ui::label_colored(ctx, "Pick a version on the left.", ui::TEXT_LEFT, theme::MUTED);
        return want;
    }
    let r = s.rows[s.selected];
    ui::layout_row_dynamic(ctx, 30.0, 1);
    ui::label_colored(ctx, str("Minecraft ", r.id), ui::TEXT_LEFT, theme::SAND);
    field(ctx, "Type", r.kind);
    field(ctx, "Released", r.released[..min(r.released.len, 10)]);
    field(ctx, "Source", if r.local_jar.len > 0 { "your Minecraft folder" } else { "download from Mojang" });
    field(ctx, "Resources", if r.ready { "prepared" } else { "not prepared yet" });
    ui::layout_row_dynamic(ctx, 12.0, 1);
    ui::spacer(ctx);
    ui::layout_row_dynamic(ctx, 36.0, 1);
    if s.busy {
        ui::widget_disable_begin(ctx);
        ui::button_label(ctx, "Working...");
        ui::widget_disable_end(ctx);
    } else if ui::button_label(ctx, if r.ready { "Prepare again" } else { "Prepare for zoo" }) {
        want = WANT_OBTAIN;
    }
    ui::layout_row_dynamic(ctx, 20.0, 1);
    var cur = if s.stage >= collection::STAGE_DONE { 5 } else { s.stage };
    ui::progress(ctx, cur, 5, false);
    ui::layout_row_dynamic(ctx, 40.0, 1);
    let color = if s.stage == collection::STAGE_FAILED { theme::RUST }
                else if s.stage == collection::STAGE_DONE { theme::LEAF } else { theme::INK };
    ui::label_colored_wrap(ctx, s.status, color);
    want
}

fn draw(ctx: ui::Context, s: State&, w: f32, h: f32) -> i64 {
    var want = WANT_NOTHING;
    let flags = ui::WINDOW_NO_SCROLLBAR;
    if ui::begin(ctx, "zoo", ui::rect(0.0, 0.0, w, h), flags) {
        let tag = specimen::current();
        let head: f32[2] = [0.5, 0.5];
        ui::layout_row(ctx, ui::DYNAMIC, 34.0, head);
        ui::label_colored(ctx, "zoo", ui::TEXT_LEFT, theme::SAND);
        ui::label_colored(ctx, str(tag.version, "  ", tag.scientific, "  ", tag.accession), ui::TEXT_RIGHT, theme::MUTED);
        let body_h = h - 34.0 - 30.0 - 30.0;
        let split: f32[2] = [0.46, 0.54];
        ui::layout_row(ctx, ui::DYNAMIC, body_h, split);
        if ui::group_begin(ctx, "Versions", ui::WINDOW_TITLE | ui::WINDOW_BORDER | ui::WINDOW_NO_SCROLLBAR) {
            draw_versions(ctx, s, body_h - 40.0);
            ui::group_end(ctx);
        }
        if ui::group_begin(ctx, "Specimen", ui::WINDOW_TITLE | ui::WINDOW_BORDER) {
            want = draw_details(ctx, s);
            ui::group_end(ctx);
        }
        let foot: f32[2] = [0.8, 0.2];
        ui::layout_row(ctx, ui::DYNAMIC, 24.0, foot);
        ui::label_colored(ctx, str("Collection: ", s.home), ui::TEXT_LEFT, theme::MUTED);
        if !s.busy && ui::button_label(ctx, "Refresh") { want = WANT_REFRESH; }
    }
    ui::end(ctx);
    want
}
