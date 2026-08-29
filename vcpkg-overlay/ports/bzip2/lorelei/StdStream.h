#pragma once

#include <cstdio>
#include <lorelei/Modules/GuestRT/GuestClient.h>
#include <lorelei/ThunkInterface/Proc.h>

namespace lore::thunk {
namespace detail {
inline FILE *resolveHostStream(const char *name) {
    void *address = mod::GuestClient::getProcAddress(nullptr, name);
    return address ? *reinterpret_cast<FILE **>(address) : nullptr;
}

inline FILE *toHostStream(FILE *stream) {
    static FILE *hostStdin = resolveHostStream("stdin");
    static FILE *hostStdout = resolveHostStream("stdout");
    static FILE *hostStderr = resolveHostStream("stderr");
    if (stream == stdin) return hostStdin;
    if (stream == stdout) return hostStdout;
    if (stream == stderr) return hostStderr;
    return stream;
}
}

template <>
struct ProcArgFilter<FILE *> {
    using type = FILE *;
    template <class Desc, size_t Index, ProcKind Kind, ProcDirection Direction, class... Args>
    static void filter(FILE *&argument, ProcArgContext<Args...>) {
        argument = detail::toHostStream(argument);
    }
};
}
