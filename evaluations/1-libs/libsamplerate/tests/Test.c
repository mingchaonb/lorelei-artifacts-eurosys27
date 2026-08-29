#include <samplerate.h>
#include <stdio.h>

struct Input { float samples[8]; int used; };
static long provide(void *opaque, float **data) {
    struct Input *input = opaque;
    if (input->used) return 0;
    input->used = 1;
    *data = input->samples;
    return 8;
}

int main(void) {
    int error = 0;
    struct Input input = {{0,1,0,-1,0,1,0,-1}, 0};
    float output[16] = {0};
    SRC_STATE *state = src_callback_new(provide, SRC_SINC_FASTEST, 1, &error, &input);
    if (!state) return 2;
    long frames = src_callback_read(state, 2.0, 16, output);
    printf("samplerate:%ld callback:%d error:%d\n", frames, input.used, src_error(state));
    src_delete(state);
    return frames > 0 && input.used == 1 ? 0 : 3;
}
