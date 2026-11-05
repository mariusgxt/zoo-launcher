/* Which system this is, for the paths Minecraft and zoo use there. Goose has
   no compile-time platform constant, and the build already picks one C file
   per platform, so the answer comes from here. */
#include "zoo_native.h"
#include <time.h>

int32_t zoo_platform(void) {
#if defined(__APPLE__)
    return 2;
#else
    return 1;
#endif
}

/* Minutes since local midnight. The launcher shows a wall clock, and Goose's
   os::time is epoch seconds with no zone, so the conversion happens here
   where the C library already knows the machine's zone. */
int32_t zoo_local_minutes(void) {
    time_t now = time(NULL);
    struct tm parts;
#if defined(_WIN32)
    localtime_s(&parts, &now);
#else
    localtime_r(&now, &parts);
#endif
    return (int32_t)(parts.tm_hour * 60 + parts.tm_min);
}

/* X11 and Wayland hand a new window the focus themselves, so there is
   nothing to do here; see the Windows file for why it exists at all. */
void zoo_raise_window(void) {}
