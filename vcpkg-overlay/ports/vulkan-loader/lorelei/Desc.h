#pragma once

#define VK_USE_PLATFORM_XLIB_KHR
#include <vulkan/vulkan.h>

#include <lorelei/ThunkInterface/Proc.h>
#include <lorelei/ThunkInterface/PassTags.h>

namespace lore::thunk {}

#ifdef Success
#undef Success
#endif
