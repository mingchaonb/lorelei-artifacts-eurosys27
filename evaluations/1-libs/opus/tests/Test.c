#include <opus/opus.h>
#include <stdio.h>

int main(void) {
    int error = 0;
    OpusEncoder *encoder = opus_encoder_create(48000, 1, OPUS_APPLICATION_AUDIO, &error);
    if (!encoder || error != OPUS_OK) return 2;
    if (opus_encoder_ctl(encoder, OPUS_SET_BITRATE(64000)) != OPUS_OK) return 3;
    opus_int16 pcm[960] = {0};
    unsigned char packet[4000];
    int bytes = opus_encode(encoder, pcm, 960, packet, sizeof(packet));
    opus_int32 bitrate = 0;
    opus_encoder_ctl(encoder, OPUS_GET_BITRATE(&bitrate));
    printf("opus:bytes:%d bitrate:%d\n", bytes, bitrate);
    opus_encoder_destroy(encoder);
    return bytes > 0 && bitrate == 64000 ? 0 : 4;
}
