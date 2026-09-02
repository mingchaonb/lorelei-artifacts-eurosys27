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
static __thread unsigned int presentation_depth;

__attribute__((constructor)) static void initialize_presentation_hook(void)
{
    const char *path = getenv("LORELEI_FPS_LOG");

    if (path && path[0])
        fps_log_fd = open(path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644);
}

__attribute__((destructor)) static void close_presentation_log(void)
{
    if (fps_log_fd >= 0)
        close(fps_log_fd);
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
    if (!real_sdl_gl_swap_window)
        real_sdl_gl_swap_window =
            (sdl_gl_swap_window_fn)dlsym(RTLD_NEXT, "SDL_GL_SwapWindow");
    if (!real_sdl_gl_swap_window)
        return;

    ++presentation_depth;
    real_sdl_gl_swap_window(window);
    if (--presentation_depth == 0)
        lorelei_log_frame_presented();
}

void SDL_GL_SwapBuffers(void)
{
    if (!real_sdl_gl_swap_buffers)
        real_sdl_gl_swap_buffers =
            (sdl_gl_swap_buffers_fn)dlsym(RTLD_NEXT, "SDL_GL_SwapBuffers");
    if (!real_sdl_gl_swap_buffers)
        return;

    ++presentation_depth;
    real_sdl_gl_swap_buffers();
    if (--presentation_depth == 0)
        lorelei_log_frame_presented();
}

void SDL_RenderPresent(void *renderer)
{
    if (!real_sdl_render_present)
        real_sdl_render_present =
            (sdl_render_present_fn)dlsym(RTLD_NEXT, "SDL_RenderPresent");
    if (!real_sdl_render_present)
        return;

    ++presentation_depth;
    real_sdl_render_present(renderer);
    if (--presentation_depth == 0)
        lorelei_log_frame_presented();
}

void glXSwapBuffers(void *display, unsigned long drawable)
{
    if (!real_glx_swap_buffers)
        real_glx_swap_buffers =
            (glx_swap_buffers_fn)dlsym(RTLD_NEXT, "glXSwapBuffers");
    if (!real_glx_swap_buffers)
        return;

    ++presentation_depth;
    real_glx_swap_buffers(display, drawable);
    if (--presentation_depth == 0)
        lorelei_log_frame_presented();
}
