// A chunk's blocks, unpacked out of its sections. Mojang stores each 16x16x16
// section as a palette of block states plus one index per block, and those
// indices are bit-packed into longs: four bits for a palette of two, more as
// the palette grows.
//
// Only the layout from 1.16 on is read, where an index never straddles two
// longs. Earlier worlds pack across the boundary; zoo says so rather than
// handing back a chunk that is quietly wrong.
import std;
import zoo.world.nbt;
namespace chunk;

let EDGE = 16;
let VOLUME = 4096;
let MIN_BITS = 4;
let DATA_VERSION_1_16 = 2566;

// Blocks are kept in one shared array for the whole world, so a layer only
// records where its 4096 entries start. y counts sections, not blocks: it is
// negative below sea level in a 1.18 world.
struct Layer { y: i64, at: i64, palette: i64 }

struct Info { cx: i64, cz: i64, data_version: i64, layers: i64, ok: bool }

// Four bits hold a palette of up to 16, and above that the width is the
// smallest that fits. Mojang never goes below four, even for a palette of one.
fn bits_for(entries: i64) -> i64 {
    var b = MIN_BITS;
    while (1 << b) < entries { b++; }
    b
}

fn palette_size(nodes: const nbt::Node[:], palette: i64) -> i64 {
    if palette >= 0 && palette < nodes.len { nodes[palette].count } else { 0 }
}

// The block name of one palette entry, as `minecraft:stone`.
fn palette_name(d: const u8[:], nodes: const nbt::Node[:], palette: i64, i: i64) -> const u8[:] {
    nbt::text_of(d, nodes, nbt::member(d, nodes, nbt::entry(nodes, palette, i), "Name"))
}

// Finds the palette index of a name, or -1. Used by the mesher to ask once per
// chunk which index is air, instead of comparing a name per block.
fn index_of(d: const u8[:], nodes: const nbt::Node[:], palette: i64, name: const u8[:]) -> i64 {
    let n = palette_size(nodes, palette);
    for i in n {
        if palette_name(d, nodes, palette, i) == name { return i; }
    }
    -1
}

// Appends the 4096 palette indices of one section, in Mojang's order:
// index = y * 256 + z * 16 + x.
fn section_blocks(d: const u8[:], nodes: const nbt::Node[:], section: i64, out: u16[>..]&) -> bool {
    let states = nbt::member(d, nodes, section, "block_states");
    let palette = nbt::member(d, nodes, states, "palette");
    let entries = palette_size(nodes, palette);
    guard entries > 0 else { return false; }
    let data = nbt::member(d, nodes, states, "data");
    // A section of one block state carries no data array at all.
    if entries == 1 {
        for i in VOLUME { out.push(0); }
        return true;
    }
    guard data >= 0 && nodes[data].kind == nbt::LONG_ARRAY else { return false; }
    let bits = bits_for(entries);
    let per = 64 / bits;
    let mask = (1 as u64 << bits as u64) - 1;
    guard nodes[data].count == (VOLUME + per - 1) / per else { return false; }
    for i in VOLUME {
        let word = nbt::long_at(d, nodes, data, i / per) as! u64;
        let v = (word >> ((i % per) * bits) as u64) & mask;
        guard v < entries as u64 else { return false; }
        out.push(v as! u16);
    }
    true
}

// Reads every section of a chunk. Sections without blocks, the empty ones
// above the terrain, are skipped: a layer that is not there is air.
fn read(d: const u8[:], nodes: const nbt::Node[:], layers: Layer[>..]&, blocks: u16[>..]&) -> Info {
    var info = Info { cx: 0, cz: 0, data_version: 0, layers: 0, ok: false };
    guard nodes.len > 0 else { return info; }
    info.cx = nbt::int_of(nodes, nbt::member(d, nodes, 0, "xPos"), 0);
    info.cz = nbt::int_of(nodes, nbt::member(d, nodes, 0, "zPos"), 0);
    info.data_version = nbt::int_of(nodes, nbt::member(d, nodes, 0, "DataVersion"), 0);
    guard info.data_version >= DATA_VERSION_1_16 else { return info; }
    let sections = nbt::member(d, nodes, 0, "sections");
    guard sections >= 0 else { return info; }
    var s = nodes[sections].child;
    while s >= 0 {
        let states = nbt::member(d, nodes, s, "block_states");
        if states >= 0 {
            let at = blocks.len;
            if section_blocks(d, nodes, s, blocks) {
                layers.push(Layer {
                    y: nbt::int_of(nodes, nbt::member(d, nodes, s, "Y"), 0),
                    at: at,
                    palette: nbt::member(d, nodes, states, "palette"),
                });
                info.layers++;
            } else {
                blocks.resize(at);
            }
        }
        s = nodes[s].next;
    }
    info.ok = info.layers > 0;
    info
}

// The palette index at a position inside a layer. x and z are 0..15, y is the
// height inside the section.
fn block_at(blocks: const u16[:], layer: const Layer&, x: i64, y: i64, z: i64) -> i64 {
    guard x >= 0 && x < EDGE && y >= 0 && y < EDGE && z >= 0 && z < EDGE else { return -1; }
    let i = layer.at + y * EDGE * EDGE + z * EDGE + x;
    if i >= 0 && i < blocks.len { blocks[i] } else { -1 }
}

// The layer covering a block height, or -1. Sections are stored in file order,
// which is bottom to top, but a search keeps that an assumption of Mojang's
// rather than one of zoo's.
fn layer_of(layers: const Layer[:], block_y: i64) -> i64 {
    let want = div_euclid(block_y, EDGE);
    for i in layers.len {
        if layers[i].y == want { return i; }
    }
    -1
}
