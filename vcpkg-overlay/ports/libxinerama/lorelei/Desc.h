#pragma once

extern "C" {
#include <X11/Xlib.h>
#include <X11/extensions/Xinerama.h>
}

#ifdef Success
#undef Success
#endif

#include <lorelei/ThunkInterface/Proc.h>
