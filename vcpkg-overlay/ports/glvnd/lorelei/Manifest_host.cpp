#define LORE_THUNK_AUTO_LINK

#include "Desc.h"
#include <dlfcn.h>
#include <lorelei/ThunkInterface/ManifestHost.cpp.inc>

extern "C" {

GLboolean glBufferRegionEnabled(void) {
    static auto function = reinterpret_cast<decltype(&glBufferRegionEnabled)>(
        glXGetProcAddressARB(reinterpret_cast<const GLubyte *>("glBufferRegionEnabled")));
    return function();
}

GLuint glNewBufferRegion(GLenum region) {
    static auto function = reinterpret_cast<decltype(&glNewBufferRegion)>(
        glXGetProcAddressARB(reinterpret_cast<const GLubyte *>("glNewBufferRegion")));
    return function(region);
}

void glDeleteBufferRegion(GLuint region) {
    static auto function = reinterpret_cast<decltype(&glDeleteBufferRegion)>(
        glXGetProcAddressARB(reinterpret_cast<const GLubyte *>("glDeleteBufferRegion")));
    function(region);
}

void glReadBufferRegion(GLuint region, GLint x, GLint y, GLsizei width, GLsizei height) {
    static auto function = reinterpret_cast<decltype(&glReadBufferRegion)>(
        glXGetProcAddressARB(reinterpret_cast<const GLubyte *>("glReadBufferRegion")));
    function(region, x, y, width, height);
}

void glDrawBufferRegion(GLuint region, GLint x, GLint y, GLsizei width, GLsizei height,
                        GLint xDest, GLint yDest) {
    static auto function = reinterpret_cast<decltype(&glDrawBufferRegion)>(
        glXGetProcAddressARB(reinterpret_cast<const GLubyte *>("glDrawBufferRegion")));
    function(region, x, y, width, height, xDest, yDest);
}

void glNamedFramebufferTextureMultiviewOVR(GLuint framebuffer, GLenum attachment, GLuint texture,
                                           GLint level, GLint baseViewIndex, GLsizei numViews) {
    static auto function = reinterpret_cast<decltype(&glNamedFramebufferTextureMultiviewOVR)>(
        glXGetProcAddressARB(
            reinterpret_cast<const GLubyte *>("glNamedFramebufferTextureMultiviewOVR")));
    function(framebuffer, attachment, texture, level, baseViewIndex, numViews);
}

void glBufferPageCommitmentMemNV(GLenum target, GLintptr offset, GLsizeiptr size, GLuint memory,
                                 GLuint64 memOffset, GLboolean commit) {
    static auto function = reinterpret_cast<decltype(&glBufferPageCommitmentMemNV)>(
        glXGetProcAddressARB(reinterpret_cast<const GLubyte *>("glBufferPageCommitmentMemNV")));
    function(target, offset, size, memory, memOffset, commit);
}

void glNamedBufferPageCommitmentMemNV(GLuint buffer, GLintptr offset, GLsizeiptr size,
                                      GLuint memory, GLuint64 memOffset, GLboolean commit) {
    static auto function = reinterpret_cast<decltype(&glNamedBufferPageCommitmentMemNV)>(
        glXGetProcAddressARB(
            reinterpret_cast<const GLubyte *>("glNamedBufferPageCommitmentMemNV")));
    function(buffer, offset, size, memory, memOffset, commit);
}

void glTexPageCommitmentMemNV(GLenum target, GLint layer, GLint level, GLint xoffset,
                              GLint yoffset, GLint zoffset, GLsizei width, GLsizei height,
                              GLsizei depth, GLuint memory, GLuint64 offset, GLboolean commit) {
    static auto function = reinterpret_cast<decltype(&glTexPageCommitmentMemNV)>(
        glXGetProcAddressARB(reinterpret_cast<const GLubyte *>("glTexPageCommitmentMemNV")));
    function(target, layer, level, xoffset, yoffset, zoffset, width, height, depth, memory, offset,
             commit);
}

void glTexturePageCommitmentMemNV(GLuint texture, GLint layer, GLint level, GLint xoffset,
                                  GLint yoffset, GLint zoffset, GLsizei width, GLsizei height,
                                  GLsizei depth, GLuint memory, GLuint64 offset, GLboolean commit) {
    static auto function = reinterpret_cast<decltype(&glTexturePageCommitmentMemNV)>(
        glXGetProcAddressARB(
            reinterpret_cast<const GLubyte *>("glTexturePageCommitmentMemNV")));
    function(texture, layer, level, xoffset, yoffset, zoffset, width, height, depth, memory, offset,
             commit);
}

}

namespace lore::thunk {

template <>
struct ProcFn<::glXCreateContextAttribsARB, GuestToHost, Adapt> {
    static GLXContext invoke(Display *display, GLXFBConfig config, GLXContext share_context,
                             Bool direct, const int *attributes) {
        // GLX proc addresses are vendor-dispatched. Calling this entry through
        // GetProcAddress metadata loses the vendor-neutral GLVND dispatch for
        // the extended context attributes used by Unity. Resolve the public
        // libGL entry directly while keeping the pointer arguments on the
        // normal Hecate shared-address path.
        static void *library =
            dlopen("/usr/lib/aarch64-linux-gnu/libGL.so.1", RTLD_NOW | RTLD_LOCAL);
        static auto function = library ? reinterpret_cast<decltype(&glXCreateContextAttribsARB)>(
                                             dlsym(library, "glXCreateContextAttribsARB"))
                                       : nullptr;
        return function ? function(display, config, share_context, direct, attributes) : nullptr;
    }
};

template <>
struct ProcFn<::glDebugMessageCallback, GuestToHost, Adapt> {
    static void invoke(GLDEBUGPROC callback, const void *user) {
        auto host_callback = reinterpret_cast<GLDEBUGPROC>(allocCallbackTrampoline<
            ProcCb<GLDEBUGPROC, HostToGuest, Entry>::invoke>((void *) callback));
        ProcFn<::glDebugMessageCallback, GuestToHost, Caller>::invoke(host_callback, user);
    }
};

template <>
struct ProcFn<::glDebugMessageCallbackARB, GuestToHost, Adapt> {
    static void invoke(GLDEBUGPROCARB callback, const void *user) {
        auto host_callback = reinterpret_cast<GLDEBUGPROCARB>(allocCallbackTrampoline<
            ProcCb<GLDEBUGPROCARB, HostToGuest, Entry>::invoke>((void *) callback));
        ProcFn<::glDebugMessageCallbackARB, GuestToHost, Caller>::invoke(host_callback, user);
    }
};

template <>
struct ProcFn<::glDebugMessageCallbackAMD, GuestToHost, Adapt> {
    static void invoke(GLDEBUGPROCAMD callback, void *user) {
        auto host_callback = reinterpret_cast<GLDEBUGPROCAMD>(allocCallbackTrampoline<
            ProcCb<GLDEBUGPROCAMD, HostToGuest, Entry>::invoke>((void *) callback));
        ProcFn<::glDebugMessageCallbackAMD, GuestToHost, Caller>::invoke(host_callback, user);
    }
};

}
