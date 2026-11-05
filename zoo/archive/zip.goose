// Zip reading over a jar held in memory. The central directory is walked
// straight from the bytes, and entries hand back slices of the jar instead
// of copies, so listing a 30 MB client jar costs nothing but the scan.
import std;
import .inflate;
namespace zip;

struct Entry {
    name: const u8[:],
    method: u16,
    crc: u32,
    packed_size: i64,
    size: i64,
    local_offset: i64,
}

fn u16_at(d: const u8[:], i: i64) -> u16 { d[i] | (d[i + 1] as u16 << 8) }
fn u32_at(d: const u8[:], i: i64) -> u32 {
    d[i] | (d[i + 1] as u32 << 8) | (d[i + 2] as u32 << 16) | (d[i + 3] as u32 << 24)
}

// The end record sits in the last 64 KiB + 22 bytes, behind an optional
// comment, so it is searched for backwards rather than assumed at the end.
fn find_end(d: const u8[:]) -> i64 {
    guard d.len >= 22 else { return -1; }
    var i = d.len - 22;
    let stop = max(0, d.len - 22 - 65535);
    while i >= stop {
        if u32_at(d, i) == 0x06054b50 { return i; }
        i--;
    }
    return -1;
}

// Zip64 is left out on purpose: Minecraft jars and their libraries stay far
// below 4 GiB and 65535 entries.
fn entries(d: const u8[:], out: Entry[>..]&) -> bool {
    let end = find_end(d);
    guard end >= 0 else { return false; }
    let count = u16_at(d, end + 10) as i64;
    var p = u32_at(d, end + 16) as i64;
    for n in count {
        if p + 46 > d.len || u32_at(d, p) != 0x02014b50 { return false; }
        let name_len = u16_at(d, p + 28) as i64;
        let extra_len = u16_at(d, p + 30) as i64;
        let comment_len = u16_at(d, p + 32) as i64;
        if p + 46 + name_len > d.len { return false; }
        out.push(Entry {
            name: d[p + 46..p + 46 + name_len],
            method: u16_at(d, p + 10),
            crc: u32_at(d, p + 16),
            packed_size: u32_at(d, p + 20),
            size: u32_at(d, p + 24),
            local_offset: u32_at(d, p + 42),
        });
        p += 46 + name_len + extra_len + comment_len;
    }
    return true;
}

fn is_dir(e: const Entry&) -> bool { e.name.len > 0 && e.name[e.name.len - 1] == '/' }

// The local header repeats name and extra field with lengths that may differ
// from the central copy, so the data offset is read from it, never derived.
fn data_of(d: const u8[:], e: const Entry&) -> const u8[:], bool {
    let p = e.local_offset;
    if p + 30 > d.len || u32_at(d, p) != 0x04034b50 { return d[0..0], false; }
    let start = p + 30 + u16_at(d, p + 26) + u16_at(d, p + 28);
    if start + e.packed_size > d.len { return d[0..0], false; }
    return d[start..start + e.packed_size], true;
}

// Appends the entry's contents to out.
fn extract(d: const u8[:], e: const Entry&, out: u8[>..]&) -> bool {
    let raw, ok = data_of(d, e);
    guard ok else { return false; }
    let before = out.len;
    let done = match e.method {
        0 => block { out.append(raw); true },
        8 => inflate::raw(raw, out),
        _ => false,
    };
    return done && out.len - before == e.size;
}
