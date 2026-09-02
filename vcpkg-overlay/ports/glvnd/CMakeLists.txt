cmake_minimum_required(VERSION 3.20)
project(lorelei_system_glvnd C)

if(NOT LORELEI_DEVKIT OR NOT SYSTEM_LIBRARY OR NOT SYSTEM_GLX_LIBRARY OR NOT AE_TEST_SOURCE OR NOT X11_PREFIX OR NOT X11_PORT OR NOT OPENGL_REGISTRY_INCLUDE)
    message(FATAL_ERROR "Lorelei, system GL, system GLX, test and X11 paths are required")
endif()

find_library(X11_LIBRARY NAMES X11 PATHS "${X11_PREFIX}/lib" NO_DEFAULT_PATH REQUIRED)
set(X11_THUNK_DIR "${CMAKE_CURRENT_BINARY_DIR}/x11-thunk")
add_custom_command(
    OUTPUT "${X11_THUNK_DIR}/libX11_HTL.so" "${X11_THUNK_DIR}/x86_64/libX11.so"
    COMMAND "${LORELEI_DEVKIT}/bin/LoreMakeThunk.py"
        --name X11
        --out "${X11_THUNK_DIR}"
        --lib "${X11_LIBRARY}"
        --symbols "${X11_PORT}/lorelei/Symbols.conf"
        --desc "${X11_PORT}/lorelei/Desc.h"
        --manifest-host "${X11_PORT}/lorelei/Manifest_host.cpp"
        --manifest-guest "${X11_PORT}/lorelei/Manifest_guest.cpp"
        --no-callback-replace
        --devkit "${LORELEI_DEVKIT}"
        --keep-intermediates
        -- "-I${X11_PREFIX}/include"
    DEPENDS
        "${X11_PORT}/lorelei/Desc.h"
        "${X11_PORT}/lorelei/Manifest_host.cpp"
        "${X11_PORT}/lorelei/Manifest_guest.cpp"
    VERBATIM
)
add_custom_target(glvnd_x11_thunk ALL DEPENDS "${X11_THUNK_DIR}/libX11_HTL.so" "${X11_THUNK_DIR}/x86_64/libX11.so")

set(THUNK_DIR "${CMAKE_CURRENT_BINARY_DIR}/thunk")
set(GL_SYMBOLS "${CMAKE_CURRENT_BINARY_DIR}/GL-Symbols.conf")
add_custom_command(
    OUTPUT "${GL_SYMBOLS}"
    COMMAND "${CMAKE_COMMAND}"
        "-DNM=${CMAKE_NM}"
        "-DINPUT_LIBRARY=${SYSTEM_LIBRARY}"
        "-DEXTRA_SYMBOLS=${CMAKE_CURRENT_SOURCE_DIR}/lorelei/ExtraSymbols.conf"
        "-DOUTPUT_FILE=${GL_SYMBOLS}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/GenerateSymbols.cmake"
    DEPENDS
        "${SYSTEM_LIBRARY}"
        "${CMAKE_CURRENT_SOURCE_DIR}/GenerateSymbols.cmake"
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/ExtraSymbols.conf"
    VERBATIM
)
add_custom_command(
    OUTPUT "${THUNK_DIR}/libGL_HTL.so" "${THUNK_DIR}/x86_64/libGL.so"
    COMMAND "${LORELEI_DEVKIT}/bin/LoreMakeThunk.py"
        --name GL
        --out "${THUNK_DIR}"
        --lib "${SYSTEM_LIBRARY}"
        --symbols "${GL_SYMBOLS}"
        --desc "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Desc.h"
        --manifest-host "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Manifest_host.cpp"
        --no-callback-replace
        --devkit "${LORELEI_DEVKIT}"
        --keep-intermediates
        -- -I/usr/include "-I${OPENGL_REGISTRY_INCLUDE}"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Desc.h"
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Manifest_host.cpp"
        "${GL_SYMBOLS}"
    VERBATIM
)
add_custom_target(glvnd_thunk ALL DEPENDS "${THUNK_DIR}/libGL_HTL.so" "${THUNK_DIR}/x86_64/libGL.so")

