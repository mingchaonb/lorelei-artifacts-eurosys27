vcpkg_download_distfile(ARCHIVE URLS "https://www.fftw.org/fftw-3.3.10.tar.gz" FILENAME "fftw-3.3.10.tar.gz" SHA512 2d34b5ccac7b08740dbdacc6ebe451d8a34cf9d9bfec85a5e776e87adf94abfd803c222412d8e10fbaa4ed46f504aa87180396af1b108666cde4314a55610b40)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}" PATCHES patches/hecate-shared-tests.patch)
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS -DBUILD_SHARED_LIBS=ON -DBUILD_TESTS=ON -DENABLE_THREADS=OFF -DDISABLE_FORTRAN=ON -DENABLE_FLOAT=OFF -DENABLE_LONG_DOUBLE=OFF -DENABLE_SSE=OFF -DENABLE_SSE2=OFF -DENABLE_AVX=OFF -DENABLE_AVX2=OFF)

# The upstream bench executable is intentionally not part of FFTW's install
# target. Build it explicitly before copying the configured test tree into the
# package, so the public runner never depends on a leftover source build.
vcpkg_cmake_build(TARGET bench LOGFILE_BASE build-upstream-bench)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/fftw3)
vcpkg_fixup_pkgconfig()

# Preserve the upstream test executable before vcpkg_cmake_get_vars() reuses
# the per-triplet build directory for its compiler probe.
set(AE_TEST_DIR "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
set(AE_TEST_BUILD_DIR "${AE_TEST_DIR}/build")
file(MAKE_DIRECTORY "${AE_TEST_BUILD_DIR}")
file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/bench"
    DESTINATION "${AE_TEST_BUILD_DIR}"
    USE_SOURCE_PERMISSIONS)

# Build a focused 2D FFT client for the CLI evaluation.  It uses the same
# installed FFTW library while avoiding unrelated behavior in the upstream
# multi-purpose benchmark driver.
vcpkg_cmake_get_vars(vars)
include("${vars}")
vcpkg_execute_required_process(
    COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -O2
        "${CMAKE_CURRENT_LIST_DIR}/lorelei/fftw-ae.c"
        "-I${CURRENT_PACKAGES_DIR}/include" "-L${CURRENT_PACKAGES_DIR}/lib"
        -lfftw3 -lm -o "${AE_TEST_DIR}/fftw-ae"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME build-ae-fftw
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
file(INSTALL "${SOURCE_PATH}/" DESTINATION "${CURRENT_PACKAGES_DIR}/tools/fftw3/upstream-tests/source" USE_SOURCE_PERMISSIONS)
