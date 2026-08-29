#include <expat.h>
#include <stdio.h>
#include <string.h>

struct Counts {
    int starts;
    int ends;
    int text_bytes;
};

static void XMLCALL start_element(void *opaque, const XML_Char *name, const XML_Char **attributes) {
    struct Counts *counts = opaque;
    (void)attributes;
    counts->starts++;
    printf("start:%s\n", name);
}

static void XMLCALL end_element(void *opaque, const XML_Char *name) {
    struct Counts *counts = opaque;
    counts->ends++;
    printf("end:%s\n", name);
}

static void XMLCALL character_data(void *opaque, const XML_Char *text, int length) {
    struct Counts *counts = opaque;
    counts->text_bytes += length;
    printf("text:%.*s\n", length, text);
}

int main(void) {
    static const char document[] = "<root><item>lorelei</item></root>";
    struct Counts counts = {0, 0, 0};
    XML_Parser parser = XML_ParserCreate(NULL);
    if (!parser) {
        return 2;
    }
    XML_SetUserData(parser, &counts);
    XML_SetElementHandler(parser, start_element, end_element);
    XML_SetCharacterDataHandler(parser, character_data);
    if (XML_Parse(parser, document, (int)strlen(document), XML_TRUE) == XML_STATUS_ERROR) {
        fprintf(stderr, "parse error on line %lu: %s\n", XML_GetCurrentLineNumber(parser), XML_ErrorString(XML_GetErrorCode(parser)));
        XML_ParserFree(parser);
        return 3;
    }
    XML_ParserFree(parser);
    printf("counts:%d,%d,%d\n", counts.starts, counts.ends, counts.text_bytes);
    return counts.starts == 2 && counts.ends == 2 && counts.text_bytes == 7 ? 0 : 4;
}
