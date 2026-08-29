if(NOT DEFINED ENV{LORELEI_DEVKIT})
    message(FATAL_ERROR "The Vulkan system port requires LORELEI_DEVKIT")
endif()
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(SYSTEM_VULKAN "/usr/lib/aarch64-linux-gnu/libvulkan.so.1")
if(NOT EXISTS "${SYSTEM_VULKAN}")
    message(FATAL_ERROR "Ubuntu system Vulkan loader was not found: ${SYSTEM_VULKAN}")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}"
    OPTIONS
        "-DLORELEI_DEVKIT=$ENV{LORELEI_DEVKIT}"
        "-DSYSTEM_LIBRARY=${SYSTEM_VULKAN}"
        "-DAE_TEST_SOURCE=${REPO_ROOT}/evaluations/2-graphics/vulkan/tests/TestVulkan.c"
        "-DX11_INCLUDE=${CURRENT_INSTALLED_DIR}/include"
)
vcpkg_cmake_install()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${CMAKE_CURRENT_LIST_DIR}/copyright")
