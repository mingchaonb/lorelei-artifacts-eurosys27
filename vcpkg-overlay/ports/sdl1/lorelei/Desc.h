#pragma once

#include <SDL/SDL.h>

#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>

namespace lore::thunk {

template <>
struct ProcFnDesc<::SDL_GL_GetProcAddress> {
    _DESC pass::GetProcAddress<1> proc_address_pass = {};
};

}
