cmake_minimum_required(VERSION 3.20)
project(breakdown_test VERSION 1.0.0 LANGUAGES C)

add_library(breakdown_test SHARED breakdown-test.c)
target_include_directories(breakdown_test PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
)
set_target_properties(breakdown_test PROPERTIES
    OUTPUT_NAME breakdown_test
    VERSION 1.0.0
    SOVERSION 1
)

install(TARGETS breakdown_test
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)
install(FILES breakdown-test.h DESTINATION include)
