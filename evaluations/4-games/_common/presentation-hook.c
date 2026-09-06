#define _GNU_SOURCE

#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

typedef void (*sdl_gl_swap_window_fn)(void *window);
typedef void (*sdl_gl_swap_buffers_fn)(void);
typedef void (*sdl_render_present_fn)(void *renderer);
typedef void (*glx_swap_buffers_fn)(void *display, unsigned long drawable);

static sdl_gl_swap_window_fn real_sdl_gl_swap_window;
static sdl_gl_swap_buffers_fn real_sdl_gl_swap_buffers;
static sdl_render_present_fn real_sdl_render_present;
static glx_swap_buffers_fn real_glx_swap_buffers;
static int fps_log_fd = -1;
static int hook_debug;
static __thread unsigned int presentation_depth;

__attribute__((constructor)) static void initialize_presentation_hook(void)
{
    const char *path = getenv("LORELEI_FPS_LOG");
    const char *debug = getenv("LORELEI_HOOK_DEBUG");

    hook_debug = debug && debug[0] == '1';
    if (path && path[0])
        fps_log_fd = open(path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644);
}

__attribute__((destructor)) static void close_presentation_log(void)
{
    if (fps_log_fd >= 0)
        close(fps_log_fd);
}

/* Name the object RTLD_NEXT selected for one presentation entry point.
 *
 * An unresolved entry point is reported unconditionally: the interceptor then
 * drops the call, so the window never presents while the process keeps
 * running. That failure is otherwise invisible. Set LORELEI_HOOK_DEBUG=1 to
 * also report successful resolutions, which identifies the case where a
 * process holds several copies of the entry point and the hook binds to one
 * that does not own the window. */
static void report_resolution(const char *name, void *resolved)
{
    Dl_info info;

    if (!resolved) {
        fprintf(stderr, "lorelei.presentation-hook: %s unresolved, "
                        "presentation dropped\n", name);
        return;
    }
    if (!hook_debug)
        return;
    if (dladdr(resolved, &info) && info.dli_fname)
        fprintf(stderr, "lorelei.presentation-hook: %s -> %s\n",
                name, info.dli_fname);
    else
        fprintf(stderr, "lorelei.presentation-hook: %s -> unknown object\n",
                name);
}

void lorelei_log_frame_presented(void)
{
    struct timespec now;
    char line[64];
    int length;

    if (fps_log_fd < 0 || clock_gettime(CLOCK_MONOTONIC, &now) != 0)
        return;

    length = snprintf(line, sizeof(line), "%lld.%09ld\n",
                      (long long)now.tv_sec, now.tv_nsec);
    if (length > 0) {
        ssize_t written = write(fps_log_fd, line, (size_t)length);
        (void)written;
    }
}

void SDL_GL_SwapWindow(void *window)
{
    if (!real_sdl_gl_swap_window) {
        real_sdl_gl_swap_window =
            (sdl_gl_swap_window_fn)dlsym(RTLD_NEXT, "SDL_GL_SwapWindow");
        report_resolution("SDL_GL_SwapWindow", (void *)real_sdl_gl_swap_window);
    }
    if (!real_sdl_gl_swap_window)
        return;

    ++presentation_depth;
    real_sdl_gl_swap_window(window);
    if (--presentation_depth == 0)
        lorelei_log_frame_presented();
}

void SDL_GL_SwapBuffers(void)
{
    if (!real_sdl_gl_swap_buffers) {
        real_sdl_gl_swap_buffers =
            (sdl_gl_swap_buffers_fn)dlsym(RTLD_NEXT, "SDL_GL_SwapBuffers");
        report_resolution("SDL_GL_SwapBuffers",
                          (void *)real_sdl_gl_swap_buffers);
    }
    if (!real_sdl_gl_swap_buffers)
        return;

    ++presentation_depth;
    real_sdl_gl_swap_buffers();
    if (--presentation_depth == 0)
        lorelei_log_frame_presented();
}

void SDL_RenderPresent(void *renderer)
{
    if (!real_sdl_render_present) {
        real_sdl_render_present =
            (sdl_render_present_fn)dlsym(RTLD_NEXT, "SDL_RenderPresent");
        report_resolution("SDL_RenderPresent", (void *)real_sdl_render_present);
    }
    if (!real_sdl_render_present)
        return;

    ++presentation_depth;
    real_sdl_render_present(renderer);
    if (--presentation_depth == 0)
        lorelei_log_frame_presented();
}

void glXSwapBuffers(void *display, unsigned long drawable)
{
    if (!real_glx_swap_buffers) {
        real_glx_swap_buffers =
            (glx_swap_buffers_fn)dlsym(RTLD_NEXT, "glXSwapBuffers");
        report_resolution("glXSwapBuffers", (void *)real_glx_swap_buffers);
    }
    if (!real_glx_swap_buffers)
        return;

    ++presentation_depth;
    real_glx_swap_buffers(display, drawable);
    if (--presentation_depth == 0)
        lorelei_log_frame_presented();
}
