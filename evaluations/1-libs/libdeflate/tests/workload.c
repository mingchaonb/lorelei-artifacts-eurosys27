#include <libdeflate.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  const char input[] = "lorelei-libdeflate-roundtrip";
  unsigned char compressed[256], output[256];
  struct libdeflate_compressor *c = libdeflate_alloc_compressor(6);
  struct libdeflate_decompressor *d = libdeflate_alloc_decompressor();
  if (!c || !d) return 1;
  size_t cs = libdeflate_zlib_compress(c, input, sizeof(input), compressed, sizeof(compressed)), os = 0;
  int rc = libdeflate_zlib_decompress(d, compressed, cs, output, sizeof(output), &os);
  libdeflate_free_compressor(c); libdeflate_free_decompressor(d);
  if (rc || os != sizeof(input) || memcmp(input, output, os)) return 2;
  puts("roundtrip=pass");
  return 0;
}
