#pragma once
extern "C" {
#include <lzo/lzo1.h>
#include <lzo/lzo1a.h>
#include <lzo/lzo1b.h>
#include <lzo/lzo1c.h>
#include <lzo/lzo1f.h>
#include <lzo/lzo1x.h>
#include <lzo/lzo1y.h>
#include <lzo/lzo1z.h>
#include <lzo/lzo2a.h>
int lzo1x_999_compress_internal(const unsigned char *, lzo_uint, unsigned char *, lzo_uintp, void *, const unsigned char *, lzo_uint, lzo_callback_t *, int, lzo_uint, lzo_uint, lzo_uint, lzo_uint, unsigned int);
int lzo1y_999_compress_internal(const unsigned char *, lzo_uint, unsigned char *, lzo_uintp, void *, const unsigned char *, lzo_uint, lzo_callback_t *, int, lzo_uint, lzo_uint, lzo_uint, lzo_uint, unsigned int);
}
