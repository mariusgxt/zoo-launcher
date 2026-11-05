// Chunks that come and go as the camera moves. Every chunk within the radius
// gets a slot with its own vertex buffer; a chunk that leaves the radius gives
// its buffer back. A few chunks are meshed per frame, nearest first, so flying
// stays smooth while the world fills in around the camera.
//
// Baked cells are not kept between frames: a whole column of cells is about
// 800 KB, and a radius of eight would hold a few hundred of them. Meshing a
// chunk bakes it and its four neighbours again instead, from region files
// that stay cached in memory, which costs a few milliseconds and no memory.
import std;
import os;
import gfx;
import zoo.world.nbt;
import zoo.world.region;
import zoo.world.chunk;
import zoo.client.atlas;
import zoo.client.mesh;
namespace stream;

let BUDGET = 2;                  // chunks meshed per frame
let REGION_CACHE = 4;            // region files kept in memory
let ATLAS_COLS = 32;             // 1024 tiles, a 512x512 texture

let EMPTY = 0;                   // not looked at yet
let ABSENT = 1;                  // the world has no chunk there
let READY = 2;                   // meshed and drawable

struct Slot { cx: i64, cz: i64, state: i64, buffer: gfx::Buffer, vertices: i64, stale: bool }

// A region file inside the shared pool. size 0 means the file is not there,
// which is remembered too, so a missing file is not looked for every frame.
struct Cached { rx: i64, rz: i64, at: i64, size: i64 }

struct Center { cx: i64, cz: i64, radius: i64 }

fn in_range(c: const Center&, cx: i64, cz: i64) -> bool {
    abs(cx - c.cx) <= c.radius && abs(cz - c.cz) <= c.radius
}

fn grid() -> atlas::Grid { atlas::fixed(ATLAS_COLS, ATLAS_COLS, 0) }

fn slot_of(slots: const Slot[:], cx: i64, cz: i64) -> i64 {
    for s, i in slots {
        if s.cx == cx && s.cz == cz { return i; }
    }
    -1
}

// The cache entry for a region, reading the file on a miss. The pool is
// cleared as a whole once it holds REGION_CACHE files, which is crude, but a
// camera flies over a region in seconds and back rarely.
fn region_entry(dir: const u8[:], rx: i64, rz: i64, cache: Cached[>..]&, pool: u8[>..]&) -> i64 {
    for c, i in cache {
        if c.rx == rx && c.rz == rz { return i; }
    }
    if cache.len >= REGION_CACHE {
        cache.resize(0);
        pool.resize(0);
    }
    var file: u8[>..] = [];
    let at = pool.len;
    var size = 0;
    if read_file(region::path_of(dir, rx, rz), file) {
        pool.append(file);
        size = file.len;
    }
    cache.push(Cached { rx: rx, rz: rz, at: at, size: size });
    cache.len - 1
}

fn exists(dir: const u8[:], cx: i64, cz: i64, cache: Cached[>..]&, pool: u8[>..]&) -> bool {
    let rx, rz = region::region_of(cx, cz);
    let e = region_entry(dir, rx, rz, cache, pool);
    let c = cache[e];
    c.size > 0 && region::exists(pool[c.at..c.at + c.size], cx, cz)
}

// Bakes one chunk into cells and records it as a piece. false when the chunk
// cannot be read, which leaves cells and pieces as they were.
fn bake_one(dir: const u8[:], root: const u8[:], cx: i64, cz: i64,
            cache: Cached[>..]&, pool: u8[>..]&,
            slots_atlas: atlas::Slot[>..]&, tiles: u8[>..]&, known: mesh::Known[>..]&,
            cells: mesh::Cell[>..]&, pieces: mesh::Piece[>..]&) -> bool {
    let rx, rz = region::region_of(cx, cz);
    let e = region_entry(dir, rx, rz, cache, pool);
    let c = cache[e];
    guard c.size > 0 else { return false; }
    var raw: u8[>..] = [];
    guard region::chunk(pool[c.at..c.at + c.size], cx, cz, raw) else { return false; }
    var tags: nbt::Node[>..] = [];
    guard nbt::read(raw, tags) else { return false; }
    var layers: chunk::Layer[>..] = [];
    var blocks: u16[>..] = [];
    guard chunk::read(raw, tags, layers, blocks).ok else { return false; }
    let vol = mesh::bake(raw, tags, layers, blocks, root, slots_atlas, tiles, known, cells);
    guard vol.layers > 0 else { return false; }
    pieces.push(mesh::Piece { cx: cx, cz: cz, vol: vol });
    true
}

// Meshes one chunk against those of its neighbours that lie within the radius,
// and returns the vertices written to out, or -1 if the chunk is not there.
fn mesh_one(dir: const u8[:], root: const u8[:], center: const Center&, cx: i64, cz: i64,
            cache: Cached[>..]&, pool: u8[>..]&,
            slots_atlas: atlas::Slot[>..]&, tiles: u8[>..]&, known: mesh::Known[>..]&,
            out: f32[>..]&) -> i64 {
    var cells: mesh::Cell[>..] = [];
    var pieces: mesh::Piece[>..] = [];
    guard bake_one(dir, root, cx, cz, cache, pool, slots_atlas, tiles, known, cells, pieces) else { return -1; }
    let near: i64[8] = [1, 0, -1, 0, 0, 1, 0, -1];
    for k in 4 {
        let nx = cx + near[k * 2];
        let nz = cz + near[k * 2 + 1];
        // A neighbour beyond the radius is left out on purpose: its wall is the
        // edge of what is drawn, and leaving it open would show a hole.
        if in_range(center, nx, nz) {
            bake_one(dir, root, nx, nz, cache, pool, slots_atlas, tiles, known, cells, pieces);
        }
    }
    out.resize(0);
    let g = grid();
    mesh::build(cells, pieces, 0, g, out);
    out.len / mesh::FLOATS
}

