#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestGuest.cpp.inc>
#include <lorelei/Modules/GuestRT/GuestClient.h>
#include <cstdio>

namespace lore::thunk {

template <>
struct ProcFn<::vkGetInstanceProcAddr, GuestToHost, Adapt> {
    static PFN_vkVoidFunction invoke(VkInstance instance, const char *name) {
        PFN_vkVoidFunction result =
            ProcFn<::vkGetInstanceProcAddr, GuestToHost, Caller>::invoke(instance, name);
        auto converted = reinterpret_cast<PFN_vkVoidFunction>(
            mod::GuestClient::convertHostProcAddress(name, reinterpret_cast<void *>(result)));
        std::fprintf(stderr, "vulkan-proc:instance:%s:%p:%p\n", name,
                     reinterpret_cast<void *>(result), reinterpret_cast<void *>(converted));
        return converted;
    }
};

template <>
struct ProcFn<::vkGetDeviceProcAddr, GuestToHost, Adapt> {
    static PFN_vkVoidFunction invoke(VkDevice device, const char *name) {
        PFN_vkVoidFunction result =
            ProcFn<::vkGetDeviceProcAddr, GuestToHost, Caller>::invoke(device, name);
        auto converted = reinterpret_cast<PFN_vkVoidFunction>(
            mod::GuestClient::convertHostProcAddress(name, reinterpret_cast<void *>(result)));
        std::fprintf(stderr, "vulkan-proc:device:%s:%p:%p\n", name,
                     reinterpret_cast<void *>(result), reinterpret_cast<void *>(converted));
        return converted;
    }
};

}
