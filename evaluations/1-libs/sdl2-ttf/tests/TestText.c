#include <SDL.h>
#include <SDL_ttf.h>
#include <stdio.h>

int main(int argc, char **argv) {
    int width = 0;
    int height = 0;
    if (argc != 2) {
        fprintf(stderr, "usage: %s FONT\n", argv[0]);
        return 2;
    }
    if (TTF_Init() != 0) {
        fprintf(stderr, "TTF_Init failed: %s\n", TTF_GetError());
        return 3;
    }
    TTF_Font *font = TTF_OpenFont(argv[1], 18);
    if (font == NULL) {
        fprintf(stderr, "TTF_OpenFont failed: %s\n", TTF_GetError());
        TTF_Quit();
        return 4;
    }
    if (TTF_SizeUTF8(font, "Hecate SDL2_ttf", &width, &height) != 0) {
        fprintf(stderr, "TTF_SizeUTF8 failed: %s\n", TTF_GetError());
        TTF_CloseFont(font);
        TTF_Quit();
        return 5;
    }
    printf("text-size:%dx%d\n", width, height);
    TTF_CloseFont(font);
    TTF_Quit();
    return width > 0 && height > 0 ? 0 : 6;
}
