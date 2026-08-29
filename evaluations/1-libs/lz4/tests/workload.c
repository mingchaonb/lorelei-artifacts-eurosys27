#include <lz4.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  const char input[] = "lorelei-lz4-roundtrip";
  char compressed[128], output[128];
  int cs = LZ4_compress_default(input, compressed, sizeof(input), sizeof(compressed));
  int os = LZ4_decompress_safe(compressed, output, cs, sizeof(output));
  if (cs <= 0 || os != sizeof(input) || memcmp(input, output, os)) return 1;
  puts("roundtrip=pass");
  return 0;
}
