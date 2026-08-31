#pragma once

extern "C" {
#include "libavutil/avstring.h"
#include "libavutil/adler32.h"
#include "libavutil/ambient_viewing_environment.h"
#include "libavutil/base64.h"
#include "libavutil/avutil.h"
#include "libavutil/bprint.h"
#include "libavutil/buffer.h"
#include "libavutil/channel_layout.h"
#include "libavutil/common.h"
#include "libavutil/cpu.h"
#include "libavutil/csp.h"
#include "libavutil/crc.h"
#include "libavutil/dict.h"
#include "libavutil/display.h"
#include "libavutil/dovi_meta.h"
#include "libavutil/error.h"
#include "libavutil/eval.h"
#include "libavutil/fifo.h"
#include "libavutil/film_grain_params.h"
#include "libavutil/file_open.h"
#include "libavutil/frame.h"
#include "libavutil/hash.h"
#include "libavutil/hdr_dynamic_metadata.h"
#include "libavutil/hwcontext.h"
#include "libavutil/iamf.h"
#include "libavutil/imgutils.h"
#include "libavutil/imgutils_internal.h"
#include "libavutil/lfg.h"
#include "libavutil/log.h"
#include "libavutil/lzo.h"
#include "libavutil/mathematics.h"
#include "libavutil/mastering_display_metadata.h"
#include "libavutil/mem.h"
#include "libavutil/opt.h"
#include "libavutil/parseutils.h"
#include "libavutil/pixdesc.h"
#include "libavutil/rational.h"
#include "libavutil/random_seed.h"
#include "libavutil/samplefmt.h"
#include "libavutil/slicethread.h"
#include "libavutil/spherical.h"
#include "libavutil/stereo3d.h"
#include "libavutil/timecode.h"
#include "libavutil/threadmessage.h"
#include "libavutil/time.h"
#include "libavutil/timestamp.h"
#include "libavutil/tx.h"
#include "libavutil/video_enc_params.h"

int avpriv_dict_set_timestamp(AVDictionary **dictionary, const char *key,
                              int64_t timestamp);
typedef struct AVFloatDSPContext AVFloatDSPContext;
AVFloatDSPContext *avpriv_float_dsp_alloc(int strict);
void avpriv_report_missing_feature(void *context, const char *message, ...);
void avpriv_request_sample(void *context, const char *message, ...);
}

#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>

namespace lore::thunk {

    using FFmpegLogCallback = void (*)(void *, int, const char *, va_list);

    template <>
    struct ProcCbDesc<FFmpegLogCallback> {
        _DESC pass::vprintf<3, 4> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::avpriv_report_missing_feature> {
        _DESC pass::printf<2, 3> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::avpriv_request_sample> {
        _DESC pass::printf<2, 3> builder_pass = {};
    };

}
