#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <breakdown-test.h>

int main(int argc, char **argv)
{
    uint64_t iterations = 1000000;
    uint64_t checksum = 0;

    if (argc == 2) {
        iterations = strtoull(argv[1], NULL, 10);
    }
    for (uint64_t i = 0; i < iterations; i++) {
        int first = (int)(i & 0x7fff);
        int result = breakdown_test(first, 0x1357, 0x2468);
        if (result != first) {
            fprintf(stderr, "unexpected result at iteration %llu: %d != %d\n",
                    (unsigned long long)i, result, first);
            return 1;
        }
        checksum += (unsigned int)result;
    }
    printf("function=breakdown_test arguments=3 iterations=%llu checksum=%llu\n",
           (unsigned long long)iterations, (unsigned long long)checksum);
    return 0;
}
