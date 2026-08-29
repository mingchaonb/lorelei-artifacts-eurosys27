#include <libbase64.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  const char input[] = "lorelei-base64";
  char encoded[128], output[128];
  size_t es = 0, os = 0;
  base64_encode(input, sizeof(input), encoded, &es, 0);
  if (!base64_decode(encoded, es, output, &os, 0)) return 1;
  if (os != sizeof(input) || memcmp(input, output, os)) return 2;
  puts("roundtrip=pass scalar=pass");
  return 0;
}