fn mark_neighbours(slots: Slot[>..]&, cx: i64, cz: i64) {
    let near: i64[8] = [1, 0, -1, 0, 0, 1, 0, -1];
    for k in 4 {
        let i = slot_of(slots, cx + near[k * 2], cz + near[k * 2 + 1]);
        if i >= 0 && slots[i].state == READY { slots[i].stale = true; }
    }
}

// Drops the slots that left the radius and opens empty ones for chunks that
// came into it. Cheap enough to run every frame: it only compares numbers.
fn follow(slots: Slot[>..]&, center: const Center&) {
    var i = 0;
    while i < slots.len {
        if !in_range(center, slots[i].cx, slots[i].cz) {
            if slots[i].buffer.id != 0 { gfx::release(slots[i].buffer); }
            let gone_x = slots[i].cx;
            let gone_z = slots[i].cz;
            slots[i] = slots[slots.len - 1];
            slots.resize(slots.len - 1);
            // The chunks beside it are now at the edge and need their wall back.
            mark_neighbours(slots, gone_x, gone_z);
        } else {
            i++;
        }
    }
    for dz in 2 * center.radius + 1 {
        for dx in 2 * center.radius + 1 {
            let cx = center.cx + dx - center.radius;
            let cz = center.cz + dz - center.radius;
            if slot_of(slots, cx, cz) < 0 {
                slots.push(Slot { cx: cx, cz: cz, state: EMPTY, buffer: gfx::Buffer { id: 0 }, vertices: 0, stale: false });
            }
        }
    }
}

// The slot that most wants work: an empty one or a stale one, nearest to the
// centre first, so the ground under the camera is never the last to appear.
fn next_job(slots: const Slot[:], center: const Center&) -> i64 {
    var best = -1;
    var best_d = 1 << 40;
    for s, i in slots {
        if s.state == EMPTY || (s.state == READY && s.stale) {
            let d = (s.cx - center.cx) * (s.cx - center.cx) + (s.cz - center.cz) * (s.cz - center.cz);
            if d < best_d {
                best_d = d;
                best = i;
            }
        }
    }
    best
}

// Does up to BUDGET chunks of work and returns how many were meshed. New
// textures land in tiles; the caller uploads the atlas when that grows.
fn work(dir: const u8[:], root: const u8[:], center: const Center&, slots: Slot[>..]&,
        cache: Cached[>..]&, pool: u8[>..]&,
        slots_atlas: atlas::Slot[>..]&, tiles: u8[>..]&, known: mesh::Known[>..]&,
        scratch: f32[>..]&) -> i64 {
    var done = 0;
    for step in BUDGET {
        let i = next_job(slots, center);
        if i < 0 { break; }
        let cx = slots[i].cx;
        let cz = slots[i].cz;
        let fresh = slots[i].state == EMPTY;
        let n = mesh_one(dir, root, center, cx, cz, cache, pool, slots_atlas, tiles, known, scratch);
        if n < 0 {
            slots[i].state = ABSENT;
            continue;
        }
        if slots[i].buffer.id != 0 { gfx::release(slots[i].buffer); }
        slots[i].buffer = if n > 0 { gfx::vertex_buffer(bytes_of(scratch)) } else { gfx::Buffer { id: 0 } };
        slots[i].vertices = n;
        slots[i].state = READY;
        slots[i].stale = false;
        // A chunk that just arrived hides part of its neighbours' walls.
        if fresh { mark_neighbours(slots, cx, cz); }
        done++;
    }
    done
}

fn pending(slots: const Slot[:]) -> i64 {
    var n = 0;
    for s in slots {
        if s.state == EMPTY || s.stale { n++; }
    }
    n
}

fn drawn(slots: const Slot[:]) -> i64 {
    var n = 0;
    for s in slots {
        if s.state == READY && s.vertices > 0 { n++; }
    }
    n
}

// The height of the highest solid block in the middle of a chunk, or -9999 if
// the chunk is not there. Used once, to put the camera above the ground.
fn ground_of(dir: const u8[:], root: const u8[:], cx: i64, cz: i64,
             cache: Cached[>..]&, pool: u8[>..]&,
             slots_atlas: atlas::Slot[>..]&, tiles: u8[>..]&, known: mesh::Known[>..]&) -> i64 {
    var cells: mesh::Cell[>..] = [];
    var pieces: mesh::Piece[>..] = [];
    guard bake_one(dir, root, cx, cz, cache, pool, slots_atlas, tiles, known, cells, pieces) else { return -9999; }
    let vol = pieces[0].vol;
    var y = vol.layers * chunk::EDGE - 1;
    while y >= 0 {
        if mesh::cell_at(cells, vol, 8, y, 8).solid != 0 { return vol.y0 * chunk::EDGE + y; }
        y--;
    }
    vol.y0 * chunk::EDGE
}
