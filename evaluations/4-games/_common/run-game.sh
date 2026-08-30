#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: ${GAME_RUNNER_NAME:-run.sh} [SECONDS]

Run one packaged x86-64 game through QEMU plus Hecate. SECONDS is the
watchdog duration and defaults to 30.

Common environment overrides:
  LORELEI_DEVKIT        Lorelei devkit installation
  QEMU                  Patched qemu-x86_64 executable
  GAMES_ROOT            Packaged game directory
  GUI_ENV               File containing DISPLAY and XAUTHORITY
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
if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    usage
    exit 0
fi
if (($# > 1)); then
    usage >&2
    exit 2
fi

run_seconds=${1:-30}
if [[ ! $run_seconds =~ ^[1-9][0-9]*$ ]]; then
    echo "SECONDS must be a positive integer: $run_seconds" >&2
    exit 2
fi
recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
rover_root=$(cd "$repo_root/.." && pwd)
devkit=$(realpath -m "${LORELEI_DEVKIT:-$rover_root/lorelei-ae/build/install}")
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
games_root=${GAMES_ROOT:-$rover_root/ae-games}
gui_env=${GUI_ENV:-$HOME/Desktop/spark-gui-env.txt}
runtime_home_root=${RUNTIME_HOME_ROOT:-$repo_root/.work/evaluations/games/runtime-home}
mangohud_enabled=${MANGOHUD_ENABLED:-1}
mangohud=
if [[ $mangohud_enabled == 1 ]]; then
    mangohud=$(command -v mangohud || true)
    [[ -x $mangohud ]] || { echo "MangoHud is enabled but mangohud was not found" >&2; exit 2; }
elif [[ $mangohud_enabled != 0 ]]; then
    echo "MANGOHUD_ENABLED must be 0 or 1: $mangohud_enabled" >&2
    exit 2
fi

sdl_prefix=$repo_root/.work/evaluations/sdl2/installed/hecate/arm64-linux-ae
sdl_thunk=$repo_root/.work/evaluations/sdl2/thunks/hecate
sdl1_prefix=$repo_root/.work/evaluations/sdl1/installed/hecate/arm64-linux-ae
sdl1_thunk=$repo_root/.work/evaluations/sdl1/thunks/hecate
gl_prefix=$repo_root/.work/evaluations/glvnd/installed/arm64-linux-ae
vk_prefix=$repo_root/.work/evaluations/vulkan-loader/installed/arm64-linux-ae
xcb_thunk=$repo_root/.work/evaluations/libxcb/thunks/hecate
x11_thunk=$repo_root/.work/evaluations/libx11/thunk

for required in "$qemu" "$gui_env" "$devkit/bin/x86_64-linux-gnu-clang" \
    "$devkit/x86_64/sysroot" "$devkit/lib/libLoreHostHLRExtension.so" \
    "$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
    "$sdl_thunk/x86_64/libSDL2.so" \
    "$x11_thunk/x86_64/libX11.so.6" \
    "$sdl_prefix/share/libxrandr/thunk/x86_64/libXrandr.so.2" \
    "$gl_prefix/share/glvnd/thunk/x86_64/libGL.so" \
    "$gl_prefix/share/glvnd/glx-thunk/x86_64/libGLX.so.0" \
    "$vk_prefix/share/vulkan-loader/thunk/x86_64/libvulkan.so"; do
    [[ -e $required ]] || { echo "Missing runtime input: $required" >&2; exit 2; }
done

case "$game" in
    assaultcube)
        game_dir=$games_root/assaultcube
        executable=$game_dir/bin_unix/linux_64_client
        game_library_path=""
        game_args=("--home=$runtime_home_root/assaultcube" --init)
        ;;
    hollow-knight)
        game_dir=$games_root/hollow-knight/game
        executable=$game_dir/Hollow\ Knight
        game_library_path="$game_dir:$game_dir/Hollow Knight_Data/MonoBleedingEdge/x86_64"
        if [[ ${HOLLOW_USE_VULKAN:-0} == 1 ]]; then
            game_args=(-force-vulkan -force-gfx-direct -screen-width 1280 -screen-height 720
                -screen-fullscreen 0)
        else
            game_args=(-force-opengl -screen-width 1280 -screen-height 720 -screen-fullscreen 0)
        fi
        ;;
    redeclipse)
        game_dir=$games_root/redeclipse
        executable=$game_dir/bin/amd64/redeclipse_linux
        game_library_path=$game_dir/bin/amd64
        game_args=()
        ;;
    openarena)
        game_dir=$games_root/openarena
        executable=$game_dir/openarena.x86_64
        game_library_path=""
        game_args=(+set r_fullscreen 0 +set r_mode -1 +set r_customwidth 1280
            +set r_customheight 720 +set com_introplayed 1)
        for required in "$sdl1_thunk/x86_64/libSDL.so" \
            "$sdl1_thunk/x86_64/libSDL-1.2.so.0" \
            "$sdl1_prefix/lib/libSDL-1.2.so.0" \
            "$sdl1_prefix/share/sdl1/ThunkDB.json"; do
            [[ -e $required ]] || { echo "Missing SDL 1.2 runtime input: $required" >&2; exit 2; }
        done
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
        game_dir=$games_root/supertux
        executable=$game_dir/build/RelWithDebInfo/supertux2
        game_library_path=$game_dir/runtime-libs
        game_args=(--datadir "$game_dir/build/install/share/games/supertux2")
        ;;
    supertuxkart)
        game_dir=$games_root/supertuxkart
        executable=$game_dir/bin/supertuxkart
        game_library_path=$game_dir/lib
        game_args=()
        ;;
    *)
        echo "Unknown or excluded game: $game" >&2
        exit 2
        ;;
