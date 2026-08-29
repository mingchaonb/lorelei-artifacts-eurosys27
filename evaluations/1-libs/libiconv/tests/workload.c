#include <iconv.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

static int convert_error(const char *input, size_t input_len, size_t output_len, int expected) {
    iconv_t cd = iconv_open("UTF-8", "UTF-8");
    char output[8] = {0};
    char *in = (char *)input;
    char *out = output;
    errno = 0;
    size_t rc = iconv(cd, &in, &input_len, &out, &output_len);
    int saved = errno;
    iconv_close(cd);
    return rc == (size_t)-1 && saved == expected;
}

int main(void) {
    iconv_t cd = iconv_open("UTF-16LE", "UTF-8");
    char input[] = "A\xc3\xa9";
    unsigned char output[16] = {0};
    char *in = input;
    char *out = (char *)output;
    size_t input_len = sizeof(input) - 1;
    size_t output_len = sizeof(output);
    size_t rc = iconv(cd, &in, &input_len, &out, &output_len);
    iconv_close(cd);
    const char invalid[] = {(char)0xff};
    int eilseq = convert_error(invalid, sizeof(invalid), 8, EILSEQ);
    int e2big = convert_error("ab", 2, 1, E2BIG);
    int ok = rc != (size_t)-1 && input_len == 0 && output[0] == 'A' && output[1] == 0 &&
             output[2] == 0xe9 && output[3] == 0 && eilseq && e2big;
    printf("utf16=%02x%02x%02x%02x eilseq=%d e2big=%d version=%d\n",
           output[0], output[1], output[2], output[3], eilseq, e2big, _libiconv_version);
    return ok ? 0 : 1;
}
