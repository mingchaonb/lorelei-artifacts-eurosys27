#include <idn2.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    uint32_t ascii[] = {'e','x','a','m','p','l','e',0};
    uint32_t unicode[] = {'b',0xfc,'c','h','e','r',0};
    uint32_t invalid[] = {0xd800,0};
    char ascii_out[64] = {0};
    char unicode_out[64] = {0};
    char invalid_out[64] = {0};
    int ascii_rc = idn2_to_ascii_4i(ascii, 7, ascii_out, 0);
    int unicode_rc = idn2_to_ascii_4i(unicode, 6, unicode_out, 0);
    int invalid_rc = idn2_to_ascii_4i(invalid, 1, invalid_out, 0);
    int ok = ascii_rc == IDN2_OK && strcmp(ascii_out, "example") == 0 && unicode_rc == IDN2_OK &&
             strcmp(unicode_out, "xn--bcher-kva") == 0 && invalid_rc != IDN2_OK;
    printf("ascii=%s unicode=%s invalid=%d\n", ascii_out, unicode_out, invalid_rc != IDN2_OK);
    return ok ? 0 : 1;
}
