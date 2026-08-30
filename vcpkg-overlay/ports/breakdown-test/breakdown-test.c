#include "breakdown-test.h"

int breakdown_test(int first, int second, int third)
{
    (void)second;
    (void)third;
    return first;
}

static int breakdown_test_callback_impl(int first, int second, int third)
{
    (void)second;
    (void)third;
    return first;
}

breakdown_test_callback breakdown_test_get_callback(void)
{
    return breakdown_test_callback_impl;
}

int breakdown_test_accept_callback(breakdown_test_callback callback)
{
    return callback == breakdown_test_callback_impl;
}
