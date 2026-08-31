#pragma once

extern "C" {
#include "libavcodec/bsf.h"
#include "libavcodec/codec_id.h"
#include "libavcodec/internal.h"
#include "libavcodec/codec_par.h"
#include "libavcodec/packet.h"
#include "libavcodec/avcodec.h"
#include "libavcodec/bsf.h"
#include "libavcodec/codec.h"
#include "libavcodec/codec_desc.h"
#include "libavcodec/codec_id.h"
#include "libavcodec/codec_par.h"
#include "libavcodec/dirac.h"
#include "libavcodec/mpegaudiodecheader.h"
#include "libavcodec/packet.h"
#include "libavcodec/packet_internal.h"
#include "libavcodec/raw.h"
#include "libavcodec/vorbis_parser.h"
#include "libavcodec/xiph.h"

typedef struct MPEG4AudioConfig MPEG4AudioConfig;
int avpriv_mpeg4audio_get_config2(MPEG4AudioConfig *config,
                                  const uint8_t *buffer, int size,
                                  int sync_extension, void *log_context);
}
