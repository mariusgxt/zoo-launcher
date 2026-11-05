// The zoo client, first look: opens a singleplayer world and draws its chunks
// with the textures prepared from your own copy of Minecraft. No gameplay yet,
// a free camera only.
//
//   zoo-client                        the newest world of your .minecraft
//   zoo-client --world NAME           a world by its folder or its name
//   zoo-client --saves DIR            another saves folder
//   zoo-client --resources DIR        another prepared resources folder
//   zoo-client --at X Y Z             start somewhere else
//   zoo-client --radius N             chunks to load around the start
//   zoo-client --frames N             draws N frames, saves zoo-client.png
//   zoo-client --list                 lists the worlds it can find
//   zoo-client --check                prints the folders it uses and whether they work
import std;
import os;
import vec;
import gfx;
import zoo.platform;
import zoo.specimen;
import zoo.diagnose;
import zoo.fatal;
import zoo.world.nbt;
import zoo.world.region;
import zoo.world.chunk;
import zoo.world.saves;
import zoo.client.atlas;
import zoo.client.mesh;
import zoo.client.camera;

let DEFAULT_RADIUS = 3;

struct Options {
    world: u8[..80],
    saves_dir: u8[..400],
    resources: u8[..400],
    radius: i64,
    frames: i64,
    list: bool,
    version: bool,
    check: bool,
    at_x: f32,
    at_y: f32,
    at_z: f32,
    placed: bool,
}

fn usage() {
    write_stderr("usage: zoo-client [--world NAME] [--saves DIR] [--resources DIR]\n");
    write_stderr("                  [--at X Y Z] [--radius N] [--frames N] [--list] [--version]\n");
}

fn read_number(s: const u8[:]) -> f32 {
    let v, ok = parse_flt(s);
    if ok { v as! f32 } else { 0.0 }
}

fn read_options() -> Options {
    var o = Options {
        world: [], saves_dir: [], resources: [], radius: DEFAULT_RADIUS, frames: -1,
        list: false, version: false, check: false, at_x: 0.0, at_y: 0.0, at_z: 0.0, placed: false,
    };
    let argv = args();
    var i = 1;
    while i < argv.len {
        let flag = argv[i];
        if flag == "--list" { o.list = true; i++; }
        else if flag == "--check" { o.check = true; i++; }
        else if flag == "--version" { o.version = true; i++; }
        else if flag == "--at" && i + 3 < argv.len {
            o.at_x = read_number(argv[i + 1]);
            o.at_y = read_number(argv[i + 2]);
            o.at_z = read_number(argv[i + 3]);
            o.placed = true;
            i += 4;
        } else if i + 1 < argv.len {
            let v = argv[i + 1];
            if flag == "--world" { o.world.append(v[..min(v.len, 80)]); }
            else if flag == "--saves" { o.saves_dir.append(v[..min(v.len, 400)]); }
            else if flag == "--resources" { o.resources.append(v[..min(v.len, 400)]); }
            else if flag == "--radius" { let n, ok = parse_int(v); if ok { o.radius = clamp(n, 0, 16); } }
            else if flag == "--frames" { let n, ok = parse_int(v); if ok { o.frames = clamp(n, 1, 100000); } }
            else { usage(); exit(2); }
            i += 2;
        } else {
            usage();
            exit(2);
        }
    }
    o
}

// The resources folder of the newest prepared version, because that is the one
// the launcher wrote last. A client that picks its own version comes later.
fn newest_resources(out: u8[..400]&) -> bool {
    let home = platform::data_dir();
    var names: u8[>..] = [];
    guard list_dir(str(home, "/resources"), names) else { return false; }
    var best: u8[..80] = [];
    each_split(names, '\n') { id =>
        if id.len > 0 && id.len <= 80 && file_exists(str(home, "/resources/", id, "/blockstates")) {
            if best.len == 0 || compare(id, best) > 0 {
                best.resize(0);
                best.append(id);
            }
        }
    };
    guard best.len > 0 else { return false; }
    let path = str(home, "/resources/", best);
    guard path.len <= 400 else { return false; }
    out.append(path);
    true
}

struct Loaded { chunks: i64, faces: i64, floats: i64, top: i64 }

