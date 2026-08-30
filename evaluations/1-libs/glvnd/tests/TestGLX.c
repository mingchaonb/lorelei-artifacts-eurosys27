#define GL_GLEXT_PROTOTYPES
#define GLX_GLXEXT_PROTOTYPES

#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glx.h>
#include <GL/glxext.h>
#include <X11/Xlib.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int debug_messages;

static void APIENTRY debug_callback(GLenum source, GLenum type, GLuint id, GLenum severity,
                                    GLsizei length, const GLchar *message,
                                    const void *user_param) {
    const int *cookie = (const int *) user_param;
    if (source == GL_DEBUG_SOURCE_APPLICATION && type == GL_DEBUG_TYPE_MARKER &&
        id == 0x484c52 && cookie && *cookie == 0x58474c && length > 0 && message) {
        debug_messages++;
    }
}

static void fail(const char *message) {
    fprintf(stderr, "glx-fail:%s\n", message);
    exit(1);
}

int main(void) {
    fprintf(stderr, "glx-stage:open-display\n");
    Display *display = XOpenDisplay(NULL);
    if (!display) {
        fail("XOpenDisplay");
    }

    fprintf(stderr, "glx-stage:query-version\n");
    int glx_major = 0;
    int glx_minor = 0;
    if (!glXQueryVersion(display, &glx_major, &glx_minor)) {
        fail("glXQueryVersion");
    }

    fprintf(stderr, "glx-stage:choose-config\n");
    const int attributes[] = {
        GLX_X_RENDERABLE, True,
        GLX_DRAWABLE_TYPE, GLX_PBUFFER_BIT,
        GLX_RENDER_TYPE, GLX_RGBA_BIT,
        GLX_RED_SIZE, 8,
        GLX_GREEN_SIZE, 8,
        GLX_BLUE_SIZE, 8,
        None,
    };
    int config_count = 0;
    GLXFBConfig *configs = glXChooseFBConfig(display, DefaultScreen(display), attributes,
                                             &config_count);
    if (!configs || config_count < 1) {
        fail("glXChooseFBConfig");
    }

    fprintf(stderr, "glx-stage:create-context\n");
    GLXContext context = glXCreateNewContext(display, configs[0], GLX_RGBA_TYPE, NULL, True);
    if (!context) {
        fail("glXCreateNewContext");
    }
    fprintf(stderr, "glx-stage:create-pbuffer\n");
    const int pbuffer_attributes[] = {GLX_PBUFFER_WIDTH, 16, GLX_PBUFFER_HEIGHT, 16, None};
    GLXPbuffer pbuffer = glXCreatePbuffer(display, configs[0], pbuffer_attributes);
    XFree(configs);
    if (!pbuffer || !glXMakeContextCurrent(display, pbuffer, pbuffer, context)) {
        fail("glXMakeContextCurrent");
    }

    fprintf(stderr, "glx-stage:get-string\n");
    const GLubyte *version = glGetString(GL_VERSION);
    const GLubyte *renderer = glGetString(GL_RENDERER);
    if (!version || !renderer) {
        fail("glGetString");
    }

    fprintf(stderr, "glx-stage:get-procs\n");
    PFNGLGENBUFFERSPROC gen_buffers =
        (PFNGLGENBUFFERSPROC) glXGetProcAddressARB((const GLubyte *) "glGenBuffers");
    PFNGLBINDBUFFERPROC bind_buffer =
        (PFNGLBINDBUFFERPROC) glXGetProcAddressARB((const GLubyte *) "glBindBuffer");
    PFNGLBUFFERDATAPROC buffer_data =
        (PFNGLBUFFERDATAPROC) glXGetProcAddressARB((const GLubyte *) "glBufferData");
    PFNGLMAPBUFFERPROC map_buffer =
        (PFNGLMAPBUFFERPROC) glXGetProcAddressARB((const GLubyte *) "glMapBuffer");
    PFNGLUNMAPBUFFERPROC unmap_buffer =
        (PFNGLUNMAPBUFFERPROC) glXGetProcAddressARB((const GLubyte *) "glUnmapBuffer");
    PFNGLDELETEBUFFERSPROC delete_buffers =
        (PFNGLDELETEBUFFERSPROC) glXGetProcAddressARB((const GLubyte *) "glDeleteBuffers");
    if (!gen_buffers || !bind_buffer || !buffer_data || !map_buffer || !unmap_buffer ||
        !delete_buffers) {
        fail("buffer proc address");
    }

    fprintf(stderr, "glx-stage:map-buffer\n");
    GLuint buffer = 0;
    gen_buffers(1, &buffer);
    bind_buffer(GL_ARRAY_BUFFER, buffer);
    buffer_data(GL_ARRAY_BUFFER, 64, NULL, GL_DYNAMIC_DRAW);
    uint8_t *mapped = (uint8_t *) map_buffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    if (!mapped) {
        fail("glMapBuffer");
    }
    for (int i = 0; i < 64; ++i) {
        mapped[i] = (uint8_t) (i ^ 0x5a);
    }
    if (!unmap_buffer(GL_ARRAY_BUFFER)) {
        fail("glUnmapBuffer");
    }
    delete_buffers(1, &buffer);

    fprintf(stderr, "glx-stage:debug-callback\n");
    PFNGLDEBUGMESSAGECALLBACKPROC set_debug_callback =
        (PFNGLDEBUGMESSAGECALLBACKPROC) glXGetProcAddressARB(
            (const GLubyte *) "glDebugMessageCallback");
    PFNGLDEBUGMESSAGEINSERTPROC insert_debug_message =
        (PFNGLDEBUGMESSAGEINSERTPROC) glXGetProcAddressARB(
            (const GLubyte *) "glDebugMessageInsert");
    int callback_cookie = 0x58474c;
    if (set_debug_callback && insert_debug_message) {
        glEnable(GL_DEBUG_OUTPUT);
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
        set_debug_callback(debug_callback, &callback_cookie);
        static const char text[] = "hecate.glx";
        insert_debug_message(GL_DEBUG_SOURCE_APPLICATION, GL_DEBUG_TYPE_MARKER, 0x484c52,
                             GL_DEBUG_SEVERITY_NOTIFICATION, sizeof(text) - 1, text);
        set_debug_callback(NULL, NULL);
        if (debug_messages != 1) {
            fail("debug callback");
        }
    }

    fprintf(stderr, "glx-stage:cleanup\n");
    printf("glx:%d.%d:%s:%s:map=64:debug=%d\n", glx_major, glx_minor, version, renderer,
           debug_messages);
    glXMakeContextCurrent(display, None, None, NULL);
    glXDestroyPbuffer(display, pbuffer);
    glXDestroyContext(display, context);
    XCloseDisplay(display);
    return 0;
}
