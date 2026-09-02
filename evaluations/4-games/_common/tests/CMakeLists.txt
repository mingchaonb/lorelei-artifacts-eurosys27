cmake_minimum_required(VERSION 3.20)
project(lorelei_game_preflight NONE)

foreach(required IN ITEMS
        LORELEI_DEVKIT SDL2_PREFIX X11_THUNK XRANDR_THUNK GLVND_PREFIX
        VULKAN_PREFIX GAME_SDL_ABI)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "Missing required configuration: ${required}")
    endif()
endforeach()

set(GUEST_CC "${LORELEI_DEVKIT}/bin/x86_64-linux-gnu-clang")
set(GUEST_SYSROOT "${LORELEI_DEVKIT}/x86_64/sysroot")

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/test-xrandr"
    COMMAND "${GUEST_CC}" "--sysroot=${GUEST_SYSROOT}"
        "-I${SDL2_PREFIX}/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/TestXRandR.c"
        "${XRANDR_THUNK}/x86_64/libXrandr.so.2"
        "${X11_THUNK}/x86_64/libX11.so.6"
        -o "${CMAKE_CURRENT_BINARY_DIR}/test-xrandr"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/TestXRandR.c"
    VERBATIM
)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/test-multi-thunk-db"
    COMMAND "${GUEST_CC}" "--sysroot=${GUEST_SYSROOT}"
        -I/usr/include -Wno-macro-redefined
        "${CMAKE_CURRENT_SOURCE_DIR}/TestMultiThunkDB.c"
        "${GLVND_PREFIX}/share/glvnd/glx-thunk/x86_64/libGLX.so.0"
        "${GLVND_PREFIX}/share/glvnd/thunk/x86_64/libGL.so"
        "${VULKAN_PREFIX}/share/vulkan-loader/thunk/x86_64/libvulkan.so"
        -o "${CMAKE_CURRENT_BINARY_DIR}/test-multi-thunk-db"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/TestMultiThunkDB.c"
    VERBATIM
)

set(PREFLIGHT_OUTPUTS
    "${CMAKE_CURRENT_BINARY_DIR}/test-xrandr"
    "${CMAKE_CURRENT_BINARY_DIR}/test-multi-thunk-db"
)
if(GAME_SDL_ABI STREQUAL "1")
    foreach(required IN ITEMS SDL1_PREFIX SDL1_THUNK)
        if(NOT DEFINED ${required})
            message(FATAL_ERROR "Missing SDL 1.2 configuration: ${required}")
        endif()
    endforeach()
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/test-sdl1-video"
        COMMAND "${GUEST_CC}" "--sysroot=${GUEST_SYSROOT}"
            "-I${SDL1_PREFIX}/include" "-I${SDL1_PREFIX}/include/SDL"
            "${CMAKE_CURRENT_SOURCE_DIR}/TestSDL1Video.c"
            "${SDL1_THUNK}/x86_64/libSDL.so"
            -o "${CMAKE_CURRENT_BINARY_DIR}/test-sdl1-video"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/TestSDL1Video.c"
        VERBATIM
    )
    list(APPEND PREFLIGHT_OUTPUTS "${CMAKE_CURRENT_BINARY_DIR}/test-sdl1-video")
elseif(GAME_SDL_ABI STREQUAL "2")
    if(NOT DEFINED SDL2_THUNK)
        message(FATAL_ERROR "Missing SDL2 configuration: SDL2_THUNK")
    endif()
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/test-sdl2-displays"
        COMMAND "${GUEST_CC}" "--sysroot=${GUEST_SYSROOT}"
            "-I${SDL2_PREFIX}/include/SDL2"
            "${CMAKE_CURRENT_SOURCE_DIR}/TestSDLDisplays.c"
            "${SDL2_THUNK}/x86_64/libSDL2.so"
            -o "${CMAKE_CURRENT_BINARY_DIR}/test-sdl2-displays"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/TestSDLDisplays.c"
        VERBATIM
    )
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/test-sdl2-gl"
        COMMAND "${GUEST_CC}" "--sysroot=${GUEST_SYSROOT}"
            "-I${SDL2_PREFIX}/include/SDL2"
            "${CMAKE_CURRENT_SOURCE_DIR}/TestSDLGL.c"
            "${SDL2_THUNK}/x86_64/libSDL2.so"
            -o "${CMAKE_CURRENT_BINARY_DIR}/test-sdl2-gl"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/TestSDLGL.c"
        VERBATIM
    )
    list(APPEND PREFLIGHT_OUTPUTS
        "${CMAKE_CURRENT_BINARY_DIR}/test-sdl2-displays"
        "${CMAKE_CURRENT_BINARY_DIR}/test-sdl2-gl")
else()
    message(FATAL_ERROR "GAME_SDL_ABI must be 1 or 2")
endif()

add_custom_target(game-preflight ALL DEPENDS ${PREFLIGHT_OUTPUTS})
