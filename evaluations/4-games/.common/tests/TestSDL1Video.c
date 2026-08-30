#include <SDL.h>
#include <stdio.h>

int main(void) {
    char driver[128] = {0};
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "init-error=%s\n", SDL_GetError());
        return 1;
    }

    const SDL_VideoInfo *info = SDL_GetVideoInfo();
    if (!info) {
        fprintf(stderr, "video-info-error=%s\n", SDL_GetError());
        SDL_Quit();
        return 2;
    }

    printf("driver=%s current=%dx%d bpp=%d window-manager=%d\n",
           SDL_VideoDriverName(driver, sizeof(driver)) ? driver : "unknown",
           info->current_w, info->current_h, info->vfmt ? info->vfmt->BitsPerPixel : 0,
           info->wm_available);
    SDL_Quit();
    return 0;
}
