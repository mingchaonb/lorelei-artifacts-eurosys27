#pragma once
extern "C" {
#include "common/fse.h"
#include "common/huf.h"
#include "common/pool.h"
#include "common/zstd_internal.h"
#include "compress/zstd_compress_internal.h"
#include "decompress/zstd_decompress_block.h"
size_t ZSTD_decodeLiteralsBlock_wrapper(ZSTD_DCtx* dctx,
                                        const void* src, size_t srcSize,
                                        void* dst, size_t dstCapacity);
}
#undef FSE_isError
#undef HUF_isError
#undef ZSTD_isError
#include <zdict.h>
#include <zstd.h>