set(GLX_THUNK_DIR "${CMAKE_CURRENT_BINARY_DIR}/glx-thunk")
set(GLX_SYMBOLS "${CMAKE_CURRENT_BINARY_DIR}/GLX-Symbols.conf")
add_custom_command(
    OUTPUT "${GLX_SYMBOLS}"
    COMMAND "${CMAKE_COMMAND}"
        "-DNM=${CMAKE_NM}"
        "-DINPUT_LIBRARY=${SYSTEM_GLX_LIBRARY}"
        "-DEXTRA_SYMBOLS=${CMAKE_CURRENT_SOURCE_DIR}/lorelei/GLXExtraSymbols.conf"
        "-DOUTPUT_FILE=${GLX_SYMBOLS}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/GenerateSymbols.cmake"
    DEPENDS
        "${SYSTEM_GLX_LIBRARY}"
        "${CMAKE_CURRENT_SOURCE_DIR}/GenerateSymbols.cmake"
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/GLXExtraSymbols.conf"
    VERBATIM
)
add_custom_command(
    OUTPUT "${GLX_THUNK_DIR}/libGLX_HTL.so" "${GLX_THUNK_DIR}/x86_64/libGLX.so"
    COMMAND "${LORELEI_DEVKIT}/bin/LoreMakeThunk.py"
        --name GLX
        --out "${GLX_THUNK_DIR}"
        --lib "${SYSTEM_GLX_LIBRARY}"
        --symbols "${GLX_SYMBOLS}"
        --desc "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Desc.h"
        --manifest-host "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Manifest_glx_host.cpp"
        --no-callback-replace
        --devkit "${LORELEI_DEVKIT}"
        --keep-intermediates
        -- -I/usr/include "-I${OPENGL_REGISTRY_INCLUDE}"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Desc.h"
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Manifest_glx_host.cpp"
        "${GLX_SYMBOLS}"
    VERBATIM
)
add_custom_target(glx_thunk ALL DEPENDS "${GLX_THUNK_DIR}/libGLX_HTL.so" "${GLX_THUNK_DIR}/x86_64/libGLX.so")

add_executable(test-glx-native "${AE_TEST_SOURCE}")
target_link_libraries(test-glx-native PRIVATE "${SYSTEM_LIBRARY}" "${X11_LIBRARY}")

set(GUEST_TEST "${CMAKE_CURRENT_BINARY_DIR}/test-glx-hecate")
add_custom_command(
    OUTPUT "${GUEST_TEST}"
    COMMAND "${LORELEI_DEVKIT}/bin/x86_64-linux-gnu-clang"
        "--sysroot=${LORELEI_DEVKIT}/x86_64/sysroot"
        -I/usr/include
        "-I${OPENGL_REGISTRY_INCLUDE}"
        "-I${X11_PREFIX}/include"
        "${AE_TEST_SOURCE}"
        "-L${THUNK_DIR}/x86_64"
        "-L${X11_THUNK_DIR}/x86_64"
        -l:libGL.so
        -l:libX11.so
        -o "${GUEST_TEST}"
    DEPENDS glvnd_thunk glvnd_x11_thunk "${AE_TEST_SOURCE}"
    VERBATIM
)
add_custom_target(glvnd_guest_test ALL DEPENDS "${GUEST_TEST}")

add_executable(test-glx-direct-native "${AE_TEST_SOURCE}")
target_link_libraries(test-glx-direct-native PRIVATE "${SYSTEM_GLX_LIBRARY}" "${SYSTEM_LIBRARY}" "${X11_LIBRARY}")

set(DIRECT_GUEST_TEST "${CMAKE_CURRENT_BINARY_DIR}/test-glx-direct-hecate")
add_custom_command(
    OUTPUT "${DIRECT_GUEST_TEST}"
    COMMAND "${LORELEI_DEVKIT}/bin/x86_64-linux-gnu-clang"
        "--sysroot=${LORELEI_DEVKIT}/x86_64/sysroot"
        -I/usr/include
        "-I${OPENGL_REGISTRY_INCLUDE}"
        "-I${X11_PREFIX}/include"
        "${AE_TEST_SOURCE}"
        "-L${GLX_THUNK_DIR}/x86_64"
        "-L${THUNK_DIR}/x86_64"
        "-L${X11_THUNK_DIR}/x86_64"
        -l:libGLX.so
        -l:libGL.so
        -l:libX11.so
        -o "${DIRECT_GUEST_TEST}"
    DEPENDS glx_thunk glvnd_thunk glvnd_x11_thunk "${AE_TEST_SOURCE}"
    VERBATIM
)
add_custom_target(glx_direct_guest_test ALL DEPENDS "${DIRECT_GUEST_TEST}")

install(DIRECTORY "${THUNK_DIR}/" DESTINATION "share/glvnd/thunk")
install(DIRECTORY "${GLX_THUNK_DIR}/" DESTINATION "share/glvnd/glx-thunk")
install(DIRECTORY "${X11_THUNK_DIR}/" DESTINATION "share/glvnd/x11-thunk")
install(TARGETS test-glx-native test-glx-direct-native RUNTIME DESTINATION "tools/glvnd")
install(PROGRAMS "${GUEST_TEST}" "${DIRECT_GUEST_TEST}" DESTINATION "tools/glvnd")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/ThunkDB.json" DESTINATION "share/glvnd")
