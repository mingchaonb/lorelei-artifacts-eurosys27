#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: ${GAME_RUNNER_NAME:-run.sh} [--lane LANE] [SECONDS]

Run one packaged game in the selected execution lane. SECONDS is the watchdog
duration and defaults to 30. LANE defaults to qemu-hecate and may be native,
qemu-hecate, box64, or box64-hecate.

Common environment overrides:
  LORELEI_DEVKIT        Lorelei devkit installation
  QEMU                  Patched qemu-x86_64 executable
  BOX64                 Box64 executable
  GAME_LANE             Default lane when --lane is omitted
  GAMES_ROOT            Legacy packaged game directory override
  GAME_DIR              Selected game's installation directory
  GUI_ENV               Optional file overriding DISPLAY and XAUTHORITY
  RUNTIME_HOME_ROOT     Per-game writable home directories
  MANGOHUD_ENABLED      Set to 0 to disable FPS collection
  MANGOHUD_CONFIG_EXTRA  Additional comma-separated MangoHud options
  HOLLOW_USE_VULKAN  Set to 1 for Hollow Knight's optional Vulkan path

Debug environment overrides:
  QEMU_DEBUG QEMU_GDB_PORT QEMU_STRACE GUEST_LD_DEBUG
EOF
}

game=${1:?Internal error: missing game name}
shift
lane=${GAME_LANE:-qemu-hecate}
run_seconds=30
seconds_set=false
while (($#)); do
    case $1 in
        --lane)
            shift
            lane=${1:?--lane requires a value}
            ;;
        --lane=*) lane=${1#*=} ;;
        -h|--help) usage; exit 0 ;;
        --*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *)
            if $seconds_set; then
                echo "Unexpected positional argument: $1" >&2
                usage >&2
                exit 2
            fi
            run_seconds=$1
            seconds_set=true
            ;;
    esac
    shift
done
case $lane in
    native|qemu-hecate|box64|box64-hecate) ;;
    *) echo "Unknown game lane: $lane" >&2; usage >&2; exit 2 ;;
esac
if [[ ! $run_seconds =~ ^[1-9][0-9]*$ ]]; then
    echo "SECONDS must be a positive integer: $run_seconds" >&2
    exit 2
fi
recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
rover_root=$(cd "$repo_root/.." && pwd)
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
export LORELEI_DEVKIT=$devkit
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
box64=$(realpath -m "${BOX64:-$repo_root/vcpkg/installed/arm64-linux/tools/box64-ae/box64}")
games_root=${GAMES_ROOT:-$rover_root/ae-games}
runtime_home_root=${RUNTIME_HOME_ROOT:-$repo_root/.work/evaluations/games/runtime-home}
mangohud_enabled=${MANGOHUD_ENABLED:-1}
mangohud=
if [[ $mangohud_enabled == 1 ]]; then
    mangohud=$(command -v mangohud || true)
    [[ -x $mangohud ]] || { echo "MangoHud is enabled but mangohud was not found" >&2; exit 2; }
    mangohud_library=$(find /usr/lib -type f -path '*/mangohud/libMangoHud.so' 2>/dev/null | head -1)
    mangohud_dlsym_library=$(find /usr/lib -type f -path '*/mangohud/libMangoHud_dlsym.so' 2>/dev/null | head -1)
    [[ -f $mangohud_library ]] || { echo "MangoHud is enabled but libMangoHud.so was not found" >&2; exit 2; }
    [[ -f $mangohud_dlsym_library ]] || { echo "MangoHud is enabled but libMangoHud_dlsym.so was not found" >&2; exit 2; }
elif [[ $mangohud_enabled != 0 ]]; then
    echo "MANGOHUD_ENABLED must be 0 or 1: $mangohud_enabled" >&2
    exit 2
fi

display=${DISPLAY:-}
xauthority=${XAUTHORITY:-}
if [[ -n ${GUI_ENV:-} ]]; then
    [[ -f $GUI_ENV ]] || { echo "GUI environment file not found: $GUI_ENV" >&2; exit 2; }
    display=$(sed -n 's/^DISPLAY=//p' "$GUI_ENV" | tail -1)
    xauthority=$(sed -n 's/^XAUTHORITY=//p' "$GUI_ENV" | tail -1)
