#include <fftw3.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
  fftw_complex *input;
  fftw_complex *output;
  fftw_plan plan;
  int n;
  int repeats;
  int index;

  if (argc != 3) {
    fprintf(stderr, "usage: %s SIZE REPEATS\n", argv[0]);
    return 64;
  }
  n = atoi(argv[1]);
  repeats = atoi(argv[2]);
  if (n <= 0 || repeats <= 0) return 64;
  input = fftw_alloc_complex((size_t)n * n);
  output = fftw_alloc_complex((size_t)n * n);
  if (!input || !output) return 2;
  memset(input, 0, (size_t)n * n * sizeof(*input));
  input[0][0] = 1.0;
  plan = fftw_plan_dft_2d(n, n, input, output, FFTW_FORWARD, FFTW_ESTIMATE);
  if (!plan) return 3;
  for (index = 0; index < repeats; ++index) fftw_execute(plan);
  printf("size=%d repeats=%d checksum=%.17g\n", n, repeats,
         output[0][0] + output[0][1]);
  fftw_destroy_plan(plan);
  fftw_free(output);
  fftw_free(input);
  return 0;
}
