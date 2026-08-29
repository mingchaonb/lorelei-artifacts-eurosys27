cmake_minimum_required(VERSION 3.20)
project(lorelei_system_vulkan C)

if(NOT LORELEI_DEVKIT OR NOT SYSTEM_LIBRARY OR NOT AE_TEST_SOURCE OR NOT X11_INCLUDE)
    message(FATAL_ERROR "Lorelei, system Vulkan, test and X11 include paths are required")
endif()

set(HEADER_DIR "${CMAKE_CURRENT_BINARY_DIR}/include")
file(COPY /usr/include/vulkan DESTINATION "${HEADER_DIR}")
file(COPY /usr/include/vk_video DESTINATION "${HEADER_DIR}")
set(THUNK_DIR "${CMAKE_CURRENT_BINARY_DIR}/thunk")
set(VULKAN_SYMBOLS "${CMAKE_CURRENT_BINARY_DIR}/Vulkan-Symbols.conf")
add_custom_command(
    OUTPUT "${VULKAN_SYMBOLS}"
    COMMAND "${CMAKE_COMMAND}"
        "-DNM=${CMAKE_NM}"
        "-DINPUT_LIBRARY=${SYSTEM_LIBRARY}"
        "-DEXTRA_SYMBOLS=${CMAKE_CURRENT_SOURCE_DIR}/lorelei/ExtraSymbols.conf"
        "-DOUTPUT_FILE=${VULKAN_SYMBOLS}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/GenerateSymbols.cmake"
    DEPENDS
        "${SYSTEM_LIBRARY}"
        "${CMAKE_CURRENT_SOURCE_DIR}/GenerateSymbols.cmake"
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/ExtraSymbols.conf"
    VERBATIM
)
add_custom_command(
    OUTPUT "${THUNK_DIR}/libvulkan_HTL.so" "${THUNK_DIR}/x86_64/libvulkan.so"
    COMMAND "${LORELEI_DEVKIT}/bin/LoreMakeThunk.py"
        --name vulkan
        --out "${THUNK_DIR}"
        --lib "${SYSTEM_LIBRARY}"
        --symbols "${VULKAN_SYMBOLS}"
        --desc "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Desc.h"
        --manifest-host "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Manifest_host.cpp"
        --manifest-guest "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Manifest_guest.cpp"
        --no-callback-replace
        --devkit "${LORELEI_DEVKIT}"
        --keep-intermediates
        -- "-I${HEADER_DIR}" "-I${X11_INCLUDE}"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Desc.h"
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Manifest_host.cpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/Manifest_guest.cpp"
        "${VULKAN_SYMBOLS}"
    VERBATIM
)
add_custom_target(vulkan_thunk ALL DEPENDS "${THUNK_DIR}/libvulkan_HTL.so" "${THUNK_DIR}/x86_64/libvulkan.so")

add_executable(test-vulkan-native "${AE_TEST_SOURCE}")
target_link_libraries(test-vulkan-native PRIVATE "${SYSTEM_LIBRARY}")

set(GUEST_TEST "${CMAKE_CURRENT_BINARY_DIR}/test-vulkan-hecate")
add_custom_command(
    OUTPUT "${GUEST_TEST}"
    COMMAND "${LORELEI_DEVKIT}/bin/x86_64-linux-gnu-clang"
        "--sysroot=${LORELEI_DEVKIT}/x86_64/sysroot"
        "-I${HEADER_DIR}"
        "${AE_TEST_SOURCE}"
        "-L${THUNK_DIR}/x86_64"
        -l:libvulkan.so
        -o "${GUEST_TEST}"
    DEPENDS vulkan_thunk "${AE_TEST_SOURCE}"
    VERBATIM
)
add_custom_target(vulkan_guest_test ALL DEPENDS "${GUEST_TEST}")

install(DIRECTORY "${THUNK_DIR}/" DESTINATION "share/vulkan-loader/thunk")
install(TARGETS test-vulkan-native RUNTIME DESTINATION "tools/vulkan-loader")
install(PROGRAMS "${GUEST_TEST}" DESTINATION "tools/vulkan-loader")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/lorelei/ThunkDB.json" DESTINATION "share/vulkan-loader")