fi
[[ -n $display && -n $xauthority ]] || {
    echo "Set DISPLAY and XAUTHORITY, or provide both through GUI_ENV." >&2
    exit 2
}

sdl_prefix=$repo_root/.work/evaluations/sdl2/installed/hecate/arm64-linux-ae
sdl_thunk=$repo_root/.work/evaluations/sdl2/thunks/hecate
sdl_image_prefix=$repo_root/.work/evaluations/sdl2-image/installed/hecate/arm64-linux-ae
sdl_image_thunk=$repo_root/.work/evaluations/sdl2-image/thunks/SDL2_image
sdl_mixer_prefix=$repo_root/.work/evaluations/sdl2-mixer/installed/hecate/arm64-linux-ae
sdl_mixer_thunk=$repo_root/.work/evaluations/sdl2-mixer/thunks/SDL2_mixer
sdl1_prefix=$repo_root/.work/evaluations/sdl1/installed/hecate/arm64-linux-ae
sdl1_thunk=$repo_root/.work/evaluations/sdl1/thunks/hecate
gl_prefix=$repo_root/.work/evaluations/glvnd/installed/arm64-linux-ae
vk_prefix=$repo_root/.work/evaluations/vulkan-loader/installed/arm64-linux-ae
xcb_thunk=$repo_root/.work/evaluations/libxcb/thunks/hecate
x11_thunk=$repo_root/.work/evaluations/libx11/thunk

native_game_prefix=
guest_game_prefix=
selected_game_prefix=
if [[ $game == hollow-knight && $lane == native ]]; then
    echo "The native lane is unavailable for Hollow Knight because the artifact cannot distribute an ARM64 game package." >&2
    exit 2
fi
if [[ $game != hollow-knight && -z ${GAMES_ROOT:-} && -z ${GAME_DIR:-} ]]; then
    game_work_dir=$repo_root/.work/evaluations/games/$game
    game_installed=$game_work_dir/installed
    native_game_prefix=$game_installed/arm64-linux-ae
    guest_game_prefix=$game_installed/x64-linux-ae
    if [[ $lane == native ]]; then
        selected_game_prefix=$native_game_prefix
    else
        selected_game_prefix=$guest_game_prefix
    fi
    [[ -d $selected_game_prefix ]] || {
        echo "Game package is not installed for lane $lane: $game" >&2
        echo "Run evaluations/install-games.sh inside the evaluation container first." >&2
        exit 2
    }
fi

case $lane in
    native) ;;
    box64)
        [[ -x $box64 ]] || { echo "Missing Box64 executable: $box64" >&2; exit 2; }
        [[ -d $devkit/x86_64/sysroot ]] || { echo "Missing guest sysroot: $devkit/x86_64/sysroot" >&2; exit 2; }
        ;;
    qemu-hecate|box64-hecate)
        emulator=$qemu
        [[ $lane == box64-hecate ]] && emulator=$box64
        for required in "$emulator" "$devkit/bin/x86_64-linux-gnu-clang" \
            "$devkit/x86_64/sysroot" "$devkit/lib/libLoreHostHLRExtension.so" \
            "$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
            "$sdl_thunk/x86_64/libSDL2.so" \
            "$sdl_image_thunk/x86_64/libSDL2_image-2.0.so.0" \
            "$sdl_mixer_thunk/x86_64/libSDL2_mixer-2.0.so.0" \
            "$x11_thunk/x86_64/libX11.so.6" \
            "$sdl_prefix/share/libxrandr/thunk/x86_64/libXrandr.so.2" \
            "$gl_prefix/share/glvnd/thunk/x86_64/libGL.so" \
            "$gl_prefix/share/glvnd/glx-thunk/x86_64/libGLX.so.0" \
            "$vk_prefix/share/vulkan-loader/thunk/x86_64/libvulkan.so"; do
            [[ -e $required ]] || { echo "Missing runtime input: $required" >&2; exit 2; }
        done
        ;;
esac

resolve_game_dir() {
    realpath -m "${GAME_DIR:-$1}"
}

