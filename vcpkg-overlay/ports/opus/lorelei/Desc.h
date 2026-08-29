#pragma once

#include <cstdarg>

#include <lorelei/DLCall/Tools/VariadicArgDefs.h>
#include <lorelei/ThunkInterface/Detail/Variadic.h>
#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>

extern "C" {
#include <opus/opus.h>
#include <opus/opus_multistream.h>
}

namespace lore::thunk::opus_detail {

    struct ControlExtractor {
        template <class State>
        static void extract(State *, int request, va_list arguments, CVargEntry *output) {
            va_list copy;
            va_copy(copy, arguments);
            size_t count = 0;
            if (request == OPUS_MULTISTREAM_GET_ENCODER_STATE_REQUEST ||
                request == OPUS_MULTISTREAM_GET_DECODER_STATE_REQUEST) {
                output[count++] = CVargGet(va_arg(copy, int));
                output[count++] = CVargGet(va_arg(copy, void *));
#ifdef OPUS_SET_DNN_BLOB_REQUEST
            } else if (request == OPUS_SET_DNN_BLOB_REQUEST) {
                output[count++] = CVargGet(va_arg(copy, void *));
                output[count++] = CVargGet(va_arg(copy, int));
#endif
            } else if (request > 0 && request != OPUS_RESET_STATE) {
                if (request & 1) {
                    output[count++] = CVargGet(va_arg(copy, void *));
                } else {
                    output[count++] = CVargGet(va_arg(copy, int));
                }
            }
            va_end(copy);
            output[count] = {};
        }
    };

}

namespace lore::thunk {

    template <>
    struct ProcFnDesc<::opus_encoder_ctl> {
        _DESC pass::custom_variadic<opus_detail::ControlExtractor, 2, 3> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::opus_decoder_ctl> {
        _DESC pass::custom_variadic<opus_detail::ControlExtractor, 2, 3> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::opus_multistream_encoder_ctl> {
        _DESC pass::custom_variadic<opus_detail::ControlExtractor, 2, 3> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::opus_multistream_decoder_ctl> {
        _DESC pass::custom_variadic<opus_detail::ControlExtractor, 2, 3> builder_pass = {};
    };

}
