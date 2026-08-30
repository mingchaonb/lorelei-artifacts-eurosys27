#pragma once

extern "C" {
#include "libavutil/avstring.h"
#include "libavutil/avutil.h"
#include "libavutil/bprint.h"
#include "libavutil/buffer.h"
#include "libavutil/channel_layout.h"
#include "libavutil/common.h"
#include "libavutil/cpu.h"
#include "libavutil/crc.h"
#include "libavutil/dict.h"
#include "libavutil/display.h"
#include "libavutil/error.h"
#include "libavutil/eval.h"
#include "libavutil/fifo.h"
#include "libavutil/file_open.h"
#include "libavutil/frame.h"
#include "libavutil/hash.h"
#include "libavutil/hwcontext.h"
#include "libavutil/iamf.h"
#include "libavutil/imgutils.h"
#include "libavutil/imgutils_internal.h"
#include "libavutil/lfg.h"
#include "libavutil/log.h"
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
}

#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>

namespace lore::thunk {

    using FFmpegLogCallback = void (*)(void *, int, const char *, va_list);

    template <>
    struct ProcCbDesc<FFmpegLogCallback> {
        _DESC pass::vprintf<3, 4> builder_pass = {};
    };

}