case "$game" in
    assaultcube)
        if [[ -n $selected_game_prefix ]]; then
            default_game_dir=$selected_game_prefix/tools/assaultcube/game
        else
            default_game_dir=$games_root/assaultcube
        fi
        game_dir=$(resolve_game_dir "$default_game_dir")
        executable=$game_dir/bin_unix/linux_64_client
        game_library_path=${selected_game_prefix:+$selected_game_prefix/lib}
        game_args=("--home=$runtime_home_root/assaultcube" --init)
        ;;
    hollow-knight)
        game_dir=$(resolve_game_dir "$games_root/hollow-knight/game")
        executable=$game_dir/Hollow\ Knight
        game_library_path="$game_dir:$game_dir/Hollow Knight_Data/MonoBleedingEdge/x86_64"
        if [[ ${HOLLOW_USE_VULKAN:-0} == 1 ]]; then
            game_args=(-force-vulkan -force-gfx-direct -screen-width 1280 -screen-height 720
                -screen-fullscreen 0)
        else
            game_args=(-force-glcore -screen-width 1280 -screen-height 720 -screen-fullscreen 0)
        fi
        ;;
    redeclipse)
        if [[ -n $selected_game_prefix ]]; then
            default_game_dir=$selected_game_prefix/tools/redeclipse/game
        else
            default_game_dir=$games_root/redeclipse
        fi
        game_dir=$(resolve_game_dir "$default_game_dir")
        executable=$game_dir/bin/amd64/redeclipse_linux
        game_library_path=$game_dir/bin/amd64
        game_args=()
        ;;
    openarena)
        if [[ -n $selected_game_prefix ]]; then
            default_game_dir=$selected_game_prefix/tools/openarena/game
        else
            default_game_dir=$games_root/openarena
        fi
        game_dir=$(resolve_game_dir "$default_game_dir")
        executable=$game_dir/openarena.x86_64
        game_library_path=${selected_game_prefix:+$selected_game_prefix/lib}
        game_args=(+set r_fullscreen 0 +set r_mode -1 +set r_customwidth 1280
            +set r_customheight 720 +set com_introplayed 1)
        if [[ $lane == qemu-hecate || $lane == box64-hecate ]]; then
            for required in "$sdl1_thunk/x86_64/libSDL.so" \
                "$sdl1_thunk/x86_64/libSDL-1.2.so.0" \
                "$sdl1_prefix/lib/libSDL-1.2.so.0" \
                "$sdl1_prefix/share/sdl1/ThunkDB.json"; do
                [[ -e $required ]] || { echo "Missing SDL 1.2 runtime input: $required" >&2; exit 2; }
            done
        fi
        # ioquake3 leaves this crash marker when a watchdog ends a run. Remove
        # only a stale marker, otherwise the next automated run blocks on a
        # host-side Zenity safe-mode dialog before SDL is initialized.
        openarena_pid_file=/tmp/ioq3+oa.pid
        if [[ -f $openarena_pid_file ]]; then
            openarena_old_pid=$(<"$openarena_pid_file")
            if [[ ! $openarena_old_pid =~ ^[0-9]+$ ]] || ! kill -0 "$openarena_old_pid" 2>/dev/null; then
                cmake -E remove "$openarena_pid_file"
            fi
        fi
        ;;
    supertux)
        if [[ -n $selected_game_prefix ]]; then
            default_game_dir=$selected_game_prefix/tools/supertux/game/usr
        else
            default_game_dir=$games_root/supertux
        fi
        game_dir=$(resolve_game_dir "$default_game_dir")
        if [[ -x $game_dir/bin/supertux2 ]]; then
            executable=$game_dir/bin/supertux2
            if [[ $lane == native && -n $selected_game_prefix ]]; then
                game_library_path=$selected_game_prefix/tools/supertux/game/lib
                game_args=(--datadir "$game_dir/share/games/supertux2")
            else
                game_library_path=$game_dir/lib/x86_64-linux-gnu
                game_args=(--datadir "$game_dir/share/supertux2")
            fi
        else
            executable=$game_dir/build/RelWithDebInfo/supertux2
            game_library_path=$game_dir/runtime-libs
            game_args=(--datadir "$game_dir/build/install/share/games/supertux2")
        fi
        ;;
    supertuxkart)
        if [[ -n $selected_game_prefix ]]; then
            default_game_dir=$selected_game_prefix/tools/supertuxkart/game
        else
            default_game_dir=$games_root/supertuxkart
        fi
        game_dir=$(resolve_game_dir "$default_game_dir")
        executable=$game_dir/bin/supertuxkart
        game_library_path=$game_dir/lib
        game_args=()
        ;;
    *)
        echo "Unknown or excluded game: $game" >&2
        exit 2
        ;;
