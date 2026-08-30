#define LORE_THUNK_CALLBACK_REPLACE

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestGuest.cpp.inc>
#include <lorelei/Modules/GuestRT/GuestClient.h>

namespace lore::thunk {

template <>
struct ProcFn<::vkGetInstanceProcAddr, GuestToHost, Adapt> {
    static PFN_vkVoidFunction invoke(VkInstance instance, const char *name) {
        PFN_vkVoidFunction result =
            ProcFn<::vkGetInstanceProcAddr, GuestToHost, Caller>::invoke(instance, name);
        return reinterpret_cast<PFN_vkVoidFunction>(
            mod::GuestClient::convertHostProcAddress(name, reinterpret_cast<void *>(result)));
    }
};

template <>
struct ProcFn<::vkGetDeviceProcAddr, GuestToHost, Adapt> {
    static PFN_vkVoidFunction invoke(VkDevice device, const char *name) {
        PFN_vkVoidFunction result =
            ProcFn<::vkGetDeviceProcAddr, GuestToHost, Caller>::invoke(device, name);
        return reinterpret_cast<PFN_vkVoidFunction>(
            mod::GuestClient::convertHostProcAddress(name, reinterpret_cast<void *>(result)));
    }
};

}
