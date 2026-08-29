#define _GNU_SOURCE

#include <dlfcn.h>
#include <langinfo.h>

typedef char *(*NlLanginfoFunction)(nl_item);

char *nl_langinfo(nl_item item) {
    if (item == CODESET) {
        return "UTF-8";
    }
    static NlLanginfoFunction next;
    if (!next) {
        next = (NlLanginfoFunction)dlsym(RTLD_NEXT, "nl_langinfo");
    }
    return next(item);
}
