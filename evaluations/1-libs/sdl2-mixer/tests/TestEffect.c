#include <SDL.h>
#include <SDL_mixer.h>
#include <stdio.h>

static volatile int effect_calls;
static volatile int done_calls;

static void effect_callback(int channel, void *stream, int len, void *opaque) {
    unsigned char *bytes = stream;
    effect_calls++;
    if (channel == MIX_CHANNEL_POST && len > 0 && *(int *)opaque == 0x53444c)
        bytes[0] ^= 1;
}

static void effect_done(int channel, void *opaque) {
    int *cookie = opaque;
    if (channel == MIX_CHANNEL_POST && *cookie == 0x53444c)
        done_calls++;
}

int main(void) {
    static unsigned char samples[44100 / 10 * 2];
    int cookie = 0x53444c;
    if (SDL_Init(SDL_INIT_AUDIO) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 2;
    }
    if (Mix_OpenAudio(44100, AUDIO_S16SYS, 1, 512) != 0) {
        fprintf(stderr, "Mix_OpenAudio failed: %s\n", Mix_GetError());
        SDL_Quit();
        return 3;
    }
    Mix_AllocateChannels(1);
    Mix_Chunk *chunk = Mix_QuickLoad_RAW(samples, (Uint32)sizeof(samples));
    if (chunk == NULL || !Mix_RegisterEffect(MIX_CHANNEL_POST, effect_callback, effect_done, &cookie)) {
        fprintf(stderr, "effect setup failed: %s\n", Mix_GetError());
        Mix_CloseAudio();
        SDL_Quit();
        return 4;
    }
    if (Mix_PlayChannelTimed(0, chunk, 0, -1) != 0) {
        fprintf(stderr, "Mix_PlayChannelTimed failed: %s\n", Mix_GetError());
        return 5;
    }
    SDL_Delay(1000);
    fprintf(stderr, "audio-driver:%s status:%d\n", SDL_GetCurrentAudioDriver(), SDL_GetAudioStatus());
    Mix_HaltChannel(0);
    Mix_UnregisterEffect(MIX_CHANNEL_POST, effect_callback);
    Mix_FreeChunk(chunk);
    Mix_CloseAudio();
    SDL_Quit();
    printf("effect-calls:%d done-calls:%d\n", effect_calls, done_calls);
    return effect_calls > 0 && done_calls == 1 ? 0 : 6;
}
