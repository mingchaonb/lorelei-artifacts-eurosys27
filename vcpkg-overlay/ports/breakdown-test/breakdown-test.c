#include "breakdown-test.h"

int breakdown_test(int first, int second, int third)
{
    (void)second;
    (void)third;
    return first;
}

int breakdown_test_2(int first, int second)
{
    (void)second;
    return first;
}

int breakdown_test_6(int first, int second, int third, int fourth, int fifth, int sixth)
{
    (void)second;
    (void)third;
    (void)fourth;
    (void)fifth;
    (void)sixth;
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
