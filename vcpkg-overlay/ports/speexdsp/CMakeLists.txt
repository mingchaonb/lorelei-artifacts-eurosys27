cmake_minimum_required(VERSION 3.15)
project(speexdsp VERSION 1.2.1 LANGUAGES C)

include(GNUInstallDirs)

option(SPEEXDSP_BUILD_TESTS "Build and install upstream test drivers" ON)
option(SPEEXDSP_USE_NEON "Use ARM NEON implementations" OFF)
option(SPEEXDSP_USE_SSE "Use x86 SSE implementations" OFF)

set(speexdsp_sources
    libspeexdsp/buffer.c
    libspeexdsp/fftwrap.c
    libspeexdsp/filterbank.c
    libspeexdsp/jitter.c
    libspeexdsp/mdf.c
    libspeexdsp/preprocess.c
    libspeexdsp/resample.c
    libspeexdsp/scal.c
    libspeexdsp/smallft.c
)

add_library(speexdsp SHARED ${speexdsp_sources})
target_include_directories(speexdsp
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_compile_definitions(speexdsp PRIVATE
    EXPORT=__attribute__\(\(visibility\("default"\)\)\)
    FLOATING_POINT
    USE_SMALLFT
    VAR_ARRAYS
    $<$<BOOL:${SPEEXDSP_USE_NEON}>:USE_NEON>
    $<$<BOOL:${SPEEXDSP_USE_SSE}>:USE_SSE>
    $<$<BOOL:${SPEEXDSP_USE_SSE}>:USE_SSE2>
)
target_link_libraries(speexdsp PRIVATE m)
set_target_properties(speexdsp PROPERTIES VERSION 1.5.2 SOVERSION 1)
set_target_properties(speexdsp PROPERTIES C_VISIBILITY_PRESET hidden)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/speexdsp_config_types.h"
    "#pragma once\n#include <stdint.h>\ntypedef int16_t spx_int16_t;\ntypedef uint16_t spx_uint16_t;\ntypedef int32_t spx_int32_t;\ntypedef uint32_t spx_uint32_t;\n")

install(TARGETS speexdsp
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
)
install(DIRECTORY include/speex DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
    FILES_MATCHING PATTERN "*.h")
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/speexdsp_config_types.h"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/speex"
)

set(prefix "${CMAKE_INSTALL_PREFIX}")
set(exec_prefix "\${prefix}")
set(libdir "\${exec_prefix}/${CMAKE_INSTALL_LIBDIR}")
set(includedir "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")
set(PACKAGE_VERSION "${PROJECT_VERSION}")
configure_file(speexdsp.pc.in speexdsp.pc @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/speexdsp.pc"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")

if(SPEEXDSP_BUILD_TESTS)
    foreach(test_name IN ITEMS testdenoise testecho testjitter testresample testresample2)
        add_executable(${test_name} "libspeexdsp/${test_name}.c")
        target_link_libraries(${test_name} PRIVATE speexdsp m)
        install(TARGETS ${test_name}
            RUNTIME DESTINATION "tools/speexdsp/upstream-tests/bin")
    endforeach()
endif()
