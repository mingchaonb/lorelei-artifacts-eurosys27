#include "idn2.h"

extern "C" int _idn2_punycode_decode(size_t input_length,
                                       const char input[],
                                       size_t *output_length,
                                       uint32_t output[]);
extern "C" int _idn2_punycode_encode(size_t input_length,
                                       const uint32_t input[],
                                       size_t *output_length,
                                       char output[]);
