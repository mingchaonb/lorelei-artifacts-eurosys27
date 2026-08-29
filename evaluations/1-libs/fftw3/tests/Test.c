#include <fftw3.h>
#include <math.h>
#include <stdio.h>

int main(void) {
    fftw_complex *in = fftw_alloc_complex(8);
    fftw_complex *out = fftw_alloc_complex(8);
    if (!in || !out) return 2;
    for (int i = 0; i < 8; ++i) {
        in[i][0] = i == 1 ? 1.0 : 0.0;
        in[i][1] = 0.0;
    }
    fftw_plan plan = fftw_plan_dft_1d(8, in, out, FFTW_FORWARD, FFTW_ESTIMATE);
    if (!plan) return 3;
    fftw_execute(plan);
    printf("fftw:%.3f,%.3f,%.3f,%.3f\n", out[0][0], out[0][1], out[2][0], out[2][1]);
    int ok = fabs(out[0][0] - 1.0) < 1e-9 && fabs(out[2][1] + 1.0) < 1e-9;
    fftw_destroy_plan(plan);
    fftw_free(out);
    fftw_free(in);
    return ok ? 0 : 4;
}
