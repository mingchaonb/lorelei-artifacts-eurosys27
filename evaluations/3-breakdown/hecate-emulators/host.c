#include <breakdown-test.h>

int breakdown_test(int first, int second, int third)
{
    (void)second;
    (void)third;
    return first;
}

static int host_callback(int first, int second, int third)
{
    (void)second;
    (void)third;
    return first;
}

breakdown_test_callback breakdown_test_get_callback(void)
{
    return host_callback;
}

int breakdown_test_accept_callback(breakdown_test_callback callback)
{
    return callback == host_callback ||
           (callback && callback(7, 11, 13) == 31);
}