esac

if [[ ! -x $executable ]]; then
    echo "Game executable not found: $executable" >&2
    echo "Set GAME_DIR to the selected game's installation directory." >&2
    exit 2
fi

run_id=$(date -u +%Y%m%dT%H%M%SZ)-$lane
game_recipe_dir=$(realpath -m "$recipe_dir/../$game")
run_dir=$game_recipe_dir/results/$run_id
game_home=$runtime_home_root/$game
mkdir -p "$run_dir/logs/preflight" "$game_home"

host_xorg=("$x11_thunk")
guest_xorg=("$x11_thunk/x86_64")
for port in libxext libxrender libxrandr libxfixes libxi libxcursor libxscrnsaver \
    libxinerama libxxf86vm; do
    host_xorg+=("$sdl_prefix/share/$port/thunk")
    guest_xorg+=("$sdl_prefix/share/$port/thunk/x86_64")
done
host_xorg+=("$xcb_thunk")
guest_xorg+=("$xcb_thunk/x86_64")

join_colon() {
    local IFS=:
    echo "$*"
}

host_xorg_path=$(join_colon "${host_xorg[@]}")
guest_xorg_path=$(join_colon "${guest_xorg[@]}")
host_library_path="$host_xorg_path:$sdl1_thunk:$sdl1_prefix/lib:$sdl_prefix/lib:$sdl_thunk:$sdl_image_prefix/lib:$sdl_image_thunk:$sdl_mixer_prefix/lib:$sdl_mixer_thunk:$gl_prefix/share/glvnd/glx-thunk:$gl_prefix/share/glvnd/thunk:$gl_prefix/share/glvnd/x11-thunk:$gl_prefix/lib:$vk_prefix/share/vulkan-loader/thunk:$vk_prefix/lib"
guest_library_path="$guest_xorg_path:$gl_prefix/share/glvnd/x11-thunk/x86_64:$sdl1_thunk/x86_64:$sdl_thunk/x86_64:$sdl_image_thunk/x86_64:$sdl_mixer_thunk/x86_64:$gl_prefix/share/glvnd/glx-thunk/x86_64:$gl_prefix/share/glvnd/thunk/x86_64:$vk_prefix/share/vulkan-loader/thunk/x86_64"
if [[ -n $game_library_path ]]; then
    guest_library_path="$guest_library_path:$game_library_path"
fi
guest_library_path="$guest_library_path:$devkit/x86_64/lib:$devkit/x86_64/sysroot/lib/x86_64-linux-gnu:$devkit/x86_64/sysroot/usr/lib/x86_64-linux-gnu"
plain_guest_paths=()
if [[ -n $game_library_path ]]; then plain_guest_paths+=("$game_library_path"); fi
plain_guest_paths+=("$devkit/x86_64/lib" "$devkit/x86_64/sysroot/lib/x86_64-linux-gnu"
    "$devkit/x86_64/sysroot/usr/lib/x86_64-linux-gnu")
plain_guest_library_path=$(join_colon "${plain_guest_paths[@]}")
qemu_debug_args=()
if [[ -n ${QEMU_DEBUG:-} ]]; then
    qemu_debug_args=(-d "$QEMU_DEBUG" -D "$run_dir/qemu.log")
fi
if [[ -n ${QEMU_GDB_PORT:-} ]]; then
    qemu_debug_args+=(-g "$QEMU_GDB_PORT")
fi
if [[ -n ${QEMU_RESERVED_VA:-} ]]; then
    qemu_debug_args+=(-R "$QEMU_RESERVED_VA")
fi
if [[ ${QEMU_STRACE:-0} == 1 ]]; then
    qemu_debug_args+=(-strace)
fi
guest_preload_args=()
if [[ -n ${GUEST_PRELOAD:-} ]]; then
    guest_preload_args=(-E "LD_PRELOAD=$GUEST_PRELOAD")
