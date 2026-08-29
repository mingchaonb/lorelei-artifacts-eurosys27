#include <libxml/parser.h>
#include <stdio.h>
#include <string.h>

struct Counts {
   int starts;
   int ends;
   int text_bytes;
};

static void start_element(void *opaque, const xmlChar *name, const xmlChar **attributes)
{
   struct Counts *counts = opaque;
   (void)name;
   (void)attributes;
   ++counts->starts;
}

static void end_element(void *opaque, const xmlChar *name)
{
   struct Counts *counts = opaque;
   (void)name;
   ++counts->ends;
}

static void character_data(void *opaque, const xmlChar *text, int length)
{
   struct Counts *counts = opaque;
   (void)text;
   counts->text_bytes += length;
}

int main(void)
{
   static const char document[] = "<root><item>lorelei</item></root>";
   xmlSAXHandler sax = {0};
   struct Counts counts = {0, 0, 0};
   xmlParserCtxtPtr parser;
   int split = 13;
   int rc;

   sax.startElement = start_element;
   sax.endElement = end_element;
   sax.characters = character_data;
   parser = xmlCreatePushParserCtxt(&sax, &counts, NULL, 0, NULL);
   if (parser == NULL)
      return 2;
   rc = xmlParseChunk(parser, document, split, 0);
   if (rc == 0)
      rc = xmlParseChunk(parser, document + split,
                         (int)strlen(document) - split, 1);
   xmlFreeParserCtxt(parser);
   xmlCleanupParser();
   printf("starts=%d ends=%d text_bytes=%d\n", counts.starts, counts.ends, counts.text_bytes);
   return rc == 0 && counts.starts == 2 && counts.ends == 2 && counts.text_bytes == 7 ? 0 : 3;
}
