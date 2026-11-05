/* HTTPS on Linux and macOS through libcurl. Goose has no networking in its
   standard library, and libcurl is on every desktop Unix already, so this
   file stays a thin adapter and owns no TLS of its own. */
#include "zoo_native.h"
#include <curl/curl.h>
#include <stdlib.h>
#include <string.h>

static size_t zoo_curl_sink(char *data, size_t size, size_t n, void *user) {
    gs_bld_append(*(gs_rref *)user, data, size * n);
    return size * n;
}

static int zoo_curl_ready = 0;

int32_t zoo_http_get(zoo_bytes url, gs_rref out, gs_rref err) {
    if (!zoo_curl_ready) {
        curl_global_init(CURL_GLOBAL_DEFAULT);
        zoo_curl_ready = 1;
    }
    char *u = (char *)malloc((size_t)url.len + 1);
    if (!u) return -1;
    memcpy(u, url.data, (size_t)url.len);
    u[url.len] = 0;
    CURL *c = curl_easy_init();
    if (!c) { free(u); return -1; }
    char msg[CURL_ERROR_SIZE] = {0};
    curl_easy_setopt(c, CURLOPT_URL, u);
    curl_easy_setopt(c, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(c, CURLOPT_USERAGENT, "zoo-launcher");
    curl_easy_setopt(c, CURLOPT_WRITEFUNCTION, zoo_curl_sink);
    curl_easy_setopt(c, CURLOPT_WRITEDATA, &out);
    curl_easy_setopt(c, CURLOPT_ERRORBUFFER, msg);
    curl_easy_setopt(c, CURLOPT_CONNECTTIMEOUT, 20L);
    CURLcode rc = curl_easy_perform(c);
    long status = -1;
    if (rc == CURLE_OK) {
        curl_easy_getinfo(c, CURLINFO_RESPONSE_CODE, &status);
    } else {
        const char *m = msg[0] ? msg : curl_easy_strerror(rc);
        gs_bld_append(err, m, strlen(m));
    }
    curl_easy_cleanup(c);
    free(u);
    return (int32_t)status;
}
