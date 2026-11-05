// Turns a chunk into triangles. Two steps, because they want different data:
// baking flattens the chunk's sections and their separate palettes into one
// column of cells, and meshing walks that column and keeps the faces that
// touch air.
//
// Hidden faces are dropped here rather than on the GPU: a chunk is mostly
// stone, and the faces inside it outnumber the ones anyone can see.
import std;
import zoo.world.nbt;
import zoo.world.chunk;
import zoo.client.atlas;
import zoo.client.blockmodel;
namespace mesh;

let EDGE = chunk::EDGE;
let FLOATS = 6;                  // x, y, z, u, v, shade
let VERTS_PER_FACE = 6;

// A block as the mesher needs it: whether it fills its cell, and the tile each
// of its three face directions wears.
struct Look { top: i64, side: i64, bottom: i64, solid: bool }

struct Known { name: u8[..120], look: Look }

struct Cell { solid: u8, top: u16, side: u16, bottom: u16 }

// The column of cells a baked chunk covers. y0 counts sections, so the block
// height of cell row 0 is y0 * 16.
struct Volume { y0: i64, layers: i64, cells: i64 }

fn air(name: const u8[:]) -> bool {
    name == "minecraft:air" || name == "minecraft:cave_air" || name == "minecraft:void_air" || name.len == 0
}

// Resolves a block name to its tiles once and remembers it: a chunk repeats a
// few dozen names over its 98304 cells, and each miss costs several JSON files.
fn look_of(root: const u8[:], name: const u8[:], slots: atlas::Slot[>..]&, tiles: u8[>..]&, known: Known[>..]&) -> Look {
    for k in known {
        if k.name == name { return k.look; }
    }
    var look = Look { top: -1, side: -1, bottom: -1, solid: false };
    if !air(name) {
        let faces = blockmodel::faces_of(root, name);
        if faces.ok {
            let missing = atlas::add_missing(slots, tiles);
            look.side = atlas::add(root, faces.side, slots, tiles);
            look.top = atlas::add(root, faces.top, slots, tiles);
            look.bottom = atlas::add(root, faces.bottom, slots, tiles);
            if look.side < 0 { look.side = missing; }
            if look.top < 0 { look.top = missing; }
            if look.bottom < 0 { look.bottom = missing; }
            look.solid = true;
        }
    }
    var k = Known { name: [], look: look };
    k.name.append(name[..min(name.len, 120)]);
    known.push(k);
    look
}

// Flattens the chunk into one cell per block, from its lowest section to its
// highest. Gaps between sections become air, which is what a gap means.
fn bake(d: const u8[:], nodes: const nbt::Node[:], layers: const chunk::Layer[:], blocks: const u16[:],
        root: const u8[:], slots: atlas::Slot[>..]&, tiles: u8[>..]&, known: Known[>..]&,
        cells: Cell[>..]&) -> Volume {
    var vol = Volume { y0: 0, layers: 0, cells: 0 };
    guard layers.len > 0 else { return vol; }
    var low = layers[0].y;
    var high = layers[0].y;
    for l in layers {
        low = min(low, l.y);
        high = max(high, l.y);
    }
    vol.y0 = low;
    vol.layers = high - low + 1;
    let at = cells.len;
    for i in vol.layers * chunk::VOLUME { cells.push(Cell { solid: 0, top: 0, side: 0, bottom: 0 }); }
    vol.cells = at;
    for l in layers {
        let entries = chunk::palette_size(nodes, l.palette);
        // One Look per palette entry, so the per-block loop is two lookups and
        // no string compare at all.
        var looks: Look[>..] = [];
        for e in entries {
            looks.push(look_of(root, chunk::palette_name(d, nodes, l.palette, e), slots, tiles, known));
        }
        let base = at + (l.y - low) * chunk::VOLUME;
        for i in chunk::VOLUME {
            let e = blocks[l.at + i] as i64;
            if e < entries {
                let look = looks[e];
                if look.solid {
                    cells[base + i] = Cell {
                        solid: 1,
                        top: look.top as! u16,
                        side: look.side as! u16,
                        bottom: look.bottom as! u16,
                    };
                }
            }
        }
    }
    vol
}

// One loaded chunk: where it sits and which slice of the cell array is its.
struct Piece { cx: i64, cz: i64, vol: Volume }

fn empty_cell() -> Cell { Cell { solid: 0, top: 0, side: 0, bottom: 0 } }

fn piece_of(pieces: const Piece[:], cx: i64, cz: i64) -> i64 {
    for p, i in pieces {
        if p.cx == cx && p.cz == cz { return i; }
    }
    -1
}

// A cell by world coordinates, across chunk borders. Anything outside the
// loaded chunks counts as air, which is why the edge of what is loaded still
// shows its faces: zoo would have to read the neighbour to know better.
fn cell_world(cells: const Cell[:], pieces: const Piece[:], wx: i64, wy: i64, wz: i64) -> Cell {
    let i = piece_of(pieces, div_euclid(wx, EDGE), div_euclid(wz, EDGE));
    guard i >= 0 else { return empty_cell(); }
    let vol = pieces[i].vol;
    cell_at(cells, vol, wx % EDGE, wy - vol.y0 * EDGE, wz % EDGE)
}

