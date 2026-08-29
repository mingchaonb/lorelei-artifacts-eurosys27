#pragma once

#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>
#include <SDL2/SDL_vulkan.h>

#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>

#ifdef Success
#undef Success
#endif

namespace lore::thunk {

template <>
struct ProcFnDesc<::SDL_LogMessageV> {
    _DESC pass::vprintf<> builder_pass = {};
};

template <>
struct ProcFnDesc<::SDL_GL_GetProcAddress> {
    _DESC pass::GetProcAddress<1> proc_address_pass = {};
};

}
