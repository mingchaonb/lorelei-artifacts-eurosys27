#include <fribidi/fribidi.h>
#include <stdio.h>

int main(void) {
    FriBidiChar ltr[] = {'a', 'b', 'c'};
    FriBidiChar rtl[] = {0x05d0, 0x05d1, 0x05d2};
    FriBidiChar out_ltr[3] = {0};
    FriBidiChar out_rtl[3] = {0};
    FriBidiStrIndex l2v[3] = {0};
    FriBidiStrIndex v2l[3] = {0};
    FriBidiLevel levels[3] = {0};
    FriBidiParType base_ltr = FRIBIDI_PAR_ON;
    FriBidiParType base_rtl = FRIBIDI_PAR_ON;
    int ok_ltr = fribidi_log2vis(ltr, 3, &base_ltr, out_ltr, l2v, v2l, levels);
    int ok_rtl = fribidi_log2vis(rtl, 3, &base_rtl, out_rtl, NULL, NULL, NULL);
    int ok = ok_ltr && ok_rtl && out_ltr[0] == 'a' && out_ltr[2] == 'c' &&
             out_rtl[0] == 0x05d2 && out_rtl[2] == 0x05d0 && l2v[1] == 1 && v2l[1] == 1;
    printf("ltr=%d rtl=%d map=%d version=%s\n", ok_ltr, ok_rtl, l2v[1], fribidi_version_info ? "set" : "missing");
    return ok ? 0 : 1;
}
