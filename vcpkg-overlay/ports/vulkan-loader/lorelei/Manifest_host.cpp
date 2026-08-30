#define LORE_THUNK_CALLBACK_REPLACE
#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <lorelei/ThunkInterface/ManifestHost.cpp.inc>
#include <dlfcn.h>

namespace {

VkInstance last_instance = VK_NULL_HANDLE;

}

extern "C" VKAPI_ATTR VkResult VKAPI_CALL vkCreateInstance(
    const VkInstanceCreateInfo *createInfo, const VkAllocationCallbacks *allocator,
    VkInstance *instance) {
    static auto function = reinterpret_cast<PFN_vkCreateInstance>(dlsym(RTLD_NEXT, "vkCreateInstance"));
    VkResult result = function(createInfo, allocator, instance);
    if (result == VK_SUCCESS) {
        last_instance = *instance;
    }
    return result;
}

extern "C" VKAPI_ATTR VkResult VKAPI_CALL vkCreateXlibSurfaceKHR(
    VkInstance instance, const VkXlibSurfaceCreateInfoKHR *createInfo,
    const VkAllocationCallbacks *allocator, VkSurfaceKHR *surface) {
    auto function = reinterpret_cast<PFN_vkCreateXlibSurfaceKHR>(
        vkGetInstanceProcAddr(instance, "vkCreateXlibSurfaceKHR"));
    return function(instance, createInfo, allocator, surface);
}

extern "C" VKAPI_ATTR VkBool32 VKAPI_CALL vkGetPhysicalDeviceXlibPresentationSupportKHR(
    VkPhysicalDevice physicalDevice, uint32_t queueFamilyIndex, Display *display,
    VisualID visualId) {
    auto function = reinterpret_cast<PFN_vkGetPhysicalDeviceXlibPresentationSupportKHR>(
        vkGetInstanceProcAddr(last_instance, "vkGetPhysicalDeviceXlibPresentationSupportKHR"));
    return function(physicalDevice, queueFamilyIndex, display, visualId);
}

#define LORE_VK_PROMOTED_ALIAS(ReturnType, Alias, Core, Parameters, Arguments) \
    extern "C" VKAPI_ATTR ReturnType VKAPI_CALL Alias Parameters { return Core Arguments; }

LORE_VK_PROMOTED_ALIAS(void, vkCmdBeginRenderPass2KHR, vkCmdBeginRenderPass2,
                       (VkCommandBuffer commandBuffer,
                        const VkRenderPassBeginInfo *renderPassBegin,
                        const VkSubpassBeginInfo *subpassBeginInfo),
                       (commandBuffer, renderPassBegin, subpassBeginInfo))
LORE_VK_PROMOTED_ALIAS(void, vkCmdNextSubpass2KHR, vkCmdNextSubpass2,
                       (VkCommandBuffer commandBuffer,
                        const VkSubpassBeginInfo *subpassBeginInfo,
                        const VkSubpassEndInfo *subpassEndInfo),
                       (commandBuffer, subpassBeginInfo, subpassEndInfo))
LORE_VK_PROMOTED_ALIAS(void, vkCmdEndRenderPass2KHR, vkCmdEndRenderPass2,
                       (VkCommandBuffer commandBuffer, const VkSubpassEndInfo *subpassEndInfo),
                       (commandBuffer, subpassEndInfo))
LORE_VK_PROMOTED_ALIAS(VkResult, vkCreateDescriptorUpdateTemplateKHR,
                       vkCreateDescriptorUpdateTemplate,
                       (VkDevice device, const VkDescriptorUpdateTemplateCreateInfo *createInfo,
                        const VkAllocationCallbacks *allocator,
                        VkDescriptorUpdateTemplate *descriptorUpdateTemplate),
                       (device, createInfo, allocator, descriptorUpdateTemplate))
LORE_VK_PROMOTED_ALIAS(void, vkDestroyDescriptorUpdateTemplateKHR,
                       vkDestroyDescriptorUpdateTemplate,
                       (VkDevice device, VkDescriptorUpdateTemplate descriptorUpdateTemplate,
                        const VkAllocationCallbacks *allocator),
                       (device, descriptorUpdateTemplate, allocator))
