// The one door to the network. The platform C behind it (native/) is
// picked by the .build sidecar, so nothing above this file knows whether
// WinHTTP or libcurl did the work.
import std;
namespace http;

extern fn zoo_http_get(url: const u8[:], out: u8[>..]&, err: u8[>..]&) -> i32;

struct Response { status: i32, error: u8[..160] }

fn ok(r: const Response&) -> bool { r.status >= 200 && r.status < 300 }

// Appends the body to out; on failure out may hold a partial body.
fn get(url: const u8[:], out: u8[>..]&) -> Response {
    var err: u8[>..] = [];
    let status = zoo_http_get(url, out, err);
    var r = Response { status: status, error: [] };
    r.error.append(err[..min(err.len, 160)]);
    if status >= 0 && (status < 200 || status >= 300) {
        r.error.resize(0);
        format(r.error, "HTTP ", status, " for ", url[..min(url.len, 120)]);
    }
    r
}