fi
host_preload=${HOST_PRELOAD-}
preflight_host_preload=
if [[ $lane == qemu-hecate ]]; then
    host_preload=${HOST_PRELOAD-$devkit/lib/libLoreHostRT.so:$devkit/lib/libLoreQEMUThreadHook.so}
    preflight_host_preload=$host_preload
fi
thunk_databases="$repo_root/vcpkg-overlay/ports/glvnd/lorelei/ThunkDB.json:$repo_root/vcpkg-overlay/ports/vulkan-loader/lorelei/ThunkDB.json"
if [[ $game == openarena ]]; then
    thunk_databases="$sdl1_prefix/share/sdl1/ThunkDB.json:$thunk_databases"
fi
thunk_variables="SDL1_PREFIX=$sdl1_prefix;SDL1_THUNK=$sdl1_thunk;GLVND_PREFIX=$gl_prefix;VULKAN_PREFIX=$vk_prefix"
mangohud_env=()
if [[ $mangohud_enabled == 1 ]]; then
    mangohud_dir=$run_dir/mangohud
    mkdir -p "$mangohud_dir"
    # Leave enough time for MangoHud to flush both raw and summary CSV files
    # before the watchdog terminates games that do not expose a scripted quit.
    mangohud_duration=$((run_seconds > 10 ? run_seconds - 10 : 1))
    mangohud_config="no_display,autostart_log=1,log_duration=$mangohud_duration,log_interval=100,output_folder=$mangohud_dir"
    if [[ -n ${MANGOHUD_CONFIG_EXTRA:-} ]]; then
        mangohud_config="$mangohud_config,$MANGOHUD_CONFIG_EXTRA"
    fi
    mangohud_env=(MANGOHUD=1 MANGOHUD_CONFIG="$mangohud_config")
    # Preload MangoHud directly into QEMU.  Invoking its shell wrapper while
    # HostRT is already preloaded would initialize HostRT in /bin/sh before
    # the QEMU bridge symbol exists in the process.
    if [[ $game == hollow-knight ]]; then
        # Unity resolves GLX entry points dynamically. The dlsym interposer
        # makes its core-profile selection fail before the Hecate GL thunk can
        # map those addresses, so keep only the main MangoHud library here.
        mangohud_preload=$mangohud_library
    else
        mangohud_preload=$mangohud_dlsym_library:$mangohud_library
        mangohud_env+=(MANGOHUD_DLSYM=1)
    fi
    if [[ -n $host_preload ]]; then
        host_preload="$host_preload:$mangohud_preload"
    else
        host_preload=$mangohud_preload
    fi
fi
# Some older SDL 1.2 games change the physical XRandR mode and may be killed
# before restoring it. Preserve the active output and mode around every game so
# a failed experiment cannot leave the shared desktop at 640 by 480.
display_state=$(env DISPLAY="$display" XAUTHORITY="$xauthority" xrandr --current 2>/dev/null |
    awk '/ connected/{output=$1} /\*/{print output, $1; exit}')
restore_display_mode() {
    local output mode
    read -r output mode <<< "$display_state"
    if [[ -n ${output:-} && -n ${mode:-} ]]; then
        env DISPLAY="$display" XAUTHORITY="$xauthority" xrandr --output "$output" --mode "$mode" >/dev/null 2>&1 || true
    fi
}
trap restore_display_mode EXIT

# Compile the small guest probes from source for this devkit. The binaries are
# disposable work products; only their logs and exit statuses become evidence.
preflight_build=$repo_root/.work/evaluations/games/preflight-build
game_sdl_abi=2
preflight_sdl_cmake=(-DSDL2_PREFIX="$sdl_prefix" -DSDL2_THUNK="$sdl_thunk")
if [[ $game == openarena ]]; then
    game_sdl_abi=1
    preflight_sdl_cmake=(-DSDL2_PREFIX="$sdl_prefix"
        -DSDL1_PREFIX="$sdl1_prefix" -DSDL1_THUNK="$sdl1_thunk")
