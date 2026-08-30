#define _POSIX_C_SOURCE 200809L

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

enum { ADDRESS_COUNT = 4096 };

static volatile uintptr_t addresses[ADDRESS_COUNT];

static uint64_t nanoseconds(void)
{
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC_RAW, &value) != 0) {
        perror("clock_gettime");
        exit(2);
    }
    return (uint64_t)value.tv_sec * 1000000000ULL + (uint64_t)value.tv_nsec;
}

int main(int argc, char **argv)
{
    uint64_t iterations = 100000000;
    const uintptr_t boundary = UINT64_C(0x0000800000000000);
    uint64_t host_count = 0;

    if (argc == 2) {
        iterations = strtoull(argv[1], NULL, 10);
    } else if (argc != 1) {
        fprintf(stderr, "usage: %s [iterations]\n", argv[0]);
        return 2;
    }
    for (size_t index = 0; index < ADDRESS_COUNT; ++index) {
        addresses[index] = boundary + 0x1000 + index * 16;
    }

    uint64_t start = nanoseconds();
    for (uint64_t index = 0; index < iterations; ++index) {
        uintptr_t address = addresses[index & (ADDRESS_COUNT - 1)];
        host_count += address >= boundary;
    }
    uint64_t elapsed = nanoseconds() - start;

    if (host_count != iterations) {
        fprintf(stderr, "unexpected classification count: %" PRIu64 "\n", host_count);
        return 1;
    }
    printf("iterations=%" PRIu64 " elapsed_ns=%" PRIu64
           " ns_per_compare=%.9f host_count=%" PRIu64 "\n",
           iterations, elapsed, (double)elapsed / (double)iterations, host_count);
    return 0;
}
