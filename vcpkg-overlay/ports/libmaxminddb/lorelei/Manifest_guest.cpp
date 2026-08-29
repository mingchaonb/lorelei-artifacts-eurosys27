#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestGuest.cpp.inc>

namespace lore::thunk {

template <>
struct ProcFn<::MMDB_dump_entry_data_list, GuestToHost, Entry> {
    static int invoke(FILE *stream, MMDB_entry_data_list_s *list, int indent) {
        if (indent < 0) {
            return MMDB_SUCCESS;
        }
        return ProcFn<::MMDB_dump_entry_data_list, GuestToHost, Adapt>::invoke(stream, list, indent);
    }
};

template <>
struct ProcFn<::MMDB_vget_value, GuestToHost, Entry> {
    static int invoke(MMDB_entry_s *start, MMDB_entry_data_s *entry_data, va_list va_path) {
        const char *path[LORE_THUNK_VARG_MAX] = {};
        va_list copy;
        va_copy(copy, va_path);
        size_t count = 0;
        while (count + 1 < LORE_THUNK_VARG_MAX) {
            path[count] = va_arg(copy, const char *);
            if (path[count++] == nullptr) {
                break;
            }
        }
        va_end(copy);
        path[LORE_THUNK_VARG_MAX - 1] = nullptr;
        return ProcFn<::MMDB_aget_value, GuestToHost, Adapt>::invoke(start, entry_data, path);
    }
};

}
