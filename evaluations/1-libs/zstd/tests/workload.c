#include <zstd.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  const char input[] = "lorelei-zstd-roundtrip";
  unsigned char compressed[256], output[256];
  size_t cs = ZSTD_compress(compressed, sizeof(compressed), input, sizeof(input), 5);
  size_t os = ZSTD_decompress(output, sizeof(output), compressed, cs);
  if (ZSTD_isError(cs) || ZSTD_isError(os) || os != sizeof(input) || memcmp(input, output, os)) return 1;
  puts("roundtrip=pass");
  return 0;
}
