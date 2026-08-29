#include <jansson.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    json_error_t error = {0};
    json_t *root = json_loads("{\"value\":42,\"items\":[true,false,null],\"name\":\"lorelei\"}", 0, &error);
    json_t *bad = json_loads("{]", 0, &error);
    json_t *value = root ? json_object_get(root, "value") : NULL;
    json_t *items = root ? json_object_get(root, "items") : NULL;
    json_t *name = root ? json_object_get(root, "name") : NULL;
    int ok = json_is_integer(value) && json_integer_value(value) == 42 && json_array_size(items) == 3 &&
             json_is_true(json_array_get(items, 0)) && json_is_false(json_array_get(items, 1)) &&
             json_is_null(json_array_get(items, 2)) && json_is_string(name) &&
             strcmp(json_string_value(name), "lorelei") == 0 && bad == NULL && error.line == 1;
    printf("value=%lld items=%zu name=%s invalid_line=%d\n", value ? (long long)json_integer_value(value) : -1LL,
           items ? json_array_size(items) : 0, name ? json_string_value(name) : "", error.line);
    json_decref(bad);
    json_decref(root);
    return ok ? 0 : 1;
}
