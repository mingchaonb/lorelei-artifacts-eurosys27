#include <curl/curl.h>
#include <stdio.h>

static size_t receive(char *data, size_t size, size_t count, void *opaque) {
    size_t bytes = size * count;
    size_t *total = opaque;
    *total += bytes;
    printf("write:%zu:%.*s\n", bytes, (int)bytes, data);
    return bytes;
}

int main(int argc, char **argv) {
    size_t total = 0;
    if (argc != 2 || curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK)
        return 2;
    CURL *curl = curl_easy_init();
    if (!curl)
        return 3;
    curl_easy_setopt(curl, CURLOPT_URL, argv[1]);
    curl_easy_setopt(curl, CURLOPT_PROXY, "");
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, receive);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &total);
    CURLcode result = curl_easy_perform(curl);
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    printf("total:%zu result:%d\n", total, result);
    return result == CURLE_OK && total == 11 ? 0 : 4;
}
