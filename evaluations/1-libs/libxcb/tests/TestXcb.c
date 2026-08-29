#include <stdio.h>
#include <stdlib.h>
#include <xcb/xcb.h>
#include <xcb/xcbext.h>

static int socket_returns;

static void return_socket(void *closure) {
    int *count = closure;
    ++*count;
    ++socket_returns;
}

int main(void) {
    int screen_number = 0;
    xcb_connection_t *connection = xcb_connect(NULL, &screen_number);
    int connection_error = xcb_connection_has_error(connection);
    if (connection_error) {
        fprintf(stderr, "connect-error:%d\n", connection_error);
        xcb_disconnect(connection);
        return 2;
    }

    const xcb_setup_t *setup = xcb_get_setup(connection);
    xcb_screen_iterator_t screens = xcb_setup_roots_iterator(setup);
    for (int index = 0; index < screen_number && screens.rem; ++index) {
        xcb_screen_next(&screens);
    }
    if (!screens.rem) {
        xcb_disconnect(connection);
        return 3;
    }

    xcb_screen_t *screen = screens.data;
    xcb_window_t window = xcb_generate_id(connection);
    uint32_t values[] = {screen->black_pixel, XCB_EVENT_MASK_EXPOSURE};
    xcb_void_cookie_t create = xcb_create_window_checked(
        connection, XCB_COPY_FROM_PARENT, window, screen->root,
        0, 0, 64, 64, 0, XCB_WINDOW_CLASS_INPUT_OUTPUT,
        screen->root_visual, XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK, values);
    xcb_generic_error_t *error = xcb_request_check(connection, create);
    if (error) {
        fprintf(stderr, "create-error:%u\n", error->error_code);
        free(error);
        xcb_disconnect(connection);
        return 4;
    }

    xcb_map_window(connection, window);
    xcb_flush(connection);

    uint64_t sent = 0;
    int closure_count = 0;
    int took_socket = xcb_take_socket(connection, return_socket, &closure_count, 0, &sent);
    if (!took_socket) {
        xcb_destroy_window(connection, window);
        xcb_disconnect(connection);
        return 5;
    }

    xcb_get_input_focus_cookie_t focus_cookie = xcb_get_input_focus(connection);
    xcb_get_input_focus_reply_t *focus = xcb_get_input_focus_reply(connection, focus_cookie, &error);
    if (!focus || error) {
        free(focus);
        free(error);
        xcb_destroy_window(connection, window);
        xcb_disconnect(connection);
        return 6;
    }

    printf("xcb:%u:%u:%d:%d:%llu\n", setup->protocol_major_version,
           setup->protocol_minor_version, closure_count, socket_returns,
           (unsigned long long)sent);
    free(focus);
    xcb_destroy_window(connection, window);
    xcb_flush(connection);
    xcb_disconnect(connection);
    return closure_count == 1 && socket_returns == 1 ? 0 : 7;
}
