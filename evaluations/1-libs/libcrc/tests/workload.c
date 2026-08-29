#include <stddef.h>
#include <checksum.h>
#include <stdio.h>
int main(void) {
  const unsigned char input[] = "123456789";
  unsigned long value = crc_32(input, 9);
  if (value != 0xcbf43926UL) return 1;
  puts("known-answer=pass");
  return 0;
}
