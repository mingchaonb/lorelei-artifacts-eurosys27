#include <syn123.h>
#include <math.h>
#include <stdio.h>

int main(void) {
    int error = 0;
    syn123_handle *handle = syn123_new(44100, 2, MPG123_ENC_SIGNED_16, 0, &error);
    if (!handle) return 2;
    double linear = syn123_db2lin(-6.0);
    double db = syn123_lin2db(linear);
    printf("syn123:error:%d linear:%.9f db:%.9f\n", error, linear, db);
    syn123_del(handle);
    return fabs(db + 6.0) < 1e-9 ? 0 : 3;
}
