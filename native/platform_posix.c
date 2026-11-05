/* Which system this is, for the paths Minecraft and zoo use there. Goose has
   no compile-time platform constant, and the build already picks one C file
   per platform, so the answer comes from here. */
#include "zoo_native.h"

int32_t zoo_platform(void) {
#if defined(__APPLE__)
    return 2;
#else
    return 1;
#endif
}
