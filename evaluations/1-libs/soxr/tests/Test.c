#include <soxr.h>
#include <math.h>
#include <stdio.h>

int main(void) {
    float input[8] = {0,1,0,-1,0,1,0,-1};
    float output[16] = {0};
    size_t odone = 0;
    soxr_error_t error = soxr_oneshot(8.0, 16.0, 1, input, 8, NULL, output, 16, &odone, NULL, NULL, NULL);
    printf("soxr:%s frames:%zu first:%.6f\n", error ? error : "ok", odone, output[0]);
    return !error && odone > 8 && isfinite(output[0]) ? 0 : 2;
}
