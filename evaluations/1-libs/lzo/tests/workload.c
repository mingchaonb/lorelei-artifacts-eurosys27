#include <lzo/lzo1x.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
int main(void) {
  const unsigned char input[] = "lorelei-lzo-roundtrip";
  unsigned char compressed[4096], output[4096];
  lzo_uint cs = 0, os = sizeof(output);
  void *work = malloc(LZO1X_1_MEM_COMPRESS);
  if (!work || lzo_init() != LZO_E_OK) return 1;
  if (lzo1x_1_compress(input, sizeof(input), compressed, &cs, work) != LZO_E_OK) return 2;
  if (lzo1x_decompress_safe(compressed, cs, output, &os, NULL) != LZO_E_OK) return 3;
  free(work);
  if (os != sizeof(input) || memcmp(input, output, os)) return 4;
  puts("roundtrip=pass");
  return 0;
}
