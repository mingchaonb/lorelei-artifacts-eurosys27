#include <vorbis/vorbisfile.h>
#include <stdio.h>
#include <string.h>

struct Reader { const unsigned char *data; size_t size; size_t pos; int reads; };
static size_t read_cb(void *ptr, size_t size, size_t nmemb, void *opaque) {
    struct Reader *r = opaque;
    size_t wanted = size * nmemb;
    size_t left = r->size - r->pos;
    if (wanted > left) wanted = left;
    memcpy(ptr, r->data + r->pos, wanted);
    r->pos += wanted;
    r->reads++;
    return size ? wanted / size : 0;
}
static int seek_cb(void *opaque, ogg_int64_t offset, int whence) { (void)opaque; (void)offset; (void)whence; return -1; }
static int close_cb(void *opaque) { (void)opaque; return 0; }
static long tell_cb(void *opaque) { return (long)((struct Reader *)opaque)->pos; }

int main(void) {
    static const unsigned char invalid[] = "not an ogg vorbis stream";
    struct Reader reader = {invalid, sizeof(invalid) - 1, 0, 0};
    ov_callbacks callbacks = {read_cb, seek_cb, close_cb, tell_cb};
    OggVorbis_File file = {0};
    int result = ov_test_callbacks(&reader, &file, NULL, 0, callbacks);
    printf("vorbisfile:result:%d reads:%d\n", result, reader.reads);
    if (result == 0) ov_clear(&file);
    return result < 0 && reader.reads > 0 ? 0 : 2;
}