esac

display=$(sed -n 's/^DISPLAY=//p' "$gui_env" | tail -1)
xauthority=$(sed -n 's/^XAUTHORITY=//p' "$gui_env" | tail -1)
run_id=$(date -u +%Y%m%dT%H%M%SZ)
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
host_library_path="$devkit/lib:$host_xorg_path:$sdl1_thunk:$sdl1_prefix/lib:$sdl_prefix/lib:$sdl_thunk:$gl_prefix/share/glvnd/glx-thunk:$gl_prefix/share/glvnd/thunk:$gl_prefix/share/glvnd/x11-thunk:$gl_prefix/lib:$vk_prefix/share/vulkan-loader/thunk:$vk_prefix/lib"
guest_library_path="$guest_xorg_path:$gl_prefix/share/glvnd/x11-thunk/x86_64:$sdl1_thunk/x86_64:$sdl_thunk/x86_64:$gl_prefix/share/glvnd/glx-thunk/x86_64:$gl_prefix/share/glvnd/thunk/x86_64:$vk_prefix/share/vulkan-loader/thunk/x86_64"
if [[ -n $game_library_path ]]; then
    guest_library_path="$guest_library_path:$game_library_path"
fi
guest_library_path="$guest_library_path:$devkit/x86_64/lib:$devkit/x86_64/sysroot/lib/x86_64-linux-gnu:$devkit/x86_64/sysroot/usr/lib/x86_64-linux-gnu"
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
qemu_command=("$qemu")
host_preload=${HOST_PRELOAD-$devkit/lib/libLoreQEMUThreadHook.so}
thunk_databases="$repo_root/vcpkg-overlay/ports/glvnd/lorelei/ThunkDB.json:$repo_root/vcpkg-overlay/ports/vulkan-loader/lorelei/ThunkDB.json"
if [[ $game == openarena ]]; then
    thunk_databases="$sdl1_prefix/share/sdl1/ThunkDB.json:$thunk_databases"
fi
thunk_variables="SDL1_PREFIX=$sdl1_prefix;SDL1_THUNK=$sdl1_thunk;GLVND_PREFIX=$gl_prefix;VULKAN_PREFIX=$vk_prefix"
mangohud_env=()
if [[ $mangohud_enabled == 1 ]]; then
    mangohud_dir=$run_dir/mangohud
    mkdir -p "$mangohud_dir"
    mangohud_duration=$((run_seconds > 2 ? run_seconds - 2 : 1))
    mangohud_config="no_display,autostart_log=1,log_duration=$mangohud_duration,log_interval=100,output_folder=$mangohud_dir"
    if [[ -n ${MANGOHUD_CONFIG_EXTRA:-} ]]; then
        mangohud_config="$mangohud_config,$MANGOHUD_CONFIG_EXTRA"
    fi
    mangohud_env=(MANGOHUD_CONFIG="$mangohud_config")
    qemu_command=("$mangohud" --dlsym "$qemu")
