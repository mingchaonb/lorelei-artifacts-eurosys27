cmake_minimum_required(VERSION 3.5...3.29)
project(bzip2 C)

if(CMAKE_BUILD_TYPE STREQUAL Debug)
    add_definitions(-DBZ_DEBUG) # enable extra assertions
endif()

set(BZ2_SOURCES
    blocksort.c
    huffman.c
    crctable.c
    randtable.c
    compress.c
    decompress.c
    bzlib.c)

add_library(bz2 ${BZ2_SOURCES})
set_target_properties(bz2 PROPERTIES
    DEBUG_POSTFIX d
    VERSION "${BZ2_VERSION}"
    SOVERSION 1.0)
if(BUILD_SHARED_LIBS)
    target_compile_definitions(bz2 PRIVATE -DBZ_BUILD_DLL)
endif()

if(MSVC)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
    add_definitions(-D_CRT_SECURE_NO_DEPRECATE)
    add_definitions(-D_CRT_NONSTDC_NO_DEPRECATE)
endif()

install(TARGETS bz2
    RUNTIME DESTINATION bin
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib)

if(NOT BZIP2_SKIP_TOOLS)
    add_executable(bzip2 bzip2.c ${BZ2_SOURCES})
    add_executable(bzip2recover bzip2recover.c ${BZ2_SOURCES})
    install(TARGETS bzip2 bzip2recover DESTINATION tools/bzip2)
endif()

if(NOT BZIP2_SKIP_HEADERS)
    install(FILES bzlib.h DESTINATION include)
endif()

add_executable(bzip2_upstream_test bzip2.c)
target_link_libraries(bzip2_upstream_test PRIVATE bz2)
install(TARGETS bzip2_upstream_test RUNTIME DESTINATION tools/bzip2/upstream-tests)
install(FILES
    sample1.ref sample1.bz2
    sample2.ref sample2.bz2
    sample3.ref sample3.bz2
    DESTINATION tools/bzip2/upstream-tests)
