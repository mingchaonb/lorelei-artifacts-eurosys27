#pragma once

#include <cstdarg>
#include <cstring>

#include <lorelei/DLCall/Tools/VariadicArgDefs.h>
#include <lorelei/ThunkInterface/Detail/Variadic.h>
#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>

extern "C" {
#define XUTIL_DEFINE_FUNCTIONS
#include <X11/XKBlib.h>
#include <X11/Xatom.h>
#include <X11/Xcms.h>
#include <X11/Xlib.h>
#include <X11/Xlibint.h>
#include <X11/Xlocale.h>
#include <X11/Xregion.h>
#include <X11/Xresource.h>
#include <X11/Xutil.h>
#include <X11/ImUtil.h>
}

#ifdef max
#undef max
#endif

#ifdef min
#undef min
#endif

#ifdef Success
#undef Success
#endif

namespace lore::thunk::x11_detail {

enum class NameValueMode {
    Get,
    Set,
};

template <NameValueMode Mode>
struct NameValueExtractor {
    static bool isUnsignedLong(const char *name) {
        return !std::strcmp(name, XNInputStyle) || !std::strcmp(name, XNClientWindow) ||
               !std::strcmp(name, XNFocusWindow) || !std::strcmp(name, XNFilterEvents) ||
               !std::strcmp(name, XNColormap) || !std::strcmp(name, XNStdColormap) ||
               !std::strcmp(name, XNForeground) || !std::strcmp(name, XNBackground) ||
               !std::strcmp(name, XNBackgroundPixmap) || !std::strcmp(name, XNCursor);
    }

    static bool isInt(const char *name) {
        return !std::strcmp(name, XNLineSpace) ||
               !std::strcmp(name, XNOrientation) ||
               !std::strcmp(name, XNDirectionalDependentDrawing) ||
               !std::strcmp(name, XNContextualDrawing);
    }

    template <class Fixed>
    static void extract(Fixed, va_list arguments, CVargEntry *output) {
        va_list copy;
        va_copy(copy, arguments);
        size_t count = 0;
        while (count + 3 < LORE_THUNK_VARG_MAX) {
            const char *name = va_arg(copy, const char *);
            output[count++] = CVargGet(name);
            if (!name) {
                break;
            }
            if constexpr (Mode == NameValueMode::Get) {
                void *value = va_arg(copy, void *);
                output[count++] = CVargGet(value);
            } else if (isUnsignedLong(name)) {
                unsigned long value = va_arg(copy, unsigned long);
                output[count++] = CVargGet(value);
            } else if (isInt(name)) {
                int value = va_arg(copy, int);
                output[count++] = CVargGet(value);
            } else {
                void *value = va_arg(copy, void *);
                output[count++] = CVargGet(value);
            }
        }
        va_end(copy);
        output[count] = {};
    }
};

using GetNameValues = NameValueExtractor<NameValueMode::Get>;
using SetNameValues = NameValueExtractor<NameValueMode::Set>;

}

namespace lore::thunk {

#define LORE_X11_GET_VALUES(F)                                                                    \
    template <>                                                                                   \
    struct ProcFnDesc<::F> {                                                                      \
        _DESC pass::custom_variadic<x11_detail::GetNameValues, 1, 2> builder_pass = {};           \
    }

#define LORE_X11_SET_VALUES(F)                                                                    \
    template <>                                                                                   \
    struct ProcFnDesc<::F> {                                                                      \
        _DESC pass::custom_variadic<x11_detail::SetNameValues, 1, 2> builder_pass = {};           \
    }

LORE_X11_SET_VALUES(XCreateIC);
LORE_X11_SET_VALUES(XCreateOC);
LORE_X11_GET_VALUES(XGetICValues);
LORE_X11_GET_VALUES(XGetIMValues);
LORE_X11_GET_VALUES(XGetOCValues);
LORE_X11_GET_VALUES(XGetOMValues);
LORE_X11_SET_VALUES(XSetICValues);
LORE_X11_SET_VALUES(XSetIMValues);
LORE_X11_SET_VALUES(XSetOCValues);
LORE_X11_SET_VALUES(XSetOMValues);
LORE_X11_SET_VALUES(XVaCreateNestedList);

#undef LORE_X11_GET_VALUES
#undef LORE_X11_SET_VALUES

}
