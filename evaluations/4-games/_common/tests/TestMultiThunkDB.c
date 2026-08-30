#include <GL/gl.h>
#include <GL/glx.h>
#include <vulkan/vulkan.h>

#include <stdio.h>

typedef const GLubyte *(APIENTRYP PFN_GL_GET_STRING)(GLenum name);

int main(void) {
    PFN_GL_GET_STRING gl_proc =
        (PFN_GL_GET_STRING) glXGetProcAddressARB((const GLubyte *) "glGetString");
    PFN_vkEnumerateInstanceVersion vk_proc =
        (PFN_vkEnumerateInstanceVersion) vkGetInstanceProcAddr(
            VK_NULL_HANDLE, "vkEnumerateInstanceVersion");
    if (!gl_proc || !vk_proc || (void *) gl_proc != (void *) glGetString ||
        (void *) vk_proc != (void *) vkEnumerateInstanceVersion) {
        fprintf(stderr, "multi-db-fail:proc-address\n");
        return 1;
    }
    uint32_t version = 0;
    if (vk_proc(&version) != VK_SUCCESS) {
        fprintf(stderr, "multi-db-fail:vulkan-version\n");
        return 1;
    }
    printf("multi-db:gl=1:vulkan=1:%u.%u.%u\n", VK_API_VERSION_MAJOR(version),
           VK_API_VERSION_MINOR(version), VK_API_VERSION_PATCH(version));
    return 0;
}
