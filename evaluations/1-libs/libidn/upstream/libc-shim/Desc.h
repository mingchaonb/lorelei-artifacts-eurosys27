#pragma once

// The interposed subset spans the allocator family (<stdlib.h>) and the stdio FILE* family
// (<stdio.h>).
#include <stdlib.h>
#include <stdio.h>

#include <lorelei/ThunkInterface/Proc.h>
#include <lorelei/ThunkInterface/PassTags.h>

extern "C" int __isoc23_fscanf(FILE *stream, const char *format, ...);
extern "C" int __isoc23_scanf(const char *format, ...);
extern "C" int __isoc23_sscanf(const char *input, const char *format, ...);

namespace lore::thunk {}
