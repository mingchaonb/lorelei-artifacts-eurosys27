#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestGuest.cpp.inc>

namespace lore::thunk {

#define LORE_X11_VARIADIC_ADAPT(F, RET, FIXED)                                                     \
    template <>                                                                                    \
    struct ProcFn<::F, GuestToHost, Adapt> {                                                       \
        static RET invoke(FIXED fixed, CVargEntry *vargs) {                                        \
            return ProcFn<::F, GuestToHost, Caller>::invoke(fixed, vargs);                          \
        }                                                                                          \
    }

LORE_X11_VARIADIC_ADAPT(XCreateIC, XIC, XIM);
LORE_X11_VARIADIC_ADAPT(XCreateOC, XOC, XOM);
LORE_X11_VARIADIC_ADAPT(XGetICValues, char *, XIC);
LORE_X11_VARIADIC_ADAPT(XGetIMValues, char *, XIM);
LORE_X11_VARIADIC_ADAPT(XGetOCValues, char *, XOC);
LORE_X11_VARIADIC_ADAPT(XGetOMValues, char *, XOM);
LORE_X11_VARIADIC_ADAPT(XSetICValues, char *, XIC);
LORE_X11_VARIADIC_ADAPT(XSetIMValues, char *, XIM);
LORE_X11_VARIADIC_ADAPT(XSetOCValues, char *, XOC);
LORE_X11_VARIADIC_ADAPT(XSetOMValues, char *, XOM);
LORE_X11_VARIADIC_ADAPT(XVaCreateNestedList, XVaNestedList, int);

#undef LORE_X11_VARIADIC_ADAPT

}