// Loads every chunk within radius of the start, meshes it and leaves the
// vertices in one buffer: a few hundred thousand faces still upload in one go,
// and splitting per chunk only pays once chunks come and go.
fn load_world(save: const saves::Save&, resources: const u8[:], cx0: i64, cz0: i64, radius: i64,
              slots: atlas::Slot[>..]&, tiles: u8[>..]&, verts: f32[>..]&) -> Loaded {
    var out = Loaded { chunks: 0, faces: 0, floats: 0, top: -2048 };
    var known: mesh::Known[>..] = [];
    var pending: mesh::Cell[>..] = [];
    var pieces: mesh::Piece[>..] = [];
    // Meshing needs the atlas grid, which is only final once every chunk has
    // been baked, so the cells are kept and the faces written in a second pass.
    var file: u8[>..] = [];
    var last_rx = 1 << 40;
    var last_rz = 1 << 40;
    for dz in 2 * radius + 1 {
        for dx in 2 * radius + 1 {
            let cx = cx0 + dx - radius;
            let cz = cz0 + dz - radius;
            let rx, rz = region::region_of(cx, cz);
            if rx != last_rx || rz != last_rz {
                file.resize(0);
                if !read_file(region::path_of(save.region_dir, rx, rz), file) { file.resize(0); }
                last_rx = rx;
                last_rz = rz;
            }
            if file.len == 0 || !region::exists(file, cx, cz) { continue; }
            var raw: u8[>..] = [];
            if !region::chunk(file, cx, cz, raw) { continue; }
            var tags: nbt::Node[>..] = [];
            if !nbt::read(raw, tags) { continue; }
            var layers: chunk::Layer[>..] = [];
            var blocks: u16[>..] = [];
            let info = chunk::read(raw, tags, layers, blocks);
            if !info.ok { continue; }
            let vol = mesh::bake(raw, tags, layers, blocks, resources, slots, tiles, known, pending);
            if vol.layers == 0 { continue; }
            pieces.push(mesh::Piece { cx: cx, cz: cz, vol: vol });
            out.chunks++;
            out.top = max(out.top, (vol.y0 + vol.layers) * chunk::EDGE);
        }
    }
    guard out.chunks > 0 else { return out; }
    var image: u8[>..] = [];
    let grid = atlas::flatten(tiles, image);
    for i in pieces.len {
        out.faces += mesh::build(pending, pieces, i, grid, verts);
    }
    out.floats = verts.len;
    out
}

let vertex_shader = """
    layout(location = 0) in vec3 a_pos;
    layout(location = 1) in vec2 a_uv;
    layout(location = 2) in float a_shade;
    layout(set = 1, binding = 0) uniform Camera { mat4 view_proj; vec4 eye; };
    layout(location = 0) out vec2 v_uv;
    layout(location = 1) out float v_shade;
    layout(location = 2) out float v_distance;
    void main() {
        v_uv = a_uv;
        v_shade = a_shade;
        v_distance = length(a_pos - eye.xyz);
        gl_Position = view_proj * vec4(a_pos, 1.0);
    }
    """;

