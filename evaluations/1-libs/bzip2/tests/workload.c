#include <bzlib.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  char input[] = "lorelei-bzip2-roundtrip";
  char compressed[256], output[256];
  unsigned int cs = sizeof(compressed), os = sizeof(output);
  if (BZ2_bzBuffToBuffCompress(compressed, &cs, input, sizeof(input), 9, 0, 30) != BZ_OK) return 1;
  if (BZ2_bzBuffToBuffDecompress(output, &os, compressed, cs, 0, 0) != BZ_OK) return 2;
  if (os != sizeof(input) || memcmp(input, output, os)) return 3;
  puts("roundtrip=pass");
  return 0;
}
