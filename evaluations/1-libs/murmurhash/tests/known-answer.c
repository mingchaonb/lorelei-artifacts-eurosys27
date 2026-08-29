#include <assert.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <murmurhash.h>
#define CHECK(value, seed, expected) do { uint32_t length = (uint32_t)strlen(value); uint32_t hash = murmurhash(value, length, seed); printf("['%s'] '%" PRIu32 "' = '%" PRIu32 "'", value, (uint32_t)(expected), hash); assert((uint32_t)(expected) == hash); printf(" ...ok\n"); } while (0)
int main(void) {
    CHECK("", 0, 0x00000000); CHECK("0", 0, 0xd271c07f); CHECK("01", 0, 0x61ec6600); CHECK("012", 0, 0xec6cff8c); CHECK("0123", 0, 0xd41994a0); CHECK("01234", 0, 0x19d02170); CHECK("2", 0, 0x0129e217); CHECK("88", 0, 0x7a0040a5); CHECK("asdfqwer", 0, 0xa46b5209); CHECK("asdfqwerty", 0, 0xa3cfe04b); CHECK("asd", 0, 0x14570c6f); CHECK("Hello", 0, 0x12da77c8); CHECK("Hello1", 0, 0x6357e0a6); CHECK("Hello2", 0, 0xe5ce223e); CHECK("hey", 0, 0x12f94418); CHECK("dude", 0, 0xef0487f3); CHECK("test", 0, 0xba6bd213); CHECK("kinkajou", 0, 0xb6d99cf8); CHECK("", 1, 0x514e28b7);
    return 0;
}
