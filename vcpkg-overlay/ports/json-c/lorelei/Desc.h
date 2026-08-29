#pragma once

extern "C" {
#include "arraylist.h"
#include "debug.h"
#include "json.h"
#include "json_visit.h"
#include "printbuf.h"
char *_json_c_strerror(int errno_in);
}

#include <lorelei/ThunkInterface/Proc.h>
#include <lorelei/ThunkInterface/PassTags.h>

namespace lore::thunk {

    template <>
    struct ProcFnDesc<::json_pointer_getf> {
        _DESC pass::printf<3, 4> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::json_pointer_setf> {
        _DESC pass::printf<3, 4> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::sprintbuf> {
        _DESC pass::printf<2, 3> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::mc_debug> {
        _DESC pass::printf<1, 2> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::mc_error> {
        _DESC pass::printf<1, 2> builder_pass = {};
    };

    template <>
    struct ProcFnDesc<::mc_info> {
        _DESC pass::printf<1, 2> builder_pass = {};
    };

}
