#include <SDL.h>
#include <stdio.h>

int main(void)
{
    SDL_Window *window;
    SDL_GLContext context;
    int red = -1;
    int green = -1;
    int blue = -1;
    int alpha = -1;
    int depth = -1;
    int stencil = -1;
    int double_buffer = -1;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "init-error=%s\n", SDL_GetError());
        return 1;
    }
    SDL_GL_GetAttribute(SDL_GL_RED_SIZE, &red);
    SDL_GL_GetAttribute(SDL_GL_GREEN_SIZE, &green);
    SDL_GL_GetAttribute(SDL_GL_BLUE_SIZE, &blue);
    SDL_GL_GetAttribute(SDL_GL_ALPHA_SIZE, &alpha);
    SDL_GL_GetAttribute(SDL_GL_DEPTH_SIZE, &depth);
    SDL_GL_GetAttribute(SDL_GL_STENCIL_SIZE, &stencil);
    SDL_GL_GetAttribute(SDL_GL_DOUBLEBUFFER, &double_buffer);
    printf("attributes rgba=%d/%d/%d/%d depth=%d stencil=%d double=%d\n",
           red, green, blue, alpha, depth, stencil, double_buffer);

    window = SDL_CreateWindow("AE SDL OpenGL preflight", SDL_WINDOWPOS_UNDEFINED,
                              SDL_WINDOWPOS_UNDEFINED, 320, 240,
                              SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN);
    if (!window) {
        fprintf(stderr, "window-error=%s\n", SDL_GetError());
        SDL_Quit();
        return 2;
    }
    context = SDL_GL_CreateContext(window);
    if (!context) {
        fprintf(stderr, "context-error=%s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 3;
    }
    printf("driver=%s context=ok\n", SDL_GetCurrentVideoDriver());
    SDL_GL_DeleteContext(context);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
