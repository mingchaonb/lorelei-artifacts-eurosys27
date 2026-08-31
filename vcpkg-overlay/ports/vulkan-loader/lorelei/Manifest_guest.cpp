#define LORE_THUNK_CALLBACK_REPLACE

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestGuest.cpp.inc>
#include <lorelei/Modules/GuestRT/GuestClient.h>
#include <dlfcn.h>

namespace lore::thunk {

template <>
struct ProcFn<::vkGetInstanceProcAddr, GuestToHost, Adapt> {
    static PFN_vkVoidFunction invoke(VkInstance instance, const char *name) {
        PFN_vkVoidFunction result =
            ProcFn<::vkGetInstanceProcAddr, GuestToHost, Caller>::invoke(instance, name);
        void *converted = dlsym(RTLD_DEFAULT, name);
        if (!converted) {
            converted = mod::GuestClient::convertHostProcAddress(
                name, reinterpret_cast<void *>(result));
        }
        return reinterpret_cast<PFN_vkVoidFunction>(converted);
    }
};

template <>
struct ProcFn<::vkGetDeviceProcAddr, GuestToHost, Adapt> {
    static PFN_vkVoidFunction invoke(VkDevice device, const char *name) {
        PFN_vkVoidFunction result =
            ProcFn<::vkGetDeviceProcAddr, GuestToHost, Caller>::invoke(device, name);
        void *converted = dlsym(RTLD_DEFAULT, name);
        if (!converted) {
            converted = mod::GuestClient::convertHostProcAddress(
                name, reinterpret_cast<void *>(result));
        }
        return reinterpret_cast<PFN_vkVoidFunction>(converted);
    }
};

}
