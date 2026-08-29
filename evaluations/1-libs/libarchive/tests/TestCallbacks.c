#include <archive.h>
#include <archive_entry.h>
#include <stdio.h>
#include <string.h>

struct Reader {
   const unsigned char *data;
   size_t size;
   size_t offset;
   int opens;
   int reads;
   int closes;
};

static int open_callback(struct archive *archive, void *opaque)
{
   struct Reader *reader = opaque;
   (void)archive;
   ++reader->opens;
   return ARCHIVE_OK;
}

static la_ssize_t read_callback(struct archive *archive, void *opaque,
                                const void **buffer)
{
   struct Reader *reader = opaque;
   size_t remaining = reader->size - reader->offset;
   size_t chunk = remaining > 127 ? 127 : remaining;
   (void)archive;
   ++reader->reads;
   *buffer = reader->data + reader->offset;
   reader->offset += chunk;
   return (la_ssize_t)chunk;
}

static la_int64_t skip_callback(struct archive *archive, void *opaque,
                                la_int64_t request)
{
   struct Reader *reader = opaque;
   size_t remaining = reader->size - reader->offset;
   size_t amount = request > (la_int64_t)remaining ? remaining : (size_t)request;
   (void)archive;
   reader->offset += amount;
   return (la_int64_t)amount;
}

static int close_callback(struct archive *archive, void *opaque)
{
   struct Reader *reader = opaque;
   (void)archive;
   ++reader->closes;
   return ARCHIVE_OK;
}

int main(void)
{
   static const char payload[] = "lorelei archive callback";
   unsigned char archive_buffer[4096];
   char output[64] = {0};
   char pathname[64] = {0};
   size_t archive_size = 0;
   struct archive *writer = archive_write_new();
   struct archive_entry *entry = archive_entry_new();
   struct archive *reader_archive;
   struct archive_entry *read_entry;
   struct Reader reader;
   la_ssize_t bytes;
   int rc;

   archive_write_set_format_pax_restricted(writer);
   rc = archive_write_open_memory(writer, archive_buffer, sizeof(archive_buffer), &archive_size);
   if (rc != ARCHIVE_OK)
      return 2;
   archive_entry_set_pathname(entry, "payload.txt");
   archive_entry_set_filetype(entry, AE_IFREG);
   archive_entry_set_perm(entry, 0644);
   archive_entry_set_size(entry, sizeof(payload) - 1);
   if (archive_write_header(writer, entry) != ARCHIVE_OK)
      return 2;
   if (archive_write_data(writer, payload, sizeof(payload) - 1) != sizeof(payload) - 1)
      return 2;
   archive_entry_free(entry);
   archive_write_close(writer);
   archive_write_free(writer);

   reader.data = archive_buffer;
   reader.size = archive_size;
   reader.offset = 0;
   reader.opens = 0;
   reader.reads = 0;
   reader.closes = 0;
   reader_archive = archive_read_new();
   archive_read_support_format_tar(reader_archive);
   rc = archive_read_open2(reader_archive, &reader, open_callback,
                           read_callback, skip_callback, close_callback);
   if (rc != ARCHIVE_OK)
      return 3;
   if (archive_read_next_header(reader_archive, &read_entry) != ARCHIVE_OK)
      return 3;
   bytes = archive_read_data(reader_archive, output, sizeof(output));
   if (bytes < 0) {
      fprintf(stderr, "%s\n", archive_error_string(reader_archive));
      return 3;
   }
   snprintf(pathname, sizeof(pathname), "%s", archive_entry_pathname(read_entry));
   archive_read_close(reader_archive);
   archive_read_free(reader_archive);
   printf("path=%s bytes=%lld opens=%d reads=%d closes=%d\n",
          pathname, (long long)bytes, reader.opens, reader.reads, reader.closes);
   return bytes == sizeof(payload) - 1 && memcmp(output, payload, sizeof(payload) - 1) == 0 &&
          reader.opens == 1 && reader.reads > 0 && reader.closes == 1 ? 0 : 4;
}
