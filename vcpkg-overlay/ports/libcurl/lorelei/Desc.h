#pragma once

#include <cstdarg>

#include <lorelei/DLCall/Tools/VariadicArgDefs.h>
#include <lorelei/ThunkInterface/Detail/Variadic.h>
#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>

// The variadic runtime stores enum values in their unsigned integer slot.
// Convert that storage value back to curl's enum return type explicitly.
#undef CVargValue
#define CVargValue(x, V) static_cast<__typeof__(x)>(_CVargValue<__typeof__(x)>(V))

extern "C" {
#include <curl/curl.h>

void lore_curl_write_callback_signature(curl_write_callback callback);
}

namespace lore::thunk::curl_detail {

struct EasySetoptExtractor {
    static void extract(CURL *, CURLoption option, va_list arguments, CVargEntry *output) {
        va_list copy;
        va_copy(copy, arguments);
        if (option >= CURLOPTTYPE_OFF_T) {
            output[0] = CVargGet(va_arg(copy, curl_off_t));
        } else if (option >= CURLOPTTYPE_FUNCTIONPOINT) {
            output[0] = CVargGet(va_arg(copy, void *));
        } else if (option >= CURLOPTTYPE_OBJECTPOINT) {
            output[0] = CVargGet(va_arg(copy, void *));
        } else {
            output[0] = CVargGet(va_arg(copy, long));
        }
        va_end(copy);
        output[1] = {};
    }
};

}

namespace lore::thunk {

template <>
struct ProcFnDesc<::curl_easy_setopt> {
    _DESC pass::custom_variadic<curl_detail::EasySetoptExtractor, 2, 3> builder_pass = {};
};

}