LORE_VK_PROMOTED_ALIAS(void, vkUpdateDescriptorSetWithTemplateKHR,
                       vkUpdateDescriptorSetWithTemplate,
                       (VkDevice device, VkDescriptorSet descriptorSet,
                        VkDescriptorUpdateTemplate descriptorUpdateTemplate, const void *data),
                       (device, descriptorSet, descriptorUpdateTemplate, data))
LORE_VK_PROMOTED_ALIAS(VkResult, vkCreateRenderPass2KHR, vkCreateRenderPass2,
                       (VkDevice device, const VkRenderPassCreateInfo2 *createInfo,
                        const VkAllocationCallbacks *allocator, VkRenderPass *renderPass),
                       (device, createInfo, allocator, renderPass))
LORE_VK_PROMOTED_ALIAS(void, vkGetBufferMemoryRequirements2KHR,
                       vkGetBufferMemoryRequirements2,
                       (VkDevice device, const VkBufferMemoryRequirementsInfo2 *info,
                        VkMemoryRequirements2 *memoryRequirements),
                       (device, info, memoryRequirements))
LORE_VK_PROMOTED_ALIAS(void, vkGetImageMemoryRequirements2KHR, vkGetImageMemoryRequirements2,
                       (VkDevice device, const VkImageMemoryRequirementsInfo2 *info,
                        VkMemoryRequirements2 *memoryRequirements),
                       (device, info, memoryRequirements))
LORE_VK_PROMOTED_ALIAS(
    void, vkGetImageSparseMemoryRequirements2KHR, vkGetImageSparseMemoryRequirements2,
    (VkDevice device, const VkImageSparseMemoryRequirementsInfo2 *info, uint32_t *count,
     VkSparseImageMemoryRequirements2 *memoryRequirements),
    (device, info, count, memoryRequirements))
LORE_VK_PROMOTED_ALIAS(void, vkGetPhysicalDeviceFeatures2KHR, vkGetPhysicalDeviceFeatures2,
                       (VkPhysicalDevice physicalDevice, VkPhysicalDeviceFeatures2 *features),
                       (physicalDevice, features))
LORE_VK_PROMOTED_ALIAS(
    void, vkGetPhysicalDeviceProperties2KHR, vkGetPhysicalDeviceProperties2,
    (VkPhysicalDevice physicalDevice, VkPhysicalDeviceProperties2 *properties),
    (physicalDevice, properties))
LORE_VK_PROMOTED_ALIAS(
    void, vkGetPhysicalDeviceFormatProperties2KHR, vkGetPhysicalDeviceFormatProperties2,
    (VkPhysicalDevice physicalDevice, VkFormat format, VkFormatProperties2 *properties),
    (physicalDevice, format, properties))
LORE_VK_PROMOTED_ALIAS(
    VkResult, vkGetPhysicalDeviceImageFormatProperties2KHR,
    vkGetPhysicalDeviceImageFormatProperties2,
    (VkPhysicalDevice physicalDevice, const VkPhysicalDeviceImageFormatInfo2 *formatInfo,
     VkImageFormatProperties2 *properties),
    (physicalDevice, formatInfo, properties))
LORE_VK_PROMOTED_ALIAS(
    void, vkGetPhysicalDeviceQueueFamilyProperties2KHR,
    vkGetPhysicalDeviceQueueFamilyProperties2,
    (VkPhysicalDevice physicalDevice, uint32_t *count, VkQueueFamilyProperties2 *properties),
    (physicalDevice, count, properties))
LORE_VK_PROMOTED_ALIAS(
    void, vkGetPhysicalDeviceMemoryProperties2KHR, vkGetPhysicalDeviceMemoryProperties2,
    (VkPhysicalDevice physicalDevice, VkPhysicalDeviceMemoryProperties2 *properties),
    (physicalDevice, properties))
LORE_VK_PROMOTED_ALIAS(
    void, vkGetPhysicalDeviceSparseImageFormatProperties2KHR,
    vkGetPhysicalDeviceSparseImageFormatProperties2,
    (VkPhysicalDevice physicalDevice, const VkPhysicalDeviceSparseImageFormatInfo2 *formatInfo,
     uint32_t *count, VkSparseImageFormatProperties2 *properties),
    (physicalDevice, formatInfo, count, properties))

#undef LORE_VK_PROMOTED_ALIAS
