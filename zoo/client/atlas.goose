// One texture atlas for everything a chunk draws, built from the prepared
// PNGs. Block textures are 16x16, and an animated one is a column of 16x16
// frames, of which the first is taken: zoo's first look does not animate.
//
// Tiles are gathered one after another and only laid out in a grid at the end.
// Appending in tile order keeps the gathering a plain push, and the renderer
// needs the grid once, not per texture.
import std;
import os;
import zoo.image.png;
import zoo.client.blockmodel;
namespace atlas;

let TILE = 16;
let BYTES = TILE * TILE * 4;

struct Slot { name: u8[..120], tile: i64 }

struct Grid { cols: i64, rows: i64, width: i64, height: i64, tiles: i64 }

fn find(slots: const Slot[:], name: const u8[:]) -> i64 {
    for s in slots {
        if s.name == name { return s.tile; }
    }
    -1
}

// Adds a texture by its model name, such as block/stone, and returns its tile.
// A name already in the atlas gives back the tile it has.
fn add(root: const u8[:], name: const u8[:], slots: Slot[>..]&, tiles: u8[>..]&) -> i64 {
    let known = find(slots, name);
    if known >= 0 { return known; }
    var file: u8[>..] = [];
    guard read_file(blockmodel::texture_path(root, name), file) else { return -1; }
    var rgba: u8[>..] = [];
    let img = png::decode(file, rgba);
    guard img.ok && img.width == TILE && img.height >= TILE else { return -1; }
    let tile = tiles.len / BYTES;
    // Only the first frame, which is the top 16 rows of the file.
    tiles.append(rgba[..BYTES]);
    var s = Slot { name: [], tile: tile };
    s.name.append(name[..min(name.len, 120)]);
    slots.push(s);
    tile
}

// A flat magenta tile, so a texture zoo could not read is obvious on screen
// rather than invisible. Mojang's own missing texture is black and magenta.
fn add_missing(slots: Slot[>..]&, tiles: u8[>..]&) -> i64 {
    let known = find(slots, "zoo:missing");
    if known >= 0 { return known; }
    let tile = tiles.len / BYTES;
    for y in TILE {
        for x in TILE {
            let dark = ((x / 8) + (y / 8)) % 2 == 0;
            tiles.push(if dark { 0 } else { 248 });
            tiles.push(0);
            tiles.push(if dark { 0 } else { 248 });
            tiles.push(255);
        }
    }
    var s = Slot { name: [], tile: tile };
    s.name.append("zoo:missing");
    slots.push(s);
    tile
}

fn square_cols(tiles: i64) -> i64 {
    var cols = 1;
    while cols * cols < tiles { cols++; }
    cols
}

// Lays the gathered tiles out as a square-ish grid and writes the image rows
// out in the order a GPU upload wants them.
fn flatten(tiles: const u8[:], out: u8[>..]&) -> Grid {
    let count = tiles.len / BYTES;
    let cols = square_cols(count);
    let rows = (count + cols - 1) / cols;
    var g = Grid { cols: cols, rows: rows, width: cols * TILE, height: rows * TILE, tiles: count };
    guard count > 0 else { return g; }
    for row in rows {
        for y in TILE {
            for col in cols {
                let tile = row * cols + col;
                if tile < count {
                    let at = tile * BYTES + y * TILE * 4;
                    out.append(tiles[at..at + TILE * 4]);
                } else {
                    for i in TILE * 4 { out.push(0); }
                }
            }
        }
    }
    g
}

// The top left corner of a tile in texture coordinates. A face's own corners
// are this plus one tile's width, which the mesher adds.
fn corner_of(g: const Grid&, tile: i64) -> f32, f32 {
    guard g.cols > 0 && tile >= 0 else { return 0.0, 0.0; }
    let u = (tile % g.cols) as f32 / g.cols as f32;
    let v = (tile / g.cols) as f32 / g.rows as f32;
    return u, v;
}

fn step_of(g: const Grid&) -> f32, f32 {
    guard g.cols > 0 && g.rows > 0 else { return 0.0, 0.0; }
    return 1.0 / g.cols as f32, 1.0 / g.rows as f32;
}
