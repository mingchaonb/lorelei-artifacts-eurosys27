#include <cerf.h>
#include <complex.h>
#include <math.h>
#include <stdio.h>

int main(void) {
    double complex z = 1.0 + 2.0 * I;
    double complex value = cerf(z);
    double d = dawson(1.0);
    double v = voigt(0.0, 1.0, 0.5);
    printf("cerf:%.9f,%.9f dawson:%.9f voigt:%.9f\n", creal(value), cimag(value), d, v);
    return isfinite(creal(value)) && isfinite(cimag(value)) && d > 0.5 && v > 0.0 ? 0 : 2;
}
