#include <brotli/encode.h>
#include <brotli/decode.h>
#include <brotli/shared_dictionary.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  const uint8_t input[] = "lorelei-brotli-roundtrip";
  uint8_t compressed[256], output[256];
  size_t cs = sizeof(compressed), os = sizeof(output);
  if (!BrotliEncoderCompress(5, BROTLI_DEFAULT_WINDOW, BROTLI_MODE_GENERIC, sizeof(input), input, &cs, compressed)) return 1;
  if (BrotliDecoderDecompress(cs, compressed, &os, output) != BROTLI_DECODER_RESULT_SUCCESS) return 2;
  BrotliSharedDictionary *d = BrotliSharedDictionaryCreateInstance(NULL, NULL, NULL);
  if (!d) return 3;
  BrotliSharedDictionaryDestroyInstance(d);
  if (os != sizeof(input) || memcmp(input, output, os)) return 4;
  puts("roundtrip=pass common=pass");
  return 0;
}
