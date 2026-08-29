#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestHost.cpp.inc>

namespace lore::thunk {

    template <>
    struct ProcFn<::lore_curl_write_callback_signature, GuestToHost, Adapt> {
        static void invoke(curl_write_callback) {
        }
    };

}
