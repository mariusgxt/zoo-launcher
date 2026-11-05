// Which textures a block wears, resolved out of the prepared resources the
// way the game does it: a block's blockstates file names a model, and a model
// names textures or inherits them from a parent.
//
// Only the faces a cube needs are kept: top, side and bottom. zoo's first look
// draws every block as a cube, so a stair's own geometry is not read yet, but
// its textures already come out right. These files are a few hundred bytes, so
// they go through json's document parser rather than its streaming reader.
import std;
import os;
import json;
namespace blockmodel;

// Deep enough for Mojang's own chains (block/cube_all -> block/cube -> block)
// and a stop for a pack whose model points at itself.
let MAX_PARENTS = 8;

struct Faces { top: u8[..120], side: u8[..120], bottom: u8[..120], ok: bool }

fn blank() -> Faces { Faces { top: [], side: [], bottom: [], ok: false } }

fn put(dst: u8[..120]&, s: const u8[:]) {
    dst.resize(0);
    dst.append(s[..min(s.len, 120)]);
}

// minecraft:stone -> stone. The namespace is dropped because zoo reads the
// vanilla resources only for now; a resource pack would need it kept.
fn bare(name: const u8[:]) -> const u8[:] {
    for i in name.len {
        if name[i] == ':' { return name[i + 1..]; }
    }
    name
}

fn model_path(root: const u8[:], model: const u8[:]) -> u8[>..] {
    str(root, "/models/", bare(model), ".json")
}

// block/stone or minecraft:block/stone -> <root>/textures/block/stone.png
fn texture_path(root: const u8[:], texture: const u8[:]) -> u8[>..] {
    str(root, "/textures/", bare(texture), ".png")
}

// The first "model" string anywhere below n. A blockstates file holds either
// variants, whose values are objects or weighted lists, or multipart entries;
// the first model is the one a full block repeats in every variant.
recursive fn first_model(n: json::Node&, out: u8[..120]&) -> bool {
    var done = false;
    json::each(n) { c =>
        if !done {
            let s, is_text = json::as_string(c);
            if is_text && c.key == "model" {
                put(out, s);
                done = true;
            } else if !is_text {
                done = first_model(c, out);
            }
        }
    };
    done
}

fn model_of(root: const u8[:], block_name: const u8[:], out: u8[..120]&) -> bool {
    var text: u8[>..] = [];
    guard read_file(str(root, "/blockstates/", bare(block_name), ".json"), text) else { return false; }
    var doc: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    let node, _msg = json::parse(text, doc, decoded);
    guard node else { return false; }
    first_model(node, out)
}

fn take(dst: u8[..120]&, n: json::Node?) {
    let s, ok = json::as_string(n);
    // A nearer model in the chain has already said what it wants, so an entry
    // that is set is never written over.
    if ok && dst.len == 0 { put(dst, s); }
}

// Follows a "#name" reference to whichever of the gathered names it points at.
fn deref(v: u8[..120]&, all: const u8[:], a: const u8[:], b: const u8[:]) {
    guard v.len > 1 && v[0] == '#' else { return; }
    let want = v[1..];
    let pick = if want == "all" || want == "texture" { all }
               else if a.len > 0 && a[0] != '#' { a }
               else { b };
    v.resize(0);
    if pick.len > 0 && pick[0] != '#' { v.append(pick); }
}

// Reads a model and then its parents, keeping the textures a cube uses.
fn faces_of(root: const u8[:], block_name: const u8[:]) -> Faces {
    var f = blank();
    var next: u8[..120] = [];
    guard model_of(root, block_name, next) else { return f; }
    var all: u8[..120] = [];
    var side: u8[..120] = [];
    var top: u8[..120] = [];
    var bottom: u8[..120] = [];
    for step in MAX_PARENTS {
        var text: u8[>..] = [];
        guard read_file(model_path(root, next), text) else { break; }
        var doc: json::Node[>..] = [];
        var decoded: u8[>..] = [];
        let node, _msg = json::parse(text, doc, decoded);
        guard node else { break; }
        let textures = json::member(node, "textures");
        if textures {
            take(all, json::member(textures, "all"));
            take(all, json::member(textures, "texture"));
            take(side, json::member(textures, "side"));
            take(side, json::member(textures, "wall"));
            take(top, json::member(textures, "top"));
            take(top, json::member(textures, "up"));
            take(top, json::member(textures, "end"));
            take(bottom, json::member(textures, "bottom"));
            take(bottom, json::member(textures, "down"));
            if all.len == 0 && side.len == 0 { take(all, json::member(textures, "particle")); }
        }
        let parent, has_parent = json::as_string(json::member(node, "parent"));
        if !has_parent { break; }
        next.resize(0);
        next.append(parent[..min(parent.len, 120)]);
    }
    // cube_all writes its faces as "#all", so a reference that is still there
    // once the chain is read is looked up among the names the chain gathered.
    deref(side, all, top, bottom);
    deref(top, all, side, bottom);
    deref(bottom, all, side, top);
    if side.len == 0 { side.append(all); }
    if top.len == 0 { top.append(side); }
    if bottom.len == 0 { bottom.append(top); }
    put(f.top, top);
    put(f.side, side);
    put(f.bottom, bottom);
    // A name still starting with '#' is a reference the chain never resolved,
    // which means this block is not a plain cube.
    f.ok = side.len > 0 && side[0] != '#';
    f
}
