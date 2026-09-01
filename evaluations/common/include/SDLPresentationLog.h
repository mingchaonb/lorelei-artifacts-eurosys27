#pragma once

extern "C" void lorelei_log_frame_presented(void) __attribute__((weak));

namespace lore::thunk {

template <>
struct ProcFn<::SDL_GL_SwapWindow, GuestToHost, Adapt> {
    static void invoke(SDL_Window *window) {
        ProcFn<::SDL_GL_SwapWindow, GuestToHost, Caller>::invoke(window);
        if (lorelei_log_frame_presented)
            lorelei_log_frame_presented();
    }
};

template <>
struct ProcFn<::SDL_RenderPresent, GuestToHost, Adapt> {
    static void invoke(SDL_Renderer *renderer) {
        ProcFn<::SDL_RenderPresent, GuestToHost, Caller>::invoke(renderer);
        if (lorelei_log_frame_presented)
            lorelei_log_frame_presented();
    }
};

}
