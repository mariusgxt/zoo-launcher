// PNG decoding, enough for Minecraft's own textures: eight bits a channel,
// greyscale, truecolour, indexed or either with alpha, not interlaced. Mojang
// writes nothing else, and refusing the rest keeps this file small.
//
// Every image comes back as straight RGBA8, because that is what the atlas and
// the GPU want; a caller never has to ask what the file carried.
import std;
import zoo.archive.compress;
namespace png;

let SIG: const u8[:] = "\x89PNG\r\n\x1a\n";

let GREY = 0;
let RGB = 2;
let INDEXED = 3;
let GREY_ALPHA = 4;
let RGBA = 6;

struct Image { width: i64, height: i64, ok: bool, error: u8[..80] }

fn be32(d: const u8[:], at: i64) -> i64 {
    var v: i64 = 0;
    for i in 4 {
        let b: i64 = d[at + i];
        v = (v << 8) | b;
    }
    v
}

fn channels_of(colour: i64) -> i64 {
    match colour {
        GREY => { 1 },
        RGB => { 3 },
        INDEXED => { 1 },
        GREY_ALPHA => { 2 },
        RGBA => { 4 },
        _ => { 0 },
    }
}

fn fail(img: Image&, why: const u8[:]) -> Image {
    img.error.resize(0);
    img.error.append(why[..min(why.len, 80)]);
    img.ok = false;
    img
}

// The Paeth predictor of the PNG spec, kept as its own function because the
// three-way distance is the one part of unfiltering that is easy to get wrong.
fn paeth(a: i64, b: i64, c: i64) -> i64 {
    let p = a + b - c;
    let pa = abs(p - a);
    let pb = abs(p - b);
    let pc = abs(p - c);
    if pa <= pb && pa <= pc { a } else if pb <= pc { b } else { c }
}

// Undoes the per-row filter in place. Rows arrive as filter byte plus pixels.
fn unfilter(raw: u8[>..]&, width_bytes: i64, height: i64, step: i64) -> bool {
    guard raw.len >= (width_bytes + 1) * height else { return false; }
    for y in height {
        let row = y * (width_bytes + 1);
        let kind = raw[row];
        for x in width_bytes {
            let i = row + 1 + x;
            let left: i64 = if x >= step { raw[i - step] } else { 0 };
            let up: i64 = if y > 0 { raw[i - (width_bytes + 1)] } else { 0 };
            let up_left: i64 = if y > 0 && x >= step { raw[i - (width_bytes + 1) - step] } else { 0 };
            let cur: i64 = raw[i];
            let v = match kind {
                0 => { cur },
                1 => { cur + left },
                2 => { cur + up },
                3 => { cur + (left + up) / 2 },
                4 => { cur + paeth(left, up, up_left) },
                _ => { -1 },
            };
            if v < 0 { return false; }
            raw[i] = (v & 0xFF) as! u8;
        }
    }
    true
}

// Decodes into out as RGBA8, row by row from the top, appending nothing on
// failure. The palette and transparency chunks are honoured where present.
fn decode(d: const u8[:], out: u8[>..]&) -> Image {
    var img = Image { width: 0, height: 0, ok: false, error: [] };
    guard d.len > 8 && d[..8] == SIG else { return fail(img, "not a png"); }
    var p: i64 = 8;
    var colour: i64 = -1;
    var depth: i64 = 0;
    var palette: u8[>..] = [];
    var alpha: u8[>..] = [];
    var idat: u8[>..] = [];
    loop {
        guard p + 8 <= d.len else { return fail(img, "truncated"); }
        let size = be32(d, p);
        let kind = d[p + 4..p + 8];
        guard size >= 0 && p + 12 + size <= d.len else { return fail(img, "bad chunk size"); }
        let body = d[p + 8..p + 8 + size];
        if kind == "IHDR" {
            guard size == 13 else { return fail(img, "bad IHDR"); }
            img.width = be32(body, 0);
            img.height = be32(body, 4);
            depth = body[8];
            colour = body[9];
            guard body[12] == 0 else { return fail(img, "interlaced pngs are not read"); }
            guard depth == 8 else { return fail(img, "only eight bits a channel are read"); }
            guard channels_of(colour) > 0 else { return fail(img, "unknown colour type"); }
            guard img.width > 0 && img.height > 0 && img.width * img.height < 1 << 26 else { return fail(img, "unreasonable size"); }
        } else if kind == "PLTE" {
            palette.append(body);
        } else if kind == "tRNS" {
            alpha.append(body);
        } else if kind == "IDAT" {
            idat.append(body);
        } else if kind == "IEND" {
            break;
        }
        p += 12 + size;
    }
    guard colour >= 0 else { return fail(img, "no IHDR"); }
    guard idat.len > 0 else { return fail(img, "no image data"); }
    let channels = channels_of(colour);
    let width_bytes = img.width * channels;
    var raw: u8[>..] = [];
    guard compress::zlib(idat, raw) else { return fail(img, "broken image data"); }
    guard raw.len == (width_bytes + 1) * img.height else { return fail(img, "wrong image data size"); }
    guard unfilter(raw, width_bytes, img.height, channels) else { return fail(img, "unknown row filter"); }
    if colour == INDEXED {
        guard palette.len >= 3 else { return fail(img, "indexed png without a palette"); }
    }
    for y in img.height {
        let row = y * (width_bytes + 1) + 1;
        for x in img.width {
            let i = row + x * channels;
            match colour {
                GREY => {
                    out.push(raw[i]);
                    out.push(raw[i]);
                    out.push(raw[i]);
                    out.push(255);
                },
                GREY_ALPHA => {
                    out.push(raw[i]);
                    out.push(raw[i]);
                    out.push(raw[i]);
                    out.push(raw[i + 1]);
                },
                RGB => {
                    out.push(raw[i]);
                    out.push(raw[i + 1]);
                    out.push(raw[i + 2]);
                    out.push(255);
                },
                RGBA => {
                    out.push(raw[i]);
                    out.push(raw[i + 1]);
                    out.push(raw[i + 2]);
                    out.push(raw[i + 3]);
                },
                INDEXED => {
                    let n: i64 = raw[i];
                    guard n * 3 + 2 < palette.len else { return fail(img, "palette index out of range"); }
                    out.push(palette[n * 3]);
                    out.push(palette[n * 3 + 1]);
                    out.push(palette[n * 3 + 2]);
                    out.push(if n < alpha.len { alpha[n] } else { 255 });
                },
                _ => { return fail(img, "unknown colour type"); },
            }
        }
    }
    img.ok = true;
    img
}
