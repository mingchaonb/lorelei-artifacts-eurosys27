#include <SDL/SDL.h>

#include <math.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static volatile unsigned callback_count;

static void audio_callback(void *userdata, Uint8 *stream, int length) {
    unsigned char silence = *(const unsigned char *)userdata;
    memset(stream, silence, (size_t)length);
    callback_count++;
}

int main(void) {
    SDL_Surface *screen;
    SDL_AudioSpec wanted;
    void *math_handle;
    double (*guest_cos)(double);
    unsigned char silence = 0;

    puts("step=init");
    fflush(stdout);
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    puts("step=video");
    fflush(stdout);
    screen = SDL_SetVideoMode(320, 240, 32, SDL_SWSURFACE);
    if (screen == NULL || screen->w != 320 || screen->h != 240) {
        fprintf(stderr, "SDL_SetVideoMode failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 2;
    }

    puts("step=audio");
    fflush(stdout);
    memset(&wanted, 0, sizeof(wanted));
    wanted.freq = 8000;
    wanted.format = AUDIO_U8;
    wanted.channels = 1;
    wanted.samples = 256;
    wanted.callback = audio_callback;
    wanted.userdata = &silence;
    if (SDL_OpenAudio(&wanted, NULL) != 0) {
        fprintf(stderr, "SDL_OpenAudio failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 3;
    }
    SDL_PauseAudio(0);
    usleep(250000);
    SDL_LockAudio();
    SDL_UnlockAudio();
    SDL_CloseAudio();
    if (callback_count == 0) {
        fprintf(stderr, "SDL audio callback did not execute\n");
        SDL_Quit();
        return 4;
    }

    puts("step=dynamic-load");
    fflush(stdout);
    math_handle = SDL_LoadObject("libm.so.6");
    guest_cos = math_handle == NULL ? NULL : (double (*)(double))SDL_LoadFunction(math_handle, "cos");
    if (guest_cos == NULL || fabs(guest_cos(0.0) - 1.0) > 0.000001) {
        fprintf(stderr, "guest dynamic loading failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 5;
    }
    SDL_UnloadObject(math_handle);

    printf("sdl=%u.%u.%u video=%dx%d callbacks=%u dynamic-load=guest\n",
        SDL_Linked_Version()->major, SDL_Linked_Version()->minor,
        SDL_Linked_Version()->patch, screen->w, screen->h, callback_count);
    SDL_Quit();
    return 0;
}
