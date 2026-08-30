#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../../.." && pwd)
work_root=$repo_root/.work/evaluations
excluded=(breakdown-test)

while (($#)); do
    case $1 in
        --work-root)
            [[ $# -ge 2 ]] || { echo "--work-root requires a path" >&2; exit 2; }
            work_root=$(realpath -m "$2")
            shift
            ;;
        --exclude)
            [[ $# -ge 2 ]] || { echo "--exclude requires a recipe name" >&2; exit 2; }
            excluded+=("$2")
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--work-root PATH] [--exclude RECIPE]..."
            echo "Counts real ELF shared objects from each recipe's vcpkg package directory."
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
    shift
done

is_excluded() {
    local candidate=$1 item
    for item in "${excluded[@]}"; do
        [[ $candidate == "$item" ]] && return 0
    done
    return 1
}

find_package_dir() {
    local recipe=$1 lane candidate
    for lane in native hecate host guest; do
        candidate=$(find "$work_root/$recipe" -type d \
            -path "*/$lane/packages/${recipe}_arm64-linux-ae" -print -quit 2>/dev/null || true)
        [[ -n $candidate && -d $candidate/lib ]] && { printf '%s\n' "$candidate"; return 0; }
    done
    candidate=$(find "$work_root/$recipe" -type d \
        \( -name "${recipe}_arm64-linux-ae" -o -name "${recipe}_x64-linux-ae" \) \
        -path '*/packages/*' -print 2>/dev/null \
        | while IFS= read -r path; do [[ -d $path/lib ]] && { printf '%s\n' "$path"; break; }; done)
    [[ -n $candidate ]] && { printf '%s\n' "$candidate"; return 0; }
    return 1
}

packages=0
all_test_packages=0
shared_objects=0
all_test_shared_objects=0
missing=0
printf 'recipe\tall_tests_passed\tshared_objects\tpackage_dir\n'
for run_script in "$repo_root"/evaluations/1-libs/*/run.sh; do
    recipe=${run_script%/run.sh}
    recipe=${recipe##*/}
    is_excluded "$recipe" && continue
    packages=$((packages + 1))

    all_tests=false
    if head -n 1 "$repo_root/evaluations/1-libs/$recipe/README.md" \
        | grep -Fq '[ALL TESTS PASSED]'; then
        all_tests=true
        all_test_packages=$((all_test_packages + 1))
    fi

    package_dir=$(find_package_dir "$recipe" || true)
    count=0
    if [[ -n $package_dir ]]; then
        while IFS= read -r library; do
            if readelf -h "$library" >/dev/null 2>&1; then
                count=$((count + 1))
            fi
        done < <(find "$package_dir/lib" -maxdepth 1 -type f -name '*.so*' | sort)
    else
        missing=$((missing + 1))
    fi
    shared_objects=$((shared_objects + count))
    $all_tests && all_test_shared_objects=$((all_test_shared_objects + count))
    printf '%s\t%s\t%d\t%s\n' "$recipe" "$all_tests" "$count" "${package_dir:-MISSING}"
done

awk -v packages="$packages" -v passed="$all_test_packages" \
    -v shared="$shared_objects" -v passed_shared="$all_test_shared_objects" \
    -v missing="$missing" 'BEGIN {
        printf "SUMMARY\tpackages=%d\tall_tests_packages=%d\tpackage_ratio=%.2f%%", packages, passed, 100 * passed / packages
        printf "\tshared_objects=%d\tall_tests_shared_objects=%d\tshared_object_ratio=%.2f%%\tmissing=%d\n", shared, passed_shared, 100 * passed_shared / shared, missing
    }'