let fragment_shader = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 1) in float v_shade;
    layout(location = 2) in float v_distance;
    layout(set = 2, binding = 0) uniform sampler2D atlas;
    layout(location = 0) out vec4 result;
    void main() {
        vec4 texel = texture(atlas, v_uv);
        if (texel.a < 0.5) discard;
        vec3 color = texel.rgb * v_shade;
        // The far edge of the loaded chunks fades into the sky instead of
        // ending in mid-air.
        float fog = smoothstep(0.55, 1.0, v_distance / 260.0);
        result = vec4(mix(color, vec3(0.62, 0.72, 0.85), fog), 1.0);
    }
    """;

struct Uniforms { view_proj: gfx::mat4, eye: float4 }

fn main() {
    let o = read_options();
    if o.version {
        var label: u8[>..] = [];
        specimen::format_label(label, specimen::current(), platform::name());
        write_stdout(label);
        return;
    }

    if o.check {
        var text: u8[>..] = [];
        diagnose::report(text);
        write_stdout(text);
        return;
    }
    var saves_dir: u8[..400] = [];
    if o.saves_dir.len > 0 { saves_dir.append(o.saves_dir); } else { saves_dir.append(platform::minecraft_dir()[..min(platform::minecraft_dir().len, 400)]); }
    var all: saves::Save[>..] = [];
    saves::scan(saves_dir, all);
    if o.list {
        if all.len == 0 { print("no worlds in ", saves_dir, "/saves"); }
        for s in all { print(s.folder, "  \"", s.name, "\"  data version ", s.version); }
        return;
    }
    guard all.len > 0 else {
        write_stderr(str("no worlds in ", saves_dir, "/saves\n"));
        exit(1);
    }
    var pick = 0;
    if o.world.len > 0 {
        pick = saves::find(all, o.world);
        guard pick >= 0 else {
            write_stderr(str("no world called ", o.world, "\n"));
            exit(1);
        }
    }
    let save = all[pick];

    var resources: u8[..400] = [];
    if o.resources.len > 0 {
        resources.append(o.resources);
    } else if !newest_resources(resources) {
        write_stderr("no prepared resources found: run the launcher's Prepare first, or pass --resources\n");
        exit(1);
    }

    var cam = camera::at(o.at_x, o.at_y, o.at_z, 135.0, -25.0);
    let cx0 = div_euclid(cam.pos.x as i64, chunk::EDGE);
    let cz0 = div_euclid(cam.pos.z as i64, chunk::EDGE);

    var slots: atlas::Slot[>..] = [];
    var tiles: u8[>..] = [];
    var verts: f32[>..] = [];
    let loaded = load_world(save, resources, cx0, cz0, o.radius, slots, tiles, verts);
    print("world \"", save.name, "\": ", loaded.chunks, " chunks, ", loaded.faces, " faces, ",
          slots.len, " textures");
    guard loaded.chunks > 0 && loaded.faces > 0 else {
        write_stderr("nothing to draw there: try --at or --radius\n");
        exit(1);
    }
    if !o.placed {
        // Start above the highest block that was loaded, looking down at it.
        cam.pos.y = (loaded.top + 6) as f32;
        cam.pos.x = (cx0 * chunk::EDGE - 12) as f32;
        cam.pos.z = (cz0 * chunk::EDGE - 12) as f32;
    }

    var image: u8[>..] = [];
    let grid = atlas::flatten(tiles, image);
    guard gfx::open("zoo", 1280, 800, gfx::WINDOW_RESIZABLE) else {
        fatal::stop(str("The window could not be opened.\n", gfx::error()));
    }
    let texture = gfx::texture2d(grid.width, grid.height);
    gfx::update_texture(texture, image);
    let sampler = gfx::sampler(gfx::NEAREST, gfx::CLAMP);
    let pipe = gfx::pipeline(embed_shader("vert", vertex_shader), embed_shader("frag", fragment_shader),
                             gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true });
    let buffer = gfx::vertex_buffer(bytes_of(verts));
    if pipe.id == 0 || buffer.id == 0 || texture.id == 0 {
        fatal::stop(str("The renderer could not be set up.\n", gfx::error()));
    }
    let vertices = loaded.floats / 6;
    var grabbed = false;
    var drawn = 0;
    while gfx::frame() {
        if gfx::key_pressed("Escape") {
            if grabbed { grabbed = false; gfx::set_mouse_relative(false); } else { break; }
        }
        if gfx::mouse_down(gfx::MOUSE_LEFT) && !grabbed {
            grabbed = true;
            gfx::set_mouse_relative(true);
        }
        if grabbed {
            let d = gfx::mouse_delta();
            camera::turn(cam, d.x, d.y);
        }
        if gfx::focused() { camera::walk(cam, delta_time_f32()); }
        let screen = gfx::screen_size();
        gfx::begin_screen(float4 { x: 0.62, y: 0.72, z: 0.85, w: 1.0 });
        gfx::bind(pipe);
        gfx::bind_vertex_buffer(buffer);
        gfx::bind_texture(gfx::FRAGMENT, 0, texture, sampler);
        gfx::uniforms(gfx::VERTEX, 0, Uniforms {
            view_proj: camera::view_proj(cam, screen.x, screen.y),
            eye: float4 { x: cam.pos.x, y: cam.pos.y, z: cam.pos.z, w: 0.0 },
        });
        gfx::draw(vertices);
        gfx::end_pass();
        drawn++;
        if o.frames > 0 && drawn >= o.frames {
            gfx::screenshot("zoo-client.png");
            break;
        }
    }
    gfx::close();
}

fn delta_time_f32() -> f32 { clamp(gfx::delta_time(), 0.0, 0.1) as! f32 }
