#include <SDL.h>
#include <stdio.h>

int main(void) {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "init-error=%s\n", SDL_GetError());
        return 1;
    }

    int displays = SDL_GetNumVideoDisplays();
    printf("driver=%s displays=%d error=%s\n", SDL_GetCurrentVideoDriver(), displays,
           SDL_GetError());
    for (int i = 0; i < displays; ++i) {
        SDL_Rect bounds = {0};
        SDL_DisplayMode mode = {0};
        int modes = SDL_GetNumDisplayModes(i);
        int bounds_status = SDL_GetDisplayBounds(i, &bounds);
        int mode_status = SDL_GetDesktopDisplayMode(i, &mode);
        printf("display=%d name=%s bounds=%d:%d,%d,%dx%d desktop=%d:%dx%d@%d modes=%d\n",
               i, SDL_GetDisplayName(i), bounds_status, bounds.x, bounds.y, bounds.w,
               bounds.h, mode_status, mode.w, mode.h, mode.refresh_rate, modes);
    }
    SDL_Quit();
    return displays > 0 ? 0 : 2;
}
