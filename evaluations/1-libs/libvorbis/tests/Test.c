#include <vorbis/vorbisenc.h>
#include <stdio.h>

int main(void) {
    vorbis_info info;
    vorbis_comment comment;
    vorbis_dsp_state dsp;
    vorbis_block block;
    vorbis_info_init(&info);
    int error = vorbis_encode_init_vbr(&info, 2, 44100, 0.4f);
    if (error) return 2;
    vorbis_comment_init(&comment);
    vorbis_comment_add_tag(&comment, "TITLE", "lorelei");
    if (vorbis_analysis_init(&dsp, &info) != 0 || vorbis_block_init(&dsp, &block) != 0) return 3;
    float **buffer = vorbis_analysis_buffer(&dsp, 16);
    for (int c = 0; c < 2; ++c) for (int i = 0; i < 16; ++i) buffer[c][i] = 0.0f;
    vorbis_analysis_wrote(&dsp, 16);
    printf("vorbis:channels:%d rate:%ld query:%d\n", info.channels, info.rate, vorbis_analysis_blockout(&dsp, &block));
    vorbis_block_clear(&block);
    vorbis_dsp_clear(&dsp);
    vorbis_comment_clear(&comment);
    vorbis_info_clear(&info);
    return 0;
}
