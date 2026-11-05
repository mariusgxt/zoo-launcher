// NBT, Mojang's binary tag format, read into one flat array of nodes rather
// than a tree of owned values: Goose has no heap, and the tags of a chunk are
// only ever walked, never reshaped. A node points at its first child and its
// next sibling by index, the way a parsed document is laid out.
//
// Nothing here copies bytes. A node stores offsets into the buffer it was read
// from, not slices of it, so the buffer travels with the nodes as `d` and the
// nodes themselves stay plain values a worker thread can pass on.
import std;
namespace nbt;

let END = 0;
let BYTE = 1;
let SHORT = 2;
let INT = 3;
let LONG = 4;
let FLOAT = 5;
let DOUBLE = 6;
let BYTE_ARRAY = 7;
let STRING = 8;
let LIST = 9;
let COMPOUND = 10;
let INT_ARRAY = 11;
let LONG_ARRAY = 12;

// Deeper than a chunk or a level.dat ever nests. The limit is there so a
// damaged file cannot walk the parser off the stack.
let MAX_DEPTH = 64;

// num carries every integer kind, dec every float kind, and at/size mark the
// bytes of a string or of an array payload. count is the number of entries of
// a list, compound or array.
struct Node {
    kind: u8,
    elem: u8,            // element kind of a list, END for anything else
    name_at: i64,
    name_size: i64,
    num: i64,
    dec: f64,
    at: i64,
    size: i64,
    count: i64,
    child: i64,          // first child, -1 if there is none
    next: i64,           // next sibling, -1 at the end of the chain
}

struct Src { d: const u8[:], p: i64, bad: bool }

// Reading past the end marks the source bad and keeps returning zeroes, so the
// parser can run to its end and be judged once, the way inflate's reader does.
fn byte_of(s: Src&) -> u8 {
    if s.p >= s.d.len { s.bad = true; return 0; }
    let v = s.d[s.p];
    s.p++;
    v
}

fn uint_of(s: Src&, n: i64) -> u64 {
    var v: u64 = 0;
    var i = 0;
    while i < n {
        let b: u64 = byte_of(s);
        v = (v << 8) | b;
        i++;
    }
    v
}

// Returns the offset of a run of n bytes and steps over it.
fn span_of(s: Src&, n: i64) -> i64 {
    if n < 0 || s.p + n > s.d.len { s.bad = true; return 0; }
    let at = s.p;
    s.p += n;
    at
}

extern fn ldexp(x: f64, e: i32) -> f64;

// IEEE-754 by arithmetic, because Goose offers no bit cast. Infinities and NaN
// come back as zero; no field zoo reads out of a world carries them.
fn ieee(bits: u64, mant_bits: i64, exp_bits: i64) -> f64 {
    let exp_mask = (1 as u64 << exp_bits as u64) - 1;
    let bias = (exp_mask >> 1) as i64;
    let exp = ((bits >> mant_bits as u64) & exp_mask) as i64;
    let frac: f64 = (bits & ((1 as u64 << mant_bits as u64) - 1)) as i64;
    var v = 0.0;
    if exp == 0 {
        v = ldexp(frac, (1 - bias - mant_bits) as! i32);
    } else if exp < exp_mask as i64 {
        v = ldexp(frac + ldexp(1.0, mant_bits as! i32), (exp - bias - mant_bits) as! i32);
    }
    if (bits >> (mant_bits + exp_bits) as u64) & 1 != 0 { -v } else { v }
}

fn blank(kind: u8, name_at: i64, name_size: i64) -> Node {
    Node {
        kind: kind, elem: END, name_at: name_at, name_size: name_size,
        num: 0, dec: 0.0, at: 0, size: 0, count: 0, child: -1, next: -1,
    }
}

// Appends the value of one tag, and its subtree, and returns its index.
// Children are appended after their parent and chained in file order.
recursive fn value(s: Src&, out: Node[>..]&, kind: u8, name_at: i64, name_size: i64, depth: i64) -> i64 {
    guard depth < MAX_DEPTH && !s.bad else { s.bad = true; return -1; }
    let me = out.len;
    out.push(blank(kind, name_at, name_size));
    match kind {
        BYTE => { out[me].num = byte_of(s) as! i8; },
        SHORT => { out[me].num = uint_of(s, 2) as! i16; },
        INT => { out[me].num = uint_of(s, 4) as! i32; },
        LONG => { out[me].num = uint_of(s, 8) as! i64; },
        FLOAT => { out[me].dec = ieee(uint_of(s, 4), 23, 8); },
        DOUBLE => { out[me].dec = ieee(uint_of(s, 8), 52, 11); },
        STRING => {
            let n = uint_of(s, 2) as i64;
            out[me].at = span_of(s, n);
            out[me].size = n;
            out[me].count = n;
        },
        BYTE_ARRAY, INT_ARRAY, LONG_ARRAY => {
            let n: i64 = uint_of(s, 4) as! i32;
            let width = if kind == BYTE_ARRAY { 1 } else if kind == INT_ARRAY { 4 } else { 8 };
            out[me].at = span_of(s, n * width);
            out[me].size = n * width;
            out[me].count = n;
        },
        LIST => {
            let elem = byte_of(s);
            let n: i64 = uint_of(s, 4) as! i32;
            out[me].elem = elem;
            out[me].count = n;
            // A list of END with entries is malformed; an empty one is how
            // Mojang writes a list whose element type is not decided yet.
            if elem == END && n > 0 { s.bad = true; return me; }
            var last: i64 = -1;
            for i in n {
                let kid = value(s, out, elem, 0, 0, depth + 1);
                guard kid >= 0 else { return me; }
                if last < 0 { out[me].child = kid; } else { out[last].next = kid; }
                last = kid;
            }
        },
        COMPOUND => {
            var last: i64 = -1;
            loop {
                let k = byte_of(s);
                if k == END || s.bad { break; }
                let n = uint_of(s, 2) as i64;
                let at = span_of(s, n);
                let kid = value(s, out, k, at, n, depth + 1);
                guard kid >= 0 else { return me; }
                if last < 0 { out[me].child = kid; } else { out[last].next = kid; }
                last = kid;
                out[me].count++;
            }
        },
        _ => { s.bad = true; },
    }
    me
}

