#include <vulkan/vulkan.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct allocation_header {
    void *base;
    size_t size;
};

struct allocation_counters {
    uint64_t allocations;
    uint64_t reallocations;
    uint64_t frees;
    uint64_t internal_allocations;
    uint64_t internal_frees;
};

static void *VKAPI_PTR test_allocate(void *user_data, size_t size, size_t alignment,
                                     VkSystemAllocationScope scope) {
    (void) scope;
    struct allocation_counters *counters = user_data;
    ++counters->allocations;
    if (!size) return NULL;
    if (alignment < sizeof(void *)) alignment = sizeof(void *);
    size_t extra = alignment - 1 + sizeof(struct allocation_header);
    if (size > SIZE_MAX - extra) return NULL;
    void *base = malloc(size + extra);
    if (!base) return NULL;
    uintptr_t address = ((uintptr_t) base + sizeof(struct allocation_header) + alignment - 1) &
                        ~(uintptr_t) (alignment - 1);
    struct allocation_header *header = (struct allocation_header *) address - 1;
    header->base = base;
    header->size = size;
    return (void *) address;
}

static void VKAPI_PTR test_free(void *user_data, void *memory) {
    struct allocation_counters *counters = user_data;
    ++counters->frees;
    if (!memory) return;
    struct allocation_header *header = (struct allocation_header *) memory - 1;
    free(header->base);
}

static void *VKAPI_PTR test_reallocate(void *user_data, void *original, size_t size,
                                       size_t alignment, VkSystemAllocationScope scope) {
    struct allocation_counters *counters = user_data;
    ++counters->reallocations;
    if (!original) return test_allocate(user_data, size, alignment, scope);
    if (!size) {
        test_free(user_data, original);
        return NULL;
    }
    struct allocation_header *old_header = (struct allocation_header *) original - 1;
    size_t old_size = old_header->size;
    void *replacement = test_allocate(user_data, size, alignment, scope);
    if (!replacement) return NULL;
    memcpy(replacement, original, old_size < size ? old_size : size);
    test_free(user_data, original);
    return replacement;
}

static void VKAPI_PTR test_internal_allocate(void *user_data, size_t size,
                                             VkInternalAllocationType type,
                                             VkSystemAllocationScope scope) {
    (void) size;
    (void) type;
    (void) scope;
    struct allocation_counters *counters = user_data;
    ++counters->internal_allocations;
}

static void VKAPI_PTR test_internal_free(void *user_data, size_t size,
                                         VkInternalAllocationType type,
                                         VkSystemAllocationScope scope) {
    (void) size;
    (void) type;
    (void) scope;
    struct allocation_counters *counters = user_data;
    ++counters->internal_frees;
}

static void fail(const char *message, VkResult result) {
    fprintf(stderr, "vulkan-fail:%s:%d\n", message, result);
    exit(1);
}

