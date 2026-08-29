#!/usr/bin/env bash
set -euo pipefail
devkit=$1
qemu=$2
work=$3
result=$4
native_prefix=$5
guest_prefix=$6
repo_root=$7
nm_tool=$8
jobs=${JOBS:-$(nproc)}
src_native=$native_prefix/share/libspng/upstream-source
src_guest=$guest_prefix/share/libspng/upstream-source
mkdir -p "$work" "$result" "$work/dump"

cmake -S "$native_prefix/share/libspng/libpng-1.6.43-source" -B "$work/png-native" -G Ninja -DCMAKE_BUILD_TYPE=Release -DPNG_SHARED=ON -DPNG_STATIC=OFF -DPNG_TESTS=OFF -DPNG_TOOLS=OFF -DPNG_HARDWARE_OPTIMIZATIONS=OFF -DZLIB_LIBRARY="$native_prefix/lib/libz.so" -DZLIB_INCLUDE_DIR="$native_prefix/include" -DCMAKE_INSTALL_PREFIX="$work/png-native-install" >"$result/png-native-configure.log" 2>&1
cmake --build "$work/png-native" -j "$jobs" >"$result/png-native-build.log" 2>&1
cmake --install "$work/png-native" >"$result/png-native-install.log" 2>&1
cmake -S "$guest_prefix/share/libspng/libpng-1.6.43-source" -B "$work/png-guest" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER="$devkit/bin/x86_64-linux-gnu-clang" -DCMAKE_C_FLAGS="--sysroot=$devkit/x86_64/sysroot" -DCMAKE_SHARED_LINKER_FLAGS="--sysroot=$devkit/x86_64/sysroot" -DPNG_SHARED=ON -DPNG_STATIC=OFF -DPNG_TESTS=OFF -DPNG_TOOLS=OFF -DPNG_HARDWARE_OPTIMIZATIONS=OFF -DZLIB_LIBRARY="$guest_prefix/lib/libz.so" -DZLIB_INCLUDE_DIR="$guest_prefix/include" -DCMAKE_INSTALL_PREFIX="$work/png-guest-install" >"$result/png-guest-configure.log" 2>&1
cmake --build "$work/png-guest" -j "$jobs" >"$result/png-guest-build.log" 2>&1
cmake --install "$work/png-guest" >"$result/png-guest-install.log" 2>&1

PKG_CONFIG_PATH="$work/png-native-install/lib/pkgconfig:$native_prefix/lib/pkgconfig" meson setup "$work/native" "$src_native" --buildtype=release -Ddefault_library=shared -Ddev_build=true -Denable_opt=true >"$result/native-configure.log" 2>&1
PKG_CONFIG_PATH="$work/png-native-install/lib/pkgconfig:$native_prefix/lib/pkgconfig" meson compile -C "$work/native" -j "$jobs" >"$result/native-build.log" 2>&1
LD_LIBRARY_PATH="$work/png-native-install/lib:$native_prefix/lib:$work/native" meson test -C "$work/native" --print-errorlogs >"$result/native-test.log" 2>&1

