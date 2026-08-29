#include <md4c-html.h>
#include <stdio.h>
static int callbacks;
static size_t bytes;
static void output(const MD_CHAR *text, MD_SIZE size, void *data) {
    (void)data;
    ++callbacks;
    bytes += size;
    fwrite(text, 1, size, stdout);
}
int main(void) {
    const char input[] = "# Lorelei\n\n- one\n- **two**\n\n[link](https://example.com)";
    int rc = md_html(input, sizeof(input) - 1, output, NULL, MD_FLAG_PERMISSIVEAUTOLINKS, 0);
    printf("callbacks=%d bytes=%zu status=%d\n", callbacks, bytes, rc);
    return rc == 0 && callbacks >= 10 && bytes > 40 ? 0 : 1;
}
