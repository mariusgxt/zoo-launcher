// SHA-1, written in Goose instead of bound from C: Mojang publishes a SHA-1
// for every client jar, library and asset object, so this runs over every
// downloaded byte and should stay free of a C dependency.
import std;
namespace sha1;

struct State { h: u32[5], chunk: u8[64], fill: i64, total: u64 }

fn start() -> State {
    State { h: [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0], chunk: [0; 64], fill: 0, total: 0 }
}

fn rotl(x: u32, n: u32) -> u32 { (x << n) | (x >> (32 - n)) }

fn compress(s: State&, b: const u8[:]) {
    var w: u32[80] = [0; 80];
    for i in 16 {
        w[i] = (b[i * 4] as u32 << 24) | (b[i * 4 + 1] as u32 << 16) | (b[i * 4 + 2] as u32 << 8) | b[i * 4 + 3];
    }
    for i in 16..80 { w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1); }
    var a = s.h[0];
    var bb = s.h[1];
    var c = s.h[2];
    var d = s.h[3];
    var e = s.h[4];
    for i in 80 {
        var f: u32 = 0;
        var k: u32 = 0;
        if i < 20 { f = (bb & c) | (~bb & d); k = 0x5A827999; }
        else if i < 40 { f = bb ^ c ^ d; k = 0x6ED9EBA1; }
        else if i < 60 { f = (bb & c) | (bb & d) | (c & d); k = 0x8F1BBCDC; }
        else { f = bb ^ c ^ d; k = 0xCA62C1D6; }
        let t = rotl(a, 5) + f + e + k + w[i];
        e = d;
        d = c;
        c = rotl(bb, 30);
        bb = a;
        a = t;
    }
    s.h[0] += a;
    s.h[1] += bb;
    s.h[2] += c;
    s.h[3] += d;
    s.h[4] += e;
}

fn update(s: State&, data: const u8[:]) {
    var i = 0;
    s.total += data.len as u64;
    if s.fill > 0 {
        while s.fill < 64 && i < data.len { s.chunk[s.fill] = data[i]; s.fill++; i++; }
        if s.fill < 64 { return; }
        compress(s, s.chunk);
        s.fill = 0;
    }
    while i + 64 <= data.len {
        compress(s, data[i..i + 64]);
        i += 64;
    }
    while i < data.len { s.chunk[s.fill] = data[i]; s.fill++; i++; }
}

// Lowercase hex, the form Mojang's metadata uses, so a check is a plain compare.
fn finish(s: State&) -> u8[..40] {
    let bits = s.total * 8;
    var tail: u8[72] = [0; 72];
    tail[0] = 0x80;
    let pad_len = if s.fill < 56 { 56 - s.fill } else { 120 - s.fill };
    update(s, tail[..pad_len]);
    var len_bytes: u8[8] = [0; 8];
    for i in 8 { len_bytes[i] = (bits >> ((7 - i) * 8) as u64) as! u8; }
    update(s, len_bytes);
    var out: u8[..40] = [];
    for i in 5 { format_uint(out, s.h[i], 16, 8, '0'); }
    out
}

fn hex(data: const u8[:]) -> u8[..40] {
    var s = start();
    update(s, data);
    finish(s)
}