fi

# Some older SDL 1.2 games change the physical XRandR mode and may be killed
# before restoring it. Preserve the active output and mode around every game so
# a failed experiment cannot leave the shared Spark desktop at 640 by 480.
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
cmake -E remove_directory "$preflight_build"
cmake -S "$recipe_dir/tests" -B "$preflight_build" \
    -DLORELEI_DEVKIT="$devkit" \
    "${preflight_sdl_cmake[@]}" \
    -DX11_THUNK="$x11_thunk" \
    -DXRANDR_THUNK="$sdl_prefix/share/libxrandr/thunk" \
    -DGLVND_PREFIX="$gl_prefix" -DVULKAN_PREFIX="$vk_prefix" \
    -DGAME_SDL_ABI="$game_sdl_abi" \
    >"$run_dir/logs/preflight/build.log" 2>&1
cmake --build "$preflight_build" >>"$run_dir/logs/preflight/build.log" 2>&1

run_preflight() {
    local name=$1 binary=$2 status
    set +e
    env \
        DISPLAY="$display" XAUTHORITY="$xauthority" \
        SDL_VIDEODRIVER=x11 SDL_AUDIODRIVER=dummy HOME="$game_home" \
        LORELEI_THUNK_DATABASE="$thunk_databases" \
        LORELEI_THUNKS_CONFIG_VARIABLES="$thunk_variables" \
        LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
        LD_PRELOAD="$host_preload" LD_LIBRARY_PATH="$host_library_path" \
        "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD \
        -E DISPLAY="$display" -E XAUTHORITY="$xauthority" \
        -E SDL_VIDEODRIVER=x11 -E SDL_AUDIODRIVER=dummy -E HOME="$game_home" \
        -E LORELEI_GUEST_LOG_LEVEL="${LORELEI_GUEST_LOG_LEVEL:-1}" \
        -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
        -E LD_LIBRARY_PATH="$guest_library_path" \
        "$binary" >"$run_dir/logs/preflight/$name.log" 2>&1
    status=$?
    set -e
    printf '%s\t%s\n' "$name" "$status" >>"$run_dir/preflight-status.tsv"
    if ((status != 0)); then
        echo "Game preflight failed: $name, see $run_dir/logs/preflight/$name.log" >&2
        return "$status"
    fi
}

printf 'test\texit_status\n' >"$run_dir/preflight-status.tsv"
run_preflight xrandr "$preflight_build/test-xrandr"
run_preflight multi-thunk-db "$preflight_build/test-multi-thunk-db"
if [[ $game == openarena ]]; then
    run_preflight sdl1-video "$preflight_build/test-sdl1-video"
else
    run_preflight sdl2-displays "$preflight_build/test-sdl2-displays"
fi

{
    echo "game=$game"
    echo "started=$(date -u +%FT%TZ)"
    echo "cwd=$game_dir"
    echo "executable=$executable"
    echo "watchdog_seconds=$run_seconds"
    echo "mangohud_enabled=$mangohud_enabled"
} > "$run_dir/run.env"

set +e
(
    cd "$game_dir" || exit 2
    env \
        "${mangohud_env[@]}" \
        DISPLAY="$display" \
        XAUTHORITY="$xauthority" \
        SDL_VIDEODRIVER=x11 \
        SDL_AUDIODRIVER=dummy \
        HOME="$game_home" \
        LORELEI_THUNK_DATABASE="$thunk_databases" \
        LORELEI_THUNKS_CONFIG_VARIABLES="$thunk_variables" \
        LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
        LD_PRELOAD="$host_preload" \
        LD_LIBRARY_PATH="$host_library_path" \
        "${qemu_command[@]}" "${qemu_debug_args[@]}" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD \
        "${guest_preload_args[@]}" \
        -E DISPLAY="$display" \
        -E XAUTHORITY="$xauthority" \
        -E SDL_VIDEODRIVER=x11 \
        -E SDL_AUDIODRIVER=dummy \
        -E HOME="$game_home" \
        -E LD_DEBUG="${GUEST_LD_DEBUG:-}" \
        -E LORELEI_GUEST_LOG_LEVEL="${LORELEI_GUEST_LOG_LEVEL:-1}" \
        -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
        -E LD_LIBRARY_PATH="$guest_library_path" \
        "$executable" "${game_args[@]}"
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
