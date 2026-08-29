#include <lzma.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  const uint8_t input[] = "lorelei-lzma-roundtrip";
  uint8_t compressed[256], output[256];
  size_t out_pos = 0, in_pos = 0, decoded = 0;
  if (lzma_easy_buffer_encode(6, LZMA_CHECK_CRC64, NULL, input, sizeof(input), compressed, &out_pos, sizeof(compressed)) != LZMA_OK) return 1;
  uint64_t limit = UINT64_MAX;
  if (lzma_stream_buffer_decode(&limit, 0, NULL, compressed, &in_pos, out_pos, output, &decoded, sizeof(output)) != LZMA_OK) return 2;
  if (decoded != sizeof(input) || memcmp(input, output, decoded)) return 3;
  puts("roundtrip=pass");
  return 0;
}
