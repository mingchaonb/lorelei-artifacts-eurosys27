#pragma once

extern "C" {
#if __has_include(<xcb/xcb.h>)
#include <xcb/xcb.h>
#include <xcb/xcbext.h>
#else
#include "xcb.h"
#include "xcbext.h"
#endif
}
