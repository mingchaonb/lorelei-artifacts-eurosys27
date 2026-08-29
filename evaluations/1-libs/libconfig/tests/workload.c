#include <libconfig.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    config_t config;
    int value = 0;
    const char *name = NULL;
    config_init(&config);
    int parsed = config_read_string(&config, "value=42; nested={name=\"lorelei\";}; items=[1,2,3];");
    config_setting_t *items = config_lookup(&config, "items");
    int ok = parsed && config_lookup_int(&config, "value", &value) &&
             config_lookup_string(&config, "nested.name", &name) && name && strcmp(name, "lorelei") == 0 &&
             items && config_setting_length(items) == 3 && config_setting_get_int_elem(items, 2) == 3;
    config_t invalid;
    config_init(&invalid);
    int rejected = !config_read_string(&invalid, "value = ;");
    printf("value=%d items=%d name=%s invalid=%d\n", value, items ? config_setting_length(items) : -1,
           name ? name : "", rejected);
    config_destroy(&invalid);
    config_destroy(&config);
    return ok && rejected ? 0 : 1;
}
