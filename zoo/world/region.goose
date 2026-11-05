// Anvil region files: 32x32 chunks in one r.X.Z.mca, addressed by a header of
// 1024 slots. A slot gives an offset in 4 KiB sectors, which is why a region
// file is always a multiple of 4 KiB and why nothing here seeks by chunk size.
import std;
import os;
import zoo.archive.compress;
namespace region;

let SECTOR = 4096;
let SPAN = 32;             // chunks per region edge

let GZIP = 1;
let ZLIB = 2;
let NONE = 3;

struct Slot { offset: i64, sectors: i64 }

// Chunk coordinates are world-wide and go negative, so the region they fall in
// is a floor division, not a truncating one.
fn region_of(cx: i64, cz: i64) -> i64, i64 { return div_euclid(cx, SPAN), div_euclid(cz, SPAN); }

fn file_name(out: u8[>..]&, rx: i64, rz: i64) { format(out, "r.", rx, ".", rz, ".mca"); }

fn path_of(dir: const u8[:], rx: i64, rz: i64) -> u8[>..] {
    var p: u8[>..] = [];
    p.append(dir);
    p.append("/");
    file_name(p, rx, rz);
    p
}

fn slot_of(d: const u8[:], cx: i64, cz: i64) -> Slot {
    // Goose's % is euclidean, so a negative chunk coordinate already lands in
    // 0..31 without a correction step.
    let i = 4 * (cx % SPAN + (cz % SPAN) * SPAN);
    guard d.len >= 2 * SECTOR && i + 4 <= d.len else { return Slot { offset: 0, sectors: 0 }; }
    let hi: i64 = d[i];
    let mid: i64 = d[i + 1];
    let lo: i64 = d[i + 2];
    let sectors: i64 = d[i + 3];
    Slot { offset: (hi << 16) | (mid << 8) | lo, sectors: sectors }
}

// Appends one chunk's NBT to out, decompressing it. false means the chunk has
// never been generated, or its entry is damaged; the two are told apart by
// asking exists() first.
fn chunk(d: const u8[:], cx: i64, cz: i64, out: u8[>..]&) -> bool {
    let s = slot_of(d, cx, cz);
    guard s.sectors > 0 else { return false; }
    let at = s.offset * SECTOR;
    guard at >= 0 && at + 5 <= d.len else { return false; }
    var len: i64 = 0;
    for i in 4 {
        let b: i64 = d[at + i];
        len = (len << 8) | b;
    }
    guard len > 1 && at + 4 + len <= d.len else { return false; }
    let body = d[at + 5..at + 4 + len];
    match d[at + 4] {
        GZIP => { compress::gzip(body, out) },
        ZLIB => { compress::zlib(body, out) },
        NONE => { out.append(body); true },
        // LZ4 and the custom slot exist since 1.20 but are off by default, and
        // zoo would rather say so than hand back half a chunk.
        _ => { false },
    }
}

fn exists(d: const u8[:], cx: i64, cz: i64) -> bool { slot_of(d, cx, cz).sectors > 0 }

// Reads the region file a chunk belongs to. Kept apart from chunk() so a
// caller walking many chunks reads each file once.
fn read_file_of(dir: const u8[:], cx: i64, cz: i64, out: u8[>..]&) -> bool {
    let rx, rz = region_of(cx, cz);
    read_file(path_of(dir, rx, rz), out)
}
