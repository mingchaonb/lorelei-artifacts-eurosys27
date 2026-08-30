#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <breakdown-test.h>

static int guest_callback(int first, int second, int third)
{
    return first + second + third;
}

int main(int argc, char **argv)
{
    uint64_t iterations = argc == 2 ? strtoull(argv[1], NULL, 10) : 1000;
    uint64_t accepted = 0;
    breakdown_test_callback host = NULL;

    if (breakdown_test(7, 11, 13) != 7) {
        fputs("direct bridge validation failed\n", stderr);
        return 1;
    }
    host = breakdown_test_get_callback();
    printf("host_callback=%p guest_callback=%p\n", (void *)host,
           (void *)guest_callback);
    fflush(stdout);
    if (!breakdown_test_accept_callback(host)) {
        fputs("host callback address classification failed\n", stderr);
        return 1;
    }
    for (uint64_t i = 0; i < iterations; ++i) {
        accepted += (unsigned int)breakdown_test_accept_callback(guest_callback);
    }
    printf("direct=ok host_address=ok guest_callback=%s iterations=%llu\n",
           accepted == iterations ? "ok" : "failed",
           (unsigned long long)iterations);
    return accepted == iterations ? 0 : 1;
}