// Reads a whole document. The root is node 0, the unnamed compound every NBT
// file starts with. Returns false and leaves out half-filled on bad input.
fn read(d: const u8[:], out: Node[>..]&) -> bool {
    out.resize(0);
    var s = Src { d: d, p: 0, bad: false };
    let kind = byte_of(s);
    guard kind == COMPOUND else { return false; }
    let n = uint_of(s, 2) as i64;
    let at = span_of(s, n);
    guard !s.bad else { return false; }
    let root = value(s, out, kind, at, n, 0);
    root == 0 && !s.bad
}

// --- walking ---------------------------------------------------------------

fn name_of(d: const u8[:], n: const Node&) -> const u8[:] { d[n.name_at..n.name_at + n.name_size] }
fn bytes_of(d: const u8[:], n: const Node&) -> const u8[:] { d[n.at..n.at + n.size] }

// The named member of a compound, or -1. Linear, which is what a handful of
// members per compound wants; a chunk's hot path reads each member once.
fn member(d: const u8[:], nodes: const Node[:], at: i64, name: const u8[:]) -> i64 {
    guard at >= 0 && at < nodes.len else { return -1; }
    var i = nodes[at].child;
    while i >= 0 {
        if name_of(d, nodes[i]) == name { return i; }
        i = nodes[i].next;
    }
    -1
}

// Follows two or three names in one go, which is how deep most lookups into a
// chunk reach (`Data/LevelName`, `block_states/palette`).
fn member(d: const u8[:], nodes: const Node[:], at: i64, a: const u8[:], b: const u8[:]) -> i64 {
    member(d, nodes, member(d, nodes, at, a), b)
}

fn member(d: const u8[:], nodes: const Node[:], at: i64, a: const u8[:], b: const u8[:], c: const u8[:]) -> i64 {
    member(d, nodes, member(d, nodes, member(d, nodes, at, a), b), c)
}

// The nth child of a list or compound, or -1.
fn entry(nodes: const Node[:], at: i64, n: i64) -> i64 {
    guard at >= 0 && at < nodes.len && n >= 0 else { return -1; }
    var i = nodes[at].child;
    var k = n;
    while i >= 0 && k > 0 {
        i = nodes[i].next;
        k--;
    }
    if k == 0 { i } else { -1 }
}

fn int_of(nodes: const Node[:], at: i64, fallback: i64) -> i64 {
    if at >= 0 && at < nodes.len && nodes[at].kind >= BYTE && nodes[at].kind <= LONG {
        nodes[at].num
    } else {
        fallback
    }
}

fn text_of(d: const u8[:], nodes: const Node[:], at: i64) -> const u8[:] {
    if at >= 0 && at < nodes.len && nodes[at].kind == STRING { bytes_of(d, nodes[at]) } else { d[..0] }
}

// The nth element of a long or int array, read big-endian out of the payload.
fn long_at(d: const u8[:], nodes: const Node[:], at: i64, n: i64) -> i64 {
    guard at >= 0 && at < nodes.len && nodes[at].kind == LONG_ARRAY && n >= 0 && n < nodes[at].count else { return 0; }
    let base = nodes[at].at + n * 8;
    var v: u64 = 0;
    for i in 8 {
        let b: u64 = d[base + i];
        v = (v << 8) | b;
    }
    v as! i64
}

fn int_at(d: const u8[:], nodes: const Node[:], at: i64, n: i64) -> i32 {
    guard at >= 0 && at < nodes.len && nodes[at].kind == INT_ARRAY && n >= 0 && n < nodes[at].count else { return 0; }
    let base = nodes[at].at + n * 4;
    var v: u32 = 0;
    for i in 4 {
        let b: u32 = d[base + i];
        v = (v << 8) | b;
    }
    v as! i32
}
