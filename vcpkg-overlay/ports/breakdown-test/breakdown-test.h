#ifndef BREAKDOWN_TEST_H
#define BREAKDOWN_TEST_H

#ifdef __cplusplus
extern "C" {
#endif

int breakdown_test(int first, int second, int third);
int breakdown_test_2(int first, int second);
int breakdown_test_6(int first, int second, int third, int fourth, int fifth, int sixth);

typedef int (*breakdown_test_callback)(int first, int second, int third);

breakdown_test_callback breakdown_test_get_callback(void);
int breakdown_test_accept_callback(breakdown_test_callback callback);

#ifdef __cplusplus
}
#endif

#endif
