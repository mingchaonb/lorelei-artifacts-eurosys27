#include <libaec.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    unsigned short input[32];
    unsigned short decoded[32] = {0};
    unsigned char compressed[256] = {0};
    for (unsigned int i = 0; i < 32; ++i) input[i] = (unsigned short)(i * i);
    struct aec_stream encode = {0};
    encode.next_in = (const unsigned char *)input;
    encode.avail_in = sizeof(input);
    encode.next_out = compressed;
    encode.avail_out = sizeof(compressed);
    encode.bits_per_sample = 16;
    encode.block_size = 8;
    encode.rsi = 2;
    encode.flags = AEC_DATA_PREPROCESS;
    int result = aec_buffer_encode(&encode);
    if (result != AEC_OK) return 2;
    struct aec_stream decode = {0};
    decode.next_in = compressed;
    decode.avail_in = encode.total_out;
    decode.next_out = (unsigned char *)decoded;
    decode.avail_out = sizeof(decoded);
    decode.bits_per_sample = 16;
    decode.block_size = 8;
    decode.rsi = 2;
    decode.flags = AEC_DATA_PREPROCESS;
    result = aec_buffer_decode(&decode);
    printf("aec:compressed:%zu decoded:%zu result:%d\n", encode.total_out, decode.total_out, result);
    return result == AEC_OK && decode.total_out == sizeof(input) && memcmp(input, decoded, sizeof(input)) == 0 ? 0 : 3;
}
