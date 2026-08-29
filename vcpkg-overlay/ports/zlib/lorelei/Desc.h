#include <zlib.h>

// zlib exposes gzgetc as a function-like optimization macro. TLC needs the
// actual exported function declaration when generating its wrapper.
#ifdef gzgetc
#undef gzgetc
#endif
