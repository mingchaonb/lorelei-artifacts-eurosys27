#include <ogg/ogg.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    static unsigned char payload[] = "lorelei";
    ogg_stream_state stream;
    ogg_packet packet = {0};
    ogg_page page;
    if (ogg_stream_init(&stream, 12345) != 0) return 2;
    packet.packet = payload;
    packet.bytes = (long)strlen((char *)payload);
    packet.b_o_s = 1;
    packet.e_o_s = 1;
    packet.granulepos = 7;
    if (ogg_stream_packetin(&stream, &packet) != 0) return 3;
    int produced = ogg_stream_flush(&stream, &page);
    printf("ogg:%d header:%ld body:%ld\n", produced, page.header_len, page.body_len);
    int ok = produced == 1 && page.header_len > 0 && page.body_len == 7;
    ogg_stream_clear(&stream);
    return ok ? 0 : 4;
}
