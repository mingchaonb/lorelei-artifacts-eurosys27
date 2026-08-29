#include <event2/event.h>
#include <stdio.h>
static void callback(evutil_socket_t fd, short events, void *opaque) {
    int *count = opaque;
    (void)fd;
    (*count)++;
    printf("callback:%d:%d\n", events, *count);
}
int main(void) {
    int count = 0;
    struct event_base *base = event_base_new();
    if (!base) return 2;
    struct event *event = event_new(base, -1, 0, callback, &count);
    if (!event) return 3;
    event_active(event, EV_TIMEOUT, 0);
    int result = event_base_loop(base, EVLOOP_ONCE);
    event_free(event);
    event_base_free(base);
    printf("count:%d\n", count);
    return result == 0 && count == 1 ? 0 : 4;
}
