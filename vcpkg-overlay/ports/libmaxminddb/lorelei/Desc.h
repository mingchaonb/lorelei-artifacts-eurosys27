#pragma once
#include <cstdarg>
#include <lorelei/DLCall/Tools/VariadicArgDefs.h>
#include <lorelei/ThunkInterface/Detail/Variadic.h>
#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>
extern "C" {
#include <maxminddb.h>
#include "DataPool.h"
}
namespace lore::thunk::maxminddb_detail {
struct PathExtractor {
    static void extract(MMDB_entry_s *, MMDB_entry_data_s *, va_list args, CVargEntry *out) {
        va_list copy;
        va_copy(copy, args);
        size_t count = 0;
        while (count + 1 < LORE_THUNK_VARG_MAX) {
            const char *element = va_arg(copy, const char *);
            out[count++] = CVargGet(element);
            if (!element) break;
        }
        va_end(copy);
        out[count] = {};
    }
};
}
namespace lore::thunk {
template <> struct ProcFnDesc<::MMDB_get_value> {
    _DESC pass::custom_variadic<maxminddb_detail::PathExtractor, 2, 3> builder_pass = {};
};
}