cat >"$work/cross.ini" <<EOF
[binaries]
c = '$devkit/bin/x86_64-linux-gnu-clang'
cpp = '$devkit/bin/x86_64-linux-gnu-clang++'
ar = '/usr/bin/llvm-ar-20'
strip = '/usr/bin/llvm-strip-20'
pkg-config = '/usr/bin/pkg-config'
exe_wrapper = '/bin/true'
[host_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
[properties]
pkg_config_libdir = ['$work/png-guest-install/lib/pkgconfig', '$guest_prefix/lib/pkgconfig', '$devkit/x86_64/sysroot/usr/lib/x86_64-linux-gnu/pkgconfig', '$devkit/x86_64/sysroot/usr/share/pkgconfig']
[built-in options]
c_args = ['--sysroot=$devkit/x86_64/sysroot']
cpp_args = ['--sysroot=$devkit/x86_64/sysroot']
c_link_args = ['--sysroot=$devkit/x86_64/sysroot']
cpp_link_args = ['--sysroot=$devkit/x86_64/sysroot']
EOF
meson setup "$work/guest" "$src_guest" --cross-file "$work/cross.ini" --buildtype=release -Ddefault_library=shared -Ddev_build=true -Denable_opt=true >"$result/guest-configure.log" 2>&1
meson compile -C "$work/guest" -j "$jobs" >"$result/guest-build.log" 2>&1

meson introspect --tests "$work/guest" | jq -r '.[].cmd[0]' | sort -u >"$work/dump/test-executables.txt"
while read -r exe; do "$nm_tool" -D --undefined-only --just-symbol-name "$exe"; done <"$work/dump/test-executables.txt" | sed 's/@.*//' | sort -u >"$work/dump/guest-undefined.txt"
host_so=$(readlink -f "$work/native/libspng.so")
"$nm_tool" -D --defined-only --just-symbol-name "$host_so" | sed 's/@.*//' | sort -u >"$work/dump/host-defined.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-defined.txt" >"$work/dump/functions.txt"
{ echo '[Function]'; cat "$work/dump/functions.txt"; } >"$work/dump/Symbols.conf"
"$devkit/bin/LoreMakeThunk.py" --name spng --out "$work/thunk" --lib "$host_so" --symbols "$work/dump/Symbols.conf" --desc "$repo_root/vcpkg-overlay/ports/libspng/lorelei/Desc.h" --devkit "$devkit" --keep-intermediates -- -I"$src_native/spng" >"$result/thunk-build.log" 2>&1

libc_shim=$repo_root/evaluations/common/libc-shim
libc_include=$repo_root/evaluations/common/include
host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$devkit/bin/LoreMakeThunk.py" --name c-shim --out "$work/thunk-libc-shim" --lib "$host_libc" --soname libc-shim.so --symbols "$libc_shim/Symbols.conf" --desc "$libc_shim/Desc.h" --manifest-host "$libc_shim/Manifest_host.cpp" --manifest-guest "$libc_shim/Manifest_guest.cpp" --devkit "$devkit" --keep-intermediates -- -D_GNU_SOURCE -I"$libc_include" >"$result/libc-shim-build.log" 2>&1
ln -sf "$host_libc" "$work/thunk-libc-shim/libc-shim.so"

hecate_wrapper=$work/hecate-wrapper
printf '#!/usr/bin/env bash\nexec env LD_LIBRARY_PATH=%q %q -L %q -E LD_BIND_NOW=1 -E %q -E %q "$@"\n' "$devkit/lib:$work/native:$work/thunk:$work/thunk-libc-shim" "$qemu" "$devkit/x86_64/sysroot" "LD_PRELOAD=$work/thunk-libc-shim/x86_64/libc-shim.so" "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64:$work/png-guest-install/lib:$guest_prefix/lib" >"$hecate_wrapper"
chmod +x "$hecate_wrapper"
sed "s|exe_wrapper = '.*'|exe_wrapper = '$hecate_wrapper'|" "$work/cross.ini" >"$work/hecate-cross.ini"
meson setup "$work/hecate" "$src_guest" --cross-file "$work/hecate-cross.ini" --buildtype=release -Ddefault_library=shared -Ddev_build=true -Denable_opt=true >"$result/hecate-configure.log" 2>&1
meson compile -C "$work/hecate" -j "$jobs" >"$result/hecate-build.log" 2>&1
meson test -C "$work/hecate" --print-errorlogs >"$result/hecate-test.log" 2>&1

for lane in native hecate; do
  log=$result/$lane-test.log
  grep -Eq '^Ok:[[:space:]]+167' "$log"
  grep -Eq '^Expected Fail:[[:space:]]+41' "$log"
  grep -Eq '^Fail:[[:space:]]+0' "$log"
  grep -Eq '^Skipped:[[:space:]]+0' "$log"
done
cp "$work/thunk/.gen/spng/ThunkStat.json" "$work/dump/ThunkStat.json"
printf '{"registered_tests":208,"normal_passed":167,"expected_failures":41,"failed":0,"oracle":"libpng 1.6.43"}\n' >"$result/summary.json"