fn cell_at(cells: const Cell[:], vol: const Volume&, x: i64, y: i64, z: i64) -> Cell {
    guard x >= 0 && x < EDGE && z >= 0 && z < EDGE && y >= 0 && y < vol.layers * EDGE else {
        return empty_cell();
    }
    cells[vol.cells + y * EDGE * EDGE + z * EDGE + x]
}

// The shade each direction gets, instead of a light source: a flat lit cube
// reads as a cube only if its faces differ. Mojang's own values are close.
fn shade_of(dx: i64, dy: i64, dz: i64) -> f32 {
    if dy > 0 { 1.0 } else if dy < 0 { 0.5 } else if dz != 0 { 0.8 } else { 0.68 }
}

fn vertex(out: f32[>..]&, x: f32, y: f32, z: f32, u: f32, v: f32, shade: f32) {
    out.push(x);
    out.push(y);
    out.push(z);
    out.push(u);
    out.push(v);
    out.push(shade);
}

// One face as two triangles, wound counter-clockwise seen from outside.
fn face(out: f32[>..]&, g: const atlas::Grid&, tile: i64, shade: f32,
        ox: f32, oy: f32, oz: f32,
        ax: f32, ay: f32, az: f32,
        bx: f32, by: f32, bz: f32) {
    let u0, v0 = atlas::corner_of(g, tile);
    let du, dv = atlas::step_of(g);
    // A hair off the tile's edge, so a neighbouring tile never bleeds in when
    // the texture is sampled with a filter.
    let inset = du * 0.001;
    let u1 = u0 + du - inset;
    let v1 = v0 + dv - inset;
    let us = u0 + inset;
    let vs = v0 + inset;
    vertex(out, ox, oy, oz, us, v1, shade);
    vertex(out, ox + ax, oy + ay, oz + az, u1, v1, shade);
    vertex(out, ox + ax + bx, oy + ay + by, oz + az + bz, u1, vs, shade);
    vertex(out, ox, oy, oz, us, v1, shade);
    vertex(out, ox + ax + bx, oy + ay + by, oz + az + bz, u1, vs, shade);
    vertex(out, ox + bx, oy + by, oz + bz, us, vs, shade);
}

// Appends the visible faces of one loaded chunk, positioned in world blocks,
// and returns how many faces were written. A face is kept when the cell next to
// it is air; at a chunk's four walls that neighbour lives in another chunk, so
// the test goes through the whole set of loaded pieces there.
fn build(cells: const Cell[:], pieces: const Piece[:], me: i64, g: const atlas::Grid&, out: f32[>..]&) -> i64 {
    guard me >= 0 && me < pieces.len else { return 0; }
    let cx = pieces[me].cx;
    let cz = pieces[me].cz;
    let vol = pieces[me].vol;
    var faces = 0;
    let wx0 = cx * EDGE;
    let wz0 = cz * EDGE;
    let wy0 = vol.y0 * EDGE;
    for y in vol.layers * EDGE {
        for z in EDGE {
            for x in EDGE {
                let here = cell_at(cells, vol, x, y, z);
                if here.solid == 0 { continue; }
                let wx = wx0 + x;
                let wy = wy0 + y;
                let wz = wz0 + z;
                let fx = wx as f32;
                let fy = wy as f32;
                let fz = wz as f32;
                // Up and down stay inside this chunk: above and below the
                // baked column there is nothing but air anyway.
                if cell_at(cells, vol, x, y + 1, z).solid == 0 {
                    face(out, g, here.top, shade_of(0, 1, 0),
                         fx, fy + 1.0, fz + 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, -1.0);
                    faces++;
                }
                if cell_at(cells, vol, x, y - 1, z).solid == 0 {
                    face(out, g, here.bottom, shade_of(0, -1, 0),
                         fx, fy, fz, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0);
                    faces++;
                }
                if side_open(cells, pieces, vol, x, y, z + 1, wx, wy, wz + 1) {
                    face(out, g, here.side, shade_of(0, 0, 1),
                         fx, fy, fz + 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0);
                    faces++;
                }
                if side_open(cells, pieces, vol, x, y, z - 1, wx, wy, wz - 1) {
                    face(out, g, here.side, shade_of(0, 0, -1),
                         fx + 1.0, fy, fz, -1.0, 0.0, 0.0, 0.0, 1.0, 0.0);
                    faces++;
                }
                if side_open(cells, pieces, vol, x + 1, y, z, wx + 1, wy, wz) {
                    face(out, g, here.side, shade_of(1, 0, 0),
                         fx + 1.0, fy, fz + 1.0, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0);
                    faces++;
                }
                if side_open(cells, pieces, vol, x - 1, y, z, wx - 1, wy, wz) {
                    face(out, g, here.side, shade_of(-1, 0, 0),
                         fx, fy, fz, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0);
                    faces++;
                }
            }
        }
    }
    faces
}

// Whether a sideways neighbour is air. Inside the chunk that is one array read;
// only the cells against a wall pay for the chunk lookup.
fn side_open(cells: const Cell[:], pieces: const Piece[:], vol: const Volume&,
             x: i64, y: i64, z: i64, wx: i64, wy: i64, wz: i64) -> bool {
    if x >= 0 && x < EDGE && z >= 0 && z < EDGE {
        return cell_at(cells, vol, x, y, z).solid == 0;
    }
    cell_world(cells, pieces, wx, wy, wz).solid == 0
}
