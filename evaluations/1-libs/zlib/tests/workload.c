#include <zlib.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  const Bytef input[] = "lorelei-zlib-roundtrip";
  Bytef compressed[256], output[256];
  uLongf cs = sizeof(compressed), os = sizeof(output);
  if (compress2(compressed, &cs, input, sizeof(input), 6) != Z_OK) return 1;
  if (uncompress(output, &os, compressed, cs) != Z_OK) return 2;
  if (os != sizeof(input) || memcmp(input, output, os)) return 3;
  printf("roundtrip=pass version=%s\n", zlibVersion());
  return 0;
}
