// SPDX-License-Identifier: MIT

#include <SDL.h>

#include <stdio.h>

int main(void) {
    SDL_free_func freeFunction = NULL;
    SDL_GetMemoryFunctions(NULL, NULL, NULL, &freeFunction);
    if (!freeFunction) {
        fputs("SDL did not return its free function\n", stderr);
        return 1;
    }

    void *allocation = SDL_malloc(64);
    if (!allocation) {
        fputs("SDL_malloc failed\n", stderr);
        return 1;
    }
    freeFunction(allocation);
    puts("SDL FDG function pointer call passed");
    return 0;
}
