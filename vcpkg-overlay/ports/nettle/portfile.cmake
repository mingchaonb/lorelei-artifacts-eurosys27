vcpkg_download_distfile(ARCHIVE
    URLS "https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz"
    FILENAME "nettle-3.10.2.tar"
    SHA512 bf37ddd7dca8e78488da2a5286dcf16761d527d620572b42f2ad27bb8ee8c12999d92b0272e06f53766e7155a3f4a1ab7ad9c4b1c3caec47c031878b6b1772fb
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}"
    PATCHES
        patches/fix-emulator-detection.patch
)
set(NETTLE_CROSS_OPTIONS)
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    list(APPEND NETTLE_CROSS_OPTIONS --host=x86_64-linux-gnu)
endif()
vcpkg_configure_make(
    SOURCE_PATH "${SOURCE_PATH}"
    AUTOCONFIG
    OPTIONS
        --disable-static
        --disable-documentation
        --disable-openssl
        --disable-assembler
        --disable-public-key
        ${NETTLE_CROSS_OPTIONS}
)
vcpkg_install_make()
set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")

# Build every test selected by this exact configure.  The recording emulator
# prevents cross executables from running during packaging and captures the
# authoritative upstream order instead of duplicating a hand-written list.
set(TEST_ROOT "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${TEST_ROOT}")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/tests/record-test.sh"
    DESTINATION "${CURRENT_BUILDTREES_DIR}"
    FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
set(RECORD_TEST "${CURRENT_BUILDTREES_DIR}/record-test.sh")
file(WRITE "${TEST_ROOT}/manifest.tsv"
    "tools\tsexp-conv-test\ntools\tpkcs1-conv-test\ntools\tnettle-pbkdf2-test\n"
    "testsuite\tsymbols-test\n"
    "examples\trsa-sign-test\nexamples\trsa-verify-test\nexamples\trsa-encrypt-test\n")
foreach(SUBDIR testsuite)
    set(GROUP_MANIFEST "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-${SUBDIR}-tests.txt")
    file(REMOVE "${GROUP_MANIFEST}")
    vcpkg_execute_required_process(
        COMMAND "${CMAKE_COMMAND}" -E env "LORELEI_TEST_MANIFEST=${GROUP_MANIFEST}"
            make -j${VCPKG_CONCURRENCY} check "EMULATOR=${RECORD_TEST}"
        WORKING_DIRECTORY "${BUILD_DIR}/${SUBDIR}"
        LOGNAME "build-upstream-tests-${SUBDIR}"
    )
    file(STRINGS "${GROUP_MANIFEST}" GROUP_TESTS)
    file(COPY "${SOURCE_PATH}/${SUBDIR}/" DESTINATION "${TEST_ROOT}/${SUBDIR}")
    foreach(TEST_PATH IN LISTS GROUP_TESTS)
        get_filename_component(TEST_NAME "${TEST_PATH}" NAME)
        file(INSTALL "${BUILD_DIR}/${SUBDIR}/${TEST_NAME}"
            DESTINATION "${TEST_ROOT}/${SUBDIR}"
            FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
        file(APPEND "${TEST_ROOT}/manifest.tsv" "${SUBDIR}\t${TEST_NAME}\n")
    endforeach()
endforeach()
foreach(SUBDIR tools examples)
    file(COPY "${SOURCE_PATH}/${SUBDIR}/" DESTINATION "${TEST_ROOT}/${SUBDIR}")
endforeach()
file(INSTALL "${BUILD_DIR}/tools/nettle-pbkdf2" "${BUILD_DIR}/tools/sexp-conv"
    DESTINATION "${TEST_ROOT}/tools"
    FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
file(INSTALL "${SOURCE_PATH}/run-tests" DESTINATION "${TEST_ROOT}"
    FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

# A small part of the upstream suite directly exercises internal algorithm
# entry points.  Install only the declarations needed by those already-built
# tests so TLC can describe the same symbols exported by libnettle.
file(MAKE_DIRECTORY "${TEST_ROOT}/include")
file(INSTALL
    "${SOURCE_PATH}/ghash-internal.h"
    "${SOURCE_PATH}/poly1305-internal.h"
    DESTINATION "${TEST_ROOT}/include")

# The x86-64 guest thunk links read-only metadata and two internal helpers
# locally because cross-architecture DATA objects are outside the TLC ABI.
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    file(GLOB META_OBJECTS "${BUILD_DIR}/*-meta.o" "${BUILD_DIR}/nettle-meta-*.o")
    file(INSTALL ${META_OBJECTS}
        "${BUILD_DIR}/chacha-core-internal.o" "${BUILD_DIR}/write-be32.o"
        DESTINATION "${TEST_ROOT}/guest-support")
endif()

# Install a self-contained TLC description made only from public package
# headers.  The evaluator never needs the vcpkg buildtree to generate thunks.
file(GLOB PUBLIC_HEADERS "${CURRENT_PACKAGES_DIR}/include/nettle/*.h")
list(SORT PUBLIC_HEADERS)
file(WRITE "${TEST_ROOT}/Desc.h" "#pragma once\n\n")
foreach(HEADER IN LISTS PUBLIC_HEADERS)
    get_filename_component(HEADER_NAME "${HEADER}" NAME)
    if(NOT HEADER_NAME MATCHES "^(asn1|bignum|curve25519|curve448|dsa|dsa-compat|ecc|ecc-curve|ecdsa|eddsa|gostdsa|pgp|pkcs1|pss|pss-mgf1|rsa|sexp)\\.h$")
        file(APPEND "${TEST_ROOT}/Desc.h" "#include <nettle/${HEADER_NAME}>\n")
    endif()
endforeach()
file(APPEND "${TEST_ROOT}/Desc.h"
    "#include \"ghash-internal.h\"\n#include \"poly1305-internal.h\"\n")
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
vcpkg_install_copyright(FILE_LIST
    "${SOURCE_PATH}/COPYING.LESSERv3" "${SOURCE_PATH}/COPYINGv2" "${SOURCE_PATH}/COPYINGv3")
