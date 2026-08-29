#include <pcap/pcap.h>
#include <stdio.h>

static int packets;
static unsigned bytes;

static void count_packet(unsigned char *opaque, const struct pcap_pkthdr *header, const unsigned char *data) {
    (void)opaque;
    packets++;
    bytes += header->caplen;
    printf("packet:%u:%u:%02x\n", header->len, header->caplen, header->caplen ? data[0] : 0);
}

int main(int argc, char **argv) {
    char error[PCAP_ERRBUF_SIZE];
    if (argc != 2) {
        return 2;
    }
    pcap_t *pcap = pcap_open_offline(argv[1], error);
    if (!pcap) {
        fprintf(stderr, "%s\n", error);
        return 3;
    }
    int result = pcap_loop(pcap, 0, count_packet, NULL);
    if (result < 0) {
        fprintf(stderr, "%s\n", pcap_geterr(pcap));
    }
    pcap_close(pcap);
    printf("counts:%d,%u\n", packets, bytes);
    return result == 0 && packets == 1 && bytes == 4 ? 0 : 4;
}
