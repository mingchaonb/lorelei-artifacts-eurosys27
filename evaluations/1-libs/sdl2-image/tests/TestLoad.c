#include <SDL.h>
#include <SDL_image.h>
#include <stdio.h>

int main(void) {
    static const unsigned char ppm[] = "P6\n2 1\n255\n\xff\x00\x00\x00\xff\x00";
    SDL_RWops *rw = SDL_RWFromConstMem(ppm, (int)sizeof(ppm) - 1);
    if (rw == NULL) {
        fprintf(stderr, "SDL_RWFromConstMem failed: %s\n", SDL_GetError());
        return 2;
    }
    SDL_Surface *surface = IMG_LoadTyped_RW(rw, 1, "PNM");
    if (surface == NULL) {
        fprintf(stderr, "IMG_LoadTyped_RW failed: %s\n", IMG_GetError());
        return 3;
    }
    SDL_FreeSurface(surface);
    puts("image-load:pass");
    return 0;
}
