#include <SDL.h>
#include <SDL_image.h>
#include <stdio.h>
#include <string.h>

static int load_fixture(const char *directory, const char *name) {
    char path[4096];
    SDL_Surface *surface;
    if (snprintf(path, sizeof(path), "%s/%s", directory, name) >= (int)sizeof(path)) {
        fprintf(stderr, "fixture path too long: %s\n", name);
        return 1;
    }
    surface = IMG_Load(path);
    if (surface == NULL) {
        fprintf(stderr, "format-load:fail file=%s error=%s\n", name, IMG_GetError());
        return 1;
    }
    printf("format-load:pass file=%s width=%d height=%d\n", name, surface->w, surface->h);
    SDL_FreeSurface(surface);
    return 0;
}

int main(int argc, char **argv) {
    static const unsigned char pnm[] = "P6\n2 1\n255\n\xff\x00\x00\x00\xff\x00";
    static const char *fixtures[] = {
        "sample.bmp",
        "palette.bmp",
        "palette.gif",
        "sample.cur",
        "sample.ico",
        "sample.pcx",
        "sample.pnm",
        "sample.qoi",
        "sample.tga",
        "sample.xcf",
        "sample.xpm",
        "svg.svg",
        "svg-class.svg",
        "svg64.bmp",
    };
    SDL_RWops *rw;
    SDL_Surface *surface;
    size_t index;
    int failures = 0;
    if (argc != 2) {
        fprintf(stderr, "usage: %s UPSTREAM_TEST_DIRECTORY\n", argv[0]);
        return 2;
    }
    rw = SDL_RWFromConstMem(pnm, (int)sizeof(pnm) - 1);
    surface = rw == NULL ? NULL : IMG_LoadTyped_RW(rw, 1, "PNM");
    if (surface == NULL || surface->w != 2 || surface->h != 1) {
        fprintf(stderr, "in-memory-load:fail error=%s\n", IMG_GetError());
        if (surface != NULL)
            SDL_FreeSurface(surface);
        return 3;
    }
    SDL_FreeSurface(surface);
    printf("in-memory-load:pass\n");
    for (index = 0; index < sizeof(fixtures) / sizeof(fixtures[0]); index++)
        failures += load_fixture(argv[1], fixtures[index]);
    if (failures != 0)
        return 4;
    printf("image-load:pass fixtures=%zu\n", sizeof(fixtures) / sizeof(fixtures[0]));
    return 0;
}
