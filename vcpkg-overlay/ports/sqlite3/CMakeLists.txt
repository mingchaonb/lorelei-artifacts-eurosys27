cmake_minimum_required(VERSION 3.15)
project(sqlite3 VERSION 3.53.4 LANGUAGES C)

find_package(Threads REQUIRED)

add_library(sqlite3 SHARED sqlite3.c)
target_include_directories(sqlite3 PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(sqlite3 PRIVATE Threads::Threads ${CMAKE_DL_LIBS} m)
set_target_properties(sqlite3 PROPERTIES VERSION 3.53.4 SOVERSION 0)

install(TARGETS sqlite3
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)
install(FILES sqlite3.h sqlite3ext.h DESTINATION include)
