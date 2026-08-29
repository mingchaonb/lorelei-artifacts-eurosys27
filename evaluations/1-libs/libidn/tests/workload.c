#include <punycode.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    const punycode_uint input[] = {'b','u','c','h',0xfc};
    char encoded[64] = {0};
    size_t encoded_len = sizeof(encoded);
    int encode_rc = punycode_encode(5, input, NULL, &encoded_len, encoded);
    punycode_uint decoded[16] = {0};
    size_t decoded_len = 16;
    int decode_rc = punycode_decode(encoded_len, encoded, &decoded_len, decoded, NULL);
    char tiny[2];
    size_t tiny_len = sizeof(tiny);
    int small_rc = punycode_encode(5, input, NULL, &tiny_len, tiny);
    int roundtrip = decoded_len == 5 && memcmp(input, decoded, sizeof(input)) == 0;
    printf("encode=%d decode=%d length=%zu roundtrip=%d small=%d\n",
           encode_rc, decode_rc, encoded_len, roundtrip, small_rc == PUNYCODE_BIG_OUTPUT);
    return encode_rc == PUNYCODE_SUCCESS && decode_rc == PUNYCODE_SUCCESS && roundtrip &&
           small_rc == PUNYCODE_BIG_OUTPUT ? 0 : 1;
}