fi
preflight_build_log=$run_dir/logs/preflight/build.log
run_preflight_build_step() {
    local step=$1 status
    shift
    set +e
    "$@" >>"$preflight_build_log" 2>&1
    status=$?
    set -e
    if ((status != 0)); then
        echo "Game preflight $step failed with exit status $status" >&2
        echo "Log: $preflight_build_log" >&2
        tail -40 "$preflight_build_log" >&2
        exit "$status"
    fi
}
if [[ $lane == qemu-hecate || $lane == box64-hecate ]]; then
    cmake -E remove_directory "$preflight_build"
    : >"$preflight_build_log"
    run_preflight_build_step configure cmake -S "$recipe_dir/tests" -B "$preflight_build" \
        -DLORELEI_DEVKIT="$devkit" \
        "${preflight_sdl_cmake[@]}" \
        -DX11_THUNK="$x11_thunk" \
        -DXRANDR_THUNK="$sdl_prefix/share/libxrandr/thunk" \
        -DGLVND_PREFIX="$gl_prefix" -DVULKAN_PREFIX="$vk_prefix" \
        -DGAME_SDL_ABI="$game_sdl_abi"
    run_preflight_build_step build cmake --build "$preflight_build"
fi

run_preflight() {
    local name=$1 binary=$2 status
    set +e
    if [[ $lane == qemu-hecate ]]; then
        env \
            DISPLAY="$display" XAUTHORITY="$xauthority" \
            SDL_VIDEODRIVER=x11 SDL_AUDIODRIVER=dummy HOME="$game_home" \
            LORELEI_THUNK_DATABASE="$thunk_databases" \
            LORELEI_THUNKS_CONFIG_VARIABLES="$thunk_variables" \
            LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
            LD_PRELOAD="$preflight_host_preload" LD_LIBRARY_PATH="$host_library_path" \
            "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD \
            -E DISPLAY="$display" -E XAUTHORITY="$xauthority" \
            -E SDL_VIDEODRIVER=x11 -E SDL_AUDIODRIVER=dummy -E HOME="$game_home" \
            -E LORELEI_GUEST_LOG_LEVEL="${LORELEI_GUEST_LOG_LEVEL:-1}" \
            -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
            -E LD_LIBRARY_PATH="$guest_library_path" \
            "$binary" >"$run_dir/logs/preflight/$name.log" 2>&1
    else
        env \
            DISPLAY="$display" XAUTHORITY="$xauthority" \
            SDL_VIDEODRIVER=x11 SDL_AUDIODRIVER=dummy HOME="$game_home" \
            LORELEI_THUNK_DATABASE="$thunk_databases" \
            LORELEI_THUNKS_CONFIG_VARIABLES="$thunk_variables" \
            LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
            LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
            LD_LIBRARY_PATH="$host_library_path" \
            BOX64_LD_LIBRARY_PATH="$guest_library_path" \
            BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 \
            "$box64" "$binary" >"$run_dir/logs/preflight/$name.log" 2>&1
    fi
    status=$?
    set -e
    printf '%s\t%s\n' "$name" "$status" >>"$run_dir/preflight-status.tsv"
    if ((status != 0)); then
        echo "Game preflight failed: $name, exit status $status" >&2
        echo "Log: $run_dir/logs/preflight/$name.log" >&2
        tail -40 "$run_dir/logs/preflight/$name.log" >&2
        return "$status"
    fi
}

printf 'test\texit_status\n' >"$run_dir/preflight-status.tsv"
set +e
env DISPLAY="$display" XAUTHORITY="$xauthority" glxinfo -B \
    >"$run_dir/logs/preflight/host-glxinfo.log" 2>&1
host_glx_status=$?
set -e
printf 'host-glxinfo\t%s\n' "$host_glx_status" >>"$run_dir/preflight-status.tsv"
if ((host_glx_status != 0)); then
    echo "Host OpenGL preflight failed with exit status $host_glx_status" >&2
    echo "Log: $run_dir/logs/preflight/host-glxinfo.log" >&2
    tail -40 "$run_dir/logs/preflight/host-glxinfo.log" >&2
    exit "$host_glx_status"
fi
host_renderer=$(sed -n 's/^[[:space:]]*OpenGL renderer string:[[:space:]]*//p' \
    "$run_dir/logs/preflight/host-glxinfo.log" | head -1)
