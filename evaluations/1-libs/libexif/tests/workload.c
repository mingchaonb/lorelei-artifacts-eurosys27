#include <libexif/exif-data.h>
#include <libexif/exif-entry.h>
#include <libexif/exif-tag.h>
#include <stdio.h>

int main(void) {
    ExifData *data = exif_data_new();
    if (!data) return 1;
    exif_data_set_byte_order(data, EXIF_BYTE_ORDER_INTEL);
    exif_data_set_data_type(data, EXIF_DATA_TYPE_COMPRESSED);
    ExifEntry *entry = exif_entry_new();
    exif_content_add_entry(data->ifd[EXIF_IFD_0], entry);
    exif_entry_initialize(entry, EXIF_TAG_ORIENTATION);
    ExifEntry *found = exif_content_get_entry(data->ifd[EXIF_IFD_0], EXIF_TAG_ORIENTATION);
    int ok = found == entry && exif_data_get_byte_order(data) == EXIF_BYTE_ORDER_INTEL &&
             exif_data_get_data_type(data) == EXIF_DATA_TYPE_COMPRESSED && entry->size > 0;
    printf("order=%d type=%d entry=%d size=%u\n", (int)exif_data_get_byte_order(data),
           (int)exif_data_get_data_type(data), found == entry, entry->size);
    exif_entry_unref(entry);
    exif_data_unref(data);
    return ok ? 0 : 1;
}
