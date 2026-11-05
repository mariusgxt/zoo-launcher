// zlib (RFC 1950) and gzip (RFC 1952) around the raw DEFLATE decoder. A jar
// needs neither, but a region file stores its chunks as zlib, and a world old
// enough still has gzip ones, so both headers have to be stepped over before
// inflate sees the stream.
import std;
import .inflate;
namespace compress;

// Method 8 is the only one zlib ever defined, and a preset dictionary is one
// we could not supply, so both are refused rather than guessed at.
fn zlib(src: const u8[:], out: u8[>..]&) -> bool {
    guard src.len > 6 else { return false; }
    guard (src[0] & 0x0F) == 8 && (src[1] & 0x20) == 0 else { return false; }
    let cmf: i64 = src[0];
    let flg: i64 = src[1];
    guard ((cmf << 8) | flg) % 31 == 0 else { return false; }
    inflate::raw(src[2..src.len - 4], out)
}

let F_EXTRA = 0x04;
let F_NAME = 0x08;
let F_COMMENT = 0x10;
let F_HCRC = 0x02;

fn zero_end(d: const u8[:], from: i64) -> i64 {
    var i = from;
    while i < d.len && d[i] != 0 { i++; }
    if i < d.len { i + 1 } else { -1 }
}

fn gzip(src: const u8[:], out: u8[>..]&) -> bool {
    guard src.len > 18 else { return false; }
    guard src[0] == 0x1F && src[1] == 0x8B && src[2] == 8 else { return false; }
    let flags = src[3] as i64;
    var p: i64 = 10;
    if (flags & F_EXTRA) != 0 {
        guard p + 2 <= src.len else { return false; }
        let lo: i64 = src[p];
        let hi: i64 = src[p + 1];
        p += 2 + (lo | (hi << 8));
    }
    if (flags & F_NAME) != 0 { p = zero_end(src, p); guard p >= 0 else { return false; } }
    if (flags & F_COMMENT) != 0 { p = zero_end(src, p); guard p >= 0 else { return false; } }
    if (flags & F_HCRC) != 0 { p += 2; }
    guard p >= 0 && p + 8 <= src.len else { return false; }
    inflate::raw(src[p..src.len - 8], out)
}

// Picks the wrapper from the first bytes. Useful where a file may carry either,
// as level.dat does: gzip since Beta, but uncompressed in a few exports.
fn any(src: const u8[:], out: u8[>..]&) -> bool {
    guard src.len > 2 else { return false; }
    if src[0] == 0x1F && src[1] == 0x8B { return gzip(src, out); }
    let cmf: i64 = src[0];
    let flg: i64 = src[1];
    if (src[0] & 0x0F) == 8 && ((cmf << 8) | flg) % 31 == 0 { return zlib(src, out); }
    out.append(src);
    true
}