if [[ -z $host_renderer || $host_renderer =~ [Ll][Ll][Vv][Mm][Pp][Ii][Pp][Ee] ||
      $host_renderer =~ [Ss][Oo][Ff][Tt][Pp][Ii][Pp][Ee] ||
      $host_renderer =~ [Ss][Ww][Rr][Aa][Ss][Tt] ]]; then
    printf 'physical-gpu-renderer\t1\n' >>"$run_dir/preflight-status.tsv"
    echo "WARNING: Host OpenGL is not using a physical GPU: ${host_renderer:-unknown}" >&2
    echo "WARNING: The game will continue, but its FPS data is not valid performance evidence." >&2
else
    printf 'physical-gpu-renderer\t0\n' >>"$run_dir/preflight-status.tsv"
fi
if [[ $lane == qemu-hecate || $lane == box64-hecate ]]; then
    run_preflight xrandr "$preflight_build/test-xrandr"
    run_preflight multi-thunk-db "$preflight_build/test-multi-thunk-db"
    if [[ $game == openarena ]]; then
        run_preflight sdl1-video "$preflight_build/test-sdl1-video"
    else
        run_preflight sdl2-displays "$preflight_build/test-sdl2-displays"
    fi
fi

{
    echo "game=$game"
    echo "started=$(date -u +%FT%TZ)"
    echo "cwd=$game_dir"
    echo "executable=$executable"
    echo "watchdog_seconds=$run_seconds"
    echo "lane=$lane"
    echo "mangohud_enabled=$mangohud_enabled"
    echo "host_renderer=$host_renderer"
    echo "native_game_prefix=$native_game_prefix"
    echo "guest_game_prefix=$guest_game_prefix"
    echo "qemu=$qemu"
    echo "box64=$box64"
} > "$run_dir/run.env"

set +e
preexisting_windows=$(env DISPLAY="$display" XAUTHORITY="$xauthority" \
    xprop -root _NET_CLIENT_LIST 2>/dev/null || true)
(
    cd "$game_dir" || exit 2
    case $lane in
        native)
            env "${mangohud_env[@]}" \
                DISPLAY="$display" XAUTHORITY="$xauthority" \
                SDL_VIDEODRIVER=x11 SDL_AUDIODRIVER=dummy HOME="$game_home" \
                LD_PRELOAD="$host_preload" LD_LIBRARY_PATH="$game_library_path" \
                "$executable" "${game_args[@]}"
            ;;
        box64)
            env "${mangohud_env[@]}" \
                DISPLAY="$display" XAUTHORITY="$xauthority" \
                SDL_VIDEODRIVER=x11 SDL_AUDIODRIVER=dummy HOME="$game_home" \
                LD_PRELOAD="$host_preload" LD_LIBRARY_PATH="$devkit/lib" \
                BOX64_LD_LIBRARY_PATH="$plain_guest_library_path" \
                BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 \
                "$box64" "$executable" "${game_args[@]}"
            ;;
        box64-hecate)
            env "${mangohud_env[@]}" \
                DISPLAY="$display" XAUTHORITY="$xauthority" \
                SDL_VIDEODRIVER=x11 SDL_AUDIODRIVER=dummy HOME="$game_home" \
                LORELEI_THUNK_DATABASE="$thunk_databases" \
                LORELEI_THUNKS_CONFIG_VARIABLES="$thunk_variables" \
                LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
                LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
                LD_PRELOAD="$host_preload" LD_LIBRARY_PATH="$host_library_path" \
                BOX64_LD_LIBRARY_PATH="$guest_library_path" \
                BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 \
                "$box64" "$executable" "${game_args[@]}"
            ;;
        qemu-hecate)
            env "${mangohud_env[@]}" \
                DISPLAY="$display" XAUTHORITY="$xauthority" \
                SDL_VIDEODRIVER=x11 SDL_AUDIODRIVER=dummy HOME="$game_home" \
                LORELEI_THUNK_DATABASE="$thunk_databases" \
                LORELEI_THUNKS_CONFIG_VARIABLES="$thunk_variables" \
                LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
                LD_PRELOAD="$host_preload" LD_LIBRARY_PATH="$host_library_path" \
                "$qemu" "${qemu_debug_args[@]}" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD \
                "${guest_preload_args[@]}" \
                -E DISPLAY="$display" -E XAUTHORITY="$xauthority" \
                -E SDL_VIDEODRIVER=x11 -E SDL_AUDIODRIVER=dummy -E HOME="$game_home" \
                -E LD_DEBUG="${GUEST_LD_DEBUG:-}" \
                -E LORELEI_GUEST_LOG_LEVEL="${LORELEI_GUEST_LOG_LEVEL:-1}" \
                -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
                -E LD_LIBRARY_PATH="$guest_library_path" \
                "$executable" "${game_args[@]}"
            ;;
    esac
) > "$run_dir/game.log" 2>&1 &
game_pid=$!
window_probe_pid=
window_probe_seconds=${WINDOW_PROBE_SECONDS:-8}
if (( window_probe_seconds > 0 )); then
    (
        sleep "$window_probe_seconds"
        client_list=$(env DISPLAY="$display" XAUTHORITY="$xauthority" xprop -root _NET_CLIENT_LIST 2>/dev/null || true)
        for window_id in $(sed 's/.*# //; s/,//g' <<< "$client_list"); do
            env DISPLAY="$display" XAUTHORITY="$xauthority" \
                xprop -id "$window_id" WM_CLASS _NET_WM_NAME WM_NAME 2>/dev/null || true
            if ! grep -qw "$window_id" <<< "$preexisting_windows"; then
                echo "ACTIVATED_WINDOW=$window_id"
                env DISPLAY="$display" XAUTHORITY="$xauthority" \
                    xdotool windowactivate --sync "$window_id" 2>/dev/null || true
                break
            fi
        done
    ) > "$run_dir/x11-windows.txt" &
    window_probe_pid=$!
