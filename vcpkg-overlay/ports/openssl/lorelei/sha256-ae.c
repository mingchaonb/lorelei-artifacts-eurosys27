#include <openssl/sha.h>

#include <errno.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
  unsigned char buffer[1 << 20];
  unsigned char digest[SHA256_DIGEST_LENGTH];
  SHA256_CTX context;
  FILE *input;
  FILE *output;
  size_t count;
  int index;

  if (argc < 3) {
    fprintf(stderr, "usage: %s OUTPUT INPUT...\n", argv[0]);
    return 64;
  }
  if (!SHA256_Init(&context)) return 2;
  for (index = 2; index < argc; ++index) {
    input = fopen(argv[index], "rb");
    if (!input) {
      fprintf(stderr, "%s: %s\n", argv[index], strerror(errno));
      return 3;
    }
    while ((count = fread(buffer, 1, sizeof(buffer), input)) != 0) {
      if (!SHA256_Update(&context, buffer, count)) return 4;
    }
    if (ferror(input) || fclose(input) != 0) return 5;
  }
  if (!SHA256_Final(digest, &context)) return 6;
  output = fopen(argv[1], "wb");
  if (!output) return 7;
  if (fwrite(digest, 1, sizeof(digest), output) != sizeof(digest)) return 8;
  return fclose(output) == 0 ? 0 : 9;
}
