#pragma push_macro("__has_attribute")
#undef __has_attribute
#define __has_attribute(x) 0
#define XXH_STATIC_LINKING_ONLY
#include <xxhash.h>
#pragma pop_macro("__has_attribute")
