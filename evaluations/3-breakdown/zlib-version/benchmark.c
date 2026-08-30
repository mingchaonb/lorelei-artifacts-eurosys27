#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>

int main(int argc, char **argv)
{
    uint64_t iterations = 1000000;
    uint64_t checksum = 0;
    const char *version = NULL;

    if (argc == 2) {
        iterations = strtoull(argv[1], NULL, 10);
    }
    for (uint64_t i = 0; i < iterations; i++) {
        version = zlibVersion();
        checksum += (unsigned char)version[0];
    }
    printf("function=zlibVersion iterations=%llu version=%s checksum=%llu\n",
           (unsigned long long)iterations, version,
           (unsigned long long)checksum);
    return version == NULL;
}
