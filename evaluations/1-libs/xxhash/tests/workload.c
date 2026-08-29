#include <xxhash.h>
#include <stdio.h>
int main(void) {
  const char input[] = "lorelei-xxhash";
  XXH64_hash_t value = XXH64(input, sizeof(input), 0);
  if (!value) return 1;
  printf("hash=%016llx\n", (unsigned long long)value);
  return 0;
}
