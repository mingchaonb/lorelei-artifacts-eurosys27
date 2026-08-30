# Fetch the exact official FFmpeg 7.1.5 commit used by both AE lanes.
vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://github.com/FFmpeg/FFmpeg.git
    REF 3a0867c2bfda4a4d4309ca1a8cbdc6175e67f587
    HEAD_REF master
)

# The ordinary package is used for both native AArch64 and guest x86-64 roots.
# The hlr feature installs the seven rewritten AArch64 host DSOs.
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

set(TEST_SOURCE "${SOURCE_PATH}")

# Resolve the compiler selected by the native or guest AE triplet.
vcpkg_cmake_get_vars(CMAKE_VARS_FILE)
include("${CMAKE_VARS_FILE}")
set(NATIVE_CC "${VCPKG_DETECTED_CMAKE_C_COMPILER}")
set(NATIVE_CXX "${VCPKG_DETECTED_CMAKE_CXX_COMPILER}")
if(NOT NATIVE_CC)
    set(NATIVE_CC cc)
endif()
if(NOT NATIVE_CXX)
    set(NATIVE_CXX c++)
endif()
find_program(MAKE NAMES gmake make REQUIRED)

# FFmpeg does not natively emit compile_commands.json. The HLR lane routes the
# initial C build through a transparent compiler wrapper. It records the exact
# commands while executing the compiler selected by the vcpkg triplet.
if(RUN_HLR)
    vcpkg_find_acquire_program(PYTHON3)
    set(REAL_NATIVE_CC "${NATIVE_CC}")
    set(CAPTURE_CC "${CURRENT_BUILDTREES_DIR}/ffmpeg-capture-cc")
    file(COPY_FILE "${CMAKE_CURRENT_LIST_DIR}/capture-cc.py" "${CAPTURE_CC}")
    file(CHMOD "${CAPTURE_CC}"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    set(COMPILE_CAPTURE_LOG "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/compile-commands.jsonl")
    set(ENV{FFMPEG_REAL_CC} "${REAL_NATIVE_CC}")
    set(ENV{FFMPEG_COMPILE_LOG} "${COMPILE_CAPTURE_LOG}")
    set(NATIVE_CC "${CAPTURE_CC}")
endif()

# Make configure discover only target dependencies installed by vcpkg.
set(ENV{PKG_CONFIG_PATH} "${CURRENT_INSTALLED_DIR}/lib/pkgconfig:${CURRENT_INSTALLED_DIR}/share/pkgconfig")
set(ENV{PKG_CONFIG_LIBDIR} "$ENV{PKG_CONFIG_PATH}")

# Shared options define the symmetric, no-samples FATE configuration. The HLR
# host adds the four external encoders used by the historical FFmpeg workload.
set(COMMON_OPTIONS
    --target-os=linux
    --enable-shared
    --disable-static
    --disable-doc
    --disable-debug
    --disable-network
    --disable-autodetect
    --disable-everything
    --disable-postproc
    --disable-stripping
    --enable-avcodec
    --enable-avformat
    --enable-avfilter
    --enable-avdevice
    --enable-swresample
    --enable-swscale
    --enable-ffmpeg
    --enable-ffprobe
    --enable-decoder=wrapped_avframe
    --enable-protocol=file,pipe
    --enable-indev=lavfi
    --enable-filter=sine,testsrc2,aformat,format,aresample,scale
)

# Configure and build this triplet's package.
set(PRIMARY_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
file(REMOVE_RECURSE "${PRIMARY_BUILD}")
file(MAKE_DIRECTORY "${PRIMARY_BUILD}")
set(PRIMARY_CFLAGS "-I${CURRENT_INSTALLED_DIR}/include")
set(PRIMARY_OPTIONS
    ${COMMON_OPTIONS}
    --prefix=${CURRENT_PACKAGES_DIR}
    --cc=${NATIVE_CC}
    --cxx=${NATIVE_CXX}
    "--extra-cflags=${PRIMARY_CFLAGS}"
    --extra-ldflags=-L${CURRENT_INSTALLED_DIR}/lib
)
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    list(APPEND PRIMARY_OPTIONS
        --arch=x86_64
        --enable-cross-compile
        --disable-x86asm
        --sysroot=$ENV{LORELEI_DEVKIT}/x86_64/sysroot
    )
else()
    list(APPEND PRIMARY_OPTIONS --arch=aarch64)
endif()
if(RUN_HLR)
    string(APPEND PRIMARY_CFLAGS " -I$ENV{LORELEI_DEVKIT}/include")
    list(REMOVE_ITEM PRIMARY_OPTIONS "--extra-cflags=-I${CURRENT_INSTALLED_DIR}/include")
    list(APPEND PRIMARY_OPTIONS
        "--extra-cflags=${PRIMARY_CFLAGS}"
        --enable-gpl
        --enable-nonfree
        --enable-libmp3lame
        --enable-libfdk-aac
        --enable-libvorbis
        --enable-libx264
        --enable-encoder=libmp3lame,libfdk_aac,libvorbis,libx264
        --enable-decoder=mp3,aac,vorbis,h264,pcm_s16le,rawvideo,wrapped_avframe
        --enable-muxer=mp3,adts,ogg,matroska,null,framecrc
        --enable-demuxer=mp3,aac,ogg,matroska
        --enable-parser=mpegaudio,aac,h264,vorbis
    )
endif()
vcpkg_execute_required_process(
    COMMAND "${SOURCE_PATH}/configure" ${PRIMARY_OPTIONS}
    WORKING_DIRECTORY "${PRIMARY_BUILD}"
    LOGNAME configure-primary
)
vcpkg_execute_build_process(
    COMMAND "${MAKE}" -j${VCPKG_CONCURRENCY}
    WORKING_DIRECTORY "${PRIMARY_BUILD}"
    LOGNAME build-primary
)

if(RUN_HLR)
    # Generate seven independent FileContexts from the just-built DSOs and the
    # captured translation-unit closures. Generated source and statistics stay
    # in the disposable buildtree, never in the overlay port.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${CMAKE_CURRENT_LIST_DIR}/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --build "${PRIMARY_BUILD}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --output "${HLR_AUDIT_DIR}"
            --installed-include "${CURRENT_INSTALLED_DIR}/include"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # Automatic rewriting stops before two reviewed FFmpeg-specific changes.
    # Static descriptor fields must remain compile-time constants, and each
    # version script must export the HLR runtime's FileContext entry point.
    find_program(PATCH_EXECUTABLE NAMES patch REQUIRED)
    foreach(POST_HLR_PATCH IN ITEMS static-descriptors.patch export-file-context.patch)
        vcpkg_execute_required_process(
            COMMAND "${PATCH_EXECUTABLE}" --dry-run --batch -p1
                -i "${CMAKE_CURRENT_LIST_DIR}/patches/${POST_HLR_PATCH}"
            WORKING_DIRECTORY "${SOURCE_PATH}"
            LOGNAME post-hlr-${POST_HLR_PATCH}-check
        )
        vcpkg_execute_required_process(
            COMMAND "${PATCH_EXECUTABLE}" --batch -p1
                -i "${CMAKE_CURRENT_LIST_DIR}/patches/${POST_HLR_PATCH}"
            WORKING_DIRECTORY "${SOURCE_PATH}"
            LOGNAME post-hlr-${POST_HLR_PATCH}-apply
        )
    endforeach()

    # Rebuild only the sources changed by HLR and the post-HLR patches.
    vcpkg_execute_build_process(
        COMMAND "${MAKE}" -j${VCPKG_CONCURRENCY}
        WORKING_DIRECTORY "${PRIMARY_BUILD}"
        LOGNAME build-hlr
    )
endif()

# Every package installs the tests configured for its own architecture.
set(TEST_BUILD "${PRIMARY_BUILD}")

# FATE builds many test executables lazily. A no-op target executor forces their
# compilation during packaging. Expected comparison failures are ignored here
# because this is preparation, not a claimed test run.
execute_process(
    COMMAND "${MAKE}" -k -j${VCPKG_CONCURRENCY} fate fate-hw TARGET_EXEC=/bin/true
    WORKING_DIRECTORY "${TEST_BUILD}"
    RESULT_VARIABLE FATE_PREPARE_RESULT
    OUTPUT_FILE "${CURRENT_BUILDTREES_DIR}/fate-prepare-${TARGET_TRIPLET}.log"
    ERROR_FILE "${CURRENT_BUILDTREES_DIR}/fate-prepare-${TARGET_TRIPLET}.log"
)
# The preparation pass exists only to compile lazy FATE executables. Do not
# package its generated outputs: stale result files can make a later evaluator
# run appear up to date and silently skip a registered test.
file(REMOVE_RECURSE "${TEST_BUILD}/tests/data")
# The compiler capture has already been reduced to the seven installed audit
# source lists. Do not duplicate its large intermediate log in upstream-tests.
file(REMOVE "${TEST_BUILD}/compile-commands.jsonl" "${TEST_BUILD}/compile_commands.json")

# Install all seven primary DSOs, public headers, ffmpeg, and ffprobe.
vcpkg_execute_required_process(
    COMMAND "${MAKE}" install
    WORKING_DIRECTORY "${PRIMARY_BUILD}"
    LOGNAME install-primary
)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")

# Install the complete configured upstream test tree at the same path in both
# packages. The relative src link makes the copied build independent of vcpkg's
# disposable source and buildtree directories.
set(TEST_ROOT "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(INSTALL "${TEST_BUILD}/" DESTINATION "${TEST_ROOT}/build" USE_SOURCE_PERMISSIONS)
file(INSTALL "${TEST_SOURCE}/" DESTINATION "${TEST_ROOT}/source" USE_SOURCE_PERMISSIONS
    PATTERN ".git" EXCLUDE)
# fate-source asks Git about the FFmpeg snapshot. Without a repository marker,
# Git can walk upward into the AE repository and inspect the wrong project.
# An intentionally invalid local gitfile makes its documented no-Git fallback
# emit the upstream reference result instead.
file(WRITE "${TEST_ROOT}/source/.git"
    "Installed FFmpeg source snapshot; Git metadata is intentionally absent.\n")
file(REMOVE "${TEST_ROOT}/build/src")
file(CREATE_LINK "../source" "${TEST_ROOT}/build/src" SYMBOLIC)
# FFmpeg's out-of-tree build creates a one-line top-level Makefile whose
# include target is the absolute source-tree Makefile. Recreate that launcher
# with the relative source link so the installed suite remains usable after
# vcpkg's buildtrees directory is removed.
file(WRITE "${TEST_ROOT}/build/Makefile" "include src/Makefile\n")
# Point the copied Make configuration at the relative source link instead of
# vcpkg's disposable absolute source directory. This is required in particular
# by fate-source and also makes the installed suite genuinely self-contained.
file(READ "${TEST_ROOT}/build/ffbuild/config.mak" TEST_CONFIG_MAK)
string(REPLACE "SRC_PATH=${SOURCE_PATH}" "SRC_PATH=src" TEST_CONFIG_MAK "${TEST_CONFIG_MAK}")
file(WRITE "${TEST_ROOT}/build/ffbuild/config.mak" "${TEST_CONFIG_MAK}")

# Preserve analysis statistics and source closures for inspection. The generated
# source remains a build product and is deliberately not installed as port data.
if(RUN_HLR)
    foreach(HLR_LIBRARY IN ITEMS avutil swresample swscale avcodec avformat avfilter avdevice)
        file(INSTALL
            "${HLR_AUDIT_DIR}/${HLR_LIBRARY}/TLC-ThunkStat.json"
            "${HLR_AUDIT_DIR}/${HLR_LIBRARY}/HLR-Stat.json"
            "${HLR_AUDIT_DIR}/${HLR_LIBRARY}/hlr-sources.txt"
            DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/hlr-audit/${HLR_LIBRARY}")
    endforeach()
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING.LGPLv2.1" "${SOURCE_PATH}/COPYING.GPLv2")
