#pragma once

extern "C" {

using cerf_complex = __complex__ double;

cerf_complex w_of_z(cerf_complex z);
double im_w_of_x(double x);
cerf_complex cerf(cerf_complex z);
cerf_complex cerfc(cerf_complex z);
cerf_complex cerfcx(cerf_complex z);
double erfcx(double x);
cerf_complex cerfi(cerf_complex z);
double erfi(double x);
cerf_complex cdawson(cerf_complex z);
double dawson(double x);
double voigt(double x, double sigma, double gamma);
double voigt_hwhm(double sigma, double gamma);

}
