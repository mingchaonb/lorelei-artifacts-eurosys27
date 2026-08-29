#include <cjson/cJSON.h>
#include <stdio.h>

int main(void) {
    cJSON *root = cJSON_Parse("{\"value\":42,\"items\":[true,false,null],\"nested\":{\"name\":\"lorelei\"}}");
    cJSON *value = root ? cJSON_GetObjectItemCaseSensitive(root, "value") : NULL;
    cJSON *items = root ? cJSON_GetObjectItemCaseSensitive(root, "items") : NULL;
    cJSON *nested = root ? cJSON_GetObjectItemCaseSensitive(root, "nested") : NULL;
    cJSON *name = nested ? cJSON_GetObjectItemCaseSensitive(nested, "name") : NULL;
    cJSON *invalid = cJSON_Parse("{\"broken\":]");
    int ok = cJSON_IsNumber(value) && value->valueint == 42 && cJSON_GetArraySize(items) == 3 &&
             cJSON_IsTrue(cJSON_GetArrayItem(items, 0)) && cJSON_IsFalse(cJSON_GetArrayItem(items, 1)) &&
             cJSON_IsNull(cJSON_GetArrayItem(items, 2)) && cJSON_IsString(name) && invalid == NULL;
    printf("value=%d items=%d name=%s invalid=%d\n", value ? value->valueint : -1,
           items ? cJSON_GetArraySize(items) : -1, name ? name->valuestring : "", invalid == NULL);
    cJSON_Delete(invalid);
    cJSON_Delete(root);
    return ok ? 0 : 1;
}
