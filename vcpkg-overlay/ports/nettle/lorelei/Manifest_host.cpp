#define LORE_THUNK_CALLBACK_REPLACE
#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestHost.cpp.inc>

namespace lore::thunk {

/// Avoid treating the uninitialized output object as an input callback aggregate.
template <>
struct ProcFn<::nettle_buffer_init, GuestToHost, Adapt> {
    static void invoke(nettle_buffer *buffer) {
        ProcFn<::nettle_buffer_init, GuestToHost, Caller>::invoke(buffer);
    }
};

}
