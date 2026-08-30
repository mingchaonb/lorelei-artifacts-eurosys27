if(NOT DEFINED ENV{LORELEI_DEVKIT})
    message(FATAL_ERROR "The glvnd system port requires LORELEI_DEVKIT")
endif()
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(SYSTEM_GL "/usr/lib/aarch64-linux-gnu/libGL.so.1")
set(SYSTEM_GLX "/usr/lib/aarch64-linux-gnu/libGLX.so.0")
if(NOT EXISTS "${SYSTEM_GL}" OR NOT EXISTS "${SYSTEM_GLX}")
    message(FATAL_ERROR "Ubuntu system libGL or libGLX was not found")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}"
    OPTIONS
        "-DLORELEI_DEVKIT=$ENV{LORELEI_DEVKIT}"
        "-DSYSTEM_LIBRARY=${SYSTEM_GL}"
        "-DSYSTEM_GLX_LIBRARY=${SYSTEM_GLX}"
        "-DAE_TEST_SOURCE=${REPO_ROOT}/evaluations/1-libs/glvnd/tests/TestGLX.c"
        "-DX11_PREFIX=${CURRENT_INSTALLED_DIR}"
        "-DX11_PORT=${CMAKE_CURRENT_LIST_DIR}/../libx11"
)
vcpkg_cmake_install()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${CMAKE_CURRENT_LIST_DIR}/copyright")
