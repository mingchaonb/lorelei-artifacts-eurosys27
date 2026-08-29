#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestGuest.cpp.inc>

#include <dlfcn.h>

#include <lorelei/Modules/GuestRT/GuestClient.h>
#include <lorethunk/ThunkUtils/Guest/libc-shim/StdStream.h>

namespace lore::thunk {

template <>
struct ProcFn<::SDL_LoadObject, GuestToHost, Entry> {
    static void *invoke(const char *sofile) {
        return dlopen(sofile, RTLD_NOW);
    }
};

template <>
struct ProcFn<::SDL_LoadFunction, GuestToHost, Entry> {
    static void *invoke(void *handle, const char *name) {
        return dlsym(handle, name);
    }
};

template <>
struct ProcFn<::SDL_UnloadObject, GuestToHost, Entry> {
    static int invoke(void *handle) {
        return dlclose(handle);
    }
};

template <>
struct ProcFn<::SDL_Vulkan_GetVkGetInstanceProcAddr, GuestToHost, Adapt> {
    static void *invoke() {
        void *result = ProcFn<::SDL_Vulkan_GetVkGetInstanceProcAddr,
                              GuestToHost, Caller>::invoke();
        return mod::GuestClient::convertHostProcAddress("vkGetInstanceProcAddr", result);
    }
};

}
