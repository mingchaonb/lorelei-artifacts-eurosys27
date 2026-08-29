#include <mpg123.h>
#include <stdio.h>

int main(void) {
    int error = MPG123_OK;
    if (mpg123_init() != MPG123_OK) return 2;
    mpg123_handle *handle = mpg123_new(NULL, &error);
    if (!handle) return 3;
    long flags = 0;
    double ignored = 0.0;
    error = mpg123_getparam(handle, MPG123_FLAGS, &flags, &ignored);
    printf("mpg123:%d flags:%ld\n", error, flags);
    mpg123_delete(handle);
    mpg123_exit();
    return error == MPG123_OK ? 0 : 4;
}