static uint32_t find_memory_type(const VkPhysicalDeviceMemoryProperties *properties,
                                 uint32_t bits) {
    for (uint32_t i = 0; i < properties->memoryTypeCount; ++i) {
        VkMemoryPropertyFlags flags = properties->memoryTypes[i].propertyFlags;
        if ((bits & (1u << i)) && (flags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) &&
            (flags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) {
            return i;
        }
    }
    return UINT32_MAX;
}

int main(void) {
    struct allocation_counters allocation_counters = {0};
    VkAllocationCallbacks allocator = {
        .pUserData = &allocation_counters,
        .pfnAllocation = test_allocate,
        .pfnReallocation = test_reallocate,
        .pfnFree = test_free,
        .pfnInternalAllocation = test_internal_allocate,
        .pfnInternalFree = test_internal_free,
    };

    fprintf(stderr, "vulkan-stage:loader-proc\n");
    uint32_t loader_version = VK_API_VERSION_1_0;
    PFN_vkEnumerateInstanceVersion enumerate_version =
        (PFN_vkEnumerateInstanceVersion) vkGetInstanceProcAddr(NULL,
                                                               "vkEnumerateInstanceVersion");
    fprintf(stderr, "vulkan-proc:enumerate=%p:direct=%p\n", (void *) enumerate_version,
            (void *) vkEnumerateInstanceVersion);
    if (enumerate_version && enumerate_version(&loader_version) != VK_SUCCESS) {
        fail("vkEnumerateInstanceVersion", VK_ERROR_UNKNOWN);
    }

    fprintf(stderr, "vulkan-stage:create-instance\n");
    VkApplicationInfo application = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "hecate.vulkan",
        .apiVersion = VK_API_VERSION_1_1,
    };
    VkInstanceCreateInfo instance_info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &application,
    };
    VkInstance instance = VK_NULL_HANDLE;
    VkResult result = vkCreateInstance(&instance_info, &allocator, &instance);
    if (result != VK_SUCCESS) fail("vkCreateInstance", result);

    fprintf(stderr, "vulkan-stage:physical-device\n");
    uint32_t physical_count = 0;
    result = vkEnumeratePhysicalDevices(instance, &physical_count, NULL);
    if (result != VK_SUCCESS || physical_count == 0) fail("vkEnumeratePhysicalDevices", result);
    VkPhysicalDevice *physical_devices = calloc(physical_count, sizeof(*physical_devices));
    if (!physical_devices) fail("calloc", VK_ERROR_OUT_OF_HOST_MEMORY);
    result = vkEnumeratePhysicalDevices(instance, &physical_count, physical_devices);
    if (result != VK_SUCCESS) fail("vkEnumeratePhysicalDevices array", result);
    VkPhysicalDevice physical = physical_devices[0];
    free(physical_devices);

    VkPhysicalDeviceProperties properties;
    vkGetPhysicalDeviceProperties(physical, &properties);
    uint32_t queue_count = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physical, &queue_count, NULL);
    VkQueueFamilyProperties *queues = calloc(queue_count, sizeof(*queues));
    if (!queues) fail("queue calloc", VK_ERROR_OUT_OF_HOST_MEMORY);
    vkGetPhysicalDeviceQueueFamilyProperties(physical, &queue_count, queues);
    uint32_t queue_family = UINT32_MAX;
    for (uint32_t i = 0; i < queue_count; ++i) {
        if (queues[i].queueFlags & VK_QUEUE_COMPUTE_BIT) {
            queue_family = i;
            break;
        }
    }
    free(queues);
    if (queue_family == UINT32_MAX) fail("compute queue", VK_ERROR_FEATURE_NOT_PRESENT);

    fprintf(stderr, "vulkan-stage:create-device\n");
    float priority = 1.0f;
    VkDeviceQueueCreateInfo queue_info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = queue_family,
        .queueCount = 1,
        .pQueuePriorities = &priority,
    };
    VkDeviceCreateInfo device_info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_info,
    };
    VkDevice device = VK_NULL_HANDLE;
    result = vkCreateDevice(physical, &device_info, &allocator, &device);
    if (result != VK_SUCCESS) fail("vkCreateDevice", result);

    fprintf(stderr, "vulkan-stage:device-procs\n");
    PFN_vkCreateBuffer create_buffer =
        (PFN_vkCreateBuffer) vkGetDeviceProcAddr(device, "vkCreateBuffer");
    PFN_vkMapMemory map_memory = (PFN_vkMapMemory) vkGetDeviceProcAddr(device, "vkMapMemory");
    if (!create_buffer || !map_memory) fail("vkGetDeviceProcAddr", VK_ERROR_UNKNOWN);

    fprintf(stderr, "vulkan-stage:mapped-memory\n");
    VkBufferCreateInfo buffer_info = {
        .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = 4096,
        .usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
    };
    VkBuffer buffer = VK_NULL_HANDLE;
    result = create_buffer(device, &buffer_info, &allocator, &buffer);
    if (result != VK_SUCCESS) fail("vkCreateBuffer", result);
    VkMemoryRequirements requirements;
    vkGetBufferMemoryRequirements(device, buffer, &requirements);
    VkPhysicalDeviceMemoryProperties memory_properties;
    vkGetPhysicalDeviceMemoryProperties(physical, &memory_properties);
    uint32_t memory_type = find_memory_type(&memory_properties, requirements.memoryTypeBits);
    if (memory_type == UINT32_MAX) fail("memory type", VK_ERROR_FEATURE_NOT_PRESENT);
    VkMemoryAllocateInfo allocation_info = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = requirements.size,
        .memoryTypeIndex = memory_type,
    };
    VkDeviceMemory memory = VK_NULL_HANDLE;
    result = vkAllocateMemory(device, &allocation_info, &allocator, &memory);
    if (result != VK_SUCCESS) fail("vkAllocateMemory", result);
    result = vkBindBufferMemory(device, buffer, memory, 0);
    if (result != VK_SUCCESS) fail("vkBindBufferMemory", result);
    uint8_t *mapped = NULL;
    result = map_memory(device, memory, 0, 4096, 0, (void **) &mapped);
    if (result != VK_SUCCESS || !mapped) fail("vkMapMemory", result);
    for (uint32_t i = 0; i < 4096; ++i) mapped[i] = (uint8_t) (i ^ 0xa5);
    vkUnmapMemory(device, memory);

    fprintf(stderr, "vulkan-stage:cleanup\n");
    vkDeviceWaitIdle(device);
    vkDestroyBuffer(device, buffer, &allocator);
    vkFreeMemory(device, memory, &allocator);
    vkDestroyDevice(device, &allocator);
    vkDestroyInstance(instance, &allocator);
    if (!allocation_counters.allocations || !allocation_counters.frees) {
        fail("allocation callbacks", VK_ERROR_UNKNOWN);
    }
    printf("vulkan:%u.%u.%u:%s:map=4096:proc=2:alloc=%llu:realloc=%llu:free=%llu\n",
           VK_API_VERSION_MAJOR(loader_version),
           VK_API_VERSION_MINOR(loader_version), VK_API_VERSION_PATCH(loader_version),
           properties.deviceName, (unsigned long long) allocation_counters.allocations,
           (unsigned long long) allocation_counters.reallocations,
           (unsigned long long) allocation_counters.frees);
    return 0;
}
