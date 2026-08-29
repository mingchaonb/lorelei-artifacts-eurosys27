#include <spng.h>
#include <stdio.h>
int main(void) {
  struct spng_ctx *ctx = spng_ctx_new(SPNG_CTX_ENCODER);
  if (!ctx) return 1;
  struct spng_ihdr h = {1, 1, 8, SPNG_COLOR_TYPE_TRUECOLOR_ALPHA, 0, 0, 0};
  if (spng_set_ihdr(ctx, &h)) return 2;
  spng_ctx_free(ctx);
  puts("context=pass");
  return 0;
}
