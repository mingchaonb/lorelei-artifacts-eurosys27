#include <sndfile.h>
#include <stdio.h>
#include <string.h>

struct Memory {
    unsigned char bytes[8192];
    sf_count_t size;
    sf_count_t position;
    int reads;
    int writes;
};

static sf_count_t get_filelen(void *opaque) { return ((struct Memory *)opaque)->size; }
static sf_count_t seek_io(sf_count_t offset, int whence, void *opaque) {
    struct Memory *memory = opaque;
    sf_count_t base = whence == SEEK_SET ? 0 : whence == SEEK_CUR ? memory->position : memory->size;
    sf_count_t next = base + offset;
    if (next < 0 || next > (sf_count_t)sizeof(memory->bytes)) return -1;
    memory->position = next;
    return next;
}
static sf_count_t read_io(void *ptr, sf_count_t count, void *opaque) {
    struct Memory *memory = opaque;
    if (count > memory->size - memory->position) count = memory->size - memory->position;
    memcpy(ptr, memory->bytes + memory->position, (size_t)count);
    memory->position += count;
    memory->reads++;
    return count;
}
static sf_count_t write_io(const void *ptr, sf_count_t count, void *opaque) {
    struct Memory *memory = opaque;
    if (count > (sf_count_t)sizeof(memory->bytes) - memory->position) count = sizeof(memory->bytes) - memory->position;
    memcpy(memory->bytes + memory->position, ptr, (size_t)count);
    memory->position += count;
    if (memory->position > memory->size) memory->size = memory->position;
    memory->writes++;
    return count;
}
static sf_count_t tell_io(void *opaque) { return ((struct Memory *)opaque)->position; }

int main(void) {
    SF_VIRTUAL_IO io = {get_filelen, seek_io, read_io, write_io, tell_io};
    struct Memory memory = {{0}, 0, 0, 0, 0};
    SF_INFO info = {0};
    info.samplerate = 8000;
    info.channels = 1;
    info.format = SF_FORMAT_WAV | SF_FORMAT_PCM_16;
    SNDFILE *file = sf_open_virtual(&io, SFM_WRITE, &info, &memory);
    if (!file) return 2;
    short samples[8] = {0, 1000, -1000, 2000, -2000, 1000, -1000, 0};
    if (sf_write_short(file, samples, 8) != 8 || sf_close(file) != 0) return 3;
    memory.position = 0;
    memset(&info, 0, sizeof(info));
    file = sf_open_virtual(&io, SFM_READ, &info, &memory);
    if (!file) return 4;
    short decoded[8] = {0};
    sf_count_t frames = sf_read_short(file, decoded, 8);
    sf_close(file);
    printf("sndfile:frames:%lld reads:%d writes:%d format:%x\n", (long long)frames, memory.reads, memory.writes, info.format);
    return frames == 8 && memcmp(samples, decoded, sizeof(samples)) == 0 && memory.reads > 0 && memory.writes > 0 ? 0 : 5;
}
