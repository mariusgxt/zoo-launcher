/* Linux and macOS have no dialog that is always there, and a launcher started
   from a terminal reports there anyway, so the message stays on stderr. */
#include "zoo_native.h"

int32_t zoo_message_box(zoo_bytes title, zoo_bytes text) {
    (void)title;
    (void)text;
    return 0;
}
