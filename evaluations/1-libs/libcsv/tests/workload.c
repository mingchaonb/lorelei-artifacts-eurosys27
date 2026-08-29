#include <csv.h>
#include <stdio.h>
#include <stdlib.h>
static int fields;
static int rows;
static size_t bytes;
static void field(void *s, size_t n, void *p) { (void)s; (void)p; ++fields; bytes += n; }
static void row(int c, void *p) { (void)c; (void)p; ++rows; }
static int allocations;
static void *resize(void *p, size_t n) { ++allocations; return realloc(p, n); }
static void release(void *p) { free(p); }
int main(void) {
    struct csv_parser p;
    const char first[] = "a,\"b,b\"\n";
    const char second[] = "c,d\r\n";
    if (csv_init(&p, CSV_STRICT)) return 1;
    csv_set_realloc_func(&p, resize);
    csv_set_free_func(&p, release);
    size_t n1 = csv_parse(&p, first, sizeof(first) - 1, field, row, NULL);
    size_t n2 = csv_parse(&p, second, sizeof(second) - 1, field, row, NULL);
    int fini = csv_fini(&p, field, row, NULL);
    int status = csv_error(&p);
    csv_free(&p);
    printf("parsed=%zu fields=%d rows=%d payload=%zu allocations=%d status=%d\n",
           n1 + n2, fields, rows, bytes, allocations, status);
    return n1 == sizeof(first) - 1 && n2 == sizeof(second) - 1 && fini == 0 &&
           fields == 4 && rows == 2 && bytes == 6 && allocations > 0 && status == CSV_SUCCESS ? 0 : 1;
}
