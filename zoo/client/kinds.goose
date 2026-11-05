// What the resource files do not say about a block: whether it can be seen
// through and which colour it is tinted with. Mojang keeps both in the game's
// code rather than in its data, so zoo keeps them here, by name, in one place
// that is easy to correct when a version adds a block.
import std;
namespace kinds;

let TINT_NONE = 0;
let TINT_GRASS = 1;
let TINT_FOLIAGE = 2;
let TINT_WATER = 3;
let TINT_BIRCH = 4;
let TINT_SPRUCE = 5;

fn bare(name: const u8[:]) -> const u8[:] {
    for i in name.len {
        if name[i] == ':' { return name[i + 1..]; }
    }
    name
}

fn has(name: const u8[:], part: const u8[:]) -> bool { find(name, part) >= 0 }

// A block that does not hide what is behind it. Its neighbours keep their faces
// against it, which is what lets you see the trunk inside a tree.
fn see_through(name: const u8[:]) -> bool {
    let n = bare(name);
    if ends_with(n, "_leaves") || has(n, "glass") || has(n, "_door") || has(n, "_trapdoor") { return true; }
    n == "water" || n == "ice" || n == "frosted_ice" || n == "slime_block" || n == "honey_block" ||
    n == "barrier" || n == "spawner" || n == "beacon" || n == "iron_bars" || n == "cobweb" ||
    n == "scaffolding"
}

// Leaves whose texture is already coloured, and so take no tint.
fn painted_leaves(n: const u8[:]) -> bool {
    n == "cherry_leaves" || n == "azalea_leaves" || n == "flowering_azalea_leaves" || n == "pale_oak_leaves"
}

// The tint of a block's top face and of its other faces. A grass block is
// green only on top; its side texture already carries its own green.
fn tints_of(name: const u8[:]) -> i64, i64 {
    let n = bare(name);
    if n == "grass_block" { return TINT_GRASS, TINT_NONE; }
    if n == "birch_leaves" { return TINT_BIRCH, TINT_BIRCH; }
    if n == "spruce_leaves" { return TINT_SPRUCE, TINT_SPRUCE; }
    if ends_with(n, "_leaves") && !painted_leaves(n) { return TINT_FOLIAGE, TINT_FOLIAGE; }
    if n == "vine" { return TINT_FOLIAGE, TINT_FOLIAGE; }
    if n == "water" { return TINT_WATER, TINT_WATER; }
    if n == "short_grass" || n == "tall_grass" || n == "fern" || n == "large_fern" || n == "sugar_cane" {
        return TINT_GRASS, TINT_GRASS;
    }
    return TINT_NONE, TINT_NONE;
}

// The colours of the plains biome. Every biome has its own, and zoo reads
// none of them yet, so the whole world looks like plains for now.
fn colour_of(tint: i64) -> f32, f32, f32 {
    match tint {
        TINT_GRASS => { return 0.569, 0.741, 0.349; },
        TINT_FOLIAGE => { return 0.467, 0.671, 0.184; },
        TINT_WATER => { return 0.247, 0.463, 0.894; },
        TINT_BIRCH => { return 0.502, 0.655, 0.333; },
        TINT_SPRUCE => { return 0.380, 0.600, 0.380; },
        _ => { return 1.0, 1.0, 1.0; },
    }
}
