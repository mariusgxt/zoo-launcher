// DEFLATE decoder (RFC 1951), modelled on zlib's puff.c. Kept in Goose so
// reading a client jar needs no zlib: the launcher only ever decompresses,
// and puff's canonical-Huffman approach is small enough to own.
import std;
namespace inflate;

let MAXBITS = 15;
let MAXLCODES = 286;
let MAXDCODES = 30;
let FIXLCODES = 288;

struct Bits { src: const u8[:], pos: i64, buf: u32, cnt: u32, bad: bool }

// count[len] is how many codes have that length, symbol[] the symbols in
// canonical order; that is all a canonical code needs to be decoded.
struct Huff { count: i16[16], symbol: i16[288] }

let LBASE: i32[29] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
                      35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258];
let LEXT: i32[29] = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
                     3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0];
let DBASE: i32[30] = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
                      257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
                      8193, 12289, 16385, 24577];
let DEXT: i32[30] = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
                     7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13];
let CLEN_ORDER: i64[19] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

// Running past the input marks the stream bad instead of aborting; the
// caller checks once at the end, the way a sticky error flag reads best here.
fn need(b: Bits&, n: u32) -> u32 {
    var v = b.buf;
    while b.cnt < n {
        if b.pos >= b.src.len { b.bad = true; return 0; }
        v |= (b.src[b.pos] as u32) << b.cnt;
        b.pos++;
        b.cnt += 8;
    }
    b.buf = if n == 32 { 0 } else { v >> n };
    b.cnt -= n;
    return if n == 32 { v } else { v & ((1 << n) - 1) };
}

fn decode(b: Bits&, h: const Huff&) -> i32 {
    var code: i32 = 0;
    var first: i32 = 0;
    var index: i32 = 0;
    for len in 1..MAXBITS + 1 {
        code |= need(b, 1) as i32;
        if b.bad { return -1; }
        let count = h.count[len] as i32;
        if code - count < first { return h.symbol[(index + (code - first)) as i64]; }
        index += count;
        first += count;
        first <<= 1;
        code <<= 1;
    }
    return -10;
}

// Returns 0 for a complete code, >0 for an incomplete one and <0 for an
// over-subscribed one, as puff does: incomplete codes are legal for a
// single distance code, so the caller decides.
fn construct(h: Huff&, lengths: const i16[:]) -> i32 {
    for i in 16 { h.count[i] = 0; }
    for l in lengths { h.count[l as i64] += 1; }
    if h.count[0] == lengths.len { return 0; }
    var left: i32 = 1;
    for len in 1..MAXBITS + 1 {
        left <<= 1;
        left -= h.count[len];
        if left < 0 { return left; }
    }
    var offs: i16[16] = [0; 16];
    for len in 1..MAXBITS { offs[len + 1] = offs[len] + h.count[len]; }
    for sym in lengths.len {
        let l = lengths[sym] as i64;
        if l != 0 { h.symbol[offs[l] as i64] = sym as i16; offs[l] += 1; }
    }
    return left;
}

fn codes(b: Bits&, out: u8[>..]&, lencode: const Huff&, distcode: const Huff&) -> bool {
    loop {
        let sym = decode(b, lencode);
        if sym < 0 { return false; }
        if sym < 256 { out.push(sym as! u8); continue; }
        if sym == 256 { return true; }
        let li = (sym - 257) as i64;
        if li >= 29 { return false; }
        let len = LBASE[li] + need(b, LEXT[li] as u32) as i32;
        let ds = decode(b, distcode);
        if ds < 0 || ds >= 30 { return false; }
        let dist = (DBASE[ds as i64] + need(b, DEXT[ds as i64] as u32) as i32) as i64;
        if b.bad || dist > out.len { return false; }
        for i in len as i64 { out.push(out[out.len - dist]); }
    }
}

fn stored(b: Bits&, out: u8[>..]&) -> bool {
    b.buf = 0;
    b.cnt = 0;
    if b.pos + 4 > b.src.len { return false; }
    let len = b.src[b.pos] | (b.src[b.pos + 1] as i64 << 8);
    let nlen = b.src[b.pos + 2] | (b.src[b.pos + 3] as i64 << 8);
    b.pos += 4;
    if len != (~nlen & 0xffff) { return false; }
    if b.pos + len > b.src.len { return false; }
    out.append(b.src[b.pos..b.pos + len]);
    b.pos += len;
    return true;
}

fn fixed(b: Bits&, out: u8[>..]&) -> bool {
    var lengths: i16[FIXLCODES] = [0; FIXLCODES];
    for i in 0..144 { lengths[i] = 8; }
    for i in 144..256 { lengths[i] = 9; }
    for i in 256..280 { lengths[i] = 7; }
    for i in 280..FIXLCODES { lengths[i] = 8; }
    var lencode = Huff { .. };
    construct(lencode, lengths);
    var dl: i16[MAXDCODES] = [5; MAXDCODES];
    var distcode = Huff { .. };
    construct(distcode, dl);
    return codes(b, out, lencode, distcode);
}

fn dynamic(b: Bits&, out: u8[>..]&) -> bool {
    let nlen = need(b, 5) as i64 + 257;
    let ndist = need(b, 5) as i64 + 1;
    let ncode = need(b, 4) as i64 + 4;
    if b.bad || nlen > MAXLCODES || ndist > MAXDCODES { return false; }
    var lengths: i16[316] = [0; 316];
    for i in ncode { lengths[CLEN_ORDER[i]] = need(b, 3) as i16; }
    var lencode = Huff { .. };
    if construct(lencode, lengths[..19]) != 0 { return false; }
    var index = 0;
    while index < nlen + ndist {
        var sym = decode(b, lencode);
        if sym < 0 { return false; }
        if sym < 16 { lengths[index] = sym as i16; index++; continue; }
        var len: i16 = 0;
        if sym == 16 {
            if index == 0 { return false; }
            len = lengths[index - 1];
            sym = 3 + need(b, 2) as i32;
        } else if sym == 17 {
            sym = 3 + need(b, 3) as i32;
        } else {
            sym = 11 + need(b, 7) as i32;
        }
        if index + sym > nlen + ndist { return false; }
        for i in sym as i64 { lengths[index] = len; index++; }
    }
    if lengths[256] == 0 { return false; }
    let err = construct(lencode, lengths[..nlen]);
    if err < 0 || (err > 0 && nlen - (lencode.count[0]) != 1) { return false; }
    var distcode = Huff { .. };
    let derr = construct(distcode, lengths[nlen..nlen + ndist]);
    if derr < 0 || (derr > 0 && ndist - (distcode.count[0]) != 1) { return false; }
    return codes(b, out, lencode, distcode);
}

// Raw DEFLATE, as zip entries store it (no zlib header). Appends to out.
fn raw(src: const u8[:], out: u8[>..]&) -> bool {
    var b = Bits { src: src, pos: 0, buf: 0, cnt: 0, bad: false };
    loop {
        let last = need(b, 1);
        let kind = need(b, 2);
        if b.bad { return false; }
        let ok = match kind {
            0 => stored(b, out),
            1 => fixed(b, out),
            2 => dynamic(b, out),
            _ => false,
        };
        if !ok || b.bad { return false; }
        if last == 1 { return true; }
    }
}
