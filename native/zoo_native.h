/* Shapes shared by the native parts. A Goose slice crosses an extern fn as
   { data, len } by value; goose.h only covers builders, so the slice is
   spelled out here once instead of in every file. */
#ifndef ZOO_NATIVE_H
#define ZOO_NATIVE_H
#include "goose.h"
#include <stdint.h>

typedef struct { const uint8_t *data; int64_t len; } zoo_bytes;

#endif
