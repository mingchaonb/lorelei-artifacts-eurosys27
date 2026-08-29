#define LORE_THUNK_CALLBACK_REPLACE
#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestHost.cpp.inc>

namespace lore::thunk {

/// Avoid scanning the uninitialized parser before the host initializer fills it.
template <>
struct ProcFn<::csv_init, GuestToHost, Adapt> {
    static int invoke(csv_parser *parser, unsigned char options) {
        return ProcFn<::csv_init, GuestToHost, Caller>::invoke(parser, options);
    }
};

}