fi
(
    sleep "$run_seconds"
    touch "$run_dir/watchdog-fired"
    if [[ $game == openarena ]]; then
        window_id=$(env DISPLAY="$display" XAUTHORITY="$xauthority" \
            xdotool search --onlyvisible --name '^OpenArena$' 2>/dev/null | tail -1)
        if [[ -n $window_id ]]; then
            env DISPLAY="$display" XAUTHORITY="$xauthority" xdotool windowactivate --sync "$window_id" \
                key --window "$window_id" shift+Escape type --window "$window_id" --delay 40 quit \
                key --window "$window_id" Return 2>/dev/null || true
            sleep 3
        fi
    fi
    kill -0 "$game_pid" 2>/dev/null || exit 0
    kill -TERM "$game_pid" 2>/dev/null || exit 0
    sleep 2
    if kill -0 "$game_pid" 2>/dev/null; then
        touch "$run_dir/watchdog-killed"
        kill -KILL "$game_pid" 2>/dev/null || true
    fi
) &
watchdog_pid=$!
wait "$game_pid"
status=$?
kill "$watchdog_pid" 2>/dev/null
wait "$watchdog_pid" 2>/dev/null
if [[ -n $window_probe_pid ]]; then
    wait "$window_probe_pid" 2>/dev/null
fi
set -e

restore_display_mode
trap - EXIT
if [[ $game == openarena && -f ${openarena_pid_file:-} ]]; then
    openarena_old_pid=$(<"$openarena_pid_file")
    if [[ ! $openarena_old_pid =~ ^[0-9]+$ ]] || ! kill -0 "$openarena_old_pid" 2>/dev/null; then
        cmake -E remove "$openarena_pid_file"
    fi
fi

echo "$status" > "$run_dir/status.txt"
if [[ $mangohud_enabled == 1 ]]; then
    raw_csv=$(find "$mangohud_dir" -maxdepth 1 -type f -name '*.csv' ! -name '*_summary.csv' | sort | head -1)
    summary_csv=$(find "$mangohud_dir" -maxdepth 1 -type f -name '*_summary.csv' | sort | head -1)
    if [[ -n $raw_csv && -n $summary_csv ]]; then
        python3 "$recipe_dir/summarize-mangohud.py" \
            "$run_dir/fps-summary.json" "$raw_csv" "$summary_csv"
        echo collected >"$run_dir/fps-status.txt"
    else
        echo missing >"$run_dir/fps-status.txt"
        echo "MangoHud produced no complete FPS log under $mangohud_dir" >&2
    fi
else
    echo disabled >"$run_dir/fps-status.txt"
fi
echo "Evidence: $run_dir"
echo "Exit status: $status"
