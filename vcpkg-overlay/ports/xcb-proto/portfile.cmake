set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_download_distfile(
    ARCHIVE
    URLS "https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-${VERSION}.tar.xz"
    FILENAME "xcb-proto-${VERSION}.tar.xz"
    SHA512 a333ac7c39f17ff2567419d09a9a77210c943a4e88d79eb152d416ae26bf6fb14e2446f9817abc806edd7aa3733bd4de5852b5ae90a25cbcc9d40e59c211aa36
)
vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES patches/pkgconfig.patch
)

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON3_DIR "${PYTHON3}" DIRECTORY)
vcpkg_add_to_path("${PYTHON3_DIR}")
set(ENV{PYTHON} "${PYTHON3}")

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        "ac_cv_path_PYTHON=${PYTHON3}"
        "am_cv_python_pyexecdir=\\\${prefix}/tools/${PORT}"
        "am_cv_python_pythondir=\\\${prefix}/tools/${PORT}"
)
vcpkg_make_install()
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
