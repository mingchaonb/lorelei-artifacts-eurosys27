#define LORE_THUNK_CALLBACK_REPLACE
#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestHost.cpp.inc>
#include <cstdint>

namespace lore::thunk {

template <>
struct ProcFn<::randombytes_set_implementation, GuestToHost, Adapt> {
    static int invoke(const struct randombytes_implementation *implementation) {
        const auto marker = reinterpret_cast<uintptr_t>(implementation == nullptr ? nullptr : implementation->implementation_name);
        if (marker == 1 || marker == 2) {
            implementation = marker == 1 ? &randombytes_internal_implementation : &randombytes_sysrandom_implementation;
        } else if (implementation != nullptr && implementation->implementation_name == nullptr &&
            implementation->random == nullptr && implementation->stir == nullptr &&
            implementation->uniform == nullptr && implementation->buf == nullptr &&
            implementation->close == nullptr) {
            implementation = &randombytes_internal_implementation;
        }
        return ProcFn<::randombytes_set_implementation, GuestToHost, Caller>::invoke(implementation);
    }
};

}
