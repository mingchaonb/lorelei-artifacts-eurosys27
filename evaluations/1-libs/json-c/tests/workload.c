#include <json-c/json.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    struct json_object *root = json_tokener_parse("{\"value\":42,\"items\":[1,2,3],\"name\":\"lorelei\"}");
    struct json_object *value = NULL;
    struct json_object *items = NULL;
    struct json_object *name = NULL;
    struct json_tokener *tok = json_tokener_new();
    struct json_object *bad = json_tokener_parse_ex(tok, "{]", 2);
    enum json_tokener_error err = json_tokener_get_error(tok);
    int ok = root && json_object_object_get_ex(root, "value", &value) && json_object_get_int(value) == 42 &&
             json_object_object_get_ex(root, "items", &items) && json_object_array_length(items) == 3 &&
             json_object_object_get_ex(root, "name", &name) && strcmp(json_object_get_string(name), "lorelei") == 0 &&
             bad == NULL && err != json_tokener_success;
    printf("value=%d items=%zu name=%s invalid=%d\n", value ? json_object_get_int(value) : -1,
           items ? json_object_array_length(items) : 0, name ? json_object_get_string(name) : "", err != json_tokener_success);
    json_object_put(bad);
    json_tokener_free(tok);
    json_object_put(root);
    return ok ? 0 : 1;
}
