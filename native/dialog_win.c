/* A fatal start error has to reach someone who double-clicked the exe and has
   no console to read. On Windows that means a message box; see dialog_posix.c
   for the other systems, where a terminal is the normal way in. */
#include "zoo_native.h"
#include <windows.h>

static WCHAR *zoo_wide(zoo_bytes s) {
    int n = MultiByteToWideChar(CP_UTF8, 0, (const char *)s.data, (int)s.len, NULL, 0);
    if (n <= 0) return NULL;
    WCHAR *w = (WCHAR *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, (n + 1) * sizeof(WCHAR));
    if (!w) return NULL;
    MultiByteToWideChar(CP_UTF8, 0, (const char *)s.data, (int)s.len, w, n);
    w[n] = 0;
    return w;
}

int32_t zoo_message_box(zoo_bytes title, zoo_bytes text) {
    WCHAR *wtitle = zoo_wide(title);
    WCHAR *wtext = zoo_wide(text);
    int32_t shown = 0;
    if (wtitle && wtext) {
        MessageBoxW(NULL, wtext, wtitle, MB_OK | MB_ICONERROR | MB_SETFOREGROUND);
        shown = 1;
    }
    if (wtitle) HeapFree(GetProcessHeap(), 0, wtitle);
    if (wtext) HeapFree(GetProcessHeap(), 0, wtext);
    return shown;
}
