#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <breakdown-test.h>

int main(int argc, char **argv)
{
    uint64_t iterations = 1000000;
    uint64_t checksum = 0;
    int argument_count = 2;

    if (argc == 3) {
        argument_count = atoi(argv[1]);
        iterations = strtoull(argv[2], NULL, 10);
    } else if (argc != 1) {
        fprintf(stderr, "usage: %s 2|6 [iterations]\n", argv[0]);
        return 2;
    }
    for (uint64_t i = 0; i < iterations; i++) {
        int first = (int)(i & 0x7fff);
        int result;
        if (argument_count == 2) {
            result = breakdown_test_2(first, 0x1357);
        } else if (argument_count == 6) {
            result = breakdown_test_6(first, 0x1357, 0x2468, 0x3579, 0x468a, 0x579b);
        } else {
            fprintf(stderr, "argument count must be 2 or 6\n");
            return 2;
        }
        if (result != first) {
            fprintf(stderr, "unexpected result at iteration %llu: %d != %d\n",
                    (unsigned long long)i, result, first);
            return 1;
        }
        checksum += (unsigned int)result;
    }
    printf("function=breakdown_test_%d arguments=%d iterations=%llu checksum=%llu\n",
           argument_count, argument_count, (unsigned long long)iterations,
           (unsigned long long)checksum);
    return 0;
}
