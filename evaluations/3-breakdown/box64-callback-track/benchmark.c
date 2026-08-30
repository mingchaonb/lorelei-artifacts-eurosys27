#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <breakdown-test.h>

int main(int argc, char **argv)
{
    uint64_t iterations = 1000000;
    uint64_t accepted = 0;

    if (argc == 2) {
        iterations = strtoull(argv[1], NULL, 10);
    }

    breakdown_test_callback callback = breakdown_test_get_callback();
    if (callback == NULL || callback(7, 11, 13) != 7) {
        fputs("callback bridge validation failed\n", stderr);
        return 1;
    }

    for (uint64_t i = 0; i < iterations; ++i) {
        accepted += (unsigned int)breakdown_test_accept_callback(callback);
    }

    printf("function=breakdown_test_accept_callback iterations=%llu "
           "accepted=%llu\n",
           (unsigned long long)iterations,
           (unsigned long long)accepted);
    return accepted == iterations ? 0 : 1;
}
