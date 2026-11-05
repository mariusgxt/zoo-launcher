/* HTTPS on Windows through WinHTTP, which ships with the system and uses
   its certificate store, so the launcher needs no bundled TLS stack there. */
#include "zoo_native.h"
#include <windows.h>
#include <winhttp.h>
#include <stdio.h>
#include <string.h>

static void zoo_win_error(gs_rref err, const char *what) {
    char buf[96];
    int n = snprintf(buf, sizeof buf, "%s failed (error %lu)", what, (unsigned long)GetLastError());
    if (n > 0) gs_bld_append(err, buf, (size_t)n);
}

int32_t zoo_http_get(zoo_bytes url, gs_rref out, gs_rref err) {
    int32_t status = -1;
    int wlen = MultiByteToWideChar(CP_UTF8, 0, (const char *)url.data, (int)url.len, NULL, 0);
    if (wlen <= 0) { zoo_win_error(err, "url conversion"); return -1; }
    WCHAR *wurl = (WCHAR *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, (wlen + 1) * sizeof(WCHAR));
    if (!wurl) return -1;
    MultiByteToWideChar(CP_UTF8, 0, (const char *)url.data, (int)url.len, wurl, wlen);

    URL_COMPONENTS parts;
    ZeroMemory(&parts, sizeof parts);
    parts.dwStructSize = sizeof parts;
    WCHAR host[256], path[2048];
    parts.lpszHostName = host;
    parts.dwHostNameLength = 256;
    parts.lpszUrlPath = path;
    parts.dwUrlPathLength = 2048;
    HINTERNET session = NULL, conn = NULL, req = NULL;
    if (!WinHttpCrackUrl(wurl, 0, 0, &parts)) { zoo_win_error(err, "WinHttpCrackUrl"); goto done; }

    session = WinHttpOpen(L"zoo-launcher", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                          WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!session) { zoo_win_error(err, "WinHttpOpen"); goto done; }
    conn = WinHttpConnect(session, host, parts.nPort, 0);
    if (!conn) { zoo_win_error(err, "WinHttpConnect"); goto done; }
    DWORD flags = parts.nScheme == INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0;
    req = WinHttpOpenRequest(conn, L"GET", path, NULL, WINHTTP_NO_REFERER,
                             WINHTTP_DEFAULT_ACCEPT_TYPES, flags);
    if (!req) { zoo_win_error(err, "WinHttpOpenRequest"); goto done; }
    if (!WinHttpSendRequest(req, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0) ||
        !WinHttpReceiveResponse(req, NULL)) {
        zoo_win_error(err, "request");
        goto done;
    }
    DWORD code = 0, size = sizeof code;
    WinHttpQueryHeaders(req, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        WINHTTP_HEADER_NAME_BY_INDEX, &code, &size, WINHTTP_NO_HEADER_INDEX);
    char chunk[65536];
    for (;;) {
        DWORD got = 0;
        if (!WinHttpReadData(req, chunk, sizeof chunk, &got)) { zoo_win_error(err, "WinHttpReadData"); goto done; }
        if (got == 0) break;
        gs_bld_append(out, chunk, got);
    }
    status = (int32_t)code;
done:
    if (req) WinHttpCloseHandle(req);
    if (conn) WinHttpCloseHandle(conn);
    if (session) WinHttpCloseHandle(session);
    HeapFree(GetProcessHeap(), 0, wurl);
    return status;
}
