#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <fcntl.h>
#include <lorelei/ThunkInterface/ManifestHost.cpp.inc>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

namespace lore::thunk {

static void logPresentationTimestamp() {
    static int fd = -2;
    struct timespec now;
    char line[64];
    const char *path;
    int length;

    if (fd == -2) {
        path = getenv("LORELEI_FPS_LOG");
        fd = path && path[0] ? open(path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644) : -1;
    }
    if (fd < 0 || clock_gettime(CLOCK_MONOTONIC, &now) != 0)
        return;
    length = snprintf(line, sizeof(line), "%lld.%09ld\n",
                      (long long) now.tv_sec, now.tv_nsec);
    if (length > 0)
        (void) write(fd, line, (size_t) length);
}

template <>
struct ProcFn<::glXSwapBuffers, GuestToHost, Adapt> {
    static void invoke(Display *display, GLXDrawable drawable) {
        ProcFn<::glXSwapBuffers, GuestToHost, Caller>::invoke(display, drawable);
        logPresentationTimestamp();
    }
};

}
