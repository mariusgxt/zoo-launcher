// A free camera: position, yaw and pitch, and the matrix a frame needs. Kept
// apart from the renderer because stage 3 replaces its input with a player's
// physics and keeps the same matrix.
import std;
import vec;
import gfx;
namespace camera;

let SPEED: f32 = 14.0;           // blocks a second
let FAST: f32 = 60.0;
let SENSITIVITY: f32 = 0.18;     // degrees a mouse pixel
let PITCH_LIMIT: f32 = 89.0;
let FOV: f32 = 70.0;
let NEAR: f32 = 0.08;
let FAR: f32 = 1024.0;

struct Camera { pos: float3, yaw: f32, pitch: f32 }

fn at(x: f32, y: f32, z: f32, yaw: f32, pitch: f32) -> Camera {
    Camera { pos: float3 { x: x, y: y, z: z }, yaw: yaw, pitch: pitch }
}

fn radians(deg: f32) -> f32 { deg * 3.14159265 / 180.0 }

// Where the camera looks. Yaw turns around the world's up axis and pitch tilts,
// the order Minecraft itself uses, so a saved player rotation drops straight in.
fn forward(c: const Camera&) -> float3 {
    let y = radians(c.yaw);
    let p = radians(c.pitch);
    float3 { x: cos(p) * sin(y), y: sin(p), z: -cos(p) * cos(y) }
}

fn right(c: const Camera&) -> float3 {
    let y = radians(c.yaw);
    float3 { x: cos(y), y: 0.0, z: sin(y) }
}

fn turn(c: Camera&, dx: f32, dy: f32) {
    c.yaw += dx * SENSITIVITY;
    c.pitch = clamp(c.pitch - dy * SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT);
    if c.yaw > 360.0 { c.yaw -= 360.0; }
    if c.yaw < 0.0 { c.yaw += 360.0; }
}

// Walks the camera for one frame. Keys are read here rather than passed in, so
// a caller only decides whether the camera may move at all.
fn walk(c: Camera&, seconds: f32) {
    let f = forward(c);
    let r = right(c);
    var dx: f32 = 0.0;
    var dy: f32 = 0.0;
    var dz: f32 = 0.0;
    if gfx::key_down("W") { dx += f.x; dy += f.y; dz += f.z; }
    if gfx::key_down("S") { dx -= f.x; dy -= f.y; dz -= f.z; }
    if gfx::key_down("D") { dx += r.x; dz += r.z; }
    if gfx::key_down("A") { dx -= r.x; dz -= r.z; }
    if gfx::key_down("Space") { dy += 1.0; }
    if gfx::key_down("Left Shift") { dy -= 1.0; }
    let len = sqrt(dx * dx + dy * dy + dz * dz);
    guard len > 0.0 else { return; }
    let base = if gfx::key_down("Left Ctrl") { FAST } else { SPEED };
    let speed = base * seconds / len;
    c.pos.x += dx * speed;
    c.pos.y += dy * speed;
    c.pos.z += dz * speed;
}

fn view_proj(c: const Camera&, width: i64, height: i64) -> gfx::mat4 {
    let f = forward(c);
    let target = float3 { x: c.pos.x + f.x, y: c.pos.y + f.y, z: c.pos.z + f.z };
    let up = float3 { x: 0.0, y: 1.0, z: 0.0 };
    let aspect = if height > 0 { width as f32 / height as f32 } else { 1.0 };
    gfx::mul(gfx::perspective(radians(FOV), aspect, NEAR, FAR), gfx::look_at(c.pos, target, up))
}
