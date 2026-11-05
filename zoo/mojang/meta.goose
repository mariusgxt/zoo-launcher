// Mojang's launcher metadata: the version manifest and one version's file.
// Only the fields zoo uses are read; the json reader skips the rest without
// building a tree, which matters for the 800 KB manifest.
import std;
import json;
namespace mojang;

let MANIFEST_URL = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json";

// Fixed-size strings keep the list indexable for the version picker.
struct VersionRef {
    id: u8[..48],
    kind: u8[..16],
    url: u8[..200],
    sha1: u8[..40],
    released: u8[..32],
}

struct Manifest { latest_release: u8[..48], latest_snapshot: u8[..48], ok: bool, error: u8[..120] }

fn put(dst: u8[..48]&, s: const u8[:]) { dst.resize(0); dst.append(s[..min(s.len, 48)]); }

fn read_manifest(text: const u8[:], versions: VersionRef[>..]&) -> Manifest {
    var m = Manifest { latest_release: [], latest_snapshot: [], ok: false, error: [] };
    var scratch: u8[>..] = [];
    var r = json::reader(text);
    json::each_member(r) { key =>
        if key == "latest" {
            json::each_member(r) { k =>
                let v = json::read_string(r, scratch);
                if k == "release" { put(m.latest_release, v); }
                else if k == "snapshot" { put(m.latest_snapshot, v); }
            };
        } else if key == "versions" {
            json::each_element(r) {
                var v = VersionRef { id: [], kind: [], url: [], sha1: [], released: [] };
                json::each_member(r) { k =>
                    if k == "id" { v.id.append(clip(json::read_string(r, scratch), 48)); }
                    else if k == "type" { v.kind.append(clip(json::read_string(r, scratch), 16)); }
                    else if k == "url" { v.url.append(clip(json::read_string(r, scratch), 200)); }
                    else if k == "sha1" { v.sha1.append(clip(json::read_string(r, scratch), 40)); }
                    else if k == "releaseTime" { v.released.append(clip(json::read_string(r, scratch), 32)); }
                    else { json::skip(r); }
                };
                versions.push(v);
            };
        } else {
            json::skip(r);
        }
    };
    m.ok = json::finish(r);
    if !m.ok { let msg = json::message(r); m.error.append(clip(msg, 120)); }
    m
}

fn clip(s: const u8[:], n: i64) -> const u8[:] { s[..min(s.len, n)] }

// What one version's file says about the files zoo needs from it.
struct Version {
    id: u8[..48],
    client_url: u8[..200],
    client_sha1: u8[..40],
    client_size: i64,
    asset_index: u8[..48],
    asset_url: u8[..200],
    asset_sha1: u8[..40],
    java_major: i64,
    ok: bool,
    error: u8[..120],
}

fn read_version(text: const u8[:]) -> Version {
    var v = Version { id: [], client_url: [], client_sha1: [], client_size: 0, asset_index: [],
                      asset_url: [], asset_sha1: [], java_major: 0, ok: false, error: [] };
    var scratch: u8[>..] = [];
    var r = json::reader(text);
    json::each_member(r) { key =>
        if key == "id" {
            v.id.append(clip(json::read_string(r, scratch), 48));
        } else if key == "downloads" {
            json::each_member(r) { k =>
                if k == "client" {
                    json::each_member(r) { f =>
                        if f == "url" { v.client_url.append(clip(json::read_string(r, scratch), 200)); }
                        else if f == "sha1" { v.client_sha1.append(clip(json::read_string(r, scratch), 40)); }
                        else if f == "size" { v.client_size = json::read_int(r); }
                        else { json::skip(r); }
                    };
                } else {
                    json::skip(r);
                }
            };
        } else if key == "assetIndex" {
            json::each_member(r) { f =>
                if f == "id" { v.asset_index.append(clip(json::read_string(r, scratch), 48)); }
                else if f == "url" { v.asset_url.append(clip(json::read_string(r, scratch), 200)); }
                else if f == "sha1" { v.asset_sha1.append(clip(json::read_string(r, scratch), 40)); }
                else { json::skip(r); }
            };
        } else if key == "javaVersion" {
            json::each_member(r) { f =>
                if f == "majorVersion" { v.java_major = json::read_int(r); } else { json::skip(r); }
            };
        } else {
            json::skip(r);
        }
    };
    v.ok = json::finish(r) && v.client_url.len > 0;
    if !v.ok {
        if json::finish(r) { v.error.append("version file has no client download"); }
        else { let msg = json::message(r); v.error.append(clip(msg, 120)); }
    }
    v
}
