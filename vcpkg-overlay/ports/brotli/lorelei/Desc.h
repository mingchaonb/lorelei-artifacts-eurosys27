#include <brotli/encode.h>
#include <brotli/shared_dictionary.h>

// Brotli 1.2.0 declares this API through an enum return type that the current
// TLC parser does not retain. The C ABI returns an int-sized status value.
extern "C" int BrotliDecoderDecompress(size_t encoded_size,
                                        const uint8_t *encoded_buffer,
                                        size_t *decoded_size,
                                        uint8_t *decoded_buffer);
